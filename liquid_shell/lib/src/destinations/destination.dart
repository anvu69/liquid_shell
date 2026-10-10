import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/destinations/badge.dart';

/// Where a destination appears.
enum LiquidPlacement {
  /// Tab bar and sidebar.
  everywhere,

  /// Sidebar only. Never in the tab bar.
  sidebarOnly,
}

/// One navigation destination: a tab bar cell and a sidebar row.
@immutable
class LiquidDestination {
  /// Creates a destination.
  const LiquidDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.badge,
    this.placement = LiquidPlacement.everywhere,
    this.sfSymbol,
  });

  /// Icon when not selected. Sized and coloured by the shell.
  final Widget icon;

  /// Icon when selected. Falls back to [icon].
  final Widget? selectedIcon;

  /// Visible text and semantics label. Must not be empty, and must be
  /// unique within a `LiquidShell`'s destinations.
  final String label;

  /// Optional count or dot.
  final LiquidBadge? badge;

  /// Tab bar and sidebar, or sidebar only.
  final LiquidPlacement placement;

  /// SF Symbol name (for example `house`) for native chrome. Native chrome
  /// needs it: a shell uses native chrome only when every destination (and
  /// its trailing action) has one, and otherwise draws Flutter chrome, also
  /// on iOS 26. In debug, such a shell logs one line naming what lacks one.
  final String? sfSymbol;

  /// Field by field. Widgets ([icon], [selectedIcon]) compare by identity;
  /// use const or stable instances, or two equal-looking destinations are
  /// never `==`.
  @override
  bool operator ==(Object other) =>
      other is LiquidDestination &&
      other.icon == icon &&
      other.selectedIcon == selectedIcon &&
      other.label == label &&
      other.badge == badge &&
      other.placement == placement &&
      other.sfSymbol == sfSymbol;

  @override
  int get hashCode =>
      Object.hash(icon, selectedIcon, label, badge, placement, sfSymbol);
}
