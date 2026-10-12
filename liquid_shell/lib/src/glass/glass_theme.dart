/// @docImport 'package:liquid_shell/src/segmented/segmented_control.dart';
library;

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
    // Native shows a fringe only on the touched lens (research §5).
    this.dispersion = 0,
    this.liquidBlurSigma = 2,
    this.selectionFill = const Color(0x14000000),
    this.tabForeground = const Color(0xFF191919),
    this.badgeColor = const Color(0xFFFF383C),
    this.tabIconSize = 26,
    this.segmentTrack = const Color(0x1F767680),
    this.segmentThumb = const Color(0xFFFFFFFF),
    this.segmentLabelStyle = _segmentLabelLight,
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
      // iOS 26.5: a barely visible top edge in light; in dark a ~1 pt rim
      // of 54 → 39 over the #191919 fill (spec VK-503 §6.4, research §5).
      rimHighlight: const Color(0xFFFFFFFF).withValues(alpha: 0.12),
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
      selectionFill: light ? const Color(0x14000000) : const Color(0x21FFFFFF),
      tabForeground: light ? const Color(0xFF191919) : const Color(0xFFF4F4F4),
      badgeColor: light ? const Color(0xFFFF383C) : const Color(0xFFFF4245),
      // Measured from UISegmentedControl, iOS 26.5 (spec VK-550 §6).
      segmentTrack: light ? const Color(0x1F767680) : const Color(0x3D767680),
      segmentThumb: light ? const Color(0xFFFFFFFF) : const Color(0x4DEBEBF5),
      segmentLabelStyle: light ? _segmentLabelLight : _segmentLabelDark,
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

  /// Tint inside the liquid lens. The liquid tier reads this, not [tint].
  ///
  /// When not given, it is a neutral milky fill picked by the brightness of
  /// [solid]: white @ 0.55 over a light [solid], #1C1C1C @ 0.90 over a dark
  /// one. That is native iOS 26.5 glass, which does not take the app's hue
  /// (spec VK-503 §6.4, Q14). [LiquidGlassTheme.fromColorScheme] uses the
  /// same default, and it follows `copyWith(solid: …)`.
  Color get liquidTint =>
      _liquidTint ??
      (ThemeData.estimateBrightnessForColor(solid) == Brightness.dark
          ? _liquidTintDark
          : _liquidTintLight);
  final Color? _liquidTint;

  // Fitted to native pixels (test/impeller/tab_material_test.dart): the
  // pill reads #FEFEFE over white and #191919 over black, and as milky as
  // native over the example's pages.
  static const Color _liquidTintLight = Color.from(
    alpha: 0.55,
    red: 1,
    green: 1,
    blue: 1,
  );
  static const Color _liquidTintDark = Color.from(
    alpha: 0.90,
    red: 28 / 255,
    green: 28 / 255,
    blue: 28 / 255,
  );

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

  /// [LiquidSegmentedControl] track fill, drawn over the page.
  final Color segmentTrack;

  /// [LiquidSegmentedControl] thumb at rest, drawn over the track.
  final Color segmentThumb;

  /// [LiquidSegmentedControl] labels at text scale 1.
  final TextStyle segmentLabelStyle;

  static const TextStyle _segmentLabelLight = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: Color(0xFF000000),
    height: 15.67 / 13,
  );
  static const TextStyle _segmentLabelDark = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: Color(0xFFFFFFFF),
    height: 15.67 / 13,
  );

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
    Color? segmentTrack,
    Color? segmentThumb,
    TextStyle? segmentLabelStyle,
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
    segmentTrack: segmentTrack ?? this.segmentTrack,
    segmentThumb: segmentThumb ?? this.segmentThumb,
    segmentLabelStyle: segmentLabelStyle ?? this.segmentLabelStyle,
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
      segmentTrack: Color.lerp(segmentTrack, other.segmentTrack, t)!,
      segmentThumb: Color.lerp(segmentThumb, other.segmentThumb, t)!,
      segmentLabelStyle: TextStyle.lerp(
        segmentLabelStyle,
        other.segmentLabelStyle,
        t,
      )!,
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
      other.tabIconSize == tabIconSize &&
      other.segmentTrack == segmentTrack &&
      other.segmentThumb == segmentThumb &&
      other.segmentLabelStyle == segmentLabelStyle;

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
    segmentTrack,
    segmentThumb,
    segmentLabelStyle,
  ]);
}
