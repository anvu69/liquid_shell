# liquid_shell P3a: native iOS alerts and action sheets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> **Approval:** the owner approves this plan with the spec `docs/specs/2026-10-10-p3a-native-alerts-design.md`. The spec's last section, the table "Quyết định cần chủ sản phẩm xác nhận", lists the open choices, and this plan builds every recommended default. If the owner picks differently, the affected steps are named in the Q's row of the "Decision hooks" table below.

**Goal:** `showLiquidAlert` / `showLiquidActionSheet` present a real `UIAlertController` on iOS 26+ (above P2's native chrome) and a Flutter glass dialog through `LiquidGlass` everywhere else. Both complete with the chosen action's value, and the example's "Discard changes?" guard uses them (VK-406).

**Architecture:** A sealed request/result pair in the platform interface. One async Pigeon host call in the existing channel. A per-engine Swift `NativeDialogPresenter`, which presents from the top-most view controller of the engine's own window, waits out transitions, and ends every Dart future exactly once. On the Dart side, a native-first orchestrator falls back to `showGeneralDialog` glass widgets when the platform answers "unavailable". Values never cross the channel: native answers an index.

**Tech Stack:** Flutter 3.44.6 / Dart 3.12 (fvm), Swift 5 + UIKit (iOS 15 deployment target), Pigeon 27.3.0 (dev), CocoaPods, XCTest (`RunnerTests`), XCUITest (new `RunnerUITests`), `flutter_test`, `integration_test`, Xcode 27 with iOS 26.5 simulators.

## Global Constraints

- Floor: Flutter `>=3.44.0`, Dart `^3.12.0`, iOS deployment target `15.0`; fvm pins `3.44.6` (`.fvmrc`).
- `very_good_analysis` pinned to `10.3.0`. `dart analyze --fatal-infos --fatal-warnings` must be clean. Never loosen `analysis_options.yaml`.
- Runtime dependencies: Flutter + our packages + `plugin_platform_interface`, plus `meta` in `liquid_shell_ios`. Nothing new. `pigeon: 27.3.0` stays the only generator (dev, exact). The dialog API goes in the EXISTING `liquid_shell_ios/pigeons/native_shell.dart`. A second Pigeon file would duplicate `PigeonError` in the Swift module.
- Native dialogs are presented when: `LIQUID_SHELL_NATIVE_OFF != "1"`, then (`requireGlass == false` or iOS ≥ 26), then the engine's view controller is in a window (spec §5.2). The Info.plist key `LiquidShellNativeChrome` is NOT required (Q3).
- `presentation: auto` → native on iOS 26+, Flutter glass elsewhere (L3). `system` → native on every iOS (Q2). `flutter` → always Flutter glass.
- Dismissed without a choice → the cancel action's value, or null without one. Never shown (the context is gone before the fallback) → null (spec §4.2, Q11).
- Validation throws `ArgumentError` synchronously before anything is shown. It throws when there are no actions, more than one cancel action, more than one preferred action, a blank label, or a blank alert title.
- Every Dart future ends exactly once: a tap, a popover dismissed outside, an external dismissal (the lifetime sentinel), a refused present (→ fallback), or engine detach (spec §5.4).
- Every glass surface of the fallback is a `LiquidGlass` (L3). No `BackdropFilter` and no colours outside `Theme`/`LiquidGlassTheme`.
- No change to `liquid_shell/lib/src/shell/liquid_shell.dart` (spec §8).
- Every visible string is a parameter. The only new library string is `LiquidShellStrings.dismiss = 'Dismiss'`.
- Provenance: no `vankhan`, `Văn Khấn`, VK/B ticket references in code, `LocaleKeys`, `easy_localization`, `go_router` (outside `*.md`), `AppColors`, or `GetIt` outside `docs/` (`make provenance`).
- Commits: `<type>(<scope>): <summary> (VK-406)`, scopes `shell glass platform ios android example docs ci`, then a blank line, then `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Run `bash .githooks/pre-commit` by hand before every commit. Stage by explicit path, never `git add -A`. Never `--no-verify`, never set `core.hooksPath`, never change git or flutter config. No push, no PR without the owner.
- Simulators only. Create your own (`xcrun simctl create`) and delete them afterwards. Never touch a physical device (in particular the Android phone QV7029CU1E). An Android **emulator** (`emulator-*`) is allowed. Keep ≥ 10 GB disk free, and delete `build/` output you created.
- `rm` is aliased in this environment: use `command rm`.
- Worktree: `/Users/invoker/Projects/tuvi/liquid_shell-vk406`, branch `VK-406-native-alerts` (based on P2 at `5e0a1e9`). Never touch `liquid_shell-vk346` or `liquid_shell-vk348`.
- Version: all four packages become `0.1.0-dev.3` (Task 8, Q10).
- Plane: each `### Task N` is one sub-issue of VK-406 (CLAUDE.md ⑤).

---

## Decision hooks (where each owner answer lands in this plan)

| Q | Default built here | If the owner answers otherwise |
|---|---|---|
| Q1 split P3a-2 | Share, haptics, date picker and alert text fields are NOT in this plan | Write a P3a-2 plan; nothing here changes |
| Q2 `system` | `LiquidDialogPresentation.system` exists | Drop the enum value (Task 5 Step 3), `requireGlass` is always true |
| Q3 no plist key | `DialogMath.unavailableReason` has no plist fact | Add a fact `enabledInInfoPlist` before `osTooOld` (Task 3) and a reason `notEnabled` (Tasks 1–2) |
| Q4 tint | `alert.view.tintColor = primary` | Delete that line (Task 3) and its XCTest assertion |
| Q5 anchored card | Regular-width fallback sheet = anchored card | `GlassActionSheet` uses the compact layout at every width (Task 4) |
| Q6 Android back | Back dismisses (cancel value / null) | Wrap `GlassAlert` in `PopScope(canPop: false)` (Task 4) |
| Q7 keep P2 | No shell change | A shell change (out of this plan) |
| Q8 XCUITest | Task 7 adds `RunnerUITests` | Task 7 Steps 6–9 become an idb script |
| Q9 iOS 18 runtime | Task 8 Step 4 downloads it if ≥ 10 GB stay free | Skip Step 4; README says "unverified on iOS < 26" |
| Q10 version | `0.1.0-dev.3` | Change Task 8 Step 6 |
| Q11 dismissed → cancel | `dialogValue(actions, null)` returns the cancel value | `dialogValue` returns null for null (Task 5) |

---

## File map

| Path | Task | Responsibility |
|---|---|---|
| `liquid_shell_platform_interface/lib/src/native_dialog.dart` | 1 | Request, action, kind, style, reason, sealed result |
| `liquid_shell_platform_interface/lib/src/liquid_shell_platform.dart` | 1 | `supportsNativeDialogs`, `presentNativeDialog` with defaults |
| `liquid_shell_platform_interface/lib/liquid_shell_platform_interface.dart` | 1 | Export |
| `liquid_shell_ios/pigeons/native_shell.dart` | 2 | `NativeDialogHostApi` + messages |
| `liquid_shell_ios/lib/src/native_shell_api.g.dart`, `.../NativeShellApi.g.swift` | 2 | Regenerated (`make pigeon`) |
| `liquid_shell_ios/lib/src/mapping.dart`, `lib/src/platform.dart`, `lib/liquid_shell_ios.dart` | 2 | Boundary mapping, `presentNativeDialog`, debug hooks |
| `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/DialogMath.swift` | 3 | Pure rules + `DialogCompletion` |
| `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeDialogPresenter.swift` | 3 | UIKit presenter + lifetime sentinel |
| `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/LiquidShellPlugin.swift` | 3 | Wiring, detach |
| `liquid_shell/example/ios/RunnerTests/RunnerTests.swift` | 3 | XCTest of math and presenter, appended (one file: no `pbxproj` edit) |
| `liquid_shell/lib/src/dialogs/dialog_metrics.dart` | 4 | Measured constants |
| `liquid_shell/lib/src/dialogs/dialog_layout.dart` | 4 | Pure layout rules |
| `liquid_shell/lib/src/dialogs/glass_dialogs.dart` | 4 | `showGlassDialog`, `GlassAlert`, `GlassActionSheet`, button, header |
| `liquid_shell/lib/src/shell/strings.dart` | 4 | `dismiss` |
| `docs/qa/p3a/metrics.md` | 4 | Native measurements |
| `liquid_shell/lib/src/dialogs/dialog_types.dart` | 5 | `LiquidAlertAction`, `LiquidAlertActionStyle`, `LiquidDialogPresentation` |
| `liquid_shell/lib/src/dialogs/dialog_plan.dart` | 5 | Validation, request building, value mapping, anchor, refusal memory |
| `liquid_shell/lib/src/dialogs/show_dialogs.dart` | 5 | `showLiquidAlert`, `showLiquidActionSheet` |
| `liquid_shell/lib/src/native/native_reset.dart`, `lib/liquid_shell.dart` | 5 | Reset memory, exports |
| `liquid_shell/test/helpers/fake_native_platform.dart` | 5 | Dialog fakes |
| `liquid_shell/example/lib/cases/native_alerts.dart`, `discard_guard.dart`, `native_chrome.dart`, `cases.dart`, `lib/main.dart` | 6 | Example |
| `liquid_shell/example/test/**`, `liquid_shell/README.md`, `liquid_shell/doc/images/*` | 6 | Smoke tests, goldens, README |
| `liquid_shell/example/integration_test/native_dialogs_test.dart`, `native_shell_test.dart` | 7 | Simulator integration |
| `liquid_shell/example/ios/RunnerUITests/RunnerUITests.swift`, `Runner.xcodeproj/**` | 7 | XCUITest real taps |
| `tool/integration_ios_native.sh`, `Makefile`, `.github/workflows/ci.yaml` | 7 | Scripts, `make ios-ui`, CI |
| `liquid_shell/doc/native_dialogs.md`, CHANGELOGs, pubspecs, podspec, `CLAUDE.md`, `CONTRIBUTING.md`, `docs/qa/p3a/*` | 8 | Docs, versions, QA, verification |

Tasks: **1** interface types · **2** Pigeon + `LiquidShellIOS` · **3** Swift presenter + XCTest · **4** Flutter glass fallback (with the metrics measurement) · **5** public API + orchestration · **6** example, goldens, README · **7** simulator integration + XCUITest + CI · **8** docs, versions, QA, verification.

Dependencies: 2 needs 1 · 3 needs 2 · 5 needs 1 and 4 · 6 needs 5 · 7 needs 3 and 6 · 8 needs all. Tasks 3 and 4 can run in parallel after 2.

Set up once (the controller, before Task 1):

```bash
cd /Users/invoker/Projects/tuvi/liquid_shell-vk406
make get
IPAD_UDID=$(xcrun simctl create "vk406 iPad" com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M4 com.apple.CoreSimulator.SimRuntime.iOS-26-5)
IPHONE_UDID=$(xcrun simctl create "vk406 iPhone" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-26-5)
echo "IPAD_UDID=$IPAD_UDID IPHONE_UDID=$IPHONE_UDID"   # export both in every later shell
xcrun simctl boot "$IPAD_UDID" && xcrun simctl bootstatus "$IPAD_UDID" -b
```

Cleanup at the very end: `xcrun simctl delete "$IPAD_UDID" "$IPHONE_UDID"`.

---

### Task 1: Platform interface — native dialog types

**Files:**
- Create: `liquid_shell_platform_interface/lib/src/native_dialog.dart`
- Modify: `liquid_shell_platform_interface/lib/src/liquid_shell_platform.dart` (two members after `nativeEvents`)
- Modify: `liquid_shell_platform_interface/lib/liquid_shell_platform_interface.dart` (export)
- Test: `liquid_shell_platform_interface/test/native_dialog_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces (exact names used by Tasks 2, 4, 5):
  - `enum LiquidNativeDialogKind { alert, actionSheet }`
  - `enum LiquidNativeDialogActionStyle { standard, cancel, destructive }`
  - `class LiquidNativeDialogAction { const ({required String label, LiquidNativeDialogActionStyle style = standard, bool enabled = true}) }`
  - `class LiquidNativeDialogRequest { const ({required LiquidNativeDialogKind kind, required List<LiquidNativeDialogAction> actions, required int tintArgb, required bool dark, required bool rtl, required bool requireGlass, String? title, String? message, int? preferredIndex, Rect? anchor}) }`
  - `enum LiquidNativeDialogUnavailableReason { unsupportedPlatform, osTooOld, noWindow, refused, disabledByEnvironment, channelError }`
  - `sealed class LiquidNativeDialogResult` with `LiquidNativeDialogChose(int index)`, `LiquidNativeDialogDismissed()`, `LiquidNativeDialogUnavailable(LiquidNativeDialogUnavailableReason reason)`
  - `LiquidShellPlatform.supportsNativeDialogs` (bool, default false), `LiquidShellPlatform.presentNativeDialog(LiquidNativeDialogRequest) → Future<LiquidNativeDialogResult>` (default `unavailable(unsupportedPlatform)`).

- [ ] **Step 1: Write the failing test**

`liquid_shell_platform_interface/test/native_dialog_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// The interface's defaults, with no platform behind them.
class _Bare extends LiquidShellPlatform {
  @override
  Stream<LiquidPlatformSignals> watchSignals() => const Stream.empty();
}

const _actions = [
  LiquidNativeDialogAction(
    label: 'Delete',
    style: LiquidNativeDialogActionStyle.destructive,
  ),
  LiquidNativeDialogAction(
    label: 'Cancel',
    style: LiquidNativeDialogActionStyle.cancel,
  ),
];

const _request = LiquidNativeDialogRequest(
  kind: LiquidNativeDialogKind.actionSheet,
  title: 'Delete?',
  message: 'It cannot be undone.',
  actions: _actions,
  preferredIndex: 0,
  anchor: Rect.fromLTWH(10, 20, 30, 40),
  tintArgb: 0xFF3D5AFE,
  dark: true,
  rtl: false,
  requireGlass: true,
);

LiquidNativeDialogRequest _with({
  LiquidNativeDialogKind kind = LiquidNativeDialogKind.actionSheet,
  String? title = 'Delete?',
  String? message = 'It cannot be undone.',
  List<LiquidNativeDialogAction> actions = _actions,
  int? preferredIndex = 0,
  Rect? anchor = const Rect.fromLTWH(10, 20, 30, 40),
  int tintArgb = 0xFF3D5AFE,
  bool dark = true,
  bool rtl = false,
  bool requireGlass = true,
}) => LiquidNativeDialogRequest(
  kind: kind,
  title: title,
  message: message,
  actions: actions,
  preferredIndex: preferredIndex,
  anchor: anchor,
  tintArgb: tintArgb,
  dark: dark,
  rtl: rtl,
  requireGlass: requireGlass,
);

void main() {
  group('LiquidNativeDialogAction', () {
    test('defaults to a standard, enabled action', () {
      const action = LiquidNativeDialogAction(label: 'OK');
      expect(action.style, LiquidNativeDialogActionStyle.standard);
      expect(action.enabled, isTrue);
    });

    test('== and hashCode compare every field', () {
      const a = LiquidNativeDialogAction(label: 'OK');
      expect(a, const LiquidNativeDialogAction(label: 'OK'));
      expect(a.hashCode, const LiquidNativeDialogAction(label: 'OK').hashCode);
      expect(a, isNot(const LiquidNativeDialogAction(label: 'No')));
      expect(
        a,
        isNot(
          const LiquidNativeDialogAction(
            label: 'OK',
            style: LiquidNativeDialogActionStyle.cancel,
          ),
        ),
      );
      expect(
        a,
        isNot(const LiquidNativeDialogAction(label: 'OK', enabled: false)),
      );
    });
  });

  group('LiquidNativeDialogRequest', () {
    test('== compares every field, the actions by value', () {
      expect(_with(), _request);
      expect(_with().hashCode, _request.hashCode);
      expect(_with(actions: List.of(_actions)), _request);
      for (final other in [
        _with(kind: LiquidNativeDialogKind.alert),
        _with(title: 'Other'),
        _with(message: null),
        _with(actions: const [LiquidNativeDialogAction(label: 'OK')]),
        _with(preferredIndex: 1),
        _with(anchor: const Rect.fromLTWH(0, 0, 1, 1)),
        _with(tintArgb: 0),
        _with(dark: false),
        _with(rtl: true),
        _with(requireGlass: false),
      ]) {
        expect(other, isNot(_request));
      }
    });
  });

  group('LiquidNativeDialogResult', () {
    test('results compare by value', () {
      expect(const LiquidNativeDialogChose(1), const LiquidNativeDialogChose(1));
      expect(
        const LiquidNativeDialogChose(1),
        isNot(const LiquidNativeDialogChose(2)),
      );
      expect(
        const LiquidNativeDialogDismissed(),
        const LiquidNativeDialogDismissed(),
      );
      expect(
        const LiquidNativeDialogUnavailable(
          LiquidNativeDialogUnavailableReason.osTooOld,
        ),
        const LiquidNativeDialogUnavailable(
          LiquidNativeDialogUnavailableReason.osTooOld,
        ),
      );
      expect(
        const LiquidNativeDialogUnavailable(
          LiquidNativeDialogUnavailableReason.osTooOld,
        ),
        isNot(
          const LiquidNativeDialogUnavailable(
            LiquidNativeDialogUnavailableReason.noWindow,
          ),
        ),
      );
    });

    test('a switch over the sealed result needs no default', () {
      String name(LiquidNativeDialogResult result) => switch (result) {
        LiquidNativeDialogChose(:final index) => 'chose $index',
        LiquidNativeDialogDismissed() => 'dismissed',
        LiquidNativeDialogUnavailable(:final reason) => reason.name,
      };
      expect(name(const LiquidNativeDialogChose(2)), 'chose 2');
      expect(name(const LiquidNativeDialogDismissed()), 'dismissed');
    });
  });

  test('the default platform has no native dialogs', () async {
    final platform = _Bare();
    expect(platform.supportsNativeDialogs, isFalse);
    expect(
      await platform.presentNativeDialog(_request),
      const LiquidNativeDialogUnavailable(
        LiquidNativeDialogUnavailableReason.unsupportedPlatform,
      ),
    );
  });
}
```

- [ ] **Step 2: Run the test to see it fail**

Run: `cd liquid_shell_platform_interface && fvm flutter test test/native_dialog_test.dart`
Expected: compile errors such as `Undefined name 'LiquidNativeDialogAction'` and `The method 'presentNativeDialog' isn't defined`.

- [ ] **Step 3: Write the types**

`liquid_shell_platform_interface/lib/src/native_dialog.dart`:

```dart
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

/// What a native dialog is.
enum LiquidNativeDialogKind {
  /// A centred alert.
  alert,

  /// An action sheet: from the bottom (or its source) on a phone, a popover
  /// at its anchor on a tablet.
  actionSheet,
}

/// How a native dialog action looks.
enum LiquidNativeDialogActionStyle {
  /// A plain action.
  standard,

  /// The cancel action. At most one per dialog: UIKit raises on a second.
  cancel,

  /// A destructive action, drawn in the error colour.
  destructive,
}

/// One button of a native dialog. Values never cross the channel: the
/// platform answers with the button's index.
@immutable
class LiquidNativeDialogAction {
  /// Creates an action.
  const LiquidNativeDialogAction({
    required this.label,
    this.style = LiquidNativeDialogActionStyle.standard,
    this.enabled = true,
  });

  /// The button's text, from the app.
  final String label;

  /// How it looks.
  final LiquidNativeDialogActionStyle style;

  /// Whether it can be chosen.
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      other is LiquidNativeDialogAction &&
      other.label == label &&
      other.style == style &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(label, style, enabled);

  @override
  String toString() =>
      'LiquidNativeDialogAction($label, ${style.name}, enabled: $enabled)';
}

/// A whole dialog, as the platform (or the Flutter fallback) draws it.
@immutable
class LiquidNativeDialogRequest {
  /// Creates a request.
  const LiquidNativeDialogRequest({
    required this.kind,
    required this.actions,
    required this.tintArgb,
    required this.dark,
    required this.rtl,
    required this.requireGlass,
    this.title,
    this.message,
    this.preferredIndex,
    this.anchor,
  });

  /// Alert or action sheet.
  final LiquidNativeDialogKind kind;

  /// The title, or null.
  final String? title;

  /// The message under the title, or null.
  final String? message;

  /// The buttons, in the app's order.
  final List<LiquidNativeDialogAction> actions;

  /// The alert's preferred action (bold, Return key); null for none and
  /// always null for an action sheet.
  final int? preferredIndex;

  /// Where an action sheet points, in global logical coordinates (the
  /// Flutter view's points); null for the view's centre.
  final Rect? anchor;

  /// The app's accent colour, `Color.toARGB32()`.
  final int tintArgb;

  /// Whether the app's theme is dark.
  final bool dark;

  /// Whether the text direction is right-to-left.
  final bool rtl;

  /// Present natively only where the system dialog is Liquid Glass
  /// (iOS 26+); false presents it on every iOS.
  final bool requireGlass;

  @override
  bool operator ==(Object other) =>
      other is LiquidNativeDialogRequest &&
      other.kind == kind &&
      other.title == title &&
      other.message == message &&
      listEquals(other.actions, actions) &&
      other.preferredIndex == preferredIndex &&
      other.anchor == anchor &&
      other.tintArgb == tintArgb &&
      other.dark == dark &&
      other.rtl == rtl &&
      other.requireGlass == requireGlass;

  @override
  int get hashCode => Object.hash(
    kind,
    title,
    message,
    Object.hashAll(actions),
    preferredIndex,
    anchor,
    tintArgb,
    dark,
    rtl,
    requireGlass,
  );
}

/// Why a native dialog was not shown.
enum LiquidNativeDialogUnavailableReason {
  /// The platform has no native dialogs (Android, web, desktop, tests).
  unsupportedPlatform,

  /// iOS before 26 and the request requires glass.
  osTooOld,

  /// The engine's view is not in a window (headless, add-to-app).
  noWindow,

  /// UIKit refused the presentation.
  refused,

  /// The diagnostic environment variable `LIQUID_SHELL_NATIVE_OFF=1`.
  disabledByEnvironment,

  /// A channel call failed.
  channelError,
}

/// How a native dialog ended.
sealed class LiquidNativeDialogResult {
  const LiquidNativeDialogResult();
}

/// The user chose the action at [index].
final class LiquidNativeDialogChose extends LiquidNativeDialogResult {
  /// Creates the result.
  const LiquidNativeDialogChose(this.index);

  /// Index into the request's actions.
  final int index;

  @override
  bool operator ==(Object other) =>
      other is LiquidNativeDialogChose && other.index == index;

  @override
  int get hashCode => index.hashCode;

  @override
  String toString() => 'LiquidNativeDialogChose($index)';
}

/// The dialog closed without a choice (a tap outside a popover, a dismissal
/// by the system).
final class LiquidNativeDialogDismissed extends LiquidNativeDialogResult {
  /// Creates the result.
  const LiquidNativeDialogDismissed();

  @override
  bool operator ==(Object other) => other is LiquidNativeDialogDismissed;

  @override
  int get hashCode => (LiquidNativeDialogDismissed).hashCode;

  @override
  String toString() => 'LiquidNativeDialogDismissed()';
}

/// The dialog was not shown; the caller draws its own.
final class LiquidNativeDialogUnavailable extends LiquidNativeDialogResult {
  /// Creates the result.
  const LiquidNativeDialogUnavailable(this.reason);

  /// Why.
  final LiquidNativeDialogUnavailableReason reason;

  @override
  bool operator ==(Object other) =>
      other is LiquidNativeDialogUnavailable && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'LiquidNativeDialogUnavailable(${reason.name})';
}
```

In `liquid_shell_platform.dart`, add the import `import 'package:liquid_shell_platform_interface/src/native_dialog.dart';` and, after `nativeEvents`:

```dart
  /// Whether this platform may present native dialogs. Read synchronously,
  /// so a caller without them draws its own at once. Default: false.
  bool get supportsNativeDialogs => false;

  /// Presents [request] natively and completes when it closes, or at once
  /// with [LiquidNativeDialogUnavailable]. Default: unavailable
  /// ([LiquidNativeDialogUnavailableReason.unsupportedPlatform]).
  Future<LiquidNativeDialogResult> presentNativeDialog(
    LiquidNativeDialogRequest request,
  ) async => const LiquidNativeDialogUnavailable(
    LiquidNativeDialogUnavailableReason.unsupportedPlatform,
  );
```

In the barrel, add `export 'src/native_dialog.dart';` between `native_chrome.dart` and `platform_signals.dart`.

- [ ] **Step 4: Run the tests to see them pass**

Run: `cd liquid_shell_platform_interface && fvm flutter test`
Expected: `All tests passed!` (the new file and every existing interface test).

- [ ] **Step 5: Commit**

```bash
bash .githooks/pre-commit && \
git add liquid_shell_platform_interface/lib/src/native_dialog.dart \
  liquid_shell_platform_interface/lib/src/liquid_shell_platform.dart \
  liquid_shell_platform_interface/lib/liquid_shell_platform_interface.dart \
  liquid_shell_platform_interface/test/native_dialog_test.dart && \
git commit -m "feat(platform): native dialog request and result types (VK-406)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Pigeon channel and `LiquidShellIOS` (Dart)

**Files:**
- Modify: `liquid_shell_ios/pigeons/native_shell.dart` (append the dialog messages and host API)
- Regenerate: `liquid_shell_ios/lib/src/native_shell_api.g.dart`, `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeShellApi.g.swift` (`make pigeon`)
- Modify: `liquid_shell_ios/lib/src/mapping.dart`, `liquid_shell_ios/lib/src/platform.dart`, `liquid_shell_ios/lib/liquid_shell_ios.dart`
- Test: `liquid_shell_ios/test/native_dialogs_test.dart`

**Interfaces:**
- Consumes (Task 1): every `LiquidNativeDialog*` type, `LiquidShellPlatform.supportsNativeDialogs`, `presentNativeDialog`.
- Produces:
  - Pigeon (Dart and Swift): `NativeDialogKind { alert, actionSheet }`, `NativeDialogActionStyle { standard, cancel, destructive }`, `NativeDialogOutcome { chose, dismissed, unavailable }`, `NativeDialogUnavailableReason { osTooOld, noWindow, refused, disabledByEnvironment }`, `NativeDialogAction { label, style, enabled }`, `NativeRect { x, y, width, height }`, `NativeDialogRequest { kind, title?, message?, actions, preferredIndex?, anchor?, tintArgb, dark, rtl, requireGlass }`, `NativeDialogResult { outcome, actionIndex?, reason? }`, `NativeDialogSnapshot { kind, title?, message?, labels, preferredIndex?, sourceRect? }`, host API `NativeDialogHostApi { @async present(request) → NativeDialogResult; debugCurrent() → NativeDialogSnapshot?; debugRespond(int actionIndex) }`. In Swift (used by Task 3): `protocol NativeDialogHostApi { func present(request: NativeDialogRequest, completion: @escaping (Result<NativeDialogResult, Error>) -> Void); func debugCurrent() throws -> NativeDialogSnapshot?; func debugRespond(actionIndex: Int64) throws }` and `NativeDialogHostApiSetup.setUp(binaryMessenger:api:)`.
  - Dart: `dialogRequestToNative(LiquidNativeDialogRequest) → NativeDialogRequest`, `dialogResultFromNative(NativeDialogResult, {required int actionCount}) → LiquidNativeDialogResult` (mapping.dart).
  - `LiquidShellIOS.supportsNativeDialogs == true`, `presentNativeDialog`, `@visibleForTesting debugNativeDialog() → Future<NativeDialogDebugSnapshot?>`, `@visibleForTesting debugRespondToNativeDialog(int actionIndex) → Future<void>`.
  - `typedef NativeDialogDebugSnapshot = ({bool actionSheet, String? title, String? message, List<String> labels, int? preferredIndex, Rect? sourceRect})`, exported from `package:liquid_shell_ios/liquid_shell_ios.dart`.
  - `liquidShellIOSWithHost(NativeShellHostApi hostApi, {NativeDialogHostApi? dialogs})` (`@visibleForTesting`).

- [ ] **Step 1: Write the failing test**

`liquid_shell_ios/test/native_dialogs_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_ios/liquid_shell_ios.dart';
import 'package:liquid_shell_ios/src/mapping.dart';
import 'package:liquid_shell_ios/src/native_shell_api.g.dart';
import 'package:liquid_shell_ios/src/platform.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// Records Dart → native dialog calls; answers with [answer].
class _FakeDialogs extends NativeDialogHostApi {
  final requests = <NativeDialogRequest>[];
  final responses = <int>[];
  NativeDialogResult answer = NativeDialogResult(
    outcome: NativeDialogOutcome.chose,
    actionIndex: 1,
  );
  NativeDialogSnapshot? snapshot;
  PlatformException? failure;

  @override
  Future<NativeDialogResult> present(NativeDialogRequest request) async {
    requests.add(request);
    final error = failure;
    if (error != null) throw error;
    return answer;
  }

  @override
  Future<NativeDialogSnapshot?> debugCurrent() async => snapshot;

  @override
  Future<void> debugRespond(int actionIndex) async =>
      responses.add(actionIndex);
}

const _sheet = LiquidNativeDialogRequest(
  kind: LiquidNativeDialogKind.actionSheet,
  title: 'Photo',
  message: 'Choose',
  actions: [
    LiquidNativeDialogAction(
      label: 'Delete',
      style: LiquidNativeDialogActionStyle.destructive,
    ),
    LiquidNativeDialogAction(label: 'Share', enabled: false),
    LiquidNativeDialogAction(
      label: 'Cancel',
      style: LiquidNativeDialogActionStyle.cancel,
    ),
  ],
  anchor: Rect.fromLTWH(10, 20, 30, 40),
  tintArgb: 0xFF3D5AFE,
  dark: true,
  rtl: true,
  requireGlass: false,
);

const _alert = LiquidNativeDialogRequest(
  kind: LiquidNativeDialogKind.alert,
  title: 'Discard changes?',
  actions: [
    LiquidNativeDialogAction(
      label: 'Keep editing',
      style: LiquidNativeDialogActionStyle.cancel,
    ),
    LiquidNativeDialogAction(label: 'Discard'),
  ],
  preferredIndex: 1,
  tintArgb: 0xFF000000,
  dark: false,
  rtl: false,
  requireGlass: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeDialogs dialogs;
  late LiquidShellIOS ios;
  setUp(() {
    dialogs = _FakeDialogs();
    ios = liquidShellIOSWithHost(NativeShellHostApi(), dialogs: dialogs);
  });

  test('iOS offers native dialogs', () {
    expect(ios.supportsNativeDialogs, isTrue);
  });

  test('an action sheet request carries every field', () async {
    await ios.presentNativeDialog(_sheet);
    final sent = dialogs.requests.single;
    expect(sent.kind, NativeDialogKind.actionSheet);
    expect(sent.title, 'Photo');
    expect(sent.message, 'Choose');
    expect([for (final a in sent.actions) a.label], [
      'Delete',
      'Share',
      'Cancel',
    ]);
    expect([for (final a in sent.actions) a.style], [
      NativeDialogActionStyle.destructive,
      NativeDialogActionStyle.standard,
      NativeDialogActionStyle.cancel,
    ]);
    expect([for (final a in sent.actions) a.enabled], [true, false, true]);
    expect(sent.preferredIndex, isNull);
    expect(
      [sent.anchor!.x, sent.anchor!.y, sent.anchor!.width, sent.anchor!.height],
      [10, 20, 30, 40],
    );
    expect(sent.tintArgb, 0xFF3D5AFE);
    expect(sent.dark, isTrue);
    expect(sent.rtl, isTrue);
    expect(sent.requireGlass, isFalse);
  });

  test('an alert request carries its preferred action and no anchor', () async {
    await ios.presentNativeDialog(_alert);
    final sent = dialogs.requests.single;
    expect(sent.kind, NativeDialogKind.alert);
    expect(sent.message, isNull);
    expect(sent.preferredIndex, 1);
    expect(sent.anchor, isNull);
    expect(sent.requireGlass, isTrue);
  });

  test('a non-finite anchor is not sent', () {
    const nan = LiquidNativeDialogRequest(
      kind: LiquidNativeDialogKind.actionSheet,
      actions: [LiquidNativeDialogAction(label: 'OK')],
      anchor: Rect.fromLTWH(double.nan, 0, 1, 1),
      tintArgb: 0,
      dark: false,
      rtl: false,
      requireGlass: true,
    );
    expect(dialogRequestToNative(nan).anchor, isNull);
  });

  group('results', () {
    Future<LiquidNativeDialogResult> answer(NativeDialogResult result) {
      dialogs.answer = result;
      return ios.presentNativeDialog(_alert);
    }

    test('a chosen index in range', () async {
      expect(
        await answer(
          NativeDialogResult(outcome: NativeDialogOutcome.chose, actionIndex: 0),
        ),
        const LiquidNativeDialogChose(0),
      );
    });

    test('a chosen index out of range is dismissed', () async {
      for (final index in [-1, 2, null]) {
        expect(
          await answer(
            NativeDialogResult(
              outcome: NativeDialogOutcome.chose,
              actionIndex: index,
            ),
          ),
          const LiquidNativeDialogDismissed(),
        );
      }
    });

    test('dismissed', () async {
      expect(
        await answer(NativeDialogResult(outcome: NativeDialogOutcome.dismissed)),
        const LiquidNativeDialogDismissed(),
      );
    });

    test('every unavailable reason maps; a missing one is a channel error', () async {
      const expected = {
        NativeDialogUnavailableReason.osTooOld:
            LiquidNativeDialogUnavailableReason.osTooOld,
        NativeDialogUnavailableReason.noWindow:
            LiquidNativeDialogUnavailableReason.noWindow,
        NativeDialogUnavailableReason.refused:
            LiquidNativeDialogUnavailableReason.refused,
        NativeDialogUnavailableReason.disabledByEnvironment:
            LiquidNativeDialogUnavailableReason.disabledByEnvironment,
      };
      for (final MapEntry(:key, :value) in expected.entries) {
        expect(
          await answer(
            NativeDialogResult(
              outcome: NativeDialogOutcome.unavailable,
              reason: key,
            ),
          ),
          LiquidNativeDialogUnavailable(value),
        );
      }
      expect(
        await answer(NativeDialogResult(outcome: NativeDialogOutcome.unavailable)),
        const LiquidNativeDialogUnavailable(
          LiquidNativeDialogUnavailableReason.channelError,
        ),
      );
    });
  });

  test('a channel failure is unavailable, logged once', () async {
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = original);
    dialogs.failure = PlatformException(code: 'boom');
    for (var i = 0; i < 2; i++) {
      expect(
        await ios.presentNativeDialog(_alert),
        const LiquidNativeDialogUnavailable(
          LiquidNativeDialogUnavailableReason.channelError,
        ),
      );
    }
    expect(logs.where((l) => l.contains('presentDialog')), hasLength(1));
  });

  test('debug hooks read the snapshot and respond', () async {
    expect(await ios.debugNativeDialog(), isNull);
    dialogs.snapshot = NativeDialogSnapshot(
      kind: NativeDialogKind.actionSheet,
      title: 'Photo',
      labels: ['Delete', 'Cancel'],
      sourceRect: NativeRect(x: 1, y: 2, width: 3, height: 4),
    );
    final shot = (await ios.debugNativeDialog())!;
    expect(shot.actionSheet, isTrue);
    expect(shot.title, 'Photo');
    expect(shot.message, isNull);
    expect(shot.labels, ['Delete', 'Cancel']);
    expect(shot.preferredIndex, isNull);
    expect(shot.sourceRect, const Rect.fromLTWH(1, 2, 3, 4));
    await ios.debugRespondToNativeDialog(-1);
    expect(dialogs.responses, [-1]);
  });

  test('present travels on the generated channel', () async {
    const name =
        'dev.flutter.pigeon.liquid_shell_ios.NativeDialogHostApi.present';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    Object? received;
    messenger.setMockMessageHandler(name, (message) async {
      received = NativeDialogHostApi.pigeonChannelCodec.decodeMessage(message);
      return NativeDialogHostApi.pigeonChannelCodec.encodeMessage(<Object?>[
        NativeDialogResult(outcome: NativeDialogOutcome.chose, actionIndex: 0),
      ]);
    });
    addTearDown(() => messenger.setMockMessageHandler(name, null));
    expect(
      await LiquidShellIOS().presentNativeDialog(_alert),
      const LiquidNativeDialogChose(0),
    );
    expect((received! as List<Object?>).single, isA<NativeDialogRequest>());
  });
}
```

- [ ] **Step 2: Run the test to see it fail**

Run: `cd liquid_shell_ios && fvm flutter test test/native_dialogs_test.dart`
Expected: compile errors, `Undefined class 'NativeDialogHostApi'` and `The named parameter 'dialogs' isn't defined`.

- [ ] **Step 3: Add the messages to the Pigeon source and regenerate**

Append to `liquid_shell_ios/pigeons/native_shell.dart`:

```dart
// --- Native dialogs (spec P3a §6) ------------------------------------------

/// What a native dialog is.
enum NativeDialogKind { alert, actionSheet }

/// How an action looks (`UIAlertAction.Style`).
enum NativeDialogActionStyle { standard, cancel, destructive }

/// How a dialog ended.
enum NativeDialogOutcome { chose, dismissed, unavailable }

/// Why a dialog was not shown (spec P3a §5.2).
enum NativeDialogUnavailableReason {
  osTooOld,
  noWindow,
  refused,
  disabledByEnvironment,
}

class NativeDialogAction {
  NativeDialogAction({
    required this.label,
    required this.style,
    required this.enabled,
  });

  String label;
  NativeDialogActionStyle style;
  bool enabled;
}

/// A rect in the Flutter view's points.
class NativeRect {
  NativeRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  double x;
  double y;
  double width;
  double height;
}

class NativeDialogRequest {
  NativeDialogRequest({
    required this.kind,
    required this.actions,
    required this.tintArgb,
    required this.dark,
    required this.rtl,
    required this.requireGlass,
    this.title,
    this.message,
    this.preferredIndex,
    this.anchor,
  });

  NativeDialogKind kind;
  String? title;
  String? message;
  List<NativeDialogAction> actions;
  int? preferredIndex;
  NativeRect? anchor;
  int tintArgb;
  bool dark;
  bool rtl;
  bool requireGlass;
}

class NativeDialogResult {
  NativeDialogResult({required this.outcome, this.actionIndex, this.reason});

  NativeDialogOutcome outcome;
  int? actionIndex;
  NativeDialogUnavailableReason? reason;
}

/// Test-only: the dialog on screen.
class NativeDialogSnapshot {
  NativeDialogSnapshot({
    required this.kind,
    required this.labels,
    this.title,
    this.message,
    this.preferredIndex,
    this.sourceRect,
  });

  NativeDialogKind kind;
  String? title;
  String? message;
  List<String> labels;
  int? preferredIndex;
  NativeRect? sourceRect;
}

/// Dart → native dialogs.
@HostApi()
abstract class NativeDialogHostApi {
  /// Presents [request]; answers when it closes, or at once when it
  /// cannot be shown.
  @async
  NativeDialogResult present(NativeDialogRequest request);

  /// Debug builds only: the dialog this engine shows, or null.
  NativeDialogSnapshot? debugCurrent();

  /// Debug builds only: closes the dialog this engine shows as if
  /// [actionIndex] were tapped; -1 dismisses it without a choice.
  void debugRespond(int actionIndex);
}
```

Run: `make pigeon`
Expected: both generated files change; `git status --short` lists `native_shell_api.g.dart` and `NativeShellApi.g.swift`, and still exactly one `final class PigeonError` in the Swift file (`grep -c "final class PigeonError" liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeShellApi.g.swift` → `1`).

- [ ] **Step 4: Map at the boundary**

Append to `liquid_shell_ios/lib/src/mapping.dart` (it already imports both type sets; add `import 'dart:ui' show Rect;`):

```dart
/// Interface dialog request → native request. A non-finite anchor is not
/// sent (spec P3a §6).
NativeDialogRequest dialogRequestToNative(LiquidNativeDialogRequest request) =>
    NativeDialogRequest(
      kind: switch (request.kind) {
        LiquidNativeDialogKind.alert => NativeDialogKind.alert,
        LiquidNativeDialogKind.actionSheet => NativeDialogKind.actionSheet,
      },
      title: request.title,
      message: request.message,
      actions: [
        for (final action in request.actions)
          NativeDialogAction(
            label: action.label,
            style: switch (action.style) {
              LiquidNativeDialogActionStyle.standard =>
                NativeDialogActionStyle.standard,
              LiquidNativeDialogActionStyle.cancel =>
                NativeDialogActionStyle.cancel,
              LiquidNativeDialogActionStyle.destructive =>
                NativeDialogActionStyle.destructive,
            },
            enabled: action.enabled,
          ),
      ],
      preferredIndex: request.preferredIndex,
      anchor: switch (request.anchor) {
        final Rect rect? when rect.isFinite => NativeRect(
          x: rect.left,
          y: rect.top,
          width: rect.width,
          height: rect.height,
        ),
        _ => null,
      },
      tintArgb: request.tintArgb,
      dark: request.dark,
      rtl: request.rtl,
      requireGlass: request.requireGlass,
    );

/// Native result → interface result, checked at the boundary: an index
/// outside the request's [actionCount] actions is a dismissal, and an
/// unavailable answer without a reason is a channel error.
LiquidNativeDialogResult dialogResultFromNative(
  NativeDialogResult result, {
  required int actionCount,
}) => switch (result.outcome) {
  NativeDialogOutcome.chose => switch (result.actionIndex) {
    final int index? when index >= 0 && index < actionCount =>
      LiquidNativeDialogChose(index),
    _ => const LiquidNativeDialogDismissed(),
  },
  NativeDialogOutcome.dismissed => const LiquidNativeDialogDismissed(),
  NativeDialogOutcome.unavailable => LiquidNativeDialogUnavailable(
    switch (result.reason) {
      NativeDialogUnavailableReason.osTooOld =>
        LiquidNativeDialogUnavailableReason.osTooOld,
      NativeDialogUnavailableReason.noWindow =>
        LiquidNativeDialogUnavailableReason.noWindow,
      NativeDialogUnavailableReason.refused =>
        LiquidNativeDialogUnavailableReason.refused,
      NativeDialogUnavailableReason.disabledByEnvironment =>
        LiquidNativeDialogUnavailableReason.disabledByEnvironment,
      null => LiquidNativeDialogUnavailableReason.channelError,
    },
  ),
};
```

- [ ] **Step 5: Implement the platform members**

In `liquid_shell_ios/lib/src/platform.dart` (add `import 'dart:ui' show Rect;`):

Replace the test factory and the constructors:

```dart
/// A [LiquidShellIOS] that talks to [hostApi] (and [dialogs]) instead of
/// the real channel.
@visibleForTesting
LiquidShellIOS liquidShellIOSWithHost(
  NativeShellHostApi hostApi, {
  NativeDialogHostApi? dialogs,
}) => LiquidShellIOS._(hostApi, dialogs ?? NativeDialogHostApi());

/// The dialog a debug build of the plugin shows (spec P3a §5.5).
typedef NativeDialogDebugSnapshot = ({
  bool actionSheet,
  String? title,
  String? message,
  List<String> labels,
  int? preferredIndex,
  Rect? sourceRect,
});
```

```dart
  LiquidShellIOS() : this._(NativeShellHostApi(), NativeDialogHostApi());

  LiquidShellIOS._(this._host, this._dialogs);
```

and the field `final NativeDialogHostApi _dialogs;` next to `_host`. Then add these members after `readWindowControls`:

```dart
  @override
  bool get supportsNativeDialogs => true;

  @override
  Future<LiquidNativeDialogResult> presentNativeDialog(
    LiquidNativeDialogRequest request,
  ) async {
    try {
      return dialogResultFromNative(
        await _dialogs.present(dialogRequestToNative(request)),
        actionCount: request.actions.length,
      );
    } on PlatformException catch (error) {
      _logOnce('presentDialog', error);
      return const LiquidNativeDialogUnavailable(
        LiquidNativeDialogUnavailableReason.channelError,
      );
    }
  }

  /// Debug builds of the plugin: the dialog this engine shows, or null.
  /// For integration tests; a channel failure reads as null.
  @visibleForTesting
  Future<NativeDialogDebugSnapshot?> debugNativeDialog() async {
    try {
      final shot = await _dialogs.debugCurrent();
      if (shot == null) return null;
      final rect = shot.sourceRect;
      return (
        actionSheet: shot.kind == NativeDialogKind.actionSheet,
        title: shot.title,
        message: shot.message,
        labels: shot.labels,
        preferredIndex: shot.preferredIndex,
        sourceRect: rect == null
            ? null
            : Rect.fromLTWH(rect.x, rect.y, rect.width, rect.height),
      );
    } on PlatformException catch (error) {
      _logOnce('debugDialog', error);
      return null;
    }
  }

  /// Debug builds of the plugin: closes the dialog as if [actionIndex] were
  /// tapped; -1 dismisses it without a choice. For integration tests.
  @visibleForTesting
  Future<void> debugRespondToNativeDialog(int actionIndex) =>
      _send('debugRespond', () => _dialogs.debugRespond(actionIndex));
```

In `liquid_shell_ios/lib/liquid_shell_ios.dart`:

```dart
export 'src/native_shell_api.g.dart' show NativeTapTarget;
export 'src/platform.dart' show LiquidShellIOS, NativeDialogDebugSnapshot;
```

The existing `liquid_shell_ios_test.dart` calls `liquidShellIOSWithHost(host)` positionally, which still compiles.

- [ ] **Step 6: Run the tests to see them pass**

Run: `cd liquid_shell_ios && fvm flutter test`
Expected: `All tests passed!` (the new file plus the P2 tests).
Run: `make pigeon-check`
Expected: `✓ pigeon output matches its source` (after `git add` of the generated files in Step 7; before staging it reports the untracked/modified generated files, which is expected).

- [ ] **Step 7: Commit**

```bash
bash .githooks/pre-commit && \
git add liquid_shell_ios/pigeons/native_shell.dart \
  liquid_shell_ios/lib/src/native_shell_api.g.dart \
  liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeShellApi.g.swift \
  liquid_shell_ios/lib/src/mapping.dart liquid_shell_ios/lib/src/platform.dart \
  liquid_shell_ios/lib/liquid_shell_ios.dart \
  liquid_shell_ios/test/native_dialogs_test.dart && \
git commit -m "feat(ios): native dialog channel and LiquidShellIOS mapping (VK-406)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" && \
make pigeon-check
```

The Swift side has the new protocol but no implementation yet. That still compiles, because the setup is not called until Task 3.

---

### Task 3: Swift presenter and XCTest

**Files:**
- Create: `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/DialogMath.swift`
- Create: `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeDialogPresenter.swift`
- Modify: `liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/LiquidShellPlugin.swift`
- Test: `liquid_shell/example/ios/RunnerTests/RunnerTests.swift` (append; the target has one file, so no `pbxproj` edit)

CocoaPods picks up new sources through the podspec's `Sources/liquid_shell_ios/**/*.swift` glob on the next `pod install` (`make ios-unit` runs `flutter build ios --config-only`, which runs it). SwiftPM's target takes the whole directory.

**Interfaces:**
- Consumes (Task 2): the generated `NativeDialogHostApi` protocol, `NativeDialogHostApiSetup`, the `NativeDialog*` structs and enums; `InstallPolicy.disableEnvironmentKey` and `UIColor(argb:)` (P2).
- Produces:
  - `enum DialogMath { static func unavailableReason(disabledByEnvironment:requireGlass:osAtLeast26:hasWindow:) -> NativeDialogUnavailableReason?; static func sourceRect(anchor: CGRect?, in: CGRect) -> CGRect?; static func preferredIndex(_: Int64?, count: Int) -> Int? }`
  - `final class DialogCompletion { init(_ body: @escaping (NativeDialogResult) -> Void); var isFinished: Bool; func finish(_ result: NativeDialogResult) }`
  - `extension NativeDialogResult { static func chose(_ index: Int); static func dismissed(); static func unavailable(_ reason:) }`
  - `final class NativeDialogPresenter: NSObject, NativeDialogHostApi { init(flutterViewController:osAtLeast26:disabledByEnvironment:); func dismissAll(); static func topmost(from:) -> UIViewController? }`

- [ ] **Step 1: Write the failing XCTests**

Append to `liquid_shell/example/ios/RunnerTests/RunnerTests.swift`:

```swift
// MARK: - Native dialogs (spec P3a §9.3)

final class DialogMathTests: XCTestCase {
  func testReasonsInOrder() {
    XCTAssertEqual(
      DialogMath.unavailableReason(
        disabledByEnvironment: true, requireGlass: true, osAtLeast26: false, hasWindow: false),
      .disabledByEnvironment)
    XCTAssertEqual(
      DialogMath.unavailableReason(
        disabledByEnvironment: false, requireGlass: true, osAtLeast26: false, hasWindow: false),
      .osTooOld)
    XCTAssertEqual(
      DialogMath.unavailableReason(
        disabledByEnvironment: false, requireGlass: false, osAtLeast26: false, hasWindow: false),
      .noWindow)
    XCTAssertNil(
      DialogMath.unavailableReason(
        disabledByEnvironment: false, requireGlass: false, osAtLeast26: false, hasWindow: true))
    XCTAssertNil(
      DialogMath.unavailableReason(
        disabledByEnvironment: false, requireGlass: true, osAtLeast26: true, hasWindow: true))
  }

  func testSourceRectIsTheAnchorClippedToTheView() {
    let bounds = CGRect(x: 0, y: 0, width: 400, height: 800)
    XCTAssertEqual(
      DialogMath.sourceRect(anchor: CGRect(x: 10, y: 20, width: 80, height: 44), in: bounds),
      CGRect(x: 10, y: 20, width: 80, height: 44))
    XCTAssertEqual(
      DialogMath.sourceRect(anchor: CGRect(x: 380, y: 780, width: 80, height: 44), in: bounds),
      CGRect(x: 380, y: 780, width: 20, height: 20))
    // A point still points: at least 1×1.
    XCTAssertEqual(
      DialogMath.sourceRect(anchor: CGRect(x: 50, y: 60, width: 0, height: 0), in: bounds),
      CGRect(x: 50, y: 60, width: 1, height: 1))
  }

  func testUnusableAnchorsAreNil() {
    let bounds = CGRect(x: 0, y: 0, width: 400, height: 800)
    XCTAssertNil(DialogMath.sourceRect(anchor: nil, in: bounds))
    XCTAssertNil(
      DialogMath.sourceRect(anchor: CGRect(x: 500, y: 900, width: 10, height: 10), in: bounds))
    XCTAssertNil(
      DialogMath.sourceRect(anchor: CGRect(x: .nan, y: 0, width: 10, height: 10), in: bounds))
    XCTAssertNil(
      DialogMath.sourceRect(
        anchor: CGRect(x: 0, y: 0, width: .infinity, height: 10), in: bounds))
  }

  func testPreferredIndexMustNameAnAction() {
    XCTAssertEqual(DialogMath.preferredIndex(1, count: 2), 1)
    XCTAssertNil(DialogMath.preferredIndex(2, count: 2))
    XCTAssertNil(DialogMath.preferredIndex(-1, count: 2))
    XCTAssertNil(DialogMath.preferredIndex(nil, count: 2))
  }

  func testACompletionAnswersOnce() {
    var answers: [NativeDialogResult] = []
    let done = DialogCompletion { answers.append($0) }
    XCTAssertFalse(done.isFinished)
    done.finish(.chose(1))
    done.finish(.dismissed())
    done.finish(.unavailable(.refused))
    XCTAssertTrue(done.isFinished)
    XCTAssertEqual(answers, [.chose(1)])
  }
}

/// The presenter in a real window of the test host. A plain view controller
/// stands in for the Flutter one: the presenter only reads its view and window.
final class NativeDialogPresenterTests: XCTestCase {
  private var windows: [UIWindow] = []
  private var root: UIViewController!

  final class Answers {
    var all: [NativeDialogResult] = []
  }

  /// A root that never presents: UIKit's refusal, made deterministic.
  final class RefusingController: UIViewController {
    override func present(
      _ viewControllerToPresent: UIViewController, animated flag: Bool,
      completion: (() -> Void)? = nil
    ) {}
  }

  override func setUpWithError() throws {
    root = try window().rootViewController
  }

  override func tearDown() {
    for window in windows {
      window.rootViewController?.presentedViewController?.dismiss(animated: false)
      window.isHidden = true
      window.rootViewController = nil
    }
    windows = []
    root = nil
    super.tearDown()
  }

  private func window(root: UIViewController = UIViewController()) throws -> UIWindow {
    let scene = try XCTUnwrap(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    window.frame = scene.coordinateSpace.bounds
    window.rootViewController = root
    window.makeKeyAndVisible()
    windows.append(window)
    return window
  }

  private func settle(_ seconds: TimeInterval = 0.8) {
    RunLoop.current.run(until: Date().addingTimeInterval(seconds))
  }

  private func presenter(
    os26: Bool = true, off: Bool = false, flutter: UIViewController? = nil
  ) -> NativeDialogPresenter {
    let fallback = root
    return NativeDialogPresenter(
      flutterViewController: { flutter ?? fallback }, osAtLeast26: { os26 },
      disabledByEnvironment: { off })
  }

  private func request(
    kind: NativeDialogKind = .alert, anchor: NativeRect? = nil, requireGlass: Bool = true
  ) -> NativeDialogRequest {
    NativeDialogRequest(
      kind: kind, title: "Discard changes?", message: "Your edits will be lost.",
      actions: [
        NativeDialogAction(label: "Keep editing", style: .cancel, enabled: true),
        NativeDialogAction(label: "Discard", style: .destructive, enabled: true),
        NativeDialogAction(label: "Later", style: .standard, enabled: false),
      ],
      preferredIndex: kind == .alert ? 1 : nil, anchor: anchor, tintArgb: 0xFF00_7AFF,
      dark: true, rtl: false, requireGlass: requireGlass)
  }

  private func present(
    _ presenter: NativeDialogPresenter, _ request: NativeDialogRequest
  ) -> Answers {
    let answers = Answers()
    presenter.present(request: request) { result in
      if case .success(let value) = result { answers.all.append(value) }
    }
    return answers
  }

  func testAnAlertCarriesEveryField() throws {
    let answers = present(presenter(), request())
    settle()
    let alert = try XCTUnwrap(root.presentedViewController as? UIAlertController)
    XCTAssertEqual(alert.preferredStyle, .alert)
    XCTAssertEqual(alert.title, "Discard changes?")
    XCTAssertEqual(alert.message, "Your edits will be lost.")
    XCTAssertEqual(alert.actions.map(\.title), ["Keep editing", "Discard", "Later"])
    XCTAssertEqual(alert.actions.map(\.style), [.cancel, .destructive, .default])
    XCTAssertEqual(alert.actions.map(\.isEnabled), [true, true, false])
    XCTAssertTrue(alert.preferredAction === alert.actions[1])
    XCTAssertEqual(alert.overrideUserInterfaceStyle, .dark)
    XCTAssertEqual(alert.view.tintColor, UIColor(argb: 0xFF00_7AFF))
    XCTAssertTrue(answers.all.isEmpty)
  }

  func testAnActionSheetPointsAtItsAnchorInTheFlutterView() throws {
    _ = present(
      presenter(),
      request(kind: .actionSheet, anchor: NativeRect(x: 100, y: 200, width: 80, height: 44)))
    settle()
    let alert = try XCTUnwrap(root.presentedViewController as? UIAlertController)
    XCTAssertEqual(alert.preferredStyle, .actionSheet)
    XCTAssertNil(alert.preferredAction)
    let popover = try XCTUnwrap(alert.popoverPresentationController)
    XCTAssertTrue(popover.sourceView === root.view)
    XCTAssertEqual(popover.sourceRect, CGRect(x: 100, y: 200, width: 80, height: 44))
  }

  func testAnActionSheetWithoutAnAnchorUsesTheCentreWithoutAnArrow() throws {
    _ = present(presenter(), request(kind: .actionSheet))
    settle()
    let alert = try XCTUnwrap(root.presentedViewController as? UIAlertController)
    let popover = try XCTUnwrap(alert.popoverPresentationController)
    XCTAssertEqual(popover.permittedArrowDirections, [])
    XCTAssertEqual(popover.sourceRect.midX, root.view.bounds.midX, accuracy: 0.5)
    XCTAssertEqual(popover.sourceRect.midY, root.view.bounds.midY, accuracy: 0.5)
  }

  func testUnavailableReasonsShowNothing() {
    let off = present(presenter(off: true), request())
    let old = present(presenter(os26: false), request())
    let hidden = present(presenter(flutter: UIViewController()), request())
    settle()
    XCTAssertEqual(off.all, [.unavailable(.disabledByEnvironment)])
    XCTAssertEqual(old.all, [.unavailable(.osTooOld)])
    XCTAssertEqual(hidden.all, [.unavailable(.noWindow)])
    XCTAssertNil(root.presentedViewController)
  }

  func testWithoutRequiringGlassAnOldOSPresents() throws {
    let answers = present(presenter(os26: false), request(requireGlass: false))
    settle()
    XCTAssertNotNil(root.presentedViewController as? UIAlertController)
    XCTAssertTrue(answers.all.isEmpty)
  }

  func testRespondAnswersOnceAndDismisses() throws {
    let dialogs = presenter()
    let answers = present(dialogs, request())
    settle()
    XCTAssertEqual(try dialogs.debugCurrent()?.labels, ["Keep editing", "Discard", "Later"])
    try dialogs.debugRespond(actionIndex: 1)
    settle()
    try dialogs.debugRespond(actionIndex: 0)
    settle()
    XCTAssertEqual(answers.all, [.chose(1)])
    XCTAssertNil(root.presentedViewController)
    XCTAssertNil(try dialogs.debugCurrent())
  }

  func testRespondMinusOneIsDismissed() throws {
    let dialogs = presenter()
    let answers = present(dialogs, request())
    settle()
    try dialogs.debugRespond(actionIndex: -1)
    settle()
    XCTAssertEqual(answers.all, [.dismissed()])
  }

  func testADismissalBySomeoneElseAnswersDismissedOnce() {
    let answers = present(presenter(), request())
    settle()
    root.dismiss(animated: false)
    let released = expectation(description: "answered")
    DispatchQueue.main.async {
      // The alert is released once UIKit lets go of it.
      self.settle(0.5)
      released.fulfill()
    }
    wait(for: [released], timeout: 3)
    XCTAssertEqual(answers.all, [.dismissed()])
  }

  func testASecondDialogWaitsForTheFirstToLeave() throws {
    let dialogs = presenter()
    _ = present(dialogs, request())
    settle()
    let first = try XCTUnwrap(root.presentedViewController as? UIAlertController)
    // As when an app answers the first alert with a second one: UIKit is
    // still dismissing the first when the second request arrives.
    first.dismiss(animated: true)
    let second = present(dialogs, request(kind: .actionSheet))
    settle(1.5)
    let shown = try XCTUnwrap(root.presentedViewController as? UIAlertController)
    XCTAssertEqual(shown.preferredStyle, .actionSheet)
    XCTAssertTrue(second.all.isEmpty)
  }

  func testARefusedPresentationIsUnavailableSoDartFallsBack() throws {
    let refusing = RefusingController()
    _ = try window(root: refusing)
    let answers = present(presenter(flutter: refusing), request())
    settle()
    XCTAssertEqual(answers.all, [.unavailable(.refused)])
  }

  func testEachEngineUsesItsOwnWindow() throws {
    let other = try window().rootViewController!
    _ = present(presenter(flutter: other), request())
    settle()
    XCTAssertNotNil(other.presentedViewController as? UIAlertController)
    XCTAssertNil(root.presentedViewController)
  }

  func testDismissAllAnswersDismissed() {
    let dialogs = presenter()
    let answers = present(dialogs, request())
    settle()
    dialogs.dismissAll()
    settle()
    XCTAssertEqual(answers.all, [.dismissed()])
    XCTAssertNil(root.presentedViewController)
  }

  func testTopmostOfAControllerPresentingNothingIsItself() {
    let base = UIViewController()
    XCTAssertTrue(NativeDialogPresenter.topmost(from: base) === base)
    XCTAssertNil(NativeDialogPresenter.topmost(from: nil))
  }
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `make ios-unit IOS_UNIT_DEVICE="$IPAD_UDID"`
Expected: build failure, `cannot find 'DialogMath' in scope` and `cannot find 'NativeDialogPresenter' in scope`.

- [ ] **Step 3: Write `DialogMath.swift`**

```swift
import CoreGraphics
import Foundation

/// The pure rules of native dialogs (spec P3a §5). There is no UIKit here,
/// so XCTest covers them without a window.
enum DialogMath {
  /// Why a dialog cannot be presented natively, or nil when it can. The
  /// facts are checked in this order (spec §5.2).
  static func unavailableReason(
    disabledByEnvironment: Bool, requireGlass: Bool, osAtLeast26: Bool, hasWindow: Bool
  ) -> NativeDialogUnavailableReason? {
    if disabledByEnvironment { return .disabledByEnvironment }
    if requireGlass && !osAtLeast26 { return .osTooOld }
    if !hasWindow { return .noWindow }
    return nil
  }

  /// The popover source rect for [anchor] in a view of [bounds]: the anchor
  /// clipped to the view, at least 1×1. Nil (the view's centre, no arrow)
  /// when there is no anchor, or it is not finite, has a negative size or
  /// lies outside the view.
  static func sourceRect(anchor: CGRect?, in bounds: CGRect) -> CGRect? {
    guard let anchor,
      anchor.origin.x.isFinite, anchor.origin.y.isFinite,
      anchor.size.width.isFinite, anchor.size.height.isFinite,
      anchor.size.width >= 0, anchor.size.height >= 0
    else { return nil }
    let clipped = anchor.intersection(bounds)
    if clipped.isNull { return nil }
    return CGRect(
      x: clipped.minX, y: clipped.minY,
      width: max(clipped.width, 1), height: max(clipped.height, 1))
  }

  /// [index] when it names one of [count] actions, else nil.
  static func preferredIndex(_ index: Int64?, count: Int) -> Int? {
    guard let index, index >= 0, index < Int64(count) else { return nil }
    return Int(index)
  }
}

/// Ends one Dart future exactly once (spec §5.4). Every later answer is
/// dropped.
final class DialogCompletion {
  private var body: ((NativeDialogResult) -> Void)?

  init(_ body: @escaping (NativeDialogResult) -> Void) {
    self.body = body
  }

  var isFinished: Bool { body == nil }

  func finish(_ result: NativeDialogResult) {
    guard let body else { return }
    self.body = nil
    body(result)
  }
}

extension NativeDialogResult {
  static func chose(_ index: Int) -> NativeDialogResult {
    NativeDialogResult(outcome: .chose, actionIndex: Int64(index))
  }

  static func dismissed() -> NativeDialogResult {
    NativeDialogResult(outcome: .dismissed)
  }

  static func unavailable(_ reason: NativeDialogUnavailableReason) -> NativeDialogResult {
    NativeDialogResult(outcome: .unavailable, reason: reason)
  }
}
```

- [ ] **Step 4: Write `NativeDialogPresenter.swift`**

```swift
import Flutter
import ObjectiveC
import UIKit

/// Presents native alerts and action sheets for one engine (spec P3a §5).
///
/// It presents in the window of this engine's own Flutter view controller,
/// from the top-most presented view controller, after any transition in
/// flight. Every request ends its Dart future exactly once.
final class NativeDialogPresenter: NSObject, NativeDialogHostApi {
  /// The engine's Flutter view controller, once known.
  private let flutterViewController: () -> UIViewController?
  private let osAtLeast26: () -> Bool
  private let disabledByEnvironment: () -> Bool
  /// The dialog this presenter shows (debug hooks, detach).
  private weak var current: UIAlertController?
  private var currentCompletion: DialogCompletion?
  private var currentKind: NativeDialogKind = .alert

  init(
    flutterViewController: @escaping () -> UIViewController?,
    osAtLeast26: @escaping () -> Bool = {
      if #available(iOS 26.0, *) { return true } else { return false }
    },
    disabledByEnvironment: @escaping () -> Bool = {
      ProcessInfo.processInfo.environment[InstallPolicy.disableEnvironmentKey] == "1"
    }
  ) {
    self.flutterViewController = flutterViewController
    self.osAtLeast26 = osAtLeast26
    self.disabledByEnvironment = disabledByEnvironment
  }

  /// The view controller to present from: follow `presentedViewController`
  /// from [root] while the next one is not leaving.
  static func topmost(from root: UIViewController?) -> UIViewController? {
    var top = root
    while let next = top?.presentedViewController, !next.isBeingDismissed { top = next }
    return top
  }

  // MARK: - NativeDialogHostApi

  func present(
    request: NativeDialogRequest,
    completion: @escaping (Result<NativeDialogResult, Error>) -> Void
  ) {
    let done = DialogCompletion { completion(.success($0)) }
    let flutter = flutterViewController()
    let window = flutter?.viewIfLoaded?.window
    if let reason = DialogMath.unavailableReason(
      disabledByEnvironment: disabledByEnvironment(), requireGlass: request.requireGlass,
      osAtLeast26: osAtLeast26(), hasWindow: window != nil)
    {
      done.finish(.unavailable(reason))
      return
    }
    guard let flutter, let window else { return }
    let alert = build(request, sourceView: flutter.view, done: done)
    show(alert, kind: request.kind, in: window, done: done, waits: 3)
  }

  func debugCurrent() throws -> NativeDialogSnapshot? {
    #if DEBUG
      guard let alert = current, currentCompletion?.isFinished == false else { return nil }
      let preferred = alert.preferredAction.flatMap { preferred in
        alert.actions.firstIndex { $0 === preferred }
      }
      let source = currentKind == .actionSheet ? alert.popoverPresentationController : nil
      return NativeDialogSnapshot(
        kind: currentKind, title: alert.title, message: alert.message,
        labels: alert.actions.map { $0.title ?? "" },
        preferredIndex: preferred.map(Int64.init),
        sourceRect: source.map {
          NativeRect(
            x: Double($0.sourceRect.minX), y: Double($0.sourceRect.minY),
            width: Double($0.sourceRect.width), height: Double($0.sourceRect.height))
        })
    #else
      return nil
    #endif
  }

  func debugRespond(actionIndex: Int64) throws {
    #if DEBUG
      guard let alert = current, let done = currentCompletion, !done.isFinished else { return }
      let count = alert.actions.count
      // Dismiss first, then answer: a chained dialog from Dart's answer
      // then meets no transition, as after a real tap.
      alert.dismiss(animated: false) {
        if actionIndex >= 0, actionIndex < Int64(count) {
          done.finish(.chose(Int(actionIndex)))
        } else {
          done.finish(.dismissed())
        }
      }
    #endif
  }

  /// Engine detach: nobody will receive an answer. Closes what is shown.
  func dismissAll() {
    current?.dismiss(animated: false)
    currentCompletion?.finish(.dismissed())
    current = nil
    currentCompletion = nil
  }

  // MARK: - Building and showing

  private func build(
    _ request: NativeDialogRequest, sourceView: UIView, done: DialogCompletion
  ) -> UIAlertController {
    let alert = UIAlertController(
      title: request.title, message: request.message,
      preferredStyle: request.kind == .alert ? .alert : .actionSheet)
    for (index, action) in request.actions.enumerated() {
      let item = UIAlertAction(title: action.label, style: Self.style(action.style)) { _ in
        done.finish(.chose(index))
      }
      item.isEnabled = action.enabled
      alert.addAction(item)
    }
    if request.kind == .alert,
      let preferred = DialogMath.preferredIndex(request.preferredIndex, count: alert.actions.count)
    {
      alert.preferredAction = alert.actions[preferred]
    }
    // Ends the future when the alert goes without an answer (spec §5.4).
    let lifetime = DialogLifetime(done)
    objc_setAssociatedObject(
      alert, &DialogLifetime.key, lifetime, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    if let popover = alert.popoverPresentationController {
      popover.sourceView = sourceView
      let anchor = request.anchor.map {
        CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height)
      }
      if let rect = DialogMath.sourceRect(anchor: anchor, in: sourceView.bounds) {
        popover.sourceRect = rect
      } else {
        let bounds = sourceView.bounds
        popover.sourceRect = CGRect(x: bounds.midX, y: bounds.midY, width: 0, height: 0)
        popover.permittedArrowDirections = []
      }
      popover.delegate = lifetime
    }
    alert.view.tintColor = UIColor(argb: request.tintArgb)
    alert.overrideUserInterfaceStyle = request.dark ? .dark : .light
    if request.rtl {
      if #available(iOS 17.0, *) {
        alert.traitOverrides.layoutDirection = .rightToLeft
      } else {
        alert.view.semanticContentAttribute = .forceRightToLeft
      }
    }
    return alert
  }

  /// Presents [alert] from the top of [window], after any presentation or
  /// dismissal in flight: UIKit refuses a present during one (spec §5.1).
  private func show(
    _ alert: UIAlertController, kind: NativeDialogKind, in window: UIWindow,
    done: DialogCompletion, waits: Int
  ) {
    guard let top = Self.topmost(from: window.rootViewController) else {
      done.finish(.unavailable(.noWindow))
      return
    }
    if waits > 0,
      let coordinator = top.presentedViewController?.transitionCoordinator
        ?? top.transitionCoordinator
    {
      coordinator.animate(alongsideTransition: nil) { [weak self, weak window] _ in
        guard let self, let window else {
          done.finish(.unavailable(.noWindow))
          return
        }
        self.show(alert, kind: kind, in: window, done: done, waits: waits - 1)
      }
      return
    }
    top.present(alert, animated: true)
    guard alert.presentingViewController != nil else {
      // Refused: Dart draws its own dialog instead.
      done.finish(.unavailable(.refused))
      return
    }
    current = alert
    currentCompletion = done
    currentKind = kind
  }

  private static func style(_ style: NativeDialogActionStyle) -> UIAlertAction.Style {
    switch style {
    case .standard: return .default
    case .cancel: return .cancel
    case .destructive: return .destructive
    }
  }
}

/// Attached to the alert (spec §5.4). It answers `dismissed` when a popover
/// is dismissed by a tap outside, and when the alert is released without
/// an answer (dismissed by someone else).
final class DialogLifetime: NSObject, UIPopoverPresentationControllerDelegate {
  static var key: UInt8 = 0
  private let done: DialogCompletion

  init(_ done: DialogCompletion) {
    self.done = done
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    done.finish(.dismissed())
  }

  deinit {
    done.finish(.dismissed())
  }
}
```

- [ ] **Step 5: Wire it into the plugin**

In `LiquidShellPlugin.swift`, add the property `private var dialogs: NativeDialogPresenter?` next to `installer`. In `register(with:)`, after `installer.start()`:

```swift
    let dialogs = NativeDialogPresenter(
      flutterViewController: { [weak registrar] in registrar?.viewController })
    NativeDialogHostApiSetup.setUp(binaryMessenger: messenger, api: dialogs)
    plugin.dialogs = dialogs
```

In `detachFromEngine(for:)`, before `removeObserver()`:

```swift
    dialogs?.dismissAll()
    NativeDialogHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
```

Update the class doc comment's bullet list with: `- Presents native alerts and action sheets (\`NativeDialogPresenter\`, spec P3a §5).`

- [ ] **Step 6: Run the XCTests to see them pass, on iPad and on iPhone**

Run: `make ios-unit IOS_UNIT_DEVICE="$IPAD_UDID"` and then `make ios-unit IOS_UNIT_DEVICE="$IPHONE_UDID"`
Expected: `** TEST SUCCEEDED **` on both. The P2 tests still pass. On the iPhone, `testAnActionSheetPointsAtItsAnchorInTheFlutterView` needs `popoverPresentationController` non-nil. UIKit creates it for action sheets on every idiom, so it passes. If it is nil there, change that test's `XCTUnwrap` into `try XCTSkipIf(alert.popoverPresentationController == nil)`. Record which happened in the commit body.

Mutation check (do it, then revert): delete the `coordinator.animate` wait in `show`. `testASecondDialogWaitsForTheFirstToLeave` must fail. Delete the lifetime's `deinit` body. `testADismissalBySomeoneElseAnswersDismissedOnce` must fail.

- [ ] **Step 7: Commit**

```bash
bash .githooks/pre-commit && \
git add liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/DialogMath.swift \
  liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/NativeDialogPresenter.swift \
  liquid_shell_ios/ios/liquid_shell_ios/Sources/liquid_shell_ios/LiquidShellPlugin.swift \
  liquid_shell/example/ios/RunnerTests/RunnerTests.swift && \
git commit -m "feat(ios): present UIAlertController from the engine's window, answer once (VK-406)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Flutter glass fallback (alert and action sheet)

**Files:**
- Create: `liquid_shell/lib/src/dialogs/dialog_metrics.dart`
- Create: `liquid_shell/lib/src/dialogs/dialog_layout.dart`
- Create: `liquid_shell/lib/src/dialogs/glass_dialogs.dart`
- Modify: `liquid_shell/lib/src/shell/strings.dart` (`dismiss`)
- Create: `docs/qa/p3a/metrics.md`
- Test: `liquid_shell/test/unit/dialog_layout_test.dart`, `liquid_shell/test/widget/glass_dialogs_test.dart`
- Throwaway (Step 1, reverted): `liquid_shell/example/ios/Runner/AppDelegate.swift`

**Interfaces:**
- Consumes (Task 1): `LiquidNativeDialogRequest`, `LiquidNativeDialogAction`, `LiquidNativeDialogKind`, `LiquidNativeDialogActionStyle`. From P1: `LiquidGlass`, `LiquidShellBreakpoints`, `LiquidShellStrings`.
- Produces (used by Task 5):
  - `Future<int?> showGlassDialog(BuildContext context, LiquidNativeDialogRequest request, {LiquidShellStrings strings = const LiquidShellStrings()})`. It completes with the chosen index, or null when dismissed.
  - widgets `GlassAlert({required LiquidNativeDialogRequest request})`, `GlassActionSheet({required LiquidNativeDialogRequest request})`, `GlassDialogButton`, `DialogHeader`;
  - pure functions `alertActionsSideBySide(...)`, `alertDisplayOrder(actions, {required bool sideBySide})`, `sheetGroups(actions) → ({List<int> main, int? cancel})`, `anchoredCardOffset(...)`;
  - `LiquidShellStrings.dismiss` (default `'Dismiss'`).

- [ ] **Step 1: Measure the native iOS 26 alert and action sheet (throwaway, simulator)**

Temporarily replace `didInitializeImplicitFlutterEngine` in `liquid_shell/example/ios/Runner/AppDelegate.swift` with:

```swift
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // SPIKE (P3a Task 4): log a native alert's and action sheet's geometry.
    // Never commit this.
    func dump(_ view: UIView, _ depth: Int) {
      var line = String(repeating: "  ", count: depth) + String(describing: type(of: view))
      line += " " + NSCoder.string(for: view.convert(view.bounds, to: nil))
      line += " r=\(view.layer.cornerRadius)"
      if let label = view as? UILabel {
        line += " '\(label.text ?? "")' \(label.font.pointSize)pt \(label.font.fontDescriptor.object(forKey: .face) ?? "")"
      }
      NSLog("[probe] %@", line)
      if depth < 10 { view.subviews.forEach { dump($0, depth + 1) } }
    }
    let style: UIAlertController.Style =
      ProcessInfo.processInfo.environment["PROBE_SHEET"] == "1" ? .actionSheet : .alert
    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
      guard
        let root = UIApplication.shared.connectedScenes
          .compactMap({ ($0 as? UIWindowScene)?.windows.first?.rootViewController }).first
      else { return }
      let alert = UIAlertController(
        title: "Discard changes?", message: "Your edits will be lost.", preferredStyle: style)
      alert.addAction(UIAlertAction(title: "Keep editing", style: .cancel))
      alert.addAction(UIAlertAction(title: "Discard", style: .destructive))
      alert.popoverPresentationController?.sourceView = root.view
      alert.popoverPresentationController?.sourceRect = CGRect(x: 100, y: 300, width: 120, height: 44)
      root.present(alert, animated: false) { dump(alert.view, 0) }
    }
  }
```

Run it on the iPhone, then on the iPad, once with `PROBE_SHEET` unset and once with `SIMCTL_CHILD_PROBE_SHEET=1`. Capture the log and a screenshot each time:

```bash
cd liquid_shell/example && fvm flutter run -d "$IPHONE_UDID" &
xcrun simctl spawn "$IPHONE_UDID" log stream --style compact --predicate 'eventMessage CONTAINS "[probe]"' | tee /tmp/p3a-probe-iphone-alert.log
xcrun simctl io "$IPHONE_UDID" screenshot docs/qa/p3a/native-iphone-alert.png
```

Write `docs/qa/p3a/metrics.md` with these numbers taken from the logs and screenshots: the alert card width and corner radius; the title and message point sizes and weights; the action height, gap and corner radius; the order of two actions (where is cancel?); whether the preferred/cancel action is filled; the compact sheet's side margin, group radius and the cancel group's gap; the iPad popover width. Use this table:

```markdown
# P3a: native iOS 26.5 dialog metrics (VK-406 Task 4)

Simulators: iPhone 17 Pro and iPad Air 11-inch (M4), iOS 26.5. Probe: the
geometry of `UIAlertController.view` and every subview, logged after presentation.

| Metric | iPhone alert | iPad alert | iPhone sheet | iPad popover | constant |
|---|---|---|---|---|---|
| card width (pt) | | | | | kAlertWidth / kSheetMaxWidth / kSheetPopoverWidth |
| corner radius (pt) | | | | | kAlertRadius / kSheetRadius |
| title size / weight | | | | | kTitleFontSize |
| message size | | | | | kMessageFontSize |
| action height (pt) | | | | | kActionHeight |
| gap between actions (pt) | | | | | kActionGap |
| two actions: cancel leading? | | | n/a | n/a | alertDisplayOrder |
| preferred action filled? | | | n/a | n/a | GlassDialogButton.prominent |

Screenshots: native-iphone-alert.png, native-ipad-alert.png,
native-iphone-sheet.png, native-ipad-sheet.png.
```

Fill every cell. Then revert the probe: `git checkout -- liquid_shell/example/ios/Runner/AppDelegate.swift`.

- [ ] **Step 2: Write the failing tests**

`liquid_shell/test/unit/dialog_layout_test.dart`:

```dart
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/dialogs/dialog_layout.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

const _cancel = LiquidNativeDialogAction(
  label: 'Cancel',
  style: LiquidNativeDialogActionStyle.cancel,
);
const _a = LiquidNativeDialogAction(label: 'A');
const _b = LiquidNativeDialogAction(label: 'B');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('alertDisplayOrder', () {
    test('side by side, the cancel action leads', () {
      expect(alertDisplayOrder(const [_a, _cancel], sideBySide: true), [1, 0]);
      expect(alertDisplayOrder(const [_cancel, _a], sideBySide: true), [0, 1]);
    });

    test('stacked, the cancel action comes last', () {
      expect(alertDisplayOrder(const [_cancel, _a, _b], sideBySide: false), [
        1,
        2,
        0,
      ]);
    });

    test('without a cancel action the order is the app\'s', () {
      expect(alertDisplayOrder(const [_b, _a], sideBySide: true), [0, 1]);
    });
  });

  test('sheetGroups keeps the cancel action apart', () {
    expect(sheetGroups(const [_a, _cancel, _b]), (main: [0, 2], cancel: 1));
    expect(sheetGroups(const [_a, _b]), (main: [0, 1], cancel: null));
  });

  group('alertActionsSideBySide', () {
    const style = TextStyle(fontSize: 17);
    bool fits(List<String> labels, {double scale = 1}) =>
        alertActionsSideBySide(
          labels: labels,
          style: style,
          textScaler: TextScaler.linear(scale),
          textDirection: TextDirection.ltr,
          rowWidth: 260,
        );

    // flutter_test's font draws every glyph 1em wide: 17pt per character.
    test('two short labels fit', () => expect(fits(['No', 'OK']), isTrue));
    test('one or three actions never sit side by side', () {
      expect(fits(['OK']), isFalse);
      expect(fits(['A', 'B', 'C']), isFalse);
    });
    test('a long label stacks', () {
      expect(fits(['Cancel', 'Discard every change on this page']), isFalse);
    });
    test('large text stacks', () {
      expect(fits(['Keep editing', 'Discard'], scale: 3), isFalse);
    });
  });

  group('anchoredCardOffset', () {
    const screen = Size(1194, 834);
    const padding = EdgeInsets.only(top: 24, bottom: 20);
    const card = Size(320, 200);

    test('below the anchor, centred on it', () {
      final offset = anchoredCardOffset(
        screen: screen,
        padding: padding,
        card: card,
        anchor: const Rect.fromLTWH(400, 100, 120, 44),
      );
      expect(offset, const Offset(300, 152));
    });

    test('above the anchor when there is no room below', () {
      final offset = anchoredCardOffset(
        screen: screen,
        padding: padding,
        card: card,
        anchor: const Rect.fromLTWH(400, 700, 120, 44),
      );
      expect(offset.dy, 700 - 8 - 200);
    });

    test('clamped to the screen edge', () {
      final offset = anchoredCardOffset(
        screen: screen,
        padding: padding,
        card: card,
        anchor: const Rect.fromLTWH(1150, 100, 40, 40),
      );
      expect(offset.dx, 1194 - 8 - 320);
    });

    test('centred without an anchor', () {
      final offset = anchoredCardOffset(
        screen: screen,
        padding: padding,
        card: card,
        anchor: null,
      );
      expect(offset, const Offset((1194 - 320) / 2, (834 - 200) / 2));
    });
  });
}
```

`liquid_shell/test/widget/glass_dialogs_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/dialogs/dialog_metrics.dart';
import 'package:liquid_shell/src/dialogs/glass_dialogs.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

const _cancel = LiquidNativeDialogAction(
  label: 'Keep editing',
  style: LiquidNativeDialogActionStyle.cancel,
);
const _discard = LiquidNativeDialogAction(
  label: 'Discard',
  style: LiquidNativeDialogActionStyle.destructive,
);
const _share = LiquidNativeDialogAction(label: 'Share');
// Short enough to sit side by side in flutter_test's font, which draws
// every glyph 1em wide.
const _no = LiquidNativeDialogAction(
  label: 'No',
  style: LiquidNativeDialogActionStyle.cancel,
);
const _yes = LiquidNativeDialogAction(
  label: 'Yes',
  style: LiquidNativeDialogActionStyle.destructive,
);

LiquidNativeDialogRequest _request({
  LiquidNativeDialogKind kind = LiquidNativeDialogKind.alert,
  List<LiquidNativeDialogAction> actions = const [_cancel, _discard],
  int? preferredIndex,
  Rect? anchor,
}) => LiquidNativeDialogRequest(
  kind: kind,
  title: 'Discard changes?',
  message: 'Your edits will be lost.',
  actions: actions,
  preferredIndex: preferredIndex,
  anchor: anchor,
  tintArgb: 0,
  dark: false,
  rtl: false,
  requireGlass: true,
);

const _phone = Size(393, 852);
const _tablet = Size(1194, 834);

/// Opens [request] from a button; returns the answers it completes with.
Future<List<int?>> _open(
  WidgetTester tester,
  LiquidNativeDialogRequest request, {
  Size size = _phone,
  TextDirection direction = TextDirection.ltr,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  final answers = <int?>[];
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: Builder(
        builder: (context) => Align(
          alignment: Alignment.bottomCenter,
          child: TextButton(
            onPressed: () async =>
                answers.add(await showGlassDialog(context, request)),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return answers;
}

Finder _in(Type dialog, Finder finder) =>
    find.descendant(of: find.byType(dialog), matching: finder);

void main() {
  test('strings: dismiss defaults to English and joins ==', () {
    expect(const LiquidShellStrings().dismiss, 'Dismiss');
    expect(
      const LiquidShellStrings(dismiss: 'Đóng'),
      isNot(const LiquidShellStrings()),
    );
  });

  group('alert', () {
    testWidgets('shows its text on glass; a tap answers the index', (
      tester,
    ) async {
      final answers = await _open(tester, _request());
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text('Your edits will be lost.'), findsOneWidget);
      expect(_in(GlassAlert, find.byType(LiquidGlass)), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(answers, [1]);
      expect(find.byType(GlassAlert), findsNothing);
    });

    testWidgets('two short actions sit side by side, cancel leading', (
      tester,
    ) async {
      await _open(tester, _request(actions: const [_yes, _no]));
      final no = tester.getCenter(find.text('No'));
      final yes = tester.getCenter(find.text('Yes'));
      expect(no.dy, yes.dy);
      expect(no.dx, lessThan(yes.dx));
    });

    testWidgets('right to left mirrors the pair', (tester) async {
      await _open(
        tester,
        _request(actions: const [_no, _yes]),
        direction: TextDirection.rtl,
      );
      expect(
        tester.getCenter(find.text('No')).dx,
        greaterThan(tester.getCenter(find.text('Yes')).dx),
      );
    });

    testWidgets('three actions stack, cancel last', (tester) async {
      await _open(tester, _request(actions: const [_cancel, _share, _discard]));
      final ys = [
        for (final label in ['Share', 'Discard', 'Keep editing'])
          tester.getCenter(find.text(label)).dy,
      ];
      expect(ys[0], lessThan(ys[1]));
      expect(ys[1], lessThan(ys[2]));
    });

    testWidgets('a label too long for half the row stacks', (tester) async {
      const long = LiquidNativeDialogAction(
        label: 'Discard every change on this page',
      );
      await _open(tester, _request(actions: const [_cancel, long]));
      expect(
        tester.getCenter(find.text('Keep editing')).dy,
        greaterThan(tester.getCenter(find.text(long.label)).dy),
      );
    });

    testWidgets('the barrier does not dismiss an alert', (tester) async {
      final answers = await _open(tester, _request());
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byType(GlassAlert), findsOneWidget);
      expect(answers, isEmpty);
    });

    testWidgets('Escape answers cancel, Enter the preferred action', (
      tester,
    ) async {
      final answers = await _open(tester, _request(preferredIndex: 1));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(answers, [0, 1]);
    });

    testWidgets('a disabled action does not answer', (tester) async {
      const later = LiquidNativeDialogAction(label: 'Later', enabled: false);
      final answers = await _open(
        tester,
        _request(actions: const [_cancel, later]),
      );
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(answers, isEmpty);
      expect(find.byType(GlassAlert), findsOneWidget);
    });

    testWidgets('scales in; reduce motion only fades', (tester) async {
      Finder scale() => find.ancestor(
        of: find.byType(GlassAlert),
        matching: find.byType(ScaleTransition),
      );
      await _open(tester, _request());
      expect(scale(), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(scale(), findsNothing);
    });

    testWidgets('the route is named by its title', (tester) async {
      final semantics = tester.ensureSemantics();
      await _open(tester, _request());
      expect(find.bySemanticsLabel('Discard changes?'), findsWidgets);
      semantics.dispose();
    });
  });

  group('action sheet', () {
    LiquidNativeDialogRequest sheet({Rect? anchor}) => _request(
      kind: LiquidNativeDialogKind.actionSheet,
      actions: const [_discard, _share, _cancel],
      anchor: anchor,
    );

    testWidgets('on a phone the cancel action sits apart, below', (
      tester,
    ) async {
      final answers = await _open(tester, sheet());
      expect(_in(GlassActionSheet, find.byType(LiquidGlass)), findsNWidgets(2));
      expect(
        tester.getCenter(find.text('Keep editing')).dy,
        greaterThan(tester.getCenter(find.text('Share')).dy),
      );
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(answers, [1]);
    });

    testWidgets('a tap outside or Escape answers null', (tester) async {
      final answers = await _open(tester, sheet());
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(answers, [null, null]);
    });

    testWidgets('the barrier is labelled with strings.dismiss', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _open(tester, sheet());
      expect(find.bySemanticsLabel('Dismiss'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('on a tablet a card below the anchor, no cancel row', (
      tester,
    ) async {
      const anchor = Rect.fromLTWH(100, 200, 120, 44);
      final answers = await _open(tester, sheet(anchor: anchor), size: _tablet);
      expect(find.text('Keep editing'), findsNothing);
      final card = tester.getRect(
        _in(GlassActionSheet, find.byType(LiquidGlass)),
      );
      expect(card.top, greaterThanOrEqualTo(anchor.bottom));
      expect(card.width, kSheetPopoverWidth);
      await tester.tapAt(const Offset(1100, 60));
      await tester.pumpAndSettle();
      expect(answers, [null]);
    });

    testWidgets('an anchor near the bottom puts the card above it', (
      tester,
    ) async {
      const anchor = Rect.fromLTWH(100, 760, 120, 44);
      await _open(tester, sheet(anchor: anchor), size: _tablet);
      final card = tester.getRect(
        _in(GlassActionSheet, find.byType(LiquidGlass)),
      );
      expect(card.bottom, lessThanOrEqualTo(anchor.top));
    });
  });
}
```

- [ ] **Step 3: Run them to see them fail**

Run: `cd liquid_shell && fvm flutter test test/unit/dialog_layout_test.dart test/widget/glass_dialogs_test.dart`
Expected: compile errors, `Target of URI doesn't exist: 'package:liquid_shell/src/dialogs/dialog_layout.dart'` and `The named parameter 'dismiss' isn't defined`.

- [ ] **Step 4: Add `LiquidShellStrings.dismiss`**

In `liquid_shell/lib/src/shell/strings.dart`: add the constructor parameter `this.dismiss = 'Dismiss',` after `badgeCount`, then the field

```dart
  /// The barrier label of a Flutter action sheet (spec P3a §4.3): screen
  /// readers offer it to close the sheet.
  final String dismiss;
```

Add `other.dismiss == dismiss &&` to `==` and `dismiss,` to `Object.hash`.

- [ ] **Step 5: Write the metrics, the layout rules and the widgets**

`liquid_shell/lib/src/dialogs/dialog_metrics.dart`. Replace each value with the measured one from `docs/qa/p3a/metrics.md`; the values below are the starting point:

```dart
import 'package:flutter/painting.dart';

// Geometry of the Flutter glass dialogs (spec P3a §7), measured from the
// native iOS 26.5 alert and action sheet (docs/qa/p3a/metrics.md). Tests
// read these constants, so a re-measure moves code and tests together.

/// Widest alert card.
const double kAlertWidth = 300;

/// Alert card corner radius.
const double kAlertRadius = 34;

/// Inner padding of the alert card.
const EdgeInsets kAlertPadding = EdgeInsets.fromLTRB(20, 22, 20, 16);

/// Smallest gap between a dialog and the screen edge.
const double kDialogMargin = 16;

/// Tallest a dialog may be, as a fraction of the screen height.
const double kDialogMaxHeightFraction = 0.8;

/// Title size.
const double kTitleFontSize = 17;

/// Message size.
const double kMessageFontSize = 15;

/// Gap between title and message.
const double kTitleMessageGap = 4;

/// Gap between the header and the actions.
const double kHeaderGap = 18;

/// Action label size.
const double kActionFontSize = 17;

/// Height of one action capsule.
const double kActionHeight = 48;

/// Gap between action capsules.
const double kActionGap = 8;

/// Horizontal padding inside an action capsule.
const double kActionLabelPadding = 12;

/// Fill of a plain action capsule, as `onSurface` alpha.
const double kActionFillAlpha = 0.08;

/// Dim colour behind a dialog.
const Color kDialogBarrier = Color(0x33000000);

/// Widest compact action sheet.
const double kSheetMaxWidth = 420;

/// Width of the regular-width anchored action-sheet card.
const double kSheetPopoverWidth = 320;

/// Corner radius of a sheet group and of the anchored card.
const double kSheetRadius = 28;

/// Inner padding of a sheet group.
const double kSheetGroupPadding = 8;

/// Padding around a sheet's title and message.
const EdgeInsets kSheetHeaderPadding = EdgeInsets.fromLTRB(12, 8, 12, 12);

/// Side and bottom margin of a compact sheet.
const double kSheetSideMargin = 8;

/// Gap between the anchored card and its anchor or the screen edge.
const double kAnchorGap = 8;

/// Alert entrance length.
const Duration kAlertDuration = Duration(milliseconds: 250);

/// Sheet entrance length.
const Duration kSheetDuration = Duration(milliseconds: 300);

/// Scale an alert grows from.
const double kAlertScaleFrom = 1.08;

/// Scale the anchored card grows from.
const double kCardScaleFrom = 0.95;
```

`liquid_shell/lib/src/dialogs/dialog_layout.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:liquid_shell/src/dialogs/dialog_metrics.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

// The pure layout rules of the Flutter glass dialogs (spec P3a §7).

int _cancelIndex(List<LiquidNativeDialogAction> actions) => actions.indexWhere(
  (action) => action.style == LiquidNativeDialogActionStyle.cancel,
);

/// Whether an alert's actions sit side by side, as UIKit does: exactly
/// two, each label fitting in half the row at [textScaler].
bool alertActionsSideBySide({
  required List<String> labels,
  required TextStyle style,
  required TextScaler textScaler,
  required TextDirection textDirection,
  required double rowWidth,
}) {
  if (labels.length != 2) return false;
  final room = (rowWidth - kActionGap) / 2 - 2 * kActionLabelPadding;
  for (final label in labels) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textScaler: textScaler,
      textDirection: textDirection,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    if (width > room) return false;
  }
  return true;
}

/// The order an alert shows its actions in, as indices into [actions].
/// Side by side, the cancel action leads; stacked, it comes last.
List<int> alertDisplayOrder(
  List<LiquidNativeDialogAction> actions, {
  required bool sideBySide,
}) {
  final cancel = _cancelIndex(actions);
  final others = [
    for (var i = 0; i < actions.length; i++)
      if (i != cancel) i,
  ];
  if (cancel < 0) return others;
  return sideBySide ? [cancel, ...others] : [...others, cancel];
}

/// An action sheet's stacked actions and its cancel action, drawn apart.
({List<int> main, int? cancel}) sheetGroups(
  List<LiquidNativeDialogAction> actions,
) {
  final cancel = _cancelIndex(actions);
  return (
    main: [
      for (var i = 0; i < actions.length; i++)
        if (i != cancel) i,
    ],
    cancel: cancel < 0 ? null : cancel,
  );
}

/// The top-left corner of the regular-width action-sheet card: below
/// [anchor] if it fits, else above, centred on it, kept [kAnchorGap] inside
/// the safe area; the screen's centre without an anchor.
Offset anchoredCardOffset({
  required Size screen,
  required EdgeInsets padding,
  required Size card,
  required Rect? anchor,
}) {
  final left = padding.left + kAnchorGap;
  final right = math.max(
    left,
    screen.width - padding.right - kAnchorGap - card.width,
  );
  final top = padding.top + kAnchorGap;
  final bottom = math.max(
    top,
    screen.height - padding.bottom - kAnchorGap - card.height,
  );
  if (anchor == null) {
    return Offset(
      ((screen.width - card.width) / 2).clamp(left, right),
      ((screen.height - card.height) / 2).clamp(top, bottom),
    );
  }
  final x = (anchor.center.dx - card.width / 2).clamp(left, right);
  final below = anchor.bottom + kAnchorGap;
  final y = below <= bottom
      ? below
      : (anchor.top - kAnchorGap - card.height).clamp(top, bottom);
  return Offset(x, y);
}
```

`liquid_shell/lib/src/dialogs/glass_dialogs.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_shell/src/dialogs/dialog_layout.dart';
import 'package:liquid_shell/src/dialogs/dialog_metrics.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';
import 'package:liquid_shell/src/shell/breakpoints.dart';
import 'package:liquid_shell/src/shell/strings.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// Shows [request] as a Flutter glass dialog on the root navigator (spec
/// P3a §7). Completes with the chosen action's index, or null when it is
/// dismissed without a choice.
Future<int?> showGlassDialog(
  BuildContext context,
  LiquidNativeDialogRequest request, {
  LiquidShellStrings strings = const LiquidShellStrings(),
}) {
  final alert = request.kind == LiquidNativeDialogKind.alert;
  return showGeneralDialog<int>(
    context: context,
    barrierDismissible: !alert,
    barrierLabel: alert ? null : strings.dismiss,
    barrierColor: kDialogBarrier,
    transitionDuration: alert ? kAlertDuration : kSheetDuration,
    pageBuilder: (context, animation, secondaryAnimation) => alert
        ? GlassAlert(request: request)
        : GlassActionSheet(request: request),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        _transition(context, animation, child, request.kind),
  );
}

/// Whether the screen is wide enough for the anchored action-sheet card.
bool isRegularDialogWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= const LiquidShellBreakpoints().regular;

Widget _transition(
  BuildContext context,
  Animation<double> animation,
  Widget child,
  LiquidNativeDialogKind kind,
) {
  if (MediaQuery.disableAnimationsOf(context)) {
    return FadeTransition(opacity: animation, child: child);
  }
  final eased = animation.drive(CurveTween(curve: Curves.easeOutCubic));
  if (kind == LiquidNativeDialogKind.actionSheet &&
      !isRegularDialogWidth(context)) {
    return SlideTransition(
      position: eased.drive(
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero),
      ),
      child: child,
    );
  }
  final from = kind == LiquidNativeDialogKind.alert
      ? kAlertScaleFrom
      : kCardScaleFrom;
  return FadeTransition(
    opacity: eased,
    child: ScaleTransition(
      scale: eased.drive(Tween<double>(begin: from, end: 1)),
      child: child,
    ),
  );
}

Widget _routeSemantics(String? label, Widget child) => Semantics(
  scopesRoute: true,
  namesRoute: true,
  explicitChildNodes: true,
  label: label,
  child: child,
);

Widget _glassGroup(Widget child) => LiquidGlass(
  borderRadius: const BorderRadius.all(Radius.circular(kSheetRadius)),
  child: Material(
    type: MaterialType.transparency,
    child: Padding(
      padding: const EdgeInsets.all(kSheetGroupPadding),
      child: child,
    ),
  ),
);

Widget _stack(List<Widget> buttons) => Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (final (n, button) in buttons.indexed) ...[
      if (n > 0) const SizedBox(height: kActionGap),
      button,
    ],
  ],
);

/// The label style of a dialog action.
TextStyle dialogActionTextStyle(
  BuildContext context, {
  required bool emphasised,
}) => (Theme.of(context).textTheme.bodyLarge ?? const TextStyle()).copyWith(
  fontSize: kActionFontSize,
  fontWeight: emphasised ? FontWeight.w600 : FontWeight.w500,
);

/// The Flutter glass alert (spec P3a §7.1). Pops the chosen index.
class GlassAlert extends StatelessWidget {
  /// Creates the alert.
  const GlassAlert({required this.request, super.key});

  /// What to show.
  final LiquidNativeDialogRequest request;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final actions = request.actions;
    final preferred = request.preferredIndex;
    final cancel = actions.indexWhere(
      (action) => action.style == LiquidNativeDialogActionStyle.cancel,
    );
    final width = math.min(kAlertWidth, media.size.width - 2 * kDialogMargin);
    final sideBySide = alertActionsSideBySide(
      labels: [for (final action in actions) action.label],
      style: dialogActionTextStyle(context, emphasised: true),
      textScaler: media.textScaler,
      textDirection: Directionality.of(context),
      rowWidth: width - kAlertPadding.horizontal,
    );
    final order = alertDisplayOrder(actions, sideBySide: sideBySide);
    void choose(int? index) {
      if (index == null || index < 0 || !actions[index].enabled) return;
      Navigator.of(context).pop(index);
    }

    Widget button(int index) => GlassDialogButton(
      action: actions[index],
      prominent: index == preferred,
      autofocus: index == (preferred ?? order.first),
      onPressed: () => choose(index),
    );
    final buttons = sideBySide
        ? Row(
            children: [
              Expanded(child: button(order[0])),
              const SizedBox(width: kActionGap),
              Expanded(child: button(order[1])),
            ],
          )
        : _stack([for (final index in order) button(index)]);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => choose(cancel),
        const SingleActivator(LogicalKeyboardKey.enter): () => choose(preferred),
        const SingleActivator(LogicalKeyboardKey.numpadEnter): () =>
            choose(preferred),
      },
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(kDialogMargin),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: width,
              maxHeight: media.size.height * kDialogMaxHeightFraction,
            ),
            child: _routeSemantics(
              request.title ?? request.message,
              LiquidGlass(
                borderRadius: BorderRadius.circular(kAlertRadius),
                child: Material(
                  type: MaterialType.transparency,
                  child: Padding(
                    padding: kAlertPadding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Flexible(
                          child: SingleChildScrollView(
                            child: DialogHeader(
                              title: request.title,
                              message: request.message,
                            ),
                          ),
                        ),
                        const SizedBox(height: kHeaderGap),
                        buttons,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Flutter glass action sheet (spec P3a §7.2): at the bottom with a
/// separate cancel action when compact, an anchored card without one when
/// regular. Pops the chosen index; a tap outside pops null.
class GlassActionSheet extends StatelessWidget {
  /// Creates the sheet.
  const GlassActionSheet({required this.request, super.key});

  /// What to show.
  final LiquidNativeDialogRequest request;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final groups = sheetGroups(request.actions);
    final regular = isRegularDialogWidth(context);
    // A popover has no cancel row (UIKit): a tap outside cancels. A sheet
    // whose only action is cancel still shows it.
    final cancel = groups.cancel;
    final stacked = regular && groups.main.isEmpty && cancel != null
        ? [cancel]
        : groups.main;
    final apart = regular ? null : cancel;
    final first = stacked.isNotEmpty ? stacked.first : apart;
    Widget button(int index) => GlassDialogButton(
      action: request.actions[index],
      autofocus: index == first,
      onPressed: () => Navigator.of(context).pop(index),
    );
    final hasHeader = request.title != null || request.message != null;
    final group = _glassGroup(
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHeader)
            Padding(
              padding: kSheetHeaderPadding,
              child: DialogHeader(
                title: request.title,
                message: request.message,
              ),
            ),
          Flexible(
            child: SingleChildScrollView(
              child: _stack([for (final index in stacked) button(index)]),
            ),
          ),
        ],
      ),
    );
    final label = request.title ?? request.message;
    final Widget sheet;
    if (regular) {
      sheet = CustomSingleChildLayout(
        delegate: AnchoredCardLayout(
          anchor: request.anchor,
          padding: media.padding,
        ),
        child: SizedBox(
          width: kSheetPopoverWidth,
          child: _routeSemantics(label, group),
        ),
      );
    } else {
      sheet = Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            kSheetSideMargin,
            media.padding.top + kSheetSideMargin,
            kSheetSideMargin,
            media.viewPadding.bottom + kSheetSideMargin,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kSheetMaxWidth),
            child: _routeSemantics(
              label,
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(child: group),
                  if (apart != null) ...[
                    const SizedBox(height: kActionGap),
                    _glassGroup(button(apart)),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: sheet,
    );
  }
}

/// Places the regular-width action-sheet card at its anchor.
class AnchoredCardLayout extends SingleChildLayoutDelegate {
  /// Creates the layout.
  AnchoredCardLayout({required this.anchor, required this.padding});

  /// Where the card points, in global logical coordinates.
  final Rect? anchor;

  /// The screen's safe area.
  final EdgeInsets padding;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        Size(
          constraints.maxWidth,
          math.max(0, constraints.maxHeight - padding.vertical - 2 * kAnchorGap),
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) => anchoredCardOffset(
    screen: size,
    padding: padding,
    card: childSize,
    anchor: anchor,
  );

  @override
  bool shouldRelayout(AnchoredCardLayout oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.padding != padding;
}

/// One action capsule of a glass dialog.
class GlassDialogButton extends StatelessWidget {
  /// Creates the button.
  const GlassDialogButton({
    required this.action,
    required this.onPressed,
    this.prominent = false,
    this.autofocus = false,
    super.key,
  });

  /// What it shows and whether it is enabled.
  final LiquidNativeDialogAction action;

  /// Called on a tap when enabled.
  final VoidCallback onPressed;

  /// A filled capsule: the alert's preferred action.
  final bool prominent;

  /// Whether it takes focus first.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final destructive =
        action.style == LiquidNativeDialogActionStyle.destructive;
    final cancel = action.style == LiquidNativeDialogActionStyle.cancel;
    final accent = destructive ? scheme.error : scheme.primary;
    final filled = prominent && action.enabled;
    final fill = filled
        ? accent
        : scheme.onSurface.withValues(alpha: kActionFillAlpha);
    final Color label;
    if (!action.enabled) {
      label = scheme.onSurface.withValues(alpha: 0.38);
    } else if (filled) {
      label = destructive ? scheme.onError : scheme.onPrimary;
    } else {
      label = accent;
    }
    return Semantics(
      button: true,
      enabled: action.enabled,
      child: Material(
        color: fill,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          autofocus: autofocus,
          onTap: action.enabled ? onPressed : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kActionHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: kActionLabelPadding,
                  vertical: 8,
                ),
                child: Text(
                  action.label,
                  textAlign: TextAlign.center,
                  style: dialogActionTextStyle(
                    context,
                    emphasised: prominent || cancel,
                  ).copyWith(color: label),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dialog's title and message.
class DialogHeader extends StatelessWidget {
  /// Creates the header.
  const DialogHeader({this.title, this.message, super.key});

  /// The title, or null.
  final String? title;

  /// The message, or null.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = this.title;
    final message = this.message;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: kTitleFontSize,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
        if (title != null && message != null)
          const SizedBox(height: kTitleMessageGap),
        if (message != null)
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: kMessageFontSize,
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
```

If Step 1 measured that the native alert does **not** put cancel on the leading side, or does not fill the preferred action, change `alertDisplayOrder` / `GlassDialogButton.prominent` to match. Update the matching tests in the same step, and note it in `metrics.md`.

- [ ] **Step 6: Run the tests to see them pass**

Run: `cd liquid_shell && fvm flutter test test/unit/dialog_layout_test.dart test/widget/glass_dialogs_test.dart`
Expected: `All tests passed!`
Run: `cd liquid_shell && fvm flutter test --exclude-tags golden`
Expected: every P1/P2 test still passes (the new strings field is additive).

- [ ] **Step 7: Commit**

```bash
bash .githooks/pre-commit && \
git add liquid_shell/lib/src/dialogs/dialog_metrics.dart \
  liquid_shell/lib/src/dialogs/dialog_layout.dart \
  liquid_shell/lib/src/dialogs/glass_dialogs.dart \
  liquid_shell/lib/src/shell/strings.dart \
  liquid_shell/test/unit/dialog_layout_test.dart \
  liquid_shell/test/widget/glass_dialogs_test.dart \
  docs/qa/p3a/metrics.md docs/qa/p3a/native-*.png && \
git commit -m "feat(glass): Flutter glass alert and action sheet measured from iOS 26 (VK-406)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Before staging, downscale the four screenshots: `sips --resampleWidth 820 docs/qa/p3a/native-*.png`.

---

### Task 5: Public API — `showLiquidAlert`, `showLiquidActionSheet`

**Files:**
- Create: `liquid_shell/lib/src/dialogs/dialog_types.dart`
- Create: `liquid_shell/lib/src/dialogs/dialog_plan.dart`
- Create: `liquid_shell/lib/src/dialogs/show_dialogs.dart`
- Modify: `liquid_shell/lib/src/native/native_reset.dart`, `liquid_shell/lib/liquid_shell.dart`
- Modify: `liquid_shell/test/helpers/fake_native_platform.dart`
- Test: `liquid_shell/test/unit/dialog_plan_test.dart`, `liquid_shell/test/widget/liquid_dialogs_test.dart`

**Interfaces:**
- Consumes: Task 1 (interface types, `LiquidShellPlatform.supportsNativeDialogs` / `presentNativeDialog`), Task 4 (`showGlassDialog`, `GlassAlert`, `GlassActionSheet`, `LiquidShellStrings.dismiss`).
- Produces (public, used by Tasks 6–7):
  - `enum LiquidAlertActionStyle { standard, cancel, destructive }`
  - `class LiquidAlertAction<T> { const ({required String label, required T value, LiquidAlertActionStyle style = standard, bool preferred = false, bool enabled = true}) }`
  - `enum LiquidDialogPresentation { auto, system, flutter }`
  - `Future<T?> showLiquidAlert<T>(BuildContext context, {required String title, required List<LiquidAlertAction<T>> actions, String? message, LiquidDialogPresentation presentation = auto})`
  - `Future<T?> showLiquidActionSheet<T>(BuildContext context, {required List<LiquidAlertAction<T>> actions, String? title, String? message, Rect? anchor, LiquidDialogPresentation presentation = auto, LiquidShellStrings strings = const LiquidShellStrings()})`
  - internal: `checkAlertActions`, `dialogRequestFor`, `dialogValue`, `anchorOf`, `NativeDialogMemory` (`refuses`, `remember`, `debugReset`).
  - `FakeNativePlatform`: `nativeDialogs`, `dialogRequests`, `dialogAnswers`, `dialogGate`.

- [ ] **Step 1: Extend the fake platform**

In `liquid_shell/test/helpers/fake_native_platform.dart`, add to `FakeNativePlatform`:

```dart
  /// What [supportsNativeDialogs] answers (iOS: true).
  bool nativeDialogs = true;

  /// Every dialog request, in order.
  final dialogRequests = <LiquidNativeDialogRequest>[];

  /// Answers for the next requests, in order. When empty, a request waits
  /// for [dialogGate] (created on demand).
  final dialogAnswers = <LiquidNativeDialogResult>[];

  /// Completes the requests that found no queued answer.
  Completer<LiquidNativeDialogResult>? dialogGate;

  @override
  bool get supportsNativeDialogs => nativeDialogs;

  @override
  Future<LiquidNativeDialogResult> presentNativeDialog(
    LiquidNativeDialogRequest request,
  ) {
    dialogRequests.add(request);
    if (dialogAnswers.isNotEmpty) {
      return Future.value(dialogAnswers.removeAt(0));
    }
    return (dialogGate ??= Completer()).future;
  }
```

- [ ] **Step 2: Write the failing tests**

`liquid_shell/test/unit/dialog_plan_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/dialogs/dialog_plan.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

enum _Pick { keep, discard, later }

const _keep = LiquidAlertAction(
  label: 'Keep editing',
  value: _Pick.keep,
  style: LiquidAlertActionStyle.cancel,
);
const _discard = LiquidAlertAction(
  label: 'Discard',
  value: _Pick.discard,
  style: LiquidAlertActionStyle.destructive,
);
const _later = LiquidAlertAction(label: 'Later', value: _Pick.later);

void main() {
  group('checkAlertActions', () {
    test('accepts a normal set', () {
      checkAlertActions(const [_keep, _discard]);
    });

    test('rejects what UIKit would crash on or draw blank', () {
      final bad = <List<LiquidAlertAction<_Pick>>>[
        const [],
        const [_keep, _keep],
        const [
          LiquidAlertAction(label: 'A', value: _Pick.keep, preferred: true),
          LiquidAlertAction(label: 'B', value: _Pick.later, preferred: true),
        ],
        const [LiquidAlertAction(label: '  ', value: _Pick.keep)],
      ];
      for (final actions in bad) {
        expect(() => checkAlertActions(actions), throwsArgumentError);
      }
    });
  });

  group('dialogValue', () {
    test('an index picks its action', () {
      expect(dialogValue(const [_keep, _discard], 1), _Pick.discard);
    });

    test('a dismissal picks the cancel action, else null', () {
      expect(dialogValue(const [_discard, _keep], null), _Pick.keep);
      expect(dialogValue(const [_discard, _later], null), isNull);
    });
  });

  group('NativeDialogMemory', () {
    tearDown(NativeDialogMemory.debugReset);

    test('remembers what cannot change while the process runs', () {
      final memory = NativeDialogMemory.instance;
      expect(memory.refuses(requireGlass: true), isFalse);
      memory.remember(
        LiquidNativeDialogUnavailableReason.osTooOld,
        requireGlass: true,
      );
      expect(memory.refuses(requireGlass: true), isTrue);
      expect(memory.refuses(requireGlass: false), isFalse);
      memory.remember(
        LiquidNativeDialogUnavailableReason.disabledByEnvironment,
        requireGlass: false,
      );
      expect(memory.refuses(requireGlass: false), isTrue);
    });

    test('forgets nothing it should retry', () {
      final memory = NativeDialogMemory.instance;
      for (final reason in [
        LiquidNativeDialogUnavailableReason.noWindow,
        LiquidNativeDialogUnavailableReason.refused,
        LiquidNativeDialogUnavailableReason.channelError,
        LiquidNativeDialogUnavailableReason.unsupportedPlatform,
      ]) {
        memory.remember(reason, requireGlass: true);
      }
      expect(memory.refuses(requireGlass: true), isFalse);
    });

    test('debugResetLiquidNative forgets', () {
      NativeDialogMemory.instance.remember(
        LiquidNativeDialogUnavailableReason.disabledByEnvironment,
        requireGlass: true,
      );
      debugResetLiquidNative();
      expect(NativeDialogMemory.instance.refuses(requireGlass: true), isFalse);
    });
  });

  test('LiquidAlertAction == compares every field', () {
    expect(
      _keep,
      const LiquidAlertAction(
        label: 'Keep editing',
        value: _Pick.keep,
        style: LiquidAlertActionStyle.cancel,
      ),
    );
    expect(_keep, isNot(_discard));
    expect(
      _later,
      isNot(const LiquidAlertAction(label: 'Later', value: _Pick.later, enabled: false)),
    );
    expect(
      _later,
      isNot(const LiquidAlertAction(label: 'Later', value: _Pick.later, preferred: true)),
    );
  });
}
```

`liquid_shell/test/widget/liquid_dialogs_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/dialogs/glass_dialogs.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

import '../helpers/fake_native_platform.dart';

enum _Pick { keep, discard }

const _keep = LiquidAlertAction(
  label: 'Keep editing',
  value: _Pick.keep,
  style: LiquidAlertActionStyle.cancel,
);
const _discard = LiquidAlertAction(
  label: 'Discard',
  value: _Pick.discard,
  style: LiquidAlertActionStyle.destructive,
  preferred: true,
);

/// A page with one button that runs [show] and records its answers.
Future<List<Object?>> _launcher(
  WidgetTester tester,
  Future<Object?> Function(BuildContext button) show, {
  ThemeData? theme,
  TextDirection direction = TextDirection.ltr,
}) async {
  final answers = <Object?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 40, top: 120),
          child: Builder(
            builder: (button) => TextButton(
              key: const Key('open'),
              onPressed: () async => answers.add(await show(button)),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  return answers;
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

Future<_Pick?> _alert(BuildContext context, {
  LiquidDialogPresentation presentation = LiquidDialogPresentation.auto,
}) => showLiquidAlert(
  context,
  title: 'Discard changes?',
  message: 'Your edits will be lost.',
  actions: const [_keep, _discard],
  presentation: presentation,
);

void main() {
  group('native', () {
    testWidgets('a native answer completes with its value, nothing Flutter', (
      tester,
    ) async {
      final fake = installFakeNative()
        ..dialogAnswers.add(const LiquidNativeDialogChose(1));
      final answers = await _launcher(tester, _alert);
      await _open(tester);
      expect(answers, [_Pick.discard]);
      expect(find.byType(GlassAlert), findsNothing);
      final request = fake.dialogRequests.single;
      expect(request.kind, LiquidNativeDialogKind.alert);
      expect(request.title, 'Discard changes?');
      expect(request.message, 'Your edits will be lost.');
      expect(request.actions, const [
        LiquidNativeDialogAction(
          label: 'Keep editing',
          style: LiquidNativeDialogActionStyle.cancel,
        ),
        LiquidNativeDialogAction(
          label: 'Discard',
          style: LiquidNativeDialogActionStyle.destructive,
        ),
      ]);
      expect(request.preferredIndex, 1);
      expect(request.anchor, isNull);
      expect(request.requireGlass, isTrue);
    });

    testWidgets('a dismissal is the cancel value, or null without one', (
      tester,
    ) async {
      final fake = installFakeNative()
        ..dialogAnswers.addAll(const [
          LiquidNativeDialogDismissed(),
          LiquidNativeDialogDismissed(),
        ]);
      final answers = await _launcher(
        tester,
        (context) async => [
          await _alert(context),
          await showLiquidAlert(
            context,
            title: 'Saved',
            actions: const [LiquidAlertAction(label: 'OK', value: 1)],
          ),
        ],
      );
      await _open(tester);
      expect(answers.single, [_Pick.keep, null]);
      expect(fake.dialogRequests, hasLength(2));
    });

    testWidgets('theme, direction and tint reach the platform', (
      tester,
    ) async {
      final fake = installFakeNative()
        ..dialogAnswers.add(const LiquidNativeDialogChose(0));
      final theme = ThemeData(
        colorSchemeSeed: const Color(0xFF3D5AFE),
        brightness: Brightness.dark,
      );
      await _launcher(
        tester,
        _alert,
        theme: theme,
        direction: TextDirection.rtl,
      );
      await _open(tester);
      final request = fake.dialogRequests.single;
      expect(request.dark, isTrue);
      expect(request.rtl, isTrue);
      expect(request.tintArgb, theme.colorScheme.primary.toARGB32());
    });

    testWidgets('system asks for the native dialog without glass', (
      tester,
    ) async {
      final fake = installFakeNative()
        ..dialogAnswers.add(const LiquidNativeDialogChose(0));
      await _launcher(
        tester,
        (c) => _alert(c, presentation: LiquidDialogPresentation.system),
      );
      await _open(tester);
      expect(fake.dialogRequests.single.requireGlass, isFalse);
    });
  });

  group('fallback', () {
    testWidgets('osTooOld draws Flutter glass, and is not asked again', (
      tester,
    ) async {
      final fake = installFakeNative()
        ..dialogAnswers.add(
          const LiquidNativeDialogUnavailable(
            LiquidNativeDialogUnavailableReason.osTooOld,
          ),
        );
      final answers = await _launcher(tester, _alert);
      await _open(tester);
      expect(find.byType(GlassAlert), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(answers, [_Pick.discard]);
      await _open(tester);
      expect(find.byType(GlassAlert), findsOneWidget);
      expect(fake.dialogRequests, hasLength(1));
    });

    testWidgets('noWindow falls back, and is asked again next time', (
      tester,
    ) async {
      final fake = installFakeNative()
        ..dialogAnswers.addAll(const [
          LiquidNativeDialogUnavailable(
            LiquidNativeDialogUnavailableReason.noWindow,
          ),
          LiquidNativeDialogChose(0),
        ]);
      final answers = await _launcher(tester, _alert);
      await _open(tester);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      await _open(tester);
      expect(answers, [_Pick.keep, _Pick.keep]);
      expect(fake.dialogRequests, hasLength(2));
    });

    testWidgets('flutter never asks the platform', (tester) async {
      final fake = installFakeNative();
      await _launcher(
        tester,
        (c) => _alert(c, presentation: LiquidDialogPresentation.flutter),
      );
      await _open(tester);
      expect(find.byType(GlassAlert), findsOneWidget);
      expect(fake.dialogRequests, isEmpty);
    });

    testWidgets('a platform without native dialogs draws Flutter at once', (
      tester,
    ) async {
      final fake = installFakeNative()..nativeDialogs = false;
      await _launcher(tester, _alert);
      await tester.tap(find.byKey(const Key('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(GlassAlert), findsOneWidget);
      expect(fake.dialogRequests, isEmpty);
    });

    testWidgets('a context gone before the fallback answers null', (
      tester,
    ) async {
      final fake = installFakeNative()..dialogGate = Completer();
      final answers = await _launcher(tester, _alert);
      await _open(tester);
      await tester.pumpWidget(const SizedBox());
      fake.dialogGate!.complete(
        const LiquidNativeDialogUnavailable(
          LiquidNativeDialogUnavailableReason.noWindow,
        ),
      );
      await tester.pumpAndSettle();
      expect(answers, [null]);
      expect(find.byType(GlassAlert), findsNothing);
    });
  });

  group('action sheet', () {
    Future<_Pick?> sheet(BuildContext button, {Rect? anchor}) =>
        showLiquidActionSheet(
          button,
          title: 'Photo',
          actions: const [_discard, _keep],
          anchor: anchor,
        );

    testWidgets('points at the tapped widget; never preferred', (
      tester,
    ) async {
      final fake = installFakeNative()
        ..dialogAnswers.add(const LiquidNativeDialogChose(0));
      final answers = await _launcher(tester, sheet);
      await _open(tester);
      final request = fake.dialogRequests.single;
      expect(request.kind, LiquidNativeDialogKind.actionSheet);
      expect(request.anchor, tester.getRect(find.byKey(const Key('open'))));
      expect(request.preferredIndex, isNull);
      expect(answers, [_Pick.discard]);
    });

    testWidgets('an explicit anchor wins', (tester) async {
      final fake = installFakeNative()
        ..dialogAnswers.add(const LiquidNativeDialogChose(1));
      const anchor = Rect.fromLTWH(1, 2, 3, 4);
      await _launcher(tester, (b) => sheet(b, anchor: anchor));
      await _open(tester);
      expect(fake.dialogRequests.single.anchor, anchor);
    });
  });

  group('validation', () {
    testWidgets('throws before anything is shown', (tester) async {
      final fake = installFakeNative();
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(
        () => showLiquidAlert<int>(context, title: 'T', actions: const []),
        throwsArgumentError,
      );
      expect(
        () => showLiquidAlert(
          context,
          title: ' ',
          actions: const [LiquidAlertAction(label: 'OK', value: 1)],
        ),
        throwsArgumentError,
      );
      expect(
        () => showLiquidActionSheet(context, actions: const [_keep, _keep]),
        throwsArgumentError,
      );
      expect(fake.dialogRequests, isEmpty);
    });
  });

  group('native chrome (spec P3a §8)', () {
    Widget shell(Widget body, {Future<bool> Function(int)? guard, ValueChanged<int>? onSelect}) =>
        MaterialApp(
          home: LiquidShell(
            destinations: const [
              LiquidDestination(
                icon: Icon(Icons.home),
                label: 'Home',
                sfSymbol: 'house',
              ),
              LiquidDestination(
                icon: Icon(Icons.inbox),
                label: 'Inbox',
                sfSymbol: 'tray',
              ),
            ],
            selectedIndex: 0,
            beforeDestinationChange: guard,
            onDestinationSelected: onSelect ?? (_) {},
            body: body,
          ),
        );

    testWidgets('a native alert leaves the compact native bar alone', (
      tester,
    ) async {
      final fake = installFakeNative(
        state: const LiquidNativeShellState(installed: true, compact: true),
      )..dialogGate = Completer();
      await tester.pumpWidget(
        shell(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => _alert(context),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = fake.configs.length;
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(fake.dialogRequests, hasLength(1));
      // No Flutter route above the shell: nothing changes natively.
      expect(fake.configs.length, before);
      expect(fake.last.interactive, isTrue);
      expect(fake.last.hidden, isFalse);
      fake.dialogGate!.complete(const LiquidNativeDialogChose(0));
      await tester.pumpAndSettle();
    });

    testWidgets('the Flutter fallback still hides the compact bar (P2)', (
      tester,
    ) async {
      final fake = installFakeNative(
        state: const LiquidNativeShellState(installed: true, compact: true),
      );
      await tester.pumpWidget(
        shell(
          Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  _alert(context, presentation: LiquidDialogPresentation.flutter),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(fake.last.hidden, isTrue);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(fake.last.hidden, isFalse);
    });

    testWidgets('a native tap guarded by a native alert moves on "Discard"', (
      tester,
    ) async {
      final fake = installFakeNative()..dialogGate = Completer();
      final selected = <int>[];
      late BuildContext page;
      await tester.pumpWidget(
        shell(
          Builder(
            builder: (context) {
              page = context;
              return const SizedBox();
            },
          ),
          guard: (index) async =>
              (await showLiquidAlert<bool>(
                page,
                title: 'Discard changes?',
                actions: const [
                  LiquidAlertAction(
                    label: 'Keep editing',
                    value: false,
                    style: LiquidAlertActionStyle.cancel,
                  ),
                  LiquidAlertAction(
                    label: 'Discard',
                    value: true,
                    style: LiquidAlertActionStyle.destructive,
                  ),
                ],
              )) ??
              false,
          onSelect: selected.add,
        ),
      );
      await tester.pumpAndSettle();
      fake.emitNative(const LiquidNativeDestinationTapped(1));
      await tester.pumpAndSettle();
      expect(fake.dialogRequests.single.title, 'Discard changes?');
      expect(fake.last.interactive, isFalse);
      fake.dialogGate!.complete(const LiquidNativeDialogChose(1));
      await tester.pumpAndSettle();
      expect(selected, [1]);
    });
  });
}
```

- [ ] **Step 3: Run them to see them fail**

Run: `cd liquid_shell && fvm flutter test test/unit/dialog_plan_test.dart test/widget/liquid_dialogs_test.dart`
Expected: compile errors, `Undefined name 'showLiquidAlert'` and `Undefined class 'LiquidAlertAction'`.

- [ ] **Step 4: Write the public types**

`liquid_shell/lib/src/dialogs/dialog_types.dart`:

```dart
import 'package:flutter/foundation.dart';

/// How an alert or action-sheet action looks. The platform decides where
/// a cancel action sits.
enum LiquidAlertActionStyle {
  /// A plain action.
  standard,

  /// The cancel action: at most one per dialog. A dismissal without a
  /// choice completes with its value.
  cancel,

  /// A destructive action, drawn in the error colour.
  destructive,
}

/// One button of `showLiquidAlert` or `showLiquidActionSheet`. The dialog's
/// future completes with [value] when the user picks it.
@immutable
class LiquidAlertAction<T> {
  /// Creates an action.
  const LiquidAlertAction({
    required this.label,
    required this.value,
    this.style = LiquidAlertActionStyle.standard,
    this.preferred = false,
    this.enabled = true,
  });

  /// The button's text.
  final String label;

  /// What the dialog completes with when this action is picked.
  final T value;

  /// How it looks.
  final LiquidAlertActionStyle style;

  /// Alerts only: emphasised, and chosen by Return. Action sheets ignore
  /// it, as UIKit does. At most one per dialog.
  final bool preferred;

  /// Whether it can be picked.
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      other is LiquidAlertAction<T> &&
      other.label == label &&
      other.value == value &&
      other.style == style &&
      other.preferred == preferred &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(label, value, style, preferred, enabled);
}

/// Who draws a dialog.
enum LiquidDialogPresentation {
  /// The platform's own dialog where it has Liquid Glass (iOS 26 and
  /// later); the Flutter glass dialog everywhere else.
  auto,

  /// The platform's own dialog wherever it has one: UIKit's alert on every
  /// iOS, without glass before 26. Flutter glass elsewhere.
  system,

  /// Always the Flutter glass dialog.
  flutter,
}
```


- [ ] **Step 5: Write the plan helpers**

`liquid_shell/lib/src/dialogs/dialog_plan.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell/src/dialogs/dialog_types.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// Throws [ArgumentError] for actions UIKit would crash on or draw blank:
/// none, more than one cancel action, more than one preferred action, a
/// blank label (spec P3a §4.2).
void checkAlertActions<T>(List<LiquidAlertAction<T>> actions) {
  if (actions.isEmpty) {
    throw ArgumentError.value(actions, 'actions', 'needs at least one action');
  }
  final cancels = actions
      .where((a) => a.style == LiquidAlertActionStyle.cancel)
      .length;
  if (cancels > 1) {
    throw ArgumentError.value(actions, 'actions', 'at most one cancel action');
  }
  if (actions.where((a) => a.preferred).length > 1) {
    throw ArgumentError.value(actions, 'actions', 'at most one preferred action');
  }
  if (actions.any((a) => a.label.trim().isEmpty)) {
    throw ArgumentError.value(actions, 'actions', 'every label needs text');
  }
}

/// The value for a dialog that ended on [index], or without a choice
/// (null): then the cancel action's value, or null without one.
T? dialogValue<T>(List<LiquidAlertAction<T>> actions, int? index) {
  if (index != null && index >= 0 && index < actions.length) {
    return actions[index].value;
  }
  for (final action in actions) {
    if (action.style == LiquidAlertActionStyle.cancel) return action.value;
  }
  return null;
}

/// [context]'s render box in global logical coordinates (the Flutter
/// view's points), or null before layout.
Rect? anchorOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  final rect = Rect.fromPoints(
    box.localToGlobal(Offset.zero),
    box.localToGlobal(box.size.bottomRight(Offset.zero)),
  );
  return rect.isFinite ? rect : null;
}

/// The request for a dialog, read from [context] before any await.
LiquidNativeDialogRequest dialogRequestFor<T>(
  BuildContext context, {
  required LiquidNativeDialogKind kind,
  required List<LiquidAlertAction<T>> actions,
  required LiquidDialogPresentation presentation,
  String? title,
  String? message,
  Rect? anchor,
}) {
  final theme = Theme.of(context);
  final preferred = actions.indexWhere((a) => a.preferred);
  return LiquidNativeDialogRequest(
    kind: kind,
    title: title,
    message: message,
    actions: [
      for (final action in actions)
        LiquidNativeDialogAction(
          label: action.label,
          style: switch (action.style) {
            LiquidAlertActionStyle.standard =>
              LiquidNativeDialogActionStyle.standard,
            LiquidAlertActionStyle.cancel =>
              LiquidNativeDialogActionStyle.cancel,
            LiquidAlertActionStyle.destructive =>
              LiquidNativeDialogActionStyle.destructive,
          },
          enabled: action.enabled,
        ),
    ],
    preferredIndex: kind == LiquidNativeDialogKind.alert && preferred >= 0
        ? preferred
        : null,
    anchor: anchor != null && anchor.isFinite ? anchor : null,
    tintArgb: theme.colorScheme.primary.toARGB32(),
    dark: theme.brightness == Brightness.dark,
    rtl: Directionality.of(context) == TextDirection.rtl,
    requireGlass: presentation != LiquidDialogPresentation.system,
  );
}

/// Refusals that cannot change while the process runs (spec P3a §6):
/// later calls skip the channel and draw Flutter at once.
final class NativeDialogMemory {
  NativeDialogMemory._();

  /// The memory. Replaced by [debugReset].
  static NativeDialogMemory instance = NativeDialogMemory._();

  /// Forgets everything. Tests, through `debugResetLiquidNative`.
  static void debugReset() => instance = NativeDialogMemory._();

  bool _osTooOld = false;
  bool _disabled = false;

  /// Whether a request with [requireGlass] is known to be refused.
  bool refuses({required bool requireGlass}) =>
      _disabled || (requireGlass && _osTooOld);

  /// Remembers [reason] if it is permanent.
  void remember(
    LiquidNativeDialogUnavailableReason reason, {
    required bool requireGlass,
  }) {
    switch (reason) {
      case LiquidNativeDialogUnavailableReason.osTooOld:
        if (requireGlass) _osTooOld = true;
      case LiquidNativeDialogUnavailableReason.disabledByEnvironment:
        _disabled = true;
      case LiquidNativeDialogUnavailableReason.unsupportedPlatform ||
          LiquidNativeDialogUnavailableReason.noWindow ||
          LiquidNativeDialogUnavailableReason.refused ||
          LiquidNativeDialogUnavailableReason.channelError:
        break;
    }
  }
}
```

In `liquid_shell/lib/src/native/native_reset.dart`, add `import 'package:liquid_shell/src/dialogs/dialog_plan.dart';` and the call `NativeDialogMemory.debugReset();` as the last line of `debugResetLiquidNative`. Extend its doc comment: "…, and the remembered native dialog refusals".

- [ ] **Step 6: Write the two functions**

`liquid_shell/lib/src/dialogs/show_dialogs.dart`:

```dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/dialogs/dialog_plan.dart';
import 'package:liquid_shell/src/dialogs/dialog_types.dart';
import 'package:liquid_shell/src/dialogs/glass_dialogs.dart';
import 'package:liquid_shell/src/shell/strings.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// Shows an alert and completes with the chosen action's value.
///
/// On iOS 26 and later this is the system's `UIAlertController`, above any
/// native chrome. Elsewhere, or with [presentation] set to
/// [LiquidDialogPresentation.flutter], it is a Flutter glass alert (spec
/// P3a). [title], [message] and every label come from the app.
///
/// Completes with the cancel action's value (or null without one) when
/// the alert closes without a choice (Escape, Android back, a dismissal by
/// the system), and with null if it could never be shown. Throws
/// [ArgumentError] at once for no actions, two cancel or two preferred
/// actions, a blank label or a blank [title].
Future<T?> showLiquidAlert<T>(
  BuildContext context, {
  required String title,
  required List<LiquidAlertAction<T>> actions,
  String? message,
  LiquidDialogPresentation presentation = LiquidDialogPresentation.auto,
}) {
  if (title.trim().isEmpty) {
    throw ArgumentError.value(title, 'title', 'must not be blank');
  }
  checkAlertActions(actions);
  return _present(
    context,
    actions: actions,
    presentation: presentation,
    strings: const LiquidShellStrings(),
    request: dialogRequestFor(
      context,
      kind: LiquidNativeDialogKind.alert,
      title: title,
      message: message,
      actions: actions,
      presentation: presentation,
    ),
  );
}

/// Shows an action sheet and completes with the chosen action's value.
///
/// On iPad, and in the Flutter fallback at regular width, the sheet points
/// at [anchor] (global logical coordinates); when [anchor] is null it
/// points at [context]'s render box. So pass the tapped widget's context,
/// for example from a `Builder` around the button. A tap outside completes
/// with the cancel action's value, or null without one. [strings] labels
/// the fallback's barrier for screen readers.
Future<T?> showLiquidActionSheet<T>(
  BuildContext context, {
  required List<LiquidAlertAction<T>> actions,
  String? title,
  String? message,
  Rect? anchor,
  LiquidDialogPresentation presentation = LiquidDialogPresentation.auto,
  LiquidShellStrings strings = const LiquidShellStrings(),
}) {
  checkAlertActions(actions);
  return _present(
    context,
    actions: actions,
    presentation: presentation,
    strings: strings,
    request: dialogRequestFor(
      context,
      kind: LiquidNativeDialogKind.actionSheet,
      title: title,
      message: message,
      actions: actions,
      presentation: presentation,
      anchor: anchor ?? anchorOf(context),
    ),
  );
}

/// Native first; the Flutter glass dialog when the platform has none,
/// refuses, or [presentation] asks for Flutter.
Future<T?> _present<T>(
  BuildContext context, {
  required LiquidNativeDialogRequest request,
  required List<LiquidAlertAction<T>> actions,
  required LiquidDialogPresentation presentation,
  required LiquidShellStrings strings,
}) async {
  final platform = LiquidShellPlatform.instance;
  final memory = NativeDialogMemory.instance;
  if (presentation != LiquidDialogPresentation.flutter &&
      platform.supportsNativeDialogs &&
      !memory.refuses(requireGlass: request.requireGlass)) {
    switch (await platform.presentNativeDialog(request)) {
      case LiquidNativeDialogChose(:final index):
        return dialogValue(actions, index);
      case LiquidNativeDialogDismissed():
        return dialogValue(actions, null);
      case LiquidNativeDialogUnavailable(:final reason):
        memory.remember(reason, requireGlass: request.requireGlass);
    }
    if (!context.mounted) return null;
  }
  final index = await showGlassDialog(context, request, strings: strings);
  return dialogValue(actions, index);
}
```

In `liquid_shell/lib/liquid_shell.dart`, add (alphabetical, after `src/destinations/tab_action.dart`):

```dart
export 'src/dialogs/dialog_types.dart';
export 'src/dialogs/show_dialogs.dart'
    show showLiquidActionSheet, showLiquidAlert;
```

- [ ] **Step 7: Run the tests to see them pass**

Run: `cd liquid_shell && fvm flutter test test/unit/dialog_plan_test.dart test/widget/liquid_dialogs_test.dart`
Expected: `All tests passed!`
Run: `cd liquid_shell && fvm flutter test --exclude-tags golden && cd .. && make coverage`
Expected: every test passes, and every covered package stays ≥ 90 %.

- [ ] **Step 8: Commit**

```bash
bash .githooks/pre-commit && \
git add liquid_shell/lib/src/dialogs/dialog_types.dart \
  liquid_shell/lib/src/dialogs/dialog_plan.dart \
  liquid_shell/lib/src/dialogs/show_dialogs.dart \
  liquid_shell/lib/src/native/native_reset.dart liquid_shell/lib/liquid_shell.dart \
  liquid_shell/test/helpers/fake_native_platform.dart \
  liquid_shell/test/unit/dialog_plan_test.dart \
  liquid_shell/test/widget/liquid_dialogs_test.dart && \
git commit -m "feat(shell): showLiquidAlert and showLiquidActionSheet, native first (VK-406)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Example — the alerts case, native guard, goldens, README

**Files:**
- Create: `liquid_shell/example/lib/cases/native_alerts.dart`
- Modify: `liquid_shell/example/lib/cases/discard_guard.dart`, `liquid_shell/example/lib/cases/native_chrome.dart` (`_confirmLeave`)
- Modify: `liquid_shell/example/lib/cases/cases.dart` (entry `alerts`), `liquid_shell/example/lib/main.dart` (`LIQUID_SHELL_EXAMPLE_DEMO`)
- Modify: `liquid_shell/example/test/cases_smoke_test.dart`, `liquid_shell/example/test/goldens/cases_test.dart`
- Modify: `liquid_shell/README.md` (guard snippet, new section)
- Regenerate: `liquid_shell/doc/images/case_guard.png`; create `case_alert.png`, `case_action_sheet.png` (`make goldens-update`)

**Interfaces:**
- Consumes (Task 5): `showLiquidAlert`, `showLiquidActionSheet`, `LiquidAlertAction`, `LiquidAlertActionStyle`, `LiquidDialogPresentation`.
- Produces (used by Task 7):
  - `NativeAlertsCase({String? autorun})`, `enum DemoChoice { keep, discard, save, delete, share, duplicate, cancel }`;
  - on-screen texts `Alert`, `Three actions`, `Action sheet`, `Action sheet without cancel`, `Draw with Flutter liquid`, `Result: <choice|none>`;
  - native labels `Discard changes?` / `Keep editing` / `Discard`, `Photo` / `Delete photo` / `Share` / `Cancel`;
  - `ExampleApp({String? demo})`. With `demo` set, home is `NativeAlertsCase(autorun: demo)`. `main()` reads `LIQUID_SHELL_EXAMPLE_DEMO` from the process environment. Autorun values: `alert`, `sheet`. Each answers with a native alert titled `Result: <choice|none>` with one action `OK`.

- [ ] **Step 1: Write the failing smoke tests**

Append inside `main()` of `liquid_shell/example/test/cases_smoke_test.dart`:

```dart
  testWidgets('the alerts case answers through the Flutter glass alert', (
    tester,
  ) async {
    await _openCase(tester, 'alerts');
    await tester.tap(find.text('Alert'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Result: discard'), findsOneWidget);
  });

  testWidgets('a tap outside the action sheet answers its cancel value', (
    tester,
  ) async {
    await _openCase(tester, 'alerts');
    await tester.tap(find.text('Action sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Delete photo'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Result: cancel'), findsOneWidget);
  });

  testWidgets('autorun shows the alert by itself, then the result', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp(demo: 'alert'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Result: keep'), findsWidgets);
  });
```

The `phone` and `tablet` loop already opens every entry of `kCases`, so it covers `alerts` once the entry exists. The two existing guard tests keep their texts and pass through the Flutter fallback.

- [ ] **Step 2: Run them to see them fail**

Run: `cd liquid_shell/example && fvm flutter test test/cases_smoke_test.dart`
Expected: FAIL. `alerts` has no row (`find.byKey(ValueKey('case-alerts'))` finds nothing), and `ExampleApp` has no `demo` parameter (compile error).

- [ ] **Step 3: Write the case**

`liquid_shell/example/lib/cases/native_alerts.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// What the demo dialogs answer.
enum DemoChoice { keep, discard, save, delete, share, duplicate, cancel }

/// Native alerts and action sheets: the system's `UIAlertController` on
/// iOS 26 (above the native tab bar), the Flutter glass dialog elsewhere.
/// "Draw with Flutter liquid" draws the Flutter dialog everywhere, to
/// compare the two on one device.
class NativeAlertsCase extends StatefulWidget {
  /// Creates the case.
  const NativeAlertsCase({this.autorun, super.key});

  /// A demo to run once after the first frame (`alert` or `sheet`), whose
  /// answer is shown in a second alert, "Result: …". UI tests use it: they
  /// can read native alerts without Flutter's semantics.
  final String? autorun;

  @override
  State<NativeAlertsCase> createState() => _NativeAlertsCaseState();
}

class _NativeAlertsCaseState extends State<NativeAlertsCase> {
  static const _destinations = [
    LiquidDestination(
      icon: Icon(Icons.chat_bubble_outline),
      label: 'Alerts',
      sfSymbol: 'exclamationmark.bubble',
    ),
    LiquidDestination(
      icon: Icon(Icons.settings_outlined),
      label: 'Settings',
      sfSymbol: 'gear',
    ),
  ];

  final _sheetButton = GlobalKey();
  int _index = 0;
  bool _flutter = false;
  String _result = 'Result: none';

  LiquidDialogPresentation get _presentation => _flutter
      ? LiquidDialogPresentation.flutter
      : LiquidDialogPresentation.auto;

  @override
  void initState() {
    super.initState();
    final demo = widget.autorun;
    if (demo != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autorun(demo));
    }
  }

  Future<void> _autorun(String demo) async {
    final choice = demo == 'sheet'
        ? await _actionSheet(_sheetButton.currentContext!)
        : await _alert();
    if (!mounted) return;
    await showLiquidAlert<bool>(
      context,
      title: _label(choice),
      actions: const [LiquidAlertAction(label: 'OK', value: true)],
    );
  }

  String _label(DemoChoice? choice) => 'Result: ${choice?.name ?? 'none'}';

  Future<void> _show(Future<DemoChoice?> Function() dialog) async {
    final choice = await dialog();
    if (mounted) setState(() => _result = _label(choice));
  }

  // #docregion readme
  Future<DemoChoice?> _alert() => showLiquidAlert<DemoChoice>(
    context,
    title: 'Discard changes?',
    message: 'Your edits will be lost.',
    actions: const [
      LiquidAlertAction(
        label: 'Keep editing',
        value: DemoChoice.keep,
        style: LiquidAlertActionStyle.cancel,
      ),
      LiquidAlertAction(
        label: 'Discard',
        value: DemoChoice.discard,
        style: LiquidAlertActionStyle.destructive,
      ),
    ],
    presentation: _presentation,
  );

  // Pass the tapped button's context: on iPad the sheet points at it.
  Future<DemoChoice?> _actionSheet(BuildContext button) =>
      showLiquidActionSheet<DemoChoice>(
        button,
        title: 'Photo',
        actions: const [
          LiquidAlertAction(
            label: 'Delete photo',
            value: DemoChoice.delete,
            style: LiquidAlertActionStyle.destructive,
          ),
          LiquidAlertAction(label: 'Share', value: DemoChoice.share),
          LiquidAlertAction(
            label: 'Cancel',
            value: DemoChoice.cancel,
            style: LiquidAlertActionStyle.cancel,
          ),
        ],
        presentation: _presentation,
      );
  // #enddocregion readme

  Future<DemoChoice?> _threeActions() => showLiquidAlert<DemoChoice>(
    context,
    title: 'Save changes?',
    message: 'You can keep them for later.',
    actions: const [
      LiquidAlertAction(
        label: 'Save',
        value: DemoChoice.save,
        preferred: true,
      ),
      LiquidAlertAction(
        label: "Don't save",
        value: DemoChoice.discard,
        style: LiquidAlertActionStyle.destructive,
      ),
      LiquidAlertAction(
        label: 'Cancel',
        value: DemoChoice.cancel,
        style: LiquidAlertActionStyle.cancel,
      ),
    ],
    presentation: _presentation,
  );

  Future<DemoChoice?> _noCancelSheet(BuildContext button) =>
      showLiquidActionSheet<DemoChoice>(
        button,
        actions: const [
          LiquidAlertAction(label: 'Share', value: DemoChoice.share),
          LiquidAlertAction(label: 'Duplicate', value: DemoChoice.duplicate),
        ],
        presentation: _presentation,
      );

  @override
  Widget build(BuildContext context) => LiquidShell(
    destinations: _destinations,
    selectedIndex: _index,
    onDestinationSelected: (i) => setState(() => _index = i),
    body: DemoPage(
      title: _destinations[_index].label,
      children: [
        SwitchListTile(
          title: const Text('Draw with Flutter liquid'),
          subtitle: const Text('Off: the system draws it on iOS 26'),
          value: _flutter,
          onChanged: (value) => setState(() => _flutter = value),
        ),
        ListTile(title: const Text('Alert'), onTap: () => _show(_alert)),
        ListTile(
          title: const Text('Three actions'),
          onTap: () => _show(_threeActions),
        ),
        Builder(
          key: _sheetButton,
          builder: (button) => ListTile(
            title: const Text('Action sheet'),
            onTap: () => _show(() => _actionSheet(button)),
          ),
        ),
        Builder(
          builder: (button) => ListTile(
            title: const Text('Action sheet without cancel'),
            onTap: () => _show(() => _noCancelSheet(button)),
          ),
        ),
        ListTile(title: Text(_result)),
      ],
    ),
  );
}
```

In `cases.dart`, import it and add after the `guard` entry:

```dart
  (
    id: 'alerts',
    title: 'Alerts and action sheets',
    subtitle: 'Native on iOS 26, Flutter glass elsewhere',
    page: NativeAlertsCase(),
  ),
```

In `main.dart`:

```dart
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:liquid_shell_example/cases/cases.dart';
import 'package:liquid_shell_example/cases/native_alerts.dart';

void main() => runApp(
  ExampleApp(demo: Platform.environment['LIQUID_SHELL_EXAMPLE_DEMO']),
);
```

and give `ExampleApp` the field:

```dart
  /// Creates the app. With [demo], it opens straight on the alerts case and
  /// runs that demo (UI tests, spec P3a §9.4).
  const ExampleApp({this.demo, super.key});

  /// `alert` or `sheet`; null shows the case list.
  final String? demo;
```

and `home: demo == null ? const CaseList() : NativeAlertsCase(autorun: demo),`.

- [ ] **Step 4: Move both guards to `showLiquidAlert`**

In `discard_guard.dart` (inside `// #docregion readme`) and in `native_chrome.dart`, replace `_confirmLeave`'s body after the early return with:

```dart
    final discard = await showLiquidAlert<bool>(
      context,
      title: 'Discard changes?',
      actions: const [
        LiquidAlertAction(
          label: 'Keep editing',
          value: false,
          style: LiquidAlertActionStyle.cancel,
        ),
        LiquidAlertAction(
          label: 'Discard',
          value: true,
          style: LiquidAlertActionStyle.destructive,
        ),
      ],
    );
    return discard ?? false;
```

- [ ] **Step 5: Run the tests to see them pass**

Run: `cd liquid_shell/example && fvm flutter test --exclude-tags golden`
Expected: `All tests passed!` (`alerts` on phone and tablet, the three new tests, both guard tests through the fallback).

- [ ] **Step 6: Goldens**

Add to `liquid_shell/example/test/goldens/cases_test.dart` (import `native_alerts.dart`):

```dart
  testWidgets('case_alert', (tester) async {
    await golden(
      tester,
      'case_alert',
      const NativeAlertsCase(),
      interact: () => tester.tap(find.text('Alert')),
    );
  });

  testWidgets('case_action_sheet', (tester) async {
    await golden(
      tester,
      'case_action_sheet',
      const NativeAlertsCase(),
      device: ipadPortrait,
      interact: () => tester.tap(find.text('Action sheet')),
    );
  });
```

Run: `make goldens-update`
Expected: `✓ goldens and doc images updated`. `git status` shows `case_guard.png` changed (glass alert instead of the Material one), and `case_alert.png` and `case_action_sheet.png` new. Open all three and check: a glass card, readable text, cancel leading in the guard. Then `make goldens` passes.

- [ ] **Step 7: README**

In `liquid_shell/README.md`:
1. Run `dart run tool/check_readme_snippets.dart --fix` from the repo root. The guard snippet follows the new `docregion`.
2. After the guard section, add:

````markdown
### Alerts and action sheets

`showLiquidAlert` and `showLiquidActionSheet` complete with the value of the
action the user picked. On iOS 26 and later they are the system's own
`UIAlertController`, with Liquid Glass, above the native tab bar and
sidebar. On Android and on iOS before 26 they are drawn by Flutter, with the
same glass as the shell (`LiquidGlass`). Pass
`presentation: LiquidDialogPresentation.flutter` to draw Flutter everywhere,
or `.system` for UIKit's alert on every iOS.

<?code-excerpt "native_alerts.dart (readme)"?>
```dart
```

| | iOS 26+ | iOS 15–25 | Android |
|---|---|---|---|
| `auto` (default) | `UIAlertController` (glass) | Flutter glass | Flutter glass |
| `system` | `UIAlertController` (glass) | `UIAlertController` | Flutter glass |
| `flutter` | Flutter glass | Flutter glass | Flutter glass |

- A tap outside an action sheet, Escape or Android back completes with the
  cancel action's value, or null without one.
- At most one `cancel` and one `preferred` action. A blank label or none
  at all throws `ArgumentError`.
- Every visible string is yours. The Flutter sheet's barrier uses
  `LiquidShellStrings.dismiss` for screen readers.

<img src="doc/images/case_alert.png" width="260" alt="Glass alert">
<img src="doc/images/case_action_sheet.png" width="360" alt="Glass action sheet at its button">
````

Then run `dart run tool/check_readme_snippets.dart --fix` again to fill the empty block, and `make snippets`.
Expected: `make snippets` passes.

- [ ] **Step 8: Commit**

```bash
bash .githooks/pre-commit && make snippets && make goldens && \
git add liquid_shell/example/lib/cases/native_alerts.dart \
  liquid_shell/example/lib/cases/discard_guard.dart \
  liquid_shell/example/lib/cases/native_chrome.dart \
  liquid_shell/example/lib/cases/cases.dart liquid_shell/example/lib/main.dart \
  liquid_shell/example/test/cases_smoke_test.dart \
  liquid_shell/example/test/goldens/cases_test.dart \
  liquid_shell/README.md liquid_shell/doc/images/case_guard.png \
  liquid_shell/doc/images/case_alert.png liquid_shell/doc/images/case_action_sheet.png && \
git commit -m "feat(example): alerts case and the guard on showLiquidAlert (VK-406)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Simulator integration, XCUITest real taps, scripts and CI

**Files:**
- Create: `liquid_shell/example/integration_test/native_dialogs_test.dart`
- Modify: `liquid_shell/example/integration_test/native_shell_test.dart` (the guard test)
- Modify: `tool/integration_ios_native.sh` (drive both targets)
- Create: `liquid_shell/example/ios/RunnerUITests/RunnerUITests.swift`
- Modify (generated by a one-off script, not committed): `liquid_shell/example/ios/Runner.xcodeproj/project.pbxproj`, `liquid_shell/example/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`
- Modify: `Makefile` (`ios-ui`), `.github/workflows/ci.yaml` (`ios-ui` job)

**Interfaces:**
- Consumes: Task 2 (`LiquidShellIOS.debugNativeDialog`, `debugRespondToNativeDialog`, `NativeDialogDebugSnapshot`), Task 3 (presenter), Task 6 (`NativeAlertsCase`, texts and labels, `LIQUID_SHELL_EXAMPLE_DEMO`).
- Produces: `make ios-ui IOS_UNIT_DEVICE=<udid>`. `tool/integration_ios_native.sh` drives `native_shell_test.dart` and `native_dialogs_test.dart`. The CI job `ios-ui` (non-blocking).

- [ ] **Step 1: Write the integration test**

`liquid_shell/example/integration_test/native_dialogs_test.dart`:

```dart
// Native alerts and action sheets on a real simulator (spec P3a §9.4).
//
// tool/integration_ios_native.sh runs it beside native_shell_test.dart on
// an iPad and an iPhone with iOS 26 (EXPECT_NATIVE=true). Taps go through
// the presenter's debug hooks; real UIKit taps are RunnerUITests (XCUITest).
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/native_alerts.dart';
import 'package:liquid_shell_ios/liquid_shell_ios.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

const _expectNative = bool.fromEnvironment('EXPECT_NATIVE');
const _runName = String.fromEnvironment('RUN_NAME', defaultValue: 'run');

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

/// The real iOS platform, also recording every chrome config sent.
class _RecordingIOS extends LiquidShellIOS {
  final configs = <LiquidNativeChromeConfig>[];

  @override
  Future<void> updateNativeChrome(LiquidNativeChromeConfig config) {
    configs.add(config);
    return super.updateNativeChrome(config);
  }
}

/// Waits for the presenter to show a dialog (UIKit animates it in).
Future<NativeDialogDebugSnapshot> _shown(
  WidgetTester tester,
  LiquidShellIOS ios,
) async {
  for (var i = 0; i < 50; i++) {
    final shot = await ios.debugNativeDialog();
    if (shot != null) return shot;
    await tester.pump(const Duration(milliseconds: 100));
  }
  fail('no native dialog appeared');
}

const _app = MaterialApp(
  debugShowCheckedModeBanner: false,
  home: NativeAlertsCase(),
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (LiquidShellPlatform.instance is LiquidShellIOS) {
    LiquidShellPlatform.instance = _RecordingIOS();
  }
  _RecordingIOS ios() => LiquidShellPlatform.instance as _RecordingIOS;

  testWidgets('a native alert answers its value and leaves the chrome alone', (
    tester,
  ) async {
    if (!_expectNative) return;
    final states = <AppLifecycleState>[];
    final listener = AppLifecycleListener(onStateChange: states.add);
    addTearDown(listener.dispose);
    await tester.pumpWidget(_app);
    await _settle(tester);

    await tester.tap(find.text('Alert'));
    final shot = await _shown(tester, ios());
    expect(shot.actionSheet, isFalse);
    expect(shot.title, 'Discard changes?');
    expect(shot.message, 'Your edits will be lost.');
    expect(shot.labels, ['Keep editing', 'Discard']);
    // Drawn by UIKit, not Flutter; the native chrome is untouched.
    expect(find.text('Your edits will be lost.'), findsNothing);
    expect(ios().configs.last.interactive, isTrue);
    expect(ios().configs.last.hidden, isFalse);
    await binding.takeScreenshot('dialogs_${_runName}_alert');

    await ios().debugRespondToNativeDialog(1);
    await _settle(tester);
    expect(find.text('Result: discard'), findsOneWidget);
    expect(await ios().debugNativeDialog(), isNull);
    expect(states, isNot(contains(AppLifecycleState.inactive)));
  });

  testWidgets('an action sheet points at its button; outside is cancel', (
    tester,
  ) async {
    if (!_expectNative) return;
    await tester.pumpWidget(_app);
    await _settle(tester);
    final button = tester.getRect(
      find.ancestor(
        of: find.text('Action sheet'),
        matching: find.byType(ListTile),
      ),
    );

    await tester.tap(find.text('Action sheet'));
    final shot = await _shown(tester, ios());
    expect(shot.actionSheet, isTrue);
    expect(shot.labels, ['Delete photo', 'Share', 'Cancel']);
    final source = shot.sourceRect;
    if (source != null) {
      expect(source.left, closeTo(button.left, 0.5));
      expect(source.top, closeTo(button.top, 0.5));
      expect(source.width, closeTo(button.width, 0.5));
      expect(source.height, closeTo(button.height, 0.5));
    }
    final tablet =
        MediaQuery.sizeOf(tester.element(find.byType(NativeAlertsCase)))
            .shortestSide >=
        600;
    if (tablet) expect(source, isNotNull);
    await binding.takeScreenshot('dialogs_${_runName}_sheet');

    await ios().debugRespondToNativeDialog(-1);
    await _settle(tester);
    expect(find.text('Result: cancel'), findsOneWidget);
  });

  testWidgets('an answer can open a second native alert at once', (
    tester,
  ) async {
    if (!_expectNative) return;
    await tester.pumpWidget(
      const MaterialApp(home: NativeAlertsCase(autorun: 'alert')),
    );
    await _settle(tester);
    expect((await _shown(tester, ios())).title, 'Discard changes?');
    await ios().debugRespondToNativeDialog(0);
    await _settle(tester);
    expect((await _shown(tester, ios())).title, 'Result: keep');
    await ios().debugRespondToNativeDialog(0);
    await _settle(tester);
    expect(await ios().debugNativeDialog(), isNull);
  });

  testWidgets('Flutter liquid draws the glass alert; the chrome turns inert', (
    tester,
  ) async {
    await tester.pumpWidget(_app);
    await _settle(tester);
    await tester.tap(find.text('Draw with Flutter liquid'));
    await _settle(tester);
    await tester.tap(find.text('Alert'));
    await _settle(tester);
    expect(find.text('Your edits will be lost.'), findsOneWidget);
    if (_expectNative) {
      expect(await ios().debugNativeDialog(), isNull);
      final compact =
          LiquidShellScope.of(
            tester.element(find.text('Alert')),
          ).sizeClass ==
          LiquidSizeClass.compact;
      expect(ios().configs.last.interactive, isFalse);
      expect(ios().configs.last.hidden, compact);
    }
    await binding.takeScreenshot('dialogs_${_runName}_alert_flutter');
    await tester.tap(find.text('Discard'));
    await _settle(tester);
    expect(find.text('Result: discard'), findsOneWidget);
  });

  testWidgets('system presents UIKit\'s alert on every iOS', (tester) async {
    if (!Platform.isIOS) return;
    await tester.pumpWidget(_app);
    await _settle(tester);
    final context = tester.element(find.text('Alert'));
    final answer = showLiquidAlert<int>(
      context,
      title: 'System',
      actions: const [LiquidAlertAction(label: 'OK', value: 7)],
      presentation: LiquidDialogPresentation.system,
    );
    expect((await _shown(tester, ios())).title, 'System');
    await ios().debugRespondToNativeDialog(0);
    await _settle(tester);
    expect(await answer, 7);
  });
}
```

The last test also runs on an iOS 18 simulator (Task 8 Step 4), where `auto` falls back but `system` must still be native.

- [ ] **Step 2: Move the P2 guard test onto the native alert**

In `liquid_shell/example/integration_test/native_shell_test.dart`, inside `'a dirty page: a native tap asks first; keep stays, discard leaves'`, replace from `await recorder.debugTap(NativeTapTarget.destination, 1);` (the first one) to the end of the test with:

```dart
    await recorder.debugTap(NativeTapTarget.destination, 1);
    await _settle(tester);
    final guard = await recorder.debugNativeDialog();
    expect(guard?.title, 'Discard changes?');
    expect(guard?.labels, ['Keep editing', 'Discard']);
    // The body keeps its bottom padding.
    expect(bodyBottom(), bottom);
    // Inert while the guard runs; an overlay sidebar closed natively.
    expect(recorder.configs.last.interactive, isFalse);
    expect(recorder.configs.last.selectedIndex, 0);
    if (overlay) expect(_scope(tester).sidebarVisible, isFalse);
    // The native alert is above the compact bar, so the bar stays (spec
    // P3a §8); P2 hid it under a Flutter dialog.
    expect(recorder.configs.last.hidden, isFalse);
    await binding.takeScreenshot('native_${_runName}_guard');

    final beforeKeep = recorder.configs.length;
    await recorder.debugRespondToNativeDialog(0); // Keep editing
    await _settle(tester);
    expect(await recorder.debugNativeDialog(), isNull);
    expect(_title(tester), 'Home');
    expect(bodyBottom(), bottom);
    final resent = recorder.configs.sublist(beforeKeep);
    expect(resent, isNotEmpty);
    expect(resent.last.selectedIndex, 0);
    expect(resent.last.interactive, isTrue);

    await recorder.debugTap(NativeTapTarget.destination, 1);
    await _settle(tester);
    await recorder.debugRespondToNativeDialog(1); // Discard
    await _settle(tester);
    expect(_title(tester), 'Inbox');
    expect(recorder.configs.last.selectedIndex, 1);
    expect(recorder.configs.last.interactive, isTrue);
  });
```

Delete the now-unused local `compact` from that test. Update the comment above the test: "the app's native alert answers".

- [ ] **Step 3: Drive both targets**

In `tool/integration_ios_native.sh`, add under the variable docs:

```bash
# NATIVE_TARGETS  space-separated integration tests to drive on each device
#                 (default "native_shell_test.dart native_dialogs_test.dart").
```

and `NATIVE_TARGETS=${NATIVE_TARGETS:-native_shell_test.dart native_dialogs_test.dart}` beside the other defaults. Change `drive` to take the target as a fourth argument (`--target=integration_test/$4`) and the per-device body to loop:

```bash
  for target in $NATIVE_TARGETS; do
    echo "▸ $name: $target"
    status=0
    drive "$udid" "$expect" "$run" "$target" || status=$?
    if [ "$status" -eq 124 ]; then
      echo "▸ flutter drive stalled; restarting $name and retrying once" >&2
      xcrun simctl shutdown "$udid" 2>/dev/null || true
      boot "$udid"
      status=0
      drive "$udid" "$expect" "$run" "$target" || status=$?
    fi
    [ "$status" -eq 0 ] || exit "$status"
  done
```

- [ ] **Step 4: Run the integration on both simulators**

Run: `NATIVE_DEVICES="$IPAD_UDID=true;$IPHONE_UDID=true" make integration-ios-native`
Expected: `✓ native shell integration passed`, with every test of both files passing on both devices. Screenshots `dialogs_*_alert.png`, `dialogs_*_sheet.png` and `dialogs_*_alert_flutter.png` appear in `liquid_shell/example/build/integration_screenshots/`. Open `dialogs_*_alert.png` and check that the native alert is drawn above the native tab bar. If the screenshot shows only Flutter content, note it in Task 8's QA doc and take the screenshot with `xcrun simctl io <udid> screenshot` during a paused run instead.

- [ ] **Step 5: Commit the integration**

```bash
bash .githooks/pre-commit && \
git add liquid_shell/example/integration_test/native_dialogs_test.dart \
  liquid_shell/example/integration_test/native_shell_test.dart \
  tool/integration_ios_native.sh && \
git commit -m "test(example): native dialogs on iPad and iPhone simulators; guard on the native alert (VK-406)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 6: Write the XCUITest**

`liquid_shell/example/ios/RunnerUITests/RunnerUITests.swift`:

```swift
import XCTest

/// Real taps on native dialogs (spec P3a §9.4). Launched with
/// LIQUID_SHELL_EXAMPLE_DEMO, the example shows the dialog by itself and
/// answers every choice with a second native alert, "Result: <value>",
/// which a UI test reads without Flutter's semantics. That covers tap →
/// UIKit handler → channel → Dart value → a new native presentation while
/// the first is still leaving.
final class NativeDialogUITests: XCTestCase {
  private let timeout: TimeInterval = 90

  override func setUp() {
    continueAfterFailure = false
  }

  private func launch(_ demo: String) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["LIQUID_SHELL_EXAMPLE_DEMO"] = demo
    app.launch()
    return app
  }

  private func expectResult(_ app: XCUIApplication, _ title: String) {
    let result = app.alerts[title]
    XCTAssertTrue(result.waitForExistence(timeout: 15), "no \"\(title)\" alert")
    result.buttons["OK"].tap()
    XCTAssertTrue(result.waitForNonExistence(timeout: 5))
  }

  func testTappingAnAlertButtonAnswersDart() {
    let app = launch("alert")
    let alert = app.alerts["Discard changes?"]
    XCTAssertTrue(alert.waitForExistence(timeout: timeout))
    alert.buttons["Discard"].tap()
    expectResult(app, "Result: discard")
  }

  func testTappingCancelAnswersTheCancelValue() {
    let app = launch("alert")
    let alert = app.alerts["Discard changes?"]
    XCTAssertTrue(alert.waitForExistence(timeout: timeout))
    alert.buttons["Keep editing"].tap()
    expectResult(app, "Result: keep")
  }

  func testTappingAnActionSheetButtonAnswersDart() {
    let app = launch("sheet")
    let delete = app.buttons["Delete photo"]
    XCTAssertTrue(delete.waitForExistence(timeout: timeout))
    delete.tap()
    expectResult(app, "Result: delete")
  }

  func testTappingOutsideAnActionSheetAnswersTheCancelValue() {
    let app = launch("sheet")
    XCTAssertTrue(app.buttons["Delete photo"].waitForExistence(timeout: timeout))
    // Near the bottom-trailing corner: outside the iPad popover, which
    // points at a row near the top, and on the iPhone's dimming view.
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.15)).tap()
    expectResult(app, "Result: cancel")
  }
}
```

`waitForNonExistence(timeout:)` needs Xcode 16 or later; the toolchain is Xcode 27.

- [ ] **Step 7: Add the `RunnerUITests` target (one-off script, not committed)**

Save as `$TMPDIR/add_ui_tests.rb` (the `xcodeproj` gem ships with CocoaPods; checked: 1.28.1):

```ruby
# One-off (spec P3a §9.4): adds the RunnerUITests UI-test target to the
# example's Xcode project and to the shared Runner scheme's test action.
require 'xcodeproj'

project_path = File.expand_path(ARGV.fetch(0))
project = Xcodeproj::Project.open(project_path)
abort('RunnerUITests already exists') if project.targets.any? { |t| t.name == 'RunnerUITests' }
app = project.targets.find { |t| t.name == 'Runner' } or abort('no Runner target')

target = project.new_target(:ui_test_bundle, 'RunnerUITests', :ios, '15.0')
group = project.main_group.find_subpath('RunnerUITests', true)
group.set_source_tree('<group>')
group.set_path('RunnerUITests')
target.add_file_references([group.new_reference('RunnerUITests.swift')])
target.add_dependency(app)
target.build_configurations.each do |config|
  settings = config.build_settings
  settings['TEST_TARGET_NAME'] = 'Runner'
  settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'vn.lasoai.liquidShellExample.RunnerUITests'
  settings['SWIFT_VERSION'] = '5.0'
  settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
  settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  settings['CODE_SIGN_STYLE'] = 'Automatic'
end
project.save

scheme_path = File.join(project_path, 'xcshareddata', 'xcschemes', 'Runner.xcscheme')
scheme = Xcodeproj::XCScheme.new(scheme_path)
scheme.add_test_target(target)
scheme.save!
puts 'RunnerUITests added'
```

Run: `ruby "$TMPDIR/add_ui_tests.rb" liquid_shell/example/ios/Runner.xcodeproj`
Expected: `RunnerUITests added`. `git diff --stat` touches only `project.pbxproj` and `Runner.xcscheme`. Then `command rm "$TMPDIR/add_ui_tests.rb"`. The Podfile does not change: UI tests run out of process and link no pod.

If the target cannot be built after Step 8 (the Flutter build phase, signing), stop and use the Q8 fallback. That is an idb script: `idb ui describe-all --udid` finds the alert button's frame, and `idb ui tap` taps it while `flutter drive` waits on `NativeAlertsCase(autorun:)`. Note the switch in the commit body, and tell the owner.

- [ ] **Step 8: `make ios-ui` and run it on both simulators**

In `Makefile`, add `ios-ui` to `.PHONY` and, after `ios-unit`:

```make
ios-ui: ## XCUITest: real taps on native dialogs (example RunnerUITests) on a simulator; IOS_UNIT_DEVICE=<udid>
	cd $(EXAMPLE) && $(FLUTTER) build ios --config-only --simulator --debug
	cd $(EXAMPLE)/ios && $(CURDIR)/tool/with_timeout.sh $(IOS_UNIT_TIMEOUT) \
	  xcodebuild test -workspace Runner.xcworkspace -scheme Runner \
	  -destination "id=$${IOS_UNIT_DEVICE:?set IOS_UNIT_DEVICE to a simulator UDID}" \
	  -only-testing:RunnerUITests -parallel-testing-enabled NO \
	  -collect-test-diagnostics never \
	  -test-timeouts-enabled YES -default-test-execution-time-allowance 180 \
	  -maximum-test-execution-time-allowance 300 -quiet
```

Also add `-skip-testing:RunnerUITests` to the `ios-unit` recipe's `xcodebuild` line, after `-only-testing:RunnerTests`. The scheme now has both test targets, and `-only-testing` already selects one, so this only documents the intent; drop it if `xcodebuild` rejects the combination.

Run: `make ios-ui IOS_UNIT_DEVICE="$IPAD_UDID"` and then `make ios-ui IOS_UNIT_DEVICE="$IPHONE_UDID"`
Expected: `** TEST SUCCEEDED **`, 4 tests on each.
Run: `make ios-unit IOS_UNIT_DEVICE="$IPAD_UDID"`
Expected: still green (`RunnerTests` only).

- [ ] **Step 9: CI**

In `.github/workflows/ci.yaml`, after `ios-unit`:

```yaml
  ios-ui:
    # Real taps on native dialogs (XCUITest, spec P3a §9.4). Non-blocking:
    # simulator UI tests are slow and can flake on shared runners.
    name: ios-ui (${{ matrix.device }})
    runs-on: macos-latest
    continue-on-error: true
    timeout-minutes: 40
    strategy:
      fail-fast: false
      matrix:
        device: [iPad, iPhone]
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: 3.44.x
          cache: true
      - run: make get
      - name: XCUITest on the newest ${{ matrix.device }} simulator
        run: |
          udid=$(xcrun simctl list devices available | grep -F "    ${{ matrix.device }}" | tail -n1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
          make ios-ui IOS_UNIT_DEVICE="$udid"
```

- [ ] **Step 10: Commit**

```bash
bash .githooks/pre-commit && \
git add liquid_shell/example/ios/RunnerUITests/RunnerUITests.swift \
  liquid_shell/example/ios/Runner.xcodeproj/project.pbxproj \
  liquid_shell/example/ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme \
  Makefile .github/workflows/ci.yaml && \
git commit -m "test(ios): XCUITest taps real native alert and sheet buttons (VK-406)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Docs, versions, side-by-side QA, verification

**Files:**
- Create: `liquid_shell/doc/native_dialogs.md`
- Create: `docs/qa/p3a/manual.md` and the screenshots under `docs/qa/p3a/`
- Modify: `liquid_shell/README.md` (feature line, Limitations, roadmap line)
- Modify: `liquid_shell/CHANGELOG.md`, `liquid_shell_platform_interface/CHANGELOG.md`, `liquid_shell_ios/CHANGELOG.md`, `liquid_shell_android/CHANGELOG.md`
- Modify: the four `pubspec.yaml` files, `liquid_shell/example/pubspec.yaml`, `liquid_shell_ios/ios/liquid_shell_ios.podspec`
- Modify: `CLAUDE.md`, `CONTRIBUTING.md` (`make ios-ui`)

**Interfaces:**
- Consumes: everything above.
- Produces: `0.1.0-dev.3` in all four packages; a green `make verify` with its output pasted into the final report.

- [ ] **Step 1: `doc/native_dialogs.md`**

Write it from the spec. Use exactly these sections:
1. "When the system draws the dialog": the availability table of spec §5.2, the `presentation` table from the README, and the fact that no Info.plist key is needed.
2. "How the answer is decided": the completion table of spec §5.4, the result rules (value / cancel value / null), and the validation errors.
3. "With native chrome": the table of spec §8.
4. "Accessibility and languages": spec §7.3, and the fact that the system alert follows the device's Dynamic Type, not Flutter's `TextScaler`.
5. "Troubleshooting": one row per `LiquidNativeDialogUnavailableReason`, with its cause and fix. `noWindow` is a headless or add-to-app engine. `refused` means another presentation was stuck. `disabledByEnvironment` is `LIQUID_SHELL_NATIVE_OFF=1`. `channelError` means a broken registration.
6. "Known limits": a hot restart leaves an orphan alert in debug builds; VoiceOver focus goes back to the Flutter view, not to the tapped node; there are no text fields in alerts (planned P3a-2).

Link it from the README's new section ("Details: [doc/native_dialogs.md](doc/native_dialogs.md)").

- [ ] **Step 2: README feature line, Limitations, roadmap**

- Features list: "**Native alerts and action sheets** on iOS 26 (`UIAlertController`), the same glass drawn by Flutter elsewhere."
- Limitations: the three items of Step 1 §6, plus "system dialog text follows the device language for any string UIKit adds (none in alerts; VoiceOver hints)".
- Roadmap: P3a done; P3a-2 (share, haptics, date picker, alert text fields) next if the owner approved Q1.

- [ ] **Step 3: Side-by-side screenshots (L5), simulators and emulator only**

1. iOS 26: copy `dialogs_<run>_alert.png`, `dialogs_<run>_alert_flutter.png` and `dialogs_<run>_sheet.png` for the iPad and the iPhone from `liquid_shell/example/build/integration_screenshots/` (Task 7 Step 4) to `docs/qa/p3a/`. Name them `ios26-<device>-<alert|alert-flutter|sheet>.png`, then `sips --resampleWidth 820` them.
2. Android **emulator** only. Use the AVD that `tool/integration_android.sh` uses. Check that the serial starts with `emulator-` and is not `QV7029CU1E`:

```bash
adb devices   # pick the emulator-XXXX serial
cd liquid_shell/example && fvm flutter run -d emulator-5554
# open "Alerts and action sheets", tap "Alert", then:
adb -s emulator-5554 exec-out screencap -p > ../../docs/qa/p3a/android-alert.png
# tap "Action sheet", then:
adb -s emulator-5554 exec-out screencap -p > ../../docs/qa/p3a/android-sheet.png
```

3. Write `docs/qa/p3a/manual.md`. Add a table that pairs each native shot with its Flutter-liquid shot, and the manual checklist of spec §9.5. That covers VoiceOver (Accessibility Inspector on the simulator), Dynamic Type AX5 (`xcrun simctl ui <udid> content_size accessibility-extra-extra-extra-large`), dark mode (`xcrun simctl ui <udid> appearance dark`), RTL (the scheme's `-AppleLanguages (ar)` launch argument), hardware keyboard Esc/Return, an alert while a Flutter `TextField` has the keyboard, and a guard alert from the iPad overlay sidebar and from the compact bar. Give each row a result column: pass, fail or "owner on device". Leave the owner's device checks unticked.

- [ ] **Step 4: iOS < 26 (Q9; skip if fewer than 10 GB would remain free)**

```bash
df -h /                                         # need ≥ 18 GB free before
xcodebuild -downloadPlatform iOS -buildVersion 18.6
OLD_UDID=$(xcrun simctl create "vk406 iOS18" com.apple.CoreSimulator.SimDeviceType.iPhone-16 com.apple.CoreSimulator.SimRuntime.iOS-18-6)
IOS_RUNTIME="iOS 18.6" NATIVE_DEVICES="$OLD_UDID=false" NATIVE_TARGETS="native_dialogs_test.dart" make integration-ios-native
```

Expected: pass. The `auto` tests return early, because `EXPECT_NATIVE=false`. The Flutter test draws the glass alert. The `system` test shows UIKit's non-glass alert natively. Screenshot the Flutter alert with `xcrun simctl io "$OLD_UDID" screenshot docs/qa/p3a/ios18-alert-flutter.png`. Afterwards run `xcrun simctl delete "$OLD_UDID"`, and delete the runtime only if the owner asks (`xcrun simctl runtime delete`). If you skip this step, write "unverified on a real iOS < 26 runtime (Q9)" in `manual.md` and in the README Limitations.

- [ ] **Step 5: CHANGELOGs**

Add a `## 0.1.0-dev.3` section on top of each:
- `liquid_shell`: "`showLiquidAlert` / `showLiquidActionSheet`: native `UIAlertController` on iOS 26+, Flutter glass elsewhere; `LiquidAlertAction`, `LiquidAlertActionStyle`, `LiquidDialogPresentation`; `LiquidShellStrings.dismiss`. Example: Alerts and action sheets case; the guard uses the native alert."
- `liquid_shell_platform_interface`: "`supportsNativeDialogs`, `presentNativeDialog` and the native dialog request/result types."
- `liquid_shell_ios`: "Native alerts and action sheets presented from the engine's own window (`NativeDialogPresenter`), over the Pigeon channel."
- `liquid_shell_android`: "Version bump only (Android draws the Flutter glass dialog)."

- [ ] **Step 6: Versions**

Replace `0.1.0-dev.2` with `0.1.0-dev.3` in exactly these places: `version:` of the four package pubspecs; every `^0.1.0-dev.2` constraint in `liquid_shell/pubspec.yaml`, `liquid_shell_ios/pubspec.yaml`, `liquid_shell_android/pubspec.yaml` and `liquid_shell/example/pubspec.yaml`; and `s.version` in the podspec. Check:

```bash
git grep -n "0.1.0-dev.2" -- ':!docs' ':!*CHANGELOG.md'   # expect no output
make get
```

- [ ] **Step 7: CLAUDE.md and CONTRIBUTING.md**

Add `make ios-ui IOS_UNIT_DEVICE=<udid>   # XCUITest: real taps on native dialogs` under the commands in both files.

- [ ] **Step 8: Full verification**

```bash
make verify
make ios-unit IOS_UNIT_DEVICE="$IPAD_UDID" && make ios-unit IOS_UNIT_DEVICE="$IPHONE_UDID"
make ios-ui IOS_UNIT_DEVICE="$IPAD_UDID" && make ios-ui IOS_UNIT_DEVICE="$IPHONE_UDID"
NATIVE_DEVICES="$IPAD_UDID=true;$IPHONE_UDID=true" make integration-ios-native
make integration-android    # emulator only
```

Expected: `✓ verify passed`, `** TEST SUCCEEDED **` ×4, `✓ native shell integration passed`, and the Android integration green. Paste every summary line into the final report (`superpowers:verification-before-completion`).

- [ ] **Step 9: Commit**

```bash
bash .githooks/pre-commit && \
git add liquid_shell/doc/native_dialogs.md liquid_shell/README.md \
  docs/qa/p3a/manual.md docs/qa/p3a/*.png \
  liquid_shell/CHANGELOG.md liquid_shell_platform_interface/CHANGELOG.md \
  liquid_shell_ios/CHANGELOG.md liquid_shell_android/CHANGELOG.md \
  liquid_shell/pubspec.yaml liquid_shell_platform_interface/pubspec.yaml \
  liquid_shell_ios/pubspec.yaml liquid_shell_android/pubspec.yaml \
  liquid_shell/example/pubspec.yaml liquid_shell_ios/ios/liquid_shell_ios.podspec \
  CLAUDE.md CONTRIBUTING.md && \
git commit -m "docs(docs): native dialogs guide, side-by-side QA, 0.1.0-dev.3 (VK-406)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Then `superpowers:requesting-code-review` for the whole branch, `superpowers:finishing-a-development-branch`, and Plane: VK-406 → Done, with the verification output as the evidence comment. Do not push or open a PR without the owner. Rebase onto `main` once P2 (#3) is merged. After the rebase, run `make goldens-update` again if the liquid-tier branch changed the glass, and run `make verify`.

---

## Self-review (done while writing)

- **Spec coverage:** §4 API → Tasks 1, 5. §4.3 strings → Task 4. §5 native → Task 3. §6 channel and memory → Tasks 2, 5. §7 fallback → Task 4. §8 chrome → Task 5 widget tests, Task 7 integration. §9.1–9.3 → Tasks 1–5. §9.4 → Task 7. §9.5 → Task 8. §9.6 goldens and CI → Tasks 6, 7. §10 example → Task 6. §11 docs and versions → Task 8. §12 errors → Tasks 2, 3, 5. §13 risks → Task 3 (exactly-once mutation checks), Task 7 Step 7 (XCUITest fallback), Task 8 Step 4 (iOS 18).
- **Names used across tasks:** `LiquidNativeDialogRequest` / `LiquidNativeDialogAction` / `LiquidNativeDialogKind` / `LiquidNativeDialogActionStyle` / `LiquidNativeDialogResult` (Tasks 1, 2, 4, 5); `presentNativeDialog`, `supportsNativeDialogs` (1, 2, 5); `NativeDialogHostApi.present/debugCurrent/debugRespond` (2, 3); `debugNativeDialog`, `debugRespondToNativeDialog`, `NativeDialogDebugSnapshot` (2, 7); `showGlassDialog`, `GlassAlert`, `GlassActionSheet` (4, 5); `dialogValue`, `checkAlertActions`, `dialogRequestFor`, `anchorOf`, `NativeDialogMemory` (5); `NativeAlertsCase(autorun:)`, `ExampleApp(demo:)`, `LIQUID_SHELL_EXAMPLE_DEMO` (6, 7).
- **Known judgment points for the implementer:** Task 3 Step 6 (`popoverPresentationController` on iPhone), Task 4 Step 5 (measured cancel side and preferred fill), Task 7 Step 4 (whether screenshots capture UIKit), Task 7 Step 7 (XCUITest → idb fallback), Task 8 Step 4 (disk). Each names what to do in both cases.
