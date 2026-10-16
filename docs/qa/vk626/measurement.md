# VK-626, VK-633, VK-634: three CI runs on the iOS test fixes

- **Branch / head:** `VK-626-ios-test-flakes` @ `f0ed736722eec36a70e52325383d28c4473e16b3`
- **Runs:** three `workflow_dispatch` runs at that head:
  1. [38920880056](https://github.com/anvu69/liquid_shell/actions/runs/38920880056): failure (only `goldens (stable)`)
  2. [38920884892](https://github.com/anvu69/liquid_shell/actions/runs/38920884892): failure (`ios-unit (iPhone)`, `integration-ios-native (iPhone, iOS 26)`, `goldens (stable)`)
  3. [38920889553](https://github.com/anvu69/liquid_shell/actions/runs/38920889553): failure (only `goldens (stable)`)
- **Runner images seen:** macos-26-arm64 (versions 20261012.601 and 20261013.0424.1 on most jobs; 20260828.587 and 20260907.0351.1 on a few); Flutter 3.44.9 (stable); simulators iPhone 17 and iPad (A16) on iOS 26.5, iPhone 17 Pro on iOS 26.2. The `iOS 27` native jobs ran about 1 minute each and passed.
- **Verdict:** PASS (spec §9.2). Two blocking jobs went red in run 2, both in the "Other" category, so they do not count against the bar (see below).

> **Tóm tắt (cho chủ sản phẩm).**
> - Đạt: trong ba lần chạy, không job chặn nào đỏ vì 1A (VK-634), 1B (VK-626) hay VK-633. `ios-minimize (iPhone)` xanh cả ba lần.
> - Có hai job chặn đỏ ở lần chạy 2, cả hai thuộc loại "Other" (không tính vào điều kiện đạt): `ios-unit (iPhone)` đỏ ở `NativeTabsTests/testAPushedPagesBackButtonIsNative()` (`XCTAssertTrue failed`, không có chữ `no searchActive`), và `integration-ios-native (iPhone, iOS 26)` đỏ vì máy ảo không xoay sang ngang (`Failed to change device orientation ... timeout`). `goldens (stable)` đỏ cả ba lần, đã đỏ sẵn trên main, chỉ để tham khảo.
> - Segv: không có `crashed with signal` nào, không có `Runner-*.ips` nào.
> - Cỡ mẫu: ba lần chạy là ít; bằng chứng chính của 1A, 1B là các test tất định. Lưu ý: test `testAPushedPagesBackButtonIsNative` là test mà VK-634 đã sửa cách chờ (commit 11ffeec) nên đáng được chủ sản phẩm xem lại; theo bảng loại của spec §9.3 nó là "Other".

## Bar (spec §9.2)

| Criterion | Result |
|---|---|
| Blocking jobs red from 1A (VK-634) | 0 (must be 0) |
| Blocking jobs red from 1B (VK-626) | 0 (must be 0) |
| Blocking jobs red from VK-633 | 0 (must be 0) |

## Every iOS job

| Run | Job (id) | Conclusion | Duration | Failing tests | Category |
|---|---|---|---|---|---|
| 1 | integration-ios (117040174961) | success | 10 min | - | - |
| 1 | integration-ios-native (iPad, iOS 26) (117040175280) | success | 27 min | - | - |
| 1 | integration-ios-native (iPad, iOS 27) (117040175292) | success | 1 min | - | - |
| 1 | integration-ios-native (iPhone, iOS 26) (117040175289) | success | 24 min | - | - |
| 1 | integration-ios-native (iPhone, iOS 27) (117040175265) | success | 1 min | - | - |
| 1 | ios-minimize (iPhone) (117040175200) | success | 13 min | - | - |
| 1 | ios-ui (iPad) (117040175398) | success | 17 min | - | - |
| 1 | ios-ui (iPhone) (117040175225) | success | 23 min | - | - |
| 1 | ios-unit (iPad) (117040175066) | success | 12 min | - | - |
| 1 | ios-unit (iPhone) (117040175197) | success | 12 min | - | - |
| 2 | integration-ios (117040189205) | success | 11 min | - | - |
| 2 | integration-ios-native (iPad, iOS 26) (117040189553) | success | 41 min | - | - |
| 2 | integration-ios-native (iPad, iOS 27) (117040189454) | success | 1 min | - | - |
| 2 | integration-ios-native (iPhone, iOS 26) (117040189400) | failure | 17 min | `native_search_test.dart:311` `Expected: Orientation.landscape, Actual: portrait` | Other |
| 2 | integration-ios-native (iPhone, iOS 27) (117040189562) | success | 1 min | - | - |
| 2 | ios-minimize (iPhone) (117040189718) | success | 17 min | - | - |
| 2 | ios-ui (iPad) (117040189291) | success | 18 min | - | - |
| 2 | ios-ui (iPhone) (117040189501) | success | 19 min | - | - |
| 2 | ios-unit (iPad) (117040189178) | success | 11 min | - | - |
| 2 | ios-unit (iPhone) (117040188912) | failure | 13 min | `NativeTabsTests/testAPushedPagesBackButtonIsNative()`: `XCTAssertTrue failed` | Other |
| 3 | integration-ios (117040205146) | success | 8 min | - | - |
| 3 | integration-ios-native (iPad, iOS 26) (117040205066) | success | 27 min | - | - |
| 3 | integration-ios-native (iPad, iOS 27) (117040262368) | success | 1 min | - | - |
| 3 | integration-ios-native (iPhone, iOS 26) (117040205004) | success | 40 min | - | - |
| 3 | integration-ios-native (iPhone, iOS 27) (117040205201) | success | 1 min | - | - |
| 3 | ios-minimize (iPhone) (117040205131) | success | 11 min | - | - |
| 3 | ios-ui (iPad) (117040205139) | success | 12 min | - | - |
| 3 | ios-ui (iPhone) (117040266731) | success | 18 min | - | - |
| 3 | ios-unit (iPad) (117040205259) | success | 12 min | - | - |
| 3 | ios-unit (iPhone) (117040205012) | success | 13 min | - | - |

## Other red jobs

- **Run 2, `ios-unit (iPhone)` (117040188912), blocking, Other:** 1 failed of 187 tests (168 passed, 18 skipped). `NativeTabsTests/testAPushedPagesBackButtonIsNative()`, `"failureText" : "XCTAssertTrue failed"`. It is a hit test of the pushed page's back button (`RunnerTests.swift:2849`); the text does not start `failed - no searchActive`, and the test is not one of the five 1A tests, so by §9.3 it is Other. Its `ios-unit (iPad)` sibling and the same job in runs 1 and 3 were green.
- **Run 2, `integration-ios-native (iPhone, iOS 26)` (117040189400), blocking, Other:** `Failed to change device orientation: Error Domain=BSActionErrorDomain Code=2 "(null)" UserInfo={BSErrorCodeDescription=timeout}`, then `Expected: Orientation:<Orientation.landscape> Actual: Orientation:<Orientation.portrait>` at `integration_test/native_search_test.dart:311` (test "VK-550: the native scope bar, over the results, follows the app"); `Some tests failed.` A simulator rotation timeout, not a 1A, 1B or VK-633 failure.
- **`goldens (stable)` in runs 1, 2 and 3 (117040175249, 117040189556, 117040205044):** informational, already red on main. Not counted.
- No `ios-ui` job was red, so no 1A, 1B or VK-633 failure in an `ios-ui` job.

## The segv (Q4)

No `crashed with signal` in these runs (0 in all 30 iOS job logs), and no `Runner-*.ips` in the one diagnostics artifact.

## Slow reports and refusals (red `ios-unit` bundles only)

Run 2, `ios-unit-iPhone-diagnostics` (the only red `ios-unit` job):
- `NativeTabsTests: searchActive true took 3.5 s`: 3 lines (reports slower than 3 s came, and the 10 s wait took them);
- "not in the window hierarchy" refusals: 3.

Runs 1 and 3 had no red `ios-unit` job (green runs upload no bundle).

## Against VK-625's six runs

| Measure | VK-626 (3 runs) | VK-625 (6 runs) |
|---|---|---|
| `ios-unit` jobs red | 1 / 6 (not 1A, 1B or the segv) | 3 / 12 (all VK-626) |
| `ios-minimize (iPhone)` red | 0 / 3 | 1 / 6 (VK-633) |

With VK-625's rates, three clean runs would still come about one time in ten (0.75⁶ × (5/6)³ ≈ 0.10): a PASS here is weak evidence on its own. The deterministic tests of Tasks 1 and 2 carry 1A and 1B.
