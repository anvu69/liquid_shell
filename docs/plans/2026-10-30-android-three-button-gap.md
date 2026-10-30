# liquid_shell VK-897: three-button gap, Implementation Plan

> **Approval:** the owner chose the 32 dp Dart rule and a hotfix on `v0.1.0-dev.9` (2026-10-30); `docs/specs/2026-10-30-android-three-button-gap-design.md` records them.

**Goal:** On Android with three-button navigation the bottom pill sits `viewPadding.bottom + 8` above the edge; gesture navigation keeps 21. Ship as `0.1.0-dev.10`.

## Task 1: the gap rule (TDD)

**Files:** `liquid_shell/lib/src/shell/shell_layout.dart`, `liquid_shell/lib/src/shell/liquid_shell.dart` (call site), `liquid_shell/test/unit/shell_layout_test.dart`, `liquid_shell/test/widget/shell_chrome_test.dart`.

- [ ] Add the unit tests of spec §3 (48 → 56 with a 48 gesture inset, threshold 31.9 → 21 and 32 → 40) and the widget test (412×915, padding bottom 48, gesture inset 48, pill bottom 915 − 56). Run `flutter test test/unit/shell_layout_test.dart test/widget/shell_chrome_test.dart` in `liquid_shell/`: the 48-with-gesture cases fail with 21.
- [ ] Replace the rule with `viewPaddingBottom < kGestureBarMaxHeight` (32), drop `gestureInsetBottom` from the function and its call site, update the doc comment. Remove the parameter from the existing tests.
- [ ] Same command: all green. `make verify` green.
- [ ] Commit `fix(shell): three-button bar decided by its height, not the gesture inset (VK-897)`.

## Task 2: version 0.1.0-dev.10

- [ ] `RELEASE_VERSION=0.1.0-dev.10 dart test tool/test/release_version_test.dart`: red.
- [ ] Bump the 4 versions, 9 sibling constraints, the podspec, and add `## 0.1.0-dev.10` headings (spec §4).
- [ ] Same command green; commit; then `flutter pub publish --dry-run` in each package: "Package has 0 warnings."
- [ ] Commit `chore(ci): 0.1.0-dev.10 (VK-897)`.

## Task 3: hand-off (text only)

The owner, from this worktree, in order: `liquid_shell_platform_interface`, `liquid_shell_android`, `liquid_shell_ios`, `liquid_shell` — `flutter pub publish` in each. After the owner reports done: tag `v0.1.0-dev.10`, push the branch and tag, open a PR into `main` (only with the owner's go-ahead).
