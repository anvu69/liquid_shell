import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/glass/drift_guard.dart';
import 'package:liquid_shell/src/glass/liquid_backdrop.dart';
import 'package:liquid_shell/src/glass/liquid_optics.dart';

const _params = LiquidOpticsParams(
  tint: Color(0x38FFFFFF),
  rim: Color(0x80FFFFFF),
  refraction: 1,
  dispersion: 0.3,
  blurSigma: 3,
);

late ui.FragmentProgram _program;
final _built = <double>[];

Future<void> _setUp(WidgetTester tester, {double ratio = 3}) async {
  _program = (await tester.runAsync(
    () => ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag'),
  ))!;
  _built.clear();
  debugLiquidFilterFactory = (shader, sigma) {
    _built.add(sigma);
    return ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
  };
  addTearDown(() => debugLiquidFilterFactory = null);
  tester.view
    ..devicePixelRatio = ratio
    ..physicalSize = const Size(400, 800) * ratio;
  addTearDown(tester.view.reset);
}

Widget _glass({LiquidOpticsParams params = _params}) => SizedBox(
  width: 200,
  height: 60,
  child: LiquidBackdrop(
    program: _program,
    borderRadius: BorderRadius.circular(30),
    params: params,
  ),
);

RenderLiquidBackdrop _render(WidgetTester tester) =>
    tester.renderObject<RenderLiquidBackdrop>(find.byType(LiquidBackdrop));

void _expectInPlace(WidgetTester tester) {
  final render = _render(tester);
  expect(render.debugPaintedRect, render.passGeometry().rect);
}

void main() {
  testWidgets('paints the uniforms of its rect at the view pixel ratio', (
    tester,
  ) async {
    await _setUp(tester);
    await tester.pumpWidget(Center(child: _glass()));

    final render = _render(tester);
    // 200x60 centred in 400x800, times 3.
    const rect = Rect.fromLTWH(300, 1110, 600, 180);
    expect(render.debugPaintedRect, rect);
    expect(
      render.debugUniforms,
      liquidUniforms(
        rect: rect,
        radii: BorderRadius.circular(30),
        params: _params,
        scale: 3,
        pass: const Size(1200, 2400),
      ),
    );
    expect(render.layer, isA<BackdropFilterLayer>());
    expect(render.layer!.filter, ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3));
    expect(_built, [3]);
  });

  testWidgets('builds a new filter only when the uniforms change', (
    tester,
  ) async {
    await _setUp(tester);
    await tester.pumpWidget(Center(child: _glass()));
    _render(tester).markNeedsPaint();
    await tester.pump();
    expect(_built, hasLength(1));

    await tester.pumpWidget(
      Center(
        child: _glass(
          params: const LiquidOpticsParams(
            tint: Color(0x38FFFFFF),
            rim: Color(0x80FFFFFF),
            refraction: 1,
            dispersion: 0.3,
            blurSigma: 5,
          ),
        ),
      ),
    );
    expect(_built, [3, 5]);
  });

  testWidgets('shares the nearest BackdropGroup', (tester) async {
    await _setUp(tester);
    final group = BackdropGroup(child: Center(child: _glass()));
    await tester.pumpWidget(group);
    expect(_render(tester).layer!.backdropKey, group.backdropKey);
  });

  testWidgets('follows a route transition in the same frame', (tester) async {
    await _setUp(tester);
    await tester.pumpWidget(const CupertinoApp(home: SizedBox.expand()));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator
        .push(CupertinoPageRoute<void>(builder: (_) => Center(child: _glass())))
        .ignore();
    await tester.pump(); // built offstage first
    await tester.pump(const Duration(milliseconds: 16)); // first painted
    final start = _render(tester).debugPaintedRect!;
    await tester.pump(const Duration(milliseconds: 16)); // moved
    _expectInPlace(tester);
    expect(_render(tester).debugPaintedRect!.left, lessThan(start.left));
  });

  testWidgets('follows scrolling in the same frame', (tester) async {
    await _setUp(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ListView(
          controller: controller,
          children: [
            const SizedBox(height: 300),
            Center(child: _glass()),
            const SizedBox(height: 2000),
          ],
        ),
      ),
    );
    final before = _render(tester).debugPaintedRect!;
    controller.jumpTo(50);
    await tester.pump();
    _expectInPlace(tester);
    expect(_render(tester).debugPaintedRect!.top, before.top - 150);
  });

  testWidgets('the drift guard corrects a layer-only move one frame later', (
    tester,
  ) async {
    await _setUp(tester);
    final offset = ValueNotifier(Offset.zero);
    addTearDown(offset.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<Offset>(
        valueListenable: offset,
        builder: (_, value, child) =>
            Transform.translate(offset: value, child: child),
        child: RepaintBoundary(child: Center(child: _glass())),
      ),
    );
    offset.value = const Offset(0, 40);
    await tester.pump();
    final render = _render(tester);
    // The RepaintBoundary layer moved; the lens did not repaint yet.
    expect(render.debugPaintedRect, isNot(render.passGeometry().rect));
    await tester.pump();
    _expectInPlace(tester);
  });

  testWidgets('one throwing check does not stop the drift guard', (
    tester,
  ) async {
    await _setUp(tester);
    final offset = ValueNotifier(Offset.zero);
    addTearDown(offset.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<Offset>(
        valueListenable: offset,
        builder: (_, value, child) =>
            Transform.translate(offset: value, child: child),
        child: RepaintBoundary(child: Center(child: _glass())),
      ),
    );
    final throwing = _ThrowingBackdrop();
    LiquidDriftGuard.instance.add(throwing);
    addTearDown(() => LiquidDriftGuard.instance.remove(throwing));
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(tester.takeException(), isA<StateError>());
    LiquidDriftGuard.instance.remove(throwing);

    offset.value = const Offset(0, 40);
    await tester.pump();
    await tester.pump();
    _expectInPlace(tester);
  });

  testWidgets('registers with the drift guard while attached', (tester) async {
    await _setUp(tester);
    final before = LiquidDriftGuard.instance.debugCount;
    await tester.pumpWidget(Center(child: _glass()));
    expect(LiquidDriftGuard.instance.debugCount, before + 1);
    await tester.pumpWidget(const SizedBox());
    expect(LiquidDriftGuard.instance.debugCount, before);
  });

  testWidgets('scale 1 views keep logical pixels', (tester) async {
    await _setUp(tester, ratio: 1);
    await tester.pumpWidget(Center(child: _glass()));
    expect(
      _render(tester).debugPaintedRect,
      const Rect.fromLTWH(100, 370, 200, 60),
    );
  });
}

/// A backdrop whose drift check throws, standing in for a bug in one entry.
class _ThrowingBackdrop extends RenderLiquidBackdrop {
  _ThrowingBackdrop()
    : super(
        program: _program,
        borderRadius: BorderRadius.zero,
        params: _params,
      );

  @override
  void checkDrift() => throw StateError('drift check failed');
}
