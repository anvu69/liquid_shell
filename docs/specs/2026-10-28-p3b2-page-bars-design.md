# liquid_shell P3b-2: native page bars on every tab, the full Flutter page bar, page actions (delta spec)

- **Plane:** VK-780 (parent). Sub-items: VK-440 (T1, back swipe spike), VK-441 (T2, a navigation controller on every tab), VK-442 (T3, `LiquidPage` native on every tab), VK-443 (T4, `LiquidPageAction`), VK-444 (T5, back swipe GO/NO-GO), VK-445 (T6, the full Flutter page bar), VK-446 (T7, example, integration, XCUITest, images, docs, verify).
- **Date:** 2026-10-28
- **Status:** approved. The owner answered "Ok hết" to Q1–Q18 on 2026-10-28; Q12–Q17 are this item's (table at the end). Q12 approves this spec and its per-branch plans together. The choices this spec had to add are listed in "Quyết định phát sinh", at the end.
- **Supersedes:** §10 of `docs/specs/2026-10-10-p3b-search-tab-design.md` (`:647-707`) and the plan `docs/plans/2026-10-10-p3b-nav-bar.md`, which is not executed (Q12: 12 stale points, §3.2; its spike cannot start, §7.1). §1–§9 of the 10-10 spec still hold wherever this spec does not change them.
- **This branch:** `VK-780-p3b2-spec`, from `main` at `e0bbf62`. One file: this spec. The code branches are B1–B5 (§8); each has its own plan, written from this spec. Suggested plan files: `docs/plans/2026-10-28-p3b2-spike.md` (B1), `-native-bars.md` (B2), `-flutter-bar.md` (B3), `-page-actions.md` (B4), `-release.md` (B5).
- **Kind of change (all branches together):**
  - Dart in `liquid_shell` (pages, the shell's native config, scope data), Dart in `liquid_shell_platform_interface` (new config field, page actions, one new event), `liquid_shell_ios` (Pigeon source and both generated files, mapping, Swift: navigation controllers on every tab, page hosts, minimize, hide-chrome, bar buttons).
  - No Android native code. No new dependency. No pubspec version change (only branch R changes versions in wave 2).
  - Public API: `LiquidPageAction` and `LiquidPage.actions` are new; `LiquidPage.largeTitle` and `LiquidHideChrome` change meaning; the platform interface gains one sealed event subclass. Breaking before 0.1.0, with one migration section (Q17, §4.6).
- **Sources:**
  - The wave-2 evidence for P3b-2 (vankhan `.superpowers/sdd/wave2-p3b2-evidence.md`, 2026-10-28): the code at `e0bbf62`, the 12 stale points, the spike blockers B-1..B-4, the options per item and risks R1–R14. Cited below as "evidence".
  - The owner's decisions Q12–Q17 (vankhan `.superpowers/sdd/wave2-decisions.md`).
  - VK-776 (branch S, `VK-776-back-overflow`, in flight): vankhan `.superpowers/sdd/wave2-bugs-evidence.md` §2.
  - The code at `e0bbf62`; every file:line below was read again there. Paths: `example/…` is `liquid_shell/example/…`; a bare `liquid_shell.dart`, `native_layout.dart`, `liquid_page.dart`, `page_bar.dart`, `page_registry.dart`, `shell_scope.dart`, `native_minimize.dart` or `branch_navigators.dart` is under `liquid_shell/lib/src/`; a bare `*.swift` file is under `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/` (tests: `liquid_shell/example/ios/`). Flutter 3.44.6 sources are cited as `flutter@3.44.6:` (`~/fvm/versions/3.44.6/packages/flutter/lib/src/…`).
  - **Probes run while writing this spec** (throwaway, removed; nothing committed):
    - **IME across a bar switch.** A widget test put a focused `TextField` in a `LiquidPage` (root with `largeTitle: true`, and pushed), typed a composing value (`hoa`, composing 0–3), then flipped `LiquidShellScopeData.nativePageBar` false → true → false. Result: the same `EditableTextState`, focus kept, composing range kept; the only text-input traffic was `TextInput.setStyle`. With the child's `GlobalKey` removed (`liquid_page.dart:149`, `key: _childKey`) the same flip gave a new `EditableTextState`, a lost composing range (`TextRange(start: -1, end: -1)`) and `TextInput.clearClient`, `setClient`, `setEditingState`, `show`. The key is what keeps the IME safe; §5.4 makes it a locked rule.
    - **Asserts in `const` constructors.** Dart 3.12 rejects `assert(list.length <= 3)` in a `const` constructor that is invoked with `const` (`const_eval_property_access`); `assert(text != '')` is accepted. §4.1 places the action-count check accordingly.

> **Tóm tắt (cho chủ sản phẩm).**
> - **Mục tiêu.** Trên iOS 26+ (khung native), mọi tab có `LiquidPage` đều có thanh điều hướng UIKit thật: tiêu đề, nút back kính tròn, tiêu đề lớn, hiệu ứng mờ mép, và nút hành động trên thanh. Ở iOS < 26, Android và khung Flutter: cùng API, thanh kính Flutter, nay có tiêu đề lớn co lại khi cuộn và nút hành động. 0.1.0 không chờ vuốt-back bám ngón tay (Q13): vuốt vẫn như hôm nay (Flutter kéo trang, thanh native đổi khi thả tay).
> - **Không chạy lại kế hoạch 10/10.** Kế hoạch đó lỗi thời ở 12 chỗ (bảng §3.2), tệ nhất là xoá `TabHostController` đang mang tính năng thu nhỏ thanh tab (VK-600), và spike của nó không chạy được. Spec này thay §10 của spec 10/10.
> - **Tiêu đề (Q14), giống nhau ở thanh native và thanh Flutter:** trang gốc mặc định: tiêu đề lớn nằm trên hàng của thanh (như Apple Music) ở khổ hẹp, không có hàng tiêu đề ở khổ rộng; `largeTitle: true`: hàng tiêu đề lớn riêng, co lại khi cuộn (chỉ trang gốc); `largeTitle: false`: không có hàng tiêu đề; trang đẩy lên: luôn tiêu đề nhỏ ở giữa, có nút back.
> - **Nút hành động (Q15):** `LiquidPageAction(sfSymbol:, icon:, label:, onPressed:)`, tối đa 3; `onPressed: null` là nút bị tắt. Native: nút kính của UIKit; Flutter: vòng kính 44pt. Avatar và menu để sau 0.1.0.
> - **`LiquidHideChrome` (Q16):** trên trang có `LiquidPage`, chỉ ẩn thanh tab và sidebar, giữ thanh điều hướng của trang (thanh Flutter vốn đã vậy). Nếu cách này gây lỗi (danh sách lỗi cụ thể ở §6.6) thì quay về cách cũ: trang dùng thanh Flutter. Trang đẩy lên trên cả shell vẫn dùng thanh Flutter.
> - **Thu nhỏ thanh tab khi cuộn (VK-600)** vẫn chạy trên mọi tab, kể cả trang đẩy lên; đẩy hay pop trang giữ nguyên dáng thanh, như thanh Flutter.
> - **Năm nhánh:** B1 spike vuốt-back (code bỏ đi, giữ bản ghi kết quả) ∥ B2 thanh native trên mọi tab (bắt đầu sau khi nhánh S của VK-776 merge) ∥ B3 hoàn thiện thanh Flutter; rồi B4 nút hành động; rồi B5 phát hành (tài liệu, ảnh, ví dụ, anh kiểm tra trên máy thật).
> - **Spike:** thử "Flutter lái thanh native" trước (Flutter giữ cử chỉ, gửi tiến độ mỗi frame sang UIKit), "UIKit lái Flutter" sau. Tiêu chí đạt có số đo (§7.4). Đạt thì làm ở 0.1.x, không đổi API; không đạt thì giữ như hôm nay.
> - **Thay đổi phá vỡ** (được phép trước 0.1.0, Q17) gom vào một mục "Migration" trong CHANGELOG: nghĩa mới của `largeTitle`, `LiquidHideChrome` giữ thanh của trang, thanh native trên mọi tab, một sự kiện mới trong interface. P3b-2 ra ở bản dev (`0.1.0-dev.10`), rồi 0.1.0, rồi semver chặt.

---

## 1. Goal

1. **Native page bars on every tab (VK-441, VK-442).** On iOS 26+ with native chrome engaged, every destination tab whose pages use `LiquidPage` shows UIKit's navigation bar: the title, the glass back circle with its history menu, the large title with the scroll-edge effect. Tabs without `LiquidPage` look exactly as today (P2).
2. **One title model on both bars (Q14).** Native and Flutter bars draw the same title for the same page (§4.2).
3. **The full Flutter page bar (VK-445).** On iOS < 26, Android and Flutter chrome, the bar gains the collapsing large-title row and, with B4, the actions.
4. **Page actions (VK-443, Q15).** Up to three trailing actions per page, native bar buttons or Flutter glass circles.
5. **Decide the finger-tracked swipe (VK-440, VK-444, Q13)** with a timeboxed spike and numbers, without making 0.1.0 wait for it.
6. **Ship it (VK-446):** example, integration tests, XCUITest, doc images, README, migration notes, the owner's device check. P3b-2 ships in a dev release (`0.1.0-dev.10`), then 0.1.0, then strict semver (Q17).

**Success:** every test of §8 is red first for the reason given, then green; `make verify` passes on every branch; the iOS suites of §9 pass on the named simulators; the owner's device check (B5) passes.

## 2. Non-goals

- **A finger-tracked native back swipe in 0.1.0** (Q13). Today's behaviour stays: Flutter's route gesture moves the page; the native bar switches when the gesture ends. A GO from the spike lands in 0.1.x, with no API change (§7.6).
- **Avatar (custom image) actions and action menus** (Q15). After 0.1.0. A custom image would need image bytes over Pigeon (evidence R14).
- **Pages pushed above the shell** (on the app's root navigator) keep the Flutter bar (Q16, 10-10 Q17). No root-level native navigation controller.
- **iOS 26's full-width content swipe.** Flutter's Cupertino gesture is a 20 pt edge strip (`flutter@3.44.6:cupertino/route.dart:31`, `:798-806`); nothing in 0.1.0 adds a full-width one (evidence R6).
- **Android predictive-back transitions by the library.** The app's own `PageTransitionsTheme` decides (Q17).
- go_router (P5), `bottomAccessory`, the microphone icon (10-10 non-goals, unchanged).
- A version bump in any P3b-2 branch (§8.6).

## 3. What changed since the 2026-10-10 spec

### 3.1 The code today (file:line at `e0bbf62`)

**iOS 26 native chrome, the search tab** (the only tab with a native bar):
- `UISearchTab { _ in nav }` with `ShellNavController(root: PageHostController)` (`liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeTabsController.swift:269-280`).
- `applyPages(_:rootTitle:tabIndex:shown:events:)` diffs the stack and animates only while the tab is shown (`ShellNavController.swift:82-129`). The root's title is the first page's or the destination label (`:86`, `:96`); pushed hosts get `.always` for `largeTitle == true`, else `.never` (`:113-116`).
- The back circle is a proposal: `backAction` → `onBackTapped(tab)` (`ShellNavController.swift:102-110`, `:152-157`). UIKit's own pops (`popViewController`, `popToViewController`, `popToRootViewController`) become `onPopToPage` proposals (`:38-60`; Pigeon `liquid_shell_ios/pigeons/native_shell.dart:289-293`).
- Interactive pops are disabled (`ShellNavController.swift:66-69`). The edge swipe reaches Flutter; native pops when the shorter stack arrives. XCUITest: `liquid_shell/example/ios/RunnerUITests/SearchUITests.swift:176-190`.
- The page proxy is the `.top` content scroll view (`ShellNavController.swift:203`); the held top (`:159-162`); hit test through the top page (`PassThroughView.swift:24-30`); frame from the tab, insets from the top page (`NativeTabsController.swift:466-476`); window controls zero under a navigation controller (`:531-536`, `:714`).
- The root title mode comes from `SearchMath.style` (`SearchMath.swift:38-49`): iPhone `.inline` unless `largeTitle == false`; iPad `.never` plus a leading title item at compact width, `.always` for `largeTitle == true`.

**Every other destination tab:**
- `UITab { _ in host }` with an eagerly built, clear `TabHostController` (`NativeTabsController.swift:282-289`) that owns VK-600's `MinimizeProxy` as its `.bottom` content scroll view (`:912-955`; `minimizeHosts` `:39`, `:284-285`). The pan follows the selected `TabHostController` (`updateMinimizePan`, `:750-769`, the cast at `:753`); Dart's offset goes to `minimizeHosts[tab]` (`setMinimizeScroll`, `:790-793`); the bottom edge-effect policy (`:221-222`).
- The trailing tab is `UISearchTab { _ in TabHostController() }` (`:298`).
- No navigation bar: a `LiquidPage` there draws the Flutter bar, because `nativePageBarFor` is true only for the search index (`liquid_shell/lib/src/native/native_layout.dart:197-204`, used at `liquid_shell/lib/src/shell/liquid_shell.dart:1878-1882`).

**Dart, already generic:**
- Registry and stack: `liquid_page.dart:70-100`, `page_registry.dart:95-116` (`isTop` `:48`). `_stackFor` / `_updatePageStack` (`liquid_shell.dart:514-560`). `nativeConfigFor` sends `pages: pageStacks[i]` for every tab (`native_layout.dart:151`, `:164`), but `_updatePageStack(selected)` runs only `if (pageBar)` (`liquid_shell.dart:1916`).
- `_onNativeBack` and `_onNativePopTo` are tab-generic (`liquid_shell.dart:567-616`). Scroll sync is gated by `_nativePageBar` (`:628-660`).
- The scope's `windowControls` is zero while `(engaged && regular) || _nativePageBar` (`liquid_shell.dart:2043-2047`).
- `LiquidHideChrome` raises `_hideRequests`; the native config's `hidden` then hides UIKit's whole tab bar controller view (`liquid_shell.dart:1898-1901` → `NativeTabsController.swift:429-437`).
- Minimize: `nativeTabsMayRebuild` compares the whole `tabs` list, pages included (`native_minimize.dart:161-167`), so any stack change already forces a minimize resend after the config (`liquid_shell.dart:466-471`).

**The Flutter page bar** (`liquid_shell/lib/src/pages/page_bar.dart:23-158`): a 54 pt row (`kPageBarExtent`, `:7`), the glass back circle, a root large title on the bar row (`:56`, `:64-70`), a pushed large title on its own 52 pt row (`kLargeTitleExtent`, `:11`; `:57`, `:137-154`), no collapse, no actions. A root page with an inline title draws no bar (`liquid_page.dart:164`). The child sits under a `GlobalKey` (`liquid_page.dart:66`, `:148-154`), whose role the probe above confirmed.

**Back routing (all platforms):** the shell's `PopScope` blocks while the selected tab can pop (`liquid_shell.dart:868-896`); `_popBranch` pops the last on-screen navigator that can pop (`:825-848`; walk `branch_navigators.dart:151-214`).

**Flutter 3.44.6:** `TransitionRoute implements PredictiveBackRoute` (`flutter@3.44.6:widgets/routes.dart:111`) with public `handleStartBackGesture` / `handleUpdateBackGestureProgress` / `handleCancelBackGesture` (`:566-586`) on every route; `handleCommitBackGesture` calls `navigator.pop()` and then `reverse(from: upperBound)` (`:588-601`). `NavigatorState.userGestureInProgressNotifier` (`widgets/navigator.dart:5819`). `ScrollMetricsNotification` is dispatched after the frame (`widgets/scroll_position.dart:1081-1091`).

**Android:** no native navigation code (`liquid_shell_android/android/src/main/kotlin/vn/lasoai/liquid_shell/` holds only signals).

### 3.2 The twelve stale points of the 10-10 plan, and their resolution

| # | 10-10 plan text | Reality at `e0bbf62` | Resolution here |
|---|---|---|---|
| S1 | Branch `VK-407-search-tab`, worktree `liquid_shell-vk407`, version "0.1.0-dev.3 / dev.4", tag `(VK-407)` (`docs/plans/2026-10-10-p3b-nav-bar.md:30`, `:71`, `:402`) | All four pubspecs are `0.1.0-dev.8`; branch R adds `## 0.1.0-dev.9`; the items are VK-440..446 under VK-780 | Branches B1–B5 (§8), each from the main of its start day; CHANGELOG under `## 0.1.0-dev.10` (§8.6); no pubspec change; commits tagged with their own item |
| S2 | `applyPages(_:rootTitle:tabIndex:events:)`, "interactive pops disabled" only (`plan:36`) | `applyPages` has `shown:` (VK-502, `ShellNavController.swift:82-85`); UIKit's pops are proposals (`:38-60`) | B2's interfaces start from the merged names and add `compact:` (§8.2); the pop overrides stay |
| S3 | Spike step 2 only re-enables `interactivePopGestureRecognizer` (`plan:140-143`) | Touches never reach the nav recognizers (`PassThroughView.swift:23-33`; sibling subtree, `ShellContainerController.swift:33-45`), and the `popViewController` override swallows the interactive pop (`ShellNavController.swift:38-44`) | The spike starts with "Flutter drives the native bar", which needs neither (§7.2); "UIKit drives Flutter" needs a carve-out and a bypass (§7.3) |
| S4 | "TabHostController goes … grep must print nothing" (`plan:422`, `:533`) | It hosts VK-600's minimize proxy (`NativeTabsController.swift:912-955`), is the trailing tab's controller (`:298`), and `updateMinimizePan` casts to it (`:753`); VK-600 gave nav controllers no minimize proxy (`docs/specs/2026-10-14-native-tab-minimize-design.md:192`) | The minimize proxy moves into every page host of a non-search tab; the root host is the tab's per-tab host, built eagerly and kept for the tabs' life; `TabHostController` stays for the trailing tab (§6.8) |
| S5 | T2's "before" snippet of `rebuildTabsIfNeeded` (`plan:510-513`) | The host is built eagerly for minimize, with `.fixed` / `.sidebarOnly` placement (`NativeTabsController.swift:282-289`) | B2 keeps the eager build and the placement; the provider returns the tab's `ShellNavController` (§8.2) |
| S6 | GO needs an exported `LiquidPageRoute` (`plan:1564`, `:1690`; 10-10 spec `:697`) | Every `TransitionRoute` is a `PredictiveBackRoute` with a public driving API (`routes.dart:111`, `:566-586`) | No new route type and no public API for the swipe: any app route can be driven or observed (§7) |
| S7 | GO commits through the route | `handleCommitBackGesture` pops, then `reverse(from: upperBound)`: the page snaps back to fully shown before it slides out (`routes.dart:588-601`) | Commit with `navigator.pop()`, then `navigator.didStopUserGesture()` once the route's animation settles; never `handleCommitBackGesture` (§7.3) |
| S8 | NO-GO tests "pass on P3b-1's code" | True and proven on the search tab (`SearchUITests.swift:176-190`) | The NO-GO guards are generalised to every tab inside B2 (§8.2); no NO-GO branch |
| S9 | T6: a root page with `largeTitle: true` collapses by 52 (`plan:2330-2370`) | Since P3b-1 Task 12 a root large title sits on the bar row and never collapses (`page_bar.dart:56`, `:64-70`); `kLargeTitleExtent` exists (`:11`); the listener is `NotificationListener<Notification>` (`liquid_page.dart:127-143`, `:150`) | Q14 makes `largeTitle: true` the collapsing row on root pages and `null` the bar-row title; B3's tests use `kLargeTitleExtent` and the existing listener (§4.2, §8.3) |
| S10 | Non-goal "tabBarMinimizeBehavior" (10-10 spec `:80`) | VK-600 shipped native minimize | Minimize works on every tab, pushed pages included (§6.8) |
| S11 | Integration reads `debugSnapshot().pageTitles` | The snapshot reads the search tab's nav only (`NativeTabsController.swift:874`, `:897`) | `NativeDebugSnapshot.tabs` lists every tab (§5.2) |
| S12 | README Roadmap: "0.1.0 is the first release … search tab", planned "Native navigation bars on every tab" (`liquid_shell/README.md:1493-1501`) | The owner put P3b-2 inside 0.1.0 (2026-10-24); the limitations say "on the search tab only" (`README.md:1402-1404`, `:1468-1469`) | B5 rewrites the Roadmap, Limitations, Known issues and `doc/native_chrome.md:213-244` (§8.5) |

## 4. Public API (`liquid_shell`)

### 4.1 `LiquidPage` (its shape once B4 has landed)

```dart
class LiquidPage extends StatefulWidget {
  const LiquidPage({
    required this.title,
    required this.child,
    this.largeTitle,
    this.actions = const <LiquidPageAction>[], // B4
    super.key,
  });

  /// At most this many actions are shown.
  static const int maxActions = 3;

  /// The navigation bar title; also the next page's native back label.
  final String title;

  /// A root page's large title. true: its own row, which collapses as
  /// the page scrolls. null: on the bar row at compact width, no title row
  /// at regular width. false: no title row.
  /// Ignored on a pushed page, whose title is always inline.
  final bool? largeTitle;

  /// Trailing actions, in reading order; at most [maxActions] are shown.
  final List<LiquidPageAction> actions;

  /// The page. Its first vertical scroll view on screen drives the native
  /// large title's collapse and the scroll-edge effect, and the Flutter
  /// bar's collapse: the first one to report (its first layout or a
  /// scroll) that is on screen (not a hidden child of an `IndexedStack`, not
  /// under an `Offstage` or an invisible `Visibility`, not a `PageView` page
  /// out of view), not nested in another vertical scroll view, and not
  /// inside a text field. It drives the title until it is disposed or
  /// hidden; then the next one on screen to report takes over, so a
  /// segment switcher's shown list takes over at its first scroll.
  /// A vertical scroll view outside the page's list that reports first
  /// takes the title for good, even one that cannot scroll: put a fixed
  /// header above the list in a `Column`, not in a shrink-wrapped list.
  final Widget child;
}
```

- `title`, `largeTitle` and `child` keep their names and types; `largeTitle`'s meaning changes (§4.2, §4.6).
- **More than three actions:** `assert(actions.length <= LiquidPage.maxActions)` in debug, checked when the page's state reads the widget (`didChangeDependencies` and `didUpdateWidget`), **not** in the constructor: `List.length` is not a constant expression, and `const LiquidPage(...)` must keep compiling (probe, header). Release builds show the first three, in both bars; Dart truncates at the platform boundary, so native never receives more (Swift also clamps).
- `LiquidBackButton` is unchanged.
- Dartdoc follows `make public-docs`: no `§`, no `VK-`, no phase codes.

### 4.2 The title model (Q14): one table for both bars

A page is a **root** when no route lies below it in its navigator: in Flutter `!ModalRoute.impliesAppBarDismissal`, natively index 0 of the tab's native stack (the stand-in rule of §6.1 makes the two agree). `compact` is the shell's size class (`LiquidShellScopeData.sizeClass`); under native chrome it is UIKit's (`NativeTabsController.isCompact`: every iPhone, a compact-width iPad window).

| Page | `largeTitle` | Size class | Actions | Mode | Flutter bar | Native bar (plain tab) |
|---|---|---|---|---|---|---|
| pushed | any | any | any | `inline` | 54 pt row: back circle, centred title, actions | shown; host `.never` |
| root | `true` | any | any | `largeCollapsing` | 54 pt row + a 52 pt large-title row below it; the large row scrolls away as the page scrolls and the inline title fades into the bar row | shown; root `.always`; the proxy drives the collapse |
| root | `null` | compact | any | `largeInRow` | 54 pt row with the large title leading on it (Apple Music); no collapse | shown; root `.inline` |
| root | `null` | regular | none | `hidden` | no bar: the shell's chrome is the title row | bar hidden |
| root | `false` | any | none | `hidden` | no bar | bar hidden |
| root | `null` (regular) or `false` | as left | ≥ 1 | `inline` | 54 pt row: centred title, actions | shown; root `.never` |

- An active search (`searchPhase == active`) hides the large title in every mode, as UIKit does (unchanged, `page_bar.dart:43`, `:57`).
- **The search tab** keeps its own root rules natively (`SearchMath.style`, `SearchMath.swift:38-49`), because a `UISearchTab` root draws no `.never` or `.inline` title on an iPad (10-10 spec `:460`). Its bar is never hidden (the field lives in it). One change for parity: on iPhone `largeTitle: true` gives `.always` (the collapsing row) instead of `.inline` (B2).
- **Implemented twice, against this one table:** Dart `pageTitleModeFor` (B3, `lib/src/pages/page_title.dart`) for the Flutter bar; Swift `PageTitleMath` (B2) for the native bar. The wire keeps `NativePage.largeTitle: bool?`. Both test suites carry this table row by row ("Quyết định phát sinh" 2).

### 4.3 `LiquidPageAction` (Q15, B4)

```dart
/// A trailing action in a `LiquidPage`'s bar: a native bar button on
/// iOS 26+ with native chrome, a glass circle in the Flutter bar elsewhere.
@immutable
class LiquidPageAction {
  const LiquidPageAction({
    required this.sfSymbol,
    required this.icon,
    required this.label,
    required this.onPressed,
  }) : assert(sfSymbol != '', 'sfSymbol names an SF Symbol'),
       assert(label != '', 'label is read by assistive technology');

  /// The native button's image (`UIImage(systemName:)`). Required: an
  /// action never moves its page to the Flutter bar.
  final String sfSymbol;

  /// The Flutter bar's icon.
  final Widget icon;

  /// Semantics label and tooltip; the native accessibility label.
  final String label;

  /// Called on tap. Null disables the action in both bars.
  final VoidCallback? onPressed;
}
```

- File `lib/src/pages/page_action.dart`, exported from `lib/liquid_shell.dart` (`export 'src/pages/page_action.dart';`); `test/unit/public_api_test.dart` gains the line.
- **No `==`.** It holds a callback. The shell compares what the bars show (`sfSymbol`, `label`, enabled) and always runs the newest callback (§8.4).
- **Order:** reading order, leading to trailing, as `AppBar.actions`. Natively `rightBarButtonItems` is the reversed list (UIKit counts from the trailing edge); RTL mirrors in both bars.
- **An unknown symbol** (`UIImage(systemName:)` returns nil): native shows a text button with `label`, plus one debug log line. The Flutter bar is unaffected.
- **Flutter look:** 44 pt `LiquidGlass` circles (so the tier policy applies, Android included), 8 pt apart, 16 pt from the trailing edge, centred in the 54 pt row; the icon at 20 pt in `onSurface`, `disabledColor` when disabled; `Semantics(button: true, enabled:, label:)` and a `Tooltip(label)`. UIKit groups its bar buttons in one shared glass capsule; the Flutter bar draws separate circles (the approved 10-10 §10.5 look; a visual delta, §11).
- **Avatar images and menus:** after 0.1.0 (Q15).

### 4.4 `LiquidHideChrome` under page bars (Q16)

New rule, worded the same for both chromes: **`LiquidHideChrome` hides the shell's chrome (tab bar, toggle, sidebar, top bar) and never the page's own bar.** The Flutter bar already behaves so: it is drawn by `LiquidPage`, not by the shell. Natively (B2):

- While a hide request is active and the selected tab's native stack is not empty (a `LiquidPage` is on top, or kept under a cover), the config carries `tabBarHidden: true` and `hidden: false`: UIKit hides the tab bar and the sidebar; the navigation bar stays (§6.6).
- With an empty stack (a page without `LiquidPage`, like the example's `HideChromeCase` detail, `example/lib/cases/hide_chrome.dart:54-61`) nothing changes: `hidden: true`, the whole chrome hides, as today.
- The scope keeps reporting `chromeKind: hidden` and zero `chromeInsets` in both cases; the page's top padding is the native bar's (Flutter's safe area).
- **Fall-back (Q16):** if B2's regression checks fail (§6.6), B2 ships the 10-10 behaviour instead: `nativePageBarFor({required bool engaged, required bool chromeHidden}) => engaged && !chromeHidden`; the page draws the Flutter bar while hidden, and `tabBarHidden` is not added. The bar switch is IME-safe (probe, §5.4).
- The class dartdoc (`shell_scope.dart:209-220`) gains: "A `LiquidPage`'s own bar stays".

### 4.5 Scope data

- `LiquidShellScopeData.nativePageBar` is true on every tab of an engaged shell (B2). Its meaning: "pages of this shell use the native bar" (`LiquidPage` draws only its child). The field and its place in `==` are unchanged.
- `windowControls` under native chrome (B2): zero while `engaged && ((regular && no hide request) || the search tab is selected)`; otherwise the platform's report, which native zeroes while the selected tab's navigation bar is shown (§6.1). The search tab's bar is always shown, so it stays zero at once, as `native_search_test.dart:526-549` asserts.

### 4.6 Breaking changes and the migration section (Q17)

Allowed before 0.1.0, gathered in one **"Migration from 0.1.0-dev.9"** section at the top of `liquid_shell/CHANGELOG.md`'s `## 0.1.0-dev.10` (written by B5; each branch's own entries carry a "**Breaking (…)**" or "**Behaviour change (…)**" tag):

1. **Native bars on every tab.** With native chrome on iOS 26+, a `LiquidPage` on any tab now gets UIKit's bar instead of the Flutter bar. To keep the Flutter bar on a shell, use `nativeChrome: LiquidNativeChrome.off` (all chrome is then Flutter's). Code that read `LiquidShellScopeData.nativePageBar` to decide whether to draw its own title row sees `true` on every tab of an engaged shell.
2. **`largeTitle: true` on a root page** is now the collapsing large-title row under the bar row, in both bars. Before, the Flutter bar (and the iPhone's native search tab) put it on the bar row. That look is now `largeTitle: null` at compact width; at regular width there is no equivalent (a root page there shows no bar row, or the collapsing row).
3. **`largeTitle` on a pushed page is ignored:** its title is always inline. Before, the Flutter bar drew a pushed large title on a row of its own (UIKit already drew it small).
4. **`LiquidHideChrome` over a `LiquidPage` keeps the page's bar** under native chrome (the Flutter bar already did). For a full-frame page, leave `LiquidPage` out of that page.
5. **Platform interface (implementers and exhaustive switches):** `LiquidNativeEvent` gains `LiquidNativePageActionTapped`; it is sealed, so an exhaustive `switch` over it needs the case. `LiquidNativeChromeConfig.tabBarHidden` and `LiquidNativePage.actions` are new fields with defaults.
6. **Native minimize follows pushed pages** (a behaviour change, no code change needed).

After 0.1.0, strict semver (Q17).

## 5. Platform contract

### 5.1 `liquid_shell_platform_interface` (`lib/src/native_chrome.dart`)

```dart
// B2
const LiquidNativeChromeConfig({
  …, // unchanged
  this.tabBarHidden = false,
});
/// Hide the tab bar and the sidebar but keep the selected tab's navigation
/// bar (a hide request over a page with a native bar). Ignored while
/// [hidden].
final bool tabBarHidden;   // joins ==, hashCode and toString

// B4
@immutable
class LiquidNativePageAction {
  const LiquidNativePageAction({
    required this.sfSymbol,
    required this.label,
    this.enabled = true,
  });
  final String sfSymbol;
  final String label;
  final bool enabled;
  // ==, hashCode, toString field by field
}

const LiquidNativePage({
  required this.title,
  this.largeTitle,
  this.actions = const [],   // B4; joins == (listEquals), hashCode, toString
});

/// The user tapped action [index] of the page at [page] (0 is the root of
/// the tab's native stack) on tab [tab]. A proposal: the shell runs the
/// action if it still shows that action there.
final class LiquidNativePageActionTapped extends LiquidNativeEvent {
  const LiquidNativePageActionTapped(
    this.tab, {
    required this.page,
    required this.index,
    required this.sfSymbol,
  });
  final int tab;
  final int page;
  final int index;
  final String sfSymbol;
  // ==, hashCode, toString
}
```

- `LiquidNativePage.largeTitle`'s dartdoc (`native_chrome.dart:234-236`) becomes: "A root page's large title: `true`, its own row that collapses as the page scrolls; `null`, on the bar row at compact width; `false`, none. A pushed page never has one." (B2.)
- No new `LiquidShellPlatform` method: page stacks, titles and actions ride in `update` (`LiquidNativeTab.pages`), as today.

### 5.2 Pigeon (`liquid_shell_ios/pigeons/native_shell.dart`)

Edited with `make pigeon`; source and both generated files committed (`make pigeon-check`).

| Direction | Message | Change | Branch |
|---|---|---|---|
| Dart → native | `update(NativeChromeConfig)` | `NativeChromeConfig.tabBarHidden: bool` | B2 |
| Dart → native | `update` | `class NativePageAction { String sfSymbol; String label; bool enabled; }`; `NativePage.actions: List<NativePageAction>` (Dart sends at most three) | B4 |
| Dart → native | `setPageScroll(int tab, double offset)` | unchanged; now for every tab's top page | B2 |
| Dart → native | `setMinimizeScroll(int tab, double offset)` | unchanged on the wire; native applies it to the tab's top page host | B2 |
| Dart → native | `debugSnapshot()` | `class NativeTabSnapshot { int tab; List<String> pageTitles; bool barHidden; List<String> titleModes; }` (`titleModes`: `"inline"`, `"always"`, `"never"`, `"automatic"`, root first); `NativeDebugSnapshot.tabs: List<NativeTabSnapshot>` (every destination). `pageTitles` stays the search tab's | B2 |
| Dart → native | `debugSnapshot()` | `NativeTabSnapshot.actionSymbols: List<String>`, `actionsEnabled: List<bool>` (the top page's items, reading order) | B4 |
| Dart → native | `debugTap(NativeTapTarget, int)` | `NativeTapTarget.pageAction`: `index` = the action on the selected tab's top page | B4 |
| native → Dart | `onBackTapped(int tab)`, `onPopToPage(int tab, int index)` | unchanged; now from every tab | B2 |
| native → Dart | `onPageActionTapped(int tab, int page, int index, String sfSymbol)` | new | B4 |

**Boundary checks.** Dart drops a tab index outside the destinations, a negative `page` or `index`, an `index ≥ LiquidPage.maxActions`; Swift clamps actions to three and checks the tab index again (the P3b boundary rule, 10-10 spec §6).

**Large-title state** travels one way: Dart sends `largeTitle` per page and the top page's scroll offset (one message per frame, only while it changes); native collapses the title through the page proxy and holds Flutter's top inset while scrolled (`restingTop`, `ShellNavController.swift:143-162`). Native reports nothing about the title back; Flutter learns the bar's height only through its safe area.

### 5.3 One-way rules (native → Dart)

1. **Dart owns state.** The config is the truth for tabs, selection, stacks, titles, actions, `hidden` and `tabBarHidden`. Native never pops, pushes, selects, runs an action or changes a title by itself.
2. **Every native gesture is a proposal.** The back circle (`onBackTapped`), the history menu, an accessibility escape, a keyboard back or a pop-to-root (`onPopToPage`), a destination tap (`onDestinationTapped`) and an action tap (`onPageActionTapped`). Dart decides (the page's `PopScope`, the guard, the action's current state) and answers with a config.
3. **No echo.** Dart never sends a native report back as a command, and native never reports Dart's own writes (unchanged P3b rule).
4. **Action taps carry identity** (tab, page, index, symbol): a tap in flight while the app changes its actions or pushes a page is dropped, never mapped to another action (§8.4).

### 5.4 IME safety

- **Never change the parent or key of a focused field.** `LiquidPage`'s child stays under its `GlobalKey` (`liquid_page.dart:66`, `:148-154`) through every bar switch (native chrome engaging or leaving, the Q16 fall-back's hide-chrome flip). The probe (header) showed that this key alone keeps the `EditableTextState`, the focus and the composing range; without it the IME client is torn down and the composition lost. B2 and B3 each add a locker test for it (§8.2, §8.3).
- **Never rebuild the page's child for a scroll frame.** The Flutter bar's collapse (B3) listens to the offset in a `ValueListenableBuilder` whose `child:` is the page, so the page's element is not rebuilt per frame; only the title rows and the scroll-edge mask are.
- **Never write into a composing field.** P3b-2 adds no write into any text field, Flutter's or native's. Action taps and native bars carry no text. Non-search tabs host no native text field.
- **Keep the native search untouched.** B2 does not change the tab `structure` key (`NativeTabsController.swift:256-258`), so no push, pop or hide request rebuilds the tabs or dismisses the search (evidence R8). `tabBarHidden` with an active search dismisses it keeping its text, as hidden chrome does (VK-551, `NativeTabsController.swift:241`).
- **The query bridge stays one-way** (§5.3).

## 6. Behaviour per mode

### 6.1 iOS 26+ native chrome: the tree and the per-tab rules (B2)

```
ShellContainerController (PassThroughView)
├─ FlutterViewController                                    unchanged
└─ NativeTabsController (.tabSidebar, clear)
   ├─ UISearchTab "trailing" → TabHostController            unchanged (never selected)
   ├─ UITab destination i → ShellNavController(search: false)
   │    ├─ PageHostController(minimizes: true)   root, built with the tabs
   │    └─ PageHostController(minimizes: true) × (pages − 1)
   └─ UISearchTab destination → ShellNavController(search: true)   P3b-1
        ├─ PageHostController(minimizes: false)  root, hosts the search controller
        └─ PageHostController(minimizes: false) × (pages − 1)
```

- **Bar visibility (plain tabs):** `PageTitleMath.barHidden(pages:compact:)`: hidden when the stack is empty or is a single root page in `hidden` mode (§4.2); shown otherwise. `setNavigationBarHidden(_:animated:)` animates only when the tab is shown (the `shown` rule of `applyPages`). The search tab's bar is never hidden.
- **Title modes:** pushed hosts `.never` on every tab; plain roots `PageTitleMath.rootMode(largeTitle:compact:)` (`true` → `.always`, `null` and compact → `.inline`, else `.never`); the search root keeps `SearchMath.style`.
- **A size-class change** (an iPad window crossing compact/regular) re-applies the last config's pages without animation from `NativeTabsController`'s trait handler (`NativeTabsController.swift:150-164`), so title modes and bar visibility follow UIKit's size class at once; Dart's config can be equal and is then not sent.
- **The stand-in root.** When the first `LiquidPage` of a tab's stack sits above a route without one (`stack.first.route.isFirst == false`), Dart's native stack starts with `LiquidNativePage(title: <destination label>, largeTitle: false)`. Natively the detail then has its back circle (labelled with the destination) where the Flutter bar shows `LiquidBackButton` (`impliesAppBarDismissal`). `_onNativePopTo(tab, 0)` then pops every page of the stack, top first; native indices map to records shifted by one (§8.2).
- **Hit test:** unchanged rule (`PassThroughView.swift:19-34`): the chain from the selected tab's top page up to the tab bar controller's view is background. A hidden bar is not hit, so its band reaches Flutter.
- **Frame and safe area:** unchanged rule (`NativeTabsController.swift:464-499`): frame = the tab's navigation controller view, insets = the top page's, held top while the page proxy is scrolled.
- **`isTiled`** (`NativeTabsController.swift:441-444`) reads the same view `syncFlutter` copies insets from (the top page's view, falling back to the tab's), so the tiled check and the copied insets agree on a navigation tree (B2 measures both).
- **Window controls:** native `windowControls()` returns zero while `chromeVisible && ((!isCompact && !tabBarHidden) || selectedShowsNavigationBar)`, where `selectedShowsNavigationBar` is "the selected `ShellNavController`'s bar is not hidden" (replaces `selectedHasNavigationBar`, `:714`). Dart's rule: §4.5.
- **`hidesBarWhenPushed`** stays false (`ShellNavController.swift:9-13`; `docs/qa/p3b/probe.md`).

### 6.2 iPhone

- Compact floating tab bar at the bottom; each tab's bar per §6.1. A root `LiquidPage` with the default title shows the large title on the bar row; `largeTitle: true` shows the 52 pt row that collapses as the page scrolls (UIKit `.always` + the proxy).
- Push: UIKit pushes with the glass back circle at x 16; the bar appears with its own animation when the root had none. Pop: when Flutter pops.
- Minimize: §6.8. Hide chrome: §6.6. Swipe: §6.7.
- iOS 27: the search tab's own placement (stacked while active, VK-698) is unchanged; B2 runs its new tests on 27.0 too.

### 6.3 iPad, tiled sidebar

- The tab host is not resized by a tiled sidebar (`ShellMath.swift:63-67`; `RunnerTests.swift:1373-1383`); UIKit lays the navigation bar's content inside the safe area, right of the sidebar. Flutter's body is moved beside the sidebar with its start padding removed (`liquid_shell.dart:2001-2010`), so Flutter's 20 pt edge strip starts at the sidebar's edge.
- Window controls: zero (regular).
- `tabBarHidden` hides the sidebar too and puts a tiled sidebar back when it ends (§6.6).
- B2 measures (task M1, §8.2) where the back circle and the title of a pushed page sit next to the tiled sidebar, on 26.5 and 27.0, and keeps the screenshots for the owner.

### 6.4 iPad, overlay sidebar and the top tab bar

- Regular width with the sidebar hidden: UIKit's floating top tab bar. A shown navigation bar is expected to share its row on iPadOS 26 (unmeasured for plain `UITab`s; the 10-10 work measured the search root only, 10-10 spec `:460`). B2's task M1 measures a pushed page there on 26.5 and 27.0 (back circle, title, tab bar frames). If UIKit overlaps them, B2 stops and reports to the owner; no layout is invented.
- Overlay sidebar (portrait regular): it slides over the content, the navigation bar included. Back closes the overlay first (VK-774 order, `liquid_shell.dart:888-896`). The held top for the overlay (`NativeTabsController.swift:477-482`) applies to the top page's insets as today.
- A compact-width iPad window: as iPhone (bottom bar, `.inline` roots, real window controls under a hidden bar).

### 6.5 Flutter chrome: iOS < 26, Android, `nativeChrome: off`, a `chromeBuilder` (B3, B4)

- Same API, same title model (§4.2), same actions (§4.3), drawn by `FlutterPageBar` with `LiquidGlass` (tier policy: liquid, frosted, solid).
- `largeCollapsing`: the child's top padding is `barTop + 54 + 52` and stays so while collapsing (as the native held top); the large row is drawn at `barTop + 54 − largeShift` and clipped to the area below the bar row; the inline title in the bar row has opacity `inlineOpacity`; the scroll-edge fade ends at `barTop + 54 + 52 − largeShift` (§8.3 `pageBarCollapse`).
- **The scroll view that drives the collapse** (owner's decisions of 2026-10-28, option a, after the B3 Task 3 review and again after the final review): the page's first vertical scroll view on screen. That is the first scroll view to report (its first layout or a scroll) that scrolls vertically, is on screen, is not inside another vertical scroll view of the page, and is not inside a text field (an `EditableText`: a multi-line field scrolls its own text vertically). Horizontal scroll views around it do not count. It drives the title until it is disposed or leaves the screen; the next scroll view that qualifies and reports then takes over, and until one does the title keeps the last offset. Every other scroll view is ignored: a multi-line composer beside the list, a second list beside the first, a list nested in the page's list.
  - **On screen** means that nothing between the scroll view and the page hides it, as the VK-593 helper `isOnScreenUnder` (`liquid_shell/lib/src/shell/branch_navigators.dart`) decides, walking from the scroll view up to the page only: not an `IndexedStack` child other than the shown one (read from `RenderIndexedStack.index`, so it keeps working from Flutter 3.47, where `IndexedStack` no longer wraps hidden children in `Visibility`), not under an `Offstage`, an invisible `Visibility` or a disabled `TickerMode`, not a `PageView` page outside the visible window (kept alive or in the cache extent). A scroll view off screen neither takes the title nor keeps it: its reports never drive it, and the next scroll view on screen that qualifies and reports takes the latch from it. Because the walk stops at the page, a page in a hidden tab or under a pushed route still follows its own list (locked by the hidden-tab test of §8.3).
  - **A `PageView` of lists** (a `TabBarView` too), its pages kept alive or not: the first page's list drives the title; after a swipe the shown page's list takes over at its first scroll, and until then the title keeps the previous list's last offset. Measured (B3 probe): the shown page's list first lays out, and reports, during the swipe while the first page is still on screen, so that report is ignored; nothing reports once the swipe has settled. A kept-alive first page's list, now off screen, no longer moves the title (before the final review's fix it drove the title for good).
  - **A segment switcher** (an `IndexedStack` or an `Offstage` of lists): the shown list drives the title. After a switch the shown list takes over at its first scroll; until then the title keeps the previous list's offset, because no notification arrives at a switch (the code before the latch had the same gap). A hidden list never moves the title, even the one that drove it. Locked by the `IndexedStack` and `Offstage` tests of §8.3.
  - **A vertical scroll view outside the page's list that reports first takes the title for good, even if it cannot scroll** (accepted, final review M-3). Example: `Column[ListView(shrinkWrap: true, physics: NeverScrollableScrollPhysics()), Expanded(list)]`: the header list, not flexible, lays out and reports first, so the list at 120 leaves the title at rest. An app puts such a fixed header in a `Column`, not in a shrink-wrapped list; `LiquidPage.child`'s dartdoc says so. A 0.1.x opt-in that names the title's scroll view (a `primary: true` scroll view, or a scroll-controller parameter, as UIKit's `setContentScrollView`) would close this gap and the stale-title gaps above.
  - **A report made during a build or a layout is decided after the frame** (re-review of the final fixes, I-1 and m-1). Most reports come outside a build: a drag, a fling's frames, and a layout's `ScrollMetricsNotification`, sent after the frame. But a `jumpTo` made while the frame builds or lays out (in `didUpdateWidget`, `didChangeDependencies` or a `LayoutBuilder`: a list that jumps to the top when a filter changes) dispatches its `ScrollUpdateNotification` at once, from inside the build. Decided there, the latch could walk the ancestors of a driver removed in that same build (inactive but still `mounted`: in debug `Looking up a deactivated widget's ancestor is unsafe`, and the page body became an error widget), and setting the offset would mark the bar dirty during the build (`setState() or markNeedsBuild() called during build`, the title then stale). So `_onScroll` defers a report that comes while `SchedulerBinding.instance.schedulerPhase` is `persistentCallbacks` (the shell's `_outsideBuild` test): one post-frame callback decides every such report of the frame, each scroll view's latest offset in the order the scroll views first reported, so the first of them to report takes over as it would outside a build. By then a scroll view removed in that frame is unmounted: it is skipped, and a driver removed is released, never walked. `midFrameMicrotasks` is not deferred: no element is inactive then, and the bar can be marked dirty. Every other report is decided at once, so a scroll frame costs what it did. Locked by the three "jumps during a build" tests of §8.3: the no-exception test, the title's follow-up, and the one where the first scroll view to report, not the first to lay out, takes over.
  - The rule is written once, on `_LiquidPageState._drivesLargeTitle` (`liquid_shell/lib/src/pages/liquid_page.dart`), and stated for package users in `LiquidPage.child`'s dartdoc (§4.1). In B3 only the Flutter bar follows it: the native report (`PageHandle.scrolled`) keeps the depth-0 vertical filter. **B2 gates the native report with the same result** (the exception in §8.0, the task and test row in §8.2): `_followScroll`, which every vertical report reaches (at once, or after the frame when it came during a build), computes `_drivesLargeTitle(origin)` once and uses that one result for both `_scrollOffset.value` and `_handle?.scrolled`, so both writes share the same decision, deferred when it is deferred; `_onScroll` drops the `depth == 0` filter (the ancestor walk already leaves nested lists out). Expected native changes, for parity with the Flutter bar: a multi-line field, a second list and a hidden segment's list no longer move UIKit's large title; the lists of a `PageView` or a `TabBarView` (depth 1 today) start to drive it.
- Back: `LiquidBackButton` (`Navigator.maybePop`); system back pops the selected tab's top page first (§6.9); the edge swipe and the transition are the app's route's (Cupertino on iOS, the app's `PageTransitionsTheme` on Android, Q17).
- Window controls: `LiquidWindowControlsClearance` on the bar row, as today (`page_bar.dart:123-124`).

### 6.6 `LiquidHideChrome` on a pushed page (Q16, B2)

Native, when the config carries `tabBarHidden: true` (rule §4.4):
1. `setTabBarHidden(true, animated:)` (iOS 18+ API; animated when the tab is shown and Reduce Motion is off);
2. at regular width: remember `sidebar.isHidden`, then hide the sidebar;
3. dismiss an active search keeping its text (VK-551 rule);
4. take the minimize pan back (`updateMinimizePan` also requires `!tabBarHidden`);
5. the navigation bar stays; Flutter's insets become the top page's (the bar at the top, the home indicator at the bottom).

When it ends: `setTabBarHidden(false, animated:)`; a sidebar that was tiled comes back tiled; an overlay never comes back (it is transient, as in `setChromeVisible`, `NativeTabsController.swift:429-432`).

**Regressions that trigger the fall-back (Q16).** B2's task M3 checks each, on iPhone 17 Pro and iPad Air 11-inch (M4), iOS 26.5 and 27.0. Any one of them fails → B2 implements the fall-back of §4.4 instead and records which one in `docs/qa/p3b2/measure.md` and the PR:
- a touch on the Flutter page (where the tab bar was, or beside the navigation bar) does not reach Flutter (hit-test XCTest on the real tree);
- Flutter's top or bottom padding is wrong or jumps by more than 1 pt between the frames before and after the change (safe-area XCTest);
- a tiled sidebar does not come back tiled, or comes back with a wrong start inset;
- the tab bar comes back minimized or stuck, or `MinimizeUITests` (`make ios-minimize`) goes red;
- UIKit shows the tab bar again by itself after a push, a pop or a size-class change while the request holds;
- any existing `RunnerTests` or `RunnerUITests` test goes red.

### 6.7 Back and the edge swipe (Q13: today's behaviour on every tab)

- **Flutter owns the swipe.** UIKit's interactive pops stay disabled on every `ShellNavController` (`ShellNavController.swift:66-69`); the left-edge touch reaches Flutter (`PassThroughView`), where the app's route runs its own back gesture (`MaterialPageRoute` and `CupertinoPageRoute` on iOS: the 20 pt strip, `cupertino/route.dart:31`, `:798-806`).
- **No stack change mid-swipe.** While the gesture runs, the top route is still current and the page still on screen (`page_registry.dart:48`), so the stack is unchanged and no config with other pages is sent. At commit the route pops, the next frame's config has the shorter stack, and UIKit pops with its own animation: the bar switches at release. A cancelled swipe sends nothing.
- **A page that refuses** (`PopScope(canPop: false)`): Flutter disables its swipe; the back circle and the history menu are proposals that `maybePop` refuses (unchanged).
- **iPad tiled sidebar:** the strip is at the body's leading edge, right of the sidebar (§6.3).
- **Android:** system back pops the selected tab's top page first; the app's predictive-back transition, if its theme has one.

### 6.8 Minimize on scroll (VK-600) on every tab (B2)

- **The per-tab host survives.** Each non-search destination keeps exactly one eagerly built host carrying its `MinimizeProxy` for the life of its tabs: the root `PageHostController(minimizes: true)` of its `ShellNavController`, built in `rebuildTabsIfNeeded` before UIKit asks the provider (as `TabHostController` is today, `NativeTabsController.swift:282-285`). A push, a pop or a config that keeps the structure never rebuilds it.
- **Pushed pages minimize too**, as the Flutter bar does (it minimizes on any vertical user scroll of the body, `liquid_shell.dart:1078-1097`). Every page host of a non-search tab owns a `MinimizeProxy` registered as its `.bottom` content scroll view, next to its page proxy (`.top`). UIKit's tab bar follows the selected navigation controller's top page.
- **A push or a pop keeps the bar's form.** Dart's offset per tab is virtual and continuous across views (`MinimizeScrollTracker`, `native_minimize.dart:25-154`); every config with another stack forces a resend after it (`nativeTabsMayRebuild`, `:161-167`; `liquid_shell.dart:466-471`), and native applies it to the new top host. The pan moves to the new top host's proxy at the end of `apply` (`updateMinimizePan`).
- A popped host gives its pan back to its proxy first (as `TabHostController.deinit`, `NativeTabsController.swift:928-930`).
- The bottom edge-effect policy (`MinimizeProxy.hidesBottomEdgeEffect`) applies to every host's proxy, hosts pushed later included.
- At regular width every host's proxy resets to 0 (as `:759`).
- The search tab: no minimize (VK-600 Q5); its hosts are `minimizes: false`.
- **Fall-back** (B2's task M2): if UIKit does not follow a pushed host's `.bottom` proxy (the bar never minimizes on a pushed page, or minimizes from the wrong offset), pushed hosts are built with `minimizes: false`, the root keeps the tab's offset, the bar expands on a push (`expandMinimizedBar()`), and the README says pushed pages do not minimize the native bar. Recorded in `docs/qa/p3b2/measure.md`.

### 6.9 Back routing: VK-593, VK-680, VK-776

P3b-2 changes none of these rules; B2 keeps their tests green.
- **VK-593:** system back and the edge swipe pop the deepest on-screen navigator that can pop, through its own `PopScope`, once (`_popBranch`, `liquid_shell.dart:825-848`; walk `branch_navigators.dart:151-214`).
- **VK-680:** a tab revealed frames after its selection is found by a re-scan; a hidden tab's pages never count.
- **VK-776 (branch S, in flight):** a shell nested directly in an outer shell's body (same route, no navigator between) steps aside: the inner shell's `PopScope` lets the route pop and does not act, and the outer shell delegates back to it in its own order (overlay → search → the selected tab's content). It also fixes a hidden nested shell blocking Android back, and one back acting in both shells (wave-2 bugs evidence §2.4 B). **B2 starts after S merges** and does not edit `_backScope`, `didChangeDependencies`'s route logic, `_bodySubtree` or `branch_navigators.dart`.
- **The native back circle and pop-to** stay proposals for the pages the native bar shows (`_onNativeBack`, `liquid_shell.dart:567-579`; `_onNativePopTo`, `:593-616`), from the shell's own page records. A navigator nested inside a page has no native bar entry (VK-593 non-goal).

### 6.10 Pages above the shell, nested shells

- **Above the shell** (the root navigator): the native chrome hides while they cover the shell (P2 §7.4, `_covered`); a `LiquidPage` there is outside the shell's scope and draws the Flutter bar (Q16). Unchanged.
- **A nested shell** must use `nativeChrome: off` (`liquid_shell.dart:190-193`); its `LiquidPage`s register with it and draw the Flutter bar. The outer tab's native stack shows only the outer shell's pages. B2 adds a guard test; B5 documents "do not wrap a nested shell in a `LiquidPage`" (two bars would stack).

## 7. The spike (VK-440, decides VK-444)

### 7.1 Question

Can the native navigation bar follow the user's finger during a back swipe on any tab, frame by frame, with Flutter's page, without any public API change? The 10-10 probe (UIKit's recognizer drives a route) cannot start: touches never reach UIKit's recognizers (B-1) and the pop override swallows the interactive pop (B-2); an iPad tiled sidebar leaves the native edge unreachable (B-3).

### 7.2 Approach: "Flutter drives the native bar" first (Q13)

Flutter keeps the touch, so there is one gesture arena (no carve-out, `PageView` conflicts resolved as today, an edge beside a tiled sidebar):

1. **B-observe.** The app's route runs its own back gesture. While the selected tab's top `LiquidPage` route is in a user gesture (`navigator.userGestureInProgressNotifier`, `flutter@3.44.6:widgets/navigator.dart:5819`) the shell forwards `progress = 1 − route.animation.value` once per frame to native (a throwaway channel message), with Flutter's frame timestamp. The `PageEntry` already holds the route (`page_registry.dart:26`).
2. **B-drive** (if B-observe cannot give a clean start, end or progress, or to try a wider swipe): a shell-owned horizontal drag in Flutter drives the route through Flutter's public back-gesture API on 3.44, `PredictiveBackRoute` (`routes.dart:654-679`): `handleStartBackGesture(progress:)`, `handleUpdateBackGestureProgress(progress:)` (the route's value, 1 = fully shown) and `handleCancelBackGesture()`. **Commit with a plain `navigator.pop()`**, then `navigator.didStopUserGesture()` once the route's animation is dismissed, **not** `handleCommitBackGesture()`, which pops and then `reverse(from: upperBound)`, snapping the page back to fully shown before it slides out (`routes.dart:588-601`; evidence S7).
3. **Native side (both):** `ShellNavController` starts an interactive pop on "began": a flag bypasses `proposePop`, a `UINavigationControllerDelegate` returns an animator that moves nothing visible (the hosts are clear) and a `UIPercentDrivenInteractiveTransition`; "changed" calls `update(progress)`; Flutter's commit (the shorter stack) calls `finish()`, a cancel calls `cancel()`; the next config then equals native's stack.
4. **First measurement (B-2):** one XCTest on the spike branch pushes two hosts, re-enables the recognizer and calls `nav.popViewController(animated: true)`, then checks `transitionCoordinator`: it shows how the override interacts with an interactive pop before any probe code is written.

### 7.3 "UIKit drives Flutter" later

Only if B fails on bar fidelity and the timebox has time left; otherwise it becomes a 0.1.x follow-up spike. It needs: a leading strip carved out of `PassThroughView` while the selected nav has more than one page and the top page may pop (B-1); `proposePop` bypassed while the recognizer is `.began`/`.changed` (B-2); Flutter driven through `PredictiveBackRoute` with the same `pop()` + `didStopUserGesture()` commit; `PopScope` mirrored per page natively (a race between configs). It has no tiled-sidebar edge (B-3), and Flutter loses taps and drags in the strip.

### 7.4 GO / NO-GO criteria

Measured on iPhone 17 Pro and iPad Air 11-inch (M4) simulators, iOS 26.5 and 27.0 (each agent's own), at the simulator's display rate (120 Hz where it renders it, else 60 Hz, recorded), then confirmed by the owner on a device. "Frame" means one frame at the measured rate. 20 swipes per device and runtime unless said otherwise.

| # | Criterion | Number | Blocking |
|---|---|---|---|
| G1 | Visual sync: native `percentComplete` vs Flutter progress (`1 − route.animation.value`), per frame, paired by timestamp | `abs(Δ) ≤ 0.02` in ≥ 95 % of frames, never `abs(Δ) > 0.05`; equivalently within 1 frame, never 2 apart | yes |
| G2 | Frame timing, profile build, during swipes | ≤ 2 % of frames over budget (8.3 ms at 120 Hz, 16.7 ms at 60 Hz); no frame over 2 budgets; the per-frame message adds ≤ 1 ms p95 to the UI thread | yes |
| G3 | Cancel: released before the threshold | 20/20 return to the start; no route popped; no stack change sent; native `viewControllers.count` unchanged | yes |
| G4 | Commit | 20/20 pop exactly one route; native count equals Dart's stack within 1 frame after both animations end; no `onBackTapped` / `onPopToPage` sent | yes |
| G5 | iPad tiled sidebar edge (landscape, sidebar tiled) | 20/20 swipes started within 20 pt right of the sidebar's trailing edge begin the gesture and meet G1; the sidebar never receives the touch | yes |
| G6 | Inset hold mid-swipe between pages whose tops differ (evidence R4) | Flutter's top padding moves ≤ 1 pt until the end | no: a GO task |
| G7 | Large title and edge effect | no visible jump > 1 pt at the end (recording) | no: a GO task |
| G8 | Lifecycle | Flutter never reports `inactive` or `paused` | yes |
| G9 | Accessibility | VoiceOver's escape and the back circle still pop through the proposals | no: a GO task |
| G10 | A refusing page (`PopScope(canPop: false)`) | no swipe starts; the native bar does not move | no: a GO task |
| G11 | A horizontal `PageView` in the page (B-drive only) | keeps its swipe | no: a GO task |

**GO** when every blocking row passes with one probe within the **2-day timebox**. **NO-GO** when any blocking row still fails at its end.

### 7.5 What is thrown away, what is kept

- **Thrown away:** all probe code (Swift probe, the Dart forwarder, the throwaway channel message, example tweaks). It lives in the working tree or on a local branch that is deleted; it is never pushed or merged.
- **Kept:** `docs/qa/p3b/s2-spike.md`: the question, the probes run, the numbers per row of §7.4 per device and runtime, the decision, the UIKit and Flutter calls that worked (or why not), and the names of recordings and logs (the files stay out of the repository). One commit on `VK-440-back-swipe-spike`, one PR.

### 7.6 What the decision changes

- **NO-GO:** nothing more. B2's NO-GO guards (§8.2) are the shipped behaviour; VK-444 closes with the write-up; the README keeps "the native back swipe does not follow the finger"; a finger-tracked swipe goes to the backlog for 0.1.x ("UIKit drives Flutter", or a later Flutter).
- **GO:** nothing in B2–B5 depends on it (no API does). A branch `VK-444-swipe-sync` after 0.1.0 (0.1.x) adds internal pieces only: a Dart → native message (for example `setBackGesture(int tab, NativeBackGesturePhase phase, double progress)`), `ShellNavController.beginInteractivePop()` / `updateInteractivePop(_:)` / `finishInteractivePop(cancelled:)`, an inset hold while `transitionCoordinator?.isInteractive`, and a shell-side forwarder from the top page's route; plus G6, G7, G9–G11 as tasks; its README line and CHANGELOG entry ship in that 0.1.x release. A GO with "UIKit drives Flutter" adds the `PassThroughView` carve-out and an internal `NativePage.interactivePop` flag. `LiquidPage`, `LiquidPageAction` and `LiquidShell` stay as they are.

## 8. Branches

### 8.0 Order and dependencies (Q12)

| Branch | Items | Starts | Depends on | Runs beside | Ships |
|---|---|---|---|---|---|
| B1 `VK-440-back-swipe-spike` | VK-440 (decides VK-444) | now | main | B2, B3 | the write-up (docs only) |
| B2 `VK-441-native-bar-every-tab` | VK-441, VK-442, VK-444's NO-GO guards | after branch S (`VK-776-back-overflow`) merges | main with S; B3 merged before its `_onScroll` edit (§6.5) | B1, B3 | native bars on every tab |
| B3 `VK-445-flutter-page-bar` | VK-445 | now | main | B1, B2 | the Flutter bar's title model and collapse |
| B4 `VK-443-page-actions` | VK-443 | after B2 and B3 merge | B2 (every tab, Pigeon), B3 (`page_bar.dart`, `liquid_page.dart`, `pageTitleModeFor`) | — | page actions |
| B5 `VK-446-p3b2-release` | VK-446 | after B4 merges (and B1's write-up) | B1–B4 | — | docs, images, migration, owner check |

Each branch has its own plan and PR, merges `main` into itself before its PR (never a force-push), and keeps `make verify` green. File ownership keeps the parallel ones apart: B2 does not edit `page_bar.dart`, nor `liquid_page.dart` except one edit made after B3 merges (its `_onScroll` edit): in `_followScroll` it gates the native report (`_handle?.scrolled`) with the same `_drivesLargeTitle` result as the Flutter bar's offset, deferred with it when the report came during a build, and drops `_onScroll`'s `depth == 0` filter (§6.5, §8.2); B3 does not edit `liquid_shell.dart`, `native_layout.dart`, the interface, Pigeon or Swift. Both edit `CHANGELOG.md` (an append under `## 0.1.0-dev.10`).

### 8.1 B1 `VK-440-back-swipe-spike` (throwaway code, keeps a write-up)

- **Scope:** §7. Timebox 2 days. Three tasks: probe B (B-observe, then B-drive if needed); probe A or skip (§7.3); the write-up and the decision.
- **Produces:** `docs/qa/p3b/s2-spike.md` with the decision **GO (B-observe)**, **GO (B-drive)**, **GO (A)** or **NO-GO**, and the numbers. Consumes: the search tab's pushed pages (`example/lib/cases/search.dart`, `SearchUITests` launch `LIQUID_SHELL_EXAMPLE_DEMO=search`), and Home pages once B2 has landed if it has.
- **Files touched (committed):** `docs/qa/p3b/s2-spike.md` only. Probe files anywhere, never committed to the PR branch.
- **Test strategy:** no TDD (throwaway code). Evidence: paired logs (native `percentComplete` and Dart progress with timestamps), `FrameTiming` counts from a profile build, screen recordings (`xcrun simctl io <udid> recordVideo`), the B-2 XCTest (§7.2 step 4). Simulators: iPhone 17 Pro and iPad Air 11-inch (M4), iOS 26.5 and 27.0, created with `xcrun simctl create` and deleted at the end. The owner's device check of the chosen probe if GO.
- **CHANGELOG:** none (no package changes).
- **Commit:** `docs(docs): back swipe spike write-up, <GO|NO-GO> (VK-440)`.

### 8.2 B2 `VK-441-native-bar-every-tab` (VK-441 + VK-442, VK-444's NO-GO guards)

**Scope.**
1. **Measurements first** (`docs/qa/p3b2/measure.md`, simulators iPhone 17 Pro and iPad Air 11-inch (M4), 26.5 and 27.0): M1 a pushed page's back circle and title next to the floating top tab bar (regular, sidebar hidden), beside a tiled sidebar and under an overlay; M2 the tab bar's minimize on a pushed host's `.bottom` proxy (§6.8 fall-back); M3 `setTabBarHidden` in `.tabSidebar` mode against the regression list of §6.6 (Q16 fall-back); M4 `isTiled` and the copied insets on a navigation tree (§6.1). Each result picks the primary design or its fall-back, written in the file.
2. A `ShellNavController` on every destination tab, bar visibility and title modes (§6.1), the stand-in root, the size-class re-apply.
3. Minimize migrated (§6.8).
4. Window controls and `isTiled` (§6.1, §4.5).
5. `tabBarHidden` end to end (§4.4, §6.6), or the fall-back.
6. Dart: the gate, stacks for every tab, the hide split, the scope rules; after B3 merges, the `_onScroll` edit in `liquid_page.dart` (the native report gated by B3's `_drivesLargeTitle` in `_followScroll`, §8.0's exception, §6.5) with its test row.
7. Per-tab debug snapshot, example `PagesCase`, integration test, XCUITest, the NO-GO guards, docs and CHANGELOG.

**Interfaces consumed.** From P3b-1, as merged: `ShellNavController(root:)`, `applyPages(_:rootTitle:tabIndex:shown:events:)`, the pop overrides and `proposePop`, `PageHostController` (`proxy`, `setScrollOffset`, `restingTop`, `flutterTop`, `onBack`), `NativeTabsController.navControllers`, `topHost(ofTab:)`, `PassThroughView.isBackground(_:chainFrom:tabsView:)`, `SearchMath.style`. From VK-600: `MinimizeProxy`, `updateMinimizePan()`, `setMinimizeScroll(tab:offset:)`, `expandMinimizedBar()`, `MinimizeScrollTracker`, `nativeTabsMayRebuild`, `nativeMinimizeActive`. Dart: `PageRegistry`, `PageEntry`, `pageStackFor`, `_stackFor`, `_updatePageStack`, `nativeConfigFor`, `_onNativeBack`, `_onNativePopTo`. From branch S: the hosted-shell back rule, untouched. From B3 (merged before the `_onScroll` edit): `_LiquidPageState._drivesLargeTitle` (§6.5's rule, through VK-593's `isOnScreenUnder`), `_followScroll` and `_onScroll`'s deferral of reports made during a build (`liquid_page.dart`), and `PageHandle.scrolled`'s dartdoc.

**Interfaces produced.**

```swift
// ShellNavController.swift
final class ShellNavController: UINavigationController {
  init(root: PageHostController, search: Bool)            // was init(root:)
  let isSearch: Bool                                       // the search tab's: bar never hidden
  var hosts: [PageHostController] { get }                  // root first
  func applyPages(
    _ pages: [NativePage], rootTitle: String, tabIndex: Int, shown: Bool,
    compact: Bool, events: NativeShellFlutterApiProtocol)  // gains compact:
}
final class PageHostController: UIViewController {
  init(minimizes: Bool)                                    // was init()
  let minimizeProxy: MinimizeProxy?                        // its .bottom content scroll view; nil for the search tab
  // deinit gives the proxy's pan back
}

// PageTitleMath.swift (new, pure; the table of §4.2)
enum PageTitleMath {
  static func rootMode(largeTitle: Bool?, compact: Bool) -> UINavigationItem.LargeTitleDisplayMode
  static func barHidden(pages: [NativePage], compact: Bool) -> Bool
  static let pushedMode: UINavigationItem.LargeTitleDisplayMode   // .never
}

// NativeTabsController.swift
func minimizeProxy(ofTab index: Int) -> MinimizeProxy?   // the tab's top host's; replaces minimizeHost(_:) and minimizeHosts
private var selectedShowsNavigationBar: Bool             // replaces selectedHasNavigationBar
// apply(_:) handles NativeChromeConfig.tabBarHidden (§6.6)
// debugSnapshot() fills NativeDebugSnapshot.tabs
```

- `SearchMath.style(isPad:osMajor:rootLargeTitle:)`: iPhone `rootLargeTitle == true` → `.always` (was `.inline`).
- Pigeon / interface: §5.1–§5.2 rows marked B2 (`tabBarHidden`, `NativeTabSnapshot`, `NativeDebugSnapshot.tabs`); `liquid_shell_ios/lib/src/mapping.dart` maps `tabBarHidden`.
- Dart (`liquid_shell`):
  - `native_layout.dart`: `nativePageBarFor` is deleted with its unit group; `nativeConfigFor(…, bool tabBarHidden = false)`. Fall-back only: `bool nativePageBarFor({required bool engaged, required bool chromeHidden})`.
  - `liquid_shell.dart`: `_nativePageBar = engaged`; the send callback runs `_updatePageStack(selected)` whenever native chrome is engaged (no longer on the search tab only), then sets the config's `tabBarHidden = hideRequested && stack.isNotEmpty` and `hidden = covered || compactDialog || (hideRequested && stack.isEmpty)` (computed after the frame from values taken in the build, as the comment at `:1912-1914` requires; `compactDialog` is today's `(state?.compact ?? false) && !_routeCurrent`). The build's own `hidden` (`:1898-1901`), which feeds the chrome kind and `nativeMinimizeActive`, is unchanged, so the scope reports hidden chrome and minimize stays off in both cases; the stand-in root (`_updatePageStack` prepends it; `_stackRecords[tab]` keeps the records; a private per-tab flag shifts native indices by one in `_onNativePopTo`); the scope's `windowControls` rule (§4.5).
  - No change to `_backScope`, `handleBack`, `_popBranch`, `didChangeDependencies`'s route logic, `branch_navigators.dart` (VK-776).
  - `liquid_page.dart`, after B3 merges (§8.0's exception): `_followScroll` computes `_drivesLargeTitle(origin)` once per vertical report and gates both `_scrollOffset.value` and `_handle?.scrolled` with it, so both writes share the same decision, deferred to after the frame when the report came during a build (§6.5); `_onScroll`'s `depth == 0` line and its comment go. Nothing else in the file changes. `PageHandle.scrolled`'s dartdoc ("the page's first vertical scroll view on screen", worded in B3) then holds.
- Example: `example/lib/cases/pages.dart` (`PagesCase`, id `pages`, entry in `cases.dart`, demo `'pages'` in `example/lib/main.dart:83-96` with semantics on, like `search`). Three tabs, each with its own `Navigator` kept alive in an `IndexedStack`: **Home** (`house`) root `LiquidPage(title: 'Home')` (default title) whose rows push `LiquidPage(title: 'Detail N')`, one of them full-frame `LiquidHideChrome(child: LiquidPage(title: 'Photo', …))`; **Library** (`books.vertical`) root `LiquidPage(title: 'Library', largeTitle: true)`; **Settings** (`gear`) root without `LiquidPage` (the stand-in root) pushing `LiquidPage(title: 'About')` and `LiquidPage(title: 'Profile')` with a `TextField` (the owner's Telex check). English UI. `HideChromeCase` is unchanged.

**Files touched.** `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/{NativeTabsController,ShellNavController,SearchMath}.swift`, new `PageTitleMath.swift`, `liquid_shell_ios/pigeons/native_shell.dart` + `lib/src/native_shell_api.g.dart` + `NativeShellApi.g.swift`, `liquid_shell_ios/lib/src/mapping.dart`, `liquid_shell_platform_interface/lib/src/native_chrome.dart`, `liquid_shell/lib/src/native/native_layout.dart`, `liquid_shell/lib/src/shell/liquid_shell.dart`, `liquid_shell/lib/src/shell/shell_scope.dart` (dartdoc of `nativePageBar` and `LiquidHideChrome`), `liquid_shell/lib/src/pages/liquid_page.dart` (`_onScroll` and `_followScroll` only, §8.0), tests (below), `liquid_shell/example/lib/{cases/pages.dart,cases/cases.dart,main.dart}`, `liquid_shell/example/integration_test/native_pages_test.dart`, `liquid_shell/example/ios/RunnerUITests/PagesUITests.swift`, `tool/integration_ios_native.sh` (default `NATIVE_TARGETS` gains `native_pages_test.dart`), `Makefile` (`IOS_UI_TIMEOUT`, re-measured with the new suite, with its comment), `liquid_shell/doc/native_chrome.md` (§ "Page stacks and the back button": every tab, minimize, hide chrome), the three CHANGELOGs, `docs/qa/p3b2/measure.md`.

**Test strategy (red first).**

Dart, host (`cd liquid_shell && fvm flutter test …`), new `test/widget/native_pages_test.dart` with `installFakeNative` and the shell harness:

| Test | At the branch base | Why |
|---|---|---|
| every tab of an engaged shell has a native page bar (Home's `nativePageBar`) | red: `Expected: true Actual: <false>` | the search-only gate (`native_layout.dart:197-204`) |
| a page pushed on Home is in the native config (`tabs[0].pages == [Home, Detail]`) | red: `Actual: []` | `_updatePageStack` runs only for the search tab (`liquid_shell.dart:1916`) |
| `LiquidHideChrome` over Home's `LiquidPage`: `tabBarHidden: true`, `hidden: false` | red (after the interface task: `tabBarHidden` false, `hidden` true) | the hide path hides everything |
| `LiquidHideChrome` over a page without `LiquidPage`: `hidden: true` | green, a locker | red under the mutation "always `tabBarHidden`" |
| a `LiquidPage` above a plain root gets the stand-in root (`[Settings, About]`) | red: `Actual: [About]` | no stand-in today |
| pop-to the stand-in root pops every page of the stack | red | index mapping |
| `native_search_test.dart:528-549` rewritten: Home now has `nativePageBar: true` and keeps native's window controls; the search tab stays zero | red: `Expected: true Actual: <false>` on Home's `nativePageBar` | the gate; the search tab's zero comes from Dart's own rule (§4.5) |
| Home without pages under the compact native bar keeps native's window controls | green at the base; red (`Actual: LiquidWindowControls.zero`) once the gate flips without the new rule | `\|\| _nativePageBar` at `liquid_shell.dart:2043-2047` |
| `LiquidHideChrome` at regular width passes native's window controls | red: `Expected: <controls> Actual: zero` | `(engaged && regular)` zeroes them today |
| NO-GO guard: a back swipe in progress on Home sends no stack change; the commit sends the shorter stack once | green, lockers | red under the mutation "stack from `route.isActive` only" |
| IME: a focused, composing field in a `LiquidPage` keeps its `EditableTextState`, focus and composing range when native chrome engages and when `LiquidHideChrome` toggles | green, a locker | red with `key: _childKey` removed (the probe's numbers) |
| a nested shell (`nativeChrome: off`) in Home: its pages draw the Flutter bar; Home's native stack excludes them | green, a locker | red under the mutation "register with the outermost shell" |
| the native report (`PageHandle.scrolled`) follows §6.5's rule, as the Flutter bar does: a multi-line field (typing a third line), two lists side by side (the second), a `PageView` of lists (the first page's, then the shown page's after a swipe), an `IndexedStack` of lists (the shown one; a hidden one never). In `liquid_page_test.dart`, whose `_Registry.offsets` records `scrolled`, or with `native_pages_test.dart`'s fake platform | red: the field's, the second list's and the hidden list's offsets reach `scrolled` (depth 0), and a `PageView`'s list never does (depth 1) | the `depth == 0` filter in `_onScroll`; red with that filter kept or the `_drivesLargeTitle` gate removed |

Plus: `test/unit/native_layout_test.dart` (`nativeConfigFor` carries `tabBarHidden`: red, compile), `liquid_shell_platform_interface/test/native_chrome_test.dart` (`tabBarHidden` in `==`, `hashCode`, `toString`: red, compile), the iOS package's mapping test (red), `example/test/cases_smoke_test.dart` (the `pages` case opens, pushes and pops: red, no case).

XCTest (`make ios-unit IOS_UNIT_DEVICE=<udid>`, `RunnerTests.swift`), red first: `testEveryDestinationTabIsANavigationController` (red: `navControllers[0]` is nil). Then `testATabWithoutPagesHidesItsNavigationBar`, `testAnInlineRootHidesTheBarAndAPushShowsIt`, `testPageTitleMathFollowsTheTitleTable` (the §4.2 rows), a `SearchMath` row next to the existing ones (`RunnerTests.swift:128-160`): `style(isPad: false, osMajor: 26, rootLargeTitle: true).titleMode == .always` (red: `.inline`), `testMinimizeFollowsTheTopPageOfAnyTab` (red: the cast at `NativeTabsController.swift:753`), `testTheRootHostKeepsItsMinimizeProxyThroughAPushAndAPop`, `testAPoppedHostGivesItsPanBack`, `testWindowControlsAreRealUnderAHiddenBarAndZeroUnderAShownOne`, `testTabBarHiddenKeepsTheNavigationBar`, `testTabBarHiddenPutsATiledSidebarBack` (iPad), `testTabBarHiddenDismissesAnActiveSearchKeepingItsText`, `testASizeClassChangeReappliesTheTitleModes` (iPad), `testTheDebugSnapshotListsEveryTab`, `testTheBodyUnderAHiddenNavigationBarReachesFlutter`. The P2 and VK-600 XCTests (hit tests beside the pill, centre, under the bar, beside a tiled sidebar, the overlay's dimming view; tiled, overlay held top, compact and hidden compact bar safe areas; sidebar-only tabs; dormant keeps the tabs; minimize at `RunnerTests.swift:1433-1764`, moved from `minimizeHost(_:)` to `minimizeProxy(ofTab:)`) run unchanged against the navigation trees: that is their re-proof.

XCUITest: `PagesUITests.swift` (`make ios-ui`, launch `LIQUID_SHELL_EXAMPLE_DEMO=pages`), red first `testABackTapAndSwipeOnHomesPushedPage` (red: no native back circle on Home), then `testHideChromeOverAPageKeepsTheNavigationBar`; `MinimizeUITests` gains `testAPushedPageOnHomeMinimizesTheBar` (`make ios-minimize`). `SearchUITests` stays green.

Integration: `native_pages_test.dart` (`NATIVE_DEVICES=… NATIVE_TARGETS=native_pages_test.dart make integration-ios-native`): per-tab snapshot after pushes on Home and Settings (titles, `barHidden`, `titleModes`, the stand-in), hide chrome, lifecycle stays `resumed`, screenshots `pages_<run>_<state>.png`.

Targets: iPhone 17 Pro and iPad Air 11-inch (M4) on iOS 26.5 for the whole `RunnerTests` and `RunnerUITests`; the new tests also on the 27.0 pair; `make ios-minimize` on an iPhone 17 (iOS 26.5, CI's blocking device). Own simulators, deleted at the end.

**CHANGELOG** (`## 0.1.0-dev.10`):

`liquid_shell/CHANGELOG.md`:
```markdown
- **Native navigation bars on every tab (VK-441, VK-442).** With native
  chrome on iOS 26+, a `LiquidPage` on any tab now gets UIKit's navigation
  bar: its title, the glass back circle and its history menu, the large
  title and the scroll-edge effect. Before, only the search tab had one and
  the other tabs drew the Flutter bar. A tab whose pages do not use
  `LiquidPage` looks as before, and so does a root page with an inline
  title: their bar stays hidden.
- **Behaviour change (VK-442).** With native chrome, `LiquidHideChrome` over
  a `LiquidPage` hides only the tab bar and the sidebar; the page's
  navigation bar stays, as the Flutter bar already did. Over a page without
  `LiquidPage` it still hides everything.
- **Behaviour change (VK-441).** The native tab bar's minimize
  (`minimizeOnScroll`) now follows pushed pages too, as the Flutter bar
  does. A push or a pop keeps the bar's form.
- **Behaviour change (VK-442).** Native large titles follow the 0.1.0 title
  model: `largeTitle: true` on a root page is a large-title row that
  collapses as the page scrolls (on the iPhone's search tab it sat on the
  bar row), and a pushed page's title is always inline.
- A `LiquidPage` pushed above a page without one now gets the native back
  circle: a root titled with the destination's label stands in for that
  page (VK-442).
- `LiquidShellScopeData.nativePageBar` is true on every tab of an engaged
  shell. Under the compact native bar, `windowControls` is the real cluster
  while the selected tab's navigation bar is hidden and zero while it shows;
  with `LiquidHideChrome` at regular width it is no longer zero when nothing
  clears the cluster (VK-442).
- The edge swipe on any tab's pushed page stays Flutter's: the page follows
  the finger, and the native bar switches when the gesture ends (VK-444).
```

`liquid_shell_platform_interface/CHANGELOG.md`:
```markdown
- `LiquidNativeChromeConfig.tabBarHidden` (default `false`): hide the tab
  bar and the sidebar but keep the selected tab's navigation bar. It joins
  `==`, `hashCode` and `toString` (VK-442).
- `LiquidNativePage.largeTitle` applies to a tab's root page only; pushed
  pages are inline (VK-442).
```

`liquid_shell_ios/CHANGELOG.md`:
```markdown
- Every destination tab is a clear navigation controller (VK-441). Its
  root page host also carries the tab bar's minimize proxy, and so does
  every pushed host. The bar is hidden without pages and for a single root
  page with an inline title. The channel gains
  `NativeChromeConfig.tabBarHidden` and a per-tab debug snapshot
  (`NativeDebugSnapshot.tabs`).
- `tabBarHidden` hides the tab bar and the sidebar, keeps the navigation
  bar, puts a tiled sidebar back afterwards and dismisses an active search
  keeping its text (VK-442).
- Window controls are zero while the selected tab's navigation bar shows,
  also at compact width; real under a hidden one (VK-442).
```
(With the Q16 fall-back, the `tabBarHidden` lines are replaced by one: "`LiquidHideChrome` over a `LiquidPage` shows the Flutter bar while the native chrome is hidden".)

### 8.3 B3 `VK-445-flutter-page-bar`

**Scope.** The title model of §4.2 in the Flutter bar: the collapsing row for `largeTitle: true` roots, pushed pages inline, the `hidden` and `inline` modes; the collapse driven by the page's first vertical scroll view on screen (§6.5's rule); dartdoc of `LiquidPage` (native bars on every tab, the title model).

**Interfaces consumed.** P3b-1's `FlutterPageBar` (`page_bar.dart:23-158`), `kPageBarExtent`, `kLargeTitleExtent`, `LiquidPage`'s `_onScroll` filter and `_childKey` (`liquid_page.dart:66`, `:127-154`), `LiquidShellScopeData.sizeClass` and `searchPhase`, `LiquidShellScope.contentPaddingOf`, `LiquidWindowControlsClearance`, `LiquidBackButton`, VK-593's `isOnScreenUnder` (`branch_navigators.dart`, unchanged). Nothing from B2.

**Interfaces produced.**

```dart
// lib/src/pages/page_title.dart (new, internal, not exported)
/// How a LiquidPage's title is drawn; the same table as the native bar.
enum PageTitleMode { hidden, inline, largeInRow, largeCollapsing }

PageTitleMode pageTitleModeFor({
  required bool root,
  required bool? largeTitle,
  required LiquidSizeClass sizeClass,
  bool hasActions = false, // B4 passes actions.isNotEmpty
});

// lib/src/pages/page_bar.dart
const double kPageBarExtent = 54;    // unchanged
const double kLargeTitleExtent = 52; // unchanged

/// The collapse at scroll [offset] (points below the top) of a root page
/// with a collapsing large title: the large row moves up by largeShift
/// (0..extent); the inline title's opacity rises from 0 at extent / 2 to
/// 1 at extent.
({double largeShift, double inlineOpacity}) pageBarCollapse(
  double offset, {
  double extent = kLargeTitleExtent,
});

class FlutterPageBar extends StatelessWidget {
  const FlutterPageBar({
    required this.title,
    required this.mode,           // never PageTitleMode.hidden (asserted)
    required this.canPop,
    required this.hideLargeTitle,
    required this.child,
    this.scrollOffset,            // ValueListenable<double>?: drives largeCollapsing
    super.key,
  });
}
```

- `pageBarCollapse`: `largeShift = offset.clamp(0, extent)`; `inlineOpacity = ((offset − extent / 2) / (extent / 2)).clamp(0, 1)`. Values: −30 → (0, 0); 0 → (0, 0); 26 → (26, 0); 39 → (39, 0.5); 52 → (52, 1); 200 → (52, 1).
- `LiquidPage` (B3): its public constructor is unchanged; its state gains a `ValueNotifier<double>`, passed as `scrollOffset`. `_onScroll` sets it (through `_followScroll`) only from the scroll view that `_drivesLargeTitle` latches (§6.5's rule: the first vertical scroll view on screen to report that is neither nested in another vertical one nor inside an `EditableText`, horizontal ancestors allowed, handed over when disposed or off screen; a scroll view off screen, by `isOnScreenUnder` up to the page, neither takes the latch nor keeps it); the native report keeps the existing depth-0 vertical filter (`liquid_page.dart:127-143`) until B2 mirrors the rule. It returns its child for `hidden`; it keeps the child under `_childKey` in every mode (§5.4). Most reports come outside a build (`ScrollMetricsNotification` is dispatched after the frame, a drag and a fling's frames outside it), but not all: a `jumpTo` made during a build or a layout (`didUpdateWidget`, `didChangeDependencies`, a `LayoutBuilder`) dispatches its `ScrollUpdateNotification` at once, from inside the build. This bullet said before that notification callbacks never run during build or layout; the re-review found the exception (m-1). Such a report is decided after the frame (§6.5), so the notifier is set only outside a build and the latch never walks an inactive driver.
- The collapse rebuilds only the title rows and the scroll-edge mask: `ValueListenableBuilder(valueListenable: scrollOffset, child: <the page>, builder: …)`.

**Files touched.** `liquid_shell/lib/src/pages/{liquid_page,page_bar}.dart`, new `page_title.dart`, `liquid_shell/test/unit/page_bar_test.dart` (new), `liquid_shell/test/widget/liquid_page_test.dart`, `liquid_shell/CHANGELOG.md`, `liquid_shell/lib/src/pages/page_registry.dart` (`PageHandle.scrolled`'s dartdoc only: "on screen"). Nothing else (§8.0).

**Test strategy (red first, host only, `cd liquid_shell && fvm flutter test test/unit/page_bar_test.dart test/widget/liquid_page_test.dart`):**

| Test | At the branch base | Why |
|---|---|---|
| `pageTitleModeFor` follows the title table (every row of §4.2) | red: compile (no function) | new |
| `pageBarCollapse` values above | red: compile | new |
| a root page with `largeTitle: true` draws a 52 pt row under the bar row | red: the title is on the bar row (`page_bar.dart:56`) | Q14 |
| scrolling collapses the large row and fades the inline title in (offsets 0, 26, 52) | red | no collapse today |
| the page's top padding stays `barTop + 106` while the title collapses | red | new |
| a pushed page with `largeTitle: true` is inline (replaces `liquid_page_test.dart:269`) | red: the large row is drawn (`page_bar.dart:57`) | Q14 |
| the collapse never rebuilds the page's child (a build counter over 10 scroll frames) | green once the collapse exists, a locker | red under the mutation "the child built inside the builder" |
| a root page with `largeTitle: false` and no actions draws no bar | green, a locker | unchanged rule |
| the large row hides while the search is active (adapts `:364`) | green, kept | unchanged rule |
| the same geometry with `debugDefaultTargetPlatformOverride = TargetPlatform.android` | green, a locker | parity (Q17) |
| IME: a focused, composing field in a collapsing page keeps its state and composing range through a scroll and a bar switch | green, a locker | red with `_childKey` removed |
| a multi-line text field (a composer under the list) never moves the large title: typing a third line and clearing it (list at 120) | red: typing moves the title 60 → 36 | §6.5's rule; red with the `EditableText` check removed |
| of two lists side by side, only the first drives the large title | red: the second at 5 moves the title to 55 | §6.5's rule; red without the latch |
| when the driving list is disposed, the next list to report drives the title | red: the second list moves it while the first lives | §6.5's rule; red without the hand-over (the `mounted` check) |
| a list nested in the page's list never drives the title (it reports first) | green, a locker | red with the vertical-ancestor check removed |
| in a `PageView` of lists the first page's list drives the title; once that page is disposed, the shown list takes over at its first scroll | red: never collapses | §6.5's rule; red when a horizontal ancestor disqualifies |
| in a `PageView` whose pages stay alive, the shown page's list takes over at its first scroll; the first page's list, off screen, never moves the title (rewritten at the final review: it asserted that the first page's list drove the title for good) | red: never collapses; at f67f577 the shown list at 30 leaves the title at 8 | §6.5's rule; red without the on-screen check |
| in an `IndexedStack` of lists (a segment switcher), the shown list takes over at its first scroll; a hidden list never moves the title | red: never collapses; at f67f577 the shown list at 30 leaves the title at 8 | §6.5's rule; red without the driver's on-screen check |
| of two `Offstage` lists, the hidden one never moves the title, even the one that drove it | red: never collapses; at f67f577 the hidden list at 20 moves the title to 40 | §6.5's rule; red without the reporting scroll view's on-screen check |
| when lists jump (in `didUpdateWidget`) during the build that removes the list that drives the title, the first of them takes over after the frame, with no error widget | red at de4933c: `Looking up a deactivated widget's ancestor is unsafe.` (`isOnScreenUnder` from `_drivesLargeTitle`, once per jumping list) | §6.5's deferral; red without it; red with a single slot where the last report wins (the second list at 30 moves the title, 60 → 30) |
| when the list that drives the title jumps during a build, the title follows it after the frame | red at de4933c: `setState() or markNeedsBuild() called during build.` | §6.5's deferral; red without it |
| when lists jump during a build, the first to report takes over after the frame, not the first to lay out | red with the after-frame decision disabled: `Expected: <60.0> Actual: <30.0>` | §6.5's per-view, first-report-order decision; red without it |
| a page in a hidden tab (an `IndexedStack` above the page) still follows its own list | green, a locker | red (the title at 60, not 8) when the on-screen walk goes past the page |

The `inline` and `largeInRow` modes keep today's geometry pixel for pixel. No goldens change in B3: no existing golden uses `largeTitle: true` (`example/lib/cases/search.dart:138-141` passes none), and pushed pages there are inline already. New images come in B5. `make verify` on the branch.

**CHANGELOG** (`liquid_shell/CHANGELOG.md`, `## 0.1.0-dev.10`):
```markdown
- **Flutter page bar, complete (VK-445).** On iOS before 26, on Android and
  with Flutter chrome, `LiquidPage(largeTitle: true)` on a root page now
  draws its large title on a row of its own that scrolls away as the page
  scrolls, while the inline title fades into the bar row, as UIKit's does.
  The page's top padding stays put while it collapses.
- **Behaviour change (VK-445).** A pushed page's title is always inline:
  `largeTitle` applies to root pages only. Before, the Flutter bar drew a
  pushed page's large title on a row of its own, where UIKit drew it small.
- **Behaviour change (VK-445).** `largeTitle: true` on a root page now means
  the collapsing row. Before, the Flutter bar put it on the bar row, which
  is what `largeTitle: null` gives a root page at compact width.
```

### 8.4 B4 `VK-443-page-actions`

**Scope.** `LiquidPageAction` and `LiquidPage.actions` (§4.1, §4.3), the platform contract rows marked B4 (§5.1–§5.2), native bar buttons, Flutter circles, tap routing, the example's actions.

**Interfaces consumed.** From B2: stacks on every tab, `ShellNavController.applyPages(…compact:…)`, `PageHostController`, `PageTitleMath.barHidden`, `NativeTabSnapshot`, the stand-in index mapping, `PagesCase`, `PagesUITests`. From B3: `pageTitleModeFor(hasActions:)`, `FlutterPageBar(mode:, scrollOffset:)`, the bar row's layout.

**Interfaces produced.**

```dart
// liquid_shell (public): LiquidPageAction (§4.3), LiquidPage.actions, LiquidPage.maxActions = 3
// liquid_shell (internal)
PageEntry({…, this.actions = const <LiquidPageAction>[]}); // sameAs compares
//   (sfSymbol, label, onPressed != null) per action, never the callbacks
FlutterPageBar({…, this.actions = const <LiquidPageAction>[]});
// _PageRecord.update(next): always stores next (newest callbacks); rebuilds
//   the shell only when !next.sameAs(entry)
// _onNativeEvent: case LiquidNativePageActionTapped → _onNativePageAction(tab, page, index, sfSymbol)
```

```swift
// PageHostController
func setActions(_ actions: [NativePageAction], onTap: @escaping (Int) -> Void)
// rightBarButtonItems = actions.prefix(3).reversed(): UIBarButtonItem(image:
// UIImage(systemName:), primaryAction:), accessibilityLabel = label,
// isEnabled = enabled; an unknown symbol → UIBarButtonItem(title: label);
// rebuilt only when (sfSymbol, label, enabled) change.
// ShellNavController.applyPages passes each page's actions; onTap sends
// onPageActionTapped(tab, page, index, sfSymbol).
// PageTitleMath.barHidden: a single root page with actions shows the bar.
```

- **Tap routing (Dart).** `_onNativePageAction` runs `actions[index].onPressed` only when: `tab` is the selected index; the shell's route is current and not covered; `page` is the top of `_stackRecords[tab]` (stand-in offset applied); that record is still registered; `index < actions.length`; `actions[index].sfSymbol == sfSymbol`; `onPressed != null`. Anything else is dropped. Native changes nothing on a tap (no pop, no state).
- **Flutter tap:** the circle calls `onPressed` directly.
- `pageTitleModeFor(hasActions: actions.isNotEmpty)` in `LiquidPage`.
- Mapping (`liquid_shell_ios/lib/src/mapping.dart`): the first three actions; `onPageActionTapped` → `LiquidNativePageActionTapped`.

**Files touched.** `liquid_shell/lib/liquid_shell.dart`, new `liquid_shell/lib/src/pages/page_action.dart`, `liquid_shell/lib/src/pages/{liquid_page,page_bar,page_registry,page_title}.dart`, `liquid_shell/lib/src/native/native_layout.dart` (pages carry actions), `liquid_shell/lib/src/shell/liquid_shell.dart` (records, event), `liquid_shell_platform_interface/lib/src/native_chrome.dart`, Pigeon source and both generated files, `liquid_shell_ios/lib/src/{mapping,platform}.dart`, `ShellNavController.swift`, `PageTitleMath.swift`, `NativeTabsController.swift` (debug tap and snapshot), tests, `example/lib/cases/pages.dart` (Home root: `plus` "Add"; Detail: `square.and.arrow.up` "Share", `heart`/`heart.fill` "Favourite" toggling, `trash` "Delete" disabled with `onPressed: null`), `PagesUITests.swift`, three CHANGELOGs.

**Test strategy (red first).**
- Interface (`liquid_shell_platform_interface/test/native_chrome_test.dart`): `LiquidNativePageAction` field-by-field equality; `LiquidNativePage.actions` in `==`; `LiquidNativePageActionTapped` equality. Red: compile.
- iOS Dart mapping test: actions mapped, at most three; the event decoded from `onPageActionTapped`. Red.
- `liquid_shell` unit: `PageEntry.sameAs` ignores callbacks and sees `sfSymbol`, `label`, enabled. Red.
- Widget (`native_pages_test.dart`): the actions reach the native page; a native tap runs `onPressed`; a tap for a page no longer on top, a tap whose symbol no longer matches, a disabled action's tap and a tap from another tab are dropped; the newest `onPressed` runs after a rebuild with a new closure (red until `update` always stores the entry). Red first: "the actions reach the native page" (`Actual: []`).
- Widget (`liquid_page_test.dart`): circles at the trailing end in reading order (and mirrored in RTL); a disabled action is not tappable and reports `enabled: false` to semantics; more than three on a `LiquidPage` is a debug assertion (`tester.takeException()` is an `AssertionError`), and `FlutterPageBar` given four actions (it does not assert) draws the first three; the inline title stays centred between the back button and the actions; a root inline page with actions shows its bar. Red first: "circles at the trailing end".
- XCTest: `testPageActionsBecomeBarButtonItems` (order reversed, labels, enabled), `testAPageActionTapSendsAnEventAndDoesNotPop`, `testAnUnknownSymbolShowsItsLabel`, `testActionsOnARootInlinePageShowTheBar`, `PageTitleMath` rows with actions. Red first: the first one.
- XCUITest (`PagesUITests`): `testAPageActionTapRunsTheAppsCallback` (the "Favourite" symbol changes after the tap, read from the native button).
- Targets: as B2.

**CHANGELOG** (`## 0.1.0-dev.10`):

`liquid_shell/CHANGELOG.md`:
```markdown
- **Page actions (VK-443).** `LiquidPage(actions: [...])` takes up to three
  `LiquidPageAction`s (`sfSymbol`, `icon`, `label`, `onPressed`; a null
  `onPressed` disables the action). With native chrome on iOS 26+ they are
  UIKit bar buttons in the navigation bar's glass group; elsewhere 44 pt
  glass circles at the trailing end of the Flutter bar. A root page with an
  inline title shows its bar when it has actions. More than three is a
  debug assertion; release builds show the first three.
```

`liquid_shell_platform_interface/CHANGELOG.md`:
```markdown
- **Breaking (VK-443).** Page actions: `LiquidNativePageAction` (`sfSymbol`,
  `label`, `enabled`), `LiquidNativePage.actions` (default empty) and the
  event `LiquidNativePageActionTapped(tab, page:, index:, sfSymbol:)`.
  `LiquidNativeEvent` is sealed: an exhaustive `switch` over it needs the
  new case.
```

`liquid_shell_ios/CHANGELOG.md`:
```markdown
- Page actions (VK-443): `NativePage.actions` become the page host's
  `rightBarButtonItems` (the SF Symbol image, the accessibility label, the
  enabled state; an unknown symbol shows the label as text). A tap sends
  `onPageActionTapped(tab, page, index, sfSymbol)` and changes nothing
  natively. Tests get `debugTap(.pageAction, index)` and the top page's
  `actionSymbols` and `actionsEnabled` in `NativeDebugSnapshot.tabs`.
```

### 8.5 B5 `VK-446-p3b2-release`

**Scope.** Docs, images, example snippet, migration notes, the full verification and the owner's device check. No library code. **Consumes** B1's decision (the README's swipe line), B2–B4's API and behaviour as merged, `PagesCase`, the integration screenshots.

- `liquid_shell/README.md`: "Pages and the back button" (`:470-490`) rewritten: native on every tab, the title table (§4.2, short), actions, the hide-chrome rule, the swipe rule; a `PagesCase` snippet (`// #docregion pages`, `make snippets`); Limitations (`:1402-1407`): drop "on the search tab only", keep the swipe line per the spike's decision, keep "pages above the shell keep the Flutter bar", add "a nested shell's pages draw the Flutter bar"; Known issues (`:1468-1469`) loses its "search tab only" line; Roadmap (`:1493-1501`): 0.1.0 includes native bars on every tab and page actions; planned: finger-tracked native swipe (0.1.x if GO), avatar and menu actions.
- `liquid_shell/doc/native_chrome.md` (`:213-244`) final pass; `liquid_shell/doc/router_integration.md`: pages in branch navigators, the stand-in root, nested shells.
- `liquid_shell/CHANGELOG.md`: the "Migration from 0.1.0-dev.9" section (§4.6) at the top of `## 0.1.0-dev.10`.
- Images: `case_pages_*` goldens and doc images through `make goldens-update` on macOS + Flutter 3.44.6 (Q11: 3.44 goldens until 0.1.0); native screenshots from `make integration-ios-native` (`pages_<run>_<state>.png`) copied to `liquid_shell/doc/images/native_iphone_pages.png` and `native_ipad_pages.png`, recompressed with `tool/compress_pngs.dart`.
- A one-line pointer to this spec at the top of §10 of `docs/specs/2026-10-10-p3b-search-tab-design.md` and of `docs/plans/2026-10-10-p3b-nav-bar.md`.
- `docs/qa/p3b2/manual.md`: the owner's device check (below).

**Verification.** `make verify`; `make ios-unit`, `make ios-ui`, `make ios-minimize` on iPhone 17 Pro and iPad Air 11-inch (M4), iOS 26.5, and the new suites on 27.0; `make integration-ios-native` (both devices, 26.5 and 27.0); `make publish-check`. Android: host widget tests cover the Flutter bar; `make integration-android` only on an emulator the agent created, else left to the owner.

**Owner device check** (`docs/qa/p3b2/manual.md`, iPhone and iPad on iOS 26, an Android phone): every tab's pushed page shows the glass back circle; back tap, history menu and edge swipe pop it; `largeTitle: true` collapses on scroll; actions run and the disabled one does not; hide chrome keeps the navigation bar and brings a tiled sidebar back; the tab bar minimizes on a pushed page and keeps its form on pop; Telex in the Profile page's field across a push, a pop and a hide-chrome toggle ("ho hoan kiem" → "hồ hoàn kiếm", no repeated letters); Android: the same states in the Flutter bar, system back pops the tab's page first.

**Test strategy.** No new library tests; `make snippets`, `make public-docs`, the goldens and the suites above are the gate. The goldens are new files (no red-first): their test is red until `make goldens-update` writes them, which the plan shows.

**CHANGELOG:** the migration section only (no new entries in the other packages).

### 8.6 Rules for every branch

- Commits `<type>(<scope>): <summary> (VK-NNN)` with the item of the task (B2: VK-441 for the native tree and minimize, VK-442 for the Dart side, hide chrome and the example, VK-444 for the NO-GO guards), ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. `bash .githooks/pre-commit` by hand before each; never `--no-verify`.
- CHANGELOG entries go under `## 0.1.0-dev.10` at the top of each package's CHANGELOG the branch changes: added under it if it exists after merging `main`, created at the top otherwise. If `0.1.0-dev.10` was published before the branch merges, the branch uses the next unreleased heading instead. No pubspec version change.
- Simulators: each agent creates its own (`xcrun simctl create`) and deletes them at the end; never `simctl shutdown all`, never a physical device. Keep ≥ 10 GB free; delete build output.
- A locker test (green at the base) is shown red by a temporary mutation that is then reverted; the run is pasted into the task report.

## 9. Test strategy: summary

| Layer | Where | Command | Red first in |
|---|---|---|---|
| Pure Dart (title table, collapse, config) | `liquid_shell/test/unit/` | `fvm flutter test` | B2 (`native_layout_test`), B3 (`page_bar_test`), B4 |
| Shell and pages, native mode through the fake platform | `liquid_shell/test/widget/native_pages_test.dart` | `fvm flutter test` | B2, B4 |
| Flutter bar | `liquid_shell/test/widget/liquid_page_test.dart` | `fvm flutter test` | B3, B4 |
| Interface values | `liquid_shell_platform_interface/test/native_chrome_test.dart` | `fvm flutter test` | B2, B4 |
| iOS mapping | `liquid_shell_ios/test/` | `fvm flutter test` | B2, B4 |
| Native tree, minimize, hide chrome, bar buttons | `example/ios/RunnerTests/RunnerTests.swift` | `make ios-unit IOS_UNIT_DEVICE=<udid>` | B2, B4 |
| Real taps and swipes | `example/ios/RunnerUITests/PagesUITests.swift`, `MinimizeUITests.swift` | `make ios-ui`, `make ios-minimize` | B2, B4 |
| End to end on simulators | `example/integration_test/native_pages_test.dart` | `make integration-ios-native` | B2 |
| Images | `example/test/goldens/` | `make goldens-update`, `make goldens` | B5 |

Why these targets: native-only state (navigation controllers, UIKit's minimize, `setTabBarHidden`) is invisible to Dart tests, so it goes red in XCTest; what Dart decides (stacks, hide split, window controls, tap routing, the title model) goes red on the host, where it is fast and exact.

## 10. CHANGELOG

The wording per branch is in §8.2–§8.5; the heading rule in §8.6. Tests alone get no entry. The migration section (§4.6) is B5's.

## 11. Risks

| # | Risk | Handling |
|---|---|---|
| 1 | UIKit's tab bar may not follow a pushed host's `.bottom` proxy | B2 task M2 first; the fall-back of §6.8 |
| 2 | `setTabBarHidden` in `.tabSidebar` mode regresses hit test, safe area, sidebar or minimize | B2 task M3 with the list of §6.6; the Q16 fall-back of §4.4, IME-safe per the probe |
| 3 | iPadOS 26's floating tab bar and a pushed page's bar share a row (unmeasured for plain tabs) | B2 task M1; stop and report on an overlap |
| 4 | Hit-test debt grows: bars on every tab, hidden bars (`PassThroughView.swift:8-13`) | XCTests on the real tree on iPhone and iPad, both runtimes; the owner's real taps in B5 |
| 5 | The title rule lives in Dart and Swift and could drift | One table (§4.2), carried row by row by both test suites |
| 6 | The stand-in root shifts native indices (pop-to, action taps) | One mapping in the shell; tests for pop-to the stand-in and for action taps under it |
| 7 | Two per-frame messages while a `LiquidPage` scrolls on a native tab (page proxy and minimize) | Both coalesced to one per frame and only on change, as today; checked in B2's integration run |
| 8 | Push and pop durations differ (Flutter's route vs UIKit's bar); the config goes out one frame after the push (evidence R9) | Side-by-side in B2's screenshots; accepted as today on the search tab |
| 9 | Sealed `LiquidNativeEvent` gains a subclass (evidence R12) | "Breaking" in the interface CHANGELOG and the migration section |
| 10 | B2 and branch S both edit `liquid_shell.dart` | B2 starts after S and stays out of the back code (§6.9) |
| 11 | B2 and B3 run in parallel | File ownership (§8.0); only the CHANGELOGs overlap |
| 12 | The spike fails or overruns | Nothing depends on it (§7.6); the 2-day timebox |
| 13 | No full-width content swipe in 0.1.0 (Flutter's 20 pt strip) | A fidelity note in the README; only a forwarded recognizer could give it (§7.3) |
| 14 | UIKit groups bar buttons in one glass capsule; the Flutter bar draws circles | Accepted for 0.1.0 (the approved look); noted in the owner's review |
| 15 | New XCUITests lengthen CI's `ios-ui` job | B2 re-measures and updates `IOS_UI_TIMEOUT` with its comment |
| 16 | Goldens under VK-700 (3.44 floor until 0.1.0) | No golden changes before B5; B5 uses `make goldens-update` on 3.44.6 only |
| 17 | iOS 27 differs (search placement, title layout) | Every new native test runs on 27.0 too |

## Quyết định đã duyệt (Q12–Q17)

Chủ sản phẩm trả lời "Ok hết" ngày 2026-10-28 (Q1–Q18; dưới đây là sáu câu của P3b-2).

| Q# | Câu hỏi | Đã chốt |
|---|---|---|
| Q12 | Dùng lại kế hoạch 10/10? | Không (12 điểm lỗi thời, spike S2 như đã viết không chạy được). Một spec delta và một kế hoạch cho mỗi nhánh, duyệt cùng nhau. Spike ∥ thanh native mọi tab ∥ hoàn thiện thanh Flutter; nhánh mọi tab bắt đầu sau khi nhánh S merge; rồi nút hành động; rồi phát hành |
| Q13 | 0.1.0 có chờ vuốt-back bám ngón tay? Ai giữ cử chỉ? | Không chờ; giữ hành vi hiện tại (Flutter vuốt, thanh native đổi khi thả). Spike thử "Flutter lái thanh native" trước, "UIKit lái Flutter" sau. Vuốt bám ngón tay vào 0.1.x |
| Q14 | Mô hình tiêu đề lớn | Kiểu Apple Music: tiêu đề trang gốc trên hàng của thanh, trang đẩy lên tiêu đề nhỏ; `largeTitle: true` cho hàng tiêu đề co lại, chỉ trên trang gốc; giống nhau ở thanh native và thanh Flutter |
| Q15 | Dạng `LiquidPageAction` | Bắt buộc SF Symbol, kèm icon Flutter, label, `onPressed` (null = tắt); tối đa 3; avatar và menu sau 0.1.0 |
| Q16 | Thanh native tự động hay bật tay? `LiquidHideChrome`? Trang trên shell? | Tự động ở mọi tab dùng `LiquidPage`; `LiquidHideChrome` trên trang đẩy lên chỉ ẩn thanh tab/sidebar, giữ thanh native (gây lỗi thì quay về thanh Flutter); trang đẩy trên cả shell giữ thanh Flutter |
| Q17 | Android, iOS < 26; chính sách thay đổi phá vỡ | Cùng API, thanh kính Flutter; app tự lo chuyển trang. Được phá vỡ trước 0.1.0 với một mục Migration; P3b-2 ra bản dev, rồi 0.1.0, rồi semver chặt |

### Quyết định phát sinh

Các câu trên không nói tới những điểm dưới đây. Spec chọn như sau (theo hướng gần nhất với các quyết định đã duyệt và bằng chứng); chủ sản phẩm có thể đổi:

1. **Bảng tiêu đề (Q14) cho trang gốc:** `largeTitle: null` = tiêu đề lớn trên hàng của thanh ở khổ hẹp, không có hàng tiêu đề ở khổ rộng; `false` = không có hàng tiêu đề (trừ khi trang có nút hành động); native ẩn thanh trong hai trường hợp đó. Lý do: giữ đúng luật thanh Flutter đã phát hành (`liquid_page.dart:164`) và tránh tiêu đề nhỏ chen với thanh tab nổi của iPad.
2. **Luật tiêu đề viết hai lần** (Dart `pageTitleModeFor` ở B3, Swift `PageTitleMath` ở B2) theo cùng một bảng, cả hai bộ test mang đủ các dòng của bảng; kênh vẫn chỉ gửi `largeTitle: bool?`. Lý do: B2 và B3 chạy song song được, không đổi kênh.
3. **Gốc thay thế (stand-in root):** `LiquidPage` đầu tiên của tab nằm trên một trang không có `LiquidPage` thì native thêm một gốc mang tên tab, để có nút back như thanh Flutter. Lý do: không có nó, thanh native không có nút back ở chỗ thanh Flutter có.
4. **`LiquidHideChrome` giữ thanh native khi ngăn trang của tab không rỗng** (có `LiquidPage` ở trên, kể cả trang gốc); trang không có `LiquidPage` thì ẩn toàn bộ như cũ. Lý do: thanh thuộc về trang (như thanh Flutter), và đường ẩn của P2 không đổi với app chưa dùng `LiquidPage`.
5. **Điều kiện quay về thanh Flutter (Q16)** là danh sách lỗi cụ thể ở §6.6, đo ở task M3 của B2. Lý do: "nếu gây lỗi" cần tiêu chí kiểm được; probe cho thấy đổi thanh không làm hỏng IME nhờ `GlobalKey` của trang.
6. **Thu nhỏ thanh tab trên trang đẩy lên:** mỗi page host có proxy riêng, đẩy/pop giữ dáng thanh (offset ảo của tab đi tiếp), như thanh Flutter. Nếu UIKit không theo (task M2): chỉ trang gốc thu nhỏ, đẩy trang thì thanh nở ra. Lý do: bằng chứng chọn phương án 1, và giữ ngang hàng với thanh Flutter.
7. **Nút cửa sổ iPad (window controls):** Dart chỉ tự đặt về 0 ở khổ rộng không có yêu cầu ẩn chrome, hoặc khi đang ở tab Tìm; còn lại theo báo cáo của native (native đặt 0 khi thanh của tab đang hiện). Lý do: thanh có thể ẩn trên tab thường; tiện sửa luôn trường hợp ẩn chrome ở khổ rộng đang báo 0 sai.
8. **Chạm nút hành động native** mang (tab, page, index, sfSymbol) và chỉ được nhận khi đúng trang trên cùng của tab đang chọn, đúng biểu tượng, nút đang bật; sai thì bỏ. Lý do: tránh chạy nhầm nút khi app vừa đổi danh sách (R11) mà không thêm bộ đếm.
9. **Hơn 3 nút:** assert ở debug khi state của trang đọc widget (`didChangeDependencies`, `didUpdateWidget`), không đặt trong constructor (`List.length` không phải hằng, `const LiquidPage(...)` phải còn biên dịch được, đã thử với Dart 3.12); bản release chỉ vẽ 3 nút đầu, Dart cắt ở biên kênh.
10. **Thứ tự nút** theo thứ tự đọc (như `AppBar.actions`), native đảo lại cho `rightBarButtonItems`. SF Symbol không tồn tại: native hiện nút chữ bằng `label` và ghi một dòng log debug.
11. **`LiquidPageAction` không có `==`** (nó giữ callback); shell so những gì thanh hiển thị (biểu tượng, nhãn, bật/tắt) và luôn chạy callback mới nhất.
12. **Trên iPhone, tab Tìm với `largeTitle: true`** đổi từ `.inline` sang `.always` (hàng tiêu đề co lại), cho khớp Q14.
13. **VK-444:** quyết định nằm ở bản ghi của B1; phần NO-GO (test chốt) đi cùng B2; nếu GO thì làm ở nhánh `VK-444-swipe-sync` sau 0.1.0, không đổi API. Lý do: Q13 không cho 0.1.0 chờ.
14. **Thứ tự thử trong spike:** B-observe (đọc cử chỉ của route của app) rồi B-drive (shell tự kéo route qua `PredictiveBackRoute`, chốt bằng `navigator.pop()`); "UIKit lái Flutter" chỉ thử nếu B hỏng về độ khớp của thanh và còn thời gian, không thì để 0.1.x. Ngưỡng số ở §7.4 (0,02 / 0,05 tiến độ, 95 % frame, 2 % frame chậm, 20/20 lần, mép 20 pt cạnh sidebar) do spec đặt.
15. **Spike chỉ commit bản ghi** `docs/qa/p3b/s2-spike.md`; không commit video, log hay code thử.
16. **Ví dụ:** case mới `PagesCase` (`pages`) do B2 tạo, B4 thêm nút hành động, B5 đưa đoạn mã vào README; case `hide_chrome` giữ nguyên (trang toàn màn hình không có `LiquidPage`).
17. **Ảnh:** B3 và B4 không đổi golden nào; B5 tạo golden `case_pages_*` và ảnh tài liệu bằng `make goldens-update` trên 3.44.6 (Q11).
18. **B5 không nâng phiên bản:** nâng lên `0.1.0-dev.10` và publish là một việc phát hành riêng sau B5 (như VK-703), vì ở đợt 2 chỉ nhánh R đổi phiên bản. Nếu dev.10 đã publish trước khi một nhánh P3b-2 merge, nhánh đó ghi CHANGELOG dưới tiêu đề chưa phát hành kế tiếp.
19. **Shell lồng** (sub-tabs, `nativeChrome: off`) giữ thanh Flutter cho trang của nó; B2 thêm test chốt, B5 ghi "đừng bọc shell lồng trong `LiquidPage`".
20. **Đổi khổ (size class) trên iPad:** native tự áp lại kiểu tiêu đề và việc ẩn thanh ngay, không chờ Dart (config có thể không đổi nên không được gửi lại).
21. **`tabBarHidden` khi đang tìm** thì đóng ô tìm, giữ chữ (như chrome ẩn, VK-551); sidebar xếp cạnh (tiled) được trả lại, sidebar phủ (overlay) thì không.
22. **B2 bắt đầu sau nhánh S** và không sửa `_backScope`, `didChangeDependencies` (phần route), `_bodySubtree`, `branch_navigators.dart`. Lý do: VK-776 sửa đúng các chỗ đó.
23. **Scroll view nào lái tiêu đề lớn** (chủ sản phẩm chốt hai lần ngày 2026-10-28, cả hai lần chọn phương án a). Sau review Task 3 của B3: scroll view dọc đầu tiên của trang báo vị trí (lần layout đầu hoặc một lần cuộn), không nằm trong một scroll view dọc khác của trang, không bao giờ là của ô nhập chữ (`EditableText`: ô nhiều dòng tự cuộn dọc); scroll view ngang bao quanh không tính; nó lái tiêu đề tới khi bị huỷ, rồi scroll view kế tiếp đủ điều kiện báo vị trí sẽ nhận. Sau review cuối của B3: thêm điều kiện **đang trên màn hình** (`isOnScreenUnder`, chỉ đi tới trang): list ẩn trong `IndexedStack`, dưới `Offstage`, `Visibility` ẩn hay trang `PageView` ngoài khung không nhận và cũng không giữ tiêu đề. Luật ở §6.5, viết một lần trên `_LiquidPageState._drivesLargeTitle` và trong dartdoc của `LiquidPage.child`; B2 dùng cùng kết quả cho thanh native (§8.0, §8.2). Lý do: ô soạn nhiều dòng, list thứ hai và list bị ẩn từng làm tiêu đề nhảy. Khoảng hở đã chấp nhận: sau khi đổi segment hay vuốt trang, tiêu đề giữ vị trí cũ tới lần cuộn đầu của list đang hiện; một list ở ngoài list của trang (header) báo vị trí trước thì giữ tiêu đề luôn. Một opt-in chỉ định scroll view (0.1.x) sẽ lấp các khoảng hở này.
