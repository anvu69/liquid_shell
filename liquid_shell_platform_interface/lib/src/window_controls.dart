import 'package:flutter/foundation.dart';

/// How much of the top-leading corner the iPadOS 26 window controls (the
/// close, minimise and resize cluster of a windowed app) cover, in logical
/// pixels, measured from the safe area.
///
/// Zero on every other platform, on iPadOS before 26, in full screen, and
/// wherever native chrome already keeps content clear of the cluster.
@immutable
class LiquidWindowControls {
  /// Creates a value. Both fields default to 0.
  const LiquidWindowControls({this.leading = 0, this.top = 0});

  /// A value read across a platform boundary: a negative or non-finite
  /// field becomes 0.
  factory LiquidWindowControls.sanitized({
    required double leading,
    required double top,
  }) => LiquidWindowControls(leading: _clean(leading), top: _clean(top));

  /// No window controls.
  static const zero = LiquidWindowControls();

  static double _clean(double value) => value.isFinite && value > 0 ? value : 0;

  /// A row at the top of the window must start this far from the
  /// safe-area start edge to clear the cluster.
  final double leading;

  /// Content that should sit below the cluster starts this far below the
  /// safe-area top.
  final double top;

  /// Whether both fields are 0.
  bool get isZero => leading == 0 && top == 0;

  /// The start indent for a row whose top edge is [rowTop] below the
  /// safe-area top: [leading] while the row starts inside the cluster's
  /// band (`rowTop < top`), otherwise 0.
  double indentFor({required double rowTop}) => rowTop < top ? leading : 0;

  @override
  bool operator ==(Object other) =>
      other is LiquidWindowControls &&
      other.leading == leading &&
      other.top == top;

  @override
  int get hashCode => Object.hash(leading, top);

  @override
  String toString() => 'LiquidWindowControls(leading: $leading, top: $top)';
}
