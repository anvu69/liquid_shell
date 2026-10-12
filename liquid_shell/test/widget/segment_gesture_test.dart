// The segmented control's touches, keyboard and motion on screen (spec
// VK-550 §8, §9, §12). Rows compare with the native fixture
// (docs/qa/vk550/native_reference.json), never with our own constants.
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/chrome/large_content_viewer.dart';
import 'package:liquid_shell/src/glass/liquid_lens.dart';
import 'package:liquid_shell/src/segmented/segmented_control.dart';

import '../helpers/native_rows.dart';

const _titles = ['All', 'Songs', 'Places'];

/// One 60 Hz frame, as the fixture's simulator.
const _frame = Duration(microseconds: 16667);

List<LiquidSegment> _segments([List<String> titles = _titles]) => [
  for (final t in titles) LiquidSegment(label: t),
];

/// Owns the selection like an app; [adopt] false ignores every change (a
/// guard that says no). [wrap] puts the control inside something else.
class _Host extends StatefulWidget {
  const _Host({
    required this.log,
    required this.segments,
    this.adopt = true,
    this.wrap,
    super.key,
  });

  final List<int> log;
  final List<LiquidSegment> segments;
  final bool adopt;
  final Widget Function(Widget control)? wrap;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int index = 0;

  void select(int i) => setState(() => index = i);

  @override
  Widget build(BuildContext context) {
    final control = SizedBox(
      width: 370,
      child: LiquidSegmentedControl(
        segments: widget.segments,
        selectedIndex: index,
        onChanged: (i) {
          widget.log.add(i);
          if (widget.adopt) setState(() => index = i);
        },
      ),
    );
    return widget.wrap?.call(control) ?? Center(child: control);
  }
}

Future<GlobalKey<_HostState>> _pump(
  WidgetTester tester,
  List<int> log, {
  List<LiquidSegment>? segments,
  bool adopt = true,
  bool reduceMotion = false,
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
  Widget Function(Widget control)? wrap,
}) async {
  tester.view
    ..devicePixelRatio = 3
    ..physicalSize = const Size(402, 874) * 3;
  addTearDown(tester.view.reset);
  final key = GlobalKey<_HostState>();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduceMotion,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: LiquidGlassScope(
                // No shader here; segment_lens_test.dart runs the liquid tier.
                policy: const LiquidGlassPolicy(
                  forcedTier: LiquidGlassTier.solid,
                ),
                child: _Host(
                  key: key,
                  log: log,
                  segments: segments ?? _segments(),
                  adopt: adopt,
                  wrap: wrap,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return key;
}

Rect _box(WidgetTester tester) =>
    tester.getRect(find.byType(LiquidSegmentedControl));

/// Segment [i]'s centre on screen (LTR: left to right).
Offset _at(WidgetTester tester, int i, {int count = 3}) {
  final box = _box(tester);
  return Offset(box.left + box.width * (i + 0.5) / count, box.center.dy);
}

/// The rest thumb (the lens rect), on screen.
Rect _thumb(WidgetTester tester) =>
    tester.getRect(find.byKey(kSegmentThumbKey));

List<String> _haptics(WidgetTester tester) {
  final calls = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        calls.add(call.arguments as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return calls;
}

/// A slow drag from [from] to [to] in 3 pt steps, one frame each, then a
/// second of holding still, then the release.
Future<void> _slowDrag(WidgetTester tester, Offset from, Offset to) async {
  final g = await tester.startGesture(from);
  final step = (to - from).dx.sign * 3;
  for (var x = from.dx; (to.dx - x) * step > 0; x += step) {
    await g.moveTo(Offset(x, from.dy));
    await tester.pump(_frame);
  }
  await g.moveTo(to);
  for (var i = 0; i < 60; i++) {
    await tester.pump(_frame);
  }
  await g.up();
  await tester.pumpAndSettle();
}

/// The normal row's fade over segment [label] (the press highlight).
double _labelFade(WidgetTester tester, String label) => tester
    .widgetList<FadeTransition>(
      find.ancestor(
        of: find.descendant(
          of: find.byKey(kSegmentNormalKey),
          matching: find.text(label),
        ),
        matching: find.byType(FadeTransition),
      ),
    )
    .fold(1, (a, w) => a * w.opacity.value);

/// Collects [debugSegmentTrace] samples, control-local x.
List<Map<String, double>> _trace() {
  final samples = <Map<String, double>>[];
  debugSegmentTrace = samples.add;
  addTearDown(() => debugSegmentTrace = null);
  return samples;
}

/// The sample nearest [t] seconds on the ticker clock.
Map<String, double> _sampleAt(List<Map<String, double>> samples, double t) =>
    samples.reduce(
      (a, b) => (a['t']! - t).abs() <= (b['t']! - t).abs() ? a : b,
    );

void main() {
  final ref = segmentReference();

  testWidgets('a tap commits on up, not on down', (tester) async {
    final log = <int>[];
    await _pump(tester, log);
    final g = await tester.startGesture(_at(tester, 2));
    await tester.pump(const Duration(milliseconds: 50));
    expect(log, isEmpty);
    await g.up();
    await tester.pump();
    expect(log, [2]);
    await tester.pumpAndSettle();
    expect(_thumb(tester).center.dx, closeTo(_at(tester, 2).dx, 0.5));
  });

  testWidgets('a drag across two segments commits the segment nearest the '
      'lens on release, with one selectionClick per crossing and none on a '
      'tap', (tester) async {
    final log = <int>[];
    final haptics = _haptics(tester);
    await _pump(tester, log);
    await tester.tapAt(_at(tester, 2));
    await tester.pumpAndSettle();
    expect(log, [2]);
    expect(haptics, isEmpty, reason: 'no click on a tap');
    await _slowDrag(tester, _at(tester, 2), _at(tester, 0));
    expect(log, [2, 0]);
    expect(haptics, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.selectionClick',
    ]);
    expect(_thumb(tester).center.dx, closeTo(_at(tester, 0).dx, 0.5));
  });

  testWidgets('a cancel commits nothing', (tester) async {
    final log = <int>[];
    await _pump(tester, log);
    final g = await tester.startGesture(_at(tester, 0));
    await g.moveTo(_at(tester, 2));
    await tester.pump(const Duration(milliseconds: 300));
    await g.cancel();
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    expect(_thumb(tester).center.dx, closeTo(_at(tester, 0).dx, 0.5));
  });

  testWidgets("a refused change returns to the app's index", (tester) async {
    final log = <int>[];
    await _pump(tester, log, adopt: false);
    await tester.tapAt(_at(tester, 2));
    await tester.pumpAndSettle();
    expect(log, [2]);
    expect(_thumb(tester).center.dx, closeTo(_at(tester, 0).dx, 0.5));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a programmatic change slides: the thumb is between the '
      'segments 100 ms later, and onChanged is not called', (tester) async {
    final log = <int>[];
    final key = await _pump(tester, log);
    key.currentState!.select(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final x = _thumb(tester).center.dx;
    expect(x, greaterThan(_at(tester, 0).dx + 1));
    expect(x, lessThan(_at(tester, 1).dx - 1));
    expect(find.byType(LiquidLens), findsNothing, reason: 'no engage');
    await tester.pumpAndSettle();
    expect(_thumb(tester).center.dx, closeTo(_at(tester, 1).dx, 0.5));
    expect(log, isEmpty);
  });

  testWidgets('reduce motion: a tap dissolves (ghost), no lift', (
    tester,
  ) async {
    final log = <int>[];
    await _pump(tester, log, reduceMotion: true);
    final rest = _thumb(tester).size;
    await tester.tapAt(_at(tester, 2));
    await tester.pump();
    expect(log, [2]);
    expect(_thumb(tester).center.dx, closeTo(_at(tester, 2).dx, 0.5));
    final ghost = find.byKey(kSegmentGhostKey);
    expect(ghost, findsOneWidget);
    expect(tester.getRect(ghost).center.dx, closeTo(_at(tester, 0).dx, 0.5));
    for (var i = 0; i < 12; i++) {
      await tester.pump(_frame);
      expect(_thumb(tester).width, closeTo(rest.width, 1e-6));
      expect(
        _thumb(tester).height,
        closeTo(rest.height, 1e-6),
        reason: 'no lift',
      );
      expect(find.byType(LiquidLens), findsNothing, reason: 'no engage');
    }
    expect(ghost, findsNothing);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a semantics tap commits', (tester) async {
    final handle = tester.ensureSemantics();
    final log = <int>[];
    await _pump(tester, log);
    tester.semantics.tap(find.semantics.byLabel('Songs'));
    await tester.pump();
    expect(log, [1]);
    expect(tester.binding.hasScheduledFrame, isTrue, reason: 'it animates');
    await tester.pumpAndSettle();
    expect(_thumb(tester).center.dx, closeTo(_at(tester, 1).dx, 0.5));
    handle.dispose();
  });

  testWidgets('a disabled segment is never committed by a tap or a drag', (
    tester,
  ) async {
    final log = <int>[];
    await _pump(
      tester,
      log,
      segments: const [
        LiquidSegment(label: 'All'),
        LiquidSegment(label: 'Songs'),
        LiquidSegment(label: 'Places', enabled: false),
      ],
    );
    await tester.tapAt(_at(tester, 2));
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    expect(_thumb(tester).center.dx, closeTo(_at(tester, 0).dx, 0.5));
    // The lens may pass over it; the release picks the nearest enabled.
    await _slowDrag(tester, _at(tester, 0), _at(tester, 2));
    expect(log, [1]);
    expect(_thumb(tester).center.dx, closeTo(_at(tester, 1).dx, 0.5));
  });

  testWidgets('the ticker stops at rest', (tester) async {
    await _pump(tester, <int>[]);
    await tester.tapAt(_at(tester, 1));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('disabled mid-press: the lens lets go and the ticker stops', (
    tester,
  ) async {
    final log = <int>[];
    var enabled = true;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 370,
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return LiquidSegmentedControl(
                  segments: _segments(),
                  selectedIndex: 0,
                  onChanged: enabled ? log.add : null,
                );
              },
            ),
          ),
        ),
      ),
    );
    final rest = _thumb(tester);
    final g = await tester.startGesture(_at(tester, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(_thumb(tester).height, greaterThan(rest.height), reason: 'held');
    rebuild(() => enabled = false);
    await tester.pumpAndSettle();
    expect(_thumb(tester).height, closeTo(rest.height, 0.01));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await g.up();
    await tester.pump();
    expect(log, isEmpty);
  });

  testWidgets('RTL: a tap at the left commits the last segment (native '
      'rtl.tapLeftCommits)', (tester) async {
    final log = <int>[];
    await _pump(tester, log, direction: TextDirection.rtl);
    await tester.tapAt(_at(tester, 0));
    await tester.pumpAndSettle();
    expect(log, [(ref['rtl'] as Map)['tapLeftCommits']]);
  });

  group('against the native rows', () {
    final geometry = ref['geometry'] as Map<String, dynamic>;
    const tolerance = 2.0;

    testWidgets('press on the selected segment: w, h and engage per row', (
      tester,
    ) async {
      final rows = rowsOf(ref, 'press');
      final samples = _trace();
      await _pump(tester, <int>[]);
      await tester.startGesture(_at(tester, 0));
      await tester.pump();
      for (var t = 0.0; t < rows.last.t + 0.05; t += 1 / 60) {
        await tester.pump(_frame);
      }
      for (final r in rows) {
        final s = _sampleAt(samples, r.t);
        expect(s['w'], closeTo(r.w, tolerance), reason: 'w at +${r.t} s');
        expect(s['h'], closeTo(r.h, tolerance), reason: 'h at +${r.t} s');
        if (r.engage == 1) {
          expect(s['engage'], closeTo(1, 0.12), reason: 'e at +${r.t} s');
        }
      }
      final pressed = samples.last;
      final grow = (geometry['pressedGrow'] as List).cast<num>();
      expect(pressed['w'], closeTo(rows.first.w + grow[0], tolerance));
      expect(pressed['h'], closeTo(rows.first.h + grow[1], tolerance));
    });

    testWidgets('release in place after 1 s: w, h and engage per row', (
      tester,
    ) async {
      final rows = rowsOf(ref, 'release');
      final samples = _trace();
      final log = <int>[];
      await _pump(tester, log);
      final g = await tester.startGesture(_at(tester, 0));
      await tester.pump();
      for (var i = 0; i < 60; i++) {
        await tester.pump(_frame);
      }
      final upAt = samples.last['t']!;
      await g.up();
      for (var t = 0.0; t < rows.last.t + 0.05; t += 1 / 60) {
        await tester.pump(_frame);
      }
      for (final r in rows) {
        final s = _sampleAt(samples, upAt + r.t);
        expect(s['w'], closeTo(r.w, tolerance), reason: 'w at +${r.t} s');
        expect(s['h'], closeTo(r.h, tolerance), reason: 'h at +${r.t} s');
        expect(s['engage'], closeTo(r.engage, 0.12), reason: '+${r.t} s');
      }
      expect(log, isEmpty, reason: 'the selected segment calls nothing');
    });

    testWidgets('press on another segment: the lens stays at rest and the '
        'label fades to the native opacity (pressOther)', (tester) async {
      final other = ref['pressOther'] as Map<String, dynamic>;
      final rows = rowsOf(ref, 'pressOther');
      final releaseAt = (other['release_at'] as num).toDouble();
      final fade = (other['pressedLabelFade'] as num).toDouble();
      final opacity = (other['pressedLabelOpacity'] as num).toDouble();
      final pressed = other['pressed'] as int;
      final samples = _trace();
      final log = <int>[];
      await _pump(tester, log);
      final g = await tester.startGesture(_at(tester, pressed));
      await tester.pump();
      expect(_labelFade(tester, _titles[pressed]), 1);
      final box = _box(tester);
      var t = 0.0;
      for (; t < fade / 2; t += 1 / 60) {
        await tester.pump(_frame);
      }
      final mid = _labelFade(tester, _titles[pressed]);
      expect(mid, lessThan(1));
      expect(mid, greaterThan(opacity));
      for (; t < releaseAt; t += 1 / 60) {
        await tester.pump(_frame);
      }
      expect(_labelFade(tester, _titles[pressed]), closeTo(opacity, 0.01));
      expect(_labelFade(tester, _titles[other['from'] as int]), 1);
      for (final r in rows.where((r) => r.t < releaseAt)) {
        final s = _sampleAt(samples, r.t);
        expect(s['x']! - box.left, closeTo(r.x, tolerance), reason: '${r.t}');
        expect(s['w'], closeTo(r.w, tolerance), reason: 'w at +${r.t} s');
        expect(s['h'], closeTo(r.h, tolerance), reason: 'h at +${r.t} s');
        expect(s['engage'], r.engage, reason: 'engage at +${r.t} s');
      }
      expect(log, isEmpty);
      await g.up();
      await tester.pump();
      expect(log, [pressed], reason: 'commit at the release');
      await tester.pumpAndSettle();
      expect(_labelFade(tester, _titles[pressed]), 1);
    });

    testWidgets('slow drag release: x, w and h per native release row', (
      tester,
    ) async {
      final drag = ref['slow_drag'] as Map<String, dynamic>;
      final rows = rowsOf(ref, 'slow_drag', field: 'release_rows');
      final speed = ((ref['fits'] as Map)['dragLag'] as Map)['speed'] as num;
      final samples = _trace();
      final log = <int>[];
      await _pump(tester, log);
      final box = _box(tester);
      final start = _at(tester, 0);
      final end = _at(tester, 2);
      final g = await tester.startGesture(start);
      await tester.pump();
      var t = 0.0;
      var x = start.dx;
      while (x < end.dx) {
        t += 1 / 60;
        x = math.min(end.dx, start.dx + speed * t);
        await g.moveTo(Offset(x, start.dy));
        await tester.pump(_frame);
      }
      // The finger rests at the end until the lens is where native's was
      // at the up (idb lifts a moment after its last move).
      for (var i = 0; i < 60; i++) {
        if (samples.last['x']! - box.left >= rows.first.x) break;
        await tester.pump(_frame);
      }
      final upAt = samples.last['t']!;
      await g.up();
      for (var t = 0.0; t < rows.last.t + 0.05; t += 1 / 60) {
        await tester.pump(_frame);
      }
      expect(log, [drag['commit']]);
      for (final r in rows) {
        final s = _sampleAt(samples, upAt + r.t);
        expect(s['x']! - box.left, closeTo(r.x, tolerance), reason: '${r.t}');
        expect(s['w'], closeTo(r.w, tolerance), reason: 'w at +${r.t} s');
        expect(s['h'], closeTo(r.h, tolerance), reason: 'h at +${r.t} s');
      }
    });

    testWidgets('flick: commits the finger segment, native overshoot ± 1 pt', (
      tester,
    ) async {
      final flick = ref['flick'] as Map<String, dynamic>;
      final landing = ref['flickLanding'] as Map<String, dynamic>;
      final rows = rowsOf(ref, 'flick');
      final releaseAt = (flick['release_at'] as num).toDouble();
      final samples = _trace();
      final log = <int>[];
      final key = await _pump(tester, log);
      key.currentState!.select(2);
      await tester.pumpAndSettle();
      samples.clear();
      final box = _box(tester);
      final start = _at(tester, 2);
      final end = _at(tester, 0);
      final velocity = (end.dx - start.dx) / releaseAt;
      final g = await tester.createGesture();
      await g.down(start);
      await tester.pump();
      var t = 0.0;
      while (t < releaseAt) {
        t += 1 / 60;
        await g.moveTo(
          Offset(start.dx + velocity * math.min(t, releaseAt), start.dy),
          timeStamp: Duration(microseconds: (t * 1e6).round()),
        );
        await tester.pump(_frame);
      }
      await g.up(timeStamp: Duration(microseconds: (t * 1e6).round()));
      // Frame by frame, as the simulator: pumpAndSettle's 100 ms steps
      // would skip the landing's lowest point.
      for (var t = 0.0; t < rows.last.t; t += 1 / 60) {
        await tester.pump(_frame);
      }
      await tester.pumpAndSettle();
      expect(log, [flick['commit']]);
      final xs = [for (final s in samples) s['x']! - box.left];
      final rest = (landing['landing'] as num).toDouble();
      expect(
        rest - xs.reduce(math.min),
        closeTo((landing['overshoot'] as num).toDouble(), 1),
      );
      expect(xs.last, closeTo(rows.last.x, tolerance));
      // In flight the lens rises as native's (peak h within 10 %).
      final nativeMaxH = rows.map((r) => r.h).reduce(math.max);
      final maxH = samples.map((s) => s['h']!).reduce(math.max);
      expect(maxH, closeTo(nativeMaxH, nativeMaxH * 0.10));
    });
  });

  testWidgets('keyboard: Tab and the arrows focus each segment with a '
      'visible ring; Enter and Space activate it once', (tester) async {
    final log = <int>[];
    await _pump(tester, log);
    final ring = find.byKey(kSegmentFocusKey);
    expect(ring, findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(ring, findsOneWidget);
    expect(tester.getRect(ring).center.dx, closeTo(_at(tester, 0).dx, 0.5));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(tester.getRect(ring).center.dx, closeTo(_at(tester, 1).dx, 0.5));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(log, [1]);
    // The segment is now selected: Space on it calls nothing.
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(log, [1]);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(tester.getRect(ring).center.dx, closeTo(_at(tester, 2).dx, 0.5));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(log, [1, 2]);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(tester.getRect(ring).center.dx, closeTo(_at(tester, 1).dx, 0.5));
    await tester.pumpAndSettle();
    expect(_thumb(tester).center.dx, closeTo(_at(tester, 2).dx, 0.5));
  });

  testWidgets('AX text: a long press shows the label in the large content '
      'viewer and commits nothing; a drag still commits', (tester) async {
    final log = <int>[];
    await _pump(tester, log, textScale: 2);
    final g = await tester.startGesture(_at(tester, 1));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    final card = find.byKey(LargeContentViewer.overlayKey);
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('Songs')),
      findsOneWidget,
    );
    await g.up();
    await tester.pumpAndSettle();
    expect(card, findsNothing);
    expect(log, isEmpty, reason: 'lifting after the card does not select');
    await _slowDrag(tester, _at(tester, 0), _at(tester, 2));
    expect(log, [2]);
  });

  testWidgets('in a vertical scroll view a vertical drag from the control '
      'scrolls, and commits nothing', (tester) async {
    final log = <int>[];
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await _pump(
      tester,
      log,
      wrap: (control) => SingleChildScrollView(
        controller: scroll,
        child: Column(
          children: [
            const SizedBox(height: 300),
            Center(child: control),
            const SizedBox(height: 1200),
          ],
        ),
      ),
    );
    await tester.dragFrom(_at(tester, 2), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(100));
    expect(log, isEmpty);
  });

  testWidgets('a tap does not take the focus from a text field', (
    tester,
  ) async {
    final log = <int>[];
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await _pump(
      tester,
      log,
      wrap: (control) => Column(
        children: [
          TextField(focusNode: focus),
          const SizedBox(height: 40),
          control,
        ],
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    await tester.tapAt(_at(tester, 1));
    await tester.pumpAndSettle();
    expect(log, [1]);
    expect(focus.hasFocus, isTrue);
  });
}
