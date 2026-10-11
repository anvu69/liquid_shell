import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/glass/liquid_backdrop.dart';
import 'package:liquid_shell/src/glass/liquid_lens.dart';
import 'package:liquid_shell/src/glass/outside_shadow.dart';

Future<void> _liquid(WidgetTester tester) async {
  debugLiquidGlassCanRefractOverride = true;
  debugLiquidFilterFactory = (shader, sigma) =>
      ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1);
  addTearDown(() => debugLiquidFilterFactory = null);
  await tester.runAsync(LiquidGlass.precache);
}

Widget _lens({
  double engage = 1,
  double refraction = 1,
  LiquidGlassTier? forced,
  bool highContrast = false,
  ValueSetter<BackdropKey?>? onKey,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(highContrast: highContrast),
    child: LiquidGlassScope(
      policy: LiquidGlassPolicy(forcedTier: forced),
      child: BackdropGroup(
        child: Builder(
          builder: (context) {
            onKey?.call(BackdropGroup.of(context)?.backdropKey);
            return Center(
              child: SizedBox(
                width: 110,
                height: 70,
                child: LiquidLens(engage: engage, refraction: refraction),
              ),
            );
          },
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('liquid: clear glass, bezel h/2, 1 pt rim, shared backdrop', (
    tester,
  ) async {
    await _liquid(tester);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    BackdropKey? key;
    await tester.pumpWidget(_lens(onKey: (k) => key = k));
    await tester.pump();
    final render = tester.renderObject<RenderLiquidBackdrop>(
      find.byType(LiquidBackdrop),
    );
    expect(render.backdropKey, isNotNull);
    expect(render.backdropKey, key);
    final u = render.debugUniforms!;
    expect(u[8], closeTo(35 * 3, 1e-3)); // bezel = h/2
    expect(u[9], closeTo(48 * 1.6 * 3, 1e-3)); // thickness
    expect(u[11], closeTo(0.6, 1e-6)); // dispersion
    expect(u[15], 0); // tint alpha: clear glass
    expect(u[19], closeTo(0.35, 1e-3)); // rim alpha
    expect(u[22], closeTo(3, 1e-6)); // rim width 1 pt
  });

  testWidgets('refraction 0.5 halves thickness and dispersion; engage the '
      'rim', (tester) async {
    await _liquid(tester);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_lens(engage: 0.5, refraction: 0.5));
    await tester.pump();
    final u = tester
        .renderObject<RenderLiquidBackdrop>(find.byType(LiquidBackdrop))
        .debugUniforms!;
    expect(u[9], closeTo(48 * 0.8 * 3, 1e-3));
    expect(u[11], closeTo(0.3, 1e-6));
    expect(u[19], closeTo(0.175, 1e-3));
  });

  testWidgets('frosted: a grouped blur, no shader', (tester) async {
    debugLiquidGlassCanRefractOverride = false;
    await tester.pumpWidget(_lens());
    expect(find.byType(LiquidBackdrop), findsNothing);
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('solid: an opaque capsule, bordered under high contrast', (
    tester,
  ) async {
    await tester.pumpWidget(_lens(forced: LiquidGlassTier.solid));
    expect(find.byType(BackdropFilter), findsNothing);
    BoxDecoration deco() => tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((d) => d.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.color != null);
    expect(deco().color!.a, 1);
    expect(deco().border, isNull);
    await tester.pumpWidget(
      _lens(forced: LiquidGlassTier.solid, highContrast: true),
    );
    expect(deco().border, isNotNull);
  });

  testWidgets('the lens shadow fades with engage', (tester) async {
    debugLiquidGlassCanRefractOverride = false;
    await tester.pumpWidget(_lens(engage: 0.5));
    final shadow = tester.widget<OutsideShadow>(find.byType(OutsideShadow));
    expect(shadow.shadow.color.a, closeTo(kLensShadow.color.a * 0.5, 1e-3));
  });
}
