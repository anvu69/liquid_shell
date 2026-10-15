# liquid_shell VK-625: the first launch after a simulator boot stops stalling CI

- **Plane:** VK-625
- **Date:** 2026-10-16
- **Status:** approved. The owner answered the decision table at the end (Q1–Q9) with "Ok hết" on 2026-10-16. Plan: `docs/plans/2026-10-16-ci-cold-launch.md`. The choices this spec had to add are listed in "Quyết định phát sinh khi viết spec", after the table.
- **Branch:** `VK-625-ci-cold-launch`, from `main` at `5c57a02`.
- **Kind of change:** CI and test tooling only: `tool/`, `tool/test/`, `Makefile`, `.github/workflows/ci.yaml`, one command row in `CONTRIBUTING.md`, and `docs/`. No package code changes, so there is no version bump and no package CHANGELOG entry (Q9).
- **Sources:**
  - The VK-625 evidence report (phase 1 of systematic debugging, 2026-10-16, kept with the Plane item). It covers the last 40 CI runs of `anvu69/liquid_shell` (38074428306 to 38765508425), the logs of every iOS job, and one xcresult bundle. Every CI number below comes from it.
  - flutter_tools 3.44.6, `lib/src/ios/simulators.dart`: the launch, then the wait for the VM service URL. Also the engine's `FlutterDartProject.mm` and `Logger.swift`: Dart's output reaches the unified log through `syslog`.
  - The code at `5c57a02`: `.github/workflows/ci.yaml`, `Makefile`, `tool/integration_ios.sh`, `tool/integration_ios_native.sh`, `tool/with_timeout.sh`, `tool/test/`.
  - VK-600's final review, item M7: "consider a blocking job that runs only the iPhone `MinimizeUITests`".
  - **Probe** (2026-10-16, while writing this spec). It ran on this machine with Xcode 27.0, on our own iPhone 17 simulator (iOS 26.5), deleted afterwards. Prototypes of the scripts in §5–§7 ran against the real simulator. The prototypes were deleted; the plan carries their code. The probe found:
    - the warm-up reached the VM service line 6 s after the first launch after a boot;
    - the real formats of `launchctl list` and `log show --style compact`;
    - `sample` worked on the live app;
    - `MinimizeUITests` ran through build-for-testing → warm-up → test-without-building in 165 s (6 passed, 2 skipped);
    - the stall guard worked against a command that hangs with the app alive.

> **Tóm tắt (cho chủ sản phẩm).**
> - **Vấn đề:** các job iOS trên CI đỏ ngẫu nhiên. Nguyên nhân là **lần mở app đầu tiên sau khi simulator khởi động** hay bị treo:
>   - `flutter drive` treo ở **30/127 (24 %)** lần chạy đầu tiên sau khi boot;
>   - lần thử lại trên simulator vừa khởi động lại treo **13/38 (34 %)**;
>   - các lần chạy sau đó chỉ treo **8/197 (4 %)**.
>
>   `ios-ui` cũng hỏng ở những lần mở app đầu tiên của job.
> - **Cách sửa (ba phần, cùng một nhánh):**
>   - (a) **Khởi động nóng (warm-up):** boot xong là mở app một lần, chờ dòng "Dart VM service is listening", rồi tắt app. Việc này làm trước mọi bộ test, không tính vào thời gian của bộ test, và không bao giờ làm job đỏ.
>   - (b) **Khi `flutter drive` treo:** dừng nó, tắt app, rồi chạy lại một lần **trên cùng simulator**. Không khởi động lại simulator nữa.
>   - (c) **Chẩn đoán:** mỗi lần treo, hoặc warm-up quá giờ, thì lưu log, `launchctl` và `sample` của app, rồi đưa lên artifact.
> - **Thêm (M7):** job mới `ios-minimize (iPhone)`, **chặn merge**. Job chỉ chạy `MinimizeUITests` trên iPhone 17 iOS 26. `ios-ui` vẫn không chặn.
> - **Đo:** thêm `workflow_dispatch` để chạy CI bằng tay, rồi chạy 6 lần trên nhánh.
>   - **Đạt** khi không có job chặn merge nào đỏ vì treo, và `ios-ui` đỏ kiểu treo không quá 1 lần.
>   - Ghi tỉ lệ treo ở lần chạy đầu và so với 24 % / 34 %.
>   - Không đạt thì dừng và báo lại kèm chẩn đoán, không sửa mò.
> - **Ngoài phạm vi:**
>   - các assert thời gian của `ios-unit` (VK-626);
>   - lỗi build "minimum platform version 15.0" (VK-627);
>   - thiếu runtime iOS 27 và lỗi hạ tầng Android: chỉ ghi nhận.
> - Không đổi phiên bản, không thêm CHANGELOG của gói.

---

## 1. Goal

The iOS CI jobs stop failing on a stalled first app launch after a simulator boot. Three changes do it, all in this branch:

1. A warm-up launch takes the first launch after every boot, so no suite gets it.
2. The stall guard retries on the same booted simulator instead of a rebooted one, so the retry is not a first launch either.
3. Every stall leaves a diagnostics dump that says which side hung.

Success is measured on six CI runs (§11).

## 2. Scope

### 2.1 In

- **(a) Warm-up** for `integration-ios`, `integration-ios-native`, `ios-unit`, `ios-ui` and the new `ios-minimize`, through one script, `tool/ios_sim.sh` (§5).
- **(b) The stall guard retries without a reboot:** `tool/integration_ios.sh`, `tool/integration_ios_native.sh`, and the native vs Flutter liquid ("compare") step in `ci.yaml` (§7).
- **(c) Diagnostics** on every stall or warm-up timeout, uploaded as an artifact (§10).
- **XCTest targets in three phases:** `make ios-unit`, `ios-ui` and `ios-minimize` run build-for-testing, then the warm-up, then test-without-building (`tool/ios_xctest.sh`, §6).
- **M7:** `make ios-minimize`, and a blocking CI job `ios-minimize (iPhone)` (§8.3).
- **Measurement:** `workflow_dispatch` and a `concurrency` group that keeps dispatched runs apart (§8.1). Six runs, recorded in `docs/qa/vk625/measurement.md` (§11).
- **Wrong comments:** `ci.yaml:304-305` and the headers of both integration scripts say the drive hung in its Xcode build or in a stuck `simctl`. The build was done, `simctl launch` had returned, and the wait was for the VM service URL (§3.2). They are rewritten.

### 2.2 Non-goals

- The `ios-unit` timing asserts (VK-626).
- The intermittent "requires minimum platform version 15.0 … target supports 13.0" build error (VK-627).
- Two kinds of failure are only noted here:
  - iOS 27 legs with no runtime on the image;
  - Android infrastructure failures (Gradle resolution, the emulator SDK download).
- `IOS_DRIVE_TIMEOUT` (600 s, 1200 s) and every test's own waits stay as they are.
- `ios-ui` stays `continue-on-error` (Q6).
- A flutter_tools fix. At most, an upstream issue is drafted for the owner (Q7, §11.5).
- Local-only tools that CI never runs: `tool/tab_frames.sh`, `segment_frames.sh` and `compare_ios.sh`.

## 3. What the evidence shows

### 3.1 Two signatures, one trigger

| | (A) `ios-ui` | (B) `integration-ios`, `integration-ios-native` |
|---|---|---|
| Symptom | "Failed to get matching snapshots: Timed out while evaluating UI query" at the first query after `app.launch()` | `flutter drive` prints "Xcode build done", then nothing for 10–20 min, then `✗ stalled …` and "Error waiting for a debug connection: The log reader failed unexpectedly" |
| Blocks main | no (`continue-on-error`) | yes. It caused every blocking iOS integration failure on main in the window: 38110886831, 38597256231, 38655913550 and 38765508425 |
| Where | 5 of 11 at launch #1 or #2 of the job; 6 at the first test of `SearchUITests`; 2 more jobs had "Failed to send signal 19" at launches #1–#3 | at the first launch after a boot (table below) |

**(B) by drive position,** 362 drives in 127 jobs:

| Drive position | Drives | Stalled | Rate |
|---|---|---|---|
| First after `simctl boot` + `bootstatus -b` | 127 | 30 | **24 %** |
| Retry after `simctl shutdown` / `boot` / `bootstatus` | 38 | 13 | **34 %** |
| Later (the simulator already ran a drive) | 197 | 8 | **4 %** |

- **A hang, not a slow start.**
  - Passing drives go from "Xcode build done" to "All tests passed" in 15–160 s (p50 74 s).
  - Stalled drives never print an app log line before the 600 s or 1200 s kill.
- **From "Xcode build done" to the first app log line:**
  - first launch after a boot: p10 26 s, p50 49 s, p90 70 s, max 85 s (n = 94);
  - later launches: p50 20 s, p90 34 s (n = 183).
- **What matters is which launch it is, not when.**
  - The first launch came about 365 s after `bootstatus` returned for passes (median), and about 384 s for stalls.
  - What counts is that the launch is the first one on that boot.
- **The retry does not cure (B):**
  - both attempts stalled in the blocking failures of 38655913550, 38597256231 and 38765508425;
  - 19 green jobs hid a stalled first attempt, which cost 10–20 min each.
- **(A) in numbers:** the iPad bundle of run 38765508425 failed at the job's first launch.
  - "Setting up automation session" came at +20.4 s, against 1.5–6.8 s for the other 17 launches.
  - The "Home" query started at +35.2 s and failed at +65.6 s.
  - The screen recording shows the first-boot banner "Ready for Apple Intelligence".

### 3.2 What the tool was waiting for

- In flutter_tools 3.44.6 (`simulators.dart`), `IOSSimulator.startApp` subscribes a VM service discovery to the log reader (478–487). It then runs `simctl launch` (507), and awaits the URL with no timeout (520–533).
- The reader is `xcrun simctl spawn <udid> log stream --style json --predicate …` (761–795). It starts asynchronously and cannot read past lines (615).
- "Error waiting for a debug connection: The log reader failed unexpectedly" prints only when that stream closes. Here it closed when `tool/with_timeout.sh` killed the group, so `simctl launch` had returned before.
- "Running Xcode build..." and "Xcode build done. Ns" always carry the same timestamp. In every stall, the build had finished.
- The line flutter_tools waits for comes from the Dart VM's service isolate: `serverPrint('The Dart VM service is listening on $serverAddress')`. The iOS engine writes Dart's output through `FlutterLogger.logDirect` → `vsyslog(LOG_ALERT, …)`, so the line is a default-level unified-log event of the `Runner` process. Probe:

  ```
  2026-10-16 02:39:17.733 Df Runner[11416:27f8cfcf] (Flutter) flutter: The Dart VM service is listening on http://127.0.0.1:49508/OoubEL0EJj0=/
  ```

- **Not known from the logs:** whether the app printed the line and the reader missed it (a late attach on a busy, freshly booted simulator), or whether the app never got that far. The diagnostics of §10 answer that.

### 3.3 Runner and boot handling today

- **Runner:** a 3-core virtual Apple M1 with 7 GB (7168 MB) of RAM, macOS 26.6.2, image `macos-26-arm64`. The simulators are iPhone 17 and iPad (A16), iOS 26.5 (23F77).
- **Flutter on iOS:** in Flutter 3.44 all Dart code runs on the iOS main thread (`FlutterEngine.mm:909-914`). Slow debug-mode Dart work at startup blocks UIKit and accessibility.
- **Boot:** `ios-ui` and `ios-unit` neither boot nor wait (`bootstatus`). xcodebuild boots the simulator implicitly. The integration scripts boot and wait, also before each retry.
- **Warm-up:** nothing launches the app before a suite.

## 4. Design overview

```
every iOS job, per simulator
  (build the app) ─▶ boot + bootstatus -b ─▶ warm-up launch ─▶ terminate ─▶ suite
                                               │ VM service line within 180 s: ok
                                               └ else: diagnose (artifact), go on

every guarded drive (integration scripts, compare step)
  drive ─▶ cap passes ─▶ diagnose (app still alive) ─▶ stop the drive
        ─▶ simctl terminate ─▶ the same drive once more, same booted simulator
```

| Job | Blocking | Warm-up through | Stall guard |
|---|---|---|---|
| `integration-ios` | yes | `tool/integration_ios.sh` → `ios_sim.sh warmup <udid> --build` | `ios_sim.sh guard`, 600 s per drive |
| `integration-ios-native (…, iOS 26)` | yes | `tool/integration_ios_native.sh` → `ios_sim.sh warmup <udid> --build` | `ios_sim.sh guard`, 1200 s per drive, and the compare step |
| `integration-ios-native (…, iOS 27)` | no | same | same |
| `ios-unit (iPad, iPhone)` | yes | `make ios-unit` → `tool/ios_xctest.sh` → `ios_sim.sh warmup <udid> <app>` | the suite cap, with a diagnostics dump |
| `ios-ui (iPad, iPhone)` | no (Q6) | `make ios-ui` → same | same |
| `ios-minimize (iPhone)` (new) | **yes** (Q5) | `make ios-minimize` → same | same |

## 5. `tool/ios_sim.sh`

### 5.1 Interface

```
tool/ios_sim.sh warmup UDID [APP | --build]
tool/ios_sim.sh diagnose UDID LABEL [WINDOW]
tool/ios_sim.sh guard UDID LABEL SECONDS command [args...]
```

| Subcommand | Exit status |
|---|---|
| `warmup` | always 0 |
| `diagnose` | always 0 |
| `guard` | the command's own status; 124 after its second stall |
| a wrong call | 2, with usage on stderr |

The script never changes the caller's directory: `guard` runs its command where it was called.

### 5.2 Environment

| Variable | Default | Used by |
|---|---|---|
| `IOS_APP_BUNDLE_ID` | `vn.lasoai.liquidShellExample` | all three |
| `IOS_WARMUP_TIMEOUT` | `180` (seconds, §9) | `warmup` |
| `IOS_BUILD_TIMEOUT` | `900` (seconds per build step, §9) | `warmup --build` |
| `IOS_DIAG_DIR` | `liquid_shell/example/build/ios-diagnostics` (absolute, from the script's location) | `diagnose`, and through it `warmup` and `guard` |
| `FLUTTER` | `flutter` (may be `fvm flutter`) | `warmup --build` |
| `GITHUB_ACTIONS` | set by Actions | when `true`, a counted line (§5.6) is printed to stdout as `::warning::…` |

### 5.3 `warmup`

1. **`--build` only:**
   - In `liquid_shell/example`, run `$FLUTTER build ios --config-only --simulator --debug`.
   - Then, in `ios/`, run `xcodebuild build -workspace Runner.xcworkspace -scheme Runner -configuration Debug -destination id=<udid> -derivedDataPath liquid_shell/example/build/ios-derived -quiet`.
   - Each step is capped at `IOS_BUILD_TIMEOUT`, and its output goes to stderr.
   - The app is `liquid_shell/example/build/ios-derived/Build/Products/Debug-iphonesimulator/Runner.app`.
   - `-destination id=<udid>` builds the one simulator architecture. `flutter build ios --simulator` builds both, which Xcode 27's lipo rejects (VK-600 plan).
2. **Boot:** `simctl boot <udid>`, capped at 600 s. "Already booted" is fine.
3. **Wait:** `simctl bootstatus <udid> -b`, capped at 600 s.
   - If it fails: print `warm-up skipped: <udid> did not finish booting` and exit 0.
   - If the build failed: print `warm-up skipped: the build failed` and exit 0. The simulator is booted all the same, as the suites expect.
4. **Install:** with an app, `simctl install <udid> <app>`, capped at 300 s. A failure prints `warm-up skipped: could not install <app>` and exits 0.
5. **Start the reader before the launch:**
   - `simctl spawn <udid> log stream --style compact --predicate '<§5.4>'`, in the background, into a temporary file.
   - It is capped at `IOS_WARMUP_TIMEOUT + 120` s, so it can never outlive the script.
   - Wait up to 30 s for its first output, the "Filtering the log data …" header. Starting the reader first means it cannot miss the line, which is the race §3.2 suspects in flutter_tools.
6. **Launch:** `simctl launch <udid> <bundle>`, capped at 120 s. A failure stops the reader, prints `warm-up skipped: could not launch <bundle>` and exits 0.
7. **Wait for the line:** poll the reader's file once a second for `Dart VM service is listening on`, for at most `IOS_WARMUP_TIMEOUT` seconds from the launch. Then stop the reader.
8. **Result:**
   - found: print `warm-up ok after <n>s on <udid>`;
   - not found: print `warm-up timeout after <IOS_WARMUP_TIMEOUT>s on <udid>` and run `diagnose <udid> warm-up`. The dump runs **before** the terminate, so `sample` sees the app.
9. **Terminate:** `simctl terminate <udid> <bundle>`, capped at 60 s, errors ignored. Exit 0.

The warm-up launches the app as built: no demo environment variable, so the example's case list.

### 5.4 The marker

- **Predicate:** `process == "Runner" AND eventMessage CONTAINS "Dart VM service is listening"`.
- **Match:** `Dart VM service is listening on`. The predicate leaves out the trailing " on", so the reader's own header, which quotes the predicate, never matches.
- **Why this line:** a better marker would be Flutter's first frame, but the example logs nothing at startup (`lib/main.dart`). So the marker is the line flutter_tools itself waits for, which is exactly where (B) hangs. Adding a startup log to the example would change package-facing code, which Q9 rules out.

### 5.5 `guard`

For attempt 1 and attempt 2:

1. Run the command under `tool/with_timeout.sh SECONDS`, with `WITH_TIMEOUT_ON_STALL` set to `ios_sim.sh diagnose <udid> "<label> stall <attempt>" <window>`. The dump therefore runs at the deadline, **before** the stop, while the app is in whatever state hung it (§5.7).
2. Any status other than 124 is returned as is. A test failure is never retried.
3. On 124:
   - after attempt 1, print `stall guard fired: <label> (attempt 1 of 2); terminating the app and retrying on the same simulator`;
   - after attempt 2, print `stall guard fired: <label> (attempt 2 of 2); giving up`.
4. `simctl terminate <udid> <bundle>`, capped at 60 s, errors ignored.

After attempt 2, return 124. No `simctl shutdown` and no `simctl boot` anywhere: the retry runs on the same booted simulator (Q2b).

**Window:** `max(15, ceil(SECONDS / 60) + 5)` minutes. That is 15m for the 600 s drive and 25m for the 1200 s ones. A 1200 s drive launched its app about 19 minutes before the dump, so the approved "--last 15m" would miss its launch. Everything else uses 15m.

**Labels:**

| Caller | Label |
|---|---|
| `integration_ios.sh` | `signals_test.dart on <device name>` |
| `integration_ios_native.sh` | `<target> on <run>`, where `<run>` is the device name or UDID with non-alphanumerics as `_` |
| the compare step | `liquid_compare_test.dart on <iPad or iPhone>` |

### 5.6 Log lines (pinned; §11 counts them)

| Line (after the `ios_sim: ` prefix) | Stream | Annotation on Actions |
|---|---|---|
| `warm-up ok after <n>s on <udid>` | stderr | no |
| `warm-up timeout after <s>s on <udid>` | stderr; stdout on Actions | `::warning::` |
| `warm-up skipped: <reason>` | stderr; stdout on Actions | `::warning::` |
| `stall guard fired: <label> (attempt <1 or 2> of 2); <what next>` | stderr; stdout on Actions | `::warning::` |
| `diagnostics in <dir>` | stderr | no |

`tool/with_timeout.sh` keeps printing its own `✗ stalled: still running after <s>s: <command>`.

### 5.7 `tool/with_timeout.sh`: the stall hook

- New optional variable `WITH_TIMEOUT_ON_STALL`: a shell command run once (`bash -c`) when the deadline passes, after the `✗ stalled` line and before the stop.
- Its status is ignored, so it must cap its own steps; `diagnose` does.
- The wrapper reads the variable, then unsets it, so neither the command nor the hook inherits it. A nested `with_timeout.sh` inside the hook therefore cannot recurse.
- Exit statuses are unchanged (124 on a stall).

## 6. XCTest targets: `tool/ios_xctest.sh` and the Makefile

```
tool/ios_xctest.sh UDID RESULT SUITE_SECONDS DEFAULT_ALLOWANCE MAX_ALLOWANCE selection...
```

1. **Build** in `liquid_shell/example`, each step capped at `IOS_BUILD_TIMEOUT` (900 s):
   - `$FLUTTER build ios --config-only --simulator --debug`;
   - `rm -rf RESULT`;
   - in `ios/`: `xcodebuild build-for-testing -workspace Runner.xcworkspace -scheme Runner -destination id=UDID -derivedDataPath liquid_shell/example/build/ios-derived <selection> -quiet`.

   A failed build exits with its status, before any warm-up.
2. **Warm up:** `tool/ios_sim.sh warmup UDID liquid_shell/example/build/ios-derived/Build/Products/Debug-iphonesimulator/Runner.app`. This runs outside every cap of this script and never fails it.
3. **Test:** `xcodebuild test-without-building`, capped at `SUITE_SECONDS` by `tool/with_timeout.sh`.
   - Arguments: the same workspace, scheme, destination, derived data and `<selection>`, plus `-parallel-testing-enabled NO -collect-test-diagnostics never -test-timeouts-enabled YES -default-test-execution-time-allowance DEFAULT_ALLOWANCE -maximum-test-execution-time-allowance MAX_ALLOWANCE -resultBundlePath RESULT -quiet`.
   - `WITH_TIMEOUT_ON_STALL` is `ios_sim.sh diagnose UDID "<RESULT's basename without .xcresult> stall"`.
   - A red run prints `xcrun xcresulttool get test-results summary --path RESULT` when RESULT exists, then exits with the run's status. A stall exits 124.

Fewer than six arguments print usage and exit 2. The flags and their reasons (`-collect-test-diagnostics never`, `-quiet` plus the summary) move from the Makefile into the script's header.

| Target | Selection | Allowances (default / max) | Suite cap | Result |
|---|---|---|---|---|
| `ios-unit` | `-only-testing:RunnerTests -skip-testing:RunnerUITests` | 60 / 120 s | `IOS_UNIT_TIMEOUT` 900 s | `liquid_shell/example/build/ios-unit.xcresult` |
| `ios-ui` | `-only-testing:RunnerUITests` | 180 / 300 s | `IOS_UI_TIMEOUT` 2100 s | `…/ios-ui.xcresult` |
| `ios-minimize` (new) | `-only-testing:RunnerUITests/MinimizeUITests` | 180 / 300 s | `IOS_MINIMIZE_TIMEOUT` 900 s | `…/ios-minimize.xcresult` |

- All three take `IOS_UNIT_DEVICE=<udid>`, as today, and pass `FLUTTER` and `IOS_BUILD_TIMEOUT` to the script. `ios-minimize` joins `.PHONY`, `make help` and the commands table of `CONTRIBUTING.md`.
- `IOS_UNIT_TIMEOUT` and `IOS_UI_TIMEOUT` keep their values. They now cap the suite alone: the build has its own cap, and the warm-up has its own. The measurements in the `IOS_UI_TIMEOUT` comment included the build, so they now overstate the suite. The comment says so.
- The three targets share one derived-data folder. Run them one at a time on a machine.

## 7. Integration scripts and the compare step

- **`tool/integration_ios.sh`:**
  - Per device, `ios_sim.sh warmup <udid> --build` replaces `simctl boot` + `bootstatus`.
  - The drive runs as `ios_sim.sh guard <udid> "signals_test.dart on <name>" "$IOS_DRIVE_TIMEOUT" $FLUTTER drive …`.
  - The script's own retry block (shutdown, boot, bootstatus, retry) goes.
  - `FLUTTER` is exported, so the warm-up's build uses the same command.
- **`tool/integration_ios_native.sh`:**
  - The same changes: `warmup --build` once per device, before its first target.
  - Each target is guarded as `<target> on <run>`.
  - The `boot()` helper and the retry block go.
- **The compare step in `ci.yaml`:** `../../tool/ios_sim.sh guard "$udid" "liquid_compare_test.dart on ${{ matrix.device }}" 1200 flutter drive …`, in place of its `compare()` function and its shutdown/boot retry. It runs after the native drives, so the simulator is already warm.
- **Comments:**
  - Both script headers now describe the warm-up and the real hang ("`simctl launch` had returned and flutter_tools waited, with no timeout of its own, for the app's VM service URL").
  - They also give the reason for no reboot (13 of 38 rebooted retries stalled).
  - The compare step's comment drops "stuck in its Xcode build".

## 8. CI workflow (`.github/workflows/ci.yaml`)

### 8.1 Trigger and concurrency

```yaml
on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

concurrency:
  group: ci-${{ github.event_name == 'workflow_dispatch' && format('dispatch-{0}', github.run_id) || github.ref }}
  cancel-in-progress: true
```

- A dispatched run's group is its own run id. It never cancels, and is never cancelled by, another dispatched run or the PR's run (`refs/pull/N/merge`).
- Pushes and PR updates behave as today.

### 8.2 Existing jobs

| Job | `timeout-minutes` | Cold-launch artifact |
|---|---|---|
| `integration-ios` | 35 → **50** (two 10 min drive caps + 30 min for setup, the warm-up build and the warm-up) | `cold-launch-integration-ios-a<attempt>` |
| `ios-unit` | 30 → **45** (the 15 min suite cap + 30) | `cold-launch-ios-unit-<device>-a<attempt>` |
| `ios-ui` | 45 → **65** (the 35 min suite cap + 30) | `cold-launch-ios-ui-<device>-a<attempt>` |
| `integration-ios-native` | 140 → **150** (+10 min for the warm-up build and the warm-up) | `cold-launch-native-<device>-<job-index>-a<attempt>` |

- **The upload step:**
  - `actions/upload-artifact@v4`, `if: always()`, `path: liquid_shell/example/build/ios-diagnostics/`, `if-no-files-found: ignore`, `retention-days: 14`;
  - `integration-ios-native` also checks `steps.sim.outputs.udid != ''`.
- `<attempt>` is `${{ github.run_attempt }}`, so a re-run never collides with an earlier attempt's artifact.
- The job comments are updated to match.

### 8.3 New job: `ios-minimize (iPhone)`

- **Blocking:** no `continue-on-error`. `timeout-minutes: 45`, the 15 min suite cap plus 30.
- **Steps:**
  1. checkout;
  2. `subosito/flutter-action@v2` with `flutter-version: 3.44.x` and `cache: true`;
  3. pick the simulator: `xcrun simctl list devices available "iOS 26" | grep -F "    iPhone 17 (" | tail -n1`. That is the runtime pin of `integration-ios-native`; `iPhone 17 (` leaves out the Pro. An empty result is `::error::no iPhone 17 simulator on iOS 26`, exit 1;
  4. `make get`;
  5. `make ios-minimize IOS_UNIT_DEVICE=<udid>`;
  6. on failure, the crash reports and `ios-minimize.xcresult` as `ios-minimize-iPhone-diagnostics` (7 days), like `ios-ui`;
  7. the cold-launch artifact `cold-launch-ios-minimize-iPhone-a<attempt>`.
- `ios-ui` keeps running `MinimizeUITests` too, non-blocking, on both idioms. The iPad-only tests run only there.
- The repository has no branch protection (`gh api …/branches/main/protection` answers "Branch not protected"). "Blocking" here means a red job turns the run red.

## 9. Timeouts (pinned)

| Name | Value | Covers | Why |
|---|---|---|---|
| `IOS_WARMUP_TIMEOUT` | **180 s** | launch → VM service line | Passing first launches after a boot logged their first line within 85 s (p90 70 s, n = 94), counted from "Xcode build done", so install included. Stalls never recovered in 600–1200 s. 180 s is about twice the slowest pass, and a stall costs 3 min instead of 10–20 |
| `IOS_BUILD_TIMEOUT` | **900 s** per build step | `flutter build ios --config-only`; `xcodebuild build` / `build-for-testing` | CI's first app launch came 93–458 s after `xcodebuild test` started, build and implicit boot included. Flutter's first drive build took up to 108.9 s. 900 s is about twice the worst |
| `IOS_MINIMIZE_TIMEOUT` | **900 s** | the `MinimizeUITests` suite | 6 iPhone tests: 165 s in the probe at host load ~200; VK-600 measured five of them at 81 s at load 6–11. On the Makefile's slow-runner scale (443 s → 1400 s, ×3.2) six take about 310 s. One stopped at its 300 s allowance makes about 610 s, which leaves ~290 s in hand |
| `IOS_UNIT_TIMEOUT` | 900 s (unchanged) | the `RunnerTests` suite alone (was: build included) | — |
| `IOS_UI_TIMEOUT` | 2100 s (unchanged) | the `RunnerUITests` suite alone (was: build included) | — |
| `IOS_DRIVE_TIMEOUT` | 600 s / 1200 s (unchanged) | one guarded drive | — |
| inner caps of `ios_sim.sh` | boot 600, bootstatus 600, install 300, launch 120, terminate 60; reader `IOS_WARMUP_TIMEOUT + 120`; dump: `log show` 120, `launchctl` 30, `sample` 60 (5 s of sampling) | each `xcrun` call | A stuck `simctl` once held a job for the 6 h limit, so every call is capped. The dump takes ≤ 210 s; it took 16 s in the probe |

## 10. Diagnostics

### 10.1 Layout

Each dump is a folder `IOS_DIAG_DIR/<UTC yyyymmddThhmmssZ>-<label>`, where the label's characters outside `A-Za-z0-9._-` become `_`. For example, `20261016T101500Z-native_shell_test.dart_on_iPhone_stall_1`.

| File | Content |
|---|---|
| `meta.txt` | `label:`, `udid:`, `bundle:`, `dump started:` (UTC), `load:` (`uptime`), `dump finished:` (UTC) |
| `vm-service.log` | `xcrun simctl spawn <udid> log show --last <window> --info --debug --style compact --predicate '<§5.4>'` (stdout and stderr) |
| `launchctl.txt` | `xcrun simctl spawn <udid> launchctl list \| grep -F <bundle>`, or `no <bundle> in the simulator's launchctl list` |
| `sample.txt` | `sample <pid> 5 -file …` when `launchctl.txt` has a numeric pid on a `UIKitApplication:<bundle>[` line; otherwise `<bundle> is not running: no sample` |

On CI the folders are uploaded as the `cold-launch-*` artifacts of §8.2.

### 10.2 Reading a dump (experiment E1 of the evidence)

| What the dump shows | Reading |
|---|---|
| `vm-service.log` has a line from `Runner[<pid>:…]` whose pid is the one in `launchctl.txt` | The app printed the line, and the reader missed it: a flutter_tools / `log stream` race (Q7) |
| The app is alive in `launchctl.txt`, with no such line | The app is stuck before its VM service started. `sample.txt` shows where (look at the main thread, `com.apple.main-thread`) |
| No app in `launchctl.txt` | The launch was lost, or the app died. Look for a crash report |

For a warm-up timeout, the reader that "missed" is our own, which started before the launch. A line there means the app was simply slower than 180 s.

## 11. Measurement

### 11.1 Runs

- Push the branch and open a draft PR. Q4 is the owner's go-ahead for this branch only.
- Dispatch six runs at the same head commit: `gh workflow run ci.yaml --ref VK-625-ci-cold-launch`. The PR's own run is reported, but not counted.
- **If GitHub refuses the dispatch** (HTTP 422, "does not have 'workflow_dispatch' trigger": `main`'s copy lacks the trigger), re-run the PR's run instead: `gh run rerun <id>` six times, one after another. Attempt numbers keep the artifacts apart.

### 11.2 Pass bar (Q4)

Over the six runs:

1. **Zero blocking jobs red because of a stall.** A stall is a guard that fired twice, a suite cap (124), or the job's own `timeout-minutes`. The blocking jobs are `integration-ios`, `integration-ios-native (…, iOS 26)`, `ios-unit (…)` and `ios-minimize (iPhone)`, plus the non-iOS jobs.
2. **At most one stall-like `ios-ui` red**, across both legs (12 jobs). Stall-like means the job failed with any of:
   - "Timed out while evaluating UI query";
   - "Failed to send signal 19";
   - "exceeded the maximum allowed time" / the 300 s allowance;
   - the suite cap (`✗ stalled`).

A red job for another reason is recorded with its category and does not count against the bar. Examples: a VK-626 timing assert, the VK-627 build error, no iOS 27 runtime, Android infrastructure.

### 11.3 Counted from the logs

Count these per job from the job logs (`gh api repos/anvu69/liquid_shell/actions/jobs/<id>/logs`):

| Count | Pattern | Baseline |
|---|---|---|
| Warm-ups | `ios_sim: warm-up ok after` + `ios_sim: warm-up timeout after` + `ios_sim: warm-up skipped` | — |
| Warm-up timeouts | `ios_sim: warm-up timeout after` | — |
| Warm-up time (p50, max) | the `<n>` of `warm-up ok after <n>s` | 49 s p50 to the first app line on a first launch |
| First-drive stalls | `stall guard fired: <first label of the job> (attempt 1 of 2)` | 30 / 127 = 24 % |
| Retry stalls | `(attempt 2 of 2)` over `(attempt 1 of 2)` | 13 / 38 = 34 % (a rebooted retry then; same-simulator now) |
| Later-drive stalls | `(attempt 1 of 2)` on a label that is not the job's first | 8 / 197 = 4 % |

The job's first label is its first `ios_sim.sh guard` call: `native_shell_test.dart on …` in `integration-ios-native`, and `signals_test.dart on …` in `integration-ios`.

### 11.4 `docs/qa/vk625/measurement.md`

1. **Header:** branch, head sha, the six run ids and links, the runner image versions seen.
2. **Per-run table:** one row per iOS job instance.
   - Columns: run, job, conclusion, duration, warm-up (ok n s / timeout / skipped), guard firings, failure category.
   - Also list the non-iOS jobs' conclusions.
3. **Totals and rates** against the baselines of §11.3.
4. **Verdict** against §11.2: PASS or FAIL, with the counting shown.
5. **Diagnostics:** for every dump, its artifact, label and reading (§10.2).
6. **Q7 outcome:** an upstream draft was written, or "not needed: <reason>".

### 11.5 Q7 and Q8

- **Q7:** if any dump of a **drive** stall reads "the app printed the line, and the reader missed it" (§10.2, first row), write `docs/qa/vk625/upstream-draft.md`.
  - It is a flutter/flutter issue draft: title, Flutter version, steps, the dump lines, and `simulators.dart:478-533` / `615`.
  - It is for the owner to approve. Never post it.
  - Otherwise, write no draft.
- **Q8:** if the bar of §11.2 fails, stop.
  - Write `measurement.md` with the verdict and the diagnostics, commit it, and report back.
  - Make no further fix in this branch without a new decision.

## 12. Testing

- **Fakes on `PATH`:** `tool/test/fake_sim.dart` writes fake `xcrun`, `xcodebuild`, `flutter` and `sample` scripts into a temporary directory.
  - Each call appends one line to a call log.
  - `FAKE_*` variables steer the answers: the VM line and its delay, a failed launch, the `launchctl` output, a failed build, a red or stalled suite, a failed or stalled drive.
  - This follows `tool/test/integration_android_test.dart` (fake `adb` and `flutter`).
- **Where the tests run:** `dart test tool/test`, which is part of `make test` (the pre-commit hook and CI's `checks` job on Ubuntu). They need only bash, so they pass on Linux, on macOS's bash 3.2 and on bash 5 (probe).

| Test file | Pins |
|---|---|
| `tool/test/with_timeout_test.dart` (+2) | the hook runs at the deadline, before the stop, with the command alive; the command never inherits the variable; a failing hook keeps 124 |
| `tool/test/ios_sim_test.dart` (new) | warm-up order (boot → bootstatus → install → reader → launch → terminate), one launch, the ok and timeout lines, the dump before the terminate, the annotation on Actions, a failed launch and a failed `--build` still exit 0, `--build` args and app path; the dump's four files, no `sample` without the app, the window; the guard: pass once, failure never retried, stall → dump → terminate → retry with no shutdown or boot, two stalls → 124 and two dumps; usage |
| `tool/test/ios_xctest_test.dart` (new) | build-for-testing → warm-up → test-without-building with the same destination, derived data and selection, and the allowances; the warm-up outside the suite cap; a warm-up timeout never fails; red → summary and the status; stall → dump and 124; a failed build stops before any `simctl`; usage |
| `tool/test/integration_ios_test.dart` (new) | both scripts: build, warm-up, then the drives; a stalled drive retried once with no `simctl shutdown`; a failing drive stops the run |

- **Locally, on our own simulators (created and deleted by each task):**
  - a real warm-up and a forced timeout dump (Task 1);
  - `make ios-minimize` (Task 2);
  - the real guard against a hanging command, and one real `integration-ios-native` drive (Task 3).
- **On CI:** the six runs are the integration test (§11).

## 13. Risks

| Risk | Handling |
|---|---|
| The warm-up stops at the VM service line, before Flutter's first frame. (A) stalls later in the launch: a blank body until about +40–50 s | The measurement shows whether `ios-ui` still stalls; Q8 then stops the branch with the dumps |
| The warm-up launch itself stalls (it is a first launch) | It costs 180 s plus a dump, never a red job. The suite's first launch is then the second after the boot |
| The integration warm-up builds the app in its own derived data, and flutter's drive build is not shared with it | About one extra build per integration job (≈ 2 min on CI). It is bounded by `IOS_BUILD_TIMEOUT` and never fails the job |
| `sample` is refused on the runner | `sample.txt` says so; the other files still answer most of §10.2 |
| The dispatch is refused on a non-default branch | The fallback of §11.1 |
| Longer job caps make a hung job hold its runner longer | Each cap is the sum of the inner caps; the inner caps fire first |
| `ios-minimize` turns the run red when a UIKit change breaks the minimize trigger (R1 of VK-600) | That is its purpose (M7) |

## 14. Process

- **Commits:** `<type>(<scope>): <summary> (VK-625)`.
  - Types: `ci`, `test` and `docs` (Q9). Scopes: `ci` or `docs`.
  - Every message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - Run `.githooks/pre-commit` by hand before each commit. Never `--no-verify`, never a git config change.
- **No version bump and no package CHANGELOG** (Q9).
- **Publishing:** the push and the draft PR happen only in the plan's last task, under Q4. Nothing else is published.

## Quyết định cần chủ sản phẩm xác nhận

Chủ sản phẩm đã trả lời "Ok hết" ngày 2026-10-16, nên mọi đề xuất dưới đây đã được chốt.

| Q# | Câu hỏi | Đã chốt |
|---|---|---|
| Q1 | Phạm vi? | Sửa lỗi treo ở lần mở app đầu tiên sau khi boot, gồm cả (A) `ios-ui` và (B) `flutter drive`, cộng thêm M7. Ngoài phạm vi, đã có việc riêng trên Plane: các assert thời gian của `ios-unit` (VK-626), lỗi build "minimum platform version 15.0" (VK-627). Thiếu runtime iOS 27 và lỗi hạ tầng Android chỉ ghi nhận |
| Q2 | Sửa thế nào? | Cả ba phần trong một nhánh. (a) Warm-up ngay sau `simctl boot` và `bootstatus -b`, trước mọi bộ test: không tính giờ, không bao giờ làm job đỏ, chờ dòng "Dart VM service is listening" của app debug rồi tắt app. (b) Khi `flutter drive` treo: dừng drive, `simctl terminate` app, chạy lại một lần trên cùng simulator đang chạy, **không khởi động lại**. (c) Chẩn đoán mỗi lần treo hoặc warm-up quá giờ, đưa lên artifact: `log show --last 15m` lọc dòng VM service, `launchctl list \| grep` app, `sample` tiến trình Runner nếu còn sống, kèm mốc thời gian |
| Q3 | Warm-up áp dụng cho job nào? | `integration-ios`, `integration-ios-native`, `ios-ui`, `ios-unit`, qua **một** script dùng chung. `ios-ui` và `ios-unit` đổi thành `build-for-testing` → warm-up → `test-without-building`, để app có sẵn trước bộ test |
| Q4 | Đo thế nào? | Thêm `workflow_dispatch`, và nhóm `concurrency` không để các lần chạy tay hủy lẫn nhau hay hủy lần chạy của PR. Chạy CI 6 lần trên nhánh. **Đạt:** không job chặn nào đỏ vì treo, và tối đa 1 lần `ios-ui` đỏ kiểu treo. Ghi tỉ lệ treo ở lần drive đầu (đếm warm-up quá giờ và số lần stall guard chạy) so với 24 % / 34 %. Repo công khai nên phút CI miễn phí |
| Q5 | M7? | Job mới **chặn merge** `ios-minimize (iPhone)`: chỉ chạy `MinimizeUITests` (`-only-testing`) trên iPhone 17, ghim runtime iOS 26 như `integration-ios-native` (image hay thiếu iOS 27), có warm-up và `timeout-minutes` hợp lý |
| Q6 | `ios-ui`? | Giữ `continue-on-error` |
| Q7 | Nếu lỗi nằm ở flutter_tools? | Nếu chẩn đoán cho thấy bộ đọc log của flutter_tools bỏ lỡ dòng VM service mà app đã in, thì soạn (không đăng) một issue gửi flutter/flutter vào `docs/qa/vk625/upstream-draft.md` để chủ sản phẩm duyệt. Nếu không thì bỏ qua |
| Q8 | Nếu 6 lần chạy không đạt Q4? | Dừng lại và báo cáo kèm chẩn đoán. Không sửa mò thêm |
| Q9 | Phiên bản, CHANGELOG? | Không đổi phiên bản, không thêm CHANGELOG của gói, vì chỉ đổi CI và test. Loại commit: `ci`, `test`, `docs` |

### Quyết định phát sinh khi viết spec

Danh sách Q1–Q9 không nói tới những điểm dưới đây. Spec chọn như sau, chủ sản phẩm có thể đổi:

1. **Tên và cách chia script:**
   - `tool/ios_sim.sh` gồm ba lệnh `warmup` / `diagnose` / `guard`; đây là script warm-up dùng chung của Q3;
   - thêm `tool/ios_xctest.sh` cho ba target XCTest, thay vì lặp ba công thức gần giống nhau trong Makefile.
2. **Chụp chẩn đoán *trước khi* dừng drive:** thêm biến `WITH_TIMEOUT_ON_STALL` vào `tool/with_timeout.sh`. Như vậy `sample` còn thấy app ở đúng trạng thái treo.
3. **Cửa sổ log:** 15 phút như Q2c, riêng stall guard của drive 1200 s nới thành 25 phút (§5.5). Lý do: drive đó mở app khoảng 19 phút trước lúc chụp.
4. **Warm-up của job integration tự build app** (`--build`, derived data riêng `build/ios-derived`), vì trước drive đầu tiên chưa có app nào được cài. Tốn thêm khoảng một lần build mỗi job.
5. **`ios-ui` / `ios-unit` nay boot simulator rõ ràng** (warm-up làm việc này), thay vì để xcodebuild tự boot.
6. **Nâng `timeout-minutes`:** `integration-ios` 35 → 50, `ios-unit` 30 → 45, `ios-ui` 45 → 65, `integration-ios-native` 140 → 150; job mới `ios-minimize` là 45. `IOS_UNIT_TIMEOUT` và `IOS_UI_TIMEOUT` giữ nguyên số, nhưng nay chỉ tính phần chạy test.
7. **`ios-ui` vẫn chạy `MinimizeUITests`**, không chặn, trên cả hai loại máy. Các test chỉ dành cho iPad chỉ chạy ở đó.
8. **Artifact:**
   - tên `cold-launch-<job>[-<máy>]-a<lần chạy>`, giữ 14 ngày;
   - `meta.txt` có thêm dòng tải máy (`uptime`).
9. **Warm-up chờ tới dòng VM service rồi tắt app,** không chờ tới khung hình đầu: app ví dụ không in gì lúc khởi động, và thêm log vào app là đổi code của gói (§5.4, §13).
