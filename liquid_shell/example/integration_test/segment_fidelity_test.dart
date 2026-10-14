// Flutter segmented control traces for the acceptance (spec VK-550 §14.5).
// tool/segment_frames.sh runs it on an iOS 26.5 iPhone 17 Pro simulator;
// tool/segment_trace_compare.dart reads build/integration_response_data.json.
// ios/RunnerUITests/SegmentFidelityUITests.swift drives UIKit's control on
// the native reference screen through the same sequence, for the strips.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
// The trace hook and the layer keys are test-only and stay out of the
// public API (spec §13).
import 'package:liquid_shell/src/segmented/segmented_control.dart'
    show debugSegmentTrace, kSegmentThumbKey, kSegmentTrackKey;
import 'package:liquid_shell_example/cases/segments.dart';
import 'package:liquid_shell_example/main.dart';

/// `make segment-traces` only (tool/segment_frames.sh sets it): the
/// sequences and samples the strips cannot have, because they pair the
/// native run's sequences and every scene change is an extra onset.
const bool _tracesOnly = bool.fromEnvironment('SEGFID_TRACES_ONLY');

/// The spike's gestures (docs/qa/vk550/spike.md, idb): a tap held 70 ms,
/// a press held 2 s, a slow drag at 82 pt/s, a flick over 0.25 s.
const Duration _tapHeld = Duration(milliseconds: 70);
const Duration _pressHeld = Duration(seconds: 2);
const double _slowDragSpeed = 82;
const double _flickSeconds = 0.25;

/// The drag's and the flick's ends, in screen points: the first and the
/// last segment of the full-width three-segment control (16 + 61, 16 +
/// 308 control-local).
const double _first = 77;
const double _last = 324;

/// Bounds every settle: a perpetual animation fails the run within seconds
/// instead of stalling for pumpAndSettle's default 10 minutes.
Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 10),
);

List<double> _ltwh(Rect r) => [r.left, r.top, r.width, r.height];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    // Every vsync frame, not one per pump: the default policy pumps a
    // frame every ~100 ms, and the lens would run slow and be sampled
    // ~7 times a second.
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  WidgetsApp.debugAllowBannerOverride = false;

  testWidgets('segmented control traces', (tester) async {
    await LiquidGlass.precache();
    // The example's segments case in the Flutter liquid tier, as the
    // `segments-liquid` demo opens it.
    await tester.pumpWidget(const ExampleApp(demo: 'segments-liquid'));
    await _settle(tester);

    Finder part(String id, Key key) => find.descendant(
      of: find.byKey(ValueKey('segments-$id')),
      matching: find.byKey(key),
    );
    Rect track(String id) => tester.getRect(part(id, kSegmentTrackKey));
    Rect thumb(String id) => tester.getRect(part(id, kSegmentThumbKey));

    /// The centre of segment [i] of [n] of control [id].
    Offset centre(String id, int i, int n) {
      final t = track(id);
      return Offset(t.left + (i + 0.5) * t.width / n, t.center.dy);
    }

    final geometry = <String, Map<String, Object>>{
      for (final id in ['intrinsic3', 'full2', 'full5'])
        id: {'track': _ltwh(track(id)), 'thumb': _ltwh(thumb(id))},
      'full3': {'track': _ltwh(track('full3'))},
    };
    final thumbs3 = List<List<double>?>.filled(3, null);

    final sequences = <String, List<Map<String, double>>>{};
    var current = <Map<String, double>>[];
    var finger = 0.0;
    var touching = false;
    // The centre line of the control being recorded: every control reports
    // to the one hook, and only the recorded one should move.
    double? line;
    debugSegmentTrace = (s) {
      final y = line;
      if (y == null || (s['y']! - y).abs() > 30) return;
      current.add({...s, 'finger': finger, 'touch': touching ? 1 : 0});
    };
    addTearDown(() => debugSegmentTrace = null);

    Future<void> idle() => tester.pump(const Duration(seconds: 1));
    Future<void> record(
      String name,
      String control,
      Future<void> Function() body,
    ) async {
      debugPrint('SEGFID $name');
      await idle();
      line = track(control).center.dy;
      current = [];
      await body();
      await _settle(tester);
      sequences[name] = current;
      line = null;
    }

    // Touches go in as the device's own: the tester's gestures make the
    // live binding paint a pointer marker (an orange ring and cross) over
    // the control for as long as the finger is down, which the native
    // recording does not have. On this path the binding hands each event to
    // GestureBinding as it is, with the same hit test, and paints nothing.
    binding.shouldPropagateDevicePointerEvents = true;
    var pointer = 0;
    TestGesture gesture() => TestGesture(
      pointer: ++pointer,
      dispatcher: (event) async => binding.handlePointerEventForSource(event),
    );

    /// A finger down at [p] for [held], then up. The flag drops just
    /// before the up: the last touching sample is the frame before it.
    Future<void> press(Offset p, Duration held) async {
      finger = p.dx;
      touching = true;
      final g = gesture();
      await g.down(p);
      await tester.pump(held);
      touching = false;
      await g.up();
    }

    /// Drags from [from] to [to] on [y] at [speed] pt/s of wall-clock
    /// time: frames are live, so the finger's speed is real time, not pump
    /// time. Every event carries its wall-clock time stamp: without one the
    /// velocity tracker reads 0 and a flick never counts as a flick.
    Future<void> drag(double from, double to, double y, double speed) async {
      finger = from;
      final clock = Stopwatch()..start();
      final g = gesture();
      touching = true;
      await g.down(Offset(from, y), timeStamp: clock.elapsed);
      final span = (to - from).abs();
      final sign = (to - from).sign;
      var travelled = 0.0;
      while (travelled < span) {
        travelled = math.min(span, speed * clock.elapsedMicroseconds / 1e6);
        finger = from + sign * travelled;
        await g.moveTo(Offset(finger, y), timeStamp: clock.elapsed);
        await tester.pump(const Duration(milliseconds: 4));
      }
      touching = false;
      await g.up(timeStamp: clock.elapsed);
    }

    final y = track('full3').center.dy;
    // tool/segment_frames.sh cuts the recording here.
    debugPrint('SEGFID start');
    await idle();
    await idle();
    for (final (name, to) in [('tap_1_2', 1), ('tap_2_3', 2), ('tap_3_1', 0)]) {
      await record(
        name,
        'full3',
        () => press(centre('full3', to, 3), _tapHeld),
      );
      thumbs3[to] = _ltwh(thumb('full3'));
    }
    // On the selected segment: the press, then its release in place.
    await record(
      'press',
      'full3',
      () => press(centre('full3', 0, 3), _pressHeld),
    );
    await record(
      'slow_drag',
      'full3',
      () => drag(_first, _last, y, _slowDragSpeed),
    );
    await record(
      'flick',
      'full3',
      () => drag(_last, _first, y, (_last - _first) / _flickSeconds),
    );
    // The app's own change: the case's "Next segment, from code".
    final next = find.byKey(kSegmentsNextKey);
    await tester.ensureVisible(next);
    await _settle(tester);
    await record('programmatic', 'full3', () async {
      final g = gesture();
      await g.down(tester.getCenter(next));
      await g.up();
    });
    geometry['full3']!['thumbs'] = thumbs3;
    // tool/segment_frames.sh ends the frames here, before the app goes.
    debugPrint('SEGFID end');
    await idle();
    await idle();

    if (_tracesOnly) {
      // Five segments, one to three (fixture tap_1_3_5seg), light.
      await record(
        'tap_1_3_5seg',
        'full5',
        () => press(centre('full5', 2, 5), _tapHeld),
      );
      // Back to the first segment unrecorded, then one to two in dark
      // (fixture dark.tap_1_2).
      await press(centre('full3', 0, 3), _tapHeld);
      await _settle(tester);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await _settle(tester);
      await record(
        'dark_tap_1_2',
        'full3',
        () => press(centre('full3', 1, 3), _tapHeld),
      );
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
    }
    debugSegmentTrace = null;
    // The binding checks that a test leaves it as it found it.
    binding.shouldPropagateDevicePointerEvents = false;

    // Rest colours (spec §14.5): the control over a white page in light
    // and a black one in dark, read back from the engine at the device
    // scale. Traces only: the scene changes would be extra onsets in the
    // strips.
    final colours = <String, List<double>>{};
    const enabled = ValueKey<String>('colours-enabled');
    const disabled = ValueKey<String>('colours-disabled');
    for (final brightness in [
      if (_tracesOnly) ...[Brightness.light, Brightness.dark],
    ]) {
      final dark = brightness == Brightness.dark;
      final boundary = GlobalKey();
      const labels = [
        LiquidSegment(label: 'All'),
        LiquidSegment(label: 'Songs'),
        LiquidSegment(label: 'Places'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: LiquidGlassScope(
            policy: const LiquidGlassPolicy(
              forcedTier: LiquidGlassTier.liquid,
            ),
            child: RepaintBoundary(
              key: boundary,
              child: Scaffold(
                backgroundColor: dark ? Colors.black : Colors.white,
                body: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 200, 16, 0),
                  child: Column(
                    children: [
                      LiquidSegmentedControl(
                        key: enabled,
                        segments: labels,
                        selectedIndex: 0,
                        onChanged: (_) {},
                      ),
                      const LiquidSegmentedControl(
                        key: disabled,
                        segments: labels,
                        selectedIndex: 0,
                        onChanged: null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await _settle(tester);
      final ratio = tester.view.devicePixelRatio;
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await render.toImage(pixelRatio: ratio);
      final width = image.width;
      final bytes = (await image.toByteData())!;
      image.dispose();
      List<double> rgb(Offset p) {
        final i = ((p.dy * ratio).floor() * width + (p.dx * ratio).floor()) * 4;
        return [
          for (var c = 0; c < 3; c++) bytes.getUint8(i + c).toDouble(),
        ];
      }

      Rect trackOf(Key control) => tester.getRect(
        find.descendant(
          of: find.byKey(control),
          matching: find.byKey(kSegmentTrackKey),
        ),
      );
      final t = trackOf(enabled);
      // The track 10 pt in from its right end, clear of "Places"; the
      // rest thumb on the first segment, left of "All".
      final bare = Offset(t.right - 10, t.center.dy);
      final mode = dark ? 'dark' : 'light';
      colours[dark ? 'darkTrackOverBlack' : 'lightTrackOverWhite'] = rgb(bare);
      colours[dark ? 'darkThumbOverTrack' : 'lightThumb'] = rgb(
        Offset(t.left + 14, t.center.dy),
      );
      if (!dark) {
        final d = trackOf(disabled);
        colours['lightDisabledTrack'] = rgb(Offset(d.right - 10, d.center.dy));
      }
      // The unselected "Songs": its darkest pixel in light, its brightest
      // in dark (the stem of a glyph, clear of antialiasing).
      final label = tester.getRect(
        find
            .descendant(of: find.byKey(enabled), matching: find.text('Songs'))
            .first,
      );
      List<double>? extreme;
      for (var y = label.top; y < label.bottom; y += 1 / ratio) {
        for (var x = label.left; x < label.right; x += 1 / ratio) {
          final c = rgb(Offset(x, y));
          final l = c.reduce((a, b) => a + b);
          final e = extreme?.reduce((a, b) => a + b);
          if (e == null || (dark ? l > e : l < e)) extreme = c;
        }
      }
      colours['${mode}Label'] = extreme!;
    }

    binding.reportData = {
      'geometry': geometry,
      'sequences': sequences,
      'colours': colours,
    };
  }, timeout: const Timeout(Duration(minutes: 4)));
}
