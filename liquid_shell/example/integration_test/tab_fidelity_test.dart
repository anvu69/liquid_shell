// Flutter liquid tab bar traces for the acceptance (spec VK-503 §17.4).
// tool/tab_frames.sh runs it on an iOS 26.5 iPhone 17 Pro simulator;
// tool/tab_trace_compare.dart reads build/integration_response_data.json.
// The touches, settle and pixels are fidelity_driver.dart's, shared with
// segment_fidelity_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
// The trace hook and the pill key are test-only and stay out of the public
// API (spec §16).
import 'package:liquid_shell/src/chrome/glass_tab_bar.dart'
    show debugTabTrace, kTabPillKey;
import 'package:liquid_shell_example/cases/basic_tabs.dart';

import 'fidelity_driver.dart';

/// The slot centre line on a 874 pt tall iPhone 17 Pro: 21 pt above the
/// bottom, half of the 62 pt pill.
const double _y = 874.0 - 21 - 31;

/// `make tab-traces` only (tool/tab_frames.sh sets it): extra sequences
/// the strips cannot have, because they pair the native run's sequences.
const bool _tracesOnly = bool.fromEnvironment('TABFID_TRACES_ONLY');

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
    await settle(tester);
    final sequences = <String, List<Map<String, double>>>{};
    var current = <Map<String, double>>[];
    final pill = tester.getRect(find.byKey(kTabPillKey));
    final geometry = <String, List<double>>{
      'pill3': [pill.left, pill.top, pill.width, pill.height],
    };
    await FidelityTouches.run(tester, (touches) async {
      debugTabTrace = (s) => current.add({
        ...s,
        'finger': touches.finger,
        'touch': touches.touching ? 1 : 0,
      });
      addTearDown(() => debugTabTrace = null);

      Future<void> idle() => tester.pump(const Duration(seconds: 1));
      Future<void> record(String name, Future<void> Function() body) async {
        debugPrint('TABFID $name');
        await idle();
        current = [];
        await body();
        await settle(tester);
        sequences[name] = current;
      }

      Future<void> tap(double x) => touches.press(Offset(x, _y));

      // tool/tab_frames.sh cuts the recording here.
      debugPrint('TABFID start');
      await idle();
      await idle();
      await record('tap_1_2', () => tap(201));
      await record('tap_2_3', () => tap(287));
      await record('tap_3_1', () => tap(115));
      await record('press_hold', () async {
        final g = await touches.down(const Offset(115, _y));
        await tester.pump(const Duration(seconds: 1));
        sequences['press_hold_snapshot'] = List.of(current);
        await touches.up(g);
      });
      // The press alone, and the press with its release.
      sequences['press_release'] = sequences['press_hold']!;
      sequences['press_hold'] = sequences.remove('press_hold_snapshot')!;
      // Research §4.2: a slow drag at 90 pt/s, a flick of 172 pt in 7
      // frames (≈ 1500 pt/s).
      await record('slow_drag', () => touches.drag(115, 287, _y, 90));
      await record(
        'fast_flick',
        () => touches.drag(287, 115, _y, 172 * 60 / 7),
      );
      // A scroll of the page, not a lens gesture: the tester's own drag,
      // whose marker stays mid-screen, far above the bar band.
      await record('minimize', () async {
        await tester.drag(
          find.byType(Scrollable).first,
          const Offset(0, -400),
        );
      });
      final circle = tester.getRect(find.byKey(kTabPillKey));
      geometry['minimized'] = [
        circle.left,
        circle.top,
        circle.width,
        circle.height,
      ];
      await record('expand', () => touches.press(circle.center));
      if (_tracesOnly) {
        // Review I2: an 80 ms tap, Home → Explore; the lift must not brake
        // the lens the press set moving.
        await record(
          'tap_held',
          () => touches.press(
            const Offset(201, _y),
            const Duration(milliseconds: 80),
          ),
        );
      }
      debugTabTrace = null;
    });

    // Rest colours (spec §17.4): the bar over a white page in light and a
    // black one in dark, read back from the engine at the device scale.
    // Traces only: the scene changes would be extra onsets in the strips.
    final colors = <String, List<double>>{};
    for (final (name, brightness, page) in [
      if (_tracesOnly) ...[
        ('light', Brightness.light, const Color(0xFFFFFFFF)),
        // The example's search page under the native field (225/223/240).
        ('lightPage', Brightness.light, const Color(0xFFE1DFF0)),
        ('dark', Brightness.dark, const Color(0xFF000000)),
      ],
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
      await settle(tester);
      final pixels = await Pixels.of(tester, boundary);
      List<double> rgb(Offset p) => pixels.rgb(p);

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
      colors['${name}Label'] = pixels.extreme(
        label,
        brightest: name != 'light',
      );
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
