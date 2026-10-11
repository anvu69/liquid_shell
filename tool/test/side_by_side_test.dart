import 'dart:typed_data';

import 'package:test/test.dart';

import '../compress_pngs.dart';
import '../side_by_side.dart';

Rgba _solid(int width, int height, List<int> rgba) => (
  width: width,
  height: height,
  pixels: Uint8List.fromList([
    for (var i = 0; i < width * height; i++) ...rgba,
  ]),
);

List<int> _at(Rgba image, int x, int y) {
  final i = (y * image.width + x) * 4;
  return image.pixels.sublist(i, i + 4);
}

void main() {
  test('scaleToHeight keeps the aspect ratio and the colour', () {
    final scaled = scaleToHeight(_solid(4, 8, [10, 20, 30, 255]), 4);
    expect(scaled.width, 2);
    expect(scaled.height, 4);
    expect(_at(scaled, 1, 3), [10, 20, 30, 255]);
  });

  test('sideBySide: left, a white gap, then right at the left height', () {
    final out = sideBySide(
      _solid(10, 20, [255, 0, 0, 255]),
      _solid(5, 10, [0, 0, 255, 255]),
    );
    expect(out.height, 20);
    expect(out.width, 10 + sideBySideGap + 10);
    expect(_at(out, 0, 0), [255, 0, 0, 255]);
    expect(_at(out, 10 + sideBySideGap ~/ 2, 5), [255, 255, 255, 255]);
    expect(_at(out, 10 + sideBySideGap + 9, 19), [0, 0, 255, 255]);
  });

  test('shrinkToHeight averages the area each output pixel covers', () {
    // Two columns: black and white. Halving both sides gives one grey
    // pixel per 2×2 block, where bilinear would pick a single source pixel.
    final image = (
      width: 4,
      height: 4,
      pixels: Uint8List.fromList([
        for (var y = 0; y < 4; y++)
          for (var x = 0; x < 4; x++)
            ...(x.isEven ? [0, 0, 0, 255] : [255, 255, 255, 255]),
      ]),
    );
    final shrunk = shrinkToHeight(image, 2);
    expect(shrunk.width, 2);
    expect(shrunk.height, 2);
    expect(_at(shrunk, 1, 1), [128, 128, 128, 255]);
  });

  test('shrinkToHeight leaves a smaller image alone', () {
    final image = _solid(3, 5, [1, 2, 3, 255]);
    expect(identical(shrinkToHeight(image, 10), image), isTrue);
  });

  test('sideBySideFit is at most sideBySideWidth wide, gap kept', () {
    final out = sideBySideFit(
      _solid(1206, 2622, [255, 0, 0, 255]),
      _solid(1080, 2400, [0, 0, 255, 255]),
    );
    expect(out.width, lessThanOrEqualTo(sideBySideWidth));
    expect(out.width, greaterThan(sideBySideWidth - 4));
    final leftWidth = (1206 * out.height / 2622).round();
    expect(_at(out, leftWidth - 1, 0), [255, 0, 0, 255]);
    expect(_at(out, leftWidth + sideBySideGap ~/ 2, 0), [255, 255, 255, 255]);
    expect(_at(out, out.width - 1, out.height - 1), [0, 0, 255, 255]);
  });

  test('sideBySideFit keeps images that already fit at full size', () {
    final out = sideBySideFit(
      _solid(100, 200, [255, 0, 0, 255]),
      _solid(100, 200, [0, 0, 255, 255]),
    );
    expect(out.height, 200);
    expect(out.width, 100 + sideBySideGap + 100);
  });

  test('encodeRgbaPng round-trips through decodePng', () {
    final image = (
      width: 3,
      height: 2,
      pixels: Uint8List.fromList(List.generate(24, (i) => i * 10)),
    );
    final png = decodePng(encodeRgbaPng(image));
    expect(png.width, 3);
    expect(png.height, 2);
    expect(png.rgba, image.pixels);
  });
}
