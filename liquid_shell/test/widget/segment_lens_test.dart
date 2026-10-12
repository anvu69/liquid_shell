// The segment lens on screen (spec VK-550 §7): the liquid pass while
// engaged, its own backdrop group, the tier variants and the trace hook.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/glass/liquid_backdrop.dart';
import 'package:liquid_shell/src/glass/liquid_lens.dart';
import 'package:liquid_shell/src/segmented/segmented_control.dart';

import '../helpers/native_rows.dart';

const _frame = Duration(microseconds: 16667);

/// The liquid tier with a stand-in filter (as lens_layer_test.dart).
Future<void> _liquid(WidgetTester tester) async {
  debugLiquidGlassCanRefractOverride = true;
  debugLiquidFilterFactory = (shader, sigma) =>
      ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1);
  addTearDown(() {
    debugLiquidFilterFactory = null;
    debugLiquidGlassCanRefractOverride = null;
  });
  await tester.runAsync(LiquidGlass.precache);
}

/// [outer]: an enclosing BackdropGroup, as a shell page has.
Future<void> _pump(
  WidgetTester tester, {
  LiquidGlassTier? forced,
  BackdropKey? outer,
  ValueChanged<int>? onChanged,
  int selected = 0,
}) async {
  tester.view
    ..devicePixelRatio = 3
    ..physicalSize = const Size(402, 874) * 3;
  addTearDown(tester.view.reset);
  final control = Center(
    child: SizedBox(
      width: 370,
      child: LiquidSegmentedControl(
        segments: const [
          LiquidSegment(label: 'All'),
          LiquidSegment(label: 'Songs'),
          LiquidSegment(label: 'Places'),
        ],
        selectedIndex: selected,
        onChanged: onChanged ?? (_) {},
      ),
    ),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: LiquidGlassScope(
        policy: LiquidGlassPolicy(forcedTier: forced),
        child: outer == null
            ? control
            : BackdropGroup(backdropKey: outer, child: control),
      ),
    ),
  );
}

Offset _at(WidgetTester tester, int i) {
  final box = tester.getRect(find.byType(LiquidSegmentedControl));
  return Offset(box.left + box.width * (i + 0.5) / 3, box.center.dy);
}

/// Holds a press on the selected segment until the lens is engaged.
Future<TestGesture> _hold(WidgetTester tester) async {
  final g = await tester.startGesture(_at(tester, 0));
  await tester.pump();
  for (var i = 0; i < 20; i++) {
    await tester.pump(_frame);
  }
  return g;
}

void main() {
  final ref = segmentReference();

  testWidgets('LiquidLens exists only while engaged, with bezel 9', (
    tester,
  ) async {
    await _liquid(tester);
    await _pump(tester);
    await tester.pump();
    expect(find.byType(LiquidLens), findsNothing, reason: 'at rest');
    final g = await _hold(tester);
    final lens = tester.widget<LiquidLens>(find.byType(LiquidLens));
    expect(lens.engage, closeTo(1, 0.05));
    // Spec §7: 9 pt, inside native's measured ring (lens.bezelEdges).
    final edges = (ref['lens'] as Map)['bezelEdges'] as Map;
    expect(lens.bezel, 9);
    expect(lens.bezel, inInclusiveRange(edges['top'] as num, 9.0));
    expect(lens.restFill, isNotNull);
    expect(find.byType(LiquidBackdrop), findsOneWidget);
    // The w500 copy is clipped to the lens.
    final clip = tester.widget<ClipPath>(find.byKey(kSegmentSelectedKey));
    final lensRect = tester.getRect(find.byType(LiquidLens));
    final clipRect = clip.clipper!
        .getClip(tester.getSize(find.byKey(kSegmentSelectedKey)))
        .getBounds()
        .shift(tester.getTopLeft(find.byKey(kSegmentSelectedKey)));
    expect(clipRect.center.dx, closeTo(lensRect.center.dx, 0.01));
    expect(clipRect.size.width, closeTo(lensRect.width, 0.01));
    await g.up();
    await tester.pumpAndSettle();
    expect(find.byType(LiquidLens), findsNothing);
  });

  testWidgets("it shares the control's own BackdropGroup key", (
    tester,
  ) async {
    await _liquid(tester);
    final outer = BackdropKey();
    await _pump(tester, outer: outer);
    var g = await _hold(tester);
    BackdropKey? keyOf() => tester
        .renderObject<RenderLiquidBackdrop>(find.byType(LiquidBackdrop))
        .backdropKey;
    final first = keyOf();
    expect(first, isNotNull);
    expect(first, isNot(same(outer)), reason: 'not the page group');
    await g.up();
    await tester.pumpAndSettle();
    // A second press: the same key, kept for the control's life.
    g = await _hold(tester);
    expect(keyOf(), same(first));
    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('frosted and solid tiers draw their lens variants', (
    tester,
  ) async {
    debugLiquidGlassCanRefractOverride = false;
    addTearDown(() => debugLiquidGlassCanRefractOverride = null);
    await _pump(tester);
    var g = await _hold(tester);
    expect(
      find.descendant(
        of: find.byType(LiquidLens),
        matching: find.byType(BackdropFilter),
      ),
      findsOneWidget,
      reason: 'frosted: a grouped blur',
    );
    expect(find.byType(LiquidBackdrop), findsNothing);
    await g.up();
    await tester.pumpAndSettle();

    await _pump(tester, forced: LiquidGlassTier.solid);
    g = await _hold(tester);
    expect(find.byType(LiquidLens), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LiquidLens),
        matching: find.byType(BackdropFilter),
      ),
      findsNothing,
      reason: 'solid: an opaque capsule',
    );
    await g.up();
    await tester.pumpAndSettle();
  });

  testWidgets('debugSegmentTrace reports one sample per tick with the lens '
      'size', (tester) async {
    final samples = <Map<String, double>>[];
    debugSegmentTrace = samples.add;
    addTearDown(() => debugSegmentTrace = null);
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 370,
            child: StatefulBuilder(
              builder: (context, setState) => LiquidSegmentedControl(
                segments: const [
                  LiquidSegment(label: 'All'),
                  LiquidSegment(label: 'Songs'),
                  LiquidSegment(label: 'Places'),
                ],
                selectedIndex: selected,
                onChanged: (i) => setState(() => selected = i),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(_at(tester, 1));
    var ticks = 0;
    await tester.pump();
    ticks++;
    while (tester.binding.hasScheduledFrame) {
      await tester.pump(_frame);
      ticks++;
    }
    expect(samples, hasLength(ticks), reason: 'one sample per tick');
    expect(
      samples.first.keys,
      containsAll(<String>['t', 'x', 'y', 'w', 'h', 'engage']),
    );
    for (var i = 1; i < samples.length; i++) {
      expect(samples[i]['t'], greaterThan(samples[i - 1]['t']!));
    }
    // Global: the last sample sits on segment 1, at the rest thumb's size.
    final thumb = tester.getRect(find.byKey(kSegmentThumbKey));
    expect(samples.last['x'], closeTo(_at(tester, 1).dx, 0.5));
    expect(samples.last['y'], closeTo(thumb.center.dy, 0.01));
    final native = (ref['geometry'] as Map)['thumbs3'] as List;
    expect(
      samples.last['w'],
      closeTo((native[1] as List)[2] as num, 1),
    );
    expect(samples.last['h'], (native[1] as List)[3]);
    expect(samples.last['engage'], 0);
  });

  testWidgets('debugSegmentLensPress draws the lens pressed and shifted', (
    tester,
  ) async {
    await _liquid(tester);
    debugSegmentLensPress = 10;
    addTearDown(() => debugSegmentLensPress = null);
    await _pump(tester);
    await tester.pump();
    final grow = ((ref['geometry'] as Map)['pressedGrow'] as List).cast<num>();
    final thumbs = ((ref['geometry'] as Map)['thumbs3'] as List)
        .cast<List<dynamic>>();
    final lens = tester.getRect(find.byType(LiquidLens));
    expect(lens.center.dx, closeTo(_at(tester, 0).dx + 10, 1));
    expect(lens.width, closeTo((thumbs[0][2] as num) + grow[0], 1));
    expect(lens.height, closeTo((thumbs[0][3] as num) + grow[1], 1e-9));
    expect(tester.widget<LiquidLens>(find.byType(LiquidLens)).engage, 1);
  });
}
