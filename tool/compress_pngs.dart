// Losslessly recompresses the doc images after `make goldens-update`
// (tool/update_goldens.sh runs it). Flutter writes RGBA PNGs with filter 0
// and default zlib; this picks a filter per row, drops an all-opaque alpha
// channel and uses zlib level 9. The pixels never change: every output is
// decoded and compared with its input before it is written, and a file
// that would not get smaller is left alone. The goldens compare decoded
// pixels, so they still match.
//
// Usage: dart run tool/compress_pngs.dart <dir>...
import 'dart:io';
import 'dart:typed_data';

/// The 8 bytes every PNG starts with.
const pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = c.isOdd ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xff] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

/// One PNG chunk: length, [type], [data], CRC.
List<int> pngChunk(String type, List<int> data) {
  final body = [...type.codeUnits, ...data];
  final length = ByteData(4)..setUint32(0, data.length);
  final crc = ByteData(4)..setUint32(0, _crc32(body));
  return [
    ...length.buffer.asUint8List(),
    ...body,
    ...crc.buffer.asUint8List(),
  ];
}

typedef _Chunk = ({String type, Uint8List data});

List<_Chunk> _chunks(Uint8List bytes) {
  for (var i = 0; i < pngSignature.length; i++) {
    if (bytes.length < 8 || bytes[i] != pngSignature[i]) {
      throw const FormatException('not a PNG');
    }
  }
  final view = ByteData.sublistView(bytes);
  final chunks = <_Chunk>[];
  var at = 8;
  while (at + 12 <= bytes.length) {
    final length = view.getUint32(at);
    final type = String.fromCharCodes(bytes.sublist(at + 4, at + 8));
    chunks.add((
      type: type,
      data: Uint8List.sublistView(bytes, at + 8, at + 8 + length),
    ));
    at += 12 + length;
    if (type == 'IEND') break;
  }
  return chunks;
}

/// A decoded 8-bit RGB or RGBA PNG without interlacing.
typedef DecodedPng = ({
  int width,
  int height,
  int colorType,
  // Unfiltered samples, row after row, without filter bytes.
  Uint8List samples,
  // The filter types its rows used.
  Set<int> filters,
  // The samples as RGBA, for comparing two encodings.
  Uint8List rgba,
});

/// Decodes [bytes]. Throws a [FormatException] for anything but 8-bit,
/// non-interlaced RGB (colour type 2) or RGBA (6).
DecodedPng decodePng(Uint8List bytes) {
  final chunks = _chunks(bytes);
  final ihdr = ByteData.sublistView(chunks.first.data);
  final width = ihdr.getUint32(0);
  final height = ihdr.getUint32(4);
  final depth = ihdr.getUint8(8);
  final colorType = ihdr.getUint8(9);
  final interlace = ihdr.getUint8(12);
  if (depth != 8 || (colorType != 2 && colorType != 6) || interlace != 0) {
    throw FormatException(
      'unsupported PNG: depth $depth, colour type $colorType, '
      'interlace $interlace',
    );
  }
  final idat = BytesBuilder(copy: false);
  for (final c in chunks) {
    if (c.type == 'IDAT') idat.add(c.data);
  }
  final raw = zlib.decode(idat.takeBytes());
  final bpp = colorType == 6 ? 4 : 3;
  final stride = width * bpp;
  final samples = Uint8List(stride * height);
  final filters = <int>{};
  for (var y = 0; y < height; y++) {
    final filter = raw[y * (stride + 1)];
    filters.add(filter);
    final src = y * (stride + 1) + 1;
    final row = y * stride;
    for (var x = 0; x < stride; x++) {
      final a = x >= bpp ? samples[row + x - bpp] : 0;
      final b = y > 0 ? samples[row - stride + x] : 0;
      final c = x >= bpp && y > 0 ? samples[row - stride + x - bpp] : 0;
      samples[row + x] = (raw[src + x] + _predict(filter, a, b, c)) & 0xff;
    }
  }
  final rgba = colorType == 6 ? samples : Uint8List(width * height * 4);
  if (colorType == 2) {
    for (var p = 0; p < width * height; p++) {
      rgba
        ..[p * 4] = samples[p * 3]
        ..[p * 4 + 1] = samples[p * 3 + 1]
        ..[p * 4 + 2] = samples[p * 3 + 2]
        ..[p * 4 + 3] = 255;
    }
  }
  return (
    width: width,
    height: height,
    colorType: colorType,
    samples: samples,
    filters: filters,
    rgba: rgba,
  );
}

int _predict(int filter, int a, int b, int c) => switch (filter) {
  0 => 0,
  1 => a,
  2 => b,
  3 => (a + b) >> 1,
  4 => _paeth(a, b, c),
  _ => throw FormatException('unknown PNG filter $filter'),
};

int _paeth(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs();
  final pb = (p - b).abs();
  final pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  return pb <= pc ? b : c;
}

/// Rows filtered with the filter whose output has the smallest sum of
/// absolute signed bytes (the libpng heuristic), each after its type byte.
Uint8List _filterRows(Uint8List samples, int stride, int height, int bpp) {
  final out = Uint8List((stride + 1) * height);
  final candidate = Uint8List(stride);
  for (var y = 0; y < height; y++) {
    final row = y * stride;
    var bestCost = 1 << 62;
    for (var filter = 0; filter < 5; filter++) {
      var cost = 0;
      for (var x = 0; x < stride; x++) {
        final a = x >= bpp ? samples[row + x - bpp] : 0;
        final b = y > 0 ? samples[row - stride + x] : 0;
        final c = x >= bpp && y > 0 ? samples[row - stride + x - bpp] : 0;
        final v = (samples[row + x] - _predict(filter, a, b, c)) & 0xff;
        candidate[x] = v;
        cost += v < 128 ? v : 256 - v;
      }
      if (cost < bestCost) {
        bestCost = cost;
        out[y * (stride + 1)] = filter;
        out.setRange(y * (stride + 1) + 1, (y + 1) * (stride + 1), candidate);
      }
    }
  }
  return out;
}

/// [bytes] re-encoded losslessly, or null when the image is not one this
/// handles or the result would not be smaller. Throws a [StateError] if the
/// re-encoded pixels differ (a bug, never written).
Uint8List? compressPng(Uint8List bytes) {
  final DecodedPng png;
  try {
    png = decodePng(bytes);
  } on FormatException {
    return null;
  }
  var colorType = png.colorType;
  var samples = png.samples;
  final pixels = png.width * png.height;
  if (colorType == 6) {
    var opaque = true;
    for (var p = 0; p < pixels && opaque; p++) {
      opaque = samples[p * 4 + 3] == 255;
    }
    if (opaque) {
      colorType = 2;
      final rgb = Uint8List(pixels * 3);
      for (var p = 0; p < pixels; p++) {
        rgb
          ..[p * 3] = samples[p * 4]
          ..[p * 3 + 1] = samples[p * 4 + 1]
          ..[p * 3 + 2] = samples[p * 4 + 2];
      }
      samples = rgb;
    }
  }
  final bpp = colorType == 6 ? 4 : 3;
  final filtered = _filterRows(samples, png.width * bpp, png.height, bpp);
  final ihdr = Uint8List.fromList(_chunks(bytes).first.data)..[9] = colorType;
  final out = BytesBuilder(copy: false)
    ..add(pngSignature)
    ..add(pngChunk('IHDR', ihdr));
  for (final c in _chunks(bytes)) {
    // sBIT describes the old channels; IDAT is rewritten below.
    if (const {'IHDR', 'IDAT', 'IEND', 'sBIT'}.contains(c.type)) continue;
    out.add(pngChunk(c.type, c.data));
  }
  out
    ..add(
      pngChunk('IDAT', ZLibEncoder(level: 9, memLevel: 9).convert(filtered)),
    )
    ..add(pngChunk('IEND', const []));
  final result = out.takeBytes();
  if (!_same(decodePng(result).rgba, png.rgba)) {
    throw StateError('re-encoded pixels differ');
  }
  return result.length < bytes.length ? result : null;
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void main(List<String> args) {
  var before = 0;
  var after = 0;
  for (final dir in args) {
    final files =
        Directory(dir)
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.png'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final bytes = file.readAsBytesSync();
      final smaller = compressPng(bytes);
      before += bytes.length;
      after += smaller?.length ?? bytes.length;
      if (smaller != null) file.writeAsBytesSync(smaller);
    }
  }
  stdout.writeln(
    '✓ PNGs recompressed losslessly: ${before ~/ 1024} KB → '
    '${after ~/ 1024} KB',
  );
}
