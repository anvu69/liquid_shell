# liquid_shell VK-699 (+ VK-698): a native search handed back to Flutter chrome, Implementation Plan

> **Approval:** the owner accepted both investigations' recommendations on 2026-10-23; the spec `docs/specs/2026-10-23-search-handback-design.md` records them (§7). This plan implements it.
>
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Leaving native chrome ends an active native search (inactive, text kept, `composing` false, no `onChanged`), and the iOS scope-bar XCTest follows the field placement UIKit realises (spec §1).

**Architecture:** Task 1 is Dart only, in `liquid_shell/lib/src/search/shell_search.dart`: the `native` setter's `true → false` branch schedules a microtask that calls `_endSearch(controller, nativeField: true)`, as `releaseField` already ends a search after the build. `_endSearch` gains an optional `nativeField` so the composing rule reads which field held the search. Task 2 changes one XCTest's branch from the device idiom to `debugSnapshot().placement`, and adds one row to the P3b spec table.

**Tech Stack:** Dart 3.12 / Flutter 3.44.6, `flutter_test`; Swift XCTest (Xcode 27.1).

**Prototype (2026-10-23).** Task 1's tests and code ran in the worktree at `a387a8e` before this plan was written, then were removed:
- the four tests were red at `a387a8e` with the messages of Task 1 Step 3, and green with Step 4's code;
- mutations M1 and M2 turned all four red;
- `make test` green (`liquid_shell` `+1262: All tests passed!`, every other package and `tool/test` green), `make analyze` and `flutter analyze`: no issues.
- Task 2's patch applies at `a387a8e` (`git apply --check`); its red/green runs come from the VK-698 investigation on `bfcccb6` (spec §3.2, §6.3). The XCTest file did not change between the two commits.

## Global Constraints

- Run `.githooks/pre-commit` by hand before every commit (`.githooks/pre-commit && git commit …`). Never `--no-verify`. Never change git config; never set `core.hooksPath`.
- Commit messages `<type>(<scope>): <summary> (VK-…)`, scope `shell` (Task 1), `ios` (Task 2). Every commit ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- No pushes, no remotes, no publishing: the controller pushes.
- TDD: run each red-first test and see it red for the reason the task gives before writing the production code.
- No public API change, no Swift production code, no Pigeon, no platform-interface change, no version bump. The CHANGELOG line goes under the existing `## 0.1.0-dev.8` of `liquid_shell/CHANGELOG.md`.
- Never loosen `analysis_options.yaml`. `dart format` before committing.
- `make verify` red only at `goldens` with the 8 band images `tab_lens_pressed`, `tab_lens_straddle`, `tab_lens_pressed_dark`, `tab_glow_release_dark`, `liquid_default`, `liquid_refraction_0`, `liquid_refraction_2`, `liquid_dispersion_03` is this machine, not the branch: report it, do not touch goldens.
- Simulators: create your own (`xcrun simctl create`), boot and delete only those UDIDs. Never open or quit Simulator.app.
- Run commands from `liquid_shell/` unless a step says otherwise. Python, if needed, with `python3 -I`.

## File map

| File | Task | Responsibility |
|---|---|---|
| `liquid_shell/lib/src/search/shell_search.dart` | 1 | the setter ends the search; `_endSearch(nativeField:)` |
| `liquid_shell/test/widget/native_search_test.dart` | 1 | group `VK-699`, tests P1, P2, P2b, P3 |
| `liquid_shell/CHANGELOG.md` | 1 | one Fix line |
| `liquid_shell/doc/search.md` | 1 | one bullet under "The controller is the truth" |
| `liquid_shell/example/ios/RunnerTests/RunnerTests.swift` | 2 | the scope-bar test branches on the realised placement |
| `docs/specs/2026-10-10-p3b-search-tab-design.md` | 2 | §7.2: the realised placement row |

---

### Task 1 (VK-699): leaving native chrome ends the native search

**Files:**
- Modify: `liquid_shell/test/widget/native_search_test.dart` (a new group at the end of `main()`)
- Modify: `liquid_shell/lib/src/search/shell_search.dart:73-92` (the `native` setter and its doc), `:274-288` (`_endSearch`)
- Modify: `liquid_shell/CHANGELOG.md`, `liquid_shell/doc/search.md`

**Interfaces:** `_endSearch(LiquidSearchController controller, {bool? nativeField})` (private). No public change.

- [ ] **Step 1: the failing tests**

At the end of `main()` in `test/widget/native_search_test.dart`, after the closing `});` of the last group and before the final `}`, add (`_destinations`, `_page`, `_compact`, `_compactPadding` exist in the file; `LiquidGlassScope`, `LiquidGlassPolicy`, `LiquidGlassTier` come from `package:liquid_shell/liquid_shell.dart`):

```dart

  // VK-699. The reverse of VK-572 bug B: an active native search,
  // mid-composition (marked text), is handed back to Flutter chrome. The
  // search ends there, its text kept, as any native end does (VK-572 §4):
  // inactive, not composing, onChanged not called.
  group('VK-699: Flutter chrome takes over a native search', () {
    Widget shell(
      LiquidSearchController controller,
      List<String> changes, {
      LiquidNativeChrome nativeChrome = LiquidNativeChrome.auto,
      LiquidGlassTier? forcedTier,
    }) => LiquidGlassScope(
      policy: LiquidGlassPolicy(forcedTier: forcedTier),
      child: TestShell(
        destinations: _destinations,
        initialIndex: 2,
        pageBuilder: _page,
        nativeChrome: nativeChrome,
        search: LiquidSearch(controller: controller, onChanged: changes.add),
      ),
    );

    Future<(FakeNativePlatform, LiquidSearchController, List<String>)>
    composing(WidgetTester tester) async {
      final fake = installFakeNative(state: _compact);
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      final changes = <String>[];
      await pumpShell(
        tester,
        shell(controller, changes),
        padding: _compactPadding,
      );
      fake
        ..emitNative(const LiquidNativeSearchActiveChanged(true))
        ..emitNative(
          const LiquidNativeSearchTextChanged('かな', composing: true),
        );
      await tester.pump();
      expect(controller.isActive, isTrue, reason: 'precondition');
      expect(controller.value.composing, isTrue, reason: 'precondition');
      changes.clear();
      return (fake, controller, changes);
    }

    void expectEnded(LiquidSearchController controller, List<String> changes) {
      expect(controller.isActive, isFalse);
      expect(controller.text, 'かな', reason: 'the composed text is kept');
      expect(controller.value.composing, isFalse);
      expect(changes, isEmpty, reason: 'the text did not change');
    }

    // The claim is released in the same build, so native's own
    // `searchActive false` (if any) never reaches the shell.
    testWidgets('P1: nativeChrome turned off mid-composition', (
      tester,
    ) async {
      final (fake, controller, changes) = await composing(tester);
      await pumpShell(
        tester,
        shell(controller, changes, nativeChrome: LiquidNativeChrome.off),
        padding: _compactPadding,
      );
      fake.emitNative(const LiquidNativeSearchActiveChanged(false));
      await tester.pumpAndSettle();
      expectEnded(controller, changes);
    });

    testWidgets('P2: a lost install mid-composition', (tester) async {
      final (fake, controller, changes) = await composing(tester);
      fake.pushState(const LiquidNativeShellState(installed: false));
      await tester.pumpAndSettle();
      expectEnded(controller, changes);
    });

    // The claim survives a lost install: native's late report arrives
    // after Dart switched to Flutter mode.
    testWidgets('P2b: a lost install, then native reports inactive', (
      tester,
    ) async {
      final (fake, controller, changes) = await composing(tester);
      fake.pushState(const LiquidNativeShellState(installed: false));
      await tester.pumpAndSettle();
      fake.emitNative(const LiquidNativeSearchActiveChanged(false));
      await tester.pumpAndSettle();
      expectEnded(controller, changes);
    });

    // A forced glass tier leaves native chrome through the same setter.
    testWidgets('P3: a forced glass tier mid-composition', (tester) async {
      final (_, controller, changes) = await composing(tester);
      await pumpShell(
        tester,
        shell(controller, changes, forcedTier: LiquidGlassTier.liquid),
        padding: _compactPadding,
      );
      expectEnded(controller, changes);
    });
  });
```

Run `dart format test/widget/native_search_test.dart` (expected: `0 changed`).

- [ ] **Step 2: (nothing to build)**

- [ ] **Step 3: see them red**

Run: `flutter test test/widget/native_search_test.dart --plain-name "VK-699"`
Expected: `+0 -4: Some tests failed.` Every precondition passes; each test fails in `expectEnded`:

| Test | Line | Failure |
|---|---|---|
| P1 | `native_search_test.dart:2669` `expect(controller.isActive, isFalse)` | `Expected: false` / `Actual: <true>` |
| P2 | `:2669` | `Expected: false` / `Actual: <true>` |
| P2b | `:2671` `expect(controller.value.composing, isFalse)` | `Expected: false` / `Actual: <true>` |
| P3 | `:2669` | `Expected: false` / `Actual: <true>` |

A failure at a `precondition` line, or a different line, is not the right red: stop and report.

- [ ] **Step 4: the setter ends the search; `_endSearch` takes the field**

In `lib/src/search/shell_search.dart` (`dart:async` is already imported for `scheduleMicrotask`), replace the setter's doc paragraph and body:

```dart
  /// Leaving native chrome (a lost install, native chrome off, a forced
  /// tier) writes the controller's text into the Flutter field, which
  /// heard nothing while native drove the search. The write follows
  /// [_writeField]'s rule: held while the field is composing.
  bool get native => _native;
  set native(bool value) {
    if (!value) {
      _sentShown = false;
      _scopeSent = false;
      _replay = true;
      final controller = _controller;
      if (_native && controller != null) _writeField(controller.text);
    }
    _native = value;
  }
```

with:

```dart
  /// Leaving native chrome (a lost install, native chrome off, a forced
  /// tier) writes the controller's text into the Flutter field, which
  /// heard nothing while native drove the search. The write follows
  /// [_writeField]'s rule: held while the field is composing. It also
  /// ends the search, its text kept, right after the build: native's own
  /// end never comes then, or comes in Flutter mode.
  bool get native => _native;
  set native(bool value) {
    if (!value) {
      _sentShown = false;
      _scopeSent = false;
      _replay = true;
      final controller = _controller;
      if (_native && controller != null) {
        _writeField(controller.text);
        // The native search ends with native chrome (VK-699): its own
        // `searchActive false` never comes (a released claim) or comes in
        // Flutter mode (a lost install). After the build, as releaseField.
        scheduleMicrotask(() {
          if (_disposed || _native || !identical(controller, _controller)) {
            return;
          }
          _endSearch(controller, nativeField: true);
        });
      }
    }
    _native = value;
  }
```

Then replace:

```dart
  /// lets go ([_onEditing]): there only `active` changes here.
  void _endSearch(LiquidSearchController controller) {
    final value = controller.value;
    final composing = !native && value.composing;
```

with:

```dart
  /// lets go ([_onEditing]): there only `active` changes here.
  /// [nativeField] says which field held the search when [native] no
  /// longer does (the hand-back to Flutter chrome).
  void _endSearch(LiquidSearchController controller, {bool? nativeField}) {
    final value = controller.value;
    final composing = !(nativeField ?? native) && value.composing;
```

- [ ] **Step 5: see them green, and the package**

Run: `flutter test test/widget/native_search_test.dart --plain-name "VK-699"`
Expected: `+4: All tests passed!`

Run: `flutter test --exclude-tags golden,impeller,liquid_golden` then `flutter analyze`
Expected: `All tests passed!` (prototype: `+1262`); `No issues found!`

- [ ] **Step 6: the mutations**

Each on `shell_search.dart`, run `flutter test test/widget/native_search_test.dart --plain-name "VK-699"`, record, revert, `git status` shows only this task's files:

| | Mutation | Prototype |
|---|---|---|
| M1 | `_endSearch(controller, nativeField: true);` → `controller.hashCode;` (the microtask does nothing) | P1, P2, P2b, P3 red |
| M2 | `_endSearch(controller, nativeField: true);` → `_endSearch(controller);` (Flutter-mode rule keeps `composing`) | P1, P2, P2b, P3 red |

- [ ] **Step 7: docs**

`doc/search.md`, section `## The controller is the truth`, after the bullet that starts `- **Native chrome takes over.**` (ends `A tap on the native field resumes it.`), add:

```markdown
- **Flutter chrome takes over.** When native chrome lets go of an active
  native search (`nativeChrome` set to `off`, a forced glass tier, the
  native shell lost), the search ends right after that build: `active`
  and `composing` turn false and the text stays. `onChanged` is not
  called. A tap on the Flutter field resumes it.
```

`CHANGELOG.md`, append to the list under `## 0.1.0-dev.8` (after the last `**Fix (VK-593).**` bullet):

```markdown
- **Fix (VK-699).** When Flutter chrome takes over an active native search
  (`nativeChrome: off`, a forced glass tier, a lost native install), the
  search now ends with its text kept, `composing` false and `onChanged`
  not called. Before, the controller stayed active (and blocked back) or
  kept `composing` true.
```

- [ ] **Step 8: commit**

```bash
dart format lib test && cd .. && .githooks/pre-commit && git add liquid_shell/lib/src/search/shell_search.dart liquid_shell/test/widget/native_search_test.dart liquid_shell/doc/search.md liquid_shell/CHANGELOG.md && git commit -m "fix(shell): a native search handed back to Flutter chrome ends (VK-699)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2 (VK-698): the scope-bar XCTest follows the realised placement

Test only. Simulators from the iOS 27.0 runtime (`com.apple.CoreSimulator.SimRuntime.iOS-27-0`, installed) and an iOS 26.x one (`iOS-26-3` on this machine; any 26.x). iPhone 17 cannot be created on 27.1 ("Incompatible device").

**Files:**
- Modify: `liquid_shell/example/ios/RunnerTests/RunnerTests.swift:2965-2994` (doc comment and body of `testTheScopeBarShowsOnlyWhileTheSearchIsActive`)
- Modify: `docs/specs/2026-10-10-p3b-search-tab-design.md` §7.2 table

- [ ] **Step 1: the simulators**

From the repo root:

```bash
U27=$(xcrun simctl create vk698-ip17-27 com.apple.CoreSimulator.SimDeviceType.iPhone-17 com.apple.CoreSimulator.SimRuntime.iOS-27-0)
U26=$(xcrun simctl create vk698-ip17-26 com.apple.CoreSimulator.SimDeviceType.iPhone-17 com.apple.CoreSimulator.SimRuntime.iOS-26-3)
echo "$U27 $U26"
```

`make ios-unit` always selects `-only-testing:RunnerTests` (the whole suite), so the filtered runs call the script it wraps, `tool/ios_xctest.sh`, with the same caps and a narrower selection. Define once:

```bash
SCOPE="-only-testing:RunnerTests/NativeTabsTests/testTheConfigsScopesReachTheSearchBarAndTheSnapshot -only-testing:RunnerTests/NativeTabsTests/testTheScopeBarShowsOnlyWhileTheSearchIsActive -only-testing:RunnerTests/NativeTabsTests/testAUserScopeChangeIsSentToDartOnce -only-testing:RunnerTests/NativeTabsTests/testDartsScopeIsNeverSentBack -only-testing:RunnerTests/NativeTabsTests/testAUserScopeChangePutsTheKeyboardAwayAndKeepsTheSearch -only-testing:RunnerTests/NativeTabsTests/testDartsScopeWaitsForTheSearchTab -only-testing:RunnerTests/NativeTabsTests/testASceneReconnectCarriesTheUsersScopeToTheNewShell -only-testing:RunnerTests/NativeTabsTests/testASceneReconnectCarriesDartsHeldScopeOverTheBars -only-testing:RunnerTests/NativeTabsTests/testDartsScopeSentWhileNoShellIsInstalledReachesTheNextOne"
```

- [ ] **Step 2: see it red on iOS 27.0**

```bash
tool/ios_xctest.sh $U27 $PWD/liquid_shell/example/build/vk698-red.xcresult 600 60 120 -only-testing:RunnerTests/NativeTabsTests/testTheScopeBarShowsOnlyWhileTheSearchIsActive
```

Expected: exit 65, `testTheScopeBarShowsOnlyWhileTheSearchIsActive` failed with
`XCTAssertLessThan failed: ("152.0") is not less than ("62.0") - above the field: NativeRect(x: 16.0, y: 62.0, width: 315.0, height: 44.0)`.

- [ ] **Step 3: branch on the realised placement**

In `RunnerTests.swift`, replace:

```swift
  /// at the top on an iPhone, above the field UIKit hosts by the tab bar;
  /// under the risen field on an iPad. Zero once hidden.
```

with:

```swift
  /// at the top on an iPhone, above the field UIKit hosts by the tab bar
  /// (iOS 26); under the risen stacked field on an iPad and on an iPhone
  /// from iOS 27.0. Zero once hidden.
```

and in the test body replace:

```swift
    let field = tabs.debugSnapshot().fieldFrame
```

with:

```swift
    let snapshot = tabs.debugSnapshot()
    let field = snapshot.fieldFrame
```

and:

```swift
    if UIDevice.current.userInterfaceIdiom == .pad {
```

with:

```swift
    // UIKit realises a stacked field on an iPad, and on an iPhone from
    // iOS 27.0 (VK-698: the active field rises to the top there).
    if snapshot.placement == "stacked" {
```

- [ ] **Step 4: see it green, on both runtimes**

```bash
tool/ios_xctest.sh $U27 $PWD/liquid_shell/example/build/vk698-27.xcresult 600 60 120 $SCOPE
tool/ios_xctest.sh $U26 $PWD/liquid_shell/example/build/vk698-26.xcresult 600 60 120 $SCOPE
```

Expected: exit 0 both, every selected test passed, none failed.

Then the whole suite, as CI runs it:

```bash
make ios-unit IOS_UNIT_DEVICE=$U27
make ios-unit IOS_UNIT_DEVICE=$U26
```

Expected: exit 0 both, 0 failed (investigation on 27.0: 190 tests, 174 passed, 16 skipped).

- [ ] **Step 5: the mutation**

Put back `if UIDevice.current.userInterfaceIdiom == .pad {` alone, run Step 2's command on `$U27`: red with Step 2's message. Revert.

- [ ] **Step 6: the P3b spec row**

In `docs/specs/2026-10-10-p3b-search-tab-design.md` §7.2, after the `preferredSearchBarPlacement` row, add:

```markdown
| Placement UIKit realises (`searchBarPlacement`, measured 2026-10-23, VK-698; 402×874 view, search active) | `inline`: field (88, 798, 226×48) by the tab bar, scope bar above it at (16, 64, 370×32) | `stacked` (27.0 `24A434`): field (16, 62, 315×44) at the top with ×, scope bar under it at (16, 116, 370×36), with or without scopes; idle after the search the field stays under the nav bar (16, 116, 370×44). The system's choice, accepted (VK-698); an iOS 27 `ios-unit` CI leg is a follow-up | `stacked` | `stacked` |
```

- [ ] **Step 7: delete the simulators**

```bash
xcrun simctl shutdown $U27 $U26; xcrun simctl delete $U27 $U26
```

- [ ] **Step 8: commit**

```bash
cd liquid_shell && dart format lib test && cd .. && .githooks/pre-commit && git add liquid_shell/example/ios/RunnerTests/RunnerTests.swift docs/specs/2026-10-10-p3b-search-tab-design.md && git commit -m "test(ios): the scope-bar test follows the placement UIKit realises (VK-698)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 9: the branch**

From the repo root: `make verify`. Expected: every step green but `goldens`, red only at the 8 band images of the Global Constraints. Paste the tail into the task report.
