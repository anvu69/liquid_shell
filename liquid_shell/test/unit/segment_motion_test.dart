import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/chrome/lens_motion.dart';
import 'package:liquid_shell/src/chrome/lens_profile.dart';
import 'package:liquid_shell/src/segmented/segment_geometry.dart';

import '../helpers/native_rows.dart';
import '../helpers/segment_gate.dart';

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

    // The tap gate (spec §14.5; one implementation with the device table,
    // tool/segment_gate.dart) on every native tap the model is fitted to:
    // the fixture's five captures (light and dark, three and five
    // segments; Task 4), and the fitting split of the discriminating taps
    // (docs/qa/vk550/native_taps.json, pass 0: two, three and five
    // segments, left and right, LTR and RTL; Task 15 review). The engage
    // onset is checked on its own, within a frame (on 1 ms model samples
    // the engine's onset is exact). The rows are read on the device table's
    // clock since f1a4cb8: the gate's best-fit `tapClock`, which lets each
    // capture pick its own x shift within ±16.5 ms (§14.5), not the
    // engage-aligned clock.
    final discriminating = segmentTaps();
    final fitted = [
      ('tap_1_2', tapRowsOf(ref, 'tap_1_2'), 3, 0, 1, false),
      ('tap_2_3', tapRowsOf(ref, 'tap_2_3'), 3, 1, 2, false),
      ('tap_3_1', tapRowsOf(ref, 'tap_3_1'), 3, 2, 0, false),
      (
        'dark.tap_1_2',
        tapRowsOf(ref['dark'] as Map<String, dynamic>, 'tap_1_2'),
        3,
        0,
        1,
        false,
      ),
      ('tap_1_3_5seg', tapRowsOf(ref, 'tap_1_3_5seg'), 5, 0, 2, false),
      for (final c in discriminating.where((c) => c.split == 'fit'))
        ('${c.key} (fit)', c.rows, c.segments, c.from, c.to, c.rtl),
    ];

    // What the fitting split still misses (pinned; docs/qa/vk550/
    // acceptance.md): the slide and its overshoot on 5-segment taps longer
    // than the fixture's (222 and 296 pt), the two-segment control's x at
    // +0.25 s, and the w swing after a long tap to the right on five
    // segments. The lift rule passes every capture.
    const known = {
      'tap_1_5_5seg (fit)': {
        'x @200ms',
        'x @250ms',
        'x @450ms',
        'x @500ms',
        'overshoot',
        'w wobble',
      },
      'tap_5_1_5seg (fit)': {'x @200ms', 'x @250ms', 'overshoot'},
      'tap_1_4_5seg (fit)': {'overshoot', 'w wobble'},
      'tap_1_2_2seg (fit)': {'x @250ms'},
    };

    for (final (key, rows, count, from, to, rtl) in fitted) {
      test('the tap gate (spec §14.5), $key: x ±2 pt per row to +0.6 s, '
          'overshoot ±1 pt, settle, peak h and the wobble ±10 %', () {
        final m = ModelTap(
          count,
          from,
          to,
          direction: rtl ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(m.committed, to);
        // The engage onset, linear between the rows: within a frame.
        final ts = [for (var i = 0; i < m.frames.length; i++) i * 0.001];
        final engage =
            onset([for (final r in rows) r[0]], [for (final r in rows) r[4]])! -
            onset(ts, m.engage)!;
        expect(engage.abs(), lessThanOrEqualTo(dt), reason: 'engage $engage');
        // The rows on the device table's clock.
        final shift = tapClock(rows, m.ours);
        expect(tapClockPinned(shift), isFalse, reason: 'clock $shift');
        final failed = {
          for (final r in m.gate(rows, shift: shift))
            if (!gatePasses(r)) r.name,
        };
        expect(failed, known[key] ?? const <String>{}, reason: 'clock $shift');
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

  // Task 15 (Task 13 review): on the simulator `flick overshoot` read 2.77
  // / 2.96 / 3.11 against native's 3.86 ±1, its run-to-run spread from
  // where the finger's last frame before the lift falls ("tune against the
  // median of several flicks, not one run"). Driven as the simulator drives
  // it (tool/segment_frames.sh, the shared driver's `arrive`: native's
  // release time, 60 fps moves, the lift as it arrives, half a frame
  // early), over every frame phase, the median landing must sit inside
  // native's band. The phases themselves spread about 1 pt (reported in
  // docs/qa/vk550/acceptance.md).
  test('flickLanding, as the simulator drives it: the median overshoot over '
      "the frame phases is within native's ±1 pt", () {
    final landing = ref['flickLanding'] as Map<String, dynamic>;
    final releaseAt = (landing['release_at'] as num).toDouble();
    final to = (landing['landing'] as num).toDouble();
    final native = (landing['overshoot'] as num).toDouble();
    final thumb = (((ref['geometry'] as Map)['thumbs3'] as List)[2] as List)
        .cast<num>();
    final from = thumb[0] + thumb[2] / 2;
    final pace = (from - to) / (releaseAt - 1 / 120);
    final g = controlOf(3);
    final y = g.size.height / 2;
    final overshoots = <double>[];
    for (var i = 0; i < 20; i++) {
      final phase = i / 20;
      final m = LensMotion(
        geometry: g,
        selected: 2,
        profile: LensProfile.segment,
      )..down(Offset(from, y));
      var lifted = false;
      for (var k = 1; !lifted; k++) {
        final finger = from - pace * (k - phase) * dt;
        if (finger <= to) {
          expect(m.up(Offset(to, y)), 0);
          lifted = true;
        } else {
          m.move(Offset(finger, y));
        }
        m.advance(dt);
      }
      var lowest = m.frame.lens.center.dx;
      for (var j = 0; j < 90; j++) {
        m.advance(dt);
        lowest = math.min(lowest, m.frame.lens.center.dx);
      }
      overshoots.add(g.centreOf(0) - lowest);
    }
    overshoots.sort();
    final median = (overshoots[9] + overshoots[10]) / 2;
    expect(median, closeTo(native, 1), reason: 'phases $overshoots');
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
    final ours = onset(ts, engage)!;
    for (final rows in [
      rowsOf(ref, 'press'),
      rowsOf(ref['dark'] as Map<String, dynamic>, 'press'),
    ]) {
      final native = onset(
        [for (final r in rows) r.t],
        [
          for (final r in rows) r.engage,
        ],
      )!;
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

  test('the landing (spec §8.4): a fast release dips only after the lens '
      'passes its target; a slow release never dips', () {
    final g = controlOf(3);
    final y = g.size.height / 2;
    final rest = g.slots[0].height;
    List<LensFrame> release(double speed) {
      final m = LensMotion(
        geometry: g,
        selected: 2,
        profile: LensProfile.segment,
      )..down(Offset(g.centreOf(2), y));
      final travel = (g.centreOf(2) - g.centreOf(0)) / speed;
      record(
        m,
        travel,
        input: (t) => m.move(
          Offset(math.max(g.centreOf(0), g.centreOf(2) - speed * t), y),
        ),
      );
      m.up(Offset(g.centreOf(0), y), velocity: -speed);
      return record(m, 1.2);
    }

    final fast = release(530);
    final crossed = fast.indexWhere(
      (f) => f.lens.center.dx < g.centreOf(0),
    );
    expect(crossed, greaterThan(0));
    for (final f in fast.take(crossed)) {
      expect(f.lens.height, greaterThanOrEqualTo(rest), reason: 'no dip yet');
    }
    expect(
      fast.map((f) => f.lens.height).reduce(math.min),
      lessThan(rest * 0.9),
      reason: 'the landing dip',
    );
    final slow = release(82.2);
    expect(
      slow.map((f) => f.lens.height).reduce(math.min),
      greaterThan(rest - 0.5),
      reason: 'slow_drag: no landing',
    );
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
