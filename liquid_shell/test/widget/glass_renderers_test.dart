import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/glass/frosted_renderer.dart';
import 'package:liquid_shell/src/glass/outside_shadow.dart';
import 'package:liquid_shell/src/glass/solid_renderer.dart';

final _scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC));
final _theme = LiquidGlassTheme.fromColorScheme(_scheme);

Widget _host(LiquidGlassRenderer renderer, {bool grouped = false}) {
  final background = Builder(
    builder: (context) => renderer.buildBackground(
      context,
      LiquidGlassSpec(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        theme: _theme,
      ),
    ),
  );
  return MaterialApp(
    theme: ThemeData(colorScheme: _scheme),
    home: Center(
      child: SizedBox(
        width: 200,
        height: 80,
        child: grouped ? BackdropGroup(child: background) : background,
      ),
    ),
  );
}

void main() {
  group('frosted', () {
    testWidgets('blurs the backdrop with the theme sigma', (tester) async {
      await tester.pumpWidget(_host(const FrostedGlassRenderer()));
      final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
      expect(filter.filter, ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10));
      expect(const FrostedGlassRenderer().tier, LiquidGlassTier.frosted);
    });

    testWidgets('shares the nearest BackdropGroup', (tester) async {
      await tester.pumpWidget(
        _host(const FrostedGlassRenderer(), grouped: true),
      );
      final element = tester.element(find.byType(BackdropFilter));
      final render = tester.renderObject<RenderBackdropFilter>(
        find.byType(BackdropFilter),
      );
      expect(render.backdropKey, isNotNull);
      expect(render.backdropKey, BackdropGroup.of(element)!.backdropKey);
    });

    testWidgets('outside a BackdropGroup it reads the backdrop alone', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const FrostedGlassRenderer()));
      final render = tester.renderObject<RenderBackdropFilter>(
        find.byType(BackdropFilter),
      );
      expect(render.backdropKey, isNull);
    });

    testWidgets('draws tint, border, rim highlight and outside shadow', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const FrostedGlassRenderer()));
      final fills = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.color == _theme.tint);
      expect(fills, hasLength(1));
      expect(fills.single.border, Border.all(color: _theme.border));
      expect(find.byType(OutsideShadow), findsOneWidget);
      expect(find.byKey(FrostedGlassRenderer.rimKey), findsOneWidget);
    });
  });

  group('solid', () {
    testWidgets('has no blur, a solid fill and an outside shadow', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const SolidGlassRenderer()));
      expect(find.byType(BackdropFilter), findsNothing);
      final fills = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.color == _theme.solid);
      expect(fills, hasLength(1));
      expect(find.byType(OutsideShadow), findsOneWidget);
      expect(const SolidGlassRenderer().tier, LiquidGlassTier.solid);
    });
  });

  // The shadow must never show through the translucent tint: inside the
  // shape every pixel is one colour, and the shadow still darkens the area
  // just below the bottom edge. flutter_test paints shadows without blur, so
  // a leak would show as a hard grey band.
  testWidgets('the shadow stays outside the shape (pixel capture)', (
    tester,
  ) async {
    const inset = 32;
    const w = 200;
    const h = 96;
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: _scheme),
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: SizedBox(
                  width: w.toDouble(),
                  height: h.toDouble(),
                  child: Builder(
                    builder: (context) =>
                        const FrostedGlassRenderer().buildBackground(
                          context,
                          LiquidGlassSpec(
                            borderRadius: BorderRadius.circular(20),
                            theme: _theme,
                          ),
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final image = (await tester.runAsync(
      () => captureImage(tester.element(find.byKey(key))),
    ))!;
    final bytes = (await tester.runAsync(image.toByteData))!;
    int red(int x, int y) => bytes.getUint8((y * image.width + x) * 4);

    const x = inset + w ~/ 2;
    // Skip 2px at each edge: the 1px border and the rim highlight.
    final inside = [for (var y = inset + 2; y < inset + h - 2; y++) red(x, y)];
    expect(
      inside.reduce((a, b) => a < b ? a : b),
      greaterThanOrEqualTo(248),
      reason: 'the inside of the glass is one colour: no shadow shows through',
    );
    final below = [
      for (var y = inset + h + 1; y < inset + h + 12; y++) red(x, y),
    ];
    expect(
      below.reduce((a, b) => a < b ? a : b),
      lessThan(250),
      reason: 'the shadow is still drawn outside the bottom edge',
    );
  });
}
