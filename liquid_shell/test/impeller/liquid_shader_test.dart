@Tags(['impeller'])
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/glass/liquid_optics.dart';

const _scale = 2.0;
const _view = Size(400, 300);

/// Stripes 8 pt wide, alternating pure red and pure blue, so a sample's
/// source column is readable from its colour.
class _Stripes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    for (var x = 0.0; x < size.width; x += 16) {
      canvas
        ..drawRect(
          Rect.fromLTWH(x, 0, 8, size.height),
          Paint()..color = const Color(0xFFFF0000),
        )
        ..drawRect(
          Rect.fromLTWH(x + 8, 0, 8, size.height),
          Paint()..color = const Color(0xFF0000FF),
        );
    }
  }

  @override
  bool shouldRepaint(_Stripes oldDelegate) => false;
}

Future<ui.FragmentProgram> _program(WidgetTester tester) async =>
    (await tester.runAsync(
      () => ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag'),
    ))!;

ui.ImageFilter _lens(
  ui.FragmentProgram program,
  Rect logical, {
  BorderRadius radii = BorderRadius.zero,
  LiquidOpticsParams params = const LiquidOpticsParams(
    tint: Color(0x00000000),
    rim: Color(0x00000000),
    refraction: 1,
    dispersion: 0,
    blurSigma: 0,
  ),
}) {
  final shader = program.fragmentShader();
  final floats = liquidUniforms(
    rect: Rect.fromLTRB(
      logical.left * _scale,
      logical.top * _scale,
      logical.right * _scale,
      logical.bottom * _scale,
    ),
    radii: radii,
    params: params,
    scale: _scale,
    pass: _view * _scale,
  );
  for (var i = 0; i < floats.length; i++) {
    shader.setFloat(LiquidOptics.firstIndex + i, floats[i]);
  }
  return ui.ImageFilter.shader(shader);
}

Future<ByteData> _render(WidgetTester tester, Widget glass) async {
  tester.view
    ..devicePixelRatio = _scale
    ..physicalSize = _view * _scale;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _Stripes())),
          glass,
        ],
      ),
    ),
  );
  // Capture from the root, at the view's pixel ratio (spec §3.2), as
  // matchesGoldenFile does for a widget with no repaint boundary of its own.
  final view = tester.binding.renderViews.single;
  final layer = view.debugLayer! as OffsetLayer;
  final image = await tester.runAsync(() => layer.toImage(view.paintBounds));
  return (await tester.runAsync(() => image!.toByteData()))!;
}

/// RGBA of the pixel at logical [p].
List<int> _pixel(ByteData data, Offset p) {
  final x = (p.dx * _scale).round();
  final y = (p.dy * _scale).round();
  final i = (y * (_view.width * _scale).round() + x) * 4;
  return [
    data.getUint8(i),
    data.getUint8(i + 1),
    data.getUint8(i + 2),
    data.getUint8(i + 3),
  ];
}

void main() {
  test('runs with Impeller only', () {
    expect(ui.ImageFilter.isShaderFilterSupported, isTrue);
  });

  testWidgets('the bezel samples from further in (lensing)', (tester) async {
    final program = await _program(tester);
    // Stripes: red on [16k, 16k + 8), blue on [16k + 8, 16k + 16).
    // At 101 (bezel x ~ 0.1) the shift is ~7.8 pt: 108.8 is blue [104, 112)
    // and unbent 101 is red [96, 104), but an outward 93.2 is blue too
    // [88, 96), so this probe proves bending, not its direction.
    const glass = Rect.fromLTWH(100, 100, 200, 100);
    final data = await _render(
      tester,
      Positioned.fromRect(
        rect: glass,
        child: ClipRect(
          child: BackdropFilter(
            filter: _lens(program, glass),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    final edge = _pixel(data, const Offset(100.75, 150));
    expect(edge[2], greaterThan(edge[0]), reason: 'blue sampled: $edge');
    // Direction: at 103.75 (bezel x ~ 0.31) the shift is ~3.2 pt. Inward
    // 106.95 is blue [104, 112); outward 100.55 and unbent 103.75 are red
    // [96, 104).
    final inward = _pixel(data, const Offset(103.5, 150));
    expect(
      inward[2],
      greaterThan(inward[0]),
      reason: 'inward (blue) sampled: $inward',
    );
    // The body is not bent: 204 lies in blue [200, 208).
    final centre = _pixel(data, const Offset(204, 150));
    expect(centre[2], greaterThan(200), reason: 'centre is the backdrop');
  });

  testWidgets('the specular rim lights the top more than the bottom', (
    tester,
  ) async {
    final program = await _program(tester);
    const glass = Rect.fromLTWH(100, 100, 200, 100);
    final data = await _render(
      tester,
      Positioned.fromRect(
        rect: glass,
        child: ClipRect(
          child: BackdropFilter(
            filter: _lens(
              program,
              glass,
              params: const LiquidOpticsParams(
                tint: Color(0x00000000),
                rim: Color(0xFFFFFFFF),
                refraction: 0,
                dispersion: 0,
                blurSigma: 0,
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    int brightness(List<int> p) => p[0] + p[1] + p[2];
    final top = _pixel(data, const Offset(204, 100.25));
    final bottom = _pixel(data, const Offset(204, 199.5));
    expect(brightness(top), greaterThan(brightness(bottom)));
  });

  testWidgets('a full tint replaces the backdrop in the body', (tester) async {
    final program = await _program(tester);
    const glass = Rect.fromLTWH(100, 100, 200, 100);
    final data = await _render(
      tester,
      Positioned.fromRect(
        rect: glass,
        child: ClipRect(
          child: BackdropFilter(
            filter: _lens(
              program,
              glass,
              params: const LiquidOpticsParams(
                tint: Color(0xFF00FF00),
                rim: Color(0x00000000),
                refraction: 1,
                dispersion: 0,
                blurSigma: 0,
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    final centre = _pixel(data, const Offset(200, 150));
    expect(centre[1], greaterThan(240));
    expect(centre[0], lessThan(15));
  });

  testWidgets('screen-edge rule: no rim on a side flush with the screen', (
    tester,
  ) async {
    final program = await _program(tester);
    const glass = Rect.fromLTWH(0, 0, 120, 300); // a sidebar
    final data = await _render(
      tester,
      Positioned.fromRect(
        rect: glass,
        child: ClipRect(
          child: BackdropFilter(
            filter: _lens(
              program,
              glass,
              params: const LiquidOpticsParams(
                tint: Color(0x00000000),
                rim: Color(0xFFFFFFFF),
                refraction: 0,
                dispersion: 0,
                blurSigma: 0,
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    int brightness(List<int> p) => p[0] + p[1] + p[2];
    // Every probe sits in a red stripe: [0, 8) and [112, 120).
    final body = brightness(_pixel(data, const Offset(114, 150)));
    // Left side, flush with the screen: no rim, same as the body.
    expect(brightness(_pixel(data, const Offset(0.25, 150))), body);
    // Inner (right) side: the rim adds light.
    expect(
      brightness(_pixel(data, const Offset(119.5, 150))),
      greaterThan(body + 100),
    );
  });
}
