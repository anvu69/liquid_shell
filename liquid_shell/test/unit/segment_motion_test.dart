import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/chrome/lens_motion.dart';
import 'package:liquid_shell/src/chrome/lens_profile.dart';
import 'package:liquid_shell/src/segmented/segment_geometry.dart';

import '../helpers/native_rows.dart';

const double dt = 1 / 60;

/// The fixture's control: 370 wide at text scale 1 (spike §2). x is
/// track-local, as the fixture's (the track starts at the control's left);
/// the thumbs sit 8 below the 44 box's top, so rows compare x, w and h.
SegmentGeometry controlOf(int count) => segmentGeometry(
  count: count,
  maxWidth: 370,
  lineHeight: 15.67,
  direction: TextDirection.ltr,
);

/// The frame at [t] seconds into [frames] (frame 0 is the state before
/// the first advance).
LensFrame at(List<LensFrame> frames, double t) => frames[(t / dt).round()];

/// Frame 0 (now) and then [seconds] of frames; [input] runs before each
/// advance with that frame's end time, as pointer events reach the model
/// between vsyncs.
List<LensFrame> record(
  LensMotion m,
  double seconds, {
  void Function(double t)? input,
}) {
  final frames = [m.frame];
  for (var f = 1; f <= (seconds / dt).round(); f++) {
    input?.call(f * dt);
    m.advance(dt);
    frames.add(m.frame);
  }
  return frames;
}

/// The first row time after which every row stays within 0.5 pt of [rest]
/// (rows on the fixture's 0.05 s grid).
double settleOf(List<double> ts, List<double> xs, double rest) {
  var settled = ts.first;
  for (var i = 0; i < xs.length; i++) {
    if ((xs[i] - rest).abs() > 0.5) {
      settled = i + 1 < ts.length ? ts[i + 1] : ts[i];
    }
  }
  return settled;
}

/// The 0.5 crossing of [engage] over [ts], linear between samples.
double onsetOf(List<double> ts, List<double> engage) {
  for (var i = 1; i < ts.length; i++) {
    if (engage[i - 1] < 0.5 && engage[i] >= 0.5) {
      return ts[i - 1] +
          (0.5 - engage[i - 1]) /
              (engage[i] - engage[i - 1]) *
              (ts[i] - ts[i - 1]);
    }
  }
  throw StateError('engage never reaches 0.5');
}

void main() {
  final ref = segmentReference();

  group('tap (spec VK-550 §8.3, §8.4)', () {
    const taps = [('tap_1_2', 0, 1), ('tap_2_3', 1, 2), ('tap_3_1', 2, 0)];

    /// The rows of [key] and our frames at their times: [from] selected, a
    /// press on [to], the up one frame later (t from the up, the commit).
    (List<NativeRow>, List<LensFrame>, LensMotion) tap(
      String key,
      int from,
      int to,
    ) {
      final rows = rowsOf(ref, key);
      final g = controlOf(3);
      final m = LensMotion(
        geometry: g,
        selected: from,
        profile: LensProfile.segment,
      );
      final finger = Offset(g.centreOf(to), g.size.height / 2);
      m
        ..down(finger)
        ..advance(dt);
      expect(m.up(finger), to, reason: 'commit at the up');
      final frames = record(m, rows.last.t);
      return (rows, [for (final r in rows) at(frames, r.t)], m);
    }

    for (final (key, from, to) in taps) {
      test('$key: peak h, landing and rest against the native rows', () {
        final (rows, ours, m) = tap(key, from, to);
        final nativeMaxH = rows.map((r) => r.h).reduce(math.max);
        final maxH = ours.map((f) => f.lens.height).reduce(math.max);
        expect(maxH, closeTo(nativeMaxH, nativeMaxH * 0.10), reason: 'max h');

        if ((to - from).abs() == 1) {
          // The landing: the first row within 5 pt of the resting x.
          final land = rows.indexWhere((r) => (r.x - rows.last.x).abs() < 5);
          final nativeMinW = rows.skip(land).map((r) => r.w).reduce(math.min);
          final minW = ours
              .skip(land)
              .map((f) => f.lens.width)
              .reduce(math.min);
          expect(
            minW,
            closeTo(nativeMinW, nativeMinW * 0.10),
            reason: 'min w after the landing',
          );
        }
        // At native's last row (+0.9 s) the wobble is over: w and h within
        // the 2 pt row tolerance of it.
        expect(ours.last.lens.width, closeTo(rows.last.w, 2), reason: 'w');
        expect(ours.last.lens.height, closeTo(rows.last.h, 2), reason: 'h');
        expect(ours.last.lens.center.dx, closeTo(rows.last.x, 1), reason: 'x');
        expect(m.committed, to);
      });
    }

    /// Every native tap capture: light and dark, two and five segments.
    final captures = [
      ('tap_1_2', rowsOf(ref, 'tap_1_2'), 3, 0, 1),
      ('tap_2_3', rowsOf(ref, 'tap_2_3'), 3, 1, 2),
      ('tap_3_1', rowsOf(ref, 'tap_3_1'), 3, 2, 0),
      (
        'dark.tap_1_2',
        rowsOf(ref['dark'] as Map<String, dynamic>, 'tap_1_2'),
        3,
        0,
        1,
      ),
      ('tap_1_3_5seg', rowsOf(ref, 'tap_1_3_5seg'), 5, 0, 2),
    ];

    for (final (key, rows, count, from, to) in captures) {
      test('the tap gate (spec §14.5), $key: x ±2 pt per row to +0.6 s, '
          'overshoot ±1 pt, settle ±10 %, on the engage-aligned clock', () {
        final g = controlOf(count);
        final y = g.size.height / 2;
        LensMotion tapped() {
          final m = LensMotion(
            geometry: g,
            selected: from,
            profile: LensProfile.segment,
          );
          final finger = Offset(g.centreOf(to), y);
          m
            ..down(finger)
            ..advance(dt);
          expect(m.up(finger), to);
          return m;
        }

        // Our clock: 1 ms samples from the commit to +1.5 s.
        const ms = 0.001;
        final m = tapped();
        final ourTs = <double>[0];
        final ourXs = [m.frame.lens.center.dx];
        final ourEngage = [m.frame.engage];
        for (var i = 1; i <= 1500; i++) {
          m.advance(ms);
          ourTs.add(i * ms);
          ourXs.add(m.frame.lens.center.dx);
          ourEngage.add(m.frame.engage);
        }

        // Spec §14.5 alignment: a capture's t0 (valueChanged) sits up to a
        // frame off the display link, which engage shows whatever the
        // travel. Its rows move by its engage onset minus ours, at most
        // one frame.
        final shift =
            onsetOf(
              [for (final r in rows) r.t],
              [
                for (final r in rows) r.engage,
              ],
            ) -
            onsetOf(ourTs, ourEngage);
        expect(shift.abs(), lessThanOrEqualTo(dt), reason: 'shift $shift');
        double ourAt(double t) {
          final i = ((t - shift) / ms).round().clamp(0, ourXs.length - 1);
          return ourXs[i];
        }

        for (final r in rows.where((r) => r.t <= 0.6)) {
          expect(
            ourAt(r.t),
            closeTo(r.x, 2),
            reason: 'x at +${r.t} s (shift ${shift.toStringAsFixed(4)})',
          );
        }
        final sign = (to - from).sign.toDouble();
        final rest = g.centreOf(to);
        final ours = ourXs.map((x) => sign * (x - rest)).reduce(math.max);
        final native = rows
            .map((r) => sign * (r.x - rows.last.x))
            .reduce(math.max);
        expect(ours, closeTo(native, 1), reason: 'overshoot');
        final ts = [for (final r in rows) r.t];
        // Native's rest is its last row (unchanged over the last two).
        final nativeSettle = settleOf(ts, [
          for (final r in rows) r.x,
        ], rows.last.x);
        expect(
          settleOf(ts, [for (final t in ts) ourAt(t)], rest),
          closeTo(nativeSettle, nativeSettle * 0.10),
          reason: 'settle',
        );
      });
    }

    test('a tap on the selected segment grows in place and lets go '
        '(tapOnSelected)', () {
      final rows = rowsOf(ref, 'tapOnSelected');
      final g = controlOf(3);
      final finger = Offset(rows.first.x, g.size.height / 2);
      final m = LensMotion(
        geometry: g,
        selected: 0,
        profile: LensProfile.segment,
      )..down(finger);
      // idb's tap: down, up 70 ms later; t from the down.
      final frames = record(
        m,
        rows.last.t,
        input: (t) {
          if (m.interacting && t >= 0.07) m.up(finger);
        },
      );
      for (final r in rows) {
        final f = at(frames, r.t);
        expect(f.lens.center.dx, closeTo(r.x, 2), reason: 'x at +${r.t} s');
        expect(f.lens.width, closeTo(r.w, 2), reason: 'w at +${r.t} s');
        expect(f.lens.height, closeTo(r.h, 2), reason: 'h at +${r.t} s');
      }
      expect(m.committed, 0);
    });
  });

  test('press on the selected segment: size and engage per native row, no '
      'glow, no pill scale, no pop', () {
    final rows = rowsOf(ref, 'press');
    final g = controlOf(3);
    final m = LensMotion(
      geometry: g,
      selected: 0,
      profile: LensProfile.segment,
    )..down(Offset(rows.first.x, g.size.height / 2));
    final frames = record(m, rows.last.t);
    for (final r in rows) {
      final f = at(frames, r.t);
      expect(f.lens.center.dx, closeTo(r.x, 2), reason: 'x at +${r.t} s');
      expect(f.lens.width, closeTo(r.w, 2), reason: 'w at +${r.t} s');
      expect(f.lens.height, closeTo(r.h, 2), reason: 'h at +${r.t} s');
      if (r.engage == 1) {
        expect(f.engage, closeTo(1, 0.12), reason: 'engage at +${r.t} s');
      }
      // The w500 copy is not magnified under the lens (Task 1).
      expect(f.magnify, (ref['lens'] as Map)['labelMagnify']);
      expect(f.glowOpacity, 0);
      expect(f.pillScale, 1);
      expect(f.highlight, 0);
      expect(f.popScale, 1);
    }
  });

  test('press engage onset (0.5) within one frame of native, light and '
      'dark (spec §14.5 "Engage in")', () {
    final g = controlOf(3);
    final m = LensMotion(
      geometry: g,
      selected: 0,
      profile: LensProfile.segment,
    )..down(Offset(g.centreOf(0), g.size.height / 2));
    final ts = <double>[0];
    final engage = [m.frame.engage];
    for (var i = 1; i <= 150; i++) {
      m.advance(0.001);
      ts.add(i * 0.001);
      engage.add(m.frame.engage);
    }
    final ours = onsetOf(ts, engage);
    for (final rows in [
      rowsOf(ref, 'press'),
      rowsOf(ref['dark'] as Map<String, dynamic>, 'press'),
    ]) {
      final native = onsetOf(
        [for (final r in rows) r.t],
        [
          for (final r in rows) r.engage,
        ],
      );
      expect(ours, closeTo(native, dt), reason: 'native onset $native');
    }
  });

  test('press on another segment: nothing moves until the up (pressOther)', () {
    final other = ref['pressOther'] as Map<String, dynamic>;
    final rows = rowsOf(ref, 'pressOther');
    final releaseAt = (other['release_at'] as num).toDouble();
    final g = controlOf(3);
    final m = LensMotion(
      geometry: g,
      selected: other['from'] as int,
      profile: LensProfile.segment,
    )..down(Offset(g.centreOf(other['pressed'] as int), g.size.height / 2));
    final frames = record(m, releaseAt);
    for (final r in rows.where((r) => r.t < releaseAt)) {
      final f = at(frames, r.t);
      expect(f.lens.center.dx, closeTo(r.x, 2), reason: 'x at +${r.t} s');
      expect(f.lens.width, closeTo(r.w, 2), reason: 'w at +${r.t} s');
      expect(f.lens.height, closeTo(r.h, 2), reason: 'h at +${r.t} s');
      expect(f.engage, r.engage, reason: 'engage at +${r.t} s');
    }
  });

  test('release in place after 1 s: size and engage per native row', () {
    final rows = rowsOf(ref, 'release');
    final g = controlOf(3);
    final finger = Offset(rows.first.x, g.size.height / 2);
    final m = LensMotion(
      geometry: g,
      selected: 0,
      profile: LensProfile.segment,
    )..down(finger);
    record(m, 1);
    expect(m.up(finger), 0);
    final frames = record(m, rows.last.t);
    for (final r in rows) {
      final f = at(frames, r.t);
      expect(f.lens.width, closeTo(r.w, 2), reason: 'w at +${r.t} s');
      expect(f.lens.height, closeTo(r.h, 2), reason: 'h at +${r.t} s');
      expect(f.engage, closeTo(r.engage, 0.12), reason: 'engage +${r.t} s');
    }
  });

  group('drag (spec VK-550 §8.3)', () {
    final lag = (ref['fits'] as Map)['dragLag'] as Map;
    final speed = (lag['speed'] as num).toDouble();
    final g = controlOf(3);
    final start = g.centreOf(0);
    final end = g.centreOf(2);
    final travel = (end - start) / speed;

    test('lag at the native drag speed; one crossing per boundary', () {
      final m = LensMotion(
        geometry: g,
        selected: 0,
        profile: LensProfile.segment,
      )..down(Offset(start, g.size.height / 2));
      final lags = <double>[];
      final crossings = <int>[];
      final frames = record(
        m,
        travel,
        input: (t) {
          m.move(Offset(start + speed * t, g.size.height / 2));
          crossings.addAll(m.takeCrossings());
        },
      );
      for (var f = 1; f < frames.length; f++) {
        final t = f * dt;
        // The steady part: past the slop and the follow spring's ramp.
        if (t < 1 || t > travel - 0.1) continue;
        // The harness holds the finger at the frame's end value: it leads
        // the continuous ramp by half a frame (as the tab lag test).
        lags.add(start + speed * (t + dt / 2) - frames[f].lens.center.dx);
      }
      crossings.addAll(m.takeCrossings());
      final mean = lags.reduce((a, b) => a + b) / lags.length;
      final native = (lag['lag'] as num).toDouble();
      expect(mean, closeTo(native, native * 0.10));
      expect(crossings, [1, 2]);
    });

    test('slow drag release: x, w and h per native release row', () {
      final drag = ref['slow_drag'] as Map<String, dynamic>;
      final rows = rowsOf(ref, 'slow_drag', field: 'release_rows');
      final m = LensMotion(
        geometry: g,
        selected: 0,
        profile: LensProfile.segment,
      )..down(Offset(start, g.size.height / 2));
      record(
        m,
        travel,
        input: (t) =>
            m.move(Offset(math.min(end, start + speed * t), g.size.height / 2)),
      );
      // The finger rests at the end until the lens is where native's was at
      // the up (idb lifts a moment after its last move).
      for (var i = 0; i < 60 && m.frame.lens.center.dx < rows.first.x; i++) {
        m.advance(dt);
      }
      expect(m.up(Offset(end, g.size.height / 2)), drag['commit']);
      final frames = record(m, rows.last.t);
      for (final r in rows) {
        final f = at(frames, r.t);
        expect(f.lens.center.dx, closeTo(r.x, 2), reason: 'x at +${r.t} s');
        expect(f.lens.width, closeTo(r.w, 2), reason: 'w at +${r.t} s');
        expect(f.lens.height, closeTo(r.h, 2), reason: 'h at +${r.t} s');
      }
    });

    test('flick: commits the finger segment, native overshoot ± 1 pt', () {
      final flick = ref['flick'] as Map<String, dynamic>;
      final landing = ref['flickLanding'] as Map<String, dynamic>;
      final releaseAt = (flick['release_at'] as num).toDouble();
      final velocity = (start - end) / releaseAt;
      final m = LensMotion(
        geometry: g,
        selected: 2,
        profile: LensProfile.segment,
      )..down(Offset(end, g.size.height / 2));
      double fingerAt(double t) => end + velocity * math.min(t, releaseAt);
      record(
        m,
        releaseAt,
        input: (t) => m.move(Offset(fingerAt(t), g.size.height / 2)),
      );
      expect(
        m.up(Offset(start, g.size.height / 2), velocity: velocity),
        flick['commit'],
      );
      final xs = [for (final f in record(m, 1.2)) f.lens.center.dx];
      expect(
        g.centreOf(0) - xs.reduce(math.min),
        closeTo((landing['overshoot'] as num).toDouble(), 1),
      );
      expect(xs.last, closeTo(g.centreOf(0), 0.5));
    });
  });

  test('programmatic (two segments): slides per native row, no engage, no '
      'resize', () {
    final rows = rowsOf(ref, 'programmatic_2seg');
    final g = controlOf(2);
    final m = LensMotion(
      geometry: g,
      selected: 0,
      profile: LensProfile.segment,
    )..show(1);
    final frames = record(m, rows.last.t);
    for (final r in rows) {
      final f = at(frames, r.t);
      expect(f.lens.center.dx, closeTo(r.x, 2), reason: 'x at +${r.t} s');
      expect(f.lens.width, closeTo(r.w, 1), reason: 'w at +${r.t} s');
      expect(f.lens.height, closeTo(r.h, 1), reason: 'h at +${r.t} s');
      expect(f.engage, 0, reason: 'engage at +${r.t} s');
    }
  });

  test('show() mid-flight ends the tap lift and the flick hold: engage '
      'falls at once and the lens slides to rest', () {
    final g = controlOf(3);
    final y = g.size.height / 2;
    final tap =
        LensMotion(geometry: g, selected: 0, profile: LensProfile.segment)
          ..down(Offset(g.centreOf(2), y))
          ..advance(dt)
          ..up(Offset(g.centreOf(2), y));
    final flick = LensMotion(
      geometry: g,
      selected: 2,
      profile: LensProfile.segment,
    )..down(Offset(g.centreOf(2), y));
    for (var i = 1; i <= 8; i++) {
      flick
        ..move(Offset(g.centreOf(2) - 25.0 * i, y))
        ..advance(dt);
    }
    flick.up(Offset(g.centreOf(0), y), velocity: -1500);
    for (final m in [tap, flick]) {
      record(m, 0.1);
      expect(m.frame.engage, greaterThan(0.9), reason: 'engaged mid-flight');
      m.show(1);
      final frames = record(m, 1.5);
      expect(at(frames, 0.1).engage, lessThan(0.5), reason: 'no hold');
      final lens = frames.last.lens;
      expect(lens.center.dx, closeTo(g.centreOf(1), 1e-9));
      expect(lens.size.width, closeTo(g.slots[1].width, 1e-9));
      expect(lens.size.height, closeTo(g.slots[1].height, 1e-9));
      expect(frames.last.engage, 0);
      expect(m.phase, LensPhase.rest);
      expect(m.committed, 1);
    }
  });

  test('an up never commits a slot canCommit refuses: the nearest allowed '
      'one wins, after a drag and after a flick (spec §8.3)', () {
    final g = controlOf(3);
    final y = g.size.height / 2;
    bool notTwo(int slot) => slot != 2;
    // A slow drag that leaves the lens on slot 2: slot 1 is nearer than 0.
    final drag = LensMotion(
      geometry: g,
      selected: 0,
      profile: LensProfile.segment,
    )..down(Offset(g.centreOf(0), y));
    record(
      drag,
      2,
      input: (t) => drag.move(
        Offset(math.min(g.centreOf(2), g.centreOf(0) + 300 * t), y),
      ),
    );
    expect(drag.frame.lens.center.dx, closeTo(g.centreOf(2), 1));
    expect(drag.up(Offset(g.centreOf(2), y), canCommit: notTwo), 1);
    expect(drag.committed, 1);
    // A flick lands on the finger's slot, or the nearest allowed to it.
    final flick = LensMotion(
      geometry: g,
      selected: 0,
      profile: LensProfile.segment,
    )..down(Offset(g.centreOf(0), y));
    for (var i = 1; i <= 8; i++) {
      flick
        ..move(Offset(g.centreOf(0) + 30.0 * i, y))
        ..advance(dt);
    }
    expect(
      flick.up(Offset(g.centreOf(2), y), velocity: 1500, canCommit: notTwo),
      1,
    );
    // Nothing allowed: no commit, the lens goes back.
    final none = LensMotion(
      geometry: g,
      selected: 0,
      profile: LensProfile.segment,
    )..down(Offset(g.centreOf(1), y));
    expect(none.up(Offset(g.centreOf(1), y), canCommit: (_) => false), null);
    expect(none.committed, 0);
    expect(none.pending, null);
  });

  group("follow: the app's selection, once per build (spec §8.3)", () {
    final g = controlOf(3);
    final y = g.size.height / 2;

    test('a commit the app adopts is accepted; nothing moves anew', () {
      final m =
          LensMotion(
              geometry: g,
              selected: 0,
              profile: LensProfile.segment,
            )
            ..down(Offset(g.centreOf(2), y))
            ..up(Offset(g.centreOf(2), y));
      expect(m.pending, 2);
      expect(m.follow(2), isFalse);
      expect(m.pending, isNull);
      expect(m.committed, 2);
    });

    test('a commit the app has not answered yet is left to the ticker', () {
      final m =
          LensMotion(
              geometry: g,
              selected: 0,
              profile: LensProfile.segment,
            )
            ..down(Offset(g.centreOf(2), y))
            ..up(Offset(g.centreOf(2), y));
      expect(m.follow(0), isFalse);
      expect(m.pending, 2, reason: 'LensTicker returns it at rest');
    });

    test("the app's own change slides (true: tick it); the same index and "
        'a finger down do nothing', () {
      final m = LensMotion(
        geometry: g,
        selected: 0,
        profile: LensProfile.segment,
      );
      expect(m.follow(0), isFalse);
      expect(m.follow(1), isTrue);
      expect(m.committed, 1);
      expect(m.phase, LensPhase.flying);
      final held = LensMotion(
        geometry: g,
        selected: 0,
        profile: LensProfile.segment,
      )..down(Offset(g.centreOf(0), y));
      expect(held.follow(1), isFalse);
      expect(held.committed, 0);
    });

    test('the tab profile jumps: nothing to tick', () {
      final m = LensMotion(geometry: g, selected: 0);
      expect(m.follow(2), isFalse);
      expect(m.committed, 2);
      expect(m.frame.lens.center.dx, g.centreOf(2));
    });
  });

  test('reduce motion: a tap dissolves in 150 ms, no lift (spec §12.2)', () {
    final g = controlOf(3);
    final m = LensMotion(
      geometry: g,
      selected: 0,
      profile: LensProfile.segment,
      reduceMotion: true,
    );
    final finger = Offset(g.centreOf(2), g.size.height / 2);
    m
      ..down(finger)
      ..advance(dt)
      ..up(finger);
    final frames = record(m, 0.5);
    final rest = g.slots[2];
    for (final f in frames) {
      expect(f.lens.height, lessThanOrEqualTo(rest.height + 1e-9));
      expect(f.engage, 0);
    }
    expect(frames.first.lens.center.dx, g.centreOf(2));
    expect(frames.first.ghost, g.slots[0]);
    expect(at(frames, 0.15 - dt).ghostOpacity, greaterThan(0));
    expect(at(frames, 0.15 + dt).ghost, isNull);
    expect(at(frames, 0.15 + dt).restOpacity, 1);
  });
}
