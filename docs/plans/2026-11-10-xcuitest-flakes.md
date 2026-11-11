# XCUITest Flakes (VK-1043) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** PagesUITests and MinimizeUITests wait for a settled screen before they tap, and retry a dropped minimize drag once (recorded), so that they stop failing at random on a loaded CI runner.

**Architecture:** Test-only Swift in `liquid_shell/example/ios/RunnerUITests/`: a new `UITestWaits.swift` holds `tapWhenSettled`. `launch()` gets chrome waits, Pages:71 gets a wait, and the minimize drag gets one recorded retry. Spec: `docs/specs/2026-11-10-xcuitest-flakes-design.md`. Evidence: `.superpowers/sdd/vk1043-investigation.md` (untracked; it is in the vankhan ledger dir, not in this worktree).

**Tech Stack:** XCUITest, Xcode 27.1, iOS 26.5 simulator, `tool/ios_xctest.sh`.

## Global Constraints

- Test files only (RunnerUITests). No package code, no `tool/` changes, no CHANGELOG line.
- No blind re-tap. Only the minimize drag gets a retry, exactly once, recorded with `XCTContext.runActivity(named: "VK-1043: retry the drag (the first was dropped)")` plus a `print`.
- Deadlines: 10 s for each wait. The settle check takes two equal frames 200 ms apart.
- If you add `UITestWaits.swift`, add it to the RunnerUITests target in `liquid_shell/example/ios/Runner.xcodeproj/project.pbxproj`. That is the one non-Swift file allowed.
- Simulators: create your own and delete them by UDID. Never touch the protected ones (572B92E2, 383C4573, C428FE39, D3A948FD, B7246683). Never `simctl shutdown all` or `erase all`. No physical devices.
- Run `.githooks/pre-commit` manually and check its exit status before committing; never `--no-verify`. `git add` explicit paths only (`.superpowers/` is not ignored, and must not even sit in the worktree while the hook runs: its provenance check scans untracked files).
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

---

### Task 1: Settled taps, chrome waits, one recorded drag retry

**Files:**
- Create: `liquid_shell/example/ios/RunnerUITests/UITestWaits.swift`
- Modify: `liquid_shell/example/ios/Runner.xcodeproj/project.pbxproj` (add the file to the RunnerUITests target)
- Modify: `liquid_shell/example/ios/RunnerUITests/PagesUITests.swift` (`launch()` ~:12, the row taps ~:43/45/89, the tab-bar check ~:71)
- Modify: `liquid_shell/example/ios/RunnerUITests/MinimizeUITests.swift` (`launch()` ~:15, `drag` ~:108 and its callers ~:172/264/288, the row tap ~:187-189)

- [ ] **Step 1: Read the evidence.** Read `/Users/invoker/Projects/tuvi/vankhan/.superpowers/sdd/vk1043-investigation.md` (groups A/B/C, file:line references) and the two suites.

- [ ] **Step 2: The helper.**

```swift
import XCTest

extension XCTestCase {
  /// Taps [element] once it is hittable and its frame has stopped moving
  /// (two equal frames 200 ms apart). Fails at [timeout] with the last
  /// state; never taps twice.
  func tapWhenSettled(
    _ element: XCUIElement,
    timeout: TimeInterval = 10,
    _ what: String,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let deadline = Date().addingTimeInterval(timeout)
    var last = CGRect.null
    while Date() < deadline {
      if element.exists, element.isHittable {
        let frame = element.frame
        if frame == last {
          element.tap()
          return
        }
        last = frame
      } else {
        last = .null
      }
      Thread.sleep(forTimeInterval: 0.2)
    }
    XCTFail(
      "\(what): not settled after \(timeout) s (exists \(element.exists), "
        + "hittable \(element.exists && element.isHittable), frame \(last))",
      file: file, line: line)
  }
}
```

  Adjust only as compilation requires. If the suites already have a `wait(timeout:until:)` style, keep this helper independent anyway.

- [ ] **Step 3: Launch waits.** In both `launch()`, after the app starts, wait (10 s, with a message) for the tab bar. In Pages also wait for Home's navigation bar, the one with the `Add` button (check the real identifiers in the suite or the example's `pages` case). For Minimize demos without a root bar, the tab bar is enough.

- [ ] **Step 4: Use them.** Replace the row taps named in the spec (`Detail 1` and others in the investigation's group A) with `tapWhenSettled`. At Pages:71, replace `.exists` with `waitForExistence(timeout: 10)`.

- [ ] **Step 5: Drag retry.** Where a minimize drag is followed by a minimized wait (`waitMinimized`), apply the spec's recorded retry once if the first wait fails: one activity, one print, one more `drag`, then the original assertion.

- [ ] **Step 6: Local runs.** Create an iPhone 17 Pro iOS 26.5 simulator and check that `simctl create` exits 0. Run `PagesUITests` and `MinimizeUITests` through `tool/ios_xctest.sh` (see the Makefile for the arguments and allowances). Expected: 0 failed. Delete the simulator. Keep disk ≥10 GB free.

- [ ] **Step 7: Hook and commit.** Run `.githooks/pre-commit` and check that it exits 0. Commit the Swift files, the pbxproj, the spec and this plan: `test(ios): page and minimize UI tests wait for a settled screen (VK-1043)`.
