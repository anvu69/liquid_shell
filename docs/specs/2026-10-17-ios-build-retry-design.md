# liquid_shell VK-627: a CI build that Flutter left at iOS 13.0 runs once more

- **Plane:** VK-627
- **Date:** 2026-10-17
- **Status:** approved. The owner answered the decision table at the end (Q1–Q5) with "Ok hết" on 2026-10-17. Plan: `docs/plans/2026-10-17-ios-build-retry.md`. The choices this spec had to add are listed in "Quyết định phát sinh khi viết spec", after the table.
- **Branch:** `VK-627-ios-build-retry`, from `origin/main` at `83414fa`.
- **Kind of change:** CI tooling only:
  - `tool/ios_sim.sh` (the retry, the output copy, a `build` subcommand) and `tool/ios_xctest.sh` (builds through it); the header comments of `tool/integration_ios.sh` and `tool/integration_ios_native.sh`;
  - `tool/test/`: the fakes and the tool tests;
  - `docs/`: this spec, the plan, and `docs/qa/vk627/upstream-draft.md` (Q2).
  - No package code (Swift or Dart), no `Makefile`, no `.github/workflows/ci.yaml`, no `tool/with_timeout.sh`. No version bump and no CHANGELOG (Q4).
- **Sources:**
  - The VK-627 evidence report (phase 1 of systematic debugging, 2026-10-17, kept with the Plane item). It read the two red job logs, 8 green drive-led first builds, 32 config-only builds and 37 later iOS job logs. It reproduced the mechanism locally with an `xcrun` shim, without a simulator. Every CI number below comes from it.
  - flutter_tools 3.44.6 (`packages/flutter_tools/lib/src/`), read again while writing this spec; the file:line pointers below were checked against it. The evidence found that 3.44.9, CI's version, changes none of these files.
  - The code at `83414fa`: `tool/ios_sim.sh`, `tool/ios_xctest.sh`, `tool/integration_ios.sh`, `tool/integration_ios_native.sh`, `tool/with_timeout.sh`, `tool/test/`, `.github/workflows/ci.yaml`, `Makefile`.
  - **Prototype** (2026-10-17, while writing this spec). The plan's script and test code ran in a scratch copy of `tool/` against the fakes, never against a simulator or a real `flutter`:
    - every new test was red before the change and green after it;
    - the 57 tests of `ios_sim_test`, `ios_xctest_test`, `integration_ios_test` and `with_timeout_test` passed on bash 5.3, and the new ones on macOS's bash 3.2;
    - the lingering-output test was red against a copy that waits for its reader without a bound;
    - `dart format` changed nothing and `dart analyze --fatal-infos` (very_good_analysis 10.3.0) found nothing.
    
    The scratch copy was deleted; the plan carries the code.

> **Tóm tắt (cho chủ sản phẩm).**
> - **Vấn đề:** thỉnh thoảng (2 lần trong khoảng 40 lần chạy) một job iOS trên CI đỏ ở bước build, với dòng "Target Integrity (Xcode): The package product 'liquid-shell-ios' requires minimum platform version 15.0 … but this target supports 13.0". Lỗi không nằm ở gói của mình: app ví dụ, Podfile, podspec và `Package.swift` đều đã ở 15.0.
> - **Nguyên nhân:** mỗi lần build iOS, Flutter viết lại gói sinh tự động `FlutterGeneratedPluginSwiftPackage` ở mức 13.0, rồi chỉ nâng lên 15.0 của app nếu `xcodebuild -showBuildSettings` trả lời trong 60 s (có thử lại một lần). Quá giờ cả hai lần thì Flutter lặng lẽ bỏ qua bước nâng, và Xcode 26.6 từ chối build. Trên CI, lệnh đó chậm ngay sau khi simulator vừa boot.
> - **Cách sửa (Q1 = A):** script CI build lại **một lần** khi build đỏ đúng với dòng lỗi này, và in một dòng ghi chú có mã VK-627. Lỗi test không bao giờ được chạy lại. Không đổi code Swift hay Dart của gói.
>   - Áp dụng cho mọi chỗ CI build iOS: các lần `flutter drive` (qua stall guard), bản build của warm-up, và bản build của `ios-unit`, `ios-ui`, `ios-minimize`.
>   - Mỗi drive vẫn chạy **tối đa hai lần**, dù vì treo hay vì lỗi này, nên giới hạn thời gian của các job giữ nguyên.
> - **Kiểm chứng (Q3):** test của tool với `flutter` và `xcodebuild` giả: lỗi một lần thì build lại đúng một lần và xanh; lỗi cả hai lần thì đỏ sau hai lần; lỗi test thì không chạy lại. Không chạy đo trên CI, không kiểm tra trên máy thật (Q5).
> - **Báo cho Flutter (Q2):** bản nháp issue gửi flutter/flutter ở `docs/qa/vk627/upstream-draft.md`, ghi "Draft for the owner. Not posted."; chủ sản phẩm tự đăng.
> - **Cần chủ sản phẩm biết:**
>   - Đây là cách giảm thiểu, không xoá nguyên nhân. Khi gặp, job tốn thêm một lần build hỏng: khoảng 5–6 phút cho một drive, 2–4 phút cho build của warm-up hay của XCTest.
>   - Để bắt được dòng lỗi, script chép output của lệnh qua một FIFO. Output của drive nay ra chung một luồng. Log CI gần như không đổi; ở máy local, flutter không còn in màu hay spinner (mục phát sinh 4).

---

## 1. Goal

1. A CI iOS build that failed only because Flutter skipped its deployment-target raise (VK-627's signature) runs once more, and the job goes on instead of going red.
2. Nothing else is retried: a test failure, a build error with another message, and a second VK-627 failure stay red.
3. A stall's retry and this retry do not add up: a guarded drive still runs at most twice.
4. Every retry leaves a named line in the log (`VK-627: …`), an annotation on GitHub Actions, so it can be counted.
5. Flutter gets a ready draft of the upstream bug (Q2).

Success: the tool tests of §10, red before the change and green after it (Q3). No CI measurement (Q3).

## 2. Scope

### 2.1 In

- The retry in every CI path where a flutter iOS build regenerates the plugin manifest (§5).
- Detecting the signature in the run's own output, copied so that no lingering process can hold the script (§6).
- The bound shared with the stall guard (§7).
- One build helper for the warm-up and the XCTest targets (§8).
- Tool tests and fakes (§10).
- The upstream draft (§11, Q2).

### 2.2 Non-goals

- Any package change: no `.iOS("13.0")` in `liquid_shell_ios`'s `Package.swift`, no `@available` audit (the evidence's fix 3; Q1).
- Building first and driving a prebuilt app (`--use-application-binary`, the evidence's fix 1; not B).
- Closing the item without a fix (not C).
- `FLUTTER_SWIFT_PACKAGE_MANAGER=false` on the iOS jobs: CI would stop covering the SwiftPM path that consumers get by default (evidence §8).
- Making `-showBuildSettings` faster, or finding out why it was slow (evidence §7, hypothesis 1).
- Local tools that build iOS but never run on CI (§5.2).
- CI measurement runs; simulator or device checks (Q3, Q5).
- A CHANGELOG entry or a version bump (Q4).

## 3. What the evidence shows

### 3.1 The target that "supports 13.0"

- It is Flutter's generated `FlutterGeneratedPluginSwiftPackage`, at `liquid_shell/example/ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift`, which depends on `liquid-shell-ios`.
  - The example app, its test targets, the Podfile, the podspec and `liquid_shell_ios`'s `Package.swift` are all at 15.0 (evidence §2).
- flutter_tools writes that manifest at its iOS floor, `.iOS("13.0")` (`darwin/darwin.dart:79`; `macos/swift_package_manager.dart:118, 124`), on every `flutter build ios` and `flutter drive`.
- It then raises it to the app's `IPHONEOS_DEPLOYMENT_TARGET` (`ios/mac.dart:352-360`, which calls `SwiftPackageManager.updateMinimumDeployment`, `swift_package_manager.dart:431-457`). It does so only when it has read the build settings.
- It reads them with `xcodebuild … -showBuildSettings` (`ios/xcodeproj.dart:234-303`):
  - a timeout of 1 minute (`:237`) and one retry (`:280`);
  - any failure is logged with `printTrace` only (`:299`), and an empty map is returned (`:300`).
- `buildXcodeProject` turns that into `{}` (`mac.dart:288-294`). The raise is then skipped without a word, and the exit code stays 0 until Xcode fails.
- Xcode 26.6 (CI's) then fails its Target Integrity check. Xcode 27.1 built the same 13.0 manifest without a diagnostic in the local reproduction (evidence §5, step 4), so developers on Xcode 27 do not see this failure.

### 3.2 When it happens

- Two red jobs in about 40 runs. Both were a drive-led first build right after `simctl boot`, both on an iPad with iOS 26. With two cases, the iPad is not significant (evidence §7).
- For a drive, the call that feeds the raise runs with `-destination id=<udid>` (`xcodeproj.dart:266`, `simulators.dart:547-552`). For `flutter build ios --simulator` it runs with the generic simulator destination.
- The window that holds this call:

  | Builds | Window | Outcome |
  |---|---|---|
  | 2 drive-led first builds (the reds) | 143.6 s, 147.6 s: two 60 s timeouts | 13.0, Target Integrity |
  | 8 drive-led first builds | 9.9–79.7 s | built |
  | 32 `flutter build ios --config-only` builds (generic destination) | 2.8–9.4 s | built |

- 79.7 s (job 115967060120) fits one timeout followed by a successful retry: a near miss that built.
- No recurrence in 37 iOS job logs downloaded after the two reds.
  - VK-625's warm-up (merged as `3508f1f`) now builds config-only first, and the later drives run against a booted, warmed simulator: their overheads were 10.9–67.5 s in 19 drive builds.
  - The risk remains, in principle, on every path that rebuilds (§5).
- **Local reproduction:** a shim that made only that call sleep 70 s gave two tries 61 s apart, exit code 0, no message, and `.iOS("13.0")` left in the manifest.

### 3.3 What the code at `83414fa` adds to the evidence

1. **Where the signature is printed.**
   - `flutter drive` prints flutter's own rendering of the Xcode issue, then flutter's hint, then exits 1 ("Application failed to start"). From both red logs:
     ```
     Target Integrity (Xcode): The package product 'liquid-shell-ios' requires minimum platform version 15.0 for the iOS platform, but this target supports 13.0
     To fix this error, increase your app's minimum platform version from 13.0 to at least 15.0 or remove the liquid-shell-ios dependency.
     ```
   - `xcodebuild` prints the error on its stdout. flutter_tools' own parser reads it there (`mac.dart:1123-1124, 1319-1330`), and it needs the target name, so the sentence there is `The package product '<p>' requires minimum platform version <v> for the iOS platform, but this target supports <w> (in target 'FlutterGeneratedPluginSwiftPackage' from project '…')`. The hint in the red logs shows that the parser matched.
   - Both contain the phrase `requires minimum platform version`.
2. **`flutter build ios --config-only` runs the raise too.** It returns after the raise and `pod install` (`mac.dart:352-365`), without an Xcode build.
   - So a config-only build that hit the double timeout exits 0 and leaves 13.0.
   - The signature then comes from the **next** step, `xcodebuild build` or `build-for-testing`.
   - Running that step again alone would fail the same way: the unit to retry is the pair (§8).
3. **A failed warm-up build costs more than the warm-up.** `warmup --build` turns a failed build into `warm-up skipped: the build failed` and goes on (`ios_sim.sh:158, 165-167`).
   - The first drive then gets the first launch after the boot (VK-625: 30 stalls in 127).
   - It also builds with `-destination id=<udid>` right after the boot: the very trigger of §3.2.
   
   So the warm-up build is worth a retry too.
4. **Processes outlive the iOS jobs.** Each red log ends with the runner's "Terminate orphan process" for `adb` and two `ibtoold` (Xcode's Interface Builder daemon); another job's log ends with `DTServiceHub`.
   - A process that outlives the build and still holds its output would hold any `cmd | tee` pipeline until it exits.
   - The output copy is built around that (§6.2).
5. **The guard already runs every CI drive.** `integration_ios.sh` and `integration_ios_native.sh` drive through `ios_sim.sh guard`, and so does the compare step of `integration-ios-native` in `ci.yaml` ("Native vs Flutter liquid …"). One change in `guard` covers all three.

## 4. Design overview

- `tool/ios_sim.sh` gains:
  - `logged`: runs a command with its output shown and copied to a file, through a FIFO, with a bounded drain (§6.2);
  - `build_again`: decides whether a finished run is VK-627's build failure that gets its one more run, and prints the note (§6.1, §9);
  - in `guard`: each attempt runs through `logged`. A run that ended neither with 0 nor with 124, and printed the signature, gets the second attempt, which a stall would otherwise have used (§7);
  - a subcommand `build UDID ACTION [xcodebuild args…]`: `flutter build ios --config-only`, then `xcodebuild ACTION`, each capped, with the same retry around the pair (§8). `warmup --build` uses it.
- `tool/ios_xctest.sh` builds through `ios_sim.sh build … build-for-testing` instead of its own two lines (§8).
- `tool/with_timeout.sh`, the `Makefile` and `ci.yaml` do not change.

## 5. The CI paths

### 5.1 Covered

| Path | CI jobs | What regenerates the manifest | Unit retried | Through |
|---|---|---|---|---|
| each `flutter drive` of `tool/integration_ios.sh` | `integration-ios` | the drive's own build (`-destination id=<udid>`) | the drive | `ios_sim.sh guard` |
| each `flutter drive` of `tool/integration_ios_native.sh` | `integration-ios-native` (iPad and iPhone, on iOS 26 and iOS 27) | the drive's own build | the drive | `ios_sim.sh guard` |
| the `liquid_compare_test.dart` drive in `ci.yaml` | `integration-ios-native` | the drive's own build | the drive | `ios_sim.sh guard` (no `ci.yaml` change) |
| `ios_sim.sh warmup UDID --build` (`build_app`), before the first drive | `integration-ios`, `integration-ios-native` | `flutter build ios --config-only` | config-only, then `xcodebuild build` | `ios_sim.sh build` |
| step 1 of `tool/ios_xctest.sh` | `ios-unit` (iPad, iPhone), `ios-ui` (iPad, iPhone), `ios-minimize (iPhone)` | `flutter build ios --config-only` | config-only, then `xcodebuild build-for-testing` | `ios_sim.sh build` |

### 5.2 Not covered, and why

| Path | Why |
|---|---|
| `xcodebuild test-without-building` in `ios_xctest.sh` | It builds nothing. The manifest is not regenerated, and the products come from the build above |
| `ios_sim.sh warmup UDID APP` (the XCTest warm-up) | It installs and launches a built app; no build |
| `integration-android` (`tool/integration_android.sh` and its compare drive) | Android |
| `checks`, `pana`, `android-unit`, `goldens` (`make test`, `make goldens`, `tool/update_goldens.sh`) | No iOS build (`flutter test`, Gradle) |
| `tool/compare_ios.sh`, `tool/tab_frames.sh`, `tool/segment_frames.sh` (with `frames_lib.sh`) | Local measurement tools, behind `make` targets that `ci.yaml` never runs. Local Xcode 27 builds a 13.0 manifest without the error (§3.1); a developer who meets a red build there runs it again |

## 6. Detection

### 6.1 The rule

A finished run gets one more run when **all** of these hold:
1. its status is neither 0 nor 124. 124 is a stall, which the guard handles as today; a build step stopped by its cap (`cap`) is 124 too and is not retried;
2. its own output, stdout and stderr, contains the fixed string `requires minimum platform version`;
3. it was the first run of that unit (§7, §8).

- **Why a test failure is never retried.** A drive prints the phrase only when its build failed Target Integrity: Xcode 26 reports it as an error, and flutter_tools prints its hint only for a failed build (`mac.dart:596, 1146-1147`). Then no test ran. A test failure's output has no such line, so rule 2 fails.
- **Why the phrase and not a whole line.** It is the part common to flutter's rendering and to xcodebuild's (§3.3, item 1), and the words flutter_tools' own parser keys on. It is matched as a fixed string (`grep -F`).
- **Not narrowed to "supports 13.0".** That would tie the rule to Flutter's current floor (`darwin.dart:79`). A permanent mismatch, such as a plugin that needs more than the app's target, prints the same phrase: it fails twice and stays red, at the cost of one extra attempt (§12).
- **No manifest check.** A check of the generated manifest (`grep -q '.iOS("15.0")' …/FlutterGeneratedPluginSwiftPackage/Package.swift`) is used nowhere:
  - the signature already covers every path of §5.1, config-only included: its 13.0 shows up in the next step's output;
  - the manifest's path is flutter_tools' internal layout, and 13.0 there is harmless on Xcode 27. A retry keyed on it would fire for builds that did not fail with Q1's signature, which is outside Q1 = A;
  - a failed pair costs little: the red builds failed 33–47 s into their Xcode build.

### 6.2 The output copy: `logged`

```
logged <log> command [args…]
```

- It empties `<log>`, makes the FIFO `<log>.fifo`, and starts `tee -a <log> < <log>.fifo` in the background.
- It runs the command with stdout and stderr both into the FIFO (`> fifo 2>&1`). The copy shows them on `logged`'s stdout, in order, as they come, so the CI log stays live.
- It returns the command's status.
- **Bounded drain.** Once the command has ended, the copy gets `copy_drain` = 10 s to read to the end and exit; normally it is done at the first look, within 1 s. Then it is stopped and the FIFO removed.
- **Why not `cmd 2>&1 | tee log`.** bash waits for every member of a pipeline, and `tee` waits until every writer has closed the pipe. An orphan that inherited the output (§3.3, item 4) would hold the script until the job cap.
  - With the FIFO, the script waits for the command only.
  - A process that still holds the FIFO after 10 s loses its reader (its next write gets SIGPIPE) instead of holding the job.
- **Why not process substitution (`> >(tee …)`).** The script cannot wait for that reader, so the last lines could still be in flight when the log is read: a race, and a flaky test.
- **If `mkfifo` fails,** the command runs without a copy. Its log is then empty, so it is never retried: a tooling problem never turns into a red job.
- **Streams.** `guard` shows the command's stdout and stderr on its own stdout. `build` shows them on stderr, because its stdout is the app's path for `warmup --build`. On CI both land in the same log. Locally, flutter sees a FIFO instead of a terminal, so it prints no colours and no spinner.
- `tool/with_timeout.sh` is unchanged. The copy wraps it (`guard`) or the build steps (`build`), so its process group, its signal handling and its stall hook work as before. Its `✗ stalled` line and the dump's `ios_sim: diagnostics in …` now go through the copy.

## 7. `guard`: one retry in all

For attempt 1 and attempt 2:
1. Run `env WITH_TIMEOUT_ON_STALL=<diagnose …> tool/with_timeout.sh SECONDS command…` through `logged`. The stall hook is today's.
2. On 124: the stall path, as today (the `stall guard fired` line, then `simctl terminate`), then the next attempt.
3. On any other status: `build_again`.
   - If attempt 1 was VK-627's failure, print the note and run attempt 2. There is no app to terminate: the build failed before any launch.
   - Otherwise return the status.

After attempt 2, return its status.

| Attempt 1 | Attempt 2 | Runs | Result |
|---|---|---|---|
| passes | — | 1 | 0 |
| a test failure, or another build error | — | 1 | its status (never retried) |
| VK-627 | passes | 2 | 0 |
| VK-627 | VK-627 | 2 | 1, with VK-627's "(attempt 2 of 2); giving up" |
| VK-627 | stalls | 2 | 124, with "stall guard fired: … (attempt 2 of 2); giving up" |
| stalls | VK-627 | 2 | 1, with VK-627's "(attempt 2 of 2); giving up" |
| stalls | stalls | 2 | 124 (as today) |

**Bound:** a guarded drive runs at most twice, whatever the reason.
- The job caps in `ci.yaml` were set as two drive caps per drive plus setup (VK-625 §9), so they still hold, and they do not change.
- A VK-627 attempt ends long before its cap: the two red drives failed 5–6 minutes after they started.

## 8. `build`: the warm-up and the XCTest builds

```
tool/ios_sim.sh build UDID ACTION [xcodebuild args…]
```

- **One run** (`build_once`):
  1. in `liquid_shell/example`: `cap IOS_BUILD_TIMEOUT ${FLUTTER:-flutter} build ios --config-only --simulator --debug`;
  2. in `ios/`: `cap IOS_BUILD_TIMEOUT xcodebuild ACTION -workspace Runner.xcworkspace -scheme Runner -destination id=UDID -derivedDataPath liquid_shell/example/build/ios-derived [args…] -quiet`.
  
  These are today's two steps of `build_app` and of `ios_xctest.sh`, now in one place.
- The pair runs through `logged`, with its output on stderr. A run that was VK-627's failure (§6.1) runs once more, both steps: config-only rewrites the manifest and tries the raise again. At most two runs; the last status is returned.
- The label in the notes is `<ACTION> on <UDID>`.
- **`warmup --build`:** `build_app` becomes `build UDID build -configuration Debug`, then prints the app's path as today. A second VK-627 failure still ends in `warm-up skipped: the build failed` and exit 0: VK-625's rule that the warm-up never fails holds.
- **`tool/ios_xctest.sh`:** step 1 becomes `"$tool_dir/ios_sim.sh" build "$udid" build-for-testing "$@"`.
  - Under `set -e`, a failed build still stops the script with xcodebuild's status, before the warm-up.
  - `rm -rf "$result"` stays before the build, in `liquid_shell/example`.
  - `IOS_BUILD_TIMEOUT` and `FLUTTER` reach `ios_sim.sh` through the environment; the `Makefile` passes both to `ios_xctest.sh`.
- **Bound:** two runs of the pair at most, each step capped at `IOS_BUILD_TIMEOUT` as today.
  - A retry follows only a run that ended in a build error: about 2–4 minutes when the config-only call timed out twice (2 × 60 s, plus an Xcode build that fails within 33–47 s).
  - The job caps keep 30 minutes for setup, build and warm-up on top of the suite cap, so they absorb one such attempt. They do not change.

## 9. Pinned names

| What | Name |
|---|---|
| Subcommand | `tool/ios_sim.sh build UDID ACTION [xcodebuild args...]` |
| Functions (`tool/ios_sim.sh`) | `logged <log> command…`, `build_again <label> <attempt> <status> <log>`, `build_once <udid> <action> [args…]`, `build <udid> <action> [args…]` |
| Variables (`tool/ios_sim.sh`) | `vk627_signature='requires minimum platform version'`, `vk627_note='VK-627: Flutter skipped the deployment-target raise (xcodebuild -showBuildSettings timed out)'`, `copy_drain=10`, `derived="$example/build/ios-derived"` |
| Environment variables | none new |
| Fakes (`tool/test/fake_sim.dart`) | `FAKE_DRIVES`, `FAKE_BUILDS` (space-separated outcomes, one per call: `pass`, `fail`, `vk627`, and `stall` for drives); `FAKE_DRIVE=linger`; `FakeSim.indicesOf(part)` |

**Log lines** (after the `ios_sim: ` prefix). They go through `warn`, like the stall lines: stderr locally, a `::warning::` on stdout on GitHub Actions.

| Line | When |
|---|---|
| `VK-627: Flutter skipped the deployment-target raise (xcodebuild -showBuildSettings timed out): <label> (attempt 1 of 2); building again once` | attempt 1 was VK-627's failure |
| `VK-627: Flutter skipped the deployment-target raise (xcodebuild -showBuildSettings timed out): <label> (attempt 2 of 2); giving up` | attempt 2 was VK-627's failure |

- `<label>` is the guard's label (`signals_test.dart on <device>`, `<target> on <run>`, `liquid_compare_test.dart on <iPad or iPhone>`), or `<action> on <udid>` for `build`.
- The stall lines of VK-625 §5.6 are unchanged.
- "timed out" is the evidence's reading. Two 60 s tries fit the 143.6 s and 147.6 s windows. A non-zero exit of `-showBuildSettings` would skip the raise the same way, but it is not retried and leaves no such window (evidence §7, item 3). The line keeps the owner's wording.

## 10. Testing (Q3)

**Fakes** (`tool/test/fake_sim.dart`):
- `FAKE_DRIVES`: the outcomes of the 1st, 2nd, … `flutter drive`. A counter file in the fake directory numbers the calls. Drives past the list pass.
  - `vk627` prints `Failed to build iOS app` (stdout), then the `Target Integrity (Xcode): … supports 13.0` line and `Application failed to start…` (stderr), and exits 1.
- `FAKE_BUILDS`: the outcomes of the 1st, 2nd, … `xcodebuild build` or `build-for-testing`. `vk627` prints xcodebuild's error line and exits 65.
- `FAKE_DRIVE=linger`: the drive passes and leaves a `sleep 60` that holds its output (its pid in `lingerer`).
- `FakeSim.indicesOf(part)`: the index of every call that contains `part`.
- `FAKE_DRIVE` and `FAKE_BUILD` keep their meaning; the new lists override them.

**Where the tests run:** `dart test tool/test`, which is part of `make test`, so in the pre-commit hook and in CI's `checks` job on Ubuntu. They need bash, `mkfifo`, `tee` and `awk`, which both systems have.

| Test file | New or changed tests | Red before the change |
|---|---|---|
| `ios_sim_test.dart`, `guard` | VK-627 once: 2 drives, exit 0, the note, the drive's own output still in the log, no `simctl terminate`, no dump. VK-627 twice: 2 drives, exit 1, "giving up". A stall, then VK-627: 2 drives, exit 1. VK-627, then a stall: 2 drives, 124. A process that holds the output: the guard is back within 40 s | exit 1 after one drive, no note; the lingering test takes 60 s (the orphan holds the guard's own output) |
| `ios_sim_test.dart`, `warmup --build` | VK-627 once: 2 config-only builds, 2 `xcodebuild build`, the second config-only after the first `xcodebuild build`, one launch, no "skipped". VK-627 twice: "giving up" and `warm-up skipped: the build failed`, exit 0. The existing failed-build test now also asserts one `xcodebuild build` | one build, then "warm-up skipped" |
| `ios_sim_test.dart`, usage | `build UDID` alone exits 2 | already green: an unknown subcommand prints usage too |
| `ios_xctest_test.dart` | VK-627 once: 2 config-only builds, 2 `build-for-testing`, then the suite, exit 0. VK-627 twice: exit 65, no `simctl`. The existing failed-build test now also asserts one `build-for-testing` | exit 65 after one build |
| `integration_ios_test.dart` | each script: VK-627 on the first drive makes that drive run twice and the next one once, exit 0 | exit 1 |

- **Unchanged, and still green:** every existing test. Among them, "a failing drive is never retried" (`FAKE_DRIVE=fail`: one drive, exit 1) is Q3's case "a test failure, no signature, no retry".
- **Mutation check of the bound** (in the plan, not committed): the lingering test is red when `logged` waits for its copy without a bound.
- **No simulator, no device, no CI run** (Q3, Q5).

## 11. The upstream draft (Q2)

- **Where:** `docs/qa/vk627/upstream-draft.md`. Its first line is `Draft for the owner. Not posted.`
- **Shape:** that of `docs/qa/vk625/upstream-draft.md`: a title, then Summary, Environment, Steps to reproduce, Expected, Actual, Where it happens, Suggested fix.
- **Title:** `[flutter_tools] iOS: a timed-out xcodebuild -showBuildSettings silently skips the SwiftPM deployment-target raise, and Xcode 26 fails Target Integrity`.
- **Content:**
  - the mechanism (§3.1), with flutter_tools 3.44.6 file:line pointers, to be checked against the then-current stable before posting;
  - the deterministic reproduction from the evidence: an `xcrun` shim that makes only the Runner `-showBuildSettings` call sleep 70 s gives exit 0, no message, and `.iOS("13.0")`; `xcodebuild build` then fails on Xcode 26.x and builds on Xcode 27.1;
  - one CI excerpt, and the window numbers of §3.2.
- **Suggested fixes:**
  1. say it: a warning instead of a trace when the build settings cannot be read and the raise is skipped, or a failed build with that message when SwiftPM is on;
  2. fall back, for `IPHONEOS_DEPLOYMENT_TARGET`, to the generic destination or to the project file when the destination-specific call fails;
  3. write the generated package with the app's target in one step when it is known, instead of writing the floor first.
- Nothing is posted, and no upstream issue gets a comment (Q2: the owner posts it).
- No other note in `docs/qa/vk627/`: the evidence stays with the Plane item, and this spec records what it found.

## 12. Risks

| Risk | Handling |
|---|---|
| The retry hides the flake instead of removing it | Q1 = A, by choice. Each retry leaves a `::warning::` naming VK-627, so a count is one log search away; the upstream draft goes after the cause |
| A real configuration regression (the app or a plugin really below a package's minimum) | It fails both runs and stays red, with "giving up" after flutter's own hint. The cost is one extra attempt |
| The second run meets the same slow `-showBuildSettings` | Then it is red, as today, with the note. After the first attempt the SwiftPM migration and the package resolution are done, and later drive builds took 10.9–67.5 s (§3.2) |
| Extra time when it happens | About 5–6 minutes for a drive, 2–4 minutes for a build pair. The job caps are unchanged and hold (§7, §8) |
| A process that still holds the copy after 10 s loses its reader (SIGPIPE on its next write) | It would have outlived the command anyway, and the runner terminates such orphans at the end of the job. Before, its writes went to the job log |
| The copy merges stdout and stderr, and locally flutter loses its terminal (no colours, no spinner) | A CI log is one stream already. No test and no consumer reads the drive's stderr on its own |
| An Xcode that reported the mismatch as a warning would print the phrase in a build that passed; a test failure after it would then be retried once | Not seen: Xcode 26.6 fails the build, and Xcode 27.1 prints nothing (evidence §5). Still at most one retry |
| Flutter or Xcode changes the wording | The rule then never fires: red as today, never a wrong retry. The tool tests pin the phrase |
| `mkfifo` is unavailable | The command runs without a copy and is never retried (§6.2) |

## 13. Process

- **Commits:** `<type>(<scope>): <summary> (VK-627)`: `ci(ci)` for the tooling, as VK-625's tool commits; `docs(docs)` for the docs. Each message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Run `.githooks/pre-commit` by hand before each commit. Never `--no-verify`, never a git config change.
- No CHANGELOG, no version bump (Q4).
- **Publishing:** after the plan's tasks, the controller pushes the branch and opens a PR. The owner merges it when CI is green (Q4).
- **Simulators and devices:** none (Q3, Q5). A task that would need a simulator creates and deletes its own; never a physical device, never `simctl shutdown all`.

## Quyết định cần chủ sản phẩm xác nhận

Chủ sản phẩm đã trả lời "Ok hết" ngày 2026-10-17, nên mọi mục dưới đây đã được chốt.

| Q# | Câu hỏi | Đã chốt |
|---|---|---|
| Q1 | Sửa thế nào? | **A:** script CI build lại một lần khi build đỏ đúng với dấu hiệu này (dòng Target Integrity `requires minimum platform version`), và in một dòng ghi chú rõ ràng có mã VK-627 (ví dụ "VK-627: Flutter skipped the deployment-target raise (xcodebuild -showBuildSettings timed out); building again once"). Lỗi test không bao giờ được chạy lại (giữ luật của `tool/ios_sim.sh guard`). Không đổi code gói (Swift, Dart). Không chọn B (build trước rồi drive app đã build sẵn), không chọn C (đóng việc) |
| Q2 | Báo lỗi cho Flutter? | Soạn bản nháp bug report gửi Flutter ở `docs/qa/vk627/upstream-draft.md`: flutter_tools trả về build settings rỗng mà không báo gì sau hai lần `-showBuildSettings` quá giờ, nên bước nâng deployment target của gói SwiftPM bị bỏ qua. Ghi "Draft for the owner. Not posted."; chủ sản phẩm tự đăng. Theo khuôn của `docs/qa/vk625/upstream-draft.md` |
| Q3 | Kiểm chứng thế nào? | Test của tool với `flutter` giả (theo `tool/test/fake_sim.dart` và các test hiện có): lần gọi đầu in dòng Target Integrity và thoát 1, lần thứ hai thoát 0, thì script chạy lại đúng một lần và xanh; cả hai lần đều có dấu hiệu thì đỏ sau hai lần; lỗi test (không có dấu hiệu) thì không chạy lại. Không chạy đo trên CI |
| Q4 | Phạm vi, CHANGELOG, phát hành? | Một spec, một plan, trên nhánh này. Không CHANGELOG (chỉ đổi CI, các gói không đổi). Xong thì push, mở PR, merge khi CI xanh (chủ sản phẩm bấm merge) |
| Q5 | Kiểm tra trên máy thật? | Không |

### Quyết định phát sinh khi viết spec

Bảng Q1–Q5 không nói tới những điểm dưới đây. Spec chọn như sau, chủ sản phẩm có thể đổi:

1. **Những đường CI được build lại (§5.1):**
   - mọi lần `flutter drive` qua `tool/ios_sim.sh guard`: `integration-ios`, `integration-ios-native`, và bước so sánh native với Flutter liquid trong `ci.yaml` (bước này đã đi qua guard, nên `ci.yaml` không phải sửa);
   - bản build của warm-up (`warmup --build`);
   - bản build của `tool/ios_xctest.sh` (`ios-unit`, `ios-ui`, `ios-minimize`).
   
   **Không áp dụng (§5.2):** `test-without-building` và warm-up với app có sẵn (không build gì), job Android, các job không build iOS, và các tool đo chỉ chạy ở máy local (`compare_ios.sh`, `tab_frames.sh`, `segment_frames.sh`): CI không chạy chúng, và Xcode 27 ở máy local không báo lỗi này.
2. **Build của warm-up và của XCTest chạy lại cả hai bước** (`--config-only` rồi `xcodebuild`). `--config-only` là bước để lại 13.0 mà không báo gì; lỗi chỉ hiện ở bước `xcodebuild` sau đó. Chạy lại riêng `xcodebuild` sẽ đỏ y như cũ (§3.3, mục 2).
3. **Gộp thành lệnh con `tool/ios_sim.sh build`,** dùng chung cho warm-up và `ios_xctest.sh`, thay cho hai bản sao của cặp lệnh build. Nhờ vậy cách build lại chỉ viết một lần.
4. **Nhận dấu hiệu bằng cách chép output qua FIFO** (`logged`), không dùng `| tee`.
   - Lý do: runner còn sót tiến trình mồ côi (`adb`, `ibtoold`, `DTServiceHub`). Một tiến trình như vậy mà giữ output thì `| tee` sẽ treo script tới hết giờ của job. Với FIFO, script chỉ chờ thêm tối đa 10 s rồi thôi (§6.2).
   - Hệ quả: stdout và stderr của drive ra chung một luồng; ở máy local, flutter không còn in màu hay spinner.
5. **Một lần chạy lại dùng chung cho cả treo lẫn VK-627:** mỗi drive chạy tối đa hai lần, vì lý do nào cũng vậy. Nhờ thế giới hạn thời gian của các job (tính theo hai lần drive) giữ nguyên, không phải sửa `ci.yaml` (§7). Ví dụ: lần đầu treo, lần hai đỏ vì VK-627, thì job đỏ, không có lần thứ ba.
6. **Không dùng phép kiểm tra manifest** (`grep '.iOS("15.0")' …/Package.swift`):
   - dấu hiệu trong output đã phủ mọi đường;
   - đường dẫn của manifest là chi tiết nội bộ của Flutter;
   - manifest ở 13.0 không gây lỗi trên Xcode 27, nên dựa vào nó sẽ chạy lại cả những lần build không đỏ vì dấu hiệu của Q1, tức là ra ngoài Q1 = A (§6.1).
7. **Dấu hiệu là cụm `requires minimum platform version`,** khớp nguyên văn (`grep -F`); cụm này có trong cả cách flutter in lẫn cách xcodebuild in. Không thu hẹp thành "supports 13.0", để không gắn với mức sàn hiện tại của Flutter. Một lỗi cấu hình thật in cùng cụm này thì đỏ sau hai lần, chỉ tốn thêm một lần build.
8. **Dòng ghi chú** theo mẫu dòng của stall guard: `ios_sim: VK-627: Flutter skipped the deployment-target raise (xcodebuild -showBuildSettings timed out): <nhãn> (attempt 1 of 2); building again once`, và `… (attempt 2 of 2); giving up` khi lần hai vẫn đỏ vì dấu hiệu. Trên GitHub Actions, hai dòng này là `::warning::`, để đếm được.
9. **Không thêm biến môi trường nào.** Thời gian chờ chép nốt output (10 s) là hằng số trong script.
10. **Không thêm ghi chú nào khác trong `docs/qa/vk627/`** ngoài bản nháp issue: bằng chứng đi kèm việc trên Plane, và spec này đã ghi lại những gì nó tìm ra.
