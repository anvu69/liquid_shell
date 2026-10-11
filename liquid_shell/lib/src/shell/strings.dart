import 'package:flutter/foundation.dart';

/// Every user-visible string of the shell, with English defaults.
///
/// Destination labels and the trailing action label come from the app
/// (`LiquidDestination.label`, `LiquidTabAction.semanticLabel`). Localise by
/// building this object from your own i18n system.
@immutable
class LiquidShellStrings {
  /// Creates the strings. Every argument has an English default.
  const LiquidShellStrings({
    this.showSidebar = 'Show sidebar',
    this.hideSidebar = 'Hide sidebar',
    this.tabBarExpanded = 'Navigation bar opened',
    this.expandTabBarHint = 'Tap to open the navigation bar',
    this.badgeDot = 'New',
    this.badgeCount = defaultBadgeCount,
    this.searchPlaceholder = 'Search',
    this.cancelSearch = 'Cancel search',
    this.back = 'Back',
    this.dismiss = 'Dismiss',
  });

  /// Tooltip and semantics of the show-sidebar toggle.
  final String showSidebar;

  /// The sidebar hide button and the overlay barrier label.
  final String hideSidebar;

  /// Announced when the minimised tab bar expands.
  final String tabBarExpanded;

  /// Semantics hint of the minimised tab bar.
  final String expandTabBarHint;

  /// Spoken after a destination label when it has a dot badge.
  final String badgeDot;

  /// Spoken after a destination label when it has a count badge.
  final String Function(int count) badgeCount;

  /// The Flutter search field's placeholder when `LiquidSearch.placeholder`
  /// is null.
  final String searchPlaceholder;

  /// Semantics and tooltip of the Flutter search field's cancel (×).
  final String cancelSearch;

  /// Semantics and tooltip of `LiquidBackButton`.
  final String back;

  /// The barrier label of a Flutter action sheet (spec P3a §4.3): screen
  /// readers offer it to close the sheet.
  final String dismiss;

  /// The default [badgeCount]: `'3 new'`.
  static String defaultBadgeCount(int count) => '$count new';

  /// Field by field. Callbacks ([badgeCount]) compare by identity; use a
  /// const or stable instance (a top-level or static function, not a fresh
  /// closure per build), or two equal-looking string sets are never `==`.
  @override
  bool operator ==(Object other) =>
      other is LiquidShellStrings &&
      other.showSidebar == showSidebar &&
      other.hideSidebar == hideSidebar &&
      other.tabBarExpanded == tabBarExpanded &&
      other.expandTabBarHint == expandTabBarHint &&
      other.badgeDot == badgeDot &&
      other.badgeCount == badgeCount &&
      other.searchPlaceholder == searchPlaceholder &&
      other.cancelSearch == cancelSearch &&
      other.back == back &&
      other.dismiss == dismiss;

  @override
  int get hashCode => Object.hash(
    showSidebar,
    hideSidebar,
    tabBarExpanded,
    expandTabBarHint,
    badgeDot,
    badgeCount,
    searchPlaceholder,
    cancelSearch,
    back,
    dismiss,
  );
}
