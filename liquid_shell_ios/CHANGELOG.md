## 0.1.0-dev.2

- The native iPadOS 26 shell: a `UITabBarController` sidebar over the Flutter
  view, installed at scene connection when Info.plist sets
  `LiquidShellNativeChrome`.
- Window controls read from the iPadOS 26 corner-adaptation region.
- `LiquidShellIOS` replaces the bare event-channel platform; the Pigeon
  channel is generated from `pigeons/native_shell.dart`.
- Depends on `meta` (imported by the generated channel code).

## 0.1.0-dev.1

- Initial development release.
