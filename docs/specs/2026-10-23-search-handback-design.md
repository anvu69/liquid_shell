# liquid_shell VK-699 (+ VK-698): a native search handed back to Flutter chrome

- **Plane:** VK-699 (main), VK-698.
- **Date:** 2026-10-23
- **Status:** approved. The owner accepted both investigations' recommendations on 2026-10-23 (§7). Plan: `docs/plans/2026-10-23-search-handback.md`.
- **Branch:** `VK-699-search-handback`, from `origin/main` at `a387a8e`.
- **Kind of change:**
  - VK-699: Dart in `liquid_shell` (`lib/src/search/shell_search.dart` only), widget tests, `CHANGELOG.md` (`## 0.1.0-dev.8`, Fix), one bullet in `doc/search.md`.
  - VK-698: one XCTest in `liquid_shell/example/ios/RunnerTests/RunnerTests.swift` (test only), one row in the P3b spec §7.2 table.
  - No Swift production code, no Pigeon, no platform-interface change, no public API change, no version bump.
- **Sources:** the two investigations of 2026-10-23 (VK-699 on `bfcccb6`, prototype re-run on `a387a8e` for this spec; VK-698 on `bfcccb6`, iPhone 17 simulators iOS 27.0 `24A434` and 26.3.1, Xcode 27.1); spec `2026-10-19-search-fixes-design.md` (VK-572 §4, §5); P3b spec `2026-10-10-p3b-search-tab-design.md` §7.2.

> **Tóm tắt (cho chủ sản phẩm).**
> - **VK-699.** Đang tìm bằng ô tìm native (UIKit), đang gõ dở (chữ còn gạch chân), mà shell chuyển về giao diện Flutter: app tắt `nativeChrome`, ép một tier kính, hoặc native shell mất. Hiện tại controller vẫn báo "đang tìm" mãi (nút back bị chặn) hoặc vẫn báo "đang gõ dở" (`composing`), nên app nào chờ hết `composing` mới ghi chữ thì bị kẹt. Sửa: lúc rời native chrome, tìm kiếm **kết thúc**: chữ giữ nguyên, `composing` tắt, không gọi `onChanged`. Kết thúc sau khi build xong (một frame vẫn thấy "đang tìm", đã chấp nhận). Người dùng chạm ô Flutter để tìm tiếp, bàn phím không tự bật. Thêm 4 test (P1, P2, P2b, P3), một dòng CHANGELOG, một câu trong `doc/search.md`.
> - **VK-698.** Trên iPhone iOS 27.0, UIKit tự đưa ô tìm lên trên cùng (kiểu iPad), thanh scope nằm dưới ô. Test XCTest cũ giả định ô ở đáy nên đỏ. Chấp nhận hành vi hệ thống, chỉ sửa test: rẽ nhánh theo kiểu đặt ô thực tế (`stacked`) thay vì theo iPad. Cập nhật bảng §7.2 của spec P3b bằng số đo. Chưa thêm job CI iOS 27 (việc sau).

---

## 1. Goal

- **VK-699.** Leaving native chrome ends an active native search the way every other native end does (VK-572 §4): `active` false, text kept, `composing` false, `onChanged` not called.
- **VK-698.** `testTheScopeBarShowsOnlyWhileTheSearchIsActive` checks the scope bar against the field placement UIKit actually realises, so it is green on iPhone iOS 26 and 27 and on iPad.

## 2. Scope

### 2.1 In

§4 and §5 with their tests; the CHANGELOG line and the `doc/search.md` bullet (VK-699); the P3b §7.2 row (VK-698).

### 2.2 Non-goals

- Keeping the iPhone iOS 27 field at the bottom (owner: accept the system behaviour).
- An iOS 27 CI leg for `ios-unit` (§8, follow-up).
- Any change to `_endSearch`'s Flutter-mode `composing` rule beyond the parameter of §4.2 (owner decision 3).
- Re-activating the Flutter field after the hand-back (owner decision 1: ended).

## 3. Evidence (file:line at `a387a8e`)

VK-593 (`a387a8e`) touched `branch_navigators.dart` and the back code of `liquid_shell.dart`, nothing in `lib/src/search/`, `native_search_test.dart` or `RunnerTests.swift`: both prototypes apply unchanged (`git apply --check`), and the line numbers below were re-read at `a387a8e`.

### 3.1 VK-699

- **The setter ends nothing.** `ShellSearch.native` (`lib/src/search/shell_search.dart:83-92`): on `true → false` it resets the send flags and writes the controller's text into the Flutter field (`:89`). `active` and `composing` stay as native last reported them. Every other native end goes through `_endSearch` (`:280-288`).
- **Path 1, `nativeChrome: off`.** `didUpdateWidget` → `_syncClaim` (`lib/src/shell/liquid_shell.dart:388`) releases the claim (`:392`); the build sets `_search..native = engaged` (`:1797`, false). Native's own `searchActive false`, if it comes, is dropped by the released claim (`lib/src/native/native_host.dart:256`, `if (!_released) _handler(event);`). Nothing ends the search: `isActive` and `composing` stay true, and the shell's back scope stays blocked (`liquid_shell.dart:855`, `canPop: !overlay && !searchActive && !_branchCanPop`).
- **Path 2, a lost install.** The claim survives; the build sets `native = false` (`:1797`) with nothing ended. If native then reports `searchActive false`, `onNativeEvent` (`shell_search.dart:200`) → `_endSearch` (`:216`) runs with `native == false`, so `composing = !native && value.composing` (`:282`) keeps `composing` true. That rule is meant for the Flutter field's own composition, which never existed here: under native, `_onEditing` and `_onFocus` return early (`:459`, `:511`).
- **Path 3, a forced glass tier** (`LiquidGlassScope.policyOf(context).forcedTier != null`, `liquid_shell.dart:1770`, fed to `nativeChromeEngaged`) leaves native through the same setter.

**Red at `a387a8e`** (the four tests of §6.1, `flutter test test/widget/native_search_test.dart --plain-name "VK-699"`, `00:01 +0 -4: Some tests failed.`):

| Test | Fails at | Message |
|---|---|---|
| P1 | `native_search_test.dart:2669` (`expect(controller.isActive, isFalse)`) | `Expected: false Actual: <true>` |
| P2 | `:2669` | `Expected: false Actual: <true>` |
| P2b | `:2671` (`expect(controller.value.composing, isFalse)`) | `Expected: false Actual: <true>` |
| P3 | `:2669` | `Expected: false Actual: <true>` |

### 3.2 VK-698

On iPhone 17, iOS 27.0 (`24A434`), the test fails with `XCTAssertLessThan failed: ("152.0") is not less than ("62.0") - above the field: NativeRect(x: 16.0, y: 62.0, width: 315.0, height: 44.0)`; green on iOS 26.3.1. Our code does not force the placement (iPhone stays `.automatic`, P3b §7.2): UIKit realises `stacked` on iPhone iOS 27.0, field at the top, scope bar under it, as on an iPad, with or without scopes. Measured (Flutter view 402×874, search active):

| | iPhone iOS 26.3.1 | iPhone iOS 27.0 |
|---|---|---|
| `debugSnapshot().placement` | `inline` | `stacked` |
| Field, with scopes | (88, 798, 226×48), bottom by the tab bar | (16, 62, 315×44), top, with × |
| Scope bar | (16, 64, 370×32), top | (16, 116, 370×36), under the field |
| Flutter safe area, with scopes | top 106, bottom 83 | top 152, bottom 83 |
| Field after the search ends (idle) | (88, 798, 286×48), bottom | (16, 116, 370×44), under the nav bar |

The Dart side already handles it: the field lies inside the top safe area, so `nativeSearchBottomInset` returns 0 as on the iPad stacked path; Flutter content moves under the scope bar, nothing overlaps.

## 4. Design: VK-699

### 4.1 The setter ends the search, after the build

In the `native` setter's `true → false` branch, after `_writeField(controller.text)`, schedule a microtask that ends the search:

- **Microtask, not synchronous.** The setter runs inside `build` (`_resolveNative`). Ending there notifies controller listeners during the build and can hit "setState during build" in app code. `releaseField` (`shell_search.dart:425-437`) already ends a search in a microtask for this reason. Listeners therefore see `isActive` true for one frame (owner decision 2: accepted).
- **Guard.** The microtask does nothing when the search was disposed, native came back meanwhile (`_native`), or the controller changed (`!identical(controller, _controller)`).
- **What ends.** `_endSearch(controller, nativeField: true)`: `active` false, `composing` false, text kept; `applySearchEdit` only, so `onChanged` is not called (VK-572 §4).

### 4.2 `_endSearch` takes the field that held the search

`_endSearch(LiquidSearchController controller, {bool? nativeField})`, with `composing = !(nativeField ?? native) && value.composing`. Every existing caller passes nothing and keeps today's rule. The setter passes `true`: at that point `_native` is already false, yet the search was held by the native field, whose marked text UIKit commits on resign (VK-572 §4).

### 4.3 Consequences

- P2b: native's late `searchActive false` after a lost install finds `!active && !composing` and is a no-op (`:283`). No change to the Flutter-mode rule (owner decision 3).
- IME safety: nothing is written into a composing field (the Flutter field is not focused under native; `_writeField` still holds a write while composing), and nothing is sent to native (claim released, or native gone).
- The text is kept as composed (owner decision 5: Apple commits marked text on resign).
- The user taps the Flutter field to resume; no `requestFocus`, so the keyboard does not pop up on a config change.

## 5. Design: VK-698 (test only)

In `testTheScopeBarShowsOnlyWhileTheSearchIsActive` (`RunnerTests.swift:2974`), read one `debugSnapshot()` for the field and branch on `snapshot.placement == "stacked"` instead of `UIDevice.current.userInterfaceIdiom == .pad`: stacked → scope under the field; otherwise → scope above the field. An iPad always realises `stacked`, so the iPad branch is unchanged. The doc comment above the test says iPhone iOS 27.0 is stacked too.

P3b spec §7.2 gets one row, the placement UIKit realises, with the measured iPhone frames of §3.2.

## 6. Tests

### 6.1 VK-699, Dart, red first

A new group at the end of `test/widget/native_search_test.dart`, `'VK-699: Flutter chrome takes over a native search'`. Setup: compact installed fake, `LiquidSearch(controller:, onChanged: changes.add)` inside a `LiquidGlassScope` (no forced tier), search tab selected; native reports `searchActive true` then `TextChanged('かな', composing: true)`. `expectEnded`: inactive, text `かな`, `composing` false, `changes` empty.

| Test | Action |
|---|---|
| P1 | rebuild with `nativeChrome: off`, then native emits `searchActive false` (dropped by the released claim) |
| P2 | `pushState(installed: false)` |
| P2b | `pushState(installed: false)`, then native emits `searchActive false` |
| P3 | rebuild with `forcedTier: LiquidGlassTier.liquid` (owner decision 4) |

### 6.2 Mutations (run, recorded in the task report, reverted)

| Mutant | P1 | P2 | P2b | P3 |
|---|---|---|---|---|
| M1: the microtask does nothing (`controller.hashCode;` for the `_endSearch` call) | red | red | red | red |
| M2: `_endSearch(controller)` (Flutter-mode rule, keeps `composing`) | red | red | red | red |

Both run on `a387a8e` while writing this spec.

### 6.3 VK-698, XCTest

On an iPhone 17 iOS 27.0 simulator: the test red before the change with the message of §3.2, green after; the scope tests of the same extension green on iOS 27.0 and on an iOS 26.x iPhone 17; then the whole `make ios-unit` on both. Already run once by the investigation (iOS 27.0 and 26.3.1: 7 scope tests passed; whole suite on 27.0: 190 tests, 174 passed, 16 skipped, 0 failed).

### 6.4 Still green

`make test` with the fix at `a387a8e`: `liquid_shell` `+1262: All tests passed!`, every other package and `tool/test` green; `make analyze` and `flutter analyze`: no issues.

## 7. Owner decisions (2026-10-23)

| # | Question | Decision |
|---|---|---|
| 1 | After the hand-back: ended or active? | Ended, text kept, `composing` false, no `onChanged` |
| 2 | Microtask or synchronous? | Microtask from the `native` setter; one frame of `isActive` true accepted |
| 3 | Also change `_endSearch`'s Flutter-mode `composing` rule? | No |
| 4 | A test for the forced glass tier? | Yes, P3 |
| 5 | Drop the composed text? | No, keep it |
| 6 | iPhone iOS 27 field at the top (VK-698) | Accept the system behaviour; fix the test only; update P3b §7.2 |
| 7 | iOS 27 CI leg | Not now (§8) |
| 8 | Docs | CHANGELOG line + a sentence in `doc/search.md` |

## 8. Follow-ups (not in this branch)

- An `ios-unit` leg on an iPhone iOS 27 simulator in CI, once the runner has the runtime (VK-698 would have been caught there).
- Whether `prominentTabIdentifier` is what makes iPhone iOS 27 stack the field (an Apple forum thread reports the same, no answer yet).

## 9. Risks

| Risk | Answer |
|---|---|
| A listener sees one frame of `isActive` true after the hand-back | Accepted (decision 2); the same as `releaseField` |
| The microtask runs after native came back | Guarded on `_native` and the controller's identity |
| `placement` strings come from our own debug snapshot | `NativeTabsController.debugSnapshot()` (`NativeTabsController.swift:871-881`) maps `searchBarPlacement`; the test reads the same value the snapshot reports |
| iOS 27.1 | iPhone 17 cannot be created on 27.1 here ("Incompatible device"); 27.0 is the measured runtime |

## 10. Process

Plane VK-699 / VK-698 → this spec → plan `docs/plans/2026-10-23-search-handback.md` → Task 1 (VK-699), Task 2 (VK-698), TDD, pre-commit by hand → review → `make verify` → PR to `main` → Plane Done. Spec and plan are committed and pushed with the branch as soon as they are written (owner go-ahead 2026-10-23).
