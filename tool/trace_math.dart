// The trace arithmetic both acceptance tables share: the tab bar's
// (tool/tab_trace_compare.dart, spec VK-503 §17.4) and the segmented
// control's (tool/segment_trace_compare.dart, spec VK-550 §14.5). A trace
// is a list of samples, one per engine frame, each a map of `t` (seconds)
// and the sample's values. Pure Dart.
import 'dart:math' as math;

/// One check's outcome.
typedef Check = ({bool pass, String detail});

/// What a row compares against.
enum Kind {
  /// Independent native data (the research traces, frames or pixels), and
  /// the Flutter value comes out of the model: it can fail.
  native('native'),

  /// Native data, but the Flutter value is set to it by a constant: only
  /// the plumbing can fail.
  constant('native, constant'),

  /// Flutter against a fitted spring: a bug detector, not native evidence.
  fit('fit');

  const Kind(this.label);

  /// The table label.
  final String label;
}

/// Closed-form step response of a unit-mass spring of damping ratio
/// [zeta] and period [response], from 0 toward [distance], at [t].
double springAt(double distance, double zeta, double response, double t) {
  if (t <= 0) return 0;
  final w = 2 * math.pi / response;
  if (zeta < 1) {
    final wd = w * math.sqrt(1 - zeta * zeta);
    final e = math.exp(-zeta * w * t);
    return distance *
        (1 - e * (math.cos(wd * t) + zeta * w / wd * math.sin(wd * t)));
  }
  if (zeta == 1) {
    return distance * (1 - math.exp(-w * t) * (1 + w * t));
  }
  final s = math.sqrt(zeta * zeta - 1);
  final r1 = -w * (zeta - s);
  final r2 = -w * (zeta + s);
  final c2 = r1 / (r2 - r1);
  final c1 = -1 - c2;
  return distance * (1 + c1 * math.exp(r1 * t) + c2 * math.exp(r2 * t));
}

/// Time after which [xs] stays within [tol] of [target]: the time of the
/// first sample that stays in band. Samples are at [ts] when given (a
/// trace that never settles gives one [dt] past its last sample), else one
/// per [dt] from 0.
double settle(
  List<double> xs,
  double target, {
  double dt = 1 / 60,
  double tol = 0.5,
  List<double>? ts,
}) {
  var last = -1;
  for (var i = 0; i < xs.length; i++) {
    if ((xs[i] - target).abs() > tol) last = i;
  }
  if (ts == null) return (last + 1) * dt;
  return last + 1 < ts.length ? ts[last + 1] : ts.last + dt;
}

/// The middle third of a drag [trace]: past the start transient, clear of
/// the end clamp.
List<Map<String, double>> _middleThird(List<Map<String, double>> trace) {
  final n = trace.length;
  return trace.sublist(n ~/ 3, n - n ~/ 3);
}

/// The finger's speed over the middle third of a drag [trace], in points
/// per second (its `finger` key): the speed [steadyLag] measures at.
double rampSpeed(List<Map<String, double>> trace) {
  final middle = _middleThird(trace);
  final first = middle.first;
  final last = middle.last;
  return (last['finger']! - first['finger']!) / (last['t']! - first['t']!);
}

/// The steady lag of a drag [trace] behind the continuous finger ramp, to
/// compare with [rampLag]: the mean `finger − x` over the middle third
/// (past the start transient, clear of the end clamp), plus half a frame
/// of finger travel. Each frame steps the spring toward the finger as
/// sampled at that frame, which leads the continuous ramp by half a frame
/// on average (the same correction as `lens_motion_test`'s drag lag).
double steadyLag(List<Map<String, double>> trace) {
  final middle = _middleThird(trace);
  final span = middle.last['t']! - middle.first['t']!;
  final frame = span / (middle.length - 1);
  final lag =
      middle.map((s) => s['finger']! - s['x']!).reduce((a, b) => a + b) /
      middle.length;
  return lag + rampSpeed(trace) * frame / 2;
}

/// How far [xs], moving from [from] toward [to], gets past [to]: 0 when it
/// never passes it.
double overshoot(List<double> xs, double from, double to) {
  final sign = (to - from).sign;
  return xs.fold(0, (m, x) => math.max(m, (x - to) * sign));
}

/// Steady lag of a spring following a ramp of [speed].
double rampLag(double speed, double zeta, double response) =>
    speed * 2 * zeta / (2 * math.pi / response);

/// The tolerance around [reference]: [abs], or [rel] of its size.
double band(double reference, {double? abs, double? rel}) =>
    abs ?? (rel! * reference.abs());

/// Whether [value] is within [tol] of [reference]. The epsilon keeps a
/// value exactly on the bound inside it.
bool near(double value, double reference, double tol) =>
    (value - reference).abs() <= tol + 1e-9;

/// [value] against [reference] within [abs] or [rel].
Check within(double value, double reference, {double? abs, double? rel}) {
  final tol = band(reference, abs: abs, rel: rel);
  return (
    pass: near(value, reference, tol),
    detail:
        '${value.toStringAsFixed(3)} vs ${reference.toStringAsFixed(3)} '
        '(±${tol.toStringAsFixed(3)})',
  );
}

/// The tap delay that fits [trace] best: the start time of the reference
/// spring (least squares over the first 0.3 s, searched in 0.5 ms steps
/// from 0 to 75 ms). Spec VK-503 §17.4: 25 ms ± 1 frame.
double fitDelay(
  List<Map<String, double>> trace, {
  required double from,
  required double to,
  required double zeta,
  required double response,
}) {
  var best = 0.0;
  var bestError = double.infinity;
  for (var step = 0; step <= 150; step++) {
    final delay = step * 0.0005;
    var error = 0.0;
    for (final s in trace) {
      final t = s['t']!;
      if (t > 0.3) break;
      final ref = t < delay
          ? from
          : from + springAt(to - from, zeta, response, t - delay);
      error += math.pow(s['x']! - ref, 2);
    }
    if (error < bestError) {
      bestError = error;
      best = delay;
    }
  }
  return best;
}

/// [got] against [want], every channel within [tolerance] (spec VK-503
/// §17.4, VK-550 §14.5).
Check colourCheck(List<double> got, List<double> want, double tolerance) {
  final worst = [
    for (var c = 0; c < 3; c++) (got[c] - want[c]).abs(),
  ].reduce(math.max);
  return (
    pass: worst <= tolerance,
    detail:
        '${got.map((v) => v.round()).join('/')} vs '
        '${want.map((v) => v.round()).join('/')} (±${tolerance.round()})',
  );
}

/// [key] of [trace] at [t] seconds after [zero] (default: its first
/// sample), linear between samples and clamped at the ends.
double valueAt(
  List<Map<String, double>> trace,
  double t,
  String key, {
  double? zero,
}) {
  final t0 = zero ?? trace.first['t']!;
  for (var i = 1; i < trace.length; i++) {
    final a = trace[i - 1];
    final b = trace[i];
    final ta = a['t']! - t0;
    final tb = b['t']! - t0;
    if (t <= tb) {
      if (t <= ta) return a[key]!;
      return a[key]! + (b[key]! - a[key]!) * (t - ta) / (tb - ta);
    }
  }
  return trace.last[key]!;
}

/// The time [values] first rises through [level] over [ts], linear
/// between samples; null when it never does (an engage onset, spec VK-550
/// §14.5).
double? onset(List<double> ts, List<double> values, {double level = 0.5}) {
  for (var i = 1; i < ts.length; i++) {
    if (values[i - 1] < level && values[i] >= level) {
      return ts[i - 1] +
          (level - values[i - 1]) /
              (values[i] - values[i - 1]) *
              (ts[i] - ts[i - 1]);
    }
  }
  return null;
}

/// When the finger left: the last touching sample's time (the integration
/// drivers lift right after a pumped frame), or the first sample's time.
double liftTime(List<Map<String, double>> trace) {
  final i = liftIndex(trace);
  return trace[i == 0 ? 0 : i - 1]['t']!;
}

/// The first sample after the finger left (`touch` 0 after a 1), or 0.
int liftIndex(List<Map<String, double>> trace) {
  for (var i = 1; i < trace.length; i++) {
    if (trace[i - 1]['touch'] == 1 && trace[i]['touch'] == 0) return i;
  }
  return 0;
}

/// Writes the table's last two lines (the rows per [Kind], then the
/// verdict) for [rows] (each row's kind and pass) to [out]; returns how many
/// failed.
int writeSummary(StringSink out, List<(Kind, bool)> rows) {
  final failed = rows.where((r) => !r.$2).length;
  final counts = {
    for (final k in Kind.values) k: rows.where((r) => r.$1 == k).length,
  };
  out
    ..writeln(
      '${counts[Kind.native]} native, ${counts[Kind.constant]} native but '
      'constant, ${counts[Kind.fit]} against fitted springs',
    )
    ..writeln(
      failed == 0
          ? '✓ all ${rows.length} checks pass'
          : '✗ $failed of ${rows.length} failed',
    );
  return failed;
}
