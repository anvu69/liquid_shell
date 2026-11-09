# liquid_shell VK-990: `guard` tool tests survive a loaded machine, Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The `guard` group in `tool/test/ios_sim_test.dart` no longer flips to a false stall when the machine is busy.

**Architecture:** One literal changes, the shared stall deadline in the group's `drive` argument list, from `'2'` to `'5'`.

**Tech Stack:** Dart `package:test`, bash (`tool/ios_sim.sh`, `tool/with_timeout.sh`), fvm.

## Global Constraints

- Test-only: the only file changed is `tool/test/ios_sim_test.dart`. Do not change `tool/ios_sim.sh`, `tool/with_timeout.sh` or `tool/test/fake_sim.dart`.
- Run `.githooks/pre-commit` by hand before `git commit` and check its exit status. Never use `--no-verify`.
- Prefix shell commands with `rtk`. Kill CPU burners by their own PIDs, never with `pkill` by pattern.
- A fresh worktree needs `rtk make get` once before pre-commit.
- No simulator or Xcode work.

---

### Task 1: raise the guard deadline to 5 s

**Files:**
- Modify: `tool/test/ios_sim_test.dart:425`

**Interfaces:** none.

- [ ] **Step 1: Baseline timing**

Run: `cd /Users/invoker/Projects/tuvi/liquid_shell-vk990 && rtk make get && /usr/bin/time -p fvm dart test tool/test/ios_sim_test.dart --plain-name guard 2>&1 | tail -3`
Expected: `All tests passed!`. Record `real`.

- [ ] **Step 2: Change the deadline**

In `group('guard')`, the `drive` list:

```dart
    const drive = [
      'guard',
      udid,
      'a_test.dart on iPhone',
      '5',
      'flutter',
      'drive',
      '--target=a_test.dart',
    ];
```

Add one comment line above it:

```dart
    // 5 s, not 2: a loaded machine (pre-commit runs every package's tests at
    // once) can take over 2 s just to start a fake drive (VK-990).
```

- [ ] **Step 3: Run the file**

Run: `cd /Users/invoker/Projects/tuvi/liquid_shell-vk990 && /usr/bin/time -p fvm dart test tool/test/ios_sim_test.dart 2>&1 | tail -3`
Expected: `All tests passed!`. The guard group is about 15 s slower than Step 1.

- [ ] **Step 4: Under load, 5 times**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-vk990 && pids=""; for i in 1 2 3 4 5 6; do yes > /dev/null & pids="$pids $!"; done; \
  ok=0; for n in 1 2 3 4 5; do fvm dart test tool/test/ios_sim_test.dart --plain-name guard > /dev/null 2>&1 && ok=$((ok+1)); done; \
  kill $pids; echo "passed $ok of 5"
```

Expected: `passed 5 of 5`.

- [ ] **Step 5: Commit**

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-vk990 && ./.githooks/pre-commit; echo "hook=$?"
# only if hook=0:
rtk git add tool/test/ios_sim_test.dart docs/specs/2026-11-09-ios-sim-guard-deadline-design.md docs/plans/2026-11-09-ios-sim-guard-deadline.md
rtk git commit -m "test(tool): guard tests allow 5 s before a stall (VK-990)

A loaded machine can take over 2 s to start a fake drive, which the guard
then reports as a stall. 5 s keeps every stall test short and gives fast
drives room.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
