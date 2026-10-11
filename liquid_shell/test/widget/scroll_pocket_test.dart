// liquid_shell/test/widget/scroll_pocket_test.dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/chrome/glass_tab_bar.dart';
import 'package:liquid_shell/src/glass/liquid_backdrop.dart';
import 'package:liquid_shell/src/glass/scroll_pocket.dart';

import '../helpers/fake_signals_platform.dart';
import '../helpers/shell_harness.dart';

Future<void> _liquid(WidgetTester tester) async {
  debugLiquidGlassCanRefractOverride = true;
  debugLiquidFilterFactory = (shader, sigma) =>
      ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1);
  addTearDown(() => debugLiquidFilterFactory = null);
  await tester.runAsync(LiquidGlass.precache);
}

Finder get _bands => find.descendant(
  of: find.byKey(kScrollPocketKey),
  matching: find.byType(BackdropFilter),
);

void main() {
  testWidgets('liquid bottom bar: three blur bands over the bottom 148', (
    tester,
  ) async {
    await _liquid(tester);
    await pumpShell(tester, const TestShell());
    expect(_bands, findsNWidgets(3));
    final rect = tester.getRect(find.byKey(kScrollPocketKey));
    expect(rect.height, kScrollPocketExtent);
    expect(rect.bottom, kPhone.height);
    final sigmas = tester
        .widgetList<BackdropFilter>(_bands)
        .map((b) => b.filter.toString())
        .toList();
    expect(
      sigmas.join(),
      allOf(contains('0.5'), contains('1.0'), contains('1.6')),
    );
  });

  testWidgets('frosted: no pocket', (tester) async {
    debugLiquidGlassCanRefractOverride = false;
    await pumpShell(tester, const TestShell());
    expect(_bands, findsNothing);
  });

  testWidgets('reduce transparency: the pocket goes away', (tester) async {
    final platform = installFakeSignals();
    await _liquid(tester);
    await pumpShell(tester, const TestShell());
    expect(_bands, findsNWidgets(3));

    platform.emit(const LiquidPlatformSignals(reduceTransparency: true));
    await tester.pumpAndSettle();
    expect(_bands, findsNothing);
  });

  testWidgets('top bar: no pocket', (tester) async {
    await _liquid(tester);
    await pumpShell(tester, const TestShell(), size: kTabletPortrait);
    expect(find.byKey(kScrollPocketKey), findsNothing);
  });

  testWidgets('it never takes touches', (tester) async {
    await _liquid(tester);
    await pumpShell(tester, const TestShell());
    expect(
      find.ancestor(
        of: _bands.first,
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );
  });

  testWidgets('the pill and the pocket share one backdrop key', (
    tester,
  ) async {
    await _liquid(tester);
    await pumpShell(tester, const TestShell());
    final pill = tester
        .renderObjectList<RenderLiquidBackdrop>(find.byType(LiquidBackdrop))
        .first;
    expect(pill.backdropKey, isNotNull);
    final bands = _bands.evaluate().map(
      (e) => (e.renderObject! as RenderBackdropFilter).backdropKey,
    );
    // One backdrop read for the whole chrome (R1): a band in a group of
    // its own would get a fresh key and a second read.
    expect(bands, hasLength(3));
    expect(bands, everyElement(same(pill.backdropKey)));
  });

  testWidgets('landscape phone: the pocket follows the 44 pt bar', (
    tester,
  ) async {
    await _liquid(tester);
    await pumpShell(tester, const TestShell(), size: kPhoneLandscape);
    expect(_bands, findsNWidgets(3));
    final rect = tester.getRect(find.byKey(kScrollPocketKey));
    expect(rect.height, closeTo(148 * 44 / 62, 1e-9));
    expect(rect.bottom, kPhoneLandscape.height);
  });

  testWidgets('the pocket stays under the minimized bar', (tester) async {
    await _liquid(tester);
    await pumpShell(tester, const TestShell());
    await tester.drag(
      find.byKey(const ValueKey('list-Home')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(kTabPillKey)), const Size(48, 48));
    expect(_bands, findsNWidgets(3));
    expect(
      tester.getRect(find.byKey(kScrollPocketKey)).height,
      kScrollPocketExtent,
    );
  });
}
