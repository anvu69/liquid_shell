import 'package:flutter/material.dart';

/// A deterministic wallpaper (no image assets) so glass has something to
/// blur. The example screens and the goldens use the same painter.
class Wallpaper extends StatelessWidget {
  /// Creates the wallpaper.
  const Wallpaper({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: WallpaperPainter(Theme.of(context).colorScheme),
    child: const SizedBox.expand(),
  );
}

/// Paints a soft gradient with a few large discs in scheme colours.
class WallpaperPainter extends CustomPainter {
  /// Creates the painter for [scheme].
  const WallpaperPainter(this.scheme);

  /// Colours to paint with.
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // The discs overhang the edges; keep them inside a wallpaper that is
    // narrower than the window (the narrow case).
    canvas
      ..clipRect(rect)
      ..drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.surface, scheme.surfaceContainerHighest],
          ).createShader(rect),
      );
    final discs = [
      (const Offset(0.15, 0.2), 0.35, scheme.primary),
      (const Offset(0.85, 0.35), 0.30, scheme.tertiary),
      (const Offset(0.3, 0.75), 0.40, scheme.secondary),
      (const Offset(0.9, 0.95), 0.30, scheme.primaryContainer),
    ];
    final unit = size.shortestSide;
    for (final (centre, radius, color) in discs) {
      canvas.drawCircle(
        Offset(centre.dx * size.width, centre.dy * size.height),
        radius * unit,
        Paint()..color = color.withValues(alpha: 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(WallpaperPainter oldDelegate) =>
      oldDelegate.scheme != scheme;
}
