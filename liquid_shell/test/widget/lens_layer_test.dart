import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/glass/liquid_backdrop.dart';
import 'package:liquid_shell/src/glass/liquid_lens.dart';
import 'package:liquid_shell/src/glass/outside_shadow.dart';
import 'package:liquid_shell/src/glass/shader_program.dart';

/// The blur sigma the last liquid filter was built with.
double? _sigma;

Future<void> _liquid(WidgetTester tester) async {
  debugLiquidGlassCanRefractOverride = true;
  debugLiquidFilterFactory = (shader, sigma) {
    _sigma = sigma;
    return ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1);
  };
  addTearDown(() => debugLiquidFilterFactory = null);
  await tester.runAsync(LiquidGlass.precache);
}

Widget _lens({
  double refraction = 1,
  Brightness brightness = Brightness.light,
  LiquidGlassTier? forced,
  bool highContrast = false,
  ValueSetter<BackdropKey?>? onKey,
}) => MaterialApp(
  theme: ThemeData(brightness: brightness),
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
                child: LiquidLens(refraction: refraction),
              ),
            );
          },
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('liquid: milky glass, bezel 14 pt, σ 2, 1 pt rim, shared '
      'backdrop (spec §7.2)', (
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
    expect(u[8], closeTo(14 * 3, 1e-3)); // bezel 14 pt
    expect(u[9], closeTo(48 * 1.6 * 3, 1e-3)); // thickness
    expect(u[11], closeTo(0.6, 1e-6)); // dispersion
    expect([u[12], u[13], u[14]], [1, 1, 1]); // tint: white…
    expect(u[15], closeTo(0.90, 1e-6)); // …at 0.90
    expect(u[19], closeTo(0.35, 1e-3)); // rim alpha
    expect(u[22], closeTo(3, 1e-6)); // rim width 1 pt
    expect(_sigma, 2); // blur σ 2 pt before the shader
  });

  testWidgets('dark: the veil is native-fitted #414141 at 0.90 (Task 16 '
      'part B: native core 61 luma; surface made a near-black disc)', (
    tester,
  ) async {
    await _liquid(tester);
    await tester.pumpWidget(_lens(brightness: Brightness.dark));
    await tester.pump();
    final u = tester
        .renderObject<RenderLiquidBackdrop>(find.byType(LiquidBackdrop))
        .debugUniforms!;
    expect(u[12], closeTo(kLensVeilDark.r, 1e-6));
    expect(u[13], closeTo(kLensVeilDark.g, 1e-6));
    expect(u[14], closeTo(kLensVeilDark.b, 1e-6));
    expect(u[15], closeTo(0.90, 1e-6));
  });

  testWidgets('the engaged liquid lens thins its veil toward the rim; the '
      'pill does not (Task 16 part B)', (tester) async {
    await _liquid(tester);
    await tester.pumpWidget(_lens());
    await tester.pump();
    final u = tester
        .renderObject<RenderLiquidBackdrop>(find.byType(LiquidBackdrop))
        .debugUniforms!;
    expect(u[24], 1); // shader float 26: the veil falloff
  });

  testWidgets('refraction 0.5 halves thickness and dispersion; the rim '
      'stays', (tester) async {
    await _liquid(tester);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_lens(refraction: 0.5));
    await tester.pump();
    final u = tester
        .renderObject<RenderLiquidBackdrop>(find.byType(LiquidBackdrop))
        .debugUniforms!;
    expect(u[9], closeTo(48 * 0.8 * 3, 1e-3));
    expect(u[11], closeTo(0.3, 1e-6));
    expect(u[19], closeTo(0.35, 1e-3));
  });

  testWidgets('a lone lens loads the shader itself, then turns liquid', (
    tester,
  ) async {
    debugLiquidGlassCanRefractOverride = true;
    debugLiquidFilterFactory = (shader, sigma) =>
        ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1);
    addTearDown(() => debugLiquidFilterFactory = null);
    // No precache and no LiquidGlass: only the lens can start the load.
    await tester.pumpWidget(_lens());
    expect(find.byType(LiquidBackdrop), findsNothing);
    for (var i = 0; i < 40 && LiquidShaderProgram.instance.value == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    await tester.pump();
    expect(find.byType(LiquidBackdrop), findsOneWidget);
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

  testWidgets('frosted: constant fill, rim and shadow (the bar fades the '
      'lens once, spec §7.2)', (tester) async {
    debugLiquidGlassCanRefractOverride = false;
    await tester.pumpWidget(_lens());
    final shadow = tester.widget<OutsideShadow>(find.byType(OutsideShadow));
    expect(shadow.shadow, kLensShadow);
    final deco =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byType(BackdropFilter),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(deco.color!.a, closeTo(0.10, 1e-3));
    expect((deco.border! as Border).top.color.a, closeTo(0.35, 1e-3));
  });
}
