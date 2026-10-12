// Flutter liquid tab bar traces for the acceptance (spec VK-503 §17.4).
// tool/tab_frames.sh runs it on an iOS 26.5 iPhone 17 Pro simulator;
// tool/tab_trace_compare.dart reads build/integration_response_data.json.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// `make tab-traces` only (tool/tab_frames.sh sets it): extra sequences
/// the strips cannot have, because they pair the native run's sequences.
const bool _tracesOnly = bool.fromEnvironment('TABFID_TRACES_ONLY');

/// Bounds every settle: a perpetual animation fails the run within seconds
/// instead of stalling for pumpAndSettle's default 10 minutes.
Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 100),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 10),
);

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
    await _settle(tester);
    final sequences = <String, List<Map<String, double>>>{};
    var current = <Map<String, double>>[];
    var finger = 0.0;
    var touching = false;
    debugTabTrace = (s) =>
        current.add({...s, 'finger': finger, 'touch': touching ? 1 : 0});
    addTearDown(() => debugTabTrace = null);

    Future<void> idle() => tester.pump(const Duration(seconds: 1));
    Future<void> record(String name, Future<void> Function() body) async {
      debugPrint('TABFID $name');
      await idle();
      current = [];
      await body();
      await _settle(tester);
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

    /// A tap pressed [held] seconds, as a finger does.
    Future<void> pressTap(double x, double held) async {
      finger = x;
      touching = true;
      final g = await tester.startGesture(Offset(x, _y));
      await tester.pump(Duration(microseconds: (held * 1e6).round()));
      touching = false;
      await g.up();
    }

    /// Drags from [from] to [to] at [speed] pt/s of wall-clock time: frames
    /// are live, so the finger's speed is real time, not pump time. Every
    /// event carries its wall-clock time stamp: without one the velocity
    /// tracker reads 0 and a flick never counts as a flick.
    Future<void> drag(double from, double to, double speed) async {
      finger = from;
      final clock = Stopwatch()..start();
      final g = await tester.createGesture();
      touching = true;
      await g.down(Offset(from, _y), timeStamp: clock.elapsed);
      final span = (to - from).abs();
      final sign = (to - from).sign;
      var travelled = 0.0;
      while (travelled < span) {
        travelled = math.min(span, speed * clock.elapsedMicroseconds / 1e6);
        finger = from + sign * travelled;
        await g.moveTo(Offset(finger, _y), timeStamp: clock.elapsed);
        await tester.pump(const Duration(milliseconds: 4));
      }
      touching = false;
      await g.up(timeStamp: clock.elapsed);
    }

    // tool/tab_frames.sh cuts the recording here.
    debugPrint('TABFID start');
    await idle();
    await idle();
    await record('tap_1_2', () => tap(201));
    await record('tap_2_3', () => tap(287));
    await record('tap_3_1', () => tap(115));
    await record('press_hold', () async {
      finger = 115;
      touching = true;
      final g = await tester.startGesture(const Offset(115, _y));
      await tester.pump(const Duration(seconds: 1));
      sequences['press_hold_snapshot'] = List.of(current);
      touching = false;
      await g.up();
    });
    // The press alone, and the press with its release.
    sequences['press_release'] = sequences['press_hold']!;
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
    if (_tracesOnly) {
      // Review I2: an 80 ms tap, Home → Explore; the lift must not brake
      // the lens the press set moving.
      await record('tap_held', () => pressTap(201, 0.08));
    }
    debugTabTrace = null;

    // Rest colours (spec §17.4): the bar over a white page in light and a
    // black one in dark, read back from the engine at the device scale.
    final colors = <String, List<double>>{};
    for (final (name, brightness, page) in [
      ('light', Brightness.light, const Color(0xFFFFFFFF)),
      // The example's search page under the native field (225/223/240).
      ('lightPage', Brightness.light, const Color(0xFFE1DFF0)),
      ('dark', Brightness.dark, const Color(0xFF000000)),
    ]) {
      final boundary = GlobalKey();
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
                backgroundColor: page,
                body: Stack(
                  children: [
                    Positioned(
                      left: 21,
                      right: 21,
                      bottom: 21,
                      child: LiquidTabBar(
                        destinations: const [
                          LiquidDestination(
                            icon: Icon(Icons.home),
                            label: 'Home',
                          ),
                          LiquidDestination(
                            icon: Icon(Icons.map),
                            label: 'Explore',
                          ),
                          LiquidDestination(
                            icon: Icon(Icons.settings),
                            label: 'Settings',
                          ),
                        ],
                        selectedIndex: 0,
                        onDestinationSelected: (_) {},
                      ),
                    ),
                  ],
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

      final pill = tester.getRect(find.byKey(kTabPillKey));
      // Between slots 1 and 2: glass with nothing drawn on it.
      final fill = rgb(Offset(pill.left + 4 + 86 * 2, pill.center.dy));
      if (name == 'lightPage') {
        colors['lightFillPage'] = fill;
        continue;
      }
      colors['${name}Fill'] = fill;
      // Inside slot 0's rest capsule, left of the Home icon.
      colors['${name}Capsule'] = rgb(Offset(pill.left + 16, pill.center.dy));
      // The unselected "Explore" label: its darkest pixel in light, its
      // brightest in dark (the stem of a glyph, clear of antialiasing).
      final label = tester.getRect(find.text('Explore').first);
      List<double>? extreme;
      for (var y = label.top; y < label.bottom; y += 1 / ratio) {
        for (var x = label.left; x < label.right; x += 1 / ratio) {
          final c = rgb(Offset(x, y));
          final l = c.reduce((a, b) => a + b);
          final e = extreme?.reduce((a, b) => a + b);
          if (e == null || (name == 'light' ? l < e : l > e)) extreme = c;
        }
      }
      colors['${name}Label'] = extreme!;
    }

    binding.reportData = {
      'tabfid': {
        'geometry': geometry,
        'sequences': sequences,
        'colors': colors,
      },
    };
  }, timeout: const Timeout(Duration(minutes: 3)));
}
