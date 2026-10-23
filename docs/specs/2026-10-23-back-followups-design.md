# liquid_shell back follow-ups: a closing dialog, a tab shown late, a nested shell

- **Plane:** VK-775 (S), VK-680 (S), VK-774 (M). Follow-ups of VK-593 (PR #21, merged at `a387a8e`).
- **Date:** 2026-10-23
- **Status:** approved by the owner 2026-10-23. Decisions: all three are fixed now, in one branch and one PR, in the order VK-775, VK-680, VK-774; VK-774 delegates back to the nested shell through an internal interface, with an iPad overlay-sidebar test and a CHANGELOG line for the behaviour change; VK-680 accepts that the scan walks hidden tabs down to their first navigator, and a re-scan when a known navigator's on-screen flag flips; VK-775 accepts depending on Flutter 3.44.6's `IgnorePointer` around a `ModalRoute` barrier, with the new test as the net for Flutter upgrades (VK-700). Plan: `docs/plans/2026-10-23-back-followups.md`.
- **Branch:** `VK-680-back-followups`, from `origin/main` at `a387a8e`.
- **Kind of change:**
  - Dart in `liquid_shell`: `lib/src/shell/branch_navigators.dart`, `lib/src/shell/liquid_shell.dart`.
  - Tests: widget tests in `test/widget/pushed_shell_back_test.dart`, both chrome modes (native through the fake platform, and Flutter).
  - Docs: `liquid_shell/CHANGELOG.md` under `## 0.1.0-dev.8` (the unreleased heading: `pubspec.yaml` is `0.1.0-dev.8` and VK-593's lines sit under it), `liquid_shell/doc/router_integration.md` (the VK-774 known limit goes).
  - No Swift, no Pigeon, no platform-interface change, no public API change (`branch_navigators.dart` is not exported), no version bump.
- **Sources:** the investigation of 2026-10-23 (each bug reproduced on the VK-593 branch head, each fix prototyped); the code at `a387a8e`; Flutter 3.44.6 `widgets/routes.dart`.

> **Tóm tắt (cho chủ sản phẩm).** Ba lỗi back còn lại sau VK-593, sửa chung một nhánh, theo thứ tự:
> - **VK-775 (S).** Bấm back lần 2 thật nhanh khi dialog còn đang đóng: shell tưởng dialog vẫn che trang, bỏ qua navigator lồng, nên pop nhầm trang ngoài. Sửa: barrier của route đang đóng (Flutter bọc nó trong `IgnorePointer(ignoring: true)`) không còn tính là che. Dựa vào chi tiết nội bộ của Flutter 3.44.6; test mới đỏ nếu Flutter đổi (VK-700).
> - **VK-680 (S).** Router hiện tab mới chậm vài frame (cross-fade) và app không có `PopScope` riêng: back pop cả shell thay vì trang trong tab. Sửa: lúc quét, ghi thêm navigator đầu tiên của tab đang ẩn (đánh dấu "không trên màn hình"); kiểm tra mỗi frame thấy cờ đó đổi thì quét lại.
> - **VK-774 (M).** Shell lồng trong body của shell khác (sub-tabs): back của shell ngoài pop thẳng trang trong tab của shell trong, bỏ qua sidebar overlay và ô tìm kiếm của shell trong. Sửa: shell ngoài dừng ở shell trong và giao back cho nó (interface nội bộ, không export), nên thứ tự của shell trong được giữ: sidebar overlay → tìm kiếm → trang của tab. **Đổi hành vi:** tìm kiếm của shell trong đang bật ở gốc tab thì back tắt tìm kiếm, không pop shell ngoài nữa (ghi CHANGELOG).
> - Không đổi API public. CHANGELOG thêm ba dòng; bỏ "known limit" sub-tabs trong `doc/router_integration.md`.

---

## 1. Goal

System back and the iOS edge swipe pop what the user sees in three cases VK-593 left: a second back while a dialog closes, a tab a router shows frames after the selection with no `PopScope` of the app's own, and a shell nested in another shell's body.

## 2. Scope

### 2.1 In

VK-775, VK-680, VK-774 below, each with its tests, the CHANGELOG lines and the router doc.

### 2.2 Non-goals

- A public way for an app's own widget to take part in back as a nested shell does. `NestedShellBack` stays internal; exporting it needs its own item.
- A shell with no navigator in its body at all: the per-frame check stays off there, as today (nothing to pop).
- The native back button (`_onNativeBack`) and the native chrome of a nested shell (README "One native chrome per window"). Unchanged.
- Flutter 3.47 (VK-700). VK-775's test is the net when it comes.

## 3. How the shell answers back today (file:line at `a387a8e`)

- `onScreenNavigatorsUnder(body)` (`branch_navigators.dart:127-150`) walks the body's elements, returns at a hidden subtree (`if (_hides(widget)) return;`, `:131`; `_shows`, `:140`), records each navigator (`:136`) with `handled`, and goes on into it.
- `_shows` skips an overlay entry that has a route after it with a barrier (`_routeAfter`, `:90-101`; `_hasBarrier`, `:105-117`, up to `_barrierDepth = 12` levels, `:103`).
- `_scanBranches` (`liquid_shell.dart:767-773`) stores the list (`:770`); `_checkBranches` (`:779-790`) re-checks it every frame with `isOnScreenUnder` (`branch_navigators.dart:156`) and `canPop()`, and sets `_branchCanPop`; `_armBranchCheck` (`:798`) stops the per-frame check when the list is empty (`:799`).
- `_backScope` (`:850-866`) builds the shell's `PopScope`: `canPop: !overlay && !searchActive && !_branchCanPop` (`:855`); a blocked pop closes the overlay sidebar, else deactivates the search, else `_popBranch` (`:812-830`), which pops the last navigator in tree order that can pop (`:818`).

## 4. VK-775: a second back while a dialog closes

**Evidence.** Tab 0 holds a page with its own navigator (a nested flow) with a pushed page, and a dialog on tab 0's navigator. Back 1 starts the dialog's reverse animation. Back 2, 50 ms later: the dialog's overlay entries are still in the overlay, so `_routeAfter` (`branch_navigators.dart:90-101`) finds its barrier after the flow page's entry and `_shows` hides the flow page; the nested navigator is not recorded, the list holds tab 0's navigator only, and its `maybePop` (the dialog no longer `isPresent`) pops the flow page: the outer page goes, the inner page should have.

**The signal.** Flutter 3.44.6 `ModalRoute._buildModalBarrier` (`widgets/routes.dart:2273-2287`) wraps every route's barrier in `IgnorePointer(ignoring: !animation!.isForwardOrCompleted)` (`:2278-2282`), and rebuilds the entry when the status changes (`changedInternalState`, `:2221`). A route closing or dismissed has `IgnorePointer(ignoring: true)` right above its barrier. This covers `ModalBarrier` (a transparent page route), `AnimatedModalBarrier`, and routes that override `buildModalBarrier`. Rejected: `AnimatedModalBarrier.color`'s status (misses the transparent `ModalBarrier`); `ModalRoute.of(barrierContext)` (registers a dependency from outside a build); the overlay entry of `_OverlayEntryWidget` (private).

**Design.** `_hasBarrier` returns false at an `IgnorePointer(ignoring: true)`: a barrier that takes no touch does not cover. One pattern match per element of the barrier walk (at most 12 levels): still cheap enough for the per-frame check. During a manual back swipe the status stays forward, so the barrier still counts, as today.

**Test (red first).** The case above in both modes: after back 2 the dialog is gone, the inner page popped, the flow page stays. Red today: `Found 0 widgets with text "Flow page: 0"`.

## 5. VK-680: a tab shown frames after the selection, no `PopScope` of the app's own

**Evidence.** A router shows the selected tab 300 ms after the selection (the end of a cross-fade), the tab left goes offstage at once. The scan after the selection frame finds no navigator: the new tab is still `Offstage`, the old one hidden (`branch_navigators.dart:131`, `:140`), so `_branches` is empty (`liquid_shell.dart:770`) and `_armBranchCheck` turns the per-frame check off (`:799`). 300 ms later the tab is on screen, but an `Offstage` change sends no `NavigationNotification`: nothing scans again, `_branchCanPop` stays false, and the shell's `PopScope` lets its route pop: back and the edge swipe pop the whole shell. VK-593's T2 test did not see it: its app `PopScope` blocks the route, so `_popBranch` runs and scans fresh.

**Design (owner choice).**

- The walk goes on into a hidden subtree **only down to its first navigator** (the tab's own, `inside` false), and records it with `onScreen: false`; it does not walk into that navigator. `BranchNavigator` gains `bool onScreen`.
- `_checkBranches({bool rescan = true})`: when a known navigator's on-screen state differs from the scan's, it calls `_scanBranches()` and returns: a full scan, so the navigators nested in a tab that just came on screen are found too. `_scanBranches` calls `_checkBranches(rescan: false)`, so a walk and an `isOnScreenUnder` that disagree cannot loop.
- `_popBranch` skips entries with `onScreen` false.
- `_armBranchCheck` is unchanged: the list is no longer empty while any tab has a navigator, so the per-frame check stays on.

**Cost.** The scan (on navigation events and on back, never per frame) now walks hidden tabs down to their first navigator; a hidden tab with no navigator is walked whole (marked `ponytail:` in the code). The per-frame check calls `isOnScreenUnder` for every tab navigator, hidden ones too, each its ancestors only.

**Tests (red first).** With no app `PopScope`, `_LateShow` body, a page pushed in tab 1, tab 0 selected, then tab 1 selected and on screen 300 ms later: back pops the page, not the shell; the edge swipe does the same; and with a nested flow as tab 1's root page (inner page pushed), back pops the inner page. The last one is what locks the re-scan: without it the tab's own navigator (at its root) is seen coming on screen, but the flow inside it never is. All red today: `Expected: false  Actual: <true>` (`shellPopped`).

## 6. VK-774: a shell nested in another shell's body (sub-tabs)

**Evidence.** The walk (`branch_navigators.dart:127-150`) goes through a nested `LiquidShell` and records its tab navigators; `_popBranch` (`liquid_shell.dart:812-830`) `maybePop`s them directly, skipping the inner shell's own order in `_backScope` (`:850-866`: overlay sidebar, then search, then the tab). The inner shell's own `PopScope` sits on the outer tab's page route, which system back never calls, so the inner shell is never asked. Two results: with the inner search active over a pushed page, back pops the page under the search (a regression of VK-593: before it, back popped the outer shell's route); with the inner search active at its tab's root, back pops the whole outer shell (as before VK-593).

**Design (owner choice: delegate).**

- An internal interface in `branch_navigators.dart`, not exported:

  ```dart
  abstract interface class NestedShellBack {
    bool get claimsBack;
    void handleBack();
  }
  ```

- `_LiquidShellState implements NestedShellBack`. `_backScope` stores the build's `overlay` and `searchActive` in `_backOverlay` and `_backSearch`; `claimsBack` is `_backOverlay || _backSearch || _branchCanPop`; `handleBack()` is the old body of `onPopInvokedWithResult` (overlay sidebar, else search, else `_popBranch`). The `PopScope` becomes `canPop: !claimsBack`, `onPopInvokedWithResult: if (!didPop) handleBack()`: the shell's own route answers exactly as before.
- The walk, at a `StatefulElement` whose state is a `NestedShellBack`, records it (`BranchNavigator.navigator` becomes `State target`) and **stops**: the inner shell's tabs are its own.
- `_checkBranches` and `_popBranch` ask `_canPop(target)`: `canPop()` for a navigator, `claimsBack` for a nested shell. `_popBranch` calls `handleBack()` on a nested shell. The outer shell reads `claimsBack` every frame, so it blocks its route (and the edge swipe) while the inner shell has something to do.
- `handled` keeps today's rule: an app's `NavigatorPopHandler` around the inner shell answers back for it, and the outer shell does not ask it again.

**Behaviour change (CHANGELOG).** With the inner shell's search active at its tab's root, back deactivates the inner search instead of popping the outer shell's route, as iOS does.

**Side effect.** `_backScope` writes two fields during build. They come from the same values as the `PopScope` it returns, so they cannot disagree with it.

**Tests (red first).** An inner `TestShell` (`nativeChrome: off`, on its search tab, one navigator per tab) as tab 1's root page:

1. inner search active over a pushed page: back deactivates the search, the page stays, the shell stays; the next back pops the page. Red today: `Found 0 widgets with text "Deep page: 0"`.
2. inner search active at the tab's root: back deactivates it, the shell stays; the next back pops the outer shell (nothing left inside). Red today: `Expected: false  Actual: <true>`.
3. **iPad** (`kTabletPortrait`): the inner shell's overlay sidebar open over its active search and a pushed page: back closes the sidebar, then the search, then pops the page; the shell stays throughout. The outer shell's bar covers the inner shell's sidebar button, so the test opens the sidebar through the inner shell's scope (`LiquidShellScope.setSidebarVisible(true)`), as the button does. Red today: `Found 0 widgets with text "Deep page: 0"` (reason "the sidebar first"). Not in the investigation; written for this spec.

## 7. Docs

- `CHANGELOG.md`, under `## 0.1.0-dev.8`: one Fixed line each for VK-775 and VK-680; one Fixed line and a **Behaviour change** line for VK-774.
- `doc/router_integration.md`: the known-limit bullet "A shell nested in another shell's body (sub-tabs)" (`:102-107`) goes; the list of back rules gains one that says how a nested shell answers back.

## 8. Risks

| Risk | Answer |
|---|---|
| VK-775 rests on Flutter's `IgnorePointer` around the barrier, not a contract | The VK-775 test goes red if Flutter changes it; CI `checks (stable)` runs it on the newest stable, and VK-700 tracks 3.47. |
| An app's own `IgnorePointer(ignoring: true)` above a `ModalBarrier` within 12 levels of an entry hides that barrier | A barrier that takes no touch does not cover; the same is true for the user. |
| VK-680's scan walks hidden tabs | Event-driven only; hidden tabs stop at their first navigator. Not measured as slow; `ponytail:` marks the ceiling. |
| VK-680's re-scan could loop if the walk and `isOnScreenUnder` disagree | `_scanBranches` checks with `rescan: false`: at most one re-scan per frame. |
| VK-774 changes the record shape used by `_checkBranches` and `_popBranch` | Internal only; every existing back test runs in both modes. |
| Coverage of the new branches | Every new branch has a test; the mutation tables of the plan show each one red without its line. |

## 9. Process

Plane VK-775, VK-680, VK-774 → this spec → plan `docs/plans/2026-10-23-back-followups.md` → Task 1 (VK-775), Task 2 (VK-680), Task 3 (VK-774), TDD, pre-commit by hand, one commit or more each → review per task and for the branch → `make verify` → one PR to `main` → Plane Done. Spec and plan are committed and pushed with the branch (owner go-ahead for these follow-up branches, 2026-10-23).

## 10. What the plan's prototype run changed against the investigation (2026-10-23)

The investigation's patches applied unchanged on `a387a8e` (its code is the merged code) and its tests went red-then-green as reported. While writing the plan:

1. **VK-680, a third test.** With the investigation's two tests, a mutation that removes the re-scan in `_checkBranches` stays green: the tab's own navigator, recorded hidden, is seen coming on screen by the per-frame check alone. The re-scan matters for a navigator nested in that tab. The test with a nested flow in tab 1 locks it.
2. **VK-680, one line less.** After recording a hidden navigator, the prototype returned (`if (!shownHere) return;`). The next level returns anyway (`!shownHere && inside`), so the line changes nothing (a mutation removing it stayed green with every test); it is not in the plan.
3. **The walk's doc comment** now says what it records for hidden tabs and nested shells.
4. **VK-774's tests** share one helper (`_Inner`, three users), take a `size` through `_Pushed.pump`, and check the step after the first back too (the page pops next; the outer shell pops when nothing is left inside).
5. **VK-774's iPad test** is new (§6, test 3).
