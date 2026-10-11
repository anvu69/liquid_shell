// Flutter liquid tab bar traces for the acceptance (spec VK-503 §17.4).
// tool/tab_frames.sh runs it on an iOS 26.5 iPhone 17 Pro simulator;
// tool/tab_trace_compare.dart reads build/integration_response_data.json.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
// The trace hook and the pill key are test-only and stay out of the public
// API (spec §16).
import 'package:liquid_shell/src/chrome/glass_tab_bar.dart'
    show debugTabTrace, kTabPillKey;
import 'package:liquid_shell_example/cases/basic_tabs.dart';

/// The slot centre line on a 874 pt tall iPhone 17 Pro: 21 pt above the
/// bottom, half of the 62 pt pill.
const double _y = 874.0 - 21 - 31;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    // Every vsync frame, not one per pump: the default policy pumps a
    // frame every ~100 ms, and the bar clamps its step to 1/30 s, so the
    // springs would run ~3.5× slow and the traces would hold ~7 samples
    // a second.
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  WidgetsApp.debugAllowBannerOverride = false;

  testWidgets('tab bar traces', (tester) async {
    await LiquidGlass.precache();
    await tester.pumpWidget(
      const MaterialApp(
        home: LiquidGlassScope(
          policy: LiquidGlassPolicy(forcedTier: LiquidGlassTier.liquid),
          child: BasicTabsCase(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final sequences = <String, List<Map<String, double>>>{};
    var current = <Map<String, double>>[];
    var finger = 0.0;
    debugTabTrace = (s) => current.add({...s, 'finger': finger});
    addTearDown(() => debugTabTrace = null);

    Future<void> idle() => tester.pump(const Duration(seconds: 1));
    Future<void> record(String name, Future<void> Function() body) async {
      await idle();
      current = [];
      await body();
      await tester.pumpAndSettle();
      sequences[name] = current;
    }

    final pill = tester.getRect(find.byKey(kTabPillKey));
    final geometry = <String, List<double>>{
      'pill3': [pill.left, pill.top, pill.width, pill.height],
    };

    Future<void> tap(double x) async {
      finger = x;
      await tester.tapAt(Offset(x, _y));
    }

    /// Drags from [from] to [to] at [speed] pt/s of wall-clock time: frames
    /// are live, so the finger's speed is real time, not pump time.
    Future<void> drag(double from, double to, double speed) async {
      finger = from;
      final g = await tester.startGesture(Offset(from, _y));
      final clock = Stopwatch()..start();
      final span = (to - from).abs();
      final sign = (to - from).sign;
      var travelled = 0.0;
      while (travelled < span) {
        travelled = math.min(span, speed * clock.elapsedMicroseconds / 1e6);
        finger = from + sign * travelled;
        await g.moveTo(Offset(finger, _y));
        await tester.pump(const Duration(milliseconds: 4));
      }
      await g.up();
    }

    await record('tap_1_2', () => tap(201));
    await record('tap_2_3', () => tap(287));
    await record('tap_3_1', () => tap(115));
    await record('press_hold', () async {
      finger = 115;
      final g = await tester.startGesture(const Offset(115, _y));
      await tester.pump(const Duration(seconds: 1));
      sequences['press_hold_snapshot'] = List.of(current);
      await g.up();
    });
    // The "held" sample is the last one before the release.
    sequences['press_hold'] = sequences.remove('press_hold_snapshot')!;
    // Research §4.2: a slow drag at 90 pt/s, a flick of 172 pt in 7
    // frames (≈ 1500 pt/s).
    await record('slow_drag', () => drag(115, 287, 90));
    await record('fast_flick', () => drag(287, 115, 172 * 60 / 7));
    await record('minimize', () async {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
    });
    final circle = tester.getRect(find.byKey(kTabPillKey));
    geometry['minimized'] = [
      circle.left,
      circle.top,
      circle.width,
      circle.height,
    ];
    await record('expand', () => tester.tapAt(circle.center));

    binding.reportData = {
      'tabfid': {'geometry': geometry, 'sequences': sequences},
    };
  });
}
