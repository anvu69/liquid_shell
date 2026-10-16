# VK-625: six CI runs on the cold-launch fix

- **Branch / head:** `VK-625-ci-cold-launch` @ `41441152e5e8c7e2a7502a4f48f754a47377d7e7`; PR https://github.com/anvu69/liquid_shell/pull/16 (draft)
- **Runs:** six `workflow_dispatch` runs at that head, all attempt 1 (the dispatch was accepted, so the rerun path of spec §11.1 was not needed):
  [38819133568](https://github.com/anvu69/liquid_shell/actions/runs/38819133568) (success),
  [38819151747](https://github.com/anvu69/liquid_shell/actions/runs/38819151747) (failure),
  [38819162000](https://github.com/anvu69/liquid_shell/actions/runs/38819162000) (success),
  [38819171451](https://github.com/anvu69/liquid_shell/actions/runs/38819171451) (failure),
  [38819180108](https://github.com/anvu69/liquid_shell/actions/runs/38819180108) (success),
  [38819190079](https://github.com/anvu69/liquid_shell/actions/runs/38819190079) (success).
  The PR's own run, [38819090289](https://github.com/anvu69/liquid_shell/actions/runs/38819090289) (success, same head), is reported but not counted (§11.1).
- **Runner images seen:** `macos-26-arm64` 20260907.0351.1 (31 iOS jobs) and 20261013.0424.1 (39 iOS jobs), macOS 26.6.2 (25G83). Flutter 3.44.9 (stable). Simulators iPhone 17 and iPad (A16), iOS 26.5 (23F77).
- **Verdict:** **PASS** (spec §11.2). No blocking job went red because of a stall, and at most one `ios-ui` red is stall-like.

> **Tóm tắt (cho chủ sản phẩm).**
> - **Đạt** theo §11.2. Không job chặn nào đỏ vì treo. `ios-ui` đỏ kiểu treo: 0 theo đúng danh sách của §11.2, 1 nếu tính chặt (lỗi khởi chạy ở lần mở app #1–#2), vẫn ≤ 1.
> - **Treo ở drive đầu:** 1/18 (5,6 %), trước đây 24 %. Lần thử lại trên cùng simulator đã chạy xanh (0/1 treo lại). Drive sau: 0/36 (trước đây 4 %). Warm-up: 48/48 ok, p50 5 s, lâu nhất 53 s, không lần nào quá giờ.
> - **Mẫu nhỏ:** 1/18 có khoảng tin cậy 95 % là 0,1–27 %; so với 30/127, p một phía = 0,065. Hướng đi đúng, nhưng sáu lần chạy chưa đủ để khẳng định chắc chắn.
> - **Q7 có:** dump của lần treo duy nhất cho thấy app đã in dòng "Dart VM service is listening" 2,2 s sau khi mở, còn bộ đọc log của flutter_tools thì bỏ lỡ dòng đó. Đã soạn `docs/qa/vk625/upstream-draft.md`, chưa đăng.
> - **Cần biết:** hai trong sáu lần chạy vẫn đỏ, nhưng không phải vì treo. Lần 38819151747 đỏ vì job chặn mới `ios-minimize` (một test của `MinimizeUITests` lỗi kiểu mới) cùng `ios-unit` (VK-626). Lần 38819171451 đỏ vì `ios-unit` (VK-626).

## Bar (spec §11.2)

| Criterion | Result |
|---|---|
| Blocking jobs red because of a stall | **0** (must be 0). There were four blocking reds, none of them a stall: no guard fired twice, no `✗ stalled` and no job hit its `timeout-minutes`. `ios-minimize (iPhone)` in 38819151747 is a new kind of test failure ("No matches found" for a row that had existed, launch #3, 12 m 43 s against the `timeout-minutes: 45` cap in `.github/workflows/ci.yaml`). The three `ios-unit` reds (38819151747 iPad, 38819171451 iPad and iPhone) are VK-626: "no searchActive true within 3 s / 10 s". Every non-iOS blocking job was green in all six runs. |
| Stall-like `ios-ui` reds (12 jobs) | **0 by the §11.2 list, 1 counted conservatively** (must be ≤ 1). No red has "Timed out while evaluating UI query", "Failed to send signal 19", an exceeded allowance or `✗ stalled`. `ios-ui (iPhone)` in 38819190079 failed at the job's first two launches with "Failed to get launch progress for <XCUIApplicationImpl … vn.lasoai.liquidShellExample …>: Timed out while requesting launch progress." and "Failed to get background assertion for target app with pid 23973". That is not on the list, but it is a launch failure at launches #1–#2, close to the "signal 19" family, so it is counted. The other two `ios-ui (iPhone)` reds are assertions. |

## Rates against the baseline (spec §11.3)

| Measure | VK-625 | Baseline |
|---|---|---|
| Warm-up timeouts | 0 / 48 (0 skipped; 8 warm-ups per run) | — |
| Warm-up time to the VM service line | p50 5 s, max 53 s (n = 48) | first app line p50 49 s, max 85 s |
| First-drive stalls | 1 / 18 = 5.6 % (95 % CI 0.1–27.3 %) | 30 / 127 = 24 % |
| Retry stalls (same simulator now) | 0 / 1 | 13 / 38 = 34 % (rebooted) |
| Later-drive stalls | 0 / 36 = 0 % (95 % CI 0–9.7 %) | 8 / 197 = 4 % |
| Stall-like `ios-ui` reds | 0 by the list, 1 conservatively / 12 | 15 / 82: 11 (A), 2 "signal 19", 2 suite cap (evidence report, last 40 runs) |
| XCTest suite caps (`✗ stalled`) in `ios-unit` / `ios-ui` / `ios-minimize` | 0 / 30 (ios-unit, ios-ui and ios-minimize jobs) | 2 / 82 `ios-ui` jobs only; the denominators count different things |

- **How the counts were made:**
  - The first drives are the 6 `integration-ios` jobs and the 12 `integration-ios-native (…, iOS 26)` jobs, all of which reached a warm-up line.
  - The later drives are 3 per native iOS 26 job: dialogs, search and compare.
  - The iOS 27 legs had no runtime on the image, so they printed "leg skipped" and are in no denominator.
  - The one retry is the one attempt-1 firing. No attempt-2 firing occurred.
- **The warm-up times are not like for like.** The baseline counts from "Xcode build done", so the install is in it. The warm-up counts from `simctl launch`.
- **The stall the retry absorbed:** 38819180108, `integration-ios-native (iPhone, iOS 26)`. Its `native_shell_test.dart` drive stalled once, and the same-simulator retry connected 14 s after its build. The job stayed green and took 39 m 51 s, against 21–24 min for the same job in the other runs.
- **Sample size:** a one-sided Fisher test of 1/18 against 30/127 gives p = 0.065. The result is consistent with an improvement, but six runs cannot prove the drop on their own: the 95 % interval for 1/18 (0.1–27.3 %) includes the 24 % baseline.
- **With the PR run** (not counted): first drives 1 / 21, later drives 0 / 42, warm-ups 56 / 56 ok (48 / 48 in the six counted runs) (p50 5 s, max 53 s), and no other guard firing.

## Every iOS job

Warm-up is the `ios_sim: warm-up …` outcome and its `<n>`. Guard firings counts `stall guard fired` lines. Every red row's evidence line is quoted from its job log (the xcresult summary that `tool/ios_xctest.sh` prints).

| Run | Job (id) | Conclusion | Duration | Warm-up | Guard firings | Category of a red |
|---|---|---|---|---|---|---|
| 38819133568 | integration-ios (116711120691) | success | 8 m 10 s | ok 9s | 0 | |
| 38819133568 | integration-ios-native (iPad, iOS 26) (116711120781) | success | 20 m 58 s | ok 15s | 0 | |
| 38819133568 | integration-ios-native (iPad, iOS 27) (116711120727) | success | 1 m 8 s | – (no iOS 27 runtime; leg skipped) | 0 | |
| 38819133568 | integration-ios-native (iPhone, iOS 26) (116711120962) | success | 21 m 39 s | ok 5s | 0 | |
| 38819133568 | integration-ios-native (iPhone, iOS 27) (116711120941) | success | 1 m 43 s | – (no iOS 27 runtime; leg skipped) | 0 | |
| 38819133568 | ios-minimize (iPhone) (116711120652) | success | 11 m 39 s | ok 5s | 0 | |
| 38819133568 | ios-ui (iPad) (116711120573) | success | 15 m 7 s | ok 5s | 0 | |
| 38819133568 | ios-ui (iPhone) (116711120788) | success | 20 m 38 s | ok 3s | 0 | |
| 38819133568 | ios-unit (iPad) (116711120658) | success | 8 m 41 s | ok 8s | 0 | |
| 38819133568 | ios-unit (iPhone) (116711120591) | success | 11 m 39 s | ok 3s | 0 | |
| 38819151747 | integration-ios (116711183260) | success | 8 m 16 s | ok 4s | 0 | |
| 38819151747 | integration-ios-native (iPad, iOS 26) (116711183579) | success | 11 m 2 s | ok 4s | 0 | |
| 38819151747 | integration-ios-native (iPad, iOS 27) (116711183641) | success | 1 m 18 s | – (no iOS 27 runtime; leg skipped) | 0 | |
| 38819151747 | integration-ios-native (iPhone, iOS 26) (116711183552) | success | 23 m 24 s | ok 7s | 0 | |
| 38819151747 | integration-ios-native (iPhone, iOS 27) (116711183253) | success | 0 m 56 s | – (no iOS 27 runtime; leg skipped) | 0 | |
| 38819151747 | ios-minimize (iPhone) (116711183429) | failure | 12 m 43 s | ok 6s | 0 | **new, not a stall**: `MinimizeUITests.testAStatusBarTapScrollsToTheTopAndExpands`, "No matches found … `label BEGINSWITH "Home item 6"`" (launch #3; the app was up) |
| 38819151747 | ios-ui (iPad) (116711183217) | success | 16 m 39 s | ok 3s | 0 | |
| 38819151747 | ios-ui (iPhone) (116711183161) | failure | 21 m 13 s | ok 50s | 0 | assertion, not stall-like: `testATapOnTheCircleExpands` "minimized" (launch #4); `testFlutterAnEdgeSwipeOffTheSearchRoot…` "a field" |
| 38819151747 | ios-unit (iPad) (116711183435) | failure | 18 m 32 s | ok 9s | 0 | VK-626: `NativeTabsTests` "no searchActive true within 3 s" |
| 38819151747 | ios-unit (iPhone) (116711183431) | success | 10 m 1 s | ok 4s | 0 | |
| 38819162000 | integration-ios (116711217105) | success | 10 m 37 s | ok 7s | 0 | |
| 38819162000 | integration-ios-native (iPad, iOS 26) (116711217266) | success | 18 m 16 s | ok 5s | 0 | |
| 38819162000 | integration-ios-native (iPad, iOS 27) (116711217376) | success | 1 m 29 s | – (no iOS 27 runtime; leg skipped) | 0 | |
| 38819162000 | integration-ios-native (iPhone, iOS 26) (116711217126) | success | 23 m 55 s | ok 3s | 0 | |
| 38819162000 | integration-ios-native (iPhone, iOS 27) (116711216917) | success | 1 m 54 s | – (no iOS 27 runtime; leg skipped) | 0 | |
| 38819162000 | ios-minimize (iPhone) (116711216860) | success | 13 m 49 s | ok 6s | 0 | |
| 38819162000 | ios-ui (iPad) (116711217026) | success | 21 m 23 s | ok 12s | 0 | |
| 38819162000 | ios-ui (iPhone) (116711217255) | failure | 17 m 41 s | ok 2s | 0 | assertion, not stall-like: `testNativeAScopeTapDismisses…` "the native field" |
| 38819162000 | ios-unit (iPad) (116711216956) | success | 10 m 43 s | ok 5s | 0 | |
| 38819162000 | ios-unit (iPhone) (116711216998) | success | 11 m 6 s | ok 31s | 0 | |
| 38819171451 | integration-ios (116711247658) | success | 11 m 0 s | ok 3s | 0 | |
| 38819171451 | integration-ios-native (iPad, iOS 26) (116711247750) | success | 28 m 7 s | ok 13s | 0 | |
| 38819171451 | integration-ios-native (iPad, iOS 27) (116711247690) | success | 1 m 0 s | – (no iOS 27 runtime; leg skipped) | 0 | |
| 38819171451 | integration-ios-native (iPhone, iOS 26) (116711247757) | success | 21 m 47 s | ok 5s | 0 | |
| 38819171451 | integration-ios-native (iPhone, iOS 27) (116711247822) | success | 1 m 21 s | – (no iOS 27 runtime; leg skipped) | 0 | |
| 38819171451 | ios-minimize (iPhone) (116711247601) | success | 9 m 18 s | ok 2s | 0 | |
| 38819171451 | ios-ui (iPad) (116711247677) | success | 17 m 52 s | ok 4s | 0 | |
| 38819171451 | ios-ui (iPhone) (116711247675) | success | 22 m 53 s | ok 5s | 0 | |
| 38819171451 | ios-unit (iPad) (116711247577) | failure | 12 m 5 s | ok 8s | 0 | VK-626: `NativeTabsTests` "no searchActive true within 3 s" |
| 38819171451 | ios-unit (iPhone) (116711247681) | failure | 12 m 57 s | ok 12s | 0 | VK-626: `NativeTabsTests` "no searchActive true within 10 s" |
| 38819180108 | integration-ios (116711275905) | success | 9 m 6 s | ok 3s | 0 | |
| 38819180108 | integration-ios-native (iPad, iOS 26) (116711276109) | success | 27 m 56 s | ok 4s | 0 | |
| 38819180108 | integration-ios-native (iPad, iOS 27) (116711276318) | success | 0 m 56 s | – (no iOS 27 runtime; leg skipped) | 0 | |
| 38819180108 | integration-ios-native (iPhone, iOS 26) (116711276063) | success | 39 m 51 s | ok 2s | 1 | green; stall (B) on `native_shell_test.dart` attempt 1, absorbed by the same-simulator retry (+20 min) |
| 38819180108 | integration-ios-native (iPhone, iOS 27) (116711276061) | success | 0 m 38 s | – (no iOS 27 runtime; leg skipped) | 0 | |
| 38819180108 | ios-minimize (iPhone) (116711276229) | success | 9 m 37 s | ok 3s | 0 | |
| 38819180108 | ios-ui (iPad) (116711276175) | success | 15 m 28 s | ok 4s | 0 | |
| 38819180108 | ios-ui (iPhone) (116711276071) | success | 22 m 7 s | ok 9s | 0 | |
| 38819180108 | ios-unit (iPad) (116711276092) | success | 10 m 55 s | ok 4s | 0 | |
| 38819180108 | ios-unit (iPhone) (116711275998) | success | 12 m 44 s | ok 53s | 0 | |
| 38819190079 | integration-ios (116711308788) | success | 8 m 4 s | ok 29s | 0 | |
| 38819190079 | integration-ios-native (iPad, iOS 26) (116711309037) | success | 28 m 15 s | ok 6s | 0 | |
| 38819190079 | integration-ios-native (iPad, iOS 27) (116711309239) | success | 1 m 11 s | – (no iOS 27 runtime; leg skipped) | 0 | |
| 38819190079 | integration-ios-native (iPhone, iOS 26) (116711309339) | success | 23 m 48 s | ok 7s | 0 | |
| 38819190079 | integration-ios-native (iPhone, iOS 27) (116711309283) | success | 1 m 44 s | – (no iOS 27 runtime; leg skipped) | 0 | |
| 38819190079 | ios-minimize (iPhone) (116711309115) | success | 12 m 9 s | ok 4s | 0 | |
| 38819190079 | ios-ui (iPad) (116711309153) | success | 16 m 30 s | ok 5s | 0 | |
| 38819190079 | ios-ui (iPhone) (116711309113) | failure | 21 m 32 s | ok 2s | 0 | **launch failures at launches #1–#2** ("Timed out while requesting launch progress"; "Failed to get background assertion"), counted stall-like (conservative), plus assertion "Flutter popped the detail" |
| 38819190079 | ios-unit (iPad) (116711309335) | success | 8 m 38 s | ok 31s | 0 | |
| 38819190079 | ios-unit (iPhone) (116711309127) | success | 12 m 13 s | ok 20s | 0 | |

The PR's own run (reported, not counted):

| Run | Job (id) | Conclusion | Duration | Warm-up | Guard firings | Category of a red |
|---|---|---|---|---|---|---|
| 38819090289 (PR) | integration-ios (116710970298) | success | 10 m 50 s | ok 5s | 0 | |
| 38819090289 (PR) | integration-ios-native (iPad, iOS 26) (116710970340) | success | 19 m 52 s | ok 6s | 0 | |
| 38819090289 (PR) | integration-ios-native (iPad, iOS 27) (116710970402) | success | 1 m 4 s | – (no iOS 27 runtime; leg skipped) | 0 | |
| 38819090289 (PR) | integration-ios-native (iPhone, iOS 26) (116710970523) | success | 16 m 58 s | ok 5s | 0 | |
| 38819090289 (PR) | integration-ios-native (iPhone, iOS 27) (116710970435) | success | 1 m 20 s | – (no iOS 27 runtime; leg skipped) | 0 | |
| 38819090289 (PR) | ios-minimize (iPhone) (116710970074) | success | 12 m 7 s | ok 4s | 0 | |
| 38819090289 (PR) | ios-ui (iPad) (116710970496) | success | 16 m 31 s | ok 9s | 0 | |
| 38819090289 (PR) | ios-ui (iPhone) (116710970399) | success | 23 m 23 s | ok 37s | 0 | |
| 38819090289 (PR) | ios-unit (iPad) (116710970453) | success | 12 m 7 s | ok 43s | 0 | |
| 38819090289 (PR) | ios-unit (iPhone) (116710970384) | success | 10 m 11 s | ok 24s | 0 | |

### The red iOS jobs, with the decisive line

| Run | Job | Class | Decisive line (job log) |
|---|---|---|---|
| 38819151747 | `ios-minimize (iPhone)` (blocking) | **New, not a stall.** The launch worked: `launch()` found the Home tab, and the row's `waitForExistence` passed, or the message would be "Flutter's rows". The failure most likely came at a later `row.frame` read, after the drag or the status-bar tap, when the row was no longer in the accessibility tree. The log has no line number, so this is an inference. The same test passed in the other 6 `ios-minimize` and all 7 `ios-ui (iPhone)` runs (13 / 14). | `MinimizeUITests/testAStatusBarTapScrollsToTheTopAndExpands()`: "Failed to get matching snapshot: No matches found for first query match sequence: `Descendants matching type Any` -> `Elements matching predicate 'label BEGINSWITH "Home item 6"'`, given input App element pid: 12547" |
| 38819151747 | `ios-unit (iPad)` (blocking) | VK-626 (timing assert) | `NativeTabsTests/testActivationNeedsTheSearchTabAndADartDismissalKeepsTheText()`: "failed - no searchActive true within 3 s: ["state", "controls", "field", "field", "field"]" |
| 38819171451 | `ios-unit (iPad)` (blocking) | VK-626 (timing assert) | `NativeTabsTests/testAnActivationResetsADismissalThatNeverEnded()`: "failed - no searchActive true within 3 s: ["state", "controls", "field", "field"]" |
| 38819171451 | `ios-unit (iPhone)` (blocking) | VK-626 (timing assert) | `NativeTabsTests/testEnteringSearchTogglesNothingAndLeavesTheScopeBarAndKeyboardAlone()`: "failed - no searchActive true within 10 s: ["state", "controls", "field", "field", "field"]" |
| 38819151747 | `ios-ui (iPhone)` | Assertion, not stall-like (launch #4; test 43 s) | `MinimizeUITests/testATapOnTheCircleExpands()`: "XCTAssertTrue failed - minimized"; `SearchUITests/testFlutterAnEdgeSwipeOffTheSearchRootKeepsTheCaseAndTheKeyboardDismissable()`: "XCTAssertTrue failed - a field" |
| 38819162000 | `ios-ui (iPhone)` | Assertion, not stall-like | `SearchUITests/testNativeAScopeTapDismissesTheKeyboardAndKeepsTheSearch()`: "XCTAssertTrue failed - the native field" |
| 38819190079 | `ios-ui (iPhone)` | **Launch failure at launches #1–#2.** It is not (A)'s query timeout and not on the §11.2 list, but it is counted as stall-like (conservative). The first test took 70 s. The warm-up before it was ok after 2 s. | `MinimizeUITests/testADragThatMovesNoContentKeepsTheBarWhole()` (launch #1): "Failed to get launch progress for <XCUIApplicationImpl: 0x106ee6ac0 vn.lasoai.liquidShellExample at …/Runner.app>: Timed out while requesting launch progress."; `MinimizeUITests/testAScrollMinimizesAndAFlingToTheTopExpands()` (launch #2): "Failed to get background assertion for target app with pid 23973: No failure details provided"; `SearchUITests/testAnEdgeSwipePopsFlutterAndTheNativeBarFollows()`: "XCTAssertTrue failed - Flutter popped the detail" |

None of the XCTest jobs printed `the selection ran 0 tests`. No `ios-ui` or `ios-minimize` job hit its suite cap.

## Other red jobs

- **`goldens (stable)`, in all six runs and in the PR run.**
  - Every run reported "20 tests passed, 7 failed": pixel diffs on the `stable` channel, for example `Golden "bands/tab_glow_release_dark.png": Pixel test failed, 19.94%`.
  - The leg is `experimental: true` (`continue-on-error`), so it is informational. It is red on `main` too (38765508425).
  - It is out of scope and not a stall.
- **Every other non-iOS job was green in all seven runs:** `checks (3.44.x)`, `checks (stable)`, `pana`, `android-unit`, `integration-android` and `goldens (3.44.x)`. So there were no Android infrastructure failures. There was no VK-627 build error either: "requires minimum platform version 15.0 …" is in none of the 77 downloaded logs, which cover every iOS job and every red job.
- **The iOS 27 legs** of `integration-ios-native` (iPad and iPhone) printed "no … simulator on iOS 27 in this runner image; leg skipped" in all seven runs. They are green, the no-runtime case.

## Diagnostics

One dump in the six runs: the drive stall above. There were no warm-up dumps (no warm-up timeout) and no XCTest suite dumps (no suite stall). The other 47 `cold-launch-*` uploads had nothing to upload (`if-no-files-found: ignore`), and the run's artifact listing has no other `cold-launch-*` name.

| Artifact / dump | Label | Reading (spec §10.2) | Note (`sample.txt` top frames) |
|---|---|---|---|
| `cold-launch-native-iPhone-2-a1` (run 38819180108, job 116711276063) / `20261016T012834Z-native_shell_test.dart_on_88931AEA_62E6_447F_8697_DCE00A671384_stall_1` | `native_shell_test.dart on 88931AEA_62E6_447F_8697_DCE00A671384 stall 1` | **Printed; the reader missed it (Q7).** Both conditions hold. (1) `vm-service.log` is complete (no `✗ stalled` in it) and has `2026-10-16 01:14:02.833 Df Runner[19423:f0fc] (Flutter) flutter: The Dart VM service is listening on http://127.0.0.1:51215/LOA13XgD8YA=/`. The pid is `app pid: 19423` from `meta.txt`, and `launchctl.txt` has `19423	0	UIKitApplication:vn.lasoai.liquidShellExample[0875][rb-legacy]`. (2) The job log has `✗ stalled: still running after 1200s: flutter drive … native_shell_test.dart …` at 01:28:34, then `Error waiting for a debug connection: The log reader failed unexpectedly` at 01:28:51. | The main thread was idle in its run loop: `UIApplicationMain` → `GSEventRunModal` → `__CFRunLoopRun` → `__CFRunLoopServiceMachPort` → `mach_msg2_trap`, 3339 / 3339 samples. This is consistent with the app waiting for a debugger to resume its paused isolate rather than hanging; an idle run-loop sample alone does not prove it. Launch Time 01:14:00.601, so the VM service line came 2.2 s after the launch. `load:` 53.86 110.10 118.95 (3-core runner). The other line in the file, `Runner[8224:77d8]` at 01:08:30.847, is the warm-up's own launch ("warm-up ok after 2s" at 01:08:33). |

**Timeline of the stalled drive (UTC; the simulator's local time is UTC):**

| Time | Event |
|---|---|
| 01:08:28 | The warm-up launches the app on the booted simulator. |
| 01:08:30.8 | The app (pid 8224) prints the VM service line, and the warm-up's reader sees it ("warm-up ok after 2s"). |
| 01:12:59 | "Xcode build done. 206.8s": the drive's build. |
| 01:14:00.6 | The drive's app (pid 19423) launches, the second launch on that boot, about 61 s after the build: install and launch under load. |
| 01:14:02.8 | The app prints "The Dart VM service is listening on http://127.0.0.1:51215/…". `flutter drive` never shows it. |
| 01:28:34 | `✗ stalled` after 1200 s, then the dump (17 s). |
| 01:28:51 | "Error waiting for a debug connection: The log reader failed unexpectedly". |
| 01:28:52 | `stall guard fired: … (attempt 1 of 2); terminating the app and retrying on the same simulator`. |
| 01:30:02 | The retry: "VMServiceFlutterDriver: Connecting to Flutter application at http://127.0.0.1:51770/…", 14 s after its "Xcode build done", and the tests pass. |

## Q7

Drafted `docs/qa/vk625/upstream-draft.md` from the dump `cold-launch-native-iPhone-2-a1/20261016T012834Z-native_shell_test.dart_on_88931AEA_62E6_447F_8697_DCE00A671384_stall_1`. It is the only drive-stall dump, and it meets both conditions of §10.2's first row. The draft is for the owner and has not been posted.

## Notes for the owner

- **What the one stall was.** It was not a first launch after the boot: the warm-up had launched the app about 5.5 minutes earlier, and it reached its line in 2 s. The app was up and idle and had printed its line, and flutter_tools' reader missed it. So (B), at least here, is a flutter_tools log-reader race under heavy load, not an app hang. The warm-up may make it rarer; 1/18 does not show it. The same-simulator retry recovers from it, at the cost of the 1200 s drive cap.
- **The new blocking job `ios-minimize (iPhone)` went red once in six runs, for a reason that is not a stall** (above). On `main` that would have turned the run red. Whether `testAStatusBarTapScrollsToTheTopAndExpands` is flaky or caught something real is not known from the log, and the xcresult was not read: this measurement downloads only `cold-launch-*` artifacts and job logs. It is in the run's `ios-minimize-iPhone-diagnostics` artifact (7 days).
- **Two of the six runs were red overall,** both for non-stall reasons: VK-626 in `ios-unit` (3 jobs over 2 runs) and the `ios-minimize` failure above.
- **`ios-ui (iPhone)` was red in 3 of 6 runs; `ios-ui (iPad)` was green in all 6.** It is non-blocking (Q6) and outside the bar.
- **Six of the seven iOS reds ran on image 20261013.0424.1.** That image ran 39 of the 70 iOS jobs. The stall ran on 20260907.0351.1. The sample is too small to read anything into it.
