Draft for the owner. Not posted.

# [flutter_tools] iOS simulator: startApp waits forever when log stream misses the VM service line

## Summary

On a loaded CI runner, `flutter drive` on an iOS simulator can wait forever for the VM service URL. The app has started and has printed "The Dart VM service is listening on …" to the unified log, but flutter_tools never reported it (cause unconfirmed; see below). `IOSSimulator.startApp` awaits the URL with no timeout. Nothing more is printed until an external timeout kills the process, and only then does "Error waiting for a debug connection: The log reader failed unexpectedly" appear. A second `flutter drive` on the same booted simulator then connects within seconds.

## Environment

- **Flutter:** 3.44.9, stable. The version comes from the CI tool cache path `flutter/stable-3.44.9-arm64`. The line numbers below are from the 3.44.6 source; check them against 3.44.9 before posting.
- **Xcode:** not printed in the job log. It is the runner image's default. *(Fill in before posting.)*
- **Host:** GitHub Actions `macos-26-arm64` image 20260907.0351.1, macOS 26.6.2 (25G83). The runner is a 3-core virtual Apple M1 with 7 GB of RAM. The load average at the time of the stall was 53.86 / 110.10 / 118.95.
- **Simulator:** iPhone 17, iOS 26.5 (23F77).

## Steps to reproduce

The failure is intermittent. It is seen on CI and has not been reproduced on demand.

1. Boot a simulator: `xcrun simctl boot <udid>`, then `xcrun simctl bootstatus <udid> -b`.
2. Optional, as in this case: launch the debug app once with `simctl launch`, wait for its VM service line, then `simctl terminate` it.
3. On a heavily loaded 3-core runner, run `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/<test>.dart -d <udid>`.

Over 40 CI runs before any mitigation, the first drive after a boot stalled 30 times in 127. With a warm-up launch first, 1 stall in 18 first drives remained, and that is the case below.

## Expected

`flutter drive` connects to the VM service, as the retry did 14 s after its build. If the URL never arrives, flutter_tools should fail with an error after a bounded wait.

## Actual

After "Xcode build done", nothing is printed for 1200 s, until an external timeout kills the process group:

```
2026-10-16T01:12:59.0879060Z Running Xcode build...
2026-10-16T01:12:59.1090750Z Xcode build done.                                           206.8s
2026-10-16T01:28:34.5325620Z ✗ stalled: still running after 1200s: flutter drive --driver=test_driver/integration_test.dart --target=integration_test/native_shell_test.dart -d 88931AEA-62E6-447F-8697-DCE00A671384 --dart-define=EXPECT_NATIVE=true --dart-define=RUN_NAME=88931AEA_62E6_447F_8697_DCE00A671384
2026-10-16T01:28:51.5633400Z Error waiting for a debug connection: The log reader failed unexpectedly
2026-10-16T01:28:51.5751150Z Application failed to start on attempt: 1
```

The `✗ stalled` line is printed by our timeout wrapper. A diagnostics dump of the simulator ran after it and before the kill, so the dump saw the app in its stalled state:

- **The app was running.** `launchctl list` in the simulator showed `19423	0	UIKitApplication:<bundle id>[0875][rb-legacy]`, so `app pid: 19423`.
- **The app had printed the line.** The dump ran `xcrun simctl spawn <udid> log show --last 25m --info --debug --style compact --predicate 'process == "Runner" AND eventMessage CONTAINS "Dart VM service is listening"'`. It found this line from that pid, about 14.5 minutes before the kill:

  ```
  2026-10-16 01:14:02.833 Df Runner[19423:f0fc] (Flutter) flutter: The Dart VM service is listening on http://127.0.0.1:51215/LOA13XgD8YA=/
  ```

- **The app was idle, not hung.** `sample 19423` gives Launch Time 01:14:00.601, so the line came 2.2 s after the launch. The main thread was idle in its run loop: `UIApplicationMain` → `GSEventRunModal` → `__CFRunLoopRun` → `mach_msg2_trap`, in every sample. This fits an app whose isolate is paused at start and waiting for the tool.
- **The retry connected at once.** The same `flutter drive` was rerun on the same booted simulator after `simctl terminate`, with no reboot. It printed `VMServiceFlutterDriver: Connecting to Flutter application at http://127.0.0.1:51770/…` 14 s after its "Xcode build done", and the tests passed.

## Where it waits

These pointers are to `packages/flutter_tools/lib/src/ios/simulators.dart` at 3.44.6:

- **478–533:** `startApp` creates a `ProtocolDiscovery.vmService` on `getLogReader(app: package)` (478–487). It then runs `_simControl.launch(...)` (507), and awaits `vmServiceDiscovery?.uri` with no timeout (520–533). The only exit without a URL is the reader's stream closing, which is what prints "The log reader failed unexpectedly".
- **615:** `getLogReader` asserts `!includePastLogs`: "Past log reading not supported on iOS simulators." A line printed before the reader attaches is lost for good.
- **841–850:** `_IOSSimulatorLogReader._start` runs on the first listen, asynchronously. It awaits `device.sdkMajorVersion` before it spawns `xcrun simctl spawn <udid> log stream --style json --predicate …` (`launchDeviceUnifiedLogging`, 761–795). Nothing makes `simctl launch` wait until the stream is attached. On a busy simulator, the app can print its VM service line, here 2.2 s after the launch, before `log stream` is listening.

That a late attach caused this is an inference: the reader's own output was not captured. What the dump does show is the app's line in the unified log, from the app's pid, while flutter_tools waited for it.

## Suggested fix

Any one of these would turn the hang into a recovery or an error:

1. **A timeout** on `vmServiceDiscovery.uri` in `IOSSimulator.startApp`, failing with an actionable error instead of waiting forever.
2. **A backfill:** when the URL has not arrived after N seconds, run `xcrun simctl spawn <udid> log show --start '<launch time>' --predicate '<same predicate>'` and feed its lines to the discovery.
3. **Attach first:** wait for `log stream`'s "Filtering the log data using …" header before `simctl launch`, so the reader is attached when the app starts. Our CI warm-up (a throwaway launch of the app on the booted simulator, before the drive) does this, and its reader caught the line in 48 of 48 launches in the six counted runs.
