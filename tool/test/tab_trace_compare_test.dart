import 'dart:math' as math;

import 'package:test/test.dart';

import '../tab_trace_compare.dart';
import '../trace_math.dart';

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

  group('§17.4 rows added in VK-503 Task 16', () {
    test('fitDelay recovers the delay of a trace, to the half millisecond', () {
      for (final delay in [0.0, 0.010, 0.025, 0.040]) {
        expect(
          fitDelay(
            spring(115, 201, delay: delay),
            from: 115,
            to: 201,
            zeta: 0.79,
            response: 0.39,
          ),
          closeTo(delay, 0.0006),
        );
      }
    });

    test('restRect: the lens rect of a sample, from its centre and size', () {
      expect(restRect({'x': 115, 'y': 822, 'w': 94, 'h': 54}), [
        68,
        795,
        94,
        54,
      ]);
    });

    test('ripple: start glow, growth and the time it is gone', () {
      final trace = [
        for (var f = 0; f <= 40; f++)
          <String, double>{
            't': 1 + f / 60,
            'glowD': 93 * (1 + 3 * math.min<double>(1, f / 30)),
            'glow': f < 30 ? 0.28 * (1 - f / 30) : 0.0,
          },
      ];
      final r = ripple(trace);
      expect(r.diameter, 93);
      expect(r.opacity, 0.28);
      // The last visible sample: 29 of the 30 frames of growth.
      expect(r.growth, closeTo(3.9, 1e-9));
      expect(r.fade, closeTo(0.5, 1e-9));
    });

    test('colourCheck: every channel within the tolerance', () {
      expect(colourCheck([236, 236, 236], [236, 236, 236], 4).pass, isTrue);
      expect(colourCheck([232, 236, 240], [236, 236, 236], 4).pass, isTrue);
      expect(colourCheck([224, 221, 228], [236, 236, 236], 4).pass, isFalse);
    });
  });

  test('morphOvershoot: how far the right edge passes the pill, in pt', () {
    // The morph dips to −0.0153 on a 262 pt right-edge travel.
    expect(
      morphOvershoot([1, 0.4, 0, -0.0153, -0.004, 0], 262),
      closeTo(4, 0.01),
    );
    expect(morphOvershoot([1, 0.5, 0], 262), 0);
  });

  test('valueAt: linear between samples, clamped at the ends', () {
    final trace = [
      {'t': 0.0, 'w': 94.0},
      {'t': 0.1, 'w': 104.0},
    ];
    expect(valueAt(trace, 0.05, 'w'), closeTo(99, 1e-9));
    expect(valueAt(trace, -1, 'w'), 94);
    expect(valueAt(trace, 1, 'w'), 104);
    expect(valueAt(trace, 0.05, 'w', zero: -0.05), 94);
    expect(valueAt(trace, 0.05, 'w', zero: 0.05), 104);
  });

  test('liftIndex: the first sample after the finger left', () {
    final trace = [
      {'t': 0.0, 'touch': 1.0},
      {'t': 0.1, 'touch': 1.0},
      {'t': 0.2, 'touch': 0.0},
    ];
    expect(liftIndex(trace), 2);
    expect(liftTime(trace), closeTo(0.1, 1e-9));
    expect(
      liftIndex([
        {'t': 0.0, 'touch': 0.0},
      ]),
      0,
    );
  });

  test('speedDips: a lens that brakes and picks up again is caught', () {
    List<Map<String, double>> trace(List<double> xs) => [
      for (final (i, x) in xs.indexed) {'t': i / 60, 'x': x},
    ];
    // One hump toward 180.
    expect(
      speedDips(
        trace([94, 96, 104, 116, 130, 145, 158, 168, 175, 179, 180]),
        180,
      ),
      0,
    );
    // Fast, then braked, then fast again.
    expect(
      speedDips(trace([94, 104, 116, 122, 124, 132, 146, 162, 175, 180]), 180),
      greaterThan(0),
    );
  });
}
