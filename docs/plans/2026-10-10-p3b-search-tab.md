# liquid_shell P3b-1: the search tab Implementation Plan

> **Approval:** the owner approves the spec `docs/specs/2026-10-10-p3b-search-tab-design.md`, this plan and `docs/plans/2026-10-10-p3b-nav-bar.md` (P3b-2) together. Until then the recommended defaults of the spec's "Quyết định cần chủ sản phẩm xác nhận" table (Q1–Q20) are what this plan implements; a different answer changes the tasks named in the "Owner defaults applied" table below.
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make search a real tab in `LiquidShell` (VK-407): UIKit's own `UISearchTab` + `UISearchController` on iOS 26+, the same states drawn in Flutter glass elsewhere, a Dart search API, `LiquidPage` with the glass back button inside the search tab, and a realistic search example.

**Architecture:** The search destination is an ordinary index in `destinations` with `role: search`; selection keeps P2's propose-accept path. Natively the search tab hosts a clear `ShellNavController` over the Flutter view (approach C); its root `PageHostController` owns the `UISearchController` and a proxy scroll view, and pushed Flutter pages are mirrored as clear hosts so UIKit draws the glass back circle. Text, activation, field frame and back taps cross the existing Pigeon channel; Dart's `ShellSearch` keeps `LiquidSearchController` as the truth and never echoes platform writes. Without native chrome the shell draws the same three phases (idle, selected, active) with `LiquidGlass`.

**Tech Stack:** Flutter 3.44.6 / Dart 3.12 (fvm), Swift 5 + UIKit (iOS 15 deployment target, native shell `@available(iOS 26.0, *)`), Pigeon 27.3.0 (dev), CocoaPods, XCTest (`RunnerTests`), XCUITest (`RunnerUITests`), `flutter_test`, `integration_test`, Xcode 27 with iOS 26.5 and 27.0 simulators.

## Global Constraints

- Floor: Flutter `>=3.44.0`, Dart `^3.12.0`, iOS deployment target `15.0`; fvm pins `3.44.6` (`.fvmrc`).
- `very_good_analysis` pinned to `10.3.0`; `dart analyze --fatal-infos --fatal-warnings` must be clean; never loosen `analysis_options.yaml`.
- Runtime dependencies: Flutter + our packages + `plugin_platform_interface`, plus `meta: ^1.10.0` in `liquid_shell_ios` only. `pigeon: 27.3.0` stays a dev dependency of `liquid_shell_ios`, pinned exactly. No new dependency anywhere, the example included.
- Generated channel: edit `liquid_shell_ios/pigeons/native_shell.dart`, run `make pigeon`, commit the source and both generated files together (`make pigeon-check` is part of `make verify`).
- Native install rule and engagement are P2's (spec P2 §14.3): `auto && owner && installed && no chromeBuilder && describable`. A search destination is describable without an `sfSymbol`.
- The body chain stays `PopScope → ShellScopeMarker → BackdropGroup → Stack → [PositionedDirectional → MediaQuery → KeyedSubtree(GlobalObjectKey) → NotificationListener → body]` in every chrome.
- Search rules (spec §4.1): at most one `LiquidDestinationRole.search` destination, the last one, `placement: everywhere`; `LiquidShell.search` is set exactly when it exists; never together with `tabBarTrailing`. Search never pushes a page. Selecting the search tab never focuses the field (Q13).
- IME rules (spec §7.4, §9.4): native applies a Dart text only when `markedTextRange == nil`; native reports only user edits, only while the search tab is selected and outside `applyingFromDart`; the Flutter fallback field is never rebuilt under a new parent or key while focused.
- Hit test (spec §7.8): background = the chain from `(selected as? UINavigationController)?.topViewController?.view ?? selected.view` up to the tab bar controller's view.
- Insets (spec §4.6): `chromeInsets` covers the search field in every phase; pages pad with `LiquidShellScope.contentPaddingOf(context)` only.
- Provenance: no `vankhan`, `Văn Khấn`, `calculator_promax`, `LocaleKeys`, `easy_localization`, `AppColors`, `AppGlassColors`, `GetIt` outside `docs/`; `go_router` only in `*.md` (`make provenance`). The owner's video frames never enter the repository (they stay in the session scratchpad `vk407/frames/`).
- Commits: `<type>(<scope>): <summary> (VK-407)`, scopes `shell glass platform ios android example docs ci`, a blank line, then `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Run `bash .githooks/pre-commit` by hand before every commit; stage by explicit path; never `--no-verify`, never set `core.hooksPath`, never change git or flutter config. No pushes.
- Simulators: create your own (`xcrun simctl create "vk407 …"`), delete them at the end; never touch a physical device. Keep ≥ 10 GB free (`df -h /`); delete `build/` output you created when space runs low.
- `rm` is aliased in this environment: use `command rm`.
- Goldens only through `make goldens-update` on macOS + Flutter 3.44.6; never edit images by hand.
- Version: all four packages become `0.1.0-dev.3` (Task 13). No publishing.
- Do not touch the other worktrees (`liquid_shell-vk346`, `-vk348`, `-vk406`).
- **Rebase:** this branch starts at `a1b9b30` on `VK-346-p2-native-ios`. When P2 merges, rebase onto `main` before Task 11 (`git rebase main`, re-run `make verify`). If P3a (VK-406) merged first, the rebase conflicts in `native_shell.dart` resolve by keeping both message sets and re-running `make pigeon`; `RunnerUITests` and `make ios-ui` then already exist (Task 12 Step 1).

## Owner defaults applied

| Q | Default | Where |
|---|---|---|
| Q1 | System look per iPadOS version: no `prominentTabIdentifier` on iPad | Task 4 |
| Q2 | × clears; the kept query is restored when the search tab is reselected | Tasks 4, 8 |
| Q3 | Native large title + proxy scroll view | Tasks 5, 8 |
| Q4 | N1 (native bar); in P3b-1 for the search tab with Flutter-owned swipe | Tasks 5, 7, 8 |
| Q5 | Scope bar drawn by Flutter (`LiquidSearchScopeBar`) in content | Task 9 |
| Q6 | Propose-accept for the search tab (Task 1 measures; fallback flag only if needed) | Tasks 1, 4 |
| Q7 | Search is a destination with `role: search` + `LiquidShell.search` | Task 6 |
| Q9 | No `tabBarTrailing` with a search destination | Task 6 |
| Q10 | `prominentTabIdentifier` on iPhone iOS 27 | Task 4 |
| Q11 | No microphone | — |
| Q12 | 350 ms `easeOutCubic`, none under reduce motion | Task 9 |
| Q13 | No autofocus on selection | Tasks 4, 8, 9 |
| Q14 | Flutter owns the swipe-back in the search tab | Task 5 |
| Q15 | iOS < 26 → Flutter fallback | (P2 install rule) |
| Q16 | `0.1.0-dev.3` | Task 13 |
| Q17 | Root pages keep the Flutter bar | Task 7 |
| Q18 | Example trailing "Search" becomes "Compose" | Task 10 |
| Q19 | `hidesBottomBarWhenPushed` per Task 1's measurement | Tasks 1, 5 |
| Q20 | Vietnamese song and place names, English UI | Task 10 |

---

## File map

| Path | Task | Responsibility |
|---|---|---|
| `docs/qa/p3b/probe.md` | 1 | Probe measurements and decisions P1–P8 |
| `liquid_shell_platform_interface/lib/src/native_chrome.dart` | 2 | `LiquidNativePage`, `LiquidNativeSearchConfig`, tab/config fields, five events |
| `liquid_shell_platform_interface/lib/src/liquid_shell_platform.dart` | 2 | `setNativeSearchText`, `setNativeSearchActive`, `setNativePageScroll` |
| `liquid_shell_ios/pigeons/native_shell.dart` + both `*.g.*` | 3 | Channel messages (spec §6) |
| `liquid_shell_ios/lib/src/mapping.dart`, `platform.dart` | 3 | Boundary mapping, new calls and events, `debugSnapshot` |
| `liquid_shell_ios/ios/.../ShellNavController.swift` | 4, 5 | `ShellNavController`, `PageHostController` (proxy), page-stack diff, back proposal |
| `liquid_shell_ios/ios/.../SearchBridge.swift` | 4 | `UISearchController` delegate, Telex rule, reporting rules |
| `liquid_shell_ios/ios/.../SearchMath.swift` | 4, 5 | Pure: search placement per device/OS, field frame change, held top |
| `liquid_shell_ios/ios/.../NativeTabsController.swift` | 4, 5 | Search tab, selection, commands, field frame, sync through the top page |
| `liquid_shell_ios/ios/.../PassThroughView.swift` | 5 | Chain rule through navigation controllers |
| `liquid_shell_ios/ios/.../NativeShellInstaller.swift` | 3, 4 | New host calls |
| `liquid_shell/example/ios/RunnerTests/RunnerTests.swift` | 3, 4, 5 | XCTest |
| `liquid_shell/lib/src/destinations/destination.dart` | 6 | `LiquidDestinationRole` |
| `liquid_shell/lib/src/search/search_controller.dart` | 6 | `LiquidSearchPhase`, `LiquidSearchValue`, `LiquidSearchController`, `SearchDriver` |
| `liquid_shell/lib/src/search/search.dart` | 6 | `LiquidSearch` |
| `liquid_shell/lib/src/search/search_layout.dart` | 6, 9 | Pure: phase, native inset, fallback geometry, search index |
| `liquid_shell/lib/src/native/native_layout.dart` | 6, 8 | Describable search, config with search + pages, `nativePageBarFor` |
| `liquid_shell/lib/src/pages/page_registry.dart` | 7 | `PageRegistry`, `PageEntry`, `PageHandle`, `pageStackFor` |
| `liquid_shell/lib/src/pages/liquid_page.dart` | 7 | `LiquidPage`, `LiquidBackButton` |
| `liquid_shell/lib/src/pages/page_bar.dart` | 7 | `FlutterPageBar` (glass back + title + large title + edge fade) |
| `liquid_shell/lib/src/search/shell_search.dart` | 8, 9 | `ShellSearch`: controller ↔ native / Flutter field |
| `liquid_shell/lib/src/native/native_host.dart` | 8 | Route search and back events to the owner |
| `liquid_shell/lib/src/shell/liquid_shell.dart`, `shell_scope.dart`, `chrome_builder.dart`, `strings.dart` | 6–9 | Integration, scope fields, slot, strings |
| `liquid_shell/lib/src/search/search_chrome.dart` | 9 | Fallback compact row and regular field |
| `liquid_shell/lib/src/search/scope_bar.dart` | 9 | `LiquidSearchScopeBar` |
| `liquid_shell/lib/liquid_shell.dart` | 6, 7, 9 | Exports |
| `liquid_shell/test/**` | 6–9 | Unit and widget tests; `FakeNativePlatform` grows the search members |
| `liquid_shell/example/lib/cases/search.dart`, `lib/support/search_data.dart` | 10 | `SearchCase`, dataset, `foldVietnamese`, matching |
| `liquid_shell/example/lib/cases/{trailing_action,native_chrome}.dart` | 10 | Compose instead of search |
| `liquid_shell/example/test/**` | 10 | Data tests, smoke, goldens |
| `liquid_shell/example/integration_test/native_search_test.dart`, `tool/integration_ios_native.sh` | 11 | `flutter drive` on four simulators |
| `liquid_shell/example/ios/RunnerUITests/SearchUITests.swift`, `liquid_shell/example/lib/main.dart` | 12 | XCUITest real taps, demo launch |
| `docs/qa/p3b/{compare,manual}.md` | 12 | Side-by-side index, owner checklist |
| `liquid_shell/README.md`, `liquid_shell/doc/{search,native_chrome,router_integration}.md`, CHANGELOGs, pubspecs, `.github/workflows/ci.yaml` | 13 | Docs, versions, CI |

Tasks: **1** probe · **2** platform interface · **3** channel · **4** native search tab · **5** native pages, insets, hit test · **6** Dart search API · **7** `LiquidPage` · **8** shell native integration · **9** Flutter fallback · **10** example · **11** integration · **12** XCUITest and screenshots · **13** docs, versions, verification.

## Set up once (the controller, before Task 1)

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-vk407      # branch VK-407-search-tab
df -h / | tail -1                                       # "Avail" must be ≥ 10Gi
make get
PHONE26=$(xcrun simctl create "vk407 iPhone 26.5" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-26-5)
PHONE27=$(xcrun simctl create "vk407 iPhone 27.0" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-27-0)
IPAD26=$(xcrun simctl create "vk407 iPad 26.5" com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M4 com.apple.CoreSimulator.SimRuntime.iOS-26-5)
IPAD27=$(xcrun simctl create "vk407 iPad 27.0" com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M4 com.apple.CoreSimulator.SimRuntime.iOS-27-0)
echo "PHONE26=$PHONE26 PHONE27=$PHONE27 IPAD26=$IPAD26 IPAD27=$IPAD27"   # export these in every later shell
# iOS 18 leg (spec §12.5): only if the runtime is installed.
RUNTIME18=$(xcrun simctl list runtimes | grep -o 'com.apple.CoreSimulator.SimRuntime.iOS-18-[0-9]*' | tail -n1)
[ -n "$RUNTIME18" ] && PHONE18=$(xcrun simctl create "vk407 iPhone 18" com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro "$RUNTIME18") || echo "no iOS 18 runtime: the iOS 18 leg is skipped"
```

At the very end (after Task 13): `xcrun simctl delete "$PHONE26" "$PHONE27" "$IPAD26" "$IPAD27" ${PHONE18:+"$PHONE18"}`.

---

### Task 1: Integration probe (spike, about 1 day, throwaway)

Throwaway code, never committed. Only `docs/qa/p3b/probe.md` is committed. It answers what the research spike could not (spec §7.3, §7.4, §7.6, §15): it runs the real Flutter view under the real P2 container.

**Files:**
- Modify (throwaway, restored in Step 7): `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeTabsController.swift`, `.../PassThroughView.swift`
- Create (throwaway, deleted in Step 7): `liquid_shell/example/lib/probe_search.dart`
- Create: `docs/qa/p3b/probe.md`

**Interfaces:**
- Consumes: P2's `NativeTabsController`, `PassThroughView`.
- Produces: decisions P1–P8 in `docs/qa/p3b/probe.md`, used by Task 4 (P1 → whether Q6's `guarded` flag is needed; P8 → whether programmatic text triggers `updateSearchResults`), Task 5 (P2 → `ShellNavController.hidesBarWhenPushed`; P6 → expected safe areas in XCTests; P7 → whether `setSearchActive(false)` must restore the text), and Task 8 (P4, P5 → the unfocus rules).

- [ ] **Step 1: Patch the trailing tab into a search tab with a navigation controller**

In `NativeTabsController.swift`, add above `final class TabHostController`:

```swift
// PROBE (P3b-1 Task 1). Never commit.
@available(iOS 26.0, *)
final class ProbeSearchHost: UIViewController, UISearchResultsUpdating,
  UISearchControllerDelegate, UISearchBarDelegate
{
  let search = UISearchController(searchResultsController: nil)
  private var shell: NativeTabsController? { tabBarController as? NativeTabsController }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    title = "Search"
    search.searchResultsUpdater = self
    search.delegate = self
    search.searchBar.delegate = self
    search.obscuresBackgroundDuringPresentation = false
    navigationItem.searchController = search
    if traitCollection.userInterfaceIdiom == .pad {
      navigationItem.preferredSearchBarPlacement = .stacked
      navigationItem.hidesSearchBarWhenScrolling = false
      navigationItem.largeTitleDisplayMode = .never
    } else {
      navigationItem.largeTitleDisplayMode = .always
    }
    let env = ProcessInfo.processInfo.environment
    if env["PROBE_DEACTIVATE"] == "1" {
      DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
        NSLog("[probe] programmatic deactivate, text before=%@", self.search.searchBar.text ?? "")
        self.search.isActive = false
        DispatchQueue.main.async { NSLog("[probe] text after=%@", self.search.searchBar.text ?? "") }
      }
    }
    if env["PROBE_SETTEXT"] == "1" {
      DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
        NSLog("[probe] programmatic text = ho")
        self.search.searchBar.text = "ho"
      }
    }
  }

  override func viewSafeAreaInsetsDidChange() {
    super.viewSafeAreaInsetsDidChange()
    NSLog("[probe] host safe=%@", NSCoder.string(for: view.safeAreaInsets))
    shell?.syncFlutter()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let field = search.searchBar.searchTextField
    if field.window != nil, let flutter = shell?.flutter.view {
      NSLog("[probe] field=%@", NSCoder.string(for: field.convert(field.bounds, to: flutter)))
    }
    shell?.syncFlutter()
  }

  func updateSearchResults(for controller: UISearchController) {
    let field = controller.searchBar.searchTextField
    NSLog(
      "[probe] text=%@ marked=%d active=%d first=%d", controller.searchBar.text ?? "",
      field.markedTextRange != nil ? 1 : 0, controller.isActive ? 1 : 0,
      field.isFirstResponder ? 1 : 0)
  }

  func didPresentSearchController(_ controller: UISearchController) { NSLog("[probe] didPresent") }

  func didDismissSearchController(_ controller: UISearchController) {
    NSLog("[probe] didDismiss text=%@", controller.searchBar.text ?? "")
  }
}
```

In `rebuildTabsIfNeeded`, replace the `trailingTab = …` statement with:

```swift
    trailingTab = new.trailing.map { _ in
      let tab = UISearchTab { _ in
        let nav = UINavigationController(rootViewController: ProbeSearchHost())
        nav.view.backgroundColor = .clear
        nav.navigationBar.prefersLargeTitles = true
        if ProcessInfo.processInfo.environment["PROBE_PUSH"] == "1" {
          DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            let detail = UIViewController()
            detail.view.backgroundColor = .clear
            detail.title = "Detail"
            detail.hidesBottomBarWhenPushed =
              ProcessInfo.processInfo.environment["PROBE_HIDE_BAR"] == "1"
            NSLog("[probe] push detail hidesBottomBar=%d", detail.hidesBottomBarWhenPushed ? 1 : 0)
            nav.pushViewController(detail, animated: true)
          }
        }
        return nav
      }
      tab.automaticallyActivatesSearch = false
      return tab
    }
    if #available(iOS 27.0, *), traitCollection.userInterfaceIdiom == .phone, let tab = trailingTab {
      prominentTabIdentifier = tab.identifier
    }
```

In `tabBarController(_:shouldSelectTab:)`, replace the `if tab === trailingTab { … }` block with:

```swift
    if tab === trailingTab {
      // Direct: UIKit selects (its own morph). Otherwise: refuse, then
      // select programmatically one frame later, as propose-accept will.
      if ProcessInfo.processInfo.environment["PROBE_DIRECT"] == "1" {
        NSLog("[probe] shouldSelect search: direct at %f", CACurrentMediaTime())
        return true
      }
      NSLog("[probe] shouldSelect search: proposed at %f", CACurrentMediaTime())
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.017) {
        NSLog("[probe] programmatic select at %f", CACurrentMediaTime())
        self.selectedTab = tab
      }
      return false
    }
```

In `syncFlutter()`, replace `var want = ShellInsets(host.view.safeAreaInsets)` with:

```swift
      let top = (host as? UINavigationController)?.topViewController ?? host
      var want = ShellInsets(top.view.safeAreaInsets)
```

In `PassThroughView.hitTest`, replace the `guard Self.isBackground(…)` statement with:

```swift
    let selected = shell.selectedViewController
    let top = (selected as? UINavigationController)?.topViewController?.viewIfLoaded
      ?? selected?.viewIfLoaded
    guard Self.isBackground(hit, selected: top, tabsView: tabsView) else { return hit }
```

- [ ] **Step 2: Add the Dart probe page**

`liquid_shell/example/lib/probe_search.dart`:

```dart
// PROBE (P3b-1 Task 1). Never commit.
import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';

void main() => runApp(
  const MaterialApp(debugShowCheckedModeBanner: false, home: _Probe()),
);

class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => LiquidShell(
    destinations: const [
      LiquidDestination(icon: Icon(Icons.home), label: 'Home', sfSymbol: 'house'),
      LiquidDestination(icon: Icon(Icons.book), label: 'Library', sfSymbol: 'books.vertical'),
    ],
    selectedIndex: _index,
    onDestinationSelected: (i) => setState(() => _index = i),
    tabBarTrailing: LiquidTabAction(
      icon: const Icon(Icons.search),
      semanticLabel: 'Search',
      sfSymbol: 'magnifyingglass',
      onPressed: () {},
    ),
    body: Builder(
      builder: (context) {
        final media = MediaQuery.of(context);
        return Material(
          child: ListView(
            padding: LiquidShellScope.contentPaddingOf(context),
            children: [
              Text('padding ${media.padding}'),
              Text('viewInsets ${media.viewInsets}'),
              const TextField(decoration: InputDecoration(labelText: 'Flutter field')),
              for (var i = 0; i < 40; i++) ListTile(title: Text('row $i'), onTap: () => debugPrint('[probe] flutter row $i')),
            ],
          ),
        );
      },
    ),
  );
}
```

- [ ] **Step 3: Run it and stream the native log**

```bash
cd liquid_shell/example
xcrun simctl boot "$PHONE27"; open -a Simulator
fvm flutter run -d "$PHONE27" -t lib/probe_search.dart &
xcrun simctl spawn "$PHONE27" log stream --style compact --predicate 'eventMessage CONTAINS "[probe]"'
```

Expected: the shell with Home, Library and a separate ⌕; `[probe]` lines once the search tab is used. Repeat on `$PHONE26`, `$IPAD26` and `$IPAD27` (iPad: also Stage Manager / Split View narrow window by hand in Simulator.app). For the environment switches, relaunch with `SIMCTL_CHILD_PROBE_DIRECT=1` (or `PROBE_PUSH=1`, `PROBE_HIDE_BAR=1`, `PROBE_SETTEXT=1`, `PROBE_DEACTIVATE=1`) exported before `fvm flutter run`.

- [ ] **Step 4: Measure P1–P8 (pass bars)**

| # | Check | How | Pass bar / what to record |
|---|---|---|---|
| P1 | Programmatic select morph vs UIKit's own | `xcrun simctl io "$PHONE27" recordVideo --codec h264 p1-<mode>.mp4` while tapping ⌕, once with `PROBE_DIRECT=1`, once without; count 60 fps frames from the tap's first highlight to the pill starting to collapse (`ffmpeg` is not installed: step through the video in QuickTime with ←/→) | Programmatic ≤ 2 frames later than direct → **no `guarded` flag** (Q6 default). More → Task 4 Step 6 adds the flag |
| P2 | iPhone push inside the search nav | `PROBE_PUSH=1`, then `PROBE_PUSH=1 PROBE_HIDE_BAR=1`; screenshot both (`xcrun simctl io "$PHONE27" screenshot p2-<mode>.png`) | Record whether the bottom field / collapsed circle stay over the detail; choose `hidesBottomBarWhenPushed` (Q19) |
| P3 | Vietnamese Telex in the native field | Simulator: Settings → General → Keyboard → Keyboards → Add → Vietnamese (Telex). Type with the on-screen keyboard `hoof hoafn kieems` | Log ends `text=hồ hoàn kiếm`; no doubled letter in any line. **Fail → stop, tell the owner** |
| P4 | Keyboard insets reach Flutter | Tap the native field; read the probe page's `viewInsets` line | `viewInsets.bottom` > 300 on iPhone |
| P5 | First responder both ways | Native field focused → tap "Flutter field"; then the reverse | One keyboard; keys go to the focused field only; log `first=0` for the native field after the Flutter field took focus. **Fail → stop, tell the owner** |
| P6 | Safe areas and field frames per phase | Log `host safe=` and `field=` in idle (other tab), selected, active, after × | Record every value on all four simulators (Task 5's XCTests use them) |
| P7 | Programmatic deactivate | `PROBE_DEACTIVATE=1`, type `ho` before 8 s | Record whether `text after` is empty (then Task 4 restores it) |
| P8 | Programmatic `searchBar.text` | `PROBE_SETTEXT=1` while the search tab is selected | Record whether a `[probe] text=ho` line follows (then Task 4 must suppress it) |

Also note the hit-test log (tap the field, ×, the collapsed circle, a Flutter row in each phase): field, × and circle must not print `[probe] flutter row`; rows must.

- [ ] **Step 5: Write `docs/qa/p3b/probe.md`**

```markdown
# P3b-1 probe: the search tab over the Flutter view (VK-407 Task 1)

Simulators: iPhone 17 Pro and iPad Air 11-inch (M4), iOS 26.5 and 27.0
(own `vk407 …` devices). Throwaway patch of `NativeTabsController` and
`PassThroughView`, plus `lib/probe_search.dart`; reverted after the run.

| # | Check | iPhone 26.5 | iPhone 27.0 | iPad 26.5 | iPad 27.0 | Decision |
|---|---|---|---|---|---|---|
| P1 | Programmatic select vs direct (frames at 60 fps) | | | | | guarded flag: yes / no |
| P2 | Push inside the search tab: bottom field over the detail? | | | n/a | n/a | hidesBottomBarWhenPushed: yes / no |
| P3 | Telex `hoof hoafn kieems` → `hồ hoàn kiếm` | | | | | pass / STOP |
| P4 | `viewInsets.bottom` with the native field focused | | | | | |
| P5 | First responder native ↔ Flutter | | | | | pass / STOP |
| P6 | Host safe area (t/l/b/r) idle · selected · active · after × | | | | | Task 5 XCTest values |
| P6 | Field frame in Flutter coordinates, selected · active | | | | | |
| P7 | Text after a programmatic deactivate | | | | | restore in setSearchActive(false): yes / no |
| P8 | `updateSearchResults` after programmatic `text =` | | | | | suppress: yes (always) |
| Hit | field / × / circle → UIKit, rows → Flutter, every phase | | | | | |
```

Fill every cell with what was measured before committing.

- [ ] **Step 6: Stop rule**

If P3 or P5 fails, stop here and report to the owner with the log lines; do not start Task 2. Every other row only selects a branch of Tasks 4–5.

- [ ] **Step 7: Revert the probe and commit the notes**

```bash
git restore liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeTabsController.swift \
  liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/PassThroughView.swift
command rm liquid_shell/example/lib/probe_search.dart
git status --short        # only docs/qa/p3b/probe.md is new
bash .githooks/pre-commit
git add docs/qa/p3b/probe.md
git commit -m "docs(docs): P3b-1 probe of the search tab over Flutter (VK-407)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Platform interface: search, pages and their events

**Files:**
- Modify: `liquid_shell_platform_interface/lib/src/native_chrome.dart`
- Modify: `liquid_shell_platform_interface/lib/src/liquid_shell_platform.dart`
- Test: `liquid_shell_platform_interface/test/native_chrome_test.dart`, `liquid_shell_platform_interface/test/liquid_shell_platform_test.dart`

**Interfaces:**
- Consumes: P2's value types.
- Produces (exported by `liquid_shell_platform_interface.dart` through `src/native_chrome.dart`):
  - `class LiquidNativePage { const LiquidNativePage({required String title, bool? largeTitle}); }`
  - `LiquidNativeTab({…, bool search = false, List<LiquidNativePage> pages = const []})`
  - `class LiquidNativeSearchConfig { const LiquidNativeSearchConfig({String? placeholder}); }`
  - `LiquidNativeChromeConfig({…, LiquidNativeSearchConfig? search})`
  - events `LiquidNativeSearchTextChanged(String text, {required bool composing})`, `LiquidNativeSearchActiveChanged(bool active)`, `LiquidNativeSearchSubmitted(String text)`, `LiquidNativeSearchFieldChanged(Rect frame)`, `LiquidNativeBackTapped(int tab)`
  - `LiquidShellPlatform.setNativeSearchText(String text)`, `setNativeSearchActive({required bool active})`, `setNativePageScroll({required int tab, required double offset})`, each `Future<void>` defaulting to nothing.

- [ ] **Step 1: Write the failing tests**

Append to `liquid_shell_platform_interface/test/native_chrome_test.dart` (inside `main()`, after the existing groups):

```dart
  group('P3b search and pages', () {
    test('LiquidNativePage compares field by field', () {
      expect(
        const LiquidNativePage(title: 'Detail', largeTitle: false),
        const LiquidNativePage(title: 'Detail', largeTitle: false),
      );
      expect(
        const LiquidNativePage(title: 'Detail'),
        isNot(const LiquidNativePage(title: 'Detail', largeTitle: true)),
      );
      expect(
        const LiquidNativePage(title: 'A').hashCode,
        const LiquidNativePage(title: 'A').hashCode,
      );
      expect(
        const LiquidNativePage(title: 'A', largeTitle: true).toString(),
        'LiquidNativePage(title: A, largeTitle: true)',
      );
    });

    test('LiquidNativeTab includes search and pages in ==', () {
      const base = LiquidNativeTab(title: 'Search', sfSymbol: '');
      expect(base.search, isFalse);
      expect(base.pages, isEmpty);
      expect(
        const LiquidNativeTab(title: 'Search', sfSymbol: '', search: true),
        isNot(base),
      );
      expect(
        const LiquidNativeTab(
          title: 'Search',
          sfSymbol: '',
          pages: [LiquidNativePage(title: 'Search')],
        ),
        isNot(base),
      );
      expect(
        const LiquidNativeTab(
          title: 'Search',
          sfSymbol: '',
          pages: [LiquidNativePage(title: 'Search')],
        ),
        const LiquidNativeTab(
          title: 'Search',
          sfSymbol: '',
          pages: [LiquidNativePage(title: 'Search')],
        ),
      );
    });

    test('LiquidNativeSearchConfig and the config field', () {
      const a = LiquidNativeSearchConfig(placeholder: 'Songs, places');
      expect(a, const LiquidNativeSearchConfig(placeholder: 'Songs, places'));
      expect(a, isNot(const LiquidNativeSearchConfig()));
      expect(
        const LiquidNativeChromeConfig(engaged: true, search: a),
        isNot(const LiquidNativeChromeConfig(engaged: true)),
      );
      expect(LiquidNativeChromeConfig.dormant.search, isNull);
      expect(
        const LiquidNativeChromeConfig(engaged: true, search: a).toString(),
        contains('search: LiquidNativeSearchConfig(placeholder: Songs, places)'),
      );
    });

    test('search and back events compare by value', () {
      expect(
        const LiquidNativeSearchTextChanged('hồ', composing: true),
        const LiquidNativeSearchTextChanged('hồ', composing: true),
      );
      expect(
        const LiquidNativeSearchTextChanged('hồ', composing: true),
        isNot(const LiquidNativeSearchTextChanged('hồ', composing: false)),
      );
      expect(
        const LiquidNativeSearchActiveChanged(true),
        const LiquidNativeSearchActiveChanged(true),
      );
      expect(
        const LiquidNativeSearchSubmitted('ho'),
        isNot(const LiquidNativeSearchSubmitted('ha')),
      );
      expect(
        const LiquidNativeSearchFieldChanged(Rect.fromLTWH(8, 490, 330, 48)),
        const LiquidNativeSearchFieldChanged(Rect.fromLTWH(8, 490, 330, 48)),
      );
      expect(const LiquidNativeBackTapped(2), const LiquidNativeBackTapped(2));
      expect(const LiquidNativeBackTapped(2), isNot(const LiquidNativeBackTapped(1)));
      expect(
        const LiquidNativeSearchTextChanged('a', composing: false).toString(),
        'LiquidNativeSearchTextChanged(a, composing: false)',
      );
    });
  });
```

Add at the top of that file, if not present: `import 'dart:ui';`.

Append to `liquid_shell_platform_interface/test/liquid_shell_platform_test.dart` (inside `main()`; the file already has a minimal subclass of `LiquidShellPlatform` used to test defaults; if it is named differently, use that one):

```dart
  test('the P3b members default to nothing and touch no channel', () async {
    final platform = _Minimal();
    await platform.setNativeSearchText('x');
    await platform.setNativeSearchActive(active: true);
    await platform.setNativePageScroll(tab: 0, offset: 12);
    // No binding, no channel: reaching here without a MissingPluginException
    // is the assertion.
  });
```

and, if the file has no such class yet:

```dart
class _Minimal extends LiquidShellPlatform {
  @override
  Stream<LiquidPlatformSignals> watchSignals() => const Stream.empty();
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `cd liquid_shell_platform_interface && fvm flutter test`
Expected: compile errors: `LiquidNativePage`, `LiquidNativeSearchConfig`, `LiquidNativeSearchTextChanged` … not defined; `setNativeSearchText` isn't defined.

- [ ] **Step 3: Implement**

In `native_chrome.dart`, add `import 'dart:ui' show Rect;` next to the existing imports, then add after `LiquidNativeFooter`:

```dart
/// One page of a tab's navigation stack (root first): its title for the
/// native navigation bar.
@immutable
class LiquidNativePage {
  /// Creates a page.
  const LiquidNativePage({required this.title, this.largeTitle});

  /// Navigation bar title.
  final String title;

  /// Large title; null leaves it to the platform (large on a phone's root
  /// page, inline elsewhere).
  final bool? largeTitle;

  @override
  bool operator ==(Object other) =>
      other is LiquidNativePage &&
      other.title == title &&
      other.largeTitle == largeTitle;

  @override
  int get hashCode => Object.hash(title, largeTitle);

  @override
  String toString() =>
      'LiquidNativePage(title: $title, largeTitle: $largeTitle)';
}

/// The native search field of the search tab.
@immutable
class LiquidNativeSearchConfig {
  /// Creates the config.
  const LiquidNativeSearchConfig({this.placeholder});

  /// Placeholder of the empty field; null keeps the system's.
  final String? placeholder;

  @override
  bool operator ==(Object other) =>
      other is LiquidNativeSearchConfig && other.placeholder == placeholder;

  @override
  int get hashCode => placeholder.hashCode;

  @override
  String toString() => 'LiquidNativeSearchConfig(placeholder: $placeholder)';
}
```

Change `LiquidNativeTab`:

```dart
  const LiquidNativeTab({
    required this.title,
    required this.sfSymbol,
    this.badge,
    this.sidebarOnly = false,
    this.search = false,
    this.pages = const [],
  });

  // … existing fields …

  /// The search tab: UIKit's search tab, hosting the search field.
  final bool search;

  /// The tab's page stack, root first. Empty: the root shows [title].
  final List<LiquidNativePage> pages;

  @override
  bool operator ==(Object other) =>
      other is LiquidNativeTab &&
      other.title == title &&
      other.sfSymbol == sfSymbol &&
      other.badge == badge &&
      other.sidebarOnly == sidebarOnly &&
      other.search == search &&
      listEquals(other.pages, pages);

  @override
  int get hashCode => Object.hash(
    title,
    sfSymbol,
    badge,
    sidebarOnly,
    search,
    Object.hashAll(pages),
  );

  @override
  String toString() =>
      'LiquidNativeTab(title: $title, sfSymbol: $sfSymbol, badge: $badge, '
      'sidebarOnly: $sidebarOnly, search: $search, pages: $pages)';
```

In `LiquidNativeChromeConfig`: add the constructor parameter `this.search,` after `this.footer,`, the field

```dart
  /// The search tab's field, when a tab has `search: true`.
  final LiquidNativeSearchConfig? search;
```

`other.search == search &&` in `==`, `search,` in `hashCode` (after `footer`), and `', search: $search'` in `toString` after the footer part:

```dart
  @override
  String toString() =>
      'LiquidNativeChromeConfig(engaged: $engaged, tabs: $tabs, '
      'selectedIndex: $selectedIndex, trailing: $trailing, footer: $footer, '
      'search: $search, '
      'tintArgb: 0x${tintArgb.toRadixString(16).padLeft(8, '0')}, '
      'dark: $dark, rtl: $rtl, hidden: $hidden, interactive: $interactive)';
```

Add the events after `LiquidWindowControlsChanged`:

```dart
/// The user changed the native search field's text. [composing]: an IME
/// composition (Telex, kana) is in progress.
final class LiquidNativeSearchTextChanged extends LiquidNativeEvent {
  /// Creates the event.
  const LiquidNativeSearchTextChanged(this.text, {required this.composing});

  /// The field's text, composition included.
  final String text;

  /// Whether an IME composition is in progress.
  final bool composing;

  @override
  bool operator ==(Object other) =>
      other is LiquidNativeSearchTextChanged &&
      other.text == text &&
      other.composing == composing;

  @override
  int get hashCode => Object.hash(text, composing);

  @override
  String toString() =>
      'LiquidNativeSearchTextChanged($text, composing: $composing)';
}

/// The native search field gained or lost focus (presented or dismissed).
final class LiquidNativeSearchActiveChanged extends LiquidNativeEvent {
  /// Creates the event.
  const LiquidNativeSearchActiveChanged(this.active);

  /// Whether the search is active.
  final bool active;

  @override
  bool operator ==(Object other) =>
      other is LiquidNativeSearchActiveChanged && other.active == active;

  @override
  int get hashCode => active.hashCode;

  @override
  String toString() => 'LiquidNativeSearchActiveChanged($active)';
}

/// The user pressed the keyboard's Search key in the native field.
final class LiquidNativeSearchSubmitted extends LiquidNativeEvent {
  /// Creates the event.
  const LiquidNativeSearchSubmitted(this.text);

  /// The submitted text.
  final String text;

  @override
  bool operator ==(Object other) =>
      other is LiquidNativeSearchSubmitted && other.text == text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'LiquidNativeSearchSubmitted($text)';
}

/// Where the native search field is, in the Flutter view's coordinates;
/// [Rect.zero] when it is not on screen.
final class LiquidNativeSearchFieldChanged extends LiquidNativeEvent {
  /// Creates the event.
  const LiquidNativeSearchFieldChanged(this.frame);

  /// The field's frame.
  final Rect frame;

  @override
  bool operator ==(Object other) =>
      other is LiquidNativeSearchFieldChanged && other.frame == frame;

  @override
  int get hashCode => frame.hashCode;

  @override
  String toString() => 'LiquidNativeSearchFieldChanged($frame)';
}

/// The user tapped the native back button of tab [tab]: a proposal; the
/// shell pops the Flutter page, and the native stack follows.
final class LiquidNativeBackTapped extends LiquidNativeEvent {
  /// Creates the event.
  const LiquidNativeBackTapped(this.tab);

  /// Index of the destination whose page should pop.
  final int tab;

  @override
  bool operator ==(Object other) =>
      other is LiquidNativeBackTapped && other.tab == tab;

  @override
  int get hashCode => tab.hashCode;

  @override
  String toString() => 'LiquidNativeBackTapped($tab)';
}
```

In `liquid_shell_platform.dart`, after `readWindowControls`:

```dart
  /// Sets the native search field's text, once no IME composition is in
  /// progress. Default: does nothing.
  Future<void> setNativeSearchText(String text) async {}

  /// Focuses (presents) or unfocuses the native search; unfocusing keeps
  /// the text. Default: does nothing.
  Future<void> setNativeSearchActive({required bool active}) async {}

  /// The scroll offset of tab [tab]'s top page, for the native large title
  /// and scroll-edge effect. Default: does nothing.
  Future<void> setNativePageScroll({
    required int tab,
    required double offset,
  }) async {}
```

The existing switch in `liquid_shell/lib/src/native/native_host.dart` (`_onEvent`) and in `_LiquidShellState._onNativeEvent` must stay exhaustive. Until Task 8 routes them, add to the `LiquidNativeStateChanged() || LiquidWindowControlsChanged()` arm of `_onNativeEvent` (shell) the new types:

```dart
      case LiquidNativeStateChanged() ||
          LiquidWindowControlsChanged() ||
          LiquidNativeSearchTextChanged() ||
          LiquidNativeSearchActiveChanged() ||
          LiquidNativeSearchSubmitted() ||
          LiquidNativeSearchFieldChanged() ||
          LiquidNativeBackTapped():
        break;
```

and in `NativeChromeHost._onEvent` add an arm before the taps:

```dart
      case LiquidNativeSearchTextChanged() ||
          LiquidNativeSearchActiveChanged() ||
          LiquidNativeSearchSubmitted() ||
          LiquidNativeSearchFieldChanged() ||
          LiquidNativeBackTapped():
        if (_claims.isNotEmpty) _claims.last._onEvent(event);
```

- [ ] **Step 4: Run the tests**

Run: `cd liquid_shell_platform_interface && fvm flutter test && cd ../liquid_shell && fvm flutter test --exclude-tags golden`
Expected: all pass (the shell tests are unchanged in behaviour).

- [ ] **Step 5: Commit**

```bash
bash .githooks/pre-commit
git add liquid_shell_platform_interface/lib/src/native_chrome.dart \
  liquid_shell_platform_interface/lib/src/liquid_shell_platform.dart \
  liquid_shell_platform_interface/test/native_chrome_test.dart \
  liquid_shell_platform_interface/test/liquid_shell_platform_test.dart \
  liquid_shell/lib/src/native/native_host.dart liquid_shell/lib/src/shell/liquid_shell.dart
git commit -m "feat(platform): native search, page stacks and back events in the interface (VK-407)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: The channel: Pigeon messages and the iOS Dart boundary

**Files:**
- Modify: `liquid_shell_ios/pigeons/native_shell.dart`; regenerate `liquid_shell_ios/lib/src/native_shell_api.g.dart` and `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeShellApi.g.swift` with `make pigeon`
- Modify: `liquid_shell_ios/lib/src/mapping.dart`, `liquid_shell_ios/lib/src/platform.dart`, `liquid_shell_ios/lib/liquid_shell_ios.dart`
- Modify: `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeShellInstaller.swift` (protocol conformance; real bodies in Tasks 4–5)
- Modify: `liquid_shell/example/ios/RunnerTests/RunnerTests.swift` (`RecordingEvents` conformance)
- Test: `liquid_shell_ios/test/liquid_shell_ios_test.dart`

**Interfaces:**
- Consumes: Task 2's interface types.
- Produces:
  - Pigeon (Dart and Swift): `NativePage{String title; bool? largeTitle}`, `NativeTab.search: bool`, `NativeTab.pages: List<NativePage>`, `NativeSearchConfig{String? placeholder}`, `NativeChromeConfig.search: NativeSearchConfig?`, `NativeRect{double x, y, width, height}`, `NativeDebugSnapshot{String selectedTab; bool searchActive; String searchText; String placement; List<String> pageTitles; NativeRect fieldFrame; bool firstResponderIsSearch}`, `NativeTapTarget` + `searchField`, `searchCancel`, `back`.
  - Host API: `setSearchText(String text)`, `setSearchActive(bool active)`, `setPageScroll(int tab, double offset)`, `NativeDebugSnapshot debugSnapshot()`.
  - Flutter API: `onSearchTextChanged(String text, bool composing)`, `onSearchActiveChanged(bool active)`, `onSearchSubmitted(String text)`, `onSearchFieldChanged(NativeRect frame)`, `onBackTapped(int tab)`.
  - Swift protocol members (generated): `setSearchText(text: String) throws`, `setSearchActive(active: Bool) throws`, `setPageScroll(tab: Int64, offset: Double) throws`, `debugSnapshot() throws -> NativeDebugSnapshot`; `NativeShellFlutterApiProtocol` gains `onSearchTextChanged(text:composing:completion:)`, `onSearchActiveChanged(active:completion:)`, `onSearchSubmitted(text:completion:)`, `onSearchFieldChanged(frame:completion:)`, `onBackTapped(tab:completion:)`.
  - Dart: `LiquidShellIOS.setNativeSearchText/setNativeSearchActive/setNativePageScroll`, `@visibleForTesting Future<NativeDebugSnapshot> debugSnapshot()`; `NativeDebugSnapshot` exported from `liquid_shell_ios.dart` next to `NativeTapTarget`; mapping `rectFromNative(NativeRect) → Rect` (non-finite → `Rect.zero`).

- [ ] **Step 1: Write the failing Dart tests**

In `liquid_shell_ios/test/liquid_shell_ios_test.dart`, add to `_FakeHost`:

```dart
  @override
  Future<void> setSearchText(String text) async {
    calls.add('setSearchText($text)');
    _maybeFail();
  }

  @override
  Future<void> setSearchActive(bool active) async {
    calls.add('setSearchActive($active)');
    _maybeFail();
  }

  @override
  Future<void> setPageScroll(int tab, double offset) async {
    calls.add('setPageScroll($tab, $offset)');
    _maybeFail();
  }

  NativeDebugSnapshot snapshot = NativeDebugSnapshot(
    selectedTab: 'destination2',
    searchActive: true,
    searchText: 'hồ',
    placement: 'stacked',
    pageTitles: ['Search', 'Hồ Hoàn Kiếm'],
    fieldFrame: NativeRect(x: 20, y: 86, width: 780, height: 44),
    firstResponderIsSearch: true,
  );

  @override
  Future<NativeDebugSnapshot> debugSnapshot() async {
    calls.add('debugSnapshot');
    _maybeFail();
    return snapshot;
  }
```

and these tests inside `main()`:

```dart
  test('updateNativeChrome sends search, pages and the placeholder', () async {
    final host = _FakeHost();
    await liquidShellIOSWithHost(host).updateNativeChrome(
      const LiquidNativeChromeConfig(
        engaged: true,
        tabs: [
          LiquidNativeTab(title: 'Home', sfSymbol: 'house'),
          LiquidNativeTab(
            title: 'Search',
            sfSymbol: '',
            search: true,
            pages: [
              LiquidNativePage(title: 'Search', largeTitle: true),
              LiquidNativePage(title: 'Hồ Hoàn Kiếm'),
            ],
          ),
        ],
        search: LiquidNativeSearchConfig(placeholder: 'Songs, places'),
      ),
    );
    final sent = host.calls.single as NativeChromeConfig;
    expect(sent.tabs.map((t) => t.search), [false, true]);
    expect(sent.tabs.first.pages, isEmpty);
    expect(sent.tabs.last.pages.map((p) => p.title), ['Search', 'Hồ Hoàn Kiếm']);
    expect(sent.tabs.last.pages.map((p) => p.largeTitle), [true, null]);
    expect(sent.search?.placeholder, 'Songs, places');
  });

  test('no search config maps to null', () async {
    final host = _FakeHost();
    await liquidShellIOSWithHost(host).updateNativeChrome(_config);
    expect((host.calls.single as NativeChromeConfig).search, isNull);
  });

  test('search commands and page scroll reach the host', () async {
    final host = _FakeHost();
    final platform = liquidShellIOSWithHost(host);
    await platform.setNativeSearchText('hồ');
    await platform.setNativeSearchActive(active: true);
    await platform.setNativePageScroll(tab: 2, offset: 48.5);
    expect(host.calls, [
      'setSearchText(hồ)',
      'setSearchActive(true)',
      'setPageScroll(2, 48.5)',
    ]);
  });

  test('a non-finite page scroll offset is not sent', () async {
    final host = _FakeHost();
    final platform = liquidShellIOSWithHost(host);
    await platform.setNativePageScroll(tab: 0, offset: double.nan);
    await platform.setNativePageScroll(tab: 0, offset: double.infinity);
    expect(host.calls, isEmpty);
  });

  test('failed search commands are swallowed and logged once each', () async {
    final logs = captureLogs();
    final host = _FakeHost()..failure = PlatformException(code: 'gone');
    final platform = liquidShellIOSWithHost(host);
    await platform.setNativeSearchText('a');
    await platform.setNativeSearchText('b');
    await platform.setNativeSearchActive(active: false);
    expect(logs.where((l) => l.contains('setSearchText')), hasLength(1));
    expect(logs.where((l) => l.contains('setSearchActive')), hasLength(1));
  });

  test('debugSnapshot passes the native snapshot through', () async {
    final host = _FakeHost();
    final snapshot = await liquidShellIOSWithHost(host).debugSnapshot();
    expect(snapshot.pageTitles, ['Search', 'Hồ Hoàn Kiếm']);
    expect(snapshot.placement, 'stacked');
    expect(host.calls, ['debugSnapshot']);
  });

  test('rectFromNative maps, and zeroes a non-finite rect', () {
    expect(
      rectFromNative(NativeRect(x: 8, y: 490, width: 330, height: 48)),
      const Rect.fromLTWH(8, 490, 330, 48),
    );
    expect(
      rectFromNative(NativeRect(x: double.nan, y: 0, width: 1, height: 1)),
      Rect.zero,
    );
  });

  test('native search and back calls on the real channel arrive as events', () async {
    final platform = liquidShellIOSWithHost(_FakeHost());
    final events = <LiquidNativeEvent>[];
    final subscription = platform.nativeEvents.listen(events.add);
    addTearDown(subscription.cancel);

    expect(await deliver('onSearchTextChanged', ['hô', true]), isTrue);
    expect(await deliver('onSearchActiveChanged', [true]), isTrue);
    expect(await deliver('onSearchSubmitted', ['hồ']), isTrue);
    expect(
      await deliver('onSearchFieldChanged', [
        NativeRect(x: 8, y: 490, width: 330, height: 48),
      ]),
      isTrue,
    );
    expect(await deliver('onBackTapped', [2]), isTrue);

    expect(events, [
      const LiquidNativeSearchTextChanged('hô', composing: true),
      const LiquidNativeSearchActiveChanged(true),
      const LiquidNativeSearchSubmitted('hồ'),
      const LiquidNativeSearchFieldChanged(Rect.fromLTWH(8, 490, 330, 48)),
      const LiquidNativeBackTapped(2),
    ]);
  });
```

Add `import 'dart:ui' show Rect;` at the top of the test file.

- [ ] **Step 2: Run them to see them fail**

Run: `cd liquid_shell_ios && fvm flutter test`
Expected: compile errors: `setSearchText` is not a method of `NativeShellHostApi`, `NativeRect`/`NativeDebugSnapshot` undefined.

- [ ] **Step 3: Extend the Pigeon source**

In `liquid_shell_ios/pigeons/native_shell.dart`:

Add after `NativeFooter`:

```dart
/// One page of a tab's navigation stack (root first).
class NativePage {
  NativePage({required this.title, this.largeTitle});

  String title;
  bool? largeTitle;
}

/// The search tab's field.
class NativeSearchConfig {
  NativeSearchConfig({this.placeholder});

  String? placeholder;
}

/// A rectangle in the Flutter view's coordinates (points).
class NativeRect {
  NativeRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  double x;
  double y;
  double width;
  double height;
}

/// Debug builds: the native search and page state, for integration tests.
class NativeDebugSnapshot {
  NativeDebugSnapshot({
    required this.selectedTab,
    required this.searchActive,
    required this.searchText,
    required this.placement,
    required this.pageTitles,
    required this.fieldFrame,
    required this.firstResponderIsSearch,
  });

  /// The selected `UITab`'s identifier ("destination<i>", or "" when none).
  String selectedTab;
  bool searchActive;
  String searchText;

  /// The realised `searchBarPlacement`: "integrated", "stacked", … or "".
  String placement;

  /// The search tab's navigation titles, root first.
  List<String> pageTitles;
  NativeRect fieldFrame;
  bool firstResponderIsSearch;
}
```

Change `NativeTab`:

```dart
class NativeTab {
  NativeTab({
    required this.title,
    required this.sfSymbol,
    required this.sidebarOnly,
    required this.search,
    required this.pages,
    this.badge,
  });

  String title;
  String sfSymbol;
  String? badge;
  bool sidebarOnly;
  bool search;
  List<NativePage> pages;
}
```

In `NativeChromeConfig`, add `this.search,` to the constructor and the field `NativeSearchConfig? search;` after `footer`.

Change `NativeTapTarget` to `enum NativeTapTarget { destination, trailing, footer, searchField, searchCancel, back }`.

Add to `NativeShellHostApi`, after `windowControls()`:

```dart
  /// Sets the search field's text once no IME composition is in progress.
  void setSearchText(String text);

  /// Presents or dismisses the search; dismissing keeps the text.
  void setSearchActive(bool active);

  /// The top page's scroll offset of tab [tab] (proxy scroll view).
  void setPageScroll(int tab, double offset);

  /// Debug builds: the native search and page state. Release: empty.
  NativeDebugSnapshot debugSnapshot();
```

Add to `NativeShellFlutterApi`:

```dart
  void onSearchTextChanged(String text, bool composing);

  void onSearchActiveChanged(bool active);

  void onSearchSubmitted(String text);

  void onSearchFieldChanged(NativeRect frame);

  void onBackTapped(int tab);
```

Run: `make pigeon`
Expected: both generated files rewritten; `git diff --stat` lists the source and the two `*.g.*` files.

- [ ] **Step 4: Map at the boundary**

In `liquid_shell_ios/lib/src/mapping.dart`, add `import 'dart:ui' show Rect;` and replace the `tabs:` entry of `configToNative` with:

```dart
      tabs: [
        for (final tab in config.tabs)
          NativeTab(
            title: tab.title,
            sfSymbol: tab.sfSymbol,
            badge: tab.badge,
            sidebarOnly: tab.sidebarOnly,
            search: tab.search,
            pages: [
              for (final page in tab.pages)
                NativePage(title: page.title, largeTitle: page.largeTitle),
            ],
          ),
      ],
```

add after `footer:`:

```dart
      search: switch (config.search) {
        null => null,
        final search => NativeSearchConfig(placeholder: search.placeholder),
      },
```

and append:

```dart
/// A native rect, checked at the boundary: any non-finite field makes it
/// [Rect.zero] ("not on screen").
Rect rectFromNative(NativeRect rect) {
  final values = [rect.x, rect.y, rect.width, rect.height];
  if (values.any((v) => !v.isFinite)) return Rect.zero;
  return Rect.fromLTWH(rect.x, rect.y, rect.width, rect.height);
}
```

In `liquid_shell_ios/lib/src/platform.dart`, add after `readWindowControls`:

```dart
  @override
  Future<void> setNativeSearchText(String text) =>
      _send('setSearchText', () => _host.setSearchText(text));

  @override
  Future<void> setNativeSearchActive({required bool active}) =>
      _send('setSearchActive', () => _host.setSearchActive(active));

  @override
  Future<void> setNativePageScroll({
    required int tab,
    required double offset,
  }) async {
    // Checked at the boundary: a NaN or infinite offset never crosses.
    if (!offset.isFinite) return;
    await _send('setPageScroll', () => _host.setPageScroll(tab, offset));
  }

  /// Debug builds of the plugin report the native search and page state;
  /// release builds an empty snapshot. For integration tests.
  @visibleForTesting
  Future<NativeDebugSnapshot> debugSnapshot() => _host.debugSnapshot();
```

and to `_NativeReceiver`:

```dart
  @override
  void onSearchTextChanged(String text, bool composing) =>
      _emit(LiquidNativeSearchTextChanged(text, composing: composing));

  @override
  void onSearchActiveChanged(bool active) =>
      _emit(LiquidNativeSearchActiveChanged(active));

  @override
  void onSearchSubmitted(String text) =>
      _emit(LiquidNativeSearchSubmitted(text));

  @override
  void onSearchFieldChanged(NativeRect frame) =>
      _emit(LiquidNativeSearchFieldChanged(rectFromNative(frame)));

  @override
  void onBackTapped(int tab) => _emit(LiquidNativeBackTapped(tab));
```

In `liquid_shell_ios/lib/liquid_shell_ios.dart`:

```dart
export 'src/native_shell_api.g.dart'
    show NativeDebugSnapshot, NativeRect, NativeTapTarget;
```

- [ ] **Step 5: Keep the Swift side compiling**

In `NativeShellInstaller.swift`, after `debugTap(…)` (Tasks 4–5 give these real bodies through `NativeTabsController`):

```swift
  func setSearchText(text: String) throws {
    if #available(iOS 26.0, *) { tabs?.setSearchText(text) }
  }

  func setSearchActive(active: Bool) throws {
    if #available(iOS 26.0, *) { tabs?.setSearchActive(active) }
  }

  func setPageScroll(tab: Int64, offset: Double) throws {
    if #available(iOS 26.0, *) { tabs?.setPageScroll(tab: Int(tab), offset: offset) }
  }

  func debugSnapshot() throws -> NativeDebugSnapshot {
    if #available(iOS 26.0, *), let tabs { return tabs.debugSnapshot() }
    return NativeDebugSnapshot.empty
  }
```

In `NativeTabsController.swift`, add these stubs at the end of the class body (Task 4 replaces each):

```swift
  // MARK: - Search and pages (P3b-1 Task 3 stubs; Tasks 4–5 implement)

  func setSearchText(_ text: String) {}
  func setSearchActive(_ active: Bool) {}
  func setPageScroll(tab: Int, offset: Double) {}
  func debugSnapshot() -> NativeDebugSnapshot { .empty }
```

and at the end of the file:

```swift
extension NativeDebugSnapshot {
  /// Release builds and "nothing installed".
  static var empty: NativeDebugSnapshot {
    NativeDebugSnapshot(
      selectedTab: "", searchActive: false, searchText: "", placement: "", pageTitles: [],
      fieldFrame: NativeRect(x: 0, y: 0, width: 0, height: 0), firstResponderIsSearch: false)
  }
}
```

`NativeTab` gained two required fields: in `NativeTabsController.swift` nothing constructs one; in `RunnerTests.swift` update the helper `config(…)` to pass `search: false, pages: []` on both `NativeTab(…)` lines (and on the `Reports` one), and add to `RecordingEvents`:

```swift
  var searchTexts: [(String, Bool)] = []
  var fieldFrames: [NativeRect] = []

  func onSearchTextChanged(
    text textArg: String, composing composingArg: Bool,
    completion: @escaping (Result<Void, PigeonError>) -> Void
  ) {
    sent.append("searchText \(textArg)")
    searchTexts.append((textArg, composingArg))
    completion(.success(()))
  }

  func onSearchActiveChanged(
    active activeArg: Bool, completion: @escaping (Result<Void, PigeonError>) -> Void
  ) {
    sent.append("searchActive \(activeArg)")
    completion(.success(()))
  }

  func onSearchSubmitted(
    text textArg: String, completion: @escaping (Result<Void, PigeonError>) -> Void
  ) {
    sent.append("searchSubmitted \(textArg)")
    completion(.success(()))
  }

  func onSearchFieldChanged(
    frame frameArg: NativeRect, completion: @escaping (Result<Void, PigeonError>) -> Void
  ) {
    sent.append("field")
    fieldFrames.append(frameArg)
    completion(.success(()))
  }

  func onBackTapped(tab tabArg: Int64, completion: @escaping (Result<Void, PigeonError>) -> Void) {
    sent.append("back \(tabArg)")
    completion(.success(()))
  }
```

The `debugTap` switch in `NativeTabsController` must stay exhaustive: add `case .searchField, .searchCancel, .back: break` (Task 5 implements them).

- [ ] **Step 6: Run everything that compiles the channel**

Run: `cd liquid_shell_ios && fvm flutter test`
Expected: PASS.
Run: `make pigeon-check`
Expected: `✓ pigeon output matches its source` (after staging is irrelevant: it checks the working tree against `git status`, so run it after Step 7's `git add`, or expect the drift message now and re-run after the commit).
Run: `make ios-unit IOS_UNIT_DEVICE="$IPAD27"`
Expected: `** TEST SUCCEEDED **` (P2's XCTests, unchanged behaviour).

- [ ] **Step 7: Commit**

```bash
bash .githooks/pre-commit
git add liquid_shell_ios/pigeons/native_shell.dart liquid_shell_ios/lib/src/native_shell_api.g.dart \
  liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeShellApi.g.swift \
  liquid_shell_ios/lib/src/mapping.dart liquid_shell_ios/lib/src/platform.dart \
  liquid_shell_ios/lib/liquid_shell_ios.dart liquid_shell_ios/test/liquid_shell_ios_test.dart \
  liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeShellInstaller.swift \
  liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeTabsController.swift \
  liquid_shell/example/ios/RunnerTests/RunnerTests.swift
git commit -m "feat(ios): search, page stack and back messages on the native channel (VK-407)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
make pigeon-check
```

---

### Task 4: Native search tab: `UISearchTab`, the search navigation controller and the query bridge

**Files:**
- Create: `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/SearchMath.swift`
- Create: `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/SearchBridge.swift`
- Create: `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/ShellNavController.swift`
- Modify: `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeTabsController.swift`
- Test: `liquid_shell/example/ios/RunnerTests/RunnerTests.swift`

**Interfaces:**
- Consumes: Task 3's generated types; Task 1's P1 and P7/P8 decisions.
- Produces (Swift, module-internal; P3b-2 consumes these names):
  - `enum SearchPlacement { case automatic, stacked }`, `struct SearchTabStyle: Equatable { placement, hidesWhenScrolling: Bool?, largeTitle: Bool, prominent: Bool }`, `enum SearchMath { static func style(isPad: Bool, osMajor: Int, rootLargeTitle: Bool?) -> SearchTabStyle }`
  - `final class SearchBridge: NSObject, UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate` with `controller: UISearchController`, `canReport: () -> Bool`, `onText: (String, Bool) -> Void`, `onActive: (Bool) -> Void`, `onSubmit: (String) -> Void`, `isComposing: () -> Bool`, `pendingText: String?`, `text: String`, `setText(_:)`, `activate()`, `dismissKeepingText()`, `debugCancel()`
  - `final class ShellNavController: UINavigationController` with `init(root: PageHostController)`, `rootHost: PageHostController`, `static var hidesBarWhenPushed: Bool`
  - `final class PageHostController: UIViewController` with `installSearch(_:style:)`, `applySearchStyle(_:)` (Task 5 adds the proxy and `onBack`)
  - `NativeTabsController`: `searchTab: UISearchTab?`, `searchIndex: Int?`, `navControllers: [Int: ShellNavController]`, `searchBridge: SearchBridge`, real `setSearchText(_:)`, `setSearchActive(_:)`

- [ ] **Step 1: Write the failing XCTests**

In `RunnerTests.swift`, add a pure test class after `ShellMathTests`:

```swift
final class SearchMathTests: XCTestCase {
  func testAnIPhoneKeepsUIKitsTabHostedFieldAndALargeTitle() {
    XCTAssertEqual(
      SearchMath.style(isPad: false, osMajor: 26, rootLargeTitle: nil),
      SearchTabStyle(placement: .automatic, hidesWhenScrolling: nil, largeTitle: true, prominent: false))
  }

  func testAnIPhoneOnIOS27MakesTheSearchTabProminent() {
    XCTAssertTrue(SearchMath.style(isPad: false, osMajor: 27, rootLargeTitle: nil).prominent)
  }

  func testAnIPadIsStackedInlineAndNeverProminent() {
    for os in [26, 27] {
      XCTAssertEqual(
        SearchMath.style(isPad: true, osMajor: os, rootLargeTitle: nil),
        SearchTabStyle(placement: .stacked, hidesWhenScrolling: false, largeTitle: false, prominent: false))
    }
  }

  func testTheAppsLargeTitleChoiceWins() {
    XCTAssertFalse(SearchMath.style(isPad: false, osMajor: 26, rootLargeTitle: false).largeTitle)
    XCTAssertTrue(SearchMath.style(isPad: true, osMajor: 27, rootLargeTitle: true).largeTitle)
  }
}
```

and, at the end of the file, an extension of `NativeTabsTests` (same file, so it can use the class's private helpers `portraitWindow`, `settle`, `window`, `events`, `hit`, `isNative`):

```swift
// MARK: - P3b-1: the search tab

@available(iOS 26.0, *)
extension NativeTabsTests {
  /// Home · Library · [Reports, sidebar only] · Find (search, last).
  fileprivate func searchConfig(
    selected: Int64 = 0, pages: [NativePage] = [], placeholder: String? = nil,
    reports: Bool = false, hidden: Bool = false, interactive: Bool = true
  ) -> NativeChromeConfig {
    var tabs = [
      NativeTab(title: "Home", sfSymbol: "house", sidebarOnly: false, search: false, pages: []),
      NativeTab(
        title: "Library", sfSymbol: "books.vertical", sidebarOnly: false, search: false, pages: []),
    ]
    if reports {
      tabs.append(
        NativeTab(title: "Reports", sfSymbol: "chart.bar", sidebarOnly: true, search: false, pages: []))
    }
    tabs.append(NativeTab(title: "Find", sfSymbol: "", sidebarOnly: false, search: true, pages: pages))
    return NativeChromeConfig(
      engaged: true, tabs: tabs, selectedIndex: selected,
      search: NativeSearchConfig(placeholder: placeholder), tintArgb: 0xFF00_7AFF, dark: false,
      rtl: false, hidden: hidden, interactive: interactive)
  }

  fileprivate func installedSearchShell(
    selected: Int64 = 0, pages: [NativePage] = [], placeholder: String? = nil,
    reports: Bool = false, sizeClass: UIUserInterfaceSizeClass? = nil
  ) throws -> NativeTabsController {
    let flutter = UIViewController()
    let tabs = NativeTabsController(flutter: flutter, events: events)
    let window = try portraitWindow(root: UIViewController())
    let container = ShellContainerController(tabs: tabs, flutter: flutter)
    if let sizeClass { container.traitOverrides.horizontalSizeClass = sizeClass }
    window.rootViewController = container
    self.window = window
    tabs.dartAttached = true
    tabs.apply(
      searchConfig(selected: selected, pages: pages, placeholder: placeholder, reports: reports))
    settle()
    return tabs
  }

  func testTheSearchDestinationIsUIKitsSearchTabWithTheAppsTitle() throws {
    let tabs = try installedSearchShell()
    let search = try XCTUnwrap(tabs.searchTab)
    XCTAssertTrue(tabs.tabs.contains { $0 === search })
    XCTAssertEqual(tabs.searchIndex, 2)
    XCTAssertEqual(search.title, "Find", "the app's label")
    XCTAssertEqual(search.image, UIImage(systemName: "magnifyingglass"), "no symbol: the system's")
    XCTAssertFalse(search.automaticallyActivatesSearch, "the video's state 2: not focused")
  }

  func testSelectingTheSearchTabOnlyProposesThenDartSelectsIt() throws {
    let tabs = try installedSearchShell()
    let search = try XCTUnwrap(tabs.searchTab)
    XCTAssertFalse(tabs.tabBarController(tabs, shouldSelectTab: search))
    XCTAssertEqual(events.sent.last, "destination 2")
    XCTAssertFalse(tabs.selectedTab === search, "nothing selected before Dart answers")
    tabs.apply(searchConfig(selected: 2))
    settle()
    XCTAssertTrue(tabs.selectedTab === search)
    XCTAssertTrue(tabs.selectedViewController is ShellNavController)
  }

  func testTheSearchRootOwnsTheSearchControllerAndThePlaceholder() throws {
    let tabs = try installedSearchShell(selected: 2, placeholder: "Songs, places")
    let nav = try XCTUnwrap(tabs.navControllers[2])
    XCTAssertTrue(nav.rootHost.navigationItem.searchController === tabs.searchBridge.controller)
    XCTAssertEqual(tabs.searchBridge.controller.searchBar.placeholder, "Songs, places")
    XCTAssertFalse(tabs.searchBridge.controller.obscuresBackgroundDuringPresentation)
    tabs.apply(searchConfig(selected: 2))
    XCTAssertEqual(
      tabs.searchBridge.controller.searchBar.placeholder, tabs.searchBridge.defaultPlaceholder,
      "no placeholder: the system's")
  }

  func testThePlacementFollowsTheIdiom() throws {
    let tabs = try installedSearchShell(selected: 2)
    let item = try XCTUnwrap(tabs.navControllers[2]).rootHost.navigationItem
    if UIDevice.current.userInterfaceIdiom == .pad {
      XCTAssertEqual(item.preferredSearchBarPlacement, .stacked)
      XCTAssertFalse(item.hidesSearchBarWhenScrolling)
      XCTAssertEqual(item.largeTitleDisplayMode, .never)
    } else {
      XCTAssertEqual(item.preferredSearchBarPlacement, .automatic)
      XCTAssertEqual(item.largeTitleDisplayMode, .always)
    }
  }

  func testOnlyAnIPhoneOnIOS27MakesTheSearchTabProminent() throws {
    guard #available(iOS 27.0, *) else { throw XCTSkip("prominentTabIdentifier is iOS 27 API") }
    let tabs = try installedSearchShell()
    let search = try XCTUnwrap(tabs.searchTab)
    if UIDevice.current.userInterfaceIdiom == .phone {
      XCTAssertEqual(tabs.prominentTabIdentifier, search.identifier)
    } else {
      XCTAssertNil(tabs.prominentTabIdentifier)
    }
  }

  func testDartsTextIsAppliedAndNeverEchoed() throws {
    let tabs = try installedSearchShell(selected: 2)
    let bridge = tabs.searchBridge
    tabs.setSearchText("hồ")
    XCTAssertEqual(bridge.text, "hồ")
    bridge.updateSearchResults(for: bridge.controller)  // UIKit may call back (probe P8)
    XCTAssertFalse(events.sent.contains("searchText hồ"), "Dart's own write is not an edit")
    bridge.controller.searchBar.text = "hồ h"  // the user types
    bridge.updateSearchResults(for: bridge.controller)
    XCTAssertEqual(events.sent.last, "searchText hồ h")
    XCTAssertEqual(events.searchTexts.last?.1, false, "no composition")
  }

  func testDartsTextWaitsForTheIMECompositionToEnd() throws {
    let tabs = try installedSearchShell(selected: 2)
    let bridge = tabs.searchBridge
    var composing = true
    bridge.isComposing = { composing }
    tabs.setSearchText("ho")
    XCTAssertEqual(bridge.text, "", "never written into a composition")
    XCTAssertEqual(bridge.pendingText, "ho")
    composing = false
    bridge.updateSearchResults(for: bridge.controller)
    XCTAssertEqual(bridge.text, "ho")
    XCTAssertNil(bridge.pendingText)
  }

  func testUserEditsAreReportedOnlyWhileTheSearchTabIsSelected() throws {
    let tabs = try installedSearchShell(selected: 0)
    let bridge = tabs.searchBridge
    bridge.controller.searchBar.text = "x"
    bridge.updateSearchResults(for: bridge.controller)
    XCTAssertFalse(events.sent.contains("searchText x"))
    tabs.apply(searchConfig(selected: 2))
    settle()
    bridge.controller.searchBar.text = "xy"
    bridge.updateSearchResults(for: bridge.controller)
    XCTAssertEqual(events.sent.last, "searchText xy")
    bridge.searchBarSearchButtonClicked(bridge.controller.searchBar)
    XCTAssertEqual(events.sent.last, "searchSubmitted xy")
  }

  func testActivationNeedsTheSearchTabAndADartDismissalKeepsTheText() throws {
    let tabs = try installedSearchShell(selected: 0)
    let bridge = tabs.searchBridge
    tabs.setSearchActive(true)
    settle()
    XCTAssertFalse(bridge.controller.isActive, "not while another tab is selected")
    tabs.apply(searchConfig(selected: 2))
    settle()
    tabs.setSearchText("hội")
    tabs.setSearchActive(true)
    settle()
    XCTAssertTrue(bridge.controller.isActive)
    XCTAssertTrue(events.sent.contains("searchActive true"))
    tabs.setSearchActive(false)
    settle()
    XCTAssertFalse(bridge.controller.isActive)
    XCTAssertEqual(bridge.text, "hội", "kept (Q2: only × clears)")
    XCTAssertFalse(events.sent.contains("searchText "), "not reported as a user clear")
  }

  func testLeavingTheSearchTabWhileActiveKeepsTheText() throws {
    let tabs = try installedSearchShell(selected: 2)
    let bridge = tabs.searchBridge
    tabs.setSearchText("phố")
    tabs.setSearchActive(true)
    settle()
    tabs.apply(searchConfig(selected: 0))
    settle()
    XCTAssertFalse(bridge.controller.isActive)
    XCTAssertEqual(bridge.text, "phố")
    XCTAssertFalse(events.sent.contains("searchText "))
  }

  func testAHiddenSelectionNeverSelectsTheSearchDestination() throws {
    let tabs = try installedSearchShell(selected: 2, reports: true, sizeClass: .compact)
    XCTAssertEqual(tabs.selectedTab?.identifier, "destination0", "Reports is left out; Home, not Find")
    XCTAssertFalse(tabs.selectedTab === tabs.searchTab)
  }
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `make ios-unit IOS_UNIT_DEVICE="$PHONE27"`
Expected: build failure: `cannot find 'SearchMath' in scope`, `value of type 'NativeTabsController' has no member 'searchTab'`.

- [ ] **Step 3: Add `SearchMath.swift`**

```swift
import Foundation

/// Where the search tab's field goes (spec P3b §7.2).
enum SearchPlacement: Equatable {
  /// UIKit decides: on an iPhone the field is hosted in the tab bar.
  case automatic
  /// Below the title row; rises into it when active (the owner's iPad video).
  case stacked
}

/// The search tab's navigation item settings for one device and OS.
struct SearchTabStyle: Equatable {
  let placement: SearchPlacement
  /// nil keeps UIKit's default.
  let hidesWhenScrolling: Bool?
  let largeTitle: Bool
  /// `UITabBarController.prominentTabIdentifier` = the search tab (iOS 27).
  let prominent: Bool
}

/// Pure decisions of the search tab, unit-tested without UIKit.
enum SearchMath {
  /// iPhone: UIKit's tab-hosted field, a large title, and on iOS 27 the
  /// prominent search tab (without it 27 makes Search an inline tab).
  /// iPad (any width): the stacked field under an inline title, always
  /// visible; never prominent (Q1). The app's `largeTitle` wins when set.
  static func style(isPad: Bool, osMajor: Int, rootLargeTitle: Bool?) -> SearchTabStyle {
    if isPad {
      return SearchTabStyle(
        placement: .stacked, hidesWhenScrolling: false, largeTitle: rootLargeTitle ?? false,
        prominent: false)
    }
    return SearchTabStyle(
      placement: .automatic, hidesWhenScrolling: nil, largeTitle: rootLargeTitle ?? true,
      prominent: osMajor >= 27)
  }
}
```

- [ ] **Step 4: Add `SearchBridge.swift`**

```swift
import UIKit

/// The search tab's `UISearchController` and its delegates (spec P3b
/// §7.4). It reports only what the user did, and writes Dart's text only
/// outside an IME composition, so Vietnamese Telex is never disturbed.
@available(iOS 26.0, *)
final class SearchBridge: NSObject, UISearchResultsUpdating, UISearchControllerDelegate,
  UISearchBarDelegate
{
  let controller = UISearchController(searchResultsController: nil)
  /// Whether a user edit may be reported now (the tabs controller: the
  /// search tab is selected and Dart's config is not being applied).
  var canReport: () -> Bool = { false }
  var onText: (String, Bool) -> Void = { _, _ in }
  var onActive: (Bool) -> Void = { _ in }
  var onSubmit: (String) -> Void = { _ in }
  /// Whether an IME composition (marked text) is in progress. Injectable
  /// for tests: XCTest cannot type marked text.
  var isComposing: () -> Bool = { false }
  /// Dart's text, held while a composition runs.
  private(set) var pendingText: String?
  /// The system placeholder, put back when Dart sends none.
  private(set) var defaultPlaceholder: String?
  /// The text to keep through a dismissal Dart asked for (UIKit may clear it).
  private var keepOnDismiss: String?
  /// Dart's last write: UIKit may call back with it (probe P8); not an edit.
  private var lastWritten: String?
  /// True while Dart's text is assigned: UIKit may call back synchronously.
  private var writing = false

  override init() {
    super.init()
    controller.searchResultsUpdater = self
    controller.delegate = self
    controller.searchBar.delegate = self
    controller.obscuresBackgroundDuringPresentation = false
    defaultPlaceholder = controller.searchBar.placeholder
    isComposing = { [weak self] in
      self?.controller.searchBar.searchTextField.markedTextRange != nil
    }
  }

  var text: String { controller.searchBar.text ?? "" }

  /// Dart's text: now, or once the composition ends.
  func setText(_ new: String) {
    if isComposing() {
      pendingText = new
      return
    }
    pendingText = nil
    guard new != text else { return }
    write(new)
  }

  /// Presents the search and focuses the field (research spike: the first
  /// responder must be asked on the next run-loop turn).
  func activate() {
    controller.isActive = true
    DispatchQueue.main.async { [weak self] in
      _ = self?.controller.searchBar.searchTextField.becomeFirstResponder()
    }
  }

  /// Dismisses the search and keeps the text: a dismissal Dart asked for
  /// (a dialog above, another tab) is not the user's ×.
  func dismissKeepingText() {
    guard controller.isActive else { return }
    keepOnDismiss = text
    controller.isActive = false
  }

  /// Debug builds: what UIKit does for a tap on × (clear, then dismiss).
  func debugCancel() {
    controller.searchBar.text = ""
    updateSearchResults(for: controller)
    controller.isActive = false
  }

  private func write(_ new: String) {
    writing = true
    lastWritten = new
    controller.searchBar.text = new
    writing = false
  }

  // MARK: UISearchResultsUpdating

  func updateSearchResults(for searchController: UISearchController) {
    let composing = isComposing()
    if !composing, let pending = pendingText {
      setText(pending)
      return
    }
    if writing || keepOnDismiss != nil { return }
    if let last = lastWritten {
      lastWritten = nil
      if last == text, !composing { return }
    }
    guard canReport() else { return }
    onText(text, composing)
  }

  // MARK: UISearchControllerDelegate

  func didPresentSearchController(_ searchController: UISearchController) {
    if canReport() { onActive(true) }
  }

  func didDismissSearchController(_ searchController: UISearchController) {
    if let kept = keepOnDismiss {
      keepOnDismiss = nil
      if kept != text { write(kept) }
    }
    // Always: inactive is idempotent on the Dart side.
    onActive(false)
  }

  // MARK: UISearchBarDelegate

  func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
    if canReport() { onSubmit(text) }
  }
}
```

- [ ] **Step 5: Add `ShellNavController.swift` (Task 5 extends it)**

```swift
import UIKit

/// The clear navigation controller of a tab with a native navigation bar
/// (spec P3b §7.1; P3b-1: the search tab). Its pages are clear
/// `PageHostController`s that mirror the tab's Flutter pages; the Flutter
/// view stays underneath and never moves.
@available(iOS 26.0, *)
final class ShellNavController: UINavigationController {
  /// iPhone, a page pushed inside the search tab: whether it hides the tab
  /// bar and the tab-hosted field (probe P2, Q19). Set from
  /// docs/qa/p3b/probe.md.
  static var hidesBarWhenPushed = false

  let rootHost: PageHostController

  init(root: PageHostController) {
    rootHost = root
    super.init(nibName: nil, bundle: nil)
    setViewControllers([root], animated: false)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    navigationBar.prefersLargeTitles = true
    // Q14: Flutter owns the swipe-back in P3b-1; the native bar follows
    // when the Flutter route commits (spec §7.6).
    interactivePopGestureRecognizer?.isEnabled = false
    interactiveContentPopGestureRecognizer?.isEnabled = false
  }
}

/// One clear page of a `ShellNavController`: a title for the native bar
/// over the Flutter page of the same depth. Reports layout to the shell as
/// `TabHostController` does.
@available(iOS 26.0, *)
final class PageHostController: UIViewController {
  private var shell: NativeTabsController? { tabBarController as? NativeTabsController }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    shell?.syncFlutter()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    shell?.syncFlutter()
  }

  override func viewSafeAreaInsetsDidChange() {
    super.viewSafeAreaInsetsDidChange()
    shell?.syncFlutter()
  }

  /// The search tab's root: host the search controller.
  func installSearch(_ bridge: SearchBridge, style: SearchTabStyle) {
    navigationItem.searchController = bridge.controller
    applySearchStyle(style)
  }

  func applySearchStyle(_ style: SearchTabStyle) {
    navigationItem.preferredSearchBarPlacement =
      style.placement == .stacked ? .stacked : .automatic
    if let hides = style.hidesWhenScrolling { navigationItem.hidesSearchBarWhenScrolling = hides }
    navigationItem.largeTitleDisplayMode = style.largeTitle ? .always : .never
  }
}
```

Set `hidesBarWhenPushed` to the value Task 1 decided (probe P2): `static var hidesBarWhenPushed = true` when the bottom field covered the pushed page, else leave `false`.

- [ ] **Step 6: Wire the search tab into `NativeTabsController`**

Add stored properties after `trailingTab`:

```swift
  /// The search destination (role search): UIKit's search tab, hosting the
  /// search field (spec P3b §7). nil without one.
  private(set) var searchTab: UISearchTab?
  /// Its index in Dart's destinations.
  private(set) var searchIndex: Int?
  /// Tabs with a native navigation bar, by destination index (P3b-1: the
  /// search tab only).
  private(set) var navControllers: [Int: ShellNavController] = [:]
  /// The search field and its delegates; one per shell, re-hosted when the
  /// tabs are rebuilt.
  let searchBridge = SearchBridge()
```

Change `private var structure: [Bool] = []` to `private var structure: [Int] = []` (0 fixed, 1 sidebar-only, 2 search; plus one trailing flag).

At the end of `init(flutter:events:)`:

```swift
    searchBridge.canReport = { [weak self] in
      guard let self, let searchTab = self.searchTab else { return false }
      return self.selectedTab === searchTab && !self.applyingFromDart
    }
    searchBridge.onText = { [weak self] text, composing in
      self?.send("onSearchTextChanged") {
        self?.events.onSearchTextChanged(text: text, composing: composing, completion: $0)
      }
    }
    searchBridge.onActive = { [weak self] active in
      self?.send("onSearchActiveChanged") {
        self?.events.onSearchActiveChanged(active: active, completion: $0)
      }
      self?.syncFlutter()
    }
    searchBridge.onSubmit = { [weak self] text in
      self?.send("onSearchSubmitted") { self?.events.onSearchSubmitted(text: text, completion: $0) }
    }
```

Replace `rebuildTabsIfNeeded` with:

```swift
  /// Creates the tabs when the structure changes; `showTabs` hands them to
  /// UIKit. A live `UITab` is never reused for a new controller (UIKit
  /// asserts): a structure change builds new tabs and controllers.
  private func rebuildTabsIfNeeded(_ new: NativeChromeConfig) {
    let wanted =
      new.tabs.map { $0.search ? 2 : ($0.sidebarOnly ? 1 : 0) } + [new.trailing != nil ? 1 : 0]
    guard wanted != structure else { return }
    structure = wanted
    searchTab = nil
    searchIndex = nil
    navControllers = [:]
    destinationTabs = new.tabs.enumerated().map { index, spec in
      if spec.search {
        let root = PageHostController()
        root.installSearch(searchBridge, style: searchStyle(rootLargeTitle: spec.pages.first?.largeTitle ?? nil))
        let nav = ShellNavController(root: root)
        navControllers[index] = nav
        let tab = UISearchTab { _ in nav }
        // The video's state 2: selecting search does not focus the field.
        tab.automaticallyActivatesSearch = false
        searchTab = tab
        searchIndex = index
        return tab
      }
      let tab = UITab(title: "", image: nil, identifier: "destination\(index)") { _ in
        TabHostController()
      }
      // `.fixed`: nothing to add, remove or reorder, so no sidebar "Edit".
      tab.preferredPlacement = spec.sidebarOnly ? .sidebarOnly : .fixed
      return tab
    }
    trailingTab = new.trailing.map { _ in
      // Pinned by default: the trailing end of the bar, the first sidebar row.
      UISearchTab { _ in TabHostController() }
    }
  }

  private func searchStyle(rootLargeTitle: Bool?) -> SearchTabStyle {
    SearchMath.style(
      isPad: traitCollection.userInterfaceIdiom == .pad,
      osMajor: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
      rootLargeTitle: rootLargeTitle)
  }

  /// Placeholder, placement and the iOS 27 prominent tab (spec §7.2).
  private func applySearch(_ new: NativeChromeConfig) {
    guard let searchIndex, new.tabs.indices.contains(searchIndex),
      let nav = navControllers[searchIndex]
    else { return }
    searchBridge.controller.searchBar.placeholder =
      new.search?.placeholder ?? searchBridge.defaultPlaceholder
    nav.rootHost.applySearchStyle(
      searchStyle(rootLargeTitle: new.tabs[searchIndex].pages.first?.largeTitle ?? nil))
    if #available(iOS 27.0, *) {
      let want = searchStyle(rootLargeTitle: nil).prominent ? searchTab?.identifier : nil
      if prominentTabIdentifier != want { prominentTabIdentifier = want }
    }
  }
```

In `apply(_:)`, replace the title/image loop with:

```swift
      for (tab, spec) in zip(destinationTabs, new.tabs) {
        tab.title = spec.title
        // A search tab without a symbol keeps the system's magnifying glass.
        tab.image = UIImage(
          systemName: spec.search && spec.sfSymbol.isEmpty ? "magnifyingglass" : spec.sfSymbol)
        tab.badgeValue = spec.badge
      }
```

and call `applySearch(new)` right after `showTabs(new)` and before `select(Int(new.selectedIndex))`.

In `showTabs(_:)`, replace the `let wanted = …` line with (the search tab is pinned like the trailing one: first in the array is the trailing end and the first sidebar row):

```swift
    let pinned = shown.filter { $0 === searchTab }
    let wanted = (trailingTab.map { [$0] } ?? []) + pinned + shown.filter { $0 !== searchTab }
```

Replace `select(_:)` with:

```swift
  /// Selects destination [index]. A sidebar-only one is left out of the
  /// compact bar: then the first shown ordinary destination, never the
  /// search or the trailing tab (their selection is a search state). Leaving
  /// an active search dismisses it and keeps its text (Q2).
  private func select(_ index: Int) {
    guard destinationTabs.indices.contains(index) else { return }
    let wanted = destinationTabs[index]
    let shown = tabs.contains { $0 === wanted }
    guard
      let tab = shown
        ? wanted : tabs.first(where: { $0 !== trailingTab && $0 !== searchTab }),
      selectedTab !== tab
    else { return }
    if selectedTab === searchTab { searchBridge.dismissKeepingText() }
    applyingFromDart = true
    selectedTab = tab
    applyingFromDart = false
  }
```

Replace the Task 3 stubs `setSearchText` and `setSearchActive` with:

```swift
  /// Dart's text (spec §7.4): applied outside a composition, never echoed.
  func setSearchText(_ text: String) {
    searchBridge.setText(text)
  }

  /// Dart's activate / deactivate. Activation needs the search tab
  /// selected; deactivation keeps the text.
  func setSearchActive(_ active: Bool) {
    if active {
      guard let searchTab, selectedTab === searchTab else { return }
      searchBridge.activate()
    } else {
      searchBridge.dismissKeepingText()
    }
  }
```

`send(_:onFailure:_:)` is `private`; the closures above call it from inside the class, which is allowed.

**Only if Task 1 decided "guarded flag: yes" (probe P1):** add `bool guarded` (required) to `NativeChromeConfig` in the Pigeon source, run `make pigeon`, send `guarded: widget.beforeDestinationChange != null` from `nativeConfigFor` (Task 6 adds the parameter), and at the top of `tabBarController(_:shouldSelectTab:)`:

```swift
    if let searchTab, tab === searchTab, config?.guarded == false {
      // No guard to ask (Q6 fallback): let UIKit run its own morph;
      // `didSelectTab` reports the selection to Dart.
      return true
    }
```

plus the XCTest `testWithoutAGuardTheSearchTabSelectsAtOnce` asserting `shouldSelectTab` returns true and `events.sent.last == "destination 2"` after `tabBarController(_:didSelectTab:previousTab:)`. Otherwise skip this paragraph.

- [ ] **Step 7: Run the XCTests on all four simulators**

Run, one after the other:

```bash
make ios-unit IOS_UNIT_DEVICE="$PHONE26"
make ios-unit IOS_UNIT_DEVICE="$PHONE27"
make ios-unit IOS_UNIT_DEVICE="$IPAD26"
make ios-unit IOS_UNIT_DEVICE="$IPAD27"
```

Expected: `** TEST SUCCEEDED **` on each. The prominent test is skipped on 26.x; P2's tests still pass.

- [ ] **Step 8: Commit**

```bash
bash .githooks/pre-commit
git add liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/SearchMath.swift \
  liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/SearchBridge.swift \
  liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/ShellNavController.swift \
  liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeTabsController.swift \
  liquid_shell/example/ios/RunnerTests/RunnerTests.swift
git commit -m "feat(ios): the search destination is UIKit's search tab with a native field (VK-407)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(If the guarded paragraph applied, also stage the Pigeon source and both generated files.)

---

### Task 5: Native pages, insets, field frame and hit testing

**Files:**
- Modify: `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/ShellNavController.swift`
- Modify: `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/SearchMath.swift`
- Modify: `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeTabsController.swift`
- Modify: `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/PassThroughView.swift`
- Test: `liquid_shell/example/ios/RunnerTests/RunnerTests.swift`

**Interfaces:**
- Consumes: Task 4 (`ShellNavController`, `PageHostController`, `searchBridge`, `navControllers`), Task 1's P2 and P6 values.
- Produces (P3b-2 consumes these names):
  - `ShellNavController.applyPages(_ pages: [NativePage], rootTitle: String, tabIndex: Int, events: NativeShellFlutterApiProtocol)`
  - `PageHostController`: `proxy: UIScrollView`, `setScrollOffset(_ offset: Double)`, `restingTop: CGFloat`, `flutterTop: CGFloat`, `rereadRestingTop(force:)`, `onBack: (() -> Void)?`
  - `SearchMath.heldTop(current:resting:scrolled:) -> CGFloat`, `SearchMath.frameChanged(_ old: NativeRect?, _ new: NativeRect) -> Bool`
  - `NativeTabsController`: `topHost(ofTab:) -> PageHostController?`, `selectedDestinationIndex: Int`, real `setPageScroll(tab:offset:)`, `publishSearchField()`, `currentFieldFrame() -> NativeRect`, real `debugSnapshot()`, `debugTap` for `.searchField`, `.searchCancel`, `.back`
  - `PassThroughView.isBackground(_ hit: UIView?, chainFrom top: UIView?, tabsView: UIView) -> Bool`

- [ ] **Step 1: Write the failing XCTests**

In `PassThroughTests`, replace the test body's calls `isBackground(x, selected: host, tabsView: tabsView)` with `isBackground(x, chainFrom: host, tabsView: tabsView)` (six calls, same expectations), and add:

```swift
  func testTheChainStartsAtANavigationControllersTopPage() {
    let tabsView = UIView()
    let navView = UIView()
    let transition = UIView()
    let wrapper = UIView()
    let top = UIView()
    let bar = UIView()
    tabsView.addSubview(navView)
    navView.addSubview(transition)
    transition.addSubview(wrapper)
    wrapper.addSubview(top)
    navView.addSubview(bar)
    for view in [top, wrapper, transition, navView, tabsView] {
      XCTAssertTrue(PassThroughView.isBackground(view, chainFrom: top, tabsView: tabsView))
    }
    XCTAssertFalse(
      PassThroughView.isBackground(bar, chainFrom: top, tabsView: tabsView),
      "the navigation bar stays with UIKit")
  }
```

Add to `SearchMathTests`:

```swift
  func testTheTopIsHeldOnlyWhileTheProxyIsScrolled() {
    XCTAssertEqual(SearchMath.heldTop(current: 116, resting: 168.7, scrolled: true), 168.7)
    XCTAssertEqual(SearchMath.heldTop(current: 116, resting: 168.7, scrolled: false), 116)
    XCTAssertEqual(SearchMath.heldTop(current: 172, resting: 168.7, scrolled: true), 172)
  }

  func testAFieldFrameChangeNeedsHalfAPoint() {
    let a = NativeRect(x: 8, y: 490, width: 330, height: 48)
    XCTAssertTrue(SearchMath.frameChanged(nil, a))
    XCTAssertFalse(SearchMath.frameChanged(a, NativeRect(x: 8.2, y: 490.4, width: 330, height: 48)))
    XCTAssertTrue(SearchMath.frameChanged(a, NativeRect(x: 8, y: 489, width: 330, height: 48)))
  }
```

Add to the `NativeTabsTests` search extension:

```swift
  private func titles(_ nav: ShellNavController) -> [String] {
    nav.viewControllers.map { $0.title ?? "" }
  }

  func testPagesArePushedAndPoppedWithTheirTitles() throws {
    let tabs = try installedSearchShell(selected: 2)
    let nav = try XCTUnwrap(tabs.navControllers[2])
    XCTAssertEqual(titles(nav), ["Find"], "no pages: the destination's label")
    tabs.apply(
      searchConfig(
        selected: 2,
        pages: [NativePage(title: "Search", largeTitle: nil), NativePage(title: "Hồ Hoàn Kiếm")]))
    settle()
    XCTAssertEqual(titles(nav), ["Search", "Hồ Hoàn Kiếm"])
    let top = try XCTUnwrap(nav.topViewController as? PageHostController)
    XCTAssertNotNil(top.navigationItem.backAction, "the back tap is a proposal")
    XCTAssertEqual(top.navigationItem.largeTitleDisplayMode, .never)
    XCTAssertEqual(top.hidesBottomBarWhenPushed, ShellNavController.hidesBarWhenPushed)
    tabs.apply(searchConfig(selected: 2, pages: [NativePage(title: "Search", largeTitle: nil)]))
    settle()
    XCTAssertEqual(titles(nav), ["Search"])
  }

  func testTheNativeBackButtonOnlyProposes() throws {
    let tabs = try installedSearchShell(
      selected: 2, pages: [NativePage(title: "Search"), NativePage(title: "Detail")])
    let nav = try XCTUnwrap(tabs.navControllers[2])
    let top = try XCTUnwrap(nav.topViewController as? PageHostController)
    top.onBack?()
    XCTAssertEqual(events.sent.last, "back 2")
    XCTAssertEqual(nav.viewControllers.count, 2, "Dart pops; native follows")
  }

  func testFlutterKeepsTheTabsFrameAndGetsTheTopPagesInsets() throws {
    let tabs = try installedSearchShell(
      selected: 2, pages: [NativePage(title: "Search"), NativePage(title: "Detail")])
    let root = try XCTUnwrap(tabs.parent?.view)
    let nav = try XCTUnwrap(tabs.navControllers[2])
    let top = try XCTUnwrap(nav.topViewController)
    XCTAssertEqual(tabs.flutter.view.frame, nav.view.convert(nav.view.bounds, to: root))
    XCTAssertEqual(
      tabs.flutter.view.safeAreaInsets.top, top.view.safeAreaInsets.top, accuracy: 0.5,
      "the native bar is Flutter's top padding")
  }

  func testTheProxyCollapsesTheLargeTitleWhileFlutterKeepsItsTop() throws {
    try requirePhone()
    let tabs = try installedSearchShell(selected: 2)
    let host = try XCTUnwrap(tabs.topHost(ofTab: 2))
    let restingFlutterTop = tabs.flutter.view.safeAreaInsets.top
    let restingHostTop = host.view.safeAreaInsets.top
    tabs.setPageScroll(tab: 2, offset: 400)
    settle()
    XCTAssertLessThan(host.view.safeAreaInsets.top, restingHostTop - 20, "the title collapsed")
    XCTAssertEqual(
      tabs.flutter.view.safeAreaInsets.top, restingFlutterTop, accuracy: 0.5,
      "held: Flutter's padding does not move under the finger")
    tabs.setPageScroll(tab: 2, offset: 0)
    settle()
    XCTAssertEqual(host.view.safeAreaInsets.top, restingHostTop, accuracy: 0.5)
  }

  func testTheFieldFrameIsPublishedInFlutterCoordinatesWhileSelected() throws {
    let tabs = try installedSearchShell(selected: 2)
    let frame = try XCTUnwrap(events.fieldFrames.last)
    XCTAssertGreaterThan(frame.width, 100, "the field is on screen")
    XCTAssertGreaterThan(frame.height, 30)
    tabs.apply(searchConfig(selected: 0))
    settle()
    XCTAssertEqual(events.fieldFrames.last?.width, 0, "not selected: zero")
  }

  func testWindowControlsAreZeroUnderTheSearchNavigationBar() throws {
    let tabs = try installedSearchShell(selected: 2, sizeClass: .compact)
    let windowed = NativeWindowControls(leading: 66, top: 44)
    tabs.readWindowControls = { _ in windowed }
    XCTAssertEqual(tabs.windowControls(), NativeWindowControls(leading: 0, top: 0))
    tabs.apply(searchConfig(selected: 0))
    settle()
    XCTAssertEqual(tabs.windowControls(), windowed, "Home has no native bar: the compact read")
  }

  func testInEveryPhaseTheFieldIsNativeAndTheBodyIsFlutters() throws {
    let tabs = try installedSearchShell(selected: 2)
    let root = try XCTUnwrap(tabs.parent?.view)
    func fieldCentre() throws -> CGPoint {
      let field = tabs.searchBridge.controller.searchBar.searchTextField
      XCTAssertNotNil(field.window, "the field is on screen")
      let frame = field.convert(field.bounds, to: root)
      return CGPoint(x: frame.midX, y: frame.midY)
    }
    // Selected.
    XCTAssertTrue(isNative(try hit(tabs, try fieldCentre()), tabs), "selected: the field")
    XCTAssertTrue(
      try hit(tabs, CGPoint(x: root.bounds.midX, y: root.bounds.midY)) === tabs.flutter.view,
      "selected: the body")
    // Active.
    tabs.setSearchActive(true)
    settle()
    XCTAssertTrue(isNative(try hit(tabs, try fieldCentre()), tabs), "active: the field")
    let body = CGPoint(x: root.bounds.midX, y: root.bounds.height * 0.35)
    XCTAssertTrue(try hit(tabs, body) === tabs.flutter.view, "active: the body")
    // Inert under a dialog.
    tabs.apply(searchConfig(selected: 2, interactive: false))
    XCTAssertTrue(try hit(tabs, try fieldCentre()) === tabs.flutter.view, "inert")
  }

  func testAPushedPagesBackButtonIsNative() throws {
    let tabs = try installedSearchShell(
      selected: 2, pages: [NativePage(title: "Search"), NativePage(title: "Detail")])
    let root = try XCTUnwrap(tabs.parent?.view)
    let bar = try XCTUnwrap(tabs.navControllers[2]).navigationBar
    let frame = bar.convert(bar.bounds, to: root)
    XCTAssertTrue(isNative(try hit(tabs, CGPoint(x: frame.minX + 38, y: frame.midY)), tabs))
  }

  func testTheDebugSnapshotDescribesTheSearchTab() throws {
    let tabs = try installedSearchShell(
      selected: 2, pages: [NativePage(title: "Search"), NativePage(title: "Detail")])
    tabs.setSearchText("ho")
    let snapshot = tabs.debugSnapshot()
    XCTAssertEqual(snapshot.selectedTab, "destination2")
    XCTAssertEqual(snapshot.searchText, "ho")
    XCTAssertEqual(snapshot.pageTitles, ["Search", "Detail"])
    if UIDevice.current.userInterfaceIdiom == .pad {
      XCTAssertEqual(snapshot.placement, "stacked")
    }
    XCTAssertFalse(snapshot.searchActive)
  }
```

- [ ] **Step 2: Run them to see them fail**

Run: `make ios-unit IOS_UNIT_DEVICE="$PHONE27"`
Expected: build failure: `extra argument 'chainFrom'`, `value of type 'PageHostController' has no member 'onBack'`, `SearchMath has no member 'heldTop'`.

- [ ] **Step 3: Pure helpers**

Append to the `SearchMath` enum:

```swift
  /// Flutter's top inset while a page's proxy scroll view is scrolled: the
  /// resting value, so the padding does not shrink as the large title
  /// collapses (spec §7.7). At rest: the current value.
  static func heldTop(current: CGFloat, resting: CGFloat, scrolled: Bool) -> CGFloat {
    scrolled ? max(current, resting) : current
  }

  /// Whether a field frame moved enough to send (≥ 0.5pt on any edge).
  static func frameChanged(_ old: NativeRect?, _ new: NativeRect) -> Bool {
    guard let old else { return true }
    return abs(old.x - new.x) >= 0.5 || abs(old.y - new.y) >= 0.5
      || abs(old.width - new.width) >= 0.5 || abs(old.height - new.height) >= 0.5
  }
```

Add `import UIKit` at the top of `SearchMath.swift` (for `CGFloat`; the file stays free of UIKit views).

- [ ] **Step 4: Pages, proxy and back in `ShellNavController.swift`**

Add to `ShellNavController`:

```swift
  /// Mirrors the tab's Flutter pages (spec §7.6): push for a longer stack,
  /// pop for a shorter one, retitle in place. The root's title is the first
  /// page's, or the destination's label without pages. Each pushed page's
  /// back button only proposes (`onBackTapped`); Dart pops the Flutter
  /// route and the next stack pops here.
  func applyPages(
    _ pages: [NativePage], rootTitle: String, tabIndex: Int,
    events: NativeShellFlutterApiProtocol
  ) {
    let wanted = pages.isEmpty ? [NativePage(title: rootTitle, largeTitle: nil)] : pages
    rootHost.title = wanted[0].title
    var hosts = viewControllers.compactMap { $0 as? PageHostController }
    if hosts.count > wanted.count { hosts = Array(hosts.prefix(wanted.count)) }
    while hosts.count < wanted.count {
      let host = PageHostController()
      host.hidesBottomBarWhenPushed = Self.hidesBarWhenPushed
      host.onBack = {
        events.onBackTapped(tab: Int64(tabIndex)) { result in
          #if DEBUG
            if case .failure(let error) = result {
              NSLog("[liquid_shell] sending onBackTapped to Dart failed: %@", String(describing: error))
            }
          #endif
        }
      }
      hosts.append(host)
    }
    for (host, page) in zip(hosts, wanted).dropFirst() {
      host.title = page.title
      host.navigationItem.largeTitleDisplayMode = (page.largeTitle ?? false) ? .always : .never
    }
    guard hosts.map(ObjectIdentifier.init) != viewControllers.map(ObjectIdentifier.init) else {
      return
    }
    let animated = viewIfLoaded?.window != nil && !UIAccessibility.isReduceMotionEnabled
    setViewControllers(hosts, animated: animated)
  }
```

Add to `PageHostController`:

```swift
  /// Invisible scroll view UIKit reads for the large title's collapse and
  /// the scroll-edge effect, moved by code from Flutter's scroll offset
  /// (spec §7.7; research §4.1).
  let proxy = UIScrollView()
  /// The top safe-area inset with the proxy at rest.
  private(set) var restingTop: CGFloat = 0
  private var offset: Double = 0
  /// The native back button's proposal (set for pushed pages).
  var onBack: (() -> Void)? {
    didSet {
      navigationItem.backAction = onBack.map { back in UIAction { _ in back() } }
    }
  }

  /// Flutter's top inset for this page: held while scrolled.
  var flutterTop: CGFloat {
    SearchMath.heldTop(current: view.safeAreaInsets.top, resting: restingTop, scrolled: offset > 0)
  }

  func setScrollOffset(_ value: Double) {
    loadViewIfNeeded()
    offset = max(0, value)
    proxy.contentOffset.y = -proxy.adjustedContentInset.top + CGFloat(offset)
  }

  /// Re-reads the resting top: at rest, or always with [force] (a search
  /// activation hides the large title on purpose; that is not a scroll).
  func rereadRestingTop(force: Bool = false) {
    if force || offset <= 0 { restingTop = view.safeAreaInsets.top }
  }
```

Replace `PageHostController.viewDidLoad` and `viewSafeAreaInsetsDidChange` with:

```swift
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    proxy.frame = view.bounds
    proxy.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    proxy.isUserInteractionEnabled = false
    proxy.backgroundColor = .clear
    proxy.showsVerticalScrollIndicator = false
    proxy.contentInsetAdjustmentBehavior = .always
    proxy.contentSize = CGSize(width: 1, height: 100_000)
    view.addSubview(proxy)
    setContentScrollView(proxy, for: .top)
  }

  override func viewSafeAreaInsetsDidChange() {
    super.viewSafeAreaInsetsDidChange()
    rereadRestingTop()
    shell?.syncFlutter()
  }
```

- [ ] **Step 5: `NativeTabsController`: pages, insets, field frame, window controls, debug**

In `apply(_:)`, right after `applySearch(new)`:

```swift
      for (index, nav) in navControllers where new.tabs.indices.contains(index) {
        nav.applyPages(
          new.tabs[index].pages, rootTitle: new.tabs[index].title, tabIndex: index, events: events)
      }
```

Add:

```swift
  /// The top page of tab [index], when it has a native navigation bar.
  func topHost(ofTab index: Int) -> PageHostController? {
    navControllers[index]?.topViewController as? PageHostController
  }

  private var selectedHasNavigationBar: Bool { selectedViewController is ShellNavController }

  /// The selected destination's index in Dart's list (0 when none is).
  var selectedDestinationIndex: Int {
    destinationTabs.firstIndex { $0 === selectedTab } ?? 0
  }
```

Replace the stub `setPageScroll` with:

```swift
  /// The top page's scroll offset (proxy, spec §7.7).
  func setPageScroll(tab: Int, offset: Double) {
    guard offset.isFinite, let host = topHost(ofTab: tab) else { return }
    host.setScrollOffset(offset)
    syncFlutter()
  }
```

In `syncFlutter()`, replace `var want = ShellInsets(host.view.safeAreaInsets)` with:

```swift
      // A navigation controller's top page carries the bar, the large title
      // and the stacked field in its safe area; its frame slides during a
      // push, so the frame above stays the tab's (spec §7.9).
      let page = (host as? UINavigationController)?.topViewController
      var want = ShellInsets(page?.viewIfLoaded?.safeAreaInsets ?? host.view.safeAreaInsets)
      if let page = page as? PageHostController, page.isViewLoaded {
        want.top = Double(page.flutterTop)
      }
```

and add `publishSearchField()` after `publishWindowControls()` at the end of `syncFlutter()`.

In `windowControls()`, replace the first line with:

```swift
    if chromeVisible, !isCompact || selectedHasNavigationBar {
      return NativeWindowControls(leading: 0, top: 0)
    }
```

Change the `searchBridge.onActive` closure set in `init` (Task 4) so a search activation re-reads the resting top:

```swift
    searchBridge.onActive = { [weak self] active in
      self?.send("onSearchActiveChanged") {
        self?.events.onSearchActiveChanged(active: active, completion: $0)
      }
      if let self, let index = self.searchIndex { self.topHost(ofTab: index)?.rereadRestingTop(force: true) }
      self?.syncFlutter()
    }
```

Add the field frame publisher and the keyboard observers:

```swift
  private var lastField: NativeRect?
  private var keyboardObservers: [NSObjectProtocol] = []

  /// The search field's frame in the Flutter view, or zero when the search
  /// tab is not selected or the field is not shown (spec §7.5).
  func currentFieldFrame() -> NativeRect {
    let zero = NativeRect(x: 0, y: 0, width: 0, height: 0)
    let field = searchBridge.controller.searchBar.searchTextField
    guard chromeVisible, let searchTab, selectedTab === searchTab, field.window != nil,
      let flutterView = flutter.viewIfLoaded
    else { return zero }
    var node: UIView? = field
    while let current = node {
      if current.isHidden || current.alpha < 0.01 { return zero }
      node = current.superview
    }
    let frame = field.convert(field.bounds, to: flutterView)
    return NativeRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height)
  }

  func publishSearchField() {
    guard dartAttached, searchTab != nil else { return }
    let frame = currentFieldFrame()
    guard SearchMath.frameChanged(lastField, frame) else { return }
    lastField = frame
    send("onSearchFieldChanged", onFailure: { [weak self] in self?.lastField = nil }) {
      self.events.onSearchFieldChanged(frame: frame, completion: $0)
    }
  }
```

In `viewDidLoad()`, after `footer.onTap = …`:

```swift
    // The iPhone field rides on the keyboard: publish its end position.
    for name in [
      UIResponder.keyboardDidChangeFrameNotification, UIResponder.keyboardDidHideNotification,
    ] {
      keyboardObservers.append(
        NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
          [weak self] _ in self?.publishSearchField()
        })
    }
```

and add:

```swift
  deinit {
    for observer in keyboardObservers { NotificationCenter.default.removeObserver(observer) }
  }
```

Replace the `debugTap` switch's `case .searchField, .searchCancel, .back: break` with:

```swift
      case .searchField:
        // A tap on the field: UIKit presents the search and reports it.
        guard let searchTab, selectedTab === searchTab else { return }
        searchBridge.activate()
      case .searchCancel:
        searchBridge.debugCancel()
      case .back:
        topHost(ofTab: index)?.onBack?()
```

Replace the stub `debugSnapshot()` with:

```swift
  /// Debug builds: the native search and page state (integration tests).
  func debugSnapshot() -> NativeDebugSnapshot {
    #if DEBUG
      let selected = selectedTab.flatMap { tab in destinationTabs.firstIndex { $0 === tab } }
      let nav = searchIndex.flatMap { navControllers[$0] }
      let placement: String
      switch nav?.rootHost.navigationItem.searchBarPlacement {
      case .stacked?: placement = "stacked"
      case .inline?: placement = "inline"
      case .integrated?: placement = "integrated"
      case .integratedCentered?: placement = "integratedCentered"
      case .integratedButton?: placement = "integratedButton"
      default: placement = ""
      }
      return NativeDebugSnapshot(
        selectedTab: selected.map { "destination\($0)" } ?? "",
        searchActive: searchBridge.controller.isActive,
        searchText: searchBridge.text,
        placement: placement,
        pageTitles: nav?.viewControllers.map { $0.title ?? "" } ?? [],
        fieldFrame: currentFieldFrame(),
        firstResponderIsSearch: searchBridge.controller.searchBar.searchTextField.isFirstResponder)
    #else
      return .empty
    #endif
  }
```

- [ ] **Step 6: The chain rule in `PassThroughView.swift`**

Replace the hit test's `guard Self.isBackground(…)` and the static function with:

```swift
    let selected = shell.selectedViewController
    // A tab with a navigation bar: the chain starts at its top page, so the
    // bar, the back button and the search field stay with UIKit (spec P3b
    // §7.8).
    let top = (selected as? UINavigationController)?.topViewController?.viewIfLoaded
      ?? selected?.viewIfLoaded
    guard Self.isBackground(hit, chainFrom: top, tabsView: tabsView) else { return hit }
```

```swift
  /// nil (chrome hidden, not interactive, or fully transparent), the tab bar
  /// controller's own view, or a view on the chain from [top] (the selected
  /// tab's view, or its navigation controller's top page) up to it.
  static func isBackground(_ hit: UIView?, chainFrom top: UIView?, tabsView: UIView) -> Bool {
    guard let hit else { return true }
    if hit === tabsView { return true }
    var node = top
    while let current = node {
      if current === hit { return true }
      if current === tabsView { break }
      node = current.superview
    }
    return false
  }
```

Update the class comment's "Tracked debt" paragraph: "background means the selected tab's host view, or its navigation controller's top page, and every ancestor up to and including the tab bar controller's view."

- [ ] **Step 7: Run the XCTests on all four simulators**

```bash
make ios-unit IOS_UNIT_DEVICE="$PHONE26"
make ios-unit IOS_UNIT_DEVICE="$PHONE27"
make ios-unit IOS_UNIT_DEVICE="$IPAD26"
make ios-unit IOS_UNIT_DEVICE="$IPAD27"
```

Expected: `** TEST SUCCEEDED **` on each. If a value differs from Task 1's P6 table (for example the active field frame), the test is wrong only if it asserted a measured constant; these tests assert relations, not constants.

- [ ] **Step 8: Commit**

```bash
bash .githooks/pre-commit
git add liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/ShellNavController.swift \
  liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/SearchMath.swift \
  liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeTabsController.swift \
  liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/PassThroughView.swift \
  liquid_shell/example/ios/RunnerTests/RunnerTests.swift
git commit -m "feat(ios): native page stack, glass back and field insets in the search tab (VK-407)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Dart search API: role, controller, value, phase, `LiquidSearch`

**Files:**
- Modify: `liquid_shell/lib/src/destinations/destination.dart`
- Create: `liquid_shell/lib/src/search/search_controller.dart`
- Create: `liquid_shell/lib/src/search/search.dart`
- Create: `liquid_shell/lib/src/search/search_layout.dart`
- Modify: `liquid_shell/lib/src/native/native_layout.dart`
- Modify: `liquid_shell/lib/src/shell/liquid_shell.dart` (parameter, asserts, the `nativeConfigFor` call)
- Modify: `liquid_shell/lib/src/shell/strings.dart`
- Modify: `liquid_shell/lib/liquid_shell.dart`
- Test: `liquid_shell/test/unit/search_test.dart` (new), `liquid_shell/test/unit/native_layout_test.dart`, `liquid_shell/test/unit/destinations_test.dart`, `liquid_shell/test/widget/search_asserts_test.dart` (new)

**Interfaces:**
- Consumes: Task 2 (`LiquidNativeTab.search/pages`, `LiquidNativeSearchConfig`, `LiquidNativePage`).
- Produces:
  - `enum LiquidDestinationRole { standard, search }`; `LiquidDestination.role` (default `standard`, in `==`)
  - `enum LiquidSearchPhase { idle, selected, active }`; `class LiquidSearchValue` (`text`, `composing`, `active`, `scopeIndex`, `copyWith`, `empty`); `class LiquidSearchController extends ValueNotifier<LiquidSearchValue>` (`text` get/set, `isActive`, `scopeIndex` get/set, `activate()`, `deactivate()`, `clear()`)
  - library-internal (not exported): `abstract interface class SearchDriver { void activate(); void deactivate(); void textSetByApp(String text); }`, `void attachSearchDriver(LiquidSearchController, SearchDriver)`, `void detachSearchDriver(LiquidSearchController, SearchDriver)`, `void applySearchEdit(LiquidSearchController, LiquidSearchValue)`
  - `class LiquidSearch { controller, placeholder, onChanged, onSubmitted }`; `LiquidShell.search`
  - `search_layout.dart`: `int? searchIndexOf(List<LiquidDestination>)`, `LiquidSearchPhase searchPhaseFor({required int selected, required int? searchIndex, required bool active})`, `double nativeSearchBottomInset({required Rect field, required Size size, required EdgeInsets padding, required EdgeInsets viewInsets, required bool active})`, `const double kSearchFieldGap = 8`
  - `native_layout.dart`: `nativeDescribable` accepts a symbol-less search destination; `nativeConfigFor(…, String? searchPlaceholder, Map<int, List<LiquidNativePage>> pageStacks = const {})`; `bool nativePageBarFor({required bool engaged, required int selected, required int? searchIndex})`
  - `LiquidShellStrings.searchPlaceholder` (`'Search'`), `.cancelSearch` (`'Cancel search'`), `.back` (`'Back'`)

- [ ] **Step 1: Write the failing unit tests**

`liquid_shell/test/unit/search_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/search/search_controller.dart';
import 'package:liquid_shell/src/search/search_layout.dart';

class _Driver implements SearchDriver {
  final calls = <String>[];

  @override
  void activate() => calls.add('activate');

  @override
  void deactivate() => calls.add('deactivate');

  @override
  void textSetByApp(String text) => calls.add('text $text');
}

void main() {
  group('LiquidSearchValue', () {
    test('compares field by field and copies', () {
      const value = LiquidSearchValue(text: 'hồ', composing: true);
      expect(value, const LiquidSearchValue(text: 'hồ', composing: true));
      expect(value, isNot(const LiquidSearchValue(text: 'hồ')));
      expect(value.copyWith(active: true).active, isTrue);
      expect(value.copyWith(scopeIndex: 2).text, 'hồ');
      expect(LiquidSearchValue.empty, const LiquidSearchValue());
      expect(
        value.toString(),
        'LiquidSearchValue(text: hồ, composing: true, active: false, '
        'scopeIndex: 0)',
      );
    });
  });

  group('LiquidSearchController', () {
    test('the app sets the text: listeners hear it and the driver sends it', () {
      final controller = LiquidSearchController(text: 'a');
      addTearDown(controller.dispose);
      final driver = _Driver();
      attachSearchDriver(controller, driver);
      var heard = 0;
      controller.addListener(() => heard++);
      controller.text = 'ab';
      expect(controller.text, 'ab');
      expect(heard, 1);
      expect(driver.calls, ['text ab']);
      controller.text = 'ab';
      expect(heard, 1, reason: 'same text: nothing');
      controller.clear();
      expect(driver.calls, ['text ab', 'text ']);
    });

    test('commands reach the driver; without one they do nothing', () {
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      controller
        ..activate()
        ..deactivate();
      final driver = _Driver();
      attachSearchDriver(controller, driver);
      controller
        ..activate()
        ..deactivate();
      expect(driver.calls, ['activate', 'deactivate']);
      detachSearchDriver(controller, driver);
      controller.activate();
      expect(driver.calls, ['activate', 'deactivate']);
    });

    test('a platform edit changes the value without reaching the driver', () {
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      final driver = _Driver();
      attachSearchDriver(controller, driver);
      applySearchEdit(
        controller,
        const LiquidSearchValue(text: 'hô', composing: true, active: true),
      );
      expect(controller.value.composing, isTrue);
      expect(controller.isActive, isTrue);
      expect(driver.calls, isEmpty);
    });

    test('scopeIndex notifies', () {
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      var heard = 0;
      controller
        ..addListener(() => heard++)
        ..scopeIndex = 1;
      expect(controller.scopeIndex, 1);
      expect(heard, 1);
    });

    test('a second driver asserts', () {
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      attachSearchDriver(controller, _Driver());
      expect(
        () => attachSearchDriver(controller, _Driver()),
        throwsAssertionError,
      );
    });
  });

  group('LiquidSearch', () {
    test('compares field by field', () {
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      void submitted(String _) {}
      expect(
        LiquidSearch(controller: controller, placeholder: 'x', onSubmitted: submitted),
        LiquidSearch(controller: controller, placeholder: 'x', onSubmitted: submitted),
      );
      expect(
        LiquidSearch(controller: controller),
        isNot(LiquidSearch(controller: controller, placeholder: 'x')),
      );
    });
  });

  group('layout', () {
    const search = LiquidDestination(
      icon: Icon(Icons.search),
      label: 'Search',
      role: LiquidDestinationRole.search,
    );
    const home = LiquidDestination(icon: Icon(Icons.home), label: 'Home');

    test('searchIndexOf finds the first search destination', () {
      expect(searchIndexOf(const [home]), isNull);
      expect(searchIndexOf(const [home, search]), 1);
    });

    test('searchPhaseFor', () {
      expect(
        searchPhaseFor(selected: 0, searchIndex: 1, active: true),
        LiquidSearchPhase.idle,
      );
      expect(
        searchPhaseFor(selected: 1, searchIndex: 1, active: false),
        LiquidSearchPhase.selected,
      );
      expect(
        searchPhaseFor(selected: 1, searchIndex: 1, active: true),
        LiquidSearchPhase.active,
      );
      expect(
        searchPhaseFor(selected: 0, searchIndex: null, active: false),
        LiquidSearchPhase.idle,
      );
    });

    group('nativeSearchBottomInset', () {
      const size = Size(402, 874);
      const padding = EdgeInsets.only(top: 62, bottom: 83);

      test('no field, or a field at the top: nothing', () {
        expect(
          nativeSearchBottomInset(
            field: Rect.zero,
            size: size,
            padding: padding,
            viewInsets: EdgeInsets.zero,
            active: true,
          ),
          0,
        );
        expect(
          nativeSearchBottomInset(
            field: const Rect.fromLTWH(20, 86, 780, 44),
            size: size,
            padding: padding,
            viewInsets: EdgeInsets.zero,
            active: true,
          ),
          0,
        );
      });

      test('selected (field in the tab bar area): the bottom padding', () {
        expect(
          nativeSearchBottomInset(
            field: const Rect.fromLTWH(88, 798, 286, 48),
            size: size,
            padding: padding,
            viewInsets: EdgeInsets.zero,
            active: false,
          ),
          83,
        );
      });

      test('active above the keyboard: down to the field top or the keyboard', () {
        // Settled: keyboard 328, field 8pt above it at y 490:
        // max(874 − 490, 328 + 48 + 16) = 392.
        expect(
          nativeSearchBottomInset(
            field: const Rect.fromLTWH(8, 490, 330, 48),
            size: size,
            padding: EdgeInsets.zero,
            viewInsets: const EdgeInsets.only(bottom: 328),
            active: true,
          ),
          392,
        );
        // Keyboard still rising (Flutter's insets animate first): the
        // keyboard-based term leads: max(874 − 798, 200 + 48 + 16) = 264.
        expect(
          nativeSearchBottomInset(
            field: const Rect.fromLTWH(88, 798, 286, 48),
            size: size,
            padding: EdgeInsets.zero,
            viewInsets: const EdgeInsets.only(bottom: 200),
            active: true,
          ),
          264,
        );
      });
    });
  });
}
```

Append to `liquid_shell/test/unit/native_layout_test.dart` (inside `main()`):

```dart
  group('P3b search', () {
    const search = LiquidDestination(
      icon: Icon(Icons.search),
      label: 'Find',
      role: LiquidDestinationRole.search,
    );
    const home = LiquidDestination(
      icon: Icon(Icons.home),
      label: 'Home',
      sfSymbol: 'house',
    );

    test('a search destination needs no symbol', () {
      expect(nativeDescribable(const [home, search], null), isTrue);
    });

    test('nativeConfigFor marks the search tab and carries pages', () {
      final config = nativeConfigFor(
        engaged: true,
        destinations: const [home, search],
        selectedIndex: 1,
        trailing: null,
        footer: null,
        tint: const Color(0xFF3D5AFE),
        dark: false,
        rtl: false,
        hidden: false,
        interactive: true,
        searchPlaceholder: 'Songs, places',
        pageStacks: const {
          1: [LiquidNativePage(title: 'Search'), LiquidNativePage(title: 'Hồ')],
        },
      );
      expect(config.tabs.map((t) => t.search), [false, true]);
      expect(config.tabs.first.pages, isEmpty);
      expect(config.tabs.last.pages.map((p) => p.title), ['Search', 'Hồ']);
      expect(config.search?.placeholder, 'Songs, places');
    });

    test('no search destination: no search config', () {
      final config = nativeConfigFor(
        engaged: true,
        destinations: const [home],
        selectedIndex: 0,
        trailing: null,
        footer: null,
        tint: const Color(0xFF3D5AFE),
        dark: false,
        rtl: false,
        hidden: false,
        interactive: true,
        searchPlaceholder: 'ignored',
      );
      expect(config.search, isNull);
    });

    test('nativePageBarFor: the search tab only, while engaged (P3b-1)', () {
      expect(nativePageBarFor(engaged: true, selected: 1, searchIndex: 1), isTrue);
      expect(nativePageBarFor(engaged: true, selected: 0, searchIndex: 1), isFalse);
      expect(nativePageBarFor(engaged: false, selected: 1, searchIndex: 1), isFalse);
      expect(nativePageBarFor(engaged: true, selected: 0, searchIndex: null), isFalse);
    });
  });
```

Append to `liquid_shell/test/unit/destinations_test.dart` (inside `main()`):

```dart
  test('role joins == and defaults to standard', () {
    const icon = Icon(Icons.search);
    expect(
      const LiquidDestination(icon: icon, label: 'S').role,
      LiquidDestinationRole.standard,
    );
    expect(
      const LiquidDestination(icon: icon, label: 'S'),
      isNot(
        const LiquidDestination(
          icon: icon,
          label: 'S',
          role: LiquidDestinationRole.search,
        ),
      ),
    );
  });
```

`liquid_shell/test/widget/search_asserts_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';

import '../helpers/shell_harness.dart';

const _home = LiquidDestination(icon: Icon(Icons.home), label: 'Home');
const _search = LiquidDestination(
  icon: Icon(Icons.search),
  label: 'Search',
  role: LiquidDestinationRole.search,
);

Future<Object?> _errorOf(
  WidgetTester tester,
  List<LiquidDestination> destinations, {
  bool withSearch = true,
  LiquidTabAction? trailing,
}) async {
  final controller = LiquidSearchController();
  addTearDown(controller.dispose);
  await pumpShell(
    tester,
    LiquidShell(
      destinations: destinations,
      selectedIndex: 0,
      onDestinationSelected: (_) {},
      tabBarTrailing: trailing,
      search: withSearch ? LiquidSearch(controller: controller) : null,
      body: const SizedBox(),
    ),
    settle: false,
  );
  return tester.takeException();
}

void main() {
  testWidgets('one search destination, last, with LiquidShell.search: fine', (
    tester,
  ) async {
    expect(await _errorOf(tester, const [_home, _search]), isNull);
  });

  testWidgets('two search destinations assert', (tester) async {
    final error = await _errorOf(tester, const [
      _home,
      LiquidDestination(
        icon: Icon(Icons.search),
        label: 'Find',
        role: LiquidDestinationRole.search,
      ),
      _search,
    ]);
    expect('$error', contains('one search destination'));
  });

  testWidgets('a search destination that is not last asserts', (tester) async {
    final error = await _errorOf(tester, const [_search, _home]);
    expect('$error', contains('must be the last'));
  });

  testWidgets('a sidebar-only search destination asserts', (tester) async {
    final error = await _errorOf(tester, const [
      _home,
      LiquidDestination(
        icon: Icon(Icons.search),
        label: 'Search',
        role: LiquidDestinationRole.search,
        placement: LiquidPlacement.sidebarOnly,
      ),
    ]);
    expect('$error', contains('placed everywhere'));
  });

  testWidgets('a search destination without LiquidShell.search asserts', (
    tester,
  ) async {
    final error = await _errorOf(
      tester,
      const [_home, _search],
      withSearch: false,
    );
    expect('$error', contains('needs LiquidShell.search'));
  });

  testWidgets('LiquidShell.search without a search destination asserts', (
    tester,
  ) async {
    final error = await _errorOf(tester, const [_home]);
    expect('$error', contains('LiquidDestinationRole.search'));
  });

  testWidgets('a search destination with tabBarTrailing asserts', (
    tester,
  ) async {
    final error = await _errorOf(
      tester,
      const [_home, _search],
      trailing: LiquidTabAction(
        icon: const Icon(Icons.edit),
        semanticLabel: 'Compose',
        onPressed: () {},
      ),
    );
    expect('$error', contains('no tabBarTrailing'));
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `cd liquid_shell && fvm flutter test test/unit/search_test.dart test/unit/native_layout_test.dart test/unit/destinations_test.dart test/widget/search_asserts_test.dart`
Expected: compile errors: `LiquidDestinationRole`, `LiquidSearchController`, `searchPhaseFor`, `nativePageBarFor` undefined; `search` is not a parameter of `LiquidShell`.

- [ ] **Step 3: The role**

In `destination.dart`, add before `class LiquidDestination`:

```dart
/// What a destination is.
enum LiquidDestinationRole {
  /// An ordinary destination.
  standard,

  /// The search tab: at most one per shell, the last destination, placed
  /// everywhere, with `LiquidShell.search`. Its page is the app's search
  /// page; selecting it never pushes a page. Natively it is UIKit's search
  /// tab, and [LiquidDestination.sfSymbol] is optional.
  search,
}
```

Add `this.role = LiquidDestinationRole.standard,` to the constructor, the field

```dart
  /// Standard, or the search tab.
  final LiquidDestinationRole role;
```

`other.role == role &&` in `==`, and `role` in `hashCode`:

```dart
  @override
  int get hashCode =>
      Object.hash(icon, selectedIcon, label, badge, placement, sfSymbol, role);
```

- [ ] **Step 4: Controller, value, phase**

`liquid_shell/lib/src/search/search_controller.dart`:

```dart
import 'package:flutter/foundation.dart';

/// Where the search is (spec P3b §3.1).
enum LiquidSearchPhase {
  /// Another tab is selected.
  idle,

  /// The search tab is selected; the field has no focus.
  selected,

  /// The field has focus.
  active,
}

/// The search field's state.
@immutable
class LiquidSearchValue {
  /// Creates a value.
  const LiquidSearchValue({
    this.text = '',
    this.composing = false,
    this.active = false,
    this.scopeIndex = 0,
  });

  /// No text, not active, the first scope.
  static const empty = LiquidSearchValue();

  /// The field's text, IME composition included.
  final String text;

  /// An IME composition (Vietnamese Telex, Japanese kana) is in progress:
  /// [text] may still change. Filter on it if you like; never write it back.
  final bool composing;

  /// The field has focus.
  final bool active;

  /// Index into the app's scope titles (`LiquidSearchScopeBar`).
  final int scopeIndex;

  /// A copy with the given fields replaced.
  LiquidSearchValue copyWith({
    String? text,
    bool? composing,
    bool? active,
    int? scopeIndex,
  }) => LiquidSearchValue(
    text: text ?? this.text,
    composing: composing ?? this.composing,
    active: active ?? this.active,
    scopeIndex: scopeIndex ?? this.scopeIndex,
  );

  @override
  bool operator ==(Object other) =>
      other is LiquidSearchValue &&
      other.text == text &&
      other.composing == composing &&
      other.active == active &&
      other.scopeIndex == scopeIndex;

  @override
  int get hashCode => Object.hash(text, composing, active, scopeIndex);

  @override
  String toString() =>
      'LiquidSearchValue(text: $text, composing: $composing, active: $active, '
      'scopeIndex: $scopeIndex)';
}

/// What a shell does for the controller's commands. Internal: the barrel
/// does not export it.
abstract interface class SearchDriver {
  /// Focus the field.
  void activate();

  /// Unfocus the field, keep the text.
  void deactivate();

  /// The app replaced the text.
  void textSetByApp(String text);
}

/// The search query as a [ValueListenable] (Flutter's stream of values),
/// plus commands for the shell's field (spec P3b §4.3). Owned by the app,
/// so the query outlives tab switches.
class LiquidSearchController extends ValueNotifier<LiquidSearchValue> {
  /// Creates a controller.
  LiquidSearchController({String text = '', int scopeIndex = 0})
    : super(LiquidSearchValue(text: text, scopeIndex: scopeIndex));

  SearchDriver? _driver;

  /// The field's text.
  String get text => value.text;

  /// Replaces the text. The field shows it (natively once no IME
  /// composition is in progress). Does not call `LiquidSearch.onChanged`.
  set text(String text) {
    if (text == value.text && !value.composing) return;
    value = value.copyWith(text: text, composing: false);
    _driver?.textSetByApp(text);
  }

  /// Whether the field has focus.
  bool get isActive => value.active;

  /// The selected scope.
  int get scopeIndex => value.scopeIndex;

  set scopeIndex(int index) => value = value.copyWith(scopeIndex: index);

  /// Focuses the field. Only while the search tab is selected; otherwise
  /// the shell ignores it (one debug line).
  void activate() => _driver?.activate();

  /// Unfocuses the field and keeps the text (unlike ×).
  void deactivate() => _driver?.deactivate();

  /// Empties the text; keeps the focus.
  void clear() => text = '';
}

/// Attaches the shell that shows [controller]. One at a time.
void attachSearchDriver(LiquidSearchController controller, SearchDriver driver) {
  assert(
    controller._driver == null || identical(controller._driver, driver),
    'A LiquidSearchController is attached to one LiquidShell at a time.',
  );
  controller._driver = driver;
}

/// Detaches [driver] if it is the attached one.
void detachSearchDriver(LiquidSearchController controller, SearchDriver driver) {
  if (identical(controller._driver, driver)) controller._driver = null;
}

/// The field's own edit (native or Flutter): updates the value and never
/// goes back to the field.
void applySearchEdit(LiquidSearchController controller, LiquidSearchValue next) {
  controller.value = next;
}
```

- [ ] **Step 5: `LiquidSearch`**

`liquid_shell/lib/src/search/search.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:liquid_shell/src/search/search_controller.dart';

/// The search tab's field (spec P3b §4.2). Give it to `LiquidShell.search`
/// with a destination whose role is `LiquidDestinationRole.search`.
@immutable
class LiquidSearch {
  /// Creates the search config.
  const LiquidSearch({
    required this.controller,
    this.placeholder,
    this.onChanged,
    this.onSubmitted,
  });

  /// The query, the active state and the scope; owned by the app.
  final LiquidSearchController controller;

  /// Text of the empty field. Null: the platform's own ("Search" in the
  /// device language natively, `LiquidShellStrings.searchPlaceholder` in
  /// the Flutter field).
  final String? placeholder;

  /// Every text change the user makes, IME composition included. Not called
  /// for text the app sets through [controller].
  final ValueChanged<String>? onChanged;

  /// The user pressed the keyboard's Search key.
  final ValueChanged<String>? onSubmitted;

  /// Field by field; callbacks by identity.
  @override
  bool operator ==(Object other) =>
      other is LiquidSearch &&
      identical(other.controller, controller) &&
      other.placeholder == placeholder &&
      other.onChanged == onChanged &&
      other.onSubmitted == onSubmitted;

  @override
  int get hashCode => Object.hash(controller, placeholder, onChanged, onSubmitted);
}
```

- [ ] **Step 6: Pure layout functions**

`liquid_shell/lib/src/search/search_layout.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/destinations/destination.dart';
import 'package:liquid_shell/src/search/search_controller.dart';

/// Gap between the search field and the keyboard or a neighbour (iOS 26).
const double kSearchFieldGap = 8;

/// The index of the search destination, or null. The first one wins in
/// release builds (debug asserts there is at most one).
int? searchIndexOf(List<LiquidDestination> destinations) {
  for (final (i, d) in destinations.indexed) {
    if (d.role == LiquidDestinationRole.search) return i;
  }
  return null;
}

/// The search phase for a selection and the controller's focus.
LiquidSearchPhase searchPhaseFor({
  required int selected,
  required int? searchIndex,
  required bool active,
}) {
  if (searchIndex == null || selected != searchIndex) {
    return LiquidSearchPhase.idle;
  }
  return active ? LiquidSearchPhase.active : LiquidSearchPhase.selected;
}

/// The bottom inset that keeps content clear of the native search field
/// (spec P3b §4.6). Only a field in the lower half counts (the iPhone's
/// tab-hosted field); a stacked field at the top is in the top padding.
/// Active: down to the field's top, or the keyboard plus the field and its
/// gaps while Flutter's keyboard inset is still animating.
double nativeSearchBottomInset({
  required Rect field,
  required Size size,
  required EdgeInsets padding,
  required EdgeInsets viewInsets,
  required bool active,
}) {
  if (field.isEmpty || field.center.dy < size.height / 2) return 0;
  if (!active) return padding.bottom;
  return [
    padding.bottom,
    size.height - field.top,
    viewInsets.bottom + field.height + 2 * kSearchFieldGap,
  ].reduce(math.max);
}
```

- [ ] **Step 7: Native layout**

In `native_layout.dart`, add `import 'package:liquid_shell/src/search/search_layout.dart';` and change `nativeDescribable`:

```dart
/// Whether every destination and the trailing action have an SF Symbol. A
/// search destination needs none: UIKit's search tab has its own image.
bool nativeDescribable(
  List<LiquidDestination> destinations,
  LiquidTabAction? trailing,
) =>
    destinations.isNotEmpty &&
    destinations.every(
      (d) => d.sfSymbol != null || d.role == LiquidDestinationRole.search,
    ) &&
    (trailing == null || trailing.sfSymbol != null);
```

`nativeSymbolHint` must skip search destinations the same way: change its `if (d.sfSymbol == null)` to `if (d.sfSymbol == null && d.role != LiquidDestinationRole.search)`.

Change `nativeConfigFor`: add the parameters `String? searchPlaceholder,` and `Map<int, List<LiquidNativePage>> pageStacks = const {},`, and build the tabs and the search config like this:

```dart
  tabs: [
    for (final (i, d) in destinations.indexed)
      LiquidNativeTab(
        title: d.label,
        sfSymbol: d.sfSymbol ?? '',
        badge: nativeBadgeText(d.badge),
        sidebarOnly: d.placement == LiquidPlacement.sidebarOnly,
        search: d.role == LiquidDestinationRole.search,
        pages: pageStacks[i] ?? const [],
      ),
  ],
  // … selectedIndex, trailing, footer unchanged …
  search: searchIndexOf(destinations) == null
      ? null
      : LiquidNativeSearchConfig(placeholder: searchPlaceholder),
```

and add:

```dart
/// Whether the selected tab has a native navigation bar (spec P3b §8.3).
/// P3b-1: the search tab only, while native chrome is engaged. P3b-2 makes
/// it every engaged tab.
bool nativePageBarFor({
  required bool engaged,
  required int selected,
  required int? searchIndex,
}) => engaged && searchIndex != null && selected == searchIndex;
```

- [ ] **Step 8: Strings**

In `strings.dart`, add the constructor parameters `this.searchPlaceholder = 'Search', this.cancelSearch = 'Cancel search', this.back = 'Back',`, the fields

```dart
  /// The Flutter search field's placeholder when `LiquidSearch.placeholder`
  /// is null.
  final String searchPlaceholder;

  /// Semantics and tooltip of the Flutter search field's cancel (×).
  final String cancelSearch;

  /// Semantics and tooltip of `LiquidBackButton`.
  final String back;
```

and all three in `==` and `hashCode` (`Object.hash` takes up to 20 arguments; there are 9).

- [ ] **Step 9: `LiquidShell.search`, the asserts and the config call**

In `liquid_shell.dart`: add `import 'package:liquid_shell/src/search/search.dart';` and `import 'package:liquid_shell/src/search/search_layout.dart';`, the constructor parameter `this.search,` (after `nativeSidebarFooter`), and the field:

```dart
  /// The search tab's field. Required with a destination whose role is
  /// [LiquidDestinationRole.search], and only then. Search is a tab: its
  /// page is that destination's page, never a page pushed above the shell.
  final LiquidSearch? search;
```

At the end of `_debugCheckArguments`, before `return true;`:

```dart
    final searches = [
      for (final (i, d) in destinations.indexed)
        if (d.role == LiquidDestinationRole.search) i,
    ];
    assert(
      searches.length <= 1,
      'LiquidShell allows one search destination; got ${searches.length}.',
    );
    assert(
      searches.isEmpty || searches.single == length - 1,
      'The search destination must be the last destination.',
    );
    assert(
      searches.every(
        (i) => destinations[i].placement == LiquidPlacement.everywhere,
      ),
      'The search destination must be placed everywhere.',
    );
    assert(
      searches.isEmpty || widget.search != null,
      'A search destination needs LiquidShell.search.',
    );
    assert(
      searches.isNotEmpty || widget.search == null,
      'LiquidShell.search needs a destination with '
      'LiquidDestinationRole.search.',
    );
    assert(
      searches.isEmpty || widget.tabBarTrailing == null,
      'A shell with a search destination has no tabBarTrailing: both are '
      'the trailing ⌕.',
    );
```

In `_resolveNative`, add `searchPlaceholder: widget.search?.placeholder,` to the `nativeConfigFor(…)` call (Task 8 adds `pageStacks:`).

- [ ] **Step 10: Exports**

In `liquid_shell/lib/liquid_shell.dart`, add:

```dart
export 'src/search/search.dart';
export 'src/search/search_controller.dart'
    show LiquidSearchController, LiquidSearchPhase, LiquidSearchValue;
```

`LiquidDestinationRole` is exported with `destination.dart` already.

- [ ] **Step 11: Run the tests**

Run: `cd liquid_shell && fvm flutter test --exclude-tags golden`
Expected: all pass, the new files included.

- [ ] **Step 12: Commit**

```bash
bash .githooks/pre-commit
git add liquid_shell/lib/src/destinations/destination.dart liquid_shell/lib/src/search \
  liquid_shell/lib/src/native/native_layout.dart liquid_shell/lib/src/shell/liquid_shell.dart \
  liquid_shell/lib/src/shell/strings.dart liquid_shell/lib/liquid_shell.dart \
  liquid_shell/test/unit/search_test.dart liquid_shell/test/unit/native_layout_test.dart \
  liquid_shell/test/unit/destinations_test.dart liquid_shell/test/widget/search_asserts_test.dart
git commit -m "feat(shell): the search destination, LiquidSearch and its controller (VK-407)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: `LiquidPage`, the page registry and the Flutter glass bar

**Files:**
- Create: `liquid_shell/lib/src/pages/page_registry.dart`
- Create: `liquid_shell/lib/src/pages/liquid_page.dart`
- Create: `liquid_shell/lib/src/pages/page_bar.dart`
- Modify: `liquid_shell/lib/src/shell/shell_scope.dart` (`searchPhase`, `nativePageBar`; `ShellScopeMarker.pages`, `.strings`)
- Modify: `liquid_shell/lib/liquid_shell.dart`
- Test: `liquid_shell/test/widget/liquid_page_test.dart` (new)

**Interfaces:**
- Consumes: Task 6 (`LiquidSearchPhase`, `LiquidShellStrings.back`).
- Produces (P3b-2 consumes these names):
  - `page_registry.dart`: `class PageEntry { title, largeTitle, route (ModalRoute<Object?>?), navigator (NavigatorState?), sequence (int), onScreen (bool), current (bool), active (bool); bool get isTop; bool sameAs(PageEntry other) }`, `abstract interface class PageHandle { void update(PageEntry entry); void scrolled(double offset); void unregister(); }`, `abstract interface class PageRegistry { PageHandle registerPage(PageEntry entry); }`, `List<PageEntry> pageStackFor(Iterable<PageEntry> entries, {required bool Function(PageEntry) isTop})`
  - `LiquidPage({required String title, required Widget child, bool? largeTitle})`, `LiquidBackButton({VoidCallback? onPressed, String? semanticLabel})` (exported)
  - `page_bar.dart`: `FlutterPageBar({required String title, required bool large, required bool canPop, required bool hideLargeTitle, required Widget child})`, `const double kPageBarExtent = 54`, `const double kLargeTitleExtent = 52`
  - `LiquidShellScopeData({…, LiquidSearchPhase? searchPhase, bool nativePageBar = false})`; `ShellScopeMarker({…, PageRegistry? pages, LiquidShellStrings strings = const LiquidShellStrings()})`

- [ ] **Step 1: Write the failing widget tests**

`liquid_shell/test/widget/liquid_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/pages/page_bar.dart';
import 'package:liquid_shell/src/pages/page_registry.dart';
import 'package:liquid_shell/src/shell/shell_scope.dart';
import 'package:liquid_shell/src/shell/shell_layout.dart';

/// Records registrations like a shell does.
class _Registry implements PageRegistry {
  final records = <_Record>[];
  final offsets = <double>[];

  List<String> stack() => [
    for (final e in pageStackFor(
      records.map((r) => r.entry),
      isTop: (e) => e.isTop,
    ))
      e.title,
  ];

  @override
  PageHandle registerPage(PageEntry entry) {
    final record = _Record(this, entry);
    records.add(record);
    return record;
  }
}

class _Record implements PageHandle {
  _Record(this.registry, this.entry);

  final _Registry registry;
  PageEntry entry;

  @override
  void update(PageEntry entry) => this.entry = entry;

  @override
  void scrolled(double offset) => registry.offsets.add(offset);

  @override
  void unregister() => registry.records.remove(this);
}

LiquidShellScopeData _scope({
  bool nativePageBar = false,
  LiquidSearchPhase? phase,
  LiquidSizeClass sizeClass = LiquidSizeClass.compact,
}) => LiquidShellScopeData(
  sizeClass: sizeClass,
  chromeKind: LiquidChromeKind.hidden,
  chromeInsets: EdgeInsets.zero,
  sidebarVisible: false,
  setSidebarVisible: (_) {},
  searchPhase: phase,
  nativePageBar: nativePageBar,
);

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      TextButton(
        onPressed: () => setState(() => taps++),
        child: Text('taps $taps'),
      ),
      for (var i = 0; i < 40; i++) SizedBox(height: 40, child: Text('row $i')),
    ],
  );
}

Future<_Registry> _pump(
  WidgetTester tester, {
  LiquidShellScopeData? data,
  Widget home = const LiquidPage(title: 'Search', child: _Counter()),
}) async {
  final registry = _Registry();
  await tester.pumpWidget(
    ShellScopeMarker(
      data: data ?? _scope(),
      registry: null,
      pages: registry,
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
  return registry;
}

void main() {
  testWidgets('pages register in push order; a pop shortens the stack', (
    tester,
  ) async {
    final registry = await _pump(tester);
    expect(registry.stack(), ['Search']);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const LiquidPage(title: 'Hồ Hoàn Kiếm', child: _Counter()),
      ),
    ).ignore();
    await tester.pumpAndSettle();
    expect(registry.stack(), ['Search', 'Hồ Hoàn Kiếm']);
    navigator.pop();
    await tester.pump(); // the pop has started: the lower route is current
    expect(registry.stack(), ['Search']);
    await tester.pumpAndSettle();
    expect(registry.records, hasLength(1));
  });

  testWidgets('only the visible branch makes the stack', (tester) async {
    final registry = await _pump(
      tester,
      home: const IndexedStack(
        index: 1,
        children: [
          LiquidPage(title: 'Home', child: _Counter()),
          LiquidPage(title: 'Search', child: _Counter()),
        ],
      ),
    );
    expect(registry.records, hasLength(2));
    expect(registry.stack(), ['Search']);
  });

  testWidgets('a root page at compact width gets a large title, no back', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byType(FlutterPageBar), findsOneWidget);
    final bar = tester.widget<FlutterPageBar>(find.byType(FlutterPageBar));
    expect(bar.large, isTrue);
    expect(bar.canPop, isFalse);
    expect(find.byType(LiquidBackButton), findsNothing);
    expect(find.text('Search'), findsOneWidget);
  });

  testWidgets('a pushed page gets the glass back button, which pops', (
    tester,
  ) async {
    await _pump(tester);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(
          MaterialPageRoute<void>(
            builder: (_) => const LiquidPage(title: 'Detail', child: _Counter()),
          ),
        )
        .ignore();
    await tester.pumpAndSettle();
    expect(find.byType(LiquidBackButton), findsOneWidget);
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    await tester.tap(find.byType(LiquidBackButton));
    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsNothing);
  });

  testWidgets('a root page with an inline title at regular width has no bar', (
    tester,
  ) async {
    await _pump(tester, data: _scope(sizeClass: LiquidSizeClass.regular));
    expect(find.byType(FlutterPageBar), findsNothing);
  });

  testWidgets('the large title hides while the search is active', (
    tester,
  ) async {
    await _pump(tester, data: _scope(phase: LiquidSearchPhase.active));
    final bar = tester.widget<FlutterPageBar>(find.byType(FlutterPageBar));
    expect(bar.hideLargeTitle, isTrue);
    expect(find.text('Search'), findsNothing);
  });

  testWidgets('under a native bar nothing is drawn and the child keeps its state', (
    tester,
  ) async {
    final registry = _Registry();
    Widget app(bool native) => ShellScopeMarker(
      data: _scope(nativePageBar: native),
      registry: null,
      pages: registry,
      child: const MaterialApp(
        home: LiquidPage(title: 'Search', child: _Counter()),
      ),
    );
    await tester.pumpWidget(app(false));
    await tester.tap(find.text('taps 0'));
    await tester.pump();
    await tester.pumpWidget(app(true));
    await tester.pump();
    expect(find.byType(FlutterPageBar), findsNothing);
    expect(find.text('taps 1'), findsOneWidget, reason: 'same State');
    await tester.pumpWidget(app(false));
    await tester.pump();
    expect(find.text('taps 1'), findsOneWidget);
  });

  testWidgets('the first vertical scroll view reports its offset', (
    tester,
  ) async {
    final registry = await _pump(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();
    expect(registry.offsets, isNotEmpty);
    expect(registry.offsets.last, greaterThan(100));
  });

  testWidgets('LiquidBackButton reads its label from the shell strings', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShellScopeMarker(
        data: _scope(),
        registry: null,
        strings: const LiquidShellStrings(back: 'Quay lại'),
        child: MaterialApp(
          home: Scaffold(body: Center(child: LiquidBackButton(onPressed: () {}))),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Quay lại'), findsOneWidget);
    expect(tester.getSize(find.byType(LiquidBackButton)), const Size(44, 44));
  });
}
```

Also append to `liquid_page_test.dart`'s `main()`:

```dart
  test('searchPhase and nativePageBar join the scope equality', () {
    expect(_scope(), _scope());
    expect(_scope(phase: LiquidSearchPhase.selected), isNot(_scope()));
    expect(_scope(nativePageBar: true), isNot(_scope()));
    expect(
      _scope(nativePageBar: true).hashCode,
      _scope(nativePageBar: true).hashCode,
    );
  });
```

- [ ] **Step 2: Run them to see them fail**

Run: `cd liquid_shell && fvm flutter test test/widget/liquid_page_test.dart`
Expected: compile errors: `PageRegistry`, `LiquidPage`, `FlutterPageBar` undefined; `pages:` not a parameter of `ShellScopeMarker`.

- [ ] **Step 3: Scope fields and the marker**

In `shell_scope.dart`: import `package:liquid_shell/src/pages/page_registry.dart`, `package:liquid_shell/src/search/search_controller.dart` and `package:liquid_shell/src/shell/strings.dart`. Add to `LiquidShellScopeData`'s constructor `this.searchPhase,` and `this.nativePageBar = false,`, the fields

```dart
  /// The search tab's phase; null when the shell has no search tab.
  final LiquidSearchPhase? searchPhase;

  /// The selected tab has a native navigation bar (iOS 26 native chrome):
  /// `LiquidPage` draws no Flutter bar, and [windowControls] is zero.
  final bool nativePageBar;
```

and both in `==` (`other.searchPhase == searchPhase && other.nativePageBar == nativePageBar`) and `hashCode`.

`ShellScopeMarker`:

```dart
class ShellScopeMarker extends InheritedWidget {
  const ShellScopeMarker({
    required this.data,
    required this.registry,
    required super.child,
    this.pages,
    this.strings = const LiquidShellStrings(),
    super.key,
  });

  final LiquidShellScopeData data;
  final HideChromeRegistry? registry;

  /// Where `LiquidPage`s register; null outside a shell.
  final PageRegistry? pages;

  /// The shell's strings (the back button's label).
  final LiquidShellStrings strings;

  @override
  bool updateShouldNotify(ShellScopeMarker oldWidget) =>
      data != oldWidget.data ||
      registry != oldWidget.registry ||
      pages != oldWidget.pages ||
      strings != oldWidget.strings;
}
```

- [ ] **Step 4: The registry**

`liquid_shell/lib/src/pages/page_registry.dart`:

```dart
import 'package:flutter/widgets.dart';

/// One registered `LiquidPage` (spec P3b §8.4): what the native bar needs
/// and where the page is.
@immutable
class PageEntry {
  /// Creates an entry.
  const PageEntry({
    required this.title,
    required this.largeTitle,
    required this.route,
    required this.navigator,
    required this.sequence,
    required this.onScreen,
    required this.current,
    required this.active,
  });

  /// Navigation bar title.
  final String title;

  /// Large title; null: the platform default.
  final bool? largeTitle;

  /// The page's route.
  final ModalRoute<Object?>? route;

  /// The navigator holding [route].
  final NavigatorState? navigator;

  /// Creation order: push order within a navigator.
  final int sequence;

  /// Tickers on: not covered by an opaque route, not in a hidden branch.
  final bool onScreen;

  /// [route] was current when the entry was taken.
  final bool current;

  /// [route] was active (in the history, not popping) when taken.
  final bool active;

  /// The page the user sees.
  bool get isTop => onScreen && (route?.isCurrent ?? false);

  /// Whether [other] describes the same page in the same state.
  bool sameAs(PageEntry other) =>
      other.title == title &&
      other.largeTitle == largeTitle &&
      identical(other.route, route) &&
      identical(other.navigator, navigator) &&
      other.sequence == sequence &&
      other.onScreen == onScreen &&
      other.current == current &&
      other.active == active;
}

/// A page's registration.
abstract interface class PageHandle {
  /// The page's state changed (title, route, on screen).
  void update(PageEntry entry);

  /// The page's first vertical scroll view scrolled to [offset].
  void scrolled(double offset);

  /// The page left the tree.
  void unregister();
}

/// Where pages register: the shell.
abstract interface class PageRegistry {
  /// Registers a page.
  PageHandle registerPage(PageEntry entry);
}

/// The selected tab's stack (spec P3b §8.4): every active page in the top
/// page's navigator, in push order. Empty when no page is on top.
List<PageEntry> pageStackFor(
  Iterable<PageEntry> entries, {
  required bool Function(PageEntry) isTop,
}) {
  PageEntry? top;
  for (final entry in entries) {
    if (isTop(entry) && (top == null || entry.sequence > top.sequence)) {
      top = entry;
    }
  }
  if (top == null) return const [];
  final navigator = top.navigator;
  return [
    for (final entry in entries)
      if (identical(entry.navigator, navigator) &&
          (identical(entry, top) || (entry.route?.isActive ?? false)))
        entry,
  ]..sort((a, b) => a.sequence.compareTo(b.sequence));
}
```

- [ ] **Step 5: The Flutter bar**

`liquid_shell/lib/src/pages/page_bar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell/src/native/window_controls.dart';
import 'package:liquid_shell/src/pages/liquid_page.dart';
import 'package:liquid_shell/src/shell/shell_scope.dart';

/// Height of the bar row (iOS 26: 54pt).
const double kPageBarExtent = 54;

/// Height of the large title row.
const double kLargeTitleExtent = 52;

/// Fade height of the scroll-edge effect under the bar.
const double _kEdgeFade = 24;

/// A `LiquidPage`'s bar where no native bar draws it (spec P3b §9.5): the
/// glass back circle, the inline or large title, and a scroll-edge fade.
/// Its child gets the bar's height added to its top padding, so
/// `LiquidShellScope.contentPaddingOf` keeps content below it.
class FlutterPageBar extends StatelessWidget {
  /// Creates the bar.
  const FlutterPageBar({
    required this.title,
    required this.large,
    required this.canPop,
    required this.hideLargeTitle,
    required this.child,
    super.key,
  });

  /// The title.
  final String title;

  /// Large title (otherwise inline in the bar row).
  final bool large;

  /// Whether the page's navigator can pop: the back button shows.
  final bool canPop;

  /// Hides the large title (an active search hides it, as UIKit does).
  final bool hideLargeTitle;

  /// The page.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    // Below the shell's own chrome at the top (a Flutter top tab bar).
    final barTop = LiquidShellScope.contentPaddingOf(context).top;
    final showLarge = large && !hideLargeTitle;
    final bottom = barTop + kPageBarExtent + (showLarge ? kLargeTitleExtent : 0);
    final padded = media.copyWith(
      padding: media.padding.copyWith(top: bottom),
      viewPadding: media.viewPadding.copyWith(top: bottom),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: MediaQuery(
            data: padded,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) {
                final end = rect.height == 0 ? 0.0 : (barTop + kPageBarExtent) / rect.height;
                final start = rect.height == 0
                    ? 0.0
                    : (barTop + kPageBarExtent - _kEdgeFade) / rect.height;
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [Color(0x00000000), Color(0xFF000000)],
                  stops: [start.clamp(0, 1), end.clamp(0, 1)],
                ).createShader(rect);
              },
              child: child,
            ),
          ),
        ),
        Positioned(
          top: barTop,
          left: 0,
          right: 0,
          height: kPageBarExtent,
          child: LiquidWindowControlsClearance(
            rowTop: barTop - media.padding.top,
            child: Row(
              children: [
                const SizedBox(width: 16),
                if (canPop) const LiquidBackButton(),
                Expanded(
                  child: large
                      ? const SizedBox.shrink()
                      : Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                // Keeps an inline title centred against the back button.
                SizedBox(width: canPop ? 16 + LiquidBackButton.size : 16),
              ],
            ),
          ),
        ),
        if (showLarge)
          PositionedDirectional(
            top: barTop + kPageBarExtent,
            start: 16,
            end: 16,
            height: kLargeTitleExtent,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 6: `LiquidPage` and `LiquidBackButton`**

`liquid_shell/lib/src/pages/liquid_page.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';
import 'package:liquid_shell/src/pages/page_bar.dart';
import 'package:liquid_shell/src/pages/page_registry.dart';
import 'package:liquid_shell/src/search/search_controller.dart';
import 'package:liquid_shell/src/shell/breakpoints.dart';
import 'package:liquid_shell/src/shell/shell_scope.dart';
import 'package:liquid_shell/src/shell/strings.dart';

/// One page of a tab: its title for the navigation bar, and the back
/// button when its navigator can pop (spec P3b §4.5).
///
/// Where its tab has a native navigation bar (iOS 26 native chrome: the
/// search tab), the platform draws the title and UIKit's glass back circle
/// and this widget draws only [child]. Elsewhere it draws a Flutter glass
/// bar. A root page with an inline title draws no bar: the shell's own
/// chrome is its title row.
class LiquidPage extends StatefulWidget {
  /// Creates a page.
  const LiquidPage({
    required this.title,
    required this.child,
    this.largeTitle,
    super.key,
  });

  /// Navigation bar title.
  final String title;

  /// Large title. Null: large on a tab's root page at compact width,
  /// inline otherwise.
  final bool? largeTitle;

  /// The page. Its first vertical scroll view drives the native large
  /// title's collapse and the scroll-edge effect.
  final Widget child;

  @override
  State<LiquidPage> createState() => _LiquidPageState();
}

class _LiquidPageState extends State<LiquidPage> {
  static int _nextSequence = 0;
  final int _sequence = _nextSequence++;
  // The child keeps its State when the bar switches between native and
  // Flutter (native chrome on or off).
  final GlobalKey _childKey = GlobalKey();
  PageRegistry? _registry;
  PageHandle? _handle;

  PageEntry _entry() {
    final route = ModalRoute.of(context);
    return PageEntry(
      title: widget.title,
      largeTitle: widget.largeTitle,
      route: route,
      navigator: Navigator.maybeOf(context),
      sequence: _sequence,
      onScreen: TickerMode.valuesOf(context).enabled,
      current: route?.isCurrent ?? false,
      active: route?.isActive ?? false,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = context
        .dependOnInheritedWidgetOfExactType<ShellScopeMarker>()
        ?.pages;
    final entry = _entry();
    if (!identical(registry, _registry)) {
      _handle?.unregister();
      _registry = registry;
      _handle = registry?.registerPage(entry);
    } else {
      _handle?.update(entry);
    }
  }

  @override
  void didUpdateWidget(LiquidPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title ||
        oldWidget.largeTitle != widget.largeTitle) {
      _handle?.update(_entry());
    }
  }

  @override
  void dispose() {
    _handle?.unregister();
    super.dispose();
  }

  bool _onScroll(ScrollUpdateNotification notification) {
    if (notification.depth == 0 &&
        notification.metrics.axis == Axis.vertical) {
      _handle?.scrolled(notification.metrics.pixels);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final scope = LiquidShellScope.maybeOf(context);
    final child = KeyedSubtree(
      key: _childKey,
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: _onScroll,
        child: widget.child,
      ),
    );
    if (scope?.nativePageBar ?? false) return child;
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    final sizeClass =
        scope?.sizeClass ??
        const LiquidShellBreakpoints().sizeClassOf(
          MediaQuery.sizeOf(context).width,
        );
    final large =
        widget.largeTitle ?? (!canPop && sizeClass == LiquidSizeClass.compact);
    if (!canPop && !large) return child;
    return FlutterPageBar(
      title: widget.title,
      large: large,
      canPop: canPop,
      hideLargeTitle: scope?.searchPhase == LiquidSearchPhase.active,
      child: child,
    );
  }
}

/// A 44pt glass circle with a back chevron (spec P3b §4.5). Pops the
/// nearest navigator with `maybePop` by default, so a page's `PopScope`
/// guard runs.
class LiquidBackButton extends StatelessWidget {
  /// Creates the button.
  const LiquidBackButton({this.onPressed, this.semanticLabel, super.key});

  /// Diameter.
  static const double size = 44;

  /// Called on tap. Null: `Navigator.maybePop(context)`.
  final VoidCallback? onPressed;

  /// Semantics and tooltip. Null: the shell's `LiquidShellStrings.back`.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final label =
        semanticLabel ??
        context.getInheritedWidgetOfExactType<ShellScopeMarker>()?.strings.back ??
        const LiquidShellStrings().back;
    void pressed() =>
        onPressed != null ? onPressed!() : unawaited(Navigator.maybePop(context));
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: pressed,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: SizedBox.square(
          dimension: size,
          child: LiquidGlass(
            borderRadius: const BorderRadius.all(Radius.circular(size / 2)),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: pressed,
                child: Center(
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Exports**

In `liquid_shell/lib/liquid_shell.dart`, add `export 'src/pages/liquid_page.dart';`.

- [ ] **Step 8: Run the tests**

Run: `cd liquid_shell && fvm flutter test --exclude-tags golden`
Expected: all pass. If `navigator.pop(); await tester.pump();` still shows two pages, the stack is read before the lower page's `ModalRoute` dependency fired: pump one more frame in the test (`await tester.pump(Duration.zero)`), since the shell itself recomputes after a frame.

- [ ] **Step 9: Commit**

```bash
bash .githooks/pre-commit
git add liquid_shell/lib/src/pages liquid_shell/lib/src/shell/shell_scope.dart \
  liquid_shell/lib/liquid_shell.dart liquid_shell/test/widget/liquid_page_test.dart
git commit -m "feat(shell): LiquidPage, the glass back button and the page registry (VK-407)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: The shell drives the native search tab and its pages

**Files:**
- Create: `liquid_shell/lib/src/search/shell_search.dart`
- Modify: `liquid_shell/lib/src/native/native_host.dart` (`NativeChromeClaim` commands)
- Modify: `liquid_shell/lib/src/shell/liquid_shell.dart`
- Modify: `liquid_shell/test/helpers/fake_native_platform.dart`, `liquid_shell/test/helpers/shell_harness.dart` (`TestShell.search`, `kNative` moved here from `native_chrome_test.dart`)
- Modify: `liquid_shell/test/widget/native_chrome_test.dart` (import `kNative` from the harness)
- Test: `liquid_shell/test/widget/native_search_test.dart` (new)

**Interfaces:**
- Consumes: Tasks 2, 6, 7.
- Produces (P3b-2 consumes these names):
  - `NativeChromeClaim.setSearchText(String)`, `.setSearchActive({required bool active})`, `.setPageScroll({required int tab, required double offset})` (owner only)
  - `final class ShellSearch implements SearchDriver` with `configure(LiquidSearch?, {required bool hasSearchDestination})`, `controller`, `native` (bool), `selected` (bool), `field` (Rect), `onNativeEvent(LiquidNativeEvent)`, `afterConfigSent()`, `editing` (`TextEditingController`), `focus` (`FocusNode`), `cancel()`, `submit(String)`, `dispose()`
  - `_LiquidShellState implements PageRegistry`; fields `_pageStacks: Map<int, List<LiquidNativePage>>`; getter `PageEntry? get _topPageEntry`
  - `TestShell({…, LiquidSearch? search})`; `kNative` in `test/helpers/shell_harness.dart`
  - `FakeNativePlatform.searchTexts`, `.searchActives`, `.pageScrolls` (`List<(int, double)>`)

- [ ] **Step 1: Test helpers**

Move the `kNative` constant (with its doc comment) from `test/widget/native_chrome_test.dart` to the end of `test/helpers/shell_harness.dart`, unchanged; `native_chrome_test.dart` already imports the harness.

In `TestShell`, add `this.search,` to the constructor, `final LiquidSearch? search;`, and `search: widget.search,` in `TestShellState.build`'s `LiquidShell(…)`.

In `FakeNativePlatform`, add:

```dart
  /// Every `setNativeSearchText`.
  final searchTexts = <String>[];

  /// Every `setNativeSearchActive`.
  final searchActives = <bool>[];

  /// Every `setNativePageScroll`, as (tab, offset).
  final pageScrolls = <(int, double)>[];

  @override
  Future<void> setNativeSearchText(String text) async => searchTexts.add(text);

  @override
  Future<void> setNativeSearchActive({required bool active}) async =>
      searchActives.add(active);

  @override
  Future<void> setNativePageScroll({
    required int tab,
    required double offset,
  }) async => pageScrolls.add((tab, offset));
```

- [ ] **Step 2: Write the failing widget tests**

`liquid_shell/test/widget/native_search_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

import '../helpers/fake_native_platform.dart';
import '../helpers/shell_harness.dart';

const _destinations = [
  LiquidDestination(icon: Icon(Icons.home), label: 'Home', sfSymbol: 'house'),
  LiquidDestination(
    icon: Icon(Icons.book),
    label: 'Library',
    sfSymbol: 'books.vertical',
  ),
  LiquidDestination(
    icon: Icon(Icons.search),
    label: 'Search',
    role: LiquidDestinationRole.search,
  ),
];

/// iPhone portrait with UIKit's compact bar in the bottom safe area.
const _compactPadding = EdgeInsets.only(top: 62, bottom: 83);
const _compact = LiquidNativeShellState(installed: true, compact: true);

final _searchNavigator = GlobalKey<NavigatorState>();

/// The search page: a branch navigator whose root is a LiquidPage.
Widget _page(int index) => switch (index) {
  2 => Navigator(
    key: _searchNavigator,
    onGenerateRoute: (_) => MaterialPageRoute<void>(
      builder: (_) => const LiquidPage(
        title: 'Search',
        child: TestPage(label: 'Search'),
      ),
    ),
  ),
  _ => TestPage(label: _destinations[index].label),
};

Future<(FakeNativePlatform, LiquidSearchController, List<String>)> _pump(
  WidgetTester tester, {
  int initialIndex = 2,
  LiquidBeforeDestinationChange? guard,
  List<String>? submitted,
}) async {
  final fake = installFakeNative(state: _compact);
  final controller = LiquidSearchController();
  addTearDown(controller.dispose);
  final changes = <String>[];
  await pumpShell(
    tester,
    TestShell(
      destinations: _destinations,
      initialIndex: initialIndex,
      guard: guard,
      pageBuilder: _page,
      search: LiquidSearch(
        controller: controller,
        placeholder: 'Songs, places',
        onChanged: changes.add,
        onSubmitted: submitted?.add,
      ),
    ),
    padding: _compactPadding,
  );
  return (fake, controller, changes);
}

LiquidShellScopeData _scope(WidgetTester tester, [String label = 'Search']) =>
    scopeOf(tester, label);

void main() {
  setUp(debugResetLiquidNative);

  testWidgets('the config marks the search tab and carries the placeholder', (
    tester,
  ) async {
    final (fake, _, _) = await _pump(tester);
    expect(fake.last.tabs.map((t) => t.search), [false, false, true]);
    expect(fake.last.search?.placeholder, 'Songs, places');
    expect(fake.last.selectedIndex, 2);
    expect(fake.last.tabs.last.pages.map((p) => p.title), ['Search']);
  });

  testWidgets('a native tap on the search tab runs the guard, then selects it', (
    tester,
  ) async {
    final asked = <int>[];
    final (fake, _, _) = await _pump(
      tester,
      initialIndex: 0,
      guard: (i) async {
        asked.add(i);
        return true;
      },
    );
    fake.emitNative(const LiquidNativeDestinationTapped(2));
    await tester.pumpAndSettle();
    expect(asked, [2]);
    expect(fake.last.selectedIndex, 2);
    expect(_scope(tester).searchPhase, LiquidSearchPhase.selected);
  });

  testWidgets('native text reaches the controller and onChanged, not back', (
    tester,
  ) async {
    final (fake, controller, changes) = await _pump(tester);
    fake.emitNative(const LiquidNativeSearchTextChanged('hô', composing: true));
    await tester.pump();
    expect(controller.value.text, 'hô');
    expect(controller.value.composing, isTrue);
    expect(changes, ['hô']);
    expect(fake.searchTexts, isEmpty, reason: 'never echoed');
  });

  testWidgets('text while another tab is selected is dropped', (tester) async {
    final (fake, controller, _) = await _pump(tester, initialIndex: 0);
    fake.emitNative(const LiquidNativeSearchTextChanged('x', composing: false));
    await tester.pump();
    expect(controller.text, '');
  });

  testWidgets('the app sets the text: native gets it', (tester) async {
    final (fake, controller, changes) = await _pump(tester);
    controller.text = 'ho';
    await tester.pump();
    expect(fake.searchTexts, ['ho']);
    expect(changes, isEmpty, reason: 'onChanged is for the user');
  });

  testWidgets('submit calls onSubmitted', (tester) async {
    final submitted = <String>[];
    final (fake, _, _) = await _pump(tester, submitted: submitted);
    fake.emitNative(const LiquidNativeSearchSubmitted('hồ'));
    await tester.pump();
    expect(submitted, ['hồ']);
  });

  testWidgets('reselecting the search tab restores the kept query (Q2)', (
    tester,
  ) async {
    final (fake, controller, _) = await _pump(tester);
    fake.emitNative(const LiquidNativeSearchTextChanged('hà', composing: false));
    await tester.pump();
    fake.emitNative(const LiquidNativeDestinationTapped(0));
    await tester.pumpAndSettle();
    expect(fake.last.selectedIndex, 0);
    expect(controller.text, 'hà', reason: 'kept while away');
    fake.searchTexts.clear();
    fake.emitNative(const LiquidNativeDestinationTapped(2));
    await tester.pumpAndSettle();
    expect(fake.last.selectedIndex, 2);
    expect(fake.searchTexts, ['hà'], reason: 'sent after the selecting config');
  });

  testWidgets('leaving the search tab while active makes it inactive', (
    tester,
  ) async {
    final (fake, controller, _) = await _pump(tester);
    fake.emitNative(const LiquidNativeSearchActiveChanged(true));
    await tester.pump();
    expect(controller.isActive, isTrue);
    expect(_scope(tester).searchPhase, LiquidSearchPhase.active);
    fake.emitNative(const LiquidNativeDestinationTapped(0));
    await tester.pumpAndSettle();
    expect(controller.isActive, isFalse);
  });

  testWidgets('activate unfocuses Flutter and asks native; ignored elsewhere', (
    tester,
  ) async {
    final (fake, controller, _) = await _pump(tester, initialIndex: 0);
    controller.activate();
    await tester.pump();
    expect(fake.searchActives, isEmpty, reason: 'search tab not selected');
    fake.emitNative(const LiquidNativeDestinationTapped(2));
    await tester.pumpAndSettle();
    // A Flutter text field elsewhere has the focus (first-responder rule,
    // spec §7.4): activation takes it away before native focuses its field.
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final entry = OverlayEntry(
      builder: (_) => Material(child: TextField(focusNode: focus)),
    );
    Overlay.of(tester.element(find.byKey(const ValueKey('list-Search'))))
        .insert(entry);
    addTearDown(entry.remove);
    await tester.pump();
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    controller.activate();
    await tester.pump();
    expect(fake.searchActives, [true]);
    expect(focus.hasFocus, isFalse);
    controller.deactivate();
    await tester.pump();
    expect(fake.searchActives, [true, false]);
  });

  testWidgets('a dialog above an active search deactivates it first', (
    tester,
  ) async {
    final (fake, _, _) = await _pump(tester);
    fake.emitNative(const LiquidNativeSearchActiveChanged(true));
    await tester.pump();
    showDialog<void>(
      context: tester.element(find.byKey(const ValueKey('list-Search'))),
      builder: (_) => const AlertDialog(title: Text('Hi')),
    ).ignore();
    await tester.pumpAndSettle();
    expect(fake.searchActives, [false]);
  });

  testWidgets('the field above the keyboard moves the bottom inset', (
    tester,
  ) async {
    final (fake, _, _) = await _pump(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 328);
    addTearDown(tester.view.resetViewInsets);
    fake
      ..emitNative(const LiquidNativeSearchActiveChanged(true))
      ..emitNative(
        const LiquidNativeSearchFieldChanged(Rect.fromLTWH(8, 490, 330, 48)),
      );
    await tester.pump();
    // max(852 − 490, 328 + 48 + 16) on the 393×852 harness window.
    expect(_scope(tester).chromeInsets.bottom, 392);
  });

  testWidgets('pages reach the config; native back pops the top page', (
    tester,
  ) async {
    final (fake, _, _) = await _pump(tester);
    _searchNavigator.currentState!
        .push(
          MaterialPageRoute<void>(
            builder: (_) => const LiquidPage(
              title: 'Hồ Hoàn Kiếm',
              child: TestPage(label: 'Detail'),
            ),
          ),
        )
        .ignore();
    await tester.pumpAndSettle();
    expect(fake.last.tabs.last.pages.map((p) => p.title), [
      'Search',
      'Hồ Hoàn Kiếm',
    ]);
    fake.emitNative(const LiquidNativeBackTapped(2));
    await tester.pumpAndSettle();
    expect(fake.last.tabs.last.pages.map((p) => p.title), ['Search']);
    expect(find.byKey(const ValueKey('list-Detail')), findsNothing);
  });

  testWidgets('a page that refuses to pop stays', (tester) async {
    final (fake, _, _) = await _pump(tester);
    _searchNavigator.currentState!
        .push(
          MaterialPageRoute<void>(
            builder: (_) => const PopScope(
              canPop: false,
              child: LiquidPage(title: 'Form', child: TestPage(label: 'Form')),
            ),
          ),
        )
        .ignore();
    await tester.pumpAndSettle();
    fake.emitNative(const LiquidNativeBackTapped(2));
    await tester.pumpAndSettle();
    expect(fake.last.tabs.last.pages, hasLength(2));
  });

  testWidgets('a back tap for another tab is dropped', (tester) async {
    final (fake, _, _) = await _pump(tester);
    _searchNavigator.currentState!
        .push(
          MaterialPageRoute<void>(
            builder: (_) => const LiquidPage(title: 'D', child: TestPage(label: 'D')),
          ),
        )
        .ignore();
    await tester.pumpAndSettle();
    fake.emitNative(const LiquidNativeBackTapped(0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('list-D')), findsOneWidget);
  });

  testWidgets('the search tab has a native bar: no Flutter bar, no controls', (
    tester,
  ) async {
    final (fake, _, _) = await _pump(tester);
    fake.controls = const LiquidWindowControls(leading: 66, top: 24);
    final scope = _scope(tester);
    expect(scope.nativePageBar, isTrue);
    expect(scope.windowControls, LiquidWindowControls.zero);
    expect(find.byType(LiquidBackButton), findsNothing);
    expect(find.text('Search'), findsNothing, reason: 'UIKit draws the title');
  });

  testWidgets('the top page scroll goes to native, tagged with its tab', (
    tester,
  ) async {
    final (fake, _, _) = await _pump(tester);
    await tester.drag(
      find.byKey(const ValueKey('list-Search')),
      const Offset(0, -300),
    );
    await tester.pump();
    expect(fake.pageScrolls, isNotEmpty);
    expect(fake.pageScrolls.last.$1, 2);
    expect(fake.pageScrolls.last.$2, greaterThan(100));
  });
}
```

- [ ] **Step 3: Run them to see them fail**

Run: `cd liquid_shell && fvm flutter test test/widget/native_search_test.dart`
Expected: failures: `searchPhase` is null, `pages` empty, `searchTexts` empty, events ignored (Task 2 left them as no-ops).

- [ ] **Step 4: Claim commands**

In `native_host.dart`, add to `NativeChromeClaim`:

```dart
  /// Sets the native search text, when this claim owns the chrome.
  void setSearchText(String text) {
    if (!isOwner) return;
    unawaited(LiquidShellPlatform.instance.setNativeSearchText(text));
  }

  /// Activates or deactivates the native search, when this claim owns it.
  void setSearchActive({required bool active}) {
    if (!isOwner) return;
    unawaited(
      LiquidShellPlatform.instance.setNativeSearchActive(active: active),
    );
  }

  /// Sends the top page's scroll offset of [tab], when this claim owns it.
  void setPageScroll({required int tab, required double offset}) {
    if (!isOwner) return;
    unawaited(
      LiquidShellPlatform.instance.setNativePageScroll(tab: tab, offset: offset),
    );
  }
```

- [ ] **Step 5: `ShellSearch`**

`liquid_shell/lib/src/search/shell_search.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/native/native_host.dart';
import 'package:liquid_shell/src/search/search.dart';
import 'package:liquid_shell/src/search/search_controller.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// Keeps a [LiquidSearchController] and the field that shows it in step
/// (spec P3b §8.2): the native field over the claim, or the shell's
/// Flutter field ([editing], [focus]). The controller is the truth; a
/// field's own edits never go back to that field.
final class ShellSearch implements SearchDriver {
  /// Creates the bridge. [claim] is the shell's native claim (null when it
  /// has none); [onChange] rebuilds the shell.
  ShellSearch({required this.claim, required this.onChange}) {
    editing.addListener(_onEditing);
    focus.addListener(_onFocus);
  }

  final NativeChromeClaim? Function() claim;
  final VoidCallback onChange;

  /// The Flutter field's text (fallback, spec §9.4). Lives as long as the
  /// shell, so the field is never rebuilt with a new controller.
  final TextEditingController editing = TextEditingController();

  /// The Flutter field's focus.
  final FocusNode focus = FocusNode(debugLabel: 'LiquidShell search');

  LiquidSearch? _config;
  LiquidSearchController? _controller;
  LiquidSearchController? _internal;
  bool _lastActive = false;
  bool _sentSelected = false;
  bool _writing = false;
  String? _pendingFieldText;

  /// Whether the native field shows the search (native chrome engaged).
  bool native = false;

  /// Whether the search tab is selected (set by the shell's build).
  bool selected = false;

  /// The native field's frame in the Flutter view; zero when not shown.
  Rect field = Rect.zero;

  /// The controller in use; null without a search destination.
  LiquidSearchController? get controller => _controller;

  /// The app's config.
  LiquidSearch? get config => _config;

  /// Follows the shell's `search` parameter. Without one but with a search
  /// destination (a release build that ignored the assert), an internal
  /// controller keeps the field working.
  void configure(LiquidSearch? config, {required bool hasSearchDestination}) {
    _config = config;
    final next =
        config?.controller ??
        (hasSearchDestination ? (_internal ??= LiquidSearchController()) : null);
    if (identical(next, _controller)) return;
    final previous = _controller;
    if (previous != null) {
      previous.removeListener(_onValue);
      detachSearchDriver(previous, this);
    }
    _controller = next;
    if (next != null) {
      attachSearchDriver(next, this);
      next.addListener(_onValue);
      _lastActive = next.isActive;
      _writeField(next.text);
    }
  }

  void _onValue() {
    final active = _controller?.isActive ?? false;
    if (active == _lastActive) return;
    _lastActive = active;
    onChange();
  }

  // --- native → controller --------------------------------------------

  /// A native search event (routed by the shell).
  void onNativeEvent(LiquidNativeEvent event) {
    final controller = _controller;
    if (controller == null) return;
    switch (event) {
      case LiquidNativeSearchTextChanged(:final text, :final composing):
        if (!selected) return;
        final value = controller.value;
        if (value.text == text && value.composing == composing) return;
        applySearchEdit(controller, value.copyWith(text: text, composing: composing));
        _config?.onChanged?.call(text);
      case LiquidNativeSearchActiveChanged(:final active):
        final next = active && selected;
        if (controller.isActive != next) {
          applySearchEdit(controller, controller.value.copyWith(active: next));
        }
      case LiquidNativeSearchSubmitted(:final text):
        if (selected) _config?.onSubmitted?.call(text);
      case LiquidNativeSearchFieldChanged(:final frame):
        if (frame != field) {
          field = frame;
          onChange();
        }
      default:
        break;
    }
  }

  /// After the shell's config went out: entering the search tab restores
  /// the kept query natively (Q2); leaving it ends the active state.
  void afterConfigSent() {
    final controller = _controller;
    final entered = selected && !_sentSelected;
    final left = !selected && _sentSelected;
    _sentSelected = selected;
    if (controller == null) return;
    if (entered && native && controller.text.isNotEmpty) {
      claim()?.setSearchText(controller.text);
    }
    if (left && controller.isActive) {
      applySearchEdit(controller, controller.value.copyWith(active: false));
    }
  }

  // --- the controller's commands (SearchDriver) ------------------------

  @override
  void activate() {
    if (!selected) {
      if (kDebugMode) {
        debugPrint(
          'liquid_shell: LiquidSearchController.activate() ignored: the '
          'search tab is not selected.',
        );
      }
      return;
    }
    if (native) {
      FocusManager.instance.primaryFocus?.unfocus();
      claim()?.setSearchActive(active: true);
    } else {
      focus.requestFocus();
    }
  }

  @override
  void deactivate() {
    if (native) {
      claim()?.setSearchActive(active: false);
    } else {
      focus.unfocus();
    }
  }

  @override
  void textSetByApp(String text) {
    if (native) {
      claim()?.setSearchText(text);
    } else {
      _writeField(text);
    }
  }

  // --- the Flutter field (fallback) --------------------------------------

  /// The ×: clears (a user edit, so onChanged hears it) and unfocuses.
  void cancel() {
    final controller = _controller;
    if (controller != null && controller.text.isNotEmpty) {
      applySearchEdit(controller, controller.value.copyWith(text: '', composing: false));
      _config?.onChanged?.call('');
    }
    _writeField('');
    focus.unfocus();
  }

  /// The keyboard's Search key in the Flutter field.
  void submit(String text) => _config?.onSubmitted?.call(text);

  /// Writes [text] into the Flutter field, never into a composition.
  void _writeField(String text) {
    if (!editing.value.composing.isCollapsed) {
      _pendingFieldText = text;
      return;
    }
    _pendingFieldText = null;
    if (editing.text == text) return;
    _writing = true;
    editing.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _writing = false;
  }

  void _onEditing() {
    if (_writing || native) return;
    final value = editing.value;
    final composing = !value.composing.isCollapsed;
    final pending = _pendingFieldText;
    if (!composing && pending != null) {
      _writeField(pending);
      return;
    }
    final controller = _controller;
    if (controller == null) return;
    if (value.text == controller.text && composing == controller.value.composing) {
      return;
    }
    applySearchEdit(
      controller,
      controller.value.copyWith(text: value.text, composing: composing),
    );
    _config?.onChanged?.call(value.text);
  }

  void _onFocus() {
    if (native) return;
    final controller = _controller;
    if (controller == null) return;
    final active = focus.hasFocus && selected;
    if (controller.isActive != active) {
      applySearchEdit(controller, controller.value.copyWith(active: active));
    }
  }

  /// Releases the controller and the field's resources.
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onValue);
      detachSearchDriver(controller, this);
    }
    _internal?.dispose();
    editing.dispose();
    focus.dispose();
  }
}
```

`package:flutter/services.dart` is needed for `TextEditingValue`/`TextSelection`; `package:flutter/widgets.dart` already re-exports it, so drop that import if the analyzer reports it unnecessary.

- [ ] **Step 6: The shell**

In `liquid_shell.dart`:

Imports: `package:liquid_shell/src/pages/page_registry.dart`, `package:liquid_shell/src/search/search_controller.dart`, `package:liquid_shell/src/search/shell_search.dart`.

Declare `class _LiquidShellState extends State<LiquidShell> implements HideChromeRegistry, PageRegistry {`.

Fields, after `_barSize`:

```dart
  // --- search and pages (spec P3b §8) --------------------------------------
  late final ShellSearch _search = ShellSearch(
    claim: () => _claim,
    onChange: _rebuild,
  );
  final List<_PageRecord> _pageRecords = [];
  final Map<int, List<LiquidNativePage>> _pageStacks = {};
  bool _nativePageBar = false;
  double? _pendingScroll;
  bool _scrollScheduled = false;
  bool _searchDeactivatedForRoute = false;
```

In `initState`, after `_syncClaim();`: `_configureSearch();`. In `didUpdateWidget`, at the end: `_configureSearch();`. In `dispose`, before `super.dispose()`: `_search.dispose();`.

```dart
  void _configureSearch() => _search.configure(
    widget.search,
    hasSearchDestination: searchIndexOf(widget.destinations) != null,
  );
```

Replace the `_onNativeEvent` switch with:

```dart
    switch (event) {
      case LiquidNativeDestinationTapped(:final index):
        // Checked at the boundary: an index from the platform.
        if (index < 0 || index >= widget.destinations.length) return;
        unawaited(_select(index).whenComplete(_resyncNativeAfterFrame));
      case LiquidNativeTrailingTapped():
        widget.tabBarTrailing?.onPressed();
      case LiquidNativeFooterTapped():
        widget.nativeSidebarFooter?.onPressed();
      case LiquidNativeSearchTextChanged() ||
          LiquidNativeSearchActiveChanged() ||
          LiquidNativeSearchSubmitted() ||
          LiquidNativeSearchFieldChanged():
        _search.onNativeEvent(event);
      case LiquidNativeBackTapped(:final tab):
        _onNativeBack(tab);
      case LiquidNativeStateChanged() || LiquidWindowControlsChanged():
        break;
    }
```

Pages:

```dart
  // --- pages (PageRegistry) -----------------------------------------------

  @override
  PageHandle registerPage(PageEntry entry) {
    final record = _PageRecord(this, entry);
    _pageRecords.add(record);
    _rebuild();
    return record;
  }

  /// The page the user sees in the selected tab, if it is a LiquidPage.
  PageEntry? get _topPageEntry {
    PageEntry? top;
    for (final record in _pageRecords) {
      final entry = record.entry;
      if (entry.isTop && (top == null || entry.sequence > top.sequence)) {
        top = entry;
      }
    }
    return top;
  }

  List<LiquidNativePage> _currentStack() => [
    for (final entry in pageStackFor(
      _pageRecords.map((r) => r.entry),
      isTop: (e) => e.isTop,
    ))
      LiquidNativePage(title: entry.title, largeTitle: entry.largeTitle),
  ];

  /// The native back button (spec P3b §7.6): a proposal for the selected
  /// tab's top page. `maybePop` runs its PopScope.
  void _onNativeBack(int tab) {
    if (tab != resolveSelectedIndex(widget.selectedIndex, widget.destinations.length)) {
      return;
    }
    unawaited(_topPageEntry?.navigator?.maybePop());
  }

  void _onPageScroll(_PageRecord record, double offset) {
    if (!_nativePageBar || !identical(record.entry, _topPageEntry)) return;
    _pendingScroll = offset;
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      final value = _pendingScroll;
      if (!mounted || value == null) return;
      _claim?.setPageScroll(
        tab: resolveSelectedIndex(widget.selectedIndex, widget.destinations.length),
        offset: value,
      );
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }
```

and at the end of the file:

```dart
/// One `LiquidPage` registered with a shell.
final class _PageRecord implements PageHandle {
  _PageRecord(this._shell, this.entry);

  final _LiquidShellState _shell;
  PageEntry entry;

  @override
  void update(PageEntry next) {
    if (next.sameAs(entry)) return;
    entry = next;
    _shell._rebuild();
  }

  @override
  void scrolled(double offset) => _shell._onPageScroll(this, offset);

  @override
  void unregister() {
    _shell._pageRecords.remove(this);
    if (_shell.mounted) _shell._rebuild();
  }
}
```

In `_scheduleNativeSend`'s post-frame callback, after `_claim?.update(latest, force: force);`, add `_search.afterConfigSent();` (inside the `if (mounted && latest != null)` branch, as a block).

In `_resolveNative`, after `final selected = resolveSelectedIndex(…);`:

```dart
    final searchIndex = searchIndexOf(widget.destinations);
    _search
      ..native = engaged
      ..selected = searchIndex != null && selected == searchIndex;
    _nativePageBar = nativePageBarFor(
      engaged: engaged,
      selected: selected,
      searchIndex: searchIndex,
    );
    if (_nativePageBar) _pageStacks[selected] = _currentStack();
    final searchActive = _search.controller?.isActive ?? false;
    // A dialog or sheet above an active search: the keyboard and the field
    // would sit above its barrier (spec §7.10). Once per covering.
    if (_routeCurrent) {
      _searchDeactivatedForRoute = false;
    } else if (engaged && searchActive && !_searchDeactivatedForRoute) {
      _searchDeactivatedForRoute = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _search.deactivate();
      });
    }
```

Pass `pageStacks: _pageStacks,` to `nativeConfigFor(…)`.

Replace `final insets = nativeChromeInsets(kind: kind, padding: media.padding);` with:

```dart
    var insets = nativeChromeInsets(kind: kind, padding: media.padding);
    if (_search.selected) {
      // The iPhone field above the keyboard is not in the safe area.
      insets = insets.copyWith(
        bottom: math.max(
          insets.bottom,
          nativeSearchBottomInset(
            field: _search.field,
            size: media.size,
            padding: media.padding,
            viewInsets: media.viewInsets,
            active: searchActive,
          ),
        ),
      );
    }
```

In the engaged `ShellScopeMarker(…)`: add `pages: this, strings: widget.strings,`, and in its `LiquidShellScopeData(…)`:

```dart
          searchPhase: searchIndex == null
              ? null
              : searchPhaseFor(
                  selected: selected,
                  searchIndex: searchIndex,
                  active: searchActive,
                ),
          nativePageBar: _nativePageBar,
          // UIKit's top bar, sidebar and navigation bars make room for the
          // cluster; the compact bar is at the bottom (spec P2 §8.3, P3b §7.9).
          windowControls:
              (engaged && sizeClass == LiquidSizeClass.regular) || _nativePageBar
              ? LiquidWindowControls.zero
              : _windowControls.value.value,
```

In `_buildLayout` (Flutter path), after `final selected = …`:

```dart
    final searchIndex = searchIndexOf(widget.destinations);
    _search
      ..native = false
      ..selected = searchIndex != null && selected == searchIndex;
    _nativePageBar = false;
```

and in its `ShellScopeMarker(…)` add `pages: this, strings: widget.strings,` and in its data:

```dart
          searchPhase: searchIndex == null
              ? null
              : searchPhaseFor(
                  selected: selected,
                  searchIndex: searchIndex,
                  active: _search.controller?.isActive ?? false,
                ),
```

`LiquidNoChrome` keeps its `ShellScopeMarker(…)` unchanged (no pages, default strings).

- [ ] **Step 7: Run the tests**

Run: `cd liquid_shell && fvm flutter test --exclude-tags golden`
Expected: all pass, P2's native tests included.

- [ ] **Step 8: Commit**

```bash
bash .githooks/pre-commit
git add liquid_shell/lib/src/search/shell_search.dart liquid_shell/lib/src/native/native_host.dart \
  liquid_shell/lib/src/shell/liquid_shell.dart liquid_shell/test/helpers/fake_native_platform.dart \
  liquid_shell/test/helpers/shell_harness.dart liquid_shell/test/widget/native_chrome_test.dart \
  liquid_shell/test/widget/native_search_test.dart
git commit -m "feat(shell): the shell drives the native search tab, its query and its pages (VK-407)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: The Flutter fallback: compact morph, regular top field, scope bar

**Files:**
- Modify: `liquid_shell/lib/src/search/search_layout.dart` (fallback geometry)
- Create: `liquid_shell/lib/src/search/search_chrome.dart`
- Create: `liquid_shell/lib/src/search/scope_bar.dart`
- Modify: `liquid_shell/lib/src/shell/chrome_builder.dart` (`LiquidChromeSlot.searchField`, `LiquidSearchChromeDetails`)
- Modify: `liquid_shell/lib/src/shell/liquid_shell.dart` (Flutter path)
- Modify: `liquid_shell/lib/liquid_shell.dart`
- Test: `liquid_shell/test/unit/search_test.dart`, `liquid_shell/test/widget/search_fallback_test.dart` (new)

**Interfaces:**
- Consumes: Task 6 (phase, controller), Task 8 (`ShellSearch.editing`, `.focus`, `.cancel()`, `.submit()`).
- Produces:
  - `search_layout.dart`: `kSearchMorphDuration` (350 ms), `kSearchMorphCurve` (`Curves.easeOutCubic`), `kSearchCompactExtent` (48), `kSearchSelectedMargin` (28), `kSearchSelectedGap` (12), `kRegularSearchFieldExtent` (44), `kRegularSearchMargin` (20), `class CompactSearchRects { circle, field, cancel }`, `CompactSearchRects compactSearchRects({required LiquidSearchPhase phase, required Size size, required double rowBottom, required double rowExtent, required double margin, required double keyboard, required TextDirection direction})`, `double regularSearchFieldTop({required LiquidSearchPhase phase, required double paddingTop, required double barExtent, required bool tiled})`
  - `search_chrome.dart`: `kSearchFieldKey`, `kSearchCollapsedKey`, `kSearchCancelKey` (`ValueKey<String>`s), `CompactSearchChrome`, `SearchFieldGlass`
  - `LiquidSearchScopeBar({required LiquidSearchController controller, required List<String> scopes})` (exported)
  - `LiquidChromeSlot.searchField`; `LiquidChromeDetails.search` (`LiquidSearchChromeDetails?`: `phase`, `controller`, `previousIndex`, `selectSearch`) (exported)

- [ ] **Step 1: Write the failing geometry tests**

Append to `liquid_shell/test/unit/search_test.dart`'s `main()`:

```dart
  group('fallback geometry', () {
    const size = Size(393, 852);
    // P1's bottom row: 62pt pill, 21pt gap above the screen edge.
    const rowBottom = 852.0 - 21;

    CompactSearchRects rects(
      LiquidSearchPhase phase, {
      double keyboard = 0,
      TextDirection direction = TextDirection.ltr,
    }) => compactSearchRects(
      phase: phase,
      size: size,
      rowBottom: rowBottom,
      rowExtent: 62,
      margin: 16,
      keyboard: keyboard,
      direction: direction,
    );

    test('idle: the ⌕ circle at the trailing end of the row', () {
      expect(
        rects(LiquidSearchPhase.idle).field,
        const Rect.fromLTWH(393 - 16 - 62, rowBottom - 62, 62, 62),
      );
    });

    test('selected: circle at 28, field from 88 to 28 from the end', () {
      final r = rects(LiquidSearchPhase.selected);
      expect(r.circle, const Rect.fromLTWH(28, rowBottom - 62 + 7, 48, 48));
      expect(
        r.field,
        const Rect.fromLTRB(88, rowBottom - 62 + 7, 393 - 28, rowBottom - 62 + 55),
      );
    });

    test('active: field and × 8pt above the keyboard', () {
      final r = rects(LiquidSearchPhase.active, keyboard: 336);
      const bottom = 852.0 - 336 - 8;
      expect(r.field, const Rect.fromLTRB(8, bottom - 48, 393 - 8 - 48 - 8, bottom));
      expect(r.cancel, const Rect.fromLTWH(393 - 8 - 48, bottom - 48, 48, 48));
    });

    test('active without a software keyboard stays in the row', () {
      final r = rects(LiquidSearchPhase.active);
      expect(r.field.bottom, rowBottom - 62 + 55);
    });

    test('RTL mirrors every rect', () {
      final ltr = rects(LiquidSearchPhase.selected);
      final rtl = rects(LiquidSearchPhase.selected, direction: TextDirection.rtl);
      expect(rtl.circle.left, 393 - ltr.circle.right);
      expect(rtl.field.right, 393 - ltr.field.left);
    });

    test('regular field top: one row below the bar, the bar row when active', () {
      expect(
        regularSearchFieldTop(
          phase: LiquidSearchPhase.selected,
          paddingTop: 24,
          barExtent: 52,
          tiled: false,
        ),
        24 + 20 + 52 + 8,
      );
      expect(
        regularSearchFieldTop(
          phase: LiquidSearchPhase.active,
          paddingTop: 24,
          barExtent: 52,
          tiled: false,
        ),
        24 + 20,
      );
      expect(
        regularSearchFieldTop(
          phase: LiquidSearchPhase.selected,
          paddingTop: 24,
          barExtent: 52,
          tiled: true,
        ),
        24 + 54,
      );
      expect(
        regularSearchFieldTop(
          phase: LiquidSearchPhase.active,
          paddingTop: 24,
          barExtent: 52,
          tiled: true,
        ),
        24 + 5,
      );
    });
  });
```

- [ ] **Step 2: Write the failing widget tests**

`liquid_shell/test/widget/search_fallback_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/search/search_chrome.dart';

import '../helpers/shell_harness.dart';

const _destinations = [
  LiquidDestination(icon: Icon(Icons.home), label: 'Home'),
  LiquidDestination(icon: Icon(Icons.book), label: 'Library'),
  LiquidDestination(
    icon: Icon(Icons.search),
    label: 'Search',
    role: LiquidDestinationRole.search,
  ),
];

const _rowBottom = 852.0 - 21;

Future<(LiquidSearchController, List<int>, List<String>)> _pump(
  WidgetTester tester, {
  Size size = kPhone,
  int initialIndex = 0,
  TextDirection direction = TextDirection.ltr,
  TargetPlatform platform = TargetPlatform.iOS,
  LiquidChromeBuilder? chromeBuilder,
}) async {
  final controller = LiquidSearchController();
  addTearDown(controller.dispose);
  final selections = <int>[];
  final changes = <String>[];
  await pumpShell(
    tester,
    TestShell(
      destinations: _destinations,
      initialIndex: initialIndex,
      selections: selections,
      chromeBuilder: chromeBuilder,
      search: LiquidSearch(controller: controller, onChanged: changes.add),
    ),
    size: size,
    direction: direction,
    platform: platform,
  );
  return (controller, selections, changes);
}

Rect _rect(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

double _opacity(WidgetTester tester, Key key) => tester
    .widget<AnimatedOpacity>(
      find.descendant(of: find.byKey(key), matching: find.byType(AnimatedOpacity)).first,
    )
    .opacity;

void main() {
  testWidgets('idle: the pill without Search, and a separate ⌕ circle', (
    tester,
  ) async {
    await _pump(tester);
    final bar = tester.widget<LiquidTabBar>(find.byType(LiquidTabBar));
    expect(bar.destinations.map((d) => d.label), ['Home', 'Library']);
    expect(
      _rect(tester, kSearchFieldKey),
      const Rect.fromLTWH(393 - 16 - 62, _rowBottom - 62, 62, 62),
    );
    expect(find.bySemanticsLabel('Search'), findsOneWidget);
    expect(scopeOf(tester).searchPhase, LiquidSearchPhase.idle);
  });

  testWidgets('tap ⌕: the search tab is selected, the field is not focused', (
    tester,
  ) async {
    final (_, selections, _) = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Search'));
    await tester.pumpAndSettle();
    expect(selections, [2]);
    expect(
      _rect(tester, kSearchFieldKey),
      const Rect.fromLTRB(88, _rowBottom - 55, 393 - 28, _rowBottom - 7),
    );
    expect(
      _rect(tester, kSearchCollapsedKey),
      const Rect.fromLTWH(28, _rowBottom - 55, 48, 48),
    );
    expect(_opacity(tester, kSearchCollapsedKey), 1);
    expect(find.bySemanticsLabel('Home'), findsWidgets, reason: 'the previous tab');
    expect(tester.testTextInput.isVisible, isFalse);
    expect(scopeOf(tester, 'Search').searchPhase, LiquidSearchPhase.selected);
  });

  testWidgets('tap the field: active above the keyboard with ×', (tester) async {
    final (controller, _, changes) = await _pump(tester, initialIndex: 2);
    await tester.tap(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(controller.isActive, isTrue);
    const bottom = 852.0 - 336 - 8;
    expect(
      _rect(tester, kSearchFieldKey),
      const Rect.fromLTRB(8, bottom - 48, 393 - 64, bottom),
    );
    expect(_rect(tester, kSearchCancelKey), const Rect.fromLTWH(393 - 56, bottom - 48, 48, 48));
    expect(_opacity(tester, kSearchCollapsedKey), 0);
    expect(scopeOf(tester, 'Search').chromeInsets.bottom, 852 - (bottom - 48) + 8);
    await tester.enterText(find.byType(TextField), 'ho');
    await tester.pump();
    expect(controller.text, 'ho');
    expect(changes, ['ho']);
  });

  testWidgets('× clears and unfocuses: back to selected', (tester) async {
    final (controller, _, changes) = await _pump(tester, initialIndex: 2);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'ho');
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Cancel search'));
    await tester.pumpAndSettle();
    expect(controller.text, '');
    expect(controller.isActive, isFalse);
    expect(changes.last, '');
    expect(scopeOf(tester, 'Search').searchPhase, LiquidSearchPhase.selected);
  });

  testWidgets('the collapsed circle returns to the previous tab', (
    tester,
  ) async {
    final (_, selections, _) = await _pump(tester, initialIndex: 1);
    await tester.tap(find.bySemanticsLabel('Search'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kSearchCollapsedKey));
    await tester.pumpAndSettle();
    expect(selections, [2, 1]);
  });

  testWidgets('the field is never rebuilt across phases', (tester) async {
    await _pump(tester, initialIndex: 2);
    final selected = tester.element(find.byType(TextField));
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(identical(tester.element(find.byType(TextField)), selected), isTrue);
    await tester.tap(find.bySemanticsLabel('Cancel search'));
    await tester.pumpAndSettle();
    expect(identical(tester.element(find.byType(TextField)), selected), isTrue);
  });

  testWidgets('an app write waits for the IME composition to end', (
    tester,
  ) async {
    final (controller, _, _) = await _pump(tester, initialIndex: 2);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    field.controller!.value = const TextEditingValue(
      text: 'hoo',
      composing: TextRange(start: 0, end: 3),
    );
    await tester.pump();
    expect(controller.value.composing, isTrue);
    controller.text = 'phố';
    expect(field.controller!.text, 'hoo', reason: 'never written into a composition');
    field.controller!.value = const TextEditingValue(text: 'hồ');
    await tester.pump();
    expect(field.controller!.text, 'phố', reason: 'applied once it ended');
  });

  testWidgets('regular: the field below the bar; active, it takes the bar row', (
    tester,
  ) async {
    final (controller, _, _) = await _pump(
      tester,
      size: kTabletPortrait,
      initialIndex: 2,
    );
    final selectedTop = _rect(tester, kSearchFieldKey).top;
    expect(selectedTop, 59 + 20 + 52 + 8);
    expect(_rect(tester, kSearchFieldKey).height, 44);
    expect(scopeOf(tester, 'Search').chromeInsets.top, selectedTop + 44 + 8);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(controller.isActive, isTrue);
    expect(_rect(tester, kSearchFieldKey).top, 59 + 20);
    final barOpacity = tester
        .widgetList<AnimatedOpacity>(
          find.ancestor(of: find.byType(LiquidTabBar), matching: find.byType(AnimatedOpacity)),
        )
        .first
        .opacity;
    expect(barOpacity, 0);
  });

  testWidgets('Android back deactivates instead of popping', (tester) async {
    final (controller, _, _) = await _pump(
      tester,
      initialIndex: 2,
      platform: TargetPlatform.android,
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(controller.isActive, isFalse);
    expect(find.byType(LiquidShell), findsOneWidget);
  });

  testWidgets('Esc deactivates', (tester) async {
    final (controller, _, _) = await _pump(tester, initialIndex: 2);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(controller.isActive, isFalse);
  });

  testWidgets('reduce motion: the morph is instant', (tester) async {
    await _pump(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Search'));
    await tester.pump();
    await tester.pump();
    expect(
      _rect(tester, kSearchFieldKey),
      const Rect.fromLTRB(88, _rowBottom - 55, 393 - 28, _rowBottom - 7),
    );
  });

  testWidgets('RTL: the collapsed circle is on the right', (tester) async {
    await _pump(tester, initialIndex: 2, direction: TextDirection.rtl);
    expect(_rect(tester, kSearchCollapsedKey).right, 393 - 28);
  });

  testWidgets('a chromeBuilder gets the searchField slot with the phase', (
    tester,
  ) async {
    final seen = <LiquidSearchPhase?>[];
    await _pump(
      tester,
      initialIndex: 2,
      chromeBuilder: (context, details, chrome) {
        if (details.slot == LiquidChromeSlot.searchField) {
          seen.add(details.search?.phase);
        }
        return chrome;
      },
    );
    expect(seen, contains(LiquidSearchPhase.selected));
  });

  testWidgets('LiquidSearchScopeBar selects a scope', (tester) async {
    final controller = LiquidSearchController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiquidSearchScopeBar(
            controller: controller,
            scopes: const ['All', 'Songs', 'Places'],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Places'));
    await tester.pump();
    expect(controller.scopeIndex, 2);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Places')),
      containsSemantics(isButton: true, isSelected: true, hasTapAction: true, label: 'Places'),
    );
  });
}
```

- [ ] **Step 3: Run them to see them fail**

Run: `cd liquid_shell && fvm flutter test test/unit/search_test.dart test/widget/search_fallback_test.dart`
Expected: compile errors: `compactSearchRects`, `kSearchFieldKey`, `LiquidSearchScopeBar`, `LiquidChromeSlot.searchField` undefined.

- [ ] **Step 4: Geometry**

Append to `search_layout.dart` (`Curves` comes with `package:flutter/widgets.dart`, already imported):

```dart
/// The fallback morph (Q12).
const Duration kSearchMorphDuration = Duration(milliseconds: 350);

/// The fallback morph's curve (Q12).
const Curve kSearchMorphCurve = Curves.easeOutCubic;

/// The compact collapsed circle, field and × height (iOS 26: 48).
const double kSearchCompactExtent = 48;

/// Selected: the collapsed circle's start and the field's end margin.
const double kSearchSelectedMargin = 28;

/// Selected: the gap between the collapsed circle and the field.
const double kSearchSelectedGap = 12;

/// The regular field's height (iPad: 44).
const double kRegularSearchFieldExtent = 44;

/// The regular field's side margins (iPad: 20).
const double kRegularSearchMargin = 20;

/// Where the compact search parts are (spec P3b §9.2).
@immutable
class CompactSearchRects {
  /// Creates the rects.
  const CompactSearchRects({
    required this.circle,
    required this.field,
    required this.cancel,
  });

  /// The collapsed circle (previous tab).
  final Rect circle;

  /// The ⌕ circle (idle) or the field.
  final Rect field;

  /// The × circle.
  final Rect cancel;

  @override
  bool operator ==(Object other) =>
      other is CompactSearchRects &&
      other.circle == circle &&
      other.field == field &&
      other.cancel == cancel;

  @override
  int get hashCode => Object.hash(circle, field, cancel);
}

/// The compact parts for [phase]: the bottom row ends at [rowBottom] and is
/// [rowExtent] tall (P1's pill); [keyboard] is the software keyboard's
/// height (0 with a hardware keyboard).
CompactSearchRects compactSearchRects({
  required LiquidSearchPhase phase,
  required Size size,
  required double rowBottom,
  required double rowExtent,
  required double margin,
  required double keyboard,
  required TextDirection direction,
}) {
  final width = size.width;
  final rowTop = rowBottom - rowExtent;
  final top = rowTop + (rowExtent - kSearchCompactExtent) / 2;
  final circle = Rect.fromLTWH(
    kSearchSelectedMargin,
    top,
    kSearchCompactExtent,
    kSearchCompactExtent,
  );
  final selectedField = Rect.fromLTRB(
    kSearchSelectedMargin + kSearchCompactExtent + kSearchSelectedGap,
    top,
    width - kSearchSelectedMargin,
    top + kSearchCompactExtent,
  );
  final activeBottom = keyboard > 0
      ? size.height - keyboard - kSearchFieldGap
      : top + kSearchCompactExtent;
  final (collapsed, field, cancel) = switch (phase) {
    LiquidSearchPhase.idle => (
      Rect.fromLTWH(margin, top, kSearchCompactExtent, kSearchCompactExtent),
      Rect.fromLTWH(width - margin - rowExtent, rowTop, rowExtent, rowExtent),
      Rect.fromLTWH(width - margin - kSearchCompactExtent, top, kSearchCompactExtent, kSearchCompactExtent),
    ),
    LiquidSearchPhase.selected => (
      circle,
      selectedField,
      Rect.fromLTWH(selectedField.right - kSearchCompactExtent, top, kSearchCompactExtent, kSearchCompactExtent),
    ),
    LiquidSearchPhase.active => (
      circle,
      Rect.fromLTRB(
        kSearchFieldGap,
        activeBottom - kSearchCompactExtent,
        width - 2 * kSearchFieldGap - kSearchCompactExtent,
        activeBottom,
      ),
      Rect.fromLTWH(
        width - kSearchFieldGap - kSearchCompactExtent,
        activeBottom - kSearchCompactExtent,
        kSearchCompactExtent,
        kSearchCompactExtent,
      ),
    ),
  };
  Rect place(Rect r) => direction == TextDirection.rtl
      ? Rect.fromLTRB(width - r.right, r.top, width - r.left, r.bottom)
      : r;
  return CompactSearchRects(
    circle: place(collapsed),
    field: place(field),
    cancel: place(cancel),
  );
}

/// The regular field's top (spec P3b §9.3): one row below the Flutter top
/// bar (or 54pt below the safe top beside a tiled sidebar); active, the bar
/// row itself.
double regularSearchFieldTop({
  required LiquidSearchPhase phase,
  required double paddingTop,
  required double barExtent,
  required bool tiled,
}) {
  final active = phase == LiquidSearchPhase.active;
  if (tiled) return paddingTop + (active ? 5 : 54);
  return active
      ? paddingTop + kTopBarGap
      : paddingTop + kTopBarGap + barExtent + kSearchFieldGap;
}
```

Add `import 'package:liquid_shell/src/shell/shell_layout.dart';` at the top of `search_layout.dart` for `kTopBarGap`.

- [ ] **Step 5: The chrome slot and its details**

In `chrome_builder.dart`, import `package:liquid_shell/src/search/search_controller.dart`; add to `LiquidChromeSlot`:

```dart
  /// The search field (fallback): the ⌕ circle that becomes the field at
  /// compact width, the field below the top bar at regular width.
  searchField,
```

add before `LiquidChromeDetails`:

```dart
/// The search part of [LiquidChromeDetails].
@immutable
class LiquidSearchChromeDetails {
  /// Creates the details.
  const LiquidSearchChromeDetails({
    required this.phase,
    required this.controller,
    required this.previousIndex,
    required this.selectSearch,
  });

  /// The search phase.
  final LiquidSearchPhase phase;

  /// The app's controller.
  final LiquidSearchController controller;

  /// The destination the collapsed circle returns to.
  final int previousIndex;

  /// Selects the search tab through the guard.
  final VoidCallback selectSearch;

  @override
  bool operator ==(Object other) =>
      other is LiquidSearchChromeDetails &&
      other.phase == phase &&
      identical(other.controller, controller) &&
      other.previousIndex == previousIndex &&
      other.selectSearch == selectSearch;

  @override
  int get hashCode => Object.hash(phase, controller, previousIndex, selectSearch);
}
```

and to `LiquidChromeDetails`: the optional constructor parameter `this.search,`, the field `/// The shell's search, when it has a search tab. final LiquidSearchChromeDetails? search;`, `other.search == search &&` in `==`, `search` in `hashCode`.

- [ ] **Step 6: The field and the compact chrome**

`liquid_shell/lib/src/search/search_chrome.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_shell/src/destinations/destination.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';
import 'package:liquid_shell/src/search/search_controller.dart';
import 'package:liquid_shell/src/search/search_layout.dart';
import 'package:liquid_shell/src/shell/strings.dart';

/// The fallback field (or the idle ⌕ circle).
const kSearchFieldKey = ValueKey<String>('liquid-search-field');

/// The fallback collapsed circle (previous tab).
const kSearchCollapsedKey = ValueKey<String>('liquid-search-collapsed');

/// The fallback × circle.
const kSearchCancelKey = ValueKey<String>('liquid-search-cancel');

const _capsule = BorderRadius.all(Radius.circular(999));

/// The fallback search field on glass (spec P3b §9.4). The `TextField` is
/// the first child of the same chain in every phase, so a phase change
/// never rebuilds it; in idle it is invisible and a ⌕ glyph takes taps.
class SearchFieldGlass extends StatelessWidget {
  /// Creates the field.
  const SearchFieldGlass({
    required this.phase,
    required this.editing,
    required this.focus,
    required this.placeholder,
    required this.searchLabel,
    required this.searchIcon,
    required this.onOpen,
    required this.onSubmitted,
    required this.onDeactivate,
    this.inlineCancel,
    super.key,
  });

  final LiquidSearchPhase phase;
  final TextEditingController editing;
  final FocusNode focus;
  final String placeholder;

  /// The search destination's label: the idle circle's semantics.
  final String searchLabel;

  /// The search destination's icon: the idle circle's glyph.
  final Widget searchIcon;

  /// Idle tap: select the search tab.
  final VoidCallback onOpen;
  final ValueChanged<String> onSubmitted;

  /// Esc.
  final VoidCallback onDeactivate;

  /// Regular layout: an × inside the field while active.
  final VoidCallback? inlineCancel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final idle = phase == LiquidSearchPhase.idle;
    final cancel = inlineCancel;
    return LiquidGlass(
      borderRadius: _capsule,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                ignoring: idle,
                child: ExcludeSemantics(
                  excluding: idle,
                  child: Opacity(
                    opacity: idle ? 0 : 1,
                    child: Row(
                      children: [
                        const SizedBox(width: 14),
                        Icon(Icons.search, size: 20, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CallbackShortcuts(
                            bindings: {
                              const SingleActivator(LogicalKeyboardKey.escape):
                                  onDeactivate,
                            },
                            child: TextField(
                              controller: editing,
                              focusNode: focus,
                              textInputAction: TextInputAction.search,
                              onSubmitted: onSubmitted,
                              decoration: InputDecoration.collapsed(
                                hintText: placeholder,
                              ),
                            ),
                          ),
                        ),
                        if (cancel != null && phase == LiquidSearchPhase.active)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: MaterialLocalizations.of(context).cancelButtonLabel,
                            onPressed: cancel,
                          )
                        else
                          const SizedBox(width: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (idle)
              Positioned.fill(
                child: Semantics(
                  container: true,
                  button: true,
                  label: searchLabel,
                  onTap: onOpen,
                  excludeSemantics: true,
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: onOpen,
                    child: Center(
                      child: IconTheme.merge(
                        data: IconThemeData(size: 26, color: scheme.onSurfaceVariant),
                        child: searchIcon,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The compact search row (spec P3b §9.2): the pill (built by the shell),
/// the collapsed circle, the field and ×, each animating between the
/// phase's rects. Empty areas pass touches to the body.
class CompactSearchChrome extends StatelessWidget {
  /// Creates the row.
  const CompactSearchChrome({
    required this.phase,
    required this.rects,
    required this.pill,
    required this.previous,
    required this.onPrevious,
    required this.field,
    required this.onCancel,
    required this.strings,
    super.key,
  });

  final LiquidSearchPhase phase;
  final CompactSearchRects rects;

  /// The pill of the other destinations: a `Positioned`, faded by the shell.
  final Widget pill;

  /// The destination the collapsed circle returns to.
  final LiquidDestination previous;
  final VoidCallback onPrevious;

  /// The field (a `SearchFieldGlass`, possibly wrapped by a chrome builder).
  final Widget field;
  final VoidCallback onCancel;
  final LiquidShellStrings strings;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : kSearchMorphDuration;
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    Widget part(Key key, Rect rect, {required bool shown, required Widget child}) =>
        AnimatedPositioned.fromRect(
          key: key,
          rect: rect,
          duration: duration,
          curve: kSearchMorphCurve,
          child: IgnorePointer(
            ignoring: !shown,
            child: ExcludeSemantics(
              excluding: !shown,
              child: AnimatedOpacity(
                opacity: shown ? 1 : 0,
                duration: duration,
                curve: kSearchMorphCurve,
                child: child,
              ),
            ),
          ),
        );
    Widget circle({required String label, required VoidCallback onTap, required Widget icon}) =>
        Semantics(
          container: true,
          button: true,
          label: label,
          onTap: onTap,
          excludeSemantics: true,
          child: Tooltip(
            message: label,
            excludeFromSemantics: true,
            child: LiquidGlass(
              borderRadius: _capsule,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onTap,
                  child: Center(
                    child: IconTheme.merge(
                      data: IconThemeData(size: 24, color: color),
                      child: icon,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
    return Positioned.fill(
      child: Stack(
        children: [
          pill,
          part(
            kSearchCollapsedKey,
            rects.circle,
            shown: phase == LiquidSearchPhase.selected,
            child: circle(
              label: previous.label,
              onTap: onPrevious,
              icon: previous.selectedIcon ?? previous.icon,
            ),
          ),
          AnimatedPositioned.fromRect(
            key: kSearchFieldKey,
            rect: rects.field,
            duration: duration,
            curve: kSearchMorphCurve,
            child: field,
          ),
          part(
            kSearchCancelKey,
            rects.cancel,
            shown: phase == LiquidSearchPhase.active,
            child: circle(
              label: strings.cancelSearch,
              onTap: onCancel,
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: The scope bar**

`liquid_shell/lib/src/search/scope_bar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';
import 'package:liquid_shell/src/search/search_controller.dart';

/// A glass segmented control for search scopes ("All | Songs | Places"),
/// bound to [controller]'s `scopeIndex` (spec P3b §4.4, Q5). Place it at
/// the top of the search page's content while the search is active.
class LiquidSearchScopeBar extends StatelessWidget {
  /// Creates the bar.
  const LiquidSearchScopeBar({
    required this.controller,
    required this.scopes,
    super.key,
  });

  /// The search controller.
  final LiquidSearchController controller;

  /// Scope titles, at least two.
  final List<String> scopes;

  @override
  Widget build(BuildContext context) {
    assert(scopes.length >= 2, 'LiquidSearchScopeBar needs two scopes or more.');
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ValueListenableBuilder<LiquidSearchValue>(
      valueListenable: controller,
      builder: (context, value, _) => LiquidGlass(
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              for (final (i, title) in scopes.indexed)
                Expanded(
                  child: Semantics(
                    container: true,
                    button: true,
                    selected: value.scopeIndex == i,
                    label: title,
                    onTap: () => controller.scopeIndex = i,
                    excludeSemantics: true,
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: const BorderRadius.all(Radius.circular(999)),
                        onTap: () => controller.scopeIndex = i,
                        child: AnimatedContainer(
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 200),
                          constraints: const BoxConstraints(minHeight: 36),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: value.scopeIndex == i
                                ? scheme.primaryContainer
                                : Colors.transparent,
                            borderRadius: const BorderRadius.all(Radius.circular(999)),
                          ),
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: value.scopeIndex == i
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 8: The shell's Flutter path**

In `liquid_shell.dart`, import `search_chrome.dart`; add the field `int _previousIndex = 0;`.

In `_buildLayout`, after the Task 8 lines that set `_search.selected`:

```dart
    if (searchIndex == null || selected != searchIndex) _previousIndex = selected;
    final phase = searchIndex == null
        ? null
        : searchPhaseFor(
            selected: selected,
            searchIndex: searchIndex,
            active: _search.controller?.isActive ?? false,
          );
    final searchDestination = searchIndex == null
        ? null
        : widget.destinations[searchIndex];
    LiquidSearchChromeDetails? searchDetails() => phase == null
        ? null
        : LiquidSearchChromeDetails(
            phase: phase,
            controller: _search.controller!,
            previousIndex: _previousIndex,
            selectSearch: () => _onSelect(searchIndex!),
          );
    Widget searchField({VoidCallback? inlineCancel}) => SearchFieldGlass(
      phase: phase!,
      editing: _search.editing,
      focus: _search.focus,
      placeholder: widget.search?.placeholder ?? widget.strings.searchPlaceholder,
      searchLabel: searchDestination!.label,
      searchIcon: searchDestination.icon,
      onOpen: () => _onSelect(searchIndex!),
      onSubmitted: _search.submit,
      onDeactivate: _search.deactivate,
      inlineCancel: inlineCancel,
    );
```

Pass `search: searchDetails(),` in the `details(…)` helper's `LiquidChromeDetails(…)`.

In the `LiquidChromeKind.bottomBar` case, when `phase != null`, add this instead of P1's `Positioned` (the `else` keeps P1's code unchanged):

```dart
        if (phase != null) {
          final narrow = size.width < kLiquidNarrowWidth;
          final margin = narrow ? _kNarrowBarMargin : _kBarMargin;
          final rowExtent = _measured[barKey] ?? kBottomPillExtent;
          final rects = compactSearchRects(
            phase: phase,
            size: size,
            rowBottom: size.height - bottomGap,
            rowExtent: rowExtent,
            margin: margin,
            keyboard: media.viewInsets.bottom,
            direction: Directionality.of(context),
          );
          final morph = MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : kSearchMorphDuration;
          final others = widget.destinations.sublist(0, searchIndex);
          children.add(
            CompactSearchChrome(
              phase: phase,
              rects: rects,
              pill: Positioned(
                left: margin,
                right: margin + rowExtent + kLiquidTabBarTrailingGap,
                bottom: bottomGap,
                child: IgnorePointer(
                  ignoring: phase != LiquidSearchPhase.idle,
                  child: AnimatedOpacity(
                    opacity: phase == LiquidSearchPhase.idle ? 1 : 0,
                    duration: morph,
                    curve: kSearchMorphCurve,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      heightFactor: 1,
                      child: measured(
                        slot(
                          details(LiquidChromeSlot.tabBar),
                          LiquidTabBar(
                            destinations: others,
                            selectedIndex: phase == LiquidSearchPhase.idle
                                ? selected
                                : _previousIndex,
                            onDestinationSelected: _onSelect,
                            strings: widget.strings,
                            narrow: narrow,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              previous: widget.destinations[_previousIndex],
              onPrevious: () => _onSelect(_previousIndex),
              field: slot(details(LiquidChromeSlot.searchField), searchField()),
              onCancel: _search.cancel,
              strings: widget.strings,
            ),
          );
          break;
        }
```

(`break` ends the switch case; P1's existing `children.add(Positioned(…))` follows unchanged for shells without search.)

In the `topBar || sidebarOverlay` case, when `phase != null`, wrap the `measured(slot(…))` child of that `Positioned` as:

```dart
            child: IgnorePointer(
              ignoring: phase == LiquidSearchPhase.active,
              child: AnimatedOpacity(
                opacity: phase == LiquidSearchPhase.active ? 0 : 1,
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                child: measured(/* … unchanged … */),
              ),
            ),
```

(use a local `Widget bar = measured(…); if (phase != null) bar = IgnorePointer(…AnimatedOpacity(child: bar));` so shells without search keep P1's exact tree).

After the `switch (kind)`, before the overlay barrier, add the regular field:

```dart
    final regularField =
        phase != null &&
        phase != LiquidSearchPhase.idle &&
        kind != LiquidChromeKind.bottomBar &&
        kind != LiquidChromeKind.hidden;
    if (regularField) {
      final fieldTop = regularSearchFieldTop(
        phase: phase,
        paddingTop: media.padding.top,
        barExtent: _measured[barKey] ?? kTopPillExtent,
        tiled: tiled,
      );
      final indent = _windowControls.value.value.indentFor(
        rowTop: fieldTop - media.padding.top,
      );
      children.add(
        AnimatedPositioned(
          key: kSearchFieldKey,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : kSearchMorphDuration,
          curve: kSearchMorphCurve,
          left: bodyStart + kRegularSearchMargin + indent,
          right: kRegularSearchMargin,
          top: fieldTop,
          height: kRegularSearchFieldExtent,
          child: slot(
            details(LiquidChromeSlot.searchField),
            searchField(inlineCancel: _search.cancel),
          ),
        ),
      );
    }
```

(In RTL the start offset belongs on the right: use `PositionedDirectional`'s logic by computing `left`/`right` from `rtl`: `left: rtl ? kRegularSearchMargin : bodyStart + kRegularSearchMargin + indent, right: rtl ? bodyStart + kRegularSearchMargin + indent : kRegularSearchMargin`.)

Insets: replace `final insets = chromeInsetsFor(…);` with `var insets = chromeInsetsFor(…);` and, once `phase` and the rects are known (move the inset computation after them), add:

```dart
    if (phase == LiquidSearchPhase.active && kind == LiquidChromeKind.bottomBar) {
      final rects = compactSearchRects(
        phase: phase,
        size: size,
        rowBottom: size.height - bottomGap,
        rowExtent: _measured[barKey] ?? kBottomPillExtent,
        margin: size.width < kLiquidNarrowWidth ? _kNarrowBarMargin : _kBarMargin,
        keyboard: media.viewInsets.bottom,
        direction: Directionality.of(context),
      );
      insets = insets.copyWith(bottom: size.height - rects.field.top + kSearchFieldGap);
    }
    if (regularField) {
      insets = insets.copyWith(
        top: regularSearchFieldTop(
              phase: phase,
              paddingTop: media.padding.top,
              barExtent: _measured[barKey] ?? kTopPillExtent,
              tiled: tiled,
            ) +
            kRegularSearchFieldExtent +
            kSearchFieldGap,
      );
    }
```

(Compute `rects` once and reuse it in the bottom-bar case to keep one source; the snippet shows the values.)

`PopScope` at the end of `_buildLayout`:

```dart
    final searchActive = phase == LiquidSearchPhase.active;
    return PopScope(
      canPop: kind != LiquidChromeKind.sidebarOverlay && !searchActive,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (kind == LiquidChromeKind.sidebarOverlay) {
          _setSidebarVisible(false);
        } else if (searchActive) {
          _search.deactivate();
        }
      },
      child: /* unchanged ShellScopeMarker … */,
    );
```

Also unfocus the Flutter field when the layout kind changes while focused (spec §9.4): at the start of `_buildLayout`, after `presentation` is known:

```dart
    if (_presentation != null &&
        sizeClassOf(_presentation!) != sizeClassOf(presentation) &&
        _search.focus.hasFocus) {
      _search.focus.unfocus();
    }
```

- [ ] **Step 9: Exports**

In `liquid_shell/lib/liquid_shell.dart`: `export 'src/search/scope_bar.dart';` and add `LiquidSearchChromeDetails` to the `chrome_builder.dart` export (it exports the whole file today; keep that).

- [ ] **Step 10: Run every Dart test**

Run: `cd liquid_shell && fvm flutter test --exclude-tags golden`
Expected: all pass. P1's shell tests must be unchanged: shells without a search destination build exactly P1's tree.

Run: `make goldens`
Expected: P1/P2 goldens unchanged (no image differs).

- [ ] **Step 11: Commit**

```bash
bash .githooks/pre-commit
git add liquid_shell/lib/src/search liquid_shell/lib/src/shell/chrome_builder.dart \
  liquid_shell/lib/src/shell/liquid_shell.dart liquid_shell/lib/liquid_shell.dart \
  liquid_shell/test/unit/search_test.dart liquid_shell/test/widget/search_fallback_test.dart
git commit -m "feat(glass): the Flutter search tab: compact morph, top field and scope bar (VK-407)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: The example: a real search case, and Compose instead of search-as-a-page

**Files:**
- Create: `liquid_shell/example/lib/support/search_data.dart`
- Create: `liquid_shell/example/lib/cases/search.dart`
- Modify: `liquid_shell/example/lib/cases/cases.dart`
- Modify: `liquid_shell/example/lib/cases/trailing_action.dart`, `liquid_shell/example/lib/cases/native_chrome.dart` (Compose, Q18)
- Modify: `liquid_shell/example/test/cases_smoke_test.dart`, `liquid_shell/example/test/goldens/cases_test.dart`, `liquid_shell/example/integration_test/native_shell_test.dart` (Compose labels)
- Create: `liquid_shell/example/test/search_case_test.dart`, `liquid_shell/example/test/goldens/search_test.dart`

**Interfaces:**
- Consumes: Tasks 6–9 (the public API: `LiquidDestinationRole.search`, `LiquidSearch`, `LiquidSearchController`, `LiquidSearchScopeBar`, `LiquidPage`, `LiquidShellScope.of(context).searchPhase`).
- Produces:
  - `search_data.dart`: `enum SearchKind { song, place }`, `class SearchItem { title, subtitle, kind, category }`, `const kSearchItems`, `const kSearchCategories`, `const kSearchScopes = ['All', 'Songs', 'Places']`, `String foldVietnamese(String)`, `bool searchMatches(SearchItem, String)`, `List<SearchItem> searchResults(String query, {required int scope})`, `List<String> rememberQuery(List<String> recents, String query)`
  - `SearchCase` (case id `search`, README region `search`); semantics labels used by Tasks 11–12: the tab labels `Home`, `Library`, `Search`; the placeholder `Songs, places`; the result title `Hồ Hoàn Kiếm`; the empty-state text `No results for "…"`; the recents header `Recently searched` with `Clear`.

- [ ] **Step 1: Write the failing tests**

`liquid_shell/example/test/search_case_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/search.dart';
import 'package:liquid_shell_example/support/search_data.dart';

Future<void> _pump(WidgetTester tester, {Size size = const Size(393, 852)}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size
    ..padding = const FakeViewPadding(top: 59, bottom: 34)
    ..viewPadding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: SearchCase()));
  await tester.pumpAndSettle();
}

Future<void> _openSearch(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Search'));
  await tester.pumpAndSettle();
}

void main() {
  group('data', () {
    test('foldVietnamese strips every tone and vowel mark, and đ', () {
      expect(foldVietnamese('Hồ Hoàn Kiếm'), 'ho hoan kiem');
      expect(foldVietnamese('ĐÀ LẠT'), 'da lat');
      expect(foldVietnamese('ưởng ợ ỹ'), 'uong o y');
      // Decomposed input (combining marks) folds the same.
      expect(foldVietnamese('Hồ'), 'ho');
    });

    test('a query matches when every word starts a word of the item', () {
      SearchItem find(String title) =>
          kSearchItems.firstWhere((i) => i.title == title);
      expect(searchMatches(find('Hồ Hoàn Kiếm'), 'ho hoan kiem'), isTrue);
      expect(searchMatches(find('Hồ Hoàn Kiếm'), 'Hồ hoan'), isTrue);
      expect(searchMatches(find('Phố cổ Hội An'), 'hoi an'), isTrue);
      expect(searchMatches(find('Đà Lạt'), 'da lat'), isTrue);
      expect(searchMatches(find('Hồ Hoàn Kiếm'), 'oan'), isFalse);
      expect(searchMatches(find('Hồ Hoàn Kiếm'), '   '), isFalse);
    });

    test('scopes filter songs and places', () {
      expect(searchResults('ha noi', scope: 0).length, greaterThan(1));
      expect(
        searchResults('ha noi', scope: 1).every((i) => i.kind == SearchKind.song),
        isTrue,
      );
      expect(
        searchResults('ha noi', scope: 2).every((i) => i.kind == SearchKind.place),
        isTrue,
      );
      expect(searchResults('zzz', scope: 0), isEmpty);
    });

    test('recents: newest first, folded duplicates removed, six at most', () {
      var recents = <String>[];
      for (final q in ['a', 'b', 'c', 'd', 'e', 'f', 'g']) {
        recents = rememberQuery(recents, q);
      }
      expect(recents, ['g', 'f', 'e', 'd', 'c', 'b']);
      expect(rememberQuery(['Hà Nội', 'x'], 'ha noi'), ['ha noi', 'x']);
      expect(rememberQuery(['x'], '  '), ['x']);
    });
  });

  group('SearchCase (Flutter chrome)', () {
    testWidgets('selected: categories; active: scope bar and recents', (
      tester,
    ) async {
      await _pump(tester);
      await _openSearch(tester);
      expect(find.text('Nhạc Trịnh'), findsOneWidget);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.byType(LiquidSearchScopeBar), findsOneWidget);
      expect(find.text('Recently searched'), findsOneWidget);
      expect(find.text('Nhạc Trịnh'), findsNothing);
    });

    testWidgets('live results, accent-insensitive; an empty state', (
      tester,
    ) async {
      await _pump(tester);
      await _openSearch(tester);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'ho hoan');
      await tester.pumpAndSettle();
      expect(find.text('Hồ Hoàn Kiếm'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No results for "zzz"'), findsOneWidget);
    });

    testWidgets('a result pushes a detail inside the tab, with the back button', (
      tester,
    ) async {
      await _pump(tester);
      await _openSearch(tester);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'ho hoan');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hồ Hoàn Kiếm'));
      await tester.pumpAndSettle();
      expect(find.byType(LiquidBackButton), findsOneWidget);
      expect(find.byType(LiquidShell), findsOneWidget, reason: 'inside the tab');
      await tester.tap(find.byType(LiquidBackButton));
      await tester.pumpAndSettle();
      expect(find.byType(LiquidBackButton), findsNothing);
      expect(find.text('Hồ Hoàn Kiếm'), findsOneWidget);
    });

    testWidgets('submit remembers the query; Clear empties the recents', (
      tester,
    ) async {
      await _pump(tester);
      await _openSearch(tester);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'da lat');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'da lat'), findsOneWidget);
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'da lat'), findsNothing);
    });

    testWidgets('the query is kept across tab switches', (tester) async {
      await _pump(tester);
      await _openSearch(tester);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'ho hoan');
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Home').first);
      await tester.pumpAndSettle();
      await _openSearch(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'ho hoan',
      );
      expect(find.text('Hồ Hoàn Kiếm'), findsOneWidget);
    });

    testWidgets('a category opens its page', (tester) async {
      await _pump(tester);
      await _openSearch(tester);
      await tester.tap(find.text('Hà Nội').first);
      await tester.pumpAndSettle();
      expect(find.text('Hồ Hoàn Kiếm'), findsOneWidget);
      expect(find.byType(LiquidBackButton), findsOneWidget);
    });
  });
}
```

`liquid_shell/example/test/goldens/search_test.dart`:

```dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_example/cases/search.dart';

import '../support/golden_harness.dart';

/// The search tab drawn by Flutter (spec P3b §12.3).
void main() {
  Future<void> openSearch(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Search'));
    await tester.pumpAndSettle();
  }

  testWidgets('case_search_phone_selected', (tester) async {
    await pumpGolden(tester, const SearchCase(), device: iphone);
    await openSearch(tester);
    await expectDocImage(tester, 'case_search_phone_selected');
  });

  testWidgets('case_search_phone_active', (tester) async {
    await pumpGolden(tester, const SearchCase(), device: iphone);
    await openSearch(tester);
    await tester.tap(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 336 * goldenPixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await expectDocImage(tester, 'case_search_phone_active');
  });

  testWidgets('case_search_phone_results', (tester) async {
    await pumpGolden(tester, const SearchCase(), device: iphone);
    await openSearch(tester);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'ho');
    await tester.pumpAndSettle();
    await expectDocImage(tester, 'case_search_phone_results');
  });

  testWidgets('case_search_tablet_selected', (tester) async {
    await pumpGolden(tester, const SearchCase(), device: ipadPortrait);
    await openSearch(tester);
    await expectDocImage(tester, 'case_search_tablet_selected');
  });

  testWidgets('case_search_tablet_active', (tester) async {
    await pumpGolden(tester, const SearchCase(), device: ipadPortrait);
    await openSearch(tester);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await expectDocImage(tester, 'case_search_tablet_active');
  });

  testWidgets('case_search_detail', (tester) async {
    await pumpGolden(tester, const SearchCase(), device: iphone);
    await openSearch(tester);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'ho hoan');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hồ Hoàn Kiếm'));
    await tester.pumpAndSettle();
    await expectDocImage(tester, 'case_search_detail');
  });
}
```

`tester.view.viewInsets` is in physical pixels (`FakeViewPadding`): multiply by the harness ratio, as above. `pumpGolden(tester, child, device:)` and `expectDocImage(tester, name)` are the harness's (`test/support/golden_harness.dart`); images land in `liquid_shell/doc/images/<name>.png`.

- [ ] **Step 2: Run them to see them fail**

Run: `cd liquid_shell/example && fvm flutter test test/search_case_test.dart`
Expected: compile errors: `package:liquid_shell_example/cases/search.dart` and `support/search_data.dart` do not exist.

- [ ] **Step 3: The dataset**

`liquid_shell/example/lib/support/search_data.dart`:

```dart
import 'package:flutter/foundation.dart';

/// What a search item is.
enum SearchKind {
  /// A song: the subtitle is the artist.
  song,

  /// A place: the subtitle is the city or province.
  place,
}

/// One searchable item of the example (titles only, no lyrics).
@immutable
class SearchItem {
  /// Creates an item.
  const SearchItem(this.title, this.subtitle, this.kind, this.category);

  /// Song or place name.
  final String title;

  /// Artist or location.
  final String subtitle;

  /// Song or place.
  final SearchKind kind;

  /// One of [kSearchCategories].
  final String category;
}

/// The search scopes, in `LiquidSearchScopeBar` order.
const kSearchScopes = ['All', 'Songs', 'Places'];

/// The category tiles of the idle search page.
const kSearchCategories = [
  'Nhạc Trịnh',
  'Bolero',
  'Hà Nội',
  'Sài Gòn',
  'Miền Trung',
  'Miền Tây',
  'Cà phê',
  'Thiên nhiên',
];

/// The local dataset (Vietnamese titles exercise the diacritics).
const kSearchItems = [
  SearchItem('Diễm xưa', 'Trịnh Công Sơn', SearchKind.song, 'Nhạc Trịnh'),
  SearchItem('Hạ trắng', 'Trịnh Công Sơn', SearchKind.song, 'Nhạc Trịnh'),
  SearchItem('Biển nhớ', 'Trịnh Công Sơn', SearchKind.song, 'Nhạc Trịnh'),
  SearchItem('Cát bụi', 'Trịnh Công Sơn', SearchKind.song, 'Nhạc Trịnh'),
  SearchItem('Nối vòng tay lớn', 'Trịnh Công Sơn', SearchKind.song, 'Nhạc Trịnh'),
  SearchItem('Ru ta ngậm ngùi', 'Trịnh Công Sơn', SearchKind.song, 'Nhạc Trịnh'),
  SearchItem('Thành phố buồn', 'Lam Phương', SearchKind.song, 'Bolero'),
  SearchItem('Đắp mộ cuộc tình', 'Vinh Sử', SearchKind.song, 'Bolero'),
  SearchItem('Duyên phận', 'Thái Thịnh', SearchKind.song, 'Bolero'),
  SearchItem('Còn thương rau đắng mọc sau hè', 'Bắc Sơn', SearchKind.song, 'Miền Tây'),
  SearchItem('Hà Nội mùa vắng những cơn mưa', 'Trương Quý Hải', SearchKind.song, 'Hà Nội'),
  SearchItem('Em ơi Hà Nội phố', 'Phú Quang', SearchKind.song, 'Hà Nội'),
  SearchItem('Nồng nàn Hà Nội', 'Nguyễn Đức Cường', SearchKind.song, 'Hà Nội'),
  SearchItem('Sài Gòn đẹp lắm', 'Y Vân', SearchKind.song, 'Sài Gòn'),
  SearchItem('Mùa xuân trên thành phố Hồ Chí Minh', 'Xuân Hồng', SearchKind.song, 'Sài Gòn'),
  SearchItem('Hồ Hoàn Kiếm', 'Hà Nội', SearchKind.place, 'Hà Nội'),
  SearchItem('Văn Miếu – Quốc Tử Giám', 'Hà Nội', SearchKind.place, 'Hà Nội'),
  SearchItem('Phố cổ Hà Nội', 'Hà Nội', SearchKind.place, 'Hà Nội'),
  SearchItem('Hồ Tây', 'Hà Nội', SearchKind.place, 'Hà Nội'),
  SearchItem('Cà phê Giảng', 'Hà Nội', SearchKind.place, 'Cà phê'),
  SearchItem('Chợ Bến Thành', 'TP. Hồ Chí Minh', SearchKind.place, 'Sài Gòn'),
  SearchItem('Nhà thờ Đức Bà', 'TP. Hồ Chí Minh', SearchKind.place, 'Sài Gòn'),
  SearchItem('Bưu điện Thành phố', 'TP. Hồ Chí Minh', SearchKind.place, 'Sài Gòn'),
  SearchItem('Phố đi bộ Nguyễn Huệ', 'TP. Hồ Chí Minh', SearchKind.place, 'Sài Gòn'),
  SearchItem('Cà phê vợt Cheo Leo', 'TP. Hồ Chí Minh', SearchKind.place, 'Cà phê'),
  SearchItem('Phố cổ Hội An', 'Quảng Nam', SearchKind.place, 'Miền Trung'),
  SearchItem('Kinh thành Huế', 'Thừa Thiên Huế', SearchKind.place, 'Miền Trung'),
  SearchItem('Cầu Rồng', 'Đà Nẵng', SearchKind.place, 'Miền Trung'),
  SearchItem('Bà Nà', 'Đà Nẵng', SearchKind.place, 'Miền Trung'),
  SearchItem('Chợ nổi Cái Răng', 'Cần Thơ', SearchKind.place, 'Miền Tây'),
  SearchItem('Cù lao Thới Sơn', 'Tiền Giang', SearchKind.place, 'Miền Tây'),
  SearchItem('Rừng tràm Trà Sư', 'An Giang', SearchKind.place, 'Miền Tây'),
  SearchItem('Vịnh Hạ Long', 'Quảng Ninh', SearchKind.place, 'Thiên nhiên'),
  SearchItem('Sa Pa', 'Lào Cai', SearchKind.place, 'Thiên nhiên'),
  SearchItem('Đà Lạt', 'Lâm Đồng', SearchKind.place, 'Thiên nhiên'),
  SearchItem('Phú Quốc', 'Kiên Giang', SearchKind.place, 'Thiên nhiên'),
];

const _foldGroups = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final Map<int, String> _fold = {
  for (final MapEntry(:key, :value) in _foldGroups.entries)
    for (final rune in value.runes) rune: key,
};

/// Lower case without Vietnamese marks: "Hồ Hoàn Kiếm" → "ho hoan kiem".
/// Combining marks (decomposed input) are dropped too.
String foldVietnamese(String text) {
  final out = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    if (rune >= 0x0300 && rune <= 0x036F) continue;
    out.write(_fold[rune] ?? String.fromCharCode(rune));
  }
  return out.toString();
}

final _wordBreak = RegExp('[^a-z0-9]+');

List<String> _words(String text) => [
  for (final word in foldVietnamese(text).split(_wordBreak))
    if (word.isNotEmpty) word,
];

/// Whether every word of [query] starts a word of the item's title or
/// subtitle, ignoring case and marks.
bool searchMatches(SearchItem item, String query) {
  final wanted = _words(query);
  if (wanted.isEmpty) return false;
  final words = _words('${item.title} ${item.subtitle}');
  return wanted.every((w) => words.any((word) => word.startsWith(w)));
}

/// The items matching [query] in [scope] (0 all, 1 songs, 2 places).
List<SearchItem> searchResults(String query, {required int scope}) => [
  for (final item in kSearchItems)
    if ((scope == 0 ||
            (scope == 1 && item.kind == SearchKind.song) ||
            (scope == 2 && item.kind == SearchKind.place)) &&
        searchMatches(item, query))
      item,
];

/// [recents] with [query] first: a folded duplicate goes, six at most.
List<String> rememberQuery(List<String> recents, String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return recents;
  final key = foldVietnamese(trimmed);
  return [
    trimmed,
    for (final q in recents)
      if (foldVietnamese(q) != key) q,
  ].take(6).toList();
}
```

- [ ] **Step 4: The case**

`liquid_shell/example/lib/cases/search.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/search_data.dart';
import 'package:liquid_shell_example/support/wallpaper.dart';

/// Search is a tab (VK-407). On iOS 26 with native chrome the field is
/// UIKit's: on iPhone the ⌕ beside the tab pill becomes the field and the
/// pill collapses to the previous tab; on iPad the field sits under the
/// title row and rises into it when active. Everywhere else the shell draws
/// the same states in glass. Results, recents and the scope bar are this
/// page's Flutter content; a result pushes a detail inside the tab, with
/// the glass back button. The query survives tab switches: the controller
/// lives here.
class SearchCase extends StatefulWidget {
  /// Creates the case.
  const SearchCase({super.key});

  @override
  State<SearchCase> createState() => _SearchCaseState();
}

class _SearchCaseState extends State<SearchCase> {
  // #docregion search
  int _index = 0;
  final _search = LiquidSearchController();
  final _recents = ValueNotifier<List<String>>(const []);
  final _navigators = [for (var i = 0; i < 3; i++) GlobalKey<NavigatorState>()];

  static const _destinations = [
    LiquidDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
      sfSymbol: 'house',
    ),
    LiquidDestination(
      icon: Icon(Icons.library_music_outlined),
      selectedIcon: Icon(Icons.library_music),
      label: 'Library',
      sfSymbol: 'books.vertical',
    ),
    LiquidDestination(
      icon: Icon(Icons.search),
      label: 'Search',
      role: LiquidDestinationRole.search,
    ),
  ];

  @override
  Widget build(BuildContext context) => LiquidShell(
    destinations: _destinations,
    selectedIndex: _index,
    onDestinationSelected: (i) {
      // Reselecting a tab pops it to its root.
      if (i == _index) _navigators[i].currentState?.popUntil((r) => r.isFirst);
      setState(() => _index = i);
    },
    search: LiquidSearch(
      controller: _search,
      placeholder: 'Songs, places',
      onSubmitted: _remember,
    ),
    body: IndexedStack(
      index: _index,
      children: [
        _branch(0, _ListPage(title: 'Home', items: _home)),
        _branch(1, _ListPage(title: 'Library', items: _library)),
        _branch(
          2,
          _SearchPage(
            controller: _search,
            recents: _recents,
            onRemember: _remember,
          ),
        ),
      ],
    ),
  );

  /// Each tab has its own navigator: a detail pushes inside the tab.
  Widget _branch(int index, Widget root) => Navigator(
    key: _navigators[index],
    onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => root),
  );
  // #enddocregion search

  void _remember(String query) =>
      _recents.value = rememberQuery(_recents.value, query);

  @override
  void dispose() {
    _search.dispose();
    _recents.dispose();
    super.dispose();
  }
}

final _home = [for (final i in kSearchItems.take(6)) i];
final _library = [
  for (final i in kSearchItems)
    if (i.kind == SearchKind.song) i,
];

/// Pads a list clear of every chrome, the search field included.
EdgeInsets _padding(BuildContext context) => LiquidShellScope.contentPaddingOf(
  context,
).add(const EdgeInsets.symmetric(horizontal: 16));

/// A wallpaper page: the glass has something to show.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: Stack(
      children: [const Positioned.fill(child: Wallpaper()), child],
    ),
  );
}

class _ListPage extends StatelessWidget {
  const _ListPage({required this.title, required this.items});

  final String title;
  final List<SearchItem> items;

  @override
  Widget build(BuildContext context) => LiquidPage(
    title: title,
    child: _Backdrop(
      child: Builder(
        builder: (context) => ListView(
          padding: _padding(context),
          children: [for (final item in items) _ResultTile(item: item)],
        ),
      ),
    ),
  );
}

class _SearchPage extends StatelessWidget {
  const _SearchPage({
    required this.controller,
    required this.recents,
    required this.onRemember,
  });

  final LiquidSearchController controller;
  final ValueNotifier<List<String>> recents;
  final ValueChanged<String> onRemember;

  @override
  Widget build(BuildContext context) => LiquidPage(
    title: 'Search',
    child: _Backdrop(
      child: ListenableBuilder(
        listenable: Listenable.merge([controller, recents]),
        builder: (context, _) {
          final value = controller.value;
          final phase = LiquidShellScope.of(context).searchPhase;
          final padding = _padding(context);
          if (value.text.isEmpty && phase != LiquidSearchPhase.active) {
            return _CategoryGrid(padding: padding, onRemember: onRemember);
          }
          final results = value.text.trim().isEmpty
              ? null
              : searchResults(value.text, scope: value.scopeIndex);
          return ListView(
            padding: padding,
            children: [
              LiquidSearchScopeBar(controller: controller, scopes: kSearchScopes),
              const SizedBox(height: 16),
              if (results == null)
                ..._recents(context)
              else if (results.isEmpty)
                _Empty(query: value.text)
              else
                for (final item in results)
                  _ResultTile(item: item, onOpen: () => onRemember(value.text)),
            ],
          );
        },
      ),
    ),
  );

  List<Widget> _recents(BuildContext context) => [
    Row(
      children: [
        Expanded(
          child: Text(
            'Recently searched',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        TextButton(
          onPressed: recents.value.isEmpty ? null : () => recents.value = const [],
          child: const Text('Clear'),
        ),
      ],
    ),
    if (recents.value.isEmpty)
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Your searches show here.'),
      )
    else
      for (final query in recents.value)
        ListTile(
          leading: const Icon(Icons.history),
          title: Text(query),
          onTap: () => controller.text = query,
        ),
  ];
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.padding, required this.onRemember});

  final EdgeInsets padding;
  final ValueChanged<String> onRemember;

  static const _colors = [
    Color(0xFF7E57C2),
    Color(0xFFEF6C00),
    Color(0xFF00897B),
    Color(0xFFD81B60),
    Color(0xFF3949AB),
    Color(0xFF558B2F),
    Color(0xFF6D4C41),
    Color(0xFF0277BD),
  ];

  @override
  Widget build(BuildContext context) => GridView.count(
    padding: padding,
    crossAxisCount: 2,
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    childAspectRatio: 1.6,
    children: [
      for (final (i, category) in kSearchCategories.indexed)
        Material(
          color: _colors[i % _colors.length],
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _ListPage(
                  title: category,
                  items: [
                    for (final item in kSearchItems)
                      if (item.category == category) item,
                  ],
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: AlignmentDirectional.bottomStart,
                child: Text(
                  category,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.item, this.onOpen});

  final SearchItem item;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
    child: ListTile(
      leading: Icon(
        item.kind == SearchKind.song ? Icons.music_note : Icons.place_outlined,
      ),
      title: Text(item.title),
      subtitle: Text(
        '${item.kind == SearchKind.song ? 'Song' : 'Place'} · ${item.subtitle}',
      ),
      onTap: () {
        onOpen?.call();
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => _DetailPage(item: item)),
        );
      },
    ),
  );
}

class _DetailPage extends StatelessWidget {
  const _DetailPage({required this.item});

  final SearchItem item;

  @override
  Widget build(BuildContext context) => LiquidPage(
    title: item.title,
    child: _Backdrop(
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return ListView(
            padding: _padding(context),
            children: [
              const SizedBox(height: 24),
              Icon(
                item.kind == SearchKind.song ? Icons.album : Icons.landscape,
                size: 96,
              ),
              const SizedBox(height: 16),
              Text(item.title, style: theme.textTheme.headlineSmall),
              Text(item.subtitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Chip(label: Text(item.category)),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 48),
    child: Column(
      children: [
        const Icon(Icons.search_off, size: 48),
        const SizedBox(height: 12),
        Text(
          'No results for "$query"',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        const Text('Check the spelling, or try another scope.'),
      ],
    ),
  );
}
```

- [ ] **Step 5: Register the case; Compose instead of search-as-a-page (Q18)**

In `cases.dart`, import `package:liquid_shell_example/cases/search.dart` and add after `'trailing'`:

```dart
  (
    id: 'search',
    title: 'Search tab',
    subtitle: 'A real search tab: field, scopes, recents, live results',
    drawnByFlutter: null,
    page: SearchCase(),
  ),
```

and change the `trailing` entry's subtitle to `'Compose: opens a page above the shell'`.

In `trailing_action.dart`, replace the class comment with `/// A compose circle at the end of the tab bar, opening a page above the shell. (Search is a tab: see SearchCase.)`, and the action and page with:

```dart
      tabBarTrailing: LiquidTabAction(
        icon: const Icon(Icons.edit_outlined),
        semanticLabel: 'Compose',
        sfSymbol: 'square.and.pencil',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: _composePage),
        ),
      ),
```

```dart
  // #docregion no-chrome
  // Pushed above the shell (on the app's navigator): no chrome covers it.
  Widget _composePage(BuildContext context) => const LiquidNoChrome(
    child: Scaffold(
      body: DemoPage(
        title: 'New message',
        children: [TextField(decoration: InputDecoration(hintText: 'Message'))],
      ),
    ),
  );
  // #enddocregion no-chrome
```

In `native_chrome.dart`, rename `_searches` to `_drafts`, and the trailing action to:

```dart
      tabBarTrailing: LiquidTabAction(
        icon: const Icon(Icons.edit_outlined),
        semanticLabel: 'Compose',
        sfSymbol: 'square.and.pencil',
        onPressed: () => setState(() => _drafts++),
      ),
```

with the body line `Text('Drafts: $_drafts'),`.

Update the tests that tapped the old action: in `cases_smoke_test.dart` replace `find.byTooltip('Search')` with `find.byTooltip('Compose')` (two places), `'Searches: 1'` with `'Drafts: 1'`, and the test name `'trailing search opens a page with no chrome'` with `'trailing compose opens a page with no chrome'`; in `goldens/cases_test.dart` the `case_no_chrome` interaction taps `find.byTooltip('Compose')` (and its comment says "The compose page"); in `integration_test/native_shell_test.dart` line 155 expects `'Drafts: 1'`.

- [ ] **Step 6: Run the example's tests; regenerate the goldens**

Run: `cd liquid_shell/example && fvm flutter test --exclude-tags golden`
Expected: all pass, the smoke test included (`search` on phone and tablet).

Run: `make goldens-update`
Expected: new `case_search_*.png` files and changed `case_trailing.png` and `case_no_chrome.png`; no other image changes (`git status --short liquid_shell/doc/images` lists only those). Open each new image and check it against spec §3.2–3.3: the selected phone shows the collapsed Home circle at bottom-left and the field to its right; active shows the field above the 336pt keyboard area with ×; the tablet shows the field under the top bar, and active has the field in the bar row with the bar faded.

Run: `make goldens`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
bash .githooks/pre-commit
git add liquid_shell/example/lib/support/search_data.dart liquid_shell/example/lib/cases/search.dart \
  liquid_shell/example/lib/cases/cases.dart liquid_shell/example/lib/cases/trailing_action.dart \
  liquid_shell/example/lib/cases/native_chrome.dart liquid_shell/example/test/search_case_test.dart \
  liquid_shell/example/test/goldens/search_test.dart liquid_shell/example/test/goldens/cases_test.dart \
  liquid_shell/example/test/cases_smoke_test.dart liquid_shell/example/integration_test/native_shell_test.dart \
  liquid_shell/doc/images/case_search_phone_selected.png liquid_shell/doc/images/case_search_phone_active.png \
  liquid_shell/doc/images/case_search_phone_results.png liquid_shell/doc/images/case_search_tablet_selected.png \
  liquid_shell/doc/images/case_search_tablet_active.png liquid_shell/doc/images/case_search_detail.png \
  liquid_shell/doc/images/case_trailing.png liquid_shell/doc/images/case_no_chrome.png
git commit -m "feat(example): a real search tab case; Compose replaces search-as-a-page (VK-407)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Integration on iPhone and iPad simulators, iOS 26.5 and 27.0

Before this task, rebase onto `main` if P2 has merged (Global Constraints, "Rebase"), then `make verify`.

**Files:**
- Create: `liquid_shell/example/integration_test/native_search_test.dart`
- Modify: `tool/integration_ios_native.sh` (a list of targets; UDID pairs)
- Modify: `Makefile` (`integration-ios-native` help text only)

**Interfaces:**
- Consumes: Task 3 (`LiquidShellIOS.debugTap`, `.debugSnapshot`, `NativeTapTarget.searchField/searchCancel/back`), Task 10 (`SearchCase` texts).
- Produces: `NATIVE_TESTS` (space-separated targets, default `integration_test/native_shell_test.dart integration_test/native_search_test.dart`) in `tool/integration_ios_native.sh`; screenshots `build/integration_screenshots/search_<run>_<phase>.png` (`idle`, `selected`, `active`, `results`, `detail`, `cancelled`), used by Task 12.

- [ ] **Step 1: Write the integration test**

`liquid_shell/example/integration_test/native_search_test.dart`:

```dart
// The native search tab on real simulators (spec P3b §12.5).
//
// tool/integration_ios_native.sh runs it with EXPECT_NATIVE=true on iPhone
// and iPad, iOS 26.5 and 27.0, and with EXPECT_NATIVE=false on iOS 18 when
// that runtime exists (the Flutter search UI). It drives the native field
// through the plugin's debug hooks and checks both sides.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/search.dart';
import 'package:liquid_shell_ios/liquid_shell_ios.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

const _expectNative = bool.fromEnvironment('EXPECT_NATIVE');
const _runName = String.fromEnvironment('RUN_NAME', defaultValue: 'run');

/// Lets the platform answer and UIKit lay out: channel round trips and
/// layout passes take real time.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

const _app = MaterialApp(debugShowCheckedModeBanner: false, home: SearchCase());

LiquidShellIOS get _ios => LiquidShellPlatform.instance as LiquidShellIOS;

/// The scope seen by the search page's content.
LiquidShellScopeData _scope(WidgetTester tester) => LiquidShellScope.of(
  tester.element(find.byType(LiquidSearchScopeBar).evaluate().isNotEmpty
      ? find.byType(LiquidSearchScopeBar).first
      : find.byType(GridView).first),
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(String phase) =>
      binding.takeScreenshot('search_${_runName}_$phase');

  void expectResumed() => expect(
    WidgetsBinding.instance.lifecycleState,
    AppLifecycleState.resumed,
    reason: 'the Flutter view never leaves the window',
  );

  testWidgets('the search tab, phase by phase', (tester) async {
    await tester.pumpWidget(_app);
    await _settle(tester);
    await shot('idle');

    // Select the search tab: a native proposal, Dart's guard, then UIKit.
    if (_expectNative) {
      await _ios.debugTap(NativeTapTarget.destination, 2);
    } else {
      await tester.tap(find.bySemanticsLabel('Search'));
    }
    await _settle(tester);
    expect(find.text('Nhạc Trịnh'), findsOneWidget, reason: 'categories');
    var scope = _scope(tester);
    expect(scope.searchPhase, LiquidSearchPhase.selected);
    expect(scope.nativePageBar, _expectNative);
    if (_expectNative) {
      final snapshot = await _ios.debugSnapshot();
      debugPrint('liquid_shell search selected: placement ${snapshot.placement} '
          'field ${snapshot.fieldFrame.x},${snapshot.fieldFrame.y} '
          '${snapshot.fieldFrame.width}x${snapshot.fieldFrame.height} '
          'insets ${scope.chromeInsets} padding ${MediaQuery.paddingOf(tester.element(find.byType(GridView)))}');
      expect(snapshot.selectedTab, 'destination2');
      expect(snapshot.searchActive, isFalse, reason: 'Q13: not focused');
      expect(snapshot.fieldFrame.width, greaterThan(100));
      final isPad = MediaQuery.sizeOf(tester.element(find.byType(GridView))).shortestSide >= 600;
      expect(snapshot.placement, isPad ? 'stacked' : isNot('stacked'));
    }
    await shot('selected');

    // Activate: the field focuses; the keyboard inset reaches Flutter.
    if (_expectNative) {
      await _ios.debugTap(NativeTapTarget.searchField, 2);
    } else {
      await tester.tap(find.byType(TextField));
    }
    await _settle(tester);
    scope = _scope(tester);
    expect(scope.searchPhase, LiquidSearchPhase.active);
    expect(find.text('Recently searched'), findsOneWidget);
    if (_expectNative) {
      final snapshot = await _ios.debugSnapshot();
      expect(snapshot.searchActive, isTrue);
      expect(snapshot.firstResponderIsSearch, isTrue);
    }
    await shot('active');

    // Text from Dart (the user's typing is XCUITest's, Task 12).
    final controller = (tester.widget<LiquidShell>(find.byType(LiquidShell)).search)!.controller;
    controller.text = 'ho hoan';
    await _settle(tester);
    expect(find.text('Hồ Hoàn Kiếm'), findsOneWidget);
    if (_expectNative) {
      expect((await _ios.debugSnapshot()).searchText, 'ho hoan');
    }
    await shot('results');

    // A result pushes a detail inside the tab: the native back circle.
    await tester.tap(find.text('Hồ Hoàn Kiếm'));
    await _settle(tester);
    if (_expectNative) {
      final snapshot = await _ios.debugSnapshot();
      expect(snapshot.pageTitles, ['Search', 'Hồ Hoàn Kiếm']);
      expect(find.byType(LiquidBackButton), findsNothing);
      await shot('detail');
      await _ios.debugTap(NativeTapTarget.back, 2);
    } else {
      expect(find.byType(LiquidBackButton), findsOneWidget);
      await shot('detail');
      await tester.tap(find.byType(LiquidBackButton));
    }
    await _settle(tester);
    expect(find.text('Hồ Hoàn Kiếm'), findsOneWidget, reason: 'back on results');
    if (_expectNative) {
      expect((await _ios.debugSnapshot()).pageTitles, ['Search']);
    }

    // Home and back: the query is kept (Q2).
    FocusManager.instance.primaryFocus?.unfocus();
    if (_expectNative) {
      await _ios.debugTap(NativeTapTarget.searchCancel, 2);
      await _settle(tester);
      expect(controller.text, '', reason: '× clears (native semantics)');
      controller.text = 'phố';
      await _settle(tester);
      await _ios.debugTap(NativeTapTarget.destination, 0);
      await _settle(tester);
      await _ios.debugTap(NativeTapTarget.destination, 2);
      await _settle(tester);
      expect((await _ios.debugSnapshot()).searchText, 'phố');
    } else {
      await tester.tap(find.bySemanticsLabel('Cancel search'));
      await _settle(tester);
      expect(controller.text, '');
    }
    expect(controller.isActive, isFalse);
    await shot('cancelled');
    expectResumed();
  });
}
```

Simplify `_scope`: the search page always contains either the grid or the scope bar; both are under the shell's scope. Keep it as written.

- [ ] **Step 2: Drive a list of targets and UDID pairs**

In `tool/integration_ios_native.sh`:
- add to the header comment: `# NATIVE_TESTS   space-separated integration targets (default: native_shell_test.dart and native_search_test.dart).`
- after `NATIVE_DEVICES=…`, add `NATIVE_TESTS=${NATIVE_TESTS:-integration_test/native_shell_test.dart integration_test/native_search_test.dart}`;
- change `drive()` to take the target as `$4` and pass `--target="$4"`;
- wrap the drive-and-retry block of the device loop in `for target in $NATIVE_TESTS; do … done`, with `run=${name//[^A-Za-z0-9]/_}` unchanged.

```bash
drive() {
  local udid=$1 expect=$2 run=$3 target=$4
  # shellcheck disable=SC2086 # FLUTTER may be "fvm flutter"
  "$tool_dir/with_timeout.sh" "$IOS_DRIVE_TIMEOUT" $FLUTTER drive \
    --driver=test_driver/integration_test.dart \
    --target="$target" \
    -d "$udid" \
    --dart-define=EXPECT_NATIVE="$expect" \
    --dart-define=RUN_NAME="$run"
}
```

```bash
  for target in $NATIVE_TESTS; do
    echo "  ▸ $target"
    status=0
    drive "$udid" "$expect" "$run" "$target" || status=$?
    if [ "$status" -eq 124 ]; then
      echo "▸ flutter drive stalled; restarting $name and retrying once" >&2
      xcrun simctl shutdown "$udid" 2>/dev/null || true
      boot "$udid"
      status=0
      drive "$udid" "$expect" "$run" "$target" || status=$?
    fi
    [ "$status" -eq 0 ] || exit "$status"
  done
```

In the `Makefile`, change the `integration-ios-native` help text to `## Native iOS 26 shell and search tab on iPad and iPhone simulators`.

- [ ] **Step 3: Run on the four simulators (and iOS 18 if present)**

Each simulator by UDID (the script accepts UDIDs; `IOS_RUNTIME=""` disables the name filter):

```bash
IOS_RUNTIME="" NATIVE_DEVICES="$PHONE26=true;$PHONE27=true;$IPAD26=true;$IPAD27=true" make integration-ios-native
[ -n "${PHONE18:-}" ] && IOS_RUNTIME="" NATIVE_DEVICES="$PHONE18=false" \
  NATIVE_TESTS=integration_test/native_search_test.dart make integration-ios-native \
  || echo "iOS 18 runtime not installed: leg skipped"
```

Expected: `All tests passed!` for each target on each device, then `✓ native shell integration passed`. The `liquid_shell search selected:` lines print the placement (`stacked` on iPad) and the field frame; copy them into `docs/qa/p3b/probe.md` under a new "Integration" heading. Screenshots are in `liquid_shell/example/build/integration_screenshots/search_*`.

If an iPad leg fails on `placement` because UIKit realises `.stacked` differently on 26.5, stop and compare with Task 1's P6 row; the expectation follows the probe, not the other way round, and the owner hears about a difference.

- [ ] **Step 4: Commit**

```bash
bash .githooks/pre-commit
git add liquid_shell/example/integration_test/native_search_test.dart tool/integration_ios_native.sh \
  Makefile docs/qa/p3b/probe.md
git commit -m "test(example): the native search tab on iPhone and iPad, iOS 26.5 and 27.0 (VK-407)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: XCUITest real taps and the side-by-side review

**Files:**
- Create: `liquid_shell/example/ios/RunnerUITests/SearchUITests.swift`
- Modify: `liquid_shell/example/lib/main.dart` (`LIQUID_SHELL_EXAMPLE_DEMO=search`)
- Modify (only if P3a has not merged): `liquid_shell/example/ios/Runner.xcodeproj/project.pbxproj`, `.../xcshareddata/xcschemes/Runner.xcscheme`, `Makefile` (`ios-ui`), `.github/workflows/ci.yaml` (`ios-ui`)
- Create: `docs/qa/p3b/compare.md`, `docs/qa/p3b/manual.md`
- Scratchpad only (never committed): `vk407/compare.swift`, `vk407/compare/*.png`

**Interfaces:**
- Consumes: Task 10's labels; Task 11's screenshots; P3a's `RunnerUITests` target, `make ios-ui`, and `ExampleApp({String? demo})` if P3a merged.
- Produces: `make ios-ui` runs `SearchUITests` too; `ExampleApp(demo: 'search')` opens `SearchCase` and turns on Flutter semantics.

- [ ] **Step 1: The UI-test target**

Check: `grep -c RunnerUITests liquid_shell/example/ios/Runner.xcodeproj/project.pbxproj`.

- **Non-zero (P3a merged):** the target, `make ios-ui` and the CI job exist. Add the new file to the target with this one-off script (`$TMPDIR/add_search_ui_test.rb`, not committed; the `xcodeproj` gem ships with CocoaPods):

  ```ruby
  # One-off (spec P3b §12.6): adds SearchUITests.swift to RunnerUITests.
  require 'xcodeproj'
  project = Xcodeproj::Project.open(File.expand_path(ARGV.fetch(0)))
  target = project.targets.find { |t| t.name == 'RunnerUITests' } or abort('no RunnerUITests')
  group = project.main_group.find_subpath('RunnerUITests', false) or abort('no group')
  abort('already added') if group.files.any? { |f| f.path == 'SearchUITests.swift' }
  target.add_file_references([group.new_reference('SearchUITests.swift')])
  project.save
  puts 'SearchUITests.swift added'
  ```

  Run: `ruby "$TMPDIR/add_search_ui_test.rb" liquid_shell/example/ios/Runner.xcodeproj` → `SearchUITests.swift added`; then `command rm "$TMPDIR/add_search_ui_test.rb"`.

- **Zero (P3a not merged):** run P3a's target script exactly as its plan gives it (`docs/plans/2026-10-10-p3a-native-alerts.md` on branch `VK-406-native-alerts`, Task 7 Step 7: `git show VK-406-native-alerts:docs/plans/2026-10-10-p3a-native-alerts.md | sed -n '/Step 7: Add the `RunnerUITests` target/,/Step 8/p'`), with `RunnerUITests.swift` replaced by `SearchUITests.swift` in `add_file_references`, and add P3a's `ios-ui` make target and CI job (its Steps 8–9) verbatim. When the second of the two branches rebases, keep one target and one job.

- [ ] **Step 2: The demo launch**

In `liquid_shell/example/lib/main.dart` (if P3a merged, extend its `demo` switch instead of adding a second one):

```dart
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:liquid_shell_example/cases/cases.dart';
import 'package:liquid_shell_example/cases/search.dart';
import 'package:liquid_shell_example/support/drawn_by_flutter.dart';

void main() => runApp(
  ExampleApp(demo: Platform.environment['LIQUID_SHELL_EXAMPLE_DEMO']),
);

/// Kept for the app's life: XCUITest reads Flutter's rows through it.
SemanticsHandle? _demoSemantics;
```

```dart
class ExampleApp extends StatelessWidget {
  /// Creates the app. [demo] opens one case directly (UI tests): `search`.
  const ExampleApp({this.demo, super.key});

  /// The case to open at launch, or null for the case list.
  final String? demo;

  @override
  Widget build(BuildContext context) {
    final home = switch (demo) {
      'search' => const SearchCase(),
      _ => const CaseList(),
    };
    // XCUITest reads Flutter's rows through the accessibility tree.
    if (demo != null) _demoSemantics ??= SemanticsBinding.instance.ensureSemantics();
    return MaterialApp(
      title: 'liquid_shell',
      theme: ThemeData(colorSchemeSeed: kExampleSeed),
      darkTheme: ThemeData(
        colorSchemeSeed: kExampleSeed,
        brightness: Brightness.dark,
      ),
      home: home,
    );
  }
}
```

- [ ] **Step 3: Write the XCUITest**

`liquid_shell/example/ios/RunnerUITests/SearchUITests.swift`:

```swift
import XCTest

/// Real taps on the native search tab (spec P3b §12.6). Launched with
/// LIQUID_SHELL_EXAMPLE_DEMO=search, the example opens the search case
/// with Flutter semantics on, so Flutter's rows are accessibility elements.
final class SearchUITests: XCTestCase {
  private let timeout: TimeInterval = 90

  override func setUp() {
    continueAfterFailure = false
  }

  private func launch() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["LIQUID_SHELL_EXAMPLE_DEMO"] = "search"
    app.launch()
    return app
  }

  /// The search tab's button: inside the bar (iPad 27) or the detached ⌕.
  private func searchTabButton(_ app: XCUIApplication) -> XCUIElement {
    let inBar = app.tabBars.buttons["Search"]
    return inBar.exists ? inBar : app.buttons["Search"].firstMatch
  }

  func testTheSearchTabFieldResultsAndBack() {
    let app = launch()
    let tab = searchTabButton(app)
    XCTAssertTrue(tab.waitForExistence(timeout: timeout))
    tab.tap()

    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 10), "the native field")
    XCTAssertFalse(app.keyboards.firstMatch.exists, "selected, not focused (Q13)")

    field.tap()
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
    field.typeText("ho hoan")
    let result = app.staticTexts["Hồ Hoàn Kiếm"]
    XCTAssertTrue(result.waitForExistence(timeout: 10), "Flutter's live results")

    result.tap()
    let back = app.navigationBars.buttons.element(boundBy: 0)
    XCTAssertTrue(back.waitForExistence(timeout: 10), "the native glass back button")
    back.tap()
    XCTAssertTrue(app.staticTexts["Hồ Hoàn Kiếm"].waitForExistence(timeout: 10))

    // × (UIKit labels it "Cancel" or "Close"): clears and unfocuses.
    let cancel = app.buttons.matching(
      NSPredicate(format: "label IN %@", ["Cancel", "Close", "Hủy", "Đóng"])
    ).firstMatch
    XCTAssertTrue(cancel.waitForExistence(timeout: 10))
    cancel.tap()
    XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 10))
    XCTAssertEqual((field.value as? String) ?? "", field.placeholderValue ?? "")
  }

  func testTheCollapsedCircleReturnsToThePreviousTab() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "iPhone only")
    let app = launch()
    let tab = searchTabButton(app)
    XCTAssertTrue(tab.waitForExistence(timeout: timeout))
    tab.tap()
    XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 10))
    // The collapsed circle carries the previous tab's label.
    let home = app.buttons["Home"].firstMatch
    XCTAssertTrue(home.waitForExistence(timeout: 10))
    home.tap()
    XCTAssertTrue(app.staticTexts["Diễm xưa"].waitForExistence(timeout: 10), "Home's list")
  }
}
```

- [ ] **Step 4: Run it on the four simulators**

```bash
for udid in "$PHONE26" "$PHONE27" "$IPAD26" "$IPAD27"; do
  make ios-ui IOS_UNIT_DEVICE="$udid" || break
done
```

Expected: `** TEST SUCCEEDED **` on each (the collapsed-circle test is skipped on iPad). If `app.staticTexts["Hồ Hoàn Kiếm"]` never appears although the result is on screen (Flutter semantics not exposed to XCUITest), replace the two Flutter-text assertions by `app.otherElements["Hồ Hoàn Kiếm"]`; if that also fails, keep the native assertions only, record it in `docs/qa/p3b/manual.md` ("Flutter rows are checked by `flutter drive`, Task 11"), and tell the reviewer (spec §12.6).

- [ ] **Step 5: Side by side with the owner's frames (scratchpad only)**

Pick the owner's frames for each state from `$SCRATCH/vk407/frames/{iphone,ipad}/f_NNNN.jpg` (`$SCRATCH` is the session scratchpad; frame n is at t = (n − 1)/5 s), using `vk407-video-findings.md`'s state list. Write `$SCRATCH/vk407/compare.swift`:

```swift
// Throwaway (never committed): ours | the owner's frame, same height.
import AppKit

let args = CommandLine.arguments
guard args.count == 4 else { fatalError("usage: compare <ours.png> <frame.jpg> <out.png>") }
let ours = NSImage(contentsOfFile: args[1])!
let theirs = NSImage(contentsOfFile: args[2])!
let height: CGFloat = 1400
func scaled(_ image: NSImage) -> NSSize {
  NSSize(width: image.size.width * height / image.size.height, height: height)
}
let a = scaled(ours), b = scaled(theirs)
let out = NSImage(size: NSSize(width: a.width + 40 + b.width, height: height))
out.lockFocus()
NSColor.white.setFill()
NSRect(origin: .zero, size: out.size).fill()
ours.draw(in: NSRect(origin: .zero, size: a))
theirs.draw(in: NSRect(origin: NSPoint(x: a.width + 40, y: 0), size: b))
out.unlockFocus()
let bitmap = NSBitmapImageRep(data: out.tiffRepresentation!)!
try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[3]))
```

```bash
cd "$SCRATCH/vk407" && mkdir -p compare
swiftc -O compare.swift -o compare-bin
SHOTS=/Users/invoker/Projects/tuvi/liquid_shell-vk407/liquid_shell/example/build/integration_screenshots
./compare-bin "$SHOTS/search_<iphone27-run>_selected.png" frames/iphone/f_<state-2>.jpg compare/iphone_selected.png
# … one line per row of the table below
```

| Ours (Task 11) | Owner frame | Output |
|---|---|---|
| iPhone 27 `idle` | iPhone state 1 | `compare/iphone_idle.png` |
| iPhone 27 `selected` | iPhone state 2 | `compare/iphone_selected.png` |
| iPhone 27 `active` | iPhone state 3 | `compare/iphone_active.png` |
| iPhone 27 `cancelled` | iPhone state 4 | `compare/iphone_cancelled.png` |
| iPad 27 `selected` | iPad state 2 | `compare/ipad_selected.png` |
| iPad 27 `active` | iPad state 3 | `compare/ipad_active.png` |

The iPad frames are a narrow window; the simulator run is full screen. Add one more pair by hand: in Simulator.app put the example in a narrow Stage Manager window, open the search case, and screenshot `selected` and `active` (`xcrun simctl io "$IPAD27" screenshot …`). Look at each pair and note any visible difference in `docs/qa/p3b/compare.md`. The images stay in the scratchpad; they go to the owner in the review message.

`docs/qa/p3b/compare.md` (committed; names only, no images):

```markdown
# P3b-1: our search tab against the owner's Apple Music videos

The owner's frames stay outside the repository (session scratchpad
`vk407/frames/`); this file lists which frame each comparison used.

| State | Our screenshot (Task 11) | Owner frame | Difference noted |
|---|---|---|---|
| iPhone idle | search_<run>_idle.png | iphone/f_NNNN.jpg | |
| iPhone selected | search_<run>_selected.png | iphone/f_NNNN.jpg | |
| iPhone active | search_<run>_active.png | iphone/f_NNNN.jpg | |
| iPhone after × | search_<run>_cancelled.png | iphone/f_NNNN.jpg | |
| iPad selected (narrow window) | ipad_narrow_selected.png | ipad/f_NNNN.jpg | |
| iPad active (narrow window) | ipad_narrow_active.png | ipad/f_NNNN.jpg | |
```

Fill every `NNNN`, run name and difference before committing.

- [ ] **Step 6: The owner's checklist**

`docs/qa/p3b/manual.md`: copy spec §12.8's ten checks as a checklist (`- [ ]`), each with the device and OS to run it on (iPhone and iPad Air on iOS 27 for 1–9; the Android emulator and iOS 18 for 10), and the line "Telex (3) and VoiceOver (9) can only be checked by hand."

- [ ] **Step 7: Commit**

```bash
bash .githooks/pre-commit
git add liquid_shell/example/ios/RunnerUITests/SearchUITests.swift liquid_shell/example/lib/main.dart \
  liquid_shell/example/ios/Runner.xcodeproj/project.pbxproj docs/qa/p3b/compare.md docs/qa/p3b/manual.md
# Only if Step 1 took the "P3a not merged" branch:
#   git add liquid_shell/example/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme Makefile .github/workflows/ci.yaml
git commit -m "test(example): real taps on the native search tab; side-by-side review notes (VK-407)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Documentation, versions, CI and the final verification

**Files:**
- Modify: `liquid_shell/README.md`
- Create: `liquid_shell/doc/search.md`
- Modify: `liquid_shell/doc/native_chrome.md`, `liquid_shell/doc/router_integration.md`
- Modify: `liquid_shell/CHANGELOG.md`, `liquid_shell_platform_interface/CHANGELOG.md`, `liquid_shell_ios/CHANGELOG.md`, `liquid_shell_android/CHANGELOG.md`
- Modify: the four `pubspec.yaml` files (`version:` and the inter-package constraints), `liquid_shell_ios/ios/liquid_shell_ios.podspec` (`s.version`) if it carries one
- Modify: `.github/workflows/ci.yaml` (`integration-ios-native` 27.0 leg)

**Interfaces:**
- Consumes: everything above.
- Produces: README region `search` matching `SearchCase` (`make snippets`), `0.1.0-dev.3` everywhere.

- [ ] **Step 1: README**

In `liquid_shell/README.md`:
- Features: add "**Search tab**: a real search tab, UIKit's own on iOS 26 (iPhone: the ⌕ becomes the field and the tabs collapse; iPad: the field under the title row rises when active), the same states in glass elsewhere" and "**Pages and the glass back button**: `LiquidPage`".
- New section "Search tab" after "Trailing action": the snippet

  ```markdown
  <?code-excerpt "search.dart (search)"?>
  ```

  (then run `make snippets` to fill it), the phase table of spec §3.1–3.3 in four rows, the inset rule ("pad with `LiquidShellScope.contentPaddingOf`; never also add `viewInsets`"), the IME note (native field owns the IME; never write `value.text` back while `composing`), and the images `case_search_phone_selected.png`, `case_search_phone_active.png`, `case_search_tablet_selected.png` (260 px wide, as the other cases).
- "Trailing action": the text and alt texts say Compose; one sentence: "For search, use a search destination (next section), not a page pushed above the shell."
- New section "Pages and the back button": `LiquidPage` and `LiquidBackButton`, what is native where (P3b-1: the search tab), `maybePop` and `PopScope`.
- Limitations: "Native navigation bars are on the search tab only (P3b-2 brings them to every tab)"; "The native back swipe does not follow the finger yet: Flutter's back gesture moves the page and the bar switches when it ends"; "Pages pushed above the shell keep the Flutter bar".

Run: `make snippets`
Expected: `✓` (the README regions equal the example's).

- [ ] **Step 2: `doc/search.md`**

Sections, each a few paragraphs, written from the spec: "API" (§4.1–4.4 with the dartdoc of each type), "Phases per platform" (§3 tables), "The controller is the truth" (§8.2: no echo; × clears; the query is kept across tab switches), "Vietnamese and other IMEs" (§7.4 and §9.4), "Insets" (§4.6), "Troubleshooting" (no native field: opt-in, `sfSymbol` on the other destinations, a `chromeBuilder`, `nativeChrome: off`; a field over a dialog: the shell deactivates it; text lost on ×: by design, Q2).

- [ ] **Step 3: `doc/native_chrome.md` and `doc/router_integration.md`**

`native_chrome.md`: a "Search tab" section (§7.1–7.3 tree and configuration table), the extended hit-test rule (§7.8) in the "Hit testing" section, and "Page stacks and the back button" (§7.6–7.7). `router_integration.md`: "A search branch" (a search destination is just an index; give each branch its own `Navigator` so details push inside the tab; reselect pops to root).

- [ ] **Step 4: Versions and CHANGELOGs**

Every `pubspec.yaml`: `version: 0.1.0-dev.3`, and every dependency on a sibling package `^0.1.0-dev.3`. The podspec's `s.version = '0.1.0-dev.3'` if present. Each CHANGELOG gets a `## 0.1.0-dev.3` entry:
- `liquid_shell`: search tab (`LiquidDestinationRole.search`, `LiquidSearch`, `LiquidSearchController`, `LiquidSearchScopeBar`), `LiquidPage`, `LiquidBackButton`, scope `searchPhase` and `nativePageBar`, strings `searchPlaceholder`, `cancelSearch`, `back`, chrome slot `searchField`.
- `liquid_shell_platform_interface`: native search config, page stacks, five events, three methods.
- `liquid_shell_ios`: `UISearchTab` search destination with a native field, page stacks with the glass back button, the extended hit test.
- `liquid_shell_android`: version only.

- [ ] **Step 5: CI**

In `.github/workflows/ci.yaml`, the `integration-ios-native` job: set `NATIVE_TESTS` to both targets (the script's default already is), and add a second matrix leg with `IOS_RUNTIME: "iOS 27"` next to the existing one, both non-blocking as before.

- [ ] **Step 6: Verify everything**

```bash
df -h / | tail -1                     # still ≥ 10Gi
make verify
make ios-unit IOS_UNIT_DEVICE="$PHONE27"
make ios-unit IOS_UNIT_DEVICE="$IPAD27"
IOS_RUNTIME="" NATIVE_DEVICES="$PHONE27=true;$IPAD27=true" make integration-ios-native
make ios-ui IOS_UNIT_DEVICE="$PHONE27"
```

Expected: `✓ verify passed`; `** TEST SUCCEEDED **` twice; `✓ native shell integration passed`; `** TEST SUCCEEDED **`. Paste the outputs into the PR body later (no PR without the owner).

- [ ] **Step 7: Commit**

```bash
bash .githooks/pre-commit
git add liquid_shell/README.md liquid_shell/doc/search.md liquid_shell/doc/native_chrome.md \
  liquid_shell/doc/router_integration.md liquid_shell/CHANGELOG.md \
  liquid_shell_platform_interface/CHANGELOG.md liquid_shell_ios/CHANGELOG.md \
  liquid_shell_android/CHANGELOG.md liquid_shell/pubspec.yaml \
  liquid_shell_platform_interface/pubspec.yaml liquid_shell_ios/pubspec.yaml \
  liquid_shell_android/pubspec.yaml .github/workflows/ci.yaml
git commit -m "docs(docs): the search tab, LiquidPage and 0.1.0-dev.3 (VK-407)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

(Add the podspec to the `git add` if Step 4 changed it.)

- [ ] **Step 8: Whole-branch review, then clean up**

Request the whole-branch review (`superpowers:requesting-code-review`) against the spec. After it is resolved: delete the simulators (Setup), `command rm -rf liquid_shell/example/build`, and report to the controller: the commits, the probe decisions P1–P8, the side-by-side differences, and anything left for the owner. Do not push.

---

## Self-review notes (plan author)

- **Spec coverage.** §3 states → Tasks 4–5 (native), 9 (fallback), 11–12 (proof). §4 API → Tasks 6, 7, 9. §5–6 → Tasks 2–3. §7 → Tasks 4–5 (each subsection has a test). §8 → Task 8. §9 → Tasks 7 (bar), 9. §10 → the P3b-2 plan. §11 → Task 10. §12 → Tasks 4–5 (XCTest), 6–10 (Dart, goldens), 11 (integration), 12 (XCUITest, side by side, manual). §13 → Task 13. §14 error rows: activate ignored (Task 8 test), events without a search destination (`ShellSearch.onNativeEvent` returns without a controller), back for another tab (Task 8 test), out-of-range index (Task 3 Swift check through `navControllers` lookup; Dart `_onNativeBack` compares with the selection), non-finite rect/offset (Task 3 tests), composition (Tasks 4, 9 tests), dialog (Task 8 test), channel failures (Task 3 test), UIKit clears (Task 4 tests), misconfiguration (Task 6 asserts; release: first search destination, internal controller in `ShellSearch.configure`).
- **Names shared with P3b-2:** `ShellNavController(root:)`, `PageHostController()`, `applyPages(_:rootTitle:tabIndex:events:)`, `topHost(ofTab:)`, `selectedDestinationIndex`, `PassThroughView.isBackground(_:chainFrom:tabsView:)`, `PageRegistry`/`PageHandle`/`PageEntry`/`pageStackFor`, `FlutterPageBar({title, large, canPop, hideLargeTitle, child})`, `nativePageBarFor({engaged, selected, searchIndex})`, `nativeConfigFor(…, pageStacks:)`, `_pageStacks`, `_topPageEntry`, `kNative` in the harness, `ExampleApp(demo:)`, `NATIVE_TESTS`, `RecordingEvents` `"back <tab>"`.
