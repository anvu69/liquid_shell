import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/chrome/glass_tab_bar.dart';
import 'package:liquid_shell/src/chrome/tab_geometry.dart';
import 'package:liquid_shell/src/glass/liquid_backdrop.dart';
import 'package:liquid_shell/src/glass/liquid_lens.dart';
import 'package:liquid_shell/src/glass/outside_shadow.dart';

const _screen = Size(402, 874);
const double _y = 874.0 - 21 - 31;
const _three = [
  LiquidDestination(icon: Icon(Icons.home), label: 'Home'),
  LiquidDestination(icon: Icon(Icons.map), label: 'Explore'),
  LiquidDestination(icon: Icon(Icons.settings), label: 'Settings'),
];

/// The bar at the bottom of the screen; [grouped] puts a `BackdropGroup`
/// above it, as the shell does.
Future<void> _pump(WidgetTester tester, {bool grouped = true}) async {
  debugLiquidGlassCanRefractOverride = true;
  debugLiquidFilterFactory = (shader, sigma) =>
      ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1);
  addTearDown(() => debugLiquidFilterFactory = null);
  await tester.runAsync(LiquidGlass.precache);
  tester.view
    ..devicePixelRatio = 3
    ..physicalSize = _screen * 3;
  addTearDown(tester.view.reset);
  final stack = Stack(
    children: [
      Positioned(
        left: TabMetrics.margin,
        right: TabMetrics.margin,
        bottom: 21,
        child: LiquidTabBar(
          destinations: _three,
          selectedIndex: 0,
          onDestinationSelected: (_) {},
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: grouped ? BackdropGroup(child: stack) : stack,
      ),
    ),
  );
}

/// The opacity the lens's glass pass reaches the screen with: the product
/// of every `Opacity` above its `LiquidBackdrop`. The shader writes alpha
/// 1, so this is the only fade the pass gets (spec §7.2).
double _lensPassOpacity(WidgetTester tester) {
  final pass = find.descendant(
    of: find.byType(LiquidLens),
    matching: find.byType(LiquidBackdrop),
  );
  var opacity = 1.0;
  for (final o in tester.widgetList<Opacity>(
    find.ancestor(of: pass, matching: find.byType(Opacity)),
  )) {
    opacity *= o.opacity;
  }
  return opacity;
}

void main() {
  testWidgets('at rest: no lens pass, one backdrop (the pill)', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byType(LiquidLens), findsNothing);
    expect(find.byType(LiquidBackdrop), findsOneWidget);
  });

  testWidgets('held: the lens pass engages, the pill bulges ×1.052', (
    tester,
  ) async {
    await _pump(tester);
    final g = await tester.startGesture(const Offset(115, _y));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final lens = tester.widget<LiquidLens>(find.byType(LiquidLens));
    expect(_lensPassOpacity(tester), closeTo(1, 0.01));
    expect(lens.refraction, closeTo(1, 0.01));
    expect(find.byType(LiquidBackdrop), findsNWidgets(2));
    final lensRect = tester.getRect(find.byType(LiquidLens));
    expect(lensRect.width, closeTo(110 * 1.052, 3));
    expect(lensRect.height, closeTo(70 * 1.052, 3));
    expect(
      tester.getRect(find.byKey(kTabPillKey)).width,
      closeTo(274 * 1.052, 0.5),
    );
    // Both lens backdrops share the shell's group key (spec §7.2).
    final keys = tester
        .renderObjectList<RenderLiquidBackdrop>(find.byType(LiquidBackdrop))
        .map((r) => r.backdropKey)
        .toSet();
    expect(keys, hasLength(1));
    await g.up();
    await tester.pumpAndSettle();
    expect(find.byType(LiquidLens), findsNothing);
    expect(tester.getRect(find.byKey(kTabPillKey)).width, closeTo(274, 0.01));
  });

  testWidgets('a tap: the lens engages in flight and is gone after 0.85 s', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tapAt(const Offset(201, _y));
    // The first frame starts the ticker (elapsed 0, as for any animation).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(LiquidLens), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.byType(LiquidLens), findsNothing);
  });

  testWidgets('debugTabLensOverride freezes an engaged frame', (tester) async {
    debugTabLensOverride = (f) => f.copyWith(engage: 1, refraction: 1);
    addTearDown(() => debugTabLensOverride = null);
    await _pump(tester);
    expect(find.byType(LiquidLens), findsOneWidget);
  });

  testWidgets('debugTabLensPress draws the pressed lens', (tester) async {
    debugTabLensPress = 0;
    addTearDown(() => debugTabLensPress = null);
    await _pump(tester);
    final lens = tester.getRect(find.byType(LiquidLens));
    expect(lens.width, closeTo(110 * 1.052, 1));
  });

  testWidgets('mid-fade the whole lens pass is at engage, once: the rim '
      'and shadow inside stay constant (spec §7.2)', (tester) async {
    debugTabLensOverride = (f) => f.copyWith(engage: 0.5, refraction: 0.5);
    addTearDown(() => debugTabLensOverride = null);
    await _pump(tester);
    await tester.pump();
    expect(_lensPassOpacity(tester), closeTo(0.5, 1e-3));
    final lens = find.byType(LiquidLens);
    final rim = tester
        .renderObject<RenderLiquidBackdrop>(
          find.descendant(of: lens, matching: find.byType(LiquidBackdrop)),
        )
        .debugUniforms![19];
    expect(rim, closeTo(0.35, 1e-3));
    final shadow = tester.widget<OutsideShadow>(
      find.descendant(of: lens, matching: find.byType(OutsideShadow)),
    );
    expect(shadow.shadow, kLensShadow);
  });

  testWidgets('after a tap the lens pass fades out over frames, no snap', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tapAt(const Offset(201, _y));
    final seen = <double>[];
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.byType(LiquidLens).evaluate().isNotEmpty) {
        seen.add(_lensPassOpacity(tester));
      } else if (seen.isNotEmpty) {
        break;
      }
    }
    expect(find.byType(LiquidLens), findsNothing, reason: 'it ended');
    final peak = seen.indexOf(seen.reduce((a, b) => a > b ? a : b));
    final fade = seen.sublist(peak);
    // Several frames between full and gone, each a small step down.
    expect(fade.where((o) => o > 0.05 && o < 0.95).length, greaterThan(3));
    for (var k = 1; k < fade.length; k++) {
      expect(fade[k], lessThanOrEqualTo(fade[k - 1] + 1e-9));
      expect(fade[k - 1] - fade[k], lessThan(0.35), reason: '$fade');
    }
    expect(fade.last, lessThan(0.05), reason: 'the last frame is faint');
  });

  testWidgets('standalone: the bar groups its own backdrops (spec §7.2)', (
    tester,
  ) async {
    debugTabLensOverride = (f) => f.copyWith(engage: 1, refraction: 1);
    addTearDown(() => debugTabLensOverride = null);
    await _pump(tester, grouped: false);
    final keys = tester
        .renderObjectList<RenderLiquidBackdrop>(find.byType(LiquidBackdrop))
        .map((r) => r.backdropKey)
        .toSet();
    expect(find.byType(LiquidBackdrop), findsNWidgets(2));
    expect(keys, hasLength(1));
    expect(keys.single, isNotNull);
  });
}
