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
