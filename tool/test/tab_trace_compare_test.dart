import 'dart:math' as math;

import 'package:test/test.dart';

import '../tab_trace_compare.dart';

/// A synthetic tap trace on the reference spring: 60 fps, from [from] to
/// [to], held for [delay].
List<Map<String, double>> spring(
  double from,
  double to, {
  double zeta = 0.79,
  double response = 0.39,
  double delay = 0.025,
  double slow = 1,
}) {
  final out = <Map<String, double>>[];
  for (var f = 0; f < 90; f++) {
    final t = f / 60;
    final x = t < delay
        ? from
        : springAt(to - from, zeta, response * slow, t - delay) + from;
    out.add({
      't': t,
      'x': x,
      'y': 0,
      'w': 94,
      'h': 54,
      'engage': 0,
      'scale': 1,
      'glow': 0,
      'glowD': 93,
      'pop': 1,
      'morph': 0,
    });
  }
  return out;
}

void main() {
  test('springAt is the closed-form step response', () {
    expect(springAt(86, 0.79, 0.39, 0), 0);
    expect(springAt(86, 0.79, 0.39, 3), closeTo(86, 1e-3));
    // Critically damped and overdamped branches.
    expect(springAt(1, 1, 0.25, 2), closeTo(1, 1e-3));
    expect(springAt(1, 1.4, 0.19, 2), closeTo(1, 1e-3));
  });

  test('settle: last frame outside 0.5 pt', () {
    final xs = <double>[0, 50, 85, 86.6, 86.2, 86];
    expect(settle(xs, 86, dt: 1), 4);
  });

  test('settle with timestamps: the first in-band sample that stays', () {
    final xs = <double>[0, 50, 85, 86.6, 86.2, 86];
    final ts = <double>[0, 0.02, 0.03, 0.07, 0.09, 0.1];
    expect(settle(xs, 86, ts: ts), 0.09);
    // Never settled: one sample interval past the end.
    expect(settle([0, 50], 86, ts: [0, 0.02]), 0.02 + 1 / 60);
  });

  test('a tap trace sampled unevenly is judged on its timestamps', () {
    // Every other 60 fps frame dropped: the settle time must not halve.
    final trace = spring(115, 201);
    final sparse = [for (var i = 0; i < trace.length; i += 2) trace[i]];
    final r = checkTap(
      sparse,
      from: 115,
      to: 201,
      zeta: 0.79,
      response: 0.39,
      delay: 0.025,
    );
    expect(r.pass, isTrue, reason: r.detail);
    final full = checkTap(
      trace,
      from: 115,
      to: 201,
      zeta: 0.79,
      response: 0.39,
      delay: 0.025,
    );
    double measured(Check c) => double.parse(c.detail.split(' ').first);
    // The same settle time, to within one 30 fps frame.
    expect(measured(full), greaterThan(0.4));
    expect(measured(r), closeTo(measured(full), 1 / 30));
  });

  test('steady lag: the mean finger − x over the middle third, plus the '
      'half-frame hold of the sampled finger', () {
    final trace = [
      for (var i = 0; i < 9; i++)
        {'t': 0.1 * i, 'finger': 10.0 * i, 'x': 10.0 * i - (i.isEven ? 6 : 8)},
    ];
    // Samples 3, 4, 5: lags 8, 6, 8. The finger runs at 100 pt/s, sampled
    // every 0.1 s: the spring sees each sample held for a frame, so it
    // leads the continuous ramp by 100 · 0.1 / 2 = 5 pt.
    expect(steadyLag(trace), closeTo(22 / 3 + 5, 1e-9));
  });

  test('steady lag of a sampled spring following a ramp is its ramp lag', () {
    // The bar's order: the pointer moves, then the frame steps the follow
    // spring (RK4, as the bar's SpringValue) toward the new finger, then
    // the trace samples both.
    const zeta = 0.75;
    const response = 0.33;
    const w = 2 * math.pi / response;
    var x = 0.0;
    var v = 0.0;
    final trace = <Map<String, double>>[];
    for (var f = 0; f <= 120; f++) {
      final t = f / 60;
      final finger = 90 * t;
      for (var i = 0; f > 0 && i < 17; i++) {
        const h = 1 / 60 / 17;
        double a(double x, double v) =>
            -w * w * (x - finger) - 2 * zeta * w * v;
        final k1x = v;
        final k1v = a(x, v);
        final k2x = v + h / 2 * k1v;
        final k2v = a(x + h / 2 * k1x, v + h / 2 * k1v);
        final k3x = v + h / 2 * k2v;
        final k3v = a(x + h / 2 * k2x, v + h / 2 * k2v);
        final k4x = v + h * k3v;
        final k4v = a(x + h * k3x, v + h * k3v);
        x += h / 6 * (k1x + 2 * k2x + 2 * k3x + k4x);
        v += h / 6 * (k1v + 2 * k2v + 2 * k3v + k4v);
      }
      trace.add({'t': t, 'finger': finger, 'x': x});
    }
    expect(
      steadyLag(trace),
      closeTo(rampLag(90, zeta, response), 0.02 * rampLag(90, zeta, response)),
    );
  });

  test('a trace on the reference spring passes the tap check', () {
    final r = checkTap(
      spring(115, 201),
      from: 115,
      to: 201,
      zeta: 0.79,
      response: 0.39,
      delay: 0.025,
    );
    expect(r.pass, isTrue, reason: r.detail);
  });

  test('a 20 % slower spring fails it', () {
    final r = checkTap(
      spring(115, 201, slow: 1.2),
      from: 115,
      to: 201,
      zeta: 0.79,
      response: 0.39,
      delay: 0.025,
    );
    expect(r.pass, isFalse);
  });

  test('overshoot: the furthest excursion past the target, either way', () {
    expect(overshoot([115, 180, 202.5, 200.8, 201], 115, 201), 1.5);
    expect(overshoot([287, 150, 113, 115.4, 115], 287, 115), 2);
    // A trace that never passes the target overshoots by 0.
    expect(overshoot([115, 160, 200, 201], 115, 201), 0);
  });

  test('the tap overshoot check is ±1 pt of the reference spring', () {
    // ζ 0.79 overshoots 86 pt by 86·exp(−πζ/√(1−ζ²)) ≈ 1.50 pt.
    final on = checkTapOvershoot(
      spring(115, 201),
      from: 115,
      to: 201,
      zeta: 0.79,
      response: 0.39,
      delay: 0.025,
    );
    expect(on.pass, isTrue, reason: on.detail);
    // ζ 0.6 overshoots by ≈ 8.1 pt: more than 1 pt past the reference.
    final bouncy = checkTapOvershoot(
      spring(115, 201, zeta: 0.6),
      from: 115,
      to: 201,
      zeta: 0.79,
      response: 0.39,
      delay: 0.025,
    );
    expect(bouncy.pass, isFalse);
    // Critically damped: no overshoot, 1.5 pt short of the reference.
    final dead = checkTapOvershoot(
      spring(115, 201, zeta: 1),
      from: 115,
      to: 201,
      zeta: 0.79,
      response: 0.39,
      delay: 0.025,
    );
    expect(dead.pass, isFalse);
  });

  test('ramp lag of the drag spring', () {
    expect(
      rampLag(90, 0.75, 0.33),
      closeTo(90 * 2 * 0.75 / (2 * math.pi / 0.33), 1e-9),
    );
  });

  test('range checks', () {
    expect(within(1.16, 1.16, abs: 0.02).pass, isTrue);
    expect(within(1.19, 1.16, abs: 0.02).pass, isFalse);
    expect(within(0.33, 0.30, rel: 0.10).pass, isTrue);
  });
}
