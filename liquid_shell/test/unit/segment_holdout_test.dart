// The segment model against native tap repeats it was never fitted to
// (spec VK-550 §14.5, Task 15): docs/qa/vk550/native_holdout.json, captured
// after every fit. The gate of the fitted captures: x ±2 pt per row to
// +0.6 s on the device table's clock (the least-squares x shift within ±1
// frame), overshoot ±1 pt, settle ±10 %, peak h and the wobble extremes
// ±10 %.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/chrome/lens_motion.dart';
import 'package:liquid_shell/src/chrome/lens_profile.dart';
import 'package:liquid_shell/src/segmented/segment_geometry.dart';

import '../helpers/native_rows.dart';

const double _dt = 1 / 60;
const double _ms = 0.001;

/// The first row time after which every row stays within 0.5 pt of [rest].
double _settle(List<double> ts, List<double> xs, double rest) {
  var settled = ts.first;
  for (var i = 0; i < xs.length; i++) {
    if ((xs[i] - rest).abs() > 0.5) {
      settled = i + 1 < ts.length ? ts[i + 1] : ts[i];
    }
  }
  return settled;
}

/// One gate check: ours against native's.
typedef _Check = ({String name, double ours, double native, bool pass});

/// Every gate check of capture [c] against [LensProfile.segment].
List<_Check> _gate(Map<String, dynamic> c) {
  final rows = rowsOf({'c': c}, 'c');
  final count = c['segments'] as int;
  final from = c['from'] as int;
  final to = c['to'] as int;
  final g = segmentGeometry(
    count: count,
    maxWidth: 370,
    lineHeight: 15.67,
    direction: TextDirection.ltr,
  );
  final m = LensMotion(
    geometry: g,
    selected: from,
    profile: LensProfile.segment,
  );
  final finger = Offset(g.centreOf(to), g.size.height / 2);
  m
    ..down(finger)
    ..advance(_dt);
  expect(m.up(finger), to);
  final frames = [m.frame];
  for (var i = 1; i <= 1500; i++) {
    m.advance(_ms);
    frames.add(m.frame);
  }
  LensFrame frameAt(double t) =>
      frames[(t / _ms).round().clamp(0, frames.length - 1)];
  final checks = <_Check>[];
  void check(String name, double ours, double native, double tolerance) =>
      checks.add((
        name: name,
        ours: ours,
        native: native,
        pass: (ours - native).abs() <= tolerance,
      ));

  // The device table's clock (spec §14.5): a 0.5 ms grid within ±16.5 ms.
  final xRows = rows.where((r) => r.t <= 0.6).toList();
  var shift = 0.0;
  var best = double.infinity;
  for (var k = -33; k <= 33; k++) {
    var e = 0.0;
    for (final r in xRows) {
      e += math.pow(frameAt(r.t - k * 0.0005).lens.center.dx - r.x, 2);
    }
    if (e < best) {
      best = e;
      shift = k * 0.0005;
    }
  }
  check('clock', shift.abs() < 0.0165 ? 0 : shift, 0, 0);
  LensFrame at(double t) => frameAt(t - shift);
  for (final r in xRows) {
    check('x @${(r.t * 1000).round()}ms', at(r.t).lens.center.dx, r.x, 2);
  }
  final sign = (to - from).sign;
  final rest = g.centreOf(to);
  check(
    'overshoot',
    [for (final f in frames) sign * (f.lens.center.dx - rest)].reduce(math.max),
    [for (final r in rows) sign * (r.x - rows.last.x)].reduce(math.max),
    1,
  );
  final ts = [for (final r in rows) r.t];
  final nativeSettle = _settle(ts, [for (final r in rows) r.x], rows.last.x);
  check(
    'settle',
    _settle(ts, [for (final t in ts) at(t).lens.center.dx], rest),
    nativeSettle,
    nativeSettle * 0.10,
  );
  final nativePeak = rows.map((r) => r.h).reduce(math.max);
  check(
    'peak h',
    [for (final t in ts) at(t).lens.height].reduce(math.max),
    nativePeak,
    nativePeak * 0.10,
  );
  final past = math.max(
    0,
    rows.indexWhere((r) => (r.x - rows.last.x) * sign > 0),
  );
  for (final (name, nativeOf, ourOf) in [
    ('w', (NativeRow r) => r.w, (LensFrame f) => f.lens.width),
    ('h', (NativeRow r) => r.h, (LensFrame f) => f.lens.height),
  ]) {
    final restValue = nativeOf(rows.last);
    final extreme = rows
        .skip(past)
        .map(nativeOf)
        .reduce(
          (a, b) => (b - restValue).abs() > (a - restValue).abs() ? b : a,
        );
    final values = [for (final r in rows.skip(past)) ourOf(at(r.t))];
    check(
      '$name wobble',
      extreme < restValue ? values.reduce(math.min) : values.reduce(math.max),
      extreme,
      extreme.abs() * 0.10,
    );
  }
  return checks;
}

void main() {
  final holdout =
      jsonDecode(
            File('../docs/qa/vk550/native_holdout.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final captures = (holdout['captures'] as List).cast<Map<String, dynamic>>();
  const fitted = {
    'tap_1_2',
    'tap_2_3',
    'tap_3_1',
    'dark.tap_1_2',
    'tap_1_3_5seg',
  };

  test('the holdout repeats every fitted tap three times', () {
    for (final key in fitted) {
      expect(
        captures.where((c) => c['key'] == key),
        hasLength(3),
        reason: key,
      );
    }
  });

  // The kinds the model was fitted on, three fresh repeats each: every
  // check passes.
  for (final c in captures.where((c) => fitted.contains(c['key']))) {
    test('holdout ${c['key']} #${c['repeat']}: the whole gate passes', () {
      final failed = _gate(c).where((k) => !k.pass);
      expect(failed, isEmpty, reason: '$failed');
    });
  }

  // Two kinds no fitted capture has, both leftward over a short distance:
  // `dark.tap_2_1` (123 pt) and `tap_3_1_5seg` (148 pt). Native lifts them
  // tall (peak h 48.6 to 49.9, as `tap_3_1`'s 247 pt), so its lift follows
  // the direction, not the distance the model reads (Task 15): our peak is
  // 37.8, and the h wobble swings the other way where native's dips below
  // rest. A known residual (docs/qa/vk550/acceptance.md): exactly these
  // checks fail. If the model learns the direction, this test fails and
  // the residual goes.
  const known = {
    'dark.tap_2_1 #1': {'peak h', 'h wobble'},
    'dark.tap_2_1 #3': {'peak h', 'h wobble'},
    'dark.tap_2_1 #5': {'peak h', 'h wobble'},
    'tap_3_1_5seg #1': {'peak h', 'h wobble'},
    'tap_3_1_5seg #3': {'peak h'},
    'tap_3_1_5seg #5': {'peak h'},
  };
  for (final c in captures.where((c) => !fitted.contains(c['key']))) {
    test('holdout ${c['key']} #${c['repeat']}: only the known lift checks '
        'fail', () {
      final checks = _gate(c);
      final failed = {for (final k in checks.where((k) => !k.pass)) k.name};
      expect(failed, known['${c['key']} #${c['repeat']}'], reason: '$checks');
    });
  }
}
