# Native iPadOS chrome

On iPadOS 26 and later, `LiquidShell` can hand its chrome to the system: a
`UITabBarController` in sidebar mode, with the Liquid Glass tab bar, the
sidebar toggle, the sidebar and a native footer. Flutter keeps drawing the
body. Everywhere else the shell draws its Flutter chrome.

## Turning it on

1. In `ios/Runner/Info.plist`:

   ```xml
   <key>LiquidShellNativeChrome</key>
   <true/>
   ```

2. Give every destination an SF Symbol (`LiquidDestination.sfSymbol`), and
   the trailing action too (`LiquidTabAction.sfSymbol`) if you have one.
3. Optionally pass `nativeSidebarFooter`.

`LiquidShell(nativeChrome: LiquidNativeChrome.off)` keeps the Flutter chrome
for one shell.

## When the native chrome is used

The plugin installs a container in the window when the scene connects, and
only when every fact below holds. The first one that fails is the reason
`attachNativeChrome()` reports.

| Fact | Reason when it fails |
|---|---|
| The device is an iPad | `notIPad` |
| iPadOS 26 or later | `osTooOld` |
| Not an iPad app running on a Mac | `iPadAppOnMac` |
| `LiquidShellNativeChrome` is `true` in Info.plist | `notEnabled` |
| The environment variable `LIQUID_SHELL_NATIVE_OFF` is not `1` | `disabledByEnvironment` |
| The plugin registered before the Flutter view was on screen | `registeredLate` |
| The scene's root view controller is a `FlutterViewController` | `rootNotFlutter` |

Once installed, a shell uses it on every frame where all of these hold:
`nativeChrome` is `auto`; the shell is the newest one on screen that asked
for it; the platform's width is regular; the shell's own width is at least
`breakpoints.regular`; there is no `chromeBuilder`; and every destination
(and the trailing action) has an SF Symbol. Otherwise the container is
dormant: it hides, gives Flutter the whole window, and lets every touch
through.

### Waiting for the platform

The platform answers `attachNativeChrome()` asynchronously. Until it does, a
shell that would use native chrome draws no chrome at all rather than flash
the Flutter one: on an iPad with the plist key set, that is the first one or
two frames. Every other shell draws its Flutter chrome from the first frame:
a compact one, one without symbols, one with a `chromeBuilder`, and any
shell on a screen whose shorter side is under 744 points. That last rule is
a shortcut for iPhones: no iPhone is that large in either orientation, so an
iPhone, even in landscape, never waits. The screen's size is used, not the
window's, so an iPad window in Split View still waits. Platforms without
native chrome (Android, web, desktop) answer at once.

## How it behaves

- **Engine matching.** The plugin touches only scenes whose Flutter view
  controller belongs to the engine it registered with. A second engine
  (headless, add-to-app) never takes over another engine's scene.
- **Selection.** A tap on a native tab or sidebar row only proposes it. The
  shell runs `beforeDestinationChange`, calls `onDestinationSelected`, and
  then selects the tab natively. A refused tap leaves the native selection
  where it was. While the guard runs, the native chrome ignores touches and
  an overlay sidebar closes, so the guard's dialog is never drawn under it.
- **Footer.** `LiquidNativeSidebarFooter.onPressed` runs after the native
  side closes an overlay sidebar. It does **not** go through
  `beforeDestinationChange`: if it navigates away from unsaved work, guard it
  yourself.
- **Routes above the shell (hide on push).** A page pushed above the shell
  hides the native chrome while it covers the shell, and shows it again when
  the page is popped. A dialog, popup or sheet above the shell makes the
  native chrome ignore touches, so a tap outside the dialog reaches its
  barrier.
- **Hide chrome.** `LiquidHideChrome` hides the native chrome as it hides the
  Flutter chrome.
- **Insets.** The native tab bar row is part of Flutter's top safe area, and
  a tiled sidebar is its start padding. The shell turns the tiled sidebar's
  padding into real width for its body. Use
  `LiquidShellScope.contentPaddingOf` as usual.
- **Several shells.** One window has one native chrome. The newest shell
  that asks for it owns it; when it goes away, the previous one gets it back,
  and with none left the native chrome hides. While another shell owns the
  chrome, a shell that would otherwise use it draws no chrome (standby), so
  Flutter and native chrome never show together during a route transition.
- **Nested shells.** A shell inside another shell's body (sub-tabs) would
  take the chrome from the outer shell, which then shows no navigation.
  Give the inner shell `nativeChrome: LiquidNativeChrome.off`.
- **Scene reconnect.** When a scene is destroyed and connects again, the
  plugin installs a fresh container and applies the last config it received
  at once. Dart then sends its config again, whole, after the new
  container's first state report, so the native chrome matches the owning
  shell whatever the platform kept. The same re-send covers a hot restart.
- **Style.** The tint is the theme's `colorScheme.primary`. Light or dark
  follows the theme's brightness, and the direction follows the shell's
  `Directionality`.

## Limits

- The native chrome is drawn by UIKit, so widget tests and goldens cannot
  draw it. Use `make integration-ios-native` on a simulator.
- Strings the system draws, such as the VoiceOver label of the sidebar
  button, follow the device language, not your app's.
- Touches on the transparent part of the native chrome go to Flutter. That
  depends on UIKit's view tree; check every new iOS with
  `make integration-ios-native`.
- The container replaces the window's root view controller. A plugin that
  casts `rootViewController` to `FlutterViewController` breaks while it is
  installed. Leave `LiquidShellNativeChrome` out if you use one.
- One scene only. With multiple scenes, only the first scene that connects
  gets the native chrome.

## Window controls

A windowed iPadOS 26 app has close, minimise and resize buttons in its
top-leading corner. `LiquidShellScope.of(context).windowControls` gives their
size (`leading`, `top`), measured from the safe area. It is zero on every
other platform, in full screen, and while the native tab bar already keeps
content clear of them. The Flutter top bar and the Flutter sidebar header
move past them on their own. For your own top rows, use
`LiquidWindowControlsClearance`.

The clearance moves a row only when it is under the buttons both ways: its
top is above `windowControls.top`, and its start edge is closer than
`windowControls.leading` to the window's start edge. A page beside a tiled
sidebar starts past the buttons and never moves. The widget measures the
row's position after layout (the **settle measure**), and only while its
route is at rest: during a push or pop the page moves with a transform, and
a row measured then would look as if it were past the buttons. Until the
first measurement a row counts as under the buttons, except beside a tiled
sidebar. So a row that mounts away from the corner settles on its second
frame, without animating. The padding animates over 200 ms when a window
resize changes it, and jumps when the platform asks to reduce motion.

## Troubleshooting

- **`notEnabled`**: add the Info.plist key.
- **`registeredLate`**: the app registers plugins after the scene connected,
  for example on a custom engine; native chrome needs the default
  registration at launch.
- **`rootNotFlutter`**: the scene's root is not the Flutter view controller.
  Native chrome needs the standard Flutter scene setup.
- **Native chrome installed but Flutter chrome shows**: a destination or the
  trailing action has no `sfSymbol` (a debug log says so), the shell has a
  `chromeBuilder`, or the window is compact.
- **The outer shell lost its navigation**: an inner shell took the native
  chrome; set its `nativeChrome` to `off`.
