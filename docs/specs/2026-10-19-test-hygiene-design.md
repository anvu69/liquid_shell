# liquid_shell VK-651: test hygiene (one flaky wait, the VK-550 leftovers, an upstream draft for the status-bar tap)

- **Plane:** VK-651 (main item). Also VK-604 (the remaining VK-550 review minors) and VK-619 (the status-bar tap that `FlutterSemanticsScrollView` takes).
- **Date:** 2026-10-19
- **Status:** approved. The owner answered "ok hết" to the triage questions on 2026-10-19. Plan: `docs/plans/2026-10-19-test-hygiene.md`. The choices this spec had to add are listed in "Quyết định phát sinh", at the end.
- **Branch:** `VK-651-test-hygiene`, from `origin/main` at `cd6504c`.
- **Kind of change:** tests, test helpers, docs and `.pubignore`. No `lib/` change, no native production code, no public API, no behaviour.
  - `liquid_shell/example/ios/RunnerTests/RunnerTests.swift` (one wait, VK-651);
  - `liquid_shell/test/helpers/segment_gate.dart`, `liquid_shell/test/unit/segment_holdout_test.dart`, `liquid_shell/.pubignore`, a comment in `liquid_shell/test/impeller/liquid_shader_test.dart`, one cell of `docs/qa/vk550/acceptance.md`, one line in `docs/specs/2026-10-12-liquid-segmented-control-design.md` (VK-604);
  - `liquid_shell/example/ios/RunnerUITests/SearchUITests.swift` (two waits, VK-604 C9a);
  - `docs/qa/vk619/upstream-draft.md` (VK-619).
- **Sources:**
  - The small-items triage at `cd6504c` (`small-evidence.md`, read-only; all three sections). Its file:line pointers were checked again in the worktree while writing this spec.
  - The VK-550 final review (C1–C9) and the VK-600 Task 8 report and review (the status-bar finding).
  - flutter engine 83675ed276 (Flutter 3.44.6), read from the local SDK at `/Users/invoker/fvm/versions/3.44.6/engine/src/flutter/shell/platform/darwin/ios/framework/Source/`.
  - **Prototype** (2026-10-19, while writing this spec, on an iPhone 17 simulator, iOS 26.5, Xcode 27.1). Every plan snippet ran against the worktree and was reverted:
    - VK-651: the wait passes ×5; two mutations behave as §3.1 says;
    - C9b: the three new tests, the red for the split test, the mutations for the other two; the Dart suite stays green; `dart analyze` and `dart format` find nothing;
    - C8: `dart pub publish --dry-run` before and after;
    - C9a: both UI tests green with the waits, red under a mutation;
    - VK-619: a scratch `flutter create` app and an XCUITest reproduce the bug (§3.5). The scratch app and the simulator were deleted.

> **Tóm tắt (cho chủ sản phẩm).**
> - **VK-651:** test `testAPushedPagesBackButtonIsNative` đọc khung thanh điều hướng ngay sau khi cài shell. Trên runner chậm, nút Back chưa được bố trí xong nên thỉnh thoảng đỏ ("XCTAssertTrue failed"). Sửa: thêm đúng một lệnh `stable(...)` chờ thanh có mặt trên màn hình và đứng yên, như test bên cạnh đã làm với ô tìm kiếm. Không đổi gì khác. Trên máy này test xanh 5/5 cả trước lẫn sau khi sửa: lỗi chỉ có trên CI nên không thể "đỏ trước" ở local (mục 3.1).
> - **VK-604 (C7, C8, C9a, C9b, dòng C3):**
>   - C7: chỉ sửa chú thích và một ô trong `acceptance.md`: test "0 như trước" chỉ chứng minh uniform trung tính, còn "như trước" do các golden band của tab và pill giữ nguyên chứng minh.
>   - C8: thêm `test/helpers/segment_gate.dart` và hai test dùng nó vào `.pubignore` (chúng import `tool/` nằm ngoài gói). `dart pub publish --dry-run` xác nhận.
>   - C9a: hai chỗ `place.exists` trong `SearchUITests` đổi thành `waitForExistence`.
>   - C9b: test holdout nay kiểm tra mọi khoá `known` khớp một capture, `validation.length == 21`, và ném lỗi khi capture thiếu `split` thay vì mặc định `'holdout'`.
>   - C3: một dòng trong spec VK-550 ghi lại chỗ lệch so với native về bàn phím cứng. Không đổi code.
>   - C4, C5, C6 bỏ (bạn ghi lý do trên Plane).
> - **VK-619:** đã tái hiện lỗi trên simulator bằng app `flutter create` thuần + XCUITest: sau khi cuộn, chạm thanh trạng thái **một lần không đưa danh sách Flutter về đầu** (cần 3 lần chạm trên iPhone 17 / iOS 26.5; với `scrollsToTop = false` trên `FlutterSemanticsScrollView`, một lần là đủ). Bản nháp issue ở `docs/qa/vk619/upstream-draft.md`, dòng đầu "Draft for the owner. Not posted."; bạn tự đăng. Chưa kiểm: máy thật với VoiceOver / Speak Screen (bạn làm, không chặn PR), engine đã vá thật, và tìm issue trùng trước khi đăng.
> - **CHANGELOG:** không có (chỉ test, doc và `.pubignore`; C8 chỉ bỏ ba file test khỏi gói pub).

---

## 1. Goal

1. `testAPushedPagesBackButtonIsNative` no longer reads the navigation bar's frame before a slow runner has laid it out (VK-651).
2. The VK-550 review minors that are cheap and safe are closed: C7, C8, C9a, C9b, and the C3 departure is written down (VK-604).
3. The owner holds a reproduction and a ready draft of the upstream bug that makes the first status-bar tap miss Flutter's list (VK-619).

Success: each change shown red where it can be (a locker is shown red by a temporary mutation, §6), then green; `make verify`'s checks that cover the touched files stay green; the simulator runs of §6 pasted into the task reports.

## 2. Scope

### 2.1 In

- The one `stable(...)` wait (§3.1).
- C7, C8, C9a, C9b and the C3 line (§3.2, §3.3, §3.4).
- The reproduction and the upstream draft (§3.5).

### 2.2 Non-goals

- Anything else in `testAPushedPagesBackButtonIsNative`: no hardening that samples the hit result itself (the evidence's optional variant), no helper change, no timeout change.
- The rotation timeout seen in run 38920884892 ("Failed to change device orientation … timeout"): a note only (§3.1).
- C1, C2 and the rest of C9 (the non-empty asserts, the shrink-scopes widget test, the `tap_2_1_5seg` double capture): they belong to VK-572, which owns the search Dart files, `native_search_test.dart` and `doc/search.md`.
- C4, C5 and C6: dropped by the owner; the controller writes the reasons on Plane.
- Any code change for C3 (no `GCKeyboard` check).
- Any workaround for VK-619 in liquid_shell, and any patched Flutter engine.
- Posting anything upstream, or commenting on an upstream issue (the owner posts).
- A physical-device check, and a CHANGELOG entry or version bump.

## 3. Design

### 3.1 VK-651: the wait

**Evidence** (`cd6504c`).
- `liquid_shell/example/ios/RunnerTests/RunnerTests.swift:2849-2856`, `NativeTabsTests.testAPushedPagesBackButtonIsNative`: after `installedSearchShell(selected: 2, pages: [Search, Detail])` the test reads `bar.convert(bar.bounds, to: root)` at once (`:2854`) and hit-tests `frame.minX + 38, frame.midY` (`:2855`). Its only assertion is that `XCTAssertTrue`: the failure text is a bare "XCTAssertTrue failed".
- CI run 38920884892 (`gh run view --log-failed`): job ios-unit (iPhone), that test, "XCTAssertTrue failed". Run 38920884892 is not on main.
- The sibling test above it (`:2830-2833`) already waits: `_ = stable({ field.convert(field.bounds, to: root) }, until: { _ in field.window != nil })`. `stable` is at `RunnerTests.swift:636`: it polls the sample every 0.1 s until two reads agree and `ready` holds, times out after 5 s, and never fails by itself.
- Not reproducible locally: on an iPhone 17 simulator (iOS 26.5) the unchanged test passed 3 of 3 (0.54–0.57 s each) at `cd6504c`.

**Design** (Q: "add the `stable` wait, no other change"). Replace the two lines that read the frame (`:2854`) with the evidence's snippet:

```swift
// A slow runner is still laying the bar out after the install: wait until
// the bar is on screen and holds still, then hit its back button.
let frame = stable({ bar.convert(bar.bounds, to: root) }, until: { _ in bar.window != nil })
```

The hit test and its assertion stay as they are.

**The red check.** The approved check is a temporary mutation that makes the wait's condition never hold. `stable` returns its last sample when the 5 s run out, so that mutation does not turn the test red: it shows that the wait is on the test's path (the test takes 5.6 s instead of 0.65 s). A second temporary mutation, `stable({ CGRect.zero }, …)`, makes the hit point come from a frame that is not the bar's: the test goes red with the same "XCTAssertTrue failed" at `:2857`, which shows that the hit point comes from the wait's result. Both are reverted. The flake itself is only in the CI log, plus these two checks (Quyết định phát sinh 1).

**Runs.** The test ×5 on an iPhone simulator, green before the change (3 of 3) and after it (5 of 5, 0.65–0.66 s each). The plan uses the tool script and `xcodebuild -test-iterations` on the same selection `make ios-unit` uses (`-only-testing:RunnerTests`, narrowed to the test; the Makefile target has no selection argument).

**Rotation timeout (note only).** Run 38920884892 has one line "Failed to change device orientation … BSErrorCodeDescription=timeout" in its integration-ios-native (iPhone, iOS 26) job. Of the last 10 main runs, 4 failed (38765508425, 38655913550, 38597256231, 38232997153) and none of them has that line or this test. One known occurrence, on a branch run. Nothing is changed for it.

### 3.2 VK-604 C7: the "0 draws as before" comment

**Evidence.** `liquid_shell/test/impeller/liquid_shader_test.dart:250-251` (title: "a squeeze samples the page farther from the spine; 0 draws as before") and `:291-302`: the "0" half renders `params(0)` and a bare default `LiquidOpticsParams` through the same, already edited shader and compares the bytes. That shows the uniform is neutral at 0; it cannot show that the pixels equal what the shader drew before the uniform existed. The comment at `:247-249` ("0 draws exactly as before") and `docs/qa/vk550/acceptance.md:54` ("0, on every other surface, takes the old path byte for byte (Impeller test; the tab and pill goldens are unchanged)") say more than the test proves.

**Design** (Q: comment or doc fix only, no new test).
- In the test, the comment at `:291` says what the compare proves and where "as before" is proven: the band goldens of the surfaces that never set the uniform (`liquid_shell/example/test/goldens/bands/tab_lens_*.png`, `liquid_*.png`), which were not regenerated by the squeeze commit (acceptance.md §2b, `:54` and `:375`; only the three `segment_lens_*` bands changed). The test's title and assertions stay.
- In `acceptance.md:54` the parenthesis names the two halves: the Impeller test shows that 0 equals the bare lens; the unchanged `tab_*` and `liquid_*` band goldens show that it equals the old pixels.

### 3.3 VK-604 C8: the segment gate tests stay out of the pub archive

**Evidence.** `liquid_shell/test/helpers/segment_gate.dart:12-15` imports `../../../tool/segment_gate.dart` and re-exports `../../../tool/trace_math.dart`, both outside the package. `liquid_shell/.pubignore` lists only `doc/images/`, `test/goldens/failures/`, `example/test/fonts/` and `example/test/goldens/`. Two tests use the helper: `test/unit/segment_motion_test.dart` and `test/unit/segment_holdout_test.dart` (`grep -rln segment_gate liquid_shell/test`). Inside the archive they cannot compile.

**Design.** Three lines in `.pubignore`: the helper and the two tests. Check, with the dry-run (the only publish command allowed; it uploads nothing):
- before: `segment_gate.dart`, `segment_holdout_test.dart` and `segment_motion_test.dart` are in the listing, 523 KB;
- after: none of them, 515 KB, "Package has 0 warnings".

Archive effect: three test files fewer. No API, no behaviour, no version: no CHANGELOG line (Quyết định phát sinh 3).

### 3.4 VK-604 C9a, C9b and the C3 line

**C9a.** `liquid_shell/example/ios/RunnerUITests/SearchUITests.swift:474` (`testTheNativeScopeBar`) and `:526` (`testTheAppsResetScopeMovesTheNativeBarWithoutAReport`): `XCTAssertTrue(place.exists, "All: a place")` right after `song.waitForExistence`. A place row can arrive after the song row. Both become `XCTAssertTrue(place.waitForExistence(timeout: 10), "All: a place")`, the timeout the neighbouring waits use. Run on an iPhone simulator: both tests green. A temporary mutation (the place label misspelt) turns both red with "All: a place", after the wait.

**C9b.** `liquid_shell/test/unit/segment_holdout_test.dart` and `liquid_shell/test/helpers/segment_gate.dart` at `cd6504c`:
- `known` (`segment_holdout_test.dart:47`) is only looked up (`known[id] ?? const {}`, `:105`), so a key that matches no capture is silently dead. New test: every key of `known` is the id (`'${key} #${repeat}'`) of a holdout capture. It passes today (a locker); a temporary mutation of one key turns it red.
- The validation set is read from `native_holdout.json` (`:19`) and its size is never asserted. New test: `validation` has 21 captures. Also a locker; a temporary `.skip(1)` turns it red.
- `nativeTaps` (`segment_gate.dart:39-57`) reads `(c['split'] ?? 'holdout') as String` (`:48`). `native_taps.json` has `split` on every capture; `native_holdout.json` has none. A capture without a split must not land in the holdout by default. Design: split `nativeTaps` into `nativeTaps(file, {String? split})`, which reads the file, and `nativeTapsOf(json, {String? split})`, which parses it. The split of a capture is its own `split`, else the argument, else `FormatException('capture <key> has no split')`. The validation call passes `split: 'validation'` (the value is not read anywhere else). New test on `nativeTapsOf`: no split and no argument throws; the argument is used; the capture's own split wins. This one is red first: the `nativeTapsOf` extraction is a pure refactor (green), then the test fails with "Expected: throws … Actual: returned [… split: holdout …]", then the throw makes it pass.

Left alone: the `tap_2_1_5seg` double capture (each of passes 0, 1, 2 appears twice in `native_taps.json`, so each holdout id appears twice and `holdout` has 52 entries): C9's remaining sub-items go with VK-572 and nothing in the approved list asks for it.

**C3.** `docs/specs/2026-10-12-liquid-segmented-control-design.md` §10 (the native scope bar) never records that a scope tap puts the keyboard away. The user-facing statement is `liquid_shell/doc/search.md:112-117` ("A tap on a scope selects it and puts the keyboard away") and the code is Flutter's `scope_bar.dart:33` (`..dismissKeyboard()`) and native `SearchBridge.dismissKeyboard` (`SearchBridge.swift:218-223`, the field resigns first responder), reached through `NativeTabsController.swift:700-704`. Nothing checks for a hardware keyboard (`GCKeyboard`). Design: one bullet at the end of §10.1 recording this as a departure from the VK-571/VK-550 behaviour: a scope tap resigns the field also when a hardware keyboard is attached, so a hardware-keyboard user taps the field again to type; whether UIKit's own scope bar does the same was not checked on a device; accepted by the owner on 2026-10-19 (VK-604 C3); no code change. `doc/search.md` is VK-572's file and is not touched.

### 3.5 VK-619: reproduction and upstream draft

**Evidence.**
- Engine 83675ed276, Flutter 3.44.6 (`bin/internal/engine.version`), `engine/src/flutter/shell/platform/darwin/ios/framework/Source/`:
  - `SemanticsObject.mm:150-160`: `FlutterScrollableSemanticsObject initWithBridge:uid:` creates `FlutterSemanticsScrollView` (`:154`), sets indicators and insets, adds it to the bridge's view (`:159`). `grep scrollsToTop` finds nothing in `SemanticsObject.mm`, `FlutterSemanticsScrollView.mm` or `FlutterViewController.mm`: UIKit's default YES stays.
  - `FlutterSemanticsScrollView.mm:14-22`: the init; its delegate is itself (`:19`), and the file has no `scrollViewShouldScrollToTop:`, so UIKit's default allows the scroll.
  - `FlutterViewController.mm:524-543` (`loadView`): Flutter's own status-bar scroll view (offset (2, 2), `scrollsToTop` default YES), and `:557-565` `scrollViewShouldScrollToTop:` forwards to `[self.engine onStatusBarTap]` and returns NO.
  - `FlutterViewController.mm:2183-2191`: the accessibility bridge is always on in a simulator (`TARGET_OS_SIMULATOR`); on a device it is on under VoiceOver, Switch Control or Speak Screen.
- liquid_shell found it first in VK-600 Task 8: `min-task-8-report.md` finding 1 (lldb: mirror `scrollsToTop = 1`, the mirror scrolled 692 → 0, Flutter did not move). It reproduces with the native chrome off, so it is not liquid_shell.
- `MinimizeUITests.testAStatusBarTapScrollsToTheTopAndExpands` (`MinimizeUITests.swift:263-289`) already taps a second time when the first does not reach the top, for this reason.
- Not known: a duplicate upstream issue. The triage's `gh search issues` found none; the broader web search was not run. It stays to do before posting.

**The reproduction** (this spec's prototype; the plan repeats it). A plain app, outside the repo, in the session's scratch directory:
- `flutter create --platforms ios`; `lib/main.dart` is a `ListView.builder` of 100 `SizedBox(height: 56)` rows with `Text('Row $i')`. The app's iOS deployment target is raised to 15.0 (the 3.44.6 template's 13.0 is below Xcode 27's floor).
- A `RunnerUITests` UI-test bundle added to the project and to the `Runner` scheme's test action (the `xcodeproj` Ruby gem does it; the draft says how to do it in Xcode).
- Semantics are on under XCUITest and, in a simulator, always (`FlutterViewController.mm:2183`), so no `ensureSemantics` call is needed.
- Tests: scroll with eight fast swipes until `Row 0` is gone; tap the status bar by coordinate (`dx` 0.85 of the window width, `dy` 15: XCUITest finds no `StatusBar` element on iOS 26.5); assert `Row 0` is back within 5 s.
- **Measured** (iPhone 17, iOS 26.5, Xcode 27.1, Flutter 3.44.6; repeated 5 times with the same result):
  - one tap: red; `Row 0` does not come back (the first built row stays `Row 81`);
  - the number of taps until `Row 0` is back: 3 each time (the first built row after taps 1 and 2 is `Row 81`; the mirror, dumped every 0.2 s, animates to offset 0 on the taps that were dumped). The VK-600 lldb note counted 2; the draft states what was measured and that the count is unexplained;
  - the scroll views, dumped from the app: `FlutterSemanticsScrollView` (frame = the screen, `scrollsToTop = true`) and Flutter's status-bar `UIScrollView` (frame 402 × 0, offset (2, 2), `scrollsToTop = true`).
- **Control.** A run without semantics is not possible on a simulator (the bridge is always on). The control is the suggested fix applied from the app: a launch argument starts a 0.25 s timer that sets `scrollsToTop = false` on every `FlutterSemanticsScrollView` in the window. With it, one tap brings `Row 0` back (green). That shows the one-line change is enough on this layout. It is not a patched engine (§4, risks).

**The draft.** `docs/qa/vk619/upstream-draft.md`; the first line is `Draft for the owner. Not posted.` Shape of `docs/qa/vk627/upstream-draft.md` and `docs/qa/vk625/upstream-draft.md`: title, Summary, Environment, Steps to reproduce, Expected, Actual, Where it happens (engine file:line at 83675ed276), Suggested fix (`scrollsToTop = NO` in the scroll view's init in `FlutterScrollableSemanticsObject`). It carries the steps and the test code, not the scratch project. It marks what is unverified: the physical-device check under VoiceOver and Speak Screen (the owner does it; it does not block the PR), the fix on a patched engine, and the duplicate-issue search. Suggested title: `[iOS] FlutterSemanticsScrollView leaves scrollsToTop on, so a status-bar tap scrolls the accessibility mirror instead of the Flutter list`.

No workaround in liquid_shell (`scrollsToTop = false` stays only on the minimize and page proxies: `MinimizeProxy.swift:22`, `ShellNavController.swift:199`).

## 4. Risks

| Risk | Handling |
|---|---|
| The VK-651 wait does not remove the CI flake | It copies the wait the sibling test above it already has (`:2833`). If it recurs, the hardening of §2.2 (sample the hit result itself) is the next step; the failure text will still be bare, so that variant would also add a message |
| `stable` returns after 5 s whatever the bar did | Yes, by design ("a wait, not a retry"): a bar that never gets there still fails the hit assertion that follows |
| The `.pubignore` lines hide a test that should ship | They only list the three files that import `tool/`, which is outside the package; the dry-run lists the archive before and after |
| The control for VK-619 is an app-side emulation | The draft says so. It shows the one property (the mirror's `scrollsToTop` is the cause), not that the engine patch builds or has no other effect |
| The 3-tap count differs on a device or on another OS | The draft states the measured configuration and does not claim the count elsewhere; the owner's device check records it |
| `XCUITest` taps by coordinate, not on a status-bar element | The draft says why; the tap is the same one `MinimizeUITests` uses |
| Line numbers in the draft drift with Flutter | The draft names 3.44.6 and engine 83675ed276 and says to re-check on the current stable before posting |
| VK-572 edits `SearchUITests.swift` or `doc/search.md` at the same time | VK-572 owns the search Dart files, `native_search_test.dart` and `doc/search.md`; this branch edits only two lines of `SearchUITests.swift` and never `doc/search.md`. A textual conflict, if any, is a trivial rebase |

## 5. Test strategy

Which test is red first, why, and on which target:

| Item | Red first? | How | Target |
|---|---|---|---|
| VK-651 | A locker. Mutation B (`stable({ CGRect.zero }, …)`) turns it red; mutation A (`until` never holds) stays green and takes 5.6 s | Temporary, reverted | iPhone simulator, `RunnerTests/NativeTabsTests/testAPushedPagesBackButtonIsNative` ×5 |
| C9b split | Yes, for the right reason: after the green `nativeTapsOf` extraction, the test fails with "Expected: throws … Actual: returned [… split: holdout …]" | Real red | `flutter test` in `liquid_shell` |
| C9b known keys, size 21 | Lockers | Mutation: rename a key; `.skip(1)` | `flutter test` in `liquid_shell` |
| C8 | No test: the dry-run listing is the check | Before and after | `dart pub publish --dry-run` in `liquid_shell` |
| C7 | No red (comments); the Impeller file stays green | | `flutter test --enable-impeller --tags impeller` |
| C9a | A locker for a race that is not reproduced. Mutation: the place label misspelt | Temporary, reverted | iPhone simulator, `RunnerUITests/SearchUITests` (2 tests) |
| C3 | Docs | | none |
| VK-619 | The repro is the test: one tap red, the control green | Real red against the engine | iPhone simulator, scratch project |

`make verify` is the end-of-branch gate; its Dart half (`format-check`, `analyze`, `provenance`, `test`) runs in the pre-commit hook. The Swift edits (VK-651, C9a) are compiled by the simulator runs; the Dart analyzer does not see them.

## 6. CHANGELOG

None. Everything is test code, docs and `.pubignore`. C8 changes the published archive, by removing three test files (523 KB → 515 KB in the dry-run); no consumer-visible behaviour or API changes, so no line under `## 0.1.0-dev.8` (Quyết định phát sinh 3).

## 7. Process

- **Commits:** `<type>(<scope>): <summary> (VK-NNN)`. The two doc commits are `docs(docs): VK-651 test hygiene spec` and `docs(docs): VK-651 test hygiene plan`, with VK-604 and VK-619 in the bodies. Each implementation commit names its own item. Each message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- `bash .githooks/pre-commit` by hand before every commit. Never `--no-verify`, never a git config change.
- **Publishing:** none in the tasks. The controller pushes and opens the PR; the owner merges when CI is green. `dart pub publish --dry-run` is the only publish command, in Task 2.
- **Simulators:** each task that needs one creates its own and deletes it at the end; never a physical device, never `simctl shutdown all`.

## Quyết định cần chủ sản phẩm xác nhận

Chủ sản phẩm đã trả lời "ok hết" ngày 2026-10-19. Các quyết định đã chốt:

| Mục | Đã chốt |
|---|---|
| VK-651 | Thêm đúng một `stable(...)` trên khung thanh điều hướng, không đổi gì khác; kiểm "đỏ" bằng đột biến tạm; chạy ×5 trên simulator iPhone; lỗi xoay màn hình chỉ ghi chú |
| VK-604 | C7: chỉ sửa chú thích/doc. C8: thêm vào `.pubignore`, kiểm bằng `dart pub publish --dry-run`. C9a: thêm `waitForExistence`. C9b: ba assert. C3: một dòng trong spec VK-550, không đổi code. C4, C5, C6 bỏ |
| VK-619 | Tái hiện trên simulator bằng app `flutter create` + XCUITest; bản nháp `docs/qa/vk619/upstream-draft.md`; không workaround; bạn tự đăng |
| CHANGELOG | Không có |

### Quyết định phát sinh

Bảng trên không nói tới những điểm dưới đây. Spec chọn như sau, chủ sản phẩm có thể đổi:

1. **Kiểm "đỏ" của VK-651 dùng hai đột biến, không phải một.** Đột biến "điều kiện chờ không bao giờ đúng" không làm test đỏ: `stable` hết 5 s thì trả mẫu cuối, và thanh đã bố trí xong trên máy này, nên test vẫn xanh (nhưng chậm 5,6 s thay vì 0,65 s: chứng tỏ lệnh chờ nằm trên đường chạy). Để có một lần đỏ thật, đột biến thứ hai cho `stable` trả `CGRect.zero`: điểm chạm lệch khỏi nút Back và test đỏ, chứng tỏ điểm chạm lấy từ kết quả của lệnh chờ. Lỗi gốc chỉ có trên CI nên không tái hiện được ở local (3/3 xanh trước khi sửa).
2. **C9b: tách `nativeTapsOf(json, {split})` khỏi `nativeTaps(file, {split})`.** Cần để test được nhánh "thiếu split" mà không ghi file tạm. `native_holdout.json` không có `split` ở đâu cả, nên lời gọi validation truyền `split: 'validation'` (giá trị này không được đọc ở chỗ nào khác). Cách khác (đặt `split` vào file JSON) sẽ sửa dữ liệu bằng chứng của VK-550, nên không chọn.
3. **Không ghi CHANGELOG cho C8.** `.pubignore` bỏ ba file test khỏi gói (523 KB → 515 KB), không đổi API hay hành vi.
4. **C7: sửa cả chú thích trong test lẫn một ô trong `acceptance.md`** (chủ sản phẩm cho phép "chú thích hoặc doc"); tiêu đề test giữ nguyên để tên test không đổi trong log CI. Chú thích trỏ tới golden band của tab và pill (`tab_lens_*`, `liquid_*`, không bị tái tạo), vì `segment_lens_*` chính là phần đã đổi.
5. **C3: dòng ghi vào cuối §10.1 của spec VK-550** (spec đó chưa nói gì về bàn phím khi chạm scope). Không đụng `doc/search.md` vì đó là file của VK-572.
6. **VK-619: không thể chạy đối chứng "không có semantics" trên simulator** (bridge luôn bật ở simulator, `FlutterViewController.mm:2183`). Đối chứng là chính cách sửa đề xuất áp từ phía app (`scrollsToTop = false` trên mọi `FlutterSemanticsScrollView`): một lần chạm là đủ. Bản nháp nói rõ đó không phải engine đã vá.
7. **VK-619: số lần chạm đo được là 3, không phải 2** (ghi chú lldb của VK-600 nói 2). Bản nháp ghi số đã đo và cấu hình, và ghi rằng chưa giải thích được; bước kiểm trên máy thật ghi lại số lần chạm.
8. **VK-619: chạm thanh trạng thái bằng toạ độ**, vì XCUITest không tìm thấy phần tử `StatusBar` trên iOS 26.5; cùng cách `MinimizeUITests` đang dùng.
9. **Nhiệm vụ C9a tách riêng** (cần simulator) và đứng sau nhiệm vụ Dart của VK-604, như kế hoạch dự kiến.
