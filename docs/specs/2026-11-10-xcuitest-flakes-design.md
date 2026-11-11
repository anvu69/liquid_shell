# The page and minimize XCUITests wait for a settled screen (VK-1043)

Status: approved by the owner on 2026-11-10 ("duyệt").

## 1. Problem

Since 2026-11-05, the CI legs `ios-ui (iPhone)` and `ios-minimize (iPhone)` fail
in most runs, each time on a different XCUITest. The first failing run is
42003075365, the first main run after PR #32 (VK-443, page actions). 23 of the
33 failures are tests that use the `pages` demo, and none of them failed before
that merge. The simulator stayed on iOS 26.5 throughout. The harness starts a
fresh app for every test and does not retry.

Evidence: `.superpowers/sdd/vk1043-investigation.md`, which has per-run tables
and file:line references.

- **A. The screen is not ready yet.** VK-443 gives a root page with actions a
  native nav bar, and the example's Home has an `Add` action. That bar appears
  after Flutter's rows are already on screen, so Home's content moves down by
  one bar height (54 pt). The tests treat "the row exists" as "ready" and tap
  `Detail 1` straight away. The tap either fails as "Not hittable"
  (`PagesUITests.swift:43`, `MinimizeUITests.swift:187`) or lands where the row
  used to be, so nothing is pushed (Pages:45/89, Minimize:189).
- **B. A check without a wait.** This is the most common failure, in 7 runs.
  `PagesUITests.swift:71` checks the tab bar with `.exists`, with no wait.
- **C. Load.** This existed before VK-443, since 2026-10-29. On a loaded runner,
  XCUITest's pre-gesture check took 30 s in one run, and then a 0.3 s drag took
  5 s to send. Single drags and swipes that are judged by their speed then do
  not minimize (Minimize:172/264/288) or do not pop (Pages:63).

## 2. Decision

These are test-only changes in `liquid_shell/example/ios/RunnerUITests/`.

1. **B.** `PagesUITests.swift:71` waits for the tab bar with
   `waitForExistence(timeout: 10)`.
2. **Launch.** `launch()` in `PagesUITests` and `MinimizeUITests` waits until the
   native chrome is up: the tab bar, plus Home's navigation bar when the demo
   shows one (the `pages` demo with `Add`). The deadline is 10 s, with a message.
3. **A.** A shared helper, `tapWhenSettled(_ element:, timeout: 10)`. It waits
   until the element `isHittable` and its `frame` is the same in two samples
   200 ms apart, then taps once. At the deadline it takes one last sample:
   if that sample equals the one before it, it taps; otherwise it fails, and
   the message gives the last frame and hittability. (On a loaded runner one
   query can take seconds, so the deadline can pass after one sample.) It
   never taps blindly a second time.
   The row taps in Pages and Minimize use it. The helper lives in a new
   `RunnerUITests/UITestWaits.swift` (an `XCTestCase` extension), which the
   other suites may adopt later. Moving them over is out of scope.
4. **C.** A minimize drag that did not minimize is retried once, in the
   recorded form that SearchUITests uses (VK-551): an
   `XCTContext.runActivity(named: "VK-1043: retry the drag (the first was dropped)")`
   plus a `print`. A second failure still fails. The Pages edge swipe at :63
   already retries. Added after the first CI round (owner, option A): the
   status-bar test gets one more tap when its two taps leave the list
   scrolled, recorded as `VK-1043: retry the status-bar tap (the last was
   dropped)`. In CI one tap took 58 s to send and read as a press.
5. **Follow-ups**, filed as new Plane items rather than fixed here:
   - whether Flutter's top inset always follows the root bar when it appears
     after launch (`syncFlutter`), which could be a VK-443 layout bug that
     users see;
   - logging that names the check in `_onNativePageAction` that drops a tap,
     for the single Favourite-tap failure (Pages:96).

Rejected: test retries in `tool/ios_xctest.sh`. They would hide real bugs in
every suite.

## 3. Verification

1. `.githooks/pre-commit` exits 0.
2. Locally, on a freshly created iPhone 17 Pro (iOS 26.5) simulator, deleted
   afterwards: `PagesUITests` and `MinimizeUITests` pass, run through
   `tool/ios_xctest.sh`.
3. CI on the PR: the first run is green, then `ios-minimize (iPhone)` is re-run
   until it has 10 green runs and `ios-ui (iPhone)` until it has 5. The PR
   reports any `VK-1043: retry` activity seen in the logs.
