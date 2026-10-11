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
