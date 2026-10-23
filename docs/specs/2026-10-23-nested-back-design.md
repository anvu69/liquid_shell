# liquid_shell VK-593: back and the edge swipe find the right navigator

- **Plane:** VK-593 (sub-items VK-686 T1, VK-687 T2, VK-688 T3, VK-689 T4, VK-690 T5).
- **Date:** 2026-10-23
- **Status:** approved. The owner approved the design on 2026-10-23 ("Duyệt"), including the one open choice: the inner navigator pops first (§7).
- **Branch:** `VK-593-nested-back`, from `origin/main` at `bfcccb6`.
- **History:** a first spec and plan (`docs/plans/2026-10-19-nested-back.md`) were written on 2026-10-19 and the Plane sub-items point at them, but they were never committed and are lost. This spec replaces them; the five tasks keep their Plane names.
- **Kind of change:**
  - Dart in `liquid_shell`: `lib/src/shell/branch_navigators.dart`, `lib/src/shell/liquid_shell.dart` (only if a task needs it), `lib/src/native/window_controls.dart`.
  - Tests: Dart widget and unit tests.
  - Docs: `liquid_shell/CHANGELOG.md` under `## 0.1.0-dev.8` (Fixed), and the back section of `liquid_shell/doc/` that describes `NavigatorPopHandler`, if one does.
  - No Swift, no Pigeon, no platform-interface change, no public API change, no version bump.
- **Sources:** the VK-567 re-review (findings M1, the `NavigatorPopHandler` pair, PageView, missing tests, and the unrelated `window_controls` NaN), as listed in the Plane item; the code at `bfcccb6`; Flutter 3.44.6 `navigator_pop_handler.dart`.

> **Tóm tắt (cho chủ sản phẩm).** Khi người dùng bấm back hoặc vuốt mép, shell phải chọn đúng navigator để pop. Hiện có ba chỗ chọn sai và một lỗi vặt:
> - **T1.** `window_controls` gọi `setState` ở mọi frame khi số đo ra `NaN` (vì `NaN != NaN`). Sửa: hai `NaN` coi là bằng nhau.
> - **T2.** Ba cơ chế quét lại trong `_popBranch` chưa có test khoá. Chỉ thêm test, mỗi test đỏ khi bỏ đúng cơ chế đó.
> - **T3.** `NavigatorPopHandler` bị tắt vẫn được Flutter gọi callback, nên shell pop thêm lần nữa (pop hai trang). Handler không có callback thì shell tưởng app tự lo, nên back bị nuốt. Sửa: "app tự lo" khi handler **có callback**, bất kể bật hay tắt.
> - **T4.** Tab chứa `PageView` giữ sống trang bên cạnh: back pop trang không hiện trên màn hình. Sửa: con của danh sách cuộn nằm ngoài vùng đang hiện thì không tính.
> - **T5.** Trang của tab có navigator riêng bên trong: back và vuốt mép pop navigator ngoài, hoặc pop cả shell. Sửa: dò tiếp vào trong, pop **navigator sâu nhất còn pop được** (như iOS), không có thì mới pop navigator ngoài.
> - Không đổi API public. CHANGELOG thêm các dòng "Fixed".

---

## 1. Goal

System back and the iOS edge swipe pop the page the user sees: the deepest navigator on screen that can pop, through its own `PopScope`, exactly once.

## 2. Scope

### 2.1 In

T1–T5 below, each with its tests, and the CHANGELOG lines.

### 2.2 Non-goals

- **VK-680** (a tab shown a few frames after selection: back does not find its navigator). Own item.
- **go_router support (P4).** VK-593 is its prerequisite; no router code here.
- **The native back button** (`_onNativeBack`, `liquid_shell.dart:562`). It pops the page the native bar shows, from the shell's page records; a navigator nested inside a page has no native bar entry. Unchanged.
- A public way for the app to pick the navigator. None is added.

## 3. How the shell picks a navigator today (file:line at `bfcccb6`)

- `onScreenNavigatorsUnder(body)` (`branch_navigators.dart:41-60`) walks the body's elements, skips subtrees hidden by `Visibility(visible: false)`, `Offstage(offstage: true)`, `TickerMode(enabled: false)`, and the non-selected children of an `IndexedStack` (`_shows`, `:22-33`). It records each navigator it meets, with `handled` = an enabled `NavigatorPopHandler` lies between the body and it, and **stops** there.
- `_scanBranches` (`liquid_shell.dart:767`) stores that list; `_checkBranches` (`:777`) re-checks it every frame with `isOnScreenUnder` (`branch_navigators.dart:64-77`, ancestors only) and `canPop()`, and sets `_branchCanPop`.
- `_backScope` (`:848`) blocks the shell's own route while `_branchCanPop`; a blocked pop calls `_popBranch` (`:810`): a fresh scan unless mid-frame, then the **last** navigator in tree order that can pop (`.reversed`); `handled` → return; else `maybePop` and a re-scan in `whenComplete`.

## 4. T1 (VK-686): no rebuild every frame on a NaN measure

**Evidence.** `window_controls.dart:186`: `if (start != _start) setState(...)`. When the row's transform is degenerate, `_startOf` returns `NaN`; `NaN != NaN` is always true, so every post-frame measure calls `setState`, which schedules another frame and another measure: a frame loop while the row sits off screen in a kept-alive branch.

**Design.** Treat two NaN values as equal: no `setState` when both `start` and `_start` are NaN. A NaN is still stored the first time (`_start == null`), as today.

**Test (red first).** A widget test that puts the controls row where `_startOf` yields NaN and counts builds over several pumps: red today (one build per frame), green after (no build after the first).

## 5. T2 (VK-687): lock the re-scan mechanisms of `_popBranch`

Test-only. Three tests, each red under a mutation that removes exactly one mechanism (the mutation is applied by hand, seen red, reverted; recorded in the task report):

1. **Fresh scan when back comes before the frame.** A navigator appears (push into a tab that had none to pop) and back arrives in the same frame: the new page pops. Mutation: drop the `_scanBranches()` call at the top of `_popBranch`.
2. **Re-scan after the pop completes.** After back pops a branch's last page, the shell's route is free again without another navigation event: the next back pops the shell's route. Mutation: drop the `whenComplete` re-scan.
3. **Last in tree order.** Two navigators on screen that can both pop (master and detail): back pops the later one. Mutation: drop `.reversed`.

If a mutation leaves its test green, the mechanism is not needed on that path: the task reports it and the owner decides (keep, or remove the mechanism in a follow-up). No production change in T2.

## 6. T3 (VK-688): a `NavigatorPopHandler` with a callback answers back, enabled or not

**Evidence (Flutter 3.44.6, `navigator_pop_handler.dart`).** The handler builds `PopScope(canPop: !widget.enabled || _canPop, onPopInvokedWithResult: (didPop, result) { if (didPop) return; widget.onPop?.call(); widget.onPopWithResult?.call(result); })`. The route calls every `PopScope` on it when a pop is blocked; the shell's own `PopScope` blocks it while a branch can pop. So:

- **disabled handler with a callback:** its callback still runs (`didPop` false), the app pops its navigator; the shell, which counts only `enabled` handlers, pops the same navigator again: **two pages pop**;
- **enabled handler without a callback:** nothing pops on its side, but the shell counts it as `handled` and returns: **back is swallowed**.

**Design.** `handled` = a `NavigatorPopHandler` with `onPop != null || onPopWithResult != null` lies between the body and the navigator, whatever `enabled` says. The shell's doc comments (`branch_navigators.dart:3-6`, `_popBranch`, `_backScope`) say so.

**Tests (red first).** Disabled handler with `onPop` that pops its navigator: one back pops exactly one page (red today: two). Enabled handler with no callback: back pops the page (red today: nothing pops). The existing enabled-with-callback test stays green.

## 7. T4 (VK-689): skip a scroll child that is not on screen

**Evidence.** `_shows` understands only `RenderIndexedStack`. A tab whose body is a `PageView` with kept-alive pages (`AutomaticKeepAliveClientMixin`, or a list with a cache extent) keeps each page's element and navigator under the sliver. The walk finds them all; `.reversed` then picks the last, which may be a page off to the right: back pops a page the user cannot see.

**Design.** `_shows(parent, child)` also answers for a `RenderSliverMultiBoxAdaptor` parent: the child is shown only when its render box is laid out in the sliver's list (not kept alive: its `SliverMultiBoxAdaptorParentData.keptAlive` is false) and its extent along the main axis overlaps the visible window `[constraints.scrollOffset, constraints.scrollOffset + constraints.remainingPaintExtent)`. Mid-swipe two pages overlap the window: both count, and the later in tree order pops, as for master and detail. Both the scan and the per-frame `isOnScreenUnder` use `_shows`, so both follow.

**Tests (red first).** A `PageView` of three kept-alive pages, each with a navigator holding a pushed page, showing page 0: back pops page 0's page and not page 2's (red today). After swiping to page 1, back pops page 1's. A `ListView` with a cache extent gives the same answer for an item scrolled out of view.

## 8. T5 (VK-690): the inner navigator of a tab's page pops first

**Evidence (M1).** The walk stops at the first navigator. When a tab's page holds its own navigator (a nested flow), its pages are invisible to the shell: at the tab's root the shell's route is not blocked, so back, and the edge swipe of a shell that is itself a pushed page, pop the whole shell instead of the inner page; when the tab's navigator can also pop, back pops the tab's page and takes the whole inner flow with it.

**Design (owner choice: inner first, as iOS and Flutter's `NavigatorPopHandler` do).**

- The walk does not stop at a navigator: it records it and goes on into it, so nested navigators are found too. Each record carries its depth (how many navigators are above it under the body).
- A nested navigator counts only while it is on screen inside its outer navigator: the route that holds it is the outer one's current route. Routes below an opaque route are already skipped by `_hides` (the overlay wraps them in `TickerMode(enabled: false)`); a route below a dialog is not, so the walk also checks that the nested navigator's enclosing route `isCurrent`. A page behind a dialog never pops before the dialog.
- `_popBranch` picks, among the navigators that can pop, the deepest; among equally deep ones, the last in tree order (T2.3 keeps holding). `handled` is read for that navigator only, as today.
- `_branchCanPop` is true when any recorded navigator can pop, so a nested flow at the tab's root blocks the shell's route and the edge swipe falls to the inner page, as it does for the tab's own pages today.

**Tests (red first).** A tab whose root page holds a nested navigator with one pushed page:
1. the tab's navigator at its root: back pops the inner page, not the shell's route (red today);
2. the tab's navigator also holds a pushed page above which sits the nested flow: back pops the inner page first, then (inner at root) the tab's page;
3. a dialog pushed on the tab's navigator over the page with the nested flow: back closes the dialog, the inner page stays;
4. a shell pushed as a page (`pushed_shell_back_test.dart` setup): the edge swipe on the tab's root with a nested pushed page pops the inner page, not the shell (red today).

If test 4 shows Flutter's gesture arena giving the swipe to another route than back picks, the task stops and reports to the owner before changing anything else.

## 9. CHANGELOG

Under `## 0.1.0-dev.8`, "Fixed": one line each for T1, T3, T4, T5 (T2 is tests only).

## 10. Risks

| Risk | Answer |
|---|---|
| Walking into every navigator costs more per scan | The scan runs on navigation events and on back, not per frame; the per-frame check walks ancestors only. A nested flow adds its own subtree once. |
| A change in Flutter's `NavigatorPopHandler` (enabled semantics) | T3's tests pin today's behaviour on 3.44.6 and fail on a change; CI `checks (stable)` runs them on the newest stable too. |
| `keptAlive` and sliver constraints are framework details | Both are public API of `rendering.dart`; T4's tests cover PageView and ListView. |
| Two parallel branches touch `branch_navigators.dart` | No other open branch does at `bfcccb6`. |

## 11. Process

Plane VK-593 → this spec → plan `docs/plans/2026-10-23-nested-back.md` → tasks T1–T5 (TDD, pre-commit by hand, one commit or more each) → review per task and for the branch → `make verify` → PR to `main` → Plane Done. Spec and plan are committed and pushed with the branch as soon as they are written, so they cannot be lost again (owner go-ahead for pushing this branch: 2026-10-23).
