import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/glass/liquid_optics.dart';

void main() {
  final light = ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC));
  final dark = ColorScheme.fromSeed(
    seedColor: const Color(0xFF3366CC),
    brightness: Brightness.dark,
  );

  group('LiquidGlassTheme.fromColorScheme', () {
    test('light values (spec §5.9)', () {
      final theme = LiquidGlassTheme.fromColorScheme(light);
      expect(theme.tint, light.surface.withValues(alpha: 0.72));
      expect(theme.solid, light.surface);
      expect(theme.border, light.outline.withValues(alpha: 0.28));
      expect(
        theme.rimHighlight,
        const Color(0xFFFFFFFF).withValues(alpha: 0.5),
      );
    });

    test('dark values (spec §5.9)', () {
      final theme = LiquidGlassTheme.fromColorScheme(dark);
      expect(theme.tint, dark.surface.withValues(alpha: 0.90));
      expect(theme.solid, dark.surface);
      expect(theme.border, dark.onSurface.withValues(alpha: 0.18));
      expect(
        theme.rimHighlight,
        const Color(0xFFFFFFFF).withValues(alpha: 0.18),
      );
    });

    test('shared values', () {
      for (final scheme in [light, dark]) {
        final theme = LiquidGlassTheme.fromColorScheme(scheme);
        expect(
          theme.shadow,
          const BoxShadow(
            color: Color(0x24000000),
            offset: Offset(0, 6),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        );
        expect(theme.labelStyle.fontSize, 10);
        expect(theme.labelStyle.height, 1.4);
        expect(theme.labelStyle.fontWeight, FontWeight.w600);
        expect(theme.labelStyle.letterSpacing, 0.4);
        expect(theme.labelStyle.fontFamily, isNull);
        expect(theme.blurSigma, 10);
        expect(theme.borderWidth, 1);
        expect(
          theme.borderRadius,
          const BorderRadius.all(Radius.circular(999)),
        );
      }
    });
  });

  group('LiquidGlassTheme.of', () {
    testWidgets('returns the theme extension when present', (tester) async {
      final custom = LiquidGlassTheme.fromColorScheme(
        light,
      ).copyWith(blurSigma: 4);
      late LiquidGlassTheme found;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: light, extensions: [custom]),
          home: Builder(
            builder: (context) {
              found = LiquidGlassTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(found, custom);
    });

    testWidgets('falls back to the displayed color scheme', (tester) async {
      late LiquidGlassTheme found;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: light),
          darkTheme: ThemeData(colorScheme: dark),
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) {
              found = LiquidGlassTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(found, LiquidGlassTheme.fromColorScheme(dark));
    });
  });

  test('copyWith replaces only the given fields', () {
    final base = LiquidGlassTheme.fromColorScheme(light);
    final copy = base.copyWith(
      tint: const Color(0x11223344),
      blurSigma: 3,
      borderRadius: BorderRadius.zero,
    );
    expect(copy.tint, const Color(0x11223344));
    expect(copy.blurSigma, 3);
    expect(copy.borderRadius, BorderRadius.zero);
    expect(copy.solid, base.solid);
    expect(copy.border, base.border);
    expect(copy.borderWidth, base.borderWidth);
    expect(copy.rimHighlight, base.rimHighlight);
    expect(copy.shadow, base.shadow);
    expect(copy.labelStyle, base.labelStyle);
    expect(base.copyWith(), base);
  });

  test('lerp returns the endpoints and blends between them', () {
    final a = LiquidGlassTheme.fromColorScheme(light);
    final b = LiquidGlassTheme.fromColorScheme(dark).copyWith(blurSigma: 20);
    expect(a.lerp(b, 0), a);
    expect(a.lerp(b, 1), b);
    expect(a.lerp(b, 0.5).blurSigma, 15);
    expect(a.lerp(null, 0.5), a);
  });

  test('== and hashCode compare every field', () {
    final a = LiquidGlassTheme.fromColorScheme(light);
    final b = LiquidGlassTheme.fromColorScheme(light);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(a.copyWith(borderWidth: 2)));
  });

  group('liquid fields (spec §5.6)', () {
    final light = LiquidGlassTheme.fromColorScheme(
      ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC)),
    );
    final dark = LiquidGlassTheme.fromColorScheme(
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF3366CC),
        brightness: Brightness.dark,
      ),
    );

    test('defaults', () {
      // Tuned against iOS 26 native (spec §3.6.1): light enough that the
      // lens shows what it bends.
      expect(light.liquidTint.a, closeTo(0.40, 1e-3));
      expect(dark.liquidTint.a, closeTo(0.45, 1e-3));
      expect(light.refraction, 1);
      expect(light.dispersion, 0.3);
      expect(light.liquidBlurSigma, 2);
      expect(dark.liquidBlurSigma, 2);
    });

    test('copyWith, lerp and equality cover them', () {
      final changed = light.copyWith(
        liquidTint: const Color(0x11223344),
        refraction: 2,
        dispersion: 0,
        liquidBlurSigma: 0,
      );
      expect(changed.liquidTint, const Color(0x11223344));
      expect(changed.refraction, 2);
      expect(changed.dispersion, 0);
      expect(changed.liquidBlurSigma, 0);
      expect(changed, isNot(light));
      expect(light.copyWith(), light);
      expect(light.copyWith().hashCode, light.hashCode);
      final half = light.lerp(changed, 0.5);
      expect(half.refraction, 1.5);
      expect(half.dispersion, closeTo(0.15, 1e-9));
      expect(half.liquidBlurSigma, 1);
    });

    test('LiquidOpticsParams.fromTheme maps the fields', () {
      expect(
        LiquidOpticsParams.fromTheme(light),
        LiquidOpticsParams(
          tint: light.liquidTint,
          rim: light.rimHighlight,
          refraction: 1,
          dispersion: 0.3,
          blurSigma: 2,
        ),
      );
    });
  });
}
