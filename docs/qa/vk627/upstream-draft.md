Draft for the owner. Not posted.

# [flutter_tools] iOS: a timed-out xcodebuild -showBuildSettings silently skips the SwiftPM deployment-target raise, and Xcode 26 fails Target Integrity

## Summary

With Swift Package Manager on, every `flutter build ios`, `flutter run` and `flutter drive` on iOS rewrites `ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift` with `.iOS("13.0")`, Flutter's floor. It then raises that to the app's `IPHONEOS_DEPLOYMENT_TARGET`. The raise needs the Xcode build settings, which flutter_tools reads with `xcodebuild -showBuildSettings`: a 60 s timeout and one retry. When both tries time out, flutter_tools logs the error with `printTrace` only and goes on with an empty map. The raise is skipped without a word, and the manifest keeps 13.0.

With a plugin whose `Package.swift` declares `.iOS("15.0")`, Xcode 26.6 then fails the build:

```
Target Integrity (Xcode): The package product 'liquid-shell-ios' requires minimum platform version 15.0 for the iOS platform, but this target supports 13.0
To fix this error, increase your app's minimum platform version from 13.0 to at least 15.0 or remove the liquid-shell-ios dependency.
```

The hint misleads: the app is already at 15.0 everywhere (the Xcode project, the Podfile, `MinimumOSVersion`). Only Flutter's generated package is at 13.0, because Flutter skipped its own raise. Running the same build again usually passes.

## Environment

- **Flutter:** 3.44.9, stable, on CI. The mechanism was read and reproduced on 3.44.6; 3.44.9 changes none of the files below. The line numbers are from 3.44.6. *(Check them against the current stable before posting.)*
- **Xcode:** 26.6 (17F113), the default Xcode of GitHub's `macos-26-arm64` image 20260907.0351.1. The job log does not print it; it comes from the image's readme. Locally, Xcode 27.1 builds the same 13.0 manifest without the error.
- **Host:** GitHub Actions `macos-26-arm64`, a 3-core virtual Apple M1 runner.
- **Project:** an app with `IPHONEOS_DEPLOYMENT_TARGET = 15.0` and one plugin, all Swift packages, whose `Package.swift` declares `.iOS("15.0")`. SwiftPM is on (the 3.44 default). A Podfile still exists, so `pod install` runs too.

## Steps to reproduce

Deterministic, on any Mac, with no simulator:

1. In such an app, put a script named `xcrun` first on `PATH`. For `xcodebuild … -scheme Runner … -sdk iphonesimulator … -showBuildSettings` it sleeps 70 s, then runs the real `/usr/bin/xcrun` with the same arguments; every other call goes straight to the real one. (flutter_tools runs xcodebuild as `/usr/bin/arch -arm64e xcrun xcodebuild …`, so the script on `PATH` is used.)
2. `flutter build ios --config-only --simulator --debug`
3. `grep -n 'iOS(' ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift`
4. On Xcode 26.x: `xcodebuild build -workspace ios/Runner.xcworkspace -scheme Runner -destination 'generic/platform=iOS Simulator'`

Without the script, step 3 shows `.iOS("15.0")`. With it:
- step 2 takes about 2 minutes longer (two tries, 61 s apart), exits 0 and prints nothing about it (the error appears only with `-v`);
- step 3 shows `.iOS("13.0")`;
- step 4 fails Target Integrity as above.

A script that makes `-showBuildSettings` fail instead of sleep gives the same result; `-v` then shows "Unexpected failure to get Xcode build settings: … exit code 65".

On CI it happens on its own, about 2 runs in 40, in `flutter drive -d <simulator udid>` right after `xcrun simctl boot`. There the call runs with `-destination id=<udid>`.

## Expected

Either the raise happens; or flutter_tools says that it could not read the build settings and that the plugin package was left at 13.0; or the build stops with that message.

## Actual

`--config-only` exits 0, and a full build goes on to Xcode. The only visible error is Xcode's Target Integrity line, with a hint to raise a target that is already raised. On CI (`flutter drive`, without `-v`):

```
10:01:09.71 Adding Swift Package Manager integration...  25.0s
10:01:09.90 All plugins found for ios are Swift Packages, but your project still has CocoaPods integration. … non-standard Podfile …
10:03:34.74 Running pod install...  1,472ms
10:04:08.16 Xcode build done.  33.3s
10:04:10.34 Failed to build iOS app
10:04:10.35 Target Integrity (Xcode): The package product 'liquid-shell-ios' requires minimum platform version 15.0 for the iOS platform, but this target supports 13.0
10:04:10.35 To fix this error, increase your app's minimum platform version from 13.0 to at least 15.0 or remove the liquid-shell-ios dependency.
10:04:14.51 Application failed to start. Will not run test. Quitting.
```

The gap between the end of the migration and the end of `pod install` holds the `-showBuildSettings` call:

| Builds | Gap |
|---|---|
| the 2 failing `flutter drive` builds | 143.6 s and 147.6 s: two 60 s timeouts |
| 8 passing `flutter drive` builds | 9.9–79.7 s; 79.7 s fits one timeout, then a successful retry |
| 32 `flutter build ios --config-only` builds (generic simulator destination) | 2.8–9.4 s |

## Where it happens

`packages/flutter_tools/lib/src/` at 3.44.6:

- `macos/swift_package_manager.dart:118, 124`: the plugin package is generated with `platform.supportedPackagePlatform` (`darwin/darwin.dart:79`: iOS 13.0), and the manifest is overwritten on every build.
- `ios/mac.dart:288-294`: `buildXcodeProject` reads the build settings, `?? <String, String>{}`.
- `ios/xcodeproj.dart:234-304`: `getBuildSettings` runs `xcodebuild … -showBuildSettings` with `timeout = const Duration(minutes: 1)` (237) and `timeoutRetries: 1` (280), and with `-destination id=<deviceId>` when a device is given (266). On any exception it calls `_logger.printTrace('Unexpected failure to get Xcode build settings: …')` (299) and returns `{}` (300).
- `xcode_project.dart:350`: only non-empty settings are cached, so a later call in the same process tries again. The raise does not.
- `ios/mac.dart:352-361`: `if (iosDeploymentTarget != null) SwiftPackageManager.updateMinimumDeployment(…)`. With `{}` the raise is skipped silently, and `--config-only` returns right after (363).
- `macos/swift_package_manager.dart:431-456`: `updateMinimumDeployment`, the only code that replaces `.iOS("13.0")`.
- `ios/mac.dart:1319-1367`: the hint that tells the user to raise the app's minimum version.

## Suggested fix

Any one of these would turn the silent skip into a clear message or a working build:

1. **Say it.** When the build settings come back empty and Swift Package Manager is on, print a warning, not a trace, that the plugin package stays at the floor. Or fail with that message, instead of letting Xcode fail later with a misleading hint.
2. **Fall back.** When the call for a specific destination fails, read `IPHONEOS_DEPLOYMENT_TARGET` another way: once more with the generic destination (2.8–9.4 s in our data), or from the Xcode project file.
3. **Do not write the floor first.** Generate the plugin package with the app's deployment target in one step when it is known, rather than writing 13.0 and raising it only if a later call succeeds.

Our CI works around it by building once more when a build fails with this Target Integrity line.
