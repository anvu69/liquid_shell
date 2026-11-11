# The Flutter search edge-swipe test retries a dropped ⌕ tap (VK-1063)

Status: approved by the owner on 2026-11-11 ("duyệt").

## 1. Problem

`SearchUITests.testFlutterAnEdgeSwipeOffTheSearchRootKeepsTheCaseAndTheKeyboardDismissable`
failed in CI run 42947448041 (attempt 3, leg `ios-ui (iPhone)`) at
`XCTAssertTrue(either.waitForExistence(timeout: 10), "a field")` in
`typeAboveTheCaseList("search-above-liquid")`. The same assertion failed 6 times
in about 150 executions since 2026-10-21 (about 5% on iPhone, 3% on iPad).

Evidence: `.superpowers/sdd/vk1063-investigation.md` (the xcresult, the
synthesized-event plist, the screen recording and the UI hierarchy of that run).

- The tap went to the centre of the settled ⌕ `Button 'Search'`, in the app
  process. The element had not moved for about 2.5 s, so `tapWhenSettled` would
  have sent the identical tap.
- The app saw the touch: the ⌕ showed its press highlight and then went idle.
  But the search tab was never selected, the screen stayed on Home (`Button
  'Home', Selected`) for the next 10 s, and no field appeared.
- The runner was heavily loaded at that moment: terminating the previous app
  took 13.3 s (normally 1.7 s), launch to tap took 30.4 s (normally 8 s), and the
  app drew about 0.4 s behind the input.
- This is the only XCUITest that taps the Flutter-drawn ⌕. The others tap the
  native tab, and they passed in the same run.

Root cause: on a loaded runner the single tap was delivered but produced no tap
in Flutter, and the test taps only once. A longer wait would not help.

## 2. Decision

A test-only change in `liquid_shell/example/ios/RunnerUITests/SearchUITests.swift`,
in `typeAboveTheCaseList`:

1. Tap the ⌕ and wait up to 5 s for a field (the existing `either` query).
2. If no field appeared and Home is still the selected tab, tap the ⌕ once more,
   recorded as `XCTContext.runActivity(named: "VK-1063: retry the ⌕ tap (the
   first was dropped)")` plus a `print`, as VK-1043 does in `MinimizeUITests`.
3. The existing `XCTAssertTrue(either.waitForExistence(timeout: 10), "a field")`
   stays. A ⌕ that never opens the search still fails it.

No retry when the search is already open (a field exists, or Home is no longer
selected). No `tapWhenSettled`. No other suite changes.

## 3. Verification

1. `.githooks/pre-commit` exits 0.
2. Locally, on a freshly created iPhone 17 Pro (iOS 26.5) simulator, deleted
   afterwards: `SearchUITests` passes through `tool/ios_xctest.sh`.
3. In CI, any `VK-1063: retry` activity is reported on the PR. A regression that
   always needs the second tap shows up there.
