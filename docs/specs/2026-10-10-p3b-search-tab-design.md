# liquid_shell P3b: search tab, glass back button and a real search example

- **Plane:** VK-407 (parent VK-404)
- **Date:** 2026-10-10
- **Status:** draft for the owner. The owner approves this spec and its two plans together: `docs/plans/2026-10-10-p3b-search-tab.md` (P3b-1) and `docs/plans/2026-10-10-p3b-nav-bar.md` (P3b-2). Open choices are in the last section, "Quyết định cần chủ sản phẩm xác nhận". Every row has a recommended default, and if the owner says nothing the default applies.
- **Branch:** `VK-407-search-tab`, from the P2 branch `VK-346-p2-native-ios` at `a1b9b30` (P2 with VK-405 Task 8). P2 is about to merge. This branch rebases onto `main` once it does. P3a (VK-406, native alerts) edits the same Pigeon source and adds the `RunnerUITests` target. Whichever of P3a and P3b merges second regenerates the channel (`make pigeon`) and reuses the other's test target (§12.6).
- **Floor:** Flutter ≥ 3.44.0 / Dart ^3.12.0 (fvm pins 3.44.6), iOS deployment target 15.0, Pigeon 27.3.0 (dev, exact), `very_good_analysis` 10.3.0. No new runtime dependency.
- **Owner input (binding).** Plane VK-407, comment of 2026-10-10, verbatim:

  > trang search làm sai. Search cũng là 1 tab, không hoạt động là push một trang mới đè lên màn hình. Nút back cũng chưa phải hiệu ứng kính. Thêm nữa tab search trên iPad và iPhone sẽ hoạt động khác nhau. Trên iPad: tab search sẽ liền với thanh tab, input search nằm ở trên cùng, lúc đầu sẽ bên dưới cụm 3 dấu chấm, khi active thì sẽ trồi lên ngang với 3 dấu chấm. Còn trên iPhone thì tab search được tách rời với cụm tab chính, khi nhấn vào search cụm tab chính thu nhỏ lại, từ icon search sẽ mở rộng ra input. Tôi sẽ quay 2 video về cách tab search hoạt động ở trên iPad và iPhone để bạn check kỹ việc làm search. Đây sẽ là bộ khung chuẩn cho Liquid Glass mà chúng ta làm

  and the work item itself: "chưa có trang search riêng nên chưa có mẫu cho search, phải làm cả example thực tế cho trang search".
- **Owner direction (standing).** On iOS 26+ everything is native. On iOS < 26 and Android the Flutter-drawn equivalent goes through `LiquidGlass`, which gets the liquid tier on branch VK-348. The same states apply on every platform.
- **Sources:**
  - vankhan `.superpowers/sdd/vk407-video-findings.md`: frame-by-frame analysis of the owner's two Apple Music videos (iPhone, 40.8 s; iPad in a narrow window, 30.1 s). The frames stay in the session scratchpad `vk407/frames/{iphone,ipad}/` and are **never** copied into this public repository.
  - vankhan `.superpowers/sdd/vk407-search-tab-research.md` and `vk407-shots/` (pure-UIKit and approach-C spike on iOS 26.5 and 27.0 simulators, with measurements). Cited below as "research §n".
  - vankhan `.superpowers/sdd/vk342-design-decisions.md` (Apple Music style search, approved 2026-10-08). Still valid where this spec does not contradict it: the query is kept across tab switches, the dirty-form guard covers the search tab, and the native field owns the IME (Vietnamese Telex safety). Where it said "the field is drawn in Flutter" and "autofocus when the user taps ⌕", the owner's videos supersede it (§3).
  - P2 spec `docs/specs/2026-10-09-p2-native-ios-design.md`: approach C (§5.2), pass-through hit testing (§5.3), safe-area copy (§5.4), propose-accept selection (§5.6), Pigeon (§6), engagement and ownership (§7), window controls (§8), D1 native chrome on every iOS 26 iPhone and iPad (§14), E1–E2 (§15).
  - P1 spec `docs/specs/2026-10-08-p1-foundation-design.md` and `liquid_shell/README.md`: router-agnostic API, body chain, chrome builder, glass seam.

> **Tóm tắt (cho chủ sản phẩm).**
> - **Tìm là một tab, không bao giờ là trang đẩy lên.** App khai báo một đích có vai trò tìm (`LiquidDestination(role: LiquidDestinationRole.search)`) và truyền `LiquidShell(search: LiquidSearch(controller: …))`. Chỉ số của tab Tìm nằm trong `destinations` như mọi tab khác, nên `IndexedStack` hay nhánh router dùng y như cũ.
> - **iOS 26+: tất cả là UIKit thật.** Tab Tìm là `UISearchTab` chứa một `UINavigationController` có `UISearchController`. iPhone: viên tab và nút ⌕ tách rời; chạm ⌕ thì viên tab thu thành 1 nút tròn mang icon tab trước, ⌕ nở thành ô tìm ở đáy; chạm ô thì ô nằm trên bàn phím kèm nút ×. iPad: ô tìm ở trên cùng, dưới hàng nút cửa sổ •••, khi gõ thì trồi lên ngang hàng •••. Đúng như hai video, đã dựng lại được trên simulator 26.5 và 27.0.
> - **Kết quả, gợi ý, "Tìm gần đây", thanh phạm vi** là nội dung Flutter vẽ bên dưới ô tìm native. Chữ gõ chạy sang Dart từng phím; bộ gõ tiếng Việt do iOS lo (ô tìm là của UIKit).
> - **Nút back kính:** khi chạm một kết quả, trang chi tiết đẩy lên *trong* tab Tìm, và thanh điều hướng native vẽ nút back kính tròn 44pt thật. P3b-1 làm việc này cho tab Tìm; P3b-2 làm cho mọi tab, bắt đầu bằng spike vuốt-để-quay-lại (S2) có tiêu chí đạt/không đạt rõ ràng.
> - **iOS < 26 và Android:** cùng các trạng thái, vẽ bằng Flutter qua `LiquidGlass`. Khổ hẹp: ⌕ tách rời nở thành ô ở đáy; khổ rộng: ô ở trên cùng.
> - **Ví dụ "Search" thật:** lưới danh mục, thanh phạm vi, "Tìm gần đây" có nút Xoá, lọc trực tiếp bỏ dấu ("ho hoan kiem" ra "Hồ Hoàn Kiếm"), trạng thái rỗng, trang chi tiết có nút back kính, giữ chữ đã gõ khi đổi tab.
> - **Chia hai kế hoạch:** P3b-1 (tab Tìm + API + bản Flutter + ví dụ) và P3b-2 (thanh điều hướng native cho mọi tab, tiêu đề lớn, vuốt quay lại). 20 câu hỏi có đề xuất mặc định ở bảng cuối; Q1–Q4 là các đề xuất của nghiên cứu.

---

## 1. Goal

The owner's verdict on the P2 build: search was wrong (a page pushed over everything), and the back button was not glass. P3b makes search and back navigation the reference frame for every app built on liquid_shell ("bộ khung chuẩn").

1. **Search is a tab.** A shell can have one search destination. Selecting it shows the app's search page in place, like any tab. It never pushes a page.
2. **iPhone and iPad behave as in the owner's videos.** On iOS 26+ that is UIKit's own `UISearchTab` behaviour (research §1–2, measured). Everywhere else the shell draws the same states in Flutter glass.
3. **A real Dart API for search:** the query as a listenable value and callbacks, `activate` / `deactivate`, scope titles, placeholder, `onSubmitted`, and insets that keep app content clear of the field in every state.
4. **The glass back button.** A page pushed inside a tab gets a native navigation bar with UIKit's glass back circle on iOS 26+, and a Flutter glass circle elsewhere.
5. **A realistic search example** that exercises all of it.

## 2. Scope and split

The work splits into two plans. P3b-1 delivers the owner's search tab end to end, including the glass back button for pages pushed inside the search tab. P3b-2 extends the native navigation bar to every tab and settles interactive swipe-back.

### 2.1 P3b-1: the search tab (`docs/plans/2026-10-10-p3b-search-tab.md`)

| # | Item | Section |
|---|---|---|
| A1 | Public search API: `LiquidDestinationRole.search`, `LiquidSearch`, `LiquidSearchController`, `LiquidSearchValue`, `LiquidSearchPhase`, `LiquidSearchScopeBar` | §4.1–4.4 |
| A2 | `LiquidPage` (title, large title, scroll forwarding) and `LiquidBackButton`; the page stack of the search tab | §4.5, §7.6, §8.4 |
| A3 | Scope data: `searchPhase`, `nativePageBar`; `chromeInsets` covers the field in every state | §4.6, §8.3 |
| A4 | Platform interface and Pigeon: search config, page stacks, search and back events, `setSearchText`, `setSearchActive`, `setPageScroll`, a debug snapshot | §5, §6 |
| A5 | Native: `UISearchTab` → `ShellNavController` → `PageHostController` with `navigationItem.searchController`; per-OS and per-idiom placement; query bridge with the Telex rule; field frame; page stack with native back (no interactive swipe yet); proxy scroll view for the large title; hit test and safe-area copy through the top view controller | §7 |
| A6 | Dart shell behaviour: selection through the guard, query kept across tab switches, controller ↔ native sync, dialogs above an active search | §8 |
| A7 | Flutter fallback: compact morph (pill → collapsed circle, ⌕ → field, field above the keyboard with ×) and regular field at the top that rises when active; `LiquidPage` Flutter bar with a glass back circle | §9 |
| A8 | Example `SearchCase` with a local Vietnamese dataset | §11 |
| A9 | Tests: unit, widget, golden, XCTest, `flutter drive` on iPhone and iPad 26.5 and 27.0, XCUITest real taps, side-by-side screenshots against the owner's frames | §12 |
| A10 | Docs, CHANGELOG `0.1.0-dev.3`, CI | §13 |

### 2.2 P3b-2: the native navigation bar on every tab (`docs/plans/2026-10-10-p3b-nav-bar.md`)

| # | Item | Section |
|---|---|---|
| B1 | **Spike S2** (first task, 2–3 days): native interactive pop synchronised with a Flutter route, with go / no-go criteria and the fallback | §10.2 |
| B2 | Every destination tab hosts a `ShellNavController`; `TabHostController` goes | §10.3 |
| B3 | `LiquidPage` native on every tab: stacks, titles, large titles with the proxy scroll view, window controls handled by the bar | §10.4 |
| B4 | Page actions: `LiquidPageAction` → glass `UIBarButtonItem` (the avatar in the owner's video) | §10.5 |
| B5 | Swipe-back: interactive sync through `LiquidPageRoute` (go) or the N1 fallback, generalised (no-go) | §10.6 |
| B6 | Flutter page bar: large title that collapses into the inline bar on scroll, with actions | §10.7 |
| B7 | Example detail pages through `LiquidPage` in every case; tests, screenshots, docs | §10.8 |

### 2.3 Non-goals

- go_router integration. It comes in P5. P3b stays router-agnostic (index-based selection, `Navigator` pages found from the widget tree).
- A native `bottomAccessory` (Music's mini player). Not required by the owner.
- The microphone icon in Music's iPhone field (research §1.3, "one small visual delta"). Q11.
- Native segmented control for the scope bar (Q5). Native controls are D2 ⑤.
- Pages pushed on the **root** navigator, above the shell. They keep P2's rule: the native chrome hides while they cover the shell (P2 §7.4), and a `LiquidPage` there draws the Flutter glass bar. A root-level native navigation controller is Q17.
- `tabBarMinimizeBehavior` (minimise on scroll). P2 §14.3 found UIKit follows only a user-tracked scroll view; the proxy scroll view does not change that.
- Search on Android with Material 3 `SearchBar`. The fallback uses the library's glass skin on every non-native platform (§9).

## 3. Reference behaviour

### 3.1 States

One state machine for every platform:

```
        select search tab               tap field / activate()
idle ───────────────────────▶ selected ─────────────────────────▶ active
  ▲                              │  ▲                                │
  │ select another tab           │  └──── × / deactivate() / Esc ────┘
  └──────────────────────────────┘        (× also clears the text)
```

`LiquidSearchPhase { idle, selected, active }`:
- **idle:** another tab is selected.
- **selected:** the search tab is selected and the field does not have focus. The keyboard is down.
- **active:** the field has focus (or, on iPad with a hardware keyboard, the search is presented with the keyboard dismissed). The keyboard is up on a touch-only device.

Selecting the search tab never focuses the field. The iPhone video (state 2) shows the tab selected with the keyboard down, and HIG says to leave the field unfocused on iPad (research §1.2). VK-342 design §6 ("autofocus when the user taps ⌕") is superseded (Q13).

### 3.2 iPhone (video → system)

| Video state | What the user sees | iOS 26+ (native) | Fallback (Flutter, compact width) |
|---|---|---|---|
| 1 idle | Glass pill with the tabs, separate glass ⌕ circle to its right; large title of the current tab | `UISearchTab`, `automaticallyActivatesSearch = false`; on iOS 27 also `prominentTabIdentifier = UISearchTab.identifier` (research §0 #2–3) | P1 pill + 62pt ⌕ circle, 8pt gap |
| 2 selected | Pill collapses to ONE 48pt circle with the **previous** tab's icon at bottom-leading; ⌕ expands into a 48pt glass field at the bottom; large title "Search"; categories grid | UIKit's own morph on selection | Circle 48pt at start 28; field from 88 to end 28 (12pt gap); morph 350 ms |
| 3 active | Keyboard up; field 8pt above it with a 48pt × circle at its trailing side; collapsed circle and large title hidden; content: scope bar, "Recently searched" + Clear, list | UIKit, after a tap on the field or `setSearchActive(true)` | Field docks at `viewInsets.bottom + 8`, margins 8, × circle 48pt; circle fades out |
| 4 × | Back to state 2 | `searchBarCancelButtonClicked`; UIKit clears the text | × clears and unfocuses |
| 5 circle | Back to the previous tab; full pill and ⌕ return | `shouldSelectTab(previous)` → propose → Dart selects | Tap → select the previous index through the guard |

Measurements (iPhone 17 Pro, research §5): pill 290×62 at y 791; ⌕ 62×62, 8pt gap, 21pt trailing margin; selected circle 48×48 at {28, 798}; selected field 286×48 at {88, 798}; active field 330×48 at {8, 490} and × 48×48 at {346, 490}, 8pt above the keyboard; nav bar content row y 62–116, large title row 116–172.7.

### 3.3 iPad (video → system)

| Video state | What the user sees | iOS 26+ (native) | Fallback (Flutter, regular width) |
|---|---|---|---|
| 1 idle, narrow window | ONE bottom bar with Search inside it as the last item | iPadOS 27: `UISearchTab` with no prominent tab sits inside the bar. iPadOS 26 always detaches ⌕ (Q1) | Compact width uses the iPhone layout (§9.2). The fallback decides by width only |
| 2 selected | Small inline title "Search" on the ••• row; full-width glass field on the row below; grid | `preferredSearchBarPlacement = .stacked`, `hidesSearchBarWhenScrolling = false`, `largeTitleDisplayMode = .never` | Field 44pt, 20pt margins, one row below the top bar row |
| 3 active | Field rises into the ••• row; × inside the field; scope bar and recents below; keyboard covers the bottom bar | UIKit's stacked activation (field y 86 → 32) | Top bar fades out; field animates into the top bar row |
| regular, full screen | Search in the top tab bar (trailing) or as the first sidebar row; field under the tab bar row, rises when active | Same `.stacked` configuration; `.automatic` would give `.integrated` (a ⌕ button), which the owner did not ask for (research §0 #5) | Same as row 2–3 |

Measurements (iPad Air 11" M4, research §5): nav bar y 32–86 (54); stacked field 780×44, 20pt side margins, y 86 idle and y 32 active on 27.0 (87 and 38 on 26.5).

The window-controls cluster (•••) is cleared by UIKit's navigation bar itself (VK-342 research 1.7, H for navigation controllers). The fallback clears it with P2's `LiquidWindowControls.indentFor`.

### 3.4 Platform matrix

| Where | Search UI | Back button |
|---|---|---|
| iOS 26+, native chrome engaged (P2 §14.4) | `UISearchTab` + `UISearchController` (§7) | Native navigation bar: in the search tab from P3b-1, in every tab from P3b-2 |
| iOS 26+, native chrome not engaged (no opt-in, a missing symbol, a `chromeBuilder`, `nativeChrome: off`) | Flutter fallback (§9) | Flutter glass bar |
| iOS < 26 (iOS 18 included), Android, web, desktop | Flutter fallback | Flutter glass bar |

UIKit has `UISearchTab` since iOS 18, but not the glass morph. The native shell installs on iOS 26+ only (P2 §5.1, `osTooOld`), so iOS 18 gets the fallback (Q15).

## 4. Public API (`liquid_shell`)

Exported from `package:liquid_shell/liquid_shell.dart`. Every change is additive (`0.1.0-dev.3`, Q16).

### 4.1 The search destination

```dart
/// What a destination is.
enum LiquidDestinationRole {
  /// An ordinary destination.
  standard,

  /// The search tab: at most one per shell, the last destination, placed
  /// everywhere. Its page is the app's search page. The shell needs
  /// [LiquidShell.search] with it. Natively it is UIKit's search tab, and
  /// sfSymbol is optional (the system draws a magnifying glass).
  search,
}

const LiquidDestination({
  required Widget icon,
  required String label,
  Widget? selectedIcon,
  LiquidBadge? badge,
  LiquidPlacement placement = LiquidPlacement.everywhere,
  String? sfSymbol,
  LiquidDestinationRole role = LiquidDestinationRole.standard,   // new; joins == and hashCode
});
```

`LiquidShell` asserts in debug:
- at most one destination with `role == search`, and it is the last one;
- it has `placement == everywhere`;
- `search != null` exactly when a search destination exists;
- a shell with a search destination has no `tabBarTrailing` (both would be the trailing ⌕, Q9).

Search is counted among the 1–5 tab bar destinations P1 allows. `selectedIndex == searchIndex` means the search tab is selected. `onDestinationSelected(searchIndex)` runs after `beforeDestinationChange(searchIndex)` accepted, exactly as for any tab (Q6).

### 4.2 `LiquidShell.search`

```dart
class LiquidShell extends StatefulWidget {
  const LiquidShell({ /* … every P1/P2 parameter … */ this.search, super.key });

  /// The search tab's field. Required when a destination has
  /// LiquidDestinationRole.search, and only then.
  final LiquidSearch? search;
}

@immutable
class LiquidSearch {
  const LiquidSearch({
    required this.controller,
    this.placeholder,
    this.onChanged,
    this.onSubmitted,
  });

  /// The query, the active state and the scope. Owned by the app: it
  /// outlives tab switches, so the query is kept (VK-342 §3).
  final LiquidSearchController controller;

  /// Text shown in the empty field. Null: the platform's own ("Search" in
  /// the device language natively; LiquidShellStrings.searchPlaceholder
  /// in the fallback).
  final String? placeholder;

  /// Every text change the user makes, including IME composition
  /// (LiquidSearchValue.composing tells which). Not called for text the app
  /// sets through the controller.
  final ValueChanged<String>? onChanged;

  /// The user pressed Search / Return on the keyboard.
  final ValueChanged<String>? onSubmitted;

  // == field by field; callbacks by identity.
}
```

### 4.3 Controller, value and phase

```dart
enum LiquidSearchPhase { idle, selected, active }

@immutable
class LiquidSearchValue {
  const LiquidSearchValue({
    this.text = '',
    this.composing = false,
    this.active = false,
    this.scopeIndex = 0,
  });
  static const empty = LiquidSearchValue();

  /// The field's text, IME composition included.
  final String text;

  /// An IME composition (Vietnamese Telex, Japanese kana) is in progress:
  /// text may still change under the user's fingers. Apps may filter on it;
  /// they must not write it back.
  final bool composing;

  /// The field has focus (phase active).
  final bool active;

  /// Index into the app's scope titles (LiquidSearchScopeBar).
  final int scopeIndex;

  LiquidSearchValue copyWith({String? text, bool? composing, bool? active, int? scopeIndex});
  // ==, hashCode, toString
}

/// The query as a ValueListenable (Flutter's stream of values), plus
/// commands for the shell's field.
class LiquidSearchController extends ValueNotifier<LiquidSearchValue> {
  LiquidSearchController({String text = '', int scopeIndex = 0});

  String get text;
  /// Replaces the text. The field shows it; natively it is applied once no
  /// IME composition is in progress (§7.4). Does not call onChanged.
  set text(String text);

  bool get isActive;
  int get scopeIndex;
  set scopeIndex(int index);

  /// Focuses the field. Only while the search tab is selected; otherwise
  /// ignored (one debug log). Unfocuses any Flutter text field first.
  void activate();

  /// Unfocuses the field and keeps the text (unlike ×).
  void deactivate();

  /// Empties the text. Keeps the focus.
  void clear();
}
```

The shell drives the field from the controller and writes the user's edits back into it. One attached shell at a time: a second `attach` while one is attached asserts in debug. Writes from the platform never echo back to it (§8.2).

### 4.4 `LiquidSearchScopeBar`

```dart
/// A glass segmented control for search scopes ("All | Songs | Places"),
/// bound to the controller's scopeIndex. Apps place it at the top of the
/// search page's content while the phase is active (the owner's video).
/// Drawn by Flutter on every platform (Q5); LiquidGlass gives it the tier.
class LiquidSearchScopeBar extends StatelessWidget {
  const LiquidSearchScopeBar({
    required this.controller,
    required this.scopes,      // titles; at least 2
    super.key,
  });
}
```

Scope titles live with the widget, not in `LiquidSearch`, because the bar is page content (the video shows it in the content area on both devices). If the owner picks Q5 B (native `scopeButtonTitles`), `LiquidSearch` gains `scopes` and this widget becomes the fallback only.

### 4.5 `LiquidPage` and `LiquidBackButton`

```dart
/// One page of a tab: its title for the navigation bar, and the back
/// button when its navigator can pop. Wrap each page of a branch.
///
/// Where its tab has a native navigation bar (iOS 26 native chrome: the
/// search tab in P3b-1, every tab in P3b-2) the platform draws the title
/// and UIKit's glass back circle, and this widget draws nothing. Elsewhere
/// it draws a Flutter glass bar: LiquidBackButton and the title.
class LiquidPage extends StatefulWidget {
  const LiquidPage({
    required this.title,
    required this.child,
    this.largeTitle,
    super.key,
  });

  /// Navigation bar title. Also the native back button's label of the
  /// next page (UIKit shortens or hides it as it needs).
  final String title;

  /// Large title. Null: large on a tab's root page at compact width, inline
  /// otherwise (the owner's videos: iPhone "Search" large, iPad inline).
  final bool? largeTitle;

  /// The page. Its first vertical scroll view drives the native large
  /// title's collapse and the scroll-edge effect.
  final Widget child;
}

/// A 44pt glass circle with a back chevron; `Navigator.maybePop` by
/// default. The Flutter bar's back button; usable on its own.
class LiquidBackButton extends StatelessWidget {
  const LiquidBackButton({this.onPressed, this.semanticLabel, super.key});
}
```

`maybePop` respects `PopScope`, so a page's own "Discard changes?" guard runs for the native back button too (§8.4).

### 4.6 Scope data and insets

```dart
const LiquidShellScopeData({
  // … P1/P2 fields …
  this.searchPhase,              // LiquidSearchPhase?; null when the shell has no search tab
  this.nativePageBar = false,    // the selected tab has a native navigation bar
});
```

Both join `==` and `hashCode`; `none()` sets neither.

**One inset rule.** `chromeInsets` covers whatever chrome the shell or the platform draws over the body, now including the search field in every phase:

| Where the field is | `chromeInsets` |
|---|---|
| Native, iPhone, selected (field in the tab bar area) | `bottom` = the bottom padding (UIKit puts the field in the host's safe area, as the bar) |
| Native, iPhone, active (field above the keyboard) | `bottom = max(padding.bottom, size.height − field.top, viewInsets.bottom + field.height + 16)` from the native field frame (§7.5) |
| Native, iPad (stacked field at the top) | `top` = the top padding (nav bar + field are in the host's safe area) |
| Fallback compact, selected / active | `bottom` = the row's extent (§9.2) / `viewInsets.bottom + 8 + 48 + 8` |
| Fallback regular | `top` = below the field |

`LiquidShellScope.contentPaddingOf(context)` therefore keeps working unchanged: the example's search page pads its list with it and nothing else. Pages must not also add `viewInsets` (a `Scaffold` with `resizeToAvoidBottomInset: true` would count the keyboard twice); the README says so.

`windowControls` is zero while `nativePageBar` is true: UIKit's navigation bar clears the cluster.

### 4.7 Strings

`LiquidShellStrings` gains, with English defaults:

| Field | Default | Used for |
|---|---|---|
| `searchPlaceholder` | `'Search'` | Fallback field placeholder when `LiquidSearch.placeholder` is null |
| `cancelSearch` | `'Cancel search'` | Fallback × circle semantics and tooltip |
| `back` | `'Back'` | `LiquidBackButton` semantics and tooltip |

Native strings (the native × and back) follow the device language (P2 §12).

### 4.8 Chrome builder

`LiquidChromeSlot` gains `searchField`: the fallback's ⌕ circle that morphs into the field (compact) or the top field (regular). `LiquidChromeDetails` gains `search: LiquidSearchChromeDetails?` with `phase`, `controller`, `previousIndex` (the destination the collapsed circle returns to) and `selectSearch()`. In the compact layout the `tabBar` slot is the pill of the other destinations; it fades out (and ignores touches) while the search tab is selected, when the collapsed circle and the field take the row. A `chromeBuilder` keeps the shell on the Flutter chrome (P2 Q6), so this is the only path for custom search chrome.

## 5. Platform interface (`liquid_shell_platform_interface`)

Additive, with defaults that touch no channel, as in P2 §4.5.

```dart
abstract class LiquidShellPlatform extends PlatformInterface {
  // … P1/P2 members …
  Future<void> setNativeSearchText(String text) async {}
  Future<void> setNativeSearchActive({required bool active}) async {}
  Future<void> setNativePageScroll({required int tab, required double offset}) async {}
}
```

Value types:
- `LiquidNativePage { title, largeTitle }`.
- `LiquidNativeTab` gains `search` (bool, default false) and `pages` (`List<LiquidNativePage>`, default empty: the root shows the tab's title).
- `LiquidNativeSearchConfig { placeholder }` (`String?`); `LiquidNativeChromeConfig` gains `search` (`LiquidNativeSearchConfig?`).
- Events (sealed `LiquidNativeEvent`):
  - `LiquidNativeSearchTextChanged(text, composing)`
  - `LiquidNativeSearchActiveChanged(active)`
  - `LiquidNativeSearchSubmitted(text)`
  - `LiquidNativeSearchFieldChanged(rect)`: the field's frame in the Flutter view's coordinates, `Rect.zero` when not on screen
  - `LiquidNativeBackTapped(tab)`

Every new type has field-by-field `==`, `hashCode` and `toString`, as P2's do.

## 6. Pigeon messages (`liquid_shell_ios/pigeons/native_shell.dart`)

Same file as P2 (and P3a: one generated pair, one drift gate).

| Direction | Message | Payload |
|---|---|---|
| Dart → native | `update(NativeChromeConfig)` | `NativeTab` gains `bool search`, `List<NativePage> pages` (`NativePage{String title, bool? largeTitle}`); `NativeChromeConfig` gains `NativeSearchConfig? search` (`{String? placeholder}`) |
| Dart → native | `setSearchText(String text)` | Applied when no composition is in progress, else at the next one-shot chance (§7.4) |
| Dart → native | `setSearchActive(bool active)` | Presents or dismisses the search; dismissing keeps the text |
| Dart → native | `setPageScroll(int tab, double offset)` | The top page's scroll offset (proxy, §7.7) |
| Dart → native | `debugTap(NativeTapTarget, int)` | `NativeTapTarget` gains `searchField`, `searchCancel`, `back` |
| Dart → native | `debugSnapshot()` | Debug builds: `NativeDebugSnapshot{selectedTab, searchActive, searchText, placement, pageTitles, fieldFrame, firstResponderIsSearch}`; release returns an empty snapshot |
| native → Dart | `onSearchTextChanged(String text, bool composing)` | Every keystroke (`updateSearchResults`) |
| native → Dart | `onSearchActiveChanged(bool active)` | `didPresent` / `didDismiss` |
| native → Dart | `onSearchSubmitted(String text)` | `searchBarSearchButtonClicked` |
| native → Dart | `onSearchFieldChanged(NativeRect frame)` | `NativeRect{x, y, width, height}`; zero when hidden; only on a change ≥ 0.5pt |
| native → Dart | `onBackTapped(int tab)` | The native back button: a proposal (§7.6) |

Boundary checks: Dart drops a tab index outside the destinations, sanitises the rect (non-finite → zero) and clamps the scroll offset to finite values; Swift checks the tab index again.

## 7. Native architecture (`liquid_shell_ios`)

### 7.1 Tree

```
ShellContainerController (PassThroughView)
├─ FlutterViewController                         ← unchanged (approach C)
└─ NativeTabsController (.tabSidebar, clear)
   ├─ UISearchTab "trailing" (P2, only for tabBarTrailing; never selected)
   ├─ UITab destination i → TabHostController (clear)              ← P2 (P3b-2: ShellNavController)
   └─ UISearchTab destination (role search) → ShellNavController (clear)
        ├─ PageHostController (root, clear, proxy UIScrollView)
        │    navigationItem.searchController = UISearchController(searchResultsController: nil)
        └─ PageHostController × (pages.count − 1)   ← pushed Flutter pages, title + glass back
```

`ShellNavController` is a clear `UINavigationController` subclass: `view.backgroundColor = .clear`, `navigationBar.prefersLargeTitles = true`, interactive pop gestures disabled in P3b-1 (§7.6). `PageHostController` is a clear `UIViewController` with an invisible proxy `UIScrollView` (`isUserInteractionEnabled = false`, `contentSize.height = 100_000`, `contentInsetAdjustmentBehavior = .always`, registered with `setContentScrollView(_:for: .top)`), as the research spike proved (§4.1).

The tab's `UISearchTab` provider returns the `ShellNavController`, built once per structure. A live `UITab` is never rebuilt for the same view controller (UIKit asserts, react-native-screens PR #4839): a structure change builds new tabs and new controllers.

### 7.2 Search tab configuration

| | iPhone iOS 26.x | iPhone iOS 27 | iPad (any width) iPadOS 26.x | iPad iPadOS 27 |
|---|---|---|---|---|
| `UISearchTab.automaticallyActivatesSearch` | false | false | false | false |
| `prominentTabIdentifier` | — (API is 27+) | `UISearchTab.identifier` (Q10) | — | nil (Q1: the system look) |
| `preferredSearchBarPlacement` | `.automatic` (tab-hosted at the bottom) | `.automatic` | `.stacked` | `.stacked` |
| `hidesSearchBarWhenScrolling` | default | default | false | false |
| Root `largeTitleDisplayMode` | `.inline` (unless `pages[0].largeTitle == false`) | `.inline` | `.never` (unless `pages[0].largeTitle == true`) | `.never` |
| `obscuresBackgroundDuringPresentation` | false | false | false | false |

`.inline` (iOS 17+), not `.always`: Apple Music's large title sits on the bar row, right under the status bar and level with its trailing items. `.always` adds a 52pt row under the bar, which put our title about 60pt lower (Task 12 side by side). Under a back button UIKit turns `.inline` into `.always`. Pushed pages that ask for a large title keep `.always`.

"iPad" means `userInterfaceIdiom == .pad`, so a narrow iPad window keeps the stacked top field (the video), and an iPhone in landscape keeps the bottom field. The search tab's `title` and `image` come from the destination (`label`, `sfSymbol` when set); otherwise UIKit's localised "Search" and magnifying glass stay. `searchBar.placeholder` is `config.search.placeholder` when set.

### 7.3 Selection

P2's propose-accept stays (P2 §5.6, Q6):
- `shouldSelectTab(searchTab)` returns **false** and sends `onDestinationTapped(searchIndex)`. Dart runs the guard and answers with an `update` whose `selectedIndex` is the search index. `select()` sets `selectedTab = searchTab` under `applyingFromDart`, and UIKit runs the same morph for a programmatic selection (research spike `-select 1`).
- The iPhone collapsed circle calls `shouldSelectTab(previousTab)`: a normal destination proposal.
- P2's hidden-selection fallback (`select()` picks the first shown tab when Dart's selection is a sidebar-only tab left out of the compact bar) never picks the search destination or the trailing tab.
- Task 1 of P3b-1 measures the delay of the programmatic morph against UIKit's own. If it is visible, Q6's fallback applies: `shouldSelectTab(searchTab)` returns true when the shell has no `beforeDestinationChange` (a `guarded` bool added to `NativeChromeConfig` only in that case), and `didSelectTab` reports it.

### 7.4 Query bridge and the Telex rule

`PageHostController` (root of the search nav) is the `searchResultsUpdater`, the search controller's `delegate` and the search bar's `delegate`. It reports through `NativeTabsController`:

| UIKit callback | Sent to Dart |
|---|---|
| `updateSearchResults(for:)` | `onSearchTextChanged(text, composing: searchTextField.markedTextRange != nil)` |
| `didPresentSearchController` / `didDismissSearchController` | `onSearchActiveChanged(true / false)` |
| `searchBarSearchButtonClicked` | `onSearchSubmitted(text)` |
| `searchBarCancelButtonClicked` (×) | nothing extra: UIKit then sends `updateSearchResults` with `""` and `didDismiss` |

Rules:
- **Report only what the user did.** Nothing is sent while `applyingFromDart`, while a Dart command is being applied, or while the search tab is not the selected tab. So UIKit clearing the field because the user left the tab, or a programmatic dismiss, never reaches the controller, and the query is kept (§8.2).
- **Telex.** `setSearchText(text)` assigns `searchBar.text` only when `markedTextRange == nil` and the text differs. Otherwise it is kept as `pendingText` and applied at the first `updateSearchResults` with no marked text. The field is a real `UISearchTextField`, so Vietnamese composition is iOS's own, not Flutter's text input.
- **Pending until selected.** A `setSearchText` that arrives before the search tab is selected is kept and applied when it is (Dart sends it right after the selecting `update`; the two travel on different Pigeon channels).
- **Activation.** `setSearchActive(true)` (only while the search tab is selected): `searchController.isActive = true`, then on the next run-loop turn `searchTextField.becomeFirstResponder()` (research spike). `setSearchActive(false)`: remember the text, `isActive = false`, and restore the text if UIKit cleared it, without reporting.
- **First responder.** Dart unfocuses its own text fields before it sends `setSearchActive(true)`; native resigns the search field when a Flutter text field takes focus (`FlutterTextInputView` becoming first responder posts `UITextInputCurrentInputModeDidChange`; native observes `UIKeyboardWillShow` with a first responder that is not the search field and resigns it). flutter#189263 and #183507 are the known failure modes; Task 1 checks both directions by hand.

### 7.5 Field frame and insets

On every `syncFlutter` while the search tab is selected, and at the end of every keyboard move (`keyboardDidChangeFrame` and `keyboardDidHide`: the field's end position, read once the animation is over), native publishes the field frame converted to the Flutter view: `searchBar.searchTextField` when it is in a window, not hidden and not transparent; `CGRect.zero` otherwise. A change under 0.5pt is not sent; a failed send forgets the value (P2 rule).

Dart turns it into `chromeInsets.bottom` with one pure function, `nativeSearchBottomInset(field, size, padding, viewInsets, active)` (§4.6). Only a field whose centre is in the lower half of the view counts (the iPhone tab-hosted field); a stacked field at the top is already in the top safe area.

### 7.6 Page stack and the native back button (search tab in P3b-1)

Dart sends the search tab's page stack as `NativeTab.pages` (root first, §8.4). Native diffs it:
- **Count grows** → push `PageHostController`s for the new entries (`setViewControllers(_:animated: true)`).
- **Count shrinks** → pop to the remaining count, animated.
- **Same count** → update titles and large-title modes in place.

UIKit draws the glass back circle (44×44 at x 16 on iPhone, research §4.1) for every page above the root. Each pushed host sets `navigationItem.backAction = UIAction { onBackTapped(tabIndex) }`: the tap is a **proposal**. Dart calls `Navigator.maybePop()` for the top page; when the Flutter route pops, the next stack is one shorter and native pops. A refused pop (`PopScope` with a dirty form) changes nothing.

**UIKit's other pops are proposals too** (Task 12 finding). The back circle's long-press menu does not call `backAction`: choosing an entry calls `popToViewController(_:animated:)` (from `_tryRequestPopToItem`). An accessibility escape or a keyboard back can call `popViewController(animated:)`, and a reselect can call `popToRootViewController(animated:)`. `ShellNavController` overrides all three: it keeps its stack and sends `onPopToPage(tab, index)` (`LiquidNativePopToPage`), `index` being the page that should end on top. Dart pops the Flutter pages above it, top first, each with `maybePop` (its `PopScope` runs). A refused pop, or a route that is not a page on top (a sheet), ends it. One page down is exactly a back tap. Native then follows the shorter stack through `setViewControllers`, which never goes through those overrides. Before this, the menu popped native alone and Flutter kept the detail page with no back button.

**Swipe-back in P3b-1.** `interactivePopGestureRecognizer` and `interactiveContentPopGestureRecognizer` (iOS 26) are disabled on `ShellNavController`. The left-edge swipe falls through to Flutter (the body chain is background, §7.8), where a `CupertinoPageRoute` or `MaterialPageRoute` on iOS runs its own back gesture. When the gesture commits, the route pops and native pops with its animation. The native bar does not follow the finger. This is research §4.2's "N1-fallback"; P3b-2's S2 spike decides whether the bar follows the finger (§10.2).

**iPhone push inside the search tab.** What UIKit does with the tab-hosted bottom field when a page is pushed on the search tab's navigation controller is not measured (research covered the root only). Task 1 measures it. If the field stays over the pushed page, pushed hosts set `hidesBottomBarWhenPushed = true`; the owner compares the result with Music in the side-by-side review (Q19).

### 7.7 Large title and the proxy scroll view

Every `PageHostController` owns the proxy scroll view (§7.1). `setPageScroll(tab, offset)` sets `proxy.contentOffset.y = −max(expandedTop, proxy.adjustedContentInset.top) + offset` for that tab's top host. `expandedTop` is the host's top inset measured at offset ≤ 0 with the search inactive (the large title out); it is never force-read. Measuring from the current `adjustedContentInset.top` is wrong: once the title has collapsed it is the small bar's height, and offset 0 would never bring the large title back (Task 5 review). UIKit then collapses the large title to the inline bar and draws its scroll-edge effect over the Flutter content (research §4.1: H on 26.5 and 27.0).

**Held top.** As the title collapses, the host's top safe area shrinks (168.7 → 116 on iPhone). Copied straight to Flutter, the page's padding would shrink under the user's finger every frame. `syncFlutter` therefore holds the host's top inset at its value when the proxy offset was ≤ 0 (`restingTop`), like P2's `heldTop`, as long as the proxy is scrolled. The hold does **not** apply to the search activation, where UIKit hides the large title on purpose: `restingTop` is re-read whenever the search's active state changes. `restingTop` holds Flutter's padding only; it is never the proxy's base (`expandedTop` above), or a search on a scrolled page would leave the large title collapsed for good.

Dart sends the offset from `LiquidPage`'s first vertical scroll view (`ScrollUpdateNotification` and `ScrollMetricsNotification`, depth 0, vertical), coalesced to one message per frame, only for the top page of a tab with a native bar. `ScrollMetricsNotification` carries the offset of a position that never scrolled: one restored from `PageStorage`, one rebuilt after a `GlobalKey` move, one clamped when the content shrinks. The shell caches the last offset per registered page and sends it once whenever the top page changes (a push, a pop, `pushReplacement`, native engaging late), as soon as that page's scroll view has reported one: native may reuse a host whose proxy keeps an old offset. A top page whose scroll view has reported nothing one frame after it became top has none: it counts as offset 0, which is sent (a scroll view that appears later reports its own offset as usual).

### 7.8 Hit testing

P2's rule (§5.3) is extended to navigation controllers. Background is any view on the chain from

```
(selectedViewController as? UINavigationController)?.topViewController?.view ?? selectedViewController?.view
```

up to the tab bar controller's view (`UILayoutContainerView`, `UINavigationTransitionView` and wrapper views included). The navigation bar (title, back circle, stacked field), the tab-hosted field, × and the collapsed circle are never on that chain, so they stay with UIKit. The spike logged exactly this split in the idle, selected and active states (research §3.1). `PassThroughView.isBackground` becomes `isBackground(_ hit: UIView?, chainFrom top: UIView?, tabsView: UIView)`; XCTests run it on UIKit's real tree in all three states on iPhone and on iPad (compact override and regular).

During a push or pop animation the leaving page's view is not on the chain; a tap there in that 0.35 s lands on UIKit and does nothing. Accepted.

### 7.9 Frame and safe-area copy

`syncFlutter` (P2 §5.4) changes in three ways:
1. **Frame** = the selected tab controller's view (the nav controller's), never the top page's: during a push the top page's view slides, and the Flutter view must not.
2. **Insets** = the top page's `view.safeAreaInsets` (it includes the nav bar, the large title row and the stacked field), with the held top of §7.7. The overlay `heldTop` of P2 stays for the sidebar.
3. **Window controls** are zero while the selected tab has a navigation controller (UIKit's bar clears the cluster), at any size class.

Every `PageHostController` calls `syncFlutter` from `viewIsAppearing`, `viewDidLayoutSubviews` and `viewSafeAreaInsetsDidChange`, as `TabHostController` does, and once more from the navigation transition's completion.

### 7.10 Lifecycle and routes above the shell

| Event | Behaviour |
|---|---|
| Cold start, hot restart | Dart attaches; until the platform answers, configs go out with `engaged: false`. The search controller's text is Dart's: the first config that shows the search tab **natively** (engaged and selected) is followed by `setSearchText(controller.text)`, **even when the text is empty** (after a hot restart native may still show the old text). Text the app set while native was not engaged (pending, standby, Flutter chrome), a cleared (empty) query included, goes out the same way: every build without native chrome re-arms that replay |
| Scene reconnect | The installer replays the last config (P2 §5.7). The host forwards the state report to the owner shell after its forced resend. A report **equal** to the state the shell last saw is the reconnect signature (a live `NativeTabsController` reports changes only; a rebuilt one reports its first state even when unchanged): the shell replays `setSearchText(controller.text)` (empty included) with the next config that shows the search tab. A **changed** report (an iPad window crossing the size class, a sidebar change) comes from a live field the user may be typing in: the shell never sends the user's own text back (the one-way rule, §7.4: outside a composition native would write the older text over a keystroke still in flight); it replays only a text the app set. A reconnect whose first state differs from the last one looks the same to Dart, so the installer covers it natively: on the scene disconnect it keeps the old shell's search text (Dart's newest held write, else the field's) and sets it on the shell the reconnect installs, without reporting it as an edit. If the old shell is already gone at the disconnect, nothing is carried and that reconnect shows an empty field until the next Dart write or user edit |
| A Flutter dialog or sheet above the shell while search is active | Dart sends `setSearchActive(false)` first: the keyboard and the field would sit above the barrier. The text is kept. On the compact bar the chrome also hides (P2 §14.3) |
| A page above the shell (root navigator) | The native chrome hides (P2 §7.4). An active search is deactivated first, as for a dialog (`setSearchActive(false)`: the keyboard would stay up over the page); its text is kept, and the search tab's page stack is kept (§8.4) |
| Dormant | The search tab is kept with the tabs (P2 §14.3 "dormant keeps the tabs") |

## 8. Dart behaviour (`liquid_shell`)

### 8.1 Engagement

P2's `nativeChromeEngaged` is unchanged. `nativeDescribable` accepts a search destination without `sfSymbol` (UIKit has its own image). With a search destination, `nativeConfigFor` sends `search: LiquidNativeSearchConfig(placeholder: …)` and marks the tab `search: true`.

### 8.2 The controller and the platform (`ShellSearch`)

An internal `ShellSearch` object, owned by `_LiquidShellState`, attaches to `LiquidSearch.controller` and to the native claim's events.

- **Native → controller.** `LiquidNativeSearchTextChanged` sets `text` and `composing`, then calls `onChanged`. `ActiveChanged` sets `active`. `Submitted` calls `onSubmitted`. These writes are marked as coming from the platform, so the controller listener does not send them back.
- **Controller → native.** A text the app set (not the platform) is sent with `setNativeSearchText`. `activate()` unfocuses Flutter's primary focus and sends `setNativeSearchActive(active: true)`; `deactivate()` sends false; `clear()` sends `''`.
- **Query kept across tab switches (Q2 A).** The controller is the truth. Native suppresses the clears UIKit makes when the tab is left (§7.4). When the search tab is selected again, `ShellSearch` sends `setNativeSearchText(controller.text)` right after the config that selects it, if the text is not empty (the first native entry after an attach or a reconnect sends it even when empty, §7.10). The user's × clears it for good (native semantics; Q2).
- **Phase.** `searchPhase` is `idle` while another index is selected, `active` while `value.active`, else `selected`. Leaving the search tab while active sets `active` to false.
- **Dialogs and pages above.** When the shell's route stops being current (a dialog, a sheet or a page above it) while active, `setNativeSearchActive(false)` is sent first, once per covering (§7.10).
- **Fallback.** The same object drives the Flutter field (§9.4), with the same controller rules.

### 8.3 Insets and scope

- Native: `chromeInsets` adds the search inset of §4.6 to P2's `nativeChromeInsets`. `LiquidNativeSearchFieldChanged` is stored and rebuilds the shell.
- `searchPhase` and `nativePageBar` are published in the scope. `nativePageBar` is true when native chrome is engaged and the selected destination has a native navigation bar (P3b-1: the search destination only).
- `LiquidShellScopeData.windowControls` is zero while `nativePageBar` is true.

### 8.4 Pages (`LiquidPage` registry)

`LiquidPage` registers with the nearest shell through a `PageRegistry` (implemented by the shell's state, published by `ShellScopeMarker` next to the hide-chrome registry). A registration carries the page's `title`, `largeTitle`, its `ModalRoute`, its `NavigatorState` and a sequence number.

After each frame in which registrations, routes or the selection changed, the shell computes the selected tab's stack with a pure function:
1. The **top page** is the registered page whose route `isCurrent` and whose `TickerMode` is enabled (on screen, not covered, not in an offstage branch).
2. The **stack** is every registered page in the top page's navigator whose route `isActive`, in sequence order (registration order is push order).
3. No top page → an empty stack: the native root shows the destination's label (a tab whose pages do not use `LiquidPage`, or a page without `LiquidPage` pushed above one). **Except under a cover**, where the last stack stays (less pages that left or whose route is gone), so native neither pops to the root nor pushes everything again, animated, when the cover goes:
   - the shell's own route is covered (a page or dialog above the shell);
   - the last top page's route is still current in its navigator (it is hidden only from outside, including the frame where the shell is uncovered before that page has noticed);
   - the last top page is still on screen under a popup route (a modal bottom sheet in the tab's navigator).

Stacks are kept per destination index; a tab's stack is recomputed only while it is selected. They travel in `LiquidNativeTab.pages`.

`LiquidNativeBackTapped(tab)` → if `tab` is the selected index, `maybePop()` on the top page's navigator. Otherwise dropped. With no top page but a kept stack under a cover inside the shell's route (a sheet in the tab's navigator), the native back circle is live: the tap goes to `maybePop()` on the kept top page's navigator, which pops the sheet, as its barrier does. Under a cover above the shell's route the chrome is not interactive and nothing pops.

`LiquidPage` itself:
- Under a native page bar (`nativePageBar` true): draws only its child, inside a `NotificationListener` that forwards the offset from `ScrollUpdateNotification` and `ScrollMetricsNotification` (§7.7).
- Otherwise: the Flutter bar of §9.5.
- The child is always the first child of the same wrapper chain, so switching between native and Flutter bars (native chrome on/off) never rebuilds it.

## 9. Flutter fallback

### 9.1 When

The Flutter chrome draws the search UI whenever the native chrome is not engaged (§3.4). Every surface is a `LiquidGlass`, so the tier policy (liquid on VK-348, frosted, solid) and `LiquidGlassScope(forcedTier:)` apply unchanged. The fallback decides compact vs regular by the shell's width (P1 `breakpoints.regular`), like the rest of the Flutter chrome. A narrow iPad window therefore gets the iPhone-like morph in the fallback, where natively it gets UIKit's stacked top field; that difference is the requirement as written ("iPhone-like separate ⌕ on compact widths; field at top on regular").

### 9.2 Compact (bottom row)

| Phase | Row content (start → end) | Geometry |
|---|---|---|
| idle | `LiquidTabBar` with every destination **except** the search one, then the ⌕ circle (selects search) | P1: pill + `kLiquidTabBarTrailingGap` (8) + square circle as tall as the pill (62) |
| selected | Collapsed circle (previous destination's icon; selects it), field capsule | Circle 48 at start 28; field 48 high from start 88 to end 28; both centred in the 62pt row |
| active | Field capsule, × circle (cancel) | Margins 8, gap 8; bottom edge at `viewInsets.bottom + 8` (above the keyboard) or the row's normal bottom when no keyboard |

- The morph animates the circle's and the field's rects (`AnimatedPositioned` inside one `Stack`), 350 ms, `Curves.easeOutCubic`; instant under `MediaQuery.disableAnimations`.
- The field capsule in selected shows the placeholder and a ⌕ glyph; a tap focuses it (→ active).
- × clears the text and unfocuses (→ selected), like UIKit.
- The collapsed circle's semantics label is the previous destination's label; tapping it runs `_select(previous)` with the guard.
- `minimizeOnScroll` is suspended while the search tab is selected.
- `chromeInsets.bottom`: idle and selected as P1's bar (measured row + bottom gap); active = `viewInsets.bottom + 8 + 48 + 8`.

### 9.3 Regular (top field)

- The field is 44pt high, as wide as the body minus 20pt margins.
- **selected:** its top is one row below the top bar row: `padding.top + kTopBarGap + barExtent + 8` with the Flutter top bar (`topBar`/`sidebarOverlay` kinds), or `padding.top + 54` beside a tiled sidebar (no bar).
- **active:** the top bar (pill and toggle) fades out over 200 ms and ignores touches; the field moves up into the bar row (`padding.top + kTopBarGap`, or `padding.top + 5` when tiled). × is a trailing icon inside the field. The row clears the window controls with `indentFor(rowTop:)` (P2 §8).
- `chromeInsets.top` = the field's bottom + 8 in both phases.
- The search destination is an ordinary cell of the Flutter top bar and an ordinary (last) row of the Flutter sidebar, highlighted while selected.

### 9.4 The field and IME safety

The fallback field is one persistent `TextField` (Material, no border, `textInputAction: TextInputAction.search`) on a `LiquidGlass` capsule, built by the shell from a `TextEditingController` and `FocusNode` that `ShellSearch` owns for the shell's lifetime.

- **Never rebuilt while focused.** Phase changes animate its position and size; they never change its parent or key. A layout-kind change (compact ↔ regular) while focused is the one exception, and unfocuses first.
- **Composition.** Controller → field writes only when `TextEditingValue.composing` is collapsed and the text differs; field → controller writes every change with `composing: !composing.isCollapsed`. The memory rule "never re-render a focused input" (VK-342 §6) holds: the field's `TextEditingValue` is only replaced from outside when the app sets the text.
- **Focus** ↔ `active`: focus gained → `active: true`; lost → false.
- **System back (Android)** while active → deactivate (a `PopScope` with `canPop: false` only while active).
- **Hardware Esc** while active → deactivate.

### 9.5 The Flutter page bar

`LiquidPage` without a native bar draws, over its child:
- a 54pt row at `padding.top`: `LiquidBackButton` at start 16 when `Navigator.canPop`, then the inline title (17pt semibold, centred between the back button and an equal trailing reserve) when the page is not large-titled;
- for a large-titled root page (no back button), the large title (34pt bold, start 16) **on that row**, as UIKit's `.inline` mode and Apple Music draw it; for a large-titled pushed page, a large title row below the bar row (UIKit turns `.inline` into `.always` under a back button). Either way it is hidden while `searchPhase == active` (UIKit hides it too);
- a scroll-edge fade under the bar (a `ShaderMask` gradient over the first 24pt below it), the iOS 26 look without a bar background;
- the child gets the bar's height added to its `MediaQuery.padding.top`, so `contentPaddingOf` keeps working.

The row clears the window controls with `LiquidWindowControlsClearance`. In P3b-1 the large title does not collapse on scroll in the fallback; P3b-2 adds the collapse (§10.7).

## 10. P3b-2: the native navigation bar on every tab

### 10.1 Why after P3b-1

P3b-1 builds every native piece once, for the search tab: `ShellNavController`, `PageHostController` with its proxy, the page-stack diff, the back proposal, the hit-test and safe-area rules for navigation controllers, and `LiquidPage`. P3b-2 turns them on for every destination and adds the one unproven piece, the finger-tracked swipe-back.

### 10.2 Spike S2: swipe-back sync (first task, 2–3 days, throwaway)

**Question.** Can UIKit's interactive pop (`interactivePopGestureRecognizer`, and iOS 26's full-width `interactiveContentPopGestureRecognizer`) drive the Flutter route's back transition frame by frame, so the native bar and the Flutter page move together?

**Probe.** In the example, the search tab's navigation controller re-enables the interactive pop. In the gesture's `began`, native sends `onBackGestureStarted(tab)`; Dart calls `navigator.didStartUserGesture()` and takes the top route's animation controller (only possible from a route class we own: `LiquidPageRoute`, a `PageRoute` with the Cupertino transition that exposes its controller to the shell). A `CADisplayLink` reads `transitionCoordinator.percentComplete` (via the coordinator's view controller views) and sends it per frame with a **synchronous FFI call** (threads are merged since Flutter 3.29), and also over Pigeon as a comparison. Dart sets `controller.value = 1 − percent`. At the end, `notifyWhenInteractionChanges` tells commit or cancel: Dart finishes the controller forwards or backwards and calls `didStopUserGesture()`.

**Go when all of these hold** on iPhone 17 Pro and iPad Air 11" M4, iOS 26.5 and 27.0 simulators, and on the owner's device:
1. **Sync.** Over 20 swipes at 120 Hz (ProMotion simulator or device), the Flutter page's translation is within 1 frame of the native bar's position in ≥ 95 % of frames (logged native `percentComplete` vs Dart `controller.value` with frame timestamps), and never more than 2 frames apart.
2. **Cancel.** A swipe released before the threshold returns both to the start, with no stack change sent and no route popped.
3. **Commit.** A committed swipe pops exactly one route, and Dart's next stack equals native's.
4. **Large title.** The previous page's large title and the proxy's edge effect follow the swipe with no jump at the end.
5. **No lifecycle noise.** Flutter never sees `inactive` or `paused`; no frame drop above 2 % at 120 Hz in the profile build.
6. **Accessibility.** VoiceOver's two-finger scrub (escape) and the back button still pop, through the proposal path.
7. **Content swipe.** iOS 26's full-width content swipe does not fight a horizontal Flutter scroll view (a `PageView` in the page keeps its swipe).

**No-go** if any of 1–3 or 5 fails after two days of tuning. Then the **fallback** (research "N1-fallback") is P3b-2's swipe: native interactive pop stays disabled; Flutter's own Cupertino back gesture moves the page; native pops with its animation when the Flutter route commits. The bar does not follow the finger; everything else (glass back circle, titles, large titles, edge effect) stays native. Criteria 4, 6 and 7 still apply to the fallback. The spike writes `docs/qa/p3b/s2-spike.md` with the measurements and the decision; the owner is told either way.

### 10.3 Every tab hosts a navigation controller

`TabHostController` is replaced by `ShellNavController(root: PageHostController)` for every destination. P2's behaviours are re-proved on the new tree by XCTest: tiled sidebar safe area, overlay held top, compact bar safe area, hidden compact bar, sidebar-only tabs at compact width, dormant keeps the tabs, hit tests (beside the pill, the centre, under the bar, beside a tiled sidebar, the overlay's dimming view).

### 10.4 `LiquidPage` everywhere

Stacks are sent for every tab; `nativePageBar` is true on every engaged tab. A tab's root page without `LiquidPage` keeps a hidden native bar (`setNavigationBarHidden(true)` while `pages` is empty), so P2 apps that do not use `LiquidPage` look exactly as today. Large titles and the proxy apply on every tab.

### 10.5 Page actions

```dart
@immutable
class LiquidPageAction {
  const LiquidPageAction({
    required this.icon,          // Flutter bar
    required this.semanticLabel,
    required this.onPressed,
    this.sfSymbol,               // native: UIBarButtonItem(image:) in the glass group
  });
}
LiquidPage({ …, this.actions = const [] })
```

Native: trailing `UIBarButtonItem`s, grouped in UIKit's shared glass background; a tap sends `onPageActionTapped(tab, index)`. The Flutter bar draws them as 44pt glass circles at the trailing end. A missing `sfSymbol` keeps that page on the Flutter bar (one debug line, like P2 E2).

### 10.6 Swipe-back

- **Go:** `LiquidPageRoute<T>` (exported): a `PageRoute` with `CupertinoPageTransitionsBuilder`'s look whose controller the shell drives during a native interactive pop (§10.2). Apps that push other route types get the fallback behaviour for those pages.
- **No-go:** the P3b-1 behaviour (§7.6) for every tab, plus a guard: while a Flutter back gesture is in progress (`navigator.userGestureInProgress`) no stack change is sent. The shorter stack goes out when Flutter pops at release, so UIKit's bar animation runs alongside the page's pop animation; nothing changes mid-swipe.

### 10.7 Flutter bar, complete

The fallback bar of §9.5 gains the large-title collapse: as the page's first vertical scroll view passes the large title row, the inline title fades in and the large title scrolls away (the iOS behaviour), plus page actions.

### 10.8 Example and tests

Every example case whose page pushes a detail (hide chrome, the search case's categories, a new "Settings → About" detail in basic tabs) uses `LiquidPage`. Integration, XCUITest (back circle tap, edge swipe on the go path) and side-by-side screenshots as in §12.

## 11. Example: "Search" case

`lib/cases/search.dart` (`SearchCase`, id `search`, README region `// #docregion search`). A shell with **Home** (`house`), **Library** (`books.vertical`) and **Search** (role search, `magnifyingglass`). Each branch has its own `Navigator`, kept alive in an `IndexedStack`, so a detail page pushes **inside** the tab.

- **Dataset** (`lib/support/search_data.dart`): about 40 local items, two kinds: songs (Vietnamese titles and artists, no lyrics) and places (Vietnamese place names), each with a category. Examples: "Hồ Hoàn Kiếm" (place, Hà Nội), "Phố cổ Hội An" (place, Miền Trung), "Diễm xưa — Trịnh Công Sơn" (song, Nhạc Trịnh).
- **Accent-insensitive matching:** `foldVietnamese(String)` lowercases, maps `đ → d`, and strips every Vietnamese diacritic with a table (no dependency). A query matches when every folded query word is a prefix of some folded word of the title or subtitle. "ho hoan kiem", "Hồ hoan", "hoi an" and "dang" (for "Đặng") all match.
- **selected (idle query):** large title "Search"; a 2-column grid of category tiles (gradient cards: "Nhạc Trịnh", "Bolero", "Hà Nội", "Sài Gòn", "Miền Trung", "Cà phê"…). A tile pushes a category page (`LiquidPage`) listing its items.
- **active, empty query:** `LiquidSearchScopeBar(scopes: ['All', 'Songs', 'Places'])` at the top; "Recently searched" with a **Clear** button and up to 6 recent queries (a tap fills the query); without recents, a hint line.
- **active, with a query:** live results filtered by the scope, each row with the matched kind's icon; **empty state** "No results for "…"" with a hint to check the scope.
- **Submit** adds the query to the recents (newest first, de-duplicated by folded text); opening a result also adds the current query.
- **Result tap** pushes a detail page (`LiquidPage(title: item.title)`) inside the search tab: the native glass back circle on iOS 26, `LiquidBackButton` elsewhere.
- **The query is kept** across tab switches: the controller lives in the case's state.
- **Padding:** every list uses `LiquidShellScope.contentPaddingOf(context)`.
- **Strings** are English UI with Vietnamese data, so the README reads for everyone and the diacritics are exercised.

The existing `TrailingActionCase` ("Opens a page above the shell") and `NativeChromeCase`'s trailing "Search" teach the pattern the owner rejected. Their trailing action becomes **Compose** (`square.and.pencil`), and the README points search apps to the search tab (Q18).

## 12. Testing

TDD per task (red → green → commit), a review per task, a whole-branch review at the end, as in P1 and P2.

### 12.1 Dart unit

- `LiquidSearchValue` / `LiquidSearchController`: `==`, `copyWith`, `text` setter notifies, `activate` / `deactivate` / `clear` reach the attached driver, a second attach asserts, nothing when detached.
- `LiquidDestination.role` in `==`; shell asserts (two search tabs, not last, sidebar-only, `search` missing or extra, with `tabBarTrailing`).
- `nativeDescribable` with a symbol-less search destination; `nativeConfigFor` marks `search` and carries the placeholder and pages.
- `nativeSearchBottomInset` over every case of §4.6; `searchPhaseFor`; the fallback geometry functions of §9.2–9.3; `pageStackFor` (top page selection, order, other navigators, no top page).
- Interface: every new value class; the default platform's new members touch no channel.
- `liquid_shell_ios`: mapping of every new field and event; `debugSnapshot` mapping; real Pigeon channel names arrive as events.
- Example: `foldVietnamese` (every vowel with each tone, `đ`, upper case), `matches`, scope filtering, recents de-duplication.

### 12.2 Widget (`FakeNativePlatform` extended with the search members)

- Native path: the search tab is proposed and selected through the guard; text events update the controller and call `onChanged` without an echo; `controller.text = …` sends `setNativeSearchText`; reselecting sends the kept text; `activate()` unfocuses a Flutter field and sends `setNativeSearchActive(true)`; a dialog while active sends false; field frames change `chromeInsets.bottom`; `searchPhase` follows; pages register and the config carries the stack; `LiquidNativeBackTapped` pops the top page, and a `PopScope(canPop: false)` keeps it; `nativePageBar` makes `LiquidPage` draw no Flutter bar and forward scroll offsets.
- Fallback: each compact phase's geometry (circle, field, ×), the previous-tab circle, × clears, the regular field rises and the top bar fades, `chromeInsets` per phase, Android back deactivates, reduce motion, RTL mirroring, `chromeBuilder` gets the `searchField` slot.
- **IME safety:** while composing (`TextEditingValue.composing` set), a controller write is held; the `TextField`'s `Element` is the same object across selected → active → selected; focus survives a phase change.
- `LiquidPage` Flutter bar: back button only when the navigator can pop; large title hidden while active; the child keeps its state when the bar switches between native and Flutter.

### 12.3 Goldens

Through `make goldens-update` only, after VK-348's liquid tier when it has merged (regenerate at rebase): `case_search_phone_selected`, `case_search_phone_active` (a fake 336pt keyboard inset, recents shown), `case_search_phone_results` ("ho" typed), `case_search_tablet_selected`, `case_search_tablet_active`, `case_search_detail` (Flutter back circle). `case_trailing` is regenerated for the Compose action.

### 12.4 XCTest (`make ios-unit`, iPhone and iPad simulators)

- The search destination is a `UISearchTab` with the app's title and image; `automaticallyActivatesSearch == false`; `prominentTabIdentifier` is the search tab on iPhone 27 and nil on iPad; placement `.stacked` and `hidesSearchBarWhenScrolling == false` on iPad.
- `shouldSelectTab(searchTab)` returns false and proposes; a config selecting it selects it; a hidden selection never selects it.
- `setSearchText` with no marked text sets the bar's text; with marked text (a `UITextField` stub whose `markedTextRange` is set) it waits; no text event is reported for Dart's own writes or while another tab is selected.
- Field frame: published in Flutter coordinates when the tab is selected, zero when not.
- Page stack: two pages → two hosts with titles; one → pops; the back action sends `onBackTapped(tab)` and does not pop.
- Proxy: `setPageScroll` moves the proxy; the held top keeps Flutter's top inset while scrolled.
- Hit test: on the real tree, the stacked field (iPad), the tab-hosted field and the collapsed circle (iPhone), × and the back circle stay with UIKit; the body reaches Flutter in idle, selected and active; everything reaches Flutter while inert.
- Safe-area copy: the Flutter view's frame equals the nav controller's during a push; its top inset is the top page's.
- Window controls are zero while the selected tab has a navigation controller.

### 12.5 Integration (`flutter drive`, `make integration-ios-native`)

`integration_test/native_search_test.dart`, driven by `tool/integration_ios_native.sh` on **iPhone 17 Pro and iPad Air 11" (M4), iOS 26.5 and 27.0** (four runs, own simulators), plus iOS 18 when its runtime is installed (`EXPECT_NATIVE=false`: the fallback; not installed on this machine at the time of writing, so that leg is skipped with a log line). With `debugTap` and `debugSnapshot`:
- select search → native selected tab is the search tab, field visible, placement as §7.2, `searchPhase == selected`, insets as §4.6;
- `searchField` tap → active, keyboard inset reaches Flutter, `chromeInsets.bottom` covers the field (iPhone) or the field is at the top row (iPad);
- `setSearchText('ho hoan')` → the snapshot's text, the example's results list "Hồ Hoàn Kiếm";
- switch to Home and back → the text is still there;
- `searchCancel` → text empty, phase selected;
- a result → detail page pushed, the snapshot shows two page titles; `back` → popped;
- the guard case: a dirty form on Home + search tab → the dialog, "Keep editing" → still Home;
- the lifecycle never leaves `resumed`;
- screenshots of every phase (`search_<run>_<phase>.png`).

### 12.6 XCUITest: real taps

`example/ios/RunnerUITests/SearchUITests.swift`, `make ios-ui`. The target and the make target come from P3a (VK-406 Task 7); if P3b-1 lands first, its Task 12 adds them with P3a's script (the same names), and the second branch to merge keeps one copy. The app is launched with `LIQUID_SHELL_EXAMPLE_DEMO=search`, which opens `SearchCase` directly and calls `SemanticsBinding.instance.ensureSemantics()` so Flutter's rows are visible to XCUITest.

- tap the search tab button (`app.tabBars.buttons["Search"]` or the detached button found by label) → `app.searchFields.firstMatch` exists and is not focused;
- tap the field → keyboard (`app.keyboards.firstMatch.exists`); `typeText("ho hoan")` → `app.staticTexts["Hồ Hoàn Kiếm"]` appears;
- tap the result → `app.navigationBars.buttons.firstMatch` (the back circle) exists → tap it → the result list is back;
- tap × (`app.buttons["Cancel"]` or the search field's clear/cancel button) → the field is empty and not focused;
- iPhone: tap the collapsed circle → the Home tab is selected.

If Flutter's semantics are not visible to XCUITest, the steps that read Flutter text fall back to `flutter drive` (§12.5) and the UI test asserts native elements only; Task 12 records which.

### 12.7 Side-by-side against the owner's videos

A throwaway Swift script in the session scratchpad (`vk407/compare.swift`, CoreGraphics only, never committed) scales each of our simulator screenshots to the frame's height and draws it next to the owner's frame, writing `vk407/compare/<state>.png` in the **scratchpad**:

| Our screenshot | Owner frame (scratchpad `vk407/frames/…`) |
|---|---|
| iPhone 27 idle | `iphone/` state 1 frame |
| iPhone 27 selected | state 2 |
| iPhone 27 active | state 3 |
| iPhone 27 after × | state 4 |
| iPad 27 compact window idle / selected / active | `ipad/` states 1–3 |

Frame numbers are listed in `docs/qa/p3b/compare.md` by name only. The composed images go to the owner in the review message, never into the repo.

### 12.8 Manual (owner on device, `docs/qa/p3b/manual.md`)

1. iPhone: ⌕ separate; tap → pill becomes one circle with the previous tab's icon, ⌕ becomes the field at the bottom, keyboard down.
2. Tap the field → field above the keyboard with ×; × → back to step 1's selected state; the circle → back to the previous tab.
3. Telex: type "ho hoan kiem" with the Vietnamese keyboard → "hồ hoàn kiếm", no repeated letters; results show "Hồ Hoàn Kiếm".
4. Switch tabs and back → the query is still there.
5. Tap a result → detail with the glass back circle; back → results.
6. iPad, narrow window: Search inside the bottom bar (iPadOS 27); field under •••, rises level with ••• when active.
7. iPad full screen: Search in the top bar / sidebar; field under the bar, rises when active.
8. A dirty form + Search → "Discard changes?".
9. VoiceOver: the field, ×, the collapsed circle and the back circle are announced; the results are reachable.
10. Android emulator and iOS 18 (if available): the same states drawn in glass.

## 13. Documentation, versions, CI

- `liquid_shell/README.md`: feature list; "Search tab" section with the `SearchCase` snippet, the state table of §3, the inset rule, IME notes; "Pages and the back button" with `LiquidPage`; Limitations (P3b-1: native bars on the search tab only; swipe-back does not follow the finger natively; root pages keep the Flutter bar).
- New `liquid_shell/doc/search.md`: API, phases per platform, the controller rules, the Telex rule, troubleshooting (a field that does not appear: `sfSymbol`, opt-in, `chromeBuilder`).
- `doc/native_chrome.md`: the search tab, the extended hit-test rule, the page stack.
- `doc/router_integration.md`: a search branch with `IndexedStack`; a branch `Navigator` per tab so details push inside the tab.
- CHANGELOGs of the four packages: `0.1.0-dev.3`.
- CI: `integration-ios-native` gains the iOS 27.0 leg and `native_search_test.dart`; `ios-ui` (from P3a) runs `SearchUITests`.

## 14. Error handling

| Case | Debug | Release |
|---|---|---|
| `controller.activate()` while the search tab is not selected | one `debugPrint` | ignored |
| Native search event while the shell has no search destination | — | dropped |
| `LiquidNativeBackTapped` for another tab, or with no page to pop | — | dropped |
| Out-of-range tab index from native | — | dropped (both sides) |
| Non-finite field rect or scroll offset | — | zero / not sent |
| `setSearchText` during IME composition | — | applied when the composition ends |
| A Flutter dialog while active | — | search deactivated first, text kept |
| `setNativeSearch*` throws (`PlatformException`) | `debugPrint` once per method | ignored; the controller keeps its value |
| UIKit clears the text on tab switch or programmatic dismiss | — | not reported; Dart restores on reselect |
| Search destination misconfigured (two, not last, sidebar-only, with `tabBarTrailing`, `search` missing) | assert | the first search destination wins; extra ones behave as standard; a missing `search` uses an internal controller |

## 15. Risks

| Risk | Mitigation |
|---|---|
| **IME / first-responder hand-off** between the native `UISearchTextField` and Flutter's text input (flutter#189263, #183507); Telex can only be typed by hand | Native owns the field's IME; Dart unfocuses before activating, native resigns when Flutter takes focus (§7.4); Task 1 probes both directions and Telex by hand; owner check 3 on device |
| **Push inside the search tab on iPhone** is unmeasured (tab-hosted field over a pushed page) | Task 1 measures; `hidesBottomBarWhenPushed` fallback; owner compares with Music (Q19) |
| **Programmatic selection** of the search tab might lag UIKit's own tap morph | Task 1 measures; Q6 fallback (allow when unguarded) behind one config flag |
| **Hit-test debt grows** (navigation controllers, the tab-hosted field) | XCTest on the real tree in all three phases on iPhone and iPad; manual real taps per iOS bump; XCUITest real taps in CI (non-blocking) |
| **iPadOS 26 detaches ⌕** in a narrow window, unlike the video (iPadOS 27) | Q1: the system look per version |
| **× clears the query** natively | Q2: native semantics; kept across tab switches by Dart |
| **Swipe-back** not finger-tracked in P3b-1 | Documented; S2 in P3b-2 with go / no-go and the fallback |
| **Per-frame scroll messages** for the proxy | One message per frame, only for a top page of a native-bar tab, only while scrolling |
| **Parallel branches** (P3a edits the Pigeon file and adds `RunnerUITests`; VK-348 changes `LiquidGlass` and goldens) | Regenerate the channel and the goldens at rebase; one `RunnerUITests` target; P3b uses only `LiquidGlass(borderRadius:, child:)` |
| **iOS 18 runtime not installed** | That leg is skipped with a log; the fallback is covered by widget tests, goldens, `nativeChrome: off` on the 26.5 simulator and the Android emulator |
| **UIKit's private view tree** used by the XCTests to find the collapsed circle and the tab-hosted field | Found by geometry and accessibility labels, not by class names; a failure means "re-measure", documented in `doc/native_chrome.md` |

## Quyết định cần chủ sản phẩm xác nhận

> **Chủ sản phẩm chấp nhận toàn bộ đề xuất Q1–Q20 (10/10/2026: "Ok hết").** Lưu ý Q16: số phiên bản theo thứ tự merge thực tế.

Mỗi dòng có đề xuất mặc định; anh không trả lời thì dùng đề xuất. Q1–Q4 là đề xuất của nghiên cứu (research §7), em đã chấp nhận làm đề xuất của mình.

| Q# | câu hỏi | đề xuất |
|---|---|---|
| Q1 | iPad iPadOS 26 ở cửa sổ hẹp: `UISearchTab` của UIKit luôn tách ⌕ ra khỏi thanh đáy, còn video (iPadOS 27) để ⌕ nằm trong thanh. Theo hệ thống từng phiên bản, hay ép dùng `UITab` thường để ⌕ nằm trong thanh cả trên 26? | **A: theo dáng hệ thống từng phiên bản** (26 tách rời, 27 nằm trong thanh). Ít code, đúng như Apple |
| Q2 | Nút × của `UISearchController` xoá chữ đã gõ. Giữ đúng hành vi đó và chỉ khôi phục chữ khi quay lại tab Tìm mà không bấm ×, hay khôi phục cả sau khi bấm ×? | **A: × xoá hẳn (như iOS); đổi tab rồi quay lại thì vẫn còn chữ** |
| Q3 | Tiêu đề lớn "Search/Tìm" trên iPhone: tiêu đề native + `UIScrollView` ẩn bám theo cuộn Flutter (đã chứng minh co lại và hiệu ứng mờ mép chạy), hay Flutter tự vẽ tiêu đề? | **A: tiêu đề native + proxy** (dùng chung với nút back) |
| Q4 | Nút back: thanh điều hướng native (N1) sau spike vuốt-để-quay-lại S2; không đạt thì dùng N1-fallback (vẫn là kính native, chỉ thanh không chạy theo ngón tay) | **N1** |
| Q5 | Thanh phạm vi ("All \| Songs \| Places"): Flutter vẽ bằng kính trong nội dung (mọi nền tảng giống nhau; thành native khi làm phần điều khiển native D2 ⑤), hay `scopeButtonTitles` native của UIKit (vị trí trên iPhone khi ô ở đáy chưa đo)? | **A: Flutter vẽ bằng kính, đặt trong nội dung** như video |
| Q6 | Chạm tab Tìm native: vẫn "đề nghị rồi chấp nhận" như P2 (Dart chạy hộp thoại "Bỏ thay đổi?" trước, rồi mới chọn tab bằng code) hay để UIKit tự chọn? | **Đề nghị rồi chấp nhận.** Task 1 đo độ trễ hiệu ứng; nếu thấy trễ thì khi app không có guard sẽ để UIKit tự chọn |
| Q7 | Dạng API: tab Tìm là một `LiquidDestination(role: search)` trong danh sách đích (chỉ số dùng chung với `IndexedStack`/nhánh router) cộng `LiquidShell(search: …)`, hay một tham số riêng nằm ngoài danh sách đích? | **A: một đích có vai trò search** |
| Q8 | Chia việc: P3b-1 (tab Tìm, API, bản Flutter, ví dụ, nút back kính trong tab Tìm) rồi P3b-2 (thanh điều hướng native cho mọi tab, mở đầu bằng spike S2) | **Đồng ý chia như trên** |
| Q9 | Một shell vừa có tab Tìm vừa có `tabBarTrailing`? | **Không:** chỉ một trong hai (cả hai đều là ⌕ cuối thanh). `tabBarTrailing` giữ cho hành động khác (ví dụ "Soạn mới") |
| Q10 | iPhone iOS 27: đặt `prominentTabIdentifier` cho tab Tìm để ⌕ tách rời như video (không đặt thì 27 để "Tìm kiếm" thành tab thứ 4 trong viên) | **Có, chỉ trên iPhone.** iPad không đặt (Q1) |
| Q11 | Biểu tượng micro trong ô tìm như Apple Music | **Không làm ở P3b** (ô tìm chuẩn của UIKit không có micro) |
| Q12 | Bản Flutter: thời gian hiệu ứng thu/nở | **350 ms, easeOutCubic; tắt khi bật Giảm chuyển động** |
| Q13 | Chạm ⌕ có tự bật bàn phím không? (thiết kế VK-342 nói có; video nói không) | **Không:** chọn tab Tìm thì ô chưa focus, như video; chỉ chạm vào ô hoặc `activate()` mới bật bàn phím |
| Q14 | Vuốt-để-quay-lại trong tab Tìm ở P3b-1 (trước S2): Flutter xử lý cử chỉ, thanh native đổi khi cử chỉ kết thúc | **Đồng ý** (P3b-2 quyết định có cho thanh chạy theo ngón tay không) |
| Q15 | iOS 18 (có `UISearchTab` nhưng không có kính/hiệu ứng mới): native hay bản Flutter? | **Bản Flutter** (như P2: native chỉ từ iOS 26) |
| Q16 | Phiên bản | **`0.1.0-dev.3`** cho cả bốn gói, chưa publish |
| Q17 | Trang đẩy trên navigator gốc (đè lên cả shell) có thanh điều hướng native không? | **Chưa:** giữ như P2 (khung native ẩn, trang dùng thanh kính Flutter); xem lại sau P3b-2 |
| Q18 | Ví dụ cũ dùng nút ⌕ để đẩy trang tìm (mẫu anh đã bác) | **Đổi thành nút "Compose"**, README chỉ app tìm kiếm sang tab Tìm |
| Q19 | iPhone, trang chi tiết đẩy trong tab Tìm: nếu UIKit vẫn để ô tìm ở đáy đè lên trang chi tiết thì ẩn thanh đáy khi đẩy (`hidesBottomBarWhenPushed`)? | **Theo kết quả đo ở Task 1; nếu ô đè lên trang thì ẩn**, anh so với Apple Music khi duyệt ảnh |
| Q20 | Dữ liệu ví dụ: tên bài hát và địa danh Việt Nam (chỉ tên, không lời bài hát), giao diện tiếng Anh | **Đồng ý** |
