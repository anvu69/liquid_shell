import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/glass/outside_shadow.dart';
import 'package:liquid_shell/src/glass/renderer.dart';
import 'package:liquid_shell/src/glass/tier.dart';

/// Built-in solid tier: outside shadow, opaque fill and border. No blur.
class SolidGlassRenderer extends LiquidGlassRenderer {
  /// Creates the solid renderer.
  const SolidGlassRenderer();

  @override
  LiquidGlassTier get tier => LiquidGlassTier.solid;

  @override
  Widget buildBackground(BuildContext context, LiquidGlassSpec spec) {
    final theme = spec.theme;
    return Stack(
      fit: StackFit.expand,
      children: [
        OutsideShadow(borderRadius: spec.borderRadius, shadow: theme.shadow),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.solid,
            borderRadius: spec.borderRadius,
            border: Border.all(color: theme.border, width: theme.borderWidth),
          ),
        ),
      ],
    );
  }
}
