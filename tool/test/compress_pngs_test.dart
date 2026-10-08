import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import '../compress_pngs.dart';

/// A plain PNG as a renderer writes it: filter 0 on every row (or 3,
/// Average, with [average]), fast zlib.
Uint8List rawPng(
  int width,
  int height,
  int colorType,
  List<int> pixels, {
  bool average = false,
}) {
  final channels = colorType == 6 ? 4 : 3;
  final stride = width * channels;
  final rows = BytesBuilder();
  for (var y = 0; y < height; y++) {
    rows.addByte(average ? 3 : 0);
    for (var x = 0; x < stride; x++) {
      final value = pixels[y * stride + x];
      final left = x >= channels ? pixels[y * stride + x - channels] : 0;
      final up = y > 0 ? pixels[(y - 1) * stride + x] : 0;
      rows.addByte(average ? (value - ((left + up) >> 1)) & 0xff : value);
    }
  }
  final ihdr = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8)
    ..setUint8(9, colorType);
  return Uint8List.fromList([
    ...pngSignature,
    ...pngChunk('IHDR', ihdr.buffer.asUint8List()),
    ...pngChunk('sRGB', [0]),
    if (colorType == 6) ...pngChunk('sBIT', [8, 8, 8, 8]),
    ...pngChunk('IDAT', ZLibEncoder(level: 1).convert(rows.takeBytes())),
    ...pngChunk('IEND', []),
  ]);
}

/// A smooth gradient with a few discs: compresses like a screenshot.
List<int> picture(int width, int height, {int Function(int x, int y)? alpha}) {
  return [
    for (var y = 0; y < height; y++)
      for (var x = 0; x < width; x++) ...[
        (x * 3 + y) & 0xff,
        (y * 2) & 0xff,
        if ((x - 20) * (x - 20) + (y - 16) * (y - 16) < 120) 200 else 40,
        alpha?.call(x, y) ?? 255,
      ],
  ];
}

int colorTypeOf(Uint8List png) => png[25];

void main() {
  test('an opaque RGBA image becomes a smaller RGB one with the same '
      'pixels', () {
    final input = rawPng(64, 48, 6, picture(64, 48));
    final output = compressPng(input);
    expect(output, isNotNull);
    expect(output!.length, lessThan(input.length));
    expect(colorTypeOf(output), 2);
    expect(decodePng(output).rgba, decodePng(input).rgba);
  });

  test('a translucent image keeps its alpha and its pixels', () {
    final input = rawPng(
      64,
      48,
      6,
      picture(64, 48, alpha: (x, y) => (x + y).isEven ? 255 : 128),
    );
    final output = compressPng(input)!;
    expect(colorTypeOf(output), 6);
    expect(decodePng(output).rgba, decodePng(input).rgba);
  });

  test('rows filtered with None, Sub, Up, Average and Paeth decode to the '
      'same pixels', () {
    // Rows that repeat the one above pick Up; the gradient picks Sub or
    // Paeth.
    final base = picture(64, 48);
    final striped = [
      for (var y = 0; y < 48; y++)
        ...base.sublist((y - y % 2) * 64 * 4, (y - y % 2 + 1) * 64 * 4),
    ];
    final output = compressPng(rawPng(64, 48, 6, striped))!;
    expect(decodePng(output).filters, containsAll(<int>[1, 2, 4]));
    expect(decodePng(output).rgba, striped);

    final averaged = rawPng(64, 48, 6, base, average: true);
    expect(decodePng(averaged).filters, {3});
    expect(decodePng(averaged).rgba, base);
    expect(decodePng(rawPng(64, 48, 6, base)).filters, {0});
  });

  test('a second pass changes nothing, so regenerating is stable', () {
    final once = compressPng(rawPng(64, 48, 6, picture(64, 48)))!;
    expect(compressPng(once), isNull);
  });

  test('a PNG it does not handle is left alone', () {
    final input = rawPng(8, 8, 6, picture(8, 8));
    final paletted = Uint8List.fromList(input)..[25] = 3;
    expect(compressPng(paletted), isNull);
  });
}
