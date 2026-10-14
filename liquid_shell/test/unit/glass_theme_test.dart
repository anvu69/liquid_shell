import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/glass/liquid_optics.dart';

/// The liquid tint defaults (VK-503 Task 16): neutral, near-opaque.
final Color _tintLight = const Color(0xFFFFFFFF).withValues(alpha: 0.55);
final Color _tintDark = const Color(0xFF1C1C1C).withValues(alpha: 0.90);

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
        const Color(0xFFFFFFFF).withValues(alpha: 0.12),
      );
    });

    test('dark values (spec §5.9)', () {
      final theme = LiquidGlassTheme.fromColorScheme(dark);
      expect(theme.tint, dark.surface.withValues(alpha: 0.90));
      expect(theme.solid, dark.surface);
      expect(theme.border, dark.onSurface.withValues(alpha: 0.18));
      expect(
        theme.rimHighlight,
        // Native's dark top rim is 54 → 47 → 39 over the #191919 fill
        // (research §5); 0.22 drew 80 (VK-503 Task 16).
        const Color(0xFFFFFFFF).withValues(alpha: 0.12),
      );
    });

    test('shared values', () {
      for (final scheme in [light, dark]) {
        final theme = LiquidGlassTheme.fromColorScheme(scheme);
        expect(
          theme.shadow,
          const BoxShadow(
            color: Color(0x12000000),
            offset: Offset(0, 3),
            blurRadius: 20,
          ),
        );
        expect(theme.labelStyle.fontSize, 10);
        expect(theme.labelStyle.height, 1.2);
        expect(theme.labelStyle.fontWeight, FontWeight.w500);
        expect(theme.labelStyle.letterSpacing, 0);
        expect(theme.labelStyle.fontFamily, isNull);
        expect(theme.tabIconSize, 26);
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
      // Native iOS 26.5 glass is a neutral, near-opaque milky fill, not the
      // scheme's hue (VK-503 Task 16: white @ 0.55, #1C1C1C @ 0.90, fitted
      // to the native pixels in test/impeller/tab_material_test.dart).
      expect(light.liquidTint, _tintLight);
      expect(dark.liquidTint, _tintDark);
      expect(light.refraction, 1);
      expect(light.dispersion, 0);
      expect(light.liquidBlurSigma, 2);
      expect(dark.liquidBlurSigma, 2);
    });

    test('copyWith, lerp and equality cover them', () {
      final changed = light.copyWith(
        liquidTint: const Color(0x11223344),
        refraction: 2,
        dispersion: 0.3,
        liquidBlurSigma: 0,
      );
      expect(changed.liquidTint, const Color(0x11223344));
      expect(changed.refraction, 2);
      expect(changed.dispersion, 0.3);
      expect(changed.liquidBlurSigma, 0);
      expect(changed, isNot(light));
      expect(light.copyWith(), light);
      expect(light.copyWith().hashCode, light.hashCode);
      final half = light.lerp(changed, 0.5);
      expect(half.refraction, 1.5);
      expect(half.dispersion, closeTo(0.15, 1e-9));
      expect(half.liquidBlurSigma, 1);
    });

    group('liquidTint is optional (spec §5.6: every field has a default)', () {
      LiquidGlassTheme bare(Color solid) => LiquidGlassTheme(
        tint: solid.withValues(alpha: 0.72),
        solid: solid,
        border: const Color(0x47000000),
        rimHighlight: const Color(0x80FFFFFF),
        shadow: const BoxShadow(),
        labelStyle: const TextStyle(),
      );

      test('defaults to the light tint over a light solid', () {
        final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC));
        final theme = bare(scheme.surface);
        expect(theme.liquidTint, _tintLight);
        expect(
          theme.liquidTint,
          LiquidGlassTheme.fromColorScheme(scheme).liquidTint,
        );
      });

      test('defaults to the dark tint over a dark solid', () {
        final scheme = ColorScheme.fromSeed(
          seedColor: const Color(0xFF3366CC),
          brightness: Brightness.dark,
        );
        final theme = bare(scheme.surface);
        expect(theme.liquidTint, _tintDark);
        expect(
          theme.liquidTint,
          LiquidGlassTheme.fromColorScheme(scheme).liquidTint,
        );
      });

      test('a derived default follows copyWith(solid:)', () {
        final theme = bare(const Color(0xFFFFFFFF));
        final moved = theme.copyWith(solid: const Color(0xFF000000));
        expect(moved.liquidTint, _tintDark);
      });

      test('an explicit liquidTint survives copyWith(solid:)', () {
        final theme = bare(
          const Color(0xFFFFFFFF),
        ).copyWith(liquidTint: const Color(0x11223344));
        final moved = theme.copyWith(solid: const Color(0xFF000000));
        expect(moved.liquidTint, const Color(0x11223344));
      });

      test('== and hashCode compare the resolved tint', () {
        const white = Color(0xFFFFFFFF);
        final derived = bare(white);
        final explicit = derived.copyWith(
          liquidTint: _tintLight,
        );
        expect(derived, explicit);
        expect(derived.hashCode, explicit.hashCode);
      });
    });

    test('LiquidOpticsParams.fromTheme maps the fields', () {
      expect(
        LiquidOpticsParams.fromTheme(light),
        LiquidOpticsParams(
          tint: light.liquidTint,
          rim: light.rimHighlight,
          refraction: 1,
          dispersion: 0,
          blurSigma: 2,
        ),
      );
    });
  });

  group('tab tokens (spec VK-503 §6.4)', () {
    test('light and dark defaults', () {
      final l = LiquidGlassTheme.fromColorScheme(light);
      final d = LiquidGlassTheme.fromColorScheme(dark);
      expect(l.selectionFill, const Color(0x14000000));
      expect(d.selectionFill, const Color(0x21FFFFFF));
      expect(l.tabForeground, const Color(0xFF191919));
      expect(d.tabForeground, const Color(0xFFF4F4F4));
      expect(l.badgeColor, const Color(0xFFFF383C));
      expect(d.badgeColor, const Color(0xFFFF4245));
    });

    test('constructor defaults', () {
      const t = LiquidGlassTheme(
        tint: Color(0x00000000),
        solid: Color(0xFFFFFFFF),
        border: Color(0x00000000),
        rimHighlight: Color(0x00000000),
        shadow: BoxShadow(),
        labelStyle: TextStyle(),
      );
      expect(t.selectionFill, const Color(0x14000000));
      expect(t.tabForeground, const Color(0xFF191919));
      expect(t.badgeColor, const Color(0xFFFF383C));
      expect(t.tabIconSize, 26);
    });

    test('a directly built theme has no dispersion (Q5)', () {
      const t = LiquidGlassTheme(
        tint: Color(0x00000000),
        solid: Color(0xFFFFFFFF),
        border: Color(0x00000000),
        rimHighlight: Color(0x00000000),
        shadow: BoxShadow(),
        labelStyle: TextStyle(),
      );
      // Native shows a fringe only on the touched lens, which sets its own.
      expect(t.dispersion, 0);
    });

    test('copyWith, lerp, == and hashCode cover them', () {
      final base = LiquidGlassTheme.fromColorScheme(light);
      final other = base.copyWith(
        selectionFill: const Color(0x28000000),
        tabForeground: const Color(0xFF000000),
        badgeColor: const Color(0xFFFF0000),
        tabIconSize: 30,
      );
      expect(other.selectionFill, const Color(0x28000000));
      expect(other.tabForeground, const Color(0xFF000000));
      expect(other.badgeColor, const Color(0xFFFF0000));
      expect(other.tabIconSize, 30);
      expect(other, isNot(base));
      expect(other.hashCode, isNot(base.hashCode));
      final half = base.lerp(other, 0.5);
      expect(half.tabIconSize, 28);
      expect(
        half.selectionFill,
        Color.lerp(
          base.selectionFill,
          other.selectionFill,
          0.5,
        ),
      );
      expect(base.copyWith(), base);
    });
  });

  group('segment tokens (spec VK-550 §6)', () {
    final colors =
        (jsonDecode(
                  File(
                    '../docs/qa/vk550/native_reference.json',
                  ).readAsStringSync(),
                )
                as Map<String, Object?>)['colors']!
            as Map<String, Object?>;
    List<int> rgb(String key) => (colors[key]! as List<Object?>).cast<int>();
    final tolerance = colors['tolerance']! as int;

    void expectRgb(Color c, List<int> native, String what) {
      expect((c.r * 255).round(), closeTo(native[0], tolerance), reason: what);
      expect((c.g * 255).round(), closeTo(native[1], tolerance), reason: what);
      expect((c.b * 255).round(), closeTo(native[2], tolerance), reason: what);
    }

    final light = LiquidGlassTheme.fromColorScheme(
      ColorScheme.fromSeed(seedColor: const Color(0xFF3D5AFE)),
    );
    final dark = LiquidGlassTheme.fromColorScheme(
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF3D5AFE),
        brightness: Brightness.dark,
      ),
    );

    test('light composites match native', () {
      const white = Color(0xFFFFFFFF);
      expectRgb(
        Color.alphaBlend(light.segmentTrack, white),
        rgb('lightTrackOverWhite'),
        'track over white',
      );
      expectRgb(light.segmentThumb, rgb('lightThumb'), 'thumb');
      expectRgb(
        light.segmentLabelStyle.color!,
        rgb('lightLabel'),
        'label',
      );
    });

    test('dark composites match native', () {
      const black = Color(0xFF000000);
      final track = Color.alphaBlend(dark.segmentTrack, black);
      expectRgb(track, rgb('darkTrackOverBlack'), 'track over black');
      expectRgb(
        Color.alphaBlend(dark.segmentThumb, track),
        rgb('darkThumbOverTrack'),
        'thumb over track',
      );
      expectRgb(dark.segmentLabelStyle.color!, rgb('darkLabel'), 'label');
    });

    test('label style is 13 pt regular with the native line height', () {
      for (final t in [light, dark]) {
        expect(t.segmentLabelStyle.fontSize, 13);
        expect(t.segmentLabelStyle.fontWeight, FontWeight.w400);
        expect(t.segmentLabelStyle.height, closeTo(15.67 / 13, 1e-9));
      }
    });

    test('exact spec values', () {
      expect(light.segmentTrack, const Color(0x1F767680));
      expect(light.segmentThumb, const Color(0xFFFFFFFF));
      expect(dark.segmentTrack, const Color(0x3D767680));
      expect(dark.segmentThumb, const Color(0x4DEBEBF5));
    });

    test('copyWith, lerp, == and hashCode carry them', () {
      final a = LiquidGlassTheme.fromColorScheme(const ColorScheme.light());
      final b = a.copyWith(
        segmentTrack: const Color(0xFF00FF00),
        segmentThumb: const Color(0xFF0000FF),
        segmentLabelStyle: const TextStyle(fontSize: 20),
      );
      expect(b.segmentTrack, const Color(0xFF00FF00));
      expect(b.segmentThumb, const Color(0xFF0000FF));
      expect(b.segmentLabelStyle.fontSize, 20);
      expect(b, isNot(a));
      expect(b.hashCode, isNot(a.hashCode));
      expect(a.lerp(b, 1).segmentTrack, b.segmentTrack);
      expect(
        a.lerp(b, 0.5).segmentThumb,
        Color.lerp(a.segmentThumb, b.segmentThumb, 0.5),
      );
      expect(a.lerp(b, 1).segmentLabelStyle.fontSize, 20);
      expect(a.copyWith(), a);
    });
  });
}
