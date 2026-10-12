import 'package:flutter/physics.dart';

/// The time after which [xs] (one sample per [dt]) stays within
/// [tolerance] of [target]: the end of the last frame outside it.
double settleTime(
  List<double> xs,
  double target, {
  double dt = 1 / 60,
  double tolerance = 0.5,
}) {
  var last = -1;
  for (var i = 0; i < xs.length; i++) {
    if ((xs[i] - target).abs() > tolerance) last = i;
  }
  return (last + 1) * dt;
}

/// [spring] from [from] to [to], sampled once per [dt] like the motion
/// model, held at [from] for [delay] seconds.
List<double> referenceTrace(
  SpringDescription spring,
  double from,
  double to, {
  double delay = 0,
  double seconds = 2,
  double dt = 1 / 60,
  double velocity = 0,
}) {
  final sim = SpringSimulation(spring, from, to, velocity);
  final frames = (seconds / dt).round();
  return [
    for (var f = 1; f <= frames; f++)
      if (f * dt < delay) from else sim.x(f * dt - delay),
  ];
}
