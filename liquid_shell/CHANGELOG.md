## 0.1.0-dev.3

- **Liquid glass by default.** A built-in, clean-room lens shader draws the
  `liquid` tier on Impeller: edge refraction, a specular rim, light
  dispersion, blur and tint. `LiquidGlass.precache()` loads it before the
  first frame. New `LiquidGlassTheme` fields: `liquidTint`, `refraction`,
  `dispersion`, `liquidBlurSigma`.
- Frosted instead of liquid without Impeller, on Android without Vulkan 1.1
  or under 3 GiB of memory, in battery saver and iOS Low Power Mode, after
  sustained slow frames, and inside another `BackdropFilter`.
- A `forcedTier` keeps shells under it on Flutter chrome.
- **Breaking:** `LiquidGlassSignals.canBlur` is removed (Skia now draws
  frosted, not solid); `debugLiquidGlassCanBlurOverride` is now
  `debugLiquidGlassCanRefractOverride`; battery saver gives frosted, not
  solid. `LiquidGlassSignals` gains `lowEnd`, `glesOnly`, `slowFrames` and
  `prefersFrosted`.

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
