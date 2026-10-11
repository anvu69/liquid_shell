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

    test('two slots: the peak is the native ×1.331 (stretchMax 1.46)', () {
      final m = LensMotion(geometry: g3, selected: 0)..tapSlot(2);
      var widest = 0.0;
      run(
        m,
        0.6,
        each: (_) {
          if (m.frame.lens.width > widest) widest = m.frame.lens.width;
        },
      );
      expect(TabSprings.stretchMax, 1.46);
      expect(widest / 94, closeTo(1.331, 0.005));
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

    test('the glow ripples ×4 and fades in 0.5 s', () {
      final m = LensMotion(geometry: g3, selected: 0)
        ..down(const Offset(94, 31));
      run(m, 0.5);
      final held = m.frame.glowDiameter;
      m.up(const Offset(94, 31));
      run(m, 0.25);
      expect(m.frame.glowDiameter, greaterThan(held * 2));
      run(m, 0.3);
      expect(m.frame.glowOpacity, 0);
      expect(m.frame.glowCenter, isNull);
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
