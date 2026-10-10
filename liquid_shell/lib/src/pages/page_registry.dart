import 'package:flutter/widgets.dart';

/// One registered `LiquidPage` (spec P3b §8.4): what the native bar needs
/// and where the page is.
@immutable
class PageEntry {
  /// Creates an entry.
  const PageEntry({
    required this.title,
    required this.largeTitle,
    required this.route,
    required this.navigator,
    required this.sequence,
    required this.onScreen,
    required this.current,
    required this.active,
  });

  /// Navigation bar title.
  final String title;

  /// Large title; null: the platform default.
  final bool? largeTitle;

  /// The page's route.
  final ModalRoute<Object?>? route;

  /// The navigator holding [route].
  final NavigatorState? navigator;

  /// Push order: the order in which [route] first had a page registered,
  /// so push order within a navigator. A page recreated in a lower route
  /// keeps its route's place. Pages of one route share it.
  final int sequence;

  /// Visible and tickers on: not covered by an opaque route, not in a
  /// hidden branch (an `IndexedStack` hides one with `Visibility` and
  /// leaves its tickers on).
  final bool onScreen;

  /// [route] was current when the entry was taken.
  final bool current;

  /// [route] was active (in the history, not popping) when taken.
  final bool active;

  /// The page the user sees.
  bool get isTop => onScreen && (route?.isCurrent ?? false);

  /// Whether [other] describes the same page in the same state.
  bool sameAs(PageEntry other) =>
      other.title == title &&
      other.largeTitle == largeTitle &&
      identical(other.route, route) &&
      identical(other.navigator, navigator) &&
      other.sequence == sequence &&
      other.onScreen == onScreen &&
      other.current == current &&
      other.active == active;
}

/// A page's registration.
abstract interface class PageHandle {
  /// The page's state changed (title, route, on screen).
  void update(PageEntry entry);

  /// The page's first vertical scroll view is at [offset]: it scrolled, or
  /// a new scroll position laid out for the first time (restored from
  /// PageStorage, or rebuilt after a GlobalKey move).
  void scrolled(double offset);

  /// The page left the tree.
  void unregister();
}

/// Where pages register: the shell.
// The port the shell's state implements, like `HideChromeRegistry`; a test
// registry stands in for it.
// ignore: one_member_abstracts
abstract interface class PageRegistry {
  /// Registers a page.
  PageHandle registerPage(PageEntry entry);
}

/// The selected tab's stack (spec P3b §8.4): every active page in the top
/// page's navigator, in push order. Empty when no page is on top.
///
/// The top page stands for its route: another page in the same route sits
/// in a hidden branch (an `IndexedStack` inside one route), not below it.
///
/// Known limit: a lower route holding several pages in an `IndexedStack`
/// lists all of them, in no set order between them. A covered route has
/// its tickers off, so its entries cannot tell the visible branch from the
/// hidden ones. Tab branches with their own navigators are not affected.
List<PageEntry> pageStackFor(
  Iterable<PageEntry> entries, {
  required bool Function(PageEntry) isTop,
}) {
  PageEntry? top;
  for (final entry in entries) {
    if (isTop(entry) && (top == null || entry.sequence > top.sequence)) {
      top = entry;
    }
  }
  if (top == null) return const [];
  final navigator = top.navigator;
  final route = top.route;
  return [
    for (final entry in entries)
      if (identical(entry, top) ||
          (identical(entry.navigator, navigator) &&
              !identical(entry.route, route) &&
              (entry.route?.isActive ?? false)))
        entry,
  ]..sort((a, b) => a.sequence.compareTo(b.sequence));
}
