import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/glass/outside_shadow.dart';
import 'package:liquid_shell/src/glass/renderer.dart';
import 'package:liquid_shell/src/glass/tier.dart';

/// Built-in frosted tier: blur → outside shadow → tint and border → rim.
class FrostedGlassRenderer extends LiquidGlassRenderer {
  /// Creates the frosted renderer.
  const FrostedGlassRenderer();

  /// Key of the rim highlight layer, for tests.
  static const rimKey = ValueKey<String>('liquid-glass-rim');

  @override
  LiquidGlassTier get tier => LiquidGlassTier.frosted;

  @override
  Widget buildBackground(BuildContext context, LiquidGlassSpec spec) {
    final theme = spec.theme;
    final radius = spec.borderRadius;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Shares one backdrop read with every sibling inside the nearest
        // BackdropGroup; outside a group it reads the backdrop on its own.
        ClipRRect(
          borderRadius: radius,
          child: BackdropFilter.grouped(
            filter: ui.ImageFilter.blur(
              sigmaX: theme.blurSigma,
              sigmaY: theme.blurSigma,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        // Above the blur, so the blur never samples the shadow.
        OutsideShadow(borderRadius: radius, shadow: theme.shadow),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.tint,
            borderRadius: radius,
            border: Border.all(color: theme.border, width: theme.borderWidth),
          ),
        ),
        CustomPaint(
          key: rimKey,
          painter: _RimPainter(radius, theme.rimHighlight),
        ),
      ],
    );
  }
}

/// A 1px stroke along the shape, from [color] at the top to transparent at
/// mid-height.
class _RimPainter extends CustomPainter {
  const _RimPainter(this.borderRadius, this.color);

  final BorderRadius borderRadius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.center,
        [color, color.withValues(alpha: 0)],
      );
    canvas.drawRRect(borderRadius.toRRect(rect).deflate(0.5), paint);
  }

  @override
  bool shouldRepaint(_RimPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius || oldDelegate.color != color;
}
