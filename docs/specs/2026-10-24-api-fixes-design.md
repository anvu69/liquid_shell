# liquid_shell VK-702: seven pre-release API fixes

- **Plane:** VK-702.
- **Date:** 2026-10-24
- **Status:** approved. The owner approved all seven items (M1, M2, M3, M5, M10, M11, M12) with the scope of §4 on 2026-10-24 (§7). Plan: `docs/plans/2026-10-24-api-fixes.md`.
- **Branch:** `VK-702-api-fixes`, from `origin/main` at `7ff7bf3`.
- **Kind of change:**
  - Dart in `liquid_shell` (`lib/src/glass/renderer.dart`, `lib/src/glass/signals_controller.dart`, `lib/src/shell/liquid_shell.dart`, `lib/src/search/search_layout.dart`), its tests and test helpers, `CHANGELOG.md` (`## 0.1.0-dev.8`).
  - Dart in `liquid_shell_platform_interface` (`lib/src/event_channel_platform.dart`), its test, `CHANGELOG.md`.
  - Kotlin in `liquid_shell_android` (`Attempt.kt`, `LiquidShellPlugin.kt`), one new JVM test, `CHANGELOG.md`.
  - No public API change, no Pigeon, no Swift, no version bump, no golden change.
- **Sources:** the VK-702 investigation of 2026-10-24 on `7ff7bf3`; prototypes of every red test and fix run in this worktree on `7ff7bf3` for this spec, then removed (§6).

> **Tóm tắt (cho chủ sản phẩm).** Bảy lỗi nhỏ trước khi phát hành, mỗi lỗi một task, một commit:
> - **M5.** Đánh dấu `LiquidGlassRenderer` là `@immutable`. Không đổi hành vi. Một renderer giả trong test có constructor không `const` (cố ý) nên cần một dòng `// ignore:` có lý do.
> - **M12.** Một platform bên thứ ba mà `watchSignals()` ném lỗi ngay lập tức không còn làm sập kính: bắt lỗi, ghi log một lần (debug), dùng "không tín hiệu".
> - **M3 (Android).** Lưu observer trước khi đăng ký, để đăng ký dở dang vẫn gỡ được. Tách một hàm nhỏ `registerAll` để test được trên JVM (`make android-unit`).
> - **M2.** Khi sidebar dạng overlay đang mở: nội dung phía sau (trang và thanh tab trên cùng) không nhận focus bàn phím, phím Escape đóng sidebar. **Ngoại lệ:** ô tìm đang hoạt động phía sau vẫn giữ focus (nếu không, mở sidebar sẽ kết thúc tìm kiếm, trái với thứ tự back của VK-774); Escape trong ô tìm vẫn kết thúc tìm kiếm như trước (§4.4, §8).
> - **M10.** Thanh tab và hàng tìm kiếm tránh vùng an toàn hai bên (tai thỏ khi xoay ngang). Golden chạy với inset ngang bằng 0 nên không đổi; nếu golden đổi thì dừng lại báo cáo.
> - **M1.** Khoảng cách đáy dùng nền tảng của thiết bị (`defaultTargetPlatform`) thay vì `Theme.platform`. **Khác báo cáo điều tra:** 11 test hiện có mô phỏng iPhone chỉ bằng `Theme.platform` sẽ đỏ; phải đánh dấu chúng chạy như thiết bị iOS (`variant`). Golden không đổi.
> - **M11.** Platform interface chỉ ghi log lỗi event channel lần đầu, chỉ ở debug.

---

## 1. Goal

Close the seven review findings the owner kept for the first release, each as a small, separately reviewable change with a test that failed first (M5: the analyzer, §4.1).

## 2. Scope

### 2.1 In

§4.1–§4.7 with their tests, test-helper changes and CHANGELOG lines.

### 2.2 Non-goals

- Any public API change, a version bump, Pigeon, Swift.
- Regenerating goldens (M10, M1: none may change; a change is a stop-and-report).
- M2: keyboard handling of the native (UIKit) sidebar; Escape order when the active search field holds focus under the overlay (§8).
- M10: the regular (iPad) search field and the sidebar. iPad sizes have no side insets, and the sidebar already pads its rows by the leading safe area (`sidebar_test.dart`, "rows start after the safe area on the leading side").
- M12: retrying a platform whose `watchSignals()` threw; the next first `acquire()` after every glass unmounted tries again, nothing more.

## 3. Evidence (file:line at `7ff7bf3`)

Paths under `liquid_shell/` unless stated.

| Item | Where | What |
|---|---|---|
| M5 | `lib/src/glass/renderer.dart:31` | `abstract class LiquidGlassRenderer` has no `@immutable`; `LiquidGlassSpec` (`:6`) has. Subclasses in lib (`frosted_renderer.dart:9`, `liquid_renderer.dart:12`, `solid_renderer.dart:7`), `doc/tiers.md:99` and `test/unit/glass_policy_test.dart:11` are const. `test/widget/liquid_glass_test.dart:76-77` `_CustomRenderer` has a non-const constructor on purpose ("equal in kind, never identical", used by "an equal but non-identical renderer neither fades nor resets"). |
| M12 | `lib/src/glass/signals_controller.dart:53-69` | `acquire()` calls `LiquidShellPlatform.instance.watchSignals().listen(...)` unguarded. A synchronous throw escapes `_LiquidGlassState.initState` (`lib/src/glass/liquid_glass.dart:92`): the glass subtree fails to build. Only stream *error events* are handled (`:59-66`). |
| M3 | `liquid_shell_android/android/src/main/kotlin/vn/lasoai/liquid_shell/LiquidShellPlugin.kt:150-162` | Two `registerContentObserver` calls in one `attempt {}`, `settingsObserver = observer` after both. If the second throws, the first stays registered and `removeObservers()` (`:199-202`) has nothing to unregister. |
| M2 | `lib/src/shell/liquid_shell.dart:1374` (body), `:1661-1684` (top bar row, shared by `topBar` and `sidebarOverlay`), `:1707-1719` (barrier), `:1721-1744` (sidebar), `:1764` (the `Stack`) | Nothing excludes focus behind the overlay. Measured on `7ff7bf3` (iPad portrait, sidebar open, 14 Tabs): focus visits the top tab bar and the page behind the barrier. Escape does nothing. |
| M10 | `lib/src/shell/liquid_shell.dart:1310-1320` (compact search rects, full width), `:1493` (the ⌕ drop target rect), `:1499-1501` (search-row pill), `:1580-1582` (tab bar row), `:1666-1668` (top bar row, `left: 0, right: 0`) | No `media.padding.left/right` anywhere in the chrome. Landscape 932×430 with a 59 pt left inset: the pill's centre is at 466 (window centre), not 495.5 (centre of the safe width). |
| M1 | `lib/src/shell/liquid_shell.dart:1284-1288`; `lib/src/shell/shell_layout.dart:106-113` | `bottomGapFor(platform: Theme.of(context).platform, …)`: an app's `ThemeData.platform` picks the gap. |
| M11 | `liquid_shell_platform_interface/lib/src/event_channel_platform.dart:82-85` | Every `PlatformException` event logs `error event <code>; using none`. Listen failures already log once (`_loggedListenFailure`, `:29`, `:121-125`). |

### 3.1 Where the code contradicts the investigation

1. **M1, the test fallout.** The investigation expected existing tests to keep working. `pumpShell` (`test/helpers/shell_harness.dart:164-206`) models a device by `ThemeData.platform` only (default `TargetPlatform.iOS`), while `defaultTargetPlatform` under `flutter test` is Android. With the fix, 11 tests that model an iPhone without a gesture inset get Android's gap (`max(21, 34 + 8) = 42`) and go red (§6.1). `debugDefaultTargetPlatformOverride` cannot be set inside `pumpShell` with `addTearDown`: the framework checks foundation debug variables before tear-downs run (prototype: hundreds of tests red, every `native_chrome_test.dart` one among them). The 11 tests take `variant: iosDevice` (`TargetPlatformVariant.only(TargetPlatform.iOS)`) instead. Goldens are unaffected: every golden device sets a gesture inset (`example/test/support/golden_harness.dart:17-51`), so the gap is 21 either way (prototype: `--tags golden` `+36: All tests passed!`).
2. **M2, Escape already exists.** "No Escape / Shortcuts anywhere in lib" is not so: `lib/src/search/search_chrome.dart:117-121` binds Escape in the search field to end the search, and `lib/src/dialogs/glass_dialogs.dart:159`, `:332` bind it in dialogs. Also the top tab bar behind the overlay takes focus (not only the body), and excluding the search field (or moving focus out of it) ends an active Flutter search (`lib/src/search/shell_search.dart:510-537`), which breaks "iPad, a shell nested in a tab, its overlay sidebar open over its active search…" (`test/widget/pushed_shell_back_test.dart:1243-1279`, red at `:1264` in the prototype). §4.4 is shaped by this.
3. **M5 is not analyzer-neutral.** `@immutable` turns `prefer_const_constructors_in_immutables` on for `_CustomRenderer` (`test/widget/liquid_glass_test.dart:77`): `make analyze` (`--fatal-infos`) fails. Making it const is wrong (the lint then asks for `const` call sites, and the test needs distinct instances); a targeted `// ignore:` with its reason is the fix.
4. **M3, the local JVM run.** `make android-unit` needs an Android SDK and an arm64 JDK on this machine (`ANDROID_HOME=/opt/homebrew/share/android-commandlinetools`, `JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`); the first run installed SDK Platform 36, Build-Tools 35 and NDK 28.2 there. CI's `android-unit` job needs nothing new.

## 4. Design

### 4.1 M5: `@immutable` on `LiquidGlassRenderer`

`@immutable` above `abstract class LiquidGlassRenderer` (`meta`'s annotation through `package:flutter/widgets.dart`, already imported). A subclass with a non-final field now gets the analyzer's `must_be_immutable`; a non-const constructor gets `prefer_const_constructors_in_immutables` where enabled. No runtime change.

`_CustomRenderer` in `liquid_glass_test.dart` keeps its non-const constructor under `// ignore: prefer_const_constructors_in_immutables`, with the reason (each call is a new instance).

**Test.** None at runtime: the annotation has no runtime effect. The analyzer is the check: `flutter analyze` reports the info at `liquid_glass_test.dart:77` after the annotation and nothing after the ignore.

### 4.2 M12: a throwing `watchSignals()`

In `acquire()`, the first user calls `watchSignals()` inside `try … on Object catch (error)`. On a throw: log `liquid_shell signals: <error>; using none` with `debugPrint` under `kDebugMode`, once per process (a `_loggedWatchFailure` flag on the controller, cleared by `debugResetLiquidGlassSignals`, as `debugResetPolicyLogging` clears the policy's once-flag); set `none`; leave `_subscription` null. `_users` stays counted, so `release()` stays balanced; the next first `acquire()` tries again.

`debugPrint` and not `FlutterError.reportError`: the repo reports with `reportError` only failures that are bugs in our code (`policy.dart:202`, `shader_program.dart:63`); a platform that cannot stream is the same case as the stream's error event (`:59-66`), which uses `debugPrint`.

**Test.** `FakeSignalsPlatform` (`test/helpers/fake_signals_platform.dart`) gains `Error? throwOnWatch`; when set, `watchSignals()` throws it synchronously (`Error`, not `Object`: `only_throw_errors`). Widget test in `test/widget/liquid_glass_test.dart`: mount a glass, unmount, mount again; no exception, frosted glass, one log line.

### 4.3 M3: keep the observer before registering

A helper next to `attempt` in `Attempt.kt`:

```kotlin
internal fun <T> registerAll(item: T, keep: (T) -> Unit, vararg registrations: (T) -> Unit) {
    keep(item)
    attempt { registrations.forEach { it(item) } }
}
```

`addObservers()` calls it with `{ settingsObserver = it }` and the two `registerContentObserver` lambdas. `removeObservers()` is unchanged: it already `attempt`s the unregister, and unregistering an observer that was never registered is harmless.

The plain JVM test cannot build `ContentResolver` or `ContentObserver` (no Robolectric, no mocks in the repo), so the order lives in the helper and is tested with strings.

**Test.** `RegisterAllTest.kt` (kotlin.test, beside `AttemptTest.kt`): every registration runs and the item is kept; a later registration throws, the item is still kept. The helper is first extracted with today's order (keep last, inside the attempt), a pure refactor, so the red comes from the real bug.

### 4.4 M2: the overlay sidebar is modal for the keyboard

In `build`, `final modal = kind == LiquidChromeKind.sidebarOverlay;` and:

1. **Body:** `ExcludeFocus(excluding: modal, child: _bodySubtree(kind))` inside the body's `MediaQuery` (`:1374`).
2. **Top bar row** (the `topBar || sidebarOverlay` case): its `Positioned` child wrapped in `ExcludeFocus(excluding: modal, …)`.
3. **Regular search field** (search tab selected, not active): wrapped in `ExcludeFocus(excluding: modal && phase == LiquidSearchPhase.selected, …)`. Focusing the idle field starts the search, so Tab must not reach it behind the barrier (final review, Important 1).
4. **Sidebar:** its slot wrapped in `Focus(autofocus: modal, skipTraversal: true, includeSemantics: false, …)` (no semantics flag on the sidebar in any kind). Autofocus only acts when nothing in the scope holds focus, so it gives Escape a place to start without taking focus from an active search.
5. **Escape:** the `Stack` (`:1764`) wrapped, always (the `Stack` keeps its state), in a `Focus(canRequestFocus: false, skipTraversal: true, includeSemantics: false, onKeyEvent: …)` that handles an Escape key-down with `_setSidebarVisible(false)` when `modal`, and ignores every other key. Ancestor of every chrome child, so Escape closes the overlay from the sidebar, a sidebar row, or with nothing focused. Not `CallbackShortcuts`: its `Focus` keeps semantics on, which merged the compact search field into a node the size of the shell, so XCUITest's tap on the field missed it.

The wrappers are always in the tree (only their flags change), so no state is lost when the chrome kind changes. `import 'package:flutter/services.dart';` is added for `LogicalKeyboardKey`.

**Only an active search field is exempt.** An idle (selected) field is excluded (item 3). Excluding the active one, or autofocusing past it, unfocuses it, and an unfocused Flutter field ends the search (`shell_search.dart:533-536`). VK-774 keeps the search alive under the overlay (back closes the sidebar, then the search). With focus in that field, Escape keeps the field's own meaning (`search_chrome.dart:117-121`: end the search), the innermost binding; see §8.

**Tests** (group `sidebar` of `test/widget/shell_chrome_test.dart`): (a) overlay open: the page's focus node cannot take focus; 12 Tabs never leave the sidebar; closed: the page can again. (b) Escape closes the overlay. (c) Search tab selected, overlay open: 12 Tabs stay in the sidebar and the search does not become active. (d) Search active, overlay open: Escape ends the search and the sidebar stays open.

### 4.5 M10: chrome clears the side safe area

`final sideLeft = media.padding.left; final sideRight = media.padding.right;` next to `bottomRowExtent`. Then:

- **Tab bar row** (`:1580-1582`): `left: barRowMargin + sideLeft, right: barRowMargin + sideRight`.
- **Compact search row:** `compactSearchRects` gets `size: Size(size.width - sideLeft - sideRight, size.height)` and its result is moved right by `sideLeft` with a new `CompactSearchRects.shift(double dx)` (in `search_layout.dart`, internal). RTL stays right: the rects mirror within the safe width, then move. The pill `Positioned` (`:1499-1501`) gets `margin + sideLeft` / `margin + sideRight`; the ⌕ drop-target rect (`:1493`) subtracts `margin + sideLeft`.
- **Top bar row** (`:1666-1668`): `left: sideLeft, right: sideRight`.

`padding`, not `viewPadding`: horizontally they are equal; `padding` is what the rest of the chrome reads (`media.padding.top`).

**Goldens.** Every golden device has zero side insets: no golden can change. Prototype: `example` `--tags golden` `+36: All tests passed!`.

**Tests** (new group `side safe area (VK-702)` in `shell_chrome_test.dart`): landscape bottom bar and landscape top bar (`compactHeight: 0`) with a 59 pt left inset are centred on the safe width (`(59 + 932) / 2`); the idle ⌕ of the landscape search row clears a 59 pt right inset.

### 4.6 M1: the device decides the bottom gap

`platform: defaultTargetPlatform` at `:1285` (`foundation.dart` is imported). `bottomGapFor` is unchanged.

**Tests.** `shell_harness.dart` gains `final iosDevice = TargetPlatformVariant.only(TargetPlatform.iOS);`; the 11 tests of §6.1 take `variant: iosDevice` first (green before and after the fix). Two new tests in group `bottom gap (Q9)`: an Android device themed as iOS (`118 = 62 + 56`), an iPhone themed as Android (`83 = 62 + 21`).

### 4.7 M11: one log for repeated error events

`static bool _loggedErrorEvent = false;` guards the error-event log like `_loggedListenFailure`; `debugResetLogging()` clears both. Debug only (`_debugLog` is `kDebugMode`-gated); `none` is still emitted for every error event.

**Test** (`liquid_shell_platform_interface/test/event_channel_platform_test.dart`): two error events, then end of stream: two `none` events, one log line.

## 5. Docs

One line per item in the package CHANGELOGs, under the existing `## 0.1.0-dev.8`: `liquid_shell` (M5, M12, M2, M10, M1), `liquid_shell_platform_interface` (M11), `liquid_shell_android` (M3, replacing "No changes; versioned with `liquid_shell`."). No `doc/` page states the behaviours changed here.

## 6. Prototype results (`7ff7bf3`, Flutter 3.44.6, macOS)

Each red test was run before its fix and after, then removed; the tree is docs-only.

| Item | Red before the fix | Green after |
|---|---|---|
| M5 | `flutter analyze`: `prefer_const_constructors_in_immutables` at `liquid_glass_test.dart:77` (after the annotation) | with the ignore: `No issues found!`; `liquid_glass_test.dart` + `glass_policy_test.dart` `+48` |
| M12 | `Expected: null` / `Actual: UnsupportedError:<Unsupported operation: no signal channel>` | `liquid_glass_test.dart` `+23: All tests passed!` |
| M3 | `RegisterAllTest > theItemIsKeptWhenALaterRegistrationFails() FAILED`, `AssertionFailedError: kept, so the remove path can undo the first registration ==> expected: <observer> but was: <null>` | `BUILD SUCCESSFUL`, both `RegisterAllTest` passed |
| M2 | (a) `Expected: false` / `Actual: <true>` (the page's `canRequestFocus`); (b) `Expected: no matching candidates` (`LiquidSidebar` still found) | both pass; whole `liquid_shell` suite `+1280` with the prototype tests |
| M10 | `Expected: <495.5>` / `Actual: <466.0>` (bottom and top bar); `Expected: a value less than or equal to <873>` / `Actual: <911.0>` (⌕) | all three pass; suite `+1277`; goldens `+36` |
| M1 | `Expected: <118>` / `Actual: <83.0>`; `Expected: <83>` / `Actual: <104.0>` | both pass; suite with the 11 variants `+1277`; `example` `+160`, `example_go_router` `+3`; goldens `+36` |
| M11 | `Expected: an object with length of <1>` / `Actual: [` (two lines) | `liquid_shell_platform_interface` `+51` |

Mutations run: M12 without the once-flag → red (two log lines); M2 `autofocus: false` → Escape test red; M2 top-bar `excluding: false` → Tab test red (`Expected: not null`, reason `Tab 1`).

### 6.1 The 11 tests that model an iPhone by theme only (M1)

| File | Test |
|---|---|
| `test/widget/search_fallback_test.dart` | `idle: the pill without Search, and a separate ⌕ circle`; `tap ⌕: the search tab is selected, the field is not focused`; `reduce motion: the morph is instant`; `VK-571: the keyboard goes, the search stays` › `dismissKeyboard: no focus, the query and × stay` |
| `test/widget/search_morph_test.dart` | `idle: pill pinned at 21, ⌕ circle at the end`; `selected: the bar itself collapses to the 48 circle at 28` |
| `test/widget/shell_chrome_test.dart` | `chrome by width (§5.1)` › `iPhone 393×852 → bottom bar`; › `a compact landscape window at least compactHeight tall keeps the 62 pt bar (690×600, VK-503 Q8)`; › `the measured bar height is kept per form: a rotation uses the right height on its first frame`; `page helpers` › `LiquidNoChrome publishes none(); contentPaddingOf takes the larger of chrome and system padding`; `custom chrome` › `a custom 100pt bar is measured into chromeInsets` |

## 7. Owner decisions (2026-10-24)

| # | Item | Decision |
|---|---|---|
| 1 | M5 | `@immutable` on `LiquidGlassRenderer`, no behaviour change |
| 2 | M12 | try/catch, log once (repo pattern), fall back to `none` |
| 3 | M3 | assign the observer before registering; JVM test; a helper for testability |
| 4 | M2 | `ExcludeFocus` behind the open overlay; Escape closes it |
| 5 | M10 | honour the horizontal safe area; goldens must not change (stop and report if they do) |
| 6 | M1 | `defaultTargetPlatform` instead of `Theme.platform` |
| 7 | M11 | log an error event the first time only, debug only |

Taken while writing this spec, within that scope (flagged for review): M1's 11 tests take `variant: iosDevice` (§3.1.1); M2 leaves an active search field focusable (§3.1.2, §4.4); M5's test renderer takes a targeted ignore (§3.1.3).

## 8. Follow-ups (not in this branch)

- M2: with focus in an active search field under the overlay, Escape ends the search (the field's binding) and the overlay stays; the next Escape reaches the shell only if something in it holds focus. If the owner wants the overlay first (back's order), the field's binding has to defer to the shell while the overlay is open.
- M2: keyboard handling of the native iPad sidebar is UIKit's.

## 9. Risks

| Risk | Answer |
|---|---|
| An app that set `ThemeData.platform` to get the iOS gap on Android | Gets the device's gap: the intended change (M1); CHANGELOG says so |
| Apps with a non-const renderer constructor see a new lint info | Analyzer info only, where `prefer_const_constructors_in_immutables` is on; CHANGELOG says so |
| `variant:` renames 11 tests (` (variant: TargetPlatform.iOS)` suffix) | `--plain-name` filters still match the prefix; no CI filter names them |
| A golden changes (M1, M10) | Not expected (§3.1.1, §4.5); stop and report, never `make goldens-update` on this branch |
| Autofocus in the sidebar steals focus | Only when nothing in the scope holds focus (an active search keeps it; `pushed_shell_back_test` green) |

## 10. Process

Plane VK-702 → this spec → plan `docs/plans/2026-10-24-api-fixes.md` → Tasks 1–7, TDD, pre-commit by hand → review → `make verify` → PR to `main` → Plane Done. Spec and plan are committed and pushed with the branch as soon as they are written (owner go-ahead 2026-10-24).
