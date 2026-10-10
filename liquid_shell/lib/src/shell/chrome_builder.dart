import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/destinations/destination.dart';
import 'package:liquid_shell/src/destinations/tab_action.dart';
import 'package:liquid_shell/src/search/search_controller.dart';
import 'package:liquid_shell/src/shell/shell_layout.dart';
import 'package:liquid_shell/src/shell/strings.dart';

/// The two places the shell draws chrome.
enum LiquidChromeSlot {
  /// The tab bar (bottom or top, toggle included at the top).
  tabBar,

  /// The sidebar.
  sidebar,

  /// The search field (fallback): the ⌕ circle that becomes the field at
  /// compact width, the field below the top bar at regular width.
  searchField,
}

/// Replaces or wraps the shell's chrome for one slot.
///
/// [defaultChrome] is what the shell would have drawn. Return it wrapped,
/// or ignore it. The shell keeps placing and measuring the slot.
typedef LiquidChromeBuilder =
    Widget Function(
      BuildContext context,
      LiquidChromeDetails details,
      Widget defaultChrome,
    );

/// The search part of [LiquidChromeDetails].
@immutable
class LiquidSearchChromeDetails {
  /// Creates the details.
  const LiquidSearchChromeDetails({
    required this.phase,
    required this.controller,
    required this.previousIndex,
    required this.selectSearch,
  });

  /// The search phase.
  final LiquidSearchPhase phase;

  /// The app's controller.
  final LiquidSearchController controller;

  /// The destination the collapsed circle returns to.
  final int previousIndex;

  /// Selects the search tab through the guard.
  final VoidCallback selectSearch;

  @override
  bool operator ==(Object other) =>
      other is LiquidSearchChromeDetails &&
      other.phase == phase &&
      identical(other.controller, controller) &&
      other.previousIndex == previousIndex &&
      other.selectSearch == selectSearch;

  @override
  int get hashCode =>
      Object.hash(phase, controller, previousIndex, selectSearch);
}

/// Everything a [LiquidChromeBuilder] needs to draw a slot.
@immutable
class LiquidChromeDetails {
  /// Creates the details. Every field but [search] is required.
  const LiquidChromeDetails({
    required this.slot,
    required this.kind,
    required this.destinations,
    required this.visibleIndices,
    required this.selectedIndex,
    required this.select,
    required this.trailing,
    required this.minimized,
    required this.expand,
    required this.sidebarVisible,
    required this.setSidebarVisible,
    required this.strings,
    this.search,
  });

  /// The slot being built.
  final LiquidChromeSlot slot;

  /// The current chrome. Never [LiquidChromeKind.hidden]: the builder is not
  /// called then.
  final LiquidChromeKind kind;

  /// All destinations.
  final List<LiquidDestination> destinations;

  /// Indices into [destinations] this slot shows: everywhere-only for the
  /// tab bar, all for the sidebar.
  final List<int> visibleIndices;

  /// The selected index.
  final int selectedIndex;

  /// Runs the same path as a tap: guard, then `onDestinationSelected`, then
  /// close the overlay sidebar.
  final ValueChanged<int> select;

  /// The tab bar trailing action, if any.
  final LiquidTabAction? trailing;

  /// Tab bar slot, compact only: the bar is minimised.
  final bool minimized;

  /// Tab bar slot: leaves the minimised state.
  final VoidCallback expand;

  /// Whether the sidebar is shown.
  final bool sidebarVisible;

  /// Shows or hides the sidebar.
  final ValueSetter<bool> setSidebarVisible;

  /// The shell's strings.
  final LiquidShellStrings strings;

  /// The shell's search, when it has a search tab.
  final LiquidSearchChromeDetails? search;

  /// Field by field. Callbacks ([select], [expand], [setSidebarVisible])
  /// compare by identity.
  @override
  bool operator ==(Object other) =>
      other is LiquidChromeDetails &&
      other.slot == slot &&
      other.kind == kind &&
      listEquals(other.destinations, destinations) &&
      listEquals(other.visibleIndices, visibleIndices) &&
      other.selectedIndex == selectedIndex &&
      other.select == select &&
      other.trailing == trailing &&
      other.minimized == minimized &&
      other.expand == expand &&
      other.sidebarVisible == sidebarVisible &&
      other.setSidebarVisible == setSidebarVisible &&
      other.strings == strings &&
      other.search == search;

  @override
  int get hashCode => Object.hash(
    slot,
    kind,
    Object.hashAll(destinations),
    Object.hashAll(visibleIndices),
    selectedIndex,
    select,
    trailing,
    minimized,
    expand,
    sidebarVisible,
    setSidebarVisible,
    strings,
    search,
  );
}
