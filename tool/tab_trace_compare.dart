// Compares Flutter tab bar traces (integration_test reportData) with the
// native reference fits (spec VK-503 §17.4). Pure Dart.
//
// Usage: dart run tool/tab_trace_compare.dart <response.json> <reference.json>
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'trace_math.dart';

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
    if (s['t']! < delay)
      from
    else
      from + springAt(to - from, zeta, response, s['t']! - delay),
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

/// How far the minimize morph's right edge passes the full pill on an
/// expand, in points: the deepest negative morph times the right edge's
/// [travel] (the morph rect is `lerp(pill, minimized, morph)`).
double morphOvershoot(List<double> morphs, double travel) =>
    -math.min(0, morphs.reduce(math.min)) * travel;

/// Places where the lens, on its way to [to], slows by more than 10 % and
/// then speeds up again by more than 10 % (+ 30 pt/s of frame jitter): a
/// brake in the middle of a move. A healthy move has one speed hump.
int speedDips(List<Map<String, double>> trace, double to) {
  final speeds = <double>[];
  final sign = (to - trace.first['x']!).sign;
  for (var i = 1; i < trace.length; i++) {
    if ((trace[i - 1]['x']! - to) * sign >= -1) break;
    final dt = trace[i]['t']! - trace[i - 1]['t']!;
    if (dt <= 0) continue;
    speeds.add((trace[i]['x']! - trace[i - 1]['x']!) * sign / dt);
  }
  var dips = 0;
  var low = double.infinity;
  var high = 0.0;
  for (final v in speeds) {
    if (v > high && low.isInfinite) {
      high = v;
    } else if (v < low) {
      low = v;
    }
    if (low < high * 0.9 && v > low * 1.1 + 30) {
      dips++;
      high = v;
      low = double.infinity;
    }
  }
  return dips;
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
  Map<String, dynamic> section(String name) =>
      reference[name]! as Map<String, dynamic>;
  double d(Map<String, dynamic> m, String k) => (m[k]! as num).toDouble();
  List<double> list(Object? v) => [
    for (final e in v! as List<dynamic>) (e as num).toDouble(),
  ];
  final rows = <(Kind, String, Check)>[];
  void add(Kind kind, String name, Check check) =>
      rows.add((kind, name, check));

  // Geometry (±1 pt). The rects are TabMetrics constants typed in from
  // the native measurement: only the layout plumbing can fail them.
  final geometry = section('geometry');
  final measured = data['geometry']! as Map<String, dynamic>;
  for (final key in ['pill3', 'minimized']) {
    final want = list(geometry[key]);
    final got = list(measured[key]);
    for (var i = 0; i < 4; i++) {
      add(
        Kind.constant,
        '$key[$i]',
        within(got[i], want[i], abs: d(geometry, 'tolerance')),
      );
    }
  }

  // Taps against the fitted tap spring (settle ±10 %, overshoot ±1 pt,
  // delay ±1 frame).
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
    add(
      Kind.fit,
      '$name settle',
      checkTap(
        shifted,
        from: from,
        to: to,
        zeta: d(tap, 'zeta'),
        response: d(tap, 'response'),
        delay: d(tap, 'delay'),
      ),
    );
    add(
      Kind.fit,
      '$name overshoot',
      checkTapOvershoot(
        shifted,
        from: from,
        to: to,
        zeta: d(tap, 'zeta'),
        response: d(tap, 'response'),
        delay: d(tap, 'delay'),
      ),
    );
    add(
      Kind.fit,
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
    );
  }

  // A tap held 80 ms: lifting must not brake the moving lens (review I2).
  // Traces-only runs record it (the strips pair the native sequences).
  final held = seqs['tap_held'];
  if (held != null) {
    final dips = speedDips(held, 201);
    add(Kind.fit, 'tap_held no brake', (
      pass: dips == 0,
      detail: '$dips speed dips',
    ));
  }

  // Slot rects (±1 pt): the lens at rest after each tap is its slot.
  final slots = geometry['slots3']! as List<dynamic>;
  for (final (slot, name) in [
    (0, 'tap_3_1'),
    (1, 'tap_1_2'),
    (2, 'tap_2_3'),
  ]) {
    final want = list(slots[slot]);
    final got = restRect(seqs[name]!.last);
    final worst = [
      for (var i = 0; i < 4; i++) (got[i] - want[i]).abs(),
    ].reduce(math.max);
    // Slot sizes and pitch are TabMetrics constants (see Geometry above).
    add(Kind.constant, 'slot$slot rect', (
      pass: worst <= d(geometry, 'tolerance') + 1e-9,
      detail:
          '${got.map((v) => v.toStringAsFixed(1)).join(', ')} vs '
          '${want.map((v) => v.toStringAsFixed(0)).join(', ')} '
          '(±${d(geometry, 'tolerance')})',
    ));
  }

  // Flight peaks (±10 %), the pop (±0.02).
  final flight = section('flight');
  final oneSlot = seqs['tap_1_2']!;
  final twoSlot = seqs['tap_3_1']!;
  add(
    Kind.native,
    'one-slot lift',
    within(
      oneSlot.map((s) => s['h']! / 54).reduce(math.max),
      d(flight, 'oneSlotHeight'),
      rel: 0.10,
    ),
  );
  add(
    Kind.native,
    'two-slot stretch',
    within(
      twoSlot.map((s) => s['w']! / 94).reduce(math.max),
      d(flight, 'twoSlotWidth'),
      rel: 0.10,
    ),
  );
  // The pop's target is the research's ×1.16, a constant: only the spring
  // overshoot around it is the model's.
  add(
    Kind.constant,
    'icon pop',
    within(
      oneSlot.map((s) => s['pop']!).reduce(math.max),
      d(flight, 'pop'),
      abs: 0.02,
    ),
  );

  // The tap's shape, frame by frame against the native per-frame trace
  // (±10 %, spec Q18): the swell, then the lift or the stretch.
  final shape = section('tapShape');
  for (final (name, trace) in [
    ('oneSlot', oneSlot),
    ('twoSlot', twoSlot),
  ]) {
    for (final row in shape[name]! as List<dynamic>) {
      final [t, w, h] = list(row);
      final ms = (t * 1000).round();
      add(
        Kind.native,
        '$name w @${ms}ms',
        within(valueAt(trace, t, 'w'), w, rel: 0.10),
      );
      add(
        Kind.native,
        '$name h @${ms}ms',
        within(valueAt(trace, t, 'h'), h, rel: 0.10),
      );
    }
  }

  // The press, frame by frame (±2.5 pt, ±0.005, ±0.05).
  final press = section('pressCourse');
  final hold = seqs['press_hold']!;
  final pt = list(press['t']);
  final pw = list(press['w']);
  final ph = list(press['h']);
  for (var i = 0; i < pt.length; i++) {
    final ms = (pt[i] * 1000).round();
    add(
      Kind.native,
      'press w @${ms}ms',
      within(valueAt(hold, pt[i], 'w'), pw[i], abs: 2.5),
    );
    add(
      Kind.native,
      'press h @${ms}ms',
      within(valueAt(hold, pt[i], 'h'), ph[i], abs: 2.5),
    );
  }
  final st = list(press['scaleT']);
  final sv = list(press['scale']);
  for (var i = 0; i < st.length; i++) {
    add(
      Kind.native,
      'press scale @${(st[i] * 1000).round()}ms',
      within(valueAt(hold, st[i], 'scale'), sv[i], abs: 0.005),
    );
  }
  final gt = list(press['glowT']);
  final gv = list(press['glow']);
  for (var i = 0; i < gt.length; i++) {
    add(
      Kind.native,
      'press glow @${(gt[i] * 1000).round()}ms',
      within(valueAt(hold, gt[i], 'glow'), gv[i], abs: 0.05),
    );
  }

  // The release of that press, from the lift (±2.5 pt, ±0.12, ±10 %).
  final released = seqs['press_release']!;
  final lifted = released.sublist(liftIndex(released));
  final up = liftTime(released);
  final rel = section('releaseCourse');
  final rt = list(rel['t']);
  final rw = list(rel['w']);
  final rh = list(rel['h']);
  final re = list(rel['engage']);
  for (var i = 0; i < rt.length; i++) {
    final ms = (rt[i] * 1000).round();
    add(
      Kind.native,
      'release w @+${ms}ms',
      within(valueAt(lifted, rt[i], 'w', zero: up), rw[i], abs: 2.5),
    );
    add(
      Kind.native,
      'release h @+${ms}ms',
      within(valueAt(lifted, rt[i], 'h', zero: up), rh[i], abs: 2.5),
    );
    add(
      Kind.native,
      'release engage @+${ms}ms',
      within(valueAt(lifted, rt[i], 'engage', zero: up), re[i], abs: 0.12),
    );
  }
  final ripple = section('ripple');
  final d0 = lifted.first['glowD']!;
  final kt = list(ripple['t']);
  final ks = list(ripple['scale']);
  final ko = list(ripple['opacity']);
  for (var i = 0; i < kt.length; i++) {
    final ms = (kt[i] * 1000).round();
    add(
      Kind.native,
      'ripple scale @+${ms}ms',
      within(valueAt(lifted, kt[i], 'glowD', zero: up) / d0, ks[i], rel: 0.10),
    );
    add(
      Kind.native,
      'ripple opacity @+${ms}ms',
      within(valueAt(lifted, kt[i], 'glow', zero: up), ko[i], abs: 0.03),
    );
  }

  // Drag lag at 90 pt/s (±10 % of the follow spring's ramp lag). The
  // reference is the fit's analytic lag, 7.09 pt (spec §17.1), not the
  // research's "about 9 pt" (native_reference.json `dragLag`).
  final follow = spring('dragFollow');
  add(
    Kind.fit,
    'drag lag',
    within(
      steadyLag(seqs['slow_drag']!),
      rampLag(90, d(follow, 'zeta'), d(follow, 'response')),
      rel: 0.10,
    ),
  );

  // A fast flick lands on the finger's slot, Home, staying clear until it
  // lands, as fast as native (research §4.2 trace).
  final flick = seqs['fast_flick']!;
  final fl = section('flick');
  final flickUp = flick.sublist(liftIndex(flick));
  final flickAt = liftTime(flick);
  add(
    Kind.native,
    'flick lands under the finger',
    within(flick.last['x']!, 115, abs: 0.5),
  );
  add(
    Kind.native,
    'flick short of Home @+${(d(fl, 't') * 1000).round()}ms',
    within(
      (valueAt(flickUp, d(fl, 't'), 'x', zero: flickAt) - 115).abs(),
      d(fl, 'short'),
      abs: 6,
    ),
  );
  // Native stays clear to +0.215 s and never passes Home (re-review).
  add(
    Kind.native,
    'flick clear @+200ms',
    within(valueAt(flickUp, 0.2, 'engage', zero: flickAt), 1, abs: 0.05),
  );
  final past = flickUp
      .map((s) => 115 - s['x']!)
      .reduce(math.max)
      .clamp(0.0, double.infinity);
  add(
    Kind.native,
    'flick overshoot',
    within(past, d(fl, 'overshoot'), abs: 1),
  );

  // Minimize (settle ±10 %).
  final collapse = spring('collapse');
  final morph = seqs['minimize']!;
  final m0 = morph.first['t']!;
  final ms = [for (final s in morph) s['morph']!];
  final mts = [for (final s in morph) s['t']! - m0];
  final mref = [
    for (final s in morph)
      if (s['t']! - m0 < d(collapse, 'delay'))
        0.0
      else
        springAt(
          1,
          d(collapse, 'zeta'),
          d(collapse, 'response'),
          s['t']! - m0 - d(collapse, 'delay'),
        ),
  ];
  add(
    Kind.fit,
    'collapse settle',
    within(
      settle(ms, 1, tol: 0.005, ts: mts),
      settle(mref, 1, tol: 0.005, ts: mts),
      rel: 0.10,
    ),
  );

  // Expand: the settle against the reference spring from the first moving
  // sample (±10 %), and the right edge's overshoot against native's (±1 pt).
  final expand = spring('expand');
  final grow = seqs['expand']!;
  final start = math.max(0, grow.indexWhere((s) => s['morph']! < 0.995) - 1);
  final moving = grow.sublist(start);
  final e0 = moving.first['t']!;
  final es = [for (final s in moving) s['morph']!];
  final ets = [for (final s in moving) s['t']! - e0];
  final eref = [
    for (final t in ets)
      1 - springAt(1, d(expand, 'zeta'), d(expand, 'response'), t),
  ];
  add(
    Kind.fit,
    'expand settle',
    within(
      settle(es, 0, tol: 0.005, ts: ets),
      settle(eref, 0, tol: 0.005, ts: ets),
      rel: 0.10,
    ),
  );
  final pill = list(measured['pill3']);
  final mini = list(measured['minimized']);
  add(
    Kind.native,
    'expand overshoot',
    within(
      morphOvershoot(es, pill[0] + pill[2] - (mini[0] + mini[2])),
      d(section('expandOvershoot'), 'pt'),
      abs: 1,
    ),
  );

  // Rest colours (±4 per channel): over white, black and the example's page.
  final colours = section('colors');
  final sampled = data['colors']! as Map<String, dynamic>;
  for (final (name, kind) in [
    ('lightFillPage', Kind.native),
    ('lightCapsule', Kind.native),
    ('lightLabel', Kind.constant),
    ('darkFill', Kind.native),
    ('darkCapsule', Kind.native),
    ('darkLabel', Kind.constant),
  ]) {
    final got = list(sampled[name]);
    final want = list(colours[name]);
    add(
      kind,
      'colour $name',
      colourCheck(got, want, d(colours, 'tolerance')),
    );
  }

  stdout.writeln('| check | kind | result | detail |\n|---|---|---|---|');
  for (final (kind, name, check) in rows) {
    stdout.writeln(
      '| $name | ${kind.label} | ${check.pass ? 'pass' : 'FAIL'} | '
      '${check.detail} |',
    );
  }
  final failed = writeSummary(stdout, [
    for (final (kind, _, check) in rows) (kind, check.pass),
  ]);
  exit(failed == 0 ? 0 : 1);
}
