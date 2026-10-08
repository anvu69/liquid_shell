import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/destinations/destination.dart';
import 'package:liquid_shell/src/shell/breakpoints.dart';

/// Which chrome the shell shows.
enum LiquidChromeKind {
  /// Compact: floating pill at the bottom.
  bottomBar,

  /// Regular with the sidebar hidden: pill at the top plus the toggle.
  topBar,

  /// Regular, sidebar shown over the body (the top bar stays underneath).
  sidebarOverlay,

  /// Regular, sidebar beside the body, no tab bar.
  sidebarTiled,

  /// A `LiquidHideChrome` is active.
  hidden,
}

/// How a layout presents navigation. Internal to the shell.
enum ShellPresentation {
  /// Bottom bar, no sidebar.
  compact,

  /// Sidebar covers the body when shown.
  overlay,

  /// Sidebar sits beside the body when shown.
  tiled,
}

/// Pill height of the bottom bar at text scale 1, used before measuring.
const double kBottomPillExtent = 62;

/// Gap between the safe area top and the top bar.
const double kTopBarGap = 20;

/// Pill height of the top bar at text scale 1, used before measuring.
const double kTopPillExtent = 52;

/// The presentation for the shell's constraints [size]. "Landscape" means
/// `width > height`.
ShellPresentation presentationFor(
  Size size,
  LiquidShellBreakpoints breakpoints,
) {
  if (breakpoints.sizeClassOf(size.width) == LiquidSizeClass.compact) {
    return ShellPresentation.compact;
  }
  return size.width >= breakpoints.tiledSidebar && size.width > size.height
      ? ShellPresentation.tiled
      : ShellPresentation.overlay;
}

/// The size class of a presentation.
LiquidSizeClass sizeClassOf(ShellPresentation presentation) =>
    presentation == ShellPresentation.compact
    ? LiquidSizeClass.compact
    : LiquidSizeClass.regular;

/// The chrome for a presentation, sidebar state and hide-chrome state.
LiquidChromeKind chromeKindFor({
  required ShellPresentation presentation,
  required bool sidebarVisible,
  required bool hidden,
}) {
  if (hidden) return LiquidChromeKind.hidden;
  return switch (presentation) {
    ShellPresentation.compact => LiquidChromeKind.bottomBar,
    ShellPresentation.overlay =>
      sidebarVisible
          ? LiquidChromeKind.sidebarOverlay
          : LiquidChromeKind.topBar,
    ShellPresentation.tiled =>
      sidebarVisible ? LiquidChromeKind.sidebarTiled : LiquidChromeKind.topBar,
  };
}

/// Sidebar visibility after a layout pass.
///
/// Compact is always hidden. A changed presentation resets to its default
/// (shown when tiled, hidden when overlay). Otherwise [visible] is kept.
bool sidebarVisibleFor({
  required ShellPresentation? previous,
  required ShellPresentation current,
  required bool visible,
}) {
  if (current == ShellPresentation.compact) return false;
  if (previous != current) return current == ShellPresentation.tiled;
  return visible;
}

/// Gap below the bottom pill (Q9): 21 over a gesture area (always on iOS;
/// on Android when the bottom gesture inset is non-zero), otherwise
/// `max(21, viewPadding.bottom + 8)` so a 3-button bar is never covered.
double bottomGapFor({
  required TargetPlatform platform,
  required double viewPaddingBottom,
  required double gestureInsetBottom,
}) {
  final gestureArea = platform == TargetPlatform.iOS || gestureInsetBottom > 0;
  return gestureArea ? 21 : math.max(21, viewPaddingBottom + 8);
}

/// The part of the body covered by chrome (§5.3). [measuredBar] is the
/// measured bar slot height, or null before the first measurement. A bar
/// measured at 0 (a custom bar collapsed away) covers nothing, so the
/// insets are zero: no gap or status bar band is added for it.
EdgeInsets chromeInsetsFor({
  required LiquidChromeKind kind,
  required double topPadding,
  required double? measuredBar,
  required double bottomGap,
}) => switch (kind) {
  _ when measuredBar == 0 => EdgeInsets.zero,
  LiquidChromeKind.bottomBar => EdgeInsets.only(
    bottom: (measuredBar ?? kBottomPillExtent) + bottomGap,
  ),
  LiquidChromeKind.topBar || LiquidChromeKind.sidebarOverlay => EdgeInsets.only(
    top: topPadding + kTopBarGap + (measuredBar ?? kTopPillExtent),
  ),
  LiquidChromeKind.sidebarTiled || LiquidChromeKind.hidden => EdgeInsets.zero,
};

/// [index] when it is in range, otherwise 0 (the release fallback).
int resolveSelectedIndex(int index, int length) =>
    index >= 0 && index < length ? index : 0;

/// Indices of the destinations the tab bar shows.
List<int> tabBarIndices(List<LiquidDestination> destinations) => [
  for (final (i, destination) in destinations.indexed)
    if (destination.placement == LiquidPlacement.everywhere) i,
];
