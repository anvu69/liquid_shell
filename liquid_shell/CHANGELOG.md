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
