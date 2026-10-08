@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/badges.dart';
import 'package:liquid_shell_example/cases/basic_tabs.dart';
import 'package:liquid_shell_example/cases/custom_chrome.dart';
import 'package:liquid_shell_example/cases/custom_theme.dart';
import 'package:liquid_shell_example/cases/discard_guard.dart';
import 'package:liquid_shell_example/cases/forced_tier.dart';
import 'package:liquid_shell_example/cases/hide_chrome.dart';
import 'package:liquid_shell_example/cases/narrow_width.dart';
import 'package:liquid_shell_example/cases/sidebar_only.dart';
import 'package:liquid_shell_example/cases/sidebar_slots.dart';
import 'package:liquid_shell_example/cases/standalone_widgets.dart';
import 'package:liquid_shell_example/cases/trailing_action.dart';

import '../support/golden_harness.dart';

/// One doc image per README case (spec §10.3).
void main() {
  Future<void> golden(
    WidgetTester tester,
    String name,
    Widget page, {
    GoldenDevice device = iphone,
    Future<void> Function()? interact,
  }) async {
    await pumpGolden(tester, page, device: device);
    if (interact != null) {
      await interact();
      await tester.pumpAndSettle();
    }
    await expectLater(find.byType(MaterialApp), matchesDocImage(name));
  }

  testWidgets('case_basic', (tester) async {
    await golden(tester, 'case_basic', const BasicTabsCase());
  });

  testWidgets('case_badges', (tester) async {
    await golden(tester, 'case_badges', const BadgesCase());
  });

  testWidgets('case_sidebar_only', (tester) async {
    await golden(
      tester,
      'case_sidebar_only',
      const SidebarOnlyCase(),
      device: ipadLandscape,
      interact: () => tester.tap(find.text('Reports')),
    );
  });

  testWidgets('case_sidebar_slots', (tester) async {
    await golden(
      tester,
      'case_sidebar_slots',
      const SidebarSlotsCase(),
      device: ipadLandscape,
    );
  });

  testWidgets('case_trailing', (tester) async {
    await golden(tester, 'case_trailing', const TrailingActionCase());
  });

  testWidgets('case_guard', (tester) async {
    await golden(
      tester,
      'case_guard',
      const DiscardGuardCase(),
      interact: () => tester.tap(find.text('Explore')),
    );
  });

  // The detail page inside the branch: no chrome at all.
  testWidgets('case_hide_chrome', (tester) async {
    await golden(
      tester,
      'case_hide_chrome',
      const HideChromeCase(),
      interact: () => tester.tap(find.text('Open a full-frame detail page')),
    );
  });

  // The search page pushed above the shell: LiquidNoChrome.
  testWidgets('case_no_chrome', (tester) async {
    await golden(
      tester,
      'case_no_chrome',
      const TrailingActionCase(),
      interact: () => tester.tap(find.byTooltip('Search')),
    );
  });

  testWidgets('case_custom_chrome', (tester) async {
    await golden(tester, 'case_custom_chrome', const CustomChromeCase());
  });

  testWidgets('case_custom_theme', (tester) async {
    await golden(tester, 'case_custom_theme', const CustomThemeCase());
  });

  testWidgets('case_tier_frosted', (tester) async {
    await golden(tester, 'case_tier_frosted', const ForcedTierCase());
  });

  testWidgets('case_tier_solid', (tester) async {
    await golden(
      tester,
      'case_tier_solid',
      const ForcedTierCase(initialTier: LiquidGlassTier.solid),
    );
  });

  // A 320pt shell inside the iPhone window: 5 tabs + trailing with the
  // narrow margins (Q17).
  testWidgets('case_narrow', (tester) async {
    await golden(tester, 'case_narrow', const NarrowWidthCase());
  });

  // LiquidTabBar and LiquidSidebar in the app's own Scaffold, no shell.
  testWidgets('case_standalone_tab_bar', (tester) async {
    await golden(
      tester,
      'case_standalone_tab_bar',
      const StandaloneWidgetsCase(),
    );
  });

  testWidgets('case_standalone_sidebar', (tester) async {
    await golden(
      tester,
      'case_standalone_sidebar',
      const StandaloneWidgetsCase(),
      device: ipadLandscape,
    );
  });
}
