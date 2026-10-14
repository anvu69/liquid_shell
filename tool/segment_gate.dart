// The segmented control's tap gate (spec VK-550 §14.5) in one place: the
// device table (tool/segment_trace_compare.dart), and the model's tests
// against the fitted captures and the holdouts
// (liquid_shell/test/helpers/segment_gate.dart re-exports it). Pure Dart.
import 'dart:math' as math;

import 'trace_math.dart';

/// Tap rows are compared every 0.05 s to here (spec §14.5).
const double tapRowsTo = 0.6;

/// The tap clock's grid (0.5 ms) and its bound, the last grid step within
/// one frame (spec §14.5, amended 2026-10-14).
const double tapClockStep = 0.0005;

/// See [tapClockStep].
const int tapClockSteps = 33;

/// Row times are differences of fixture times: this absorbs their
/// rounding.
const double _eps = 1e-6;

/// One native row: t (seconds from valueChanged), lens centre x, w, h,
/// engage.
typedef TapRow = List<double>;

/// Flutter's [key] (`x`, `w` or `h`) at [t] seconds on its own clock from
/// the commit.
typedef TapSampler = double Function(double t, String key);

/// One comparison of the gate: its name without the capture's prefix,
/// Flutter's value against native's within `abs` or `rel`.
typedef GateRow = ({
  String name,
  double flutter,
  double native,
  double? abs,
  double? rel,
});

/// Whether [row] is within its tolerance.
bool gatePasses(GateRow row) => near(
  row.flutter,
  row.native,
  band(row.native, abs: row.abs, rel: row.rel),
);

/// The row times of [native] from its first row (the capture's t0).
List<double> tapTimes(List<TapRow> native) => [
  for (final r in native) r[0] - native.first[0],
];

/// The x rows of [native] the clock and the x rows read: to [tapRowsTo].
List<int> tapXRows(List<TapRow> native) {
  final ts = tapTimes(native);
  return [
    for (var i = 0; i < native.length; i++)
      if (ts[i] <= tapRowsTo + _eps) i,
  ];
}

/// The device table's clock (spec §14.5, amended 2026-10-14): the shift on
/// a 0.5 ms grid within ±16.5 ms that best fits Flutter's x ([ours]) to the
/// x rows of [native], least squares. Flutter is read at `t − shift`.
double tapClock(List<TapRow> native, TapSampler ours) {
  final rows = tapXRows(native);
  final ts = tapTimes(native);
  return bestShift(
    (s) => rows.fold(
      0,
      (sum, i) => sum + math.pow(ours(ts[i] - s, 'x') - native[i][1], 2),
    ),
    from: -tapClockSteps,
    steps: 2 * tapClockSteps,
    step: tapClockStep,
  );
}

/// Whether [shift] sits on the clock's bound: the two are more than a
/// frame apart, and the `clock` condition fails.
bool tapClockPinned(double shift) =>
    shift.abs() >= tapClockSteps * tapClockStep - _eps;

/// The gate's comparisons of one tap capture (spec §14.5): x at every row
/// to [tapRowsTo], the overshoot (±1 pt), the settle time (±10 %), the
/// peak height and, once x passes its rest, the extremes of w and h
/// against native's at the same rows (±10 %). Flutter is read at
/// `t − shift`; [ourXs] is every Flutter x from the commit on, [ourFrom]
/// its first and [ourRest] its resting x.
List<GateRow> tapGateRows(
  List<TapRow> native,
  TapSampler ours, {
  required double shift,
  required List<double> ourXs,
  required double ourFrom,
  required double ourRest,
}) {
  double at(double t, String key) => ours(t - shift, key);
  final ts = tapTimes(native);
  final xs = [for (final r in native) r[1]];
  final from = xs.first;
  final rest = xs.last;
  final sign = (rest - from).sign;
  final rows = <GateRow>[
    for (final i in tapXRows(native))
      (
        name: 'x @${(ts[i] * 1000).round()}ms',
        flutter: at(ts[i], 'x'),
        native: xs[i],
        abs: 2,
        rel: null,
      ),
    (
      name: 'overshoot',
      flutter: overshoot(ourXs, ourFrom, ourRest),
      native: overshoot(xs, from, rest),
      abs: 1,
      rel: null,
    ),
    (
      name: 'settle',
      flutter: settle([for (final t in ts) at(t, 'x')], ourRest, ts: ts),
      native: settle(xs, rest, ts: ts),
      abs: null,
      rel: 0.10,
    ),
    (
      name: 'peak h',
      flutter: [for (final t in ts) at(t, 'h')].reduce(math.max),
      native: [for (final r in native) r[3]].reduce(math.max),
      abs: null,
      rel: 0.10,
    ),
  ];
  // The wobble (spec §8.4): once x passes its rest, the size swings past
  // its own; the extreme of each, against native's at the same rows.
  final past = math.max(0, native.indexWhere((r) => (r[1] - rest) * sign > 0));
  for (final (key, column) in [('w', 2), ('h', 3)]) {
    final restValue = native.last[column];
    final extreme = [
      for (final r in native.skip(past)) r[column],
    ].reduce((a, b) => (b - restValue).abs() > (a - restValue).abs() ? b : a);
    final values = [
      for (var i = past; i < native.length; i++) at(ts[i], key),
    ];
    rows.add((
      name: '$key wobble',
      flutter: values.reduce(extreme < restValue ? math.min : math.max),
      native: extreme,
      abs: null,
      rel: 0.10,
    ));
  }
  return rows;
}
