# liquid_shell VK-776: a nested shell on its host's route lets the host answer back (with VK-779, the landscape ⌕ overflow)

- **Plane:** VK-776 (the main item), VK-779. Parent: VK-780 (liquid_shell backlog wave 2).
- **Date:** 2026-10-28
- **Status:** approved. The owner answered the wave-2 decision table (Q1–Q18) with "Ok hết" on 2026-10-28. This spec records Q7 (VK-776), Q8 (VK-776 priority, VK-779) and the CHANGELOG rule of Q2. Plan: `docs/plans/2026-10-28-back-overflow.md`. The choices this spec had to add are listed in "Quyết định phát sinh", at the end.
- **Branch:** `VK-776-back-overflow`, from `main` at `e0bbf62` (branch S of wave 2).
- **Kind of change:**
  - Dart in `liquid_shell`: `lib/src/shell/liquid_shell.dart` (VK-776) and `lib/src/search/search_chrome.dart` (VK-779).
  - Tests: Dart widget tests in `test/widget/pushed_shell_back_test.dart` (VK-776), `test/widget/search_morph_test.dart` and `test/widget/shell_chrome_test.dart` (VK-779).
  - Docs: `liquid_shell/doc/router_integration.md` (two bullets), `liquid_shell/CHANGELOG.md` under a new `## 0.1.0-dev.10` heading.
  - No change to `branch_navigators.dart`, no native code, no Pigeon, no platform-interface change, no public API change, no other package, no version bump, no simulator or device step.
- **Sources:**
  - The wave-2 evidence report for VK-776 and VK-779 (investigator, 2026-10-28): 13 VK-776 probes (S1–S11, S1b, S1n) and the VK-779 frame probes, run at `e0bbf62` with Flutter 3.44.6, plus a throwaway prototype of each fix.
  - The code at `e0bbf62`. Every file:line below was read again there.
  - **Prototype** (2026-10-28, while writing this spec and the plan). The plan's test code and production code ran in this worktree, then were removed:
    - every red-first test of §7 was red at `e0bbf62` for the reason given there, and green with the plan's code;
    - every mutation check of §7.3 turned the named tests red;
    - the whole `liquid_shell` suite passed after each task (`+1307` after Task 1, `+1316` after Task 2; 1290 at `e0bbf62`), and `make verify` passed with both tasks applied (`liquid_shell` coverage 97.81 %, the 36 plain and 27 liquid example goldens unchanged).

> **Tóm tắt (cho chủ sản phẩm).**
> - **VK-776.** Khi trang của một tab chính là một `LiquidShell` khác (tab con, không có `Navigator` ở giữa), shell trong nằm trên cùng route với shell ngoài, nên cả hai cùng trả lời một lần back:
>   - một trang "bỏ thay đổi?" (`PopScope(canPop: false)`) bị hỏi 2 lần, hiện 2 hộp thoại; 3 shell lồng nhau thì 3 lần;
>   - shell trong nằm ở một tab đang ẩn vẫn giữ back: back pop một trang người dùng không thấy, và trên Android ở shell gốc thì không thoát được app;
>   - khi sidebar overlay của shell ngoài đang mở, hoặc ô tìm của shell ngoài đang active, một lần back vừa làm việc đó vừa pop trang của shell trong.
>   - **Sửa (khoảng 15 dòng Dart, một file):** shell trong biết mình nằm trong body của shell ngoài, trên cùng route, thì "đứng sang một bên": `PopScope` của nó không chặn và không làm gì. Shell ngoài vốn đã thấy shell trong khi duyệt cây, nên nó chuyển back cho shell trong theo thứ tự của mình (sidebar, ô tìm, rồi tab đang chọn), và chỉ khi shell trong đang hiện. Có `Navigator` ở giữa (go_router luôn có) thì không đổi gì.
> - **VK-779.** Màn ngang, chrome Flutter: lúc chuyển từ idle sang tab tìm (chạm ⌕, thả kéo lên ⌕, hay app tự chọn), bản debug báo "RenderFlex overflowed by 12 pixels" trong khung hình đầu của chuyển động. Bản release không thấy gì sai.
>   - **Sửa:** bọc `Row` của ô tìm trong một `ConstraintsTransformBox` (rộng ít nhất 56, cắt phần thừa). Chỉ đổi layout: ô không bị dựng lại, không ai ghi vào ô, nên quy tắc bộ gõ tiếng Việt vẫn giữ.
> - **Kiểm tra:** widget test Dart trên VM, cho cả iOS và Android. Không cần simulator.
> - **CHANGELOG:** hai dòng "Fix" dưới tiêu đề mới `## 0.1.0-dev.10` của `liquid_shell`. Không nâng phiên bản.

---

## 1. Goal

1. **VK-776: one back, one actor.** A shell in another shell's body with no navigator between (a tab's page that is itself a `LiquidShell`) no longer answers back beside the outer shell:
   - a page's refusing `PopScope` is asked once per back (one dialog, not two), also with three shells on one route (one, not three);
   - a nested shell in a hidden tab does not hold back and never pops a page the user cannot see; at an Android root shell whose shown tab is at its root, back leaves the app;
   - with the outer shell's overlay sidebar open or its search active, one back acts in the outer shell only.
2. **VK-779.** In compact landscape with the Flutter chrome, idle → search selected (a tap on the ⌕, a lens drag dropped on it, the app selecting the tab) reports no overflow, on iOS and Android. The search field is never rebuilt and never written to (the Vietnamese IME rule).

**Success:** the tests of §7 are red before the change for the reason given there and green after it. The mutation checks of §7.3 turn the named tests red. `make verify` passes.

## 2. Scope

### 2.1 In

- `_LiquidShellState` (`liquid_shell.dart`): a private marker on the body, a `_hosted` flag, two changed lines in `_backScope` (§4).
- `SearchFieldGlass` (`search_chrome.dart`): a `ConstraintsTransformBox` around the field's `Row`, and the Row's fixed parts as named constants (§5).
- Tests: §7.
- Docs: §8.

### 2.2 Non-goals

- Changing the walk (`branch_navigators.dart`), or the item's suggested fix A (the walk skips a same-route nested shell). See §4.5.
- A navigator between the outer tab and the nested shell (the VK-774 layout, go_router's `StatefulShellRoute` and `ShellRoute`): unchanged.
- The native back button (`_onNativeBack`, `liquid_shell.dart:567-579`) and native chrome for a nested shell: a nested shell still needs `nativeChrome: off` (`:190-193`).
- The one-frame lag of a nested shell's new claim (§9): kept, as VK-774 kept it.
- An app `NavigatorPopHandler` placed directly around a same-route nested shell: the existing "the app answers" rule applies (§4.4); no new test.
- VK-779: the regular top field, native chrome, portrait (not affected, §3.2), and any change of the morph's geometry.
- A version bump, a simulator or device run.

## 3. What the evidence shows (file:line at `e0bbf62`)

### 3.1 VK-776: a nested shell with no navigator between

- Each shell builds its own `PopScope` in `_backScope` (`liquid_shell.dart:868-882`: `canPop: !claimsBack`, `if (!didPop) handleBack()`), from both layouts (`:1773`, `:2019`). `PopScope` registers with `ModalRoute.of(context)`. With no navigator between, the inner shell's `PopScope` lands on the **outer shell's route**, and a route calls every `PopScope` registered on it when a pop is blocked.
- The outer shell's walk records the inner shell whether a navigator lies between or not (`branch_navigators.dart:168-176`; the `inside` flag, `:156`/`:180`, is not read there). The outer counts the inner's claim (`_canPop`, `liquid_shell.dart:898-902`, from `_checkBranches` `:788-803`) and delegates to it (`_popBranch` `:825-849`, `handleBack()` at `:837`).
- So two actors answer one back: the outer by delegating, the inner through its own `PopScope`. `handleBack` (`:888-896`) ends in `_popBranch`, which calls `maybePop` (`:842`). Both `maybePop`s run the top page's `PopScope` callback: a dialog goes on the root navigator, so the inner tab navigator's top entry does not change between them (probe S1b).
- The same fact, a second `PopScope` on the outer route that knows nothing of the outer walk, explains the other three bugs:
  - **A hidden inner shell** (probes S3, S5, S9). The inner's `_branchCanPop` checks visibility only up to its **own** body (`isOnScreenUnder(…, body)`, `branch_navigators.dart:201-214`, called at `liquid_shell.dart:795`). Its tab with a page counts as on screen while the outer `IndexedStack` hides the whole inner shell. Its `PopScope` keeps the outer route blocked, and its callback pops the hidden page. This breaks the documented rule "a page kept in another tab never holds back the shell's own pop" (`doc/router_integration.md:68-72`). On Android the framework then claims back at the shown tab's root (`setFrameworkHandlesBack(true)`), so the app cannot be left.
  - **Two actors, two orders** (S4, S9). The outer acts on its overlay sidebar or search (`liquid_shell.dart:889-892`), and the inner, called on its own, pops its page.
- With a navigator between (VK-774), the inner's `PopScope` sits on the outer tab navigator's root route, which system back never calls. VK-774's tests (`pushed_shell_back_test.dart:1198-1283`) never saw the bug for that reason.

| Probe | At `e0bbf62` |
|---|---|
| S1 a refusing page in the inner tab, one back | asked twice: `Expected: <1> Actual: <2>` |
| S1b the refusal shows a dialog | two dialogs |
| S1n S1 with the outer in native chrome | asked twice |
| S3 inner hidden (outer on Home, at its root), a page in the inner tab, back | the shell stays, the hidden page pops |
| S4 iPad, outer overlay sidebar open, inner page, back | the sidebar closes and the page pops |
| S5 Android root shell, inner hidden with a page, outer at its root | `setFrameworkHandlesBack(true)`: the app cannot be left |
| S6 Android root shell, inner shown, refusing page | asked twice |
| S7 edge swipe on the inner page | green: pops it, the shell stays |
| S8 inner search active over a page | green: the search ends, the page stays |
| S9 outer search active, inner hidden with a page | the search ends and the hidden page pops |
| S10 three shells on one route | asked 3 times |
| S11 the VK-774 layout in an app `NavigatorPopHandler`, inner search active | green: the search ends |

### 3.2 VK-779: the landscape ⌕ grows into the field

- **The overflowing flex** is the field's `Row` (`search_chrome.dart:107-149`). Its fixed parts are the leading `SizedBox(14)` (`:109`), the `Icon` of size 20 (`:110-114`), the `SizedBox(8)` (`:115`) and the trailing `SizedBox(14)` (`:147`): 56 in all. The `Expanded` `TextField` (`:116-132`) takes the rest, down to 0. The compact field never has the inline × (`field: searchField()`, `liquid_shell.dart:1579`).
- **The width is the morph's start.** In idle the field's rect is the ⌕, `rowExtent` square (`search_layout.dart:146-148`). In compact landscape `rowExtent` is the measured bar, 44 (`TabMetrics.landscapeExtent`, `tab_geometry.dart:56`). In portrait it is 62 (`kBottomPillExtent`, `shell_layout.dart:39`), which is at least 56.
- **Why only on the selection.** The Row overflows the 44-wide ⌕ during all of idle, but idle paints it at `Opacity(0)` (`search_chrome.dart:105-106`). `RenderOpacity` skips a fully transparent child, and `RenderFlex` reports an overflow from `paint`. On idle → selected the phase flips in one build: the opacity becomes 1 while the `AnimatedPositioned` (`search_chrome.dart:285-305`) is still at its start, 44. The morph's first frame paints the Row at 44 and reports `A RenderFlex overflowed by 12 pixels on the right` at `search_chrome.dart:107:28`. The next frame is already about 80 wide. selected → idle turns the opacity to 0 first, so nothing is reported, and idle → active cannot happen directly (`shell_search.dart:312-321`).
- **Affected:** compact landscape (width > height and height < `breakpoints.compactHeight`) with the Flutter chrome, on every platform: Android, iOS without native chrome, desktop, web. A tap, a drop and an app selection all reproduce it, with or without a side inset, and before VK-702 too (`7ff7bf3`).
- **Not affected:** native chrome (UIKit draws the field, `_resolveNative` returns first, `liquid_shell.dart:1222-1227`), portrait, and the regular top field (built only when not idle, `:1338-1349`, as wide as the body minus 40).
- **Impact:** debug only, a `FlutterError` and one frame of yellow-and-black stripes. In release the overflowing part is the invisible trailing spacer and the icon fits (14 + 20 = 34 of 44). It fails any widget test that drives the landscape search: VK-702's left-inset test hovers and then cancels instead of dropping for that reason (`shell_chrome_test.dart:1362-1386`, `g.cancel()` at `:1385`).

## 4. Design: VK-776, the inner shell steps aside, the outer one answers

**Rule (Q7).** A shell in another shell's body, on the same route, lets that shell answer back for it: its own `PopScope` never blocks and never acts. The outer shell's walk already records the nested shell with its on-screen flag (`branch_navigators.dart:168-176`), so the outer shell hands back to it in the outer order (overlay sidebar, then search, then the selected tab's content, which is the nested shell), and only while it is on screen.

### 4.1 The host marker

A private `InheritedWidget` marks a shell's body. It wraps the body inside `_bodySubtree` (`liquid_shell.dart:907-916`), under the `KeyedSubtree` that the walk starts from, so it moves with the body when the shell switches between native and Flutter chrome:

```dart
/// Marks a shell's body: a shell nested in it finds its host here.
class _ShellBody extends InheritedWidget {
  const _ShellBody({required this.shell, required super.child});

  final _LiquidShellState shell;

  // Built by [shell] itself, so it never changes.
  @override
  bool updateShouldNotify(_ShellBody oldWidget) => false;
}
```

```dart
  Widget _bodySubtree(LiquidChromeKind? kind) => KeyedSubtree(
    key: _bodyKey,
    child: _ShellBody(
      shell: this,
      child: NotificationListener<NavigationNotification>(
        onNotification: _onBranchNavigation,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => _onBodyScroll(n, kind),
          child: widget.body,
        ),
      ),
    ),
  );
```

Only the host's **body** counts, the part its walk covers. A shell elsewhere in the host (a sidebar header, a chrome builder's slot) is not walked, so it keeps its own `PopScope` ("Quyết định phát sinh" 1).

The nearest marker alone does not say that a shell is in its host's body. A shell in the sidebar header of a nested shell M, with M in the body of a shell O on the same route, has no marker of M above it (M marks only its body), so the nearest marker is O's. O's walk records M and stops there, and M's walk covers only M's body, so nobody would hand that shell back. The host must therefore also be the nearest shell around the hosted one (final review, I2).

### 4.2 The hosted shell

`_hosted` is computed in `didChangeDependencies`, after the existing `ModalRoute.of` (`:364`), so it is recomputed whenever the route changes or the shell moves:

```dart
  // In another shell's body on the same route: that shell answers back for
  // this one (VK-776). Set in [didChangeDependencies].
  bool _hosted = false;
```

```dart
    _routeCurrent = route?.isCurrent ?? true;
    // VK-776: with no navigator between, this shell's PopScope would sit on
    // the host's route, a second voice beside the host's walk. Only the
    // shell right around this one walks it: in another slot of a nested
    // shell (its sidebar header), the nearest body is an outer one's.
    final host = context
        .dependOnInheritedWidgetOfExactType<_ShellBody>()
        ?.shell;
    final hosted =
        host != null &&
        identical(host._route, route) &&
        identical(context.findAncestorStateOfType<_LiquidShellState>(), host);
    // The host learns of a shell built after its last walk (VK-776).
    if (hosted && !_hosted) host._scheduleBranchScan();
    _hosted = hosted;
```

A shell is hosted when three things hold: it has a nearest marker, the marker's shell is on its route, and that shell is also the nearest shell around it (§4.1). The host's `didChangeDependencies` runs before its body builds, so `host._route` is current. With a navigator between, the two routes differ and the shell is not hosted: it keeps today's `PopScope` on the tab's root route (the VK-774 layout). The ancestor lookup runs only here and adds no dependency.

When a shell becomes hosted, it asks its host for a walk (`_scheduleBranchScan`). The host's walks otherwise run only on its own triggers (a new shell, a new selection, a moved shell), on a `NavigationNotification` from its body, or when a known branch changes its on-screen state. A nested shell that is built after the host's last walk and has no tab navigators sends none of these: for example, a loader's result, or a re-keyed subtree. The host would never read that shell's search or overlay claim, and on an Android root shell back would leave the app with the search open (final review, I1).

`_backScope` (`:868-882`) keeps the same widget in every state, so a change of `_hosted` rebuilds nothing below it:

```dart
    return PopScope(
      canPop: _hosted || !claimsBack,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_hosted) handleBack();
      },
      child: child,
    );
```

`claimsBack` and `handleBack()` (the `NestedShellBack` side, `:884-896`) do not change: the host keeps reading the hosted shell's claim every frame and calls its `handleBack()`. The doc comment of `_backScope` gains one paragraph that says the hosted shell steps aside.

### 4.3 Why one change fixes the four bugs

| Bug | Before | With §4 |
|---|---|---|
| Double ask (S1, S1b, S1n, S6) | the outer delegates, and the inner's own callback runs too | only the outer's callback runs; it delegates once |
| Three shells (S10) | three callbacks | the outermost delegates to the middle, which delegates to the innermost: one `maybePop` |
| Hidden inner (S3, S5, S9) | the inner's `PopScope` blocks the outer route and pops the hidden page | the hosted inner never blocks; the outer's walk marks it `onScreen: false` (`_shows`, `branch_navigators.dart:57-66`; `isOnScreenUnder`), so the outer does not count it |
| Two actors (S4, S9) | the outer closes its sidebar or ends its search, and the inner pops its page | the outer acts in its own order and stops there |

### 4.4 Checks against the back rules on main

| Rule (VK-567, VK-593, VK-680, VK-774) | With §4 |
|---|---|
| Android: a root shell claims back only while something can pop, so the app can be left at the root | the outer's `PopScope` alone decides; it blocks while the on-screen nested shell claims back (S6) and not for a hidden one (S5: no claim, `SystemNavigator.pop`) |
| The iOS edge swipe falls to the tab's page while the shell's route is blocked | the outer blocks for the on-screen nested shell, so the swipe still pops the nested page (S7) |
| The onstage walk (VK-593, VK-680) is the one source of "on screen" | unchanged and now also the only source for a hosted shell |
| A `NavigatorPopHandler` with a callback answers back for its navigator (VK-593) | unchanged with a navigator between (S11 locks the route check). An app handler put directly around a same-route nested shell (no navigator) makes the outer return (`handled`), and the hosted shell steps aside: the app's callback answers, as the rule says (§9) |
| `NestedShellBack` (VK-774): the outer hands back to the nested shell | unchanged; the nested shell's order (sidebar, search, page) holds (S8) |
| VK-593's lockers (`pushed_shell_back_test.dart`, 87 tests) | all green; the lines they lock are not touched |
| go_router (`StatefulShellRoute`, `ShellRoute`) | a navigator is always between: not hosted, no change |

### 4.5 Rejected options

- **A. The item's suggested fix: the walk skips a same-route nested shell** (`if (!inside) return;` before `found.add`, `branch_navigators.dart:168-176`). It fixes only the double ask and leaves the hidden-shell bugs (S3, S5, S9) and the two-actor order (S4): their fix needs the outer walk to own the nested shell again. Mutation M4 (§7.3) runs A on top of this design and shows the walk must keep recording the hosted shell.
- **C. A per-back "already handled" token shared by the shells on a route.** The result depends on the order the route calls its `PopScope`s (registration order), and S4 stays wrong whenever the inner runs first.
- **`findAncestorStateOfType<_LiquidShellState>()`** (the probe's lookup): it also matches a shell outside the host's body, which the host's walk does not cover.

## 5. Design: VK-779, the Row is never narrower than its fixed parts

### 5.1 The box

The `Row` under the field's `Opacity` (`search_chrome.dart:105-150`) goes inside an unconditional `ConstraintsTransformBox` (Flutter `widgets/basic.dart`, the box behind `UnconstrainedBox`):

```dart
                  child: Opacity(
                    opacity: idle ? 0 : 1,
                    // VK-779: never narrower than its fixed parts. The
                    // compact landscape ⌕ is 44 wide, and the first frame
                    // out of idle paints the Row there; clipped, it shows
                    // its leading edge. Layout only, in every phase: the
                    // field is never rebuilt.
                    child: ConstraintsTransformBox(
                      constraintsTransform: _atLeastFixedParts,
                      alignment: AlignmentDirectional.centerStart,
                      clipBehavior: Clip.hardEdge,
                      child: Row(
                        children: [
                          const SizedBox(width: _fieldInset),
                          Icon(
                            Icons.search,
                            size: _fieldIcon,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: _fieldIconGap),
                          // … the Expanded TextField and the trailing part
                          // as today; the trailing SizedBox is _fieldInset.
                        ],
                      ),
                    ),
                  ),
```

```dart
// The field Row's fixed parts: the leading inset, the search icon, its gap
// and the trailing inset, 56 in all. With the regular field's inline ×
// (an IconButton, at least 48) it needs 90; that field spans the body, so
// it is never that narrow.
const double _fieldInset = 14;
const double _fieldIcon = 20;
const double _fieldIconGap = 8;
const double _fieldFixedWidth =
    _fieldInset + _fieldIcon + _fieldIconGap + _fieldInset;

/// The field Row's constraints: at least its fixed parts wide.
BoxConstraints _atLeastFixedParts(BoxConstraints constraints) =>
    constraints.maxWidth < _fieldFixedWidth
    ? constraints.copyWith(maxWidth: _fieldFixedWidth)
    : constraints;
```

- **At 44** the box gets tight 44; the Row gets 44 to 56 and, as a `Row` takes its maximum, lays out at 56 with its children exactly fitting (the `TextField` at 0). The box stays 44 and clips: a clipping `RenderConstraintsTransformBox` paints no overflow indicator (Flutter 3.44.6 `rendering/shifted_box.dart:960-995`). `AlignmentDirectional.centerStart` keeps the leading inset and the icon where they are in the grown field: in LTR the cut is the trailing 12, in RTL the left 12.
- **At 56 or more** the constraints pass unchanged, the child is as large as the box, and the box paints its child as before (`!_isOverflowing`). The `TextField` spans the field minus 56, as today.
- Raising `maxWidth` alone is enough, and it can never produce constraints that are not normalized ("Quyết định phát sinh" 10).
- The named constants are used both by the Row and by the floor, so the floor cannot drift from the Row.

### 5.2 The IME rule (P3b spec §9.4, `docs/specs/2026-10-10-p3b-search-tab-design.md:627-636`, `:743`)

- The chain above the `TextField` is the same in every phase and at every width: the box is added once in code, never per phase, and no `if` depends on width or phase.
- No per-frame rebuild during the morph: the box acts in layout only (no `LayoutBuilder`).
- Nothing writes to `editing`.

The landscape identity test (§7.2) pins it: the `TextField`'s `Element` is the same object from idle through selected and active back to selected. Mutation V6 (§7.3) shows that a phase-dependent box would break it.

### 5.3 Rejected options

- **Keep the Row invisible until it fits.** A `LayoutBuilder` rebuilds the field every morph frame (it breaks "never rebuilt"); a one-frame opacity delay depends on timing and shows the field's content later than native does.
- **Change the geometry** (start the morph from a 56-wide rect, or a 56-point landscape ⌕). It leaves the measured native 44-point landscape bar and changes idle visibly.
- **`Flexible` spacers.** Flex sharing would shrink the `TextField`'s share at every width.

## 6. Pinned names

| What | Name |
|---|---|
| Host marker (`liquid_shell.dart`, private) | `class _ShellBody extends InheritedWidget`, field `final _LiquidShellState shell` |
| Flag (`_LiquidShellState`, private) | `bool _hosted` |
| Row floor (`search_chrome.dart`, private) | `_fieldInset`, `_fieldIcon`, `_fieldIconGap`, `_fieldFixedWidth`; `BoxConstraints _atLeastFixedParts(BoxConstraints constraints)` |
| Test helpers (`pushed_shell_back_test.dart`) | `_subTabs(String label, {tabs, search, key, initialIndex, bare})`; `class _SameRoute`; `_pushForm(tester, navigator, title)` → `int Function()`; `class _AndroidBack {claims, exits}`; `_onAndroid(tester, body)`; `_Pushed.pump(bare:)` |
| VK-776 tests | in the `VK-593 (<mode>): back finds the right navigator` group, each name starting `VK-776:`; and `Android, a root shell, a nested shell in a hidden tab with a page: …`, `Android, a root shell, a nested shell shown with an unsaved form: …` |
| VK-779 group (`search_morph_test.dart`) | `VK-779: compact landscape, idle → selected` |
| VK-702 test (renamed) | `landscape search row, left inset: the ⌕ keeps the right edge, and a drag dropped on it opens the search` |

## 7. Test strategy

All tests are Dart widget tests on the VM (`flutter_test`, Flutter 3.44.6 through fvm). `PopScope`, `ModalRoute`, Android's `setFrameworkHandlesBack` and `SystemNavigator.pop`, and the overflow report are framework behaviour, so no simulator or device is needed.

### 7.1 VK-776, red first (`test/widget/pushed_shell_back_test.dart`)

A test layout `_SameRoute`: an outer `_Pushed` shell (both modes: `_Mode.native` through `FakeNativePlatform`, `_Mode.flutter`) whose tab 1 page is an inner `TestShell(nativeChrome: off)` with no navigator between. `_Pushed.branch` always wraps a tab in a navigator, so `_Pushed.pump` gains a `bare` hook that returns a tab's page as is. The inner shell's tabs are navigators (`_subTabs`, also used by the existing `_Inner`). A refusing page `_pushForm` counts its refusals and shows a dialog for each.

| Test (mode) | At `e0bbf62` | Why |
|---|---|---|
| a refusing form in the inner tab asks once per back (both) | red: `Expected: <1> Actual: <2>` | the outer delegates and the inner's own callback runs |
| three shells on one route: the form asks once (both) | red: `Expected: <1> Actual: <3>` | one callback per shell |
| the inner shell in a hidden tab, a page in its tab: back pops the shell's route (both) | red: `Expected: true Actual: <false>` | the hidden inner's `PopScope` blocks the route and pops the hidden page |
| the outer search active, the inner hidden with a page: back ends the outer search only (both) | red: `Found 0 widgets with text "Hidden page: 0"` | both callbacks act |
| iPad, the outer overlay sidebar open over the inner shell with a page: back closes the sidebar only (Flutter) | red: `Found 0 widgets with text "Deep page: 0"` | both callbacks act |
| Android root shell, the inner hidden with a page: no claim at the shown root, back leaves the app (`SystemNavigator.pop`), the hidden page stays | red: `Expected: false Actual: <true>` (the claim) | the hidden inner blocks the root route |
| Android root shell, the inner shown with a refusing form: one back asks once | red: `Expected: <1> Actual: <2>` | as the first row |
| the edge swipe on the inner page pops it, not the shell (both) | green, a guard | red under M4 |
| the inner search active over a page: back ends it, then pops the page (both) | green, a guard | red under M4 |
| the VK-774 layout inside the app's `NavigatorPopHandler`, inner search active at its root: back ends it (both) | green, a guard | red under M3 |

Natively, the outer-search test checks the shell's request to UIKit (`searchActives.last` is `false`), because the fake never reports the end. The iPad overlay test runs in Flutter mode only: the fake's native state is compact, so the native outer shell has no overlay sidebar.

### 7.2 VK-779, red first

**`test/widget/search_morph_test.dart`**, a new group. Compact landscape (`kPhoneLandscape`, 932×430, padding bottom 21), Flutter chrome (no native platform installed), Home · Library · Search; `pumpShell(platform: defaultTargetPlatform)` so the theme follows the variant.

| Test | Targets | At `e0bbf62` | Note |
|---|---|---|---|
| a tap on the ⌕ | `TargetPlatformVariant({iOS, android})` | red: `Expected: null Actual: FlutterError:<A RenderFlex overflowed by 12 pixels on the right.>` | also asserts the field is selected and the `TextField` is the field's width minus 56 |
| a lens drag dropped on the ⌕ | iOS, Android | red, as above | |
| the app selects the search tab | iOS, Android | red, as above | |
| the first frame shows the leading edge (LTR) | the test default (Android) | red: the overflow | the icon's left is the field's left + 14 at the morph's first frame, the field still 44 wide |
| the first frame shows the leading edge (RTL) | the test default (Android) | red: `Expected: <51.0> Actual: <63.0>` (and the overflow) | the icon's right is the field's right − 14 |
| the field is one element from idle to active and back | the test default (Android) | red: the overflow fails it | its own claim is shown by V6 |

**`test/widget/shell_chrome_test.dart`**: the VK-702 left-inset test (`:1362-1386`) drops instead of cancelling, then asserts no exception and the search tab selected. Red today: the overflow.

### 7.3 Mutation checks (run, pasted into the task reports, never committed)

| Mutation | Must go red |
|---|---|
| M1: `canPop: _hosted \|\| !claimsBack` → `canPop: !claimsBack` | the hidden-inner test (both modes) and the Android hidden-inner test |
| M2: `if (!didPop && !_hosted)` → `if (!didPop)` | the form, three-shell and outer-search tests (both modes), the iPad overlay test, the Android form test |
| M3: `_hosted = host != null && identical(host._route, route)` → `_hosted = host != null` | the `NavigatorPopHandler` guard (both modes) |
| M4: option A on top of the fix (`branch_navigators.dart`: `if (!inside) return;` before `found.add` of a nested shell) | the form, three-shell, edge swipe and nested-search tests (both modes), the iPad overlay test, both Android tests |
| V2: `clipBehavior: Clip.hardEdge` → `Clip.none` | every VK-779 test and the VK-702 test (`A RenderConstraintsTransformBox overflowed by 12 pixels`) |
| V3a: `AlignmentDirectional.centerStart` → `Alignment.center` | both first-frame tests |
| V3b: → `Alignment.centerLeft` | the RTL first-frame test |
| V4: drop the condition of `_atLeastFixedParts` (always `copyWith(maxWidth: 56)`) | broadly red: `BoxConstraints(62.0<=w<=56.0, …; NOT NORMALIZED)` in portrait |
| V5: `_atLeastFixedParts` returns its input | every VK-779 test and the VK-702 test (`A RenderFlex overflowed by 12 pixels`) |
| V6: the box keyed by the phase (`key: ValueKey(idle)`) | the landscape identity test (`Actual: <false>`) |

### 7.4 Unchanged, still green

- `pushed_shell_back_test.dart`'s 87 tests at `e0bbf62` (VK-567, VK-593, VK-680, VK-774, VK-775), the existing Android test now through the shared `_onAndroid` helper.
- The search suites, including the VK-699 mid-composition tests (`native_search_test.dart`) and the portrait "never rebuilt" test (`search_fallback_test.dart:274-283`).
- The example goldens (`example/test/goldens/search_test.dart`, `form_factors_test.dart` and the rest): `make goldens`, macOS with Flutter 3.44.6.

## 8. Docs and CHANGELOG wording

**`liquid_shell/doc/router_integration.md`:**
- the "selected tab's navigator" bullet (`:68-72`) ends: "Neither does a page in a shell nested in another tab.";
- the nested-shell bullet (`:93-96`): "with or without a navigator between", and "The outer shell asks it only while it is on screen, after the outer shell's own overlay sidebar and search, so one back does one thing: a refusing page's `PopScope` is asked once."

`doc/native_chrome.md:123` and the README's nested-shell note keep their `nativeChrome: off` rule; nothing else changes. The public-docs check (`tool/check_public_docs.sh`) holds: no internal reference in `doc/` or in a `///` comment.

**`liquid_shell/CHANGELOG.md`** (Q2): a new `## 0.1.0-dev.10` heading at the top of the file, with:

```markdown
## 0.1.0-dev.10

- **Fix (VK-776).** A shell nested in another shell's body with no
  navigator between (a tab's page that is itself a `LiquidShell`) no
  longer answers back beside the outer shell. One back asked a page's
  `PopScope` twice (an unsaved form showed two dialogs; with three shells,
  three). A nested shell in a tab that was not shown still held back: back
  popped a page the user could not see, and at a root shell on Android the
  app could not be left. With the outer shell's overlay sidebar open or
  its search active, one back also popped the nested shell's page. The
  outer shell now asks the nested one in its own order, and only while it
  is on screen. With a navigator between (go_router's `StatefulShellRoute`
  and `ShellRoute` always put one there) nothing changes.
- **Fix (VK-779).** Compact landscape with the Flutter chrome: selecting
  the search tab from idle (a tap on the ⌕, a lens drag dropped on it, or
  the app) no longer reports "A RenderFlex overflowed by 12 pixels" in
  debug builds for the first frame of the morph. The field's row keeps the
  width of its fixed parts and is clipped while it grows out of the
  44-point ⌕. Release builds showed nothing wrong.
```

No other package changes, so no other CHANGELOG. No pubspec version changes (only branch R bumps).

## 9. Risks

| Risk | Handling |
|---|---|
| A hosted shell's new claim (its search just activated, a page just pushed) blocks the route one frame later, through the host's per-frame check (`liquid_shell.dart:811-820`) | The lag VK-774 accepted for the navigator-between case (`docs/specs/2026-10-23-back-followups-design.md` §6). A back in that frame acts as if the nested shell had nothing |
| An app `NavigatorPopHandler` with a callback put directly around a same-route nested shell (no navigator): the hosted shell steps aside and the app's callback answers alone | The existing rule ("the app answers back for its navigator", `doc/router_integration.md:77-82`). Before, both acted. Not tested: no known app does it ("Quyết định phát sinh" 8) |
| `_hosted` reads `host._route`, set in the host's own `didChangeDependencies` | A parent's `didChangeDependencies` runs before its children build. A move under another route changes the nested shell's `ModalRoute` dependency too, so both recompute |
| A shell on the host's route but outside its body (a sidebar header, a chrome builder slot) keeps today's two voices | Out of scope: the host's walk does not cover it, so stepping aside there would lose its claims. That holds in a nested shell's sidebar header too, through the nearest-shell check (§4.1) |
| A hosted shell built after the host's last walk, with no tab navigators (a loader's result) | It asks the host for a walk when it becomes hosted (§4.2) |
| The hidden-inner fix rests on the walk's on-screen check; Flutter 3.47's `IndexedStack` drops `Visibility` | The walk reads `RenderIndexedStack` (`branch_navigators.dart:60-62`), already 3.47-ready (VK-700) |
| VK-779: the 56 floor does not cover the regular field's inline × (at least 90 with it) | That field spans the body width minus 40; the comment says so |
| VK-779: after a first clip, the box keeps a clip-layer handle | Flutter's own design (`LayerHandle`); no paint cost while not overflowing |
| Merge with the other wave-2 branches | The `CHANGELOG.md` top: R adds `## 0.1.0-dev.9`, F adds the same `## 0.1.0-dev.10`. The later merge keeps one `## 0.1.0-dev.10` with every bullet, above `## 0.1.0-dev.9`. F (VK-778) edits `liquid_shell.dart` around the overlay sidebar's close and the regular field's inset: a textual conflict only if it touches `_backScope`, `_bodySubtree`, `didChangeDependencies` or the field's `Row`. P3b-2's every-tab branch starts after S merges (Q12) |

## 10. Process

- **Tasks, in order** (the plan): Task 1, VK-776 (tests, fix, docs, CHANGELOG heading); Task 2, VK-779 (tests, fix, the VK-702 test, CHANGELOG bullet). They touch different files except `CHANGELOG.md`; Task 2's bullet follows Task 1's.
- **Commits:** `fix(shell): … (VK-776)` and `fix(shell): … (VK-779)`, each ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Run `bash .githooks/pre-commit` by hand before each commit. Never `--no-verify`, never a git or flutter config change.
- `make verify` before the PR. One PR for the branch (Q1). No push, no remote change in the tasks.
- Plane: VK-776's priority goes to medium and VK-779's description is widened to "any idle → search selected in compact landscape with the Flutter chrome (tap, drop, app selection)" (Q8); the controller does it, not the tasks.

## Quyết định của chủ sản phẩm (đã chốt)

Chủ sản phẩm đã trả lời "Ok hết" ngày 2026-10-28 (Q1–Q18 của wave 2), nên các mục dưới đây đã được chốt.

| Q# | Câu hỏi | Đã chốt |
|---|---|---|
| Q1 | Nhánh và PR | Nhánh S `VK-776-back-overflow` gồm VK-776 và VK-779, một spec, một plan, một PR, từ `main` `e0bbf62` |
| Q2 | CHANGELOG | Mục của S ghi dưới tiêu đề mới `## 0.1.0-dev.10` ở đầu CHANGELOG của mỗi gói S sửa; không nâng phiên bản |
| Q7 | Cách sửa VK-776 | Sửa gốc (~10 dòng): shell trong đứng sang một bên khi một shell ngoài cùng route với nó; shell ngoài chuyển back theo thứ tự của mình. Sửa luôn (a) shell trong ở tab ẩn chặn back Android (không thoát được app) và (b) một lần back làm việc ở cả hai shell |
| Q8 | Ưu tiên VK-776, phạm vi và cách sửa VK-779 | VK-776 lên medium. Mô tả VK-779 mở rộng: mọi lần idle → chọn tab tìm ở màn ngang compact với chrome Flutter (chạm, thả, app chọn) đều tràn. Sửa: `ConstraintsTransformBox` quanh `Row` ở `search_chrome.dart:107`, rộng ít nhất 56, cắt phần thừa; không bao giờ dựng lại hay ghi vào ô |

### Quyết định phát sinh

Bảng trên không nói tới những điểm dưới đây. Spec chọn như sau, chủ sản phẩm có thể đổi:

1. **Shell trong tìm shell chủ qua một `InheritedWidget` riêng (`_ShellBody`) đặt trong body của shell chủ**, không qua `findAncestorStateOfType` như bản thăm dò. Lý do: chỉ shell nằm trong body (phần shell chủ duyệt) mới được đứng sang một bên; shell ở chỗ khác (header sidebar, ô của `chromeBuilder`) giữ `PopScope` của nó. Dùng `dependOnInheritedWidgetOfExactType`, `updateShouldNotify` trả `false` (shell chủ không bao giờ đổi). Sau review cuối (I2), có thêm một điều kiện: shell chủ cũng phải là shell gần nhất bao quanh (`findAncestorStateOfType`). Lý do: một shell nằm trong header sidebar của một shell trong (shell trong này đã có chủ) chỉ thấy marker của shell ngoài cùng (§4.1).
2. **Không sửa phép duyệt cây (`branch_navigators.dart`).** Đột biến M4 (cách A đặt lên trên bản sửa) cho thấy phép duyệt phải tiếp tục ghi nhận shell trong: test vuốt cạnh, test ô tìm của shell trong và hai test Android đỏ.
3. **Chỗ đặt test VK-776:** trong nhóm VK-593 của `pushed_shell_back_test.dart`, chạy cả hai chế độ; hai test Android đặt sau test Android có sẵn. Test Android có sẵn chuyển sang hàm chung `_onAndroid` (ba chỗ dùng). Hàm dựng shell của `_Inner` tách thành `_subTabs`, dùng chung cho `_Inner`, `_SameRoute` và test ba shell.
4. **Gộp S1 và S1b thành một test** (trang từ chối vừa đếm vừa hiện hộp thoại); S1n của bản thăm dò là lần chạy chế độ native của test đó. Không thêm S2 (hai trang thường): `maybePop` tự kiểm lại trang trên cùng, vô hại, và test có sẵn đã phủ việc pop thường.
5. **Test sidebar overlay của shell ngoài (S4) chỉ chạy chế độ Flutter:** trạng thái native giả là compact, nên shell ngoài native không có sidebar overlay.
6. **Ở chế độ native, test ô tìm của shell ngoài kiểm yêu cầu gửi cho UIKit** (`searchActives.last` là `false`), vì native giả không bao giờ báo kết thúc.
7. **Test Android shell trong bị ẩn (S5) kiểm thêm** rằng app thoát (`SystemNavigator.pop` một lần) và trang ẩn vẫn còn; test Android trang từ chối (S6) kiểm rằng app không thoát.
8. **Không có test cho `NavigatorPopHandler` của app đặt thẳng quanh một shell trong cùng route** (không có `Navigator`): quy tắc có sẵn "app trả lời back" áp dụng; ghi ở mục Rủi ro.
9. **Test VK-779 nằm trong một nhóm mới của `search_morph_test.dart`:** ba cách vào (chạm, thả, app chọn) chạy trên `TargetPlatformVariant({iOS, android})`, `pumpShell(platform: defaultTargetPlatform)`. Thêm test khung hình đầu cho LTR và RTL (chốt `AlignmentDirectional.centerStart`) và test cùng một `Element` ở màn ngang (idle → selected → active → selected).
10. **Các phần cố định của `Row` thành hằng có tên** (`_fieldInset`, `_fieldIcon`, `_fieldIconGap`, `_fieldFixedWidth`), dùng cho cả `Row` và mức sàn, để mức sàn không lệch khỏi `Row`. Hàm biến đổi chỉ nâng `maxWidth`: ràng buộc vào là chặt ở 44, nâng `maxWidth` là đủ và không bao giờ sinh ràng buộc không chuẩn hoá.
11. **Test cùng một `Element` ở màn ngang hôm nay cũng đỏ** (lỗi tràn làm nó hỏng); điều nó thực sự chốt được chứng minh bằng đột biến V6 (hộp gắn key theo phase).
12. **Test VK-702 đổi tên** ("a drag dropped on it opens the search"): thả thay vì huỷ, rồi kiểm không có lỗi và tab tìm được chọn.
13. **CHANGELOG:** mỗi bản sửa một dòng "Fix" dưới `## 0.1.0-dev.10` mới ở đầu `liquid_shell/CHANGELOG.md`; Task 1 thêm tiêu đề, Task 2 thêm dòng của nó ngay sau dòng của Task 1.
14. **Tài liệu:** sửa hai gạch đầu dòng của `doc/router_integration.md`; `doc/native_chrome.md` và README giữ nguyên (quy tắc `nativeChrome: off` cho shell lồng nhau vẫn đúng).
15. **Thứ tự task:** VK-776 trước, VK-779 sau. Hai task sửa các file khác nhau, chỉ chung `CHANGELOG.md`.
