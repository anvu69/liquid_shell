// Places two screenshots side by side for the liquid tier acceptance
// (spec 2026-10-10 §10.4, §11): iOS 26 native on the left, Flutter liquid
// on the right. The right image is scaled (bilinear) to the left one's
// height; the gap and the margins are white. The pair is shrunk (area
// average) to at most sideBySideWidth px wide, so a README image stays
// small. Pure Dart: reuses the PNG decoder of tool/compress_pngs.dart and
// writes an RGBA PNG.
//
// Usage: dart run tool/side_by_side.dart <left.png> <right.png> <out.png>
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'compress_pngs.dart';

/// Gap between the two images, in pixels.
const sideBySideGap = 24;

/// Largest width of a composed pair, in pixels.
const sideBySideWidth = 820;

/// An RGBA image.
typedef Rgba = ({int width, int height, Uint8List pixels});

/// [image] scaled to [height] with bilinear sampling, keeping its aspect.
Rgba scaleToHeight(Rgba image, int height) {
  if (image.height == height) return image;
  final width = (image.width * height / image.height).round();
  final out = Uint8List(width * height * 4);
  final sx = image.width / width;
  final sy = image.height / height;
  for (var y = 0; y < height; y++) {
    final fy = ((y + 0.5) * sy - 0.5).clamp(0, image.height - 1).toDouble();
    final y0 = fy.floor();
    final y1 = (y0 + 1).clamp(0, image.height - 1);
    final wy = fy - y0;
    for (var x = 0; x < width; x++) {
      final fx = ((x + 0.5) * sx - 0.5).clamp(0, image.width - 1).toDouble();
      final x0 = fx.floor();
      final x1 = (x0 + 1).clamp(0, image.width - 1);
      final wx = fx - x0;
      for (var c = 0; c < 4; c++) {
        int at(int px, int py) => image.pixels[(py * image.width + px) * 4 + c];
        final top = at(x0, y0) * (1 - wx) + at(x1, y0) * wx;
        final bottom = at(x0, y1) * (1 - wx) + at(x1, y1) * wx;
        out[(y * width + x) * 4 + c] = (top * (1 - wy) + bottom * wy).round();
      }
    }
  }
  return (width: width, height: height, pixels: out);
}

/// [left] and [right] (scaled to [left]'s height) with a white gap.
Rgba sideBySide(Rgba left, Rgba right) {
  final r = scaleToHeight(right, left.height);
  final width = left.width + sideBySideGap + r.width;
  // Opaque white everywhere the two images do not cover.
  final out = Uint8List(width * left.height * 4)
    ..fillRange(0, width * left.height * 4, 255);
  for (var y = 0; y < left.height; y++) {
    out.setRange(
      y * width * 4,
      y * width * 4 + left.width * 4,
      left.pixels,
      y * left.width * 4,
    );
    final start = (y * width + left.width + sideBySideGap) * 4;
    out.setRange(start, start + r.width * 4, r.pixels, y * r.width * 4);
  }
  return (width: width, height: left.height, pixels: out);
}

/// [image] shrunk to [height] by averaging the area each output pixel
/// covers, keeping its aspect; returned as is when it is not taller.
///
/// Bilinear sampling at a 3× reduction reads one source pixel in nine, so
/// text and hairlines would alias.
Rgba shrinkToHeight(Rgba image, int height) {
  if (height >= image.height) return image;
  final width = math.max(1, (image.width * height / image.height).round());
  final xs = _areaWeights(image.width, width);
  final ys = _areaWeights(image.height, height);
  final out = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      for (var c = 0; c < 4; c++) {
        var sum = 0.0;
        for (final (sy, wy) in ys[y]) {
          for (final (sx, wx) in xs[x]) {
            sum += image.pixels[(sy * image.width + sx) * 4 + c] * wy * wx;
          }
        }
        out[(y * width + x) * 4 + c] = sum.round().clamp(0, 255);
      }
    }
  }
  return (width: width, height: height, pixels: out);
}

/// For each of [to] output samples, the source samples of [from] it covers
/// and their weights (summing to 1).
List<List<(int, double)>> _areaWeights(int from, int to) {
  final step = from / to;
  return [
    for (var i = 0; i < to; i++)
      [
        for (var j = (i * step).floor(); j < ((i + 1) * step).ceil(); j++)
          if (j < from)
            (
              j,
              (math.min(j + 1, (i + 1) * step) - math.max(j, i * step)) / step,
            ),
      ],
  ];
}

/// [sideBySide] of [left] and [right], both shrunk to one height so the
/// pair is at most [width] pixels wide.
Rgba sideBySideFit(Rgba left, Rgba right, {int width = sideBySideWidth}) {
  final aspects = left.width / left.height + right.width / right.height;
  final height = ((width - sideBySideGap) / aspects).floor();
  return sideBySide(
    shrinkToHeight(left, height),
    shrinkToHeight(right, height),
  );
}

/// [image] as a PNG: 8-bit RGBA, filter 0, zlib.
Uint8List encodeRgbaPng(Rgba image) {
  final stride = image.width * 4;
  final raw = Uint8List((stride + 1) * image.height);
  for (var y = 0; y < image.height; y++) {
    raw.setRange(
      y * (stride + 1) + 1,
      (y + 1) * (stride + 1),
      image.pixels,
      y * stride,
    );
  }
  final ihdr = ByteData(13)
    ..setUint32(0, image.width)
    ..setUint32(4, image.height)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 6); // RGBA
  return Uint8List.fromList([
    ...pngSignature,
    ...pngChunk('IHDR', ihdr.buffer.asUint8List()),
    ...pngChunk('IDAT', zlib.encode(raw)),
    ...pngChunk('IEND', const []),
  ]);
}

Rgba _read(String path) {
  final png = decodePng(File(path).readAsBytesSync());
  return (width: png.width, height: png.height, pixels: png.rgba);
}

void main(List<String> args) {
  if (args.length != 3) {
    stderr.writeln(
      'usage: dart run tool/side_by_side.dart <left.png> <right.png> <out>',
    );
    exit(2);
  }
  final out = File(args[2])..createSync(recursive: true);
  final bytes = encodeRgbaPng(sideBySideFit(_read(args[0]), _read(args[1])));
  out.writeAsBytesSync(compressPng(bytes) ?? bytes);
  stdout.writeln('✓ ${args[2]}');
}
