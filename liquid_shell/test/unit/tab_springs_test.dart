import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/chrome/tab_springs.dart';

void main() {
  test('fittedSpring: mass 1, stiffness (2π/response)², damping 2ζ√k', () {
    final s = fittedSpring(0.79, 0.39);
    expect(s.mass, 1);
    expect(s.stiffness, closeTo(259.6, 0.1));
    expect(s.damping, closeTo(2 * 0.79 * math.sqrt(s.stiffness), 1e-9));
  });

  test('the research §7 table, stiffness per spring', () {
    expect(TabSprings.tap.stiffness, closeTo(260, 1));
    expect(TabSprings.snap.stiffness, closeTo(322, 1));
    expect(TabSprings.heightIn.stiffness, closeTo(342, 1));
    expect(TabSprings.widthIn.stiffness, closeTo(1094, 1));
    expect(TabSprings.scaleIn.stiffness, closeTo(411, 1));
    expect(TabSprings.scaleOut.stiffness, closeTo(322, 1));
    expect(TabSprings.effectIn.stiffness, closeTo(632, 1));
    expect(TabSprings.effectOut.stiffness, closeTo(158, 1));
    // Drag follow uses the primary fit, 0.33 s (spec §8.1).
    expect(TabSprings.dragFollow.stiffness, closeTo(362.5, 1));
  });

  for (final (name, spring) in [
    ('tap', TabSprings.tap),
    ('dragFollow', TabSprings.dragFollow),
    ('snap', TabSprings.snap),
    ('widthIn (overdamped)', TabSprings.widthIn),
    ('engageIn (stiff, critical)', TabSprings.engageIn),
  ]) {
    test('SpringValue follows SpringSimulation for $name within 0.05', () {
      final value = SpringValue(0, spring)..target = 86;
      final sim = SpringSimulation(spring, 0, 86, 0);
      for (var f = 1; f <= 90; f++) {
        value.advance(1 / 60);
        expect(value.value, closeTo(sim.x(f / 60), 0.05), reason: 'frame $f');
      }
    });
  }

  test('retarget keeps position and velocity (a moving target)', () {
    final value = SpringValue(0, TabSprings.dragFollow)
      ..target = 100
      ..advance(SpringValue.maxAdvance);
    final x = value.value;
    final v = value.velocity;
    value.retarget(50);
    expect(value.value, x);
    expect(value.velocity, v);
    expect(value.target, 50);
  });

  test('retarget can swap the spring', () {
    final value = SpringValue(0, TabSprings.dragFollow)
      ..retarget(10, TabSprings.snap);
    expect(value.spring, same(TabSprings.snap));
  });

  test('settled: close to the target and nearly still', () {
    final value = SpringValue(0, TabSprings.snap)..target = 40;
    expect(value.settled(0.5), isFalse);
    for (var f = 0; f < 120; f++) {
      value.advance(1 / 60);
    }
    expect(value.settled(0.5), isTrue);
  });

  test('jump stops at the value', () {
    final value = SpringValue(0, TabSprings.tap)
      ..target = 10
      ..advance(0.05)
      ..jump(3);
    expect(value.value, 3);
    expect(value.target, 3);
    expect(value.velocity, 0);
  });

  test('splitting dt gives the same trajectory', () {
    final whole = SpringValue(0, TabSprings.tap)..target = 86;
    final split = SpringValue(0, TabSprings.tap)..target = 86;
    for (var f = 1; f <= 60; f++) {
      whole.advance(1 / 60);
      split
        ..advance(1 / 180)
        ..advance(1 / 180)
        ..advance(1 / 180);
      expect(split.value, closeTo(whole.value, 1e-6), reason: 'frame $f');
      expect(split.velocity, closeTo(whole.velocity, 1e-4), reason: 'frame $f');
    }
  });

  test('a long frame drop advances at most maxAdvance (0.1 s)', () {
    expect(SpringValue.maxAdvance, 0.1);
    final dropped = SpringValue(0, TabSprings.tap)
      ..target = 86
      ..advance(30);
    final capped = SpringValue(0, TabSprings.tap)
      ..target = 86
      ..advance(SpringValue.maxAdvance);
    expect(dropped.value, capped.value);
    expect(dropped.velocity, capped.velocity);
  });

  group('SpringCurve (VK-503 Task 16: the search field on the bar clock)', () {
    final curve = SpringCurve(TabSprings.expand);

    test('ends at 0 and 1, and its duration is the settle time', () {
      expect(curve.transform(0), 0);
      expect(curve.transform(1), 1);
      final sim = SpringSimulation(TabSprings.expand, 0, 1, 0);
      final settle = curve.duration.inMicroseconds / 1e6;
      expect((sim.x(settle) - 1).abs(), lessThanOrEqualTo(0.002));
      expect((sim.x(settle - 0.001) - 1).abs(), greaterThan(0.002));
    });

    test('follows the spring step response, overshoot included', () {
      final sim = SpringSimulation(TabSprings.expand, 0, 1, 0);
      final seconds = curve.duration.inMicroseconds / 1e6;
      var peak = 0.0;
      for (var i = 1; i < 100; i++) {
        final t = i / 100;
        expect(curve.transform(t), closeTo(sim.x(t * seconds), 1e-9));
        peak = math.max(peak, curve.transform(t));
      }
      expect(peak, greaterThan(1));
    });
  });
}
