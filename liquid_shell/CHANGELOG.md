## 0.1.0-dev.6

- **Tab bar fidelity (VK-503).** The Flutter tab bar matches iOS 26.5:
  native slot geometry (86 pt slots, 21 pt margins, the pill pinned at
  the start beside a trailing circle), a liquid lens that engages on touch,
  follows a drag and snaps on release (the measured springs), tinted and
  magnified icons under the lens, a pill swell, a highlight and a finger
  glow, an icon pop on tap, and selection clicks while dragging. See
  `doc/tab_bar.md`.
- **Behaviour changes.**
  - A tab is selected on release, not on touch. A drag selects the tab
    nearest the lens when it lifts, a flick the tab under the finger.
  - Every tab slot draws `selectedIcon ?? icon`, selected or not, as iOS
    draws a filled symbol in every slot. Give each destination a filled
    `selectedIcon`. The sidebar still switches `icon` / `selectedIcon` by
    selection.
  - Tab colours: the selected tab is `ColorScheme.primary` on a neutral
    capsule (`selectionFill`), not a `primaryContainer` chip; the others
    are `tabForeground`. Sidebar rows use `tabForeground` too.
  - There is no ink splash.
  - With `minimizeOnScroll`, the minimized bar is a 48 pt icon-only circle
    that expands on a tap or on a selection change, not when the page
    scrolls back up, as on iOS 26. A `chromeBuilder` sees the same in
    `LiquidChromeDetails.minimized`: it stays true until the chrome calls
    `details.expand` or the selected destination changes.
  - Landscape phones get the 44 pt bottom bar (icon beside a 12 pt label)
    instead of the top bar: a landscape shell lower than
    `LiquidShellBreakpoints.compactHeight` (500) is compact. Pass
    `compactHeight: 0` for the previous layout.
  - The iPad top bar is 48 pt, label only (17 pt, the search tab as an
    icon), 5.5 pt below the safe area instead of 20, so it sits 14.5 pt
    higher and a regular layout's `chromeInsets.top` is 14.5 pt smaller.
  - The bottom bar margin is 21 pt (8 pt in a narrow shell).
  - Badges are the native 21 pt red capsule, #FF383C in light and
    #FF4245 in dark (`badgeColor`), in the tab bar and the sidebar.
- **New:** `LiquidGlassTheme.selectionFill`, `tabForeground`,
  `badgeColor`, `tabIconSize`; `LiquidShellBreakpoints.compactHeight`; a
  scroll-edge pocket under the liquid bottom bar (three blur bands and a
  faint dim, liquid tier only: frosted, solid and Reduce Transparency draw
  none).
- **Defaults changed** for every glass surface (bars, circles, sidebar,
  dialogs, the back button): `rimHighlight` 0.12, `liquidTint` a neutral
  milky white @ 0.55 (light) / #1C1C1C @ 0.90 (dark) instead of the
  scheme's `surface` @ 0.40 / 0.45 (native glass takes no app hue), `shadow` 7 %
  (0, 3) blur 20, `dispersion` 0 in the constructor and in
  `fromColorScheme` (the touched tab lens adds its own fringe; pass
  `dispersion: 0.3` for the previous look), `labelStyle` 10 / 1.2 / w500 /
  no tracking.

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
  Everywhere else the shell draws the same states in glass, liquid on the
  default tier. The query is kept across tab switches; × clears it.
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
- **Breaking:** `LiquidChromeSlot` gains `searchField`, so an exhaustive
  `switch (details.slot)` in a `chromeBuilder` needs the new case (or a
  `default`).
- Example: a real "Search" case (songs and places, Vietnamese without
  accents matches); the trailing action case is now "Compose".

## 0.1.0-dev.4

- **Liquid glass.** A built-in, clean-room lens shader draws the `liquid`
  tier on Impeller: edge refraction, a specular rim, light dispersion,
  blur and tint. `LiquidGlass.precache()` loads it before the first frame.
  New `LiquidGlassTheme` fields, all optional with defaults: `liquidTint`
  (`solid` @ 0.40, 0.45 when dark), `refraction`, `dispersion`,
  `liquidBlurSigma`.
- Frosted instead of liquid without Impeller, on Android without Vulkan 1.1
  or under 3 GiB of memory, in battery saver and iOS Low Power Mode, after
  sustained slow frames, and inside another `BackdropFilter`.
- The Flutter glass alert and action sheet (`showLiquidAlert` /
  `showLiquidActionSheet` off the native path) draw the liquid tier too:
  they are `LiquidGlass`. Doc images `case_alert` and `case_action_sheet`
  are now the liquid tier.
- A `forcedTier` keeps shells under it on Flutter chrome.
- `LiquidGlassSignals` gains `lowEnd`, `glesOnly`, `slowFrames` and
  `prefersFrosted`.
- **Breaking:**
  - **Liquid is the default tier** on Impeller (iOS, Android 10+, macOS),
    where glass was frosted. Force `frosted` with
    `LiquidGlassPolicy(forcedTier:)` to keep the old look.
  - **`tint` and `blurSigma` now style frosted only.** The liquid tier
    reads `liquidTint`, `liquidBlurSigma`, `refraction`, `dispersion`,
    `rimHighlight` (its specular rim), `shadow` and the shape. A brand
    theme that sets only `tint`/`blurSigma` shows on the default tier as
    the stock liquid glass: set `liquidTint` (and `liquidBlurSigma`) too.
    `border` and `borderWidth` draw on frosted and solid, not liquid.
  - `LiquidGlassSignals.canBlur` is removed (Skia now draws frosted, not
    solid); `debugLiquidGlassCanBlurOverride` is now
    `debugLiquidGlassCanRefractOverride`; battery saver gives frosted, not
    solid.
- Known limits of the liquid tier (README "Limitations", `doc/liquid.md`):
  it writes opaque pixels, so over a transparent window or in an image
  capture of a subtree it is a solid tint (force `frosted` there); under a
  scaling or rotating ancestor the lens is placed on the bounding box.

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
