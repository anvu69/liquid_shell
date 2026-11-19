# A "Failed to terminate" failure is rerun once, gated and recorded (VK-1083)

Status: approved by the owner on 2026-11-19 (every default of the decision
table: D1 option A only, the script's gated rerun plus a record; D2 every
`testFailures` entry is a terminate failure, `failedTests` equals the
distinct matched ids, at most 2; D3 only those ids, `-only-testing`,
replacing the original selection; D4 one rerun; D5 all three callers of
`tool/ios_xctest.sh`; D6 `::warning::`, `ios_sim.sh diagnose` and the first
summary under `ios-diagnostics/`; D7 a rerun cap of `max_allowance × n +
120 s`; D8 an unreadable first result is not rerun; D9 `*-rerun.xcresult` in
the three `failure()` uploads; D10 no Swift-side `XCTExpectFailure`; D11 one
`log show` of the termination path; D12 the summary is parsed with
`python3`).

## 1. Problem

Twice in about 335 iPhone job attempts that run `MinimizeUITests` (H1 on
11-09 in `ios-ui`, H2 on 11-16 in the blocking `ios-minimize`), a test failed
inside `XCUIApplication.launch()`'s implicit terminate of the previous
test's app:

```
Failed to terminate vn.lasoai.liquidShellExample:12586: Failed to terminate vn.lasoai.liquidShellExample:0
```

H2's xcresult shows a stalled runner: a 27.9 s "check for interrupting
elements" and an 8 s drag in the previous test, then a terminate that failed
after 68.5 s (every other terminate in the bundle took about 2 s). The victim
app died on its own before the next test; the same simulator, never
rebooted, passed the 4 later tests. No crash report. H1 also had a real
failure in the same run. Root cause (best-supported hypothesis): during a
transient host stall, the simulator's process-termination path took longer
than XCTest's internal terminate deadline (about 60 s). The test's code is
not at fault and XCTest offers no API to catch the issue or set its deadline.
Product code is not involved (medium-high confidence: no lifecycle handler
that could delay a terminate).

Evidence: `.superpowers/sdd/vk1083-design.md` in the vankhan ledger dir (not
in this worktree): the 183-run scan, the H2 timeline, the options. The H2
summary is committed as `tool/test/fixtures/h2-terminate-summary.json` (its
artifact expires 2026-11-23).

## 2. Decision

`tool/ios_xctest.sh` reruns a red suite once, only on an exact positive
signal, only the tests that carry it, and records every rerun. No product or
Swift test change. No `-retry-tests-on-failure` (it retries every failure
without a signal; VK-1043, VK-1063, VK-1069, VK-1081 D10).

### 2.1 The gate (D2, D8)

A red suite is rerun only when xcodebuild exited 65 (the tests ran and some
failed: never a stall's 124, nor 70 or any other exit of a run that could
not test) and all of these hold on its `xcresulttool get test-results
summary`:

- the result bundle exists and its summary parses as JSON (`python3 -I`,
  D12: `make test` runs `tool/test` on ubuntu, which has no `plutil`);
- `testFailures` has at least one entry, and **every** entry's
  `failureText` matches
  `^Failed to terminate vn\.lasoai\.liquidShellExample:[0-9]+` (the bundle
  id is `IOS_APP_BUNDLE_ID`, escaped);
- each entry's id, `targetName` + `/` + `testIdentifierString` without its
  trailing `()`, has the shape `Target/Class/test` (word characters only);
- `result` is `Failed`, and `passedTests + failedTests + skippedTests +
  expectedFailures == totalTestCount` (no test went unrun);
- the top-level `failedTests` equals the number of distinct ids (a guard in
  case `testFailures` is not exhaustive);
- there are at most 2 ids.

Anything else (python3 missing or failing included) keeps the first run's
status, and the script says why it did not rerun.

### 2.2 The rerun (D3, D4, D7)

- One `xcodebuild test-without-building` with the same flags, but the
  original selection (`"$@"`, for example
  `-only-testing:RunnerUITests/MinimizeUITests`) **replaced** by one
  `-only-testing:<id>` per id: appended, the union would rerun the whole
  class.
- Result bundle `<result>-rerun.xcresult` (removed at the start of every
  run, next to `<result>`).
- Capped at `MAX_ALLOWANCE × n + 120` seconds (300 × n + 120 for the UI
  suites). A stalled rerun is diagnosed before the stop, as the suite is.
- The run's status is the rerun's. A red rerun saves its own app log and
  prints its summary, after the first one. A green rerun passes the
  zero-test guard on the rerun bundle, and its `passedTests` must equal the
  number of rerun ids (a skipped rerun test is red).
- Never more than one rerun.

### 2.3 The record (D6, D9, D11)

Before the rerun, in this order:

1. `::warning::ios_xctest: XCTest failed to terminate the previous app before
   <ids> (VK-1083); rerunning only those, once`.
2. The first summary, copied to
   `IOS_DIAG_DIR/<UTC>-<label>-terminate-rerun.json`.
3. `tool/ios_sim.sh diagnose UDID "<label> terminate"`: load, the app in the
   simulator's launchd, a sample.
4. `tool/ios_sim.sh termlog UDID LABEL SECONDS` (new): `log show --last
   SECONDS` of the termination path into
   `IOS_DIAG_DIR/<UTC>-<label>-term.log`, predicate
   `process == "runningboardd" OR process == "testmanagerd" OR eventMessage
   CONTAINS "<IOS_APP_BUNDLE_ID>"` (default `vn.lasoai.liquidShellExample`,
   `\` and `"` escaped for the predicate's string; final review, in place
   of D11's literal `liquidShellExample`), the window the suite's seconds plus a
   minute, at most its newest `IOS_TERMLOG_BYTES` (default 10 MB; a minute of
   runningboardd is chatty and the event can be early in the window). The
   read is capped at 120 s; a failed one leaves a note; it exits 0.

A rescued run is green, so only the `always()` upload of `ios-diagnostics/`
keeps its record: all three items land there. A red rerun also uploads
`*-rerun.xcresult` with the job's `failure()` diagnostics (D9).

### 2.4 Time

- `ios-minimize`: 900 s cap + at most 720 s rerun + about 600 s setup =
  about 2220 s, inside 45 minutes.
- `ios-ui`: 2100 + 720 + 600 = about 3420 s, inside 65 minutes.
- `ios-unit`: 900 + 360 + 600, inside 45 minutes.

No job timeout changes.

## 3. What it rescues

H2 (the only failure in its run). Not H1, which also had a real failure and
correctly stays red. A test that always fails to terminate still fails
twice.

## 4. Follow-ups

- The first real rescue shows as a `::warning::` with its dump and term log:
  record it on VK-1083 or a follow-up. Re-open option C (screen recording
  off) only if the dumps show sustained load during the stall.
- Option B (Swift `XCTExpectFailure`) only with a ticket that can induce the
  failure.

## 5. Verification

- `tool/test/fake_sim.dart`: per-call `FAKE_TESTS` outcomes, a parseable
  summary when `FAKE_FAILURES` is set (`FAKE_FAILED`, `FAKE_RERUN_TOTAL`),
  `FAKE_RESULT_MISSING`, `FAKE_STALL_RESULT` (a stall that leaves a
  readable bundle, so only the 124 check keeps it from a rerun),
  `FAKE_SUMMARY=broken`. The default summary stays unparseable.
- `tool/test/ios_xctest_test.dart`: the positive case from the H2 fixture,
  then each gate condition red against a looser version first (non-exhaustive
  list, n > 2, a mixed failure, an empty list, an unreadable or absent
  result, a stall, a red rerun, a rerun of 0 tests), plus the record.
- `tool/test/ios_sim_test.dart`: `termlog` carries the predicate and window.
- End to end (the flake itself cannot be induced): a throwaway, uncommitted
  `MinimizeUITests/testZZTerminateProbe` that fails with the H2 text, run by
  `make ios-minimize` on an own iPhone 17 (iOS 26.5) simulator: the real
  summary passes the gate, the second `xcodebuild` selects only the probe,
  the rerun bundle has `totalTestCount` 1, both runs are red, the warning,
  the summary copy, the dump and the term log exist. Then the probe is
  removed and the simulator deleted by UDID.
- `make test`, `.githooks/pre-commit`; CI green on the PR (the rerun path
  does not run on a green CI).
