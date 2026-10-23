# liquid_shell VK-572: the search controller follows the native field again (with VK-594 and VK-604)

- **Plane:** VK-572 (the main item), VK-594, VK-604 (rows C1, C2 and C9c only).
- **Date:** 2026-10-19
- **Status:** approved. The owner answered the decision tables of the three evidence reports with "ok hết" on 2026-10-19 (table at the end). Plan: `docs/plans/2026-10-19-search-fixes.md`. The choices this spec had to add are listed in "Quyết định phát sinh", after the table.
- **Branch:** `VK-572-search-fixes`, from `origin/main` at `cd6504c`.
- **Kind of change:**
  - Dart in `liquid_shell`: `lib/src/search/shell_search.dart` (VK-572, VK-604 C1) and `lib/src/search/search_layout.dart` (VK-594).
  - Tests: Dart unit and widget tests, one assertion in the example's integration test (VK-594), three XCTests in the example's `RunnerTests` (VK-572, characterization), and one test helper in `segmented_control_test.dart` (VK-604 C9c).
  - Docs: `liquid_shell/doc/search.md`, `liquid_shell/doc/native_chrome.md`, spec P3b §7.5 (`docs/specs/2026-10-10-p3b-search-tab-design.md:493`), `liquid_shell/CHANGELOG.md` under `## 0.1.0-dev.8`.
  - No Swift production code, no Pigeon, no platform-interface change, no public API change, no other package, no version bump.
- **Sources:**
  - The three evidence reports (2026-10-19, kept with the Plane items): VK-572 (probe tests A1–A5 and B1–B11, XCTest on three simulators, a throwaway prototype), VK-594 (measured values on an iPhone 17 Pro and an iPad Air 11-inch (M4), iOS 26.5; the root cause; the one-line fix), and the small-items triage (VK-604 rows C1, C2, C9). The VK-550 final review gives C9's line list.
  - The code at `cd6504c`. Every file:line below was read again there.
  - **Prototype** (2026-10-19, while writing this spec and the plan). The plan's test code and production code ran in this worktree, then were removed:
    - every red-first test was red at `cd6504c` for the reason given in §10, and green with the plan's code;
    - every mutation check of §10 turned the named tests red;
    - XCTests (simulators created for the check, then deleted): the three new tests passed on an iPhone 17 Pro and an iPad Air 11-inch (M4) on iOS 26.5 and an iPhone 17 on iOS 27.0; the evidence's red form and the two Swift mutations were red on the iPhone 26.5; the whole RunnerTests suite (`make ios-unit`) passed on the iPhone 26.5 (190 tests: 172 passed, 18 skipped, 0 failed); on the iPad and on iOS 27.0 only the three new tests ran;
    - the integration assertion was red on the iPhone 17 Pro 26.5 with the old rule (`Expected: a value greater than or equal to <259.0>`, `Actual: <0.0>`), and green with the new one on the iPad and the iPhone, iOS 26.5 (iPhone: keyboard 208, field y 142, bottom 268) and iOS 27.0 (iPhone: keyboard 224, field y 126, bottom 284);
    - the whole `liquid_shell` suite (`+1223`, 21 more than at `cd6504c`) and the tool tests passed, and `make verify` passed with every task applied (`liquid_shell` coverage 97.68 %).

> **Tóm tắt (cho chủ sản phẩm).**
> - **VK-572, lỗi A.** Trên ô tìm native, khi người dùng đang gõ dở bằng bộ gõ có "chữ đánh dấu" (tiếng Nhật, tiếng Trung; Telex của Apple thì không) mà việc tìm bị đóng do app hay shell yêu cầu (`deactivate()`, sang tab khác, hộp thoại đè lên, ẩn chrome, scene nối lại), thì `composing` trong controller cứ ở `true` cho tới lần gõ sau. App làm đúng tài liệu ("xem `composing` trước khi ghi") sẽ không ghi được.
>   - **Sửa (chỉ Dart):** khi ô native thôi active thì `composing` cũng thôi, chữ giữ nguyên. Không gọi `onChanged`, vì chữ không đổi.
>   - Chỉ áp cho ô native. Ô Flutter tự báo việc kết thúc gõ dở của nó như cũ.
> - **VK-572, lỗi B.** Khi chrome native thế chỗ một ô tìm Flutter đang được dùng (đang focus, đã cất bàn phím, hoặc đang gõ dở), controller cứ báo "đang tìm" trong khi UIKit hiện ô tìm rảnh: nút back bị chặn, `deactivate()` không làm gì, shell được push thành trang không pop được.
>   - **Sửa (chỉ Dart):** lúc shell nhả ô Flutter, việc tìm kết thúc (không active, không composing), chữ giữ nguyên, như khi ô Flutter bị ẩn. Người dùng chạm ô native để tìm tiếp.
>   - Có thêm test "native-engage" mà VK-571 còn thiếu. Kiểm tra đột biến: đổi `holdsField` ở `liquid_shell.dart:1189` về `focus.hasFocus` thì các test này đỏ.
>   - Phía Swift: test XCTest đỏ trong bằng chứng chỉ ghi lại hành vi native, hành vi này giữ nguyên. Test Dart là chốt chặn; không sửa code Swift. Ba test XCTest mới (xanh) ghi lại đúng hành vi đó.
> - **VK-594.** iPhone nằm ngang, ô tìm native active, bàn phím lên: inset đáy là 0 (dọc là 399), nên danh sách không cuộn ra khỏi ô tìm và bàn phím.
>   - **Sửa (một dòng Dart):** ô tìm chỉ được coi là ô ở trên cùng khi nó nằm trong vùng an toàn phía trên. Nằm ngang có bàn phím, inset đáy thành 268, cùng quy tắc với dọc. iPad không đổi.
>   - Kiểm tra trên simulator: iPhone và iPad iOS 26.5, và cặp iOS 27.0 cài sẵn ở máy.
> - **VK-604.** C1: khi native báo một scope không còn tồn tại (app vừa bớt scope), Dart gửi lại scope của controller cho native, một lần. C2: thêm một dòng tài liệu "khi bớt scope, app tự kẹp `scopeIndex`". C9c: các vòng lặp trong test segmented control có kiểm tra không rỗng; thêm test đổi scope lúc chạy ở chế độ native.
> - **CHANGELOG:** bốn dòng "Fix" dưới `## 0.1.0-dev.8` của `liquid_shell`. Không nâng phiên bản.

---

## 1. Goal

1. **VK-572 bug A.** Natively, `LiquidSearchValue.composing` ends when the search ends: whatever ends the native search mid-composition leaves the controller inactive and not composing, with its text kept. `onChanged` is not called for that end.
2. **VK-572 bug B.** When native chrome takes over a Flutter search (focused, keyboard-down or composing), the search ends: the controller is inactive and not composing, with its text kept. Back, `deactivate()` and a pushed shell's pop work again. VK-571's missing native-engage test exists and guards `holdsField` (`liquid_shell.dart:1189`).
3. **VK-594.** On an iPhone in landscape, with the native search active and the keyboard up, the bottom content inset clears the raised field and the keyboard, as in portrait: 268 pt on an iPhone 17 Pro (portrait: 399). The iPad is unchanged.
4. **VK-604.**
   - C1: a native scope index past the titles, ignored while the search tab is selected natively, sends the controller's scope back to native, once.
   - C2: `doc/search.md` says the app clamps `scopeIndex` when its scopes shrink.
   - C9c: the tracking loops of `segmented_control_test.dart` assert they are not empty, and one widget test changes `LiquidSearch.scopes` at run time in native mode.

**Success:** the tests of §10 are red before the change for the reason given there and green after it. The mutation checks turn the named tests red. The simulator runs of §10.4 pass.

## 2. Scope

### 2.1 In

- `ShellSearch` (`shell_search.dart`): one helper that ends the search in the controller, used where Dart learns or decides that the native search ended (§4) and where the shell releases the Flutter field under native chrome (§5); the C1 resync (§8.1).
- `nativeSearchBottomInset` (`search_layout.dart:45`): the top-field rule (§7).
- Tests: §10.
- Docs: `doc/search.md` (four places), `doc/native_chrome.md` (one sentence), spec P3b §7.5 (one sentence), `CHANGELOG.md` (four bullets): §11.

### 2.2 Non-goals

- **Any Swift production change.** No native report of the composition's end (VK-572's option A2), no change to `keepOnDismiss`, `restoreKept` or `dismissKeepingText`. The bridge stays one-way, and nothing is written into any field.
- Carrying a Flutter search into native when native takes over (VK-572's option B2: it would raise the keyboard unasked).
- A native placement flag through Pigeon (VK-594's option C), or UIKit's keyboard-only parity (option D).
- The iPad keyboard in the content inset (VK-594's D3): "the keyboard covers the bottom" stays as `doc/search.md:150` documents.
- A code clamp of `scopeIndex` (C2 is doc only).
- VK-604's other rows: C3 to C8, C9a and C9b. C8, C9a and C9b belong to the `VK-651-test-hygiene` branch.
- A version bump. A device check.

## 3. What the evidence shows (file:line at `cd6504c`)

### 3.1 VK-572 bug A: `composing` stays true after a dismissal Dart asked for

Native (`liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/SearchBridge.swift`):

| Line | What |
|---|---|
| 57 | `known`: what Dart was last told (text, composing) |
| 204-211 | `dismissKeepingText()`: `keepOnDismiss = pendingText ?? text`, then `controller.isActive = false`. The field resigns, which commits the marked text |
| 249-263 | `updateSearchResults`, the only place that reports text. Line 252 drops every callback while `keepOnDismiss` is set, so the commit's callback is swallowed |
| 288-303 | `didDismissSearchController`: `restoreKept()` (289), then `onActive(false)` (302). No text report |
| 234-239 | `write()` sets `known = Known(text: new, composing: false)` (236): `composing` is cleared natively without telling Dart |
| 218-223 | For contrast, VK-571's `dismissKeyboard()` reads the field again after the resign, so its commit does reach Dart |

- Callers of `dismissKeepingText` (`NativeTabsController.swift`): 241 (hidden chrome), 262 (a tab structure rebuild), 402 (`select()`: Dart's answer to the user's own tab tap) and 668 (`setSearchActive(false)`: `deactivate()`, a dialog above, back).
- On the tab-tap path native could not report the commit anyway: `canReport()` (81-84) is false once the search tab is no longer selected, and Dart drops text while `!selected` (`shell_search.dart:207`).
- Dart (`liquid_shell/lib/src/search/shell_search.dart`): `LiquidNativeSearchActiveChanged(false)` (216-220), leaving the search tab (271-273) and `replay(reconnect: true)` (164-171) change only `active`. `composing` keeps its old value.
- **Consequence.** `doc/search.md:264-265` tells apps to "check `composing` before writing". Such an app holds its write (a recent search tapped, a reset) although no composition is open, until the user's next edit, across re-activation and across a trip to another tab.
- **Who is affected:** IMEs that mark their text natively (Japanese, Chinese). Apple's Vietnamese Telex never marks its text (`doc/search.md:246-248`).
- **Reproduced:** XCTest red on iPhone 17 Pro and iPad Air 11-inch (M4) on iOS 26.5 and iPhone 17 on iOS 27.0, identical lines (`("かな composing=true") is not equal to ("かな composing=false")` after the dismissal, after re-activation, and after the tab change). Dart probe tests A1–A4 red at `cd6504c`; A5 (a reconnect mid-composition) was named but not written.

### 3.2 VK-572 bug B: native engages over a Flutter search that holds the field

| Line | What |
|---|---|
| `liquid_shell.dart:1795-1797` | `_resolveNative` sets `_search..native = engaged` first |
| `liquid_shell.dart:1186-1191` | `_buildLayout`: `if (_search.holdsField) _search.releaseField();` (1189, VK-571's `holdsField`). On a direct engage `native` is already true here |
| `shell_search.dart:398-410` | `releaseField()`: its doc promises to "end its composition and active state"; its microtask only calls `_onFocus()` |
| `shell_search.dart:484` | `_onFocus`: `if (native) return;` comes before the active update (487-490) |
| `shell_search.dart:432` | `_onEditing`: `if (_writing \|\| native) return;`: the composition's collapse is never reported |
| `shell_search.dart:299-302`, `SearchBridge.swift:207` | `deactivate()` under native → `setSearchActive(false)` → `dismissKeepingText()` guards on `controller.isActive` and returns: native never answers |
| `liquid_shell.dart:853-866` | `PopScope(canPop: … && !searchActive …)`: back calls `_search.deactivate()` |

- **When:** a direct engage, native chrome engaged in the same build that last showed the Flutter field: `nativeChrome` auto → off → auto after the host attached, a forced glass tier lifted, `chromeBuilder` removed, the destinations made describable, or native reporting `installed: false`, then `installed: true` (`NativeShellInstaller.swift:186-188, 216-224`). The first claim goes through *pending* (`liquid_shell.dart:1873-1883`), where line 1189 releases with `native == false`, and works.
- **Consequence:** `isActive` stays true while UIKit shows an idle search; `LiquidPage` keeps its large title hidden; back is blocked and `deactivate()` is a no-op, so a pushed shell cannot pop; a composing Flutter field leaves `composing` true. The user recovers by tapping the native field, then ×.
- **The native-engage test (VK-571 review M-6):** not on `main`. The pending-path test (keyboard-down, first claim) is green at `cd6504c` and red when line 1189 is reverted to `focus.hasFocus`. The direct-engage tests (keyboard-down, auto → off → auto; keyboard-down, late install) are red at `cd6504c` because of bug B; with the fix they go green, and red again under the same mutation.
- **Provenance of the gates:** `shell_search.dart:432/484` (VK-407, 6482fbf). VK-571 (6d542ae) only widened the window, with the keyboard-down state.

### 3.3 VK-594: the iPhone landscape inset

Measured on an iPhone 17 Pro, iOS 26.5, native search active, keyboard up:

| | Portrait | Landscape |
|---|---|---|
| View | 402×874 | 874×402 |
| `MediaQuery.padding` | T106 B0 | L62 T68 R62 B0 |
| Keyboard (`viewInsets.bottom`) | 335 | 208 (top 194) |
| Native field | 8,483 330×48 (centre 507 > 437) | **80,142 662×44 (centre 164 < 201)** |
| `chromeInsets` / `contentPaddingOf().bottom` | 399 / 399 | **0 / 0** |

- **Root cause:** `nativeSearchBottomInset` (`liquid_shell/lib/src/search/search_layout.dart:38-52`), line 45: `if (field.isEmpty || field.center.dy < size.height / 2) return 0;`. The rule (spec P3b §7.5, `docs/specs/2026-10-10-p3b-search-tab-design.md:493`) meant "skip the iPad's stacked top field". In landscape the 208 pt keyboard lifts the iPhone's field above the midline, so the early return also drops the keyboard term.
- Native is right: it publishes the field frame (`NativeTabsController.swift:811-818, 833`), and Dart folds it in at `liquid_shell.dart:1890-1903`.
- **The broken contract:** spec P3b A3 ("`chromeInsets` covers the field in every state", `:52`) and `doc/native_chrome.md:208-211` ("on iPhone the bottom inset follows the field above the keyboard").
- **Mitigated:** the first user drag puts the keyboard away (VK-571), and the inset is then 64 and right. It shows at rest, with `dismissKeyboardOnDrag: false`, and on programmatic scrolls.
- **The scratch fix** (`field.bottom <= padding.top + 1`) measured: landscape 0 → 268; portrait 399, landscape keyboard-down 64 and iPad T134 B0 unchanged. One unit fixture failed: `test/unit/search_test.dart:376` pairs a top field (16,86 370×44, bottom 130) with a 62 pt top padding, which no device produces (iPad: field bottom 82 under a 134 pt top padding; selected, 131 under 146).
- iPad: the stacked field is at the top in both orientations (VK-550 measured iPad landscape at y 39). Plus/Max/Air iPhones and iOS 27 (field at y 126) fail the old rule the same way (inferred, not measured).

### 3.4 VK-604 C1, C2, C9c

- **C1** (`shell_search.dart:223-238`): the ignore branch (`index >= count`, 228-234) returns and resyncs nothing. A user tap on the old last scope, in flight while the app shortens `LiquidSearch.scopes`: Dart ignores the index; native's bar shows the tap, and `setScopes` then selects native's `knownScope` (the tapped index) clamped to the new titles (`SearchBridge.swift:92-102, 121-128`), while the controller keeps its own index. They disagree until the tab is entered again or the scene reconnects. Native's `setScope` (`SearchBridge.swift:114-117`) never reports (`writing`, and a programmatic selection does not call the delegate), so a resync is no echo.
- **C2:** `scopeIndex` is never clamped (`search_controller.dart:168-171`); `scope_bar.dart:57` clamps for display only. `doc/search.md:118-122` does not say what happens when scopes shrink.
- **C9c** (VK-550 final review, C9):
  - "The tracking test loops at `segmented_control_test.dart:1002,1023,1035` have no non-empty assertion." At `cd6504c` the loops over the `styles()` helper (`:967-970`) are at 1002, 1023, 1035, 1039 and 1059. Only the test at 980 asserts the count (`hasLength(6)`, 981).
  - "No Dart widget test changes `LiquidSearch.scopes` at run time in native mode."

## 4. Design: VK-572 bug A, the composition ends with the native search

**Rule.** Natively, `composing` follows `active`: wherever Dart learns or decides that the native search ended, the controller becomes `active: false, composing: false`, with its text kept. It rests on UIKit's rule that a field that resigns first responder commits its marked text, which VK-571's `dismissKeyboard` already relies on.

**One helper**, `ShellSearch._endSearch(LiquidSearchController controller)`:

```dart
void _endSearch(LiquidSearchController controller) {
  final value = controller.value;
  final composing = !native && value.composing;
  if (!value.active && value.composing == composing) return;
  applySearchEdit(
    controller,
    value.copyWith(active: false, composing: composing),
  );
}
```

- **Natively** it ends both. **In Flutter mode** it ends only `active`, as each site does today: the Flutter field reports its own composition end when it lets go (`_onFocus`'s collapse, then `_onEditing`, which also calls `onChanged`). An unconditional clear would run first (post-frame, before the field's microtasks) and take that report away: the prototype's guard test R3 went red with it. See "Quyết định phát sinh" 1.
- It never calls `onChanged`: the text did not change, and the `onChanged` doc says "every text change the user makes". `ValueListenable` listeners see `composing: false`.

**Where it is called (bug A):**

| Site | Today | With VK-572 |
|---|---|---|
| `onNativeEvent`, `LiquidNativeSearchActiveChanged` (216-220) | `next = active && selected`; only `active` changes | `!active \|\| !selected` → `_endSearch`; otherwise `active: true` if it is not yet. `composing` is never touched by an active report |
| `afterConfigSent`, leaving the search tab (271-273) | `if (left && controller.isActive)` → `active: false` | `if (left) _endSearch(controller)`: natively the composition ends at Dart's own decision, before native's `searchActive false` arrives |
| `replay(reconnect: true)` (164-171) | `active: false` | `_endSearch(controller)`: the new field has no composition |

- **Not changed:** a composition end that native reports itself (`LiquidNativeSearchTextChanged` with the same text and `composing: false`, 206-215, for example VK-571's resign) still calls `onChanged`, as today. That path is an edit native saw; the owner kept it (decision 3 of the VK-572 report).
- **Timing.** For a `deactivate()`, a dialog above or hidden chrome, `composing` ends when native's `searchActive false` arrives, after UIKit's dismissal (up to about 0.7 s). For the tab tap it ends with Dart's own selection.
- **IME safety.** Nothing is written into any field, nothing is sent to native, and no focused field is rebuilt: only the controller's value changes.

## 5. Design: VK-572 bug B, a native takeover ends the Flutter search

**Rule.** When native chrome takes over while the Flutter field holds the search, the search ends, its text kept, as Flutter mode ends it for hidden chrome or a size-class change. Native is told so too (`setSearchActive(active: false)`, added in ee98009): the takeover must not leave native active.

**Change:** `releaseField()` keeps its promise in both modes. Its microtask, after `_onFocus()`, calls `_endSearch(controller)` and tells native the search is inactive when `native` is true:

```dart
void releaseField() {
  _keyboardDown = false;
  focus.unfocus();
  scheduleMicrotask(() {
    if (_disposed) return;
    _onFocus();
    final controller = _controller;
    if (native && controller != null) {
      _endSearch(controller);
      claim()?.setSearchActive(active: false);
    }
  });
}
```

- The `setSearchActive(active: false)` call runs on every takeover, also when native is already inactive. That is safe: native ignores it then (XCTest `testDeactivatingAnInactiveSearchSendsNothing`). Do not remove it as redundant: test B12 fails without it.

- The gates `if (native) return;` (`_onFocus`, 484) and `if (_writing || native) return;` (`_onEditing`, 432) stay as they are for ordinary events: under native they keep the Flutter field's leftovers away from the controller.
- In Flutter mode (`releaseField` at `liquid_shell.dart:1246-1247`) nothing changes: `native` is false.
- On the pending path (first claim) `native` is still false when the microtask runs, and `_onFocus` ends the search as today.
- The Flutter field is already out of the tree. `_onFocus` still collapses its composition (existing code), and `_onEditing` ignores that under native. When Flutter chrome comes back, the field gets the controller's text, as today (the `native` setter, 83-92). Nothing is written into a composing field.
- The user resumes by tapping the native field: the text is there (sent on the native entry by `afterConfigSent`).

## 6. The native side: no Swift change

- The evidence's red XCTest (the dismissal mid-composition should report `composing=false` to Dart) documents native behaviour that **stays unchanged**: native does not report the commit after a dismissal Dart asked for. A Dart-only fix cannot turn it green, so it is not committed in that form.
- **The Dart tests are the guard** (§10.1). No Swift production change is made.
- **Three characterization XCTests** (green, in `RunnerTests`, `NativeTabsTests`) pin the native behaviour Dart's rules rest on:
  1. a `deactivate` mid-composition (`setSearchActive(false)`) ends in `searchActive false`, the composed text kept, and the last text report Dart got is still `composing=true`;
  2. the same through the user's tab tap (`apply(searchConfig(selected: 0))`);
  3. `setSearchActive(false)` on a search that is not active sends nothing (bug B's premise: native never answers, so Dart ends a takeover by itself).
- Tests 1 and 2 are the evidence's probe with its last assertion turned around: they say what native does, not what it should do. If native ever reports the commit, these tests and `_endSearch`'s rule change together; their doc comments say so.
- They sit in the P3b-1 search extension of `RunnerTests.swift`, after `testDismissingTheKeyboardWithoutAnActiveSearchDoesNothing`, with two helpers (`lastTextReport()`, `composingSearch()`).

## 7. Design: VK-594, a top field is one inside the top safe area

**Rule** (owner: keep "clear the field"; a geometric rule in Dart). A field counts as the stacked top field only if it lies inside the top safe area:

```dart
if (field.isEmpty || field.bottom <= padding.top + 1) return 0;
```

- It replaces "the field's centre is in the upper half" at `search_layout.dart:45`. The rest of the function is unchanged: inactive, `padding.bottom`; active, `max(padding.bottom, size.height − field.top, viewInsets.bottom + field.height + 16)`.
- **Values** (measured inputs): iPhone 17 Pro landscape, keyboard up: `max(0, 402 − 142, 208 + 44 + 16)` = **268**. Portrait stays 399. Landscape with the keyboard down (VK-571): `max(64, 402 − 338, 60)` = 64. iPad active (field bottom 82, top padding 134) and selected (131, 146): 0.
- `+ 1` absorbs sub-point rounding between UIKit's frame and Flutter's padding.
- It states what the old rule meant ("a stacked field at the top is already in the top safe area") and does not depend on the orientation or on the keyboard.
- The iPad is unchanged, as is the Flutter search path (it does not use this function).
- The function's doc comment, spec P3b §7.5 and the docs say "in either orientation" (§11).

## 8. Design: VK-604

### 8.1 C1: native gets the controller's scope back

In `onNativeEvent`'s `LiquidNativeSearchScopeChanged` case:

```dart
if (!selected || index < 0 || index == controller.scopeIndex) return;
if (index >= (_config?.scopes?.length ?? 0)) {
  if (native) claim()?.setSearchScope(controller.scopeIndex);
  return;
}
applySearchEdit(controller, controller.value.copyWith(scopeIndex: index));
```

- Only an index past the titles, while the search tab is selected and native, resyncs. A negative index, another tab and Flutter mode stay ignored and send nothing, as today.
- An index equal to the controller's is no change and sends nothing, even past the titles: native's `knownScope` then already equals Dart's.
- Native's `setScope` sets `knownScope` and selects it clamped, whether it arrives before or after the config with the new titles (`setScopes` selects `knownScope` again). It never reports, so the call count stays one.

### 8.2 C2: doc only

One bullet in `doc/search.md`'s Scopes section, after "One way": the shell never clamps `scopeIndex`; when the scopes shrink below it, the app clamps it in the same change (an app action, so it moves the native bar once). Both bars show the last scope meanwhile, but a filter on the stale index would use a scope that is gone.

### 8.3 C9c: non-empty loops and a run-time scopes test

- `segmented_control_test.dart`: the `styles()` helper (`:967-970`) asserts `hasLength(6)` (three segments, normal and selected rows) before it returns. That covers every loop over it: 1002, 1023 and 1035, which the review names, and 1039 and 1059, which use the same helper. A loop over nothing can no longer pass.
- `native_search_test.dart`, VK-550 group: the app changes `LiquidSearch.scopes` at run time (three titles, then two) in native mode. The config carries the new titles, `LiquidShellScopeData.searchScopes` follows, `nativeSearchScopes` stays true, and Flutter draws no bar.
- The C1 test reuses the same setup: after the titles shrink, a native `LiquidNativeSearchScopeChanged(2)` leaves `scopeIndex` at 0 and sends `setNativeSearchScope(0)` once.

## 9. Pinned names

| What | Name |
|---|---|
| Helper (`ShellSearch`, private) | `void _endSearch(LiquidSearchController controller)` |
| Dart test groups (`native_search_test.dart`) | `VK-572: the native composition ends with the search`; `VK-572: native takes over a Flutter search`; the VK-604 tests inside `VK-550: the native scope bar` |
| Dart test names | A1, A2/A4, A3, A5, R1, R2, R3 (bug A); B2, B5–B12 (bug B; B12 added with ee98009), as in the plan |
| XCTests (`NativeTabsTests`) | `testADeactivateMidCompositionEndsInactiveWithNoCommitReport`, `testATabChangeMidCompositionEndsInactiveWithNoCommitReport`, `testDeactivatingAnInactiveSearchSendsNothing`; helpers `lastTextReport()`, `composingSearch()` |
| Unit tests (`search_test.dart`, `nativeSearchBottomInset`) | `no field: nothing`; `the stacked field inside the top safe area: nothing`; `landscape, keyboard up: the raised field counts`; `landscape, keyboard down (VK-571): down to the field top` |
| Widget test (VK-594) | `landscape: the raised field still moves the bottom inset` |
| Public API | none new, none changed |

## 10. Test strategy

### 10.1 Dart, red first (`liquid_shell`, `fvm flutter test`)

All widget tests use the fake native platform (`installFakeNative`) and the shell harness (`pumpShell`, `TestShell`).

**Bug A** (`test/widget/native_search_test.dart`, new group). A composing native search: `searchActive true`, then `searchText かな` with `composing: true`.

| Test | At `cd6504c` | Why |
|---|---|---|
| A1: `deactivate()`, native answers `searchActive false` only | red: `composing` `Expected: false Actual: <true>` | site 216-220 changes only `active` |
| A3: an app write that checks `composing` lands | red: `Expected: ['phở'] Actual: []` | the consequence of A1 |
| A2, A4: the user taps another tab; checked before native's report, after it, and back on the search tab | red: `composing` `Expected: false Actual: <true>` | site 271-273 changes only `active` |
| A5: a scene reconnect (the same state pushed again) | red: `composing` `Expected: false Actual: <true>` | site 164-171 changes only `active` |
| R1: `searchActive true` keeps the composition | green, stays green | an active report never clears `composing` |
| R2: a composition end native reports calls `onChanged` | green, stays green | the owner kept that path |
| R3: Flutter mode (not installed, the shell's claim), the user leaves the tab mid-composition: the field reports its own end, `onChanged(かな)` | green, stays green | the Flutter path is unchanged (§4) |

A1–A5 also assert that `onChanged` is not called and that the text is kept.

**Bug B** (`test/widget/native_search_test.dart`, new group). Three ways in: *pending* (off, then auto, first claim), *via off* (auto, off, then auto: a direct engage) and *late install* (`installed: false`, then `installed: true` pushed).

| Test | At `cd6504c` | Why |
|---|---|---|
| B2: keyboard-down, pending | green | `native` is false on the pending path; the `holdsField` guard |
| B5: focused, via off | red: `isActive` `Expected: false Actual: <true>` | `_onFocus` returns under native |
| B6: keyboard-down, via off (VK-571 native-engage) | red, as B5 | as B5 |
| B7: focused, late install | red, as B5 | as B5 |
| B8: keyboard-down, late install (VK-571 native-engage) | red, as B5 | as B5 |
| B9: composing, late install: inactive, text kept, not composing | red, as B5 | as B5, and `_onEditing` returns under native |
| B10: `deactivate()` after a late install leaves the search inactive | red, as B5 | native never answers (the fake never does either) |
| B11: a shell pushed as a page pops with one back after a late install | red: `Found 0 widgets with text "The list"`, reason `back blocked: sent [false], isActive true` | `PopScope` blocks while `isActive` |

**VK-594** (`test/unit/search_test.dart`, group `nativeSearchBottomInset`; `test/widget/native_search_test.dart`):

| Test | At `cd6504c` | Note |
|---|---|---|
| landscape, keyboard up: 268 | red: `Expected: <268> Actual: <0.0>` | the evidence's decisive unit test |
| widget: landscape (874×402, padding L62 T68 R62, keyboard 208, field 80,142 662×44): `contentPaddingOf().bottom == 268` | red: `Expected: <268> Actual: <0.0>` | pins the wiring at `liquid_shell.dart:1890-1903` |
| the stacked field inside the top safe area (iPad active and selected, measured) | green both | replaces the unreal fixture of `:376` |
| no field | green both | split from the old test |
| landscape, keyboard down: 64 | green both | |
| portrait settled (392), keyboard rising (264), selected (83) | unchanged, green | |

**VK-604** (`test/widget/native_search_test.dart`, VK-550 group; `test/widget/segmented_control_test.dart`):

| Test | At `cd6504c` | Note |
|---|---|---|
| C1: an index past the new titles sends the controller's scope back once | red: `Expected: [0] Actual: []` | |
| C9c: scopes changed at run time reach native | green (a locker) | red under a mutation, below |
| C9c: `styles()` asserts six labels | the four tests stay green | red under a mutation, below |

### 10.2 Mutation checks (run, pasted into the task reports, never committed)

| Mutation | Must go red |
|---|---|
| `liquid_shell.dart:1189` `holdsField` → `focus.hasFocus` (with the bug B fix) | B2, B6, B8 (`isActive` `Expected: false Actual: <true>`); B5 and B7 stay green |
| site 1 (`LiquidNativeSearchActiveChanged`) back to the active-only code | A1, A3 |
| site 2 (leaving the tab) back to the active-only code | A2/A4 |
| site 3 (`replay`) back to the active-only code | A5 |
| `_endSearch` clears `composing` in both modes | R3 (`Expected: ['かな'] Actual: []`) |
| `LiquidNativeSearchConfig.==` ignores `scopes` (`liquid_shell_platform_interface/lib/src/native_chrome.dart:270`) | the run-time scopes test (`Actual: ['All', 'Songs', 'Places']`) |
| `styles()` reads rows under keys nobody draws | before C9c: three of the four tests pass on nothing (`+3 -1`); after: all four red (`Expected: an object with length of <6> Actual: []`) |
| the XCTests: `didDismissSearchController` without its final `onActive(false)` | the two dismissal tests (`no searchActive false within 10 s`) |
| the XCTests: `dismissKeepingText` answers `onActive(false)` when inactive | `testDeactivatingAnInactiveSearchSendsNothing` |

### 10.3 Unchanged, still green

`search_fallback_test.dart` (Flutter mode), `unit/shell_search_test.dart` (its "an index past the last scope … is ignored" stays true: the controller keeps its index), `pushed_shell_back_test.dart`, `search_morph_test.dart`, `native_chrome_test.dart`, and the rest of the `liquid_shell` suite.

### 10.4 Simulators

Each task that needs one creates its own simulators with `xcrun simctl create` and deletes them at the end, also on failure. Never a physical device, never `simctl shutdown all`.

| Task | Command | Simulators |
|---|---|---|
| XCTests (VK-572) | `tool/ios_xctest.sh` with `-only-testing` for the three tests (and the mutations), then `make ios-unit IOS_UNIT_DEVICE=<udid>` | iPhone 17 Pro, iOS 26.5; iPad Air 11-inch (M4), iOS 26.5; iPhone 17, iOS 27.0 |
| Integration (VK-594) | `NATIVE_DEVICES="<udid>=true" NATIVE_TARGETS=native_search_test.dart make integration-ios-native` | iPhone 17 Pro and iPad Air 11-inch (M4), iOS 26.5; the same pair on iOS 27.0 (installed locally; 27.1 not run) |

- **The integration assertion** goes into the iPhone-only landscape block of `VK-550: the native scope bar, over the results, follows the app` (`example/integration_test/native_search_test.dart:306-318`), the landscape twin of the portrait check at `:163`: the keyboard is up, and `contentPaddingOf(...).bottom >= size.height − field.y − 1`.
- **Its red** is shown on the iPhone 26.5 with `search_layout.dart:45` temporarily back to the half rule (`Expected: a value greater than or equal to <259.0> Actual: <0.0>`), then green with the fix. The iPad runs unchanged assertions.
- XCUITest is not needed: no UI change, and XCUITest cannot type marked text.
- `make verify` (format, analyze, provenance, Pigeon, tests, Impeller tests, coverage ≥ 90 %, goldens, snippets) runs before the PR.

## 11. Docs and CHANGELOG wording

**`liquid_shell/doc/search.md`:**
- after "or check `composing` before writing." (`:265`), a paragraph: natively `composing` ends with the search (`deactivate()`, another tab, a dialog or page above, hidden chrome, a reconnected scene): the field resigns and commits its marked text, and the controller reads `active` and `composing` false with the text kept; `onChanged` is not called for it, while a commit the field reports itself is an edit and calls it;
- "The controller is the truth": a bullet **Native chrome takes over**: the search ends as when the Flutter field hides, `active` and `composing` false, the text kept; a tap on the native field resumes it;
- the Insets table: "iPhone, native, `active` (above the keyboard, in either orientation)";
- Scopes, after "One way": a bullet **Fewer scopes** (§8.2).

**`liquid_shell/doc/native_chrome.md:208-211`:** "on iPhone the bottom inset follows the field above the keyboard, in either orientation; on iPad …".

**Spec P3b §7.5 (`:493`):** the rule sentence becomes the §7 rule, with a note that VK-594 replaced the half-of-the-view rule.

**`liquid_shell/CHANGELOG.md`**, four bullets at the end of the existing `## 0.1.0-dev.8` section, in task order:

```markdown
- **Fix (VK-572).** With native chrome, `LiquidSearchValue.composing` now
  ends with the native search. A dismissal mid-composition that the app or
  the shell asked for (`deactivate()`, another tab, a dialog above, hidden
  chrome) or a reconnected scene left it true until the user's next edit,
  so an app that checks `composing` before writing held its write. It
  affects IMEs that mark their text (Japanese, Chinese), not Apple's
  Vietnamese Telex. `onChanged` is not called for it: the text did not
  change.
- **Fix (VK-572).** When native chrome takes over while the Flutter field
  holds the search (focused, its keyboard put away, or composing), for
  example `nativeChrome` back to `auto` or a late native install, the
  search now ends with its text kept, as it does when the Flutter field
  hides. Before, `isActive` (and `composing`) stayed true while UIKit
  showed an idle search: system back was blocked, `deactivate()` did
  nothing, and a shell pushed as a page could not be popped.
- **Fix (VK-594).** iPhone with native chrome, in landscape, search active
  with the keyboard up: `chromeInsets.bottom` and
  `LiquidShellScope.contentPaddingOf(context).bottom` were 0, so the
  results could not scroll clear of the field and the keyboard. They now
  cover the raised field, as in portrait (268 pt on an iPhone 17 Pro). The
  iPad is unchanged.
- **Fix (VK-604).** Native scope bar: a user tap on a scope that the app
  removed at the same moment no longer leaves the bar and
  `LiquidSearchController.scopeIndex` on different scopes: the shell sends
  the controller's scope back to native. `doc/search.md` now says that the
  app clamps `scopeIndex` when its scopes shrink.
```

No other package changes, so no other CHANGELOG. Tests alone (the XCTests, C9c's helper) get no entry.

## 12. Risks

| Risk | Handling |
|---|---|
| Dart infers the composition's end; native does not report it | It rests on UIKit's commit-on-resign rule, which VK-571 already relies on. The XCTests pin what native does today; a native change to it breaks them on purpose (§6) |
| For a `deactivate()`, a dialog or hidden chrome, `composing` ends at `didDismiss` (≤ 0.7 s after the ask), not at once | The controller is then consistent with native's own state. An app write in that window is held, as during any composition |
| **Not covered:** `deactivate()` then `activate()` within the dismissal's animation, mid-composition. Native then sends no `searchActive false` (`activateAfterDismiss`, `SearchBridge.swift:290-298`), so `composing` stays true until the next edit | Rare, and outside the approved rule (Dart only acts on "inactive"). Recorded, not fixed ("Quyết định phát sinh" 3) |
| A native takeover ends a search the user was in | The owner's choice (VK-572 decision 4). The text stays; one tap on the native field resumes. These transitions are rare (§3.2) |
| `_endSearch` behaves differently by mode | By design (§4); R3 pins the Flutter side, A1–A5 the native side |
| VK-594's rule relies on UIKit keeping the stacked field inside the top safe area | True in every measured state (iPad selected and active, iPad landscape in VK-550). A future placement that breaks it would need option C (a native flag) |
| An app that removes the top padding above the shell (`SafeArea` or `MediaQuery.removePadding` around `LiquidShell`) would make an iPad's stacked field count as a bottom field | Outside the supported setup: native chrome sets the Flutter view's safe area itself and expects the shell to get it. Not changed here |
| Plus/Max/Air iPhones and a hardware keyboard: inferred, not measured | iOS 27.0 was measured while the plan was checked (iPhone 17 Pro: field y 126, keyboard 224, bottom 284). The integration assertion runs on CI's iOS 27 leg too (non-blocking) |
| C1's resync races a later user tap | The resync carries the controller's index at the time of the ignored event; a later user tap reports again and wins, as any user change does |
| Merge overlap with the parallel branches | `VK-651-test-hygiene` edits `RunnerTests.swift` near line 2849 and segment tests: this branch adds its XCTests after line 2433, in another extension, and edits only `segmented_control_test.dart`'s `styles()` helper. `VK-593-nested-back` edits back/navigator files and `window_controls`: not touched here |

## 13. Process

- **Tasks, in order** (the plan): VK-572 bug A; VK-572 bug B; the VK-572 XCTests; VK-594 rule, unit and widget tests, docs; the VK-594 integration assertion; VK-604. Bug A comes first because it adds `_endSearch`, which bug B reuses; VK-604 comes last because it edits `shell_search.dart` after VK-572.
- **Commits:** `<type>(<scope>): <summary> (VK-NNN)`, each naming its own item; `fix(shell)` for the Dart fixes, `test(example)` for the XCTests and the integration assertion. Each message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Run `bash .githooks/pre-commit` by hand before each commit. Never `--no-verify`, never a git or flutter config change.
- CHANGELOG under the existing `## 0.1.0-dev.8`; no version bump.
- No push, no PR, no remote change in the tasks.
- Simulators: §10.4.

## Quyết định cần chủ sản phẩm xác nhận

Chủ sản phẩm đã trả lời "ok hết" ngày 2026-10-19, nên mọi mục dưới đây đã được chốt.

| Q# | Câu hỏi | Đã chốt |
|---|---|---|
| VK-572 D1 | Phạm vi | Sửa cả lỗi A (composing native còn `true` sau khi Dart yêu cầu đóng lúc đang gõ dở) và lỗi B (native thế chỗ ô tìm Flutter, controller còn active và composing, back bị chặn), trên một nhánh |
| VK-572 D2 | Sửa lỗi A ở đâu | Chỉ Dart, trong `shell_search.dart`: native thôi active thì `composing` cũng thôi ("composing theo active"). Không sửa Swift, không ghi gì vào ô nào, cầu nối vẫn một chiều |
| VK-572 D3 | Kết thúc composition suy ra có gọi `onChanged` không | Không, vì chữ không đổi. Ghi chú: kết thúc do native *báo* với cùng chữ vẫn gọi nó (`shell_search.dart:209-215`); giữ nguyên |
| VK-572 D4 | Native thế chỗ một tìm kiếm Flutter | Kết thúc nó (không active, giữ chữ), như chế độ Flutter làm khi chrome bị ẩn. `releaseField()` kết thúc active và composing phía Dart khi native thế chỗ |
| VK-572 test | Test native-engage và XCTest | Thêm test native-engage của VK-571 (B6/B8) và ghi lại kiểm tra đột biến (`holdsField` ở ~1189 về `focus.hasFocus` thì đỏ). XCTest đỏ của bằng chứng chỉ ghi lại hành vi native không đổi: nói rõ điều đó; test Dart là chốt chặn; không sửa code Swift |
| VK-594 D1 | Hợp đồng cho ô tìm iPhone đã nâng | Giữ "che hết ô tìm": nằm ngang có bàn phím, inset đáy 268, như dọc (399) |
| VK-594 D2 | Quy tắc hình học trong Dart hay cờ native qua Pigeon | Quy tắc Dart: ô tìm chỉ là ô trên cùng khi nằm trong vùng an toàn phía trên |
| VK-594 D3 | iPad | Không đổi ("bàn phím che phần đáy", như `doc/search.md`) |
| VK-594 D4 | Kiểm tra | Chỉ simulator: unit, cập nhật fixture, widget test tuỳ chọn, assertion tích hợp iPhone nằm ngang (`make integration-ios-native`, iPhone và iPad 26.5; cả 27.x nếu máy có runtime). Sửa `doc/native_chrome.md` ("in either orientation") và câu của spec P3b |
| VK-604 C1 | Chỉ số scope native bị bỏ qua | Khi bỏ qua vì `index >= count` lúc đang chọn tab tìm và ở chế độ native: gửi lại `setSearchScope(controller.scopeIndex)`. Widget test với đếm số lần gọi trên platform giả |
| VK-604 C2 | `scopeIndex` khi bớt scope | Chỉ tài liệu: một dòng trong `doc/search.md` "khi bớt scope, app tự kẹp `scopeIndex`" |
| VK-604 C9c | Vệ sinh test | Kiểm tra không rỗng cho các vòng lặp bằng chứng nêu; một widget test đổi scope lúc chạy ở chế độ native (đi cặp với C1) |
| CHANGELOG | Ghi ở đâu | Dưới `## 0.1.0-dev.8` sẵn có của `liquid_shell/CHANGELOG.md` (và của gói khác nếu có sửa). Không nâng phiên bản |

### Quyết định phát sinh

Bảng trên không nói tới những điểm dưới đây. Spec chọn như sau, chủ sản phẩm có thể đổi:

1. **"Composing theo active" chỉ áp cho ô native** (`_endSearch` chỉ xoá `composing` khi `native`). Ở chế độ Flutter, các chỗ đó vẫn chỉ đổi `active` như cũ, vì ô Flutter tự báo việc kết thúc gõ dở (kèm `onChanged`). Xoá ở cả hai chế độ sẽ chạy trước và lấy mất lần báo đó: test R3 đỏ khi thử.
2. **Một hàm `_endSearch` dùng chung cho bốn chỗ** (báo inactive của native, rời tab tìm, scene nối lại, nhả ô Flutter khi native thế chỗ), thay vì sửa từng chỗ riêng. Lý do: một quy tắc, một chỗ viết.
3. **Không xử lý trường hợp `deactivate()` rồi `activate()` ngay trong lúc UIKit đang đóng** (đang gõ dở): native khi đó không gửi `searchActive false`, nên `composing` còn `true` tới lần gõ sau. Ngoài quy tắc đã duyệt (Dart chỉ dựa vào "inactive"), rất hiếm; ghi ở mục Rủi ro.
4. **XCTest:** không commit bản đỏ của bằng chứng (nó sẽ đỏ mãi vì không sửa Swift). Commit ba test xanh ghi lại hành vi native: đóng giữa lúc gõ dở thì kết thúc bằng `searchActive false`, giữ chữ, và không báo việc commit; `deactivate` một ô không active thì không gửi gì. Đặt sau các test VK-571 (khoảng dòng 2433), xa chỗ nhánh VK-651 sửa (dòng 2849).
5. **Test lỗi B:** thêm B2 (đường pending, xanh từ trước, chốt `holdsField`) và B5–B11. Không thêm B1, B3, B4 của bản thăm dò: test sẵn có "native takes over a focused, composing Flutter field" đã phủ đường pending. B11 chỉ bấm back một lần: sau khi sửa, tìm kiếm không còn active, nên lần back đầu pop luôn.
6. **Test lỗi A:** A2 và A4 gộp thành một test (kiểm tra trước khi native báo, sau khi báo, và khi quay lại tab tìm); A5 (scene nối lại) được viết mới; thêm R2 (kết thúc do native báo vẫn gọi `onChanged`) và R3 (chế độ Flutter giữ nguyên).
7. **VK-594:** sửa thêm dòng bảng Insets của `doc/search.md` ("in either orientation") cho khớp với `doc/native_chrome.md`. Fixture cũ không thật (`search_test.dart:376`) được thay bằng số đo iPad (active và selected).
8. **VK-594 trên iOS 27:** chạy cặp iPhone 17 Pro và iPad Air 11-inch (M4) trên iOS 27.0 (cài sẵn ở máy); không chạy 27.1.
9. **C1:** chỉ số bằng chỉ số của controller thì coi là "không đổi", không gửi gì, kể cả khi vượt số scope. Chỉ gửi lại khi native và đang chọn tab tìm. Test unit sẵn có "an index past the last scope … is ignored" giữ nguyên (vẫn đúng); test mới là widget test.
10. **C9c:** kiểm tra số lượng đặt trong hàm `styles()`, nên phủ cả năm vòng lặp dùng nó (1002, 1023, 1035 như review nêu, và 1039, 1059). Dùng `hasLength(6)` như test ở dòng 981, thay vì chỉ "không rỗng". Vòng lặp ở dòng 942 (không qua `styles()`, review không nêu) giữ nguyên.
11. **Test đổi scope lúc chạy:** từ ba scope xuống hai. Vì nó xanh ngay từ đầu, độ đỏ được chứng minh bằng đột biến tạm ở `LiquidNativeSearchConfig.==` (bỏ qua `scopes`).
12. **CHANGELOG:** bốn dòng "Fix", mỗi bản sửa một dòng, chỉ trong `liquid_shell` (không gói nào khác đổi). XCTest và sửa test không có dòng riêng.
13. **Thứ tự task:** VK-572 lỗi A, lỗi B, XCTest; VK-594 quy tắc và tài liệu, rồi assertion tích hợp; VK-604 cuối cùng (sửa `shell_search.dart` sau VK-572).
