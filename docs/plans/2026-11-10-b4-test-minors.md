# B4 Test-Only Follow-ups (VK-924) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tighten three B4 tests: the disabled-action tap, the smoke Delete check and the XCUITest row lookup.

**Architecture:** Test-only edits in three files. Spec: `docs/specs/2026-11-10-b4-test-minors-design.md`.

**Tech Stack:** flutter_test, XCUITest. Flutter 3.44.9 (`fvm flutter`).

## Global Constraints

- No production code changes. No CHANGELOG line.
- Run `.githooks/pre-commit` manually and check its exit status before committing; never `--no-verify`. `git add` explicit paths only (`.superpowers/` is not ignored).
- Simulators: create your own and delete them by UDID. Never touch the protected ones (lba144-duo 572B92E2, iPhone Duo 383C4573, iPhone 17 Pro C428FE39, D3A948FD, B7246683).
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

---

### Task 1: Tighten the three tests

**Files:**
- Modify: `liquid_shell/test/widget/liquid_page_test.dart` (test at ~:1682, "a tap runs onPressed; a disabled action is not tappable…")
- Modify: `liquid_shell/example/test/cases_smoke_test.dart` (~:219-225)
- Modify: `liquid_shell/example/ios/RunnerUITests/PagesUITests.swift` (~:97-100)

- [ ] **Step 1: T6.** After `expect(taps, ['Favourite']);`, add:

```dart
      final deleteInk = find.descendant(
        of: find.byTooltip('Delete'),
        matching: find.byType(InkWell),
      );
      expect(deleteInk, findsOneWidget, reason: 'one InkWell per action circle');
      expect(tester.widget<InkWell>(deleteInk).onTap, isNull);
```

  Mutation check: give `Delete` an `onPressed` in the test's `actions(...)` helper locally, and confirm the new `onTap` assert fails. Then revert.
  Run: `cd liquid_shell && fvm flutter test test/widget/liquid_page_test.dart`. Expected: all pass.

- [ ] **Step 2: T8 smoke.** Replace the `tester.widget<InkWell>(find.descendant(...))` block with:

```dart
    final deleteInk = find.descendant(
      of: find.byTooltip('Delete'),
      matching: find.byType(InkWell),
    );
    expect(deleteInk, findsOneWidget, reason: 'one InkWell per action circle');
    expect(tester.widget<InkWell>(deleteInk).onTap, isNull);
```

  Run: `cd liquid_shell/example && fvm flutter test test/cases_smoke_test.dart`. Expected: all pass.

- [ ] **Step 3: T8 predicate.** On your own iPhone 17 Pro (iOS 26.5) simulator, find the row's element type. For example, add a temporary `print(app.debugDescription)` or read the failure tree. Then replace:

```swift
    let note = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label CONTAINS %@", "A favourite")).firstMatch
```

  with the narrowest query that matches, for example:

```swift
    let note = app.staticTexts
      .matching(NSPredicate(format: "label ENDSWITH %@", "A favourite")).firstMatch
```

  Use `app.otherElements` instead if that is where the label is. Remove any temporary print.

- [ ] **Step 4: Suites.** Run `.githooks/pre-commit` (exit 0). Then run `PagesUITests` on your simulator, either through `tool/ios_xctest.sh` or `xcodebuild test -only-testing:RunnerUITests/PagesUITests`. Expected: 0 failed. Delete the simulator.

- [ ] **Step 5: Commit** the three files plus the spec and this plan: `test(pages): tighten the B4 disabled-action and row checks (VK-924)`.
