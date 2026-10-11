import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:liquid_shell/src/glass/glass_theme.dart';

/// Internal optics of the liquid tier (spec §4, §5.6). Lengths are logical
/// pixels; [liquidUniforms] scales them to pass pixels.
abstract final class LiquidOptics {
  /// Width of the curved band inside the edge. Wide and deep enough that
  /// the band mirrors what lies inside it, as iOS 26 glass does (§3.6.1).
  static const double bezel = 20;

  /// Glass thickness at `refraction` 1.
  static const double thickness = 48;

  /// Refractive index (crown glass).
  static const double index = 1.5;

  /// Width of the specular rim.
  static const double rimWidth = 1.5;

  /// Vibrancy: 1 keeps the colours, above 1 saturates.
  static const double saturation = 1.1;

  /// Direction toward the light, y down (top-left).
  static const Offset light = Offset(-0.5, -0.85);

  /// Shader float index of the first value [liquidUniforms] returns
  /// (0 and 1 are the engine's size uniform).
  static const int firstIndex = 2;

  /// Number of floats [liquidUniforms] returns.
  static const int floatCount = 24;
}

/// What the shader needs besides the geometry, from `LiquidGlassTheme`.
@immutable
class LiquidOpticsParams {
  /// Creates a parameter set.
  const LiquidOpticsParams({
    required this.tint,
    required this.rim,
    required this.refraction,
    required this.dispersion,
    required this.blurSigma,
  });

  /// The liquid fields of [theme]; the rim uses `rimHighlight`.
  factory LiquidOpticsParams.fromTheme(LiquidGlassTheme theme) =>
      LiquidOpticsParams(
        tint: theme.liquidTint,
        rim: theme.rimHighlight,
        refraction: theme.refraction,
        dispersion: theme.dispersion,
        blurSigma: theme.liquidBlurSigma,
      );

  /// Tint mixed over the refracted backdrop (alpha = amount).
  final Color tint;

  /// Specular rim colour (alpha = strength).
  final Color rim;

  /// Thickness multiplier; 0 is flat glass.
  final double refraction;

  /// Colour fringe in the bezel, 0–1.
  final double dispersion;

  /// Logical sigma of the blur chained before the shader.
  final double blurSigma;

  @override
  bool operator ==(Object other) =>
      other is LiquidOpticsParams &&
      other.tint == tint &&
      other.rim == rim &&
      other.refraction == refraction &&
      other.dispersion == dispersion &&
      other.blurSigma == blurSigma;

  @override
  int get hashCode => Object.hash(tint, rim, refraction, dispersion, blurSigma);
}

/// The floats for shader indices 2–25 (spec §4.2), in pass pixels.
///
/// [rect] is the glass in pass pixels and [radii] its drawn corners in
/// logical pixels. [scale] is pass pixels per logical pixel, and [pass] the
/// pass size in pixels. A side within half a pixel of the pass edge is
/// pushed out of the pass so it gets no bezel and no rim (screen-edge rule).
Float32List liquidUniforms({
  required Rect rect,
  required BorderRadius radii,
  required LiquidOpticsParams params,
  required double scale,
  required Size pass,
}) {
  final half = math.min(rect.width, rect.height) / 2;
  double corner(Radius r) => math.min(r.x * scale, half);
  final tl = corner(radii.topLeft);
  final tr = corner(radii.topRight);
  final br = corner(radii.bottomRight);
  final bl = corner(radii.bottomLeft);
  final bezel = (LiquidOptics.bezel * scale)
      .clamp(1.0, math.max(1.0, half))
      .toDouble();

  final reach = bezel + math.max(math.max(tl, tr), math.max(br, bl)) + 2;
  const edge = 0.5;
  final left = rect.left <= edge ? rect.left - reach : rect.left;
  final top = rect.top <= edge ? rect.top - reach : rect.top;
  final right = rect.right >= pass.width - edge
      ? rect.right + reach
      : rect.right;
  final bottom = rect.bottom >= pass.height - edge
      ? rect.bottom + reach
      : rect.bottom;

  return Float32List.fromList([
    left,
    top,
    right - left,
    bottom - top,
    tl,
    tr,
    br,
    bl,
    bezel,
    LiquidOptics.thickness * params.refraction * scale,
    LiquidOptics.index,
    params.dispersion.clamp(0.0, 1.0),
    params.tint.r,
    params.tint.g,
    params.tint.b,
    params.tint.a,
    params.rim.r,
    params.rim.g,
    params.rim.b,
    params.rim.a,
    LiquidOptics.light.dx,
    LiquidOptics.light.dy,
    LiquidOptics.rimWidth * scale,
    LiquidOptics.saturation,
  ]);
}

/// Signed inward displacement at bezel coordinate [x] (0 at the edge, 1
/// where the bezel flattens), in the unit of [bezel] and [thickness].
///
/// The Dart mirror of the shader's `displacement` along the normal (spec
/// §4.1 steps 4–7), for tests and docs. Negative means inward.
double liquidDisplacement(
  double x, {
  double bezel = LiquidOptics.bezel,
  double thickness = LiquidOptics.thickness,
  double index = LiquidOptics.index,
}) {
  if (x >= 1 || thickness <= 0) return 0;
  double height(double x) {
    final u = 1 - x;
    return math.pow(math.max(1 - u * u * u * u, 0), 0.25).toDouble();
  }

  final xc = math.max(x, 0.02);
  final u = 1 - xc;
  final inner = math.max(1 - u * u * u * u, 1e-4);
  final bezelSlope = u * u * u * math.pow(inner, -0.75);
  final s = math.min<double>(thickness / bezel * bezelSlope, 8);
  final length = math.sqrt(s * s + 1);
  final nx = s / length;
  final nz = 1 / length;
  // refract(I = (0, 0, -1), N, 1 / index), as GLSL defines it.
  final eta = 1 / index;
  final cosI = nz;
  final k = 1 - eta * eta * (1 - cosI * cosI);
  if (k < 0) return 0;
  final coef = eta * cosI - math.sqrt(k);
  final rx = coef * nx;
  final rz = -eta + coef * nz;
  return rx * thickness * height(x) / math.max(-rz, 0.2);
}
