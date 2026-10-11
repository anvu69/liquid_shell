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
    expect(lens.engage, closeTo(1, 0.01));
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

  testWidgets('mid-fade the lens shows at engage, not engage² (spec §7.1)', (
    tester,
  ) async {
    debugTabLensOverride = (f) => f.copyWith(engage: 0.5, refraction: 0.5);
    addTearDown(() => debugTabLensOverride = null);
    await _pump(tester);
    await tester.pump();
    final lens = find.byType(LiquidLens);
    // Whatever fades the lens on its way to the screen.
    var faded = 1.0;
    for (final o in tester.widgetList<Opacity>(
      find.ancestor(of: lens, matching: find.byType(Opacity)),
    )) {
      faded *= o.opacity;
    }
    final shadow = tester.widget<OutsideShadow>(
      find.descendant(of: lens, matching: find.byType(OutsideShadow)),
    );
    expect(
      faded * shadow.shadow.color.a / kLensShadow.color.a,
      closeTo(0.5, 1e-3),
    );
    final rim = tester
        .renderObject<RenderLiquidBackdrop>(
          find.descendant(of: lens, matching: find.byType(LiquidBackdrop)),
        )
        .debugUniforms![19];
    expect(faded * rim, closeTo(0.35 * 0.5, 1e-3));
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
