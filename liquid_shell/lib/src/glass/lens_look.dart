import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The engaged tab lens's veil over the page: native's milky core (spec
/// VK-503 §7.2, about 10 % of the backdrop passes).
const double kLensVeil = 0.90;

/// The dark engaged lens's veil colour: native's held lens reads 61 luma
/// in its core over the example's dark page (idb dark press strip), where
/// `colorScheme.surface` made a near-black disc (23). Task 16 part B.
const Color kLensVeilDark = Color(0xFF414141);

/// How far the dark lens's veil thins in its ring. Native's dark ring keeps
/// some veil (ring luma 57 against the core's 60); at 1 the Flutter ring
/// read p99 chroma 102 on the simulator against native's 64, at 0.8 it
/// reads 85 (idb dark press strip). Task 16 part B.
const double kLensVeilFalloffDark = 0.8;

/// The engaged tab lens's refracting ring, in points (spec §7.2).
const double kLensBezel = 14;

/// The blur before the tab lens shader, logical sigma (spec §7.2).
const double kLensBlurSigma = 2;

/// What an engaged lens looks like: the lens shader's optics at engage 1,
/// and what they fade from at engage 0 (spec VK-503 §7.2, VK-550 §7).
@immutable
final class LensLook {
  /// Creates a look.
  const LensLook({
    required this.overGlass,
    required this.veil,
    required this.veilLight,
    required this.veilDark,
    required this.veilFalloffLight,
    required this.veilFalloffDark,
    required this.thickness,
    required this.dispersion,
    required this.blurSigma,
    required this.bezel,
    required this.rim,
    required this.rimWidth,
    this.saturation,
    this.squeeze = 0,
  });

  /// The lens sits on glass (the tab pill): at engage 0 it is that glass's
  /// own optics, and the host paints the rest fill under it. Otherwise
  /// (the segment's flat track) it fades from clear, unrefracted glass and
  /// paints the rest fill itself in every tier, so the fill is drawn once.
  final bool overGlass;

  /// The veil's alpha at engage 1.
  final double veil;

  /// The veil's colour in light.
  final Color veilLight;

  /// The veil's colour in dark.
  final Color veilDark;

  /// How much the veil thins toward the rim at engage 1, light (0–1).
  final double veilFalloffLight;

  /// How much the veil thins toward the rim at engage 1, dark (0–1).
  final double veilFalloffDark;

  /// Glass thickness, a multiple of `LiquidOptics.thickness` at refraction 1.
  final double thickness;

  /// Colour fringe in the ring at refraction 1 (0–1).
  final double dispersion;

  /// Logical blur sigma before the shader at engage 1.
  final double blurSigma;

  /// The refracting ring, in points.
  final double bezel;

  /// The specular rim's colour (alpha = strength) at engage 1.
  final Color rim;

  /// The specular rim's width, in points, at engage 1.
  final double rimWidth;

  /// Vibrancy; null keeps `LiquidOptics.saturation`.
  final double? saturation;

  /// At refraction 1, how much farther from the lens's spine the page is
  /// read (`LiquidOpticsParams.squeeze`): the page under the lens shows
  /// 1 / (1 + squeeze) of its size across the height. 0 for the tab.
  final double squeeze;

  /// VK-503's tab lens: milky in the core, a clear refracting ring, over
  /// the pill's glass.
  static const LensLook tab = LensLook(
    overGlass: true,
    veil: kLensVeil,
    veilLight: Color(0xFFFFFFFF),
    veilDark: kLensVeilDark,
    veilFalloffLight: 1,
    veilFalloffDark: kLensVeilFalloffDark,
    thickness: 1.6,
    dispersion: 0.6,
    blurSigma: kLensBlurSigma,
    bezel: kLensBezel,
    rim: Color.from(alpha: 0.35, red: 1, green: 1, blue: 1),
    rimWidth: 1,
  );

  /// VK-550's segment lens (spec §7, Task 15): clear glass on a flat
  /// track, tuned against native's held lens in the segment strips
  /// (`native_reference.json` `lens.look`): the page passes with its
  /// colours (core chroma 0.96 of the page's, native 0.965) a little darker,
  /// squeezed to 1 / 1.22 across the height as native's (squeeze 0.22:
  /// 1.226 against 1.225 / 1.231), bent about 3 pt in its ring (3.1 / 3.0
  /// against 3.0 / 3.4, thickness 0.2 with the full fringe), under a thin
  /// bright rim. The tab's thickness bent rays 59 pt in: a black rim.
  static const LensLook segment = LensLook(
    overGlass: false,
    veil: 0.04,
    veilLight: Color(0xFF000000),
    veilDark: Color(0xFF000000),
    veilFalloffLight: 0,
    veilFalloffDark: 0,
    thickness: 0.2,
    dispersion: 1,
    blurSigma: 0,
    bezel: 9,
    rim: Color.from(alpha: 0.5, red: 1, green: 1, blue: 1),
    rimWidth: 1,
    saturation: 1,
    squeeze: 0.22,
  );
}
