import 'package:flutter/foundation.dart';

/// The two width classes of the shell.
enum LiquidSizeClass {
  /// Below `LiquidShellBreakpoints.regular`: bottom tab bar.
  compact,

  /// At or above it: sidebar and top tab bar.
  regular,
}

/// Width thresholds of the shell, in logical pixels of the shell's own
/// constraints (not the screen).
@immutable
class LiquidShellBreakpoints {
  /// Creates breakpoints. `0 < regular <= tiledSidebar`, `compactHeight >= 0`.
  const LiquidShellBreakpoints({
    this.regular = 700,
    this.tiledSidebar = 1024,
    this.compactHeight = 500,
  }) : assert(regular > 0, 'regular must be positive'),
       assert(tiledSidebar >= regular, 'tiledSidebar must be >= regular'),
       assert(compactHeight >= 0, 'compactHeight must not be negative');

  /// Widths below this are compact.
  final double regular;

  /// A regular layout tiles the sidebar beside the body only when it is
  /// landscape AND at least this wide. Otherwise the sidebar overlays.
  final double tiledSidebar;

  /// A landscape shell lower than this is compact (phones in landscape get
  /// the bottom bar, spec VK-503 §12.1). 0 restores P1.
  final double compactHeight;

  /// The size class of [width].
  LiquidSizeClass sizeClassOf(double width) =>
      width < regular ? LiquidSizeClass.compact : LiquidSizeClass.regular;

  @override
  bool operator ==(Object other) =>
      other is LiquidShellBreakpoints &&
      other.regular == regular &&
      other.tiledSidebar == tiledSidebar &&
      other.compactHeight == compactHeight;

  @override
  int get hashCode => Object.hash(regular, tiledSidebar, compactHeight);

  @override
  String toString() =>
      'LiquidShellBreakpoints(regular: $regular, tiledSidebar: $tiledSidebar, '
      'compactHeight: $compactHeight)';
}
