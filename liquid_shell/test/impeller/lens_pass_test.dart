@Tags(['impeller'])
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/glass/liquid_optics.dart';

const _scale = 2.0;
const _view = Size(400, 300);
const _pill = Rect.fromLTWH(50, 100, 300, 62);
const _lensRect = Rect.fromLTWH(100, 104, 94, 54);

/// A pill pixel outside the lens, clear of the pill's corners.
const _pillPoint = Offset(75, 131);

ui.ImageFilter _filter(ui.FragmentProgram program, Rect r, Color tint) {
  final shader = program.fragmentShader();
  final floats = liquidUniforms(
    rect: Rect.fromLTRB(
      r.left * _scale,
      r.top * _scale,
      r.right * _scale,
      r.bottom * _scale,
    ),
    radii: BorderRadius.circular(r.height / 2),
    params: LiquidOpticsParams(
      tint: tint,
      rim: const Color(0x00000000),
      refraction: 0,
      dispersion: 0,
      blurSigma: 0,
    ),
    scale: _scale,
    pass: _view * _scale,
  );
  for (var i = 0; i < floats.length; i++) {
    shader.setFloat(LiquidOptics.firstIndex + i, floats[i]);
  }
  return ui.ImageFilter.shader(shader);
}

Widget _pass(
  ui.FragmentProgram p,
  Rect r,
  Color tint, {
  required bool grouped,
}) => Positioned.fromRect(
  rect: r,
  child: ClipRect(
    child: grouped
        ? BackdropFilter.grouped(
            filter: _filter(p, r, tint),
            child: const SizedBox.expand(),
          )
        : BackdropFilter(
            filter: _filter(p, r, tint),
            child: const SizedBox.expand(),
          ),
  ),
);

/// The RGB at the lens centre and at [_pillPoint].
Future<({List<int> lens, List<int> pill})> _sample(
  WidgetTester tester, {
  required bool grouped,
}) async {
  final program = (await tester.runAsync(
    () => ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag'),
  ))!;
  tester.view
    ..devicePixelRatio = _scale
    ..physicalSize = _view * _scale;
  addTearDown(tester.view.reset);
  final stack = Stack(
    children: [
      const Positioned.fill(child: ColoredBox(color: Color(0xFF00FF00))),
      // The pill: an opaque red tint, so the lens would show red if it
      // sampled the pill.
      _pass(program, _pill, const Color(0xFFFF0000), grouped: grouped),
      // The lens: clear, no refraction, so it shows what it samples.
      _pass(program, _lensRect, const Color(0x00000000), grouped: grouped),
    ],
  );
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: grouped ? BackdropGroup(child: stack) : stack,
    ),
  );
  final view = tester.binding.renderViews.single;
  final layer = view.debugLayer! as OffsetLayer;
  final image = await tester.runAsync(() => layer.toImage(view.paintBounds));
  final data = (await tester.runAsync(() => image!.toByteData()))!;
  image!.dispose();
  List<int> rgb(Offset p) {
    final i =
        ((p.dy * _scale).round() * (_view.width * _scale).round() +
            (p.dx * _scale).round()) *
        4;
    return [data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2)];
  }

  return (lens: rgb(_lensRect.center), pill: rgb(_pillPoint));
}

void main() {
  testWidgets('in one BackdropGroup the lens samples the page (spec R1)', (
    tester,
  ) async {
    final (:lens, :pill) = await _sample(tester, grouped: true);
    // The grouped pill drew, so a green lens centre is not just the page
    // showing through a missing pill.
    expect(pill[0], greaterThan(200), reason: 'red pill, got $pill');
    expect(lens[1], greaterThan(200), reason: 'green page, got $lens');
    expect(lens[0], lessThan(60), reason: 'not the red pill, got $lens');
  });

  testWidgets('control: ungrouped, the lens samples the pill', (tester) async {
    final (:lens, :pill) = await _sample(tester, grouped: false);
    expect(pill[0], greaterThan(200), reason: 'red pill, got $pill');
    expect(lens[0], greaterThan(200), reason: 'red pill, got $lens');
  });
}
