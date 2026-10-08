import 'package:flutter/widgets.dart';

/// Paints [shadow] only OUTSIDE the rounded shape, so it never shows
/// through a translucent fill drawn on top.
class OutsideShadow extends StatelessWidget {
  /// Creates an outside-only shadow for [borderRadius].
  const OutsideShadow({
    required this.borderRadius,
    required this.shadow,
    super.key,
  });

  /// Shape the shadow belongs to.
  final BorderRadius borderRadius;

  /// The shadow to paint.
  final BoxShadow shadow;

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: _OutsideOf(borderRadius, shadow),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [shadow],
      ),
    ),
  );
}

class _OutsideOf extends CustomClipper<Path> {
  const _OutsideOf(this.borderRadius, this.shadow);

  final BorderRadius borderRadius;
  final BoxShadow shadow;

  @override
  Path getClip(Size size) {
    final shape = Offset.zero & size;
    // Reach of the shadow: offset + spread + about 3 sigma of its blur.
    final reach =
        shadow.offset.distance +
        shadow.spreadRadius.abs() +
        shadow.blurRadius * 1.5 +
        8;
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(shape.inflate(reach)),
      Path()..addRRect(borderRadius.toRRect(shape)),
    );
  }

  @override
  bool shouldReclip(_OutsideOf oldClipper) =>
      oldClipper.borderRadius != borderRadius || oldClipper.shadow != shadow;
}
