## 0.1.0-dev.5

- **Search tab.** `LiquidDestinationRole.search` on `LiquidDestination` (at
  most one, the last destination, placed everywhere) with
  `LiquidShell.search` (`LiquidSearch`: controller, placeholder,
  `onChanged`, `onSubmitted`). `LiquidSearchController`,
  `LiquidSearchValue` and `LiquidSearchPhase` (idle, selected, active);
  `LiquidSearchScopeBar`, a glass segmented control for search scopes. On
  iOS 26 with native chrome the field is UIKit's own `UISearchTab`: on
  iPhone the ⌕ becomes the field and the tabs collapse to one circle; on
  iPad the field sits under the title row and rises into it when active.
  Everywhere else the shell draws the same states in glass. The query is
  kept across tab switches; × clears it.
- **Pages and the glass back button.** `LiquidPage` (title, large title,
  the back button when its navigator can pop) and `LiquidBackButton`. In
  the native search tab, UIKit draws the title and its glass back circle;
  every back, the long-press back menu included, is a proposal that goes
  through `Navigator.maybePop`, so `PopScope` runs.
- A root `LiquidPage`'s large title now sits on the bar row, as Apple
  Music's does: in the Flutter bar on every platform, and natively on
  iPhone (on iPad the native search root shows a small title, or its own
  large-title row with `largeTitle: true`). A pushed page's large title
  keeps a row of its own in the Flutter bar; under the native search tab,
  UIKit draws it small and centred (see `LiquidPage.largeTitle`).
- `LiquidShellScopeData.searchPhase` and `nativePageBar`; `chromeInsets`
  covers the search field in every phase, so
  `LiquidShellScope.contentPaddingOf` keeps working (never add
  `viewInsets` on top).
- `LiquidShellStrings.searchPlaceholder`, `cancelSearch` and `back`.
- `LiquidChromeSlot.searchField` and
  `LiquidChromeDetails.search` (`LiquidSearchChromeDetails`) for a
  `chromeBuilder`.
- Example: a real "Search" case (songs and places, Vietnamese without
  accents matches); the trailing action case is now "Compose".

## 0.1.0-dev.3

- `showLiquidAlert` / `showLiquidActionSheet`: native `UIAlertController` on
  iOS 26+, Flutter glass elsewhere; `LiquidAlertAction`,
  `LiquidAlertActionStyle`, `LiquidDialogPresentation`;
  `LiquidShellStrings.dismiss`. Example: Alerts and action sheets case; the
  guard uses the native alert.

## 0.1.0-dev.2

- Native iOS 26 chrome (opt-in) on iPhone and iPad, compact windows
  included: `LiquidShell(nativeChrome:)`,
  `LiquidNativeChrome`, `LiquidNativeSidebarFooter`, and `sfSymbol` on
  `LiquidDestination` and `LiquidTabAction`. Every iPhone gets the floating
  bottom tab bar, and so does an iPad window of compact width; a full or
  wide iPad window gets the top bar and the sidebar.
- `LiquidNativeUnavailableReason.notIPad` was removed (it never shipped in a
  release): an iPhone is no longer a reason to keep the Flutter chrome.
- Window controls: `LiquidShellScopeData.windowControls`,
  `LiquidWindowControlsClearance`, and the Flutter top bar and sidebar
  header move past the iPadOS 26 window controls.
- `LiquidShellScopeData.nativeChrome`; `LiquidNoChrome` passes the window
  controls through.
- `debugResetLiquidNative()` for tests that swap the platform.
- In debug, a shell that could use native chrome but lacks an `sfSymbol`
  logs one line, once per shell, naming the destinations and the trailing action
  without one.
- Example: every case with a real shell runs native on iOS 26; the cases
  about the Flutter chrome say so on screen.

## 0.1.0-dev.1

- Initial development release.
