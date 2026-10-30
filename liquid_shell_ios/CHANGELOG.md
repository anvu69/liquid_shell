## 0.1.0-dev.10

- Every destination tab is a clear navigation controller (VK-441). Its
  root page host also carries the tab bar's minimize proxy, and so does
  every pushed host. The bar is hidden without pages and for a single root
  page with an inline title. The channel gains
  `NativeChromeConfig.tabBarHidden` and a per-tab debug snapshot
  (`NativeDebugSnapshot.tabs`, with each tab's bar height).
- A root page's large title that turns on while the page is on screen (a
  tab's pages arrive once the tab shows) is drawn out at rest; UIKit kept
  it collapsed. So is an iPad search root's when it asks for a large title
  while shown (VK-441).
- `tabBarHidden` hides the tab bar and the sidebar, keeps the navigation
  bar, puts a tiled sidebar back afterwards and dismisses an active search
  keeping its text (VK-442).
- Window controls are zero while the selected tab's navigation bar shows,
  also at compact width; real under a hidden one (VK-442).

## 0.1.0-dev.9

First release on pub.dev.

## 0.1.0-dev.8

- Swift Package Manager: CI builds the example with it (Flutter 3.44), so
  the README no longer calls it unverified.
- Native minimize on scroll (VK-600): a hidden `MinimizeProxy` scroll view
  per tab host, set as the bottom content scroll view, that follows the
  offset Dart sends; its pan sits on the Flutter view (direct touches only,
  not over platform views) while the bar may minimize; `tabBarMinimizeBehavior`
  follows `minimizeOnScroll`; an expand toggle serves a selection change
  (not into search) and `expandNativeTabBar`; `scrollsToTop = false` on the
  proxies and on the search page proxy, so the status-bar tap reaches
  Flutter. The channel gains `minimizeOnScroll`, `setMinimizeScroll` and
  `expandTabBar`.
- The proxies turn on UIKit's bottom scroll-edge effect under the compact
  bar. It shows while `minimizeOnScroll` is on and is hidden
  (`bottomEdgeEffect.isHidden`) while it is off.
- **Breaking for fakes:** the exported `NativeDebugSnapshot` gains two
  required fields, `minimizeBehavior` and `minimizePanAttached`. Code that
  constructs one (a test fake) must pass them.
- An activation Dart asks for right after selecting the search tab (a
  deep link, a programmatic focus) is no longer lost when UIKit refuses
  it because the search root is not in a window yet: it is kept until the
  root appears, and Dart's deactivate, leaving the tab, hidden chrome or a
  page pushed over the root drop it. While a page already covers the root
  the activation is still dropped, not kept. A refused presentation no
  longer leaves the scope bar drawn on an inactive search (VK-634).

## 0.1.0-dev.7

- UIKit's scope bar for the search tab (VK-550): `scopeBarActivation =
  .manual`, shown in `willPresent` and hidden in `willDismiss`, titles
  from `NativeSearchConfig.scopes`. The channel gains `scopes`,
  `setSearchScope` and `onSearchScopeChanged` (Pigeon, generated). A
  user's change is reported once; Dart's own writes are not echoed.
- A tap on a native scope puts the search keyboard away and keeps the
  search active (UIKit keeps the keyboard up), as Flutter's scope bar does.
- The selected scope is carried across a scene reconnect, as the search
  text is.
- **Breaking for fakes:** the exported `NativeDebugSnapshot` gains four
  required fields, `scopeTitles`, `scopeShown`, `selectedScope` and
  `scopeFrame`. Code that constructs one (a test fake) must pass them.

## 0.1.0-dev.6

- A page stack applied with the config that selects or leaves a tab is a
  restore, set without a transition; only a tab that stays selected
  animates its pushes and pops (VK-502).
- Hidden native chrome (the dormant config of a shell that left, or a
  hidden one) ends an active search and keeps its text: its field no
  longer keeps the keyboard up under the hidden chrome, and an activation
  Dart asks for while the chrome is hidden is ignored (VK-551).
- `dismissSearchKeyboard` on the channel: the search field resigns first
  responder and the search stays active with its text; marked text the
  resignation commits is reported once (VK-571).

## 0.1.0-dev.5

- The search destination is UIKit's `UISearchTab` with a native
  `UISearchController` field (tab-hosted at the bottom on iPhone, stacked
  under the title row on iPad; `prominentTabIdentifier` on iPhone iOS 27).
  Dart's text is written only outside an IME composition, and only the
  user's edits are reported, so Vietnamese Telex is never disturbed.
- Page stacks in the search tab: a clear `UINavigationController` with one
  host per `LiquidPage`, UIKit's glass back circle, a proxy scroll view for
  the large title and the scroll-edge effect. Every UIKit pop (the back
  button, its long-press menu, an accessibility escape) is a proposal to
  Dart; the back swipe stays with Flutter.
- The hit test extends to navigation controllers: the top page's view and
  its containers are background, so touches there reach Flutter.
- A scene reconnect carries the search text to the new shell.

## 0.1.0-dev.4

- Reports Low Power Mode as `powerSave`.

## 0.1.0-dev.3

- Native alerts and action sheets presented from the engine's own window
  (`NativeDialogPresenter`), over the Pigeon channel.

## 0.1.0-dev.2

- The native iOS 26 shell on iPhone and iPad: a `UITabBarController` in
  sidebar mode over the Flutter view (top bar and sidebar at regular width,
  the floating tab bar at compact width; the trailing action is a search
  tab), installed at scene connection when Info.plist sets
  `LiquidShellNativeChrome`. Every iPhone is compact, in either
  orientation.
- No `notIPad` reason any more: the install rule has no idiom fact, so the
  shell installs on iPhone as on iPad.
- On iOS 27 the trailing search tab stays a separate circle after the
  compact bar's pill when the app is built with the iOS 27 SDK (Xcode 27);
  built with an older SDK, iOS 27 may draw it inside the pill.
- Window controls read from the iPadOS 26 corner-adaptation region.
- `LiquidShellIOS` replaces the bare event-channel platform; the Pigeon
  channel is generated from `pigeons/native_shell.dart`.
- Depends on `meta` (imported by the generated channel code).

## 0.1.0-dev.1

- Initial development release.
