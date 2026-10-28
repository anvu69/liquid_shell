import 'package:liquid_shell/src/shell/breakpoints.dart';

/// How a `LiquidPage` draws its title. The native navigation bar follows
/// the same table, so both bars show the same title for the same page.
enum PageTitleMode {
  /// No bar: the shell's own chrome is the page's title row.
  hidden,

  /// The bar row with the title small and centred.
  inline,

  /// The bar row with the large title leading on it, as in Apple Music. It
  /// never collapses.
  largeInRow,

  /// The bar row and a large-title row below it. The large row scrolls
  /// away as the page scrolls, and the small title fades into the bar row.
  largeCollapsing,
}

/// The title mode of a page.
///
/// [root] is true when no route lies below the page in its navigator. A
/// pushed page is always [PageTitleMode.inline]. On a root page,
/// [largeTitle] true gives [PageTitleMode.largeCollapsing]; null gives
/// [PageTitleMode.largeInRow] at compact width and no bar at regular width;
/// false gives no bar. A root page with actions ([hasActions]) keeps an
/// inline bar where it would have none.
PageTitleMode pageTitleModeFor({
  required bool root,
  required bool? largeTitle,
  required LiquidSizeClass sizeClass,
  bool hasActions = false,
}) {
  if (!root) return PageTitleMode.inline;
  return switch (largeTitle) {
    true => PageTitleMode.largeCollapsing,
    null when sizeClass == LiquidSizeClass.compact => PageTitleMode.largeInRow,
    _ when hasActions => PageTitleMode.inline,
    _ => PageTitleMode.hidden,
  };
}
