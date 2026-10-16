# liquid_shell VK-626, VK-633, VK-634: the flaky iOS tests, and the search activation they exposed

- **Plane:** VK-626 (the `ios-unit` flakes: groups 1A and 1B, and the segv), VK-634 (the product race behind 1A), VK-633 (`MinimizeUITests`).
- **Date:** 2026-10-16
- **Status:** approved. The owner decided Q1–Q8 on 2026-10-16 (table at the end). Plan: `docs/plans/2026-10-16-ios-test-flakes.md`. The choices this spec had to add are listed in "Quyết định phát sinh khi viết spec", after the table.
- **Branch:** `VK-626-ios-test-flakes`, from `7617a7c` (the head of VK-625's PR #16, since merged into `main` as `3508f1f`).
- **Kind of change:**
  - one product fix in `liquid_shell_ios` (Swift): `SearchBridge.swift`, `NativeTabsController.swift`, and `PageHostController` in `ShellNavController.swift`;
  - tests: the example's `RunnerTests.swift` (XCTest) and `MinimizeUITests.swift` (XCUITest);
  - one CHANGELOG line in `liquid_shell_ios/CHANGELOG.md` (Q7), and `docs/`.
  - No Dart, Pigeon, CI or tooling change. No version bump, nothing published (Q7).
- **Sources:**
  - The VK-626 evidence report (phase 1 of systematic debugging, 2026-10-16, kept with the Plane item). It read the logs of every failed `ios-unit`, `ios-ui` and `ios-minimize` job in the last 60 `ci` runs, and four result bundles with `xcresulttool`, the test host's stdout included. It also ran local probes on its own iPhone 17 and iPad (A16) simulators (iOS 26.5, Xcode 27.0), deleted afterwards. Every CI or probe number below comes from it.
  - The code at `7617a7c`. File:line pointers below are to that commit.
  - VK-550's spike §1 (`docs/qa/vk550/spike.md`): the one scope-bar setup UIKit draws in a search tab.
  - VK-625's measurement (`docs/qa/vk625/measurement.md`): the six runs in which 1A, 1B and VK-633 went red.

> **Tóm tắt (cho chủ sản phẩm).**
> - **Ba nhóm lỗi, một nhánh (Q1):**
>   - **1A (VK-634) là lỗi thật của gói.** Dart chọn tab tìm kiếm rồi kích hoạt ô tìm ngay sau đó (deep link, lệnh "focus search"). Lúc ấy trang gốc của tab tìm kiếm chưa vào cửa sổ, nên UIKit từ chối mở ô tìm. Đường cứu hiện có chỉ thắng khoảng 6 trên 7 lần. Lần thua thì:
>     - ô tìm không bao giờ mở, không có bàn phím;
>     - Dart không nhận được `searchActive true`;
>     - thanh phạm vi (scope bar) vẫn hiện dưới một ô tìm chưa mở.
>   - **1B (VK-626):** runner CI thỉnh thoảng đứng vài giây. Báo cáo đến trễ (3,0–3,5 s) chứ không mất, mà test chỉ chờ 3 s.
>   - **Segv (VK-626):** một lần crash trong khoảng 80 job, chưa rõ nguyên nhân.
>   - **VK-633:** trên runner chậm, cú kéo 300 pt thành cú vuốt khoảng 850 pt. Hàng "Home item 6" rời cây accessibility, và test đỏ ngay khi đọc `frame` của một phần tử không còn.
> - **Cách sửa:**
>   - **1A:** khi UIKit từ chối, `SearchBridge` giữ lại lời kích hoạt và thực hiện nó khi trang gốc của tab tìm kiếm đã vào cửa sổ (`viewDidAppear`). Dart tắt tìm kiếm, rời tab hoặc ẩn chrome (luật VK-551) thì lời kích hoạt bị huỷ. Lần bị từ chối không còn để lại thanh phạm vi. Viết trước một test đỏ chắc chắn, không phụ thuộc may rủi. Test cũ giữ làm lớp bảo vệ.
>   - **1B:** thời gian chờ mặc định 3 s → 10 s. Lần chờ nào quá 3 s vẫn được in ra.
>   - **Segv:** không sửa. Lần sau CI giữ crash report thì đọc nó.
>   - **VK-633:** chỉ sửa test. Hàng đã rời cây được tính là "đã cuộn". Phải có hàng thì mới so vị trí "đã về đầu danh sách". Không làm chậm cú kéo.
> - **Đo:** 3 lần chạy CI bằng `workflow_dispatch`. **Đạt** khi không job chặn merge nào đỏ vì 1A, 1B hay VK-633. Không đạt thì dừng và báo cáo, không sửa mò.
> - **Khác:** một dòng CHANGELOG cho 1A trong `liquid_shell_ios`. Không đổi phiên bản, không phát hành, không kiểm tra trên máy thật.
> - **Cần chủ sản phẩm biết:**
>   - Dòng in "chờ quá 3 s" nằm trong result bundle. CI chỉ tải bundle lên khi job đỏ, nên ở lần chạy xanh không thấy dòng này (mục phát sinh 6).
>   - Nếu Dart kích hoạt lúc có một trang con đè lên trang gốc tab tìm kiếm, lời kích hoạt bị bỏ như trước, và push một trang lên trang gốc thì huỷ lời kích hoạt đang giữ. Deep link pop về trang gốc rồi kích hoạt ngay thì ô tìm vẫn mở. Chủ sản phẩm chọn ngày 2026-10-16 (mục phát sinh 3).

---

## 1. Goal

1. Dart's activation of the native search is never lost because the search root was not in a window yet (VK-634). A refused presentation leaves no scope bar on an inactive search.
2. The `ios-unit` waits for a search report survive the CI runner's multi-second stalls (VK-626, 1B).
3. `MinimizeUITests` reads a row that left the accessibility tree as scrolled, instead of failing on the read (VK-633).
4. The segv waits for the crash report that CI now keeps (VK-626, Q4).

Success:
- a deterministic red-then-green XCTest for 1A;
- the existing 1A test, kept as a guard, stays green;
- three CI runs with no blocking job red from 1A, 1B or VK-633 (§9).

## 2. Scope

### 2.1 In

- **1A (VK-634):** a pending activation in `SearchBridge`, applied from the search root's `viewDidAppear` (§4). Two new XCTests. One CHANGELOG line (§10).
- **1B (VK-626):** `settle(sending:within:_:)` waits 10 s by default (§5). One new XCTest.
- **VK-633:** `MinimizeUITests` reads a row's frame through one snapshot, and a missing row counts as scrolled (§7).
- **Segv (VK-626):** the evidence is recorded (§3.3). Its crash report is read when one exists, during the measurement (§6, §9.4).
- **Measurement:** three dispatched CI runs, recorded in `docs/qa/vk626/measurement.md` (§9).

### 2.2 Non-goals

- A segv fix (Q4). The evidence's approaches B (a quiet second engine) and C (no `destroyContext()`) wait for the crash report.
- A slower drag in `MinimizeUITests` (Q5).
- Finding what stalls the CI runner (1B hypothesis 1: unidentified).
- Any other wait: `settle()` (0.5 s), `stable(timeout: 5)`, the UI suite's 10 s.
- The `ios-ui (iPhone)` red of `testATapOnTheCircleExpands` ("minimized") in run 38819151747: the evidence names it as adjacent and does not analyse it.
- The VK-627 build error, the missing iOS 27 runtimes, Android infrastructure.
- A device check (Q8).
- A CI change to show slow waits in green runs (§5, addition 6).

## 3. What the evidence shows

### 3.1 1A: an activation before the search root is in a window (VK-634)

**The test.** `NativeTabsTests/testEnteringSearchTogglesNothingAndLeavesTheScopeBarAndKeyboardAlone`, `RunnerTests.swift:1708-1734`:
1. it installs a compact search shell with scopes (`:1709`), then turns minimize on (`:1712`);
2. it selects the search tab: `apply(searchConfig(selected: 2, …))` (`:1715`);
3. **at once** it activates: `settle(sending: "searchActive true", within: 10) { tabs.setSearchActive(true) }` (`:1725`);
4. it expects the field to be first responder (`:1726`).

**The path of the signal:**
- `NativeTabsController.setSearchActive` (`NativeTabsController.swift:640-647`) calls `SearchBridge.activate()` (`SearchBridge.swift:131-145`).
- `activate()` sets `controller.isActive = true`. It retries only when a dismissal is still running (`:134`). Otherwise it asks for `becomeFirstResponder()` on the next main-queue turn (`:142-144`).
- UIKit calls `didPresentSearchController` (`:226-228`), which calls `onActive(true)` when `canReport()` holds (`NativeTabsController.swift:81-84`). That sends `onSearchActiveChanged`, recorded as `"searchActive true"`.

**The failing runs:**
- iPhone, run 38819171451 (budget 10 s) and run 38720891102 (budget 3 s). Both have the same payload: `no searchActive true within 10 s: ["state", "controls", "field", "field", "field"]`, then "the keyboard comes with the search".
- The scope-bar asserts passed, so `willPresent` had run. The test took 13.0 s, against about 2 s normally.
- The host's stdout, 21 lines before the failure: `Attempt to present <UISearchController …> on <liquid_shell_ios.PageHostController …> … whose view is not in the window hierarchy.`
- Both iPad bundles passed this test but logged the same refusal. Every run of this test is refused; it fails only when the recovery loses.

**Local reproduction** (the decisive evidence):

| Variant | Runs | Refused ("not in the window hierarchy") | Never presented (≥ 60 s) |
|---|---|---|---|
| Immediate, iPhone compact (the test and four probes, ± minimize, ± scopes) | 36 | 36 | **5** (14 %) |
| Immediate, iPad regular | 10 | 10 | **3** |
| Settled 0.5 s first, iPhone | 23 | 0 | 0 |
| Settled 0.5 s first, iPad (5 of them under 16 busy-loop processes) | 15 | 0 | 0 |

- **Right after `isActive = true`:** the root was in no window, and `isActive=false`, no transition coordinator, nothing presented, `showsScopeBar=true`. UIKit refused, but `willPresent` had already shown the scope bar.
- **On the next main-queue turn, 18 of 20 runs:** the root was in the window, and the field's `becomeFirstResponder` made UIKit present the search, as a user's tap does. The report followed in 0.45–0.68 s.
- **2 of 20:** the root was still in no window, so the field's request failed. Nothing ever retried. After 60 s, `isActive=false`, and the scope bar was still drawn.
- **Load plays no part:** the main-thread stall monitor read 0.00 s in every failing local run.

**Root cause:**
- `activate()` relies on its next-turn `becomeFirstResponder` running after the layout pass that puts the newly selected tab's view in the window.
- The order between main-queue blocks and the run loop's layout and Core Animation observers is not guaranteed.

**Product impact: yes.**
- Dart's `LiquidSearchController.activate()` (`shell_search.dart:278-297`) is allowed as soon as Dart's `selected` is true. A deep link or a "focus search" command sends the search-tab config and `setSearchActive(true)` back to back.
- About one time in seven (iPhone; three in ten on the iPad):
  - the search tab shows, but the search is not active, and there is no keyboard;
  - the scope bar is drawn under an inactive field;
  - Dart never hears `searchActive true`.
- A tap on the field recovers.

### 3.2 1B: a 3 s budget against the runner's stalls (VK-626)

- **The tests:**
  - `testActivationNeedsTheSearchTabAndADartDismissalKeepsTheText` (`RunnerTests.swift:2275-2292`), iPad, run 38819151747;
  - `testAnActivationResetsADismissalThatNeverEnded` (`:2469-2482`), iPad, run 38819171451;
  - earlier, `testAUserScopeChangePutsTheKeyboardAwayAndKeepsTheSearch`, iPhone, run 38622494199.
- **Late, not lost:**
  - In 38819151747 the wait failed with `no searchActive true within 3 s`. The asserts right after it passed (`:2286-2287`): once `settle()`'s 0.5 s was done, `isActive` was true and `"searchActive true"` was recorded.
  - So the report came between 3.0 and about 3.5 s.
- **No refusal in either test:** the 1A signature is absent from both hosts' stdout.
- **The runner stalls for seconds, one test at a time:**
  - `testACompactShellShowsTheBottomTabBarInFluttersBottomSafeArea`, whose longest wait is 0.5 s, took 38.1 s (iPad) and 15.5 s (iPhone) in 38819171451, against 0.7–1.8 s elsewhere.
  - The failing tests ran 7–13 s longer than their own normal runs.
- **Locally:** 34 waits on the iPad, median 0.47 s, max 0.575 s. Host CPU load does not reproduce the stall.
- **Product impact:** none. A slow presentation reports later, and Dart waits for the report.

### 3.3 The segv (VK-626)

- **The test:** `PluginDialogWiringTests/testDetachingFromTheEngineAnswersAnOpenAlertDismissed` (`RunnerTests.swift:3529-3570`).
  - It starts a second `FlutterEngine` that runs the example's whole `main()`, shows its `FlutterViewController` in a key window, and presents an alert.
  - Then it calls `detachFromEngine`, and its teardown destroys the engine's context.
- **The one occurrence:** run 38729861858, job 116404684170, `ios-unit (iPhone)`: "Test crashed with signal segv". About 1 in 80 `ios-unit` jobs. No stack, and no crash report from that run.
- **Locally:** 60 of 60 green under 12 busy-loop processes.
- **Weak corroboration:** a local test-host crash report of 2026-10-14. It shows `SIGSEGV`, `KERN_INVALID_ADDRESS 0x10`, on `io.flutter.1.raster`, in `flutter::LayerStateStack::set_preroll_delegate` ← `LayerTree::Preroll` ← `Rasterizer::DrawToSurfaces`. Which test was running is unknown.
- **The plugin is not implicated by its code:** the second `detachFromEngine`, from `-[FlutterEngine dealloc]`, is safe.
- **Ranked hypotheses:**
  1. An engine-teardown race: the second engine is destroyed while its raster or worker threads still draw or compile pipelines. CI logs pipeline builds of 0.7–2.5 s (low-medium).
  2. A raster crash of the host engine, set off by the test's window churn (low).
  3. Plugin code (very low).
- **Product impact:** none found.

### 3.4 VK-633: the drag became a fling, and the row left the tree

- **The failure:** `MinimizeUITests/testAStatusBarTapScrollsToTheTopAndExpands`, `ios-minimize (iPhone)`, run 38819151747, job 116711183429.
  - The message was `Failed to get matching snapshot: No matches found … 'label BEGINSWITH "Home item 6"'`, at `MinimizeUITests.swift:249`, before any status-bar tap.
  - `continueAfterFailure = false` (`:13`) ended the test there.
- **What happened:**
  - "Synthesize event" took 2.3 s for a 0.55 s gesture.
  - The recording has no frame from 39.34 s to 41.40 s. Then the list moved about 830–860 pt for a 300 pt drag, decelerating over 2 s: a fling after release.
  - At the failure, row 6 was missing from the hierarchy, rows 7 and 8 were zero-size off-screen nodes, and the bar was minimized (`waitMinimized(true)` at `:248` had passed).
- **The mechanism:**
  - On iOS, Flutter decides the finger stopped with `IOSScrollViewFlingVelocityTracker`. Its check is a wall-clock stopwatch reset at processing time: zero velocity only after 40 ms of processing time (`velocity_tracker.dart:142, 151-153, 309-310, 350-351`).
  - With the main thread stalled (Dart runs on it, VK-625 §3.3), the moves, the 0.2 s hold and the lift arrive in one burst. The hold collapses, and the list flings at the drag's own velocity.
- **The same read is at `:225`** (`testFlutterGetsTheDragAndTheTapAndTheAppsTabChangeExpands`). `atTop` (`:262`) reads `row.frame` too.
- **Product impact:** none for liquid_shell. The bar minimized as it should.

### 3.5 What the code at `7617a7c` adds to the evidence

1. **Q3's print already exists.** `settle(sending:)` prints a wait longer than 3 s (`RunnerTests.swift:1967-1968`, since `af2393a`, VK-600). Where it lands:
   - Under `xcodebuild -quiet` the test host's stdout never reaches the job log. The red iPad job 116711183435 shows the failing test name and the summary, and no test output.
   - The print is in the result bundle's diagnostics (`xcresulttool export diagnostics`), which CI uploads on a red run only (`ci.yaml:210-222`).
2. **The crash-report step came with VK-600.** `09105ee` (2026-10-15) keeps `Runner-*.ips` for a red `ios-unit` or `ios-ui` job; VK-625 added it to `ios-minimize`. The evidence dates the step to VK-625. Either way, the segv run 38729861858 had no crash report.
3. **The VK-633 read is in four tests, not two.** The evidence names `:249` and `:225`. The same `XCTAssertLessThan(row.frame.minY, before - 200, …)` is also at:
   - `:175`, `testTheRegularTopBarNeverMinimizes` ("Home item 12");
   - `:360`, `testANarrowIPadWindowMinimizesLikeAnIPhone` ("Home item 8").
   
   Both are iPad-only, so they run in the non-blocking `ios-ui (iPad)`, never in `ios-minimize (iPhone)`.
4. **`SearchScopeBridgeTests` call `willPresentSearchController` by hand** and expect the scope bar (`RunnerTests.swift:3042-3063`). The design keeps `willPresent` showing it (§4.4), so these tests stay as they are.
5. **`activate()` has two more callers:** `debugTap(.searchField)` (`NativeTabsController.swift:606-608`) and `didDismiss`'s re-activation (`SearchBridge.swift:232-241`). Both get the same rule.
6. **The installer never applies a config to a shell outside a window** (`NativeShellInstaller.swift:208-213`). So in the product the window race is between the tab controller and the search root, never the whole shell (§8, risks).

## 4. Design: 1A (VK-634), a kept activation

### 4.1 The state

`SearchBridge` gains `private(set) var activationPending = false`, next to `activateAfterDismiss`.

After `controller.isActive = true`, `activate()` reads one of three outcomes:

| `isActive` after the set | `transitionCoordinator` | Meaning | Before | After |
|---|---|---|---|---|
| true | any | the presentation started | restore the kept text; focus the field on the next turn | unchanged |
| false | non-nil | a dismissal is still running | `activateAfterDismiss = true` | unchanged |
| false | nil | **refused**: the search root is in no window (36 of 36 immediate activations) | fell through to the next-turn focus, which won about 6 times in 7 | `activationPending = canKeepActivation()`: true only while the search tab is selected, the chrome is shown and the search root is the top of its stack (else dropped, §4.3); the scope bar follows `isActive` (§4.4); return |

After a refusal the next-turn focus no longer runs:
- the root's appearance is now the one recovery path, and it is deterministic;
- a cancel (§4.3) then cancels everything. A next-turn focus already queued could otherwise present a search that Dart had just deactivated.

### 4.2 Where it is applied: the search root's `viewDidAppear`

- `PageHostController.viewDidAppear(_:)` calls `NativeTabsController.searchRootAppeared(self)`.
- The shell goes on only when all of these hold:
  - this host is the search tab's root (`navControllers[searchIndex]?.rootHost === host`);
  - the search tab is selected (`isSearchSelected`);
  - the chrome is shown (`chromeVisible`).
  
  Those are `setSearchActive`'s own conditions (VK-551).
- Then the shell calls `SearchBridge.applyPendingActivation()`. If an activation is pending, that clears it, and if the search is not active, calls `activate()`.

**Why `viewDidAppear`** (Q2 asked the design to pick one):
1. It fires when the evidence's condition becomes true (the root's view is in the window), whatever brought it there: the first install, a tab selection, a scene reconnect's reinstall, a pop back to the root.
2. `viewDidAppear` comes after the appearance transition, and `viewIsAppearing` comes inside it. Starting the search's presentation inside the tab's own appearance transition would overlap two UIKit transitions. This design avoids that overlap rather than probing it.
3. The selection transition's completion needs the tab controller's `transitionCoordinator`. The shell selects programmatically inside `apply` (`selectedTab = tab`, after `setTabs(_, animated: false)`), where a coordinator is not guaranteed. Without one there is no completion to hook, so that design would need this hook as a fallback anyway.

- **Cost:** when the old next-turn focus won, the search came a little sooner. Now it comes after the appearance transition.

### 4.3 What ends it, and `activateAfterDismiss`

| Event | `activateAfterDismiss` | `activationPending` |
|---|---|---|
| `activate()` starts | cleared (today) | cleared |
| `willPresentSearchController` (any presentation, the user's tap included) | cleared (today) | **cleared**: the search came; a later appearance of the root must not bring it back after the user closed it |
| `dismissKeepingText()`, which serves Dart's `setSearchActive(false)`, leaving the search tab (`select`, `NativeTabsController.swift:388-397`), a rebuild (`:257`) and hidden chrome (`apply`, `:236`, VK-551) | cleared (today) | **cleared, before its `guard controller.isActive`**: a pending search is not active |
| `didDismiss` with `activateAfterDismiss` | cleared; `activate()` on the next turn (today) | if that activation is refused: pending only when the search root is on top of its stack (otherwise dropped, addition 3), and `searchActive false` is still reported (`!isActive && !activateAfterDismiss`, `SearchBridge.swift:239`), so Dart hears what UIKit did |
| A refusal while a page is pushed over the search root (the search tab's stack top is not the root; `canKeepActivation`) | — | **not set**: dropped, as before VK-634 (the owner's choice, addition 3). `syncScopeBar()` still runs, so no scope bar is left |
| A refusal while the search tab is not selected or the chrome is hidden (`canKeepActivation`; for example `didDismiss`'s deferred `activate()` after Dart left the tab) | — | **not set**: the invariant "pending ⇒ search tab selected and chrome shown" holds while the activation is kept, not only when it is applied |
| Dart's config pushes a page over the search root (`apply`, after the pages: `dropPendingActivation()`) | — | **cleared** (addition 3): the pop back must not bring the search |
| The root's `viewDidAppear`, search tab selected, chrome shown | — | applied, and cleared |

### 4.4 The scope bar

- **Before:** shown in `willPresentSearchController`, hidden in `willDismissSearchController`. VK-550's spike §1 found this the only setup UIKit draws on iPhone and iPad, iOS 26.5 and 27. A refused presentation runs `willPresent` and is never dismissed, so its scope bar stays.
- **After:** one rule, `syncScopeBar()`: the bar is shown if and only if Dart sent two or more titles and `controller.isActive` holds. `setScopes` already computes exactly this (`SearchBridge.swift:83-84`); the two lines move into the new function.
- `willPresent` still shows the bar, so a presentation that starts looks as VK-550 measured it. After a refused `isActive = true`, `activate()` calls `syncScopeBar()`. That hides the bar in the same run-loop turn, before any frame is drawn.
- So the bar is shown only while UIKit's `isActive` holds, never by `willPresent` alone (Q2). `didPresent` needs no call: a presentation that started already shows it.

### 4.5 Reports to Dart

- No new message, no channel change.
- `searchActive true` still comes only from `didPresent`, under `canReport()`. It now also comes when a kept activation is applied.
- A kept activation that ends (§4.3) reports nothing. Dart never heard `true`, and Dart's `activate()` waits for the report (`shell_search.dart:278-297`).

### 4.6 Vietnamese IME safety (checked against the three rules)

- **Never rebuild a focused field.** The search controller, its bar and its field stay the same objects, and no tab rebuild is added.
- **Never write while composing.**
  - The fix writes no text.
  - A kept activation is applied only while the search is inactive. Its field is then not first responder, so no composition can be running.
  - The applied `activate()` runs today's `restoreKept()` (VK-551) only after a presentation has started.
- **The native→Dart query bridge stays one-way.**
  - The only report is `searchActive true` from `didPresent`.
  - `syncScopeBar()` changes the scope bar's visibility, never `selectedScopeButtonIndex`, so no scope change is reported.
- The composition tests (`testDartsTextWaitsForTheIMECompositionToEnd`, `testAnIMECommitWinsOverDartsPendingText`, `testDismissingTheKeyboardMidCompositionReportsTheCommit`, …) stay in the suite and must stay green.

### 4.7 Code

| File | Change |
|---|---|
| `SearchBridge.swift` | `private(set) var activationPending`; `activate()` keeps a refused activation when `canKeepActivation()` allows it; `func applyPendingActivation()`; `func dropPendingActivation()`; `private func syncScopeBar()`, used by `setScopes` and after a refusal; `dismissKeepingText()` and `willPresentSearchController(_:)` clear the flag; the header comment |
| `NativeTabsController.swift` | `func searchRootAppeared(_ host: PageHostController)`; `private var isSearchRootOnTop`, which feeds `canKeepActivation` and, in `apply` after the pages, drops a kept activation (addition 3); `setSearchActive`'s comment |
| `ShellNavController.swift` | `PageHostController.viewDidAppear(_:)` calls `shell?.searchRootAppeared(self)` |

## 5. 1B (VK-626): 10 s by default

- `settle(sending:within:_:)` (`RunnerTests.swift:1953-1971`) waits 10 s by default instead of 3 s.
  - 10 s is the UI suite's wait, and the one 1A's test already passes.
  - The helper waits on the right condition, the report itself, so a longer budget is the honest fix.
  - **Cost:** a report that really is missing costs 10 s per wait instead of 3 s. About 34 such waits in an iPad run stay well inside the 900 s suite cap.
- The print of a wait longer than 3 s stays as it is (`:1967-1968`). It is the record of a slow report that still came (§3.5, addition 6).
- The 1A guard test drops its explicit `within: 10`, now the default.
- A new test pins the default: a report sent 3.5 s after the action counts. It is red at 3 s and green at 10 s, and its green run prints `NativeTabsTests: searchActive true took 3.5 s`.

## 6. The segv (VK-626): no fix now (Q4)

- §3.3 is the record.
- **When a crash report comes:**
  - CI keeps `Runner-*.ips` on a red `ios-unit` job, in the artifact `ios-unit-<device>-diagnostics` (`ci.yaml:207-222`, 7 days).
  - The measurement (§9.4) reads the faulting thread of any such report, and so does whoever meets the next occurrence.
- **Then the owner decides,** between the evidence's approach B and approach C:
  - B: run the second engine with a minimal Dart entry point (`run(withEntrypoint:)` plus a `@pragma('vm:entry-point')` no-op in the example), or wait for its first frame before the teardown;
  - C: release the engine after its view controller, without `destroyContext()`.

## 7. VK-633: test-only (Q5)

`MinimizeUITests.swift` gains two helpers, next to `flutterRow`:

| Helper | Returns |
|---|---|
| `frameInTree(_ element: XCUIElement) -> CGRect?` | `(try? element.snapshot())?.frame`: the frame, or nil when the element is not in the tree. One snapshot answers both "is it there" and "where", so a row that leaves between two queries cannot fail the read. `bar(_:selected:other:)` reads the tab bar the same way (`:35-49`) |
| `scrolled(_ row: XCUIElement, from start: CGFloat, by distance: CGFloat = 200) -> Bool` | true when the row is not in the tree (it went further still), else `frame.minY < start - distance` |

| Place | Before | After |
|---|---|---|
| `:175` (iPad) | `XCTAssertLessThan(row.frame.minY, before - 200, "the drag scrolled the list")` | `XCTAssertTrue(scrolled(row, from: before), …)` |
| `:225` | the same, "the drag scrolled Flutter's list" | the same change |
| `:249` | the same, "scrolled" | the same change |
| `:262` | `atTop = { abs(row.frame.minY - top) < 2 }` | `frameInTree(row)` exists and is within 2 pt of `top`; a missing row is "not yet" |
| `:265` | message `\(row.frame)` | message `\(String(describing: frameInTree(row)))` |
| `:360` (iPad) | as `:175` | the same change |
| `drag`'s comment (`:102-104`) | "The hold at the end stops a fling" | names the exception: a stalled main thread hands Flutter the hold in one burst (VK-633) |

- **What the tests still check:**
  - "scrolled" still fails when the row stayed (it moved less than 200 pt);
  - "at the top" still needs the row back in the tree, within 2 pt of where it started.
- **Unchanged (Q5):** no slower drag. The hold, the velocity and the distances stay. `:209` stays too: there the row must not move at all, so a missing row is a real failure.

## 8. Testing

| Test (file) | Pins | Red before the change |
|---|---|---|
| `NativeTabsTests/testAReportLaterThanThreeSecondsStillCounts` (new, `RunnerTests.swift`) | a report 3.5 s after the action counts; the default is 10 s | `no searchActive true within 3 s` |
| `NativeTabsTests/testAnActivationBeforeTheSearchRootIsInAWindowIsAppliedOnceItAppears` (new) | **Q2's deterministic red.** The shell has Dart's config (search tab selected) but is in no window, so its root is provably in none; activation is refused. For 1 s with no window: not active, **no scope bar**, no keyboard, no report. The container then becomes a window's root and Dart's config is applied again, as `NativeShellInstaller.install` does. Expected: `searchActive true`, `isActive`, the keyboard, the scope bar, and exactly one `searchActive` report | `no searchActive true within 10 s`, the keyboard, and the scope bar while inactive if UIKit ran `willPresent` as in the probe |
| `NativeTabsTests/testAKeptActivationEndsWithADeactivateALeaveHiddenChromeOrAPresentation` (new) | the same refused activation, then one of: Dart's deactivate; another tab and back; hidden chrome and back; a presentation (`willPresent`, as UIKit calls it for a user's tap); a page pushed over the root (addition 3). Then the root appears, and nothing presents, nothing focuses, nothing is reported | each case presents and reports, once the activation is kept but never cancelled |
| `NativeTabsTests/testAnActivationOverAPushedPageIsDroppedAndOneRightAfterThePopIsApplied` (new, addition 3) | a shell in a window with a page pushed in the search tab. A deep link (pop to the root, then activate at once) is refused while the pop runs, kept, and presents and reports. An activation while the page covers the root is refused, leaves no scope bar, and the pop back brings no search, no keyboard and no report | with the activation kept under a page: the pop presents and reports |
| `NativeTabsTests/testAnActivationRefusedAfterLeavingTheSearchTabIsNotKept` (new, final review) | a shell in no window with the search tab not selected: `activate()` directly, as `didDismiss`'s deferred block does. Not kept (`activationPending` false). The shell then shows with the search tab selected: nothing presents, no keyboard, no scope bar, no report | `activationPending` true after the refusal, and the search presenting once the tab is selected |
| `testEnteringSearchTogglesNothingAndLeavesTheScopeBarAndKeyboardAlone` (kept) | the product's own sequence (select, then activate at once) is the **guard** (Q2); locally ×20 iterations | — (racy: about 1 in 7) |
| every other `RunnerTests` test | unchanged behaviour: activation, dismissal, `activateAfterDismiss`, VK-551, scopes, compositions | — |
| `MinimizeUITests` (6 iPhone, 2 iPad) | §7 | a temporary probe, never committed, flings the list and shows the old read failing with `No matches found` |

**Why the red test keeps the whole shell out of a window:**
- It is the same refusal as in the product: UIKit's "not in the window hierarchy" for the search root.
- The test holds that state as long as it likes, so the red is certain.
- The product's own sequence (the root installed one layout pass later) cannot give a certain red: today's recovery wins it about 6 times in 7. That sequence stays covered by the guard.

**Locally,** on simulators each task creates and deletes:
- Task 1: the new 1B test, iPhone 17 (iOS 26.5).
- Task 2:
  - the two new 1A tests, red then green, iPhone 17 (26.5);
  - the guard with `-test-iterations 20`;
  - `make ios-unit` on an iPhone 17 and an iPad (A16) (26.5);
  - the three 1A tests on an iPhone 17 with iOS 27.0 (CI has no iOS 27 runtime).
- Task 3: the probe, red then green; `make ios-minimize` on an iPhone 17 and an iPad (A16) (26.5).

**On CI:** the three runs of §9.

## 9. Measurement (Q6)

### 9.1 Runs

- Push the branch. Q6 is the go-ahead for this push and these runs only.
- Dispatch three runs at the head commit: `gh workflow run -R anvu69/liquid_shell ci.yaml --ref VK-626-ios-test-flakes`, three times. `main` has the `workflow_dispatch` trigger since `3508f1f`, and so does this branch.
- No PR in this step (addition 9).

### 9.2 Pass bar

- **The blocking jobs:**
  - `ios-unit (iPad)` and `ios-unit (iPhone)`;
  - `ios-minimize (iPhone)`;
  - `integration-ios`;
  - `integration-ios-native (…, iOS 26)`;
  - the non-iOS jobs that are not `continue-on-error`.
- **PASS:** across the three runs, no blocking job is red with a failure in category 1A, 1B or VK-633 (§9.3).
- A red job of another category is recorded with its evidence line and does not count against the bar. `ios-ui` is non-blocking: a 1A, 1B or VK-633 failure there is recorded, not counted.

### 9.3 Categories (from the failing test and its failure text in the job log's summary)

| Category | A failure in | Against the bar |
|---|---|---|
| 1A (VK-634) | `NativeTabsTests/testEnteringSearchTogglesNothingAndLeavesTheScopeBarAndKeyboardAlone`, `…/testAnActivationBeforeTheSearchRootIsInAWindowIsAppliedOnceItAppears`, `…/testAKeptActivationEndsWithADeactivateALeaveHiddenChromeOrAPresentation`, `…/testAnActivationOverAPushedPageIsDroppedAndOneRightAfterThePopIsApplied`, `…/testAnActivationRefusedAfterLeavingTheSearchTabIsNotKept` | yes (blocking job) |
| 1B (VK-626) | `…/testAReportLaterThanThreeSecondsStillCounts`, or any other `NativeTabsTests` failure whose text starts `failed - no searchActive` (a `settle(sending:)` wait) | yes |
| VK-633 | a `MinimizeUITests` failure whose text names a `Home item` row (`No matches found`), or reads `scrolled`, `the drag scrolled` or `at the top again` | yes |
| Segv | `crashed with signal` in an `ios-unit` job | no (Q4): its crash report is read (§9.4) |
| Other | anything else (a stall, VK-627, iOS 27, Android, another UI assertion) | no; recorded |

### 9.4 What is read

- **Every red iOS job:** the failing tests and failure texts that `tool/ios_xctest.sh` prints from the summary (`testIdentifierString`, `failureText`).
- **Every red `ios-unit` job:** its `ios-unit-<device>-diagnostics` artifact, with two reads:
  - the bundle's exported diagnostics: the `NativeTabsTests: … took <n> s` lines (slow reports that came), and the count of "not in the window hierarchy" refusals;
  - every `Runner-*.ips`: the exception, the faulting thread, and its top frames (§6).
- **Green runs:** no bundle is uploaded, so their slow waits are not seen (addition 6).
- **Every job:** logs through `gh api --allow-escape-sequences repos/anvu69/liquid_shell/actions/jobs/<id>/logs`. Without the flag gh writes 0 bytes, so every download is checked to be non-empty, and a failed one stops the count.

### 9.5 `docs/qa/vk626/measurement.md`

1. **Header:** branch, head sha, the three run ids and links, runner image versions, verdict.
2. **A Vietnamese summary for the owner.**
3. **Bar:** reds by category in blocking jobs (each must be 0), with job, run and line.
4. **Every iOS job:** run, job (id), conclusion, duration, failing tests, category.
5. **Other red jobs.**
6. **The segv:** any crash report and its faulting frames, or "none in these runs".
7. **Slow reports and refusals seen in red bundles.**
8. **Against VK-625's six runs:**
   - `ios-unit` was red in 3 of 12 jobs (VK-626), `ios-minimize` in 1 of 6 (VK-633);
   - a PASS is weak evidence on its own. Even with nothing fixed, those rates give about a 10 % chance of three clean runs: 0.75⁶ × (5/6)³ ≈ 0.10. For 1A and 1B the proof is the deterministic tests; the runs check that the known reds do not come back and that nothing new broke.

### 9.6 If the bar fails

Stop. Write `measurement.md` with the verdict and the evidence, commit it, push, and report (Q6). No further fix in this branch without a new decision.

## 10. CHANGELOG (Q7)

- **Where:** `liquid_shell_ios/CHANGELOG.md`, the package that owns `SearchBridge`.
  - The line goes last under `## 0.1.0-dev.8`. That version is not on pub.dev: `pub.dev/api/packages/liquid_shell_ios` answers 404.
  - No version bump, no other CHANGELOG.
- **The line,** in that file's style (a plain sentence, the ticket at the end):

  > - An activation Dart asks for right after selecting the search tab (a deep link, a programmatic focus) is no longer lost when UIKit refuses it because the search root is not in a window yet: it is kept until the root appears, and Dart's deactivate, leaving the tab or hidden chrome drop it. A refused presentation no longer leaves the scope bar drawn on an inactive search (VK-634).

## 11. Risks

| Risk | Handling |
|---|---|
| UIKit refuses with the root already in a window (never seen: every refusal in the evidence had the root in none) | The activation waits for the root's next appearance instead of a next-turn focus. The measurement counts the refusals in red bundles |
| iOS 27 reports a refusal differently (for example `isActive` true) | CI runs iOS 26.5 only. Task 2 runs the three 1A tests on a local iOS 27.0 simulator; a failure there stops the task |
| A page pushed over the search root: Dart's activation is refused there too | Not kept: the owner's choice (2026-10-16, the default of question A; addition 3). An activation refused while a page covers the root is dropped, as before, with no scope bar left; a push over the root drops a kept one. A pop to the root, then an activation (a deep link), is kept and applied |
| After an animated pop to the search root, the applied activation presents the search and reports it, but the field does not take the keyboard (found in Task 2: 5 of 5 probes, iOS 26.5, at the parent commit as with the fix) | Not changed here: it predates VK-634 and is outside Q2. The pushed-page test does not assert the keyboard there. No follow-up: the owner (2026-10-16) needs no deep link here, since the example app has none |
| The red test's state (a whole shell in no window) is not a product state (§3.5 item 6) | It pins the bridge's rule on the same refusal. The guard test keeps the product's own sequence |
| `willPresent` shows the scope bar, then the refusal hides it | Both happen in one run-loop turn, before any frame is drawn |
| A missing report now costs 10 s per wait | About 34 waits per iPad run; a red run stays well inside the 900 s cap |
| Three runs can pass by luck (about 10 %, §9.5) | Said in `measurement.md`; the deterministic tests carry 1A and 1B |
| Slow waits on green CI runs stay invisible | Addition 6, for the owner |

## 12. Process

- **Commits:** `<type>(<scope>): <summary> (VK-6xx)`:
  - `test(example)` for 1B (VK-626) and for VK-633 (VK-633);
  - `fix(ios)` for 1A (VK-634);
  - `docs(docs)` for the measurement (VK-626).
  
  Each message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Run `.githooks/pre-commit` by hand before each commit. Never `--no-verify`, never a git config change.
- **Simulators:** each task creates its own and deletes them. Never `simctl shutdown all`, and never a physical device (Q8).
- **Disk:** keep at least 10 GB free.
- **Versions:** no bump; one CHANGELOG line (Q7).
- **Publishing:** the push and the dispatched runs happen in the plan's last task only, under Q6. No PR, nothing published.

## Quyết định cần chủ sản phẩm xác nhận

Chủ sản phẩm đã chốt cả tám câu ngày 2026-10-16, nên mọi mục dưới đây đã được duyệt.

| Q# | Câu hỏi | Đã chốt |
|---|---|---|
| Q1 | Phạm vi? | Một spec, một nhánh, gồm 1A (VK-634, lỗi sản phẩm), 1B và segv (VK-626), và VK-633 |
| Q2 | Sửa 1A thế nào? | **Cách A của báo cáo:** khi `isActive = true` không ăn và không có lần đóng (dismissal) nào đang chạy, `SearchBridge` giữ lời kích hoạt và thực hiện nó khi trang gốc tab tìm kiếm đã vào cửa sổ. Thời điểm là `viewIsAppearing`/`viewDidAppear` của trang gốc, hoặc lúc chuyển tab xong; design chọn một và giải thích (§4.2: `viewDidAppear`). `setSearchActive(false)`, rời tab và chrome bị ẩn (luật VK-551) thì huỷ; khớp với `activateAfterDismiss`. Thanh phạm vi chỉ hiện khi tìm kiếm đang mở (theo `isActive`/`didPresent`, không chỉ theo `willPresent`), nên lần mở bị từ chối không để lại thanh phạm vi. **TDD:** trước hết một XCTest đỏ chắc chắn: kích hoạt khi trang gốc chắc chắn chưa ở trong cửa sổ, rồi cho nó hiện ra, và mong có `searchActive true`, có bàn phím, và không có thanh phạm vi khi chưa mở. Test `testEnteringSearchTogglesNothingAndLeavesTheScopeBarAndKeyboardAlone` giữ lại làm lớp bảo vệ |
| Q3 | 1B? | Nâng thời gian chờ báo cáo mặc định của helper XCTest từ 3 s lên 10 s, và in ra mọi lần chờ quá 3 s, để báo cáo chậm mà vẫn đến vẫn thấy được |
| Q4 | Segv? | Chưa sửa. Spec ghi lại bằng chứng và cách đọc crash report mà CI nay giữ lại (VK-600 thêm bước tải crash report khi job đỏ) |
| Q5 | VK-633? | Chỉ sửa test. Trong `MinimizeUITests`, hàng đã rời cây accessibility được tính là "đã cuộn"; kiểm tra hàng tồn tại trước khi xét danh sách đã về đầu chưa; sửa cùng mẫu đó ở `testFlutterGetsTheDrag…` (khoảng dòng 225). Không làm chậm cú kéo |
| Q6 | Đo thế nào? | Sau khi làm xong, chạy 3 lần `workflow_dispatch` trên đầu nhánh. **Đạt** khi không job chặn nào đỏ vì 1A, 1B hay VK-633. Không đạt thì dừng và báo cáo, không sửa mò. Đây là task cuối của plan, theo mẫu Task 5 của VK-625: lệnh dispatch có `-R anvu69/liquid_shell`, log lấy bằng `gh api --allow-escape-sequences`, kết quả ở `docs/qa/vk626/measurement.md` |
| Q7 | CHANGELOG? | Một dòng sửa lỗi cho 1A trong CHANGELOG của gói plugin chứa `SearchBridge` (`liquid_shell_ios`), theo lối viết sẵn có. Không đổi phiên bản, không phát hành |
| Q8 | Kiểm tra trên máy thật? | Không |

### Quyết định phát sinh khi viết spec

Bảng Q1–Q8 không nói tới những điểm dưới đây. Spec chọn như sau, chủ sản phẩm có thể đổi:

1. **Thực hiện ở `viewDidAppear` của trang gốc** (§4.2). Lý do:
   - nó chạy đúng lúc điều kiện thành đúng, dù do cài shell, chọn tab, nối lại scene hay quay về trang gốc;
   - nó chạy sau hiệu ứng xuất hiện;
   - lúc chuyển tab bằng code không chắc có `transitionCoordinator` để móc vào.
2. **Bị từ chối thì bỏ lần focus ở lượt run loop sau.** Chỉ còn một đường cứu, chắc chắn, và huỷ là huỷ hết (§4.1). Ở lần trước bị từ chối, nếu lần focus đó thắng thì ô tìm mở sớm hơn một chút.
3. **Trang con đè lên trang gốc tab tìm kiếm: không giữ lời kích hoạt.** Chủ sản phẩm chọn ngày 2026-10-16, theo mặc định của câu hỏi A. Bản nháp trước giữ lời kích hoạt đến khi người dùng quay về trang gốc; chủ sản phẩm không chọn cách đó. Luật như sau:
   - Dart kích hoạt lúc có trang con đè lên trang gốc (đỉnh ngăn xếp của tab tìm kiếm không phải trang gốc) thì UIKit cũng từ chối. Lời kích hoạt bị bỏ như trước: không giữ lại, và không để lại thanh phạm vi.
   - Push một trang lên trang gốc thì huỷ lời kích hoạt đang giữ.
   - Pop về trang gốc rồi kích hoạt ngay (đường của deep link) thì vẫn chạy: đỉnh ngăn xếp đã là trang gốc, nên lời kích hoạt bị từ chối lúc pop đang chạy vẫn được giữ và thực hiện khi trang gốc hiện ra.
4. **Thanh phạm vi:** `willPresent` vẫn hiện nó, như spike VK-550 đã đo. Ngay khi bị từ chối, `activate()` ẩn nó đi theo `isActive`, trong cùng lượt run loop. Như vậy thanh phạm vi chỉ hiện khi `isActive` đúng, không hiện chỉ vì `willPresent` (§4.4).
5. **Test đỏ dùng một shell chưa vào cửa sổ nào,** để đỏ chắc chắn; cuộc đua thật chỉ đỏ khoảng 1/7 lần. Thêm bốn test: một test đỏ cho lời kích hoạt trước khi có cửa sổ, một test cho năm cách huỷ (tắt, rời tab, ẩn chrome, một lần mở đã xảy ra, một lần push trang), một test cho trang con đè lên trang gốc (bỏ, và pop rồi kích hoạt thì chạy), và một test 1B (báo cáo đến sau 3,5 s).
6. **Dòng in "chờ quá 3 s" đã có sẵn từ VK-600.** Nó nằm trong stdout của test host, tức trong result bundle. Với `-quiet`, log của job không có nó, và CI chỉ tải bundle lên khi job đỏ. Muốn thấy cả ở lần chạy xanh thì phải đổi `tool/ios_xctest.sh` hoặc `ci.yaml`; việc đó ngoài phạm vi và chờ chủ sản phẩm quyết.
7. **VK-633:**
   - sửa cả hai test iPad có cùng mẫu (`:175`, `:360`), theo câu đầu của Q5 ("trong `MinimizeUITests`");
   - đọc frame bằng một snapshot duy nhất, nên "có tồn tại" và "ở đâu" đọc cùng một lần, không có khe hở giữa hai lần hỏi;
   - sửa luôn chú thích của `drag`.
8. **CHANGELOG** viết theo lối của `liquid_shell_ios` (câu thường, mã VK ở cuối), dưới mục `0.1.0-dev.8`. Mục này chưa phát hành trên pub.dev.
9. **Bước đo chỉ push nhánh và chạy ba lần dispatch,** không mở PR. PR mở theo `finishing-a-development-branch`, khi chủ sản phẩm đồng ý.
10. **Chạy thêm ba test 1A trên simulator iOS 27.0 ở máy local,** vì CI không có runtime 27.
