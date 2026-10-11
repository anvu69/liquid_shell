// Compares Flutter tab bar traces (integration_test reportData) with the
// native reference fits (spec VK-503 §17.4). Pure Dart.
//
// Usage: dart run tool/tab_trace_compare.dart <response.json> <reference.json>
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// One check's outcome.
typedef Check = ({bool pass, String detail});

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

/// The steady lag of a drag [trace] behind the continuous finger ramp, to
/// compare with [rampLag]: the mean `finger − x` over the middle third
/// (past the start transient, clear of the end clamp), plus half a frame
/// of finger travel. Each frame steps the spring toward the finger as
/// sampled at that frame, which leads the continuous ramp by half a frame
/// on average (the same correction as `lens_motion_test`'s drag lag).
double steadyLag(List<Map<String, double>> trace) {
  final n = trace.length;
  final middle = trace.sublist(n ~/ 3, n - n ~/ 3);
  final first = middle.first;
  final last = middle.last;
  final span = last['t']! - first['t']!;
  final speed = (last['finger']! - first['finger']!) / span;
  final frame = span / (middle.length - 1);
  final lag =
      middle.map((s) => s['finger']! - s['x']!).reduce((a, b) => a + b) /
      middle.length;
  return lag + speed * frame / 2;
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

/// [value] against [reference] within [abs] or [rel].
Check within(double value, double reference, {double? abs, double? rel}) {
  final tol = abs ?? (rel! * reference.abs());
  // The epsilon keeps a value exactly on the bound inside it.
  final ok = (value - reference).abs() <= tol + 1e-9;
  return (
    pass: ok,
    detail:
        '${value.toStringAsFixed(3)} vs ${reference.toStringAsFixed(3)} '
        '(±${tol.toStringAsFixed(3)})',
  );
}

/// The reference tap spring sampled at [trace]'s times.
List<double> _tapReference(
  List<Map<String, double>> trace, {
  required double from,
  required double to,
  required double zeta,
  required double response,
  required double delay,
}) => [
  for (final s in trace)
    s['t']! < delay
        ? from
        : from + springAt(to - from, zeta, response, s['t']! - delay),
];

/// The settle time of a tap trace against the reference spring ±10 %.
Check checkTap(
  List<Map<String, double>> trace, {
  required double from,
  required double to,
  required double zeta,
  required double response,
  required double delay,
}) {
  final xs = [for (final s in trace) s['x']!];
  final ts = [for (final s in trace) s['t']!];
  final ref = _tapReference(
    trace,
    from: from,
    to: to,
    zeta: zeta,
    response: response,
    delay: delay,
  );
  return within(settle(xs, to, ts: ts), settle(ref, to, ts: ts), rel: 0.10);
}

/// The overshoot of a tap trace against the reference spring's over the
/// same distance, ±1 pt (spec §17.1).
Check checkTapOvershoot(
  List<Map<String, double>> trace, {
  required double from,
  required double to,
  required double zeta,
  required double response,
  required double delay,
}) {
  final xs = [for (final s in trace) s['x']!];
  final ref = _tapReference(
    trace,
    from: from,
    to: to,
    zeta: zeta,
    response: response,
    delay: delay,
  );
  return within(overshoot(xs, from, to), overshoot(ref, from, to), abs: 1);
}

/// The tap delay that fits [trace] best: the start time of the reference
/// spring (least squares over the first 0.3 s, searched in 0.5 ms steps
/// from 0 to 75 ms). Spec §17.4: 25 ms ± 1 frame.
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

/// The lens rect of a trace [sample] as `[left, top, width, height]`.
List<double> restRect(Map<String, double> sample) => [
  sample['x']! - sample['w']! / 2,
  sample['y']! - sample['h']! / 2,
  sample['w']!,
  sample['h']!,
];

/// A tap's finger glow ripple (research §3): the glow at the first sample
/// (the release), how far its diameter grows over that, and how long after
/// the first sample it is gone.
({double diameter, double opacity, double growth, double fade}) ripple(
  List<Map<String, double>> trace,
) {
  final first = trace.first;
  final t0 = first['t']!;
  var widest = first['glowD']!;
  var fade = double.infinity;
  for (final s in trace) {
    if (s['glow']! > 0) widest = math.max(widest, s['glowD']!);
    if (s['glow']! == 0 && fade.isInfinite) fade = s['t']! - t0;
  }
  return (
    diameter: first['glowD']!,
    opacity: first['glow']!,
    growth: widest / first['glowD']!,
    fade: fade,
  );
}

/// [got] against [want], every channel within [tolerance] (spec §17.4).
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

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'usage: tab_trace_compare.dart <response.json> <reference.json>',
    );
    exit(64);
  }
  final response =
      jsonDecode(File(args[0]).readAsStringSync()) as Map<String, dynamic>;
  final reference =
      jsonDecode(File(args[1]).readAsStringSync()) as Map<String, dynamic>;
  final data = response['tabfid']! as Map<String, dynamic>;
  final seqs = (data['sequences']! as Map<String, dynamic>).map(
    (k, v) => MapEntry(k, [
      for (final s in v as List<dynamic>)
        (s as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        ),
    ]),
  );
  final springs = reference['springs']! as Map<String, dynamic>;
  Map<String, dynamic> spring(String name) =>
      springs[name]! as Map<String, dynamic>;
  double d(Map<String, dynamic> m, String k) => (m[k]! as num).toDouble();
  final rows = <(String, Check)>[];

  // Geometry (±1 pt).
  final geometry = reference['geometry']! as Map<String, dynamic>;
  final measured = data['geometry']! as Map<String, dynamic>;
  for (final key in ['pill3', 'minimized']) {
    final want = [
      for (final v in geometry[key]! as List<dynamic>) (v as num).toDouble(),
    ];
    final got = [
      for (final v in measured[key]! as List<dynamic>) (v as num).toDouble(),
    ];
    for (var i = 0; i < 4; i++) {
      rows.add((
        '$key[$i]',
        within(got[i], want[i], abs: d(geometry, 'tolerance')),
      ));
    }
  }

  // Taps (settle ±10 %, overshoot ±1 pt).
  final tap = spring('tap');
  for (final (name, from, to) in [
    ('tap_1_2', 115.0, 201.0),
    ('tap_2_3', 201.0, 287.0),
    ('tap_3_1', 287.0, 115.0),
  ]) {
    final trace = seqs[name]!;
    final t0 = trace.first['t']!;
    final shifted = [
      for (final s in trace) {...s, 't': s['t']! - t0},
    ];
    rows
      ..add((
        '$name settle',
        checkTap(
          shifted,
          from: from,
          to: to,
          zeta: d(tap, 'zeta'),
          response: d(tap, 'response'),
          delay: d(tap, 'delay'),
        ),
      ))
      ..add((
        '$name overshoot',
        checkTapOvershoot(
          shifted,
          from: from,
          to: to,
          zeta: d(tap, 'zeta'),
          response: d(tap, 'response'),
          delay: d(tap, 'delay'),
        ),
      ))
      ..add((
        '$name delay',
        within(
          fitDelay(
            shifted,
            from: from,
            to: to,
            zeta: d(tap, 'zeta'),
            response: d(tap, 'response'),
          ),
          d(tap, 'delay'),
          abs: 1 / 60,
        ),
      ));
  }

  // Slot rects (±1 pt): the lens at rest after each tap is its slot.
  final slots = geometry['slots3']! as List<dynamic>;
  for (final (slot, name) in [
    (0, 'tap_3_1'),
    (1, 'tap_1_2'),
    (2, 'tap_2_3'),
  ]) {
    final want = [
      for (final v in slots[slot] as List<dynamic>) (v as num).toDouble(),
    ];
    final got = restRect(seqs[name]!.last);
    final worst = [
      for (var i = 0; i < 4; i++) (got[i] - want[i]).abs(),
    ].reduce(math.max);
    rows.add((
      'slot$slot rect',
      (
        pass: worst <= d(geometry, 'tolerance') + 1e-9,
        detail:
            '${got.map((v) => v.toStringAsFixed(1)).join(', ')} vs '
            '${want.map((v) => v.toStringAsFixed(0)).join(', ')} '
            '(±${d(geometry, 'tolerance')})',
      ),
    ));
  }

  // Flight peaks (±10 %).
  final flight = reference['flight']! as Map<String, dynamic>;
  final oneSlot = seqs['tap_1_2']!;
  rows
    ..add((
      'one-slot lift',
      within(
        oneSlot.map((s) => s['h']! / 54).reduce(math.max),
        d(flight, 'oneSlotHeight'),
        rel: 0.10,
      ),
    ))
    ..add((
      'two-slot stretch',
      within(
        seqs['tap_3_1']!.map((s) => s['w']! / 94).reduce(math.max),
        d(flight, 'twoSlotWidth'),
        rel: 0.10,
      ),
    ))
    ..add((
      'icon pop',
      within(
        oneSlot.map((s) => s['pop']!).reduce(math.max),
        d(flight, 'pop'),
        abs: 0.02,
      ),
    ));

  // The finger glow of a tap (research §3): 93 pt at 0.28, then ×4 and
  // gone in 0.5 s.
  final glow = reference['glow']! as Map<String, dynamic>;
  final tapGlow = ripple(oneSlot);
  rows
    ..add((
      'glow diameter',
      within(tapGlow.diameter, d(glow, 'diameter'), abs: 2),
    ))
    ..add((
      'glow opacity',
      within(tapGlow.opacity, d(glow, 'opacity'), abs: 0.03),
    ))
    ..add((
      'glow ripple',
      within(tapGlow.growth, d(glow, 'ripple'), rel: 0.10),
    ))
    ..add(('glow fade', within(tapGlow.fade, d(glow, 'fade'), rel: 0.10)));

  // Press and hold.
  final press = reference['press']! as Map<String, dynamic>;
  final held = seqs['press_hold']!.last;
  rows
    ..add(('press width', within(held['w']!, d(press, 'w'), abs: 2)))
    ..add(('press height', within(held['h']!, d(press, 'h'), abs: 2)))
    ..add((
      'press scale',
      within(held['scale']!, d(press, 'scale'), abs: 0.005),
    ))
    ..add(('press glow', within(held['glow']!, d(press, 'glow'), abs: 0.03)));

  // Drag lag at 90 pt/s (±10 % of the follow spring's ramp lag). The
  // reference is the fit's analytic lag, 7.09 pt (spec §17.1), not the
  // research's "about 9 pt": VK-503 Task 16 kept the fit (see
  // native_reference.json `dragLag`).
  final follow = spring('dragFollow');
  rows
    ..add((
      'drag lag',
      within(
        steadyLag(seqs['slow_drag']!),
        rampLag(90, d(follow, 'zeta'), d(follow, 'response')),
        rel: 0.10,
      ),
    ))
    // A fast flick lands on the finger's slot, Home (research §4.2).
    ..add((
      'flick lands under the finger',
      within(seqs['fast_flick']!.last['x']!, 115, abs: 0.5),
    ));

  // Minimize (settle ±10 %).
  final collapse = spring('collapse');
  final morph = seqs['minimize']!;
  final m0 = morph.first['t']!;
  final ms = [for (final s in morph) s['morph']!];
  final mts = [for (final s in morph) s['t']! - m0];
  final mref = [
    for (final s in morph)
      s['t']! - m0 < d(collapse, 'delay')
          ? 0.0
          : springAt(
              1,
              d(collapse, 'zeta'),
              d(collapse, 'response'),
              s['t']! - m0 - d(collapse, 'delay'),
            ),
  ];
  rows.add((
    'collapse settle',
    within(
      settle(ms, 1, tol: 0.005, ts: mts),
      settle(mref, 1, tol: 0.005, ts: mts),
      rel: 0.10,
    ),
  ));

  // Expand (settle ±10 %): the morph back from the circle, no delay.
  final expand = spring('expand');
  final grow = seqs['expand']!;
  final e0 = grow.first['t']!;
  final es = [for (final s in grow) s['morph']!];
  final ets = [for (final s in grow) s['t']! - e0];
  final eref = [
    for (final t in ets)
      1 - springAt(1, d(expand, 'zeta'), d(expand, 'response'), t),
  ];
  rows.add((
    'expand settle',
    within(
      settle(es, 0, tol: 0.005, ts: ets),
      settle(eref, 0, tol: 0.005, ts: ets),
      rel: 0.10,
    ),
  ));

  // Rest colours (±4 per channel over a white or black page).
  final colours = reference['colors']! as Map<String, dynamic>;
  final sampled = data['colors']! as Map<String, dynamic>;
  for (final name in [
    'lightFill',
    'lightCapsule',
    'lightLabel',
    'darkFill',
    'darkCapsule',
    'darkLabel',
  ]) {
    List<double> rgb(Map<String, dynamic> m) => [
      for (final v in m[name]! as List<dynamic>) (v as num).toDouble(),
    ];
    rows.add((
      'colour $name',
      colourCheck(rgb(sampled), rgb(colours), d(colours, 'tolerance')),
    ));
  }

  var failed = 0;
  stdout.writeln('| check | result | detail |\n|---|---|---|');
  for (final (name, check) in rows) {
    if (!check.pass) failed++;
    stdout.writeln(
      '| $name | ${check.pass ? 'pass' : 'FAIL'} | ${check.detail} |',
    );
  }
  stdout.writeln(
    failed == 0
        ? '✓ all ${rows.length} checks pass'
        : '✗ $failed of ${rows.length} failed',
  );
  exit(failed == 0 ? 0 : 1);
}
