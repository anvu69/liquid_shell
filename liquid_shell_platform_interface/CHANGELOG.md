## 0.1.0-dev.12

- The native state reports the screen side of the iPhone Duo's vertical bar
  (`LiquidNativeVerticalBarSide`).

## 0.1.0-dev.11

- `LiquidNativeChromeConfig.tabBarHidden` (default `false`): hide the tab
  bar and the sidebar but keep the selected tab's navigation bar. It joins
  `==`, `hashCode` and `toString` (VK-442).
- `LiquidNativePage.largeTitle` applies to a tab's root page only; pushed
  pages are inline (VK-442).
- **Breaking (VK-443).** Page actions: `LiquidNativePageAction` (`sfSymbol`,
  `label`, `enabled`), `LiquidNativePage.actions` (default empty) and the
  event `LiquidNativePageActionTapped(tab, page:, index:, sfSymbol:)`.
  `LiquidNativeEvent` is sealed: an exhaustive `switch` over it needs the
  new case.

## 0.1.0-dev.10

Version bump to match liquid_shell.

## 0.1.0-dev.9

First release on pub.dev.

## 0.1.0-dev.8

- Native minimize on scroll (VK-600): `LiquidNativeChromeConfig.minimizeOnScroll`
  (default `false`; the shell passes `LiquidShell.minimizeOnScroll`, which
  defaults to `true`), `setNativeMinimizeScroll(tab, offset)` and
  `expandNativeTabBar()`. Both methods have no-op defaults, so other
  platform implementations keep working.
- Repeated error events on the signal channel are logged once, the first
  time, in debug builds only (VK-702). Each still emits
  `LiquidPlatformSignals.none`.

## 0.1.0-dev.7

- Native search scopes (VK-550): `LiquidNativeSearchConfig.scopes` (the
  titles, two or more, or null), `setNativeSearchScope(int)` (default does
  nothing) and the event `LiquidNativeSearchScopeChanged(index)`, a user's
  change of scope. `LiquidNativeEvent` is sealed: an exhaustive `switch`
  over it needs the new case.

## 0.1.0-dev.6

- `dismissNativeSearchKeyboard()`, with a default that does nothing:
  puts the native search keyboard away and keeps the search (VK-571).

## 0.1.0-dev.5

- Native search: `LiquidNativeSearchConfig` on
  `LiquidNativeChromeConfig.search`, and `LiquidNativeTab.search`.
- Page stacks: `LiquidNativePage` and `LiquidNativeTab.pages`.
- Six events: `LiquidNativeSearchTextChanged`,
  `LiquidNativeSearchActiveChanged`, `LiquidNativeSearchSubmitted`,
  `LiquidNativeSearchFieldChanged`, `LiquidNativeBackTapped` and
  `LiquidNativePopToPage`. `LiquidNativeEvent` is sealed: an exhaustive
  `switch` over it needs the new cases.
- Three methods, with defaults that do nothing: `setNativeSearchText`,
  `setNativeSearchActive` and `setNativePageScroll`.

## 0.1.0-dev.4

- `LiquidPlatformSignals.lowEnd` and `glesOnly`.

## 0.1.0-dev.3

- `supportsNativeDialogs`, `presentNativeDialog` and the native dialog
  request/result types.

## 0.1.0-dev.2

- Native chrome and window-control members on `LiquidShellPlatform`, all
  with defaults, and their value types (`LiquidNativeShellState`,
  `LiquidNativeChromeConfig`, `LiquidNativeEvent`, `LiquidWindowControls`).
- `LiquidNativeUnavailableReason` has no `notIPad` (removed before release):
  native chrome runs on iPhone and on iPad, compact windows included.

## 0.1.0-dev.1

- Initial development release.
