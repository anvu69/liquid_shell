import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curve;
import 'package:flutter/physics.dart';

/// A spring from a least-squares fit: damping ratio [ratio] and undamped
/// period [response] in seconds (spec VK-503 §8.1).
SpringDescription fittedSpring(double ratio, double response) =>
    SpringDescription.withDampingRatio(
      mass: 1,
      stiffness: math.pow(2 * math.pi / response, 2).toDouble(),
      ratio: ratio,
    );

/// Springs and envelope constants of the tab lens (spec §8, research §3,
/// §4, §6, §7). The envelope constants are the only tuning knobs (§8.3).
abstract final class TabSprings {
  /// Lens x after a tap; icon pop.
  static final SpringDescription tap = fittedSpring(0.79, 0.39);

  /// Lens x following the finger.
  static final SpringDescription dragFollow = fittedSpring(0.75, 0.33);

  /// Lens x after a drag release, or back after a rejected commit.
  static final SpringDescription snap = fittedSpring(0.92, 0.35);

  /// Lens height growing.
  static final SpringDescription heightIn = fittedSpring(0.72, 0.34);

  /// Lens height shrinking.
  static final SpringDescription heightOut = fittedSpring(0.77, 0.36);

  /// Lens width growing.
  static final SpringDescription widthIn = fittedSpring(1.4, 0.19);

  /// Lens width shrinking.
  static final SpringDescription widthOut = fittedSpring(1.5, 0.16);

  /// Pill scale growing.
  static final SpringDescription scaleIn = fittedSpring(0.63, 0.31);

  /// Pill scale shrinking.
  static final SpringDescription scaleOut = fittedSpring(0.61, 0.35);

  /// Refraction in.
  static final SpringDescription effectIn = fittedSpring(1, 0.25);

  /// Refraction, highlight and glow out.
  static final SpringDescription effectOut = fittedSpring(1, 0.5);

  /// Pill highlight in (≈ 0.10 s).
  static final SpringDescription highlightIn = fittedSpring(1, 0.10);

  /// Lens engage in (≈ 60 ms, native `opacityPair`).
  static final SpringDescription engageIn = fittedSpring(1, 0.065);

  /// Lens engage out.
  static final SpringDescription engageOut = fittedSpring(1, 0.2);

  /// Finger glow in (≈ 0.08 s).
  static final SpringDescription glowIn = fittedSpring(1, 0.08);

  /// Minimize collapse.
  static final SpringDescription collapse = fittedSpring(0.8, 0.30);

  /// Minimize expand (small overshoot). Research §6 gives only "≈ 0.35 s,
  /// small overshoot"; ζ 0.80 makes the 3-tab pill's right edge overshoot
  /// ≈ 4 pt, as the native TabFid expand strip shows (ζ 0.70: ≈ 12 pt, and
  /// a full-width pill brushed the ⌕). VK-503 Task 16.
  static final SpringDescription expand = fittedSpring(0.8, 0.35);

  /// Reduce motion: the rest-size capsule following the finger.
  static final SpringDescription reduced = fittedSpring(1, 0.25);

  /// Delay between a tap and the lens leaving (research §3).
  static const double tapDelay = 0.025;

  /// A tap shows the press (swell, engage) for at least this long from the
  /// down, then its flight envelope. Every measured native tap was a
  /// 65-66 ms press (research §3 trace), and the native lens swells to
  /// about 96 × 60 before it lifts, even for idb taps shorter than that.
  static const double tapPress = 0.066;

  /// After a press is lifted in place, the lens stays clear this long
  /// (research §4.1 trace: opacityPair 1.0 to +0.10 s, 0.93 at +0.13 s).
  static const double releaseHold = 0.12;

  /// The lens stays engaged this long after a tap.
  static const double flightHold = 0.35;

  /// The flight's shape (a one-slot lift, a two-slot stretch) is held this
  /// long from the down. Fitted to the native per-frame traces: the
  /// one-slot height peaks near 0.20 s (81.8 pt) and is back to 70.7 by
  /// 0.30 s; the two-slot width holds about 125 pt to 0.22 s (research §3;
  /// Task 16 review, was 0.25 for both the shape and the refraction).
  static const double liftUntil = 0.22;

  /// Two slots or more lift late, after the stretch, until this long from
  /// the down (research §3 trace: 107 × 67 at 0.30 s).
  static const double farLiftUntil = 0.34;

  /// Refraction lasts this long after a tap (research §3: the displacement
  /// peaks at about 0.25 s).
  static const double refractUntil = 0.25;

  /// The target icon pops this long.
  static const double popUntil = 0.22;

  /// The pill bulges this long after a tap.
  static const double bulgeUntil = 0.12;

  /// The tap highlight impulse lasts this long.
  static const double highlightUntil = 0.10;

  /// Pill scale during a tap bulge.
  static const double bulge = 1.022;

  /// Pressed lens width factor.
  static const double pressWidthFactor = 1.17;

  /// Pressed lens height factor.
  static const double pressHeightFactor = 1.30;

  /// Pressed pill scale.
  static const double pressScale = 1.052;

  /// Pill highlight while pressed.
  static const double highlightPress = 0.845;

  /// Pill highlight impulse on a tap.
  static const double highlightTap = 0.7;

  /// Finger glow opacity.
  static const double glowOpacity = 0.28;

  /// Finger glow diameter on touch-down.
  static const double glowDiameter = 93;

  /// Finger glow diameter while held.
  static const double glowHeldDiameter = 98;

  /// Ripple growth on release.
  static const double glowRipple = 4;

  /// Ripple duration.
  static const double glowFade = 0.5;

  /// Icon pop scale.
  static const double pop = 1.16;

  /// Magnification of the tinted copy at full engage.
  static const double magnify = 0.16;

  /// Flight width floor (one slot). The native one-slot lens narrows to
  /// 84.8 pt (×0.902) at 0.20 s; behind the `widthOut` spring a ×0.87
  /// target reaches ×0.909 in the shorter shape window (Task 16 review,
  /// was 0.9).
  static const double stretchFloor = 0.87;

  /// Lens speed above which the flight width stretches.
  static const double stretchKnee = 700;

  /// Width gain per pt/s above the knee. At 0.005 the target saturates at
  /// [stretchMax] by 790 pt/s, so the stretch is effectively a step at the
  /// knee (spec §8.3).
  static const double stretchGain = 0.005;

  /// Flight width ceiling. Above the native peak because the `widthIn`
  /// spring lags the target: with the stretch held to [liftUntil], 1.425
  /// gives the native two-slot peak, 127.4 pt (×1.355) at 0.18–0.22 s
  /// (research §3 trace; Task 16 review, was 1.46 for ×1.331).
  static const double stretchMax = 1.425;

  /// Flight height gain.
  static const double liftGain = 0.55;

  /// Lift gate for two or more slots.
  static const double liftGateFar = 0.45;

  /// Top bar tap inflation, width and height (research §1.3).
  static const double topTapWidth = 1.34;

  /// Top bar tap inflation, height.
  static const double topTapHeight = 1.375;

  /// Finger speed at release above which the finger's slot wins.
  static const double flickVelocity = 600;

  /// Reduce motion: tap dissolve duration.
  static const double ghostFade = 0.15;

  /// Delay before a scroll collapses the bar.
  static const double minimizeDelay = 0.24;

  /// Minimize dip depth (×0.96 at the midpoint).
  static const double dip = 0.04;

  /// Lens velocity → flight width factor (spec §8.3).
  static double stretchFor(double velocity) =>
      (stretchFloor + stretchGain * math.max(0, velocity.abs() - stretchKnee))
          .clamp(stretchFloor, stretchMax);
}

/// One value on a spring toward a target that may move every frame,
/// integrated with classic Runge-Kutta (RK4) in fixed 1 ms steps.
class SpringValue {
  /// Starts at rest at [value].
  SpringValue(double value, this.spring) : _value = value, target = value;

  /// The current spring.
  SpringDescription spring;

  /// Where the value is heading.
  double target;

  double _value;
  double _velocity = 0;

  /// The current value.
  double get value => _value;

  /// The current velocity per second.
  double get velocity => _velocity;

  /// Integration step.
  static const double step = 0.001;

  /// The most one [advance] call integrates: a long frame drop costs at
  /// most 100 steps instead of spinning thousands.
  static const double maxAdvance = 0.1;

  /// Moves [dt] seconds forward, at most [maxAdvance].
  void advance(double dt) {
    var left = math.min(dt, maxAdvance);
    while (left > 1e-9) {
      final h = math.min(left, step);
      _rk4(h);
      left -= h;
    }
  }

  double _accel(double x, double v) =>
      (-spring.stiffness * (x - target) - spring.damping * v) / spring.mass;

  void _rk4(double h) {
    final x = _value;
    final v = _velocity;
    final a1 = _accel(x, v);
    final v2 = v + a1 * h / 2;
    final a2 = _accel(x + v * h / 2, v2);
    final v3 = v + a2 * h / 2;
    final a3 = _accel(x + v2 * h / 2, v3);
    final v4 = v + a3 * h;
    final a4 = _accel(x + v3 * h, v4);
    _value = x + h / 6 * (v + 2 * v2 + 2 * v3 + v4);
    _velocity = v + h / 6 * (a1 + 2 * a2 + 2 * a3 + a4);
  }

  /// Sets a new [target] (and [newSpring]) without touching the motion.
  void retarget(double target, [SpringDescription? newSpring]) {
    this.target = target;
    if (newSpring != null) spring = newSpring;
  }

  /// Stops at [value].
  void jump(double value) {
    _value = value;
    target = value;
    _velocity = 0;
  }

  /// Within [tolerance] of the target and slower than 4 × tolerance per
  /// second.
  bool settled(double tolerance) =>
      (_value - target).abs() <= tolerance && _velocity.abs() <= tolerance * 4;
}

/// A spring's step response from 0 to 1 as a [Curve] that lasts
/// [duration]: the time after which it stays within 0.002 of 1 (the last
/// step to exactly 1 is under half a point on the search field). An
/// implicit animation (`AnimatedPositioned`) with it moves on the same
/// clock as a [SpringValue] on [spring] that starts at rest: the compact
/// search field and the tab bar's minimize morph (VK-503 Task 16).
class SpringCurve extends Curve {
  /// The step response of [spring].
  SpringCurve(this.spring)
    : _simulation = SpringSimulation(spring, 0, 1, 0),
      duration = _settle(spring);

  /// The spring.
  final SpringDescription spring;

  /// How long the curve lasts.
  final Duration duration;

  final SpringSimulation _simulation;

  static Duration _settle(SpringDescription spring) {
    final simulation = SpringSimulation(spring, 0, 1, 0);
    var last = 0;
    for (var ms = 0; ms <= 2000; ms++) {
      if ((simulation.x(ms / 1000) - 1).abs() > 0.002) last = ms;
    }
    return Duration(milliseconds: last + 1);
  }

  @override
  double transformInternal(double t) =>
      _simulation.x(t * duration.inMicroseconds / 1e6);
}
