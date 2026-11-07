# liquid_shell VK-930: Flutter content under the iPhone Duo vertical bar

- **Plane:** VK-930. Related: VK-876 (Flutter chrome draws its own vertical column), VK-931 (Xcode 27.1 simulator build failure).
- **Date:** 2026-11-07
- **Status:** approved. The owner accepted every default ("Ok hết", 2026-11-07).
- **Branch:** `VK-930-duo-top-band`, from `main` 48aabb3.
- **Kind of change:** one rule in the native shell's inset sync (Swift), its tests, one integration test. No Dart API, no Pigeon change.

> **Tóm tắt (cho chủ sản phẩm).**
> - Trên iPhone Duo khi có cột bar dọc, iOS cho cửa sổ khoảng chừa trên = 0. Native chrome của liquid_shell đúng sẵn (cột tab dọc, nút back và nút trang dưới khối status). Lỗi duy nhất: nội dung Flutter vẽ từ y=0, góc bo 55 pt của màn trong cắt chữ.
> - Sửa: khi cột dọc bật, Swift nâng padding trên của Flutter lên đúng vùng bar trên mà UIKit dùng (đo được 26 pt), ngang hàng đồng hồ. Không đổi gì phía Dart.
> - Không thêm API `axisBehavior`, `verticalBarCompressionBehavior`, `preferredVerticalBarBehavior`. Chrome Flutter tự vẽ cột dọc vẫn là VK-876. Lỗi build Xcode 27.1 là VK-931.
> - **Khác với mặc định đã duyệt ở câu 7:** test tự động chỉ chạy được ở màn ngoài gập (simulator khởi động ở tư thế đó, `simctl` không đổi được tư thế). Màn ngoài góc bo chỉ 8 pt nên không thấy chữ bị cắt; test kiểm tra con số padding. Việc góc bo màn trong không còn cắt chữ được kiểm bằng tay qua DeviceHub, ảnh chụp đính kèm PR.

## 1. Evidence

Probe report: vankhan `.superpowers/sdd/vk930-probe-report.md` (iOS 27.1 simulator, device type `iPhone Duo`). The facts this design uses:

| Posture | Vertical bar | `verticalBarEdge` | Window safe area {t l b r} | `layoutRegionForBarOnEdge(.top, extent 44)` top |
|---|---|---|---|---|
| Folded outer, portrait 466×678 | yes, right, 84 pt | trailing | {0 0 34 84} | 26 |
| Folded outer, landscape 678×466 | yes | trailing | {0 0 34 84} | 26 |
| Unfolded wide 951×669 (flat and half open) | yes | trailing | {0 0 34 84} | 26 |
| Unfolded tall 669×951 | no | unspecified | {82 0 34 0} | 26 |
| Any, `preferredVerticalBarBehavior = .disabled` | no | trailing on the folded screen | {82 0 34 0} | 26 |

- UIKit puts its own navigation bar at y=24 in vertical-bar postures. The top bar region already stops short of the status block, and the right safe inset (84) already keeps content out of the column and the block under it.
- liquid_shell example, `tabs` demo (Flutter pages, native tab bar), unfolded wide: the Flutter header starts at y≈0 and the 55 pt corner cuts the "H" of "Home" (probe screenshot 31). Folded outer: same y≈0, corner radius 8, nothing visibly cut, 24 pt higher than UIKit's bar.
- `pages` demo (native `UINavigationBar`): correct. Its Flutter top comes from `PageHostController.flutterTop` (82).

## 2. Cause

`NativeTabsController.syncFlutter()` gives Flutter the selected host's safe area through the `FlutterViewController`'s `additionalSafeAreaInsets` (`ShellMath.additionalInsets`). For a tab without a native page bar the host's top is the window's, which is 0 under a vertical bar. The Dart shell passes `MediaQuery.padding.top` through unchanged under native chrome (`liquid_shell.dart`, `nativeChromeInsets` changes only the bottom), so every Flutter header starts at y=0.

## 3. Design

### 3.1 Rule

While the chrome is visible and the trait collection reports a vertical bar (`verticalBarEdge != .unspecified`), Flutter's top inset is

```
want.top = max(want.top, topBarRegionTop)
```

where `topBarRegionTop` is the top of `UIView.LayoutRegion` for a bar on the top edge with extent 44, read from the selected host's view. Otherwise nothing changes.

- `tabs` path: 0 becomes 26. Content starts level with the clock, like UIKit's bar.
- `pages` path and `.disabled`: already 82, `max` keeps it.
- Unfolded tall: no vertical bar, rule off; safe top is already 82.
- iOS before 27.1, other devices: no vertical bar, rule off.
- Chrome hidden (Flutter gets the whole window): out of scope. The probe did not measure whether the vertical bar stays while the tab bar is hidden.

### 3.2 Units

- `ShellMath.verticalBarTop(safeTop: Double, barRegionTop: Double?) -> Double`: pure. `nil`, negative or non-finite region means `safeTop`; else `max(safeTop, barRegionTop)`.
- `VerticalBarReader.topBarRegionTop(_ view: UIView) -> Double?` (new file `VerticalBarReader.swift`, beside `WindowControlsReader.swift`): `nil` unless the SDK has the API, the OS is iOS 27.1 or later and the view's trait reports a vertical bar.
- `syncFlutter()`: after `want` is computed and before the overlay hold, `want.top = ShellMath.verticalBarTop(safeTop: want.top, barRegionTop: VerticalBarReader.topBarRegionTop(host.view))`.

`syncFlutter()` already runs on `viewSafeAreaInsetsDidChange` and every layout of the host, so fold, unfold and rotation reach it. The Duo's posture change resizes the scene, which triggers both.

### 3.3 Compiling on older SDKs

`verticalBarEdge` and `layoutRegionForBarOnEdge:extent:` are `API_AVAILABLE(ios(27.1))`. CI builds on `macos-latest`, whose Xcode can be older than 27.1, and the existing iOS 27 guard `#if compiler(>=6.4)` is also true on the iOS 27.0 SDK. The code must compile on SDKs without these symbols. The plan's first task decides the compile-time guard (`#if canImport(UIKit, _version: …)` with the version read from the 27.1 SDK's `UIKit.tbd`, 9127.0.85) and proves it, or, if no reliable compile-time guard exists, reads both through the Objective-C runtime behind `responds(to:)`. Either way the reader returns `nil` where the API is missing.

## 4. Testing

- **Unit (XCTest, `RunnerTests`, any simulator):** `ShellMath.verticalBarTop`: `(0, 26) → 26`, `(82, 26) → 82`, `(0, nil) → 0`, `(0, -1) → 0`, `(0, .nan) → 0`.
- **Integration (new `integration_test/native_duo_test.dart`, iPhone Duo iOS 27.1 simulator, folded outer portrait, the posture a fresh simulator boots in):** the example's tabs case with native chrome. Assert `MediaQuery.padding.right` within 0.5 of 84 (the vertical bar is there) and `MediaQuery.padding.top >= 24`. Red before the fix (top 0), green after. Not added to the default `NATIVE_TARGETS`; run with `NATIVE_DEVICES` / `NATIVE_TARGETS` set to the Duo.
- **The build:** `flutter build`/`flutter drive` for the simulator fails on Xcode 27.1 (VK-931). The plan's first task checks whether `tool/integration_ios_native.sh` builds on a Duo; if not, the integration run uses the probe's `xcodebuild … ARCHS=arm64` build plus `flutter drive --use-application-binary`. VK-930 does not fix VK-931.
- **Manual, inner screen:** DeviceHub "fully open" preset, `tabs` demo, `simctl io <udid> screenshot --display=3 --mask=black`: the header is not cut by the corner. Screenshot in the PR.
- **Regression:** `make verify`; `make ios-unit` on an iPhone 17 Pro (iOS 26.5) simulator; `native_shell_test.dart` and `native_pages_test.dart` on one iPhone simulator.

## 5. Not in this change

- Public API for `axisBehavior`, `verticalBarCompressionBehavior` or `preferredVerticalBarBehavior` (owner decisions 3–5; system defaults already match the owner's description).
- The Flutter-chrome tier's vertical column (VK-876).
- VK-931.

## 6. Not measured

Hinge angles other than the three DeviceHub presets, outer portraitUpsideDown and landscapeLeft, a real device, chrome hidden under a vertical bar, the `native_chrome` example case.
