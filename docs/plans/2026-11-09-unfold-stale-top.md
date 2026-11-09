# Flutter's Top Follows the Search Field After a Fold (VK-1024) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the iPhone Duo's vertical bar comes or goes and the search root's field is re-styled, Flutter's held top inset is re-read even if the page is scrolled.

**Architecture:** `NativeTabsController.verticalBarChanged()` writes `hidesSearchBarWhenScrolling`. After that write it lays the search tab's navigation controller out, force-reads the root host's resting top, and syncs Flutter. Spec: `docs/specs/2026-11-09-unfold-stale-top-design.md`.

**Tech Stack:** Swift (UIKit, iOS 26+ / 27.1), XCTest in `liquid_shell/example/ios/RunnerTests`.

## Global Constraints

- Swift sources: `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/`.
- No re-style or move of a focused field: the write stays skipped while a search is active (VK-979 rule, unchanged).
- Tests inject the bar's presence with `tabs.readVerticalBar` and call `tabs.verticalBarChanged()` directly (`simctl` has no posture).
- Assertion accuracy 0.5pt. Scroll offset 400.
- Full suite: iPhone Duo iOS 27.1 and iPhone 17 Pro iOS 26.5, each on a simulator you create and delete by UDID.
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Run `.githooks/pre-commit` manually and check its exit status before `git commit`; never `--no-verify`. `git add` explicit paths only (`.superpowers/` is not ignored here).

---

### Task 1: Re-read Flutter's top after a vertical-bar re-style

**Files:**
- Modify: `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeTabsController.swift` (`func verticalBarChanged()`, ~L388-400)
- Modify: `liquid_shell_ios/CHANGELOG.md` (`## 0.1.0-dev.12`, the VK-979 bullet)
- Test: `liquid_shell/example/ios/RunnerTests/RunnerTests.swift` (class `NativeTabsTests`, after `testAVerticalBarChangeWhileSearchingWaitsForTheSearchToEnd`)

**Interfaces:**
- Consumes: `NativeTabsController.readVerticalBar`, `verticalBarChanged()`, `navControllers`, `topHost(ofTab:)`, `setPageScroll(tab:offset:)`, `setSearchActive(_:)`, `debugTap(.searchCancel, index:)`, `syncFlutter()`; `PageHostController.rereadRestingTop(force:)`; test helpers `installedSearchShell(selected:)`, `requirePhone()`, `hasVerticalBar(_:)`, `settle()`, `settle(sending:_:)`.
- Produces: nothing new for other tasks.

- [ ] **Step 1: Write the failing tests**

Insert after `testAVerticalBarChangeWhileSearchingWaitsForTheSearchToEnd`:

```swift
  /// The search root scrolled to 400 with its field under the title row (the
  /// vertical bar's style), injected first on an iPhone without the bar.
  private func scrolledSearchRootWithTheTopField() throws
    -> (NativeTabsController, PageHostController)
  {
    try requirePhone()
    let tabs = try installedSearchShell(selected: 2)
    let host = try XCTUnwrap(tabs.topHost(ofTab: 2))
    if !hasVerticalBar(tabs) {
      tabs.readVerticalBar = { _ in true }
      tabs.verticalBarChanged()
      settle()
    }
    tabs.setPageScroll(tab: 2, offset: 400)
    settle()
    return (tabs, host)
  }

  /// An unfold on a scrolled search root moves the field, which is not a
  /// scroll: Flutter's held top follows it (VK-1024).
  func testAVerticalBarChangeOnAScrolledSearchRootRereadsFlutterTop() throws {
    let (tabs, host) = try scrolledSearchRootWithTheTopField()
    tabs.readVerticalBar = { _ in false }
    tabs.verticalBarChanged()
    settle()
    XCTAssertEqual(
      tabs.flutter.view.safeAreaInsets.top, host.view.safeAreaInsets.top, accuracy: 0.5,
      "the field moved: Flutter's top is re-read")
  }

  /// An unfold during a search on a scrolled root: the deferred write at the
  /// search's end re-reads Flutter's top too (VK-1024).
  func testAVerticalBarChangeDuringASearchRereadsFlutterTopAtItsEnd() throws {
    let (tabs, host) = try scrolledSearchRootWithTheTopField()
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    tabs.readVerticalBar = { _ in false }
    tabs.verticalBarChanged()
    settle(sending: "searchActive false") { tabs.debugTap(.searchCancel, index: 2) }
    settle()
    XCTAssertEqual(
      tabs.flutter.view.safeAreaInsets.top, host.view.safeAreaInsets.top, accuracy: 0.5,
      "the deferred write: Flutter's top is re-read")
  }
```

If `topHost(ofTab:)` returns a type other than `PageHostController`, use that type in the helper's return tuple.

- [ ] **Step 2: Run the tests to verify they fail**

Create an iPhone Duo iOS 27.1 simulator and boot it (check the `simctl create` exit status). Run:

```bash
FLUTTER="fvm flutter" tool/ios_xctest.sh <udid> "$PWD/liquid_shell/example/build/vk1024.xcresult" 900 60 120 \
  -only-testing:RunnerTests/NativeTabsTests/testAVerticalBarChangeOnAScrolledSearchRootRereadsFlutterTop \
  -only-testing:RunnerTests/NativeTabsTests/testAVerticalBarChangeDuringASearchRereadsFlutterTopAtItsEnd
```

(RESULT must be an absolute path. Arguments: UDID, RESULT, SUITE_SECONDS, DEFAULT_ALLOWANCE, MAX_ALLOWANCE, then the selection. See the header of `tool/ios_xctest.sh`. Delete the `.xcresult` before each re-run.)

Expected: both FAIL on the assertion, with the Flutter top about 54pt larger than the host's.
If either test PASSES before the fix, stop and report BLOCKED with the measured insets. Do not change the fix to make a passing test fail.

- [ ] **Step 3: Write the fix**

In `verticalBarChanged()`, replace the write block:

```swift
    {
      nav.rootHost.navigationItem.hidesSearchBarWhenScrolling = hides
    }
```

with:

```swift
    {
      nav.rootHost.navigationItem.hidesSearchBarWhenScrolling = hides
      // The field moved, which is not a scroll: Flutter's held top follows
      // it, as a search's start and end do (VK-1024).
      nav.view.layoutIfNeeded()
      nav.rootHost.rereadRestingTop(force: true)
      syncFlutter()
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Use the same command as Step 2. Expected: both PASS.
If they still fail because the host's inset settles only after the synchronous layout, report DONE_WITH_CONCERNS with the measured insets, and do not invent another mechanism. The controller decides on a follow-up.

- [ ] **Step 5: CHANGELOG**

In `liquid_shell_ios/CHANGELOG.md`, change the end of the VK-979 bullet under `## 0.1.0-dev.12` from

```
  vertical bar comes or goes, and never during a search (VK-979).
```

to

```
  vertical bar comes or goes, and never during a search (VK-979). A fold
  or unfold on a scrolled page re-reads Flutter's top inset, which no
  longer keeps the old one until the page scrolls back (VK-1024).
```

- [ ] **Step 6: Full suite on both devices**

```bash
IOS_UNIT_DEVICE=<duo udid> FLUTTER="fvm flutter" make ios-unit
IOS_UNIT_DEVICE=<iphone 17 pro 26.5 udid> FLUTTER="fvm flutter" make ios-unit
```

Expected: exit 0 on each, with 0 failed and 0 expected failures. Record the total, passed and skipped counts from `xcresulttool`. Then delete both simulators by UDID.

- [ ] **Step 7: Commit**

```bash
.githooks/pre-commit; echo "hook exit $?"   # must be 0
git add liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeTabsController.swift \
  liquid_shell/example/ios/RunnerTests/RunnerTests.swift liquid_shell_ios/CHANGELOG.md \
  docs/specs/2026-11-09-unfold-stale-top-design.md docs/plans/2026-11-09-unfold-stale-top.md
git commit -m "fix(ios): Flutter's top follows the search field after a fold on a scrolled page (VK-1024)" \
  -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
