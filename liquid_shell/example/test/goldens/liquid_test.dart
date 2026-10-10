@Tags(['liquid_golden'])
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/basic_tabs.dart';
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

  for (final (name, adjust) in <(String, _Adjust)>[
    ('liquid_refraction_0', (t) => t.copyWith(refraction: 0)),
    ('liquid_refraction_2', (t) => t.copyWith(refraction: 2)),
    ('liquid_dispersion_0', (t) => t.copyWith(dispersion: 0)),
  ]) {
    testWidgets(name, (tester) async {
      await liquid(tester, name, _themed(adjust, const BasicTabsCase()));
    });
  }
}
