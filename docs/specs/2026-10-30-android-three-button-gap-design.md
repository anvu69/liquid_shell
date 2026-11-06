# liquid_shell VK-897: the bottom pill covers Android's three-button bar

- **Plane:** VK-897.
- **Date:** 2026-10-30
- **Status:** approved. The owner chose "Luật Dart 32 dp" and "Vá trên thẻ dev.9" on 2026-10-30.
- **Branch:** `VK-897-android-three-button-gap`, from the tag `v0.1.0-dev.9`, not `main`: `main` is 80 unreleased commits ahead and must not ride along.
- **Kind of change:** one private function in `liquid_shell`, its tests, and the version bump to `0.1.0-dev.10` in all four packages (the release guard keeps them in lockstep).

> **Tóm tắt (cho chủ sản phẩm).**
> - Android chế độ ba nút: viên thuốc tab đáy đè lên ◀ ● ■. Gói đoán "máy dùng cử chỉ" khi `systemGestureInsets.bottom > 0`, mà Android ba nút cũng báo khác 0.
> - Sửa: trên Android, vùng đáy hệ thống dưới 32 dp là vạch cử chỉ (khe 21), từ 32 dp trở lên là thanh nút (khe = đáy + 8).
> - Claude không publish, không tag, không push. Chủ sản phẩm chạy lệnh publish ở cuối kế hoạch.

## 1. Evidence

Found while accepting Lỗ Ban AR LBA-154 (the app moved to `liquid_shell 0.1.0-dev.9`). Android 36 emulator (pixel_8, 1080×2400, density 2.625), cold start. `adb shell dumpsys window`:

| Inset source (bottom) | Three-button | Gesture |
|---|---|---|
| `navigationBars` → `viewPadding.bottom` | 126 px = 48 dp | 63 px = 24 dp |
| `systemGestures` | 0 | 0 (left/right edges only) |
| `mandatorySystemGestures` | 126 px = 48 dp | 84 px = 32 dp |
| `tappableElement` | 126 px = 48 dp | 0 |

Flutter's `systemGestureInsets` includes the mandatory gesture area, so it is 48 dp with three buttons. `bottomGapFor` (`liquid_shell/lib/src/shell/shell_layout.dart:111`) takes `gestureInsetBottom > 0` as "gesture navigation" and returns 21: the pill sits 21 dp above the edge, on top of the buttons. Gesture mode is correct. The bug is on `main` too.

## 2. Design

`bottomGapFor` decides by the navigation bar's own height:

```dart
const double kGestureBarMaxHeight = 32;

double bottomGapFor({
  required TargetPlatform platform,
  required double viewPaddingBottom,
}) {
  final gestureArea =
      platform == TargetPlatform.iOS || viewPaddingBottom < kGestureBarMaxHeight;
  return gestureArea ? 21 : math.max(21, viewPaddingBottom + 8);
}
```

- A gesture handle is 24 dp on AOSP (some OEMs 16–20); a button bar is 48 dp. 32 sits between them with margin both ways. Lỗ Ban AR shipped the same 32 dp rule for its own tablet edge mode (`navigationBarInsetOf`).
- `gestureInsetBottom` goes away: it was the wrong signal and nothing else reads it. The function is private to the package (`shell_layout.dart` exports only `LiquidChromeKind`).
- `viewPaddingBottom` 0 (bar hidden, or a window without insets) stays 21, as before.

Rejected: reading the navigation mode natively in `liquid_shell_android` (exact, but touches the platform interface and Pigeon for a one-line decision).

## 3. Tests

| Test | Red before the fix because |
|---|---|
| unit: Android, `viewPaddingBottom` 48 → 56 | today the 48 dp gesture inset sends it to 21 |
| widget: Android 412×915, padding bottom 48 and gesture inset 48 → pill bottom at 915 − 56 | same, through `LiquidShell` |
| unit: Android, `viewPaddingBottom` 31.9 → 21 and 32 → 40 | pins the threshold |

The existing cases (iOS 21; Android gesture 24 → 21; Android 48 without gesture inset → 56) stay green.

**Golden harness.** The example's goldens drew the iPhone and iPad with the theme set to iOS but the device (`defaultTargetPlatform`) left at `flutter test`'s Android. Their 21-pt gap came from the 34-pt gesture inset the harness sets, i.e. from the very rule this fixes: with the fix they moved to 42 (15 images, 4.5 % of pixels). The harness now runs each golden as its device (`onDevice`, which sets and resets `debugDefaultTargetPlatformOverride` inside the test body, and `pumpGolden` asserts it). Every image then matches the committed one unchanged; none is regenerated.

## 4. Release

Bump all four packages to `0.1.0-dev.10` (versions, sibling constraints, podspec, CHANGELOG headings) so `tool/test/release_version_test.dart` stays green. CHANGELOG of `liquid_shell`: "Fix: on Android with three-button navigation the bottom pill no longer covers the buttons (VK-897)." The other three: "Version bump to match liquid_shell." The owner publishes; afterwards Claude tags `v0.1.0-dev.10` and merges the branch back into `main`.
