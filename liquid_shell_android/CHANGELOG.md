## 0.1.0-dev.8

- **Fix (VK-702).** If registering the settings observer fails part-way,
  the half that did register is now removed on cancel and detach. Before,
  it stayed registered.

## 0.1.0-dev.7

- No changes; versioned with `liquid_shell`. Search scopes are drawn by
  Flutter's `LiquidSearchScopeBar` on Android.

## 0.1.0-dev.6

- No changes; versioned with `liquid_shell`. `dismissNativeSearchKeyboard`
  (VK-571) keeps the interface's default, which does nothing.

## 0.1.0-dev.5

- Version aligned with the other packages; no Android change.

## 0.1.0-dev.4

- Reports `lowEnd` (low-RAM flag or under 3 GiB) and `glesOnly` (Android 10+ without Vulkan 1.1).

## 0.1.0-dev.3

- Version bump only (Android draws the Flutter glass dialog).

## 0.1.0-dev.2

- Version aligned with the other packages; no Android change.

## 0.1.0-dev.1

- Initial development release.
