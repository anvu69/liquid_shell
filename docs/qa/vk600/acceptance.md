# VK-600 acceptance: the native tab bar minimizes on scroll

Evidence for spec `docs/specs/2026-10-14-native-tab-minimize-design.md` §12.5 (XCUITest) and §12.2 (the real channel). Task 10 adds the device checklist and its results.

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

So the first tap goes to Flutter's accessibility mirror of the list. It has `scrollsToTop` on, and UIKit scrolls it, not Flutter's content. Once the mirror is at the top, the next tap reaches Flutter's own status-bar scroll view, and the `Scaffold` scrolls the list. The mirror exists only while semantics are on, as under XCUITest or VoiceOver. Native chrome or not, the behaviour is the same. Flutter's engine owns the mirror, so this is not something VK-600 can change. liquid_shell's proxies never take the tap: `scrollsToTop` is 0 (Q10). The test taps a second time only when the first one leaves the list where it was, and says why.

## 4. XCUITest (Task 8)

`MinimizeUITests`. The iPhone tests skip on an iPad, and the iPad test skips on an iPhone.

| Test | Demo | What it proves |
|---|---|---|
| `testAScrollMinimizesAndAFlingToTheTopExpands` | `tabs` | A real swipe minimizes. A slow reverse drag in mid-content keeps it minimized for 1.5 s. A fling to the top expands |
| `testATapOnTheCircleExpands` | `tabs` | A tap on the circle expands |
| `testFlutterGetsTheDragAndTheTapAndTheAppsTabChangeExpands` | `minimize` | With the pan attached, Flutter's list moves under the drag (more than 200 pt). Minimized, a tap reaches Flutter ("Next tab"). The app's tab change expands the bar (Q4, the `.never` toggle) |
| `testAStatusBarTapScrollsToTheTopAndExpands` | `minimize` | A status-bar tap scrolls Flutter to the top, and that programmatic scroll expands the bar (Q3, the `.never` toggle). The tap reaches Flutter, so no proxy competes for it (Q10) |
| `testTheSearchTabFromAMinimizedBarKeepsItsFieldScopesAndKeyboard` | `search` | Q5. Minimized on Library, the ⌕ opens the search with no keyboard (Q13). A drag on the search page leaves the field's frame unchanged. A tap on the field brings the keyboard. "pho" shows UIKit's scope bar at the top, and "Songs" filters. × dismisses the keyboard. Back on Library, the bar is expanded |
| `testTheRegularTopBarNeverMinimizes` | `tabs` | iPad, regular width. The drag scrolls the list by more than 200 pt, and the top bar stays whole |
| `testANarrowIPadWindowMinimizesLikeAnIPhone` | `tabs` | iPad, narrow window (Q6). It is compact, with the bottom bar. A swipe minimizes and a fling to the top expands, as on an iPhone. Skipped when the simulator has no resize grabber (not in Windowed Apps) |

The `minimize` demo (`liquid_shell/example/lib/support/minimize_demo.dart`) adds what the `tabs` demo lacks: a `Scaffold` above the shell, which handles the status-bar tap, and an app-driven "Next tab". UIKit alone keeps the bar minimized after a programmatic scroll to the top and after a programmatic tab change (spike §3.2). The two expands therefore come from liquid_shell's `.never` toggle.

`TabFidelityUITests.testSequences` used to assert that the native swipe did *not* minimize the bar (VK-503). With VK-600 it failed there, as expected: "native: the swipe scrolls the page and the bar does not minimize". It now asserts the minimize. The tap at the circle's centre, (52, 822) on an iPhone 17 Pro, is also the centre of UIKit's minimized circle, so it now expands the native bar, as in the Flutter run. `docs/qa/vk503/acceptance.md` (strip 7 "is a scroll") records the state before VK-600.

**A narrow iPad window.** The iPad simulators (26.5 and 27.0) start in iPadOS 26's Windowed Apps mode (Settings › Multitasking & Gestures). SpringBoard gives the app's window a resize grabber (`resize-grabber`, "Resize Liquid Shell Example", value "Bottom Right"). The test drags it half the screen's width to the left. On the 27.0 iPad the window went from 820 × 1180 to 375–410 pt wide, compact, with UIKit's bottom tab bar ("Home" 94 × 54 near the window's bottom). iPadOS keeps a window's size for the next launch, so the test drags the grabber back to the screen's bottom-right corner when it ends. That restored 820 × 1180 in the probe. The window does not start at the screen's origin: one probe window sat at (223, 83), while `XCUIApplication.frame` still reported (0, 0). So every drag in `MinimizeUITests` is relative to the window.

## 5. The real channel (integration, Task 8)

`liquid_shell/example/integration_test/native_shell_test.dart`, run by `make integration-ios-native`:

- `minimize on scroll is set; its pan only in compact (VK-600)`: `debugSnapshot()` reports `minimizeBehavior` `onScrollDown`, and `minimizePanAttached` equals "compact";
- `the search tab takes the minimize pan off (VK-600 Q5)`: on Home the pan is attached when compact; with the search tab selected it is off and the behaviour stays `onScrollDown`; back on Home it is attached again.

`make integration-ios-native NATIVE_DEVICES="<iPad 26.5>=true;<iPhone 26.5>=true"` (own simulators; 7 min 3 s): every target passed on both, `native_shell_test` 11/11, `native_dialogs_test` 6/6, `native_search_test` 6/6. The VK-600 lines:

| Device | Home | Search selected |
|---|---|---|
| iPad Air 11-inch (M4), 26.5, regular | `minimize onScrollDown pan false compact false` | `search onScrollDown pan false compact false` |
| iPhone 17 Pro, 26.5 | `minimize onScrollDown pan true compact true` | `search onScrollDown pan false compact true` |

