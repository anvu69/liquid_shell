# liquid_shell VK-990: the `guard` tool tests survive a loaded machine

- **Plane:** VK-990. Found during VK-949 (a pre-commit run failed once and the rerun passed).
- **Date:** 2026-11-09
- **Status:** approved: default "ok hết" and spec + plan "Duyệt" (2026-11-09).
- **Branch:** `VK-990-ios-sim-flaky`, from `main` f95d6d1.
- **Kind of change:** test-only (`tool/test/ios_sim_test.dart`). No change to `tool/ios_sim.sh` or `tool/with_timeout.sh`, no CHANGELOG.

> **Tóm tắt (cho chủ sản phẩm).** Test công cụ `guard` cho `flutter drive` giả 2 giây trước khi coi là treo. Máy bận thì lần chạy nhanh cũng quá 2 giây, nên bị tính là treo và test đỏ. Nâng hạn lên 5 giây cho cả nhóm `guard`. Bộ test chậm thêm khoảng 15 giây.

## 1. Cause

`group('guard')` passes one argument list, `drive`, to every test. Its stall deadline is `'2'`. `tool/with_timeout.sh` polls once a second and reports a stall (exit 124) once the deadline passes. The fake drives that should end at once (`vk627`, `fail`, the default pass, and `linger`) are bash scripts. On a loaded machine (pre-commit runs every package's tests in parallel), bash start-up plus the fake can take more than 2 s. The guard then sees a stall instead of the expected exit.

In the observed failure, "the VK-627 signature, then a stall: two drives, 124": attempt 1 was reported as a stall, and the assertion `contains('(attempt 1 of 2); building again once')` failed. The exit code was still 124, so the result looked like a plain assertion miss. Every test in the group that has a fast drive is exposed to the same race.

Evidence: `vankhan/.superpowers/sdd/flaky-ios-sim-test.md`. Alone, the test passes in 8 s. Under 6 CPU burners it passed 4 times, and the 5th run was stopped after 120 s, so the race was not reproduced on demand.

## 2. Design

Change the shared deadline in `drive` from `'2'` to `'5'`.

- Fast drives get 2.5 times the headroom.
- The stall drives (`stall`, `stall-once`, and the stall in `stall vk627` / `vk627 stall`) sleep 300 s in the fake. They still end at the deadline, now after 5 s instead of 2 s. That costs about 3 s per stall, and the group holds 5 stalls in total, so about 15 s.
- The linger test asserts `elapsed < 40 s`, and 5 s stays well inside that.
- The usage test (`['guard', udid, 'x', '5']`, exit 2) is a different argument list and is not affected.

### Alternative considered

Give the non-stall tests a roomy deadline such as 30 s, and keep a short one only where a stall must fire. That is more headroom where it is free. It also means two lists, and the tests that mix a fast drive with a stall (`vk627 stall`, `stall vk627`) keep the same short-deadline race. The single 5-s change is the approved default.

## 3. Verification

- `fvm dart test tool/test/ios_sim_test.dart`: all pass. Record the group's time before and after the change. Expect about +15 s.
- Run the guard group 5 times under 6 CPU burners. The burners are killed by their own PIDs, never with `pkill` by pattern. All 5 runs pass.
- `.githooks/pre-commit` exits 0.

No red-first test applies: this fixes a timing flake that cannot be reproduced on demand, and the change does not alter what any assertion checks. The PR states this.
