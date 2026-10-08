import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Colours and shapes of `liquid_shell` glass.
///
/// Add it to `ThemeData.extensions` to override the defaults; without it,
/// [LiquidGlassTheme.of] derives one from the displayed [ColorScheme].
@immutable
class LiquidGlassTheme extends ThemeExtension<LiquidGlassTheme> {
  /// Creates a glass theme.
  const LiquidGlassTheme({
    required this.tint,
    required this.solid,
    required this.border,
    required this.rimHighlight,
    required this.shadow,
    required this.labelStyle,
    this.borderWidth = 1,
    this.blurSigma = 10,
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
  });

  /// Defaults for light and dark, derived from [scheme] (spec §5.9).
  factory LiquidGlassTheme.fromColorScheme(ColorScheme scheme) {
    final light = scheme.brightness == Brightness.light;
    return LiquidGlassTheme(
      tint: scheme.surface.withValues(alpha: light ? 0.72 : 0.90),
      solid: scheme.surface,
      border: light
          ? scheme.outline.withValues(alpha: 0.28)
          : scheme.onSurface.withValues(alpha: 0.18),
      rimHighlight: const Color(
        0xFFFFFFFF,
      ).withValues(alpha: light ? 0.50 : 0.18),
      shadow: const BoxShadow(
        color: Color(0x24000000),
        offset: Offset(0, 6),
        blurRadius: 20,
        spreadRadius: -2,
      ),
      labelStyle: const TextStyle(
        fontSize: 10,
        height: 1.4,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }

  /// The theme extension if present, otherwise one derived from
  /// `Theme.of(context).colorScheme`. Never throws.
  static LiquidGlassTheme of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<LiquidGlassTheme>() ??
        LiquidGlassTheme.fromColorScheme(theme.colorScheme);
  }

  /// Frosted fill.
  final Color tint;

  /// Solid fill.
  final Color solid;

  /// Outline colour.
  final Color border;

  /// Outline width in logical pixels.
  final double borderWidth;

  /// Frosted top-edge highlight, fading to transparent at mid-height.
  final Color rimHighlight;

  /// Drop shadow, drawn outside the shape only.
  final BoxShadow shadow;

  /// Backdrop blur sigma of the frosted tier.
  final double blurSigma;

  /// Default bar shape (a pill).
  final BorderRadius borderRadius;

  /// Compact tab labels.
  final TextStyle labelStyle;

  @override
  LiquidGlassTheme copyWith({
    Color? tint,
    Color? solid,
    Color? border,
    double? borderWidth,
    Color? rimHighlight,
    BoxShadow? shadow,
    double? blurSigma,
    BorderRadius? borderRadius,
    TextStyle? labelStyle,
  }) => LiquidGlassTheme(
    tint: tint ?? this.tint,
    solid: solid ?? this.solid,
    border: border ?? this.border,
    borderWidth: borderWidth ?? this.borderWidth,
    rimHighlight: rimHighlight ?? this.rimHighlight,
    shadow: shadow ?? this.shadow,
    blurSigma: blurSigma ?? this.blurSigma,
    borderRadius: borderRadius ?? this.borderRadius,
    labelStyle: labelStyle ?? this.labelStyle,
  );

  @override
  LiquidGlassTheme lerp(covariant LiquidGlassTheme? other, double t) {
    if (other == null) return this;
    return LiquidGlassTheme(
      tint: Color.lerp(tint, other.tint, t)!,
      solid: Color.lerp(solid, other.solid, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderWidth: lerpDouble(borderWidth, other.borderWidth, t)!,
      rimHighlight: Color.lerp(rimHighlight, other.rimHighlight, t)!,
      shadow: BoxShadow.lerp(shadow, other.shadow, t)!,
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t)!,
      borderRadius: BorderRadius.lerp(borderRadius, other.borderRadius, t)!,
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LiquidGlassTheme &&
      other.tint == tint &&
      other.solid == solid &&
      other.border == border &&
      other.borderWidth == borderWidth &&
      other.rimHighlight == rimHighlight &&
      other.shadow == shadow &&
      other.blurSigma == blurSigma &&
      other.borderRadius == borderRadius &&
      other.labelStyle == labelStyle;

  @override
  int get hashCode => Object.hash(
    tint,
    solid,
    border,
    borderWidth,
    rimHighlight,
    shadow,
    blurSigma,
    borderRadius,
    labelStyle,
  );
}
