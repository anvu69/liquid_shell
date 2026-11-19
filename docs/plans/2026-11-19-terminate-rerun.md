# Terminate Rerun (VK-1083) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A red iOS XCTest suite whose only failures are XCTest's "Failed to terminate vn.lasoai.liquidShellExample:<pid>" (a stalled runner, not the tests) reruns those tests once, recorded; every other red stays red.

**Architecture:** `tool/ios_xctest.sh` reads the first summary once, gates it with an inline `python3 -I -c` parser, and on a pass warns, copies the summary, runs `tool/ios_sim.sh diagnose` and the new `termlog`, then reruns only the matched ids into `<result>-rerun.xcresult` under a `MAX_ALLOWANCE × n + 120` cap. CI uploads the rerun bundle on failure. Spec: `docs/specs/2026-11-19-terminate-rerun-design.md`. Evidence: `.superpowers/sdd/vk1083-design.md` (vankhan ledger dir, untracked, not in this worktree).

**Tech Stack:** bash 3.2 (macOS) / bash 5 (ubuntu), python3 `json` + `re`, Dart `test` (`tool/test`, fake simulator tools), GitHub Actions.

## Global Constraints

- CI only: no product, plugin or Swift test change; no CHANGELOG line, no version bump.
- The default fake summary stays unparseable (`FAKE SUMMARY` before the JSON); existing `tool/test` tests stay untouched and green.
- bash 3.2: no `mapfile`, no empty-array expansion under `set -u`; a failing or absent `python3` means "no rerun", never an abort.
- Run `.githooks/pre-commit` by hand before every commit and check exit 0; never `--no-verify`. `git add` explicit paths only.
- Commit: `<type>(<scope>): <summary> (VK-1083)` + `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Simulators: an own one, addressed and deleted by UDID; never another session's, never `shutdown all` / `erase all`. Keep ≥10 GB free.
- Out of scope: product code, option B (Swift `XCTExpectFailure`), option C (screen recording), VK-1081.

---

### Task 1: Fake harness: per-call test outcomes and a failures summary

**Files:**
- Modify: `tool/test/fake_sim.dart`
- Create: `tool/test/fixtures/h2-terminate-summary.json` (H2's real `xcresulttool` summary)

- [ ] **Step 1:** `FAKE_TESTS="fail pass"`: the outcomes of the 1st, 2nd, … `test-without-building` (`pass`, `fail`, `stall`), as `FAKE_DRIVES`; overrides `FAKE_TEST`. `FAKE_RESULT_MISSING`: a red run writes no bundle. `xcresulttool … summary` fails on an absent bundle. With `FAKE_FAILURES` (a JSON array) it prints a parseable summary: `failedTests` `FAKE_FAILED` (default the array's length, here given by the test), at top level and under `devicesAndConfigurations`, and `totalTestCount` `FAKE_RERUN_TOTAL` (default 1) for a `-rerun.xcresult`.
- [ ] **Step 2:** `fvm dart test tool/test/ios_xctest_test.dart tool/test/ios_sim_test.dart`: green, the defaults are unchanged.
- [ ] **Step 3: Commit** `test(ci): fake per-call xcodebuild test outcomes and failure lists (VK-1083)`.

### Task 2: The gated rerun

**Files:**
- Modify: `tool/ios_xctest.sh`, `tool/test/ios_xctest_test.dart`

- [ ] **Step 1: Red.** The positive case from the fixture: exit 0, two `test-without-building` calls, the second with `-only-testing:RunnerUITests/MinimizeUITests/testAScrollMinimizesAndAFlingToTheTopExpands`, `-resultBundlePath …-rerun.xcresult` and without the original selection, a `::warning::` line. Red today: one call.
- [ ] **Step 2:** The loosest rerun that passes it (any red with a parseable summary reruns its failed ids).
- [ ] **Step 3: Red, one at a time, each against the looser version, then tighten:** a non-exhaustive list (`failedTests` 2, one entry); 3 matching ids; one terminate and one other failure; an empty list; an unreadable summary; an absent bundle; a red rerun (the rerun's status, both summaries); a rerun of 0 tests (red); a stall (124, no rerun); the rerun's cap.
- [ ] **Step 4:** Green: the whole `tool/test`.
- [ ] **Step 5: Commit** `ci(ci): rerun only the tests XCTest failed to terminate before, once, recorded (VK-1083)`.

### Task 3: Keep the record

**Files:**
- Modify: `tool/ios_xctest.sh`, `tool/ios_sim.sh`, `tool/test/ios_xctest_test.dart`, `tool/test/ios_sim_test.dart`, `.github/workflows/ci.yaml`

- [ ] **Step 1: Red:** a rescued run leaves `IOS_DIAG_DIR/<UTC>-<label>-terminate-rerun.json` (the first summary), one diagnose dump `…-<label>_terminate` and a `…-<label>-term.log`; `ios_sim.sh termlog UDID LABEL SECONDS` runs `log show --last SECONDSs` with the D11 predicate, caps at `IOS_TERMLOG_BYTES`, survives a failed read, and appears in the usage.
- [ ] **Step 2:** Implement; `applog` and `termlog` share one helper.
- [ ] **Step 3:** Add `liquid_shell/example/build/<suite>-rerun.xcresult` to the `failure()` uploads of ios-unit, ios-ui and ios-minimize.
- [ ] **Step 4: Commit** `ci(ci): keep the first summary and the rerun bundle of a terminate rerun (VK-1083)`.

### Task 4: Docs

- [ ] Header of `tool/ios_xctest.sh`: step 3b, in the style of VK-625's steps; `ios_sim.sh`'s header for `termlog` and `IOS_TERMLOG_BYTES`. Folded into Tasks 2 and 3's commits when they touch the same lines, else `docs(ci): …`.

### Task 5: Verify

- [ ] `make test` and `.githooks/pre-commit` (the repo has no shellcheck).
- [ ] End to end on an own iPhone 17 (iOS 26.5): a throwaway `MinimizeUITests/testZZTerminateProbe` failing with the H2 text, `make ios-minimize`: the real summary passes the gate, the second `xcodebuild` selects only the probe, the rerun bundle's `totalTestCount` is 1, red twice, the warning, summary copy, dump and term log present. Remove the probe (`git status` clean), delete the simulator by UDID.
- [ ] Evidence to `.superpowers/sdd/vk1083-report.md` (vankhan ledger dir). No push.
