# liquid_shell VK-949: XCTests aware of the iPhone Duo vertical bar

- **Plane:** VK-949. Related: VK-930 (top band, #37), VK-938 (vertical chrome kind, #38).
- **Date:** 2026-11-08
- **Status:** approved ("duyệt", 2026-11-09). The owner accepted every proposed default ("Ok hết", 2026-11-08).
- **Branch:** `VK-949-duo-xctests`, from `main` 64f1b79.
- **Kind of change:** test-only (`liquid_shell/example/ios/RunnerTests/RunnerTests.swift`). No production code, no CHANGELOG, no publish.

> **Tóm tắt (cho chủ sản phẩm).**
> - `make ios-unit` đỏ 13 test trên iPhone Duo iOS 27.1 (190 pass / 13 fail). iPhone 17 Pro iOS 27.0 xanh 203/203.
> - Lý do: ở tư thế cột dọc, UIKit đưa tab vào cột phải, nav bar cố định 58 pt không có dòng tiêu đề lớn, vùng an toàn trên = 0. UIKit thuần cũng vậy. Tắt cột dọc thì 13 test xanh.
> - 11 test giả định bố cục iPhone thường: sửa để kiểm đúng bố cục Duo. 2 test ô tìm kiếm: việc đầu là đo xem bấm ⌕ có mở ô không, rồi mới chọn nhánh.

## 1. Goal

`make ios-unit` passes with 0 failures on an iPhone Duo iOS 27.1 simulator (folded outer portrait, the posture a fresh simulator boots in), and stays green on iPhone 17 Pro iOS 26.5. Each of the 11 assumption tests checks the real Duo layout under a vertical bar instead of being skipped there.

## 2. Root cause (from the Phase 1 investigation)

Under a vertical bar (`VerticalBarReader.side(view) != .none`), iOS 27.1 UIKit:

- draws the tab bar as a 69 × 678 column at x = 397 (folded outer, 466 × 678 window), with Inbox at (418, 581.7). The bar sits in the right safe inset (84), not the bottom (34);
- keeps the navigation bar at 58 pt and never adds a large-title row (bare `UINavigationController` matches);
- leaves the top safe inset at 0, which VK-930 raises to 26 for Flutter (`ShellMath.verticalBarTop`);
- collapses a stacked search bar in a scrolling, titled root to 0 pt (bare UIKit matches).

Plain UIKit reproduces every value. With `preferredVerticalBarBehavior = .disabled`, all 13 pass. Neither VK-930 nor VK-938 caused this.

## 3. Design

### 3.1 One test helper

Add to `NativeTabsTests`:

```swift
/// UIKit's vertical bar (iPhone Duo): the tab bar is a column on one side,
/// the navigation bar has no large-title row, the top safe inset is 0.
private func hasVerticalBar(_ tabs: NativeTabsController) -> Bool {
  VerticalBarReader.side(tabs.view) != .none
}
```

It uses the production reader, so the tests and the shell agree on what a vertical bar is. Tests that do not depend on the layout do not call it.

### 3.2 Expectations per group

Each test keeps its current assertions for the no-vertical-bar branch, unchanged. The vertical-bar branch asserts what that layout guarantees. It uses relationships, not pixel constants, except where the investigation measured a fixed UIKit value.

| Group | Tests | Vertical-bar expectation |
|---|---|---|
| A. Compact bar | `testACompactShellShowsTheBottomTabBarInFluttersBottomSafeArea`, `testADormantSpellKeepsTheTabsSoTheCompactBarComesBack` | The bar sits in the host's right (or left, from `side`) safe inset: that inset is at least the column's width (84 ≥ 69 measured; the window already carries the 84, so a "window + 40" check cannot hold), and Flutter's side inset equals the host's. The Inbox label's x lies inside the column (`> host.width − host.safeAreaInsets.right`). The bottom inset equals the window's (home indicator only). |
| A. | `testTouchesAboveTheCompactBarReachFlutter` | Touches just beside the column (`column.minX − 4`, at the Inbox label's y) reach `flutter.view`. The touch on the label itself is native, as today. |
| A. | `testTheTrailingActionIsTheSeparateCircleAfterThePill` | The trailing action is still a separate drawn circle, placed after the tab items along the column: its minY ≥ the Inbox label's maxY, and it does not contain the Inbox label. `compactBar()` gets a vertical-column reading (§3.3). |
| B. Large title | the 6 large-title tests | No large-title row exists: the bar height is the same at rest, scrolled and back (`abs(a − b) ≤ 0.5`). The title label is on screen inside the navigation bar. A test whose subject is "not stretched" (`…IsNotStretched`) asserts that the height never exceeds the at-rest height. Tests that check the reveal path (offset back to 0, title present) keep those checks. |
| C. Flutter top | `testATabWithoutPagesHidesItsNavigationBar` | Flutter's top equals `ShellMath.verticalBarTop(safeTop: page.top, barRegionTop: VerticalBarReader.topBarRegionTop(<host view>))`, read from the same view production reads (`NativeTabsController.syncFlutter`) (26 on the Duo), not the page top. The navigation bar stays hidden, as today. |
| D. Search field | `testTheFieldFrameIsPublishedInFlutterCoordinatesWhileSelected`, `testInEveryPhaseTheFieldIsNativeAndTheBodyIsFlutters` | Decided by the probe in §3.4. |

### 3.3 `compactBar()` under a vertical bar

Today `compactBar()` looks for a horizontal pill that holds the Inbox label and a circle to its right. Under a vertical bar the platter is a column. The helper gets a branch: with a vertical bar, the "pill" is the drawn subview that contains the Inbox label, and the "circle" is the drawn subview below it that does not contain the label. Callers that only exist for a horizontal layout keep the horizontal branch. If UIKit draws no separate platter for the tab items (the investigation found only the 48 × 48 circle at (418, 609)), the vertical branch reports `pill = nil` and the test asserts on the circle and the label alone. Task 1's probe records which case holds.

### 3.4 Search: probe first, then one of two branches

Task 1 measures on the Duo, without changing the tests:

1. Select the search tab. Does tapping the ⌕ circle in the column (or the selected search tab's item) activate `UISearchController` (`isActive`, the field on screen with height > 30)?
2. If so, where is the field, and does a hit test at its centre land on a native view?

Branch **yes** counts only a tap driven through UIKit (the control's action or accessibility activate). If only Dart's `setSearchActive` opens the field, that is branch **no**.

Branch **yes** (UIKit offers ⌕ as the Duo's way in): tests 12–13 activate search through that path when there is a vertical bar, then assert today's intent: a published frame with height > 30, and a native hit at the field's centre. The test documents that on the Duo the field is hidden until ⌕ is tapped.

Branch **no** (the field cannot be reached): create a new Plane item, "iPhone Duo: search field unreachable under the vertical bar" (the product gap is in `SearchMath.style`'s iPhone branch, which assumes the field is in the tab bar). Under a vertical bar, tests 12–13 wrap only the failing assertions in `XCTExpectFailure("<new id>: …")` (strict). The same gap makes the ⌕ circle take no touch, so the circle's native-hit check in `testTheTrailingActionIsTheSeparateCircleAfterThePill` (group A) is wrapped the same way (as built: VK-979, 3 expectations). The suite stays green, and the expectation fails once the product is fixed, which forces the test update. No production change in VK-949.

The probe's outcome and the chosen branch are written in the ledger and in the PR body. The owner is told which branch was taken. Because both branches are specified here, no extra approval is needed.

## 4. Non-goals

- No change to `SearchMath`, `ShellContainerController`, or any production Swift.
- No `XCTSkip` for vertical-bar runs in groups A to C.
- Other Duo postures (unfolded wide or tall) and real hardware are not measured: `simctl` cannot change posture. The helper's branching follows `VerticalBarReader`, so a posture without a vertical bar runs the regular assertions.
- The runtime move of the field to (28, 606) when `hidesSearchBarWhenScrolling` changes is not investigated. It belongs to the new search item if branch **no** is taken.

## 5. Verification

- `IOS_UNIT_DEVICE=<Duo 27.1 udid> make ios-unit`: 0 failures (203 passed on branch yes; on branch no, as built, 0 failed with 3 expected failures: the two search-field tests and the circle hit).
- `IOS_UNIT_DEVICE=<iPhone 17 Pro 26.5 udid> make ios-unit`: 0 failures, the same count as on main.
- Each changed test: run on the Duo before the change (red), then after it (green).
- `.githooks/pre-commit` exit 0 before each commit.
- Simulators are created and deleted by UDID by whoever runs them. The owner's named simulators are never touched.
