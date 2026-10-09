import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/glass/glass_theme.dart';
import 'package:liquid_shell/src/glass/tier.dart';

/// What a [LiquidGlassRenderer] needs to draw one surface.
@immutable
class LiquidGlassSpec {
  /// Creates a spec.
  const LiquidGlassSpec({required this.borderRadius, required this.theme});

  /// Shape of the surface.
  final BorderRadius borderRadius;

  /// Colours and blur.
  final LiquidGlassTheme theme;

  @override
  bool operator ==(Object other) =>
      other is LiquidGlassSpec &&
      other.borderRadius == borderRadius &&
      other.theme == theme;

  @override
  int get hashCode => Object.hash(borderRadius, theme);
}

/// Draws the background of a glass surface for one [LiquidGlassTier].
///
/// Register extra renderers (for example a liquid adapter) through
/// `LiquidGlassPolicy.renderers`.
abstract class LiquidGlassRenderer {
  /// Const constructor for subclasses.
  const LiquidGlassRenderer();

  /// The tier this renderer draws.
  LiquidGlassTier get tier;

  /// Whether this renderer can draw on this device right now.
  bool isSupported(BuildContext context) => true;

  /// The background layer only (blur, tint, rim, shadow), sized to fill its
  /// parent. Must not paint outside the shape except for a shadow.
  Widget buildBackground(BuildContext context, LiquidGlassSpec spec);
}
