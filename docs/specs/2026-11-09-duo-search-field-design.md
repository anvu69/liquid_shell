# liquid_shell VK-979: a reachable search field under the iPhone Duo vertical bar

- **Plane:** VK-979. Related: VK-949 (Duo XCTests, #39, which added the three `XCTExpectFailure("VK-979 …")`), VK-930 (top band), VK-938 (vertical bar side).
- **Date:** 2026-11-09
- **Status:** approved: decisions "ok hết" and spec + plan "Duyệt" (2026-11-09).
- **Branch:** `VK-979-duo-search-field`, from `main` f95d6d1. Worktree `/Users/invoker/Projects/tuvi/liquid_shell-vk979`.
- **Kind of change:** production Swift in `liquid_shell_ios` (search style, one trait observer), the RunnerTests that cover it, `liquid_shell_ios/CHANGELOG.md`, one paragraph of `liquid_shell/doc/native_chrome.md`. No Dart API change, no pubspec bump, no publish.
- **Evidence:** `/Users/invoker/Projects/tuvi/vankhan/.superpowers/sdd/vk979-investigation.md`; `/Users/invoker/Projects/tuvi/vankhan/.superpowers/sdd/vk949-investigation.md` §4 group D; `/Users/invoker/Projects/tuvi/vankhan/.superpowers/sdd/vk949-search-probe.md` §A, §C.

> **Tóm tắt (cho chủ sản phẩm).**
> - Trên iPhone Duo (cột tab dọc), mở app ở tab Tìm kiếm thì ô tìm kiếm cao 0 pt: không thấy, không chạm được. UIKit thuần cũng vậy với cấu hình của shell.
> - Sửa: khi có cột dọc, ô tìm kiếm "không ẩn khi cuộn". Lần chọn tab đầu tiên ô nằm trên, dưới tiêu đề (thanh trên cao thêm 54 pt). Từ lần chọn thứ hai UIKit tự đặt ô ở dưới đáy: giữ nguyên như UIKit.
> - Gập/mở máy: chỉ đặt lại khi cột dọc xuất hiện hoặc biến mất, và không bao giờ khi đang gõ. Phần này chỉ có unit test, chưa kiểm được trên máy vì simulator không đổi được tư thế.
> - Test: bỏ cả 3 `XCTExpectFailure` của VK-979; ⌕ được tìm đúng nút thật. Duo 27.1 mong đợi 0 fail, 0 expected failure.
> - Đĩa hiện ~9,9 GB, dưới ngưỡng 10 GB: lúc thực thi, nếu vẫn dưới ngưỡng thì dừng và báo, không tạo simulator.

## 1. Goal

On an iPhone Duo under UIKit's vertical bar (`VerticalBarReader.side(view) != .none`), the search tab always has a native, on-screen, hit-testable field:

- the first selection, including a shell installed with the search tab selected, shows the field under the title row: (20, 82, 362, 44) in the folded outer portrait posture;
- later selections show UIKit's tab-hosted field at the bottom: (28, 606, 414, 48) inactive, (28, 606, 354, 48) active.

`make ios-unit` on a fresh iPhone Duo iOS 27.1 simulator then has 0 failures and 0 expected failures. On an iPhone 17 Pro iOS 26.5 it has 0 failures, and no assertion in a no-vertical-bar branch changes.

## 2. Root cause (from the investigation)

- `SearchMath.style`'s iPhone branch returns `.automatic` placement with `hidesWhenScrolling: nil` (UIKit's default, `true`). It assumes that on an iPhone the field is hosted in the tab bar.
- Under a vertical bar that holds only when the search tab is selected after the first layout. Selected at the first layout, UIKit stacks the field under the 58-pt bar, and the scroll-backed root at rest keeps it collapsed to 0 pt. Bare UIKit with the same settings matches.
- `hidesSearchBarWhenScrolling = false` gives (20, 82, 362, 44) at rest, a 112-pt bar, and a native hit. The field stays put through scrolling (+150, −80) and through activation and dismissal.
- Any runtime *change* of `hidesSearchBarWhenScrolling` or `preferredSearchBarPlacement` after layout makes UIKit re-realize the field as the bottom one. Reassigning the *same* value does not.
- The ⌕ "taking no touch" (VK-949) was the test's mistake. `compactBar()` picked the decoration `_UITabBarAuxiliaryView` (418, 609, 48, 48), the only `tabBar.subviews` entry, and `hitTest` returns nil there. The real control is a `_UITabButton` at (394, 606, 48, 48). It lives in the floating-bar host under `tabs.view`, not in `tabBar.subviews`, and a hit at its centre is native.

## 3. Design

### 3.1 The style (decision 1)

`SearchMath.style(isPad:osMajor:rootLargeTitle:verticalBar:)` gains `verticalBar: Bool`. The default is `false`, which keeps every existing call and test unchanged. It is a presence flag: a left or right bar and the layout direction do not change the style.

- iPhone with `verticalBar == true`: `hidesWhenScrolling: false`. Everything else stays as today (`.automatic`, `titleMode`, `prominent: osMajor >= 27`).
- iPhone without a bar: unchanged (`hidesWhenScrolling: nil`).
- iPad: unchanged (`.stacked`, `false`). No iPad has a vertical bar.

`NativeTabsController` keeps the bar presence the search root was styled for, `styledVerticalBar: Bool`. `rebuildTabsIfNeeded` sets it from `readVerticalBar(view)` (§3.2) just before `installSearch`. `searchStyle(rootLargeTitle:)` passes it. The value therefore reaches `installSearch` before the first layout. The investigation measured that at all three `searchStyle` calls during install the side is already `.right` and the view is in a window. The production installer also sets `window.rootViewController` before it calls `apply` (`NativeShellInstaller.install`).

`applySearch` runs on every config and reassigns the same `false` each time, which UIKit ignores (measured). `searchStyle` reads the stored value, not a fresh one, so a config can never be the thing that changes the value: only §3.2 changes it.

Accepted cost: on the Duo the search tab's navigation bar is 112 pt instead of 58 pt at rest, so Flutter's top inset on that tab grows by 54 pt. Other tabs are unchanged.

### 3.2 Fold and unfold (decision 3)

A pure decision in `SearchMath`:

```swift
static func hidesAfterBarChange(
  isPad: Bool, searchActive: Bool, had: Bool, has: Bool
) -> Bool?
```

- It returns nil (assign nothing) on an iPad, while the search is active, and when the bar's presence is unchanged. A left ↔ right swap is "unchanged".
- Otherwise it returns `!has`: `false` when the bar appears, and `true` (UIKit's default, which the regular style leaves alone) when it goes. Without that write, a Duo unfolded to the tall posture would keep `false`.

`VerticalBarReader.observeChanges(_:_:)` registers `registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge)` behind the same SDK and `#available(iOS 27.1, *)` guard as the reader. Before 27.1, or on an older SDK, it does nothing. `NativeTabsController.viewDidLoad` uses it to call `verticalBarChanged()`, which:

1. reads the bar's presence through `readVerticalBar` (default `{ VerticalBarReader.side($0) != .none }`, injectable for tests like `readWindowControls`);
2. asks `hidesAfterBarChange`, and assigns a non-nil answer to the search root's `navigationItem.hidesSearchBarWhenScrolling`;
3. updates `styledVerticalBar`, unless the search was active. Kept stale, the next call still sees the change.

The header warns that these traits can change while the edge stays the same, so the presence comparison is what makes this "only on a real change". After an assignment UIKit re-realizes the field: the investigation found that any change shows the bottom field, the same state as a later selection, so it stays reachable.

**Not verified on a device:** `simctl` cannot change the Duo's posture. The decision is unit-tested. The wiring is tested by injecting `readVerticalBar` and calling `verticalBarChanged()` directly, which is what the observer calls. Whether UIKit fires the observer on a real fold is not measured.

### 3.3 Vietnamese IME safety

The fix keeps every IME rule:

- **Never rebuild a focused field.** A posture change while the search is active assigns nothing (`searchActive` → nil). `searchBridge.onActive(false)` runs after `didDismissSearchController`, when the field is no longer first responder, and calls `verticalBarChanged()` again. That applies the deferred value then.
- **Never write while composing.** Nothing here writes text. `SearchBridge`'s text paths are untouched.
- **Native → Dart events only.** No new channel call. The field frame is still published by `publishSearchField` on layout.
- **Focus never in a hidden field.** The change makes a 0-pt (hidden) field visible. It never hides a field that has focus, because the 44-pt field stays through activation (measured), and a re-realization only happens while the search is inactive.

### 3.4 Later selections (decision 2)

Nothing forces the field to the top. From the second selection on, UIKit shows its bottom field. Inactive, it spans (28, 606, 414, 48) and covers the ⌕ button, as in bare UIKit. Active, it spans (28, 606, 354, 48), clear of the column (maxX 382 < 397). It is native and published. The shell's `shouldSelectTab`, which proposes every destination to Dart, is unchanged.

### 3.5 Tests (decision 4)

| Test | Change |
|---|---|
| `SearchMathTests` | 2 new: the vertical-bar style (`hidesWhenScrolling == false` on an iPhone on 26 and 27; the iPad and no-bar results unchanged), and the `hidesAfterBarChange` table. |
| `testTheFieldFrameIsPublishedInFlutterCoordinatesWhileSelected` | The `if hasVerticalBar` branch and its `XCTExpectFailure` go. The existing `XCTAssertGreaterThan(frame.height, 30)` runs everywhere. The doc comment loses the "known gap" text. |
| `testInEveryPhaseTheFieldIsNativeAndTheBodyIsFlutters` | The same: one native-hit assertion everywhere, at the top field (first selection). |
| `testTheTrailingActionIsTheSeparateCircleAfterThePill` | `XCTExpectFailure` goes, and the circle's native hit is asserted directly. The hit wait is 10 s on every device (it was 0 under a vertical bar). |
| `compactBar()` | Under a vertical bar, `circle` is the drawn `UIControl` in `tabs.view`, below the Inbox label and not containing it, furthest down: the `_UITabButton`, found by type (`UIControl`), not by private class name. The horizontal branch is unchanged. |
| new `testUnderAVerticalBarALaterSelectionShowsUIKitsBottomField` | iPhone with a vertical bar only (`XCTSkipUnless`). Install on Home, then select Search. The field is on screen with height > 30 and below the window's middle, the hit at its centre is native, and the published frame has height > 30. Active: the hit is native and the field is clear of the column. |
| new `testAVerticalBarChangeRestylesTheSearchFieldOnlyWhenItComesOrGoes` | Any iPhone. `readVerticalBar` is injected with the opposite presence, then `verticalBarChanged()` writes `!has`. Calling it again with the same presence writes nothing (a sentinel value survives). Going back to the start writes the start's value. |
| new `testAVerticalBarChangeWhileSearchingWaitsForTheSearchToEnd` | Any iPhone. With the search active, a change writes nothing. After Cancel, the deferred value is written. |

No-vertical-bar branches keep their expressions and messages. The trailing-action circle frame under a bar was not measured (only bare UIKit's prominent search tab was). The plan's red run measures it before `compactBar()` changes.

### 3.6 Changelog and docs (decision 5)

The repo records unreleased work under the next dev heading above the pubspec version. `liquid_shell_ios/CHANGELOG.md` already has `## 0.1.0-dev.12` (pubspec `0.1.0-dev.11`); one bullet goes there. `liquid_shell/doc/native_chrome.md` gets one sentence under its search table about the Duo, with no internal references (the `public-docs` gate). No version bump, no publish.

## 4. Non-goals

- Forcing every selection to the top field (candidate 2) or disabling the vertical bar (candidate 3).
- `automaticallyActivatesSearch` under a vertical bar (Q13 stays).
- `verticalBarCompressionBehavior` (not measured).
- Other postures and real hardware beyond §3.2's unit tests.
- Dart and Android packages.

## 5. Verification

- Each production change follows a red run: on the Duo for the field tests and the circle, and at compile time or as a unit test for `SearchMath`.
- `.githooks/pre-commit` exits 0 before each commit. Never `--no-verify`.
- A fresh iPhone Duo 27.1 `make ios-unit`: exit 0, `failedTests` 0, `expectedFailures` 0. Baseline on main (VK-949 T5): total 227, passed 200, skipped 24, expected 3. Expected after: total 232 (+5 new), passed 208, skipped 24.
- A fresh iPhone 17 Pro 26.5 `make ios-unit`: exit 0, `failedTests` 0, `expectedFailures` 0. Baseline: total 227, passed 201, skipped 26. Expected after: total 232, passed 205, skipped 27 (the Duo-only test skips).
- Simulators are created and deleted by UDID, one at a time, never the owner's.
- **Disk:** at least 10 GB free before each simulator. It is ~9.9 GB at spec time, so the first simulator step may stop and report. That is by design, not a failure of the plan.
- Posture change (§3.2) on a device: not verified. That is stated in the PR.
