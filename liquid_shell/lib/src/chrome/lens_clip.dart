import 'package:flutter/widgets.dart';

/// Inside or outside a lens capsule, in the clipped child's coordinates:
/// one widget draws its content twice, the normal copy
/// outside the lens and the tinted copy inside it.
class LensClip extends CustomClipper<Path> {
  /// Clips to [lens]'s capsule ([inside]) or to everything but it.
  const LensClip(this.lens, {required this.inside});

  /// The lens rect; its capsule radius is half the shorter side.
  final Rect lens;

  /// Keep the capsule (true) or cut it out (false).
  final bool inside;

  @override
  Path getClip(Size size) {
    final capsule = Path()
      ..addRRect(
        RRect.fromRectAndRadius(lens, Radius.circular(lens.shortestSide / 2)),
      );
    if (inside) return capsule;
    return Path.combine(
      PathOperation.difference,
      Path()..addRect((Offset.zero & size).inflate(64)),
      capsule,
    );
  }

  @override
  bool shouldReclip(LensClip oldClipper) =>
      oldClipper.lens != lens || oldClipper.inside != inside;
}
