@Tags(['liquid_golden'])
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/basic_tabs.dart';
import 'package:liquid_shell_example/cases/custom_theme.dart';
import 'package:liquid_shell_example/cases/forced_tier.dart';
import 'package:liquid_shell_example/cases/sidebar_slots.dart';

import '../support/golden_harness.dart';

/// Changes one field of the default glass theme.
typedef _Adjust = LiquidGlassTheme Function(LiquidGlassTheme theme);

/// [child] under a theme whose glass is [adjust]ed.
Widget _themed(_Adjust adjust, Widget child) => Builder(
  builder: (context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        extensions: [
          adjust(LiquidGlassTheme.fromColorScheme(theme.colorScheme)),
        ],
      ),
      child: child,
    );
  },
);

/// Margin around the glass in a chrome-band image, in logical pixels.
const _bandMargin = 8.0;

/// The chrome band: every liquid surface on screen plus [_bandMargin].
Rect _chromeBand(WidgetTester tester) {
  Rect? band;
  for (final element
      in find
          .byWidgetPredicate(
            (w) => w.runtimeType.toString() == 'LiquidBackdrop',
          )
          .evaluate()) {
    final box = element.renderObject! as RenderBox;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    band = band?.expandToInclude(rect) ?? rect;
  }
  expect(band, isNotNull, reason: 'no liquid glass on screen');
  final screen = Offset.zero & tester.view.physicalSize / goldenPixelRatio;
  return band!.inflate(_bandMargin).intersect(screen);
}

/// Compares only the chrome band with `bands/<name>.png`, so the 0.5 %
/// tolerance (Q12) is a share of the glass, not of the whole screen: a
/// change to the lens, the rim or the dispersion fails it.
Future<void> _expectBand(WidgetTester tester, String name) async {
  final band = _chromeBand(tester);
  final source = Rect.fromLTRB(
    (band.left * goldenPixelRatio).floorToDouble(),
    (band.top * goldenPixelRatio).floorToDouble(),
    (band.right * goldenPixelRatio).ceilToDouble(),
    (band.bottom * goldenPixelRatio).ceilToDouble(),
  );
  final cropped = await tester.runAsync(() async {
    final screen = await captureImage(tester.element(find.byType(MaterialApp)));
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      screen,
      source,
      Offset.zero & source.size,
      Paint(),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      source.width.toInt(),
      source.height.toInt(),
    );
    picture.dispose();
    screen.dispose();
    return image;
  });
  await expectLater(cropped, matchesGoldenFile('bands/$name.png'));
}

void main() {
  setUp(() {
    // These goldens are the liquid tier; a run without Impeller is a
    // misconfiguration, not a frosted image to record.
    expect(ui.ImageFilter.isShaderFilterSupported, isTrue);
  });

  Future<void> liquid(
    WidgetTester tester,
    String name,
    Widget child, {
    GoldenDevice device = iphone,
    Brightness brightness = Brightness.light,
  }) async {
    await tester.runAsync(LiquidGlass.precache);
    await pumpGolden(tester, child, device: device, brightness: brightness);
    await expectDocImage(tester, name);
  }

  for (final device in [iphone, ipadLandscape, android]) {
    for (final brightness in Brightness.values) {
      final name = 'liquid_hero_${device.name}_${brightness.name}';
      testWidgets(name, (tester) async {
        await liquid(
          tester,
          name,
          const SidebarSlotsCase(),
          device: device,
          brightness: brightness,
        );
      });
    }
  }

  testWidgets('case_tier_liquid', (tester) async {
    await liquid(
      tester,
      'case_tier_liquid',
      const ForcedTierCase(initialTier: LiquidGlassTier.liquid),
    );
  });

  // The brand theme on the default tier: its liquidTint must show.
  testWidgets('case_custom_theme_liquid', (tester) async {
    await liquid(tester, 'case_custom_theme_liquid', const CustomThemeCase());
  });

  // BasicTabs on an iPhone, one theme field changed at a time: the doc
  // image of each, and its chrome band as the regression check.
  for (final (name, adjust, brightness) in <(String, _Adjust, Brightness)>[
    ('liquid_default', (t) => t, Brightness.light),
    ('liquid_default_dark', (t) => t, Brightness.dark),
    ('liquid_refraction_0', (t) => t.copyWith(refraction: 0), Brightness.light),
    ('liquid_refraction_2', (t) => t.copyWith(refraction: 2), Brightness.light),
    ('liquid_dispersion_0', (t) => t.copyWith(dispersion: 0), Brightness.light),
  ]) {
    testWidgets(name, (tester) async {
      await liquid(
        tester,
        name,
        _themed(adjust, const BasicTabsCase()),
        brightness: brightness,
      );
      await _expectBand(tester, name);
    });
  }
}
