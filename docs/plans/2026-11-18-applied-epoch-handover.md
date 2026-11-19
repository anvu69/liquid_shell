# Applied-epoch hand-over (VK-1074, VK-1075, VK-1082) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** what a shell draws follows the config native has applied, and the shell knows which config that is: an `epoch` stamped by the Dart host, echoed by native as `appliedEpoch`. Fixes the standby page bar (S-1), the owner-change takeover, the quick re-engage and (if Task 0 says go) the disengage. B6 makes `LiquidNativeSearchActiveChanged` take a named `active`.

**Architecture:** spec `docs/specs/2026-11-18-applied-epoch-handover-design.md`. Interface fields → Pigeon → host stamping → native takeover → a pure phase function in `native_layout.dart` → `_handOver` in `liquid_shell.dart`.

**Tech Stack:** fvm (3.44.9 floor, 3.47.9 pinned, 3.50.0 stable), `flutter_test`, XCTest (RunnerTests), Pigeon 27.3.0 (`tool/pigeon`), GNU make.

## Global Constraints

- Branch `VK-1075-engaged-ack`. No push, no tag, no publish.
- TDD: each red test shown failing for the right reason before the code.
- `analysis_options.yaml` untouched; `make analyze` keeps `--fatal-infos`.
- Simulators: own iPhone 17 Pro and iPad (iOS 26.5), by UDID only, deleted afterwards.
- `.githooks/pre-commit` by hand before every commit, exit 0; explicit `git add` paths.
- Commit: `<type>(<scope>): <summary> (VK-…)` + `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

---

### Task 0: Measure the native disengage (go/no-go for D6)

**Files:** Modify `liquid_shell/example/ios/RunnerTests/RunnerTests.swift`

- [ ] **Step 1:** Characterization test: engage with `Add`, settle, `apply(dormant)`; in `RecordingEvents.onState` with `engagedApplied == false` record `flutter.view.safeAreaInsets.top`, `flutter.additionalSafeAreaInsets`, `flutter.view.frame`, `tabs.view.isHidden`.
- [ ] **Step 2:** Run on both sims. Expect: additional insets zero, the frame the root bounds, hidden, when the state is sent → GO. Otherwise NO-GO (skip Task 6).
- [ ] **Step 3:** Round trip: a temporary, uncommitted DEBUG log in the example, if feasible. Record in spec §9.
- [ ] **Step 4:** Pre-commit; commit `test(ios): the disengage hides and resets Flutter's insets before its state (VK-1074)`.

### Task 1: The epoch on the channel; B6

**Files:** `liquid_shell_platform_interface/lib/src/native_chrome.dart` + its tests; `tool/pigeon/pigeons/native_shell.dart`; generated Dart and Swift; `liquid_shell_ios/lib/src/mapping.dart` + test; Swift call sites (`NativeTabsController.currentState`, installer: literal 0); `tool/check_analyze.dart` + `tool/test/check_analyze_test.dart`; every `LiquidNativeSearchActiveChanged(` call site; Makefile comment.

- [ ] **Step 1: Red:** the fields default to 0 and take part in `==`/`hashCode`/`toString`; `configToNative` maps `epoch`, `stateFromNative` maps `appliedEpoch`; `LiquidNativeSearchActiveChanged(active: true)` and its `toString`; R2 in `native_chrome.dart` blocks in `check_analyze_test`.
- [ ] **Step 2:** Run: red (compile errors / failing expectations).
- [ ] **Step 3:** Fields; Pigeon (fields last); `make pigeon`; mapping; Swift passes `appliedEpoch: 0` (Task 3 wires it); B6 + call sites; R2 list.
- [ ] **Step 4:** Green on the three packages and `tool/test`; `make pigeon-check`; analyze on 3.44.9 / 3.47.9, `make analyze-stable` on 3.50.0. Commit `feat(platform): config epoch and appliedEpoch on the channel; named active (VK-1075)`.

### Task 2: The host stamps and bumps the epoch

**Files:** `liquid_shell/lib/src/native/native_host.dart`; `liquid_shell/test/helpers/fake_native_platform.dart`; create `liquid_shell/test/unit/native_host_test.dart`

- [ ] **Step 1: Red:** a claim bumps; the owner's release bumps; an engaged flip bumps; the dormant config bumps; a forced resend after a state keeps it; dedup compares epoch; attach seeds from `appliedEpoch`; `claim.epoch` and `claim.releaseEpoch`; `appliedConfig`.
- [ ] **Step 2:** Fake native model: `updateNativeChrome` applies (when `autoApply`) and pushes a state with `engagedApplied`/`appliedEpoch` of the config, deduplicated; `autoAck` maps onto it.
- [ ] **Step 3:** Implement; whole `liquid_shell` suite green (record any churn).
- [ ] **Step 4:** Commit `feat(shell): the native host stamps each config with a hand-over epoch (VK-1075)`.

### Task 3: Native takeover

**Files:** `NativeTabsController.swift`, `RunnerTests.swift`

- [ ] **Step 1: Red RunnerTests:** `appliedEpoch` follows the applied config; a new epoch while engaged applies pages with no animation keys and acks with the inset set (iPhone); the same epoch animates; a takeover from `hidden` has no fade; `hidden` toggles send no state; a reconnect re-applies `lastConfig` with an equal state.
- [ ] **Step 2:** Run on the iPhone sim: red.
- [ ] **Step 3:** `appliedEpoch: config?.epoch ?? 0`; `takeover` beside `engaging` in `applyPages`, `setChromeVisible`, the pre-ack layout.
- [ ] **Step 4:** Green on both sims; commit `feat(ios): an owner's takeover is applied unanimated and echoes its epoch (VK-1075)`.

### Task 4: Dart takeover phase; the shortcut removed (VK-1075)

**Files:** `liquid_shell/lib/src/native/native_layout.dart` (+ unit test), `liquid_shell/lib/src/shell/liquid_shell.dart`, `liquid_shell/test/widget/native_pages_test.dart`

- [ ] **Step 1: Red:** the phase function's table; widget tests: push over engaged; pop back; root replaced in one frame; quick off → auto with a stale ack; hot restart (attach acked with a foreign epoch); the latch; D3 (iPad default root → root with actions: waiting); takeover over `hidden` → waiting; epoch 0 → dev.13; the 250 ms fallback; the generation guard.
- [ ] **Step 2:** Implement; VK-1064 tests reviewed one by one (spec change vs regression).
- [ ] **Step 3:** Commit `fix(shell): a new owner takes the native chrome over without a gap or a double bar (VK-1075)`.

### Task 5: Standby keeps the native page layout (S-1)

**Files:** `liquid_shell.dart`, `native_pages_test.dart`

- [ ] **Step 1: Red:** a shell pushed over an engaged one: through push and pop, A shows no `FlutterPageBar` and A's row never moves. The `nativeChrome: off` nested shell still draws its bar; a same-route nested `auto` shell leaves the outer bars.
- [ ] **Step 2:** A route-covered flag (`secondaryAnimation` not dismissed) and `_nativePageBar = true` in covered standby.
- [ ] **Step 3:** Re-run `pushed_shell_back_test.dart`, `native_search_test.dart`; commit `fix(shell): a shell in standby under a pushed shell keeps native's page layout (VK-1082)`.

### Task 6: Releasing + mirror hold (VK-1074; only on Task 0 GO)

**Files:** `native_layout.dart`, `liquid_shell.dart`, `native_pages_test.dart`

- [ ] **Step 1: Red:** mode off with native insets still applied: no Flutter page bar or tab bar until `released`, the row put in both arrival orders; the 250 ms fallback; a destinations flap; a re-engage while releasing → takeover.
- [ ] **Step 2:** Implement; commit `fix(shell): a disengaging shell keeps native's layout until native has hidden (VK-1074)`.

### Task 7: IME and search guards

**Files:** `native_pages_test.dart`, `native_search_test.dart`

- [ ] **Step 1:** A composing `hoa` stays through a takeover, a release and a standby push → pop: no `setClient`/`clearClient`/`setEditingState`, the same `EditableTextState`.
- [ ] **Step 2:** A takeover's state event does not end an active native search.
- [ ] **Step 3:** Commit `test(shell): IME and search across a takeover, a release and standby (VK-1075)`.

### Task 8: Docs and release

**Files:** spec §9 and status, CHANGELOGs, pubspecs, podspec, example case "shell over shell".

- [ ] **Step 1:** Example case: a pushed full-screen shell over the shell.
- [ ] **Step 2:** CHANGELOGs; `0.1.0-dev.14` for all four (as VK-1079 did for dev.13).
- [ ] **Step 3:** Verification: `fvm flutter test` in the three packages, `fvm dart test tool/test`, `make pigeon-check`, `make analyze-stable` (3.50.0), `make provenance`, RunnerTests on both sims, `.githooks/pre-commit`, pana on 3.50.0.
- [ ] **Step 4:** Commits `feat(example): …`, `chore(release): bump to 0.1.0-dev.14 (VK-1075)`.
