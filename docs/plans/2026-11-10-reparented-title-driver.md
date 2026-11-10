# Reparented Title Driver (VK-826) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A scroll view that a `GlobalKey` moved out of a `LiquidPage` neither takes nor keeps that page's large title.

**Architecture:** One private helper `_isInPage` in `_LiquidPageState`, used twice in `_drivesLargeTitle`. `isOnScreenUnder` stays unchanged. Spec: `docs/specs/2026-11-10-reparented-title-driver-design.md`.

**Tech Stack:** Flutter 3.44.9 (`fvm flutter`), flutter_test.

## Global Constraints

- `isOnScreenUnder` in `lib/src/shell/branch_navigators.dart` is not changed.
- The CHANGELOG line, verbatim, under `## 0.1.0-dev.12` in `liquid_shell/CHANGELOG.md`: "A scroll view that a `GlobalKey` moves out of a `LiquidPage` no longer drives, or keeps, that page's large title."
- The dartdoc sentence, verbatim, added to `_drivesLargeTitle`: "A scroll view that a `GlobalKey` moved out of the page neither takes the title nor keeps it."
- No internal references (§, VK-, phase codes) in dartdoc (`make public-docs`).
- Run `.githooks/pre-commit` manually and check its exit status before committing; never `--no-verify`. `git add` explicit paths only (`.superpowers/` is not ignored).
- Commit trailer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

---

### Task 1: Only the page's own scroll views drive its title

**Files:**
- Modify: `liquid_shell/lib/src/pages/liquid_page.dart` (`_drivesLargeTitle`, ~:279-291; new `_isInPage` next to `_isPageScrollView`)
- Test: `liquid_shell/test/widget/liquid_page_test.dart` (new tests next to the existing large-title-follows tests; reuse the file's pump helpers, such as the 'Library' large-title helpers at ~:203-230)
- Modify: `liquid_shell/CHANGELOG.md`

**Interfaces:**
- Produces: `bool _isInPage(BuildContext element)` (private to `_LiquidPageState`).

- [ ] **Step 1: Write the Keep test.** A root page titled 'Library' with a large title. Its child is a `StatefulBuilder` (or a small stateful test widget) that holds a `GlobalKey` `aKey` and a flag `aInPage`. While `aInPage` is true, the page shows an `IndexedStack(index: shown)` of list A (`ListView`, `key: aKey`, 50 tall items) and list B (plain `ListView`). When it is false, A is placed outside the page, still mounted, for example in a `Stack` above the shell inside the same `MaterialApp`, as an `Offstage(offstage: false)` sibling, via a top-level holder. Steps:
  1. Drag A up 100 and settle. The large title's top has moved up (record it).
  2. Set `aInPage = false` and `shown = 1` (B) in one `setState`. Pump.
  3. Drag B up 30 and settle.
  4. Expect the title to follow B: its top equals the top for offset 30, not 100. Compute it as you find best, for example from the title top at offset 0 minus 30, clamped as the helpers show.

- [ ] **Step 2: Run it red.** Run `cd liquid_shell && fvm flutter test test/widget/liquid_page_test.dart --plain-name "<test name>"`. Expected: FAIL, the title still at A's offset.

- [ ] **Step 3: Write the Take test, and try to make it red.** In one build, a list reports from inside the page (for example a child that calls `controller.jumpTo(80)` from a post-layout path that runs during `persistentCallbacks`, or a list whose extent changes in that build so a `ScrollMetricsNotification` fires), and in the same build that list moves out by `GlobalKey` and the current driver is removed. After `pump()`, expect the title not at offset 80. If you cannot reach a setup that is red on main, drop this test and say so in the report, with what you tried.

- [ ] **Step 4: Implement.**

```dart
  // Whether [element] is under this page: a GlobalKey can move a scroll
  // view out of the page while it stays mounted.
  bool _isInPage(BuildContext element) {
    var found = false;
    element.visitAncestorElements((ancestor) {
      found = identical(ancestor, context);
      return !found;
    });
    return found;
  }
```

  and in `_drivesLargeTitle`:

```dart
  bool _drivesLargeTitle(BuildContext origin) {
    if (!_isInPage(origin) || !isOnScreenUnder(origin, context)) return false;
    final driver = _titleScrollView;
    if (identical(origin, driver)) return true;
    if (driver != null &&
        driver.mounted &&
        _isInPage(driver) &&
        isOnScreenUnder(driver, context)) {
      return false;
    }
    if (!_isPageScrollView(origin)) return false;
    _titleScrollView = origin;
    return true;
  }
```

  Add the dartdoc sentence (Global Constraints) after "every other scroll view is ignored." Add the CHANGELOG line.

- [ ] **Step 5: Run green.** Run the new tests, then the whole `test/widget/liquid_page_test.dart`. Expected: all pass.

- [ ] **Step 6: Hook.** Run `.githooks/pre-commit` and check that it exits 0.

- [ ] **Step 7: Commit** the three files plus the spec and this plan: `fix(pages): a scroll view moved out of the page no longer drives its large title (VK-826)`.
