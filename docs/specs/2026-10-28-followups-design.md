# liquid_shell VK-778: follow-ups of the VK-702 review (with VK-777 and VK-700)

- **Plane:** VK-778 (the main item), VK-777, VK-700 (its CI part only; VK-700 stays open until 0.1.0). Parent VK-780.
- **Date:** 2026-10-28
- **Status:** approved. The owner answered Q1–Q18 of backlog wave 2 with "Ok hết" on 2026-10-28; this branch carries Q9, Q10, Q11 and the CHANGELOG rule of Q2 (table at the end). Plan: `docs/plans/2026-10-28-followups.md`. The choices this spec had to add are listed in "Quyết định phát sinh", after the table.
- **Branch:** `VK-778-followups`, from `main` at `e0bbf62`.
- **Kind of change:**
  - Dart in `liquid_shell`: `lib/src/shell/liquid_shell.dart` (VK-778 (1), (3), and the comment of (5)) and `lib/src/glass/signals_controller.dart` (the comment of (4)).
  - Tests: widget tests in `liquid_shell/test/widget/shell_chrome_test.dart`; one assertion in the example's `RunnerTests.swift` (VK-777).
  - CI and tooling (VK-700): the `goldens` job of `.github/workflows/ci.yaml`, two `Makefile` targets, `CONTRIBUTING.md`.
  - `liquid_shell/CHANGELOG.md`: a new `## 0.1.0-dev.10` heading with two bullets.
  - No Swift production code, no Pigeon, no platform-interface change, no public API change, no other package, no version bump, no golden image change.
- **Sources:**
  - The two wave-2 evidence reports of 2026-10-28 at `e0bbf62`, kept with the Plane items: the follow-ups report (VK-777; VK-778 points (1) to (5), probes P1, P2, P2b, P2c and the inset probe) and the goldens report (VK-700: runs on Flutter 3.44.6 and 3.47.7, the diff anatomy, options a to e).
  - The merged VK-702 spec, `docs/specs/2026-10-24-api-fixes-design.md` §3.1.2, §4.4, §4.5 and §8, where the five points of VK-778 come from.
  - The code at `e0bbf62`. Every file:line below was read again there.
  - **Plan check** (2026-10-28, in this worktree; every change was then removed). The plan's test and production code ran here:
    - every red-first test of §10 was red at `e0bbf62` for the reason given there, and green with the plan's code; every mutation of §10.2 turned the named tests red;
    - the whole `liquid_shell` suite passed with Tasks 1 to 3 applied (`+1301`, 11 more than at `e0bbf62`); `make goldens` passed with Task 2 applied (`+36`, `+27`): no image moved;
    - XCTest, on two iPhone 17 simulators created for the check and then deleted: the scope-bar test with the new assertion passed on iOS 26.5 and iOS 27.0; the product mutation the evidence proposed stayed green (§7.2); the threshold mutation was red on 26.5;
    - the CI check of §8.3 was red on today's `ci.yaml` and green with the change; `make goldens-plain`, `make goldens-liquid` and `make test-impeller` passed on 3.44.6 (`+36`, `+27`, `+19`);
    - `make verify` passed with every task applied.

> **Tóm tắt (cho chủ sản phẩm).**
> - **VK-778 (1): trả lại focus khi đóng sidebar overlay.** Khi sidebar dạng overlay mở (iPad dọc), trang và thanh tab trên cùng không nhận focus bàn phím (VK-702), nên thứ đang giữ focus bị mất. Nay khi đóng bằng Escape, chạm nền mờ, nút Hide hoặc back, focus quay về đúng chỗ cũ (một nút của trang, một ô nhập chữ, nút mở sidebar).
>   - Chọn một mục khác trong sidebar, hoặc app tự đổi trang khi sidebar đang mở (nút ở đầu/cuối sidebar, deep link), thì không trả lại (trang đã đổi). Ô tìm của shell không bao giờ được trả focus kiểu này: focus vào ô tìm đang rảnh là bắt đầu tìm, nên lượt tìm đã kết thúc dưới overlay (Escape trong ô, hoặc Tab sang sidebar) không tự mở lại khi đóng.
>   - Chỉ chuyển focus: không dựng lại ô nhập, không ghi gì vào ô (luật bộ gõ tiếng Việt). Có test riêng cho ô nhập chữ.
>   - Một nút đã rời khỏi cây trong lúc sidebar mở thì bỏ qua; nếu không, nó sẽ giành focus khi xuất hiện lại.
>   - Ghép với nhánh S (VK-776 sửa back giữa hai shell lồng nhau): thay đổi nằm trong setter hiển thị sidebar, chỉ chạy lúc chuyển từ hiện sang ẩn, nên mỗi lần đóng chỉ trả focus một lần, dù ai gọi `handleBack`. Hai nhánh không sửa chung dòng nào.
> - **VK-778 (3): ô tìm dạng regular tránh tai thỏ.** Khi app đặt breakpoint cho điện thoại nằm ngang dùng bố cục regular, ô tìm trên cùng nằm dưới tai thỏ. Nay ô tìm tránh vùng an toàn hai bên như các thanh tab. Cạnh sidebar tiled chỉ cộng inset phía cuối (sidebar đã tự tránh phía đầu). Golden không đổi.
> - **VK-778 (4)(5):** hai sửa chỉ ở comment, một commit.
> - **VK-777:** một assert XCTest: trên iPhone, vị trí ô tìm native là `inline` dưới iOS 27 và `stacked` từ iOS 27. Đã chạy xanh trên simulator iOS 26.5 và 27.0. Cách làm đỏ mà bằng chứng gợi ý (ép `.stacked` trong `SearchMath.style`) vẫn xanh: trên iPhone UIKit tự chọn vị trí và bỏ qua yêu cầu của mình. Vì vậy assert được chứng minh đỏ bằng cách đổi tạm ngưỡng phiên bản. CI không thêm trục runtime.
> - **VK-700:** nhánh CI Flutter stable chạy golden thường và shader probe (hai thứ này quyết định màu của nhánh); golden liquid ở đó chỉ để tham khảo (bước đó được phép đỏ, kèm một cảnh báo). Nhánh vẫn không chặn merge. Nhánh 3.44.x không đổi: mọi golden vẫn chặn. Thêm `make goldens-plain` và `make goldens-liquid`. VK-700 vẫn mở tới 0.1.0 (lúc đó chuyển mốc lên 3.47 và tạo lại 7 ảnh).
> - **Bỏ, có lý do (controller cập nhật Plane):** VK-778 (2) không tái hiện được (xoay máy thì sidebar về ẩn, mở lại là mount mới, autofocus chạy); nửa "sidebar overlay" của (3) đã đúng (biểu tượng đầu ở x = 87).
> - **CHANGELOG:** hai dòng "Fix" dưới tiêu đề mới `## 0.1.0-dev.10` của `liquid_shell`. Không nâng phiên bản.

---

## 1. Goal

1. **VK-778 (1).** When the Flutter overlay sidebar closes by Escape, by a tap on its barrier, by its Hide button or by back, the node that held primary focus when it opened has primary focus again. Not after another destination is selected while it is open, in the sidebar or by the app.
2. **VK-778 (3).** The regular search field (the search tab selected or active, top bar or sidebar layout) lies inside the horizontal safe area. Beside a tiled sidebar only the trailing inset is added.
3. **VK-778 (4), (5).** Two comments say what the code does. No behaviour change.
4. **VK-777.** On an iPhone, the scope-bar XCTest asserts the placement UIKit realises: `inline` below iOS 27, `stacked` from iOS 27.
5. **VK-700.** The stable CI leg is green when the plain goldens and the shader probes pass; its liquid goldens only inform. The 3.44.x leg does not change.

**Success:** the tests of §10 are red before the change for the reason given there and green after it. The mutation checks turn the named tests red. The simulator runs of §10.4 pass. `make verify` is green.

## 2. Scope

### 2.1 In

- `_LiquidShellState` (`liquid_shell.dart`): one field, two private methods and one line in `_select` (§4); the regular field's horizontal position (§5); one comment moved (§6).
- `LiquidSignalsController.acquire()` (`signals_controller.dart`): one comment (§6).
- `testTheScopeBarShowsOnlyWhileTheSearchIsActive` (`RunnerTests.swift`): one assertion (§7).
- `Makefile`: `goldens-plain` and `goldens-liquid`; `goldens` runs both (§8.1). The `goldens` job of `ci.yaml` (§8.2). `CONTRIBUTING.md` (§8.4).
- Tests: §10. CHANGELOG: §11.

### 2.2 Non-goals

- **VK-778 (2), dropped** (Q9). "Escape after rotating an iPad (tiled → overlay): autofocus does not run again" does not reproduce. Probes P2 and P2b at `e0bbf62`: `sidebarVisibleFor` (`shell_layout.dart:93-100`) resets visibility on every presentation change (tiled shows, overlay hides), so the overlay's sidebar is always mounted fresh when it opens and its `Focus(autofocus: modal)` (`liquid_shell.dart:1750-1752`) runs.
  - The adjacent hole the evidence found (P2c) is a note, not a task: if focus is lost while the overlay is open (a click on a non-focusable area), Escape does nothing, because the shell's key handler (`:1794-1806`) only hears keys while something inside the shell holds focus. The barrier and Hide still close it.
- **The overlay-sidebar half of VK-778 (3), dropped** (Q9). The sidebar already clears the inset. Probe at `e0bbf62` (tablet portrait, 59 pt insets): the panel is `Rect(0, 0, 300, 1194)` and its first icon starts at x = 87 = 59 + 16 + 12. `LiquidSidebar` reads `MediaQuery.paddingOf` (`lib/src/chrome/sidebar.dart:66`), pinned by `sidebar_test.dart:262-280` ("rows start after the safe area on the leading side", LTR and RTL). The panel's background under the notch is by design.
- Focus for the native (UIKit) sidebar: its keyboard handling is UIKit's (VK-702 §8). `_applySidebarVisible` returns before the new code when native chrome is engaged.
- Escape in an active search field under the overlay keeps ending the search, not the overlay (VK-702 §8, unchanged).
- Giving focus back after a destination is chosen (Q9).
- A runtime axis on the `ios-unit` CI job (Q10). A run on iOS 27.1.
- Moving the Flutter pin, the package floor or the golden reference to 3.47; regenerating the 7 dark images; per-version golden sets; a dark-only tolerance (Q11: the move happens at 0.1.0; the evidence rejects options b and c).
- The `checks` job's stable leg: not red in the evidence, not touched.
- A version bump. A device check.

## 3. What the evidence shows (file:line at `e0bbf62`)

### 3.1 VK-778 (1): focus is not given back

`liquid_shell/lib/src/shell/liquid_shell.dart`:

| Line | What |
|---|---|
| 1376 | `final modal = kind == LiquidChromeKind.sidebarOverlay;` |
| 1385 | the body in `ExcludeFocus(excluding: modal, …)` |
| 1682-1683 | the top bar row in `ExcludeFocus(excluding: modal, …)` |
| 1719-1720 | the regular search field: excluded only while `selected`; an active one keeps its focus (VK-774) |
| 1750-1752 | the sidebar in `Focus(autofocus: modal, skipTraversal: true, …)` |
| 1794-1806 | the Escape handler: `_setSidebarVisible(false)` while `modal` |
| 922-923, 925-943 | `_setSidebarVisible` → `_outsideBuild` → `_applySidebarVisible`; native returns at 927-930, compact at 931-939; the transition is 940-942 |
| close paths | Escape 1804; barrier 1735; Hide 1760; back, `handleBack` 888-890; destination chosen, `_select` 989-995 |

- **Probe** (evidence): focus a page node, open the overlay, close it by Escape: the primary focus is then the route's `_ModalScopeState` scope, not the page node. The plan check reproduced it in all four close paths (`Actual: FocusScopeNode:<FocusScopeNode#…(_ModalScopeState<dynamic> Focus Scope [PRIMARY…`).
- **Root cause:** the overlay's `ExcludeFocus` drops the focused node when it opens, and nothing remembers it. On close the sidebar's focused node unmounts, and focus falls to the route's scope.
- **Flutter 3.44.6** (`packages/flutter/lib/src/widgets/focus_manager.dart`):
  - `canRequestFocus` (536) is false while an ancestor excludes focus, and `_doRequestFocus` (1169-1175) then does nothing: a request made in the frame that closes the overlay, before the rebuild lifts `ExcludeFocus`, is lost;
  - `_doRequestFocus` on a node with no parent (1177-1182) is deferred until the node is reparented (1079-1082): a node that left the tree would take focus whenever it came back.
- **The search field:** `ShellSearch._onFocus` (`lib/src/search/shell_search.dart:510-537`) makes the search active when the field gains focus (533-536). Focusing an idle field starts a search.

### 3.2 VK-778 (3): the regular search field ignores the side insets

- `liquid_shell.dart:1703-1725`: `start = bodyStart + kRegularSearchMargin + indent` (1707); `left: rtl ? kRegularSearchMargin : start` and `right: rtl ? start : kRegularSearchMargin` (1713-1714). `kRegularSearchMargin` is 20 (`lib/src/search/search_layout.dart:76`).
- The side insets are already in scope: `sideLeft`, `sideRight` (1314-1315, VK-702 M10). `bodyStart` (1367) is `widget.sidebarWidth` (default 300) when tiled; the tiled sidebar clears the leading inset itself (`sidebar.dart:66`).
- **Probe** (evidence): tablet portrait, 834 wide, insets 59/59, search selected: field `Rect.fromLTRB(20.0, 85.5, 814.0, 129.5)`, outside the safe width 59..775.
- **Plan check**, a landscape phone 932×430 with insets 59/59 (as an iPhone reports them) and custom breakpoints:
  - top bar (`compactHeight: 0`): left 20, right 912 (the safe width is 59..873);
  - tiled (`compactHeight: 0, tiledSidebar: 900`): LTR right 912; RTL left 20.
- **Reachable only through an app's breakpoints:** VK-702's spec lists it as a non-goal (§2.2, "iPad sizes have no side insets").
- **Goldens:** every golden device has zero side insets, so no image can move.

### 3.3 VK-778 (4) and (5): comments

- **(4)** `lib/src/glass/signals_controller.dart:54-83`: when `watchSignals()` throws, the catch calls `_set(LiquidPlatformSignals.none)` (68), which notifies if an earlier stream left another value (`_set`, 97-101; the value is kept after the last release, doc 35-37). `acquire()` runs from `initState` (`liquid_glass.dart:92`, `liquid_lens.dart:71`, `scroll_pocket.dart:41`).
  - Harmless: the only listeners are those widgets' own `ListenableBuilder`s over `liquidGlassChanges()` (`liquid_glass.dart:14-18`), each subscribed in `build`, after its own state's `acquire()`. At `_users == 1` no mounted glass listens.
  - `LiquidSignalsController` is not exported: `lib/liquid_shell.dart` exports only `debugLiquidGlassCanRefractOverride` and `debugResetLiquidGlassSignals` from that file.
  - After a failure `_users` stays counted with no subscription; when the last user releases, the next first `acquire()` calls `watchSignals()` again.
  - Covered by VK-702's M12 test (`test/widget/liquid_glass_test.dart`, "a watchSignals() that throws falls back to no signals, logged once").
- **(5)** `liquid_shell.dart:1285-1290`: the comment `// The device decides, not an app's ThemeData.platform (VK-702).` sits between `bottomGapFor(` and its first named argument.

### 3.4 VK-777: nothing pins the iPhone's placement

- `liquid_shell/example/ios/RunnerTests/RunnerTests.swift:2975-3000`, `testTheScopeBarShowsOnlyWhileTheSearchIsActive`: the branch at 2988 follows `snapshot.placement`. The only placement assertion is the iPad's (2932-2934, `testTheDebugSnapshotDescribesTheSearchTab`). If iOS 26 gave `stacked`, or iOS 27 `inline`, together with the matching geometry, the test would take the other branch and stay green.
- **The iPhone's placement is UIKit's:**
  - `SearchMath.style` asks for `.automatic` on a phone (`liquid_shell_ios/…/SearchMath.swift:45-48`);
  - `applySearchStyle` sets `navigationItem.preferredSearchBarPlacement` (`ShellNavController.swift:236-238`);
  - `debugSnapshot()` reports `navigationItem.searchBarPlacement`, the realised value (`NativeTabsController.swift:873-883`, `""` when there is none);
  - **plan check:** asking for `.stacked` (`SearchMath.swift:46`) or `.integrated` (`ShellNavController.swift:238`) on an iPhone 17, iOS 26.5, still realises `inline`.
- **CI:** `ios-unit` (`.github/workflows/ci.yaml:183-208`) has the matrix `device: [iPad, iPhone]` and takes the newest device on the runner image (`tail -n1`), with no runtime pin. `integration-ios-native` (`:337-426`) has the iOS 26 / iOS 27 axis but runs Dart drives, not `RunnerTests`.
- **Local runtimes:** iOS 26.5, 27.0 and 27.1.

### 3.5 VK-700: the stable leg is red on every run

- `.github/workflows/ci.yaml:427-461`, job `goldens`: matrix `3.44.x` (blocking) and `stable` (`experimental: true`, job-level `continue-on-error`, 431); one step `make goldens` (451); `make test-impeller` (455-456), which on the stable leg also runs after a failure; the failures are uploaded on `failure()` (457-461).
- `Makefile:67-71`: `goldens` runs `flutter test --tags golden`, then `flutter test --enable-impeller --tags liquid_golden`, in `liquid_shell/example`.
- **Tags** (`liquid_shell/example/dart_test.yaml`): `golden` in `test/goldens/cases_test.dart`, `form_factors_test.dart`, `hero_test.dart` and `search_test.dart`; `liquid_golden` in `test/goldens/liquid_test.dart`.
- **Evidence runs:** 3.44.6, `+36` and `+27`, green. 3.47.7: the plain set `+36`, green; the liquid set `+20 -7`, the 7 dark images; the Impeller shader probes 19/19, green. The stable leg is therefore red on every run from its liquid half alone.
- `tool/update_goldens.sh:14-21` refuses any Flutter but 3.44.x. It does not change.

## 4. Design: VK-778 (1), focus comes back when the overlay closes

**Rule.** In the Flutter overlay presentation the shell keeps what held primary focus when the sidebar opens. When the sidebar closes, it lets go of focus at once. After the closing frame the kept node gets focus back, unless the shell's route is no longer current or primary focus has left the scope around the shell, where the close put it. Every close goes through `_setSidebarVisible(false)`: Escape, the barrier, Hide, back, and an app's `LiquidShellScope.setSidebarVisible(false)`. Nothing is given back when another destination is selected while the overlay is open, in the sidebar or by the app.

**Code** (`liquid_shell.dart`, line numbers at `e0bbf62`). Three fields after `_sidebarVisible` (219):

```dart
  // What held focus when the overlay sidebar opened; it gets focus back
  // when the overlay closes (VK-778).
  FocusNode? _focusBeforeOverlay;
  // The selected destination when the overlay sidebar opened.
  int _selectedBeforeOverlay = 0;
  // The sidebar's own node: the overlay takes focus with it when it opens
  // and lets go of it when it closes (VK-778).
  final FocusNode _sidebarFocus = FocusNode(debugLabel: 'LiquidShell sidebar');
```

`dispose` (403) also disposes `_sidebarFocus`. The sidebar's `Focus` (1751) takes the node: `focusNode: _sidebarFocus,` above `autofocus: modal,`.

In `_applySidebarVisible`, inside the existing transition branch (940):

```dart
    if (_sidebarVisible != visible) {
      if (_presentation == ShellPresentation.overlay) {
        if (visible) {
          _rememberFocus();
        } else {
          // Focus leaves the sidebar now, before a route opened in this
          // turn asks for it. Removed in the closing frame with focus, the
          // sidebar would give it to the scope around the shell after that
          // request, taking it from the route. `scope`, not the previous
          // child: a row focused by Tab would get it again.
          if (_sidebarFocus.hasFocus) _sidebarFocus.unfocus();
          _restoreFocus();
        }
      }
      setState(() => _sidebarVisible = visible);
    }
  }

  /// The overlay opens: the body and the top bar stop taking focus, so the
  /// node that holds it loses it. It is kept to get it back. Not the
  /// shell's search field: an active one keeps its focus under the overlay,
  /// and focusing an idle one starts a search. Tab out of an active field
  /// ends the search; closing does not restart it.
  void _rememberFocus() {
    final focus = FocusManager.instance.primaryFocus;
    _focusBeforeOverlay = identical(focus, _search.focus) ? null : focus;
    _selectedBeforeOverlay = widget.selectedIndex;
  }

  /// The overlay closes: the kept node gets focus back after the frame,
  /// once the rebuild has made the body and the top bar focusable again.
  /// Only focus moves: the node's widget is neither rebuilt nor written to.
  /// A node no longer in the tree is skipped: asked now, it would take
  /// focus whenever it came back.
  ///
  /// Nothing is given back when focus is no longer where the close left
  /// it, or while the shell's route is covered. Under a route opened in the
  /// same turn (a dialog, a pushed page, on any navigator), the kept node
  /// would take focus, and a text field its input connection, behind that
  /// route. A node that took focus since (a field that autofocuses as the
  /// overlay closes) keeps it. Nor after the app selected another page
  /// while the overlay was open: a body that keeps hidden pages focusable
  /// would give focus to the page left behind.
  void _restoreFocus() {
    final node = _focusBeforeOverlay;
    _focusBeforeOverlay = null;
    if (node == null) return;
    final selected = _selectedBeforeOverlay;
    // After the frame's other post-frame callbacks (a text field asks for
    // its autofocus in one) and after the focus update the frame queued
    // during the build, which applies what they asked for.
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => scheduleMicrotask(() {
        if (!mounted || !(node.context?.mounted ?? false)) return;
        // The app selected another page while the overlay was open, or as
        // it closed.
        if (widget.selectedIndex != selected) return;
        // A route above the shell's, also one that takes no focus and so
        // leaves it on the scope below.
        if (!(_route?.isCurrent ?? true)) return;
        // The closing sidebar leaves focus on the scope around the shell;
        // anywhere else, something took it since.
        final scope = FocusScope.of(context, createDependency: false);
        if (!identical(FocusManager.instance.primaryFocus, scope)) return;
        node.requestFocus();
      }),
    );
  }
```

In `_select`, before the app's callback (987):

```dart
    // Another page: the focus it held is not given back (VK-778), also when
    // the app's callback closes the overlay itself.
    _focusBeforeOverlay = null;
    widget.onDestinationSelected(index);
```

The dartdoc names no Plane id: `tool/check_public_docs.sh` rejects `VK-` in `///` lines under `lib/`.

**Properties.**

- **Visible → hidden only.** The new code sits in the setter's transition branch (940), and the kept node is cleared when it is used. A second close in the same turn (two backs, back then Escape) finds the sidebar already hidden: nothing happens.
- **Overlay only.** Compact returns earlier (931-939). The tiled presentation excludes no focus, so nothing is lost or given back. With native chrome engaged the setter returns at 927-930 (UIKit's sidebar, a non-goal).
- **The sidebar lets go first.** The close calls `_sidebarFocus.unfocus()` (disposition `scope`): focus moves at once to the scope around the shell, before a route opened in the same turn asks for it. Without that, the sidebar is removed in the closing frame while it holds focus, and Flutter's detach gives focus to that scope after the route's request, taking it from the route. A dialog on the app's root navigator over a shell in a nested navigator then lost focus, and the kept field got it with its input connection (re-review I-A); on the shell's own navigator the covering route lost it to the shell's route. `hasFocus`, not `hasPrimaryFocus`: a sidebar row focused by Tab holds it. `scope`, not `previouslyFocusedChild`: that one would focus the row again. Mutations `sidebar-unfocus`, `primary-only` and `previous-child` (§10.2).
- **After the frame, in a microtask.** The rebuild lifts `ExcludeFocus`; a request before it does nothing (§3.1). The give-back runs in a microtask queued from a post-frame callback: after the closing frame's other post-frame callbacks (`EditableText` asks for its autofocus in one, `editable_text.dart:3332-3339`) and after the focus update the frame queued during the build, which applies what they asked for. In the post-frame callback itself those requests are still pending, and the give-back would win over them; it would also cancel an autofocus (`_Autofocus.applyIfValid` needs an empty scope, `focus_manager.dart:158-170`). Mutations `same-frame` and `microtask`.
- **Not while the shell's route is covered** (`_route?.isCurrent`): a route opened on the shell's navigator in the same turn. This guard alone catches a route that takes no focus (`requestFocus: false`): focus then stays on the scope around the shell, and only the route tells that the page is covered. Mutation `route-current`.
- **Not when focus moved:** primary focus is not `FocusScope.of(context, createDependency: false)`, the scope the close put it on. A route opened in the same turn on any other navigator (the app's root navigator over a shell in a nested navigator, a navigator inside the body as a router's shell route uses), and a request made during the closing frame or later (a build, an autofocus, a post-frame callback), keep their focus. `createDependency: false` adds no rebuild dependency. Mutation `focus-moved`.
- **Not the shell's search field.** Active, it keeps its focus under the overlay (VK-774), so there is nothing to give back. Tab out of an active field into the sidebar ends the search; closing does not restart it. Idle, focusing it starts a search: a search the user ended under the overlay (Escape in the field, or Tab) would start again on close. Mutation `search-field`.
- **A node out of the tree is skipped** (`node.context?.mounted`). Asked anyway, it would take focus whenever it came back (§3.1).
- **No extra code for two harmless cases.** A node that is mounted but can no longer take focus ignores the request: Flutter checks `canRequestFocus` itself. With nothing focused at open, the kept node is the route's scope; asking it for focus leaves focus on that scope, where the close leaves it anyway.
- **A destination chosen:** `_select` drops the kept node before it calls the app's `onDestinationSelected`, so also when that callback closes the overlay itself. With a body that keeps hidden pages focusable the old page would otherwise get focus while hidden: `Offstage` branches, or go_router's custom `navigatorContainerBuilder` example (`example/lib/others/custom_stateful_shell_route.dart`: `AnimatedOpacity`, `IgnorePointer` and `TickerMode`, no `ExcludeFocus`). An `IndexedStack` body (the shell's default, and go_router's `StatefulShellRoute.indexedStack`) is safe: its `Visibility` excludes focus from hidden children (Flutter 3.44.6 `basic.dart:4886-4894`, `visibility.dart:267`). Since the selection check below, this line matters for an app that selects the page after the closing frame (an async router callback). Mutations `selection` and `callback-order`: red only on the test whose app selects after the frame.
- **Another destination selected by the app** while the overlay is open or as it closes (a `sidebarHeader` or `sidebarFooter` button, a deep link, `goBranch`; final review I1): that selection does not go through `_select`. `_rememberFocus` keeps `widget.selectedIndex`, and the give-back's microtask returns when the shell's `selectedIndex` differs, so the page left behind gets neither focus nor, for a text field, an input connection. A selection the app makes after the closing frame is not seen: focus goes back to the page still shown, and what happens when the app then hides it is the body's own behaviour, as without the overlay. Mutation `app-selection`.
- **A rotation while the overlay is open** changes the presentation; `sidebarVisibleFor` resets visibility without the setter, so nothing is given back (not one of the listed paths). The next open replaces the kept node.
- **Not handled**, recorded in §12: a focus move an app makes in the same turn as the close, before the frame; and a route that takes no focus opened on a navigator around the shell's own.
- **Vietnamese IME safety.** The only calls are `FocusNode.unfocus()` on the sidebar's own node and `FocusNode.requestFocus()` on the kept node. No widget is rebuilt: the body subtree and its `ExcludeFocus` wrapper stay in the tree, and only their flags change (VK-702 §4.4). Nothing is written into any controller. A page text field's composition already ended when the field lost focus at open (`EditableText` clears it on unfocus; the dev.8 CHANGELOG says the field loses focus). On focus the field reopens its input connection with its own value, as for any focus. The test pins the same `EditableTextState`, the same `TextEditingValue` and no rebuild of the page. Under a route opened in the same turn the field gets neither focus nor an input connection: the route tests assert `hasAnyClients` is false.

**How it composes with `handleBack` and branch S (VK-776).**

- `handleBack` (887-896) closes the overlay with `_setSidebarVisible(false)`. The give-back lives in the setter's transition branch, not in `handleBack`, and branch F does not change `handleBack`.
- S changes who calls `handleBack` between nested shells: an inner shell on its host's route steps aside, and the host hands back in its own order. Whatever path reaches a shell's `handleBack`, each shell gives its own kept node back at most once per close: a second call finds its sidebar hidden.
- Before S, one back can act in both shells (S's case (b)). Each shell then gives back its own node, still once each.
- No shared lines: S edits the fields after `_backSearch` (292), `didChangeDependencies` (around 368), `_backScope` (865-889), `_bodySubtree` (906-916) and the end of the file. F edits the fields at 219, `dispose` at 403, `_applySidebarVisible` at 940, `_select` at 987-995, the comment at 1285, the field layout at 1707 and the sidebar's `Focus` at 1751. Each focus test uses a single shell (two of them in a nested navigator, with no back), so S's change does not reach them.

## 5. Design: VK-778 (3), the regular search field keeps to the safe width

In `liquid_shell.dart`, the `regularFieldTop != null` block (1703-1716):

```dart
      // The safe width, as for the bars (VK-778). Tiled, the sidebar
      // already clears the leading inset: only the trailing one is added.
      final sideStart = tiled ? 0.0 : (rtl ? sideRight : sideLeft);
      final sideEnd = rtl ? sideLeft : sideRight;
      final start = bodyStart + sideStart + kRegularSearchMargin + indent;
      final end = sideEnd + kRegularSearchMargin;
      children.add(
        AnimatedPositioned(
          key: kSearchFieldKey,
          duration: morph,
          curve: kSearchMorphCurve,
          left: rtl ? end : start,
          right: rtl ? start : end,
```

- **Values,** 932×430 with insets 59/59:
  - top bar or overlay sidebar: 79..853;
  - tiled, LTR: 320..853;
  - tiled, RTL: 79..612.
- Every phase (selected and active) and both kinds that show the field (`topBar`, `sidebarOverlay`, `sidebarTiled`) take the same rule. The vertical position is unchanged.
- **The window-controls indent** (iPadOS windowed) is added as before. It and side insets do not occur together, and the top bar adds both in the same way (1679-1680, 1647).
- **Zero side insets** (every iPad, every golden): the old values exactly.

## 6. Design: VK-778 (4) and (5), comments only

**(4)** Above `_set(LiquidPlatformSignals.none);` in `acquire()`'s catch (`signals_controller.dart:68`):

```dart
        // Safe from initState: this notifies only when an earlier stream
        // left a value other than none, and then nobody listens. Every
        // listener is a mounted glass, which would already count as a user,
        // and _users is 1. That user stays counted with no stream; once the
        // last user releases, the next first acquire() tries again.
```

**(5)** The comment moves above the statement (`liquid_shell.dart:1285-1290`):

```dart
    // The device decides, not an app's ThemeData.platform (VK-702).
    final bottomGap = bottomGapFor(
      platform: defaultTargetPlatform,
```

**No test:** behaviour does not change. The task checks that the diff holds only comment lines, and that the M12 test stays green.

## 7. Design: VK-777, the iPhone's placement is pinned per OS

### 7.1 The assertion

In `testTheScopeBarShowsOnlyWhileTheSearchIsActive`, before the branch at 2988:

```swift
    // VK-777: on an iPhone UIKit makes that choice (`SearchMath.style`
    // asks for `.automatic`), so it is pinned per OS: a change in UIKit
    // fails here instead of quietly taking the other branch.
    if UIDevice.current.userInterfaceIdiom == .phone {
      let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
      XCTAssertEqual(snapshot.placement, major >= 27 ? "stacked" : "inline", "iOS \(major)")
    }
```

- It is the expression of Q10. `major` is the value `NativeTabsController.swift:324` passes to `SearchMath.style` as `osMajor`, and 27 is the threshold `SearchMath` already uses (`prominent: osMajor >= 27`, `SearchMath.swift:48`). The message names the OS, so a red run says which side changed.
- Only in the scope-bar test, where the item asks. `testTheDebugSnapshotDescribesTheSearchTab` keeps its iPad-only assertion.
- The iPad runs the test unchanged.

### 7.2 Its red

The assertion pins UIKit's behaviour, not our code (§3.4). The evidence proposed to show it red by forcing `.stacked` for the phone in `SearchMath.style`. The plan check ran that mutation on the iOS 26.5 iPhone: the test stayed green (`"passedTests" : 1`), because UIKit still realised `inline`. Asking for `.integrated` in `applySearchStyle` stayed green too. No product mutation moves the iPhone's realised placement.

The red is therefore shown with the assertion's threshold changed for one run: `major >= 27` becomes `major >= 26`, on the iOS 26.5 iPhone. Measured: `XCTAssertEqual failed: ("inline") is not equal to ("stacked") - iOS 26`, the only failure. Together with the two green runs (26.5 realises `inline`, 27.0 realises `stacked`), it shows that:

- the assertion runs on an iPhone;
- it reads the value UIKit realised;
- that value differs by OS, as the expression says.

The task also runs the evidence's product mutation once, for the report, so the reviewer sees that it stays green.

### 7.3 Where it runs

- **Locally (Q10):** iPhone 17 simulators on iOS 26.5 and iOS 27.0, created by the task and deleted at the end. The selection is the one test (`-only-testing:RunnerTests/NativeTabsTests/testTheScopeBarShowsOnlyWhileTheSearchIsActive`); the change touches no other test.
- **CI:** the `ios-unit` iPhone leg runs it on the newest runtime of the runner image, one branch per run (Q10: no runtime axis).

## 8. Design: VK-700, the stable leg's liquid goldens only inform

### 8.1 `Makefile`

`goldens` becomes the sum of two targets that run the same two commands, in the same order. `make verify` and the 3.44.x leg run exactly what they ran before; make stops at the first failing prerequisite, as `&&` did.

```make
goldens: goldens-plain goldens-liquid ## Golden tests (reference toolchain: macOS + Flutter 3.44.x); liquid ones under Impeller

# The two halves of `goldens`. CI's latest-stable leg runs them as separate
# steps: the plain half and the shader probes decide its colour, the liquid
# half only informs (VK-700: newer engines draw the dark glass differently).
goldens-plain: ## Plain golden tests (tag golden)
	@if [ -d $(EXAMPLE)/test/goldens ]; then \
	  cd $(EXAMPLE) && $(FLUTTER) test --tags golden; \
	else echo "▸ no goldens yet"; fi

goldens-liquid: ## Liquid-tier golden tests under Impeller (tag liquid_golden)
	@if [ -d $(EXAMPLE)/test/goldens ]; then \
	  cd $(EXAMPLE) && $(FLUTTER) test --enable-impeller --tags liquid_golden; \
	else echo "▸ no goldens yet"; fi
```

Both names join `.PHONY`. CI calls make targets only (the Makefile's first line: one entry point per check).

### 8.2 The `goldens` job

```yaml
      - run: make get
      # `make goldens` in two steps. On 3.44.x (the floor and the golden
      # reference) both block. On stable the plain goldens and the shader
      # probes decide the leg's colour, and the liquid goldens only inform:
      # newer engines draw the dark glass slightly differently (VK-700),
      # until the reference moves to a newer Flutter at 0.1.0.
      - run: make goldens-plain
      - id: liquid
        run: make goldens-liquid
        continue-on-error: ${{ matrix.experimental }}
      - if: ${{ steps.liquid.outcome == 'failure' }}
        run: echo "::warning title=Liquid goldens differ on Flutter ${{ matrix.flutter }}::Informational on this leg until the golden reference moves (CONTRIBUTING.md, Toolchain)."
      # The shader probes (lens placement and direction) are the early
      # warning for an engine change; on the informational stable leg they
      # must run even when its goldens drift.
      - if: ${{ success() || (always() && matrix.experimental) }}
        run: make test-impeller
      - if: ${{ failure() || steps.liquid.outcome == 'failure' }}
        uses: actions/upload-artifact@v4
```

- **3.44.x:** `continue-on-error` is false, so a liquid failure fails the job as today. The plain step stops the job at its first failure, as `make goldens` did.
- **Stable:** a liquid failure gives the step the outcome `failure` and the conclusion `success`. The job stays green and the probes run. The warning annotation shows in the run summary, and the failure images are uploaded (`steps.liquid.outcome`, because `failure()` stays false). A plain or probe failure still makes the leg red.
- **The job keeps its `continue-on-error: ${{ matrix.experimental }}`** (431): the stable leg never blocks a merge (Q11).
- **With 3.47.7's numbers** (evidence): plain `+36` green, liquid 7 red (informational), probes 19/19 green. The leg is green with one warning.

### 8.3 How it is checked

- **Red first:** `make goldens-plain` and `make goldens-liquid` fail with `No rule to make target`. A structure check of the `goldens` job (a short Python script in the agent's scratchpad, never committed, run with `python3 -I`, given in full in the plan) fails on today's `ci.yaml` with three problems: `make goldens` still runs; no `make goldens-plain` step; no `make goldens-liquid` step.
- **Green:**
  - the structure check passes (matrix and job-level `continue-on-error` unchanged; plain blocking; liquid `continue-on-error: ${{ matrix.experimental }}` with an id; order plain, liquid, probes; the upload covers the liquid outcome);
  - `ci.yaml` parses (`python3 -I` with PyYAML);
  - `actionlint .github/workflows/ci.yaml` passes, where it is installed;
  - `make -n goldens` prints the two `flutter test` commands in the old order;
  - `make help` lists both targets.
- **The split selects the right files** (3.44.6): `make goldens-plain` `+36` (the `golden` files); `make goldens-liquid` `+27` (`liquid_test.dart`); `make test-impeller` `+19`. `+36` and `+27` are the counts `make goldens` gave before the split (evidence §2.3).
- **A mutation of the check:** the liquid step with `continue-on-error: true` (informational on 3.44.x too) makes it red (`✗ liquid goldens: informational on stable only`).
- **Not run here:** the stable leg on Flutter 3.47.7 (no 3.47 on this machine; the evidence ran it from a scratch clone). Its outcome follows from the evidence's numbers above. The first CI run of the PR shows it.

### 8.4 `CONTRIBUTING.md`

- Toolchain, after "Goldens are only valid on macOS with Flutter 3.44.x (spec Q11).", a bullet: CI also runs the latest stable Flutter, never blocking. There the plain goldens and the shader probes must pass. The liquid goldens only inform, because newer engines draw the dark glass slightly differently (VK-700). At 0.1.0 the golden reference moves to a newer Flutter and the images are regenerated once.
- Commands table, a row before `make goldens-update`: `make goldens-plain` / `make goldens-liquid`, the two halves of the goldens in `make verify`.
- No README or `doc/` change: a pub.dev reader does not see CI.

### 8.5 Later, at 0.1.0 (not on this branch)

Move `.fvmrc`, the CI matrix, the `tool/update_goldens.sh` guard and the floor together; regenerate the 7 images; inspect the dark diffs by eye (max delta 55-58 on glass edges). VK-700 stays open until then.

## 9. Pinned names

| What | Name |
|---|---|
| Fields (`_LiquidShellState`, private) | `FocusNode? _focusBeforeOverlay`, `int _selectedBeforeOverlay`, `final FocusNode _sidebarFocus` |
| Methods (private) | `void _rememberFocus()`, `void _restoreFocus()` |
| Test group (`shell_chrome_test.dart`, in `sidebar`) | `focus returns when the overlay closes (VK-778)` |
| Its tests | `closed by Escape: the node that held focus has it again`; the same for `the barrier`, `Hide`, `system back`; `a text field has focus again, not rebuilt or written to`; `a destination chosen in the overlay: the page left behind gets no focus`; `a destination chosen, the app's callback closing the overlay itself: the page left behind gets no focus`, and the same with `, the page selected after the frame` before the colon; `a node that left the tree while the overlay was open takes no focus when it comes back`; `a dialog shown as the overlay closes: the field under it gets no focus and no input connection`, and the same for `a page pushed`; `a dialog shown on the root navigator as the overlay closes, the shell in a nested navigator: the field under it gets no focus and no input connection`, and the same with `, a sidebar row focused` after `closes`; `a page pushed on a navigator inside the body as the overlay closes: the field under it gets no focus and no input connection`; `a page pushed as the overlay closes, taking no focus: the field under it gets no focus and no input connection`; `a field that takes focus as the overlay closes keeps it`; `the app selects another page while the overlay is open: the page left behind gets no focus and no input connection`; `the app selects another page as the overlay closes: the page left behind gets no focus and no input connection` |
| Tests (in `sidebar` › `with the search tab selected`) | `overlay: a search ended under it stays ended when it closes`; `overlay: a search ended by Tab into it stays ended when it closes` |
| Test group (`shell_chrome_test.dart`, before `side safe area (VK-702)`) | `the regular search field clears the side insets (VK-778)`; tests `top bar: both insets`, `tiled, ltr: the trailing inset only`, `tiled, rtl: the trailing inset only` |
| XCTest | the assertion in `testTheScopeBarShowsOnlyWhileTheSearchIsActive` |
| Make targets | `goldens-plain`, `goldens-liquid` (`goldens` runs both) |
| CI step id | `liquid` |
| Public API | none new, none changed |

## 10. Test strategy

### 10.1 Red first (`liquid_shell`, `fvm flutter test`)

All widget tests use the shell harness (`pumpShell`, `TestShell`, `scopeOf`). Overlay tests run on `kTabletPortrait` with the file's `_tablet` padding.

**VK-778 (1)** (group `sidebar` of `test/widget/shell_chrome_test.dart`):

| Test | At `e0bbf62` | Why |
|---|---|---|
| closed by Escape / the barrier / Hide / system back (one test each, from a map of closers) | red: `Expected: same instance as FocusNode:<FocusNode#…(context: Focus)>`, `Actual: FocusScopeNode:<…(_ModalScopeState<dynamic> Focus Scope [PRIMARY…` | nothing remembers the node; focus falls to the route's scope |
| a text field has focus again, not rebuilt or written to | red, the same lines | as above; it also pins the same `EditableTextState`, the same `TextEditingValue` and no page rebuild (a counting `Builder`) |
| a destination chosen in the overlay (`offstageBranches: true`): the page left behind gets no focus | green (a locker) | nothing is given back today; red under the `selection` mutation |
| a node that left the tree while the overlay was open takes no focus when it comes back | green (a locker) | red under the `mounted` mutation |
| overlay: a search ended under it stays ended when it closes | green (a locker) | red under the `search-field` mutation |

The group's precondition lines (`reason: 'precondition'`, `'the overlay is modal'`) hold at `e0bbf62`: the page node had focus, and the overlay took it.

**Added after review** (I1, M1; red at `c2a02fd`, before the first fix). They use the helper `focusFieldThenOpen`: page 0 is a text field with focus, then the overlay opens, and the field's input connection closes.

| Test | At `c2a02fd` | Why |
|---|---|---|
| a destination chosen, the app's callback closing the overlay itself: the page left behind gets no focus | red: `Expected: false`, `Actual: <true>` | the kept node was cleared only after the app's callback, which had closed the overlay |
| a dialog shown as the overlay closes: the field under it gets no focus and no input connection | red: `Expected: false`, `Actual: <true>` on `node.hasFocus`, and on `hasAnyClients` when asserted alone | given back under the dialog |
| a page pushed as the overlay closes: the field under it gets no focus and no input connection | red, the same lines | given back under the page |
| a field that takes focus as the overlay closes keeps it | red: `Expected:` the editor's node, `Actual:` the kept field | the give-back cancelled the autofocus |

**Added after re-review** (I-A, M-c; red at `d85cf7f`, before the second fix):

| Test | At `d85cf7f` | Why |
|---|---|---|
| a dialog shown / a page pushed as the overlay closes (the two above), now also asserting that the route above holds focus | red: `Expected: same instance as DialogRoute<void>…` (`MaterialPageRoute<void>…`), `Actual: MaterialPageRoute<dynamic>…(RouteSettings("/"…` | the removed sidebar gave focus to the shell's route after the covering route had asked for it |
| a dialog shown on the root navigator as the overlay closes, the shell in a nested navigator: the field under it gets no focus and no input connection | red: `Expected: false`, `Actual: <true>` on `node.hasFocus`, and on `hasAnyClients` when asserted alone | the shell's route stays current; the removed sidebar put focus back on the scope around the shell after the dialog's request, so `focus-moved` passed |
| the same, a sidebar row focused (by Tab) | red, the same lines | as above; it pins `hasFocus` and the `scope` disposition |
| a page pushed on a navigator inside the body as the overlay closes: the field under it gets no focus and no input connection | green (a locker) | red under `focus-moved` and `microtask` |
| a page pushed as the overlay closes, taking no focus: the field under it gets no focus and no input connection (`requestFocus: false`) | green (a locker) | red under `route-current` only |

**Added after the final review** (I1, N1, M5; red at `99e7e2d`, before the fix). The two I1 tests use `focusFieldThenOpen` with `offstageBranches: true`; the second adds a `sidebarFooter` button.

| Test | At `99e7e2d` | Why |
|---|---|---|
| the app selects another page while the overlay is open (`select(1)`, then Escape): the page left behind gets no focus and no input connection | red: `Expected: false`, `Actual: <true>` on `node.hasFocus`, and on `hasAnyClients` when asserted alone | only `_select` dropped the kept node; after the app's own selection the hidden page's field got focus and its input connection back |
| the app selects another page as the overlay closes (a footer button that selects and closes in one turn): the same | red, the same lines | as above |
| overlay: a search ended by Tab into it stays ended when it closes | green (a locker) | red under `search-field` |
| a destination chosen, the app's callback closing the overlay itself, the page selected after the frame (added at `b2bde83`, after the fix) | green (a locker) | with the selection check, both destination tests stayed green under `selection` (`+42`): their apps select in the same turn. This one's app selects after the closing frame, so only `_select` keeps the page out. Red under `selection` and `callback-order` only |

The two nested-navigator dialog tests also assert, after the close, that the field's route (the shell's) is still current (`reason: 'precondition'`, M5). They rest on `focus-moved` and `sidebar-unfocus`; a harness change that covered the shell's route would move them onto `route-current` unseen.

**VK-778 (3)** (new group before `side safe area (VK-702)`; `kPhoneLandscape`, insets 59/59, bottom 21, search tab selected):

| Test | At `e0bbf62` |
|---|---|
| top bar: both insets (`compactHeight: 0`) | red: `Expected: <79>`, `Actual: <20.0>` |
| tiled, ltr: the trailing inset only (`compactHeight: 0, tiledSidebar: 900`) | red: `Expected: <853>`, `Actual: <912.0>` |
| tiled, rtl: the trailing inset only | red: `Expected: <79>`, `Actual: <20.0>` |

**VK-778 (4), (5):** no test (§6).

### 10.2 Mutation checks (run, pasted into the task reports, never committed)

VK-778 (1) counts are for `--plain-name 'sidebar'`: 39 tests after the re-review fix (31 at Task 1, where `selection` gave `+30 -1` and `same-frame` `+26 -5`), 43 after the final review's fixes. A row's count is at 39 unless it names another.

| Mutation | Must go red |
|---|---|
| `selection`: `_select` without `_focusBeforeOverlay = null;` | both destination tests (`Expected: false`, `Actual: <true>`), `+37 -2`. After the final review only the app's-callback test whose app selects after the frame, `+42 -1` (at 43) |
| `callback-order`: the kept node cleared after `widget.onDestinationSelected(index)` | the app's-callback destination test (`Expected: false`, `Actual: <true>`), `+38 -1`. After the final review only its variant that selects after the frame, `+42 -1` (at 43) |
| `search-field`: `_rememberFocus` keeps the search field too | the search-ended test (`Expected: false`, `Actual: <true>`), `+38 -1`. After the final review also the Tab test, `+40 -2` (at 42) |
| `app-selection`: `_restoreFocus` without `if (widget.selectedIndex != selected) return;` | both app-selects-another-page tests (`Expected: false`, `Actual: <true>`), `+40 -2` (at 42) |
| `mounted`: `_restoreFocus` without the `node.context?.mounted` check | the left-the-tree test (`Expected: false`, `Actual: <true>`), `+38 -1` |
| `same-frame`: `_restoreFocus` asks at once, not after the frame | the four close tests and the text field test (`Actual: FocusScopeNode…(_ModalScopeState<dynamic> Focus Scope [PRIMARY…`), `+34 -5` |
| `microtask`: the checks run in the post-frame callback itself | both nested-navigator dialog tests and the page pushed inside the body (`Expected: false`, `Actual: <true>`), the autofocus test (`Actual:` the kept field), `+35 -4` |
| `route-current`: without `if (!(_route?.isCurrent ?? true)) return;` | the page that takes no focus (`Expected: false`, `Actual: <true>`), `+38 -1` |
| `focus-moved`: without the primary-focus check | the same four as `microtask`, `+35 -4` |
| `sidebar-unfocus`: without `if (_sidebarFocus.hasFocus) _sidebarFocus.unfocus();` | the dialog and page tests (`Actual: MaterialPageRoute<dynamic>…("/"…`: the route above lost focus) and both nested-navigator dialog tests (`Expected: false`, `Actual: <true>`), `+35 -4` |
| `primary-only`: `hasPrimaryFocus` in place of `hasFocus` | the nested-navigator dialog test with a sidebar row focused, `+38 -1` |
| `previous-child`: `unfocus(disposition: UnfocusDisposition.previouslyFocusedChild)` | the same test, `+38 -1` |
| `tiled-leading`: the tiled field adds the leading inset too | both tiled tests (`Expected: <320>`, `Actual: <379.0>`; `Expected: <612>`, `Actual: <553.0>`) |
| VK-777: the threshold `major >= 27` → `major >= 26`, on the iOS 26.5 iPhone | the scope-bar test, `("inline") is not equal to ("stacked") - iOS 26` |
| VK-777, for the report: `SearchMath.style` asks `.stacked` for a phone | stays **green** on the 26.5 iPhone (§7.2) |
| VK-700: the liquid step's `continue-on-error: true` | the CI structure check (`✗ liquid goldens: informational on stable only`) |

### 10.3 Unchanged, still green

The rest of `shell_chrome_test.dart` (`+62` at `e0bbf62`: `+70` after Task 1, `+73` after Task 2, `+77` after the Task 1 fix, `+81` after the re-review fix, `+85` after the final review's fixes), `sidebar_test.dart` (including "rows start after the safe area on the leading side"), `pushed_shell_back_test.dart`, `native_chrome_test.dart` (the native sidebar), `search_fallback_test.dart`, `liquid_glass_test.dart` (M12), the whole `liquid_shell` suite, `make goldens` (no image moves), and the rest of `RunnerTests` on CI.

### 10.4 Simulators

| Task | Command | Simulators |
|---|---|---|
| VK-777 | `tool/ios_xctest.sh <udid> <result> 900 120 300 -only-testing:RunnerTests/NativeTabsTests/testTheScopeBarShowsOnlyWhileTheSearchIsActive` | iPhone 17, iOS 26.5 (the two mutations, then green); iPhone 17, iOS 27.0 (green) |

- Each simulator is created by the task with `xcrun simctl create`, passed by UDID and deleted at the end, also on failure. Never a physical device; never `simctl shutdown all`.
- No XCUITest and no integration test: no UI change.
- `make verify` (format, analyze, provenance, public docs, Pigeon, tests, Impeller tests, coverage ≥ 90 %, goldens, snippets) runs before the PR.

## 11. CHANGELOG wording

`liquid_shell/CHANGELOG.md` gets a new heading at the top, above `## 0.1.0-dev.8` (Q2). Branch R adds `## 0.1.0-dev.9` and branch S also writes under `## 0.1.0-dev.10`; see §12 for the merge.

```markdown
## 0.1.0-dev.10

- **Fix (VK-778).** When the Flutter overlay sidebar closes by Escape, a
  tap on its barrier, its Hide button or system back, keyboard focus goes
  back to what held it when the sidebar opened (a page's control or text
  field, the sidebar toggle). Before, it stayed on the route, so a
  hardware-keyboard user lost their place. Nothing is given back when
  another destination is selected while the sidebar is open, in the
  sidebar or by the app (the page changes), and the shell's own search
  field is never refocused this way: focusing it starts a search.
  Nothing is given back either when a route opens in the same turn (a
  dialog or a pushed page, on any navigator; the route keeps focus), or
  when something else takes focus as the sidebar closes (a field that
  autofocuses). The exception is a route that takes no focus
  (`requestFocus: false`) opened on a navigator around the shell's own.
  An app that moves focus itself when it closes the sidebar should do so
  after the frame: before it, the page cannot take focus yet, and the
  give-back wins.
- **Fix (VK-778).** The regular search field (the search tab selected in
  the top bar or sidebar layout) keeps inside the horizontal safe area, as
  the bars do since 0.1.0-dev.8. Side insets reach that layout only through
  breakpoints that give a landscape phone the regular layout, where the
  field ran under the notch. Beside a tiled sidebar only the trailing inset
  is added: the sidebar already clears the leading one.
```

- The first bullet supersedes the dev.8 sentence "focus is not restored to it when the sidebar closes". The dev.8 section is not edited (Q3 keeps it as it is).
- **No entries** for the comments (VK-778 (4), (5)), the XCTest (VK-777) or the CI change (VK-700): no package behaviour changes. No other package changes, so no other CHANGELOG.

## 12. Risks

| Risk | Handling |
|---|---|
| Focus given back to a text field on a touch-only iPad brings the software keyboard back | The field had it when the overlay opened; it is what a dismissed UIKit alert does. On a hardware keyboard nothing shows |
| An app moves focus itself when the overlay closes (it listens to `sidebarVisible`), or opens a route in the same turn | Handled after review (VK-778 I1) and re-review (I-A): the sidebar lets go of focus as it closes, before a route opened in the same turn asks for it. The give-back runs after the closing frame's post-frame callbacks and the focus update they queue, and only while the shell's route is current and primary focus is still on the scope around the shell, where the close put it. A dialog or page opened in the same turn keeps focus on any navigator: the shell's, the app's root navigator over a shell in a nested navigator, or a navigator inside the body. So does a request made during the closing frame or later (a build, an autofocus, a post-frame callback). Tests pin each. Left, recorded, not handled ("Quyết định phát sinh" 4): (1) a move made in the same turn as the close, before the frame: Flutter drops a request to a node behind the overlay (it cannot take focus until the rebuild), and `unfocus()` parks focus on that same scope, so the kept node still gets focus back; an app that wants its own target requests it after the frame. (2) A route that takes no focus (`requestFocus: false`) opened in the same turn on a navigator around the shell's own: the shell's route stays current and focus stays on the scope around the shell, so the kept node, a text field with its input connection, gets focus under that route (probe, no test). Flutter itself leaves focus below such a route; on the shell's own navigator `route-current` catches it |
| VK-776 (branch S) changes back delegation in the same file at the same time | No shared lines (§4). Each close gives back once, whoever calls `handleBack`. If S merges first, F merges `main` and reruns the focus group and `pushed_shell_back_test.dart` |
| VK-779 (branch S) adds compact-row tests near the side-safe-area group | F's inset tests sit in their own group before `side safe area (VK-702)`; VK-779's code is in `search_chrome.dart`, this is `liquid_shell.dart` |
| CHANGELOG merge with R (`## 0.1.0-dev.9`) and S (`## 0.1.0-dev.10`) | All three insert at the top. Resolution: one `## 0.1.0-dev.10` section (S's and F's bullets) above `## 0.1.0-dev.9`, above `## 0.1.0-dev.8` |
| UIKit changes the iPhone's placement in an iOS update | The VK-777 assertion is meant to go red then, with the OS in its message. The fix is the expression and the test's comment, after a look at the new geometry |
| CI's `ios-unit` iPhone leg moves to a newer runtime | The assertion covers every major version by its threshold. A 26.x-only runner and a 27.x runner both pass |
| The stable leg hides a new liquid regression behind "informational" | The warning annotation and the uploaded images stay visible. The 3.44.x leg still blocks every liquid golden. The shader probes stay blocking on the stable leg |
| `make goldens` behaviour changes for `verify` | Same commands, same order, same first-failure stop (`make -n goldens`) |

## 13. Process

- **Tasks, in order** (the plan):
  1. VK-778 (1), focus comes back;
  2. VK-778 (3), the field's inset;
  3. VK-778 (4) and (5), comments;
  4. VK-777, the XCTest assertion on two simulators;
  5. VK-700, CI.

  Tasks 1 and 2 add the CHANGELOG section and its two bullets. Task 3 follows them because (5) edits `liquid_shell.dart` too. The last step is `make verify` for the branch.
- **Commits:** `<type>(<scope>): <summary> (VK-NNN)`. `fix(shell)` for Tasks 1 and 2, `docs(shell)` for Task 3, `test(example)` for Task 4, `ci(ci)` for Task 5. Each message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Run `bash .githooks/pre-commit` by hand before each commit. Never `--no-verify`, never a git or flutter config change.
- No push, no PR, no remote change in the tasks. Plane is updated by the controller (the dropped points: §2.2).
- Simulators: §10.4.

## Quyết định cần chủ sản phẩm xác nhận

Chủ sản phẩm đã trả lời "Ok hết" cho Q1–Q18 ngày 2026-10-28, nên mọi mục dưới đây đã được chốt (chỉ những mục của nhánh này).

| Q# | Câu hỏi | Đã chốt |
|---|---|---|
| Q1 | Chia nhánh | Nhánh F `VK-778-followups` gồm VK-778, VK-777 và phần CI của VK-700; spec, plan và PR riêng, từ `main` `e0bbf62` |
| Q2 | CHANGELOG | Ghi dưới tiêu đề mới `## 0.1.0-dev.10` ở đầu CHANGELOG của mỗi gói bị sửa; không nâng phiên bản trong S hay F |
| Q9 | VK-778 làm gì | (1) trả focus khi sidebar overlay đóng bằng Escape, nền mờ, Hide hoặc back (không khi chọn mục; chỉ lúc chuyển hiện → ẩn); (3) inset ngang cho ô tìm regular (bố cục tiled chỉ cần inset phía cuối); (4)(5) chỉ sửa comment, một commit. Bỏ có lý do: (2) không tái hiện; nửa "sidebar overlay" của (3) |
| Q10 | VK-777 | Chỉ một assert (`XCTAssertEqual(snapshot.placement, majorVersion >= 27 ? "stacked" : "inline")` trên iPhone), chạy ở máy trên simulator iOS 26.5 và 27.0; không thêm trục runtime vào CI |
| Q11 | VK-700 | Giữ mốc Flutter 3.44 và golden 3.44 tới 0.1.0. Nhánh CI stable chạy shader probe và golden thường; golden liquid ở đó chỉ để tham khảo; nhánh vẫn không chặn (continue-on-error) nhưng không còn đỏ thường trực. Tới 0.1.0: chuyển lên 3.47, tạo lại 7 ảnh, xem diff bằng mắt. VK-700 mở tới lúc đó |

### Quyết định phát sinh

Bảng trên không nói tới những điểm dưới đây. Spec chọn như sau, chủ sản phẩm có thể đổi:

1. **Trả focus chỉ cho chrome Flutter.** Sidebar native (UIKit) giữ nguyên: bàn phím ở đó là việc của UIKit (VK-702 §8), và bằng chứng chỉ đo phía Flutter.
2. **Không bao giờ trả focus cho ô tìm của shell.** Ô đang tìm vẫn giữ focus dưới overlay (VK-774), nên không có gì để trả; focus vào ô đang rảnh là bắt đầu tìm, nên một lần tìm người dùng đã kết thúc dưới overlay (Escape trong ô, hoặc Tab sang sidebar) sẽ tự mở lại khi đóng. Có test cho cả hai.
3. **Bỏ qua nút đã rời khỏi cây** (`node.context?.mounted`). Flutter hoãn yêu cầu focus của một nút ngoài cây tới khi nó được gắn lại, nên nếu hỏi, nút sẽ giành focus lúc xuất hiện lại. Có test.
4. **Trả focus sau frame, và chỉ khi focus vẫn ở chỗ việc đóng để lại** (sửa sau review VK-778 I1 và re-review I-A). Khi đóng, sidebar nhả focus ngay (`_sidebarFocus.unfocus()`, kiểu `scope`), trước khi một route mở cùng lượt xin focus. Nếu không, lúc bị gỡ khỏi cây trong frame đóng, sidebar sẽ đưa focus về scope bao quanh shell sau yêu cầu của route và giành mất focus của route (ví dụ dialog trên navigator gốc khi shell nằm trong một `Navigator` lồng: ô bị che nhận lại focus và kết nối bàn phím). Phải đợi frame vì `ExcludeFocus` chỉ gỡ khi dựng lại (đột biến `same-frame` cho thấy). Việc trả chạy trong một microtask, sau các post-frame callback của frame đóng (ô `TextField` xin autofocus trong một callback như vậy) và sau lượt cập nhật focus mà frame đã xếp trong lúc build. Không trả nếu route của shell không còn là route hiện tại (kể cả route không lấy focus, `requestFocus: false`), hoặc nếu focus chính không còn nằm trên scope bao quanh shell, nơi việc đóng để lại nó (route mở ở bất kỳ navigator nào, hoặc một nút khác đã giành, ví dụ một ô autofocus). Có test cho dialog, trang mới, dialog trên navigator gốc khi shell nằm trong navigator lồng (thêm biến thể một hàng sidebar đang có focus nhờ Tab), trang đẩy vào navigator bên trong body, trang không lấy focus và ô autofocus. Còn lại, ghi ở mục Rủi ro: app tự đổi focus cùng lượt với việc đóng nhưng trước frame (Flutter bỏ yêu cầu tới nút nằm sau overlay; `unfocus()` để focus trên chính scope đó), và route không lấy focus (`requestFocus: false`) mở cùng lượt ở một navigator bao ngoài navigator của shell.
5. **Đổi trang thì không trả focus.** Chọn mục trong sidebar: `_select` xoá nút đã nhớ (một dòng) thay vì thêm tham số cho setter. Setter được đưa ra ngoài dưới dạng `ValueSetter<bool>` (scope và chrome), nên giữ nguyên chữ ký. App tự đổi trang khi overlay đang mở hoặc ngay lúc đóng (nút ở `sidebarHeader`/`sidebarFooter`, deep link, `goBranch`; sửa sau review cuối, I1) thì không đi qua `_select`: shell nhớ `selectedIndex` lúc mở, và microtask trả focus bỏ qua nếu nó đã đổi. Vẫn giữ dòng xoá trong `_select`: router bất đồng bộ đổi trang sau frame đóng, lúc đó chỉ dòng này chặn (có test riêng). Test dùng thân có trang ẩn vẫn nhận focus (`offstageBranches: true` hoặc `Offstage` tự dựng), vì đó là lúc trang cũ còn nhận focus. `IndexedStack` (mặc định, và `StatefulShellRoute.indexedStack` của go_router) đã loại focus khỏi trang ẩn qua `Visibility`; mẫu `navigatorContainerBuilder` tuỳ chỉnh của go_router thì không.
6. **Chỉ ở bố cục overlay, chỉ trong nhánh chuyển trạng thái của setter.** Tiled và compact không đổi. Xoay máy khi overlay đang mở thì không trả (không thuộc các đường đã duyệt); lần mở sau ghi đè nút đã nhớ.
7. **Không thêm test "không có focus trước thì sau cũng không".** Khi đó nút được nhớ là scope của route; hỏi nó thì focus vẫn ở scope, đúng chỗ việc đóng để lại. Không có đột biến nào làm test đó đỏ, nên nó không chứng minh gì.
8. **Inset: test bằng điện thoại nằm ngang 932×430, inset 59/59, breakpoint tuỳ chỉnh** (`compactHeight: 0`; tiled thêm `tiledSidebar: 900`). Đây là đường thật duy nhất để inset ngang tới bố cục regular, thay vì máy tính bảng dọc với inset giả của bản thăm dò. Có test RTL cho tiled; top bar đối xứng nên chỉ một test.
9. **Vị trí test:** nhóm focus nằm trong nhóm `sidebar`; nhóm inset là nhóm riêng đặt ngay trước `side safe area (VK-702)`, không nằm trong nó, vì nhánh S (VK-779) có thể thêm test vào nhóm đó. Code của F cũng tránh các đoạn S sửa trong `liquid_shell.dart`.
10. **VK-777, cách làm đỏ:** đột biến bằng chứng gợi ý (ép `.stacked` trong `SearchMath.style`) và `.integrated` trong `applySearchStyle` đều vẫn xanh trên iPhone 26.5 (UIKit vẫn chọn `inline`). Nên độ đỏ được chứng minh bằng cách đổi tạm ngưỡng của assert (`>= 27` → `>= 26`) trên 26.5; đột biến của bằng chứng vẫn được chạy một lần để ghi vào báo cáo.
11. **VK-777, phạm vi:** assert chỉ đặt trong test scope bar (nơi item yêu cầu), không thêm vào `testTheDebugSnapshotDescribesTheSearchTab`. Chỉ chạy đúng test đó trên 26.5 và 27.0; không chạy cả bộ `RunnerTests`, không chạy 27.1.
12. **VK-700, cách tách:** thêm hai target Make (`goldens-plain`, `goldens-liquid`); `goldens` gọi cả hai với đúng lệnh và thứ tự cũ, nên `make verify` và nhánh 3.44.x không đổi. CI chỉ gọi target Make (một lối vào cho mỗi kiểm tra). Ở nhánh stable: `continue-on-error` cấp bước cho golden liquid, một cảnh báo trong tóm tắt run, và vẫn tải ảnh lỗi lên. Không đụng job `checks`.
13. **VK-700, kiểm tra:** một script Python nhỏ trong scratchpad (không commit) kiểm cấu trúc job, đỏ trên `ci.yaml` cũ, xanh trên cái mới; cộng parse YAML, `actionlint` nếu máy có (máy này không có), `make -n`, và chạy hai nửa golden trên 3.44.6. Nhánh stable với 3.47.7 không chạy lại ở máy (không có 3.47); kết quả suy từ số của bằng chứng.
14. **Tài liệu VK-700:** thêm một gạch đầu dòng và một dòng bảng lệnh trong `CONTRIBUTING.md`; không sửa README hay `doc/` (người đọc pub.dev không thấy CI).
15. **CHANGELOG:** hai dòng "Fix" dưới `## 0.1.0-dev.10` của `liquid_shell`. Không có dòng cho comment, XCTest hay CI. Không sửa câu "focus is not restored" của dev.8 (Q3 giữ nguyên dev.8); dòng mới thay thế nó.
16. **Commit:** Task 3 dùng `docs(shell)` (chỉ comment, ở hai file của gói `liquid_shell`); Task 5 dùng `ci(ci)`.
