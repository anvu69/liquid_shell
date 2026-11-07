# liquid_shell VK-938: native chrome kind under the iPhone Duo vertical bar

- **Plane:** VK-938. Related: VK-930 (top band, merged in #37), VK-876 (the Flutter chrome draws its own vertical column; it reuses this change's plumbing).
- **Date:** 2026-11-08
- **Status:** approved. The owner accepted every default ("Ok hết", 2026-11-08).
- **Branch:** `VK-938-duo-vertical-chrome`, from `main` 9f70daa.
- **Kind of change:** a new native state field (Pigeon, platform interface, Swift), a new public `LiquidChromeKind` value, its insets, tests.

> **Tóm tắt (cho chủ sản phẩm).**
> - Trên iPhone Duo, native chrome xếp tab thành cột dọc bên phải, nhưng Dart vẫn báo `bottomBar` và `chromeInsets = only(bottom: 34)` (vạch home). App dựa vào `chromeInsets` sẽ chừa sai cạnh. Hai test `native_shell_test.dart` lỗi vì vậy.
> - Sửa: Swift báo thêm cạnh của cột dọc (`none` / `left` / `right`); Dart có giá trị mới `LiquidChromeKind.verticalBar`, `chromeInsets` là padding cạnh cột.
> - Chrome Flutter chưa vẽ cột dọc (việc của VK-876); vé này chỉ native.

## 1. Evidence

From VK-930 (iPhone Duo simulator, iOS 27.1, folded outer portrait, `BasicTabsCase` / `NativeChromeCase` with native chrome, after #37):

- `MediaQuery.padding` = `EdgeInsets(0.0, 26.0, 84.0, 34.0)`: the tab column takes the right 84 pt; 34 is the home indicator.
- `LiquidShellScope.chromeKind` = `bottomBar` (the native state is `compact`), `chromeInsets` = `EdgeInsets.only(bottom: 34)`.
- `native_shell_test.dart:140` fails: `padding.bottom > 40` (34). `:286` fails: with `LiquidNoChrome` the bottom padding does not drop, because the bar was never at the bottom.
- `UITraitCollection.verticalBarEdge` is `trailing` while the column shows and `unspecified` in the unfolded tall posture (probe report, VK-930).

## 2. Cause

`nativeChromeKind` (`liquid_shell/lib/src/native/native_layout.dart`) maps `state.compact` to `bottomBar`, and `nativeChromeInsets` takes the bottom padding for `bottomBar`. The native state carries nothing about a vertical bar.

## 3. Design

### 3.1 Native state

- Pigeon (`liquid_shell_ios/pigeons/native_shell.dart`): `enum NativeVerticalBarSide { none, left, right }` and a required field `NativeVerticalBarSide verticalBarSide` on `NativeShellState`.
- Platform interface: `enum LiquidNativeVerticalBarSide { none, left, right }` (dartdoc: the screen side of the system's vertical bar, already resolved for right-to-left), field `verticalBarSide` on `LiquidNativeShellState`, default `none`, in `==`, `hashCode`, `toString`. Android and the unavailable states report `none`.
- `liquid_shell_ios` mapping: `stateFromNative` maps the field.

### 3.2 Swift

- `ShellMath.verticalBarSide(edge: Int, rightToLeft: Bool) -> NativeVerticalBarSide`: pure. `edge` is the `UIVerticalBarEdge` raw value: 1 (leading) is `left`, or `right` in right-to-left; 2 (trailing) is `right`, or `left` in right-to-left; anything else is `none`.
- `VerticalBarReader.side(_ view: UIView) -> NativeVerticalBarSide`: behind the same guard as `topBarRegionTop` (`#if canImport(UIKit, _version: 9127.0.85)`, `#available(iOS 27.1, *)`), reads `view.traitCollection.verticalBarEdge.rawValue` and `view.effectiveUserInterfaceLayoutDirection`; `none` everywhere else.
- `NativeTabsController.currentState()` sets `verticalBarSide: VerticalBarReader.side(view)`. `NativeShellInstaller`'s unavailable state sets `.none`. `publishState()` already sends only on change, and `syncFlutter()` runs on every posture change, so fold and unfold reach Dart.

### 3.3 Dart shell

- `LiquidChromeKind.verticalBar`: "The system's vertical bar beside the body (iPhone Duo, native chrome); [LiquidShellScopeData.chromeInsets] is its side." Placed after `bottomBar`. Adding a value breaks exhaustive `switch`es in apps: CHANGELOG says so.
- `nativeChromeKind`: `hidden` wins; then `state.verticalBarSide != none` gives `verticalBar`; then the existing rules.
- `nativeChromeInsets` gains `LiquidNativeVerticalBarSide verticalBarSide = LiquidNativeVerticalBarSide.none`: for `verticalBar`, `EdgeInsets.only(left: padding.left)` or `EdgeInsets.only(right: padding.right)`; other kinds unchanged.
- The bottom-bar inset hold (`_holdBarInset`) stays tied to `bottomBar`.
- Flutter chrome never produces `verticalBar` here; its build `switch` draws nothing for it (VK-876 will draw the column).
- README and `doc/` lists of chrome kinds name the new value.

### 3.4 Chrome hidden

Not measured: whether the column leaves the safe area under `LiquidNoChrome` on the Duo. The plan's first task measures it; the integration test asserts what it finds on the column's side, and this spec's §6 records the answer.

## 4. Testing

- Platform interface unit: `LiquidNativeShellState` equality, hash and `toString` include `verticalBarSide`; default `none`.
- `liquid_shell_ios` unit: `stateFromNative` maps all three sides.
- XCTest: `ShellMath.verticalBarSide` for edges 0, 1, 2, 7 in both directions.
- `liquid_shell` unit (`native_layout_test.dart`): `verticalBar` from the side, `hidden` still wins; insets for both sides; every other kind unchanged.
- Integration: `native_shell_test.dart` handles `verticalBar` (first test: `chromeInsets` equals the column side's padding, which is > 40; the guard test measures the column's side). All of it passes on an iPhone Duo iOS 27.1 simulator and, as regression, on an iPhone 17 Pro iOS 26.5 simulator. `native_duo_test.dart` also asserts `chromeKind == verticalBar`.
- `make verify` green, `make pigeon-check` included.

## 5. Not in this change

- The Flutter chrome's vertical column (VK-876).
- A field naming the edge besides `chromeInsets`.
- Publishing: the entry goes into `0.1.0-dev.12` with VK-930; no publish now.

## 6. Measured during the plan

(Filled by Task 1: chrome hidden under the vertical bar; the unfolded wide posture's native `compact`.)
