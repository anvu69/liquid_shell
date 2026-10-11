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
    this._liquidTint,
    this.borderWidth = 1,
    this.blurSigma = 10,
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
    this.refraction = 1,
    this.dispersion = 0.3,
    this.liquidBlurSigma = 2,
    this.selectionFill = const Color(0x14000000),
    this.tabForeground = const Color(0xFF191919),
    this.badgeColor = const Color(0xFFFF383C),
    this.tabIconSize = 26,
  });

  /// Defaults for light and dark, derived from [scheme] (spec §5.9).
  factory LiquidGlassTheme.fromColorScheme(ColorScheme scheme) {
    final light = scheme.brightness == Brightness.light;
    return LiquidGlassTheme(
      tint: scheme.surface.withValues(alpha: light ? 0.72 : 0.90),
      solid: scheme.surface,
      liquidTint: scheme.surface.withValues(alpha: light ? 0.40 : 0.45),
      border: light
          ? scheme.outline.withValues(alpha: 0.28)
          : scheme.onSurface.withValues(alpha: 0.18),
      // iOS 26.5: a barely visible top edge in light, ~1 pt in dark
      // (spec VK-503 §6.4, research §5).
      rimHighlight: const Color(
        0xFFFFFFFF,
      ).withValues(alpha: light ? 0.12 : 0.22),
      shadow: const BoxShadow(
        color: Color(0x12000000),
        offset: Offset(0, 3),
        blurRadius: 20,
      ),
      labelStyle: const TextStyle(
        fontSize: 10,
        height: 1.2,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      // Native shows a fringe only on the active lens (research §5).
      dispersion: 0,
      selectionFill: light ? const Color(0x14000000) : const Color(0x21FFFFFF),
      tabForeground: light ? const Color(0xFF191919) : const Color(0xFFF4F4F4),
      badgeColor: light ? const Color(0xFFFF383C) : const Color(0xFFFF4245),
    );
  }

  /// The theme extension if present, otherwise one derived from
  /// `Theme.of(context).colorScheme`. Never throws.
  factory LiquidGlassTheme.of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<LiquidGlassTheme>() ??
        LiquidGlassTheme.fromColorScheme(theme.colorScheme);
  }

  /// Fill of the frosted tier only; the liquid tier reads [liquidTint].
  final Color tint;

  /// Fill of the solid tier.
  final Color solid;

  /// Outline colour of the frosted and solid tiers (liquid has none).
  final Color border;

  /// Outline width in logical pixels.
  final double borderWidth;

  /// Frosted top-edge highlight, fading to transparent at mid-height; also
  /// the colour of the liquid tier's specular rim.
  final Color rimHighlight;

  /// Drop shadow, drawn outside the shape only.
  final BoxShadow shadow;

  /// Backdrop blur sigma of the frosted tier only; the liquid tier reads
  /// [liquidBlurSigma].
  final double blurSigma;

  /// Default bar shape (a pill).
  final BorderRadius borderRadius;

  /// Compact tab labels.
  final TextStyle labelStyle;

  /// Tint inside the liquid lens; lighter than [tint]. The liquid tier
  /// reads this, not [tint].
  ///
  /// When not given, it is [solid] at 0.40 alpha, or 0.45 when [solid] is
  /// dark: the same as [LiquidGlassTheme.fromColorScheme], and it follows
  /// `copyWith(solid: …)`.
  Color get liquidTint =>
      _liquidTint ??
      solid.withValues(
        alpha: ThemeData.estimateBrightnessForColor(solid) == Brightness.dark
            ? 0.45
            : 0.40,
      );
  final Color? _liquidTint;

  /// Liquid lens thickness multiplier: 0 is flat glass, 1 the default.
  final double refraction;

  /// Liquid colour fringe in the bezel, 0 (off) to 1. Default 0: native
  /// shows a fringe only on the active tab lens, which sets its own.
  final double dispersion;

  /// Logical sigma of the blur under the liquid lens. 0 turns it off.
  final double liquidBlurSigma;

  /// The selected tab lens at rest: a neutral fill over the pill (spec
  /// VK-503 §6.2).
  final Color selectionFill;

  /// Unselected tab icons and labels.
  final Color tabForeground;

  /// Tab bar badge capsule.
  final Color badgeColor;

  /// Tab bar icon size at text scale 1.
  final double tabIconSize;

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
    Color? liquidTint,
    double? refraction,
    double? dispersion,
    double? liquidBlurSigma,
    Color? selectionFill,
    Color? tabForeground,
    Color? badgeColor,
    double? tabIconSize,
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
    liquidTint: liquidTint ?? _liquidTint,
    refraction: refraction ?? this.refraction,
    dispersion: dispersion ?? this.dispersion,
    liquidBlurSigma: liquidBlurSigma ?? this.liquidBlurSigma,
    selectionFill: selectionFill ?? this.selectionFill,
    tabForeground: tabForeground ?? this.tabForeground,
    badgeColor: badgeColor ?? this.badgeColor,
    tabIconSize: tabIconSize ?? this.tabIconSize,
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
      liquidTint: Color.lerp(liquidTint, other.liquidTint, t),
      refraction: lerpDouble(refraction, other.refraction, t)!,
      dispersion: lerpDouble(dispersion, other.dispersion, t)!,
      liquidBlurSigma: lerpDouble(liquidBlurSigma, other.liquidBlurSigma, t)!,
      selectionFill: Color.lerp(selectionFill, other.selectionFill, t)!,
      tabForeground: Color.lerp(tabForeground, other.tabForeground, t)!,
      badgeColor: Color.lerp(badgeColor, other.badgeColor, t)!,
      tabIconSize: lerpDouble(tabIconSize, other.tabIconSize, t)!,
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
      other.labelStyle == labelStyle &&
      other.liquidTint == liquidTint &&
      other.refraction == refraction &&
      other.dispersion == dispersion &&
      other.liquidBlurSigma == liquidBlurSigma &&
      other.selectionFill == selectionFill &&
      other.tabForeground == tabForeground &&
      other.badgeColor == badgeColor &&
      other.tabIconSize == tabIconSize;

  @override
  int get hashCode => Object.hashAll([
    tint,
    solid,
    border,
    borderWidth,
    rimHighlight,
    shadow,
    blurSigma,
    borderRadius,
    labelStyle,
    liquidTint,
    refraction,
    dispersion,
    liquidBlurSigma,
    selectionFill,
    tabForeground,
    badgeColor,
    tabIconSize,
  ]);
}
