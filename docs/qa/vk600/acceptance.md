# VK-600 acceptance: the native tab bar minimizes on scroll

Evidence for spec `docs/specs/2026-10-14-native-tab-minimize-design.md` §12.5 (XCUITest) and §12.2 (the real channel). Task 10 adds the R3 before/after comparison (§7, an open owner question, Q14), the gates (§8) and the owner's device checklist (`manual.md`), whose results the owner records.

## 1. Run (Task 8)

- **Date:** 2026-10-15.
- **Simulators**, each created for this run and deleted after it: `vk600 t8 iPhone 26.5` and `vk600 t8 iPhone 27` (iPhone 17 Pro), `vk600 t8 iPad 26.5` and `vk600 t8 iPad 27` (iPad Air 11-inch (M4)). iOS 26.5 is 23F77, iOS 27.0 is 24A434.
- **Toolchain:** Xcode 27.0 (27A266a), Flutter 3.44.6 (fvm).
- **Host:** shared and heavily loaded. Load averages ranged from 5 to about 500 during the runs.

## 2. The minimized signal

Spec §12.5 reads "minimized" from UIKit's accessibility tree. A temporary XCUITest launched the `tabs` demo, printed `app.tabBars.firstMatch.debugDescription` at rest, then ran `app.swipeUp()`, waited 3 s and printed it again. The element subtrees below are trimmed to the buttons.

**iOS 26.5, at rest** (iOS 27.0 is the same, apart from the Settings image's size):

```
TabBar, {{0.0, 791.0}, {402.0, 83.0}}, label: 'Tab Bar'
  Other, {{64.0, 791.0}, {274.0, 62.0}}
    Other, {{64.0, 791.0}, {274.0, 62.0}}
      Button, {{68.0, 795.0}, {94.0, 54.0}}, label: 'Home', Selected
      Button, {{154.0, 795.0}, {94.0, 54.0}}, label: 'Explore'
      Button, {{240.0, 795.0}, {94.0, 54.0}}, label: 'Settings'
```

**iOS 26.5, after the swipe:**

```
TabBar, {{0.0, 791.0}, {402.0, 83.0}}, label: 'Tab Bar'
  Other, {{28.0, 798.0}, {48.0, 48.0}}
    Other, {{28.0, 798.0}, {48.0, 48.0}}
      Button, {{28.0, 798.0}, {48.0, 48.0}}, label: 'Home', value: Collapsed, Selected
        Image, {{35.3, 808.0}, {33.3, 28.0}}, identifier: 'house.fill', label: 'home'
```

**iOS 27.0, after the swipe:**

```
TabBar, {{0.0, 791.0}, {402.0, 83.0}}, label: 'Tab Bar'
  Other, {{28.0, 798.0}, {48.0, 48.0}}
    Other, {{28.0, 798.0}, {48.0, 48.0}}
      Button, {{28.0, 798.0}, {48.0, 48.0}}, label: 'Home', value: Collapsed, Selected
        Image, {{35.3, 808.0}, {33.3, 28.0}}, identifier: 'house.fill', label: 'home'
    Other, {{28.0, 798.0}, {48.0, 48.0}}
```

| Signal | 26.5 | 27.0 |
|---|---|---|
| "Explore" (and "Settings") leave the tree: `exists` false | flips | flips |
| "Home" shrinks from 94 × 54 to the 48 × 48 circle at (28, 798) | flips | flips |
| "Home" gains the accessibility value "Collapsed" | flips | flips |

Both of the brief's signals flip on both versions, so `MinimizeUITests.isMinimized` keeps both: an unselected tab is gone or not hittable, or the selected tab is under 60 pt wide. While UIKit animates, the tree holds both forms of the selected tab (a "Home" circle with the value "Collapsed" next to the full "Home"), so a plain `buttons["Home"].frame` fails with "multiple matching elements". The check reads every match: the bar counts as minimized only when every "Home" is the circle. The circle matches the spike's probe (spike §1.2: 48 × 48 at (28, 798)). The "Collapsed" value is UIKit's own string. It is not used, because it may be localized.

**As changed in Task 10** (Task 8 review). Both states need positive evidence, so a missing bar fails both waits: minimized needs at least one "Home" circle, with "Explore" gone from the bar or every "Home" the circle; expanded needs "Explore" in the bar and every "Home" wider than 60 pt. The old check read a bar with no tabs as minimized: a new assertion in `testTheRegularTopBarNeverMinimizes` was red on the iPad 27, whose top bar is not a tab bar in the tree ("XCTAssertFalse failed - the top bar is not read as minimized"), and green after. The bar is read from one accessibility snapshot of the tab bar per poll. Reading each match's `exists` and then its `frame` failed once on the iPhone 26.5 ("No matches found for Element at index 1"), when the second "Home" left the tree between the two reads. Presence in the bar replaces `isHittable` for "Explore": at rest a minimized bar has no "Explore" (the dumps above).

**iPad 27, regular width.** The top bar's buttons are not under a `TabBar` element. They sit in a plain group under the window: `Other, {{0.0, 29.5}, {820.0, 48.0}}` holds "Toggle sidebar", "Home", "Explore" and "Settings". So `app.tabBars.buttons["Home"]` never appears there, and the iPad test finds the tab among `app.buttons`. On iOS 26.5 the same lookup passes too.

## 3. The status-bar tap and Flutter's semantics scroll view

`testAStatusBarTapScrollsToTheTopAndExpands` taps the status bar to cause a programmatic scroll to the top (Q3). The first tap after a scroll did not move Flutter's list. The second tap did. Probes on the `minimize` demo, iPhone 26.5 (one tap every 3 s):

| Probe | Tap 1 | Tap 2 |
|---|---|---|
| Native chrome, after a drag | list stays, bar minimized | list at the top, bar expanded |
| The same again | stays | top, expanded |
| A neutral tap on the page between the drag and the status bar | stays | top, expanded |
| A fling left to settle | stays | top, expanded |
| Two taps 0.5 s apart | (one result) top, expanded | |
| Flutter liquid chrome (no native chrome) | stays | top |

lldb attached to the example (demo `minimize`, launched by `simctl`, driven with `idb`) listed every `UIScrollView` in the window: frame in the window, `scrollsToTop`, `contentOffset` and adjusted inset.

| Moment | Flutter's status-bar `UIScrollView` | `FlutterSemanticsScrollView` (the list's accessibility mirror) | `MinimizeProxy` (Home) |
|---|---|---|---|
| At rest | (0, 0, 402, 0), top 1, offset (2, 2) | full screen, top 1, offset 0 | top 0, offset −62 (Dart's 0), inset 62/83 |
| After a swipe | unchanged | offset 692.7 | offset 630.7 (Dart's 692.7) |
| After tap 1 | unchanged | **offset 0** | 630.7: Flutter did not move |
| After tap 2 | unchanged | 0 | −62: Flutter scrolled to the top |

So the first tap goes to Flutter's accessibility mirror of the list. It has `scrollsToTop` on, and UIKit scrolls it, not Flutter's content. Once the mirror is at the top, the next tap reaches Flutter's own status-bar scroll view, and the `Scaffold` scrolls the list. Native chrome or not, the behaviour is the same. Flutter's engine owns the mirror, so this is not something VK-600 can change.

- **When the mirror exists.** The engine creates it whenever semantics are on. On a simulator the engine turns them on always (`FlutterViewController.mm:2183-2187`, Flutter 3.44.6), so every simulator run has the mirror. On a device it turns them on under VoiceOver, Switch Control or Speak Screen (`:2190-2191`), and an app turns them on itself with `SemanticsBinding.ensureSemantics()` (the example's `minimize` and `search` demos do). The owner's checklist records the device behaviour under VoiceOver and Speak Screen (`manual.md`).
- **Spec §8.4's premise.** §8.4 says iOS runs the status-bar scroll-to-top only when one scroll view on screen has `scrollsToTop`. Here two have it, the mirror and Flutter's own status-bar view, and UIKit picks one per tap. Turning the proxies' `scrollsToTop` off (Q10) keeps them out of that choice, but it does not make Flutter's view the only candidate while the mirror exists.
- **What pins Q10.** XCTest does: `MinimizeProxyTests.testItLeavesTheStatusBarAccessibilityTrackpadAndPencilAlone` (named `…AndTrackpadAlone` until the final review's I5) and `NativeTabsTests.testThePageProxyLeavesTheStatusBarTapToFlutter` assert `scrollsToTop` false on the minimize proxy and on the search page's proxy. The XCUITest below cannot: with up to two taps it cannot tell the mirror's tap from a proxy's.
- **The test's second tap.** It taps again when the list is not back at the top within 3 s of the first tap, and says why in a comment.

## 4. XCUITest (Task 8)

`MinimizeUITests`. The iPhone tests skip on an iPad, and the iPad test skips on an iPhone.

| Test | Demo | What it proves |
|---|---|---|
| `testAScrollMinimizesAndAFlingToTheTopExpands` | `tabs` | A real swipe minimizes. A slow reverse drag in mid-content keeps it minimized for 1.5 s. A fling to the top expands |
| `testATapOnTheCircleExpands` | `tabs` | A tap on the circle expands |
| `testFlutterGetsTheDragAndTheTapAndTheAppsTabChangeExpands` | `minimize` | With the pan attached, Flutter's list moves under the drag (more than 200 pt). Minimized, a tap reaches Flutter ("Next tab"). The app's tab change expands the bar (Q4, the `.never` toggle) |
| `testAStatusBarTapScrollsToTheTopAndExpands` | `minimize` | A status-bar tap scrolls Flutter to the top, and that programmatic scroll expands the bar (Q3, the `.never` toggle). Q10 is pinned by XCTest, not here (§3) |
| `testTheSearchTabFromAMinimizedBarKeepsItsFieldScopesAndKeyboard` | `search` | Q5. Minimized on Library, the ⌕ opens the search with no keyboard (Q13). A drag on the search page leaves the field's frame unchanged. A tap on the field brings the keyboard. "pho" shows UIKit's scope bar at the top, and "Songs" filters. × dismisses the keyboard. Back on Library, the bar is expanded |
| `testTheRegularTopBarNeverMinimizes` | `tabs` | iPad, regular width. The drag scrolls the list by more than 200 pt, and the top bar stays whole |
| `testANarrowIPadWindowMinimizesLikeAnIPhone` | `tabs` | iPad, narrow window (Q6). It is compact, with the bottom bar. A swipe minimizes and a fling to the top expands, as on an iPhone. Skipped when the simulator has no resize grabber (not in Windowed Apps) |

The `minimize` demo (`liquid_shell/example/lib/support/minimize_demo.dart`) adds what the `tabs` demo lacks: a `Scaffold` above the shell, which handles the status-bar tap, and an app-driven "Next tab". UIKit alone keeps the bar minimized after a programmatic scroll to the top and after a programmatic tab change (spike §3.2). The two expands therefore come from liquid_shell's `.never` toggle.

`TabFidelityUITests.testSequences` used to assert that the native swipe did *not* minimize the bar (VK-503). With VK-600 it failed there, as expected: "native: the swipe scrolls the page and the bar does not minimize". It now asserts the minimize. The tap at the circle's centre, (52, 822) on an iPhone 17 Pro, is also the centre of UIKit's minimized circle, so it now expands the native bar, as in the Flutter run. `docs/qa/vk503/acceptance.md` (strip 7 "is a scroll") records the state before VK-600.

**A narrow iPad window.** The iPad simulators (26.5 and 27.0) start in iPadOS 26's Windowed Apps mode (Settings › Multitasking & Gestures). SpringBoard gives the app's window a resize grabber (`resize-grabber`, "Resize Liquid Shell Example", value "Bottom Right"). The test drags it half the screen's width to the left. On the 27.0 iPad the window went from 820 × 1180 to 375–410 pt wide, compact, with UIKit's bottom tab bar ("Home" 94 × 54 near the window's bottom). iPadOS keeps a window's size for the next launch, so the test drags the grabber back to the screen's bottom-right corner when it ends. That restored 820 × 1180 in the probe. The window does not start at the screen's origin: one probe window sat at (223, 83), while `XCUIApplication.frame` still reported (0, 0). So every drag in `MinimizeUITests` is relative to the window. Since Task 10 the drag asks for iPadOS's narrowest window (the window's width minus 375 pt), the test skips when that window stays regular, and the teardown fails unless the window is as wide as before (Task 8 review: the half-screen drag was tuned on the iPad Air 11). The half-screen version also passed on an iPad Pro 13-inch (M5) 26.5, so no device was red for it; the change removes the dependence, and the new version passes there and on an iPad Pro 11-inch (M5) 27.

## 5. The real channel (integration, Task 8)

`liquid_shell/example/integration_test/native_shell_test.dart`, run by `make integration-ios-native`:

- `minimize on scroll is set; its pan only in compact (VK-600)`: `debugSnapshot()` reports `minimizeBehavior` `onScrollDown`, and `minimizePanAttached` equals "compact";
- `the search tab takes the minimize pan off (VK-600 Q5)`: on Home the pan is attached when compact; with the search tab selected it is off and the behaviour stays `onScrollDown`; back on Home it is attached again.

`make integration-ios-native NATIVE_DEVICES="<iPad 26.5>=true;<iPhone 26.5>=true"` (own simulators; 7 min 3 s): every target passed on both, `native_shell_test` 11/11, `native_dialogs_test` 6/6, `native_search_test` 6/6. The VK-600 lines:

| Device | Home | Search selected |
|---|---|---|
| iPad Air 11-inch (M4), 26.5, regular | `minimize onScrollDown pan false compact false` | `search onScrollDown pan false compact false` |
| iPhone 17 Pro, 26.5 | `minimize onScrollDown pan true compact true` | `search onScrollDown pan false compact true` |


## 6. Gates and the UI suite's time (Task 8)

| Gate | Device | Result |
|---|---|---|
| `MinimizeUITests` alone | iPhone 26.5, iPhone 27.0, iPad 26.5, iPad 27.0 | all pass; the iPhone tests skip on an iPad and the iPad tests on an iPhone. Load average up to ~270 |
| `make ios-ui` | iPhone 17 Pro, 26.5 | 28 tests, 26 run, all pass; 534 s (511 s of tests). An earlier run had one failure, `SegmentFidelityUITests.testSequences`. It drives the Runner's own UIKit screen (`segments-native`), with no shell on screen, and passed alone (48.5 s) and in the rerun |
| `make ios-ui` | iPad Air 11-inch (M4), 26.5 | 28 tests, 18 run, all pass; 357 s (326 s of tests). The narrow-window test ran (19.8 s), and the iPad tests after it found the full-size window again |
| `make ios-unit` | iPhone 17 Pro, 26.5 | 180 tests: 162 pass, 18 skipped, 0 failed |
| `make integration-ios-native` | iPad and iPhone, 26.5 | passed, §5 |
| `make verify` | | passed: coverage 97.67 % (`liquid_shell`), 96.49 %, 99.01 %, 100 % |

The `MinimizeUITests` iPhone tests took 81 s of the iPhone run, and its iPad tests 29 s of the iPad run. By the Makefile's earlier scaling (443 s locally was about 1400 s on a slow runner), the iPhone suite is now about 1700 s. That is ~100 s under the old 1800 s cap, where VK-571 had raised the cap at 250 s. `IOS_UI_TIMEOUT` is now 2100 s, and CI's `ios-ui` job allows 45 minutes (commit "the UI suite's cap").

**Red before VK-600 (plan Step 3).** The check on `main` at the rebase base (22830ab) was not run: disk on the shared host was 3.6–8 GB free during this task, below the 10 GB floor, so this task did not do a second build of the example. The same evidence comes from `TabFidelityUITests`. On `main` it asserts that `app.swipeUp()` on the `tabs` demo leaves the native bar whole, and it passes there (CI). With VK-600 that assertion failed, because the same swipe now minimizes the bar (§4). So `testAScrollMinimizesAndAFlingToTheTopExpands` would fail on "a swipe up minimizes" before Tasks 3–6.

## 7. The bottom scroll-edge effect, before and after (R3, Q12, Task 10)

**Run.** `vk600 t10 iPhone 26.5` (iPhone 17 Pro, iOS 26.5, 23F77), the `tabs` demo. A scratch XCUITest (not committed) waited 4 s after launch and took a screenshot, then dragged the list up 300 pt at 1000 pt/s with a 0.2 s hold before the lift (no fling), waited 4 s and took another. Three builds, the same test:

- `main` at the rebase base `22830ab`, before VK-600 (an export of that commit, built on its own);
- VK-600 at `12a9ba1` with `minimizeOnScroll: false` (a scratch edit of `basic_tabs.dart`);
- VK-600 at `12a9ba1` as committed (`minimizeOnScroll` defaults to true).

All three scrolled to the same rows (Home item 3 at the top). The band compared is the bottom 160 pt (480 px at @3x), the bar and the content around and under it. Pixels that differ by more than 2 % (ImageMagick `compare -metric AE -fuzz 2%`, of 578 880):

| Pair | At rest | Scrolled 300 pt |
|---|---|---|
| VK-600 off vs VK-600 on | 0 (identical) | 203 605 (the bar minimized: expected) |
| `main` vs VK-600 off | 19 905 (3.4 %) | 21 068 (3.6 %) |
| `main` vs VK-600 on | 19 905 (3.4 %) | 185 811 (the minimized bar) |
| `main` vs VK-600 on, proxy `bottomEdgeEffect.isHidden = true` (scratch) | 8 241 (1.4 %), inside the bar only | |

**The difference is visible.** Since VK-600, the content near the bottom edge, under and beside the bar, is softly blurred: UIKit's bottom scroll-edge effect, which `setContentScrollView(minimizeProxy, for: .bottom)` turns on. It is the look of a native `UITabBarController` over a scroll view. Before VK-600 no scroll view was registered for the bottom edge, and the content there stayed sharp. It does not depend on `minimizeOnScroll`: off and on are identical at rest. A scratch build that set the proxy's public `bottomEdgeEffect.isHidden = true` (iOS 26 API) matched `main` everywhere outside the bar. Inside the bar 1.4 % of the band still differed: the glass of the selected tab's pill and the bar's top highlight. That build was not committed and was not run through the suites.

- `r3_bands.png`, at 50 %. Left column, at rest: `main`, VK-600, VK-600 with the effect hidden. Right column, scrolled: `main`, VK-600 off, VK-600 on (minimized).
- `r3_zoom.png`, at 100 %, at rest: `main` (left) and VK-600 (right), the left half of the bar. The rows under the bar ("Home item 9", "Scroll to see…") are sharp before and blurred after.

**Q12 is therefore not met as written** ("accepted if the before and after screenshots look the same"). Per the plan, this is a new question for the owner before merge, **Q14**:

| Choice | Meaning | Work |
|---|---|---|
| **A** (recommended) | Keep UIKit's bottom scroll-edge effect: the native look | None in code; one CHANGELOG line ("the native bar now draws UIKit's bottom scroll-edge effect") |
| **B** | Hide it: `minimizeProxy.bottomEdgeEffect.isHidden = true` in `TabHostController.viewDidLoad` | A small TDD task (XCTest red first), then `make ios-unit` and `make ios-ui` again; `MinimizeUITests` shows whether the minimize still works with the effect hidden |

The final review added **A′**: keep the effect while the bar may minimize, and hide it when `minimizeOnScroll` is `false`, so that `false` is a real way back to the old look.

**Decision (owner, 2026-10-15): A′** ("làm theo đề xuất"). `MinimizeProxy.hidesBottomEdgeEffect(minimizeOnScroll:)` returns `!minimizeOnScroll`, and `NativeTabsController.apply` sets `bottomEdgeEffect.isHidden` on every proxy, also on hosts a rebuild creates. XCTest `testTheBottomEdgeEffectShowsOnlyWhileTheBarMayMinimize` went red first (with A, hidden was false for `minimizeOnScroll: false`), then green.
- **Minimize on (the default):** the native look, as measured above (VK-600 on vs `main`: 3.4 % of the band at rest).
- **`minimizeOnScroll: false`:** the effect is hidden. That is the scratch build in the table above (`main` vs VK-600 with the effect hidden), which matched `main` everywhere outside the bar; 1.4 % of the band still differed inside the bar (the selected pill's glass and the bar's top highlight). The committed A′ build was not screenshotted again.
- Q12 is closed for the default by the owner's acceptance of the native look, and for `false` by the match outside the bar.

## 8. Gates (Task 10)

- **Code:** `12a9ba1` (the carried review fixes on top of `3bad9e6`). Task 10 then adds only this file, `manual.md` and the two R3 images.
- **Simulators,** each created for this task and deleted after it: `vk600 t10 iPhone 26.5` and `vk600 t10 iPhone 27` (iPhone 17 Pro); `vk600 t10 iPad 26.5` and `vk600 t10 iPad 27` (iPad Pro 11-inch (M5)); `vk600 t10 iPad13 26.5` (iPad Pro 13-inch (M5)), used only for the narrow-window test. `make tab-traces` and `make segment-traces` create and delete their own.
- **Toolchain:** Xcode 27.0 (27A266a), Flutter 3.44.6 (fvm).
- **Host:** shared. The load average ran from 3 to 130, and other sessions held free disk between 5 and 16 GB.

| Gate | Device | Result |
|---|---|---|
| `make verify` | | passed in 3 min 12 s. `dart format`: 237 files, 0 changed. `dart analyze`: no issues. Provenance and the glass seam: clean. Pigeon: output matches its source. Tests: `liquid_shell` 1199, `liquid_shell_platform_interface` 50, `liquid_shell_ios` 36, `liquid_shell_android` 1, the example 160, `tool` 113; `test-impeller` 19. Coverage: 97.67 % (5287/5413), 96.49 % (357/370), 99.01 % (200/202), 100 % (2/2). Goldens: 36 and 27 (liquid). Snippets: 19 match |
| `make test-impeller` | | 19 passed (12 s) |
| `make ios-unit` | iPhone 17 Pro, 26.5 | 180 tests: 162 passed, 18 skipped, 0 failed (194 s) |
| `make ios-unit` | iPad Pro 11-inch (M5), 27.0 | 180 tests: 176 passed, 4 skipped, 0 failed (230 s) |
| `make ios-ui` | iPhone 17 Pro, 26.5 | 28 tests: 26 passed, 2 skipped, 0 failed (529 s; `MinimizeUITests` 82 s) |
| `make ios-ui` | iPad Pro 11-inch (M5), 27.0 | 28 tests: 18 passed, 10 skipped, 0 failed (424 s). The narrow-window test ran (33 s), and the regular-width test after it found the window wide again |
| `make ios-ui` | iPhone 17 Pro, 27.0 | 28 tests: 26 passed, 2 skipped, 0 failed (623 s; `MinimizeUITests` 99 s). `TabFidelityUITests` passed on 27.0 too (Task 8 review, "cannot verify" b) |
| `make integration-ios-native` | iPad Pro 11 (M5) and iPhone 17 Pro, 26.5 | passed (435 s): `native_shell_test` 11/11, `native_dialogs_test` 6/6, `native_search_test` 6/6 on each |
| `make integration-ios-native` | iPad Pro 11 (M5) and iPhone 17 Pro, 27.0 | passed (429 s): 11/11, 6/6, 6/6 on each |
| `make integration-ios` | iPhone 17 Pro and iPad Pro 11 (M5), 26.5 | passed: `signals_test` 4/4 on each |
| `make tab-traces` | its own iPhone 17 Pro, 26.5 | 99/100: the known `colour lightFillPage` (242/241/249 against 242/240/254, as in VK-503 and VK-550). A first run, while the load average rose from 16 to about 80, also failed six `press` timing rows: Flutter's press grew 2.6–3.9 pt (1 % in scale) behind native's at +100 to +200 ms. The rerun passed them |
| `make segment-traces` | its own iPhone 17 Pro, 26.5 | three runs, each 190/191. Each time one `frames` condition failed: a single frame of 33–50 ms (`dark.tap_1_2` twice, `tap_1_2` once). Every motion row passed. `main` at `22830ab`, run once at the same load, failed 3/191: the same two `frames` conditions and one motion row. Single dropped frames on this shared host are VK-550's known item (`docs/qa/vk550/acceptance.md` §3, item 6), and VK-600 does not touch the segmented control |
| `bash .githooks/pre-commit` | | passed before every commit of this task |

The `minimize` integration lines, on both runtimes:

| Device | Home | Search selected |
|---|---|---|
| iPad Pro 11-inch (M5), regular (26.5 and 27.0) | `minimize onScrollDown pan false compact false` | `search onScrollDown pan false compact false` |
| iPhone 17 Pro (26.5 and 27.0) | `minimize onScrollDown pan true compact true` | `search onScrollDown pan false compact true` |

**Red before VK-600 (Task 8, plan Step 3).** §7's `main` build at `22830ab` gives the evidence Task 8 could not, from the same 300 pt drag. Native chrome on, the bar stayed whole on `main` (`main_base_scrolled`), and VK-600 minimized it. So `testAScrollMinimizesAndAFlingToTheTopExpands` fails "a swipe up minimizes" before VK-600.
