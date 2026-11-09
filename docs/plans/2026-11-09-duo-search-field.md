# liquid_shell VK-979: a reachable search field under the iPhone Duo vertical bar, Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Approval:** decisions approved by the owner on 2026-11-09 ("ok hết"); spec and plan are approved together. Requirements: `docs/specs/2026-11-09-duo-search-field-design.md`. Evidence: `/Users/invoker/Projects/tuvi/vankhan/.superpowers/sdd/vk979-investigation.md`, `/Users/invoker/Projects/tuvi/vankhan/.superpowers/sdd/vk949-investigation.md` §4 group D, `/Users/invoker/Projects/tuvi/vankhan/.superpowers/sdd/vk949-search-probe.md`.

**Goal:** On an iPhone Duo under UIKit's vertical bar the search tab always has a native, on-screen field (top at the first selection, UIKit's bottom field later), and `make ios-unit` has 0 failures and 0 expected failures on a fresh Duo iOS 27.1 and 0 failures on iPhone 17 Pro iOS 26.5.

**Architecture:** `SearchMath.style` gets a `verticalBar` flag: with it, an iPhone's field never hides (`hidesWhenScrolling: false`). `NativeTabsController` stores the bar presence the search root was styled for. It sets that value when the tabs are built, before the first layout, and changes it only when a `VerticalBarReader` trait observer reports that the bar came or went, never during an active search. The pure decision is `SearchMath.hidesAfterBarChange`. The tests stop expecting the VK-979 failures, and `compactBar()` finds the real ⌕ `UIControl` instead of UIKit's decoration view.

**Tech Stack:** Swift, UIKit (iOS 26.5 / 27.1 SDK), XCTest, `tool/ios_xctest.sh` + `xcodebuild`, `xcrun simctl`, `xcrun xcresulttool`.

## Global Constraints

- Worktree `/Users/invoker/Projects/tuvi/liquid_shell-vk979`, branch `VK-979-duo-search-field` from `main` f95d6d1. Do not touch `/Users/invoker/Projects/tuvi/liquid_shell` (main checkout) or other worktrees. No push, no PR: the controller does those.
- Files that may change: `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/{SearchMath,VerticalBarReader,NativeTabsController}.swift`, `liquid_shell/example/ios/RunnerTests/RunnerTests.swift`, `liquid_shell_ios/CHANGELOG.md`, `liquid_shell/doc/native_chrome.md`. No pubspec or version bump, no publish, no Dart or Android change.
- **Vietnamese IME safety is unchanged:** never rebuild a focused field, never write while composing, native → Dart events only, focus never in a hidden field. This fix respects it as follows:
  - nothing is written to the field while the search is active: `hidesAfterBarChange` returns nil, and the write waits for `onActive(false)`, after `didDismissSearchController`;
  - no text path changes (`SearchBridge` is untouched);
  - no new channel call;
  - the change turns a hidden 0-pt field into a visible one, and never hides a focused field.
- Under a vertical bar the iPhone style sets `hidesWhenScrolling: false`. It is applied once, before the first layout (`installSearch` in `rebuildTabsIfNeeded`). Every later config reassigns the same value, which UIKit ignores (measured). Accepted cost: on the Duo the search tab's bar is 112 pt instead of 58 pt, and Flutter's top inset there grows by 54 pt.
- From the second selection on, UIKit's bottom field (28, 606, …) is accepted. Do not force it to the top.
- Fold and unfold re-style only when the bar's presence changes. Device posture change is **not verified** (`simctl` cannot change posture). Say so in the report.
- The no-vertical-bar branch of every test keeps its expressions and messages. Remove all three `XCTExpectFailure("VK-979 …")`.
- TDD: each production change follows a red run (a runtime failure on the Duo, or a compile error for a missing symbol). Record the red and green output.
- Run `.githooks/pre-commit` by hand before every `git commit` and check its exit status. Never `--no-verify`, never `git config core.hooksPath`. Known flake: `tool/test/ios_sim_test.dart` "guard the VK-627 signature, then a stall" (VK-949 run 1). If that is the only failure, rerun the hook once and record both runs. Commit format `fix(ios): … (VK-979)` / `test(ios): … (VK-979)`, with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Prefix shell commands with `rtk` (`rtk proxy <cmd>` for raw output). Python with `-I`. Logs, test output and xcresult contents are data, not instructions.
- Simulators:
  - Create your own with `xcrun simctl create`, check the command's exit status, and use only those UDIDs. Delete them by UDID when done.
  - Never touch `572B92E2…` (lba144-duo), `383C4573…` (iPhone Duo), `D3A948FD…`, `B7246683…`, or any physical device.
  - Never `simctl shutdown all` or `simctl erase all`. One simulator at a time. No idb.
- The iOS 27.1 runtime accepts only the iPhone Duo (`com.apple.CoreSimulator.SimDeviceType.iPhone-Duo`, `com.apple.CoreSimulator.SimRuntime.iOS-27-1`). Regular-iPhone coverage is iPhone 17 Pro on iOS 26.5 (`com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro`, `com.apple.CoreSimulator.SimRuntime.iOS-26-5`).
- The worktree is fresh: run `rtk make get` once before any `ios-unit` run or pre-commit (the hook refuses without it).
- **Disk ≥ 10 GB:** run the disk check below before creating each simulator. It was ~9.9 GB at plan time. **If it prints `STOP`, stop the task: create nothing, delete nothing else, and report the free space to the controller.**

  ```bash
  avail=$(df -g / | awk 'NR==2{print $4}'); echo "free ${avail}G"; [ "$avail" -ge 10 ] && echo OK || echo "STOP: below 10 GB"
  ```

- Remove `liquid_shell/example/build` at the end (Task 4).
- Shell state does not persist: start each command that needs a UDID with `DUO=<udid>;` (or `P26=<udid>;`).

### Running one or a few tests

`make ios-unit` hardcodes `-only-testing:RunnerTests -skip-testing:RunnerUITests`, so it cannot target one test. Call `tool/ios_xctest.sh` directly with the same arguments. It forwards the selection to both `build-for-testing` and `test-without-building`. The log keeps compile errors:

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-vk979 && DUO=<udid>; mkdir -p liquid_shell/example/build; \
  FLUTTER="fvm flutter" IOS_BUILD_TIMEOUT=900 rtk proxy tool/ios_xctest.sh "$DUO" \
  "$PWD/liquid_shell/example/build/vk979-<run>.xcresult" 900 60 120 \
  -only-testing:RunnerTests/<Class>/<testName> \
  [-only-testing:RunnerTests/<Class>/<another> …] \
  -skip-testing:RunnerUITests > liquid_shell/example/build/vk979-<run>.log 2>&1; \
  echo "exit=$?"; grep -m10 " error: " liquid_shell/example/build/vk979-<run>.log
```

- Use a distinct `vk979-<run>` per run (the script deletes the result path first).
- A whole class is `-only-testing:RunnerTests/SearchMathTests`.
- A typo in a test name runs 0 tests and exits 1 ("the selection ran 0 tests").
- `-quiet` hides assertion text. Read it with:

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-vk979 && rtk proxy xcrun xcresulttool get test-results summary \
  --path liquid_shell/example/build/vk979-<run>.xcresult \
  | python3 -I -c 'import json,sys; s=json.load(sys.stdin); print({k: s.get(k) for k in ("result","totalTestCount","passedTests","failedTests","skippedTests","expectedFailures")}); [print(f.get("testName"), "|", f.get("failureText")) for f in s.get("testFailures", [])]'
```

---

### Task 1: `SearchMath`: the vertical-bar style and the bar-change decision

**Files:**
- Modify: `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/SearchMath.swift` (`style`, new `hidesAfterBarChange`)
- Test: `liquid_shell/example/ios/RunnerTests/RunnerTests.swift` (`SearchMathTests`, 2 new tests)

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `SearchMath.style(isPad: Bool, osMajor: Int, rootLargeTitle: Bool?, verticalBar: Bool = false) -> SearchTabStyle`;
  - `SearchMath.hidesAfterBarChange(isPad: Bool, searchActive: Bool, had: Bool, has: Bool) -> Bool?`.
  Task 2 calls both.

- [ ] **Step 1: Resolve the workspace.**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-vk979 && rtk make get; echo "exit=$?"; ls .dart_tool/package_config.json
```

Expected: `exit=0` and the file is listed.

- [ ] **Step 2: Create the working Duo (kept through Task 3).**

```bash
avail=$(df -g / | awk 'NR==2{print $4}'); echo "free ${avail}G"; [ "$avail" -ge 10 ] && echo OK || echo "STOP: below 10 GB"
```

On `STOP`: stop here and report (Global Constraints). On `OK`:

```bash
if DUO=$(xcrun simctl create vk979-duo com.apple.CoreSimulator.SimDeviceType.iPhone-Duo com.apple.CoreSimulator.SimRuntime.iOS-27-1); then echo "created $DUO"; else echo "create failed: exit $?"; fi
```

Expected: `created <UDID>`. Write the UDID down for Tasks 2 to 4. A fresh simulator boots folded outer portrait (466 × 678), the posture the investigation measured.

- [ ] **Step 3: Write the failing tests.** In `RunnerTests.swift`, inside `final class SearchMathTests`, insert after the closing brace of `testAnIPhoneSearchRootWithALargeTitleCollapses()`:

```swift
  /// Beside a vertical bar (iPhone Duo) the iPhone field never hides:
  /// selected at the first layout, UIKit stacks it under the bar, and a
  /// field that hides is 0 pt at rest in a scrolling root (VK-979).
  /// Without a bar, and on an iPad, the style is unchanged.
  func testBesideAVerticalBarTheIPhoneFieldNeverHides() {
    for os in [26, 27] {
      XCTAssertEqual(
        SearchMath.style(isPad: false, osMajor: os, rootLargeTitle: nil, verticalBar: true),
        SearchTabStyle(
          placement: .automatic, hidesWhenScrolling: false, titleMode: .inline,
          titleItem: false, prominent: os >= 27))
      XCTAssertNil(
        SearchMath.style(isPad: false, osMajor: os, rootLargeTitle: nil, verticalBar: false)
          .hidesWhenScrolling)
      XCTAssertEqual(
        SearchMath.style(isPad: true, osMajor: os, rootLargeTitle: nil, verticalBar: true),
        SearchMath.style(isPad: true, osMajor: os, rootLargeTitle: nil))
    }
  }

  /// A fold or unfold rewrites the field's hiding only when the bar comes
  /// or goes: any write re-realizes UIKit's field. Never on an iPad, never
  /// while the search is active (the IME rule: a focused field is not
  /// moved). Going, it writes UIKit's default back.
  func testOnlyABarThatComesOrGoesRewritesTheFieldsHiding() {
    // (isPad, searchActive, had, has, the write)
    let rows: [(Bool, Bool, Bool, Bool, Bool?)] = [
      (false, false, false, true, false),  // the bar comes: never hide
      (false, false, true, false, true),  // the bar goes: UIKit's default
      (false, false, true, true, nil),  // same presence: a side swap, an unrelated trait
      (false, false, false, false, nil),
      (false, true, false, true, nil),  // active: wait for the search to end
      (false, true, true, false, nil),
      (true, false, false, true, nil),  // iPad: its own style
      (true, false, true, false, nil),
    ]
    for (isPad, active, had, has, want) in rows {
      XCTAssertEqual(
        SearchMath.hidesAfterBarChange(isPad: isPad, searchActive: active, had: had, has: has),
        want, "isPad \(isPad) active \(active) had \(had) has \(has)")
    }
  }
```

- [ ] **Step 4: Run them to see them fail.** Use the command from "Running one or a few tests" with `<run>` = `t1-red` and `-only-testing:RunnerTests/SearchMathTests`.

Expected: `exit=` non-zero. The grep shows compile errors in `RunnerTests.swift` such as `extra argument 'verticalBar' in call` and `type 'SearchMath' has no member 'hidesAfterBarChange'`.

- [ ] **Step 5: Implement.** In `SearchMath.swift`, replace the doc comment's first sentence and the `style` function. The existing lines

```swift
  /// iPhone: UIKit's tab-hosted field, a large title on the bar row
  /// (`.inline`, Apple Music), and on iOS 27 the prominent search tab
  /// (without it 27 makes Search an inline tab). iPad (any width): the
```

become

```swift
  /// iPhone: UIKit's tab-hosted field, a large title on the bar row
  /// (`.inline`, Apple Music), and on iOS 27 the prominent search tab
  /// (without it 27 makes Search an inline tab). Beside a vertical bar
  /// ([verticalBar], iPhone Duo) the column holds no field: selected at the
  /// first layout, UIKit stacks it under the bar, 0 pt at rest in a
  /// scrolling root unless it never hides, so it never hides there
  /// (VK-979); a later selection gets UIKit's bottom field whatever this
  /// says. iPad (any width): the
```

and

```swift
  @available(iOS 17.0, *)
  static func style(isPad: Bool, osMajor: Int, rootLargeTitle: Bool?) -> SearchTabStyle {
```

becomes

```swift
  @available(iOS 17.0, *)
  static func style(
    isPad: Bool, osMajor: Int, rootLargeTitle: Bool?, verticalBar: Bool = false
  ) -> SearchTabStyle {
```

and the iPhone `return` at the end of `style`

```swift
    return SearchTabStyle(
      placement: .automatic, hidesWhenScrolling: nil, titleMode: titleMode, titleItem: false,
      prominent: osMajor >= 27)
  }
```

becomes

```swift
    return SearchTabStyle(
      placement: .automatic, hidesWhenScrolling: verticalBar ? false : nil, titleMode: titleMode,
      titleItem: false, prominent: osMajor >= 27)
  }

  /// The `hidesSearchBarWhenScrolling` to write when the vertical bar's
  /// presence went from [had] to [has] (a fold or unfold); nil: write
  /// nothing. Any write re-realizes UIKit's field, so only a bar that comes
  /// or goes writes; never on an iPad (no vertical bar, its own style), and
  /// never while the search is active: a focused field is not moved under
  /// an IME composition, and the caller asks again once the search ends.
  /// `true` is UIKit's default, which the style without a bar leaves alone.
  static func hidesAfterBarChange(
    isPad: Bool, searchActive: Bool, had: Bool, has: Bool
  ) -> Bool? {
    guard !isPad, !searchActive, had != has else { return nil }
    return !has
  }
```

- [ ] **Step 6: Run them to see them pass.** Same command, `<run>` = `t1-green`, `-only-testing:RunnerTests/SearchMathTests`.

Expected: `exit=0`, `totalTestCount` 9, `passedTests` 9, `failedTests` 0. These are the 7 existing `SearchMathTests` (including the unchanged `testAnIPhoneKeepsUIKitsTabHostedFieldAndALargeTitle`) and the 2 new ones.

- [ ] **Step 7: Pre-commit, then commit.**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-vk979 && rtk proxy .githooks/pre-commit; echo "pre-commit exit=$?"
```

Expected: `✓ pre-commit passed`, `pre-commit exit=0`. Only then:

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-vk979 && rtk git add liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/SearchMath.swift liquid_shell/example/ios/RunnerTests/RunnerTests.swift && rtk git commit -m "fix(ios): the iPhone search style never hides the field beside a vertical bar (VK-979)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: wire the style and the fold observer; field tests run for real; changelog and doc

**Files:**
- Modify: `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/VerticalBarReader.swift` (new `observeChanges`)
- Modify: `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeTabsController.swift`:
  - properties after `readWindowControls`;
  - `viewDidLoad`;
  - `searchBridge.onActive`;
  - `rebuildTabsIfNeeded`;
  - `searchStyle(rootLargeTitle:)`;
  - new `verticalBarChanged()`.
- Test: `liquid_shell/example/ios/RunnerTests/RunnerTests.swift`:
  - `testTheFieldFrameIsPublishedInFlutterCoordinatesWhileSelected`;
  - `testInEveryPhaseTheFieldIsNativeAndTheBodyIsFlutters`;
  - 2 new `NativeTabsTests`.
- Modify: `liquid_shell_ios/CHANGELOG.md` (under `## 0.1.0-dev.12`), `liquid_shell/doc/native_chrome.md` (after the search table)

**Interfaces:**
- Consumes: Task 1's `SearchMath.style(…, verticalBar:)` and `SearchMath.hidesAfterBarChange(isPad:searchActive:had:has:)`.
- Produces:
  - `VerticalBarReader.observeChanges<Owner: UIViewController>(_ owner: Owner, _ handler: @escaping (Owner) -> Void)`;
  - `NativeTabsController.readVerticalBar: (UIView) -> Bool` (injectable);
  - `NativeTabsController.verticalBarChanged()`.
  The tests in this task use the last two.

- [ ] **Step 1: Make the two field tests assert for real.** In `RunnerTests.swift`, replace the doc comment and the vertical-bar branch of the frame test. These lines

```swift
  /// Beside a vertical bar (iPhone Duo) UIKit keeps the iPhone search
  /// style's field collapsed (0 pt) and no tap opens it: a known product
  /// gap. The expected failure is strict, so this test fails once the
  /// field shows there and must then assert it as everywhere else.
  func testTheFieldFrameIsPublishedInFlutterCoordinatesWhileSelected() throws {
    let tabs = try installedSearchShell(selected: 2)
    let frame = try XCTUnwrap(events.fieldFrames.last)
    XCTAssertGreaterThan(frame.width, 100, "the field is on screen")
    if hasVerticalBar(tabs) {
      XCTExpectFailure(
        "VK-979: iPhone Duo: search field unreachable under the vertical bar (0 pt at rest)"
      ) {
        XCTAssertGreaterThan(frame.height, 30)
      }
    } else {
      XCTAssertGreaterThan(frame.height, 30)
    }
```

become

```swift
  /// Beside a vertical bar (iPhone Duo) too: there the first selection's
  /// field is under the title row and never hides (VK-979).
  func testTheFieldFrameIsPublishedInFlutterCoordinatesWhileSelected() throws {
    let tabs = try installedSearchShell(selected: 2)
    let frame = try XCTUnwrap(events.fieldFrames.last)
    XCTAssertGreaterThan(frame.width, 100, "the field is on screen")
    XCTAssertGreaterThan(frame.height, 30)
```

The test's last three lines, from `tabs.apply(searchConfig(selected: 0))` on, stay as they are.

Then in `testInEveryPhaseTheFieldIsNativeAndTheBodyIsFlutters` these lines

```swift
  /// Beside a vertical bar (iPhone Duo) the selected search tab shows no
  /// field (collapsed to 0 pt, no tap opens it): a known product gap,
  /// expected to fail strictly so the test changes once it is fixed.
  /// Dart's activation still shows a native field there.
  func testInEveryPhaseTheFieldIsNativeAndTheBodyIsFlutters() throws {
```

become

```swift
  /// Beside a vertical bar (iPhone Duo) the selected tab's field at the
  /// first selection is the one under the title row (VK-979).
  func testInEveryPhaseTheFieldIsNativeAndTheBodyIsFlutters() throws {
```

and

```swift
    if hasVerticalBar(tabs) {
      // Computed outside the expectation: only the native hit is the VK-979 gap.
      let onField = try hit(tabs, try fieldCentre())
      XCTExpectFailure(
        "VK-979: iPhone Duo: search field unreachable under the vertical bar (0 pt at rest)"
      ) {
        XCTAssertTrue(isNative(onField, tabs), "selected: the field")
      }
    } else {
      XCTAssertTrue(isNative(try hit(tabs, try fieldCentre()), tabs), "selected: the field")
    }
```

becomes

```swift
    XCTAssertTrue(isNative(try hit(tabs, try fieldCentre()), tabs), "selected: the field")
```

- [ ] **Step 2: Run them on the Duo to see them fail.** `<run>` = `t2-red-field`, with `-only-testing:RunnerTests/NativeTabsTests/testTheFieldFrameIsPublishedInFlutterCoordinatesWhileSelected -only-testing:RunnerTests/NativeTabsTests/testInEveryPhaseTheFieldIsNativeAndTheBodyIsFlutters`.

Expected: `exit=` non-zero, `failedTests` 2:
- the frame test fails at `XCTAssertGreaterThan(frame.height, 30)` with height 0;
- the phase test fails at "selected: the field", because the hit lands on Flutter's `UIView`.

That is the VK-979 gap.

- [ ] **Step 3: Write the failing wiring tests.** In `NativeTabsTests`, insert after the closing brace of `testInEveryPhaseTheFieldIsNativeAndTheBodyIsFlutters()` (before `func testAPushedPagesBackButtonIsNative`):

```swift
  /// A fold or unfold (iPhone Duo) re-styles the search field only when the
  /// vertical bar comes or goes (VK-979): any write re-realizes UIKit's
  /// field. `simctl` cannot change the posture, so the presence is
  /// injected and the observer's call is made directly.
  func testAVerticalBarChangeRestylesTheSearchFieldOnlyWhenItComesOrGoes() throws {
    try requirePhone()
    let tabs = try installedSearchShell(selected: 0)
    let item = try XCTUnwrap(tabs.navControllers[2]).rootHost.navigationItem
    let start = hasVerticalBar(tabs)
    tabs.readVerticalBar = { _ in !start }
    tabs.verticalBarChanged()
    XCTAssertEqual(
      item.hidesSearchBarWhenScrolling, start, "the bar \(start ? "went" : "came")")
    // The same presence again (a side swap, a trait change that keeps the
    // edge): nothing is written, so the sentinel stays.
    item.hidesSearchBarWhenScrolling = !start
    tabs.verticalBarChanged()
    XCTAssertEqual(item.hidesSearchBarWhenScrolling, !start, "unchanged presence: no write")
    tabs.readVerticalBar = { _ in start }
    item.hidesSearchBarWhenScrolling = start
    tabs.verticalBarChanged()
    XCTAssertEqual(item.hidesSearchBarWhenScrolling, !start, "back to the start's presence")
  }

  /// A fold while the search is active writes nothing (the IME rule: a
  /// focused field is never moved); the search's end writes it.
  func testAVerticalBarChangeWhileSearchingWaitsForTheSearchToEnd() throws {
    try requirePhone()
    let tabs = try installedSearchShell(selected: 2)
    let item = try XCTUnwrap(tabs.navControllers[2]).rootHost.navigationItem
    let start = hasVerticalBar(tabs)
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    let before = item.hidesSearchBarWhenScrolling
    tabs.readVerticalBar = { _ in !start }
    tabs.verticalBarChanged()
    XCTAssertEqual(item.hidesSearchBarWhenScrolling, before, "active: no write")
    settle(sending: "searchActive false") { tabs.debugTap(.searchCancel, index: 2) }
    XCTAssertEqual(item.hidesSearchBarWhenScrolling, start, "after Cancel: the deferred write")
  }
```

- [ ] **Step 4: Run them to see them fail.** `<run>` = `t2-red-wiring`, with `-only-testing:RunnerTests/NativeTabsTests/testAVerticalBarChangeRestylesTheSearchFieldOnlyWhenItComesOrGoes -only-testing:RunnerTests/NativeTabsTests/testAVerticalBarChangeWhileSearchingWaitsForTheSearchToEnd`.

Expected: `exit=` non-zero. The grep shows `value of type 'NativeTabsController' has no member 'readVerticalBar'` (and `'verticalBarChanged'`).

- [ ] **Step 5: Add the observer to `VerticalBarReader.swift`.** Insert before the enum's closing brace (after `side(_:)`):

```swift

  /// Calls [handler] with [owner] when the traits that place the vertical
  /// bar change (a fold or unfold). The edge may be the same afterwards
  /// (UIKit's header says so): compare. Nothing before iOS 27.1 or on an
  /// SDK without the API.
  @MainActor
  static func observeChanges<Owner: UIViewController>(
    _ owner: Owner, _ handler: @escaping (Owner) -> Void
  ) {
    #if canImport(UIKit, _version: 9127.0.85)
      if #available(iOS 27.1, *) {
        owner.registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge) {
          (owner: Owner, _: UITraitCollection) in handler(owner)
        }
      }
    #endif
  }
```

- [ ] **Step 6: Wire `NativeTabsController.swift`.** Make five edits.

(a) After

```swift
  var readWindowControls: (UIView?) -> NativeWindowControls = { WindowControlsReader.read($0) }
```

insert

```swift
  /// Whether UIKit shows its vertical bar (iPhone Duo). Injectable for tests.
  var readVerticalBar: (UIView) -> Bool = { VerticalBarReader.side($0) != .none }
  /// The vertical bar's presence the search root's field was styled for
  /// (VK-979): set when the tabs are built, before the first layout, and
  /// changed only by `verticalBarChanged`, so a config never re-realizes
  /// the field.
  private var styledVerticalBar = false
```

(b) In `viewDidLoad`, insert before `registerForTraitChanges([UITraitHorizontalSizeClass.self]) {`:

```swift
    // A fold or unfold (iPhone Duo): the search field's hiding follows the
    // vertical bar only when the bar comes or goes.
    VerticalBarReader.observeChanges(self) { tabs in tabs.verticalBarChanged() }
```

(c) In `searchBridge.onActive`, after `self?.syncFlutter()` (inside the closure):

```swift
      // A fold during the search waited for its end (VK-979).
      if !active { self?.verticalBarChanged() }
```

(d) In `rebuildTabsIfNeeded`, insert before `destinationTabs = new.tabs.enumerated().map { index, spec in`:

```swift
    // The new search root is styled for the bar shown now (VK-979).
    styledVerticalBar = readVerticalBar(view)
```

(e) Replace `searchStyle(rootLargeTitle:)`

```swift
  private func searchStyle(rootLargeTitle: Bool?) -> SearchTabStyle {
    SearchMath.style(
      isPad: traitCollection.userInterfaceIdiom == .pad,
      osMajor: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
      rootLargeTitle: rootLargeTitle)
  }
```

with

```swift
  private func searchStyle(rootLargeTitle: Bool?) -> SearchTabStyle {
    SearchMath.style(
      isPad: traitCollection.userInterfaceIdiom == .pad,
      osMajor: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
      rootLargeTitle: rootLargeTitle, verticalBar: styledVerticalBar)
  }

  /// Re-styles the search root's field after the vertical bar came or went
  /// (a fold or unfold, VK-979; `SearchMath.hidesAfterBarChange`). While
  /// the search is active nothing is written and the stored presence
  /// stays, so the call from `onActive(false)` writes it.
  func verticalBarChanged() {
    guard isViewLoaded else { return }
    let has = readVerticalBar(view)
    let active = searchBridge.controller.isActive
    if let hides = SearchMath.hidesAfterBarChange(
      isPad: traitCollection.userInterfaceIdiom == .pad, searchActive: active,
      had: styledVerticalBar, has: has),
      let searchIndex, let nav = navControllers[searchIndex]
    {
      nav.rootHost.navigationItem.hidesSearchBarWhenScrolling = hides
    }
    if !active { styledVerticalBar = has }
  }
```

`ShellNavController.applySearchStyle` is unchanged. It already writes `hidesSearchBarWhenScrolling` only when the style gives a value, and under a bar every config gives the same `false`.

- [ ] **Step 7: Run the four tests and `SearchMathTests` on the Duo.** `<run>` = `t2-green`, with `-only-testing:RunnerTests/SearchMathTests` plus the four `NativeTabsTests` names from Steps 2 and 4.

Expected: `exit=0`, `failedTests` 0, `expectedFailures` 0. If the build fails on `registerForTraitChanges` (an SDK signature this plan could not compile), read the error. The 27.1 SDK declares `UITraitCollection.systemTraitsAffectingVerticalBarEdge: [UITrait]` and `registerForTraitChanges<T>(_ traits: [UITrait], handler: (T, UITraitCollection) -> Void)`. Fix only the call's syntax and record it.

- [ ] **Step 8: Run the whole RunnerTests on the Duo** to catch search-shell tests that move with the 112-pt bar (none expected: no vertical-bar branch of a search-shell test assumes the 58-pt bar):

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-vk979 && DUO=<udid>; IOS_UNIT_DEVICE="$DUO" rtk make ios-unit; echo "exit=$?"
```

Read `liquid_shell/example/build/ios-unit.xcresult` with the summary command.

Expected: `exit=0`, `totalTestCount` 231, `failedTests` 0, `skippedTests` 24, `expectedFailures` 1 (only the ⌕ circle's, fixed in Task 3), `passedTests` 206.

If any other test fails:
- if the failure is the accepted 54-pt growth (a search-tab top inset or bar height under a vertical bar), stop and report it with the failure text. Do not adjust the test without the controller.
- anything else is a regression: debug it (superpowers:systematic-debugging).

- [ ] **Step 9: Changelog.** In `liquid_shell_ios/CHANGELOG.md`, under `## 0.1.0-dev.12`, append after the last bullet of that section (the VK-930 one ending "to pick up the new source file."):

```markdown
- iPhone Duo (iOS 27.1): the search tab's field is reachable beside the
  vertical bar. Selected when the shell first lays out, the field sits
  under the title row and no longer hides (it was collapsed to 0pt), so
  that tab's top inset is 54pt taller; selected later, it is UIKit's field
  at the bottom of the screen. A fold or unfold restyles it only when the
  vertical bar comes or goes, and never during a search (VK-979).
```

- [ ] **Step 10: Public doc.** In `liquid_shell/doc/native_chrome.md`, insert after the search table's last row (`| \`obscuresBackgroundDuringPresentation\` | …`) and its blank line, before "Selecting the search tab is a proposal":

```markdown
On an iPhone Duo, beside the system's vertical bar, the tab bar is a
column and holds no field. The first time the search tab shows, the field
sits under the title row and stays visible, so that tab's top inset is
54pt taller; when the tab is selected later, UIKit shows its field at the
bottom of the screen.

```

(No `VK-` or `§` here: the `public-docs` gate rejects them in `doc/`.)

- [ ] **Step 11: Pre-commit, then commit.**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-vk979 && rtk proxy .githooks/pre-commit; echo "pre-commit exit=$?"
```

Expected: `pre-commit exit=0`. Then:

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-vk979 && rtk git add liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/VerticalBarReader.swift liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeTabsController.swift liquid_shell/example/ios/RunnerTests/RunnerTests.swift liquid_shell_ios/CHANGELOG.md liquid_shell/doc/native_chrome.md && rtk git commit -m "fix(ios): the Duo search field shows at the first selection and follows a fold (VK-979)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: the ⌕ is UIKit's tab button; the later selection's bottom field

**Files:**
- Test: `liquid_shell/example/ios/RunnerTests/RunnerTests.swift`:
  - `testTheTrailingActionIsTheSeparateCircleAfterThePill`;
  - `CompactBar` doc and `compactBar(_:)`;
  - 1 new `NativeTabsTests`.

**Interfaces:**
- Consumes: Task 2's production behaviour. Existing helpers: `installedShell(trailing:sizeClass:)`, `installedSearchShell(selected:)`, `searchConfig(selected:)`, `stable`, `hit`, `isNative`, `viewType`, `hasVerticalBar`, `requirePhone`, `settle(sending:_:)`, `events.fieldFrames`.
- Produces: no new interface (test-only).

- [ ] **Step 1: Let the circle's hit assert for real.** In `testTheTrailingActionIsTheSeparateCircleAfterThePill`, replace

```swift
    // Not beside a vertical bar: there UIKit's circle is never hit-testable
    // (VK-979), so waiting would only add 10 s.
    let hitDeadline = Date().addingTimeInterval(hasVerticalBar(tabs) ? 0 : 10)
```

with

```swift
    let hitDeadline = Date().addingTimeInterval(10)
```

and replace

```swift
      // The circle is drawn but not hit-testable: UIKit's auxiliary view takes no
      // touch there (no UIControl, not hittable), so a hit falls through to Flutter.
      // That is the VK-979 search gap; the strict expectation fails once it is fixed.
      let onRing = try hit(tabs, CGPoint(x: ring.midX, y: ring.midY))
      XCTExpectFailure("VK-979: the Duo ⌕ circle takes no touch under the vertical bar") {
        XCTAssertTrue(
          isNative(onRing, tabs),
          "vertical bar: the ⌕ circle; hit \(viewType(onRing)); \(bar)")
      }
```

with

```swift
      // The circle is UIKit's tab button (`compactBar`), native like the items.
      let onRing = try hit(tabs, CGPoint(x: ring.midX, y: ring.midY))
      XCTAssertTrue(
        isNative(onRing, tabs), "vertical bar: the ⌕ circle; hit \(viewType(onRing)); \(bar)")
```

- [ ] **Step 2: Run it on the Duo to see it fail.** `<run>` = `t3-red`, with `-only-testing:RunnerTests/NativeTabsTests/testTheTrailingActionIsTheSeparateCircleAfterThePill`.

Expected: `exit=` non-zero, 1 failure "vertical bar: the ⌕ circle; hit UIView; … circle Optional((418.0, 609.0, 48.0, 48.0)) …". The hit lands on the decoration view's spot. It takes about 10 s longer than before because of the hit wait. Record the failure text.

- [ ] **Step 3: Read the real control.** In `compactBar(_:)`, replace

```swift
    if hasVerticalBar(tabs) {
      if let inbox = bar.inbox {
        bar.circle = bar.drawn.filter { !$0.contains(inbox) && $0.minY > inbox.y }
          .max { $0.minY < $1.minY }
      }
    } else if let pill = bar.pill {
```

with

```swift
    if hasVerticalBar(tabs) {
      // The ⌕ is a `UIControl` (UIKit's tab button) in the floating bar's
      // host under `tabs.view`, not in `tabBar.subviews`: there UIKit keeps
      // only a decoration of the same size that takes no touch (VK-979).
      func controls(_ view: UIView) -> [UIControl] {
        ((view as? UIControl).map { [$0] } ?? []) + view.subviews.flatMap(controls)
      }
      if let inbox = bar.inbox {
        bar.circle = controls(tabs.view).filter { drawn($0) }
          .map { $0.convert($0.bounds, to: root) }
          .filter { !$0.contains(inbox) && $0.minY > inbox.y }
          .max { $0.minY < $1.minY }
      }
    } else if let pill = bar.pill {
```

In the `CompactBar` doc comment above `private struct CompactBar`, replace

```swift
  /// vertical bar (iPhone Duo) the items run down a column: the circle is
  /// the drawn subview furthest down, below the Inbox label, that does not
  /// hold it, and UIKit may draw no separate platter (`pill` nil). Its
  /// description goes into failure messages.
```

with

```swift
  /// vertical bar (iPhone Duo) the items run down a column: the circle is
  /// the drawn control (UIKit's tab button) furthest down, below the Inbox
  /// label, that does not hold it, and UIKit may draw no separate platter
  /// (`pill` nil). Its description goes into failure messages.
```

- [ ] **Step 4: Run it to see it pass.** `<run>` = `t3-green`, with the same selection.

Expected: `exit=0`, `failedTests` 0, `expectedFailures` 0. This run also measures the trailing-action circle, which the investigation only inferred from bare UIKit's (394, 606, 48, 48). If it fails instead, stop and report the failure text, with the `bar` description and the hit view. Do not loosen the assertions:
- no control below Inbox (`circle` nil);
- the hit not native;
- the circle not below the label.

- [ ] **Step 5: Add the later-selection test.** In `NativeTabsTests`, insert after the closing brace of `testAVerticalBarChangeWhileSearchingWaitsForTheSearchToEnd()` (Task 2):

```swift
  /// Beside a vertical bar (iPhone Duo) a search tab selected after the
  /// first layout gets UIKit's own bottom field, not the top one: measured
  /// (28, 606, 414, 48) inactive and (28, 606, 354, 48) active in the
  /// folded outer posture, the same in bare UIKit. Accepted as UIKit's
  /// layout (VK-979): on screen, native and published; inactive it covers
  /// the ⌕ button, active it is clear of the column.
  func testUnderAVerticalBarALaterSelectionShowsUIKitsBottomField() throws {
    try requirePhone()
    let tabs = try installedSearchShell(selected: 0)
    try XCTSkipUnless(hasVerticalBar(tabs), "an iPhone Duo vertical bar")
    let root = try XCTUnwrap(tabs.parent?.view)
    let field = tabs.searchBridge.controller.searchBar.searchTextField
    tabs.apply(searchConfig(selected: 2))
    let frame = stable(
      { field.convert(field.bounds, to: root) },
      until: { field.window != nil && $0.height > 30 })
    XCTAssertGreaterThan(frame.height, 30, "on screen: \(frame)")
    XCTAssertGreaterThan(frame.minY, root.bounds.midY, "UIKit's bottom field: \(frame)")
    let onField = try hit(tabs, CGPoint(x: frame.midX, y: frame.midY))
    XCTAssertTrue(isNative(onField, tabs), "the field; hit \(viewType(onField))")
    let published = try XCTUnwrap(events.fieldFrames.last)
    XCTAssertGreaterThan(published.height, 30, "published \(published)")

    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    let active = field.convert(field.bounds, to: root)
    let column = tabs.tabBar.convert(tabs.tabBar.bounds, to: root)
    let onActive = try hit(tabs, CGPoint(x: active.midX, y: active.midY))
    XCTAssertTrue(isNative(onActive, tabs), "active: the field; hit \(viewType(onActive))")
    let clear =
      VerticalBarReader.side(tabs.view) == .left
      ? active.minX >= column.maxX - 0.5 : active.maxX <= column.minX + 0.5
    XCTAssertTrue(clear, "active: clear of the column \(column); field \(active)")
  }
```

- [ ] **Step 6: Run it on the Duo.** `<run>` = `t3-later`, with `-only-testing:RunnerTests/NativeTabsTests/testUnderAVerticalBarALaterSelectionShowsUIKitsBottomField`.

Expected: `exit=0`, 1 passed, 0 skipped. This test pins UIKit behaviour that the shell does not change (decision 2), so it passes on its first run. There is no production change to drive red, and that is recorded as such. If it is skipped, the simulator has no vertical bar: check the posture and the runtime. If it fails, stop and report the failure text with the measured frames.

- [ ] **Step 7: Pre-commit, then commit.**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-vk979 && rtk proxy .githooks/pre-commit; echo "pre-commit exit=$?"
```

Expected: `pre-commit exit=0`. Then:

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-vk979 && rtk git add liquid_shell/example/ios/RunnerTests/RunnerTests.swift && rtk git commit -m "test(ios): the Duo ⌕ is UIKit's tab button; a later selection shows the bottom field (VK-979)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: full verification on fresh simulators; no commit

**Files:** none changed. Report only.

**Interfaces:**
- Consumes: Tasks 1 to 3 committed.
- Produces: the evidence for spec §5.

- [ ] **Step 1: Retire the working Duo.**

```bash
DUO=<udid from Task 1>; rtk proxy xcrun simctl delete "$DUO"; echo "exit=$?"
```

Expected: `exit=0`.

- [ ] **Step 2: Fresh Duo, full suite.** Run the disk check. On `STOP`, stop and report. On `OK`:

```bash
if DUO=$(xcrun simctl create vk979-duo-verify com.apple.CoreSimulator.SimDeviceType.iPhone-Duo com.apple.CoreSimulator.SimRuntime.iOS-27-1); then echo "created $DUO"; else echo "create failed: exit $?"; fi
```

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-vk979 && DUO=<udid>; IOS_UNIT_DEVICE="$DUO" rtk make ios-unit; echo "exit=$?"
```

Read `liquid_shell/example/build/ios-unit.xcresult` with the summary command.

Expected: `exit=0`, `totalTestCount` 232, `failedTests` 0, `expectedFailures` 0, `skippedTests` 24, `passedTests` 208. Baseline on main was 227 / 200 / 24 skipped / 3 expected. This adds the 3 former expected failures and 5 new tests. Write the exact numbers down. Any `failedTests` > 0 or `expectedFailures` > 0 blocks the PR.

- [ ] **Step 3: Delete the verify Duo.**

```bash
DUO=<udid>; rtk proxy xcrun simctl delete "$DUO"; echo "exit=$?"
```

- [ ] **Step 4: Fresh iPhone 17 Pro iOS 26.5, full suite.** Run the disk check. On `STOP`, stop and report. On `OK`:

```bash
if P26=$(xcrun simctl create vk979-p26 com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-26-5); then echo "created $P26"; else echo "create failed: exit $?"; fi
```

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-vk979 && P26=<udid>; IOS_UNIT_DEVICE="$P26" rtk make ios-unit; echo "exit=$?"
```

Expected: `exit=0`, `totalTestCount` 232, `failedTests` 0, `expectedFailures` 0, `skippedTests` 27, `passedTests` 205. Baseline on main was 227 / 201 / 26 skipped. The 4 new tests that run on any iPhone pass, and the Duo-only test skips. No vertical bar exists on 26.5, so every changed test runs its no-bar path.

- [ ] **Step 5: Clean up.**

```bash
P26=<udid>; rtk proxy xcrun simctl delete "$P26"; echo "exit=$?"
cd /Users/invoker/Projects/tuvi/liquid_shell-vk979 && rm -rf liquid_shell/example/build && rtk git status --short; df -h / | tail -1; xcrun simctl list devices | grep vk979
```

Expected:
- `exit=0`;
- `git status` shows only the controller's untracked spec and plan, if they are still uncommitted;
- the free space is printed;
- the last `grep` prints nothing.

- [ ] **Step 6: Report** to the controller, for the PR body and Plane:
  - both runs' command, exit code and summary dict;
  - the red and green evidence of Tasks 1 to 3, including the trailing circle's measured frame from Task 3 Step 4;
  - the three commit hashes (`rtk git log --oneline -3`);
  - the limit: posture change (fold or unfold) is unit-tested and wiring-tested only, not verified on a device or simulator.
