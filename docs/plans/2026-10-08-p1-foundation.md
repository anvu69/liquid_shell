# liquid_shell P1 Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the P1 foundation of `liquid_shell` (VK-345): a pub workspace of four federated packages plus `liquid_shell/example`, a router-agnostic adaptive `LiquidShell` with glass chrome, the glass tier seam, native accessibility/power signals, and the test, golden, doc and CI machinery, exactly as specified in `docs/specs/2026-10-08-p1-foundation-design.md` (commit 95b0996).

**Architecture:** `liquid_shell` (pure Flutter widgets) depends on `liquid_shell_platform_interface` (signal contract + one shared `EventChannel` implementation); `liquid_shell_ios` (Swift) and `liquid_shell_android` (Kotlin) only register that implementation and stream `{reduceTransparency, powerSave, blurDisabled}`. All drawing is Dart: `LiquidGlass` renders through a `LiquidGlassRenderer` chosen by `LiquidGlassPolicy` (frosted and solid built in), and `LiquidShell` lays out a bottom pill, a top pill + toggle, or an overlay/tiled `LiquidSidebar` from its own constraints while keeping `body` in one stable subtree.

**Tech Stack:** Flutter 3.38.10 / Dart 3.10.9 (floor; local loop via fvm `.fvmrc`), pub workspaces, `plugin_platform_interface` 2.1.8, `very_good_analysis` 10.1.0, `flutter_test` + `integration_test` + `flutter_driver`, Kotlin 2.2.20 / AGP 8.11.1 / JUnit 5, Swift 5 (CocoaPods + Swift Package Manager manifest), GitHub Actions (`subosito/flutter-action`, `reactivecircus/android-emulator-runner`), pana 0.23.12, Inter 4.1 (OFL) for goldens.

> **Tóm tắt cho chủ sản phẩm.** Kế hoạch này chia P1 thành 14 task. Mỗi task kết thúc bằng một thứ chạy được và review được độc lập: (1) dựng repo, công cụ, CI và kiểm rủi ro, (2) platform interface, (3) đọc tín hiệu native iOS/Android cùng test trên simulator/emulator, (4) bộ từ vựng kính (tầng, theme, renderer, policy), (5) widget `LiquidGlass`, (6) destination/badge/chuỗi, (7) `LiquidTabBar`, (8) `LiquidSidebar`, (9) luật bố cục thuần, (10) `LiquidShell`, (11) app example, (12) golden và ảnh tài liệu, (13) README và doc, (14) kiểm tra cuối. Toàn bộ kế hoạch đã chạy thử trên một bản sao: mọi test, golden, analyze, coverage (97,9%), test JVM Android, integration trên iPhone/iPad iOS 26.5 và emulator `tuvi_test` (API 36) đều xanh. Máy này cài được Flutter 3.38.10 bằng fvm, nên vòng làm việc local dùng đúng 3.38 (sàn), đã chạy chéo trên 3.44.6 cũng xanh. Rủi ro đã kiểm: `BackdropGroup` và `isShaderFilterSupported` có trên 3.38. Riêng pana: gói interface đạt tối đa khi code đã lên `main` của GitHub. Ba gói còn lại chưa thể chấm đủ điểm cho đến khi interface được publish (P6), nên kế hoạch để job pana của ba gói này ở chế độ chỉ báo. Có 2 câu hỏi cần anh xác nhận, ở bảng "Decisions needing owner confirmation".

## Global Constraints

Copied from the spec; every task implicitly includes them.

- Packages: `liquid_shell`, `liquid_shell_platform_interface`, `liquid_shell_ios`, `liquid_shell_android`, plus `liquid_shell/example` (inside the package, so pana credits it). Pub workspace root `liquid_shell_workspace`, `publish_to: none`. No melos, no Pigeon, no changelog tool.
- Every package: `environment: sdk: ^3.10.0, flutter: ">=3.38.0"`, version `0.1.0-dev.1`, `homepage`/`repository: https://github.com/anvu69/liquid_shell/tree/main/<package>`, `issue_tracker: https://github.com/anvu69/liquid_shell/issues`, `topics: [navigation, glassmorphism, adaptive-layout, tab-bar, sidebar]`, `resolution: workspace`.
- Runtime dependencies: Flutter, our federated packages and `plugin_platform_interface: ^2.1.8` only. No third-party UI, i18n, router, logger or equality package.
- `very_good_analysis` pinned to exactly `10.1.0`; each package's `analysis_options.yaml` includes it directly. Never loosen analysis to pass.
- Native floors: iOS 15.0; Android `compileSdk` 36, `minSdk` = Flutter's default.
- `LICENSE` in every package: MIT, `Copyright (c) 2026 lasoai.vn`.
- Channel: one `EventChannel` named `vn.lasoai.liquid_shell/signals`, standard codec, payload `{"reduceTransparency": bool, "powerSave": bool, "blurDisabled": bool}`; any failed read sends `false`.
- Every public class is `@immutable` unless it is a widget or state; value classes implement `==`/`hashCode` by hand with `Object.hash`.
- Public API names and signatures are binding (spec §4). `LiquidTabBar` and `LiquidSidebar` are exported (Q12).
- Provenance (spec §9): only SAFE code, re-typed into the new API with English comments; the two integration helpers flagged in §9 are written from the public `integration_test` docs without opening the originals; `tool/check_provenance.sh` rejects banned names outside `docs/`.
- Coverage ≥ 90% lines for `liquid_shell/lib` and `liquid_shell_platform_interface/lib` (Q14). Golden tolerance 0.5% of pixels; reference toolchain macOS + Flutter 3.38.x (Q11).
- Commits: `type(scope): summary`, scopes `shell glass platform ios android example docs ci`, each ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Branch `VK-345-p1-foundation`. Run `.githooks/pre-commit` by hand before each commit; never set `core.hooksPath`, never change git config, never push or create remotes.
- Nothing in the app repository changes in P1.

## Toolchain decision (Flutter 3.38 locally)

`fvm install 3.38.10 --setup` works on this machine (70 s, then `flutter precache --ios --android` for the engine artifacts). The repo pins it in `.fvmrc`; the `Makefile` calls `fvm flutter` when fvm is installed and plain `flutter` otherwise (CI). So **the local loop runs on 3.38.10**, the same as the blocking CI job and the golden reference. The dry run also ran the whole `liquid_shell` suite, analyze and every golden on **3.44.6** (the app's toolchain): all green, goldens inside the 0.5% tolerance. Latest stable (3.47.6 today) is covered only by the non-blocking CI jobs.

Executor setup, once:

```bash
fvm install 3.38.10 --setup
fvm flutter precache --ios --android
cd /Users/invoker/Projects/tuvi/liquid_shell
git checkout -b VK-345-p1-foundation
```

## Risk checks (spec §14), results

| Risk | Check | Result | Consequence for the plan |
|---|---|---|---|
| `BackdropGroup` / `BackdropFilter.grouped` missing on 3.38 | Source of 3.38.10 + `sdk_floor_test.dart` (Task 1) | Present (`basic.dart:466`, `:654`). `BackdropFilter.grouped` falls back to an ungrouped backdrop read when no `BackdropGroup` is above it | No fallback needed. The frosted renderer always uses `.grouped` |
| `ImageFilter.isShaderFilterSupported` missing on 3.38 | Same | Present (`painting.dart:4300`, `=> _impellerEnabled`); `false` under `flutter test` | `canBlur` uses it as specified; tests set `debugLiquidGlassCanBlurOverride = true` |
| `SemanticsService.sendAnnouncement` (sets the floor) | Same | Present; `tester.takeAnnouncements()` captures it on 3.38 | As specified |
| pana max score with workspace + SwiftPM | `pana 0.23.12` on the packages | The workspace itself is fine: pana resolves `resolution: workspace` packages and `pub publish --dry-run` passes for all four with 0 warnings. **Two limits**: (a) the 10 "valid pubspec" points need the package's `pubspec.yaml` on GitHub `main` (fails on any branch that adds a package, passes after merge); (b) `liquid_shell`, `liquid_shell_ios` and `liquid_shell_android` cannot resolve until `liquid_shell_platform_interface` is on pub.dev, so pana scores them ~40/160 before P6. `pubspec_overrides.yaml` does not help: pana ignores it. The spec's fallback (drop the workspace) would not fix either | CI `pana` job: interface at `--exit-code-threshold 0` on `main` (10 off branches); the three dependants informational until P6 publishes the interface first. Owner question O1 |
| Android "Reduce blur effects" | API 36 emulator `tuvi_test` (Android 16, BE2A.250530) | No such setting key exists on this image (`settings list` has only `disable_window_blurs`). `disable_window_blurs=1` flips `isCrossWindowBlurEnabled` → `blurDisabled: true` (verified) | Documented as best effort in `doc/tiers.md` |
| `wm disable-blur 1` (spec §10.5) | API 36 google_apis | `SecurityException` as the shell user | The script writes `settings put global disable_window_blurs 1`, which is what `wm disable-blur` writes |
| iOS Reduce Transparency has no supported `simctl` switch (§10.5) | `xcrun simctl spawn <udid> defaults write com.apple.Accessibility EnhancedBackgroundContrastEnabled -bool true`, then the integration test with `EXPECT_REDUCE_TRANSPARENCY=true` | Works on iOS 26.5: the channel reports `reduceTransparency: true` at launch. The key is undocumented | Task 14 uses it as an extra automated check; the live toggle in Settings stays the manual check the spec asks for |
| Swift Package Manager build | Example with per-project `enable-swift-package-manager` | `Package.swift` resolves; the app build then fails inside Flutter's own `debug_unpack_ios` lipo check under Xcode 27 on both 3.38.10 and 3.44.6 (toolchain issue, unrelated to the plugin). CocoaPods builds and runs | Ship the SwiftPM manifest; CI keeps CocoaPods. Owner question O2 |

## Decisions made while planning (spec gaps resolved, not owner questions)

| # | Spec says | Plan does | Why |
|---|---|---|---|
| D1 | `minSdk = flutter.minSdkVersion` | Plugin `build.gradle`: `minSdk = 24`; the example app keeps `flutter.minSdkVersion` | A plugin library module cannot read `flutter.minSdkVersion`; 24 is its value on 3.38 |
| D2 | Provenance check bans `go_router` everywhere outside `docs/` | Banned in every non-Markdown file | §12.2 requires `doc/router_integration.md` to show go_router wiring |
| D3 | §10.3 golden list | Adds `case_hide_chrome` (22 images) | §12.1 asks for one image per README case, and "hide chrome / no chrome" is a case |
| D4 | Internal tab bar with "bottom and top variants" | Public `enum LiquidTabBarPosition { bottom, top }` on `LiquidTabBar` | Q12 made the tab bar public; its variant needs a public parameter |
| D5 | Spec §5.10 AX threshold `textScaler.scale(14) / 14 ≥ 1.6` | As written (the app used 17pt) | Spec is binding |
| D6 | `make verify` equivalent | `Makefile` + `tool/check_coverage.dart` (a fixed 90% floor, no ratchet) | Q14 |
| D7 | Screenshot driver | `test_driver/integration_test.dart` saves `build/integration_screenshots/<run>.png`; the integration test takes one per run | §10.5 / §9 |
| D8 | Overlay barrier "blocks the semantics" | `BlockSemantics(child: ModalBarrier(...))` | Verified in the semantics tree: only sidebar rows and the barrier label remain |

## Decisions needing owner confirmation

> **Owner confirmed O1 and O2 as recommended (2026-10-08: "Ok").**

| # | Question | Recommended default | Impact if declined |
|---|---|---|---|
| O1 | Spec S9 asks for pana at max score in P1. Before the interface is on pub.dev, pana cannot resolve the other three packages. Accept "interface at max (on `main`), the other three informational until P6, which publishes the interface first"? | **Yes.** P6 flips the three to `--exit-code-threshold 0` right after publishing `liquid_shell_platform_interface` | Publishing the interface early would require a pub.dev release before P6, which the spec reserves for the owner |
| O2 | The SwiftPM build of an app on Xcode 27 fails in Flutter's own tooling (3.38.10 and 3.44.6). Ship `Package.swift` now and verify the SwiftPM app build when Flutter fixes it, with CocoaPods as the tested path? | **Yes.** Manifest ships (validated by package resolution); a manual SwiftPM build check is added to P6's release checklist | Without SwiftPM, newer Flutter projects that disable CocoaPods would not pick up the plugin |

## File structure

Created by this plan (generated platform boilerplate from `flutter create` omitted):

```
liquid_shell/                                   repo root
├─ pubspec.yaml  analysis_options.yaml  LICENSE  README.md  .gitignore  .fvmrc
├─ Makefile                                     one entry point per check
├─ CLAUDE.md  CONTRIBUTING.md                   TDD, commit, provenance rules
├─ .githooks/pre-commit                         run by hand
├─ .github/workflows/ci.yaml                    checks, pana, android-unit, integration-*, goldens
├─ tool/check_coverage.dart                     lcov floor (Q14)
├─ tool/check_provenance.sh                     §9 banned names
├─ tool/check_readme_snippets.dart              §12.3
├─ tool/update_goldens.sh                       §10.4
├─ tool/integration_ios.sh  tool/integration_android.sh   §10.5
├─ tool/test/                                   tests of the Dart tools
├─ liquid_shell_platform_interface/
│  └─ lib/src/{platform_signals,liquid_shell_platform,event_channel_platform}.dart
├─ liquid_shell_ios/  lib/liquid_shell_ios.dart, ios/liquid_shell_ios.podspec,
│                     ios/liquid_shell_ios/{Package.swift, Sources/liquid_shell_ios/*}
├─ liquid_shell_android/  lib/liquid_shell_android.dart,
│                     android/{build.gradle, src/main/kotlin/vn/lasoai/liquid_shell/*, src/test/...}
└─ liquid_shell/
   ├─ lib/liquid_shell.dart                     the only public library
   ├─ lib/src/glass/      tier, glass_theme, renderer, outside_shadow, frosted_renderer,
   │                      solid_renderer, policy, glass_scope, signals_controller, liquid_glass
   ├─ lib/src/destinations/  destination, badge, tab_action
   ├─ lib/src/chrome/     text_scale, large_content_viewer, tab_bar, sidebar, sidebar_toggle
   ├─ lib/src/shell/      strings, breakpoints, shell_layout, bar_measure, chrome_builder,
   │                      shell_scope, liquid_shell
   ├─ test/{unit,widget,helpers}/  flutter_test_config.dart
   ├─ doc/{theming,tiers,router_integration}.md  doc/images/*.png (generated)
   └─ example/  lib/{main.dart, cases/*, support/*}, test/{cases_smoke_test, goldens/*,
                support/golden_harness, fonts/*}, integration_test/, test_driver/
```

Responsibilities: one file per concept; `shell_layout.dart` holds every pure layout rule so `liquid_shell.dart` only wires state and widgets. Private helpers that tests need (`FrostedGlassRenderer`, `LargeContentViewer`, `SidebarToggle`, `shell_layout` functions) live in `lib/src` and are not exported.

All commands below run from `/Users/invoker/Projects/tuvi/liquid_shell` unless a step says otherwise.

---

### Task 1: Bootstrap the workspace, tooling, CI and risk checks

**Files:**
- Create: `pubspec.yaml`, `analysis_options.yaml`, `LICENSE`, `README.md`, `.gitignore`, `.fvmrc`, `Makefile`, `CLAUDE.md`, `CONTRIBUTING.md`, `.githooks/pre-commit`, `.github/workflows/ci.yaml`
- Create: `tool/check_coverage.dart`, `tool/check_provenance.sh`, `tool/test/check_coverage_test.dart`
- Create, per package `P` in `liquid_shell liquid_shell_platform_interface liquid_shell_ios liquid_shell_android`: `P/pubspec.yaml`, `P/analysis_options.yaml`, `P/LICENSE`, `P/CHANGELOG.md`, `P/README.md`, `P/lib/P.dart`; `example/example.md` for the three non-app packages
- Create: `liquid_shell/dart_test.yaml`, `liquid_shell/test/unit/sdk_floor_test.dart`
- Create (via `flutter create`, then edited): `liquid_shell/example/**` with `pubspec.yaml`, `analysis_options.yaml`, `dart_test.yaml`, `lib/main.dart`, `ios/Podfile`

**Interfaces:**
- Consumes: nothing.
- Produces: `make` targets `get format format-check analyze test coverage goldens goldens-update provenance snippets verify pana publish-check android-unit integration-ios integration-android` (`goldens`/`snippets` print "no … yet" until Tasks 12/13 add them); `tool/check_coverage.dart` with `class LineCoverage { const LineCoverage({required int found, required int hit}); factory LineCoverage.parse(String lcov); double get percent; bool meets(double floor); }` and CLI `dart run tool/check_coverage.dart <lcov.info> <min-percent>`; `tool/check_provenance.sh` (exit 1 on a banned name); tag `golden` declared in both `dart_test.yaml`.

- [ ] **Step 1: Workspace root and licence**

`pubspec.yaml`:

```yaml
name: liquid_shell_workspace
description: Workspace root for the liquid_shell federated packages. Not published.
publish_to: none

environment:
  sdk: ^3.10.0

workspace:
  - liquid_shell
  - liquid_shell/example
  - liquid_shell_platform_interface
  - liquid_shell_ios
  - liquid_shell_android

dev_dependencies:
  test: ^1.26.0
  very_good_analysis: 10.1.0
```

`analysis_options.yaml` (root, for `tool/` only):

```yaml
# Root options cover tool/ only. Every package has its own
# analysis_options.yaml, because pana analyses a package on its own.
include: package:very_good_analysis/analysis_options.yaml

analyzer:
  exclude:
    - liquid_shell/**
    - liquid_shell_platform_interface/**
    - liquid_shell_ios/**
    - liquid_shell_android/**
```

`LICENSE` (copy the same file into each package in Step 3):

```text
MIT License

Copyright (c) 2026 lasoai.vn

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

`.gitignore`:

```gitignore
# Dart / Flutter
.dart_tool/
.packages
build/
coverage/
pubspec_overrides.yaml
.flutter-plugins
.flutter-plugins-dependencies
**/doc/api/

# Golden failures (diff images from a failed golden run)
**/failures/

# fvm: the SDK symlink is per machine; .fvmrc is committed
.fvm/

# IDE / OS
.idea/
*.iml
.vscode/
.DS_Store

# Libraries do not commit lock files; CI and pana resolve fresh.
pubspec.lock

# CocoaPods lock of the example app (regenerated per toolchain)
liquid_shell/example/ios/Podfile.lock
```

`.fvmrc`:

```json
{
  "flutter": "3.38.10"
}
```

`README.md`:

```markdown
# liquid_shell

Adaptive navigation shell with a Liquid Glass look for iOS and Android.

The app-facing package and its documentation live in
[`liquid_shell/`](liquid_shell/README.md).

| Package | Role |
|---|---|
| [`liquid_shell`](liquid_shell/) | Widgets: `LiquidShell`, `LiquidTabBar`, `LiquidSidebar`, `LiquidGlass` |
| [`liquid_shell_platform_interface`](liquid_shell_platform_interface/) | Platform signal contract |
| [`liquid_shell_ios`](liquid_shell_ios/) | iOS signals (Swift) |
| [`liquid_shell_android`](liquid_shell_android/) | Android signals (Kotlin) |

Contributors: read [CONTRIBUTING.md](CONTRIBUTING.md) first.

MIT licensed. See [LICENSE](LICENSE).
```

- [ ] **Step 2: The four package pubspecs**

`liquid_shell/pubspec.yaml` (the `flutter.plugin` section arrives in Task 3, with the native code it points to):

```yaml
name: liquid_shell
description: Adaptive navigation shell with a Liquid Glass look for iOS and Android. A floating tab bar on phones and a glass sidebar on tablets, with no router dependency.
version: 0.1.0-dev.1
homepage: https://github.com/anvu69/liquid_shell/tree/main/liquid_shell
repository: https://github.com/anvu69/liquid_shell/tree/main/liquid_shell
issue_tracker: https://github.com/anvu69/liquid_shell/issues
topics: [navigation, glassmorphism, adaptive-layout, tab-bar, sidebar]
resolution: workspace

environment:
  sdk: ^3.10.0
  flutter: ">=3.38.0"

dependencies:
  flutter:
    sdk: flutter
  liquid_shell_android: ^0.1.0-dev.1
  liquid_shell_ios: ^0.1.0-dev.1
  liquid_shell_platform_interface: ^0.1.0-dev.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  very_good_analysis: 10.1.0
```

`liquid_shell_platform_interface/pubspec.yaml`:

```yaml
name: liquid_shell_platform_interface
description: A common platform interface for the liquid_shell plugin. It carries the accessibility and power signals that make the glass fall back to a solid fill.
version: 0.1.0-dev.1
homepage: https://github.com/anvu69/liquid_shell/tree/main/liquid_shell_platform_interface
repository: https://github.com/anvu69/liquid_shell/tree/main/liquid_shell_platform_interface
issue_tracker: https://github.com/anvu69/liquid_shell/issues
topics: [navigation, glassmorphism, adaptive-layout, tab-bar, sidebar]
resolution: workspace

environment:
  sdk: ^3.10.0
  flutter: ">=3.38.0"

dependencies:
  flutter:
    sdk: flutter
  plugin_platform_interface: ^2.1.8

dev_dependencies:
  flutter_test:
    sdk: flutter
  very_good_analysis: 10.1.0
```

`liquid_shell_ios/pubspec.yaml`:

```yaml
name: liquid_shell_ios
description: The iOS implementation of the liquid_shell plugin. Reads Reduce Transparency through UIAccessibility.
version: 0.1.0-dev.1
homepage: https://github.com/anvu69/liquid_shell/tree/main/liquid_shell_ios
repository: https://github.com/anvu69/liquid_shell/tree/main/liquid_shell_ios
issue_tracker: https://github.com/anvu69/liquid_shell/issues
topics: [navigation, glassmorphism, adaptive-layout, tab-bar, sidebar]
resolution: workspace

environment:
  sdk: ^3.10.0
  flutter: ">=3.38.0"

dependencies:
  flutter:
    sdk: flutter
  liquid_shell_platform_interface: ^0.1.0-dev.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  very_good_analysis: 10.1.0
```

`liquid_shell_android/pubspec.yaml`:

```yaml
name: liquid_shell_android
description: The Android implementation of the liquid_shell plugin. Reads reduce transparency, battery saver and the system blur switch.
version: 0.1.0-dev.1
homepage: https://github.com/anvu69/liquid_shell/tree/main/liquid_shell_android
repository: https://github.com/anvu69/liquid_shell/tree/main/liquid_shell_android
issue_tracker: https://github.com/anvu69/liquid_shell/issues
topics: [navigation, glassmorphism, adaptive-layout, tab-bar, sidebar]
resolution: workspace

environment:
  sdk: ^3.10.0
  flutter: ">=3.38.0"

dependencies:
  flutter:
    sdk: flutter
  liquid_shell_platform_interface: ^0.1.0-dev.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  very_good_analysis: 10.1.0
```

- [ ] **Step 3: Per-package files**

```bash
for p in liquid_shell liquid_shell_platform_interface liquid_shell_ios liquid_shell_android; do
  cp LICENSE $p/LICENSE
  printf 'include: package:very_good_analysis/analysis_options.yaml\n' > $p/analysis_options.yaml
  printf '## 0.1.0-dev.1\n\n- Initial development release.\n' > $p/CHANGELOG.md
done
mkdir -p liquid_shell/lib liquid_shell/test/unit tool/test .githooks .github/workflows
```

`liquid_shell/lib/liquid_shell.dart`:

```dart
/// Adaptive navigation shell with a Liquid Glass look for iOS and Android.
library;
```

`liquid_shell_platform_interface/lib/liquid_shell_platform_interface.dart`:

```dart
/// Platform interface for liquid_shell.
library;
```

`liquid_shell_ios/lib/liquid_shell_ios.dart`:

```dart
/// iOS implementation of liquid_shell.
library;
```

`liquid_shell_android/lib/liquid_shell_android.dart`:

```dart
/// Android implementation of liquid_shell.
library;
```

`liquid_shell/README.md` (placeholder; Task 13 writes the full guide):

```markdown
# liquid_shell

Adaptive navigation shell with a Liquid Glass look for iOS and Android: a
floating glass tab bar on phones and a glass sidebar on tablets, with no
router dependency.

Status: under development (`0.1.0-dev`). The full guide arrives with the
first usable release.

## License

MIT. See [LICENSE](LICENSE).
```

`liquid_shell_platform_interface/README.md`:

````markdown
# liquid_shell_platform_interface

A common platform interface for the [`liquid_shell`][app] plugin.

It defines `LiquidShellPlatform`, the stream of `LiquidPlatformSignals`
(reduce transparency, battery saver, system blur disabled) that make
`liquid_shell` glass fall back to a solid fill, and the event-channel
implementation shared by the iOS and Android packages.

## Usage

Apps do not use this package directly. Depend on [`liquid_shell`][app].

To implement a new platform, extend `LiquidShellPlatform` and set
`LiquidShellPlatform.instance` from your package's `registerWith()`:

```dart
class LiquidShellMyOS extends LiquidShellPlatform {
  static void registerWith() {
    LiquidShellPlatform.instance = LiquidShellMyOS();
  }

  @override
  Stream<LiquidPlatformSignals> watchSignals() =>
      Stream.value(LiquidPlatformSignals.none);
}
```

## License

MIT. See [LICENSE](LICENSE).

[app]: https://pub.dev/packages/liquid_shell
````

`liquid_shell_ios/README.md`:

```markdown
# liquid_shell_ios

The iOS implementation of [`liquid_shell`][app].

It reports Reduce Transparency (`UIAccessibility.isReduceTransparencyEnabled`). iOS 15.0 or later. Ships for CocoaPods and Swift Package Manager.

## Usage

This package is [endorsed][endorsed]: depend on `liquid_shell` and it is
added to your app automatically. You never import it.

## License

MIT. See [LICENSE](LICENSE).

[app]: https://pub.dev/packages/liquid_shell
[endorsed]: https://docs.flutter.dev/packages-and-plugins/developing-packages#endorsed-federated-plugin
```

`liquid_shell_android/README.md`:

```markdown
# liquid_shell_android

The Android implementation of [`liquid_shell`][app].

It reports reduce transparency (animator duration scale 0 or high contrast), battery saver (`PowerManager.isPowerSaveMode`) and system blur disabled (`WindowManager.isCrossWindowBlurEnabled`, API 31+). No permissions.

## Usage

This package is [endorsed][endorsed]: depend on `liquid_shell` and it is
added to your app automatically. You never import it.

## License

MIT. See [LICENSE](LICENSE).

[app]: https://pub.dev/packages/liquid_shell
[endorsed]: https://docs.flutter.dev/packages-and-plugins/developing-packages#endorsed-federated-plugin
```

`liquid_shell_platform_interface/example/example.md` (identical file in `liquid_shell_ios/example/` and `liquid_shell_android/example/`):

````markdown
# Example

This package is part of the federated [`liquid_shell`](https://pub.dev/packages/liquid_shell)
plugin. The runnable example app lives in
[`liquid_shell/example`](https://github.com/anvu69/liquid_shell/tree/main/liquid_shell/example).

```dart
import 'package:liquid_shell/liquid_shell.dart';
```
````

`liquid_shell/dart_test.yaml` (identical file at `liquid_shell/example/dart_test.yaml`):

```yaml
tags:
  golden:
```

- [ ] **Step 4: Create the example app (iOS 15.0)**

```bash
cd liquid_shell
fvm flutter create --platforms=ios,android --org vn.lasoai --project-name liquid_shell_example --no-pub example
cd example
rm -f test/widget_test.dart liquid_shell_example.iml README.md
rmdir test
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = 13.0;/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/' ios/Runner.xcodeproj/project.pbxproj
/usr/libexec/PlistBuddy -c "Set :MinimumOSVersion 15.0" ios/Flutter/AppFrameworkInfo.plist
printf 'include: package:very_good_analysis/analysis_options.yaml\n' > analysis_options.yaml
cp ../dart_test.yaml dart_test.yaml
cd ../..
grep -c "IPHONEOS_DEPLOYMENT_TARGET = 15.0" liquid_shell/example/ios/Runner.xcodeproj/project.pbxproj
```

Expected: `3`.

Replace `liquid_shell/example/pubspec.yaml`:

```yaml
name: liquid_shell_example
description: Example app for liquid_shell. One screen per documented case.
publish_to: none
version: 1.0.0+1
resolution: workspace

environment:
  sdk: ^3.10.0
  flutter: ">=3.38.0"

dependencies:
  flutter:
    sdk: flutter
  liquid_shell: ^0.1.0-dev.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  very_good_analysis: 10.1.0

flutter:
  uses-material-design: true
```

Replace `liquid_shell/example/lib/main.dart` (placeholder until Task 11):

```dart
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

/// Placeholder until Task 9 adds the case list.
class ExampleApp extends StatelessWidget {
  /// Creates the example app.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(body: Center(child: Text('liquid_shell example'))),
  );
}
```

Create `liquid_shell/example/ios/Podfile` (Xcode 27 rejects pods below iOS 15.0; without the `post_install` override the Flutter pod's 13.0 target fails the build):

```ruby
# Xcode 27 rejects deployment targets below iOS 15.0 (spec Q16).
platform :ios, '15.0'

# CocoaPods analytics sends network stats synchronously affecting flutter build latency.
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist. If you're running pod install manually, make sure flutter pub get is executed first"
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}. Try deleting Generated.xcconfig, then run flutter pub get"
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))
  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end
```

- [ ] **Step 5: Write the failing coverage-tool test**

`tool/test/check_coverage_test.dart`:

```dart
import 'package:test/test.dart';

import '../check_coverage.dart';

void main() {
  group('LineCoverage.parse', () {
    test('sums LF and LH over every record', () {
      const lcov = '''
SF:lib/a.dart
DA:1,1
LF:10
LH:9
end_of_record
SF:lib/b.dart
LF:30
LH:21
end_of_record
''';
      final coverage = LineCoverage.parse(lcov);
      expect(coverage.found, 40);
      expect(coverage.hit, 30);
      expect(coverage.percent, 75);
    });

    test('an empty report is 100 percent (nothing to cover)', () {
      expect(LineCoverage.parse('').percent, 100);
    });

    test('ignores records outside lib/', () {
      const lcov = '''
SF:test/helper.dart
LF:10
LH:0
end_of_record
SF:lib/a.dart
LF:4
LH:4
end_of_record
''';
      expect(LineCoverage.parse(lcov).percent, 100);
    });
  });

  group('LineCoverage.meets', () {
    test('is inclusive of the floor', () {
      const coverage = LineCoverage(found: 10, hit: 9);
      expect(coverage.meets(90), isTrue);
      expect(coverage.meets(90.1), isFalse);
    });
  });
}
```

Run: `fvm flutter pub get && fvm dart test tool/test`
Expected: FAIL, `Error: Error when reading 'tool/check_coverage.dart': No such file or directory`.

- [ ] **Step 6: Implement `tool/check_coverage.dart`**

```dart
// Fails when line coverage of lib/ in an lcov report is below a floor.
//
// Usage: dart run tool/check_coverage.dart <lcov.info> <min-percent>
import 'dart:io';

/// Line coverage summed over the `lib/` records of an lcov report.
class LineCoverage {
  /// Creates a coverage summary from raw counts.
  const LineCoverage({required this.found, required this.hit});

  /// Parses an lcov report. Records whose `SF:` path has no `lib/` segment
  /// (test helpers, generated test files) are ignored.
  factory LineCoverage.parse(String lcov) {
    var found = 0;
    var hit = 0;
    var inLib = false;
    for (final line in lcov.split('\n')) {
      if (line.startsWith('SF:')) {
        final path = line.substring(3).replaceAll(r'\', '/');
        inLib = path.startsWith('lib/') || path.contains('/lib/');
      } else if (inLib && line.startsWith('LF:')) {
        found += int.parse(line.substring(3));
      } else if (inLib && line.startsWith('LH:')) {
        hit += int.parse(line.substring(3));
      }
    }
    return LineCoverage(found: found, hit: hit);
  }

  /// Instrumented lines.
  final int found;

  /// Lines executed at least once.
  final int hit;

  /// Percentage of [found] lines that were hit. 100 when nothing is
  /// instrumented.
  double get percent => found == 0 ? 100 : hit * 100 / found;

  /// Whether [percent] is at least [floor].
  bool meets(double floor) => percent >= floor;
}

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('usage: check_coverage.dart <lcov.info> <min-percent>');
    exit(64);
  }
  final file = File(args[0]);
  if (!file.existsSync()) {
    stderr.writeln('✗ ${args[0]} not found. Run flutter test --coverage.');
    exit(1);
  }
  final floor = double.parse(args[1]);
  final coverage = LineCoverage.parse(file.readAsStringSync());
  final summary =
      '${coverage.percent.toStringAsFixed(2)}% '
      '(${coverage.hit}/${coverage.found} lines) in ${args[0]}';
  if (!coverage.meets(floor)) {
    stderr.writeln('✗ coverage $summary is below $floor%');
    exit(1);
  }
  stdout.writeln('✓ coverage $summary ≥ $floor%');
}
```

Run: `fvm dart test tool/test`
Expected: `+4: All tests passed!`

- [ ] **Step 7: Provenance gate**

`tool/check_provenance.sh` (it scans tracked files plus untracked files `.gitignore` keeps, so generated build files with local paths never trip it):

```bash
#!/usr/bin/env bash
# Provenance gate (spec §9). Fails if any file outside docs/ names the source
# app, its i18n/DI/theme symbols, or the project whose test helpers must be
# rewritten. go_router is allowed in Markdown only, because
# liquid_shell/doc/router_integration.md teaches that wiring (spec §12.2).
#
# Scans tracked files plus untracked files that .gitignore does not ignore,
# so generated build files with local absolute paths never trip it.
set -euo pipefail
cd "$(dirname "$0")/.."

banned='vankhan|Văn Khấn|calculator_promax|LocaleKeys|easy_localization|AppColors|AppGlassColors|GetIt'
outside_docs=(-- . ':!docs/' ':!tool/check_provenance.sh')
status=0

if git grep --untracked -n -I -i -E "$banned" "${outside_docs[@]}"; then
  status=1
fi
if git grep --untracked -n -I -E 'go_router' "${outside_docs[@]}" ':!*.md'; then
  status=1
fi

if [ "$status" -ne 0 ]; then
  echo "✗ provenance: banned name found (spec §9). Remove it." >&2
  exit 1
fi
echo "✓ provenance clean"
```

```bash
chmod +x tool/check_provenance.sh
tool/check_provenance.sh
echo "import 'package:go_router/go_router.dart';" > probe.dart && tool/check_provenance.sh; echo "exit=$?"; rm probe.dart
```

Expected: `✓ provenance clean`, then `probe.dart:1:import 'package:go_router/go_router.dart';`, `✗ provenance: banned name found (spec §9). Remove it.` and `exit=1`.

- [ ] **Step 8: Risk probe for the 3.38 floor**

`liquid_shell/test/unit/sdk_floor_test.dart`. It compiles only if `BackdropGroup`, `BackdropFilter.grouped`, `ImageFilter.isShaderFilterSupported` and `SemanticsService.sendAnnouncement` exist, so the blocking CI job guards the floor:

```dart
// Risk probe (spec §14, plan Task 1): the Flutter 3.38 floor must provide
// every engine/framework API the glass and the minimised tab bar rely on.
// This file only compiles if they exist, so CI's 3.38.x job guards the floor.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ImageFilter.isShaderFilterSupported is a bool getter', () {
    expect(ui.ImageFilter.isShaderFilterSupported, isA<bool>());
  });

  test('SemanticsService.sendAnnouncement exists', () {
    expect(SemanticsService.sendAnnouncement, isA<Function>());
  });

  testWidgets('BackdropFilter.grouped renders inside a BackdropGroup', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: BackdropGroup(
          child: Stack(
            children: [
              const ColoredBox(color: Color(0xFF2196F3)),
              BackdropFilter.grouped(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: const SizedBox.square(dimension: 40),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(
      BackdropGroup.of(tester.element(find.byType(BackdropFilter))),
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
}
```

Run: `cd liquid_shell && fvm flutter test test/unit/sdk_floor_test.dart; cd ..`
Expected: `+3: All tests passed!` on 3.38.10. **If it fails to compile** (it did not in the dry run): apply spec §14. The frosted renderer uses plain `BackdropFilter`; `liquidGlassCanBlur()` uses the Android API level (≤ 28 → false), read through the platform signal channel; and record the change in this plan.

- [ ] **Step 9: Makefile, hook, CI, contributor rules**

`Makefile` (recipe lines are tabs):

```makefile
# liquid_shell: one entry point per check. CI, the pre-commit hook and
# contributors all call these targets, so "green" has exactly one definition.
#
# The SDK comes from fvm when it is installed (.fvmrc pins the floor, 3.38.10),
# otherwise from the flutter on PATH (CI). Override with FLUTTER=... DART=...

FVM := $(shell command -v fvm 2>/dev/null)
FLUTTER ?= $(if $(FVM),fvm flutter,flutter)
DART ?= $(if $(FVM),fvm dart,dart)

PACKAGES := liquid_shell liquid_shell_platform_interface liquid_shell_ios liquid_shell_android
EXAMPLE := liquid_shell/example
# Packages whose lib/ must keep >= COVERAGE_MIN % line coverage (spec Q14).
# As executed: Task 2 starts with liquid_shell_platform_interface only (a
# barrel-only liquid_shell instruments 0 lines); Task 3 adds
# tool/check_covered.dart, which fails `make coverage` when a package whose
# lib/ has code is missing here, so liquid_shell rejoins in the task that
# gives its lib/ code.
COVERED := liquid_shell liquid_shell_platform_interface
COVERAGE_MIN := 90

.PHONY: help get format format-check analyze test coverage goldens \
        goldens-update provenance snippets verify pana publish-check \
        android-unit integration-ios integration-android

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

get: ## Resolve the whole pub workspace
	$(FLUTTER) pub get

format: ## Rewrite formatting in place (a fixer, not a gate)
	$(DART) format .

format-check: ## Formatting gate: check only, never rewrite
	$(DART) format --output=none --set-exit-if-changed .

analyze: ## Static analysis; infos and warnings are fatal
	$(FLUTTER) analyze --fatal-infos --fatal-warnings

test: ## Unit and widget tests in every package and the example (no goldens)
	@set -e; for p in $(PACKAGES) $(EXAMPLE); do \
	  if [ -d $$p/test ]; then \
	    echo "▸ test $$p"; \
	    (cd $$p && $(FLUTTER) test --exclude-tags golden); \
	  fi; \
	done
	$(DART) test tool/test

coverage: ## Tests with coverage; fails below COVERAGE_MIN for COVERED packages
	@set -e; for p in $(COVERED); do \
	  if [ -d $$p/test ]; then \
	    echo "▸ coverage $$p"; \
	    (cd $$p && $(FLUTTER) test --exclude-tags golden --coverage); \
	    $(DART) run tool/check_coverage.dart $$p/coverage/lcov.info $(COVERAGE_MIN); \
	  fi; \
	done

goldens: ## Golden tests (reference toolchain: macOS + Flutter 3.38.x)
	@if [ -d $(EXAMPLE)/test/goldens ]; then \
	  cd $(EXAMPLE) && $(FLUTTER) test --tags golden; \
	else echo "▸ no goldens yet"; fi

goldens-update: ## Regenerate every golden and doc image
	FLUTTER="$(FLUTTER)" tool/update_goldens.sh

provenance: ## Fail on app names or banned dependencies outside docs/
	tool/check_provenance.sh

snippets: ## README snippets must equal their #docregion in example/lib/cases
	@if [ -f tool/check_readme_snippets.dart ]; then \
	  $(DART) run tool/check_readme_snippets.dart; \
	else echo "▸ no snippet check yet"; fi

verify: format-check analyze provenance test coverage goldens snippets ## Everything CI's blocking jobs run
	@echo "✓ verify passed"

pana: ## pana for each package (see docs/plans: pre-publish limits)
	@set -e; for p in $(PACKAGES); do \
	  echo "▸ pana $$p"; \
	  $(DART) pub global run pana --no-warning $$p; \
	done

publish-check: ## pub publish --dry-run for each package
	@set -e; for p in $(PACKAGES); do \
	  echo "▸ publish --dry-run $$p"; \
	  (cd $$p && $(FLUTTER) pub publish --dry-run); \
	done

android-unit: ## JVM unit tests of the Android plugin (SignalReaderTest)
	cd $(EXAMPLE) && $(FLUTTER) build apk --debug --config-only
	cd $(EXAMPLE)/android && ./gradlew :liquid_shell_android:testDebugUnitTest

integration-ios: ## Signal channel round-trip on an iOS simulator
	FLUTTER="$(FLUTTER)" tool/integration_ios.sh

integration-android: ## Signal channel + every Android signal on an emulator
	FLUTTER="$(FLUTTER)" tool/integration_android.sh
```

`.githooks/pre-commit` (then `chmod +x .githooks/pre-commit`):

```bash
#!/usr/bin/env bash
# Pre-commit gate. Run it BY HAND before every commit:
#
#   .githooks/pre-commit && git commit ...
#
# Never wire it with `git config core.hooksPath` (repo rule: nobody changes
# git config). It runs the fast half of `make verify`; coverage and goldens
# run in `make verify` before a PR.
set -euo pipefail
cd "$(dirname "$0")/.."

# When git runs a hook it exports GIT_DIR and friends. flutter reads its own
# version with `git describe` inside the SDK checkout; with GIT_DIR pointing
# here it reports 0.0.0-unknown and pub rejects every SDK constraint.
nogit() { env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_PREFIX "$@"; }

[ -f .dart_tool/package_config.json ] || {
  echo "✗ Workspace not resolved. Run: make get" >&2
  exit 1
}

for target in format-check analyze provenance test; do
  echo "▸ pre-commit: $target"
  nogit make --no-print-directory "$target"
done
echo "✓ pre-commit passed"
```

`.github/workflows/ci.yaml` (Tasks 3 and 12 append jobs):

```yaml
name: ci

on:
  push:
    branches: [main]
  pull_request:

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

# Flutter 3.38.x is the supported floor and blocks merges. Latest stable runs
# as an early warning and never blocks (continue-on-error).
jobs:
  checks:
    name: checks (${{ matrix.flutter }})
    runs-on: ubuntu-latest
    continue-on-error: ${{ matrix.experimental }}
    strategy:
      fail-fast: false
      matrix:
        include:
          - flutter: 3.38.x
            experimental: false
          - flutter: stable
            experimental: true
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: ${{ matrix.flutter == 'stable' && '' || matrix.flutter }}
          cache: true
      - run: make get
      - run: make format-check
      - run: make analyze
      - run: make provenance
      - run: make test
      - run: make coverage
      - run: make snippets

  pana:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: make get
      - run: dart pub global activate pana
      # pana checks that `repository` on GitHub main contains this pubspec.
      # On a branch that adds a package, main does not have it yet, so those
      # 10 points are allowed off main only.
      - name: pana liquid_shell_platform_interface (max score on main)
        run: >
          dart pub global run pana --no-warning
          --exit-code-threshold ${{ github.ref == 'refs/heads/main' && '0' || '10' }}
          liquid_shell_platform_interface
      # These three depend on liquid_shell_platform_interface, which pana can
      # only resolve from pub.dev. Informational until P6 publishes it first.
      - name: pana dependants (informational until P6)
        continue-on-error: true
        run: |
          for p in liquid_shell liquid_shell_ios liquid_shell_android; do
            dart pub global run pana --no-warning --exit-code-threshold 0 "$p"
          done
      - run: make publish-check
```

`CONTRIBUTING.md`:

````markdown
# Contributing to liquid_shell

## Toolchain

- Flutter **3.38.10** is the floor and the golden reference (`.fvmrc`).
  With [fvm](https://fvm.app) installed, `make` uses it automatically:
  `fvm install 3.38.10`, then `make get`.
- Without fvm, put a Flutter 3.38.x on `PATH`, or run
  `make verify FLUTTER=/path/to/flutter DART=/path/to/dart`.
- Goldens are only valid on macOS with Flutter 3.38.x (spec Q11).

## Commands

| Command | What it does |
|---|---|
| `make get` | Resolve the pub workspace (all packages and the example) |
| `make format` | Rewrite formatting in place |
| `make verify` | format-check, analyze, provenance, tests, coverage ≥ 90 %, goldens, README snippets. **Must be green before a PR.** |
| `make goldens-update` | Regenerate goldens and `liquid_shell/doc/images` (macOS + 3.38 only) |
| `make android-unit` | Kotlin JVM tests of the Android plugin |
| `make integration-ios` / `make integration-android` | Signal channel tests on a simulator / emulator |
| `make pana` / `make publish-check` | pub.dev scoring and publish dry-run |

## Pre-commit gate

Run the hook **by hand** before every commit:

```bash
.githooks/pre-commit && git commit
```

Do not install it with `git config core.hooksPath`; nobody changes git
config in this repo.

## Test-driven development (mandatory)

1. Write the test. Run it. **Watch it fail for the right reason.**
2. Write the smallest code that makes it pass. Run it. Green.
3. Refactor, keep it green, commit.

Production code written before a failing test is deleted and rewritten. A
bug fix starts with a test that reproduces the bug.

## Commits and branches

- Branch: `<PLANE-ID>-<short-slug>`, for example `VK-345-p1-foundation`.
- Commit: `<type>(<scope>): <summary>`. Types: `feat fix refactor docs test
  chore perf ci`. Scopes: `shell glass platform ios android example docs ci`.
- Every plan task ends in at least one commit, and every commit is green.
- A PR body links the Plane work item and pastes the `make verify` output.

## Provenance (open source, MIT)

- Only code we wrote goes in. Code ported from our app is **re-typed** into
  the new API with new names and English comments; no app names, ticket
  numbers or Vietnamese comments.
- The two integration-test helpers named in spec §9 are **rewritten from the
  public `integration_test` documentation**, never copied, and the person
  writing them must not open the originals.
- No app assets, screenshots, fonts or brand colours.
- `tool/check_provenance.sh` (run by `make verify`, the hook and CI) rejects
  banned names outside `docs/`.
- Every package `LICENSE` is MIT, `Copyright (c) 2026 lasoai.vn`.
- Third-party code needs a compatible licence and its notice. Fonts used by
  tests ship with their OFL text.

## Dependencies

Runtime dependencies are Flutter, our own federated packages and
`plugin_platform_interface` only. Adding anything else needs a spec change.
`very_good_analysis` stays pinned to `10.1.0`.
````

`CLAUDE.md`:

````markdown
# CLAUDE.md — liquid_shell

Binding rules for every session in this repo. Details: `CONTRIBUTING.md`,
the spec in `docs/specs/`, and the plan in `docs/plans/`.

## Before typing

1. Is there a Plane work item (VK-…)? No → stop and ask.
2. Is there an approved spec? No → `superpowers:brainstorming`. No code.
3. Is there a plan? No → `superpowers:writing-plans`. No code.

## Hard rules

- **TDD.** No production code without a test that failed first for the
  right reason (`superpowers:test-driven-development`).
- **Evidence.** Never say "done" without running `make verify` (or the
  task's commands) and pasting the output
  (`superpowers:verification-before-completion`).
- **Pre-commit by hand.** `.githooks/pre-commit && git commit`. Never set
  `core.hooksPath`; never change git config. `--no-verify` is not an option.
- **Commits.** `<type>(<scope>): <summary>`, scopes `shell glass platform
  ios android example docs ci`, ending with the Co-Authored-By line.
- **No pushes, no remotes, no publishing** without the owner's explicit
  go-ahead.
- **Provenance.** Re-type ported code in English with new names. Rewrite the
  two integration helpers named in spec §9 from public docs without opening
  the originals. `make provenance` must stay green.
- **Dependencies.** Flutter + our packages + `plugin_platform_interface`.
  Nothing else at runtime. `very_good_analysis` pinned to 10.1.0.
- **Never loosen `analysis_options.yaml`** to get code through. Fix the code.
- **Goldens** are regenerated only with `make goldens-update` on macOS +
  Flutter 3.38.10. Never edit images by hand.

## Commands

```bash
make get        # resolve the workspace
make verify     # everything blocking CI runs; green before any PR
make goldens-update
make android-unit
make integration-ios
make integration-android
```
````

- [ ] **Step 10: Verify the bootstrap**

Run: `make get && make verify`
Expected (tail):
```
No issues found!
✓ provenance clean
✓ coverage 100.00% (0/0 lines) in liquid_shell/coverage/lcov.info ≥ 90.0%
▸ no goldens yet
▸ no snippet check yet
✓ verify passed
```

Run: `make publish-check`
Expected: `Package has 0 warnings.` four times (uncommitted files show as a warning; run it after the commit if needed).

Run the pana probe on the interface (needs `fvm dart pub global activate pana` once):
`fvm dart pub global run pana --no-warning --flutter-sdk ~/fvm/versions/3.38.10 liquid_shell_platform_interface | tail -1`
Expected before the code is on GitHub `main`: `Points: 150/160.`. Only "Provide a valid `pubspec.yaml`" fails, because pana looks for the pubspec on GitHub `main` (see the risk table).

- [ ] **Step 11: Commit**

```bash
.githooks/pre-commit
git add -A
git commit -m "chore(ci): bootstrap workspace, tooling and CI (VK-345)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Expected hook tail: `✓ pre-commit passed`.

---

### Task 2: Platform interface (`liquid_shell_platform_interface`)

**Files:**
- Create: `liquid_shell_platform_interface/lib/src/platform_signals.dart`, `lib/src/liquid_shell_platform.dart`, `lib/src/event_channel_platform.dart`
- Modify: `liquid_shell_platform_interface/lib/liquid_shell_platform_interface.dart`
- Test: `liquid_shell_platform_interface/test/platform_signals_test.dart`, `test/liquid_shell_platform_test.dart`, `test/event_channel_platform_test.dart`

**Interfaces:**
- Consumes: Task 1 workspace.
- Produces:
  - `@immutable class LiquidPlatformSignals { const LiquidPlatformSignals({bool reduceTransparency = false, bool powerSave = false, bool blurDisabled = false}); factory LiquidPlatformSignals.fromMap(Object? payload); static const none; final bool reduceTransparency, powerSave, blurDisabled; }`
  - `abstract class LiquidShellPlatform extends PlatformInterface { static LiquidShellPlatform get instance; static set instance(LiquidShellPlatform); Stream<LiquidPlatformSignals> watchSignals(); }`. The default instance emits `none` once.
  - `class EventChannelLiquidShellPlatform extends LiquidShellPlatform { @visibleForTesting static const channel = EventChannel('vn.lasoai.liquid_shell/signals'); @visibleForTesting static void debugResetLogging(); }`. It never emits errors.

- [ ] **Step 1: Write the failing tests**

`liquid_shell_platform_interface/test/platform_signals_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

void main() {
  group('LiquidPlatformSignals.fromMap', () {
    test('reads every field from a full payload', () {
      final signals = LiquidPlatformSignals.fromMap(const {
        'reduceTransparency': true,
        'powerSave': true,
        'blurDisabled': true,
      });
      expect(
        signals,
        const LiquidPlatformSignals(
          reduceTransparency: true,
          powerSave: true,
          blurDisabled: true,
        ),
      );
    });

    test('a missing field is false', () {
      final signals = LiquidPlatformSignals.fromMap(const {'powerSave': true});
      expect(signals.reduceTransparency, isFalse);
      expect(signals.powerSave, isTrue);
      expect(signals.blurDisabled, isFalse);
    });

    test('a non-bool field is false and unknown keys are ignored', () {
      final signals = LiquidPlatformSignals.fromMap(const {
        'reduceTransparency': 1,
        'powerSave': 'true',
        'blurDisabled': null,
        'somethingNew': true,
      });
      expect(signals, LiquidPlatformSignals.none);
    });

    test('a non-map payload is none', () {
      expect(LiquidPlatformSignals.fromMap(null), LiquidPlatformSignals.none);
      expect(LiquidPlatformSignals.fromMap(true), LiquidPlatformSignals.none);
      expect(
        LiquidPlatformSignals.fromMap(const [true]),
        LiquidPlatformSignals.none,
      );
    });
  });

  test('none has every signal off', () {
    expect(LiquidPlatformSignals.none.reduceTransparency, isFalse);
    expect(LiquidPlatformSignals.none.powerSave, isFalse);
    expect(LiquidPlatformSignals.none.blurDisabled, isFalse);
  });

  test('== and hashCode compare every field', () {
    const a = LiquidPlatformSignals(powerSave: true);
    const b = LiquidPlatformSignals(powerSave: true);
    const c = LiquidPlatformSignals(blurDisabled: true);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
    expect(a.toString(), contains('powerSave: true'));
  });
}
```

`liquid_shell_platform_interface/test/liquid_shell_platform_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

class _ExtendsFake extends LiquidShellPlatform {
  @override
  Stream<LiquidPlatformSignals> watchSignals() =>
      Stream.value(const LiquidPlatformSignals(powerSave: true));
}

class _ImplementsFake implements LiquidShellPlatform {
  @override
  Stream<LiquidPlatformSignals> watchSignals() => const Stream.empty();
}

void main() {
  late LiquidShellPlatform original;

  setUp(() => original = LiquidShellPlatform.instance);
  tearDown(() => LiquidShellPlatform.instance = original);

  test('the default instance emits none once, without a channel', () async {
    final events = await LiquidShellPlatform.instance.watchSignals().toList();
    expect(events, [LiquidPlatformSignals.none]);
  });

  test('accepts an implementation that extends the interface', () async {
    LiquidShellPlatform.instance = _ExtendsFake();
    final first = await LiquidShellPlatform.instance.watchSignals().first;
    expect(first.powerSave, isTrue);
  });

  test('rejects an implementation that only implements the interface', () {
    expect(
      () => LiquidShellPlatform.instance = _ImplementsFake(),
      throwsA(isA<AssertionError>()),
    );
  });
}
```

`liquid_shell_platform_interface/test/event_channel_platform_test.dart`. It drives the real channel through `MockStreamHandler` and `setMockMethodCallHandler`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = EventChannelLiquidShellPlatform.channel;
  final methods = MethodChannel(channel.name);

  late List<String> logs;
  late DebugPrintCallback originalDebugPrint;

  setUp(() {
    logs = [];
    originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    EventChannelLiquidShellPlatform.debugResetLogging();
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
    messenger
      ..setMockStreamHandler(channel, null)
      ..setMockMethodCallHandler(methods, null);
  });

  test('uses the agreed channel name', () {
    expect(channel.name, 'vn.lasoai.liquid_shell/signals');
  });

  test('decodes events and keeps listening after an error event', () async {
    messenger.setMockStreamHandler(
      channel,
      MockStreamHandler.inline(
        onListen: (arguments, events) {
          events
            ..success(const {'reduceTransparency': true})
            ..error(code: 'read-failed')
            ..success(const {'powerSave': true, 'blurDisabled': 'yes'})
            ..endOfStream();
        },
      ),
    );

    final events = await EventChannelLiquidShellPlatform()
        .watchSignals()
        .toList();

    expect(events, const [
      LiquidPlatformSignals(reduceTransparency: true),
      LiquidPlatformSignals.none,
      LiquidPlatformSignals(powerSave: true),
    ]);
    expect(logs.single, contains('read-failed'));
  });

  test('MissingPluginException on listen emits none and logs once', () async {
    final first = await EventChannelLiquidShellPlatform().watchSignals().first;
    final second = await EventChannelLiquidShellPlatform().watchSignals().first;

    expect(first, LiquidPlatformSignals.none);
    expect(second, LiquidPlatformSignals.none);
    expect(logs, hasLength(1));
    expect(logs.single, contains('MissingPluginException'));
  });

  test('PlatformException on listen emits none', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      throw PlatformException(code: 'denied');
    });

    final first = await EventChannelLiquidShellPlatform().watchSignals().first;

    expect(first, LiquidPlatformSignals.none);
    expect(logs.single, contains('denied'));
  });

  test('cancel tells the native side to remove its observers', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call.method);
      return null;
    });

    final subscription = EventChannelLiquidShellPlatform()
        .watchSignals()
        .listen((_) {});
    await pumpEventQueue();
    await subscription.cancel();

    expect(calls, ['listen', 'cancel']);
  });

  test('a cancel that fails natively is swallowed', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      if (call.method == 'cancel') throw PlatformException(code: 'gone');
      return null;
    });

    final subscription = EventChannelLiquidShellPlatform()
        .watchSignals()
        .listen((_) {});
    await pumpEventQueue();

    await expectLater(subscription.cancel(), completes);
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `cd liquid_shell_platform_interface && fvm flutter test; cd ..`
Expected: FAIL, compilation errors such as `Undefined name 'LiquidPlatformSignals'`.

- [ ] **Step 3: Implement**

`liquid_shell_platform_interface/lib/liquid_shell_platform_interface.dart`:

```dart
/// The platform interface of the liquid_shell federated plugin.
///
/// Apps depend on `liquid_shell`, never on this package directly.
library;

export 'src/event_channel_platform.dart';
export 'src/liquid_shell_platform.dart';
export 'src/platform_signals.dart';
```

`liquid_shell_platform_interface/lib/src/platform_signals.dart`:

```dart
import 'package:flutter/foundation.dart';

/// Accessibility and power signals read from the operating system.
///
/// Any of them being `true` makes `liquid_shell` draw solid instead of
/// glass. Every field defaults to `false`; a signal that cannot be read is
/// reported as `false`.
@immutable
class LiquidPlatformSignals {
  /// Creates a set of signals. Every field defaults to `false`.
  const LiquidPlatformSignals({
    this.reduceTransparency = false,
    this.powerSave = false,
    this.blurDisabled = false,
  });

  /// Lenient decoding of a channel payload.
  ///
  /// Unknown keys are ignored. A missing or non-`bool` field is `false`. A
  /// payload that is not a map is [none].
  factory LiquidPlatformSignals.fromMap(Object? payload) {
    if (payload is! Map) return none;
    bool read(String key) => payload[key] == true;
    return LiquidPlatformSignals(
      reduceTransparency: read('reduceTransparency'),
      powerSave: read('powerSave'),
      blurDisabled: read('blurDisabled'),
    );
  }

  /// Every signal off.
  static const none = LiquidPlatformSignals();

  /// iOS Reduce Transparency; on Android, animations off or high contrast.
  final bool reduceTransparency;

  /// Android battery saver.
  final bool powerSave;

  /// Android 12+: the system disabled window blurs.
  final bool blurDisabled;

  @override
  bool operator ==(Object other) =>
      other is LiquidPlatformSignals &&
      other.reduceTransparency == reduceTransparency &&
      other.powerSave == powerSave &&
      other.blurDisabled == blurDisabled;

  @override
  int get hashCode => Object.hash(reduceTransparency, powerSave, blurDisabled);

  @override
  String toString() =>
      'LiquidPlatformSignals(reduceTransparency: $reduceTransparency, '
      'powerSave: $powerSave, blurDisabled: $blurDisabled)';
}
```

`liquid_shell_platform_interface/lib/src/liquid_shell_platform.dart`:

```dart
import 'package:liquid_shell_platform_interface/src/platform_signals.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The interface that platform implementations of liquid_shell extend.
///
/// Implementations must `extend` this class (not `implement` it), so that
/// adding a method later is not a breaking change.
abstract class LiquidShellPlatform extends PlatformInterface {
  /// Constructs a platform implementation.
  LiquidShellPlatform() : super(token: _token);

  static final Object _token = Object();

  static LiquidShellPlatform _instance = _NoSignalLiquidShellPlatform();

  /// The active implementation.
  ///
  /// Defaults to one that emits [LiquidPlatformSignals.none] once and never
  /// touches a platform channel (web, desktop, `flutter test`).
  static LiquidShellPlatform get instance => _instance;

  /// Platform packages set this from their `registerWith()`.
  static set instance(LiquidShellPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Emits the current signals on listen, then every change.
  Stream<LiquidPlatformSignals> watchSignals();
}

class _NoSignalLiquidShellPlatform extends LiquidShellPlatform {
  @override
  Stream<LiquidPlatformSignals> watchSignals() =>
      Stream.value(LiquidPlatformSignals.none);
}
```

`liquid_shell_platform_interface/lib/src/event_channel_platform.dart`. It does not use `receiveBroadcastStream`, because that API reports a failed `listen` through `FlutterError.reportError` and never emits, which would break spec §6.5:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:liquid_shell_platform_interface/src/liquid_shell_platform.dart';
import 'package:liquid_shell_platform_interface/src/platform_signals.dart';

/// [LiquidShellPlatform] over one `EventChannel`, shared by the iOS and
/// Android packages.
///
/// Protocol: on `listen` the native side sends the current signals, then one
/// event per change; on `cancel` it removes every observer. Events are maps
/// decoded by [LiquidPlatformSignals.fromMap].
///
/// Failures never surface as errors. A missing plugin or a failed `listen`
/// emits [LiquidPlatformSignals.none]; an error event emits
/// [LiquidPlatformSignals.none] and the stream keeps listening. Failures are
/// logged with `debugPrint` in debug builds only.
class EventChannelLiquidShellPlatform extends LiquidShellPlatform {
  /// The signal channel. Visible so tests can mock it.
  @visibleForTesting
  static const channel = EventChannel('vn.lasoai.liquid_shell/signals');

  static bool _loggedListenFailure = false;

  /// Lets tests observe the once-only listen-failure log again.
  @visibleForTesting
  static void debugResetLogging() => _loggedListenFailure = false;

  @override
  Stream<LiquidPlatformSignals> watchSignals() {
    final messenger = channel.binaryMessenger;
    final methods = MethodChannel(channel.name, channel.codec);
    late final StreamController<LiquidPlatformSignals> controller;

    Future<void> onListen() async {
      messenger.setMessageHandler(channel.name, (data) async {
        if (data == null) {
          await controller.close();
          return null;
        }
        try {
          controller.add(
            LiquidPlatformSignals.fromMap(channel.codec.decodeEnvelope(data)),
          );
        } on PlatformException catch (error) {
          _debugLog('error event ${error.code}; using none');
          controller.add(LiquidPlatformSignals.none);
        }
        return null;
      });
      try {
        await methods.invokeMethod<void>('listen');
      } on MissingPluginException catch (error) {
        _listenFailed(error);
        controller.add(LiquidPlatformSignals.none);
      } on PlatformException catch (error) {
        _listenFailed(error);
        controller.add(LiquidPlatformSignals.none);
      }
    }

    Future<void> onCancel() async {
      messenger.setMessageHandler(channel.name, null);
      try {
        await methods.invokeMethod<void>('cancel');
      } on MissingPluginException {
        // Nothing was listening natively.
      } on PlatformException {
        // The native side is already gone; nothing to clean up here.
      }
    }

    controller = StreamController<LiquidPlatformSignals>(
      onListen: onListen,
      onCancel: onCancel,
    );
    return controller.stream;
  }

  static void _listenFailed(Object error) {
    if (_loggedListenFailure) return;
    _loggedListenFailure = true;
    _debugLog('listen failed ($error); using none');
  }

  static void _debugLog(String message) {
    if (kDebugMode) debugPrint('liquid_shell signals: $message');
  }
}
```

- [ ] **Step 4: Run them to see them pass**

Run: `cd liquid_shell_platform_interface && fvm flutter test; cd ..`
Expected: `+15: All tests passed!`

Run: `make format-check analyze coverage`
Expected: `✓ coverage 100.00% (57/57 lines) in liquid_shell_platform_interface/coverage/lcov.info ≥ 90.0%`.

- [ ] **Step 5: Commit**

```bash
.githooks/pre-commit
git add liquid_shell_platform_interface
git commit -m "feat(platform): signal contract and event-channel implementation (VK-345)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Native signal readers (iOS, Android) and device integration tests

**Files:**
- Create: `liquid_shell_ios/ios/liquid_shell_ios.podspec`, `liquid_shell_ios/ios/liquid_shell_ios/Package.swift`, `.../Sources/liquid_shell_ios/LiquidShellPlugin.swift`, `.../Sources/liquid_shell_ios/PrivacyInfo.xcprivacy`
- Create: `liquid_shell_android/android/{build.gradle,settings.gradle,.gitignore,src/main/AndroidManifest.xml}`, `src/main/kotlin/vn/lasoai/liquid_shell/{LiquidShellPlugin.kt,SignalReader.kt}`, `src/test/kotlin/vn/lasoai/liquid_shell/SignalReaderTest.kt`
- Modify: `liquid_shell_ios/lib/liquid_shell_ios.dart`, `liquid_shell_android/lib/liquid_shell_android.dart`, the three plugin `pubspec.yaml` files, `liquid_shell/example/pubspec.yaml`, `.github/workflows/ci.yaml`
- Create: `liquid_shell/example/test_driver/integration_test.dart`, `liquid_shell/example/integration_test/signals_test.dart`, `tool/integration_ios.sh`, `tool/integration_android.sh`
- Test: `liquid_shell_ios/test/liquid_shell_ios_test.dart`, `liquid_shell_android/test/liquid_shell_android_test.dart`

**Interfaces:**
- Consumes (Task 2): `LiquidShellPlatform.instance`, `EventChannelLiquidShellPlatform`, the channel protocol.
- Produces: `abstract final class LiquidShellIOS { static void registerWith(); }` and `abstract final class LiquidShellAndroid { static void registerWith(); }`, both installing `EventChannelLiquidShellPlatform()`. Kotlin: `internal data class RawSignals(animatorDurationScale: Float?, contrast: Float?, highTextContrast: Int?, powerSaveMode: Boolean?, crossWindowBlurEnabled: Boolean?, apiLevel: Int)` and `internal object SignalReader { fun toPayload(raw: RawSignals): Map<String, Boolean> }`. Scripts: `tool/integration_ios.sh` (env `IOS_RUNTIME` default `iOS 26.5`, `IOS_DEVICES` default `iPhone 17 Pro;iPad Pro 11-inch (M5)`, `auto` = first iPhone) and `tool/integration_android.sh` (env `ANDROID_SERIAL`, default first `emulator-*`; refuses physical devices unless `ALLOW_PHYSICAL_DEVICE=1`). The integration test reads `--dart-define` `EXPECT_REDUCE_TRANSPARENCY`, `EXPECT_POWER_SAVE`, `EXPECT_BLUR_DISABLED` (`true`/`false`/empty = unchecked).

- [ ] **Step 1: Federated wiring in the pubspecs**

Append the `flutter.plugin` section. `liquid_shell/pubspec.yaml` becomes:

```yaml
name: liquid_shell
description: Adaptive navigation shell with a Liquid Glass look for iOS and Android. A floating tab bar on phones and a glass sidebar on tablets, with no router dependency.
version: 0.1.0-dev.1
homepage: https://github.com/anvu69/liquid_shell/tree/main/liquid_shell
repository: https://github.com/anvu69/liquid_shell/tree/main/liquid_shell
issue_tracker: https://github.com/anvu69/liquid_shell/issues
topics: [navigation, glassmorphism, adaptive-layout, tab-bar, sidebar]
resolution: workspace

environment:
  sdk: ^3.10.0
  flutter: ">=3.38.0"

dependencies:
  flutter:
    sdk: flutter
  liquid_shell_android: ^0.1.0-dev.1
  liquid_shell_ios: ^0.1.0-dev.1
  liquid_shell_platform_interface: ^0.1.0-dev.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  very_good_analysis: 10.1.0

flutter:
  plugin:
    platforms:
      ios:
        default_package: liquid_shell_ios
      android:
        default_package: liquid_shell_android
```

`liquid_shell_ios/pubspec.yaml` becomes:

```yaml
name: liquid_shell_ios
description: The iOS implementation of the liquid_shell plugin. Reads Reduce Transparency through UIAccessibility.
version: 0.1.0-dev.1
homepage: https://github.com/anvu69/liquid_shell/tree/main/liquid_shell_ios
repository: https://github.com/anvu69/liquid_shell/tree/main/liquid_shell_ios
issue_tracker: https://github.com/anvu69/liquid_shell/issues
topics: [navigation, glassmorphism, adaptive-layout, tab-bar, sidebar]
resolution: workspace

environment:
  sdk: ^3.10.0
  flutter: ">=3.38.0"

dependencies:
  flutter:
    sdk: flutter
  liquid_shell_platform_interface: ^0.1.0-dev.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  very_good_analysis: 10.1.0

flutter:
  plugin:
    implements: liquid_shell
    platforms:
      ios:
        pluginClass: LiquidShellPlugin
        dartPluginClass: LiquidShellIOS
```

`liquid_shell_android/pubspec.yaml` becomes:

```yaml
name: liquid_shell_android
description: The Android implementation of the liquid_shell plugin. Reads reduce transparency, battery saver and the system blur switch.
version: 0.1.0-dev.1
homepage: https://github.com/anvu69/liquid_shell/tree/main/liquid_shell_android
repository: https://github.com/anvu69/liquid_shell/tree/main/liquid_shell_android
issue_tracker: https://github.com/anvu69/liquid_shell/issues
topics: [navigation, glassmorphism, adaptive-layout, tab-bar, sidebar]
resolution: workspace

environment:
  sdk: ^3.10.0
  flutter: ">=3.38.0"

dependencies:
  flutter:
    sdk: flutter
  liquid_shell_platform_interface: ^0.1.0-dev.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  very_good_analysis: 10.1.0

flutter:
  plugin:
    implements: liquid_shell
    platforms:
      android:
        package: vn.lasoai.liquid_shell
        pluginClass: LiquidShellPlugin
        dartPluginClass: LiquidShellAndroid
```

`liquid_shell/example/pubspec.yaml` becomes (the driver and the interface are needed by the integration test):

```yaml
name: liquid_shell_example
description: Example app for liquid_shell. One screen per documented case.
publish_to: none
version: 1.0.0+1
resolution: workspace

environment:
  sdk: ^3.10.0
  flutter: ">=3.38.0"

dependencies:
  flutter:
    sdk: flutter
  liquid_shell: ^0.1.0-dev.1

dev_dependencies:
  flutter_driver:
    sdk: flutter
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  liquid_shell_platform_interface: ^0.1.0-dev.1
  very_good_analysis: 10.1.0

flutter:
  uses-material-design: true
```

- [ ] **Step 2: Write the failing Dart registration tests**

`liquid_shell_ios/test/liquid_shell_ios_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_ios/liquid_shell_ios.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

void main() {
  test('registerWith installs the event-channel implementation', () {
    LiquidShellIOS.registerWith();
    expect(
      LiquidShellPlatform.instance,
      isA<EventChannelLiquidShellPlatform>(),
    );
  });
}
```

`liquid_shell_android/test/liquid_shell_android_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_android/liquid_shell_android.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

void main() {
  test('registerWith installs the event-channel implementation', () {
    LiquidShellAndroid.registerWith();
    expect(
      LiquidShellPlatform.instance,
      isA<EventChannelLiquidShellPlatform>(),
    );
  });
}
```

Run: `fvm flutter pub get && (cd liquid_shell_ios && fvm flutter test)`
Expected: FAIL, `Undefined name 'LiquidShellIOS'`.

- [ ] **Step 3: Implement the Dart registrars**

`liquid_shell_ios/lib/liquid_shell_ios.dart`:

```dart
/// The iOS implementation of liquid_shell.
library;

import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// Registers the event-channel signal reader for iOS.
///
/// Called by the generated plugin registrant. Apps never call it.
abstract final class LiquidShellIOS {
  /// Makes [EventChannelLiquidShellPlatform] the active implementation.
  static void registerWith() {
    LiquidShellPlatform.instance = EventChannelLiquidShellPlatform();
  }
}
```

`liquid_shell_android/lib/liquid_shell_android.dart`:

```dart
/// The Android implementation of liquid_shell.
library;

import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// Registers the event-channel signal reader for Android.
///
/// Called by the generated plugin registrant. Apps never call it.
abstract final class LiquidShellAndroid {
  /// Makes [EventChannelLiquidShellPlatform] the active implementation.
  static void registerWith() {
    LiquidShellPlatform.instance = EventChannelLiquidShellPlatform();
  }
}
```

Run: `(cd liquid_shell_ios && fvm flutter test) && (cd liquid_shell_android && fvm flutter test)`
Expected: `+1: All tests passed!` twice.

- [ ] **Step 4: Write the failing Kotlin test**

`liquid_shell_android/android/settings.gradle`:

```groovy
rootProject.name = 'liquid_shell_android'
```

`liquid_shell_android/android/build.gradle` (from the 3.38 plugin template; namespace `vn.lasoai.liquid_shell`, see D1 for `minSdk`):

```groovy
group = "vn.lasoai.liquid_shell"
version = "1.0-SNAPSHOT"

buildscript {
    ext.kotlin_version = "2.2.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

apply plugin: "com.android.library"
apply plugin: "kotlin-android"

android {
    namespace = "vn.lasoai.liquid_shell"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17
    }

    sourceSets {
        main.java.srcDirs += "src/main/kotlin"
        test.java.srcDirs += "src/test/kotlin"
    }

    defaultConfig {
        // Flutter 3.38's flutter.minSdkVersion. A plugin library cannot read
        // that property, so the value is written out (spec Q16).
        minSdk = 24
    }

    dependencies {
        testImplementation("org.jetbrains.kotlin:kotlin-test")
    }

    testOptions {
        unitTests.all {
            useJUnitPlatform()

            testLogging {
               events "passed", "skipped", "failed", "standardOut", "standardError"
               outputs.upToDateWhen {false}
               showStandardStreams = true
            }
        }
    }
}
```

`liquid_shell_android/android/.gitignore`:

```gitignore
*.iml
.gradle
/local.properties
/.idea/workspace.xml
/.idea/libraries
.DS_Store
/build
/captures
.cxx
```

`liquid_shell_android/android/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
</manifest>
```

`liquid_shell_android/android/src/test/kotlin/vn/lasoai/liquid_shell/SignalReaderTest.kt`. It covers every row of §6.1 for API 30, 31, 34 and 36:

```kotlin
package vn.lasoai.liquid_shell

import kotlin.test.Test
import kotlin.test.assertEquals

class SignalReaderTest {
    private fun raw(
        api: Int,
        animatorDurationScale: Float? = 1f,
        contrast: Float? = 0f,
        highTextContrast: Int? = 0,
        powerSaveMode: Boolean? = false,
        crossWindowBlurEnabled: Boolean? = true,
    ) = RawSignals(
        animatorDurationScale = animatorDurationScale,
        contrast = contrast,
        highTextContrast = highTextContrast,
        powerSaveMode = powerSaveMode,
        crossWindowBlurEnabled = crossWindowBlurEnabled,
        apiLevel = api,
    )

    private fun payload(
        reduceTransparency: Boolean = false,
        powerSave: Boolean = false,
        blurDisabled: Boolean = false,
    ) = mapOf(
        "reduceTransparency" to reduceTransparency,
        "powerSave" to powerSave,
        "blurDisabled" to blurDisabled,
    )

    @Test
    fun defaultSettingsAreAllOffOnEveryApi() {
        for (api in listOf(30, 31, 34, 36)) {
            assertEquals(payload(), SignalReader.toPayload(raw(api)), "API $api")
        }
    }

    @Test
    fun animatorScaleZeroReducesTransparencyOnEveryApi() {
        for (api in listOf(30, 31, 34, 36)) {
            assertEquals(
                payload(reduceTransparency = true),
                SignalReader.toPayload(raw(api, animatorDurationScale = 0f)),
                "API $api",
            )
        }
    }

    @Test
    fun highTextContrastReducesTransparencyOnEveryApi() {
        for (api in listOf(30, 31, 34, 36)) {
            assertEquals(
                payload(reduceTransparency = true),
                SignalReader.toPayload(raw(api, highTextContrast = 1)),
                "API $api",
            )
        }
    }

    @Test
    fun contrastAboveZeroCountsFromApi34Only() {
        assertEquals(payload(), SignalReader.toPayload(raw(30, contrast = 0.5f)))
        assertEquals(payload(), SignalReader.toPayload(raw(31, contrast = 0.5f)))
        assertEquals(
            payload(reduceTransparency = true),
            SignalReader.toPayload(raw(34, contrast = 0.5f)),
        )
        assertEquals(
            payload(reduceTransparency = true),
            SignalReader.toPayload(raw(36, contrast = 1f)),
        )
        assertEquals(payload(), SignalReader.toPayload(raw(36, contrast = -0.5f)))
    }

    @Test
    fun powerSaveOnEveryApi() {
        for (api in listOf(30, 31, 34, 36)) {
            assertEquals(
                payload(powerSave = true),
                SignalReader.toPayload(raw(api, powerSaveMode = true)),
                "API $api",
            )
        }
    }

    @Test
    fun blurDisabledCountsFromApi31Only() {
        assertEquals(
            payload(),
            SignalReader.toPayload(raw(30, crossWindowBlurEnabled = false)),
        )
        for (api in listOf(31, 34, 36)) {
            assertEquals(
                payload(blurDisabled = true),
                SignalReader.toPayload(raw(api, crossWindowBlurEnabled = false)),
                "API $api",
            )
        }
    }

    @Test
    fun failedReadsAreOff() {
        val failed = RawSignals(
            animatorDurationScale = null,
            contrast = null,
            highTextContrast = null,
            powerSaveMode = null,
            crossWindowBlurEnabled = null,
            apiLevel = 36,
        )
        assertEquals(payload(), SignalReader.toPayload(failed))
    }
}
```

Run: `make android-unit`
Expected: FAIL. `flutter build apk --config-only` reports `The plugin liquid_shell_android doesn't have a main class defined in .../LiquidShellPlugin.kt`.

- [ ] **Step 5: Implement the Android plugin**

`liquid_shell_android/android/src/main/kotlin/vn/lasoai/liquid_shell/SignalReader.kt`:

```kotlin
package vn.lasoai.liquid_shell

/**
 * Raw values read from the system. A field is null when its read failed or
 * the API does not exist on this device.
 */
internal data class RawSignals(
    /** Settings.Global.ANIMATOR_DURATION_SCALE. */
    val animatorDurationScale: Float?,
    /** UiModeManager.getContrast(), API 34+. */
    val contrast: Float?,
    /** Settings.Secure "high_text_contrast_enabled". */
    val highTextContrast: Int?,
    /** PowerManager.isPowerSaveMode. */
    val powerSaveMode: Boolean?,
    /** WindowManager.isCrossWindowBlurEnabled, API 31+. */
    val crossWindowBlurEnabled: Boolean?,
    /** Build.VERSION.SDK_INT. */
    val apiLevel: Int,
)

/** Pure mapping from raw system values to the channel payload (spec §6.1). */
internal object SignalReader {
    fun toPayload(raw: RawSignals): Map<String, Boolean> = mapOf(
        "reduceTransparency" to reduceTransparency(raw),
        "powerSave" to (raw.powerSaveMode == true),
        "blurDisabled" to (raw.apiLevel >= 31 && raw.crossWindowBlurEnabled == false),
    )

    private fun reduceTransparency(raw: RawSignals): Boolean =
        raw.animatorDurationScale == 0f ||
            (raw.apiLevel >= 34 && (raw.contrast ?: 0f) > 0f) ||
            raw.highTextContrast == 1
}
```

`liquid_shell_android/android/src/main/kotlin/vn/lasoai/liquid_shell/LiquidShellPlugin.kt`:

```kotlin
package vn.lasoai.liquid_shell

import android.app.Activity
import android.app.UiModeManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.database.ContentObserver
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import java.util.function.Consumer

/**
 * Streams the accessibility and power signals liquid_shell needs on Android
 * over the `vn.lasoai.liquid_shell/signals` event channel (spec §6).
 *
 * Every read is wrapped so a failure reports `false`. Every observer is
 * removed on cancel, on detach from the activity and on detach from the
 * engine. No permissions are needed.
 */
class LiquidShellPlugin : FlutterPlugin, ActivityAware, EventChannel.StreamHandler {
    private var context: Context? = null
    private var activity: Activity? = null
    private var channel: EventChannel? = null
    private var sink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())

    private var settingsObserver: ContentObserver? = null
    private var powerReceiver: BroadcastReceiver? = null
    // Typed as Any so this class never references API 34 types on old devices.
    private var contrastListener: Any? = null
    private var blurListener: Consumer<Boolean>? = null
    private var blurWindowManager: WindowManager? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = EventChannel(binding.binaryMessenger, CHANNEL).also {
            it.setStreamHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        removeObservers()
        sink = null
        channel?.setStreamHandler(null)
        channel = null
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = attach(binding)

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        attach(binding)

    override fun onDetachedFromActivityForConfigChanges() = detach()

    override fun onDetachedFromActivity() = detach()

    private fun attach(binding: ActivityPluginBinding) {
        activity = binding.activity
        if (sink != null) {
            addObservers()
            send()
        }
    }

    private fun detach() {
        removeObservers()
        activity = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        addObservers()
        send()
    }

    override fun onCancel(arguments: Any?) {
        removeObservers()
        sink = null
    }

    private fun send() {
        sink?.success(SignalReader.toPayload(read()))
    }

    private fun read(): RawSignals {
        val ctx = context
        val resolver = ctx?.contentResolver
        val api = Build.VERSION.SDK_INT
        return RawSignals(
            animatorDurationScale = attempt {
                Settings.Global.getFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f)
            },
            contrast = if (api >= 34) {
                attempt { ctx?.getSystemService(UiModeManager::class.java)?.contrast }
            } else {
                null
            },
            highTextContrast = attempt {
                Settings.Secure.getInt(resolver, HIGH_TEXT_CONTRAST, 0)
            },
            powerSaveMode = attempt {
                ctx?.getSystemService(PowerManager::class.java)?.isPowerSaveMode
            },
            crossWindowBlurEnabled = if (api >= 31) {
                attempt { windowManager()?.isCrossWindowBlurEnabled }
            } else {
                null
            },
            apiLevel = api,
        )
    }

    private fun windowManager(): WindowManager? =
        (activity ?: context)?.getSystemService(WindowManager::class.java)

    private fun addObservers() {
        val ctx = context ?: return
        removeObservers()

        val observer = object : ContentObserver(main) {
            override fun onChange(selfChange: Boolean) = send()
        }
        attempt {
            ctx.contentResolver.registerContentObserver(
                Settings.Global.getUriFor(Settings.Global.ANIMATOR_DURATION_SCALE),
                false,
                observer,
            )
            ctx.contentResolver.registerContentObserver(
                Settings.Secure.getUriFor(HIGH_TEXT_CONTRAST),
                false,
                observer,
            )
            settingsObserver = observer
        }

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) = send()
        }
        val filter = IntentFilter(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED)
        attempt {
            if (Build.VERSION.SDK_INT >= 33) {
                ctx.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                ctx.registerReceiver(receiver, filter)
            }
            powerReceiver = receiver
        }

        if (Build.VERSION.SDK_INT >= 34) {
            attempt {
                val listener = UiModeManager.ContrastChangeListener { send() }
                ctx.getSystemService(UiModeManager::class.java)
                    ?.addContrastChangeListener(ctx.mainExecutor, listener)
                contrastListener = listener
            }
        }

        if (Build.VERSION.SDK_INT >= 31) {
            attempt {
                val wm = windowManager()
                val listener = Consumer<Boolean> { send() }
                wm?.addCrossWindowBlurEnabledListener(ctx.mainExecutor, listener)
                blurWindowManager = wm
                blurListener = listener
            }
        }
    }

    private fun removeObservers() {
        val ctx = context
        settingsObserver?.let { observer ->
            attempt { ctx?.contentResolver?.unregisterContentObserver(observer) }
        }
        settingsObserver = null
        powerReceiver?.let { receiver -> attempt { ctx?.unregisterReceiver(receiver) } }
        powerReceiver = null
        if (Build.VERSION.SDK_INT >= 34) {
            (contrastListener as? UiModeManager.ContrastChangeListener)?.let { listener ->
                attempt {
                    ctx?.getSystemService(UiModeManager::class.java)
                        ?.removeContrastChangeListener(listener)
                }
            }
        }
        contrastListener = null
        if (Build.VERSION.SDK_INT >= 31) {
            blurListener?.let { listener ->
                attempt { blurWindowManager?.removeCrossWindowBlurEnabledListener(listener) }
            }
        }
        blurListener = null
        blurWindowManager = null
    }

    /** Runs [block]; any SecurityException or other runtime failure → null. */
    private inline fun <T> attempt(block: () -> T): T? =
        try {
            block()
        } catch (e: SecurityException) {
            null
        } catch (e: Settings.SettingNotFoundException) {
            null
        } catch (e: RuntimeException) {
            null
        }

    private companion object {
        const val CHANNEL = "vn.lasoai.liquid_shell/signals"
        const val HIGH_TEXT_CONTRAST = "high_text_contrast_enabled"
    }
}
```

Run: `make android-unit`
Expected: seven `SignalReaderTest > … PASSED` lines and `BUILD SUCCESSFUL`.

- [ ] **Step 6: Implement the iOS plugin (CocoaPods + SwiftPM layout)**

`liquid_shell_ios/ios/liquid_shell_ios.podspec`:

```ruby
Pod::Spec.new do |s|
  s.name             = 'liquid_shell_ios'
  s.version          = '0.1.0'
  s.summary          = 'iOS signals for the liquid_shell Flutter plugin.'
  s.description      = <<-DESC
Streams Reduce Transparency to liquid_shell so its glass can fall back to a solid fill.
                       DESC
  s.homepage         = 'https://github.com/anvu69/liquid_shell'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'lasoai.vn' => 'lasotuviai@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'liquid_shell_ios/Sources/liquid_shell_ios/**/*.swift'
  s.resource_bundles = { 'liquid_shell_ios_privacy' => ['liquid_shell_ios/Sources/liquid_shell_ios/PrivacyInfo.xcprivacy'] }
  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version    = '5.0'
end
```

`liquid_shell_ios/ios/liquid_shell_ios/Package.swift`:

```swift
// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "liquid_shell_ios",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "liquid-shell-ios", targets: ["liquid_shell_ios"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "liquid_shell_ios",
            dependencies: [],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
```

`liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/PrivacyInfo.xcprivacy` (empty manifest from the 3.38 template):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<key>NSPrivacyAccessedAPITypes</key>
	<array/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyTracking</key>
	<false/>
</dict>
</plist>
```

`liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/LiquidShellPlugin.swift`:

```swift
import Flutter
import UIKit

/// Streams the accessibility signals liquid_shell needs on iOS over the
/// `vn.lasoai.liquid_shell/signals` event channel (spec §6).
///
/// iOS reports Reduce Transparency only. Battery saver and blur-disabled are
/// always false here: the system's own glass ignores Low Power Mode.
public final class LiquidShellPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var observer: NSObjectProtocol?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterEventChannel(
      name: "vn.lasoai.liquid_shell/signals",
      binaryMessenger: registrar.messenger()
    )
    channel.setStreamHandler(LiquidShellPlugin())
  }

  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    sink = events
    observer = NotificationCenter.default.addObserver(
      forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.send()
    }
    send()
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let observer = observer {
      NotificationCenter.default.removeObserver(observer)
    }
    observer = nil
    sink = nil
    return nil
  }

  private func send() {
    sink?([
      "reduceTransparency": UIAccessibility.isReduceTransparencyEnabled,
      "powerSave": false,
      "blurDisabled": false,
    ])
  }
}
```

- [ ] **Step 7: Screenshot driver and integration test (from the public `integration_test` docs)**

`liquid_shell/example/test_driver/integration_test.dart`:

```dart
// Host side of `flutter drive`. Saves every screenshot the device test takes
// to build/integration_screenshots/<name>.png. Written from the public
// integration_test documentation (spec §9).
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final file = File('build/integration_screenshots/$name.png');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    return true;
  },
);
```

`liquid_shell/example/integration_test/signals_test.dart` (Task 5 and Task 11 extend it):

```dart
// Signal channel round-trip on a real simulator or emulator (spec §10.5).
//
// tool/integration_ios.sh and tool/integration_android.sh pass the expected
// value of each signal with --dart-define. An empty value means "do not
// check this field" (for example, battery saver also disables window blurs).
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

const _expectReduceTransparency = String.fromEnvironment(
  'EXPECT_REDUCE_TRANSPARENCY',
);
const _expectPowerSave = String.fromEnvironment('EXPECT_POWER_SAVE');
const _expectBlurDisabled = String.fromEnvironment('EXPECT_BLUR_DISABLED');

void _check(String expected, {required bool actual, required String name}) {
  if (expected.isEmpty) return;
  expect(actual, expected == 'true', reason: name);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the platform package registered the event channel', (
    tester,
  ) async {
    expect(
      LiquidShellPlatform.instance,
      isA<EventChannelLiquidShellPlatform>(),
    );
  });

  testWidgets('watchSignals emits a well-formed value within 5 s', (
    tester,
  ) async {
    final signals = await LiquidShellPlatform.instance
        .watchSignals()
        .first
        .timeout(const Duration(seconds: 5));
    debugPrint('liquid_shell integration: $signals');

    _check(
      _expectReduceTransparency,
      actual: signals.reduceTransparency,
      name: 'reduceTransparency',
    );
    _check(_expectPowerSave, actual: signals.powerSave, name: 'powerSave');
    _check(
      _expectBlurDisabled,
      actual: signals.blurDisabled,
      name: 'blurDisabled',
    );
  });
}
```

- [ ] **Step 8: Device scripts**

`tool/integration_ios.sh` (the `RUN_NAME` define is added in Task 11):

```bash
#!/usr/bin/env bash
# Signal channel round-trip on iOS simulators (spec §10.5).
#
#   tool/integration_ios.sh
#
# IOS_RUNTIME   simctl runtime to pick devices from (default "iOS 26.5";
#               empty = any available runtime, used by CI).
# IOS_DEVICES   ';'-separated simulator names
#               (default "iPhone 17 Pro;iPad Pro 11-inch (M5)").
#               "auto" = the first available iPhone (CI).
# FLUTTER       flutter command (default: flutter).
#
# Reduce Transparency has no supported simctl switch, so only the default
# value is asserted here; toggling it is the manual check in docs/qa/.
set -euo pipefail
cd "$(dirname "$0")/../liquid_shell/example"
FLUTTER=${FLUTTER:-flutter}
IOS_RUNTIME=${IOS_RUNTIME-iOS 26.5}
IOS_DEVICES=${IOS_DEVICES:-iPhone 17 Pro;iPad Pro 11-inch (M5)}

udid_of() {
  local name=$1 pattern
  if [ "$name" = auto ]; then pattern='    iPhone'; else pattern="    $name ("; fi
  xcrun simctl list devices available ${IOS_RUNTIME:+"$IOS_RUNTIME"} \
    | grep -F "$pattern" | head -n1 \
    | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'
}

IFS=';' read -r -a names <<< "$IOS_DEVICES"
for name in "${names[@]}"; do
  udid=$(udid_of "$name")
  if [ -z "$udid" ]; then
    echo "✗ no available simulator named '$name' (${IOS_RUNTIME:-any runtime})" >&2
    exit 1
  fi
  echo "▸ $name ($udid)"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  $FLUTTER drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/signals_test.dart \
    -d "$udid" \
    --dart-define=EXPECT_REDUCE_TRANSPARENCY=false \
    --dart-define=EXPECT_POWER_SAVE=false \
    --dart-define=EXPECT_BLUR_DISABLED=false
done
echo "✓ iOS integration passed"
```

`tool/integration_android.sh`:

```bash
#!/usr/bin/env bash
# Signal channel + every Android signal on an emulator (spec §10.5).
#
#   tool/integration_android.sh
#
# ANDROID_SERIAL  adb serial (default: the first running emulator-*). The
#                 script changes system settings, so it refuses a physical
#                 device unless ALLOW_PHYSICAL_DEVICE=1.
# FLUTTER         flutter command (default: flutter).
#
# Each run sets one signal with adb, then asserts it through
# integration_test/signals_test.dart (expectations via --dart-define).
# Every setting is restored on exit, even after a failure.
set -euo pipefail
cd "$(dirname "$0")/../liquid_shell/example"
FLUTTER=${FLUTTER:-flutter}

if [ -z "${ANDROID_SERIAL:-}" ]; then
  ANDROID_SERIAL=$(adb devices | awk 'NR>1 && $2=="device" && $1 ~ /^emulator-/ {print $1; exit}')
fi
if [ -z "$ANDROID_SERIAL" ]; then
  echo "✗ no running emulator. Start one, e.g. emulator -avd tuvi_test" >&2
  exit 1
fi
if [[ "$ANDROID_SERIAL" != emulator-* && "${ALLOW_PHYSICAL_DEVICE:-0}" != 1 ]]; then
  echo "✗ $ANDROID_SERIAL is not an emulator; set ALLOW_PHYSICAL_DEVICE=1 to proceed" >&2
  exit 1
fi
export ANDROID_SERIAL
api=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
echo "▸ device $ANDROID_SERIAL, API $api"

orig_scale=$(adb shell settings get global animator_duration_scale | tr -d '\r')
restore() {
  if [ "$orig_scale" = null ]; then
    adb shell settings delete global animator_duration_scale >/dev/null || true
  else
    adb shell settings put global animator_duration_scale "$orig_scale" || true
  fi
  adb shell settings put global low_power 0 || true
  adb shell cmd battery reset || true
  adb shell settings put global disable_window_blurs 0 || true
}
trap restore EXIT
restore

run() {
  local name=$1
  shift
  echo "▸ run: $name"
  $FLUTTER drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/signals_test.dart \
    -d "$ANDROID_SERIAL" "$@"
}

blur_default=false
if [ "$api" -ge 31 ] &&
  [ "$(adb shell getprop ro.surface_flinger.supports_background_blur | tr -d '\r')" != 1 ]; then
  blur_default=true # no GPU blur on this image: the system reports it disabled
fi

run default \
  --dart-define=EXPECT_REDUCE_TRANSPARENCY=false \
  --dart-define=EXPECT_POWER_SAVE=false \
  --dart-define=EXPECT_BLUR_DISABLED=$blur_default

adb shell settings put global animator_duration_scale 0
run reduceTransparency --dart-define=EXPECT_REDUCE_TRANSPARENCY=true
restore

adb shell cmd battery unplug
adb shell settings put global low_power 1
# Battery saver also disables window blurs on API 31+, so blurDisabled is
# not asserted in this run.
run powerSave --dart-define=EXPECT_POWER_SAVE=true
restore

if [ "$api" -ge 31 ]; then
  # `wm disable-blur 1` writes this setting but needs root on API 36
  # google_apis images (SecurityException as the shell user).
  adb shell settings put global disable_window_blurs 1
  run blurDisabled --dart-define=EXPECT_BLUR_DISABLED=true
  restore
fi
echo "✓ Android integration passed"
```

```bash
chmod +x tool/integration_ios.sh tool/integration_android.sh
```

- [ ] **Step 9: Run on devices**

Run: `make integration-ios`
Expected, for each of `iPhone 17 Pro` and `iPad Pro 11-inch (M5)` on iOS 26.5: `flutter: liquid_shell integration: LiquidPlatformSignals(reduceTransparency: false, powerSave: false, blurDisabled: false)` and `All tests passed.`, ending with `✓ iOS integration passed`. The first run executes `pod install`, which edits `ios/Runner.xcodeproj/project.pbxproj` and `ios/Runner.xcworkspace/contents.xcworkspacedata`; commit those changes.

Start the emulator if it is not running: `$ANDROID_HOME/emulator/emulator -avd tuvi_test -no-snapshot-save &`. Then:
Run: `make integration-android`
Expected on `tuvi_test` (API 36):
```
▸ run: default            … LiquidPlatformSignals(reduceTransparency: false, powerSave: false, blurDisabled: false)
▸ run: reduceTransparency … (reduceTransparency: true, powerSave: false, blurDisabled: false)
▸ run: powerSave          … (reduceTransparency: false, powerSave: true, blurDisabled: true)
▸ run: blurDisabled       … (reduceTransparency: false, powerSave: false, blurDisabled: true)
✓ Android integration passed
```
Afterwards, `adb shell settings get global disable_window_blurs` must print `0`: the script restores every setting, even after a failure.

Record for spec §6.1: `adb shell settings list global; adb shell settings list secure` shows no "reduce blur" key on the API 36 image. Note the result in the PR.

- [ ] **Step 10: CI jobs for native code**

`.github/workflows/ci.yaml` becomes:

```yaml
name: ci

on:
  push:
    branches: [main]
  pull_request:

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

# Flutter 3.38.x is the supported floor and blocks merges. Latest stable runs
# as an early warning and never blocks (continue-on-error).
jobs:
  checks:
    name: checks (${{ matrix.flutter }})
    runs-on: ubuntu-latest
    continue-on-error: ${{ matrix.experimental }}
    strategy:
      fail-fast: false
      matrix:
        include:
          - flutter: 3.38.x
            experimental: false
          - flutter: stable
            experimental: true
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: ${{ matrix.flutter == 'stable' && '' || matrix.flutter }}
          cache: true
      - run: make get
      - run: make format-check
      - run: make analyze
      - run: make provenance
      - run: make test
      - run: make coverage
      - run: make snippets

  pana:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: make get
      - run: dart pub global activate pana
      # pana checks that `repository` on GitHub main contains this pubspec.
      # On a branch that adds a package, main does not have it yet, so those
      # 10 points are allowed off main only.
      - name: pana liquid_shell_platform_interface (max score on main)
        run: >
          dart pub global run pana --no-warning
          --exit-code-threshold ${{ github.ref == 'refs/heads/main' && '0' || '10' }}
          liquid_shell_platform_interface
      # These three depend on liquid_shell_platform_interface, which pana can
      # only resolve from pub.dev. Informational until P6 publishes it first.
      - name: pana dependants (informational until P6)
        continue-on-error: true
        run: |
          for p in liquid_shell liquid_shell_ios liquid_shell_android; do
            dart pub global run pana --no-warning --exit-code-threshold 0 "$p"
          done
      - run: make publish-check

  android-unit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: 3.38.x
          cache: true
      - run: make get
      - run: make android-unit

  integration-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Enable KVM
        run: |
          echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo tee /etc/udev/rules.d/99-kvm4all.rules
          sudo udevadm control --reload-rules
          sudo udevadm trigger --name-match=kvm
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: 3.38.x
          cache: true
      - run: make get
      - uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 34
          target: google_apis
          arch: x86_64
          script: tool/integration_android.sh

  integration-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: 3.38.x
          cache: true
      - run: make get
      - run: tool/integration_ios.sh
        env:
          IOS_RUNTIME: ""
          IOS_DEVICES: auto
```

- [ ] **Step 11: Gates and commit**

Run: `make verify`
Expected: `✓ verify passed`.

```bash
.githooks/pre-commit
git add -A
git commit -m "feat(platform): iOS and Android signal readers with device integration tests (VK-345)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Glass vocabulary: tiers, theme, renderer seam, built-in renderers, policy

**Files:**
- Create: `liquid_shell/lib/src/glass/{tier,glass_theme,renderer,outside_shadow,frosted_renderer,solid_renderer,policy,glass_scope}.dart`
- Modify: `liquid_shell/lib/liquid_shell.dart`
- Test: `liquid_shell/test/unit/glass_theme_test.dart`, `liquid_shell/test/unit/glass_policy_test.dart`, `liquid_shell/test/widget/glass_renderers_test.dart`

**Interfaces:**
- Consumes: nothing beyond Flutter.
- Produces (exported): `enum LiquidGlassTier { liquid, frosted, solid }`; `class LiquidGlassTheme extends ThemeExtension<LiquidGlassTheme>` (spec §4.7 fields; `factory fromColorScheme(ColorScheme)`, `static LiquidGlassTheme of(BuildContext)`, `copyWith`, `lerp`, `==`); `class LiquidGlassSpec { const LiquidGlassSpec({required BorderRadius borderRadius, required LiquidGlassTheme theme}); }`; `abstract class LiquidGlassRenderer { LiquidGlassTier get tier; bool isSupported(BuildContext) => true; Widget buildBackground(BuildContext, LiquidGlassSpec); }`; `class LiquidGlassSignals { … bool get prefersSolid; }`; `class LiquidGlassPolicy { const LiquidGlassPolicy({LiquidGlassTier? forcedTier, List<LiquidGlassRenderer> renderers = const []}); LiquidGlassTier resolve(BuildContext, LiquidGlassSignals); LiquidGlassRenderer rendererFor(BuildContext, LiquidGlassTier); }`; `class LiquidGlassScope extends InheritedWidget { static LiquidGlassPolicy policyOf(BuildContext); }`.
- Produces (internal, `lib/src`): `FrostedGlassRenderer` (`static const rimKey`), `SolidGlassRenderer`, `OutsideShadow({required BorderRadius borderRadius, required BoxShadow shadow})`, `void debugResetPolicyLogging()`.

- [ ] **Step 1: Write the failing tests**

`liquid_shell/test/unit/glass_theme_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';

void main() {
  final light = ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC));
  final dark = ColorScheme.fromSeed(
    seedColor: const Color(0xFF3366CC),
    brightness: Brightness.dark,
  );

  group('LiquidGlassTheme.fromColorScheme', () {
    test('light values (spec §5.9)', () {
      final theme = LiquidGlassTheme.fromColorScheme(light);
      expect(theme.tint, light.surface.withValues(alpha: 0.72));
      expect(theme.solid, light.surface);
      expect(theme.border, light.outline.withValues(alpha: 0.28));
      expect(
        theme.rimHighlight,
        const Color(0xFFFFFFFF).withValues(alpha: 0.5),
      );
    });

    test('dark values (spec §5.9)', () {
      final theme = LiquidGlassTheme.fromColorScheme(dark);
      expect(theme.tint, dark.surface.withValues(alpha: 0.90));
      expect(theme.solid, dark.surface);
      expect(theme.border, dark.onSurface.withValues(alpha: 0.18));
      expect(
        theme.rimHighlight,
        const Color(0xFFFFFFFF).withValues(alpha: 0.18),
      );
    });

    test('shared values', () {
      for (final scheme in [light, dark]) {
        final theme = LiquidGlassTheme.fromColorScheme(scheme);
        expect(
          theme.shadow,
          const BoxShadow(
            color: Color(0x24000000),
            offset: Offset(0, 6),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        );
        expect(theme.labelStyle.fontSize, 10);
        expect(theme.labelStyle.height, 1.4);
        expect(theme.labelStyle.fontWeight, FontWeight.w600);
        expect(theme.labelStyle.letterSpacing, 0.4);
        expect(theme.labelStyle.fontFamily, isNull);
        expect(theme.blurSigma, 10);
        expect(theme.borderWidth, 1);
        expect(
          theme.borderRadius,
          const BorderRadius.all(Radius.circular(999)),
        );
      }
    });
  });

  group('LiquidGlassTheme.of', () {
    testWidgets('returns the theme extension when present', (tester) async {
      final custom = LiquidGlassTheme.fromColorScheme(
        light,
      ).copyWith(blurSigma: 4);
      late LiquidGlassTheme found;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: light, extensions: [custom]),
          home: Builder(
            builder: (context) {
              found = LiquidGlassTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(found, custom);
    });

    testWidgets('falls back to the displayed color scheme', (tester) async {
      late LiquidGlassTheme found;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: light),
          darkTheme: ThemeData(colorScheme: dark),
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) {
              found = LiquidGlassTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(found, LiquidGlassTheme.fromColorScheme(dark));
    });
  });

  test('copyWith replaces only the given fields', () {
    final base = LiquidGlassTheme.fromColorScheme(light);
    final copy = base.copyWith(
      tint: const Color(0x11223344),
      blurSigma: 3,
      borderRadius: BorderRadius.zero,
    );
    expect(copy.tint, const Color(0x11223344));
    expect(copy.blurSigma, 3);
    expect(copy.borderRadius, BorderRadius.zero);
    expect(copy.solid, base.solid);
    expect(copy.border, base.border);
    expect(copy.borderWidth, base.borderWidth);
    expect(copy.rimHighlight, base.rimHighlight);
    expect(copy.shadow, base.shadow);
    expect(copy.labelStyle, base.labelStyle);
    expect(base.copyWith(), base);
  });

  test('lerp returns the endpoints and blends between them', () {
    final a = LiquidGlassTheme.fromColorScheme(light);
    final b = LiquidGlassTheme.fromColorScheme(dark).copyWith(blurSigma: 20);
    expect(a.lerp(b, 0), a);
    expect(a.lerp(b, 1), b);
    expect(a.lerp(b, 0.5).blurSigma, 15);
    expect(a.lerp(null, 0.5), a);
  });

  test('== and hashCode compare every field', () {
    final a = LiquidGlassTheme.fromColorScheme(light);
    final b = LiquidGlassTheme.fromColorScheme(light);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(a.copyWith(borderWidth: 2)));
  });
}
```

`liquid_shell/test/unit/glass_policy_test.dart`. `debugPrint` and `FlutterError.onError` are restored inside each test body, because `testWidgets` checks that foundation hooks are unset before `tearDown` runs:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/glass/frosted_renderer.dart';
import 'package:liquid_shell/src/glass/solid_renderer.dart';

class _FakeRenderer extends LiquidGlassRenderer {
  const _FakeRenderer(this.tier, {this.supported = true, this.throws = false});

  @override
  final LiquidGlassTier tier;
  final bool supported;
  final bool throws;

  @override
  bool isSupported(BuildContext context) {
    if (throws) throw StateError('probe failed');
    return supported;
  }

  @override
  Widget buildBackground(BuildContext context, LiquidGlassSpec spec) =>
      const SizedBox.expand();
}

Future<BuildContext> _context(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    Builder(
      builder: (c) {
        context = c;
        return const SizedBox();
      },
    ),
  );
  return context;
}

/// Runs [body] with `debugPrint` captured. Restores it before the test
/// ends, because testWidgets checks that foundation hooks are unset.
Future<List<String>> _captureLogs(Future<void> Function() body) async {
  final logs = <String>[];
  final original = debugPrint;
  debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
  try {
    await body();
  } finally {
    debugPrint = original;
  }
  return logs;
}

void main() {
  group('LiquidGlassSignals.prefersSolid', () {
    test('is false with every signal off', () {
      expect(const LiquidGlassSignals().prefersSolid, isFalse);
    });

    test('is true for each signal alone', () {
      expect(
        const LiquidGlassSignals(reduceTransparency: true).prefersSolid,
        isTrue,
      );
      expect(const LiquidGlassSignals(highContrast: true).prefersSolid, isTrue);
      expect(const LiquidGlassSignals(powerSave: true).prefersSolid, isTrue);
      expect(const LiquidGlassSignals(blurDisabled: true).prefersSolid, isTrue);
      expect(const LiquidGlassSignals(canBlur: false).prefersSolid, isTrue);
    });

    test('== and hashCode compare every field', () {
      expect(
        const LiquidGlassSignals(powerSave: true),
        const LiquidGlassSignals(powerSave: true),
      );
      expect(
        const LiquidGlassSignals(powerSave: true).hashCode,
        const LiquidGlassSignals(powerSave: true).hashCode,
      );
      expect(
        const LiquidGlassSignals(powerSave: true),
        isNot(const LiquidGlassSignals(canBlur: false)),
      );
    });
  });

  group('LiquidGlassPolicy.resolve', () {
    testWidgets('no signals → frosted', (tester) async {
      final context = await _context(tester);
      expect(
        const LiquidGlassPolicy().resolve(context, const LiquidGlassSignals()),
        LiquidGlassTier.frosted,
      );
    });

    testWidgets('each signal alone → solid', (tester) async {
      final context = await _context(tester);
      const policy = LiquidGlassPolicy(
        renderers: [_FakeRenderer(LiquidGlassTier.liquid)],
      );
      for (final signals in const [
        LiquidGlassSignals(reduceTransparency: true),
        LiquidGlassSignals(highContrast: true),
        LiquidGlassSignals(powerSave: true),
        LiquidGlassSignals(blurDisabled: true),
        LiquidGlassSignals(canBlur: false),
      ]) {
        expect(policy.resolve(context, signals), LiquidGlassTier.solid);
      }
    });

    testWidgets('a supported liquid renderer → liquid', (tester) async {
      final context = await _context(tester);
      const policy = LiquidGlassPolicy(
        renderers: [_FakeRenderer(LiquidGlassTier.liquid)],
      );
      expect(
        policy.resolve(context, const LiquidGlassSignals()),
        LiquidGlassTier.liquid,
      );
    });

    testWidgets('an unsupported liquid renderer → frosted', (tester) async {
      final context = await _context(tester);
      const policy = LiquidGlassPolicy(
        renderers: [_FakeRenderer(LiquidGlassTier.liquid, supported: false)],
      );
      expect(
        policy.resolve(context, const LiquidGlassSignals()),
        LiquidGlassTier.frosted,
      );
    });

    testWidgets('forcedTier wins over every signal', (tester) async {
      final context = await _context(tester);
      const solidSignals = LiquidGlassSignals(reduceTransparency: true);
      final logs = await _captureLogs(() async {
        expect(
          const LiquidGlassPolicy(
            forcedTier: LiquidGlassTier.frosted,
          ).resolve(context, solidSignals),
          LiquidGlassTier.frosted,
        );
        expect(
          const LiquidGlassPolicy(
            forcedTier: LiquidGlassTier.solid,
          ).resolve(context, const LiquidGlassSignals()),
          LiquidGlassTier.solid,
        );
        expect(
          const LiquidGlassPolicy(
            forcedTier: LiquidGlassTier.liquid,
            renderers: [_FakeRenderer(LiquidGlassTier.liquid)],
          ).resolve(context, solidSignals),
          LiquidGlassTier.liquid,
        );
      });
      expect(logs, isEmpty);
    });

    testWidgets('forced liquid without a renderer → frosted, logged once', (
      tester,
    ) async {
      final context = await _context(tester);
      const policy = LiquidGlassPolicy(forcedTier: LiquidGlassTier.liquid);
      final logs = await _captureLogs(() async {
        for (var i = 0; i < 2; i++) {
          expect(
            policy.resolve(context, const LiquidGlassSignals()),
            LiquidGlassTier.frosted,
          );
        }
      });
      expect(logs, hasLength(1));
      expect(logs.single, contains('liquid'));
    });

    testWidgets('isSupported that throws counts as unsupported and is '
        'reported', (tester) async {
      final context = await _context(tester);
      const policy = LiquidGlassPolicy(
        renderers: [_FakeRenderer(LiquidGlassTier.liquid, throws: true)],
      );
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = errors.add;
      try {
        expect(
          policy.resolve(context, const LiquidGlassSignals()),
          LiquidGlassTier.frosted,
        );
      } finally {
        FlutterError.onError = originalOnError;
      }
      expect(errors.single.library, 'liquid_shell');
      expect(errors.single.exception, isA<StateError>());
    });
  });

  group('LiquidGlassPolicy.rendererFor', () {
    testWidgets('built-ins fill the tiers nobody registered', (tester) async {
      final context = await _context(tester);
      const policy = LiquidGlassPolicy();
      expect(
        policy.rendererFor(context, LiquidGlassTier.frosted),
        isA<FrostedGlassRenderer>(),
      );
      expect(
        policy.rendererFor(context, LiquidGlassTier.solid),
        isA<SolidGlassRenderer>(),
      );
      expect(
        policy.rendererFor(context, LiquidGlassTier.liquid),
        isA<FrostedGlassRenderer>(),
      );
    });

    testWidgets('the first supported registered renderer wins', (
      tester,
    ) async {
      final context = await _context(tester);
      const unsupported = _FakeRenderer(
        LiquidGlassTier.frosted,
        supported: false,
      );
      const first = _FakeRenderer(LiquidGlassTier.frosted);
      const second = _FakeRenderer(LiquidGlassTier.frosted);
      const policy = LiquidGlassPolicy(
        renderers: [unsupported, first, second],
      );
      expect(
        identical(policy.rendererFor(context, LiquidGlassTier.frosted), first),
        isTrue,
      );
    });
  });

  test('== compares forcedTier and renderers', () {
    const renderer = _FakeRenderer(LiquidGlassTier.liquid);
    expect(
      const LiquidGlassPolicy(renderers: [renderer]),
      const LiquidGlassPolicy(renderers: [renderer]),
    );
    expect(
      const LiquidGlassPolicy().hashCode,
      const LiquidGlassPolicy().hashCode,
    );
    expect(
      const LiquidGlassPolicy(),
      isNot(const LiquidGlassPolicy(forcedTier: LiquidGlassTier.solid)),
    );
  });

  testWidgets('LiquidGlassScope.policyOf', (tester) async {
    const policy = LiquidGlassPolicy(forcedTier: LiquidGlassTier.solid);
    late LiquidGlassPolicy inside;
    late LiquidGlassPolicy outside;
    await tester.pumpWidget(
      Column(
        children: [
          Builder(
            builder: (context) {
              outside = LiquidGlassScope.policyOf(context);
              return const SizedBox();
            },
          ),
          LiquidGlassScope(
            policy: policy,
            child: Builder(
              builder: (context) {
                inside = LiquidGlassScope.policyOf(context);
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
    expect(inside, policy);
    expect(outside, const LiquidGlassPolicy());
  });
}
```

`liquid_shell/test/widget/glass_renderers_test.dart`, including the pixel-capture shadow test ported from the app:

```dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/glass/frosted_renderer.dart';
import 'package:liquid_shell/src/glass/outside_shadow.dart';
import 'package:liquid_shell/src/glass/solid_renderer.dart';

final _scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC));
final _theme = LiquidGlassTheme.fromColorScheme(_scheme);

Widget _host(LiquidGlassRenderer renderer, {bool grouped = false}) {
  final background = Builder(
    builder: (context) => renderer.buildBackground(
      context,
      LiquidGlassSpec(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        theme: _theme,
      ),
    ),
  );
  return MaterialApp(
    theme: ThemeData(colorScheme: _scheme),
    home: Center(
      child: SizedBox(
        width: 200,
        height: 80,
        child: grouped ? BackdropGroup(child: background) : background,
      ),
    ),
  );
}

void main() {
  group('frosted', () {
    testWidgets('blurs the backdrop with the theme sigma', (tester) async {
      await tester.pumpWidget(_host(const FrostedGlassRenderer()));
      final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
      expect(filter.filter, ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10));
      expect(const FrostedGlassRenderer().tier, LiquidGlassTier.frosted);
    });

    testWidgets('shares the nearest BackdropGroup', (tester) async {
      await tester.pumpWidget(
        _host(const FrostedGlassRenderer(), grouped: true),
      );
      final element = tester.element(find.byType(BackdropFilter));
      final render = tester.renderObject<RenderBackdropFilter>(
        find.byType(BackdropFilter),
      );
      expect(render.backdropKey, isNotNull);
      expect(render.backdropKey, BackdropGroup.of(element)!.backdropKey);
    });

    testWidgets('outside a BackdropGroup it reads the backdrop alone', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const FrostedGlassRenderer()));
      final render = tester.renderObject<RenderBackdropFilter>(
        find.byType(BackdropFilter),
      );
      expect(render.backdropKey, isNull);
    });

    testWidgets('draws tint, border, rim highlight and outside shadow', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const FrostedGlassRenderer()));
      final fills = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.color == _theme.tint);
      expect(fills, hasLength(1));
      expect(fills.single.border, Border.all(color: _theme.border));
      expect(find.byType(OutsideShadow), findsOneWidget);
      expect(find.byKey(FrostedGlassRenderer.rimKey), findsOneWidget);
    });
  });

  group('solid', () {
    testWidgets('has no blur, a solid fill and an outside shadow', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const SolidGlassRenderer()));
      expect(find.byType(BackdropFilter), findsNothing);
      final fills = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.color == _theme.solid);
      expect(fills, hasLength(1));
      expect(find.byType(OutsideShadow), findsOneWidget);
      expect(const SolidGlassRenderer().tier, LiquidGlassTier.solid);
    });
  });

  // The shadow must never show through the translucent tint: inside the
  // shape every pixel is one colour, and the shadow still darkens the area
  // just below the bottom edge. flutter_test paints shadows without blur, so
  // a leak would show as a hard grey band.
  testWidgets('the shadow stays outside the shape (pixel capture)', (
    tester,
  ) async {
    const inset = 32;
    const w = 200;
    const h = 96;
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorScheme: _scheme),
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: SizedBox(
                  width: w.toDouble(),
                  height: h.toDouble(),
                  child: Builder(
                    builder: (context) =>
                        const FrostedGlassRenderer().buildBackground(
                          context,
                          LiquidGlassSpec(
                            borderRadius: BorderRadius.circular(20),
                            theme: _theme,
                          ),
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final image = (await tester.runAsync(
      () => captureImage(tester.element(find.byKey(key))),
    ))!;
    final bytes = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    int red(int x, int y) => bytes.getUint8((y * image.width + x) * 4);

    const x = inset + w ~/ 2;
    // Skip 2px at each edge: the 1px border and the rim highlight.
    final inside = [for (var y = inset + 2; y < inset + h - 2; y++) red(x, y)];
    expect(
      inside.reduce((a, b) => a < b ? a : b),
      greaterThanOrEqualTo(248),
      reason: 'the inside of the glass is one colour: no shadow shows through',
    );
    final below = [
      for (var y = inset + h + 1; y < inset + h + 12; y++) red(x, y),
    ];
    expect(
      below.reduce((a, b) => a < b ? a : b),
      lessThan(250),
      reason: 'the shadow is still drawn outside the bottom edge',
    );
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `cd liquid_shell && fvm flutter test test/unit/glass_theme_test.dart test/unit/glass_policy_test.dart test/widget/glass_renderers_test.dart; cd ..`
Expected: FAIL, `Error: Undefined name 'LiquidGlassTheme'` and `Error when reading 'lib/src/glass/frosted_renderer.dart'`.

- [ ] **Step 3: Implement**

`liquid_shell/lib/src/glass/tier.dart`:

```dart
/// How a glass surface is drawn, from richest to plainest.
enum LiquidGlassTier {
  /// Refracting glass. Needs a registered renderer (none ships in this
  /// package yet).
  liquid,

  /// Blurred backdrop with a tint, border, rim highlight and shadow.
  frosted,

  /// Opaque fill. Used when accessibility or power signals ask for it.
  solid,
}
```

`liquid_shell/lib/src/glass/glass_theme.dart` (values from spec §5.9; the light/dark split follows the displayed theme):

```dart
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Colours and shapes of `liquid_shell` glass.
///
/// Add it to `ThemeData.extensions` to override the defaults; without it,
/// [LiquidGlassTheme.of] derives one from the displayed [ColorScheme].
@immutable
class LiquidGlassTheme extends ThemeExtension<LiquidGlassTheme> {
  /// Creates a glass theme.
  const LiquidGlassTheme({
    required this.tint,
    required this.solid,
    required this.border,
    required this.rimHighlight,
    required this.shadow,
    required this.labelStyle,
    this.borderWidth = 1,
    this.blurSigma = 10,
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
  });

  /// Defaults for light and dark, derived from [scheme] (spec §5.9).
  factory LiquidGlassTheme.fromColorScheme(ColorScheme scheme) {
    final light = scheme.brightness == Brightness.light;
    return LiquidGlassTheme(
      tint: scheme.surface.withValues(alpha: light ? 0.72 : 0.90),
      solid: scheme.surface,
      border: light
          ? scheme.outline.withValues(alpha: 0.28)
          : scheme.onSurface.withValues(alpha: 0.18),
      rimHighlight: const Color(
        0xFFFFFFFF,
      ).withValues(alpha: light ? 0.50 : 0.18),
      shadow: const BoxShadow(
        color: Color(0x24000000),
        offset: Offset(0, 6),
        blurRadius: 20,
        spreadRadius: -2,
      ),
      labelStyle: const TextStyle(
        fontSize: 10,
        height: 1.4,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }

  /// The theme extension if present, otherwise one derived from
  /// `Theme.of(context).colorScheme`. Never throws.
  static LiquidGlassTheme of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<LiquidGlassTheme>() ??
        LiquidGlassTheme.fromColorScheme(theme.colorScheme);
  }

  /// Frosted fill.
  final Color tint;

  /// Solid fill.
  final Color solid;

  /// Outline colour.
  final Color border;

  /// Outline width in logical pixels.
  final double borderWidth;

  /// Frosted top-edge highlight, fading to transparent at mid-height.
  final Color rimHighlight;

  /// Drop shadow, drawn outside the shape only.
  final BoxShadow shadow;

  /// Backdrop blur sigma of the frosted tier.
  final double blurSigma;

  /// Default bar shape (a pill).
  final BorderRadius borderRadius;

  /// Compact tab labels.
  final TextStyle labelStyle;

  @override
  LiquidGlassTheme copyWith({
    Color? tint,
    Color? solid,
    Color? border,
    double? borderWidth,
    Color? rimHighlight,
    BoxShadow? shadow,
    double? blurSigma,
    BorderRadius? borderRadius,
    TextStyle? labelStyle,
  }) => LiquidGlassTheme(
    tint: tint ?? this.tint,
    solid: solid ?? this.solid,
    border: border ?? this.border,
    borderWidth: borderWidth ?? this.borderWidth,
    rimHighlight: rimHighlight ?? this.rimHighlight,
    shadow: shadow ?? this.shadow,
    blurSigma: blurSigma ?? this.blurSigma,
    borderRadius: borderRadius ?? this.borderRadius,
    labelStyle: labelStyle ?? this.labelStyle,
  );

  @override
  LiquidGlassTheme lerp(covariant LiquidGlassTheme? other, double t) {
    if (other == null) return this;
    return LiquidGlassTheme(
      tint: Color.lerp(tint, other.tint, t)!,
      solid: Color.lerp(solid, other.solid, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderWidth: lerpDouble(borderWidth, other.borderWidth, t)!,
      rimHighlight: Color.lerp(rimHighlight, other.rimHighlight, t)!,
      shadow: BoxShadow.lerp(shadow, other.shadow, t)!,
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t)!,
      borderRadius: BorderRadius.lerp(borderRadius, other.borderRadius, t)!,
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LiquidGlassTheme &&
      other.tint == tint &&
      other.solid == solid &&
      other.border == border &&
      other.borderWidth == borderWidth &&
      other.rimHighlight == rimHighlight &&
      other.shadow == shadow &&
      other.blurSigma == blurSigma &&
      other.borderRadius == borderRadius &&
      other.labelStyle == labelStyle;

  @override
  int get hashCode => Object.hash(
    tint,
    solid,
    border,
    borderWidth,
    rimHighlight,
    shadow,
    blurSigma,
    borderRadius,
    labelStyle,
  );
}
```

`liquid_shell/lib/src/glass/renderer.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/glass/glass_theme.dart';
import 'package:liquid_shell/src/glass/tier.dart';

/// What a [LiquidGlassRenderer] needs to draw one surface.
@immutable
class LiquidGlassSpec {
  /// Creates a spec.
  const LiquidGlassSpec({required this.borderRadius, required this.theme});

  /// Shape of the surface.
  final BorderRadius borderRadius;

  /// Colours and blur.
  final LiquidGlassTheme theme;

  @override
  bool operator ==(Object other) =>
      other is LiquidGlassSpec &&
      other.borderRadius == borderRadius &&
      other.theme == theme;

  @override
  int get hashCode => Object.hash(borderRadius, theme);
}

/// Draws the background of a glass surface for one [LiquidGlassTier].
///
/// Register extra renderers (for example a liquid adapter) through
/// `LiquidGlassPolicy.renderers`.
abstract class LiquidGlassRenderer {
  /// Const constructor for subclasses.
  const LiquidGlassRenderer();

  /// The tier this renderer draws.
  LiquidGlassTier get tier;

  /// Whether this renderer can draw on this device right now.
  bool isSupported(BuildContext context) => true;

  /// The background layer only (blur, tint, rim, shadow), sized to fill its
  /// parent. Must not paint outside the shape except for a shadow.
  Widget buildBackground(BuildContext context, LiquidGlassSpec spec);
}
```

`liquid_shell/lib/src/glass/outside_shadow.dart` (the app's outside-only clip, re-typed):

```dart
import 'package:flutter/widgets.dart';

/// Paints [shadow] only OUTSIDE the rounded shape, so it never shows
/// through a translucent fill drawn on top.
class OutsideShadow extends StatelessWidget {
  /// Creates an outside-only shadow for [borderRadius].
  const OutsideShadow({
    required this.borderRadius,
    required this.shadow,
    super.key,
  });

  /// Shape the shadow belongs to.
  final BorderRadius borderRadius;

  /// The shadow to paint.
  final BoxShadow shadow;

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: _OutsideOf(borderRadius, shadow),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [shadow],
      ),
    ),
  );
}

class _OutsideOf extends CustomClipper<Path> {
  const _OutsideOf(this.borderRadius, this.shadow);

  final BorderRadius borderRadius;
  final BoxShadow shadow;

  @override
  Path getClip(Size size) {
    final shape = Offset.zero & size;
    // Reach of the shadow: offset + spread + about 3 sigma of its blur.
    final reach =
        shadow.offset.distance +
        shadow.spreadRadius.abs() +
        shadow.blurRadius * 1.5 +
        8;
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(shape.inflate(reach)),
      Path()..addRRect(borderRadius.toRRect(shape)),
    );
  }

  @override
  bool shouldReclip(_OutsideOf oldClipper) =>
      oldClipper.borderRadius != borderRadius || oldClipper.shadow != shadow;
}
```

`liquid_shell/lib/src/glass/frosted_renderer.dart`:

```dart
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/glass/outside_shadow.dart';
import 'package:liquid_shell/src/glass/renderer.dart';
import 'package:liquid_shell/src/glass/tier.dart';

/// Built-in frosted tier: blur → outside shadow → tint and border → rim.
class FrostedGlassRenderer extends LiquidGlassRenderer {
  /// Creates the frosted renderer.
  const FrostedGlassRenderer();

  /// Key of the rim highlight layer, for tests.
  static const rimKey = ValueKey<String>('liquid-glass-rim');

  @override
  LiquidGlassTier get tier => LiquidGlassTier.frosted;

  @override
  Widget buildBackground(BuildContext context, LiquidGlassSpec spec) {
    final theme = spec.theme;
    final radius = spec.borderRadius;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Shares one backdrop read with every sibling inside the nearest
        // BackdropGroup; outside a group it reads the backdrop on its own.
        ClipRRect(
          borderRadius: radius,
          child: BackdropFilter.grouped(
            filter: ui.ImageFilter.blur(
              sigmaX: theme.blurSigma,
              sigmaY: theme.blurSigma,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        // Above the blur, so the blur never samples the shadow.
        OutsideShadow(borderRadius: radius, shadow: theme.shadow),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.tint,
            borderRadius: radius,
            border: Border.all(color: theme.border, width: theme.borderWidth),
          ),
        ),
        CustomPaint(
          key: rimKey,
          painter: _RimPainter(radius, theme.rimHighlight),
        ),
      ],
    );
  }
}

/// A 1px stroke along the shape, from [color] at the top to transparent at
/// mid-height.
class _RimPainter extends CustomPainter {
  const _RimPainter(this.borderRadius, this.color);

  final BorderRadius borderRadius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.center,
        [color, color.withValues(alpha: 0)],
      );
    canvas.drawRRect(borderRadius.toRRect(rect).deflate(0.5), paint);
  }

  @override
  bool shouldRepaint(_RimPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius || oldDelegate.color != color;
}
```

`liquid_shell/lib/src/glass/solid_renderer.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/glass/outside_shadow.dart';
import 'package:liquid_shell/src/glass/renderer.dart';
import 'package:liquid_shell/src/glass/tier.dart';

/// Built-in solid tier: outside shadow, opaque fill and border. No blur.
class SolidGlassRenderer extends LiquidGlassRenderer {
  /// Creates the solid renderer.
  const SolidGlassRenderer();

  @override
  LiquidGlassTier get tier => LiquidGlassTier.solid;

  @override
  Widget buildBackground(BuildContext context, LiquidGlassSpec spec) {
    final theme = spec.theme;
    return Stack(
      fit: StackFit.expand,
      children: [
        OutsideShadow(borderRadius: spec.borderRadius, shadow: theme.shadow),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.solid,
            borderRadius: spec.borderRadius,
            border: Border.all(color: theme.border, width: theme.borderWidth),
          ),
        ),
      ],
    );
  }
}
```

`liquid_shell/lib/src/glass/policy.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/glass/frosted_renderer.dart';
import 'package:liquid_shell/src/glass/renderer.dart';
import 'package:liquid_shell/src/glass/solid_renderer.dart';
import 'package:liquid_shell/src/glass/tier.dart';

/// Everything [LiquidGlassPolicy.resolve] looks at besides the renderers.
@immutable
class LiquidGlassSignals {
  /// Creates a set of signals. Defaults describe a device with no
  /// accessibility or power restriction that can blur.
  const LiquidGlassSignals({
    this.reduceTransparency = false,
    this.highContrast = false,
    this.powerSave = false,
    this.blurDisabled = false,
    this.canBlur = true,
  });

  /// iOS Reduce Transparency; Android animations off or high contrast.
  final bool reduceTransparency;

  /// `MediaQuery.highContrastOf` (reported by iOS only).
  final bool highContrast;

  /// Android battery saver.
  final bool powerSave;

  /// Android 12+: the system disabled window blurs.
  final bool blurDisabled;

  /// False on Android without Impeller (no shader filters, API ≤ 28).
  final bool canBlur;

  /// Whether any signal asks for the solid tier.
  bool get prefersSolid =>
      reduceTransparency ||
      highContrast ||
      powerSave ||
      blurDisabled ||
      !canBlur;

  @override
  bool operator ==(Object other) =>
      other is LiquidGlassSignals &&
      other.reduceTransparency == reduceTransparency &&
      other.highContrast == highContrast &&
      other.powerSave == powerSave &&
      other.blurDisabled == blurDisabled &&
      other.canBlur == canBlur;

  @override
  int get hashCode => Object.hash(
    reduceTransparency,
    highContrast,
    powerSave,
    blurDisabled,
    canBlur,
  );
}

bool _loggedForcedFallback = false;

/// Resets the once-only debug log. Called by `debugResetLiquidGlassSignals`.
void debugResetPolicyLogging() => _loggedForcedFallback = false;

/// Chooses the tier and the renderer for every `LiquidGlass`.
@immutable
class LiquidGlassPolicy {
  /// Creates a policy. With no arguments it picks automatically and uses
  /// the built-in frosted and solid renderers.
  const LiquidGlassPolicy({this.forcedTier, this.renderers = const []});

  /// App override. Wins over every signal. `null` picks automatically.
  final LiquidGlassTier? forcedTier;

  /// Extra renderers, for example a liquid adapter. For each tier the first
  /// supported registered renderer wins; the built-in frosted and solid
  /// renderers fill the rest. Solid is always available.
  final List<LiquidGlassRenderer> renderers;

  static const _frosted = FrostedGlassRenderer();
  static const _solid = SolidGlassRenderer();

  /// The tier to draw.
  ///
  /// 1. [forcedTier], stepping down liquid → frosted → solid when it has no
  ///    supported renderer (logged once in debug builds).
  /// 2. [LiquidGlassSignals.prefersSolid] → solid.
  /// 3. Otherwise liquid when a supported liquid renderer is registered,
  ///    else frosted.
  LiquidGlassTier resolve(BuildContext context, LiquidGlassSignals signals) {
    final forced = forcedTier;
    if (forced != null) {
      final tier = rendererFor(context, forced).tier;
      if (tier != forced) _logForcedFallback(forced, tier);
      return tier;
    }
    if (signals.prefersSolid) return LiquidGlassTier.solid;
    return _registered(context, LiquidGlassTier.liquid) != null
        ? LiquidGlassTier.liquid
        : LiquidGlassTier.frosted;
  }

  /// The renderer that will draw [tier], after fallbacks.
  LiquidGlassRenderer rendererFor(BuildContext context, LiquidGlassTier tier) {
    final registered = _registered(context, tier);
    if (registered != null) return registered;
    return switch (tier) {
      LiquidGlassTier.liquid => rendererFor(context, LiquidGlassTier.frosted),
      LiquidGlassTier.frosted => _frosted,
      LiquidGlassTier.solid => _solid,
    };
  }

  LiquidGlassRenderer? _registered(BuildContext context, LiquidGlassTier tier) {
    for (final renderer in renderers) {
      if (renderer.tier == tier && _supported(renderer, context)) {
        return renderer;
      }
    }
    return null;
  }

  static bool _supported(LiquidGlassRenderer renderer, BuildContext context) {
    try {
      return renderer.isSupported(context);
    } on Object catch (exception, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'liquid_shell',
          context: ErrorDescription(
            'while checking ${renderer.runtimeType}.isSupported',
          ),
        ),
      );
      return false;
    }
  }

  static void _logForcedFallback(LiquidGlassTier forced, LiquidGlassTier used) {
    if (_loggedForcedFallback) return;
    _loggedForcedFallback = true;
    if (kDebugMode) {
      debugPrint(
        'liquid_shell: forced tier ${forced.name} has no supported renderer; '
        'drawing ${used.name}.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is LiquidGlassPolicy &&
      other.forcedTier == forcedTier &&
      listEquals(other.renderers, renderers);

  @override
  int get hashCode => Object.hash(forcedTier, Object.hashAll(renderers));
}
```

`liquid_shell/lib/src/glass/glass_scope.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/glass/policy.dart';

/// Sets the [LiquidGlassPolicy] for a subtree.
///
/// Put it in `MaterialApp.builder` for an app-wide policy. Without one,
/// `const LiquidGlassPolicy()` applies.
class LiquidGlassScope extends InheritedWidget {
  /// Creates a scope.
  const LiquidGlassScope({
    required this.policy,
    required super.child,
    super.key,
  });

  /// The policy for this subtree.
  final LiquidGlassPolicy policy;

  /// The nearest scope's policy, or `const LiquidGlassPolicy()`.
  static LiquidGlassPolicy policyOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LiquidGlassScope>()?.policy ??
      const LiquidGlassPolicy();

  @override
  bool updateShouldNotify(LiquidGlassScope oldWidget) =>
      policy != oldWidget.policy;
}
```

`liquid_shell/lib/liquid_shell.dart`:

```dart
/// Adaptive navigation shell with a Liquid Glass look for iOS and Android.
library;

export 'src/glass/glass_scope.dart';
export 'src/glass/glass_theme.dart';
export 'src/glass/policy.dart' show LiquidGlassPolicy, LiquidGlassSignals;
export 'src/glass/renderer.dart';
export 'src/glass/tier.dart';
```

- [ ] **Step 4: Run them to see them pass**

Run: `cd liquid_shell && fvm flutter test test/unit test/widget; cd ..`
Expected: `All tests passed!` (14 policy, 8 theme, 6 renderer, 3 floor tests).

Run: `make format-check analyze provenance coverage`
Expected: `✓ coverage 92.51% (173/187 lines) in liquid_shell/coverage/lcov.info ≥ 90.0%`.

- [ ] **Step 5: Commit**

```bash
.githooks/pre-commit
git add liquid_shell
git commit -m "feat(glass): tiers, theme, renderer seam, frosted and solid renderers, policy (VK-345)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: `LiquidGlass`, process-wide signals, tier cross-fade

**Files:**
- Create: `liquid_shell/lib/src/glass/signals_controller.dart`, `liquid_shell/lib/src/glass/liquid_glass.dart`
- Create: `liquid_shell/test/flutter_test_config.dart`, `liquid_shell/test/helpers/fake_signals_platform.dart`
- Modify: `liquid_shell/lib/liquid_shell.dart`, `liquid_shell/example/integration_test/signals_test.dart`
- Test: `liquid_shell/test/widget/liquid_glass_test.dart`

**Interfaces:**
- Consumes: Task 2 `LiquidShellPlatform.instance.watchSignals()`, `LiquidPlatformSignals`; Task 4 `LiquidGlassPolicy`, `LiquidGlassSignals`, `LiquidGlassScope.policyOf`, `LiquidGlassTheme.of`, `LiquidGlassSpec`, `debugResetPolicyLogging`.
- Produces (exported): `class LiquidGlass extends StatefulWidget { const LiquidGlass({required Widget child, BorderRadius? borderRadius, Key? key}); }`; `@visibleForTesting bool? debugLiquidGlassCanBlurOverride`; `@visibleForTesting void debugResetLiquidGlassSignals()`; re-export `LiquidPlatformSignals`.
- Produces (internal): `bool liquidGlassCanBlur()`; `LiquidSignalsController.instance` (`ValueListenable<LiquidPlatformSignals>`, `acquire()`, `release()`).
- Produces (tests): `class FakeSignalsPlatform extends LiquidShellPlatform { LiquidPlatformSignals current; int listeners; void emit(LiquidPlatformSignals); void emitError(Object); }`, `FakeSignalsPlatform installFakeSignals()`. `liquid_shell/test/flutter_test_config.dart` sets the blur override to `true` before each test and resets the signals after it.

- [ ] **Step 1: Test helpers and config**

`liquid_shell/test/helpers/fake_signals_platform.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// A [LiquidShellPlatform] whose signals a test sets with [emit].
///
/// Every listener first receives [current], then every later [emit].
class FakeSignalsPlatform extends LiquidShellPlatform {
  final _changes = StreamController<LiquidPlatformSignals>.broadcast();

  /// The value a new listener receives first.
  LiquidPlatformSignals current = LiquidPlatformSignals.none;

  /// Number of active listeners.
  int listeners = 0;

  /// Sends [signals] to every listener.
  void emit(LiquidPlatformSignals signals) {
    current = signals;
    _changes.add(signals);
  }

  /// Sends an error event to every listener.
  void emitError(Object error) => _changes.addError(error);

  @override
  Stream<LiquidPlatformSignals> watchSignals() {
    late final StreamController<LiquidPlatformSignals> controller;
    StreamSubscription<LiquidPlatformSignals>? forward;
    controller = StreamController<LiquidPlatformSignals>(
      onListen: () {
        listeners++;
        controller.add(current);
        forward = _changes.stream.listen(
          controller.add,
          onError: controller.addError,
        );
      },
      onCancel: () async {
        listeners--;
        await forward?.cancel();
      },
    );
    return controller.stream;
  }
}

/// Installs a [FakeSignalsPlatform] until the current test ends.
FakeSignalsPlatform installFakeSignals() {
  final original = LiquidShellPlatform.instance;
  final fake = FakeSignalsPlatform();
  LiquidShellPlatform.instance = fake;
  addTearDown(() => LiquidShellPlatform.instance = original);
  return fake;
}
```

`liquid_shell/test/flutter_test_config.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';

/// Runs before every test file in this package.
///
/// `flutter test` reports Android with no shader filters, so the device
/// probe would answer "cannot blur" and every glass would be solid. Tests
/// that exercise the probe set the override back to null themselves.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() => debugLiquidGlassCanBlurOverride = true);
  tearDown(() {
    debugLiquidGlassCanBlurOverride = null;
    debugResetLiquidGlassSignals();
  });
  await testMain();
}
```

- [ ] **Step 2: Write the failing widget tests**

`liquid_shell/test/widget/liquid_glass_test.dart`. A signal needs two pumps: one delivers the stream event, the next rebuilds:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';

import '../helpers/fake_signals_platform.dart';

final _scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC));

Widget _app({
  Widget child = const SizedBox(width: 120, height: 40),
  MediaQueryData mediaQuery = const MediaQueryData(),
  LiquidGlassPolicy? policy,
  List<ThemeExtension<dynamic>> extensions = const [],
  BorderRadius? borderRadius,
}) {
  Widget glass = Center(
    child: LiquidGlass(borderRadius: borderRadius, child: child),
  );
  if (policy != null) glass = LiquidGlassScope(policy: policy, child: glass);
  return MediaQuery(
    data: mediaQuery,
    child: MaterialApp(
      theme: ThemeData(colorScheme: _scheme, extensions: extensions),
      home: glass,
    ),
  );
}

Iterable<BoxDecoration> _fills(WidgetTester tester, Color color) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .map((box) => box.decoration)
    .whereType<BoxDecoration>()
    .where((d) => d.color == color);

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => count++),
    child: Text('count $count', textDirection: TextDirection.ltr),
  );
}

void main() {
  final glassTheme = LiquidGlassTheme.fromColorScheme(_scheme);

  testWidgets('frosted by default', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(_fills(tester, glassTheme.tint), hasLength(1));
  });

  testWidgets('each platform signal → solid; back to none → frosted', (
    tester,
  ) async {
    final platform = installFakeSignals();
    await tester.pumpWidget(_app());
    await tester.pump();

    for (final signals in const [
      LiquidPlatformSignals(reduceTransparency: true),
      LiquidPlatformSignals(powerSave: true),
      LiquidPlatformSignals(blurDisabled: true),
    ]) {
      platform.emit(signals);
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing, reason: '$signals');
      expect(_fills(tester, glassTheme.solid), hasLength(1));

      platform.emit(LiquidPlatformSignals.none);
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsOneWidget);
    }
  });

  testWidgets('high contrast → solid', (tester) async {
    await tester.pumpWidget(
      _app(mediaQuery: const MediaQueryData(highContrast: true)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('cannot blur → solid', (tester) async {
    debugLiquidGlassCanBlurOverride = false;
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('the blur probe only demotes Android (Q6)', (tester) async {
    debugLiquidGlassCanBlurOverride = null;
    // flutter test has no shader filters, like Android on Skia.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(_app(child: const SizedBox(width: 121)));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a forced tier from LiquidGlassScope wins', (tester) async {
    await tester.pumpWidget(
      _app(policy: const LiquidGlassPolicy(forcedTier: LiquidGlassTier.solid)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('a tier change cross-fades over 200ms, then drops the blur', (
    tester,
  ) async {
    final platform = installFakeSignals();
    await tester.pumpWidget(_app());
    await tester.pump();

    platform.emit(const LiquidPlatformSignals(reduceTransparency: true));
    await tester.pump(); // delivers the event
    await tester.pump(); // rebuilds; the fade starts here
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(BackdropFilter), findsOneWidget, reason: 'mid-fade');
    expect(_fills(tester, glassTheme.solid), hasLength(1));

    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('under disableAnimations the switch is instant', (tester) async {
    final platform = installFakeSignals();
    await tester.pumpWidget(
      _app(mediaQuery: const MediaQueryData(disableAnimations: true)),
    );
    await tester.pump();
    expect(find.byType(AnimatedSwitcher), findsNothing);

    platform.emit(const LiquidPlatformSignals(reduceTransparency: true));
    await tester.pump(); // delivers the event
    await tester.pump(); // rebuilds with no fade
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('a tier change keeps the child state', (tester) async {
    final platform = installFakeSignals();
    await tester.pumpWidget(_app(child: const _Counter()));
    await tester.pump();
    await tester.tap(find.byType(_Counter));
    await tester.pump();
    expect(find.text('count 1'), findsOneWidget);

    platform.emit(const LiquidPlatformSignals(reduceTransparency: true));
    await tester.pumpAndSettle();
    expect(find.text('count 1'), findsOneWidget);
  });

  testWidgets('an error event falls back to no signals', (tester) async {
    final platform = installFakeSignals();
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    try {
      await tester.pumpWidget(_app());
      await tester.pump();
      platform.emit(const LiquidPlatformSignals(powerSave: true));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing);

      platform.emitError(StateError('channel broke'));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsOneWidget);
    } finally {
      debugPrint = original;
    }
    expect(logs.single, contains('channel broke'));
  });

  testWidgets('listens while any glass is mounted, stops after the last', (
    tester,
  ) async {
    final platform = installFakeSignals();
    await tester.pumpWidget(
      Column(
        children: [
          _app(),
          _app(child: const SizedBox(width: 10, height: 10)),
        ],
      ),
    );
    await tester.pump();
    expect(platform.listeners, 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(platform.listeners, 0);

    await tester.pumpWidget(_app());
    await tester.pump();
    expect(platform.listeners, 1);
  });

  testWidgets('honours a custom theme extension and borderRadius', (
    tester,
  ) async {
    final custom = glassTheme.copyWith(tint: const Color(0x80FF0000));
    await tester.pumpWidget(
      _app(extensions: [custom], borderRadius: BorderRadius.circular(8)),
    );
    await tester.pump();
    final fill = _fills(tester, const Color(0x80FF0000)).single;
    expect(fill.borderRadius, BorderRadius.circular(8));
  });

  testWidgets('without a theme extension nothing throws', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: LiquidGlass(child: SizedBox(width: 10))),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
```

Run: `cd liquid_shell && fvm flutter test test/widget/liquid_glass_test.dart; cd ..`
Expected: FAIL, `Error: Method not found: 'LiquidGlass'`.

- [ ] **Step 3: Implement**

`liquid_shell/lib/src/glass/signals_controller.dart`:

```dart
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:liquid_shell/src/glass/policy.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// Test hook replacing the device blur probe. `null` (the default) probes.
///
/// `flutter test` reports Android without shader filters, so tests that
/// want frosted glass set this to `true`.
@visibleForTesting
bool? debugLiquidGlassCanBlurOverride;

/// Whether this device can blur behind glass.
///
/// False only on Android without Impeller (`isShaderFilterSupported` is
/// false on Skia, API ≤ 28). Reads `defaultTargetPlatform`, not the theme:
/// the capability belongs to the device.
bool liquidGlassCanBlur() =>
    debugLiquidGlassCanBlurOverride ??
    !(defaultTargetPlatform == TargetPlatform.android &&
        !ui.ImageFilter.isShaderFilterSupported);

/// Process-wide platform signals.
///
/// Starts the platform stream when the first `LiquidGlass` mounts and
/// cancels it when the last one unmounts. Keeps the last value when the
/// stream closes; an error event resets to [LiquidPlatformSignals.none].
class LiquidSignalsController extends ChangeNotifier
    implements ValueListenable<LiquidPlatformSignals> {
  LiquidSignalsController._();

  /// The single instance.
  static final instance = LiquidSignalsController._();

  LiquidPlatformSignals _value = LiquidPlatformSignals.none;
  int _users = 0;
  StreamSubscription<LiquidPlatformSignals>? _subscription;

  @override
  LiquidPlatformSignals get value => _value;

  /// Registers one user; the first one starts the platform stream.
  void acquire() {
    _users++;
    if (_users == 1) {
      _subscription = LiquidShellPlatform.instance.watchSignals().listen(
        _set,
        onError: (Object error) {
          if (kDebugMode) {
            debugPrint('liquid_shell signals: $error; using none');
          }
          _set(LiquidPlatformSignals.none);
        },
      );
    }
  }

  /// Unregisters one user; the last one cancels the platform stream.
  void release() {
    if (_users == 0) return;
    _users--;
    if (_users == 0) _cancel();
  }

  void _cancel() {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  void _set(LiquidPlatformSignals value) {
    if (value == _value) return;
    _value = value;
    notifyListeners();
  }
}

/// Test hook: forgets the platform signals, the stream and the once-only
/// debug logs, so the next test starts clean.
@visibleForTesting
void debugResetLiquidGlassSignals() {
  final controller = LiquidSignalsController.instance
    .._cancel()
    .._users = 0;
  controller._set(LiquidPlatformSignals.none);
  debugResetPolicyLogging();
}
```

`liquid_shell/lib/src/glass/liquid_glass.dart` (the child is always the second `Stack` child; the blur layer leaves the tree once the fade to solid ends):

```dart
import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/glass/glass_scope.dart';
import 'package:liquid_shell/src/glass/glass_theme.dart';
import 'package:liquid_shell/src/glass/policy.dart';
import 'package:liquid_shell/src/glass/renderer.dart';
import 'package:liquid_shell/src/glass/signals_controller.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// A glass surface.
///
/// The background comes from the renderer the [LiquidGlassPolicy] picks
/// (see [LiquidGlassScope]); [child] is drawn on top. A tier change
/// cross-fades over 200ms (instantly under reduce motion) and never
/// rebuilds [child], so focus and scroll position survive.
class LiquidGlass extends StatefulWidget {
  /// Creates a glass surface around [child].
  const LiquidGlass({required this.child, this.borderRadius, super.key});

  /// The content, drawn above the glass.
  final Widget child;

  /// Shape of the surface. `null` uses [LiquidGlassTheme.borderRadius].
  final BorderRadius? borderRadius;

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> {
  static const _fade = Duration(milliseconds: 200);
  final _signals = LiquidSignalsController.instance;

  @override
  void initState() {
    super.initState();
    _signals.acquire();
  }

  @override
  void dispose() {
    _signals.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<LiquidPlatformSignals>(
        valueListenable: _signals,
        child: widget.child,
        builder: (context, platform, child) {
          final policy = LiquidGlassScope.policyOf(context);
          final tier = policy.resolve(
            context,
            LiquidGlassSignals(
              reduceTransparency: platform.reduceTransparency,
              highContrast: MediaQuery.highContrastOf(context),
              powerSave: platform.powerSave,
              blurDisabled: platform.blurDisabled,
              canBlur: liquidGlassCanBlur(),
            ),
          );
          final theme = LiquidGlassTheme.of(context);
          final renderer = policy.rendererFor(context, tier);
          final background = KeyedSubtree(
            key: ObjectKey(renderer),
            child: renderer.buildBackground(
              context,
              LiquidGlassSpec(
                borderRadius: widget.borderRadius ?? theme.borderRadius,
                theme: theme,
              ),
            ),
          );
          return Stack(
            children: [
              Positioned.fill(
                child: MediaQuery.disableAnimationsOf(context)
                    ? background
                    : AnimatedSwitcher(
                        duration: _fade,
                        layoutBuilder: (current, previous) => Stack(
                          fit: StackFit.expand,
                          children: [...previous, ?current],
                        ),
                        child: background,
                      ),
              ),
              child!,
            ],
          );
        },
      );
}
```

`liquid_shell/lib/liquid_shell.dart`:

```dart
/// Adaptive navigation shell with a Liquid Glass look for iOS and Android.
library;

export 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart'
    show LiquidPlatformSignals;

export 'src/glass/glass_scope.dart';
export 'src/glass/glass_theme.dart';
export 'src/glass/liquid_glass.dart';
export 'src/glass/policy.dart' show LiquidGlassPolicy, LiquidGlassSignals;
export 'src/glass/renderer.dart';
export 'src/glass/signals_controller.dart'
    show debugLiquidGlassCanBlurOverride, debugResetLiquidGlassSignals;
export 'src/glass/tier.dart';
```

- [ ] **Step 4: Run them to see them pass**

Run: `cd liquid_shell && fvm flutter test; cd ..`
Expected: `All tests passed!` (`liquid_glass_test.dart`: 13 tests).

Run: `make format-check analyze coverage`
Expected: `✓ coverage 94.90% (242/255 lines) in liquid_shell/coverage/lcov.info ≥ 90.0%`.

- [ ] **Step 5: Assert the tier on devices**

`liquid_shell/example/integration_test/signals_test.dart` becomes:

```dart
// Signal channel round-trip on a real simulator or emulator (spec §10.5).
//
// tool/integration_ios.sh and tool/integration_android.sh pass the expected
// value of each signal with --dart-define. An empty value means "do not
// check this field" (for example, battery saver also disables window blurs).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

const _expectReduceTransparency = String.fromEnvironment(
  'EXPECT_REDUCE_TRANSPARENCY',
);
const _expectPowerSave = String.fromEnvironment('EXPECT_POWER_SAVE');
const _expectBlurDisabled = String.fromEnvironment('EXPECT_BLUR_DISABLED');

/// Solid is expected when the run switched any signal on.
final _expectSolid = [
  _expectReduceTransparency,
  _expectPowerSave,
  _expectBlurDisabled,
].contains('true');

void _check(String expected, {required bool actual, required String name}) {
  if (expected.isEmpty) return;
  expect(actual, expected == 'true', reason: name);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the platform package registered the event channel', (
    tester,
  ) async {
    expect(
      LiquidShellPlatform.instance,
      isA<EventChannelLiquidShellPlatform>(),
    );
  });

  testWidgets('watchSignals emits a well-formed value within 5 s', (
    tester,
  ) async {
    final signals = await LiquidShellPlatform.instance
        .watchSignals()
        .first
        .timeout(const Duration(seconds: 5));
    debugPrint('liquid_shell integration: $signals');

    _check(
      _expectReduceTransparency,
      actual: signals.reduceTransparency,
      name: 'reduceTransparency',
    );
    _check(_expectPowerSave, actual: signals.powerSave, name: 'powerSave');
    _check(
      _expectBlurDisabled,
      actual: signals.blurDisabled,
      name: 'blurDisabled',
    );
  });

  testWidgets('glass draws the tier the signals ask for', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: LiquidGlass(child: SizedBox(width: 200, height: 60)),
        ),
      ),
    );
    // The first channel event arrives asynchronously, then the tier fades.
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(
      find.byType(BackdropFilter),
      _expectSolid ? findsNothing : findsOneWidget,
    );
  });
}
```

Run: `make integration-ios && make integration-android`
Expected: `+4: All tests passed!` in every run; `✓ iOS integration passed`, `✓ Android integration passed`.

- [ ] **Step 6: Commit**

```bash
.githooks/pre-commit
git add liquid_shell
git commit -m "feat(glass): LiquidGlass widget, process-wide signals, tier cross-fade (VK-345)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Destinations, badges, trailing action, strings

**Files:**
- Create: `liquid_shell/lib/src/destinations/{destination,badge,tab_action}.dart`, `liquid_shell/lib/src/shell/strings.dart`
- Modify: `liquid_shell/lib/liquid_shell.dart`
- Test: `liquid_shell/test/unit/destinations_test.dart`, `liquid_shell/test/widget/badge_view_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces (exported): `enum LiquidPlacement { everywhere, sidebarOnly }`; `class LiquidDestination { const LiquidDestination({required Widget icon, required String label, Widget? selectedIcon, LiquidBadge? badge, LiquidPlacement placement = LiquidPlacement.everywhere}); }`; `sealed class LiquidBadge { const factory LiquidBadge.count(int count, {int max}); const factory LiquidBadge.dot(); }`, `final class LiquidCountBadge` (`count`, `max = 99`), `final class LiquidDotBadge`; `class LiquidTabAction { const LiquidTabAction({required Widget icon, required VoidCallback onPressed, required String semanticLabel}); }`; `class LiquidShellStrings` (six fields, English defaults, `static String defaultBadgeCount(int)`).
- Produces (internal): `bool badgeVisible(LiquidBadge?)`, `String badgeText(LiquidCountBadge)`, `String badgeSemanticsLabel(String label, LiquidBadge? badge, LiquidShellStrings strings)`, `class LiquidBadgeView extends StatelessWidget { const LiquidBadgeView({required LiquidBadge badge}); }`.

- [ ] **Step 1: Write the failing tests**

`liquid_shell/test/unit/destinations_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/destinations/badge.dart';

void main() {
  group('LiquidDestination', () {
    test('defaults: everywhere, no badge, no selected icon', () {
      const destination = LiquidDestination(
        icon: Icon(Icons.home_outlined),
        label: 'Home',
      );
      expect(destination.placement, LiquidPlacement.everywhere);
      expect(destination.badge, isNull);
      expect(destination.selectedIcon, isNull);
    });

    test('== compares every field', () {
      const icon = Icon(Icons.home_outlined);
      expect(
        const LiquidDestination(icon: icon, label: 'Home'),
        const LiquidDestination(icon: icon, label: 'Home'),
      );
      expect(
        const LiquidDestination(icon: icon, label: 'Home').hashCode,
        const LiquidDestination(icon: icon, label: 'Home').hashCode,
      );
      expect(
        const LiquidDestination(icon: icon, label: 'Home'),
        isNot(
          const LiquidDestination(
            icon: icon,
            label: 'Home',
            placement: LiquidPlacement.sidebarOnly,
          ),
        ),
      );
      expect(
        const LiquidDestination(icon: icon, label: 'Home'),
        isNot(
          const LiquidDestination(
            icon: icon,
            label: 'Home',
            badge: LiquidBadge.dot(),
          ),
        ),
      );
    });
  });

  group('LiquidBadge', () {
    test('count defaults max to 99', () {
      const badge = LiquidBadge.count(3);
      expect(badge, isA<LiquidCountBadge>());
      expect((badge as LiquidCountBadge).max, 99);
      expect(badge.count, 3);
    });

    test('count asserts a non-negative count and a positive max', () {
      expect(() => LiquidCountBadge(-1), throwsAssertionError);
      expect(() => LiquidCountBadge(1, max: 0), throwsAssertionError);
    });

    test('== by value', () {
      expect(const LiquidBadge.count(3), const LiquidBadge.count(3));
      expect(
        const LiquidBadge.count(3).hashCode,
        const LiquidBadge.count(3).hashCode,
      );
      expect(
        const LiquidBadge.count(3),
        isNot(const LiquidBadge.count(3, max: 9)),
      );
      expect(const LiquidBadge.dot(), const LiquidBadge.dot());
      expect(
        const LiquidBadge.dot().hashCode,
        const LiquidBadge.dot().hashCode,
      );
    });

    test('text shows max+ above max', () {
      expect(badgeText(const LiquidCountBadge(3)), '3');
      expect(badgeText(const LiquidCountBadge(99)), '99');
      expect(badgeText(const LiquidCountBadge(120)), '99+');
      expect(badgeText(const LiquidCountBadge(10, max: 9)), '9+');
    });

    test('visibility: count 0 is hidden, dot is shown', () {
      expect(badgeVisible(null), isFalse);
      expect(badgeVisible(const LiquidCountBadge(0)), isFalse);
      expect(badgeVisible(const LiquidCountBadge(1)), isTrue);
      expect(badgeVisible(const LiquidDotBadge()), isTrue);
    });

    test('semantics label appends the badge', () {
      const strings = LiquidShellStrings();
      expect(badgeSemanticsLabel('Inbox', null, strings), 'Inbox');
      expect(
        badgeSemanticsLabel('Inbox', const LiquidCountBadge(0), strings),
        'Inbox',
      );
      expect(
        badgeSemanticsLabel('Inbox', const LiquidCountBadge(120), strings),
        'Inbox, 120 new',
      );
      expect(
        badgeSemanticsLabel('Inbox', const LiquidDotBadge(), strings),
        'Inbox, New',
      );
    });
  });

  group('LiquidTabAction', () {
    test('== compares every field', () {
      void onPressed() {}
      const icon = Icon(Icons.search);
      expect(
        LiquidTabAction(icon: icon, onPressed: onPressed, semanticLabel: 'S'),
        LiquidTabAction(icon: icon, onPressed: onPressed, semanticLabel: 'S'),
      );
      expect(
        LiquidTabAction(
          icon: icon,
          onPressed: onPressed,
          semanticLabel: 'S',
        ).hashCode,
        LiquidTabAction(
          icon: icon,
          onPressed: onPressed,
          semanticLabel: 'S',
        ).hashCode,
      );
      expect(
        LiquidTabAction(icon: icon, onPressed: onPressed, semanticLabel: 'S'),
        isNot(
          LiquidTabAction(icon: icon, onPressed: onPressed, semanticLabel: 'T'),
        ),
      );
    });
  });

  group('LiquidShellStrings', () {
    test('English defaults', () {
      const strings = LiquidShellStrings();
      expect(strings.showSidebar, 'Show sidebar');
      expect(strings.hideSidebar, 'Hide sidebar');
      expect(strings.tabBarExpanded, 'Navigation bar opened');
      expect(strings.expandTabBarHint, 'Tap to open the navigation bar');
      expect(strings.badgeDot, 'New');
      expect(strings.badgeCount(3), '3 new');
      expect(LiquidShellStrings.defaultBadgeCount(7), '7 new');
    });

    test('== compares every field', () {
      expect(const LiquidShellStrings(), const LiquidShellStrings());
      expect(
        const LiquidShellStrings().hashCode,
        const LiquidShellStrings().hashCode,
      );
      expect(
        const LiquidShellStrings(),
        isNot(const LiquidShellStrings(badgeDot: 'Mới')),
      );
    });
  });
}
```

`liquid_shell/test/widget/badge_view_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/destinations/badge.dart';

final _scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC));

Future<void> _pump(WidgetTester tester, LiquidBadge badge) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData(colorScheme: _scheme),
    home: Center(child: LiquidBadgeView(badge: badge)),
  ),
);

void main() {
  testWidgets('count is a capsule with onError text on error', (tester) async {
    await _pump(tester, const LiquidBadge.count(3));
    final text = tester.widget<Text>(find.text('3'));
    expect(text.style!.color, _scheme.onError);
    expect(text.style!.fontSize, 11);
    expect(text.style!.fontWeight, FontWeight.w600);
    final box = tester.getSize(find.byType(LiquidBadgeView));
    expect(box.width, greaterThanOrEqualTo(16));
    expect(box.height, greaterThanOrEqualTo(16));
    final decoration =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byType(LiquidBadgeView),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(decoration.color, _scheme.error);
  });

  testWidgets('overflow shows max+', (tester) async {
    await _pump(tester, const LiquidBadge.count(120));
    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('count 0 draws nothing', (tester) async {
    await _pump(tester, const LiquidBadge.count(0));
    expect(find.byType(Text), findsNothing);
    expect(tester.getSize(find.byType(LiquidBadgeView)), Size.zero);
  });

  testWidgets('dot is 8×8 in the error colour', (tester) async {
    await _pump(tester, const LiquidBadge.dot());
    expect(tester.getSize(find.byType(LiquidBadgeView)), const Size(8, 8));
  });

  testWidgets('the badge adds no semantics node of its own', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, const LiquidBadge.count(3));
    expect(find.bySemanticsLabel('3'), findsNothing);
    handle.dispose();
  });
}
```

Run: `cd liquid_shell && fvm flutter test test/unit/destinations_test.dart test/widget/badge_view_test.dart; cd ..`
Expected: FAIL, `Error when reading 'lib/src/destinations/badge.dart'` and `Method not found: 'LiquidDestination'`.

- [ ] **Step 2: Implement**

`liquid_shell/lib/src/shell/strings.dart`:

```dart
import 'package:flutter/foundation.dart';

/// Every user-visible string of the shell, with English defaults.
///
/// Destination labels and the trailing action label come from the app
/// (`LiquidDestination.label`, `LiquidTabAction.semanticLabel`). Localise by
/// building this object from your own i18n system.
@immutable
class LiquidShellStrings {
  /// Creates the strings. Every argument has an English default.
  const LiquidShellStrings({
    this.showSidebar = 'Show sidebar',
    this.hideSidebar = 'Hide sidebar',
    this.tabBarExpanded = 'Navigation bar opened',
    this.expandTabBarHint = 'Tap to open the navigation bar',
    this.badgeDot = 'New',
    this.badgeCount = defaultBadgeCount,
  });

  /// Tooltip and semantics of the show-sidebar toggle.
  final String showSidebar;

  /// The sidebar hide button and the overlay barrier label.
  final String hideSidebar;

  /// Announced when the minimised tab bar expands.
  final String tabBarExpanded;

  /// Semantics hint of the minimised tab bar.
  final String expandTabBarHint;

  /// Spoken after a destination label when it has a dot badge.
  final String badgeDot;

  /// Spoken after a destination label when it has a count badge.
  final String Function(int count) badgeCount;

  /// The default [badgeCount]: `'3 new'`.
  static String defaultBadgeCount(int count) => '$count new';

  @override
  bool operator ==(Object other) =>
      other is LiquidShellStrings &&
      other.showSidebar == showSidebar &&
      other.hideSidebar == hideSidebar &&
      other.tabBarExpanded == tabBarExpanded &&
      other.expandTabBarHint == expandTabBarHint &&
      other.badgeDot == badgeDot &&
      other.badgeCount == badgeCount;

  @override
  int get hashCode => Object.hash(
    showSidebar,
    hideSidebar,
    tabBarExpanded,
    expandTabBarHint,
    badgeDot,
    badgeCount,
  );
}
```

`liquid_shell/lib/src/destinations/badge.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell/src/shell/strings.dart';

/// A badge on a destination: a count or a dot.
@immutable
sealed class LiquidBadge {
  const LiquidBadge._();

  /// Numeric badge. Shows "max+" above [LiquidCountBadge.max]. Hidden when
  /// the count is 0.
  const factory LiquidBadge.count(int count, {int max}) = LiquidCountBadge;

  /// Small dot with no number.
  const factory LiquidBadge.dot() = LiquidDotBadge;
}

/// A numeric badge. See [LiquidBadge.count].
final class LiquidCountBadge extends LiquidBadge {
  /// Creates a count badge. [count] must not be negative.
  const LiquidCountBadge(this.count, {this.max = 99})
    : assert(count >= 0, 'count must not be negative'),
      assert(max > 0, 'max must be positive'),
      super._();

  /// The number to show. 0 hides the badge.
  final int count;

  /// Above this the badge shows "max+".
  final int max;

  @override
  bool operator ==(Object other) =>
      other is LiquidCountBadge && other.count == count && other.max == max;

  @override
  int get hashCode => Object.hash(count, max);
}

/// A dot badge. See [LiquidBadge.dot].
final class LiquidDotBadge extends LiquidBadge {
  /// Creates a dot badge.
  const LiquidDotBadge() : super._();

  @override
  bool operator ==(Object other) => other is LiquidDotBadge;

  @override
  int get hashCode => (LiquidDotBadge).hashCode;
}

/// Whether [badge] draws anything. A count of 0 (or a negative count in
/// release builds) is hidden.
bool badgeVisible(LiquidBadge? badge) => switch (badge) {
  null => false,
  LiquidDotBadge() => true,
  LiquidCountBadge(:final count) => count > 0,
};

/// The visible text of a count badge.
String badgeText(LiquidCountBadge badge) =>
    badge.count > badge.max ? '${badge.max}+' : '${badge.count}';

/// [label] followed by the spoken badge, for example "Inbox, 3 new".
String badgeSemanticsLabel(
  String label,
  LiquidBadge? badge,
  LiquidShellStrings strings,
) {
  if (!badgeVisible(badge)) return label;
  return switch (badge!) {
    LiquidDotBadge() => '$label, ${strings.badgeDot}',
    LiquidCountBadge(:final count) => '$label, ${strings.badgeCount(count)}',
  };
}

/// Draws a [LiquidBadge]: an error-coloured capsule (min 16×16, 11/16 w600
/// text) or an 8×8 dot. Adds no semantics; the label carries the badge.
class LiquidBadgeView extends StatelessWidget {
  /// Creates the badge view.
  const LiquidBadgeView({required this.badge, super.key});

  /// The badge to draw.
  final LiquidBadge badge;

  @override
  Widget build(BuildContext context) {
    if (!badgeVisible(badge)) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: switch (badge) {
        LiquidDotBadge() => SizedBox.square(
          dimension: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.error,
              shape: BoxShape.circle,
            ),
          ),
        ),
        final LiquidCountBadge count => DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.error,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  badgeText(count),
                  style: TextStyle(
                    fontSize: 11,
                    height: 16 / 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.onError,
                  ),
                ),
              ),
            ),
          ),
        ),
      },
    );
  }
}
```

`liquid_shell/lib/src/destinations/destination.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/destinations/badge.dart';

/// Where a destination appears.
enum LiquidPlacement {
  /// Tab bar and sidebar.
  everywhere,

  /// Sidebar only. Never in the tab bar.
  sidebarOnly,
}

/// One navigation destination: a tab bar cell and a sidebar row.
@immutable
class LiquidDestination {
  /// Creates a destination.
  const LiquidDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
    this.badge,
    this.placement = LiquidPlacement.everywhere,
  });

  /// Icon when not selected. Sized and coloured by the shell.
  final Widget icon;

  /// Icon when selected. Falls back to [icon].
  final Widget? selectedIcon;

  /// Visible text and semantics label. Must not be empty.
  final String label;

  /// Optional count or dot.
  final LiquidBadge? badge;

  /// Tab bar and sidebar, or sidebar only.
  final LiquidPlacement placement;

  @override
  bool operator ==(Object other) =>
      other is LiquidDestination &&
      other.icon == icon &&
      other.selectedIcon == selectedIcon &&
      other.label == label &&
      other.badge == badge &&
      other.placement == placement;

  @override
  int get hashCode => Object.hash(icon, selectedIcon, label, badge, placement);
}
```

`liquid_shell/lib/src/destinations/tab_action.dart`:

```dart
import 'package:flutter/widgets.dart';

/// An action at the trailing end of the tab bar (for example search). Also
/// shown as the first sidebar row while the sidebar is visible.
@immutable
class LiquidTabAction {
  /// Creates an action.
  const LiquidTabAction({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
  });

  /// The icon. Sized and coloured by the shell.
  final Widget icon;

  /// Called on tap.
  final VoidCallback onPressed;

  /// Screen-reader label and tooltip. Also the visible text of the sidebar
  /// row.
  final String semanticLabel;

  @override
  bool operator ==(Object other) =>
      other is LiquidTabAction &&
      other.icon == icon &&
      other.onPressed == onPressed &&
      other.semanticLabel == semanticLabel;

  @override
  int get hashCode => Object.hash(icon, onPressed, semanticLabel);
}
```

`liquid_shell/lib/liquid_shell.dart`:

```dart
/// Adaptive navigation shell with a Liquid Glass look for iOS and Android.
library;

export 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart'
    show LiquidPlatformSignals;

export 'src/destinations/badge.dart'
    show LiquidBadge, LiquidCountBadge, LiquidDotBadge;
export 'src/destinations/destination.dart';
export 'src/destinations/tab_action.dart';
export 'src/glass/glass_scope.dart';
export 'src/glass/glass_theme.dart';
export 'src/glass/liquid_glass.dart';
export 'src/glass/policy.dart' show LiquidGlassPolicy, LiquidGlassSignals;
export 'src/glass/renderer.dart';
export 'src/glass/signals_controller.dart'
    show debugLiquidGlassCanBlurOverride, debugResetLiquidGlassSignals;
export 'src/glass/tier.dart';
export 'src/shell/strings.dart';
```

- [ ] **Step 3: Run them to see them pass**

Run: `cd liquid_shell && fvm flutter test test/unit/destinations_test.dart test/widget/badge_view_test.dart; cd ..`
Expected: `+16: All tests passed!`

Run: `make format-check analyze provenance coverage`
Expected: `✓ coverage 96.12% (322/335 lines) in liquid_shell/coverage/lcov.info ≥ 90.0%`.

- [ ] **Step 4: Commit**

```bash
.githooks/pre-commit
git add liquid_shell
git commit -m "feat(shell): destinations, badges, trailing action and strings (VK-345)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: `LiquidTabBar` (public), AX text scale, large content viewer

**Files:**
- Create: `liquid_shell/lib/src/chrome/{text_scale,large_content_viewer,tab_bar}.dart`
- Modify: `liquid_shell/lib/liquid_shell.dart`
- Test: `liquid_shell/test/widget/tab_bar_test.dart`

**Interfaces:**
- Consumes: Task 5 `LiquidGlass`; Task 4 `LiquidGlassTheme.of(context).labelStyle`; Task 6 `LiquidDestination`, `LiquidPlacement`, `LiquidTabAction`, `LiquidShellStrings`, `badgeVisible`, `badgeSemanticsLabel`, `LiquidBadgeView`.
- Produces (exported): `enum LiquidTabBarPosition { bottom, top }`; `class LiquidTabBar extends StatelessWidget { const LiquidTabBar({required List<LiquidDestination> destinations, required int selectedIndex, required ValueChanged<int> onDestinationSelected, LiquidTabBarPosition position = LiquidTabBarPosition.bottom, LiquidTabAction? trailing, bool minimized = false, VoidCallback? onExpand, LiquidShellStrings strings = const LiquidShellStrings(), Key? key}); }`. It draws the row only (pill + 8pt gap + circle); the caller adds margins.
- Produces (internal): `const double kLiquidTabBarTrailingGap = 8`; `class LiquidActionCircle`; `const kAxTextScale = 1.6`, `const kAxMaxIconSize = 36`, `bool isAxTextScale(BuildContext)`, `double axIconSize(BuildContext, double base)`; `class LargeContentViewer({required Widget icon, required String label, required Widget child})` with `static const overlayKey`.

- [ ] **Step 1: Write the failing tests**

`liquid_shell/test/widget/tab_bar_test.dart`. Cells use `excludeSemantics`, so their nodes expose a tap action but no focus action:

```dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/chrome/large_content_viewer.dart';

final _scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC));

const _destinations = [
  LiquidDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
  LiquidDestination(
    icon: Icon(Icons.inbox_outlined),
    label: 'Inbox',
    badge: LiquidBadge.count(120),
  ),
  LiquidDestination(
    icon: Icon(Icons.bar_chart),
    label: 'Reports',
    placement: LiquidPlacement.sidebarOnly,
  ),
  LiquidDestination(
    icon: Icon(Icons.settings_outlined),
    label: 'Settings',
    badge: LiquidBadge.dot(),
  ),
];

Widget _host({
  int selectedIndex = 0,
  ValueChanged<int>? onSelected,
  LiquidTabBarPosition position = LiquidTabBarPosition.bottom,
  LiquidTabAction? trailing,
  bool minimized = false,
  VoidCallback? onExpand,
  List<LiquidDestination> destinations = _destinations,
  double textScale = 1,
  bool disableAnimations = false,
  double width = 393,
  TextDirection direction = TextDirection.ltr,
}) => MaterialApp(
  theme: ThemeData(colorScheme: _scheme),
  home: MediaQuery(
    data: MediaQueryData(
      size: Size(width, 852),
      textScaler: TextScaler.linear(textScale),
      disableAnimations: disableAnimations,
    ),
    child: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: width,
            child: Center(
              child: LiquidTabBar(
                destinations: destinations,
                selectedIndex: selectedIndex,
                onDestinationSelected: onSelected ?? (_) {},
                position: position,
                trailing: trailing,
                minimized: minimized,
                onExpand: onExpand,
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

Finder _cell(String label) => find.bySemanticsLabel(RegExp('^$label'));

void main() {
  testWidgets('shows only everywhere destinations', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Reports'), findsNothing);
  });

  testWidgets('a tap reports the index in the full destination list', (
    tester,
  ) async {
    final selected = <int>[];
    await tester.pumpWidget(_host(onSelected: selected.add));
    await tester.tap(find.text('Settings'));
    await tester.tap(find.text('Home'));
    expect(selected, [3, 0]);
  });

  testWidgets('selected cell: primary on a primaryContainer chip', (
    tester,
  ) async {
    await tester.pumpWidget(_host(selectedIndex: 1));
    expect(
      tester.widget<Text>(find.text('Inbox')).style!.color,
      _scheme.primary,
    );
    expect(
      tester.widget<Text>(find.text('Home')).style!.color,
      _scheme.onSurfaceVariant,
    );
    final chips = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.color == _scheme.primaryContainer);
    expect(chips, hasLength(1));
  });

  testWidgets('semantics: button, selected, label with badge', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(selectedIndex: 1));
    expect(
      tester.getSemantics(_cell('Inbox')),
      matchesSemantics(
        label: 'Inbox, 120 new',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(_cell('Settings')),
      matchesSemantics(
        label: 'Settings, New',
        isButton: true,
        hasSelectedState: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('a selected sidebarOnly destination highlights nothing', (
    tester,
  ) async {
    await tester.pumpWidget(_host(selectedIndex: 2));
    for (final label in ['Home', 'Inbox', 'Settings']) {
      expect(
        tester.widget<Text>(find.text(label)).style!.color,
        _scheme.onSurfaceVariant,
      );
    }
  });

  testWidgets('badges draw on the icons', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('bottom pill is 62 high at text scale 1; trailing is a '
      'square of the same height, 8 away', (tester) async {
    await tester.pumpWidget(
      _host(
        trailing: LiquidTabAction(
          icon: const Icon(Icons.search),
          onPressed: () {},
          semanticLabel: 'Search',
        ),
      ),
    );
    final pill = tester.getRect(find.byType(LiquidGlass).first);
    final circle = tester.getRect(find.byType(LiquidGlass).last);
    expect(pill.height, 62);
    expect(circle.height, 62);
    expect(circle.width, 62);
    expect(circle.left - pill.right, 8);
  });

  testWidgets('top pill is 52 high with icons beside labels', (tester) async {
    await tester.pumpWidget(_host(position: LiquidTabBarPosition.top));
    expect(tester.getRect(find.byType(LiquidGlass).first).height, 52);
    final icon = tester.getRect(find.byIcon(Icons.home_outlined));
    final label = tester.getRect(find.text('Home'));
    expect(label.left, greaterThan(icon.right));
  });

  testWidgets('trailing action: tap, tooltip and semantics', (tester) async {
    final handle = tester.ensureSemantics();
    var pressed = 0;
    await tester.pumpWidget(
      _host(
        trailing: LiquidTabAction(
          icon: const Icon(Icons.search),
          onPressed: () => pressed++,
          semanticLabel: 'Search',
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.search));
    expect(pressed, 1);
    expect(find.bySemanticsLabel('Search'), findsOneWidget);
    expect(find.byTooltip('Search'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('minimised: only the selected cell, trailing kept', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        selectedIndex: 1,
        minimized: true,
        trailing: LiquidTabAction(
          icon: const Icon(Icons.search),
          onPressed: () {},
          semanticLabel: 'Search',
        ),
      ),
    );
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('minimised tap expands, keeps the tab and announces', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final selected = <int>[];
    var expanded = 0;
    await tester.pumpWidget(
      _host(
        selectedIndex: 1,
        minimized: true,
        onSelected: selected.add,
        onExpand: () => expanded++,
      ),
    );
    expect(
      tester.getSemantics(_cell('Inbox')),
      matchesSemantics(
        label: 'Inbox, 120 new',
        hint: 'Tap to open the navigation bar',
        isButton: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.text('Inbox'));
    expect(expanded, 1);
    expect(selected, isEmpty);
    final announcements = tester.takeAnnouncements();
    expect(announcements.single.message, 'Navigation bar opened');
    handle.dispose();
  });

  testWidgets('AnimatedSize is removed under disableAnimations', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    expect(find.byType(AnimatedSize), findsOneWidget);
    await tester.pumpWidget(_host(disableAnimations: true));
    expect(find.byType(AnimatedSize), findsNothing);
  });

  testWidgets('AX text scale: icon-only cells, label in semantics, long '
      'press shows the large content viewer', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(textScale: 2));
    expect(find.text('Home'), findsNothing);
    expect(_cell('Home'), findsOneWidget);
    expect(tester.getSize(find.byIcon(Icons.home_outlined)).height, 36);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byIcon(Icons.home_outlined)),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    expect(find.byKey(LargeContentViewer.overlayKey), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(find.byKey(LargeContentViewer.overlayKey), findsNothing);
    handle.dispose();
  });

  testWidgets('five destinations fit a 320pt phone without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        width: 320,
        destinations: [
          for (final label in ['One', 'Two', 'Three', 'Four', 'Five'])
            LiquidDestination(icon: const Icon(Icons.circle), label: label),
        ],
        trailing: LiquidTabAction(
          icon: const Icon(Icons.search),
          onPressed: () {},
          semanticLabel: 'Search',
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('RTL puts the trailing circle at the pill start', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        direction: TextDirection.rtl,
        trailing: LiquidTabAction(
          icon: const Icon(Icons.search),
          onPressed: () {},
          semanticLabel: 'Search',
        ),
      ),
    );
    final pill = tester.getRect(find.byType(LiquidGlass).first);
    final circle = tester.getRect(find.byType(LiquidGlass).last);
    expect(circle.right, lessThan(pill.left));
  });

  testWidgets('announcement uses the ambient text direction', (tester) async {
    await tester.pumpWidget(
      _host(minimized: true, direction: TextDirection.rtl),
    );
    await tester.tap(find.text('Home'));
    expect(tester.takeAnnouncements().single.textDirection, TextDirection.rtl);
  });
}
```

Run: `cd liquid_shell && fvm flutter test test/widget/tab_bar_test.dart; cd ..`
Expected: FAIL, `Method not found: 'LiquidTabBar'`.

- [ ] **Step 2: Implement**

`liquid_shell/lib/src/chrome/text_scale.dart`:

```dart
import 'package:flutter/widgets.dart';

/// Accessibility text-scale threshold (about iOS AX1). From here bar cells
/// become icon-only and the label moves to semantics.
const double kAxTextScale = 1.6;

/// Largest icon size at accessibility text scales.
const double kAxMaxIconSize = 36;

/// Whether the ambient text scale is at or above [kAxTextScale], measured
/// on 14pt text because the system scaler can be non-linear.
bool isAxTextScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14) / 14 >= kAxTextScale;

/// [base] scaled with the text, never below [base], capped at
/// [kAxMaxIconSize].
double axIconSize(BuildContext context, double base) =>
    MediaQuery.textScalerOf(context).scale(base).clamp(base, kAxMaxIconSize);
```

`liquid_shell/lib/src/chrome/large_content_viewer.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell/src/chrome/text_scale.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';

/// iOS-style large content viewer: at accessibility text sizes a long press
/// on an icon-only control shows its icon and label large in the middle of
/// the screen until the finger lifts. Below that size it returns [child].
///
/// The long press wins the gesture arena, so lifting the finger after the
/// card appears does not activate the control. No animation, so it already
/// respects reduce motion.
class LargeContentViewer extends StatefulWidget {
  /// Wraps [child] with the long-press viewer.
  const LargeContentViewer({
    required this.icon,
    required this.label,
    required this.child,
    super.key,
  });

  /// Key of the floating card, for tests.
  static const overlayKey = ValueKey<String>('liquid-large-content-viewer');

  /// Icon shown in the card.
  final Widget icon;

  /// Label shown in the card.
  final String label;

  /// The control.
  final Widget child;

  @override
  State<LargeContentViewer> createState() => _LargeContentViewerState();
}

class _LargeContentViewerState extends State<LargeContentViewer> {
  OverlayEntry? _entry;

  void _show() {
    _hide();
    final entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: ExcludeSemantics(
          child: Center(
            child: _Card(icon: widget.icon, label: widget.label),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    _entry = entry;
  }

  void _hide() {
    _entry
      ?..remove()
      ..dispose();
    _entry = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The text scale dropped below AX mid-press: the gesture detector is
    // gone and no long-press end will arrive to remove the card.
    if (!isAxTextScale(context)) _hide();
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isAxTextScale(context)) return widget.child;
    return GestureDetector(
      excludeFromSemantics: true,
      onLongPressStart: (_) => _show(),
      onLongPressEnd: (_) => _hide(),
      onLongPressCancel: _hide,
      child: widget.child,
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Transparent Material: the card lives in the Overlay, outside any
    // Scaffold, and Text needs a Material ancestor for its default style.
    return Material(
      key: LargeContentViewer.overlayKey,
      type: MaterialType.transparency,
      child: LiquidGlass(
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              IconTheme.merge(
                data: IconThemeData(
                  size: 64,
                  color: theme.colorScheme.onSurface,
                ),
                child: icon,
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

`liquid_shell/lib/src/chrome/tab_bar.dart`. The geometry is the app's: bottom pill 8/4 padding + cell 8/4 + icon 28 + 4 + label 14 = 62; top pill 4 + 44 + 4 = 52:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:liquid_shell/src/chrome/large_content_viewer.dart';
import 'package:liquid_shell/src/chrome/text_scale.dart';
import 'package:liquid_shell/src/destinations/badge.dart';
import 'package:liquid_shell/src/destinations/destination.dart';
import 'package:liquid_shell/src/destinations/tab_action.dart';
import 'package:liquid_shell/src/glass/glass_theme.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';
import 'package:liquid_shell/src/shell/strings.dart';

/// Where a [LiquidTabBar] sits, which sets its cell layout.
enum LiquidTabBarPosition {
  /// Compact: floating at the bottom, icon over label, 62pt pill.
  bottom,

  /// Regular: floating at the top, icon beside label, 52pt pill.
  top,
}

/// The gap between the pill and the trailing circle.
const double kLiquidTabBarTrailingGap = 8;

/// A floating glass pill of destinations, with an optional separate glass
/// circle for a [LiquidTabAction].
///
/// `LiquidShell` places it for you. Use it directly to build your own
/// chrome. It draws the row only: the caller adds the outer margins.
class LiquidTabBar extends StatelessWidget {
  /// Creates a tab bar.
  const LiquidTabBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.position = LiquidTabBarPosition.bottom,
    this.trailing,
    this.minimized = false,
    this.onExpand,
    this.strings = const LiquidShellStrings(),
    super.key,
  });

  /// All destinations. Only [LiquidPlacement.everywhere] ones are shown.
  final List<LiquidDestination> destinations;

  /// Index into [destinations]. A hidden (sidebar-only) index highlights
  /// nothing.
  final int selectedIndex;

  /// Called with an index into [destinations] when a cell is tapped while
  /// the bar is not minimised.
  final ValueChanged<int> onDestinationSelected;

  /// Bottom (compact) or top (regular) layout.
  final LiquidTabBarPosition position;

  /// Optional action in a separate circle at the trailing end.
  final LiquidTabAction? trailing;

  /// Shows only the selected cell. A tap then calls [onExpand] and does not
  /// change the destination.
  final bool minimized;

  /// Called when the minimised bar is tapped.
  final VoidCallback? onExpand;

  /// Strings for the minimised hint, the expand announcement and badges.
  final LiquidShellStrings strings;

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final (i, destination) in destinations.indexed)
        if (destination.placement == LiquidPlacement.everywhere) i,
    ];
    final shown = !minimized || visible.isEmpty
        ? visible
        : [
            if (visible.contains(selectedIndex))
              selectedIndex
            else
              visible.first,
          ];
    final top = position == LiquidTabBarPosition.top;
    final ax = isAxTextScale(context);

    void handleTap(int index) {
      if (!minimized) {
        onDestinationSelected(index);
        return;
      }
      onExpand?.call();
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          strings.tabBarExpanded,
          Directionality.of(context),
        ),
      );
    }

    final pill = LiquidGlass(
      child: Padding(
        padding: top
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final i in shown)
              Flexible(
                child: _Cell(
                  destination: destinations[i],
                  selected: i == selectedIndex,
                  minimized: minimized,
                  top: top,
                  ax: ax,
                  strings: strings,
                  onTap: () => handleTap(i),
                ),
              ),
          ],
        ),
      ),
    );

    final action = trailing;
    return Material(
      type: MaterialType.transparency,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: MediaQuery.disableAnimationsOf(context)
                  ? pill
                  : AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child: pill,
                    ),
            ),
            if (action != null) ...[
              const SizedBox(width: kLiquidTabBarTrailingGap),
              LiquidActionCircle(action: action),
            ],
          ],
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.destination,
    required this.selected,
    required this.minimized,
    required this.top,
    required this.ax,
    required this.strings,
    required this.onTap,
  });

  final LiquidDestination destination;
  final bool selected;
  final bool minimized;
  final bool top;
  final bool ax;
  final LiquidShellStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    final base = top ? 22.0 : 28.0;
    final iconSize = ax ? axIconSize(context, base) : base;
    final icon = _BadgedIcon(
      icon: selected
          ? destination.selectedIcon ?? destination.icon
          : destination.icon,
      badge: destination.badge,
      size: iconSize,
      color: color,
    );
    final label = ax
        ? null
        : Text(
            destination.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: top
                ? theme.textTheme.labelMedium?.copyWith(color: color)
                : LiquidGlassTheme.of(
                    context,
                  ).labelStyle.copyWith(color: color),
          );
    final decoration = BoxDecoration(
      color: selected ? scheme.primaryContainer : Colors.transparent,
      borderRadius: const BorderRadius.all(Radius.circular(999)),
    );

    final content = top
        ? Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: decoration,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                if (label != null) ...[
                  const SizedBox(width: 8),
                  Flexible(child: label),
                ],
              ],
            ),
          )
        : Container(
            constraints: const BoxConstraints(maxWidth: 88),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: decoration,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                if (label != null) ...[const SizedBox(height: 4), label],
              ],
            ),
          );

    return Semantics(
      container: true,
      button: true,
      // While minimised a tap expands the bar instead of selecting, so the
      // node must not claim a selected state at all.
      selected: minimized ? null : selected,
      label: badgeSemanticsLabel(destination.label, destination.badge, strings),
      hint: minimized ? strings.expandTabBarHint : null,
      onTap: onTap,
      excludeSemantics: true,
      child: LargeContentViewer(
        icon: destination.icon,
        label: destination.label,
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          onTap: onTap,
          child: content,
        ),
      ),
    );
  }
}

class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({
    required this.icon,
    required this.badge,
    required this.size,
    required this.color,
  });

  final Widget icon;
  final LiquidBadge? badge;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final themed = IconTheme.merge(
      data: IconThemeData(size: size, color: color),
      child: icon,
    );
    final badge = this.badge;
    if (!badgeVisible(badge)) return themed;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        themed,
        PositionedDirectional(
          top: -4,
          end: -8,
          child: LiquidBadgeView(badge: badge!),
        ),
      ],
    );
  }
}

/// A glass circle for a [LiquidTabAction]: square, as tall as its row.
class LiquidActionCircle extends StatelessWidget {
  /// Creates the circle.
  const LiquidActionCircle({required this.action, super.key});

  /// The action.
  final LiquidTabAction action;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: action.semanticLabel,
    onTap: action.onPressed,
    excludeSemantics: true,
    child: Tooltip(
      message: action.semanticLabel,
      excludeFromSemantics: true,
      child: LiquidGlass(
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: action.onPressed,
          child: AspectRatio(
            aspectRatio: 1,
            child: Center(
              child: IconTheme.merge(
                data: IconThemeData(
                  size: 26,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                child: action.icon,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
```

`liquid_shell/lib/liquid_shell.dart`:

```dart
/// Adaptive navigation shell with a Liquid Glass look for iOS and Android.
library;

export 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart'
    show LiquidPlatformSignals;

export 'src/chrome/tab_bar.dart' show LiquidTabBar, LiquidTabBarPosition;
export 'src/destinations/badge.dart'
    show LiquidBadge, LiquidCountBadge, LiquidDotBadge;
export 'src/destinations/destination.dart';
export 'src/destinations/tab_action.dart';
export 'src/glass/glass_scope.dart';
export 'src/glass/glass_theme.dart';
export 'src/glass/liquid_glass.dart';
export 'src/glass/policy.dart' show LiquidGlassPolicy, LiquidGlassSignals;
export 'src/glass/renderer.dart';
export 'src/glass/signals_controller.dart'
    show debugLiquidGlassCanBlurOverride, debugResetLiquidGlassSignals;
export 'src/glass/tier.dart';
export 'src/shell/strings.dart';
```

- [ ] **Step 3: Run them to see them pass**

Run: `cd liquid_shell && fvm flutter test test/widget/tab_bar_test.dart; cd ..`
Expected: `+16: All tests passed!`

Run: `make format-check analyze coverage`
Expected: `✓ coverage 97.17% (481/495 lines) in liquid_shell/coverage/lcov.info ≥ 90.0%`.

- [ ] **Step 4: Commit**

```bash
.githooks/pre-commit
git add liquid_shell
git commit -m "feat(shell): LiquidTabBar with badges, trailing action, minimise and AX (VK-345)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: `LiquidSidebar` (public)

**Files:**
- Create: `liquid_shell/lib/src/chrome/sidebar.dart`
- Modify: `liquid_shell/lib/liquid_shell.dart`
- Test: `liquid_shell/test/widget/sidebar_test.dart`

**Interfaces:**
- Consumes: Task 5 `LiquidGlass`; Task 6 destinations, badges, strings.
- Produces (exported): `class LiquidSidebar extends StatelessWidget { const LiquidSidebar({required List<LiquidDestination> destinations, required int selectedIndex, required ValueChanged<int> onDestinationSelected, VoidCallback? onHide, Widget? header, Widget? footer, LiquidTabAction? trailing, double width = 300, LiquidShellStrings strings = const LiquidShellStrings(), Key? key}); }`. The hide button shows only when `onHide != null`. Rows: radius 12, padding 12, 12 icon gap, `bodyLarge` w600/w500.

- [ ] **Step 1: Write the failing tests**

`liquid_shell/test/widget/sidebar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';

final _scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC));

const _destinations = [
  LiquidDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
  LiquidDestination(
    icon: Icon(Icons.inbox_outlined),
    label: 'Inbox',
    badge: LiquidBadge.count(3),
  ),
  LiquidDestination(
    icon: Icon(Icons.bar_chart),
    label: 'Reports',
    placement: LiquidPlacement.sidebarOnly,
  ),
];

Widget _host({
  int selectedIndex = 0,
  ValueChanged<int>? onSelected,
  VoidCallback? onHide,
  Widget? header,
  Widget? footer,
  LiquidTabAction? trailing,
  double width = 300,
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
}) => MaterialApp(
  theme: ThemeData(colorScheme: _scheme),
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(834, 600),
      padding: const EdgeInsets.only(top: 24, bottom: 20),
      textScaler: TextScaler.linear(textScale),
    ),
    child: Directionality(
      textDirection: direction,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: LiquidSidebar(
          destinations: _destinations,
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelected ?? (_) {},
          onHide: onHide,
          header: header,
          footer: footer,
          trailing: trailing,
          width: width,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('lists every destination in order, sidebar-only included', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    final ys = [
      for (final label in ['Home', 'Inbox', 'Reports'])
        tester.getTopLeft(find.text(label)).dy,
    ];
    expect(ys, orderedEquals([...ys]..sort()));
  });

  testWidgets('selected row: primaryContainer, onPrimaryContainer w600', (
    tester,
  ) async {
    await tester.pumpWidget(_host(selectedIndex: 2));
    final selected = tester.widget<Text>(find.text('Reports'));
    expect(selected.style!.color, _scheme.onPrimaryContainer);
    expect(selected.style!.fontWeight, FontWeight.w600);
    final other = tester.widget<Text>(find.text('Home'));
    expect(other.style!.color, _scheme.onSurface);
    expect(other.style!.fontWeight, FontWeight.w500);
    final fills = tester
        .widgetList<Material>(find.byType(Material))
        .where((m) => m.color == _scheme.primaryContainer);
    expect(fills, hasLength(1));
  });

  testWidgets('a tap reports the destination index', (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(_host(onSelected: selected.add));
    await tester.tap(find.text('Reports'));
    expect(selected, [2]);
  });

  testWidgets('semantics: selected state and badge in the label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(selectedIndex: 1));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Inbox, 3 new')),
      matchesSemantics(
        label: 'Inbox, 3 new',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(find.text('3'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('header, footer and hide button', (tester) async {
    var hidden = 0;
    await tester.pumpWidget(
      _host(
        header: const Text('My App'),
        footer: const Text('Profile'),
        onHide: () => hidden++,
      ),
    );
    expect(find.text('My App'), findsOneWidget);
    expect(find.byTooltip('Hide sidebar'), findsOneWidget);
    await tester.tap(find.byTooltip('Hide sidebar'));
    expect(hidden, 1);
    // Footer pinned to the bottom: 600 − 20 (safe area) − 24 (padding).
    expect(tester.getBottomLeft(find.text('Profile')).dy, closeTo(556, 1));
  });

  testWidgets('no hide button without onHide', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.byTooltip('Hide sidebar'), findsNothing);
  });

  testWidgets('the trailing action is the first row and never selected', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var pressed = 0;
    await tester.pumpWidget(
      _host(
        trailing: LiquidTabAction(
          icon: const Icon(Icons.search),
          onPressed: () => pressed++,
          semanticLabel: 'Search',
        ),
      ),
    );
    expect(
      tester.getTopLeft(find.text('Search')).dy,
      lessThan(tester.getTopLeft(find.text('Home')).dy),
    );
    await tester.tap(find.text('Search'));
    expect(pressed, 1);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Search')),
      matchesSemantics(label: 'Search', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('width and an end border in outlineVariant', (tester) async {
    await tester.pumpWidget(_host(width: 280));
    expect(tester.getSize(find.byType(LiquidSidebar)).width, 280);
    final border = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((d) => d.border)
        .whereType<BorderDirectional>()
        .single;
    expect(border.end.color, _scheme.outlineVariant);
  });

  testWidgets('scrolls instead of overflowing at large text', (tester) async {
    await tester.pumpWidget(
      _host(textScale: 3, footer: const SizedBox(height: 200)),
    );
    expect(tester.takeException(), isNull);
  });
}
```

Run: `cd liquid_shell && fvm flutter test test/widget/sidebar_test.dart; cd ..`
Expected: FAIL, `Method not found: 'LiquidSidebar'`.

- [ ] **Step 2: Implement**

`liquid_shell/lib/src/chrome/sidebar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell/src/destinations/badge.dart';
import 'package:liquid_shell/src/destinations/destination.dart';
import 'package:liquid_shell/src/destinations/tab_action.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';
import 'package:liquid_shell/src/shell/strings.dart';

/// A full-height glass sidebar of destinations.
///
/// From top to bottom: a header row (`header` and the hide button), the
/// [trailing] action as a row, every destination in list order, and the
/// [footer] pinned to the bottom. `LiquidShell` shows it in regular widths;
/// use it directly to build your own chrome.
class LiquidSidebar extends StatelessWidget {
  /// Creates a sidebar.
  const LiquidSidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.onHide,
    this.header,
    this.footer,
    this.trailing,
    this.width = 300,
    this.strings = const LiquidShellStrings(),
    super.key,
  });

  /// All destinations, sidebar-only ones included, in display order.
  final List<LiquidDestination> destinations;

  /// Index into [destinations] of the selected row.
  final int selectedIndex;

  /// Called with an index into [destinations] when a row is tapped.
  final ValueChanged<int> onDestinationSelected;

  /// Shows the hide button when not null.
  final VoidCallback? onHide;

  /// Leading part of the header row.
  final Widget? header;

  /// Pinned to the bottom.
  final Widget? footer;

  /// Shown as the first row (icon and `semanticLabel`), never selected.
  final LiquidTabAction? trailing;

  /// Width in logical pixels.
  final double width;

  /// Hide-button tooltip and badge semantics.
  final LiquidShellStrings strings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pad = MediaQuery.paddingOf(context);
    final start = Directionality.of(context) == TextDirection.ltr
        ? pad.left
        : pad.right;
    final onHide = this.onHide;
    final action = trailing;
    final rows = <Widget>[
      Row(
        children: [
          Expanded(child: header ?? const SizedBox.shrink()),
          if (onHide != null)
            IconButton(
              onPressed: onHide,
              tooltip: strings.hideSidebar,
              color: scheme.onSurfaceVariant,
              icon: const Icon(Icons.view_sidebar_outlined),
            ),
        ],
      ),
      if (action != null)
        _SidebarRow(
          icon: action.icon,
          label: action.semanticLabel,
          semanticsLabel: action.semanticLabel,
          onTap: action.onPressed,
        ),
      for (final (i, destination) in destinations.indexed)
        _SidebarRow(
          icon: i == selectedIndex
              ? destination.selectedIcon ?? destination.icon
              : destination.icon,
          label: destination.label,
          semanticsLabel: badgeSemanticsLabel(
            destination.label,
            destination.badge,
            strings,
          ),
          badge: destination.badge,
          selected: i == selectedIndex,
          onTap: () => onDestinationSelected(i),
        ),
    ];

    return SizedBox(
      width: width,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: BorderDirectional(
            end: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        child: LiquidGlass(
          borderRadius: BorderRadius.zero,
          child: Material(
            type: MaterialType.transparency,
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    16 + start,
                    24 + pad.top,
                    16,
                    0,
                  ),
                  sliver: SliverList.separated(
                    itemCount: rows.length,
                    itemBuilder: (context, i) => rows[i],
                    separatorBuilder: (context, i) => const SizedBox(height: 8),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      16 + start,
                      8,
                      16,
                      24 + pad.bottom,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.bottomStart,
                      child: footer ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarRow extends StatelessWidget {
  const _SidebarRow({
    required this.icon,
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
    this.badge,
    this.selected,
  });

  final Widget icon;
  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;
  final LiquidBadge? badge;

  /// `null` for the trailing action row, which is never a selection.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSelected = selected ?? false;
    final color = isSelected ? scheme.onPrimaryContainer : scheme.onSurface;
    final badge = this.badge;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: semanticsLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: isSelected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                spacing: 12,
                children: [
                  IconTheme.merge(
                    data: IconThemeData(size: 22, color: color),
                    child: icon,
                  ),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: color,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (badgeVisible(badge)) LiquidBadgeView(badge: badge!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

`liquid_shell/lib/liquid_shell.dart`:

```dart
/// Adaptive navigation shell with a Liquid Glass look for iOS and Android.
library;

export 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart'
    show LiquidPlatformSignals;

export 'src/chrome/sidebar.dart';
export 'src/chrome/tab_bar.dart' show LiquidTabBar, LiquidTabBarPosition;
export 'src/destinations/badge.dart'
    show LiquidBadge, LiquidCountBadge, LiquidDotBadge;
export 'src/destinations/destination.dart';
export 'src/destinations/tab_action.dart';
export 'src/glass/glass_scope.dart';
export 'src/glass/glass_theme.dart';
export 'src/glass/liquid_glass.dart';
export 'src/glass/policy.dart' show LiquidGlassPolicy, LiquidGlassSignals;
export 'src/glass/renderer.dart';
export 'src/glass/signals_controller.dart'
    show debugLiquidGlassCanBlurOverride, debugResetLiquidGlassSignals;
export 'src/glass/tier.dart';
export 'src/shell/strings.dart';
```

- [ ] **Step 3: Run them to see them pass**

Run: `cd liquid_shell && fvm flutter test test/widget/sidebar_test.dart; cd ..`
Expected: `+9: All tests passed!`

Run: `make format-check analyze provenance coverage`
Expected: `✓ coverage 97.42% (566/581 lines) …`.

- [ ] **Step 4: Commit**

```bash
.githooks/pre-commit
git add liquid_shell
git commit -m "feat(shell): LiquidSidebar with header, footer, trailing row and badges (VK-345)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Breakpoints and pure layout rules

**Files:**
- Create: `liquid_shell/lib/src/shell/breakpoints.dart`, `liquid_shell/lib/src/shell/shell_layout.dart`
- Modify: `liquid_shell/lib/liquid_shell.dart`
- Test: `liquid_shell/test/unit/shell_layout_test.dart`

**Interfaces:**
- Consumes: Task 6 `LiquidDestination`, `LiquidPlacement`.
- Produces (exported): `enum LiquidSizeClass { compact, regular }`; `class LiquidShellBreakpoints { const LiquidShellBreakpoints({double regular = 700, double tiledSidebar = 1024}); LiquidSizeClass sizeClassOf(double width); }`; `enum LiquidChromeKind { bottomBar, topBar, sidebarOverlay, sidebarTiled, hidden }`.
- Produces (internal): `enum ShellPresentation { compact, overlay, tiled }`; `ShellPresentation presentationFor(Size, LiquidShellBreakpoints)`; `LiquidSizeClass sizeClassOf(ShellPresentation)`; `LiquidChromeKind chromeKindFor({required ShellPresentation presentation, required bool sidebarVisible, required bool hidden})`; `bool sidebarVisibleFor({required ShellPresentation? previous, required ShellPresentation current, required bool visible})`; `double bottomGapFor({required TargetPlatform platform, required double viewPaddingBottom, required double gestureInsetBottom})`; `EdgeInsets chromeInsetsFor({required LiquidChromeKind kind, required double topPadding, required double? measuredBar, required double bottomGap})`; `int resolveSelectedIndex(int index, int length)`; `List<int> tabBarIndices(List<LiquidDestination>)`; constants `kBottomPillExtent = 62`, `kTopBarGap = 20`, `kTopPillExtent = 52`.

- [ ] **Step 1: Write the failing tests**

`liquid_shell/test/unit/shell_layout_test.dart` (every cell of §5.1, the §5.3 insets and the Q2 and Q9 rules):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/shell/shell_layout.dart';

void main() {
  const breakpoints = LiquidShellBreakpoints();

  group('LiquidShellBreakpoints', () {
    test('defaults 700 / 1024; compact below 700', () {
      expect(breakpoints.regular, 700);
      expect(breakpoints.tiledSidebar, 1024);
      expect(breakpoints.sizeClassOf(699), LiquidSizeClass.compact);
      expect(breakpoints.sizeClassOf(699.9), LiquidSizeClass.compact);
      expect(breakpoints.sizeClassOf(700), LiquidSizeClass.regular);
    });

    test('asserts regular > 0 and tiledSidebar >= regular', () {
      expect(
        () => LiquidShellBreakpoints(regular: 0),
        throwsAssertionError,
      );
      expect(
        () => LiquidShellBreakpoints(regular: 800, tiledSidebar: 700),
        throwsAssertionError,
      );
    });

    test('==', () {
      expect(const LiquidShellBreakpoints(), const LiquidShellBreakpoints());
      expect(
        const LiquidShellBreakpoints().hashCode,
        const LiquidShellBreakpoints().hashCode,
      );
      expect(
        const LiquidShellBreakpoints(),
        isNot(const LiquidShellBreakpoints(regular: 600)),
      );
    });
  });

  group('presentationFor', () {
    ShellPresentation of(double w, double h) =>
        presentationFor(Size(w, h), breakpoints);

    test('reference devices (spec §5.1)', () {
      expect(of(393, 852), ShellPresentation.compact); // iPhone
      expect(of(932, 430), ShellPresentation.overlay); // Pro Max landscape
      expect(of(834, 1194), ShellPresentation.overlay); // iPad 11" portrait
      expect(of(1194, 834), ShellPresentation.tiled); // iPad 11" landscape
      expect(of(412, 915), ShellPresentation.compact); // Android phone
      expect(of(1280, 800), ShellPresentation.tiled); // Android tablet
    });

    test('tiled needs landscape AND width ≥ tiledSidebar', () {
      expect(of(1023, 700), ShellPresentation.overlay);
      expect(of(1024, 700), ShellPresentation.tiled);
      expect(of(1025, 700), ShellPresentation.tiled);
      expect(of(1024, 1366), ShellPresentation.overlay); // portrait
      expect(of(1100, 1100), ShellPresentation.overlay); // square is not w > h
    });

    test('size class at 699 / 700', () {
      expect(of(699, 400), ShellPresentation.compact);
      expect(of(700, 400), ShellPresentation.overlay);
      expect(sizeClassOf(ShellPresentation.compact), LiquidSizeClass.compact);
      expect(sizeClassOf(ShellPresentation.overlay), LiquidSizeClass.regular);
      expect(sizeClassOf(ShellPresentation.tiled), LiquidSizeClass.regular);
    });
  });

  group('chromeKindFor (every cell of §5.1)', () {
    LiquidChromeKind kind(
      ShellPresentation p, {
      bool visible = false,
      bool hidden = false,
    }) =>
        chromeKindFor(presentation: p, sidebarVisible: visible, hidden: hidden);

    test('compact → bottomBar', () {
      expect(kind(ShellPresentation.compact), LiquidChromeKind.bottomBar);
    });

    test('regular with the sidebar hidden → topBar', () {
      expect(kind(ShellPresentation.overlay), LiquidChromeKind.topBar);
      expect(kind(ShellPresentation.tiled), LiquidChromeKind.topBar);
    });

    test('sidebar shown → sidebarOverlay / sidebarTiled', () {
      expect(
        kind(ShellPresentation.overlay, visible: true),
        LiquidChromeKind.sidebarOverlay,
      );
      expect(
        kind(ShellPresentation.tiled, visible: true),
        LiquidChromeKind.sidebarTiled,
      );
    });

    test('hide-chrome wins everywhere', () {
      for (final p in ShellPresentation.values) {
        for (final visible in [false, true]) {
          expect(
            kind(p, visible: visible, hidden: true),
            LiquidChromeKind.hidden,
          );
        }
      }
    });
  });

  group('sidebarVisibleFor (state machine, Q2)', () {
    test('initial value per presentation', () {
      for (final (p, expected) in [
        (ShellPresentation.compact, false),
        (ShellPresentation.overlay, false),
        (ShellPresentation.tiled, true),
      ]) {
        expect(
          sidebarVisibleFor(previous: null, current: p, visible: !expected),
          expected,
        );
      }
    });

    test('keeps the value while the presentation stays', () {
      expect(
        sidebarVisibleFor(
          previous: ShellPresentation.overlay,
          current: ShellPresentation.overlay,
          visible: true,
        ),
        isTrue,
      );
      expect(
        sidebarVisibleFor(
          previous: ShellPresentation.tiled,
          current: ShellPresentation.tiled,
          visible: false,
        ),
        isFalse,
      );
    });

    test('resets to the default when the presentation changes', () {
      expect(
        sidebarVisibleFor(
          previous: ShellPresentation.tiled,
          current: ShellPresentation.overlay,
          visible: true,
        ),
        isFalse,
      );
      expect(
        sidebarVisibleFor(
          previous: ShellPresentation.overlay,
          current: ShellPresentation.tiled,
          visible: false,
        ),
        isTrue,
      );
    });

    test('compact is always false and ignores setters', () {
      expect(
        sidebarVisibleFor(
          previous: ShellPresentation.compact,
          current: ShellPresentation.compact,
          visible: true,
        ),
        isFalse,
      );
    });
  });

  group('bottomGapFor (Q9)', () {
    test('21 over a gesture area: always on iOS', () {
      expect(
        bottomGapFor(
          platform: TargetPlatform.iOS,
          viewPaddingBottom: 34,
          gestureInsetBottom: 0,
        ),
        21,
      );
    });

    test('21 on Android gesture navigation', () {
      expect(
        bottomGapFor(
          platform: TargetPlatform.android,
          viewPaddingBottom: 24,
          gestureInsetBottom: 24,
        ),
        21,
      );
    });

    test('max(21, viewPadding + 8) otherwise', () {
      expect(
        bottomGapFor(
          platform: TargetPlatform.android,
          viewPaddingBottom: 48,
          gestureInsetBottom: 0,
        ),
        56,
      );
      expect(
        bottomGapFor(
          platform: TargetPlatform.android,
          viewPaddingBottom: 0,
          gestureInsetBottom: 0,
        ),
        21,
      );
    });
  });

  group('chromeInsetsFor (§5.3)', () {
    EdgeInsets insets(LiquidChromeKind kind, {double? measured}) =>
        chromeInsetsFor(
          kind: kind,
          topPadding: 24,
          measuredBar: measured,
          bottomGap: 21,
        );

    test('bottomBar: measured row + gap, 83 before measurement', () {
      expect(
        insets(LiquidChromeKind.bottomBar),
        const EdgeInsets.only(bottom: 83),
      );
      expect(
        insets(LiquidChromeKind.bottomBar, measured: 100),
        const EdgeInsets.only(bottom: 121),
      );
    });

    test('topBar and sidebarOverlay: pad.top + 20 + pill, +72 before '
        'measurement', () {
      for (final kind in [
        LiquidChromeKind.topBar,
        LiquidChromeKind.sidebarOverlay,
      ]) {
        expect(insets(kind), const EdgeInsets.only(top: 96));
        expect(insets(kind, measured: 60), const EdgeInsets.only(top: 104));
      }
    });

    test('sidebarTiled and hidden: zero', () {
      expect(insets(LiquidChromeKind.sidebarTiled), EdgeInsets.zero);
      expect(insets(LiquidChromeKind.hidden), EdgeInsets.zero);
    });
  });

  test('resolveSelectedIndex maps out-of-range to 0 (release)', () {
    expect(resolveSelectedIndex(2, 3), 2);
    expect(resolveSelectedIndex(3, 3), 0);
    expect(resolveSelectedIndex(-1, 3), 0);
  });

  test('tabBarIndices lists everywhere destinations only', () {
    const destinations = [
      LiquidDestination(icon: SizedBox(), label: 'A'),
      LiquidDestination(
        icon: SizedBox(),
        label: 'B',
        placement: LiquidPlacement.sidebarOnly,
      ),
      LiquidDestination(icon: SizedBox(), label: 'C'),
    ];
    expect(tabBarIndices(destinations), [0, 2]);
  });
}
```

Run: `cd liquid_shell && fvm flutter test test/unit/shell_layout_test.dart; cd ..`
Expected: FAIL, `Error when reading 'lib/src/shell/shell_layout.dart'`.

- [ ] **Step 2: Implement**

`liquid_shell/lib/src/shell/breakpoints.dart`:

```dart
import 'package:flutter/foundation.dart';

/// The two width classes of the shell.
enum LiquidSizeClass {
  /// Below `LiquidShellBreakpoints.regular`: bottom tab bar.
  compact,

  /// At or above it: sidebar and top tab bar.
  regular,
}

/// Width thresholds of the shell, in logical pixels of the shell's own
/// constraints (not the screen).
@immutable
class LiquidShellBreakpoints {
  /// Creates breakpoints. `0 < regular <= tiledSidebar`.
  const LiquidShellBreakpoints({this.regular = 700, this.tiledSidebar = 1024})
    : assert(regular > 0, 'regular must be positive'),
      assert(tiledSidebar >= regular, 'tiledSidebar must be >= regular');

  /// Widths below this are compact.
  final double regular;

  /// A regular layout tiles the sidebar beside the body only when it is
  /// landscape AND at least this wide. Otherwise the sidebar overlays.
  final double tiledSidebar;

  /// The size class of [width].
  LiquidSizeClass sizeClassOf(double width) =>
      width < regular ? LiquidSizeClass.compact : LiquidSizeClass.regular;

  @override
  bool operator ==(Object other) =>
      other is LiquidShellBreakpoints &&
      other.regular == regular &&
      other.tiledSidebar == tiledSidebar;

  @override
  int get hashCode => Object.hash(regular, tiledSidebar);
}
```

`liquid_shell/lib/src/shell/shell_layout.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/destinations/destination.dart';
import 'package:liquid_shell/src/shell/breakpoints.dart';

/// Which chrome the shell shows.
enum LiquidChromeKind {
  /// Compact: floating pill at the bottom.
  bottomBar,

  /// Regular with the sidebar hidden: pill at the top plus the toggle.
  topBar,

  /// Regular, sidebar shown over the body (the top bar stays underneath).
  sidebarOverlay,

  /// Regular, sidebar beside the body, no tab bar.
  sidebarTiled,

  /// A `LiquidHideChrome` is active.
  hidden,
}

/// How a layout presents navigation. Internal to the shell.
enum ShellPresentation {
  /// Bottom bar, no sidebar.
  compact,

  /// Sidebar covers the body when shown.
  overlay,

  /// Sidebar sits beside the body when shown.
  tiled,
}

/// Pill height of the bottom bar at text scale 1, used before measuring.
const double kBottomPillExtent = 62;

/// Gap between the safe area top and the top bar.
const double kTopBarGap = 20;

/// Pill height of the top bar at text scale 1, used before measuring.
const double kTopPillExtent = 52;

/// The presentation for the shell's constraints [size]. "Landscape" means
/// `width > height`.
ShellPresentation presentationFor(
  Size size,
  LiquidShellBreakpoints breakpoints,
) {
  if (breakpoints.sizeClassOf(size.width) == LiquidSizeClass.compact) {
    return ShellPresentation.compact;
  }
  return size.width >= breakpoints.tiledSidebar && size.width > size.height
      ? ShellPresentation.tiled
      : ShellPresentation.overlay;
}

/// The size class of a presentation.
LiquidSizeClass sizeClassOf(ShellPresentation presentation) =>
    presentation == ShellPresentation.compact
    ? LiquidSizeClass.compact
    : LiquidSizeClass.regular;

/// The chrome for a presentation, sidebar state and hide-chrome state.
LiquidChromeKind chromeKindFor({
  required ShellPresentation presentation,
  required bool sidebarVisible,
  required bool hidden,
}) {
  if (hidden) return LiquidChromeKind.hidden;
  return switch (presentation) {
    ShellPresentation.compact => LiquidChromeKind.bottomBar,
    ShellPresentation.overlay =>
      sidebarVisible
          ? LiquidChromeKind.sidebarOverlay
          : LiquidChromeKind.topBar,
    ShellPresentation.tiled =>
      sidebarVisible ? LiquidChromeKind.sidebarTiled : LiquidChromeKind.topBar,
  };
}

/// Sidebar visibility after a layout pass.
///
/// Compact is always hidden. A changed presentation resets to its default
/// (shown when tiled, hidden when overlay). Otherwise [visible] is kept.
bool sidebarVisibleFor({
  required ShellPresentation? previous,
  required ShellPresentation current,
  required bool visible,
}) {
  if (current == ShellPresentation.compact) return false;
  if (previous != current) return current == ShellPresentation.tiled;
  return visible;
}

/// Gap below the bottom pill (Q9): 21 over a gesture area (always on iOS;
/// on Android when the bottom gesture inset is non-zero), otherwise
/// `max(21, viewPadding.bottom + 8)` so a 3-button bar is never covered.
double bottomGapFor({
  required TargetPlatform platform,
  required double viewPaddingBottom,
  required double gestureInsetBottom,
}) {
  final gestureArea = platform == TargetPlatform.iOS || gestureInsetBottom > 0;
  return gestureArea ? 21 : math.max(21, viewPaddingBottom + 8);
}

/// The part of the body covered by chrome (§5.3). [measuredBar] is the
/// measured bar slot height, or null before the first measurement.
EdgeInsets chromeInsetsFor({
  required LiquidChromeKind kind,
  required double topPadding,
  required double? measuredBar,
  required double bottomGap,
}) => switch (kind) {
  LiquidChromeKind.bottomBar => EdgeInsets.only(
    bottom: (measuredBar ?? kBottomPillExtent) + bottomGap,
  ),
  LiquidChromeKind.topBar || LiquidChromeKind.sidebarOverlay => EdgeInsets.only(
    top: topPadding + kTopBarGap + (measuredBar ?? kTopPillExtent),
  ),
  LiquidChromeKind.sidebarTiled || LiquidChromeKind.hidden => EdgeInsets.zero,
};

/// [index] when it is in range, otherwise 0 (the release fallback).
int resolveSelectedIndex(int index, int length) =>
    index >= 0 && index < length ? index : 0;

/// Indices of the destinations the tab bar shows.
List<int> tabBarIndices(List<LiquidDestination> destinations) => [
  for (final (i, destination) in destinations.indexed)
    if (destination.placement == LiquidPlacement.everywhere) i,
];
```

`liquid_shell/lib/liquid_shell.dart`:

```dart
/// Adaptive navigation shell with a Liquid Glass look for iOS and Android.
library;

export 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart'
    show LiquidPlatformSignals;

export 'src/chrome/sidebar.dart';
export 'src/chrome/tab_bar.dart' show LiquidTabBar, LiquidTabBarPosition;
export 'src/destinations/badge.dart'
    show LiquidBadge, LiquidCountBadge, LiquidDotBadge;
export 'src/destinations/destination.dart';
export 'src/destinations/tab_action.dart';
export 'src/glass/glass_scope.dart';
export 'src/glass/glass_theme.dart';
export 'src/glass/liquid_glass.dart';
export 'src/glass/policy.dart' show LiquidGlassPolicy, LiquidGlassSignals;
export 'src/glass/renderer.dart';
export 'src/glass/signals_controller.dart'
    show debugLiquidGlassCanBlurOverride, debugResetLiquidGlassSignals;
export 'src/glass/tier.dart';
export 'src/shell/breakpoints.dart';
export 'src/shell/shell_layout.dart' show LiquidChromeKind;
export 'src/shell/strings.dart';
```

- [ ] **Step 3: Run them to see them pass**

Run: `cd liquid_shell && fvm flutter test test/unit/shell_layout_test.dart; cd ..`
Expected: `+22: All tests passed!`

Run: `make format-check analyze coverage`
Expected: `✓ coverage 97.57% (603/618 lines) …`.

- [ ] **Step 4: Commit**

```bash
.githooks/pre-commit
git add liquid_shell
git commit -m "feat(shell): breakpoints and pure layout rules (VK-345)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: `LiquidShell`, scope, page helpers, bar measurement, guard, custom chrome

**Files:**
- Create: `liquid_shell/lib/src/shell/{bar_measure,chrome_builder,shell_scope,liquid_shell}.dart`, `liquid_shell/lib/src/chrome/sidebar_toggle.dart`
- Modify: `liquid_shell/lib/liquid_shell.dart`
- Create: `liquid_shell/test/helpers/shell_harness.dart`
- Test: `liquid_shell/test/widget/shell_chrome_test.dart`, `liquid_shell/test/widget/shell_behaviour_test.dart`

**Interfaces:**
- Consumes: Task 7 `LiquidTabBar`, `LiquidTabBarPosition`, `kLiquidTabBarTrailingGap`; Task 8 `LiquidSidebar`; Task 9 every `shell_layout.dart` function and constant, `LiquidShellBreakpoints`; Task 6 types; Task 5 `LiquidGlass`; Task 5 test helpers `installFakeSignals`, `FakeSignalsPlatform.emit`.
- Produces (exported, spec §4.1, §4.4, §4.5): `typedef LiquidBeforeDestinationChange = Future<bool> Function(int index)`; `class LiquidShell extends StatefulWidget` (constructor exactly as spec §4.1); `enum LiquidChromeSlot { tabBar, sidebar }`; `typedef LiquidChromeBuilder = Widget Function(BuildContext, LiquidChromeDetails, Widget defaultChrome)`; `class LiquidChromeDetails` (12 required fields: `slot, kind, destinations, visibleIndices, selectedIndex, select, trailing, minimized, expand, sidebarVisible, setSidebarVisible, strings`); `abstract final class LiquidShellScope { static LiquidShellScopeData of(BuildContext); static LiquidShellScopeData? maybeOf(BuildContext); static EdgeInsets contentPaddingOf(BuildContext); }`; `class LiquidShellScopeData` (+ `factory none()`; `==` ignores the setter); `LiquidHideChrome({required Widget child, bool enabled = true})`; `LiquidNoChrome({required Widget child})`; `LiquidContentInset({required Widget child})`.
- Produces (internal): `BarMeasure({required Object tag, required ValueChanged<double> onHeight, required Widget child})`; `ShellScopeMarker`; `abstract interface class HideChromeRegistry { void addHideRequest(); void removeHideRequest(); }`; `SidebarToggle({required VoidCallback onPressed, required String tooltip})`, `kSidebarToggleSize = 48`, `kSidebarToggleInset = 20`.
- Produces (tests): `test/helpers/shell_harness.dart` with `kDestinations`, `kPhone`, `kPhoneLandscape`, `kTabletPortrait`, `kTabletLandscape`, `TestShell`, `TestShellState.select(int)`, `TestPage`, `pumpShell(tester, shell, {size, padding, gestureInsets, platform, direction, theme, settle})`, `resize(tester, size)`, `scopeOf(tester, [label])`, `tapsOf(tester, label)`.

Invariants to keep (spec §5.6, §5.5): `body` is always the first `Stack` child, under `PositionedDirectional → MediaQuery → KeyedSubtree(GlobalObjectKey(state))` in every layout. Hide-chrome requests that arrive during a build are applied right after the frame (a page cannot mark the shell dirty mid-build). The guard is single-flight. The overlay closes after an accepted selection. `PopScope` closes the overlay on system back.

- [ ] **Step 1: Test harness**

`liquid_shell/test/helpers/shell_harness.dart`. Pages pad with `LiquidShellScope.contentPaddingOf`, like real apps, so taps never land under the chrome:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';

/// Home · Inbox (count 3) · Reports (sidebar only) · Settings (dot).
const kDestinations = [
  LiquidDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
  LiquidDestination(
    icon: Icon(Icons.inbox_outlined),
    label: 'Inbox',
    badge: LiquidBadge.count(3),
  ),
  LiquidDestination(
    icon: Icon(Icons.bar_chart),
    label: 'Reports',
    placement: LiquidPlacement.sidebarOnly,
  ),
  LiquidDestination(
    icon: Icon(Icons.settings_outlined),
    label: 'Settings',
    badge: LiquidBadge.dot(),
  ),
];

/// Reference sizes from spec §10.2.
const kPhone = Size(393, 852);
const kPhoneLandscape = Size(932, 430);
const kTabletPortrait = Size(834, 1194);
const kTabletLandscape = Size(1194, 834);

/// Scaffolds a LiquidShell that owns its selection, like an app would.
class TestShell extends StatefulWidget {
  const TestShell({
    this.destinations = kDestinations,
    this.initialIndex = 0,
    this.selections,
    this.guard,
    this.onHidden,
    this.trailing,
    this.sidebarHeader,
    this.sidebarFooter,
    this.chromeBuilder,
    this.minimizeOnScroll = true,
    this.strings = const LiquidShellStrings(),
    this.pageBuilder,
    super.key,
  });

  final List<LiquidDestination> destinations;
  final int initialIndex;
  final List<int>? selections;
  final LiquidBeforeDestinationChange? guard;
  final ValueChanged<int>? onHidden;
  final LiquidTabAction? trailing;
  final Widget? sidebarHeader;
  final Widget? sidebarFooter;
  final LiquidChromeBuilder? chromeBuilder;
  final bool minimizeOnScroll;
  final LiquidShellStrings strings;

  /// Builds the page of one destination. Defaults to [TestPage].
  final Widget Function(int index)? pageBuilder;

  @override
  State<TestShell> createState() => TestShellState();
}

class TestShellState extends State<TestShell> {
  late int index = widget.initialIndex;

  void select(int value) => setState(() => index = value);

  @override
  Widget build(BuildContext context) => LiquidShell(
    destinations: widget.destinations,
    selectedIndex: index,
    onDestinationSelected: (i) {
      widget.selections?.add(i);
      select(i);
    },
    beforeDestinationChange: widget.guard,
    onSelectedDestinationHidden: widget.onHidden,
    tabBarTrailing: widget.trailing,
    sidebarHeader: widget.sidebarHeader,
    sidebarFooter: widget.sidebarFooter,
    chromeBuilder: widget.chromeBuilder,
    minimizeOnScroll: widget.minimizeOnScroll,
    strings: widget.strings,
    body: IndexedStack(
      index: index,
      children: [
        for (final (i, d) in widget.destinations.indexed)
          widget.pageBuilder?.call(i) ?? TestPage(label: d.label),
      ],
    ),
  );
}

/// A scrolling page with a tap counter, to prove its State survives.
class TestPage extends StatefulWidget {
  const TestPage({required this.label, super.key});

  final String label;

  @override
  State<TestPage> createState() => TestPageState();
}

class TestPageState extends State<TestPage> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => ListView(
    key: ValueKey('list-${widget.label}'),
    padding: LiquidShellScope.contentPaddingOf(context),
    children: [
      TextButton(
        key: ValueKey('counter-${widget.label}'),
        onPressed: () => setState(() => taps++),
        child: Text('${widget.label} page: $taps'),
      ),
      for (var i = 0; i < 60; i++) SizedBox(height: 40, child: Text('row $i')),
    ],
  );
}

/// Pumps [shell] in a MaterialApp on a window of [size] logical pixels.
Future<void> pumpShell(
  WidgetTester tester,
  Widget shell, {
  Size size = kPhone,
  EdgeInsets padding = const EdgeInsets.only(top: 59, bottom: 34),
  EdgeInsets? gestureInsets,
  TargetPlatform platform = TargetPlatform.iOS,
  TextDirection direction = TextDirection.ltr,
  ThemeData? theme,
  bool settle = true,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size
    ..padding = FakeViewPadding(
      left: padding.left,
      top: padding.top,
      right: padding.right,
      bottom: padding.bottom,
    )
    ..viewPadding = FakeViewPadding(
      left: padding.left,
      top: padding.top,
      right: padding.right,
      bottom: padding.bottom,
    )
    ..systemGestureInsets = gestureInsets == null
        ? FakeViewPadding.zero
        : FakeViewPadding(bottom: gestureInsets.bottom);
  addTearDown(tester.view.reset);
  final base =
      theme ??
      ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC)),
      );
  await tester.pumpWidget(
    MaterialApp(
      theme: base.copyWith(platform: platform),
      home: Directionality(textDirection: direction, child: shell),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

/// Resizes the window and lets the bar measurement settle.
Future<void> resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

/// The scope data seen by the page of [label].
LiquidShellScopeData scopeOf(WidgetTester tester, [String label = 'Home']) =>
    LiquidShellScope.of(tester.element(find.byKey(ValueKey('list-$label'))));

/// Taps of the page of [label], even while it is offstage.
int tapsOf(WidgetTester tester, String label) => tester
    .state<TestPageState>(
      find.ancestor(
        of: find.byKey(ValueKey('list-$label'), skipOffstage: false),
        matching: find.byType(TestPage, skipOffstage: false),
      ),
    )
    .taps;
```

- [ ] **Step 2: Write the failing chrome tests**

`liquid_shell/test/widget/shell_chrome_test.dart` (layouts at 393×852, 932×430, 834×1194, 1194×834; sidebar; back; RTL; Q9 gap; page helpers; custom chrome). Semantics blocking is asserted with `find.semantics.byLabel`, which searches the real semantics tree:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/chrome/sidebar_toggle.dart';

import '../helpers/shell_harness.dart';

const _tablet = EdgeInsets.only(top: 24, bottom: 20);

void main() {
  group('chrome by width (§5.1)', () {
    testWidgets('iPhone 393×852 → bottom bar', (tester) async {
      await pumpShell(tester, const TestShell());
      final scope = scopeOf(tester);
      expect(scope.sizeClass, LiquidSizeClass.compact);
      expect(scope.chromeKind, LiquidChromeKind.bottomBar);
      expect(scope.chromeInsets, const EdgeInsets.only(bottom: 83));
      expect(scope.sidebarVisible, isFalse);
      expect(find.byType(LiquidTabBar), findsOneWidget);
      expect(find.byType(LiquidSidebar), findsNothing);
      expect(find.byTooltip('Show sidebar'), findsNothing);
      // The pill sits 21 above the bottom edge, over the home indicator.
      final pill = tester.getRect(
        find.descendant(
          of: find.byType(LiquidTabBar),
          matching: find.byType(LiquidGlass),
        ),
      );
      expect(pill.bottom, 852 - 21);
      expect(pill.height, 62);
    });

    testWidgets('932×430 landscape phone → top bar, sidebar overlays', (
      tester,
    ) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kPhoneLandscape,
        padding: const EdgeInsets.only(left: 59, right: 59, bottom: 21),
      );
      final scope = scopeOf(tester);
      expect(scope.sizeClass, LiquidSizeClass.regular);
      expect(scope.chromeKind, LiquidChromeKind.topBar);
      expect(scope.chromeInsets, const EdgeInsets.only(top: 72));
      expect(find.byTooltip('Show sidebar'), findsOneWidget);

      await tester.tap(find.byTooltip('Show sidebar'));
      await tester.pumpAndSettle();
      expect(scopeOf(tester).chromeKind, LiquidChromeKind.sidebarOverlay);
      expect(find.byType(LiquidSidebar), findsOneWidget);
      expect(find.byType(ModalBarrier), findsWidgets);
    });

    testWidgets('iPad portrait 834×1194 → top bar; body never resized', (
      tester,
    ) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletPortrait,
        padding: _tablet,
      );
      expect(scopeOf(tester).chromeKind, LiquidChromeKind.topBar);
      expect(scopeOf(tester).chromeInsets, const EdgeInsets.only(top: 96));
      // The pill is centred; the toggle is a 48pt circle at (20, pad.top+20).
      expect(
        tester.getRect(find.byType(SidebarToggle)),
        const Rect.fromLTWH(20, 44, 48, 48),
      );
      await tester.tap(find.byTooltip('Show sidebar'));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('list-Home'))).width,
        834,
      );
    });

    testWidgets('iPad landscape 1194×834 → tiled sidebar, body beside it', (
      tester,
    ) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletLandscape,
        padding: _tablet,
      );
      final scope = scopeOf(tester);
      expect(scope.chromeKind, LiquidChromeKind.sidebarTiled);
      expect(scope.chromeInsets, EdgeInsets.zero);
      expect(scope.sidebarVisible, isTrue);
      expect(find.byType(LiquidTabBar), findsNothing);
      final body = tester.element(find.byKey(const ValueKey('list-Home')));
      expect(MediaQuery.sizeOf(body).width, 1194 - 300);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('list-Home'))).dx,
        300,
      );

      await tester.tap(find.byTooltip('Hide sidebar'));
      await tester.pumpAndSettle();
      expect(scopeOf(tester).chromeKind, LiquidChromeKind.topBar);
      expect(find.byType(LiquidTabBar), findsOneWidget);
      expect(MediaQuery.sizeOf(body).width, 1194);
    });

    testWidgets('tiled: the body loses the start padding the sidebar covers', (
      tester,
    ) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletLandscape,
        padding: const EdgeInsets.only(left: 30, top: 24),
      );
      final body = tester.element(find.byKey(const ValueKey('list-Home')));
      expect(MediaQuery.paddingOf(body).left, 0);
      expect(MediaQuery.paddingOf(body).top, 24);
    });
  });

  group('sidebar', () {
    testWidgets('overlay closes on barrier tap; Hide button closes it', (
      tester,
    ) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletPortrait,
        padding: _tablet,
      );
      await tester.tap(find.byTooltip('Show sidebar'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(800, 600));
      await tester.pumpAndSettle();
      expect(find.byType(LiquidSidebar), findsNothing);

      await tester.tap(find.byTooltip('Show sidebar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Hide sidebar'));
      await tester.pumpAndSettle();
      expect(find.byType(LiquidSidebar), findsNothing);
    });

    testWidgets('the overlay barrier hides the content behind it from '
        'screen readers and is labelled', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletPortrait,
        padding: _tablet,
      );
      expect(find.semantics.byLabel('Home page: 0'), findsOne);
      await tester.tap(find.byTooltip('Show sidebar'));
      await tester.pumpAndSettle();
      expect(find.semantics.byLabel('Home page: 0'), findsNothing);
      expect(find.semantics.byLabel('Hide sidebar'), findsOne);
      handle.dispose();
    });

    testWidgets('system back closes the overlay (Q10)', (tester) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletPortrait,
        padding: _tablet,
      );
      await tester.tap(find.byTooltip('Show sidebar'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(LiquidSidebar), findsNothing);
      expect(find.byType(TestShell), findsOneWidget);
    });

    testWidgets('visibility resets when the presentation changes (Q2)', (
      tester,
    ) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletLandscape,
        padding: _tablet,
      );
      await tester.tap(find.byTooltip('Hide sidebar'));
      await tester.pumpAndSettle();
      expect(scopeOf(tester).sidebarVisible, isFalse);

      await resize(tester, kTabletPortrait);
      expect(scopeOf(tester).sidebarVisible, isFalse);
      await resize(tester, kTabletLandscape);
      expect(scopeOf(tester).sidebarVisible, isTrue, reason: 'tiled default');
    });

    testWidgets('setSidebarVisible from the scope; ignored in compact', (
      tester,
    ) async {
      final logs = <String>[];
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletPortrait,
        padding: _tablet,
      );
      scopeOf(tester).setSidebarVisible(true);
      await tester.pumpAndSettle();
      expect(scopeOf(tester).chromeKind, LiquidChromeKind.sidebarOverlay);

      await resize(tester, kPhone);
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
      try {
        scopeOf(tester).setSidebarVisible(true);
        await tester.pumpAndSettle();
      } finally {
        debugPrint = original;
      }
      expect(scopeOf(tester).chromeKind, LiquidChromeKind.bottomBar);
      expect(logs.single, contains('compact'));
    });

    testWidgets('header, footer, hide button and trailing row', (
      tester,
    ) async {
      var searched = 0;
      await pumpShell(
        tester,
        TestShell(
          sidebarHeader: const Text('Acme'),
          sidebarFooter: const Text('Signed in as Ana'),
          trailing: LiquidTabAction(
            icon: const Icon(Icons.search),
            onPressed: () => searched++,
            semanticLabel: 'Search',
          ),
        ),
        size: kTabletLandscape,
        padding: _tablet,
      );
      expect(find.text('Acme'), findsOneWidget);
      expect(find.text('Signed in as Ana'), findsOneWidget);
      expect(find.byTooltip('Hide sidebar'), findsOneWidget);
      await tester.tap(find.text('Search'));
      expect(searched, 1);
    });

    testWidgets('RTL: the toggle sits at the top right', (tester) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletPortrait,
        padding: _tablet,
        direction: TextDirection.rtl,
      );
      expect(
        tester.getRect(find.byType(SidebarToggle)),
        const Rect.fromLTWH(834 - 20 - 48, 44, 48, 48),
      );
    });
  });

  group('trailing action', () {
    LiquidTabAction search(VoidCallback onPressed) => LiquidTabAction(
      icon: const Icon(Icons.search),
      onPressed: onPressed,
      semanticLabel: 'Search',
    );

    testWidgets('a circle in the bottom bar, kept when minimised', (
      tester,
    ) async {
      var pressed = 0;
      await pumpShell(tester, TestShell(trailing: search(() => pressed++)));
      await tester.tap(find.byTooltip('Search'));
      expect(pressed, 1);

      await tester.drag(
        find.byKey(const ValueKey('list-Home')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(find.text('Inbox'), findsNothing, reason: 'minimised');
      expect(find.byTooltip('Search'), findsOneWidget);
    });

    testWidgets('a circle in the top bar', (tester) async {
      await pumpShell(
        tester,
        TestShell(trailing: search(() {})),
        size: kTabletPortrait,
        padding: _tablet,
      );
      expect(find.byTooltip('Search'), findsOneWidget);
    });
  });

  group('bottom gap (Q9)', () {
    testWidgets('Android 3-button navigation: max(21, padding + 8)', (
      tester,
    ) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: const Size(412, 915),
        padding: const EdgeInsets.only(top: 24, bottom: 48),
        platform: TargetPlatform.android,
      );
      final pill = tester.getRect(
        find.descendant(
          of: find.byType(LiquidTabBar),
          matching: find.byType(LiquidGlass),
        ),
      );
      expect(pill.bottom, 915 - 56);
      expect(scopeOf(tester).chromeInsets.bottom, 62 + 56);
    });

    testWidgets('Android gesture navigation: 21', (tester) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: const Size(412, 915),
        padding: const EdgeInsets.only(top: 24, bottom: 24),
        gestureInsets: const EdgeInsets.only(bottom: 24),
        platform: TargetPlatform.android,
      );
      expect(scopeOf(tester).chromeInsets.bottom, 83);
    });
  });

  group('page helpers', () {
    testWidgets('LiquidHideChrome hides every slot and zeroes the insets; '
        'requests are reference-counted', (tester) async {
      await pumpShell(
        tester,
        TestShell(
          pageBuilder: (i) => i == 0
              ? const _HideChromePage()
              : TestPage(label: kDestinations[i].label),
        ),
        size: kTabletPortrait,
        padding: _tablet,
      );
      final state = tester.state<_HideChromePageState>(
        find.byType(_HideChromePage),
      );
      state.set(first: true, second: true);
      await tester.pumpAndSettle();
      expect(find.byType(LiquidTabBar), findsNothing);
      expect(find.byTooltip('Show sidebar'), findsNothing);
      final scope = LiquidShellScope.of(tester.element(find.text('probe')));
      expect(scope.chromeKind, LiquidChromeKind.hidden);
      expect(scope.chromeInsets, EdgeInsets.zero);

      state.set(first: false, second: true);
      await tester.pumpAndSettle();
      expect(find.byType(LiquidTabBar), findsNothing, reason: 'one left');

      state.set(first: false, second: false);
      await tester.pumpAndSettle();
      expect(find.byType(LiquidTabBar), findsOneWidget);
    });

    testWidgets('LiquidHideChrome(enabled: false) and outside a shell are '
        'no-ops', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: LiquidHideChrome(child: Text('alone'))),
      );
      expect(find.text('alone'), findsOneWidget);

      await pumpShell(
        tester,
        TestShell(
          pageBuilder: (i) => LiquidHideChrome(
            enabled: false,
            child: TestPage(label: kDestinations[i].label),
          ),
        ),
      );
      expect(find.byType(LiquidTabBar), findsOneWidget);
    });

    testWidgets('LiquidNoChrome publishes none(); contentPaddingOf takes the '
        'larger of chrome and system padding', (tester) async {
      await pumpShell(tester, const TestShell());
      final inShell = tester.element(find.byKey(const ValueKey('list-Home')));
      expect(
        LiquidShellScope.contentPaddingOf(inShell),
        const EdgeInsets.only(top: 59, bottom: 83),
      );

      final navigator = Navigator.of(inShell);
      unawaitedPush(navigator);
      await tester.pumpAndSettle();
      final above = tester.element(find.text('above'));
      expect(LiquidShellScope.of(above), LiquidShellScopeData.none());
      expect(
        LiquidShellScope.contentPaddingOf(above),
        const EdgeInsets.only(top: 59, bottom: 34),
      );
      expect(
        tester
            .widget<Padding>(
              find
                  .ancestor(
                    of: find.text('above'),
                    matching: find.byType(Padding),
                  )
                  .first,
            )
            .padding,
        const EdgeInsets.only(top: 59, bottom: 34),
      );
    });

    testWidgets('LiquidShellScope.of outside a shell asserts', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              LiquidShellScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });

    test('LiquidShellScopeData == ignores the setter', () {
      LiquidShellScopeData data(ValueSetter<bool> setter) =>
          LiquidShellScopeData(
            sizeClass: LiquidSizeClass.regular,
            chromeKind: LiquidChromeKind.topBar,
            chromeInsets: const EdgeInsets.only(top: 96),
            sidebarVisible: false,
            setSidebarVisible: setter,
          );
      expect(data((_) {}), data((_) {}));
      expect(data((_) {}).hashCode, data((_) {}).hashCode);
      expect(
        LiquidShellScopeData.none(),
        LiquidShellScopeData(
          sizeClass: LiquidSizeClass.compact,
          chromeKind: LiquidChromeKind.hidden,
          chromeInsets: EdgeInsets.zero,
          sidebarVisible: false,
          setSidebarVisible: (_) {},
        ),
      );
    });
  });

  group('custom chrome', () {
    testWidgets('the builder gets the default chrome and the details of '
        'each visible slot', (tester) async {
      final calls = <LiquidChromeDetails>[];
      await pumpShell(
        tester,
        TestShell(
          initialIndex: 1,
          chromeBuilder: (context, details, defaultChrome) {
            calls.add(details);
            return KeyedSubtree(
              key: ValueKey('custom-${details.slot.name}'),
              child: defaultChrome,
            );
          },
        ),
        size: kTabletLandscape,
        padding: _tablet,
      );
      final sidebar = calls.lastWhere(
        (d) => d.slot == LiquidChromeSlot.sidebar,
      );
      expect(sidebar.kind, LiquidChromeKind.sidebarTiled);
      expect(sidebar.visibleIndices, [0, 1, 2, 3]);
      expect(sidebar.selectedIndex, 1);
      expect(sidebar.sidebarVisible, isTrue);
      expect(find.byKey(const ValueKey('custom-sidebar')), findsOneWidget);
      expect(find.byType(LiquidSidebar), findsOneWidget);

      sidebar.setSidebarVisible(false);
      await tester.pumpAndSettle();
      final bar = calls.lastWhere((d) => d.slot == LiquidChromeSlot.tabBar);
      expect(bar.kind, LiquidChromeKind.topBar);
      expect(bar.visibleIndices, [0, 1, 3]);
      expect(bar.minimized, isFalse);
      expect(find.byKey(const ValueKey('custom-tabBar')), findsOneWidget);

      bar.select(3);
      await tester.pumpAndSettle();
      expect(scopeOf(tester, 'Settings').chromeKind, LiquidChromeKind.topBar);
    });

    testWidgets('a custom 100pt bar is measured into chromeInsets', (
      tester,
    ) async {
      await pumpShell(
        tester,
        TestShell(
          chromeBuilder: (context, details, defaultChrome) =>
              details.slot == LiquidChromeSlot.tabBar
              ? const SizedBox(width: 300, height: 100, child: Text('bar'))
              : defaultChrome,
        ),
      );
      expect(scopeOf(tester).chromeInsets, const EdgeInsets.only(bottom: 121));
      expect(find.byType(LiquidTabBar), findsNothing);
    });

    test('LiquidChromeDetails ==', () {
      void select(int _) {}
      void expand() {}
      void setVisible(bool _) {}
      LiquidChromeDetails details({int selected = 0}) => LiquidChromeDetails(
        slot: LiquidChromeSlot.tabBar,
        kind: LiquidChromeKind.bottomBar,
        destinations: kDestinations,
        visibleIndices: const [0, 1, 3],
        selectedIndex: selected,
        select: select,
        trailing: null,
        minimized: false,
        expand: expand,
        sidebarVisible: false,
        setSidebarVisible: setVisible,
        strings: const LiquidShellStrings(),
      );
      expect(details(), details());
      expect(details().hashCode, details().hashCode);
      expect(details(), isNot(details(selected: 1)));
    });
  });
}

void unawaitedPush(NavigatorState navigator) {
  navigator.push(
    MaterialPageRoute<void>(
      builder: (context) => const LiquidNoChrome(
        child: Scaffold(body: LiquidContentInset(child: Text('above'))),
      ),
    ),
  );
}

class _HideChromePage extends StatefulWidget {
  const _HideChromePage();

  @override
  State<_HideChromePage> createState() => _HideChromePageState();
}

class _HideChromePageState extends State<_HideChromePage> {
  bool first = false;
  bool second = false;

  void set({required bool first, required bool second}) => setState(() {
    this.first = first;
    this.second = second;
  });

  @override
  Widget build(BuildContext context) => ListView(
    key: const ValueKey('list-Home'),
    children: [
      if (first) const LiquidHideChrome(child: SizedBox(height: 1)),
      if (second) const LiquidHideChrome(child: SizedBox(height: 1)),
      const Text('probe'),
    ],
  );
}
```

- [ ] **Step 3: Write the failing behaviour tests**

`liquid_shell/test/widget/shell_behaviour_test.dart` (selection, guard accept/refuse/throw/pending/unmount/reselect, `sidebarOnly`, per-tab state across every change, minimise, glass, strings):

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';

import '../helpers/fake_signals_platform.dart';
import '../helpers/shell_harness.dart';

const _tablet = EdgeInsets.only(top: 24, bottom: 20);

Future<void> _openSidebar(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Show sidebar'));
  await tester.pumpAndSettle();
}

void main() {
  group('selection', () {
    testWidgets('a tap selects; reselect calls back too', (tester) async {
      final selections = <int>[];
      await pumpShell(tester, TestShell(selections: selections));
      await tester.tap(find.text('Inbox'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inbox'));
      await tester.pumpAndSettle();
      expect(selections, [1, 1]);
    });

    testWidgets('picking in the overlay closes it; tiled stays open', (
      tester,
    ) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletPortrait,
        padding: _tablet,
      );
      await _openSidebar(tester);
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      expect(find.byType(LiquidSidebar), findsNothing);

      await resize(tester, kTabletLandscape);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(LiquidSidebar), findsOneWidget);
    });

    testWidgets('selectedIndex out of range asserts in debug', (tester) async {
      await pumpShell(
        tester,
        const TestShell(initialIndex: 9),
        settle: false,
      );
      final error = tester.takeException();
      expect(error, isAssertionError);
      expect('$error', contains('0..3'));
    });

    testWidgets('more than five tab bar destinations assert', (tester) async {
      await pumpShell(
        tester,
        TestShell(
          destinations: [
            for (var i = 0; i < 6; i++)
              LiquidDestination(icon: const Icon(Icons.circle), label: '$i'),
          ],
        ),
        settle: false,
      );
      expect(tester.takeException(), isAssertionError);
    });
  });

  group('beforeDestinationChange', () {
    testWidgets('accept → callback and the overlay closes', (tester) async {
      final selections = <int>[];
      final asked = <int>[];
      await pumpShell(
        tester,
        TestShell(
          selections: selections,
          guard: (i) async {
            asked.add(i);
            return true;
          },
        ),
        size: kTabletPortrait,
        padding: _tablet,
      );
      await _openSidebar(tester);
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      expect(asked, [3]);
      expect(selections, [3]);
      expect(find.byType(LiquidSidebar), findsNothing);
    });

    testWidgets('refuse → no callback and the overlay stays open', (
      tester,
    ) async {
      final selections = <int>[];
      await pumpShell(
        tester,
        TestShell(selections: selections, guard: (i) async => false),
        size: kTabletPortrait,
        padding: _tablet,
      );
      await _openSidebar(tester);
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      expect(selections, isEmpty);
      expect(find.byType(LiquidSidebar), findsOneWidget);
    });

    testWidgets('throw → refused and reported with library liquid_shell', (
      tester,
    ) async {
      final selections = <int>[];
      await pumpShell(
        tester,
        TestShell(
          selections: selections,
          guard: (i) async => throw StateError('dialog failed'),
        ),
      );
      final errors = <FlutterErrorDetails>[];
      final original = FlutterError.onError;
      FlutterError.onError = errors.add;
      try {
        await tester.tap(find.text('Inbox'));
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = original;
      }
      expect(selections, isEmpty);
      expect(errors.single.library, 'liquid_shell');
      expect(errors.single.exception, isA<StateError>());
      expect(
        errors.single.context.toString(),
        contains('beforeDestinationChange'),
      );
    });

    testWidgets('a second tap while the guard is pending is ignored', (
      tester,
    ) async {
      final selections = <int>[];
      final pending = Completer<bool>();
      final asked = <int>[];
      await pumpShell(
        tester,
        TestShell(
          selections: selections,
          guard: (i) {
            asked.add(i);
            return pending.future;
          },
        ),
      );
      await tester.tap(find.text('Inbox'));
      await tester.tap(find.text('Settings'));
      await tester.pump();
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(asked, [1]);
      expect(selections, [1]);
    });

    testWidgets('unmounting while pending drops the result', (tester) async {
      final selections = <int>[];
      final pending = Completer<bool>();
      await pumpShell(
        tester,
        TestShell(selections: selections, guard: (i) => pending.future),
      );
      await tester.tap(find.text('Inbox'));
      await tester.pumpWidget(const SizedBox());
      pending.complete(true);
      await tester.pump();
      expect(selections, isEmpty);
    });

    testWidgets('reselect runs the guard; programmatic changes do not', (
      tester,
    ) async {
      final asked = <int>[];
      await pumpShell(
        tester,
        TestShell(
          guard: (i) async {
            asked.add(i);
            return true;
          },
        ),
      );
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      tester.state<TestShellState>(find.byType(TestShell)).select(3);
      await tester.pumpAndSettle();
      expect(asked, [0]);
    });
  });

  group('sidebarOnly', () {
    testWidgets('absent from the pill, present in the sidebar', (tester) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletPortrait,
        padding: _tablet,
      );
      expect(find.text('Reports'), findsNothing);
      await _openSidebar(tester);
      expect(find.text('Reports'), findsOneWidget);
    });

    testWidgets('selected in compact: nothing highlighted, callback once', (
      tester,
    ) async {
      final hidden = <int>[];
      await pumpShell(
        tester,
        TestShell(initialIndex: 2, onHidden: hidden.add),
      );
      final scheme = Theme.of(
        tester.element(find.byType(LiquidTabBar)),
      ).colorScheme;
      for (final label in ['Home', 'Inbox', 'Settings']) {
        expect(
          tester.widget<Text>(find.text(label)).style!.color,
          scheme.onSurfaceVariant,
        );
      }
      expect(hidden, [2]);
      await tester.pump();
      expect(hidden, [2]);
    });

    testWidgets('regular → compact → regular → compact calls back twice', (
      tester,
    ) async {
      final hidden = <int>[];
      await pumpShell(
        tester,
        TestShell(initialIndex: 2, onHidden: hidden.add),
        size: kTabletPortrait,
        padding: _tablet,
      );
      expect(hidden, isEmpty);
      await resize(tester, kPhone);
      await resize(tester, kTabletPortrait);
      await resize(tester, kPhone);
      expect(hidden, [2, 2]);
    });
  });

  group('per-tab state survives every chrome change (§5.6)', () {
    testWidgets('sidebar toggle, compact↔regular, rotation, hide chrome, '
        'chromeBuilder and tier', (tester) async {
      final platform = installFakeSignals();
      var useBuilder = false;
      var hide = false;
      late StateSetter rebuild;
      await pumpShell(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return TestShell(
              chromeBuilder: useBuilder
                  ? (context, details, defaultChrome) => defaultChrome
                  : null,
              pageBuilder: (i) => i == 0
                  ? LiquidHideChrome(
                      enabled: hide,
                      child: TestPage(label: kDestinations[i].label),
                    )
                  : TestPage(label: kDestinations[i].label),
            );
          },
        ),
        size: kTabletPortrait,
        padding: _tablet,
      );
      await tester.tap(find.text('Home page: 0'));
      await tester.pump();
      expect(tapsOf(tester, 'Home'), 1);

      Future<void> check(String step) async {
        await tester.pumpAndSettle();
        expect(tapsOf(tester, 'Home'), 1, reason: step);
      }

      await _openSidebar(tester);
      await check('sidebar shown');
      await tester.tap(find.byTooltip('Hide sidebar'));
      await check('sidebar hidden');
      await resize(tester, kPhone);
      await check('compact');
      await resize(tester, kTabletLandscape);
      await check('rotation to tiled');
      await resize(tester, kTabletPortrait);
      await check('rotation back');
      rebuild(() => hide = true);
      await check('hide chrome on');
      rebuild(() => hide = false);
      await check('hide chrome off');
      rebuild(() => useBuilder = true);
      await check('chromeBuilder added');
      rebuild(() => useBuilder = false);
      await check('chromeBuilder removed');
      platform.emit(const LiquidPlatformSignals(reduceTransparency: true));
      await check('tier change');
    });
  });

  group('minimise on scroll (§5.7)', () {
    testWidgets('reverse minimises, forward expands', (tester) async {
      await pumpShell(tester, const TestShell());
      final list = find.byKey(const ValueKey('list-Home'));
      await tester.drag(list, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('Inbox'), findsNothing);
      expect(find.text('Home'), findsOneWidget);

      await tester.drag(list, const Offset(0, 100));
      await tester.pumpAndSettle();
      expect(find.text('Inbox'), findsOneWidget);
    });

    testWidgets('a tap expands without changing tab and announces', (
      tester,
    ) async {
      final selections = <int>[];
      await pumpShell(tester, TestShell(selections: selections));
      await tester.drag(
        find.byKey(const ValueKey('list-Home')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Inbox'), findsOneWidget);
      expect(selections, isEmpty);
      expect(
        tester.takeAnnouncements().single.message,
        'Navigation bar opened',
      );
    });

    testWidgets('minimizeOnScroll: false keeps the bar', (tester) async {
      await pumpShell(tester, const TestShell(minimizeOnScroll: false));
      await tester.drag(
        find.byKey(const ValueKey('list-Home')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(find.text('Inbox'), findsOneWidget);
    });

    testWidgets('does not apply to the top bar', (tester) async {
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletPortrait,
        padding: _tablet,
      );
      await tester.drag(
        find.byKey(const ValueKey('list-Home')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(find.text('Inbox'), findsOneWidget);
    });
  });

  group('glass in the shell', () {
    testWidgets('chrome shares one BackdropGroup and turns solid on a '
        'signal', (tester) async {
      final platform = installFakeSignals();
      await pumpShell(
        tester,
        TestShell(
          trailing: LiquidTabAction(
            icon: const Icon(Icons.search),
            onPressed: () {},
            semanticLabel: 'Search',
          ),
        ),
      );
      expect(find.byType(BackdropFilter), findsNWidgets(2));
      expect(find.byType(BackdropGroup), findsOneWidget);

      platform.emit(const LiquidPlatformSignals(powerSave: true));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('light and dark come from LiquidGlassTheme.of', (
      tester,
    ) async {
      final dark = ColorScheme.fromSeed(
        seedColor: const Color(0xFF3366CC),
        brightness: Brightness.dark,
      );
      await pumpShell(
        tester,
        const TestShell(),
        theme: ThemeData(colorScheme: dark),
      );
      final expected = LiquidGlassTheme.fromColorScheme(dark).tint;
      final fills = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.color == expected);
      expect(fills, isNotEmpty);
    });
  });

  group('strings', () {
    testWidgets('toggle and hide tooltips come from strings', (tester) async {
      await pumpShell(
        tester,
        const TestShell(
          strings: LiquidShellStrings(
            showSidebar: 'Hiện thanh bên',
            hideSidebar: 'Ẩn thanh bên',
          ),
        ),
        size: kTabletPortrait,
        padding: _tablet,
      );
      await tester.tap(find.byTooltip('Hiện thanh bên'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Ẩn thanh bên'), findsOneWidget);
    });
  });
}
```

Run: `cd liquid_shell && fvm flutter test test/widget/shell_chrome_test.dart test/widget/shell_behaviour_test.dart; cd ..`
Expected: FAIL, `Type 'LiquidBeforeDestinationChange' not found`, `Type 'LiquidChromeBuilder' not found`, `Type 'LiquidShellScopeData' not found`.

- [ ] **Step 4: Implement the building blocks**

`liquid_shell/lib/src/shell/bar_measure.dart` (the app's height reporter, re-typed: reports after two stable frames, keyed by tag):

```dart
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Reports the height of [child] once it has been stable for two frames.
///
/// It never calls back during layout, and never once per frame while the
/// bar animates: a new height must repeat on the next frame first. It only
/// reports when the height or [tag] changes, so there is no loop. A new
/// [tag] (size class or text scale) re-reports even an unchanged height, so
/// every tag gets its own measurement.
class BarMeasure extends SingleChildRenderObjectWidget {
  /// Creates a reporter.
  const BarMeasure({
    required this.tag,
    required this.onHeight,
    required super.child,
    super.key,
  });

  /// What the measurement belongs to.
  final Object tag;

  /// Receives the settled height.
  final ValueChanged<double> onHeight;

  @override
  RenderBarMeasure createRenderObject(BuildContext context) =>
      RenderBarMeasure(tag, onHeight);

  @override
  void updateRenderObject(BuildContext context, RenderBarMeasure renderObject) {
    renderObject
      ..tag = tag
      ..onHeight = onHeight;
  }
}

/// Render object of [BarMeasure].
class RenderBarMeasure extends RenderProxyBox {
  /// Creates the render object.
  RenderBarMeasure(this._tag, this.onHeight);

  /// Receives the settled height.
  ValueChanged<double> onHeight;

  (Object, double)? _reported;
  double? _settling;
  bool _checking = false;

  Object _tag;

  /// What the measurement belongs to.
  Object get tag => _tag;
  set tag(Object value) {
    if (value == _tag) return;
    _tag = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    super.performLayout();
    if ((_tag, size.height) == _reported || _checking) return;
    _checking = true;
    _settling = null;
    SchedulerBinding.instance.addPostFrameCallback(_check);
  }

  void _check(Duration _) {
    if (!attached) {
      _checking = false;
      return;
    }
    final height = size.height;
    if (height != _settling) {
      // Changed, or the first check: look again on the next frame.
      _settling = height;
      SchedulerBinding.instance
        ..addPostFrameCallback(_check)
        ..scheduleFrame();
      return;
    }
    _checking = false;
    final reported = (_tag, height);
    if (reported == _reported) return;
    _reported = reported;
    onHeight(height);
  }
}
```

`liquid_shell/lib/src/shell/chrome_builder.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/destinations/destination.dart';
import 'package:liquid_shell/src/destinations/tab_action.dart';
import 'package:liquid_shell/src/shell/shell_layout.dart';
import 'package:liquid_shell/src/shell/strings.dart';

/// The two places the shell draws chrome.
enum LiquidChromeSlot {
  /// The tab bar (bottom or top, toggle included at the top).
  tabBar,

  /// The sidebar.
  sidebar,
}

/// Replaces or wraps the shell's chrome for one slot.
///
/// [defaultChrome] is what the shell would have drawn. Return it wrapped,
/// or ignore it. The shell keeps placing and measuring the slot.
typedef LiquidChromeBuilder =
    Widget Function(
      BuildContext context,
      LiquidChromeDetails details,
      Widget defaultChrome,
    );

/// Everything a [LiquidChromeBuilder] needs to draw a slot.
@immutable
class LiquidChromeDetails {
  /// Creates the details. Every field is required.
  const LiquidChromeDetails({
    required this.slot,
    required this.kind,
    required this.destinations,
    required this.visibleIndices,
    required this.selectedIndex,
    required this.select,
    required this.trailing,
    required this.minimized,
    required this.expand,
    required this.sidebarVisible,
    required this.setSidebarVisible,
    required this.strings,
  });

  /// The slot being built.
  final LiquidChromeSlot slot;

  /// The current chrome. Never [LiquidChromeKind.hidden]: the builder is not
  /// called then.
  final LiquidChromeKind kind;

  /// All destinations.
  final List<LiquidDestination> destinations;

  /// Indices into [destinations] this slot shows: everywhere-only for the
  /// tab bar, all for the sidebar.
  final List<int> visibleIndices;

  /// The selected index.
  final int selectedIndex;

  /// Runs the same path as a tap: guard, then `onDestinationSelected`, then
  /// close the overlay sidebar.
  final ValueChanged<int> select;

  /// The tab bar trailing action, if any.
  final LiquidTabAction? trailing;

  /// Tab bar slot, compact only: the bar is minimised.
  final bool minimized;

  /// Tab bar slot: leaves the minimised state.
  final VoidCallback expand;

  /// Whether the sidebar is shown.
  final bool sidebarVisible;

  /// Shows or hides the sidebar.
  final ValueSetter<bool> setSidebarVisible;

  /// The shell's strings.
  final LiquidShellStrings strings;

  @override
  bool operator ==(Object other) =>
      other is LiquidChromeDetails &&
      other.slot == slot &&
      other.kind == kind &&
      listEquals(other.destinations, destinations) &&
      listEquals(other.visibleIndices, visibleIndices) &&
      other.selectedIndex == selectedIndex &&
      other.select == select &&
      other.trailing == trailing &&
      other.minimized == minimized &&
      other.expand == expand &&
      other.sidebarVisible == sidebarVisible &&
      other.setSidebarVisible == setSidebarVisible &&
      other.strings == strings;

  @override
  int get hashCode => Object.hash(
    slot,
    kind,
    Object.hashAll(destinations),
    Object.hashAll(visibleIndices),
    selectedIndex,
    select,
    trailing,
    minimized,
    expand,
    sidebarVisible,
    setSidebarVisible,
    strings,
  );
}
```

`liquid_shell/lib/src/shell/shell_scope.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/shell/breakpoints.dart';
import 'package:liquid_shell/src/shell/shell_layout.dart';

/// What the nearest `LiquidShell` tells its body.
@immutable
class LiquidShellScopeData {
  /// Creates scope data.
  const LiquidShellScopeData({
    required this.sizeClass,
    required this.chromeKind,
    required this.chromeInsets,
    required this.sidebarVisible,
    required this.setSidebarVisible,
  });

  /// No shell: compact, hidden chrome, zero insets, no sidebar.
  factory LiquidShellScopeData.none() => const LiquidShellScopeData(
    sizeClass: LiquidSizeClass.compact,
    chromeKind: LiquidChromeKind.hidden,
    chromeInsets: EdgeInsets.zero,
    sidebarVisible: false,
    setSidebarVisible: _ignore,
  );

  static void _ignore(bool visible) {}

  /// Compact or regular.
  final LiquidSizeClass sizeClass;

  /// The chrome on screen.
  final LiquidChromeKind chromeKind;

  /// The part of the body covered by chrome, from the body's edges.
  final EdgeInsets chromeInsets;

  /// Whether the sidebar is shown.
  final bool sidebarVisible;

  /// Shows or hides the sidebar. Ignored in compact (logged in debug).
  final ValueSetter<bool> setSidebarVisible;

  @override
  bool operator ==(Object other) =>
      other is LiquidShellScopeData &&
      other.sizeClass == sizeClass &&
      other.chromeKind == chromeKind &&
      other.chromeInsets == chromeInsets &&
      other.sidebarVisible == sidebarVisible;

  @override
  int get hashCode =>
      Object.hash(sizeClass, chromeKind, chromeInsets, sidebarVisible);
}

/// Receives hide-chrome requests. Implemented by the shell's state.
abstract interface class HideChromeRegistry {
  /// One more [LiquidHideChrome] is active.
  void addHideRequest();

  /// One fewer [LiquidHideChrome] is active.
  void removeHideRequest();
}

/// Publishes [data] (and the hide registry) to the subtree.
class ShellScopeMarker extends InheritedWidget {
  /// Creates the marker.
  const ShellScopeMarker({
    required this.data,
    required this.registry,
    required super.child,
    super.key,
  });

  /// Scope data for the subtree.
  final LiquidShellScopeData data;

  /// Where [LiquidHideChrome] registers; null above or outside a shell.
  final HideChromeRegistry? registry;

  @override
  bool updateShouldNotify(ShellScopeMarker oldWidget) =>
      data != oldWidget.data || registry != oldWidget.registry;
}

/// Reads the nearest `LiquidShell`.
abstract final class LiquidShellScope {
  /// The nearest shell's data. Outside any shell: asserts in debug, returns
  /// [LiquidShellScopeData.none] in release.
  static LiquidShellScopeData of(BuildContext context) {
    final data = maybeOf(context);
    assert(
      data != null,
      'LiquidShellScope.of() called outside a LiquidShell. Use maybeOf(), or '
      'wrap pages pushed above the shell in LiquidNoChrome.',
    );
    return data ?? LiquidShellScopeData.none();
  }

  /// The nearest shell's data, or null outside any shell.
  static LiquidShellScopeData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScopeMarker>()?.data;

  /// Padding that keeps content clear of both chrome and system UI: per
  /// side, the larger of the chrome insets and `MediaQuery.paddingOf`.
  static EdgeInsets contentPaddingOf(BuildContext context) {
    final chrome = maybeOf(context)?.chromeInsets ?? EdgeInsets.zero;
    final system = MediaQuery.paddingOf(context);
    return EdgeInsets.fromLTRB(
      math.max(chrome.left, system.left),
      math.max(chrome.top, system.top),
      math.max(chrome.right, system.right),
      math.max(chrome.bottom, system.bottom),
    );
  }
}

/// While mounted with [enabled] inside a shell, hides all chrome (bar,
/// toggle, sidebar) and zeroes the insets. For full-frame pages pushed
/// inside a branch. Requests are reference-counted. Outside a shell it
/// does nothing.
class LiquidHideChrome extends StatefulWidget {
  /// Hides the chrome while [child] is mounted.
  const LiquidHideChrome({required this.child, this.enabled = true, super.key});

  /// The page.
  final Widget child;

  /// Whether to hide the chrome.
  final bool enabled;

  @override
  State<LiquidHideChrome> createState() => _LiquidHideChromeState();
}

class _LiquidHideChromeState extends State<LiquidHideChrome> {
  HideChromeRegistry? _registry;
  bool _active = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final registry = context
        .dependOnInheritedWidgetOfExactType<ShellScopeMarker>()
        ?.registry;
    if (registry != _registry) {
      _deactivate();
      _registry = registry;
    }
    _sync();
  }

  @override
  void didUpdateWidget(LiquidHideChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.enabled && _registry != null) {
      if (!_active) {
        _active = true;
        _registry!.addHideRequest();
      }
    } else {
      _deactivate();
    }
  }

  void _deactivate() {
    if (!_active) return;
    _active = false;
    _registry?.removeHideRequest();
  }

  @override
  void dispose() {
    _deactivate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// For pages pushed ABOVE the shell (on the root navigator): publishes
/// [LiquidShellScopeData.none] to [child], so its insets ignore the chrome
/// underneath.
class LiquidNoChrome extends StatelessWidget {
  /// Creates the wrapper.
  const LiquidNoChrome({required this.child, super.key});

  /// The page.
  final Widget child;

  @override
  Widget build(BuildContext context) => ShellScopeMarker(
    data: LiquidShellScopeData.none(),
    registry: null,
    child: child,
  );
}

/// `Padding(LiquidShellScope.contentPaddingOf(context))`, for content that
/// does not scroll.
class LiquidContentInset extends StatelessWidget {
  /// Creates the inset.
  const LiquidContentInset({required this.child, super.key});

  /// The content.
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: LiquidShellScope.contentPaddingOf(context),
    child: child,
  );
}
```

`liquid_shell/lib/src/chrome/sidebar_toggle.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';

/// Size of the show-sidebar toggle.
const double kSidebarToggleSize = 48;

/// Distance of the toggle from the start edge and the top bar row.
const double kSidebarToggleInset = 20;

/// The 48pt glass circle that shows the sidebar.
class SidebarToggle extends StatelessWidget {
  /// Creates the toggle.
  const SidebarToggle({
    required this.onPressed,
    required this.tooltip,
    super.key,
  });

  /// Shows the sidebar.
  final VoidCallback onPressed;

  /// Tooltip and semantics label.
  final String tooltip;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: kSidebarToggleSize,
    child: LiquidGlass(
      child: Material(
        type: MaterialType.transparency,
        child: IconButton(
          onPressed: onPressed,
          tooltip: tooltip,
          icon: const Icon(Icons.view_sidebar_outlined),
        ),
      ),
    ),
  );
}
```

- [ ] **Step 5: Implement the shell**

`liquid_shell/lib/src/shell/liquid_shell.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_shell/src/chrome/sidebar.dart';
import 'package:liquid_shell/src/chrome/sidebar_toggle.dart';
import 'package:liquid_shell/src/chrome/tab_bar.dart';
import 'package:liquid_shell/src/destinations/destination.dart';
import 'package:liquid_shell/src/destinations/tab_action.dart';
import 'package:liquid_shell/src/shell/bar_measure.dart';
import 'package:liquid_shell/src/shell/breakpoints.dart';
import 'package:liquid_shell/src/shell/chrome_builder.dart';
import 'package:liquid_shell/src/shell/shell_layout.dart';
import 'package:liquid_shell/src/shell/shell_scope.dart';
import 'package:liquid_shell/src/shell/strings.dart';

/// Decides whether a user selection may proceed. Return `false` to cancel.
typedef LiquidBeforeDestinationChange = Future<bool> Function(int index);

/// Horizontal margin of the tab bar rows.
const double _kBarMargin = 16;

/// Space each side of the top pill reserves while the toggle is shown:
/// toggle inset + toggle + gap.
const double _kToggleReserve =
    kSidebarToggleInset + kSidebarToggleSize + kLiquidTabBarTrailingGap;

/// An adaptive navigation shell with no router dependency.
///
/// Below `breakpoints.regular` it floats a glass tab bar at the bottom.
/// From there up it shows a glass sidebar: over the body in portrait (or
/// narrow landscape), beside it in landscape at `breakpoints.tiledSidebar`
/// and wider, with a top tab bar and a toggle while the sidebar is hidden.
///
/// [body] is always the first child of the same subtree, so per-tab state
/// survives every layout change. Keeping branch bodies alive (for example
/// with an `IndexedStack`) is the app's or router's job.
class LiquidShell extends StatefulWidget {
  /// Creates a shell.
  const LiquidShell({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.beforeDestinationChange,
    this.onSelectedDestinationHidden,
    this.tabBarTrailing,
    this.sidebarHeader,
    this.sidebarFooter,
    this.chromeBuilder,
    this.breakpoints = const LiquidShellBreakpoints(),
    this.sidebarWidth = 300,
    this.minimizeOnScroll = true,
    this.strings = const LiquidShellStrings(),
    super.key,
  });

  /// All destinations, in display order. Indices refer to this list.
  final List<LiquidDestination> destinations;

  /// The destination whose content [body] currently shows.
  final int selectedIndex;

  /// Called after a user selects a destination, once any guard has
  /// accepted. Also called when `index == selectedIndex` (reselect); apps
  /// usually pop that branch to its root.
  final ValueChanged<int> onDestinationSelected;

  /// The content: an `IndexedStack`, a router's shell child, and so on. The
  /// shell never rebuilds it under a new parent.
  final Widget body;

  /// Optional async guard, for example "Discard changes?". Runs before every
  /// user selection, including reselect; `false` or a throw cancels it.
  /// Taps while it is pending are ignored.
  final LiquidBeforeDestinationChange? beforeDestinationChange;

  /// Called once when the layout becomes compact while a sidebar-only
  /// destination is selected.
  final ValueChanged<int>? onSelectedDestinationHidden;

  /// Action at the trailing end of the tab bar, also the first sidebar row.
  final LiquidTabAction? tabBarTrailing;

  /// Leading part of the sidebar header row. The shell adds the hide button.
  final Widget? sidebarHeader;

  /// Pinned to the bottom of the sidebar.
  final Widget? sidebarFooter;

  /// Replaces or wraps the default chrome per slot.
  final LiquidChromeBuilder? chromeBuilder;

  /// Width thresholds.
  final LiquidShellBreakpoints breakpoints;

  /// Sidebar width. `0 < sidebarWidth < breakpoints.regular`.
  final double sidebarWidth;

  /// Compact bottom bar only: shrink to the selected tab while content
  /// scrolls down; expand on scroll up or tap.
  final bool minimizeOnScroll;

  /// Every user-visible string.
  final LiquidShellStrings strings;

  @override
  State<LiquidShell> createState() => _LiquidShellState();
}

class _LiquidShellState extends State<LiquidShell>
    implements HideChromeRegistry {
  final ValueNotifier<bool> _minimized = ValueNotifier(false);
  late final GlobalObjectKey _bodyKey = GlobalObjectKey(this);

  /// Settled bar heights per (size class, text scale).
  Map<(LiquidSizeClass, double), double> _measured = const {};
  ShellPresentation? _presentation;
  bool _sidebarVisible = false;
  bool _guardPending = false;
  int _hideRequests = 0;
  bool _hiddenSelectionReported = false;

  @override
  void dispose() {
    _minimized.dispose();
    super.dispose();
  }

  // --- hide chrome -------------------------------------------------------

  @override
  void addHideRequest() => _changeHideRequests(1);

  @override
  void removeHideRequest() => _changeHideRequests(-1);

  void _changeHideRequests(int delta) {
    void apply() {
      if (mounted) setState(() => _hideRequests += delta);
    }

    // Requests arrive while pages build or unmount; the shell cannot be
    // marked dirty then, so they apply right after the frame.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  // --- sidebar and selection ---------------------------------------------

  void _setSidebarVisible(bool visible) {
    if (_presentation == ShellPresentation.compact) {
      if (kDebugMode) {
        debugPrint(
          'liquid_shell: setSidebarVisible($visible) ignored in the compact '
          'layout.',
        );
      }
      return;
    }
    if (_sidebarVisible != visible) {
      setState(() => _sidebarVisible = visible);
    }
  }

  void _onSelect(int index) => unawaited(_select(index));

  Future<void> _select(int index) async {
    if (_guardPending) return;
    final guard = widget.beforeDestinationChange;
    if (guard != null) {
      _guardPending = true;
      var accepted = false;
      try {
        accepted = await guard(index);
      } on Object catch (exception, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: exception,
            stack: stack,
            library: 'liquid_shell',
            context: ErrorDescription('while running beforeDestinationChange'),
          ),
        );
      } finally {
        _guardPending = false;
      }
      if (!mounted || !accepted) return;
    }
    widget.onDestinationSelected(index);
    if (mounted && _presentation == ShellPresentation.overlay) {
      _setSidebarVisible(false);
    }
  }

  void _expand() => _minimized.value = false;

  void _onBarHeight((LiquidSizeClass, double) key, double height) {
    if (!mounted || height <= 0 || _measured[key] == height) return;
    setState(() => _measured = {..._measured, key: height});
  }

  bool _onScroll(UserScrollNotification notification, LiquidChromeKind kind) {
    if (!widget.minimizeOnScroll || kind != LiquidChromeKind.bottomBar) {
      return false;
    }
    switch (notification.direction) {
      case ScrollDirection.reverse:
        _minimized.value = true;
      case ScrollDirection.forward:
        _minimized.value = false;
      case ScrollDirection.idle:
        break;
    }
    return false;
  }

  void _reportHiddenSelection(ShellPresentation presentation, int selected) {
    if (presentation != ShellPresentation.compact) {
      _hiddenSelectionReported = false;
      return;
    }
    final destinations = widget.destinations;
    final hidden =
        destinations.isNotEmpty &&
        destinations[selected].placement == LiquidPlacement.sidebarOnly;
    if (!hidden || _hiddenSelectionReported) return;
    _hiddenSelectionReported = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSelectedDestinationHidden?.call(selected);
    });
  }

  bool _debugCheckArguments() {
    final destinations = widget.destinations;
    final length = destinations.length;
    assert(length > 0, 'LiquidShell.destinations must not be empty.');
    final tabs = tabBarIndices(destinations).length;
    assert(
      length == 0 || (tabs >= 1 && tabs <= 5),
      'LiquidShell needs 1 to 5 destinations with LiquidPlacement.everywhere; '
      'got $tabs.',
    );
    assert(
      length == 0 ||
          (widget.selectedIndex >= 0 && widget.selectedIndex < length),
      'LiquidShell.selectedIndex ${widget.selectedIndex} is out of range '
      '0..${length - 1}.',
    );
    assert(
      destinations.every((d) => d.label.isNotEmpty),
      'Every LiquidDestination.label must be non-empty.',
    );
    assert(
      widget.sidebarWidth > 0 &&
          widget.sidebarWidth < widget.breakpoints.regular,
      'LiquidShell.sidebarWidth must be > 0 and < breakpoints.regular.',
    );
    return true;
  }

  // --- build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    assert(_debugCheckArguments());
    return LayoutBuilder(builder: _buildLayout);
  }

  Widget _buildLayout(BuildContext context, BoxConstraints constraints) {
    final size = constraints.biggest;
    final presentation = presentationFor(size, widget.breakpoints);
    _sidebarVisible = sidebarVisibleFor(
      previous: _presentation,
      current: presentation,
      visible: _sidebarVisible,
    );
    _presentation = presentation;

    final media = MediaQuery.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final sizeClass = sizeClassOf(presentation);
    final selected = resolveSelectedIndex(
      widget.selectedIndex,
      widget.destinations.length,
    );
    _reportHiddenSelection(presentation, selected);

    final kind = chromeKindFor(
      presentation: presentation,
      sidebarVisible: _sidebarVisible,
      hidden: _hideRequests > 0 || widget.destinations.isEmpty,
    );
    final barKey = (sizeClass, media.textScaler.scale(14));
    final bottomGap = bottomGapFor(
      platform: Theme.of(context).platform,
      viewPaddingBottom: media.viewPadding.bottom,
      gestureInsetBottom: media.systemGestureInsets.bottom,
    );
    final insets = chromeInsetsFor(
      kind: kind,
      topPadding: media.padding.top,
      measuredBar: _measured[barKey],
      bottomGap: bottomGap,
    );

    // The body: always the first child, always the same wrappers.
    final tiled = kind == LiquidChromeKind.sidebarTiled;
    final bodyStart = tiled ? widget.sidebarWidth : 0.0;
    var bodyMedia = media.copyWith(
      size: Size(size.width - bodyStart, size.height),
    );
    if (tiled) {
      bodyMedia = bodyMedia.removePadding(removeLeft: !rtl, removeRight: rtl);
    }
    final children = <Widget>[
      PositionedDirectional(
        start: bodyStart,
        top: 0,
        end: 0,
        bottom: 0,
        child: MediaQuery(
          data: bodyMedia,
          child: KeyedSubtree(
            key: _bodyKey,
            child: NotificationListener<UserScrollNotification>(
              onNotification: (n) => _onScroll(n, kind),
              child: widget.body,
            ),
          ),
        ),
      ),
    ];

    final sidebarShown =
        kind == LiquidChromeKind.sidebarOverlay ||
        kind == LiquidChromeKind.sidebarTiled;

    LiquidChromeDetails details(
      LiquidChromeSlot slot, {
      bool minimized = false,
    }) => LiquidChromeDetails(
      slot: slot,
      kind: kind,
      destinations: widget.destinations,
      visibleIndices: slot == LiquidChromeSlot.tabBar
          ? tabBarIndices(widget.destinations)
          : [for (var i = 0; i < widget.destinations.length; i++) i],
      selectedIndex: selected,
      select: _onSelect,
      trailing: widget.tabBarTrailing,
      minimized: minimized,
      expand: _expand,
      sidebarVisible: sidebarShown,
      setSidebarVisible: _setSidebarVisible,
      strings: widget.strings,
    );

    Widget slot(LiquidChromeDetails details, Widget defaultChrome) {
      final builder = widget.chromeBuilder;
      if (builder == null) return defaultChrome;
      return Builder(
        builder: (context) => builder(context, details, defaultChrome),
      );
    }

    Widget measured(Widget child) => BarMeasure(
      tag: barKey,
      onHeight: (height) => _onBarHeight(barKey, height),
      child: child,
    );

    switch (kind) {
      case LiquidChromeKind.bottomBar:
        children.add(
          Positioned(
            left: _kBarMargin,
            right: _kBarMargin,
            bottom: bottomGap,
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1,
              child: ValueListenableBuilder<bool>(
                valueListenable: _minimized,
                builder: (context, minimized, _) {
                  final isMinimized = widget.minimizeOnScroll && minimized;
                  return measured(
                    slot(
                      details(LiquidChromeSlot.tabBar, minimized: isMinimized),
                      LiquidTabBar(
                        destinations: widget.destinations,
                        selectedIndex: selected,
                        onDestinationSelected: _onSelect,
                        trailing: widget.tabBarTrailing,
                        minimized: isMinimized,
                        onExpand: _expand,
                        strings: widget.strings,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      case LiquidChromeKind.topBar || LiquidChromeKind.sidebarOverlay:
        final toggle = kind == LiquidChromeKind.topBar;
        children.add(
          Positioned(
            left: 0,
            right: 0,
            top: media.padding.top + kTopBarGap,
            child: measured(
              slot(
                details(LiquidChromeSlot.tabBar),
                Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            _kBarMargin + (toggle ? _kToggleReserve : 0),
                      ),
                      child: Center(
                        heightFactor: 1,
                        child: LiquidTabBar(
                          destinations: widget.destinations,
                          selectedIndex: selected,
                          onDestinationSelected: _onSelect,
                          position: LiquidTabBarPosition.top,
                          trailing: widget.tabBarTrailing,
                          strings: widget.strings,
                        ),
                      ),
                    ),
                    if (toggle)
                      PositionedDirectional(
                        start: kSidebarToggleInset,
                        top: 0,
                        child: SidebarToggle(
                          onPressed: () => _setSidebarVisible(true),
                          tooltip: widget.strings.showSidebar,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      case LiquidChromeKind.sidebarTiled || LiquidChromeKind.hidden:
        break;
    }

    if (kind == LiquidChromeKind.sidebarOverlay) {
      // Modal for screen readers: drops the semantics of everything before.
      children.add(
        Positioned.fill(
          child: BlockSemantics(
            child: ModalBarrier(
              color: Theme.of(
                context,
              ).colorScheme.scrim.withValues(alpha: 0.32),
              semanticsLabel: widget.strings.hideSidebar,
              onDismiss: () => _setSidebarVisible(false),
            ),
          ),
        ),
      );
    }

    if (sidebarShown) {
      children.add(
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          width: widget.sidebarWidth,
          child: slot(
            details(LiquidChromeSlot.sidebar),
            LiquidSidebar(
              destinations: widget.destinations,
              selectedIndex: selected,
              onDestinationSelected: _onSelect,
              onHide: () => _setSidebarVisible(false),
              header: widget.sidebarHeader,
              footer: widget.sidebarFooter,
              trailing: widget.tabBarTrailing,
              width: widget.sidebarWidth,
              strings: widget.strings,
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: kind != LiquidChromeKind.sidebarOverlay,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setSidebarVisible(false);
      },
      child: ShellScopeMarker(
        data: LiquidShellScopeData(
          sizeClass: sizeClass,
          chromeKind: kind,
          chromeInsets: insets,
          sidebarVisible: sidebarShown,
          setSidebarVisible: _setSidebarVisible,
        ),
        registry: this,
        // One backdrop read for all chrome glass (budget rule, §5.8).
        child: BackdropGroup(child: Stack(children: children)),
      ),
    );
  }
}
```

`liquid_shell/lib/liquid_shell.dart` (final export list, spec §4.9):

```dart
/// Adaptive navigation shell with a Liquid Glass look for iOS and Android.
library;

export 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart'
    show LiquidPlatformSignals;

export 'src/chrome/sidebar.dart';
export 'src/chrome/tab_bar.dart' show LiquidTabBar, LiquidTabBarPosition;
export 'src/destinations/badge.dart'
    show LiquidBadge, LiquidCountBadge, LiquidDotBadge;
export 'src/destinations/destination.dart';
export 'src/destinations/tab_action.dart';
export 'src/glass/glass_scope.dart';
export 'src/glass/glass_theme.dart';
export 'src/glass/liquid_glass.dart';
export 'src/glass/policy.dart' show LiquidGlassPolicy, LiquidGlassSignals;
export 'src/glass/renderer.dart';
export 'src/glass/signals_controller.dart'
    show debugLiquidGlassCanBlurOverride, debugResetLiquidGlassSignals;
export 'src/glass/tier.dart';
export 'src/shell/breakpoints.dart';
export 'src/shell/chrome_builder.dart';
export 'src/shell/liquid_shell.dart';
export 'src/shell/shell_layout.dart' show LiquidChromeKind;
export 'src/shell/shell_scope.dart'
    show
        LiquidContentInset,
        LiquidHideChrome,
        LiquidNoChrome,
        LiquidShellScope,
        LiquidShellScopeData;
export 'src/shell/strings.dart';
```

- [ ] **Step 6: Run them to see them pass**

Run: `cd liquid_shell && fvm flutter test test/widget/shell_chrome_test.dart test/widget/shell_behaviour_test.dart; cd ..`
Expected: `+45: All tests passed!`

Run: `make format-check analyze provenance test coverage`
Expected: `✓ coverage 97.91% (938/958 lines) in liquid_shell/coverage/lcov.info ≥ 90.0%`; `liquid_shell` total 152 tests.

- [ ] **Step 7: Commit**

```bash
.githooks/pre-commit
git add liquid_shell
git commit -m "feat(shell): LiquidShell with scope, page helpers, guard and custom chrome (VK-345)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 11: Example app, one screen per case

**Files:**
- Create: `liquid_shell/example/lib/support/{wallpaper,demo_page}.dart`, `liquid_shell/example/lib/cases/{cases,basic_tabs,badges,sidebar_only,sidebar_slots,trailing_action,discard_guard,custom_chrome,custom_theme,forced_tier,form_factors}.dart`
- Modify: `liquid_shell/example/lib/main.dart`, `liquid_shell/example/integration_test/signals_test.dart`, `tool/integration_ios.sh`, `tool/integration_android.sh`
- Test: `liquid_shell/example/test/cases_smoke_test.dart`

**Interfaces:**
- Consumes: the whole public API of Tasks 4–10.
- Produces: `class ExampleApp`, `class CaseList`, `const kExampleSeed = Color(0xFF3D5AFE)`; `typedef ExampleCase = ({String id, String title, String subtitle, Widget page})`, `const kCases` (ids `basic badges sidebar_only sidebar_slots trailing guard custom_chrome custom_theme forced_tier form_factors`; rows keyed `ValueKey('case-<id>')`); case widgets `BasicTabsCase`, `BadgesCase`, `SidebarOnlyCase`, `SidebarSlotsCase`, `TrailingActionCase` (+ `SearchPage`), `DiscardGuardCase` (+ `DetailPage`), `CustomChromeCase`, `CustomThemeCase`, `ForcedTierCase({LiquidGlassTier initialTier = LiquidGlassTier.frosted})`, `FormFactorsCase` (+ `DeviceFrame`, `kDeviceFrames`); `DemoPage({required String title, List<Widget> children})`, `kDemoDestinations`; `Wallpaper`, `WallpaperPainter(ColorScheme)`. Each case marks its README snippet with `// #docregion readme` … `// #enddocregion readme`. The integration test reads `--dart-define=RUN_NAME` and saves `build/integration_screenshots/shell_<RUN_NAME>.png`.

- [ ] **Step 1: Write the failing smoke tests**

`liquid_shell/example/test/cases_smoke_test.dart` (every case at phone and tablet size, plus the guard, the hide/no-chrome pages and the sidebar-only fallback):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/cases.dart';
import 'package:liquid_shell_example/main.dart';

const _sizes = {'phone': Size(393, 852), 'tablet': Size(1194, 834)};

Future<void> _openCase(WidgetTester tester, String id) async {
  await tester.pumpWidget(const ExampleApp());
  final row = find.byKey(ValueKey('case-$id'));
  await tester.scrollUntilVisible(row, 100);
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

void main() {
  for (final MapEntry(key: sizeName, value: size) in _sizes.entries) {
    for (final entry in kCases) {
      testWidgets('${entry.id} on a $sizeName opens without errors', (
        tester,
      ) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = size;
        addTearDown(tester.view.reset);
        await _openCase(tester, entry.id);
        expect(tester.takeException(), isNull);
        expect(find.byType(LiquidShell), findsWidgets);
      });
    }
  }

  testWidgets('the guard asks before leaving dirty edits', (tester) async {
    await _openCase(tester, 'guard');
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Home item 1'), findsOneWidget);
  });

  testWidgets('the detail page hides the chrome', (tester) async {
    await _openCase(tester, 'guard');
    await tester.tap(find.text('Open a full-frame detail page'));
    await tester.pumpAndSettle();
    expect(find.byType(LiquidTabBar), findsNothing);
  });

  testWidgets('trailing search opens a page with no chrome', (tester) async {
    await _openCase(tester, 'trailing');
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    final field = tester.element(find.byType(TextField));
    expect(LiquidShellScope.of(field), LiquidShellScopeData.none());
  });

  testWidgets('a sidebar-only selection falls back to the first tab on a '
      'phone', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(834, 1194);
    addTearDown(tester.view.reset);
    await _openCase(tester, 'sidebar_only');
    await tester.tap(find.byTooltip('Show sidebar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.text('Destination 4'), findsOneWidget);

    tester.view.physicalSize = const Size(393, 852);
    await tester.pumpAndSettle();
    expect(find.text('Destination 1'), findsOneWidget);
  });
}
```

Run: `cd liquid_shell/example && fvm flutter test; cd ../..`
Expected: FAIL, `Error when reading 'lib/cases/cases.dart'`.

- [ ] **Step 2: Shared support**

`liquid_shell/example/lib/support/wallpaper.dart` (deterministic, no image assets; the goldens use the same painter):

```dart
import 'package:flutter/material.dart';

/// A deterministic wallpaper (no image assets) so glass has something to
/// blur. The example screens and the goldens use the same painter.
class Wallpaper extends StatelessWidget {
  /// Creates the wallpaper.
  const Wallpaper({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: WallpaperPainter(Theme.of(context).colorScheme),
    child: const SizedBox.expand(),
  );
}

/// Paints a soft gradient with a few large discs in scheme colours.
class WallpaperPainter extends CustomPainter {
  /// Creates the painter for [scheme].
  const WallpaperPainter(this.scheme);

  /// Colours to paint with.
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.surface, scheme.surfaceContainerHighest],
        ).createShader(rect),
    );
    final discs = [
      (const Offset(0.15, 0.2), 0.35, scheme.primary),
      (const Offset(0.85, 0.35), 0.30, scheme.tertiary),
      (const Offset(0.3, 0.75), 0.40, scheme.secondary),
      (const Offset(0.9, 0.95), 0.30, scheme.primaryContainer),
    ];
    final unit = size.shortestSide;
    for (final (centre, radius, color) in discs) {
      canvas.drawCircle(
        Offset(centre.dx * size.width, centre.dy * size.height),
        radius * unit,
        Paint()..color = color.withValues(alpha: 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(WallpaperPainter oldDelegate) =>
      oldDelegate.scheme != scheme;
}
```

`liquid_shell/example/lib/support/demo_page.dart` (Task 12 sets the cards' elevation to 0):

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/wallpaper.dart';

/// A long page over the [Wallpaper]. Its list is padded with
/// [LiquidShellScope.contentPaddingOf], so content scrolls under the glass
/// chrome but starts and ends clear of it.
class DemoPage extends StatelessWidget {
  /// Creates a page titled [title].
  const DemoPage({required this.title, this.children = const [], super.key});

  /// Page title, shown as the first row.
  final String title;

  /// Rows shown under the title, before the filler rows.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = Navigator.of(context).canPop();
    // Transparent Material: list tiles, switches and segmented buttons need
    // one, and the wallpaper must stay visible.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          const Positioned.fill(child: Wallpaper()),
          ListView(
            padding: LiquidShellScope.contentPaddingOf(
              context,
            ).add(const EdgeInsets.symmetric(horizontal: 16)),
            children: [
              Row(
                children: [
                  if (canPop) const BackButton(),
                  Expanded(
                    child: Text(title, style: theme.textTheme.headlineMedium),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...children,
              for (var i = 1; i <= 24; i++)
                Card(
                  color: theme.colorScheme.surface.withValues(alpha: 0.8),
                  child: ListTile(
                    title: Text('$title item $i'),
                    subtitle: const Text('Scroll to see the glass chrome blur'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The three destinations most cases share.
const kDemoDestinations = [
  LiquidDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home),
    label: 'Home',
  ),
  LiquidDestination(
    icon: Icon(Icons.explore_outlined),
    selectedIcon: Icon(Icons.explore),
    label: 'Explore',
  ),
  LiquidDestination(
    icon: Icon(Icons.settings_outlined),
    selectedIcon: Icon(Icons.settings),
    label: 'Settings',
  ),
];
```

- [ ] **Step 3: The cases**

`liquid_shell/example/lib/cases/basic_tabs.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// The smallest shell: three tabs over an `IndexedStack`.
class BasicTabsCase extends StatefulWidget {
  /// Creates the case.
  const BasicTabsCase({super.key});

  @override
  State<BasicTabsCase> createState() => _BasicTabsCaseState();
}

class _BasicTabsCaseState extends State<BasicTabsCase> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // #docregion readme
    return LiquidShell(
      destinations: const [
        LiquidDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
        LiquidDestination(icon: Icon(Icons.explore_outlined), label: 'Explore'),
        LiquidDestination(
          icon: Icon(Icons.settings_outlined),
          label: 'Settings',
        ),
      ],
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      body: IndexedStack(
        index: _index,
        children: const [
          DemoPage(title: 'Home'),
          DemoPage(title: 'Explore'),
          DemoPage(title: 'Settings'),
        ],
      ),
    );
    // #enddocregion readme
  }
}
```

`liquid_shell/example/lib/cases/badges.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// Count, overflowing count and dot badges.
class BadgesCase extends StatefulWidget {
  /// Creates the case.
  const BadgesCase({super.key});

  @override
  State<BadgesCase> createState() => _BadgesCaseState();
}

class _BadgesCaseState extends State<BadgesCase> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // #docregion readme
    const destinations = [
      LiquidDestination(
        icon: Icon(Icons.inbox_outlined),
        label: 'Inbox',
        badge: LiquidBadge.count(3),
      ),
      LiquidDestination(
        icon: Icon(Icons.forum_outlined),
        label: 'Chats',
        badge: LiquidBadge.count(120), // shows "99+"
      ),
      LiquidDestination(
        icon: Icon(Icons.notifications_outlined),
        label: 'Alerts',
        badge: LiquidBadge.dot(),
      ),
    ];
    // #enddocregion readme
    return LiquidShell(
      destinations: destinations,
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      body: DemoPage(title: destinations[_index].label),
    );
  }
}
```

`liquid_shell/example/lib/cases/sidebar_only.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// Two destinations that live in the sidebar only.
class SidebarOnlyCase extends StatefulWidget {
  /// Creates the case.
  const SidebarOnlyCase({super.key});

  @override
  State<SidebarOnlyCase> createState() => _SidebarOnlyCaseState();
}

class _SidebarOnlyCaseState extends State<SidebarOnlyCase> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // #docregion readme
    return LiquidShell(
      destinations: const [
        ...kDemoDestinations,
        LiquidDestination(
          icon: Icon(Icons.bar_chart),
          label: 'Reports',
          placement: LiquidPlacement.sidebarOnly,
        ),
        LiquidDestination(
          icon: Icon(Icons.archive_outlined),
          label: 'Archive',
          placement: LiquidPlacement.sidebarOnly,
        ),
      ],
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      // Phones have no sidebar: fall back to the first tab.
      onSelectedDestinationHidden: (_) => setState(() => _index = 0),
      body: DemoPage(title: 'Destination ${_index + 1}'),
    );
    // #enddocregion readme
  }
}
```

`liquid_shell/example/lib/cases/sidebar_slots.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// A title in the sidebar header and a profile footer.
class SidebarSlotsCase extends StatefulWidget {
  /// Creates the case.
  const SidebarSlotsCase({super.key});

  @override
  State<SidebarSlotsCase> createState() => _SidebarSlotsCaseState();
}

class _SidebarSlotsCaseState extends State<SidebarSlotsCase> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // #docregion readme
    return LiquidShell(
      destinations: kDemoDestinations,
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      sidebarHeader: Text('Acme Notes', style: theme.textTheme.titleLarge),
      sidebarFooter: const ListTile(
        leading: CircleAvatar(child: Text('A')),
        title: Text('Ana Lima'),
        subtitle: Text('ana@example.com'),
      ),
      body: DemoPage(title: kDemoDestinations[_index].label),
    );
    // #enddocregion readme
  }
}
```

`liquid_shell/example/lib/cases/trailing_action.dart` (Task 13 adds a `no-chrome` region):

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// A search circle at the end of the tab bar, opening a page above the shell.
class TrailingActionCase extends StatefulWidget {
  /// Creates the case.
  const TrailingActionCase({super.key});

  @override
  State<TrailingActionCase> createState() => _TrailingActionCaseState();
}

class _TrailingActionCaseState extends State<TrailingActionCase> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // #docregion readme
    return LiquidShell(
      destinations: kDemoDestinations,
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      tabBarTrailing: LiquidTabAction(
        icon: const Icon(Icons.search),
        semanticLabel: 'Search',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SearchPage()),
        ),
      ),
      body: DemoPage(title: kDemoDestinations[_index].label),
    );
    // #enddocregion readme
  }
}

/// A page pushed above the shell: no chrome covers it.
class SearchPage extends StatelessWidget {
  /// Creates the page.
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) => const LiquidNoChrome(
    child: Scaffold(
      body: DemoPage(
        title: 'Search',
        children: [TextField(decoration: InputDecoration(hintText: 'Find'))],
      ),
    ),
  );
}
```

`liquid_shell/example/lib/cases/discard_guard.dart` (Task 13 adds a `hide-chrome` region):

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// Asks "Discard changes?" before leaving a tab with unsaved edits.
class DiscardGuardCase extends StatefulWidget {
  /// Creates the case.
  const DiscardGuardCase({super.key});

  @override
  State<DiscardGuardCase> createState() => _DiscardGuardCaseState();
}

class _DiscardGuardCaseState extends State<DiscardGuardCase> {
  int _index = 0;
  bool _dirty = true;

  // #docregion readme
  Future<bool> _confirmLeave(int index) async {
    if (!_dirty || index == _index) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }
  // #enddocregion readme

  @override
  Widget build(BuildContext context) => LiquidShell(
    destinations: kDemoDestinations,
    selectedIndex: _index,
    beforeDestinationChange: _confirmLeave,
    onDestinationSelected: (i) => setState(() {
      if (i != _index) _dirty = false;
      _index = i;
    }),
    body: DemoPage(
      title: kDemoDestinations[_index].label,
      children: [
        SwitchListTile(
          title: const Text('Unsaved changes'),
          value: _dirty,
          onChanged: (value) => setState(() => _dirty = value),
        ),
        ListTile(
          title: const Text('Open a full-frame detail page'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const DetailPage()),
          ),
        ),
      ],
    ),
  );
}

/// A detail page that hides the chrome while it is open.
class DetailPage extends StatelessWidget {
  /// Creates the page.
  const DetailPage({super.key});

  @override
  Widget build(BuildContext context) => const LiquidHideChrome(
    child: Scaffold(body: DemoPage(title: 'Detail')),
  );
}
```

`liquid_shell/example/lib/cases/custom_chrome.dart` (no `Chip`: the tab-bar slot has no `Material` ancestor):

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// Wraps the default tab bar and replaces the sidebar.
class CustomChromeCase extends StatefulWidget {
  /// Creates the case.
  const CustomChromeCase({super.key});

  @override
  State<CustomChromeCase> createState() => _CustomChromeCaseState();
}

class _CustomChromeCaseState extends State<CustomChromeCase> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => LiquidShell(
    destinations: kDemoDestinations,
    selectedIndex: _index,
    onDestinationSelected: (i) => setState(() => _index = i),
    chromeBuilder: _chrome,
    body: DemoPage(title: kDemoDestinations[_index].label),
  );

  // #docregion readme
  Widget _chrome(
    BuildContext context,
    LiquidChromeDetails details,
    Widget defaultChrome,
  ) {
    if (details.slot == LiquidChromeSlot.tabBar) {
      // Wrap: a caption above the default bar.
      final scheme = Theme.of(context).colorScheme;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: ShapeDecoration(
              color: scheme.tertiaryContainer,
              shape: const StadiumBorder(),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text('Beta'),
            ),
          ),
          const SizedBox(height: 8),
          defaultChrome,
        ],
      );
    }
    // Replace: a plain list instead of the glass sidebar.
    return Material(
      child: ListView(
        children: [
          for (final i in details.visibleIndices)
            ListTile(
              leading: details.destinations[i].icon,
              title: Text(details.destinations[i].label),
              selected: i == details.selectedIndex,
              onTap: () => details.select(i),
            ),
        ],
      ),
    );
  }

  // #enddocregion readme
}
```

`liquid_shell/example/lib/cases/custom_theme.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// A brand glass theme with a light/dark switch.
class CustomThemeCase extends StatefulWidget {
  /// Creates the case.
  const CustomThemeCase({super.key});

  @override
  State<CustomThemeCase> createState() => _CustomThemeCaseState();
}

class _CustomThemeCaseState extends State<CustomThemeCase> {
  int _index = 0;
  Brightness _brightness = Brightness.light;

  @override
  Widget build(BuildContext context) {
    // #docregion readme
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00897B),
      brightness: _brightness,
    );
    final glass = LiquidGlassTheme.fromColorScheme(scheme).copyWith(
      tint: scheme.primaryContainer.withValues(alpha: 0.6),
      blurSigma: 18,
      labelStyle: const TextStyle(
        fontSize: 11,
        height: 1.3,
        fontWeight: FontWeight.w700,
      ),
    );
    final theme = ThemeData(colorScheme: scheme, extensions: [glass]);
    // #enddocregion readme
    return Theme(
      data: theme,
      child: LiquidShell(
        destinations: kDemoDestinations,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        body: DemoPage(
          title: 'Brand glass',
          children: [
            SwitchListTile(
              title: const Text('Dark'),
              value: _brightness == Brightness.dark,
              onChanged: (dark) => setState(
                () => _brightness = dark ? Brightness.dark : Brightness.light,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

`liquid_shell/example/lib/cases/forced_tier.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// Forces the glass tier for a subtree.
class ForcedTierCase extends StatefulWidget {
  /// Creates the case, optionally starting at [initialTier].
  const ForcedTierCase({this.initialTier = LiquidGlassTier.frosted, super.key});

  /// The tier selected first.
  final LiquidGlassTier initialTier;

  @override
  State<ForcedTierCase> createState() => _ForcedTierCaseState();
}

class _ForcedTierCaseState extends State<ForcedTierCase> {
  int _index = 0;
  late LiquidGlassTier _tier = widget.initialTier;

  @override
  Widget build(BuildContext context) {
    // #docregion readme
    return LiquidGlassScope(
      policy: LiquidGlassPolicy(forcedTier: _tier),
      child: LiquidShell(
        destinations: kDemoDestinations,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        body: DemoPage(
          title: 'Forced tier',
          children: [
            SegmentedButton<LiquidGlassTier>(
              segments: [
                for (final tier in LiquidGlassTier.values)
                  ButtonSegment(value: tier, label: Text(tier.name)),
              ],
              selected: {_tier},
              onSelectionChanged: (s) => setState(() => _tier = s.single),
            ),
            if (_tier == LiquidGlassTier.liquid)
              const Text('No liquid renderer is registered: drawing frosted.'),
          ],
        ),
      ),
    );
    // #enddocregion readme
  }
}
```

`liquid_shell/example/lib/cases/form_factors.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell_example/cases/basic_tabs.dart';

/// A device frame: logical size and safe-area padding.
typedef DeviceFrame = ({String name, Size size, EdgeInsets padding});

/// The reference frames of the goldens.
const kDeviceFrames = <DeviceFrame>[
  (
    name: 'iPhone',
    size: Size(393, 852),
    padding: EdgeInsets.only(top: 59, bottom: 34),
  ),
  (
    name: 'iPad portrait',
    size: Size(834, 1194),
    padding: EdgeInsets.only(top: 24, bottom: 20),
  ),
  (
    name: 'iPad landscape',
    size: Size(1194, 834),
    padding: EdgeInsets.only(top: 24, bottom: 20),
  ),
  (
    name: 'Android',
    size: Size(412, 915),
    padding: EdgeInsets.only(top: 24, bottom: 24),
  ),
];

/// The basic shell inside fixed device frames, scaled to fit, so one
/// screen shows every layout.
class FormFactorsCase extends StatelessWidget {
  /// Creates the case.
  const FormFactorsCase({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Form factors')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final frame in kDeviceFrames) ...[
          Text(frame.name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          // #docregion readme
          AspectRatio(
            aspectRatio: frame.size.aspectRatio,
            child: FittedBox(
              child: SizedBox.fromSize(
                size: frame.size,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: frame.size,
                    padding: frame.padding,
                    viewPadding: frame.padding,
                  ),
                  child: const BasicTabsCase(),
                ),
              ),
            ),
          ),
          // #enddocregion readme
          const SizedBox(height: 24),
        ],
      ],
    ),
  );
}
```

`liquid_shell/example/lib/cases/cases.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:liquid_shell_example/cases/badges.dart';
import 'package:liquid_shell_example/cases/basic_tabs.dart';
import 'package:liquid_shell_example/cases/custom_chrome.dart';
import 'package:liquid_shell_example/cases/custom_theme.dart';
import 'package:liquid_shell_example/cases/discard_guard.dart';
import 'package:liquid_shell_example/cases/forced_tier.dart';
import 'package:liquid_shell_example/cases/form_factors.dart';
import 'package:liquid_shell_example/cases/sidebar_only.dart';
import 'package:liquid_shell_example/cases/sidebar_slots.dart';
import 'package:liquid_shell_example/cases/trailing_action.dart';

/// One entry of the case list.
typedef ExampleCase = ({String id, String title, String subtitle, Widget page});

/// Every documented case, in README order.
const kCases = <ExampleCase>[
  (
    id: 'basic',
    title: 'Basic 3 tabs',
    subtitle: 'The smallest LiquidShell',
    page: BasicTabsCase(),
  ),
  (
    id: 'badges',
    title: 'Badges',
    subtitle: 'count(3), count(120) → 99+, dot()',
    page: BadgesCase(),
  ),
  (
    id: 'sidebar_only',
    title: 'Sidebar-only destinations',
    subtitle: 'Hidden on phones, with a fallback',
    page: SidebarOnlyCase(),
  ),
  (
    id: 'sidebar_slots',
    title: 'Sidebar header and footer',
    subtitle: 'App title and profile',
    page: SidebarSlotsCase(),
  ),
  (
    id: 'trailing',
    title: 'Trailing search action',
    subtitle: 'Opens a page above the shell',
    page: TrailingActionCase(),
  ),
  (
    id: 'guard',
    title: '"Discard changes?" guard',
    subtitle: 'beforeDestinationChange and LiquidHideChrome',
    page: DiscardGuardCase(),
  ),
  (
    id: 'custom_chrome',
    title: 'Custom chrome',
    subtitle: 'Wrap the bar, replace the sidebar',
    page: CustomChromeCase(),
  ),
  (
    id: 'custom_theme',
    title: 'Custom theme',
    subtitle: 'LiquidGlassTheme extension, light and dark',
    page: CustomThemeCase(),
  ),
  (
    id: 'forced_tier',
    title: 'Forced tier',
    subtitle: 'liquid / frosted / solid',
    page: ForcedTierCase(),
  ),
  (
    id: 'form_factors',
    title: 'Form factors',
    subtitle: 'iPhone, iPad portrait and landscape, Android',
    page: FormFactorsCase(),
  ),
];
```

`liquid_shell/example/lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell_example/cases/cases.dart';

void main() => runApp(const ExampleApp());

/// The seed colour of the example theme.
const kExampleSeed = Color(0xFF3D5AFE);

/// The example app: a list of cases, each opening one screen.
class ExampleApp extends StatelessWidget {
  /// Creates the app.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'liquid_shell',
    theme: ThemeData(colorSchemeSeed: kExampleSeed),
    darkTheme: ThemeData(
      colorSchemeSeed: kExampleSeed,
      brightness: Brightness.dark,
    ),
    home: const CaseList(),
  );
}

/// The home screen: one row per case.
class CaseList extends StatelessWidget {
  /// Creates the list.
  const CaseList({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('liquid_shell')),
    body: ListView(
      children: [
        for (final entry in kCases)
          ListTile(
            key: ValueKey('case-${entry.id}'),
            title: Text(entry.title),
            subtitle: Text(entry.subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => entry.page),
            ),
          ),
      ],
    ),
  );
}
```

- [ ] **Step 4: Run them to see them pass**

Run: `cd liquid_shell/example && fvm flutter test; cd ../..`
Expected: `+24: All tests passed!`

- [ ] **Step 5: Integration renders a real shell and saves a screenshot**

`liquid_shell/example/integration_test/signals_test.dart` becomes:

```dart
// Signal channel round-trip on a real simulator or emulator (spec §10.5).
//
// tool/integration_ios.sh and tool/integration_android.sh pass the expected
// value of each signal with --dart-define. An empty value means "do not
// check this field" (for example, battery saver also disables window blurs).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_shell_example/cases/basic_tabs.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

const _expectReduceTransparency = String.fromEnvironment(
  'EXPECT_REDUCE_TRANSPARENCY',
);
const _expectPowerSave = String.fromEnvironment('EXPECT_POWER_SAVE');
const _expectBlurDisabled = String.fromEnvironment('EXPECT_BLUR_DISABLED');

/// Names the screenshot of this run, for example `android_powerSave`.
const _runName = String.fromEnvironment('RUN_NAME', defaultValue: 'run');

/// Solid is expected when the run switched any signal on.
final _expectSolid = [
  _expectReduceTransparency,
  _expectPowerSave,
  _expectBlurDisabled,
].contains('true');

void _check(String expected, {required bool actual, required String name}) {
  if (expected.isEmpty) return;
  expect(actual, expected == 'true', reason: name);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the platform package registered the event channel', (
    tester,
  ) async {
    expect(
      LiquidShellPlatform.instance,
      isA<EventChannelLiquidShellPlatform>(),
    );
  });

  testWidgets('watchSignals emits a well-formed value within 5 s', (
    tester,
  ) async {
    final signals = await LiquidShellPlatform.instance
        .watchSignals()
        .first
        .timeout(const Duration(seconds: 5));
    debugPrint('liquid_shell integration: $signals');

    _check(
      _expectReduceTransparency,
      actual: signals.reduceTransparency,
      name: 'reduceTransparency',
    );
    _check(_expectPowerSave, actual: signals.powerSave, name: 'powerSave');
    _check(
      _expectBlurDisabled,
      actual: signals.blurDisabled,
      name: 'blurDisabled',
    );
  });

  testWidgets('the shell draws the tier the signals ask for', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: BasicTabsCase()));
    // The first channel event arrives asynchronously, then the tier fades.
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(
      find.byType(BackdropFilter),
      _expectSolid ? findsNothing : findsWidgets,
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      await binding.convertFlutterSurfaceToImage();
      await tester.pumpAndSettle();
    }
    await binding.takeScreenshot('shell_$_runName');
  });
}
```

`tool/integration_ios.sh` becomes:

```bash
#!/usr/bin/env bash
# Signal channel round-trip on iOS simulators (spec §10.5).
#
#   tool/integration_ios.sh
#
# IOS_RUNTIME   simctl runtime to pick devices from (default "iOS 26.5";
#               empty = any available runtime, used by CI).
# IOS_DEVICES   ';'-separated simulator names
#               (default "iPhone 17 Pro;iPad Pro 11-inch (M5)").
#               "auto" = the first available iPhone (CI).
# FLUTTER       flutter command (default: flutter).
#
# Reduce Transparency has no supported simctl switch, so only the default
# value is asserted here; toggling it is the manual check in docs/qa/.
set -euo pipefail
cd "$(dirname "$0")/../liquid_shell/example"
FLUTTER=${FLUTTER:-flutter}
IOS_RUNTIME=${IOS_RUNTIME-iOS 26.5}
IOS_DEVICES=${IOS_DEVICES:-iPhone 17 Pro;iPad Pro 11-inch (M5)}

udid_of() {
  local name=$1 pattern
  if [ "$name" = auto ]; then pattern='    iPhone'; else pattern="    $name ("; fi
  xcrun simctl list devices available ${IOS_RUNTIME:+"$IOS_RUNTIME"} \
    | grep -F "$pattern" | head -n1 \
    | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'
}

IFS=';' read -r -a names <<< "$IOS_DEVICES"
for name in "${names[@]}"; do
  udid=$(udid_of "$name")
  if [ -z "$udid" ]; then
    echo "✗ no available simulator named '$name' (${IOS_RUNTIME:-any runtime})" >&2
    exit 1
  fi
  echo "▸ $name ($udid)"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  $FLUTTER drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/signals_test.dart \
    -d "$udid" \
    --dart-define=RUN_NAME="ios_${name//[^A-Za-z0-9]/_}" \
    --dart-define=EXPECT_REDUCE_TRANSPARENCY=false \
    --dart-define=EXPECT_POWER_SAVE=false \
    --dart-define=EXPECT_BLUR_DISABLED=false
done
echo "✓ iOS integration passed"
```

`tool/integration_android.sh` becomes:

```bash
#!/usr/bin/env bash
# Signal channel + every Android signal on an emulator (spec §10.5).
#
#   tool/integration_android.sh
#
# ANDROID_SERIAL  adb serial (default: the first running emulator-*). The
#                 script changes system settings, so it refuses a physical
#                 device unless ALLOW_PHYSICAL_DEVICE=1.
# FLUTTER         flutter command (default: flutter).
#
# Each run sets one signal with adb, then asserts it through
# integration_test/signals_test.dart (expectations via --dart-define).
# Every setting is restored on exit, even after a failure.
set -euo pipefail
cd "$(dirname "$0")/../liquid_shell/example"
FLUTTER=${FLUTTER:-flutter}

if [ -z "${ANDROID_SERIAL:-}" ]; then
  ANDROID_SERIAL=$(adb devices | awk 'NR>1 && $2=="device" && $1 ~ /^emulator-/ {print $1; exit}')
fi
if [ -z "$ANDROID_SERIAL" ]; then
  echo "✗ no running emulator. Start one, e.g. emulator -avd tuvi_test" >&2
  exit 1
fi
if [[ "$ANDROID_SERIAL" != emulator-* && "${ALLOW_PHYSICAL_DEVICE:-0}" != 1 ]]; then
  echo "✗ $ANDROID_SERIAL is not an emulator; set ALLOW_PHYSICAL_DEVICE=1 to proceed" >&2
  exit 1
fi
export ANDROID_SERIAL
api=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
echo "▸ device $ANDROID_SERIAL, API $api"

orig_scale=$(adb shell settings get global animator_duration_scale | tr -d '\r')
restore() {
  if [ "$orig_scale" = null ]; then
    adb shell settings delete global animator_duration_scale >/dev/null || true
  else
    adb shell settings put global animator_duration_scale "$orig_scale" || true
  fi
  adb shell settings put global low_power 0 || true
  adb shell cmd battery reset || true
  adb shell settings put global disable_window_blurs 0 || true
}
trap restore EXIT
restore

run() {
  local name=$1
  shift
  echo "▸ run: $name"
  $FLUTTER drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/signals_test.dart \
    -d "$ANDROID_SERIAL" \
    --dart-define=RUN_NAME="android_$name" "$@"
}

blur_default=false
if [ "$api" -ge 31 ] &&
  [ "$(adb shell getprop ro.surface_flinger.supports_background_blur | tr -d '\r')" != 1 ]; then
  blur_default=true # no GPU blur on this image: the system reports it disabled
fi

run default \
  --dart-define=EXPECT_REDUCE_TRANSPARENCY=false \
  --dart-define=EXPECT_POWER_SAVE=false \
  --dart-define=EXPECT_BLUR_DISABLED=$blur_default

adb shell settings put global animator_duration_scale 0
run reduceTransparency --dart-define=EXPECT_REDUCE_TRANSPARENCY=true
restore

adb shell cmd battery unplug
adb shell settings put global low_power 1
# Battery saver also disables window blurs on API 31+, so blurDisabled is
# not asserted in this run.
run powerSave --dart-define=EXPECT_POWER_SAVE=true
restore

if [ "$api" -ge 31 ]; then
  # `wm disable-blur 1` writes this setting but needs root on API 36
  # google_apis images (SecurityException as the shell user).
  adb shell settings put global disable_window_blurs 1
  run blurDisabled --dart-define=EXPECT_BLUR_DISABLED=true
  restore
fi
echo "✓ Android integration passed"
```

Run: `make integration-ios && make integration-android`
Expected: `+4: All tests passed!` in all 6 runs. `liquid_shell/example/build/integration_screenshots/` then holds `shell_ios_iPhone_17_Pro.png`, `shell_ios_iPad_Pro_11_inch__M5_.png` and `shell_android_{default,reduceTransparency,powerSave,blurDisabled}.png`. Open one frosted and one solid image: the iPad shows the frosted top pill and toggle; Android `reduceTransparency` shows an opaque pill.

- [ ] **Step 6: Gates and commit**

Run: `make verify`
Expected: `✓ verify passed`.

```bash
.githooks/pre-commit
git add -A
git commit -m "feat(example): one screen per case, smoke tests, shell integration check (VK-345)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Goldens that generate the doc images

**Files:**
- Create: `liquid_shell/example/test/fonts/{Inter-Regular,Inter-Medium,Inter-SemiBold,Inter-Bold}.ttf`, `liquid_shell/example/test/fonts/OFL.txt`
- Create: `liquid_shell/example/test/flutter_test_config.dart`, `liquid_shell/example/test/support/golden_harness.dart`, `liquid_shell/example/test/goldens/{hero,cases,form_factors}_test.dart`, `tool/update_goldens.sh`, `liquid_shell/.pubignore`
- Modify: `liquid_shell/example/lib/support/demo_page.dart`, `.github/workflows/ci.yaml`
- Generated: `liquid_shell/doc/images/*.png` (21 images)

**Interfaces:**
- Consumes: Task 11 cases, `kExampleSeed`; Task 5 `debugLiquidGlassCanBlurOverride`, `debugResetLiquidGlassSignals`.
- Produces: `typedef GoldenDevice = ({String name, Size size, EdgeInsets padding, double gestureBottom, TargetPlatform platform})`; `const iphone, ipadPortrait, ipadLandscape, android`; `const goldenPixelRatio = 2.0`; `Future<void> loadGoldenFonts()` (called once from `flutter_test_config.dart`, outside fake async); `ThemeData goldenTheme(Brightness, TargetPlatform)`; `Future<void> pumpGolden(WidgetTester, Widget, {required GoldenDevice device, Brightness brightness})`; `Matcher matchesDocImage(String name)` → `../../../doc/images/<name>.png`; `class TolerantGoldenComparator extends LocalFileComparator { TolerantGoldenComparator(Uri testFile, {double tolerance = 0.005}); }`.

- [ ] **Step 1: Inter (OFL 1.1)**

```bash
mkdir -p liquid_shell/example/test/fonts
inter=$(mktemp -d)
curl -sSLo "$inter/inter.zip" https://github.com/rsms/inter/releases/download/v4.1/Inter-4.1.zip
shasum -a 256 "$inter/inter.zip"
unzip -o -q "$inter/inter.zip" -d "$inter" 'extras/ttf/Inter-Regular.ttf' 'extras/ttf/Inter-Medium.ttf' 'extras/ttf/Inter-SemiBold.ttf' 'extras/ttf/Inter-Bold.ttf' LICENSE.txt
cp "$inter"/extras/ttf/Inter-{Regular,Medium,SemiBold,Bold}.ttf liquid_shell/example/test/fonts/
cp "$inter/LICENSE.txt" liquid_shell/example/test/fonts/OFL.txt
shasum -a 256 liquid_shell/example/test/fonts/*
```

Expected: zip `9883fdd4a49d4fb66bd8177ba6625ef9a64aa45899767dde3d36aa425756b11e`; `Inter-Bold.ttf 288316099b1e0a47…`, `Inter-Medium.ttf 97ad806f526e4154…`, `Inter-Regular.ttf 40d692fce188e447…`, `Inter-SemiBold.ttf 78a843fade9d4612…`, `OFL.txt 262481e844521b32…`.

- [ ] **Step 2: Harness and config**

`liquid_shell/example/test/support/golden_harness.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_example/main.dart';

/// A golden device: logical size, safe area, gesture area and platform.
typedef GoldenDevice = ({
  String name,
  Size size,
  EdgeInsets padding,
  double gestureBottom,
  TargetPlatform platform,
});

/// iPhone 393×852 (top 59, bottom 34).
const iphone = (
  name: 'iphone',
  size: Size(393, 852),
  padding: EdgeInsets.only(top: 59, bottom: 34),
  gestureBottom: 34.0,
  platform: TargetPlatform.iOS,
);

/// iPad 11" portrait 834×1194 (top 24, bottom 20).
const ipadPortrait = (
  name: 'ipad_portrait',
  size: Size(834, 1194),
  padding: EdgeInsets.only(top: 24, bottom: 20),
  gestureBottom: 20.0,
  platform: TargetPlatform.iOS,
);

/// iPad 11" landscape 1194×834 (top 24, bottom 20).
const ipadLandscape = (
  name: 'ipad_landscape',
  size: Size(1194, 834),
  padding: EdgeInsets.only(top: 24, bottom: 20),
  gestureBottom: 20.0,
  platform: TargetPlatform.iOS,
);

/// Android phone 412×915 (top 24, gesture bottom 24).
const android = (
  name: 'android',
  size: Size(412, 915),
  padding: EdgeInsets.only(top: 24, bottom: 24),
  gestureBottom: 24.0,
  platform: TargetPlatform.android,
);

/// Device pixel ratio of every golden.
const goldenPixelRatio = 2.0;

/// Loads Inter (OFL, `test/fonts`) as the theme font and MaterialIcons from
/// the Flutter SDK cache, so text and icons render as glyphs, not boxes.
///
/// Reads files, so it must run outside `testWidgets` (fake async): it is
/// called once from `flutter_test_config.dart`.
Future<void> loadGoldenFonts() async {
  final inter = FontLoader('Inter');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    inter.addFont(_bytes('test/fonts/Inter-$weight.ttf'));
  }
  await inter.load();

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) {
    throw StateError('FLUTTER_ROOT is not set; run through `flutter test`.');
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      _bytes(
        '$flutterRoot/bin/cache/artifacts/material_fonts/'
        'MaterialIcons-Regular.otf',
      ),
    );
  await icons.load();
}

Future<ByteData> _bytes(String path) async =>
    ByteData.sublistView(await File(path).readAsBytes());

/// The example theme with the Inter font.
ThemeData goldenTheme(Brightness brightness, TargetPlatform platform) =>
    ThemeData(
      colorSchemeSeed: kExampleSeed,
      brightness: brightness,
      fontFamily: 'Inter',
      platform: platform,
    );

/// Sets up [device] and pumps [child] as the home of a MaterialApp.
Future<void> pumpGolden(
  WidgetTester tester,
  Widget child, {
  required GoldenDevice device,
  Brightness brightness = Brightness.light,
}) async {
  FakeViewPadding physical(EdgeInsets p) => FakeViewPadding(
    left: p.left * goldenPixelRatio,
    top: p.top * goldenPixelRatio,
    right: p.right * goldenPixelRatio,
    bottom: p.bottom * goldenPixelRatio,
  );
  tester.view
    ..devicePixelRatio = goldenPixelRatio
    ..physicalSize = device.size * goldenPixelRatio
    ..padding = physical(device.padding)
    ..viewPadding = physical(device.padding)
    ..systemGestureInsets = physical(
      EdgeInsets.only(bottom: device.gestureBottom),
    );
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: goldenTheme(brightness, device.platform),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

/// Matches the doc image `liquid_shell/doc/images/<name>.png`.
Matcher matchesDocImage(String name) =>
    matchesGoldenFile('../../../doc/images/$name.png');
```

`liquid_shell/example/test/flutter_test_config.dart`. Fonts load here, because file I/O inside `testWidgets` (fake async) never completes: in the dry run the first golden of each file hung for 10 minutes until this moved:

```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';

import 'support/golden_harness.dart';

/// Runs before every test file of the example.
///
/// `flutter test` reports Android without shader filters, so without the
/// override every golden would show the solid tier. `case_tier_solid` gets
/// solid through `forcedTier`, not through this flag.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() => debugLiquidGlassCanBlurOverride = true);
  tearDown(() {
    debugLiquidGlassCanBlurOverride = null;
    debugResetLiquidGlassSignals();
  });
  await loadGoldenFonts();
  final local = goldenFileComparator;
  if (local is LocalFileComparator) {
    goldenFileComparator = TolerantGoldenComparator(
      local.basedir.resolve('flutter_test_config.dart'),
    );
  }
  await testMain();
}

/// Passes when at most [tolerance] of the pixels differ (Q11: 0.5%).
class TolerantGoldenComparator extends LocalFileComparator {
  /// Creates the comparator for the test file at [testFile].
  TolerantGoldenComparator(super.testFile, {this.tolerance = 0.005});

  /// Largest accepted ratio of differing pixels, between 0 and 1.
  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
```

- [ ] **Step 3: Write the goldens and see them fail**

`liquid_shell/example/test/goldens/hero_test.dart`:

```dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_example/cases/sidebar_slots.dart';

import '../support/golden_harness.dart';

void main() {
  for (final device in [iphone, ipadLandscape, android]) {
    for (final brightness in Brightness.values) {
      final name = 'hero_${device.name}_${brightness.name}';
      testWidgets(name, (tester) async {
        await pumpGolden(
          tester,
          const SidebarSlotsCase(),
          device: device,
          brightness: brightness,
        );
        await expectLater(find.byType(MaterialApp), matchesDocImage(name));
      });
    }
  }
}
```

`liquid_shell/example/test/goldens/cases_test.dart` (Task 13 adds `case_hide_chrome`):

```dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/badges.dart';
import 'package:liquid_shell_example/cases/basic_tabs.dart';
import 'package:liquid_shell_example/cases/custom_chrome.dart';
import 'package:liquid_shell_example/cases/custom_theme.dart';
import 'package:liquid_shell_example/cases/discard_guard.dart';
import 'package:liquid_shell_example/cases/forced_tier.dart';
import 'package:liquid_shell_example/cases/sidebar_only.dart';
import 'package:liquid_shell_example/cases/sidebar_slots.dart';
import 'package:liquid_shell_example/cases/trailing_action.dart';

import '../support/golden_harness.dart';

/// One doc image per README case (spec §10.3).
void main() {
  Future<void> golden(
    WidgetTester tester,
    String name,
    Widget page, {
    GoldenDevice device = iphone,
    Future<void> Function()? interact,
  }) async {
    await pumpGolden(tester, page, device: device);
    if (interact != null) {
      await interact();
      await tester.pumpAndSettle();
    }
    await expectLater(find.byType(MaterialApp), matchesDocImage(name));
  }

  testWidgets('case_basic', (tester) async {
    await golden(tester, 'case_basic', const BasicTabsCase());
  });

  testWidgets('case_badges', (tester) async {
    await golden(tester, 'case_badges', const BadgesCase());
  });

  testWidgets('case_sidebar_only', (tester) async {
    await golden(
      tester,
      'case_sidebar_only',
      const SidebarOnlyCase(),
      device: ipadLandscape,
      interact: () => tester.tap(find.text('Reports')),
    );
  });

  testWidgets('case_sidebar_slots', (tester) async {
    await golden(
      tester,
      'case_sidebar_slots',
      const SidebarSlotsCase(),
      device: ipadLandscape,
    );
  });

  testWidgets('case_trailing', (tester) async {
    await golden(tester, 'case_trailing', const TrailingActionCase());
  });

  testWidgets('case_guard', (tester) async {
    await golden(
      tester,
      'case_guard',
      const DiscardGuardCase(),
      interact: () => tester.tap(find.text('Explore')),
    );
  });

  testWidgets('case_custom_chrome', (tester) async {
    await golden(tester, 'case_custom_chrome', const CustomChromeCase());
  });

  testWidgets('case_custom_theme', (tester) async {
    await golden(tester, 'case_custom_theme', const CustomThemeCase());
  });

  testWidgets('case_tier_frosted', (tester) async {
    await golden(tester, 'case_tier_frosted', const ForcedTierCase());
  });

  testWidgets('case_tier_solid', (tester) async {
    await golden(
      tester,
      'case_tier_solid',
      const ForcedTierCase(initialTier: LiquidGlassTier.solid),
    );
  });
}
```

`liquid_shell/example/test/goldens/form_factors_test.dart`:

```dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_example/cases/basic_tabs.dart';

import '../support/golden_harness.dart';

/// The basic shell on every reference device (spec §10.3).
void main() {
  for (final device in [iphone, ipadPortrait, ipadLandscape, android]) {
    final name = 'ff_${device.name}';
    testWidgets(name, (tester) async {
      await pumpGolden(tester, const BasicTabsCase(), device: device);
      await expectLater(find.byType(MaterialApp), matchesDocImage(name));
    });
  }

  testWidgets('ff_ipad_portrait_sidebar_open', (tester) async {
    await pumpGolden(tester, const BasicTabsCase(), device: ipadPortrait);
    await tester.tap(find.byTooltip('Show sidebar'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesDocImage('ff_ipad_portrait_sidebar_open'),
    );
  });
}
```

Run: `make goldens`
Expected: FAIL, `Could not be compared against non-existent file: "../../../doc/images/…png"`.

- [ ] **Step 4: Flat cards for clean images**

`liquid_shell/example/lib/support/demo_page.dart` becomes:

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/wallpaper.dart';

/// A long page over the [Wallpaper]. Its list is padded with
/// [LiquidShellScope.contentPaddingOf], so content scrolls under the glass
/// chrome but starts and ends clear of it.
class DemoPage extends StatelessWidget {
  /// Creates a page titled [title].
  const DemoPage({required this.title, this.children = const [], super.key});

  /// Page title, shown as the first row.
  final String title;

  /// Rows shown under the title, before the filler rows.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = Navigator.of(context).canPop();
    // Transparent Material: list tiles, switches and segmented buttons need
    // one, and the wallpaper must stay visible.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          const Positioned.fill(child: Wallpaper()),
          ListView(
            padding: LiquidShellScope.contentPaddingOf(
              context,
            ).add(const EdgeInsets.symmetric(horizontal: 16)),
            children: [
              Row(
                children: [
                  if (canPop) const BackButton(),
                  Expanded(
                    child: Text(title, style: theme.textTheme.headlineMedium),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...children,
              for (var i = 1; i <= 24; i++)
                Card(
                  // Flat: flutter_test paints shadows without blur, which
                  // would show as hard outlines in the doc images.
                  elevation: 0,
                  color: theme.colorScheme.surface.withValues(alpha: 0.8),
                  child: ListTile(
                    title: Text('$title item $i'),
                    subtitle: const Text('Scroll to see the glass chrome blur'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The three destinations most cases share.
const kDemoDestinations = [
  LiquidDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home),
    label: 'Home',
  ),
  LiquidDestination(
    icon: Icon(Icons.explore_outlined),
    selectedIcon: Icon(Icons.explore),
    label: 'Explore',
  ),
  LiquidDestination(
    icon: Icon(Icons.settings_outlined),
    selectedIcon: Icon(Icons.settings),
    label: 'Settings',
  ),
];
```

- [ ] **Step 5: One command for images**

`tool/update_goldens.sh` (then `chmod +x tool/update_goldens.sh`):

```bash
#!/usr/bin/env bash
# Regenerates every golden and doc image in liquid_shell/doc/images
# (spec §10.4). This is the ONLY way doc images are produced; never edit
# them by hand. Reference toolchain only (Q11): macOS + Flutter 3.38.x.
set -euo pipefail
cd "$(dirname "$0")/../liquid_shell/example"
FLUTTER=${FLUTTER:-flutter}

if [ "$(uname)" != Darwin ]; then
  echo "✗ goldens are generated on macOS only (spec Q11)" >&2
  exit 1
fi
version=$($FLUTTER --version --machine | grep -o '"frameworkVersion": *"[^"]*"' | grep -o '[0-9][0-9.]*')
case "$version" in
  3.38.*) ;;
  *)
    echo "✗ Flutter $version; goldens need 3.38.x (spec Q11)" >&2
    exit 1
    ;;
esac

$FLUTTER test --tags golden --update-goldens
echo "✓ goldens and doc images updated in liquid_shell/doc/images (Flutter $version)"
```

`liquid_shell/.pubignore`:

```gitignore
doc/images/
test/goldens/failures/
```

Run: `make goldens-update && ls liquid_shell/doc/images | wc -l && make goldens`
Expected: `✓ goldens and doc images updated in liquid_shell/doc/images (Flutter 3.38.10)`, `21`, then `+21: All tests passed!` (about 12 s).

Review the images, at least `case_badges.png` (3, 99+ and dot badges on the pill), `case_guard.png` (dialog over the shell), `hero_ipad_landscape_dark.png` (tiled sidebar with "Acme Notes" and footer) and `case_tier_solid.png` (opaque pill). Text must be Inter and icons must be real glyphs, never boxes.

- [ ] **Step 6: CI goldens job**

`.github/workflows/ci.yaml` becomes:

```yaml
name: ci

on:
  push:
    branches: [main]
  pull_request:

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

# Flutter 3.38.x is the supported floor and blocks merges. Latest stable runs
# as an early warning and never blocks (continue-on-error).
jobs:
  checks:
    name: checks (${{ matrix.flutter }})
    runs-on: ubuntu-latest
    continue-on-error: ${{ matrix.experimental }}
    strategy:
      fail-fast: false
      matrix:
        include:
          - flutter: 3.38.x
            experimental: false
          - flutter: stable
            experimental: true
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: ${{ matrix.flutter == 'stable' && '' || matrix.flutter }}
          cache: true
      - run: make get
      - run: make format-check
      - run: make analyze
      - run: make provenance
      - run: make test
      - run: make coverage
      - run: make snippets

  pana:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: make get
      - run: dart pub global activate pana
      # pana checks that `repository` on GitHub main contains this pubspec.
      # On a branch that adds a package, main does not have it yet, so those
      # 10 points are allowed off main only.
      - name: pana liquid_shell_platform_interface (max score on main)
        run: >
          dart pub global run pana --no-warning
          --exit-code-threshold ${{ github.ref == 'refs/heads/main' && '0' || '10' }}
          liquid_shell_platform_interface
      # These three depend on liquid_shell_platform_interface, which pana can
      # only resolve from pub.dev. Informational until P6 publishes it first.
      - name: pana dependants (informational until P6)
        continue-on-error: true
        run: |
          for p in liquid_shell liquid_shell_ios liquid_shell_android; do
            dart pub global run pana --no-warning --exit-code-threshold 0 "$p"
          done
      - run: make publish-check

  android-unit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: 3.38.x
          cache: true
      - run: make get
      - run: make android-unit

  integration-android:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Enable KVM
        run: |
          echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo tee /etc/udev/rules.d/99-kvm4all.rules
          sudo udevadm control --reload-rules
          sudo udevadm trigger --name-match=kvm
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: 17
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: 3.38.x
          cache: true
      - run: make get
      - uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 34
          target: google_apis
          arch: x86_64
          script: tool/integration_android.sh

  integration-ios:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: 3.38.x
          cache: true
      - run: make get
      - run: tool/integration_ios.sh
        env:
          IOS_RUNTIME: ""
          IOS_DEVICES: auto

  goldens:
    name: goldens (${{ matrix.flutter }})
    runs-on: macos-latest
    continue-on-error: ${{ matrix.experimental }}
    strategy:
      fail-fast: false
      matrix:
        include:
          - flutter: 3.38.x
            experimental: false
          - flutter: stable
            experimental: true
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: ${{ matrix.flutter == 'stable' && '' || matrix.flutter }}
          cache: true
      - run: make get
      - run: make goldens
      - if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: golden-failures-${{ matrix.flutter }}
          path: liquid_shell/example/test/goldens/failures/
```

- [ ] **Step 7: Gates and commit**

Run: `make verify`
Expected: `✓ verify passed`.

```bash
.githooks/pre-commit
git add -A
git commit -m "test(example): goldens that generate the doc images (VK-345)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: README, `doc/` guides, checked snippets

**Files:**
- Create: `tool/check_readme_snippets.dart`, `tool/test/check_readme_snippets_test.dart`, `liquid_shell/doc/{theming,tiers,router_integration}.md`
- Modify: `liquid_shell/README.md`, `liquid_shell/example/lib/cases/discard_guard.dart`, `liquid_shell/example/lib/cases/trailing_action.dart`, `liquid_shell/example/test/goldens/cases_test.dart`
- Generated: `liquid_shell/doc/images/case_hide_chrome.png`

**Interfaces:**
- Consumes: Task 11 `#docregion`s, Task 12 images and `make goldens-update`.
- Produces: `tool/check_readme_snippets.dart` with `Map<String, String> extractRegions(String source)`, `List<Excerpt> findExcerpts(String markdown)` (`typedef Excerpt = ({String file, String region, String code, int start, int end})`), `List<String> checkSnippets(String readme, Map<String, Map<String, String>> regions)`, `String fixSnippets(String readme, Map<String, Map<String, String>> regions)`, CLI `dart run tool/check_readme_snippets.dart [--fix]`. README markers: `<?code-excerpt "<file>.dart (<region>)"?>` directly above a ```` ```dart ```` block. New regions `hide-chrome` (discard_guard.dart) and `no-chrome` (trailing_action.dart).

- [ ] **Step 1: Write the failing checker tests**

`tool/test/check_readme_snippets_test.dart`:

````dart
import 'package:test/test.dart';

import '../check_readme_snippets.dart';

void main() {
  group('extractRegions', () {
    test('returns each named region, dedented', () {
      const source = '''
class A {
  Widget build() {
    // #docregion readme
    return Text(
      'hi',
    );
    // #enddocregion readme
  }
  // #docregion other
  int x = 1;
  // #enddocregion other
}
''';
      expect(extractRegions(source), {
        'readme': "return Text(\n  'hi',\n);",
        'other': 'int x = 1;',
      });
    });

    test('an unterminated region is an error', () {
      expect(
        () => extractRegions('// #docregion readme\nint x;\n'),
        throwsFormatException,
      );
    });
  });

  group('findExcerpts', () {
    test('pairs each marker with the dart block that follows it', () {
      const readme = '''
# Title

<?code-excerpt "basic_tabs.dart (readme)"?>
```dart
return 1;
```

Text.

<?code-excerpt "badges.dart (other)"?>
```dart
int x = 1;
```
''';
      final excerpts = findExcerpts(readme);
      expect(excerpts.map((e) => (e.file, e.region, e.code)), [
        ('basic_tabs.dart', 'readme', 'return 1;'),
        ('badges.dart', 'other', 'int x = 1;'),
      ]);
    });
  });

  group('checkSnippets', () {
    const regions = {
      'a.dart': {'readme': 'return 1;'},
    };

    test('passes when every snippet equals its region', () {
      const readme =
          '<?code-excerpt "a.dart (readme)"?>\n```dart\nreturn 1;\n```\n';
      expect(checkSnippets(readme, regions), isEmpty);
    });

    test('reports a drifted snippet', () {
      const readme =
          '<?code-excerpt "a.dart (readme)"?>\n```dart\nreturn 2;\n```\n';
      expect(
        checkSnippets(readme, regions).single,
        contains('a.dart (readme)'),
      );
    });

    test('reports a missing file or region', () {
      const readme =
          '<?code-excerpt "b.dart (readme)"?>\n```dart\nx\n```\n'
          '<?code-excerpt "a.dart (nope)"?>\n```dart\nx\n```\n';
      expect(checkSnippets(readme, regions), hasLength(2));
    });

    test('fixSnippets rewrites drifted blocks from the regions', () {
      const readme =
          '<?code-excerpt "a.dart (readme)"?>\n```dart\nreturn 2;\n```\n';
      final fixed = fixSnippets(readme, regions);
      expect(checkSnippets(fixed, regions), isEmpty);
    });
  });
}
````

Run: `fvm dart test tool/test`
Expected: FAIL, `Error when reading 'tool/check_readme_snippets.dart'`.

- [ ] **Step 2: Implement the checker**

`tool/check_readme_snippets.dart`:

````dart
// Checks that every README snippet equals its #docregion in
// liquid_shell/example/lib/cases (spec §12.3, Q13).
//
// A snippet is a ```dart block right after a marker line:
//   <?code-excerpt "basic_tabs.dart (readme)"?>
// Usage: dart run tool/check_readme_snippets.dart [--fix]
import 'dart:io';

/// One README snippet and where it claims to come from.
typedef Excerpt = ({
  String file,
  String region,
  String code,
  int start,
  int end,
});

final _marker = RegExp(r'^<\?code-excerpt "([^" ]+) \(([^)]+)\)"\?>$');
final _open = RegExp(r'^\s*// #docregion (\S+)\s*$');
final _close = RegExp(r'^\s*// #enddocregion (\S+)\s*$');

/// The named regions of a Dart [source], each dedented by its common
/// leading whitespace.
Map<String, String> extractRegions(String source) {
  final regions = <String, List<String>>{};
  final open = <String>{};
  for (final line in source.split('\n')) {
    final start = _open.firstMatch(line);
    final end = _close.firstMatch(line);
    if (start != null) {
      open.add(start[1]!);
      regions[start[1]!] = [];
    } else if (end != null) {
      open.remove(end[1]);
    } else {
      for (final name in open) {
        regions[name]!.add(line);
      }
    }
  }
  if (open.isNotEmpty) {
    throw FormatException('unterminated #docregion ${open.join(', ')}');
  }
  return {for (final e in regions.entries) e.key: _dedent(e.value)};
}

String _dedent(List<String> lines) {
  final indents = [
    for (final line in lines)
      if (line.trim().isNotEmpty) line.length - line.trimLeft().length,
  ];
  final cut = indents.isEmpty ? 0 : indents.reduce((a, b) => a < b ? a : b);
  return lines
      .map((l) => l.trim().isEmpty ? '' : l.substring(cut))
      .join('\n')
      .trim();
}

/// Every marked ```dart block in [markdown].
List<Excerpt> findExcerpts(String markdown) {
  final lines = markdown.split('\n');
  final excerpts = <Excerpt>[];
  for (var i = 0; i < lines.length; i++) {
    final marker = _marker.firstMatch(lines[i].trim());
    if (marker == null) continue;
    if (i + 1 >= lines.length || lines[i + 1].trim() != '```dart') {
      throw FormatException(
        'marker on line ${i + 1} is not followed by ```dart',
      );
    }
    final start = i + 2;
    var end = start;
    while (end < lines.length && lines[end].trim() != '```') {
      end++;
    }
    excerpts.add((
      file: marker[1]!,
      region: marker[2]!,
      code: lines.sublist(start, end).join('\n').trim(),
      start: start,
      end: end,
    ));
    i = end;
  }
  return excerpts;
}

/// Problems found in [readme] against [regions] (file → region → code).
List<String> checkSnippets(
  String readme,
  Map<String, Map<String, String>> regions,
) {
  final problems = <String>[];
  for (final e in findExcerpts(readme)) {
    final code = regions[e.file]?[e.region];
    if (code == null) {
      problems.add('${e.file} (${e.region}): no such #docregion');
    } else if (code != e.code) {
      problems.add('${e.file} (${e.region}): README snippet differs');
    }
  }
  return problems;
}

/// [readme] with every marked block replaced by its region.
String fixSnippets(String readme, Map<String, Map<String, String>> regions) {
  final lines = readme.split('\n');
  for (final e in findExcerpts(readme).reversed) {
    final code = regions[e.file]?[e.region];
    if (code == null) continue;
    lines.replaceRange(e.start, e.end, code.split('\n'));
  }
  return lines.join('\n');
}

void main(List<String> args) {
  final root = File.fromUri(Platform.script).parent.parent.path;
  final casesDir = Directory('$root/liquid_shell/example/lib/cases');
  final readmeFile = File('$root/liquid_shell/README.md');
  final regions = {
    for (final file in casesDir.listSync().whereType<File>())
      if (file.path.endsWith('.dart'))
        file.uri.pathSegments.last: extractRegions(file.readAsStringSync()),
  };
  final readme = readmeFile.readAsStringSync();
  if (args.contains('--fix')) {
    readmeFile.writeAsStringSync(fixSnippets(readme, regions));
    stdout.writeln('✓ README snippets rewritten from #docregion');
    return;
  }
  final problems = checkSnippets(readme, regions);
  final count = findExcerpts(readme).length;
  if (problems.isNotEmpty) {
    problems.forEach(stderr.writeln);
    stderr.writeln(
      '✗ README snippets drifted. Run: dart run '
      'tool/check_readme_snippets.dart --fix',
    );
    exit(1);
  }
  stdout.writeln('✓ $count README snippets match their #docregion');
}
````

Run: `fvm dart test tool/test`
Expected: `+11: All tests passed!`

- [ ] **Step 3: Regions and image for "hide chrome / no chrome"**

`liquid_shell/example/lib/cases/discard_guard.dart` becomes:

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// Asks "Discard changes?" before leaving a tab with unsaved edits.
class DiscardGuardCase extends StatefulWidget {
  /// Creates the case.
  const DiscardGuardCase({super.key});

  @override
  State<DiscardGuardCase> createState() => _DiscardGuardCaseState();
}

class _DiscardGuardCaseState extends State<DiscardGuardCase> {
  int _index = 0;
  bool _dirty = true;

  // #docregion readme
  Future<bool> _confirmLeave(int index) async {
    if (!_dirty || index == _index) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }
  // #enddocregion readme

  @override
  Widget build(BuildContext context) => LiquidShell(
    destinations: kDemoDestinations,
    selectedIndex: _index,
    beforeDestinationChange: _confirmLeave,
    onDestinationSelected: (i) => setState(() {
      if (i != _index) _dirty = false;
      _index = i;
    }),
    body: DemoPage(
      title: kDemoDestinations[_index].label,
      children: [
        SwitchListTile(
          title: const Text('Unsaved changes'),
          value: _dirty,
          onChanged: (value) => setState(() => _dirty = value),
        ),
        ListTile(
          title: const Text('Open a full-frame detail page'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const DetailPage()),
          ),
        ),
      ],
    ),
  );
}

/// A detail page that hides the chrome while it is open.
class DetailPage extends StatelessWidget {
  /// Creates the page.
  const DetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    // #docregion hide-chrome
    return const LiquidHideChrome(
      child: Scaffold(body: DemoPage(title: 'Detail')),
    );
    // #enddocregion hide-chrome
  }
}
```

`liquid_shell/example/lib/cases/trailing_action.dart` becomes:

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// A search circle at the end of the tab bar, opening a page above the shell.
class TrailingActionCase extends StatefulWidget {
  /// Creates the case.
  const TrailingActionCase({super.key});

  @override
  State<TrailingActionCase> createState() => _TrailingActionCaseState();
}

class _TrailingActionCaseState extends State<TrailingActionCase> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // #docregion readme
    return LiquidShell(
      destinations: kDemoDestinations,
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      tabBarTrailing: LiquidTabAction(
        icon: const Icon(Icons.search),
        semanticLabel: 'Search',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SearchPage()),
        ),
      ),
      body: DemoPage(title: kDemoDestinations[_index].label),
    );
    // #enddocregion readme
  }
}

/// A page pushed above the shell: no chrome covers it.
class SearchPage extends StatelessWidget {
  /// Creates the page.
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    // #docregion no-chrome
    return const LiquidNoChrome(
      child: Scaffold(
        body: DemoPage(
          title: 'Search',
          children: [TextField(decoration: InputDecoration(hintText: 'Find'))],
        ),
      ),
    );
    // #enddocregion no-chrome
  }
}
```

`liquid_shell/example/test/goldens/cases_test.dart` becomes:

```dart
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/badges.dart';
import 'package:liquid_shell_example/cases/basic_tabs.dart';
import 'package:liquid_shell_example/cases/custom_chrome.dart';
import 'package:liquid_shell_example/cases/custom_theme.dart';
import 'package:liquid_shell_example/cases/discard_guard.dart';
import 'package:liquid_shell_example/cases/forced_tier.dart';
import 'package:liquid_shell_example/cases/sidebar_only.dart';
import 'package:liquid_shell_example/cases/sidebar_slots.dart';
import 'package:liquid_shell_example/cases/trailing_action.dart';

import '../support/golden_harness.dart';

/// One doc image per README case (spec §10.3).
void main() {
  Future<void> golden(
    WidgetTester tester,
    String name,
    Widget page, {
    GoldenDevice device = iphone,
    Future<void> Function()? interact,
  }) async {
    await pumpGolden(tester, page, device: device);
    if (interact != null) {
      await interact();
      await tester.pumpAndSettle();
    }
    await expectLater(find.byType(MaterialApp), matchesDocImage(name));
  }

  testWidgets('case_basic', (tester) async {
    await golden(tester, 'case_basic', const BasicTabsCase());
  });

  testWidgets('case_badges', (tester) async {
    await golden(tester, 'case_badges', const BadgesCase());
  });

  testWidgets('case_sidebar_only', (tester) async {
    await golden(
      tester,
      'case_sidebar_only',
      const SidebarOnlyCase(),
      device: ipadLandscape,
      interact: () => tester.tap(find.text('Reports')),
    );
  });

  testWidgets('case_sidebar_slots', (tester) async {
    await golden(
      tester,
      'case_sidebar_slots',
      const SidebarSlotsCase(),
      device: ipadLandscape,
    );
  });

  testWidgets('case_trailing', (tester) async {
    await golden(tester, 'case_trailing', const TrailingActionCase());
  });

  testWidgets('case_guard', (tester) async {
    await golden(
      tester,
      'case_guard',
      const DiscardGuardCase(),
      interact: () => tester.tap(find.text('Explore')),
    );
  });

  testWidgets('case_hide_chrome', (tester) async {
    await golden(
      tester,
      'case_hide_chrome',
      const DiscardGuardCase(),
      interact: () => tester.tap(find.text('Open a full-frame detail page')),
    );
  });

  testWidgets('case_custom_chrome', (tester) async {
    await golden(tester, 'case_custom_chrome', const CustomChromeCase());
  });

  testWidgets('case_custom_theme', (tester) async {
    await golden(tester, 'case_custom_theme', const CustomThemeCase());
  });

  testWidgets('case_tier_frosted', (tester) async {
    await golden(tester, 'case_tier_frosted', const ForcedTierCase());
  });

  testWidgets('case_tier_solid', (tester) async {
    await golden(
      tester,
      'case_tier_solid',
      const ForcedTierCase(initialTier: LiquidGlassTier.solid),
    );
  });
}
```

Run: `make goldens-update && ls liquid_shell/doc/images | wc -l`
Expected: `22`.

- [ ] **Step 4: README, snippets red, then green**

Write `liquid_shell/README.md` with every ```` ```dart ```` block under a marker left **empty**, then:

Run: `make snippets`
Expected: FAIL, 12 lines like `basic_tabs.dart (readme): README snippet differs`, then `✗ README snippets drifted.`

Run: `fvm dart run tool/check_readme_snippets.dart --fix && make snippets`
Expected: `✓ README snippets rewritten from #docregion`, then `✓ 12 README snippets match their #docregion`.

The resulting `liquid_shell/README.md` must be exactly:

````markdown
# liquid_shell

Adaptive navigation shell with a Liquid Glass look for iOS and Android: a
floating glass tab bar on phones, a glass sidebar on tablets, and no router
dependency.

[![pub](https://img.shields.io/pub/v/liquid_shell.svg)](https://pub.dev/packages/liquid_shell)
[![CI](https://github.com/anvu69/liquid_shell/actions/workflows/ci.yaml/badge.svg)](https://github.com/anvu69/liquid_shell/actions/workflows/ci.yaml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

| | iPhone | iPad landscape | Android |
|---|---|---|---|
| Light | <img src="doc/images/hero_iphone_light.png" width="180" alt="iPhone, light"> | <img src="doc/images/hero_ipad_landscape_light.png" width="320" alt="iPad landscape, light"> | <img src="doc/images/hero_android_light.png" width="180" alt="Android, light"> |
| Dark | <img src="doc/images/hero_iphone_dark.png" width="180" alt="iPhone, dark"> | <img src="doc/images/hero_ipad_landscape_dark.png" width="320" alt="iPad landscape, dark"> | <img src="doc/images/hero_android_dark.png" width="180" alt="Android, dark"> |

## Features

- **One shell, every width.** A bottom glass pill below 700pt; a glass
  sidebar from 700pt, over the content in portrait and beside it in
  landscape from 1024pt, with a top pill and a toggle while it is hidden.
- **Router-agnostic.** You pass `selectedIndex`, `onDestinationSelected` and
  a `body`. Works with `IndexedStack`, `Navigator` or any router.
- **Badges**, **sidebar-only destinations**, **sidebar header and footer**,
  a **trailing action** (for example search) and an async **"Discard
  changes?" guard**.
- **Per-tab state survives** sidebar toggles, rotation and size changes: the
  body is never rebuilt under a new parent.
- **Glass tiers** (liquid, frosted, solid) behind a `LiquidGlassRenderer`
  seam, with automatic **solid fallback** for Reduce Transparency, battery
  saver, disabled window blurs and devices that cannot blur.
- **Accessible**: semantics, large-text icon-only cells with a large content
  viewer, RTL, and every string replaceable through `LiquidShellStrings`.
- Runtime dependencies: Flutter and this plugin's own packages only.

| Platform | Look | Signals |
|---|---|---|
| iOS 15+ | Glass pill and sidebar | Reduce Transparency |
| Android | Same as iOS | Animations off / high contrast, battery saver, window blurs disabled (API 31+), no Impeller |
| Web, macOS, Windows, Linux | Frosted glass | None (always frosted unless forced) |

## Install

```sh
flutter pub add liquid_shell
```

Requires Flutter 3.38 or later.

## Quickstart

<?code-excerpt "basic_tabs.dart (readme)"?>
```dart
return LiquidShell(
  destinations: const [
    LiquidDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
    LiquidDestination(icon: Icon(Icons.explore_outlined), label: 'Explore'),
    LiquidDestination(
      icon: Icon(Icons.settings_outlined),
      label: 'Settings',
    ),
  ],
  selectedIndex: _index,
  onDestinationSelected: (i) => setState(() => _index = i),
  body: IndexedStack(
    index: _index,
    children: const [
      DemoPage(title: 'Home'),
      DemoPage(title: 'Explore'),
      DemoPage(title: 'Settings'),
    ],
  ),
);
```

Pad your pages with `LiquidShellScope.contentPaddingOf(context)` so content
scrolls under the glass but starts and ends clear of it.

## Cases

Every case is a screen in [`example/`](example/lib/cases). Each snippet
below is checked against its source in CI, and each image is a golden test.

### Badges

<?code-excerpt "badges.dart (readme)"?>
```dart
const destinations = [
  LiquidDestination(
    icon: Icon(Icons.inbox_outlined),
    label: 'Inbox',
    badge: LiquidBadge.count(3),
  ),
  LiquidDestination(
    icon: Icon(Icons.forum_outlined),
    label: 'Chats',
    badge: LiquidBadge.count(120), // shows "99+"
  ),
  LiquidDestination(
    icon: Icon(Icons.notifications_outlined),
    label: 'Alerts',
    badge: LiquidBadge.dot(),
  ),
];
```

<img src="doc/images/case_badges.png" width="260" alt="Count, 99+ and dot badges">

### Sidebar-only destinations

`LiquidPlacement.sidebarOnly` destinations never appear in the tab bar. When
one is selected and the layout becomes compact, the shell calls
`onSelectedDestinationHidden` once so you can move elsewhere.

<?code-excerpt "sidebar_only.dart (readme)"?>
```dart
return LiquidShell(
  destinations: const [
    ...kDemoDestinations,
    LiquidDestination(
      icon: Icon(Icons.bar_chart),
      label: 'Reports',
      placement: LiquidPlacement.sidebarOnly,
    ),
    LiquidDestination(
      icon: Icon(Icons.archive_outlined),
      label: 'Archive',
      placement: LiquidPlacement.sidebarOnly,
    ),
  ],
  selectedIndex: _index,
  onDestinationSelected: (i) => setState(() => _index = i),
  // Phones have no sidebar: fall back to the first tab.
  onSelectedDestinationHidden: (_) => setState(() => _index = 0),
  body: DemoPage(title: 'Destination ${_index + 1}'),
);
```

<img src="doc/images/case_sidebar_only.png" width="480" alt="Sidebar with two sidebar-only rows">

### Sidebar header and footer

<?code-excerpt "sidebar_slots.dart (readme)"?>
```dart
return LiquidShell(
  destinations: kDemoDestinations,
  selectedIndex: _index,
  onDestinationSelected: (i) => setState(() => _index = i),
  sidebarHeader: Text('Acme Notes', style: theme.textTheme.titleLarge),
  sidebarFooter: const ListTile(
    leading: CircleAvatar(child: Text('A')),
    title: Text('Ana Lima'),
    subtitle: Text('ana@example.com'),
  ),
  body: DemoPage(title: kDemoDestinations[_index].label),
);
```

<img src="doc/images/case_sidebar_slots.png" width="480" alt="Sidebar with a title and a profile footer">

### Trailing action

The action is a separate glass circle at the end of the tab bar, and the
first row of the sidebar while the sidebar is shown.

<?code-excerpt "trailing_action.dart (readme)"?>
```dart
return LiquidShell(
  destinations: kDemoDestinations,
  selectedIndex: _index,
  onDestinationSelected: (i) => setState(() => _index = i),
  tabBarTrailing: LiquidTabAction(
    icon: const Icon(Icons.search),
    semanticLabel: 'Search',
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SearchPage()),
    ),
  ),
  body: DemoPage(title: kDemoDestinations[_index].label),
);
```

<img src="doc/images/case_trailing.png" width="260" alt="Search circle beside the tab bar">

### "Discard changes?" guard

`beforeDestinationChange` runs before every user selection, reselect
included. Return `false` (or throw) to stay. Taps while it is pending are
ignored.

<?code-excerpt "discard_guard.dart (readme)"?>
```dart
Future<bool> _confirmLeave(int index) async {
  if (!_dirty || index == _index) return true;
  final discard = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Discard changes?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep editing'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Discard'),
        ),
      ],
    ),
  );
  return discard ?? false;
}
```

<img src="doc/images/case_guard.png" width="260" alt="Discard changes dialog">

### Hide the chrome, or none at all

A full-frame page pushed **inside** a branch hides every piece of chrome
while it is mounted:

<?code-excerpt "discard_guard.dart (hide-chrome)"?>
```dart
return const LiquidHideChrome(
  child: Scaffold(body: DemoPage(title: 'Detail')),
);
```

A page pushed **above** the shell (root navigator) tells its content that no
chrome covers it:

<?code-excerpt "trailing_action.dart (no-chrome)"?>
```dart
return const LiquidNoChrome(
  child: Scaffold(
    body: DemoPage(
      title: 'Search',
      children: [TextField(decoration: InputDecoration(hintText: 'Find'))],
    ),
  ),
);
```

<img src="doc/images/case_hide_chrome.png" width="260" alt="A full-frame detail page without chrome">

### Custom chrome

`chromeBuilder` receives the chrome the shell would draw. Wrap it, or ignore
it and draw your own; the shell still places and measures the slot.
`LiquidTabBar` and `LiquidSidebar` are public for building your own.

<?code-excerpt "custom_chrome.dart (readme)"?>
```dart
Widget _chrome(
  BuildContext context,
  LiquidChromeDetails details,
  Widget defaultChrome,
) {
  if (details.slot == LiquidChromeSlot.tabBar) {
    // Wrap: a caption above the default bar.
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: ShapeDecoration(
            color: scheme.tertiaryContainer,
            shape: const StadiumBorder(),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text('Beta'),
          ),
        ),
        const SizedBox(height: 8),
        defaultChrome,
      ],
    );
  }
  // Replace: a plain list instead of the glass sidebar.
  return Material(
    child: ListView(
      children: [
        for (final i in details.visibleIndices)
          ListTile(
            leading: details.destinations[i].icon,
            title: Text(details.destinations[i].label),
            selected: i == details.selectedIndex,
            onTap: () => details.select(i),
          ),
      ],
    ),
  );
}
```

<img src="doc/images/case_custom_chrome.png" width="260" alt="Default tab bar with a Beta caption">

### Custom theme

<?code-excerpt "custom_theme.dart (readme)"?>
```dart
final scheme = ColorScheme.fromSeed(
  seedColor: const Color(0xFF00897B),
  brightness: _brightness,
);
final glass = LiquidGlassTheme.fromColorScheme(scheme).copyWith(
  tint: scheme.primaryContainer.withValues(alpha: 0.6),
  blurSigma: 18,
  labelStyle: const TextStyle(
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w700,
  ),
);
final theme = ThemeData(colorScheme: scheme, extensions: [glass]);
```

<img src="doc/images/case_custom_theme.png" width="260" alt="Brand-tinted glass">

See [doc/theming.md](doc/theming.md) for every field and its default.

### Forced tier

<?code-excerpt "forced_tier.dart (readme)"?>
```dart
return LiquidGlassScope(
  policy: LiquidGlassPolicy(forcedTier: _tier),
  child: LiquidShell(
    destinations: kDemoDestinations,
    selectedIndex: _index,
    onDestinationSelected: (i) => setState(() => _index = i),
    body: DemoPage(
      title: 'Forced tier',
      children: [
        SegmentedButton<LiquidGlassTier>(
          segments: [
            for (final tier in LiquidGlassTier.values)
              ButtonSegment(value: tier, label: Text(tier.name)),
          ],
          selected: {_tier},
          onSelectionChanged: (s) => setState(() => _tier = s.single),
        ),
        if (_tier == LiquidGlassTier.liquid)
          const Text('No liquid renderer is registered: drawing frosted.'),
      ],
    ),
  ),
);
```

| Frosted | Solid |
|---|---|
| <img src="doc/images/case_tier_frosted.png" width="260" alt="Frosted tier"> | <img src="doc/images/case_tier_solid.png" width="260" alt="Solid tier"> |

No liquid renderer ships yet; forcing `liquid` draws frosted. See
[doc/tiers.md](doc/tiers.md).

### Form factors

The example's form-factor screen puts the basic shell in fixed device frames:

<?code-excerpt "form_factors.dart (readme)"?>
```dart
AspectRatio(
  aspectRatio: frame.size.aspectRatio,
  child: FittedBox(
    child: SizedBox.fromSize(
      size: frame.size,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: frame.size,
          padding: frame.padding,
          viewPadding: frame.padding,
        ),
        child: const BasicTabsCase(),
      ),
    ),
  ),
),
```

| iPhone | Android | iPad portrait | iPad portrait, sidebar open | iPad landscape |
|---|---|---|---|---|
| <img src="doc/images/ff_iphone.png" width="140" alt="iPhone"> | <img src="doc/images/ff_android.png" width="140" alt="Android"> | <img src="doc/images/ff_ipad_portrait.png" width="200" alt="iPad portrait"> | <img src="doc/images/ff_ipad_portrait_sidebar_open.png" width="200" alt="iPad portrait with the sidebar open"> | <img src="doc/images/ff_ipad_landscape.png" width="280" alt="iPad landscape"> |

## Layout rules

Widths are the shell's own constraints, so Split View, freeform windows and
tests behave correctly.

| Layout | When | Sidebar | Tab bar |
|---|---|---|---|
| Compact | width < 700 | never | bottom pill |
| Regular, overlay | width ≥ 700, portrait or narrower than 1024 | hidden by default; covers the content when shown | top pill + toggle |
| Regular, tiled | width ≥ 1024 and landscape | shown by default, beside the content | none while shown; top pill + toggle when hidden |
| Hidden | a `LiquidHideChrome` is mounted | none | none |

Change the thresholds with `LiquidShellBreakpoints`. Read the current
layout, insets and sidebar state with `LiquidShellScope.of(context)`.

## Accessibility and fallbacks

Glass turns solid when any of these is on. A signal that cannot be read
counts as off, so the shell never fails to draw.

| Signal | iOS | Android |
|---|---|---|
| Reduce transparency | Reduce Transparency | Animator duration scale 0, or high contrast (API 34+ contrast, or high-text-contrast) |
| High contrast | Increase Contrast | (reported through reduce transparency) |
| Battery saver | not used | Battery Saver |
| Window blurs disabled | not used | `isCrossWindowBlurEnabled` false (API 31+) |
| Cannot blur | never | No Impeller (Skia, API 28 and lower) |

Cells and rows are buttons with labels, badge text and selected state. From
1.6× text size the bar is icon-only and a long press shows the label large.
The overlay sidebar is modal for screen readers, and system back closes it.

## More

- [doc/theming.md](doc/theming.md): `LiquidGlassTheme` fields and defaults
- [doc/tiers.md](doc/tiers.md): tiers, the policy, signals, writing a renderer
- [doc/router_integration.md](doc/router_integration.md): `IndexedStack`,
  `Navigator` and go_router wiring, branch state, hide/no chrome

Roadmap: native iOS chrome (UITabBarController, window controls); back
button and search field; a liquid tier for Android; a go_router adapter;
0.1.0 on pub.dev.

## License

MIT. See [LICENSE](LICENSE).
````

- [ ] **Step 5: The guides**

`liquid_shell/doc/theming.md`:

````markdown
# Theming

All glass reads one `ThemeExtension`, `LiquidGlassTheme`. Without one,
`LiquidGlassTheme.of(context)` derives it from the **displayed**
`Theme.of(context).colorScheme` (never from the platform brightness), so
`themeMode` and nested `Theme` widgets just work.

## Fields and defaults

| Field | Light | Dark | Used for |
|---|---|---|---|
| `tint` | `surface` @ 0.72 | `surface` @ 0.90 | frosted fill |
| `solid` | `surface` | `surface` | solid fill |
| `border` | `outline` @ 0.28 | `onSurface` @ 0.18 | 1px outline |
| `borderWidth` | 1 | 1 | outline width |
| `rimHighlight` | white @ 0.50 | white @ 0.18 | frosted top-edge highlight |
| `shadow` | `#24000000`, offset (0, 6), blur 20, spread −2 | same | drawn outside the shape only |
| `blurSigma` | 10 | 10 | frosted blur |
| `borderRadius` | pill (999) | pill | bars, circles |
| `labelStyle` | 10/14, w600, letter spacing 0.4, theme font | same | compact tab labels |

Tab colours come from the `ColorScheme`: the selected cell is `primary` on
a `primaryContainer` chip, others `onSurfaceVariant`. Top-bar labels use
`textTheme.labelMedium`; sidebar rows use `textTheme.bodyLarge`
(`onPrimaryContainer` on `primaryContainer` when selected).

## A brand theme

```dart
final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF00897B));
final glass = LiquidGlassTheme.fromColorScheme(scheme).copyWith(
  tint: scheme.primaryContainer.withValues(alpha: 0.6),
  blurSigma: 18,
);
MaterialApp(
  theme: ThemeData(colorScheme: scheme, extensions: [glass]),
  darkTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF00897B),
      brightness: Brightness.dark,
    ),
  ), // no extension: dark defaults are derived
  home: const MyShell(),
);
```

`LiquidGlassTheme` implements `lerp`, so theme animations interpolate the
glass too.

## Your own glass surfaces

`LiquidGlass` is public. Wrap any widget to get the same tiers, signals and
theme as the chrome:

```dart
LiquidGlass(
  borderRadius: BorderRadius.circular(20),
  child: const Padding(
    padding: EdgeInsets.all(16),
    child: Text('Now playing'),
  ),
)
```

Keep glass to a few surfaces: every frosted surface reads the backdrop. The
shell groups its own chrome into one `BackdropGroup`; never put glass on list
cells.
````

`liquid_shell/doc/tiers.md`:

````markdown
# Glass tiers

| Tier | Drawn as | Ships in |
|---|---|---|
| `liquid` | refracting glass | a separate adapter package (planned); none in this package |
| `frosted` | backdrop blur, tint, 1px border, rim highlight, outside shadow | built in |
| `solid` | opaque fill, border, outside shadow; no blur | built in |

A tier change cross-fades over 200ms (instantly with reduce motion). The
child of a `LiquidGlass` is never rebuilt by a tier change, so focus and
scroll position survive.

## How the tier is chosen

`LiquidGlassPolicy.resolve(context, signals)`:

1. `forcedTier` set → that tier. If it has no supported renderer, step down
   liquid → frosted → solid (logged once in debug builds).
2. Any signal asks for solid (`LiquidGlassSignals.prefersSolid`) → solid.
3. Otherwise the richest tier with a supported renderer: liquid if a
   registered liquid renderer's `isSupported` is true, else frosted.

Signals:

| Field | Source |
|---|---|
| `reduceTransparency` | iOS Reduce Transparency. Android: animator duration scale 0, contrast > 0 (API 34+), or the high-text-contrast setting |
| `highContrast` | `MediaQuery.highContrastOf` (reported by iOS) |
| `powerSave` | Android battery saver (iOS Low Power Mode is ignored, like the system glass) |
| `blurDisabled` | Android 12+ `WindowManager.isCrossWindowBlurEnabled` false: battery saver, GPU without blur, or the developer "disable window blurs" switch |
| `canBlur` | false only on Android without Impeller (`ImageFilter.isShaderFilterSupported`, Skia on API 28 and lower) |

Android signals are best effort: OEM builds vary, and Android 16's "Reduce
blur effects" has no public API (on the API 36 emulator it is not exposed as
a setting). Every read that fails counts as off.

## Forcing a tier

```dart
LiquidGlassScope(
  policy: const LiquidGlassPolicy(forcedTier: LiquidGlassTier.solid),
  child: MyShell(),
)
```

Put the scope in `MaterialApp.builder` to cover pages pushed above the
shell too.

## Writing a renderer

```dart
class TintOnlyRenderer extends LiquidGlassRenderer {
  const TintOnlyRenderer();

  @override
  LiquidGlassTier get tier => LiquidGlassTier.liquid;

  @override
  bool isSupported(BuildContext context) =>
      ui.ImageFilter.isShaderFilterSupported;

  @override
  Widget buildBackground(BuildContext context, LiquidGlassSpec spec) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: spec.theme.tint,
          borderRadius: spec.borderRadius,
        ),
      );
}

LiquidGlassScope(
  policy: const LiquidGlassPolicy(renderers: [TintOnlyRenderer()]),
  child: MyShell(),
)
```

Rules: fill the parent, paint nothing outside the shape except a shadow, and
keep `isSupported` cheap. If `isSupported` throws, the error is reported and
the renderer counts as unsupported.

## Testing

`flutter test` reports Android without shader filters, so the probe answers
"cannot blur" and glass is solid. Set the override in
`test/flutter_test_config.dart`:

```dart
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() => debugLiquidGlassCanBlurOverride = true);
  tearDown(() {
    debugLiquidGlassCanBlurOverride = null;
    debugResetLiquidGlassSignals();
  });
  await testMain();
}
```
````

`liquid_shell/doc/router_integration.md` (Markdown may name go_router, see D2):

````markdown
# Router integration

`LiquidShell` owns no navigation. You give it the selected index, a callback
and a `body`; it gives you chrome, insets and the sidebar.

## Keep branch state alive

The shell never rebuilds `body` under a new parent, so state survives every
layout change. Keeping **inactive** branches alive is your job: use an
`IndexedStack` (or your router's equivalent).

```dart
LiquidShell(
  destinations: destinations,
  selectedIndex: index,
  onDestinationSelected: (i) => setState(() => index = i),
  body: IndexedStack(
    index: index,
    children: [for (final tab in tabs) tab.page],
  ),
)
```

## One Navigator per tab

```dart
final keys = [for (final _ in tabs) GlobalKey<NavigatorState>()];

LiquidShell(
  destinations: destinations,
  selectedIndex: index,
  onDestinationSelected: (i) {
    if (i == index) {
      keys[i].currentState!.popUntil((route) => route.isFirst); // reselect
    }
    setState(() => index = i);
  },
  body: IndexedStack(
    index: index,
    children: [
      for (final (i, tab) in tabs.indexed)
        Navigator(
          key: keys[i],
          onGenerateRoute: (_) => MaterialPageRoute(builder: tab.builder),
        ),
    ],
  ),
)
```

## go_router (until the adapter ships)

```dart
StatefulShellRoute.indexedStack(
  builder: (context, state, shell) => LiquidShell(
    destinations: destinations,
    selectedIndex: shell.currentIndex,
    onDestinationSelected: (i) =>
        shell.goBranch(i, initialLocation: i == shell.currentIndex),
    body: shell,
  ),
  branches: [/* one StatefulShellBranch per destination */],
)
```

`StatefulShellRoute.indexedStack` already keeps each branch alive.

## Pages and the chrome

| Page | Wrap it in | Effect |
|---|---|---|
| Inside a branch, normal | nothing; pad with `LiquidShellScope.contentPaddingOf(context)` | content scrolls under the glass |
| Inside a branch, full frame (reader, detail) | `LiquidHideChrome` | every piece of chrome hides while it is mounted |
| Above the shell (root navigator: search, sheets) | `LiquidNoChrome` | its insets ignore the chrome underneath |
| Static content | `LiquidContentInset` | `Padding(contentPaddingOf(context))` |

## Leaving a page with unsaved work

`beforeDestinationChange` runs before every user selection (not before
programmatic `selectedIndex` changes). Show a dialog and return its answer:

```dart
beforeDestinationChange: (index) async {
  if (!form.isDirty) return true;
  return await showDialog<bool>(
        context: context,
        builder: (_) => const DiscardDialog(),
      ) ??
      false;
},
```

While it is pending, further taps are ignored. A throw counts as `false`
and is reported through `FlutterError.reportError`.

## The sidebar from your pages

```dart
final scope = LiquidShellScope.of(context);
if (scope.sizeClass == LiquidSizeClass.regular) {
  scope.setSidebarVisible(false); // for example, on a wide editor page
}
```

There is one shell-wide sidebar state. It resets to the default (shown when
tiled, hidden when overlay) whenever the presentation changes.
````

- [ ] **Step 6: Gates and commit**

Run: `make verify && make publish-check`
Expected: `✓ 12 README snippets match their #docregion`, `✓ verify passed`, and `Package has 0 warnings.` for all four packages (run `publish-check` after committing; uncommitted files count as a warning). The `liquid_shell` archive is about 900 KB, with the OFL fonts and without `doc/images/`.

```bash
.githooks/pre-commit
git add -A
git commit -m "docs(shell): README with checked snippets and images, theming/tiers/router guides (VK-345)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: Final verification and evidence

**Files:**
- Create: `docs/qa/2026-10-08-vk345-signals/` (screenshots, manual check)

**Interfaces:**
- Consumes: everything. Produces: the PR evidence (§13: every §10.6 command run locally with output pasted).

- [ ] **Step 1: Everything blocking CI runs**

Run: `make get && make verify`
Expected (tail): `✓ provenance clean`, `✓ coverage 97.91% (938/958 lines) in liquid_shell/…`, `✓ coverage 100.00% (57/57 lines) in liquid_shell_platform_interface/…`, `+22: All tests passed!` (goldens), `✓ 12 README snippets match their #docregion`, `✓ verify passed`.

- [ ] **Step 2: Native and device suites**

Run: `make android-unit && make integration-ios && make integration-android`
Expected: `BUILD SUCCESSFUL` with 7 `PASSED`; `✓ iOS integration passed`; `✓ Android integration passed`.

- [ ] **Step 3: Manual Reduce Transparency check on iOS (spec §10.5)**

Run the example on the iPhone 17 Pro simulator (iOS 26.5): `cd liquid_shell/example && fvm flutter run -d "iPhone 17 Pro"`. Open "Basic 3 tabs". Save a screenshot: `xcrun simctl io booted screenshot ../../docs/qa/2026-10-08-vk345-signals/ios-frosted.png`. In the simulator open Settings → Accessibility → Display & Text Size → Reduce Transparency → on, return to the app: the pill must turn opaque within a second without restarting. Save `ios-reduce-transparency.png`. Turn the switch off again.

Extra automated check (verified in the dry run; the defaults key is undocumented):

```bash
U=$(xcrun simctl list devices available "iOS 26.5" | grep -F "    iPhone 17 Pro (" | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
xcrun simctl spawn "$U" defaults write com.apple.Accessibility EnhancedBackgroundContrastEnabled -bool true
(cd liquid_shell/example && fvm flutter drive --driver=test_driver/integration_test.dart --target=integration_test/signals_test.dart -d "$U" --dart-define=EXPECT_REDUCE_TRANSPARENCY=true --dart-define=RUN_NAME=ios_reduce_transparency)
xcrun simctl spawn "$U" defaults write com.apple.Accessibility EnhancedBackgroundContrastEnabled -bool false
cp liquid_shell/example/build/integration_screenshots/shell_ios_reduce_transparency.png docs/qa/2026-10-08-vk345-signals/
```

Expected: `LiquidPlatformSignals(reduceTransparency: true, powerSave: false, blurDisabled: false)` and `+4: All tests passed!`.

- [ ] **Step 4: Toolchain cross-check and pub.dev checks**

Run: `make pana`
Expected for `liquid_shell_platform_interface`: `Points: 150/160.` before the branch is merged (only "Provide a valid `pubspec.yaml`" fails, because GitHub `main` does not have the package yet). For `liquid_shell_ios` (and likewise the other two): `Points: 40/150.`. Dependency resolution fails until the interface is on pub.dev (O1).

Run: `make publish-check`
Expected: `Package has 0 warnings.` ×4.

Optional cross-check on the app's toolchain: `~/fvm/versions/3.44.6/bin/flutter pub get && (cd liquid_shell && ~/fvm/versions/3.44.6/bin/flutter test) && (cd liquid_shell/example && ~/fvm/versions/3.44.6/bin/flutter test --tags golden)`, then `fvm flutter pub get` to return to 3.38.10. Expected: `+152` and `+22: All tests passed!`.

- [ ] **Step 5: Whole-branch review, then commit the evidence**

Run `superpowers:requesting-code-review` on the branch, then `superpowers:verification-before-completion`.

```bash
.githooks/pre-commit
git add docs/qa
git commit -m "docs(qa): signal screenshots and verification evidence (VK-345)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

The PR body links VK-345 and pastes the outputs of Steps 1–4. Do not push; the controller pushes.

---

## Execution notes

- Before Task 1, the controller creates one Plane sub-issue under VK-345 per task (14), titled `P1 Task N: <task name>`, and moves each to Done with its commit SHA and the pasted command output.
- Tasks 2 and 3 can run in parallel worktrees after Task 1 (they touch different packages). After that the tasks are sequential: each consumes the previous one's exported names.
- Device runs take about 3 min (iOS, two simulators) and 7 min (Android, four runs). Never point `integration_android.sh` at a physical phone: it changes system settings.
- Local runs on this machine: run `flutter pub get` with the toolchain you then test with. A `pub get` on 3.44.6 rewrites `.dart_tool` for that SDK.
- Disk: device builds need about 10 GB free. The dry run filled the disk once (5 GB free at the start of the last step); delete `liquid_shell/example/build` between device runs if space is short.

## Dry-run notes

The plan was executed end to end on a scratch copy (`rsync` of the repo with `.git` removed and re-initialised, so the real repo was never touched): one commit per task, tags `t1`–`t13`. Every code block above was generated from those commits by a script (`git show tN:<path>`), so each block is the exact code that passed. Toolchain: Flutter 3.38.10 / Dart 3.10.9 via fvm, Xcode 27.0, CocoaPods 1.17.0, JDK 17, iOS 26.5 simulators, AVD `tuvi_test` (Pixel 7, API 36, Android 16).

| Task | Result in the dry run |
|---|---|
| 1 | `make verify` green; risk probe `+3`; provenance red→green on a probe file; publish dry-run 0 warnings ×4 |
| 2 | red (undefined names) → `+15`; coverage 100% (57/57) |
| 3 | `+1` ×2 (Dart registrars); Kotlin red (no main class) → 7 PASSED; iOS iPhone 17 Pro + iPad Pro 11" (M5) green; Android default / reduceTransparency / powerSave / blurDisabled green; settings restored |
| 4 | red → green (14 + 8 + 6 tests); coverage 92.51% |
| 5 | red → `+13`; coverage 94.90%; device runs green with the tier assertion |
| 6 | red → `+16`; 96.12% |
| 7 | red → `+16`; 97.17% |
| 8 | red → `+9`; 97.42% |
| 9 | red → `+22`; 97.57% |
| 10 | red → `+45`; 97.91% (938/958); 152 package tests |
| 11 | red → `+24`; all 6 device runs green, 6 screenshots checked by eye |
| 12 | red (no golden files) → 21 images → `+21` in about 12 s |
| 13 | checker red → `+11`; README red (12 drifted) → `--fix` → green; 22 images; publish dry-run 0 warnings ×4 |
| 14 | `make verify`, `android-unit`, `integration-ios`, `integration-android` and `.githooks/pre-commit` all exit 0; pana: interface 150/160 (repository check only), `liquid_shell_ios` 40/150 (no interface on pub.dev); simctl Reduce Transparency run green |

Problems found and fixed during the dry run (already reflected in the plan):

1. `example/ios/Podfile` needs `platform :ios, '15.0'` plus a `post_install` deployment-target override. Without them, Xcode 27 fails the Flutter pod (13.0).
2. `EventChannel.receiveBroadcastStream` reports a failed `listen` through `FlutterError.reportError` and never emits, which would break spec §6.5. So the interface drives the channel by hand.
3. `testWidgets` asserts that `debugPrint` and `FlutterError.onError` are restored before `tearDown`. Tests restore them in a `try/finally` inside the body.
4. A platform signal needs two pumps in widget tests: one to deliver the event, one to rebuild.
5. `excludeSemantics` cells expose a tap action but no focus action. Matchers were adjusted.
6. The toggle measured through `find.byTooltip` is the 40pt IconButton, not the 48pt circle. Tests find `SidebarToggle`.
7. `find.bySemanticsLabel` reads stale render-object semantics. Overlay blocking is asserted with `find.semantics.byLabel`.
8. Taps in the per-tab-state test landed under the top chrome. The harness pages pad with `contentPaddingOf`.
9. Case pages need a `Material` ancestor (`DemoPage` adds a transparent one). `Chip` in the chrome builder was replaced.
10. Case rows run off-screen on a phone, so the smoke test scrolls and calls `ensureVisible` before tapping.
11. Font loading inside `testWidgets` hung for 10 minutes (real file I/O under fake async). It moved to `flutter_test_config.dart`.
12. `wm disable-blur 1` throws `SecurityException` on API 36 google_apis. The script writes the setting directly.
13. The provenance scan first matched generated, gitignored files containing the scratch path. It now uses `git grep --untracked`, which respects `.gitignore`.

Cross-checks:
- Flutter 3.44.6: 152 package tests, analyze and all goldens green; golden drift stays within 0.5%.
- SwiftPM: the package graph resolves; the app build fails in Flutter's lipo check under Xcode 27 on both SDKs (O2).
- GitHub Actions YAML was parsed (jobs `checks, pana, android-unit, integration-android, integration-ios, goldens`) but not executed; the first push is the first real CI run.

## Self-review

**Spec coverage.** §2.1 S1 → Tasks 1, 3; S2 → 9, 10; S3 features 1/3/4/5/6 → 6–8 (badges, sidebarOnly, slots, trailing) and 10 (per-tab state); S4 → 10; S5 → 10; S6 → 4, 5; S7 → 2, 3; S8 → 6; S9 → 1–14 (CI 1/3/12, coverage 1); S10 → 11–13. §3 layout and pubspecs → 1, 3. §4.1–4.9 → 4–10, with exports in the final `liquid_shell.dart` (Task 10). §5.1–5.10 → 9, 10, 7, 8, 4, 5. §6 → 2, 3. §7 error table → asserts and fallbacks in 2, 4, 5, 6, 10, each with a test. §8 file map → ported files 4–10, couplings removed (the provenance gate passes). §9 → 1 (gate, rules), 3 (driver written from public docs). §10.1–10.6 → unit 2/4/6/9, widget 4–10, goldens 12, integration 3/5/11, CI 1/3/12. §11 → 11. §12 → 13. §13 → execution notes and Task 14. §14 → risk table. Gaps: none. Deviations are listed under D1–D8 and O1–O2.

**Placeholder scan.** No "TBD", "TODO" or "similar to Task N". Every code step embeds a complete file. Generated files (`flutter create`, `pod install`, PNGs) come from exact commands.

**Type consistency.** Names checked across tasks: `LiquidTabBarPosition.top`, `kLiquidTabBarTrailingGap`, `kSidebarToggleInset/Size`, `kBottomPillExtent/kTopBarGap/kTopPillExtent`, `badgeSemanticsLabel(label, badge, strings)`, `debugResetPolicyLogging()` (called by `debugResetLiquidGlassSignals()`), `installFakeSignals()`, `pumpGolden(..., device:)`, `matchesDocImage(name)`, `ForcedTierCase(initialTier:)`, `DemoPage(title:, children:)`. They are identical in every task, because the code compiled and passed at each tag.

## Execution handoff

Plan complete and saved to `docs/plans/2026-10-08-p1-foundation.md`. Two execution options:

1. **Subagent-Driven (recommended).** A fresh subagent per task, review between tasks (superpowers:subagent-driven-development).
2. **Inline execution.** Tasks in one session with checkpoints (superpowers:executing-plans).
