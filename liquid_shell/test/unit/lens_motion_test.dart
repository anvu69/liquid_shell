import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/chrome/lens_motion.dart';
import 'package:liquid_shell/src/chrome/tab_geometry.dart';
import 'package:liquid_shell/src/chrome/tab_springs.dart';

import '../helpers/settle.dart';

const double dt = 1 / 60;
// Slot centres 94 / 180 / 266 bar-local = 115 / 201 / 287 on screen.
final TabBarGeometry g3 = compactTabGeometry(
  count: 3,
  maxWidth: 360,
  trailing: false,
  direction: TextDirection.ltr,
);

/// Advances [m] for [seconds]; returns the frames. Like production, where
/// pointer events reach the model between vsyncs, [input] runs before each
/// frame's advance (with that frame's end time); [each] runs after it.
List<LensFrame> run(
  LensMotion m,
  double seconds, {
  void Function(double t)? input,
  void Function(double t)? each,
}) {
  final frames = <LensFrame>[];
  final n = (seconds / dt).round();
  for (var f = 1; f <= n; f++) {
    input?.call(f * dt);
    m.advance(dt);
    frames.add(m.frame);
    each?.call(f * dt);
  }
  return frames;
}

double within(double reference, double fraction) => reference * fraction;

void main() {
  group('rest', () {
    test('the lens is the selected slot', () {
      final m = LensMotion(geometry: g3, selected: 1);
      expect(m.frame.lens, g3.slots[1]);
      expect(m.frame.visible, isTrue);
      expect(m.frame.engage, 0);
      expect(m.advance(dt), isFalse);
    });

    test('nothing selected: invisible', () {
      final m = LensMotion(geometry: g3, selected: null);
      expect(m.frame.visible, isFalse);
    });
  });

  group('tap (research §3)', () {
    test('one slot: settle matches the tap spring with a 25 ms delay', () {
      final m = LensMotion(geometry: g3, selected: 0)..tapSlot(1);
      final xs = [for (final f in run(m, 1.5)) f.lens.center.dx];
      final ours = settleTime(xs, 180);
      final reference = settleTime(
        referenceTrace(
          TabSprings.tap,
          94,
          180,
          delay: TabSprings.tapDelay,
          seconds: 1.5,
        ),
        180,
      );
      expect(ours, closeTo(reference, within(reference, 0.10)));
      expect(m.committed, 1);
      expect(m.phase, LensPhase.rest);
    });

    test('the lens leaves 25 ms after the commit, not at the frame before '
        '(spec §17.4 tap delay; VK-503 Task 16)', () {
      final m = LensMotion(geometry: g3, selected: 0)..tapSlot(1);
      final xs = [for (final f in run(m, 0.3)) f.lens.center.dx];
      final reference = referenceTrace(
        TabSprings.tap,
        94,
        180,
        delay: TabSprings.tapDelay,
        seconds: 0.3,
      );
      for (var i = 0; i < xs.length; i++) {
        expect(xs[i], closeTo(reference[i], 0.05), reason: 'frame ${i + 1}');
      }
    });

    test('a touch tap holds the lens for the 25 ms too: the press does not '
        'start the flight early (VK-503 Task 16)', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(180, 31))
        ..up(const Offset(180, 31));
      final xs = [for (final f in run(m, 0.3)) f.lens.center.dx];
      final reference = referenceTrace(
        TabSprings.tap,
        94,
        180,
        delay: TabSprings.tapDelay,
        seconds: 0.3,
      );
      for (var i = 0; i < xs.length; i++) {
        expect(xs[i], closeTo(reference[i], 0.05), reason: 'frame ${i + 1}');
      }
    });

    test(
      'one slot lifts: height ×1.55 ± 10 % at 0.15–0.30 s, width ≤ ×0.92',
      () {
        final m = LensMotion(geometry: g3, selected: 0)..tapSlot(1);
        var peak = 0.0;
        var narrowest = double.infinity;
        run(
          m,
          0.6,
          each: (t) {
            final lens = m.frame.lens;
            if (t >= 0.15 && t <= 0.30 && lens.height > peak) {
              peak = lens.height;
            }
            if (lens.width < narrowest) narrowest = lens.width;
          },
        );
        expect(peak / 54, closeTo(1.55, 0.155));
        expect(narrowest / 94, lessThanOrEqualTo(0.92));
      },
    );

    test('two slots stretch: width ×1.33 ± 10 %', () {
      final m = LensMotion(geometry: g3, selected: 0)..tapSlot(2);
      var widest = 0.0;
      run(
        m,
        0.6,
        each: (_) {
          if (m.frame.lens.width > widest) widest = m.frame.lens.width;
        },
      );
      expect(widest / 94, closeTo(1.33, 0.133));
    });

    test('two slots: the peak is native ×1.355 (127.4 pt, research trace; '
        'stretchMax 1.425)', () {
      // As the research run: a 66 ms press on Settings, from Home.
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(266, 31));
      var widest = 0.0;
      run(
        m,
        0.6,
        input: (t) {
          if ((t * 60).round() == 5) m.up(const Offset(266, 31));
        },
        each: (_) {
          if (m.frame.lens.width > widest) widest = m.frame.lens.width;
        },
      );
      expect(TabSprings.stretchMax, 1.425);
      expect(widest / 94, closeTo(127.4 / 94, 0.01));
    });

    test('top bar: inflates ×1.34 by ×1.375, no lift, no stretch', () {
      const top = TabBarGeometry(
        form: TabBarForm.top,
        size: Size(200, 48),
        pill: Rect.fromLTWH(0, 0, 200, 48),
        slots: [Rect.fromLTWH(4, 4, 80, 40), Rect.fromLTWH(84, 4, 100, 40)],
        trailing: null,
        minimized: Rect.fromLTWH(0, 0, 200, 48),
        minimizedTrailing: null,
      );
      final m = LensMotion(geometry: top, selected: 0)..tapSlot(1);
      var widest = 0.0;
      var narrowest = double.infinity;
      var tallest = 0.0;
      run(
        m,
        0.6,
        each: (_) {
          final lens = m.frame.lens;
          if (lens.width > widest) widest = lens.width;
          if (lens.width < narrowest) narrowest = lens.width;
          if (lens.height > tallest) tallest = lens.height;
        },
      );
      // The width target is rest × 1.34 (rest grows 80 → 100 in flight).
      expect(widest, greaterThan(80 * 1.2));
      expect(widest, lessThanOrEqualTo(100 * TabSprings.topTapWidth));
      expect(narrowest, greaterThanOrEqualTo(80 - 0.5));
      // heightIn (ζ 0.72) overshoots its ×1.375 target a little; the compact
      // lift (×1.55) would not fit here.
      expect(tallest / 40, closeTo(TabSprings.topTapHeight, 0.05));
      run(m, 1.5);
      expect(m.phase, LensPhase.rest);
      expect(m.frame.lens.size, const Size(100, 40));
    });

    test('engage holds 0.35 s, the target pops ×1.16, the pill bulges', () {
      final m = LensMotion(geometry: g3, selected: 0)..tapSlot(1);
      var popPeak = 1.0;
      var scalePeak = 1.0;
      run(
        m,
        0.3,
        each: (_) {
          final f = m.frame;
          if (f.popScale > popPeak) popPeak = f.popScale;
          if (f.pillScale > scalePeak) scalePeak = f.pillScale;
        },
      );
      expect(m.frame.engage, greaterThan(0.95));
      expect(m.frame.popSlot, 1);
      expect(popPeak, closeTo(1.16, 0.02));
      expect(scalePeak, inInclusiveRange(1.010, 1.030));
      run(m, 1);
      expect(m.frame.engage, lessThan(0.01));
      expect(m.frame.popScale, closeTo(1, 0.002));
    });
  });

  group('press and hold (research §4.1)', () {
    test('a press during a tap flight drops the pop back to ×1', () {
      final m = LensMotion(geometry: g3, selected: 0)..tapSlot(1);
      run(m, 0.1);
      expect(m.frame.popScale, greaterThan(1.05));
      m.down(const Offset(180, 31));
      run(m, 0.5);
      expect(m.frame.popScale, closeTo(1, 0.002));
    });

    test('lens 110 × 70, pill ×1.052, highlight 0.845, glow 0.28', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(94, 31));
      run(m, 1);
      final f = m.frame;
      expect(f.lens.width, closeTo(110, 2));
      expect(f.lens.height, closeTo(70, 2));
      expect(f.pillScale, closeTo(1.052, 0.005));
      expect(f.engage, closeTo(1, 0.01));
      expect(f.highlight, closeTo(0.845, 0.02));
      expect(f.glowOpacity, closeTo(0.28, 0.02));
      expect(f.glowDiameter, closeTo(98, 1));
      expect(f.glowCenter, const Offset(94, 31));
      expect(f.magnify, closeTo(1.16, 0.002));
      expect(m.phase, LensPhase.pressed);
    });

    test('holding never selects', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(180, 31));
      run(m, 1);
      expect(m.committed, 0);
      expect(m.pending, isNull);
    });
  });

  group('drag (research §4.2)', () {
    test('lag at 90 pt/s equals the follow spring ramp lag ± 10 %', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(94, 31));
      var finger = 94.0;
      run(
        m,
        1,
        input: (t) {
          finger = 94 + 90 * t;
          m.move(Offset(finger, 31));
        },
      );
      final s = TabSprings.dragFollow;
      final rampLag = 90 * s.damping / s.stiffness; // v·2ζ/ω
      // A harness sampling artifact, not frame timing: the target is held
      // at the frame's end value, so it leads the continuous finger ramp by
      // half a frame on average and the measured lag is rampLag − hold.
      const hold = 90 * dt / 2;
      expect(
        finger + hold - m.frame.lens.center.dx,
        closeTo(rampLag, within(rampLag, 0.10)),
      );
      expect(rampLag, closeTo(7.1, 0.1));
      expect(m.phase, LensPhase.dragging);
    });

    test('the lens is clamped to the first and last slot', () {
      final m = LensMotion(geometry: g3, selected: 1)
        ..down(const Offset(180, 31))
        ..move(const Offset(400, 31));
      run(m, 1);
      expect(m.frame.lens.center.dx, closeTo(266, 0.5));
      m.move(const Offset(-80, 31));
      run(m, 1);
      expect(m.frame.lens.center.dx, closeTo(94, 0.5));
    });

    test('one crossing per slot boundary, in order', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(94, 31));
      final crossings = <int>[];
      run(
        m,
        3,
        input: (t) => m.move(Offset(94 + 60 * t, 31)),
        each: (_) => crossings.addAll(m.takeCrossings()),
      );
      expect(crossings, [1, 2]);
    });

    test('travel during the press is not a crossing (Q6)', () {
      // The lens follows the finger to slot 2 while still pressed; the drag
      // that follows crosses 1 and 0 only.
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(266, 31));
      run(m, 0.5);
      expect(m.phase, LensPhase.pressed);
      final crossings = <int>[];
      run(
        m,
        3,
        input: (t) => m.move(Offset(266 - 60 * t, 31)),
        each: (_) => crossings.addAll(m.takeCrossings()),
      );
      expect(crossings, [1, 0]);
    });

    test('no crossing on a tap, even when the lens moves', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(266, 31));
      run(m, 0.3);
      expect(m.takeCrossings(), isEmpty);
    });
  });

  group('release (research §4.3)', () {
    test('commits the slot nearest the lens, not the finger', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(94, 31))
        ..move(const Offset(230, 31));
      while (m.frame.lens.center.dx < 215) {
        m.advance(dt);
      }
      expect(m.up(const Offset(230, 31), velocity: 90), 1);
      expect(m.pending, 1);
    });

    test('a flick commits the finger slot', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(94, 31))
        ..move(const Offset(230, 31));
      while (m.frame.lens.center.dx < 215) {
        m.advance(dt);
      }
      expect(m.up(const Offset(230, 31), velocity: 1500), 2);
    });

    test('settles on the snap spring ± 10 %', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(94, 31))
        ..move(const Offset(220, 31));
      run(m, 1.5);
      final from = m.frame.lens.center.dx;
      expect(m.up(const Offset(220, 31)), 1);
      final xs = [for (final f in run(m, 1.5)) f.lens.center.dx];
      final reference = settleTime(
        referenceTrace(TabSprings.snap, from, 180),
        180,
      );
      expect(settleTime(xs, 180), closeTo(reference, within(reference, 0.10)));
      expect(m.frame.lens.size, const Size(94, 54));
      expect(m.frame.pillScale, closeTo(1, 0.001));
    });

    test('the glow ripples ×4 and is gone by about 0.55 s (native: 0.004 at '
        '+0.52 s)', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(94, 31));
      run(m, 0.5);
      final held = m.frame.glowDiameter;
      m.up(const Offset(94, 31));
      run(m, 0.25);
      expect(m.frame.glowDiameter, greaterThan(held * 2));
      run(m, 0.35);
      expect(m.frame.glowOpacity, 0);
      expect(m.frame.glowCenter, isNull);
    });

    test('a quick tap ripples too: from the 0.28, 93 pt glow (research §3; '
        'VK-503 Task 16)', () {
      // Down and up before any frame: the glow had no time to fade in, and
      // the ripple started from opacity 0, invisible.
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(180, 31))
        ..up(const Offset(180, 31))
        ..advance(0);
      expect(m.frame.glowOpacity, closeTo(TabSprings.glowOpacity, 0.001));
      expect(m.frame.glowDiameter, closeTo(TabSprings.glowDiameter, 0.001));
      var widest = 0.0;
      var gone = double.infinity;
      run(
        m,
        0.6,
        each: (t) {
          widest = math.max(widest, m.frame.glowDiameter);
          if (m.frame.glowOpacity == 0 && gone.isInfinite) gone = t;
        },
      );
      expect(widest / TabSprings.glowDiameter, closeTo(4, 0.4));
      // Native: 0.004 at +0.52 s, 0.002 at +0.58 s.
      expect(gone, closeTo(0.55, 0.05));
    });

    test('a tap on the selected slot commits it again (reselect)', () {
      final m = LensMotion(geometry: g3, selected: 1)
        ..down(const Offset(180, 31));
      run(m, 0.05);
      expect(m.up(const Offset(180, 31)), 1);
    });

    test('cancel goes back to the committed slot', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(94, 31))
        ..move(const Offset(200, 31));
      run(m, 0.5);
      m.cancel();
      run(m, 1.5);
      expect(m.frame.lens.center.dx, closeTo(94, 0.5));
      expect(m.committed, 0);
      expect(m.pending, isNull);
    });
  });

  group('commit bookkeeping (spec §8.7)', () {
    test('accept clears the pending commit', () {
      final m = LensMotion(geometry: g3, selected: 0)..tapSlot(2);
      expect(m.pending, 2);
      m.accept();
      expect(m.pending, isNull);
      expect(m.committed, 2);
    });

    test('returnTo snaps back to the app selection', () {
      final m = LensMotion(geometry: g3, selected: 0)..tapSlot(2);
      run(m, 1.5);
      m.returnTo(0);
      expect(m.pending, isNull);
      run(m, 1.5);
      expect(m.frame.lens.center.dx, closeTo(94, 0.5));
    });

    test('show jumps without animation', () {
      final m = LensMotion(geometry: g3, selected: 0)..show(2);
      expect(m.frame.lens, g3.slots[2]);
      expect(m.advance(dt), isFalse);
    });

    test('a new geometry at rest moves the lens with it', () {
      final m = LensMotion(geometry: g3, selected: 1);
      final g4 = compactTabGeometry(
        count: 4,
        maxWidth: 360,
        trailing: true,
        direction: TextDirection.ltr,
      );
      m.geometry = g4;
      expect(m.frame.lens, g4.slots[1]);
    });
  });

  group('reduce motion (spec §13.2)', () {
    test('press: nothing inflates, nothing engages', () {
      final m = LensMotion(geometry: g3, selected: 0, reduceMotion: true)
        ..down(const Offset(94, 31));
      run(m, 0.5);
      expect(m.frame.lens.size, const Size(94, 54));
      expect(m.frame.engage, 0);
      expect(m.frame.pillScale, 1);
      expect(m.frame.glowOpacity, 0);
    });

    test('tap: a 150 ms dissolve, no slide', () {
      final m = LensMotion(geometry: g3, selected: 0, reduceMotion: true)
        ..tapSlot(2);
      expect(m.frame.lens, g3.slots[2]);
      expect(m.frame.ghost, g3.slots[0]);
      expect(m.frame.ghostOpacity, 1);
      expect(m.frame.restOpacity, 0);
      run(m, 0.2);
      expect(m.frame.ghost, isNull);
      expect(m.frame.restOpacity, 1);
      expect(m.frame.popScale, 1);
    });

    test('pointer tap: no slide while pressed, a dissolve in place', () {
      final m = LensMotion(geometry: g3, selected: 0, reduceMotion: true)
        ..down(const Offset(266, 31));
      run(m, 0.1);
      expect(m.frame.lens.center.dx, closeTo(94, 0.5));
      expect(m.up(const Offset(266, 31)), 2);
      expect(m.frame.lens, g3.slots[2]);
      expect(m.frame.ghost, g3.slots[0]);
      expect(m.frame.ghostOpacity, 1);
      expect(m.frame.restOpacity, 0);
      final xs = [for (final f in run(m, 0.2)) f.lens.center.dx];
      expect(xs, everyElement(266));
      expect(m.frame.ghost, isNull);
      expect(m.frame.restOpacity, 1);
    });

    test('drag: the rest-size capsule follows the finger', () {
      final m = LensMotion(geometry: g3, selected: 0, reduceMotion: true)
        ..down(const Offset(94, 31))
        ..move(const Offset(200, 31));
      run(m, 1);
      expect(m.frame.lens.center.dx, closeTo(200, 0.5));
      expect(m.frame.lens.size, const Size(94, 54));
    });
  });

  // VK-503 Task 16 review. Native numbers from the research's per-frame
  // layer traces (scratchpad tabfid/runs/n265_basic3.log, iPhone 17 Pro iOS
  // 26.5, pure UITabBarController), bar-local (screen x − 21). Each native
  // tap there was a 65–66 ms press.
  group('native timeline (review)', () {
    /// Frames of [m] at 60 fps for [seconds]; [input] runs before frame f.
    List<LensFrame> frames(
      LensMotion m,
      double seconds, [
      void Function(int f)? input,
    ]) {
      final out = <LensFrame>[];
      for (var f = 1; f <= (seconds * 60).round(); f++) {
        input?.call(f);
        m.advance(dt);
        out.add(m.frame);
      }
      return out;
    }

    test('a tap pressed 80 ms flies on without braking (review I2)', () {
      // The same press, held or lifted at 80 ms: lifting must not brake the
      // lens it already set moving (the speed within 10 % of the held one
      // over the next 50 ms).
      List<double> speeds({required bool lift}) {
        final m = LensMotion(geometry: g3, selected: 0)
          ..down(const Offset(180, 31));
        final xs = [
          for (final f in frames(m, 0.15, (f) {
            if (lift && f == 6) m.up(const Offset(180, 31));
          }))
            f.lens.center.dx,
        ];
        return [for (var i = 1; i < xs.length; i++) (xs[i] - xs[i - 1]) / dt];
      }

      final held = speeds(lift: false);
      final lifted = speeds(lift: true);
      for (var i = 4; i < 8; i++) {
        expect(
          lifted[i],
          closeTo(held[i], held[i].abs() * 0.10),
          reason: 'frame ${i + 1}: held $held, lifted $lifted',
        );
      }
    });

    test('the press answers 25 ms after the down (research §4.1 trace)', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(94, 31));
      final f = frames(m, 0.2);
      // Native, pill-local: frame → (w, h).
      const native = {2: (94.7, 54.7), 4: (99.2, 59.3), 6: (103.4, 63.6)};
      // ±2 pt (spec §17.4 press size); the height spring runs up to 2.5 pt
      // behind native in its first frames, one 60 fps frame of its rise.
      for (final MapEntry(key: k, value: (w, h)) in native.entries) {
        expect(f[k - 1].lens.width, closeTo(w, 2), reason: 'w frame $k');
        expect(f[k - 1].lens.height, closeTo(h, 2.5), reason: 'h frame $k');
      }
      // opacityPair 0.18 at 33 ms, 1.0 at 67 ms.
      expect(f[1].engage, closeTo(0.18, 0.15));
      expect(f[3].engage, greaterThan(0.9));
    });

    test('a press held 1 s, released in place: clear for about 0.12 s, '
        'then the release springs (research §4.1 trace)', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(94, 31));
      frames(m, 1);
      m.up(const Offset(94, 31));
      final f = frames(m, 0.25);
      // Native after the lift: frame → (w, h, opacityPair).
      const native = {
        2: (109.5, 69.5, 1.0),
        4: (105.1, 65.1, 1.0),
        6: (100.7, 60.7, 1.0),
        8: (97.9, 57.6, 0.93),
        10: (96.3, 55.7, 0.49),
        12: (95.5, 54.6, 0.25),
      };
      for (final MapEntry(key: k, value: (w, h, op)) in native.entries) {
        final fr = f[k - 1];
        // ±2.5 pt: one 60 fps frame of the release springs.
        expect(fr.lens.width, closeTo(w, 2.5), reason: 'w frame $k');
        expect(fr.lens.height, closeTo(h, 2.5), reason: 'h frame $k');
        expect(fr.engage, closeTo(op, 0.12), reason: 'engage frame $k');
      }
    });

    test('the finger glow answers 25 ms after the down and ripples on a '
        'critically damped 0.5 s curve (research LittleGlowView trace)', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(94, 31));
      final press = frames(m, 1);
      // opacity 0.059 / 0.225 / 0.273 at 33 / 66 / 99 ms.
      for (final (k, o) in [(2, 0.059), (4, 0.225), (6, 0.273)]) {
        expect(press[k - 1].glowOpacity, closeTo(o, 0.05), reason: 'k $k');
      }
      m.up(const Offset(94, 31));
      final ripple = frames(m, 0.6);
      final d0 = press.last.glowDiameter;
      // After the lift: (frame, diameter ×, opacity).
      for (final (k, x, o) in [
        (5, 1.54, 0.233),
        (9, 2.43, 0.149),
        (15, 3.34, 0.063),
        (21, 3.65, 0.033),
      ]) {
        final f = ripple[k - 1];
        expect(f.glowDiameter / d0, closeTo(x, x * 0.10), reason: 'x $k');
        expect(f.glowOpacity, closeTo(o, 0.03), reason: 'o $k');
      }
    });

    void flight(
      int from,
      double finger,
      Map<int, (double, double, double)> native,
    ) {
      final m = LensMotion(geometry: g3, selected: from)
        ..down(Offset(finger, 31));
      final f = frames(m, 0.4, (f) {
        if (f == 5) m.up(Offset(finger, 31));
      });
      for (final MapEntry(key: k, value: (x, w, h)) in native.entries) {
        final l = f[k - 1].lens;
        expect(l.center.dx, closeTo(x, 4), reason: 'x frame $k');
        expect(l.width, closeTo(w, w * 0.10), reason: 'w frame $k');
        expect(l.height, closeTo(h, h * 0.10), reason: 'h frame $k');
      }
    }

    test('a one-slot tap swells first, then lifts (research §3 trace)', () {
      flight(0, 180, const {
        4: (104.5, 95.7, 59.8),
        10: (157.2, 87.0, 80.0),
        12: (168.3, 84.8, 81.8),
        16: (179.0, 91.9, 77.9),
        20: (181.1, 95.3, 63.0),
      });
    });

    test('a two-slot tap stretches wide and low (research §3 trace)', () {
      flight(2, 94, const {
        4: (236.1, 102.6, 58.5),
        9: (147.5, 124.7, 57.2),
        11: (124.0, 127.4, 55.8),
        15: (101.1, 120.7, 61.5),
        19: (95.0, 106.6, 66.4),
      });
    });

    test('after a flick the lens stays clear until it lands, about 0.12 s '
        'after the release (spec §8.2 as amended; research trace)', () {
      // As the research run: a 0.33 s hold on Settings, then the finger
      // crosses 172 pt in 0.1 s and lifts on Home.
      final m = LensMotion(geometry: g3, selected: 2)
        ..down(const Offset(266, 31));
      frames(m, 1 / 3);
      // The native finger samples: 244, 190, 134, 94 at 0, 33, 67, 102 ms
      // (pill-local), 1470 pt/s from about 15 ms before the first.
      final f = frames(m, 0.1, (f) {
        m.move(Offset(math.max(94, 266 - 1470 * (f * dt + 0.015)), 31));
      });
      // Native: the lens at 191.8 when the finger lifts (ours lags about
      // 8 pt more: the fitted follow spring, spec §8.1).
      expect(f.last.lens.center.dx, closeTo(191.8, 10), reason: 'lagging');
      m.up(const Offset(94, 31), velocity: -1500);
      var landed = -1;
      final after = frames(m, 0.5);
      for (final (i, fr) in after.indexed) {
        if ((fr.lens.center.dx - 94).abs() <= 1) {
          landed = i;
          break;
        }
        expect(fr.engage, greaterThan(0.99), reason: 'frame $i in flight');
      }
      expect(landed, isNonNegative);
      // Native, pill-local: 8.4 pt short of Home 0.100 s after the release
      // and 5.1 pt at 0.115 s. ±6 pt is about one frame of this flight
      // (ours leaves from 8 pt further back).
      expect((after[5].lens.center.dx - 94).abs(), closeTo(8.4, 6));
      expect((after[6].lens.center.dx - 94).abs(), closeTo(5.1, 6));
      expect(m.committed, 0);
    });
  });

  group('minimize (research §6)', () {
    test(
      'collapse waits 0.24 s, then settles on the collapse spring ± 10 %',
      () {
        final m = MinimizeMotion(minimized: false)..set(true);
        final values = <double>[];
        for (var f = 0; f < 120; f++) {
          m.advance(dt);
          values.add(m.value);
        }
        expect(values[(0.2 / dt).floor()], 0);
        final ours = settleTime(values, 1, tolerance: 0.005);
        final reference = settleTime(
          referenceTrace(
            TabSprings.collapse,
            0,
            1,
            delay: TabSprings.minimizeDelay,
          ),
          1,
          tolerance: 0.005,
        );
        expect(ours, closeTo(reference, reference * 0.10));
      },
    );

    test('the dip reaches ×0.96 at the midpoint', () {
      final m = MinimizeMotion(minimized: false)..set(true, delayed: false);
      var lowest = 1.0;
      for (var f = 0; f < 60; f++) {
        m.advance(dt);
        if (m.dip < lowest) lowest = m.dip;
      }
      expect(lowest, closeTo(0.96, 0.005));
    });

    test('expand overshoots slightly below 0, then rests at 0', () {
      final m = MinimizeMotion(minimized: true)..set(false);
      var lowest = 1.0;
      for (var f = 0; f < 90; f++) {
        m.advance(dt);
        if (m.value < lowest) lowest = m.value;
      }
      expect(lowest, lessThan(0));
      expect(m.value, 0);
      expect(m.advance(dt), isFalse);
    });

    test('expand: the 3-tab pill right edge overshoots ≈ 4 pt, as native '
        '(VK-503 Task 16, TabFid expand strip; ζ 0.70 gave ≈ 12)', () {
      final m = MinimizeMotion(minimized: true)..set(false);
      var lowest = 1.0;
      for (var f = 0; f < 90; f++) {
        m.advance(dt);
        if (m.value < lowest) lowest = m.value;
      }
      // The glass rect is lerp(pill, minimized, morph): below 0 the right
      // edge extrapolates past the pill by −morph × its travel.
      final travel = g3.pill.right - g3.minimized.right;
      expect(-lowest * travel, closeTo(4, 1));
    });

    test('a quick reverse during the delay never collapses', () {
      final m = MinimizeMotion(minimized: false)
        ..set(true)
        ..advance(0.1)
        ..set(false);
      for (var f = 0; f < 60; f++) {
        m.advance(dt);
      }
      expect(m.value, 0);
    });

    test('reduce motion: instant', () {
      final m = MinimizeMotion(minimized: false)
        ..reduceMotion = true
        ..set(true);
      expect(m.value, 1);
      expect(m.advance(dt), isFalse);
    });
  });
}
