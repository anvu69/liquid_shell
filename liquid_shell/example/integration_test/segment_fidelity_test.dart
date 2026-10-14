// Flutter segmented control traces for the acceptance (spec VK-550 §14.5).
// tool/segment_frames.sh runs it on an iOS 26.5 iPhone 17 Pro simulator;
// tool/segment_trace_compare.dart reads build/integration_response_data.json.
// ios/RunnerUITests/SegmentFidelityUITests.swift drives UIKit's control on
// the native reference screen through the same sequence, for the strips.
// The touches, settle and pixels are fidelity_driver.dart's, shared with
// tab_fidelity_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
// The trace hook and the layer keys are test-only and stay out of the
// public API (spec §13).
import 'package:liquid_shell/src/segmented/segmented_control.dart'
    show debugSegmentTrace, kSegmentThumbKey, kSegmentTrackKey;
import 'package:liquid_shell_example/cases/segments.dart';
import 'package:liquid_shell_example/main.dart';

import 'fidelity_driver.dart';

/// `make segment-traces` only (tool/segment_frames.sh sets it): the
/// sequences and samples the strips cannot have, because they pair the
/// native run's sequences and every scene change is an extra onset.
const bool _tracesOnly = bool.fromEnvironment('SEGFID_TRACES_ONLY');

/// The flick native's `flickLanding` capture made, from
/// docs/qa/vk550/native_reference.json (tool/segment_frames.sh reads it):
/// "seconds,from,to", down to up, control-local.
const String _flick = String.fromEnvironment('SEGFID_FLICK');

/// The spike's gestures (docs/qa/vk550/spike.md, idb): a tap held 70 ms,
/// a press held 2 s, a slow drag at 82 pt/s.
const Duration _tapHeld = Duration(milliseconds: 70);
const Duration _pressHeld = Duration(seconds: 2);
const double _slowDragSpeed = 82;

/// The slow drag's ends, in screen points: the first and the last segment
/// of the full-width three-segment control (16 + 61, 16 + 308
/// control-local).
const double _first = 77;
const double _last = 324;

List<double> _ltwh(Rect r) => [r.left, r.top, r.width, r.height];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    // Every vsync frame, not one per pump: the default policy pumps a
    // frame every ~100 ms, and the lens would run slow and be sampled
    // ~7 times a second.
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  WidgetsApp.debugAllowBannerOverride = false;

  testWidgets('segmented control traces', (tester) async {
    final flick = _flick.split(',').map(double.tryParse).toList();
    if (flick.length != 3 || flick.contains(null)) {
      fail(
        'SEGFID_FLICK is "$_flick": run through tool/segment_frames.sh, '
        'which reads the flick from the native fixture',
      );
    }
    final [flickSeconds, flickFrom, flickTo] = [
      for (final v in flick) v!,
    ];
    await LiquidGlass.precache();
    // The example's segments case in the Flutter liquid tier, as the
    // `segments-liquid` demo opens it.
    await tester.pumpWidget(const ExampleApp(demo: 'segments-liquid'));
    await settle(tester);

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
    final drives = <String, Map<String, double>>{};
    final sequences = <String, List<Map<String, double>>>{};
    var current = <Map<String, double>>[];

    await FidelityTouches.run(tester, (touches) async {
      // The centre line of the control being recorded: every control
      // reports to the one hook, and only the recorded one should move.
      double? line;
      debugSegmentTrace = (s) {
        final y = line;
        if (y == null || (s['y']! - y).abs() > 30) return;
        current.add({
          ...s,
          'finger': touches.finger,
          'touch': touches.touching ? 1 : 0,
        });
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
        await settle(tester);
        sequences[name] = current;
        line = null;
      }

      final full3 = track('full3');
      final y = full3.center.dy;
      // Task 15: the trace runs a debug (JIT) build, where the first run of
      // the lens's tap code compiles it, and the first tap after launch
      // dropped a frame (33-50 ms in every run) wherever its first new code
      // path fell: warming the lens pipeline did not remove it, and a 1 x 1
      // lens drawn at mount moved it from the engage to the release. One
      // unrecorded tap there and back runs every tap path once before the
      // recording, and before the strips' start marker. A release (AOT)
      // build compiles nothing at run time.
      for (final to in [1, 0]) {
        await touches.press(centre('full3', to, 3), _tapHeld);
        await settle(tester);
      }
      // tool/segment_frames.sh cuts the recording here.
      debugPrint('SEGFID start');
      await idle();
      await idle();
      for (final (name, to) in [
        ('tap_1_2', 1),
        ('tap_2_3', 2),
        ('tap_3_1', 0),
      ]) {
        await record(
          name,
          'full3',
          () => touches.press(centre('full3', to, 3), _tapHeld),
        );
        thumbs3[to] = _ltwh(thumb('full3'));
      }
      // On the selected segment: the press, then its release in place.
      await record(
        'press',
        'full3',
        () => touches.press(centre('full3', 0, 3), _pressHeld),
      );
      await record(
        'slow_drag',
        'full3',
        () => touches.drag(_first, _last, y, _slowDragSpeed),
      );
      // The flick native's capture made, at the same speed: the overshoot
      // depends on it (tool/segment_trace_compare.dart checks the drive).
      await record('flick', 'full3', () async {
        final drive = await touches.drag(
          full3.left + flickFrom,
          full3.left + flickTo,
          y,
          (flickFrom - flickTo).abs() / flickSeconds,
          arrive: true,
        );
        drives['flick'] = {
          'seconds': drive.seconds,
          'from': drive.from - full3.left,
          'to': drive.to - full3.left,
        };
      });
      // The app's own change: the case's "Next segment, from code".
      final next = find.byKey(kSegmentsNextKey);
      await tester.ensureVisible(next);
      await settle(tester);
      await record('programmatic', 'full3', () => touches.tapOn(next));
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
          () => touches.press(centre('full5', 2, 5), _tapHeld),
        );
        // Back to the first segment unrecorded, then one to two in dark
        // (fixture dark.tap_1_2).
        await touches.press(centre('full3', 0, 3), _tapHeld);
        await settle(tester);
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        addTearDown(
          tester.platformDispatcher.clearPlatformBrightnessTestValue,
        );
        await settle(tester);
        await record(
          'dark_tap_1_2',
          'full3',
          () => touches.press(centre('full3', 1, 3), _tapHeld),
        );
        tester.platformDispatcher.clearPlatformBrightnessTestValue();
      }
      debugSegmentTrace = null;
    });

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
      await settle(tester);
      final pixels = await Pixels.of(tester, boundary);
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
      colours[dark ? 'darkTrackOverBlack' : 'lightTrackOverWhite'] = pixels.rgb(
        bare,
      );
      colours[dark ? 'darkThumbOverTrack' : 'lightThumb'] = pixels.rgb(
        Offset(t.left + 14, t.center.dy),
      );
      if (!dark) {
        final d = trackOf(disabled);
        colours['lightDisabledTrack'] = pixels.rgb(
          Offset(d.right - 10, d.center.dy),
        );
      }
      // The unselected "Songs": its darkest pixel in light, its brightest
      // in dark.
      colours['${dark ? 'dark' : 'light'}Label'] = pixels.extreme(
        tester.getRect(
          find
              .descendant(of: find.byKey(enabled), matching: find.text('Songs'))
              .first,
        ),
        brightest: dark,
      );
    }

    binding.reportData = {
      'geometry': geometry,
      'sequences': sequences,
      'drives': drives,
      'colours': colours,
    };
  }, timeout: const Timeout(Duration(minutes: 4)));
}
