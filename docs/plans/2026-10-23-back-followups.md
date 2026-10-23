# liquid_shell VK-775, VK-680, VK-774: the back follow-ups, Implementation Plan

> **Approval:** the owner approved the three fixes and their designs on 2026-10-23 (spec `docs/specs/2026-10-23-back-followups-design.md`, status line). This plan implements it. Spec §10 lists what the prototype run changed against the investigation.
>
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** System back and the iOS edge swipe pop what the user sees when a dialog is still closing (VK-775), when a router shows the selected tab frames late and the app has no `PopScope` (VK-680), and when a shell sits in another shell's body (VK-774).

**Architecture:** The walk in `liquid_shell/lib/src/shell/branch_navigators.dart` decides what back can reach: VK-775 makes a closing route's barrier not count, VK-680 records a hidden tab's own navigator as off screen, VK-774 records a nested shell and stops there. `liquid_shell.dart` acts on the records: VK-680 re-scans when a record's on-screen state flips, VK-774 asks a nested shell through the internal `NestedShellBack` interface (`claimsBack`, `handleBack()`), which `_LiquidShellState` implements with its own `_backScope` order. Every test is a widget test in `pushed_shell_back_test.dart`, run in both chrome modes.

**Tech Stack:** Dart 3.12 / Flutter 3.44.6; `flutter_test`.

**Prototype (2026-10-23).** Every test and every line of production code below ran in the worktree at `a387a8e` before this plan was written, then was removed:
- each red-first test was red at the state its task starts from, with the failure text the task gives, and green with the task's code;
- the mutations in the tables were run on the final code with the whole `liquid_shell` suite; each turned the tests named red;
- `make verify` with all three tasks and their docs passed every step but `goldens`: the 8 band images of the Global Constraints (red on this machine on `main` too). `liquid_shell` 1272 tests (87 in the back test file, 73 at `a387a8e`), coverage 97.72 %.

## Global Constraints

- Run `.githooks/pre-commit` by hand before every commit (`.githooks/pre-commit && git commit …`). Never `--no-verify`. Never change git config; never set `core.hooksPath`.
- Commit messages `<type>(<scope>): <summary> (VK-…)`, scope `shell` (tests too) or `docs`. Every commit ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- No pushes, no remotes, no publishing: the controller pushes.
- TDD: run each red-first test and see it red for the reason the task gives before writing the production code.
- No public API change: `NestedShellBack` lives in `branch_navigators.dart`, which `lib/liquid_shell.dart` does not export. No Swift, no Pigeon, no platform-interface change, no version bump. CHANGELOG lines go under the existing `## 0.1.0-dev.8` of `liquid_shell/CHANGELOG.md` (the unreleased heading: `pubspec.yaml` is `0.1.0-dev.8`).
- No Plane id, `§` or phase code in a `///` comment, a README or `doc/` (`make public-docs`); a plain `//` comment and the CHANGELOG may name the item.
- Mutations run **after** the task's commit, so `git checkout -- <file>` restores the committed fix, not `main`. Never `git checkout` a file with uncommitted work.
- Never loosen `analysis_options.yaml`. `dart format` before committing.
- `make verify` red only at `goldens` with the 8 band images `tab_lens_pressed`, `tab_lens_straddle`, `tab_lens_pressed_dark`, `tab_glow_release_dark`, `liquid_default`, `liquid_refraction_0`, `liquid_refraction_2`, `liquid_dispersion_03` is this machine, not the branch: report it, do not touch goldens.
- Run commands from `liquid_shell/` unless a step says otherwise. Python, if needed, with `python3 -I`.

## File map

| File | Tasks | Responsibility |
|---|---|---|
| `liquid_shell/lib/src/shell/branch_navigators.dart` | 1, 2, 3 | the walk: barriers (1), hidden tabs (2), nested shells and `NestedShellBack` (3) |
| `liquid_shell/lib/src/shell/liquid_shell.dart` | 2, 3 | `_scanBranches`, `_checkBranches`, `_popBranch`, `_backScope` |
| `liquid_shell/test/widget/pushed_shell_back_test.dart` | 1, 2, 3 | the tests, appended to the group `VK-593 (${mode.name}): back finds the right navigator`; `_Pushed.pump(size:)` and `_Inner` (3) |
| `liquid_shell/doc/router_integration.md` | 3 | the nested-shell rule replaces its known limit |
| `liquid_shell/CHANGELOG.md` | 1, 2, 3 | one Fixed line each, and VK-774's behaviour change |

---

### Task 1 (VK-775): a closing route's barrier does not cover the page under it

**Files:**
- Modify: `liquid_shell/test/widget/pushed_shell_back_test.dart` (one test at the end of the group `VK-593 (${mode.name}): back finds the right navigator`, after `'a toast in the tab overlay over a nested flow: back still pops the inner page'`)
- Modify: `liquid_shell/lib/src/shell/branch_navigators.dart:105-106` (`_hasBarrier`)
- Modify: `liquid_shell/CHANGELOG.md`

- [ ] **Step 1: the failing test**

After the toast test (it ends with `expect(app.shellPopped, isFalse);` and `});`), before the `});` that closes the group, add:

```dart

      // VK-775: a route that is closing no longer covers the page under it,
      // so a quick second back reaches the nested flow.
      testWidgets('a quick second back while a dialog closes pops the inner '
          'page, not the outer one', (tester) async {
        final inner = GlobalKey<NavigatorState>();
        final app = _Pushed(mode);
        await app.pump(tester);
        app.tabs[0].currentState!
            .push(
              MaterialPageRoute<void>(builder: (_) => _flow(inner, 'Flow')),
            )
            .ignore();
        await tester.pumpAndSettle();
        await _pushOn(tester, inner, 'Inner');
        app.tabs[0].currentState!
            .push(
              DialogRoute<void>(
                context: app.tabs[0].currentContext!,
                builder: (_) => const Text('The dialog'),
              ),
            )
            .ignore();
        await tester.pumpAndSettle();
        await app.outer.currentState!.maybePop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('The dialog'), findsOneWidget, reason: 'closing');
        await back(app, tester);
        expect(find.text('The dialog'), findsNothing);
        expect(_page('Inner'), findsNothing, reason: 'the inner page popped');
        expect(_page('Flow'), findsOneWidget, reason: 'the outer page stays');
      });
```

- [ ] **Step 2: see it red**

Run: `flutter test test/widget/pushed_shell_back_test.dart --plain-name "a quick second back while a dialog closes"`
Expected: FAIL in both modes (`+0 -2`):

```
Expected: exactly one matching candidate
  Actual: _TextWidgetFinder:<Found 0 widgets with text "Flow page: 0": []>
the outer page stays
```

(The closing dialog's barrier still hides the flow page, so tab 0's navigator pops it.)

- [ ] **Step 3: the guard**

In `branch_navigators.dart`, `_hasBarrier`, insert as its first statement (before `if (element.widget is ModalBarrier ||`):

```dart
  // A route that is closing (or dismissed) wraps its barrier in an
  // IgnorePointer that ignores: its page no longer covers the one under it
  // (VK-775).
  if (element.widget case IgnorePointer(ignoring: true)) return false;
```

- [ ] **Step 4: see it green, and the file**

Run: `flutter test test/widget/pushed_shell_back_test.dart`
Expected: `+75: All tests passed!`

- [ ] **Step 5: CHANGELOG**

Append to the list under `## 0.1.0-dev.8` (after the last `**Fix (VK-593).**` entry):

```markdown
- **Fix (VK-775).** A second back while a dialog is still closing pops
  the page of a navigator nested in the tab's page, not the page that
  holds it: a route that is closing no longer covers the page under it.
```

- [ ] **Step 6: commit**

```bash
dart format lib test && cd .. && .githooks/pre-commit && git add liquid_shell/lib/src/shell/branch_navigators.dart liquid_shell/test/widget/pushed_shell_back_test.dart liquid_shell/CHANGELOG.md && git commit -m "fix(shell): a closing dialog no longer hides the nested flow from back (VK-775)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 7: the mutation**

On `lib/src/shell/branch_navigators.dart`, run the whole package (`flutter test --exclude-tags golden,impeller,liquid_golden`), record, revert with `git checkout -- lib/src/shell/branch_navigators.dart`, `git status` clean:

| | Mutation | Red tests | Prototype |
|---|---|---|---|
| M1 | delete the line `if (element.widget case IgnorePointer(ignoring: true)) return false;` | `a quick second back while a dialog closes` | red (2) |

---

### Task 2 (VK-680): a tab shown frames after the selection, no app `PopScope`

**Files:**
- Modify: `liquid_shell/test/widget/pushed_shell_back_test.dart` (three tests after Task 1's)
- Modify: `liquid_shell/lib/src/shell/branch_navigators.dart` (`BranchNavigator`, `onScreenNavigatorsUnder`)
- Modify: `liquid_shell/lib/src/shell/liquid_shell.dart` (`_scanBranches`, `_checkBranches`, `_popBranch`)
- Modify: `liquid_shell/CHANGELOG.md`

**Interfaces:** Produces `BranchNavigator.onScreen` (Task 3 keeps it).

- [ ] **Step 1: the failing tests**

After Task 1's test, before the `});` that closes the group, add:

```dart

      // VK-680: with no PopScope of the app's own, the shell's answer comes
      // from the per-frame check alone; a branch that comes on screen
      // frames after the selection must turn it.
      testWidgets('no app PopScope, a branch on screen 300 ms after the '
          'selection: back pops its page, not the shell', (tester) async {
        final app = _Pushed(mode);
        await app.pump(
          tester,
          body: (index, pages) => _LateShow(index: index, children: pages),
        );
        await app.select(tester, 1);
        await app.push(tester, 1, 'Kept');
        await app.select(tester, 0);
        app.shell.currentState!.select(1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        await back(app, tester);
        expect(app.shellPopped, isFalse, reason: 'the tab has a page');
        expect(_page('Kept'), findsNothing);
        expect(_page('Library'), findsOneWidget);
      });

      testWidgets('no app PopScope, a branch on screen 300 ms after the '
          'selection: the edge swipe pops its page, not the shell', (
        tester,
      ) async {
        final app = _Pushed(mode);
        await app.pump(
          tester,
          body: (index, pages) => _LateShow(index: index, children: pages),
        );
        await app.select(tester, 1);
        await app.push(tester, 1, 'Kept');
        await app.select(tester, 0);
        app.shell.currentState!.select(1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        await _swipeFromTheEdge(tester);
        expect(app.shellPopped, isFalse, reason: 'the tab has a page');
        expect(_page('Library'), findsOneWidget);
      });

      testWidgets('no app PopScope, a branch with a nested flow on screen '
          '300 ms after the selection: back pops the inner page', (
        tester,
      ) async {
        final inner = GlobalKey<NavigatorState>();
        final app = _Pushed(mode);
        await app.pump(
          tester,
          root: (i) => i == 1 ? _flow(inner, 'Flow') : null,
          body: (index, pages) => _LateShow(index: index, children: pages),
        );
        await app.select(tester, 1);
        await _pushOn(tester, inner, 'Inner');
        await app.select(tester, 0);
        app.shell.currentState!.select(1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        await back(app, tester);
        expect(app.shellPopped, isFalse, reason: 'the nested flow has a page');
        expect(_page('Inner'), findsNothing);
        expect(_page('Flow'), findsOneWidget);
      });
```

- [ ] **Step 2: see them red**

Run: `flutter test test/widget/pushed_shell_back_test.dart --plain-name "no app PopScope"`
Expected: FAIL, all six (`+0 -6`), each with:

```
Expected: false
  Actual: <true>
```

(reason `the tab has a page`, or `the nested flow has a page`): the scan after the selection frame found no navigator, the per-frame check stopped, and the shell's route popped.

- [ ] **Step 3: the record**

In `branch_navigators.dart`, replace the line `typedef BranchNavigator = ({NavigatorState navigator, bool handled});` with:

```dart
///
/// `onScreen` false: a tab's own navigator that is hidden at the scan (an
/// unselected tab, or one a router shows frames after the selection), kept
/// so the per-frame check can see it come on screen.
typedef BranchNavigator = ({
  NavigatorState navigator,
  bool handled,
  bool onScreen,
});
```

- [ ] **Step 4: the walk**

In the doc comment of `onScreenNavigatorsUnder`, replace `/// A branch hidden by [_hides] or [_shows] is skipped.` with:

```dart
/// A branch hidden by [_hides] or [_shows] is skipped, but for its first
/// navigator (a hidden tab's own), recorded with `onScreen` false.
```

Replace the function (from `List<BranchNavigator> onScreenNavigatorsUnder(BuildContext root) {` to its closing `}`) with:

```dart
List<BranchNavigator> onScreenNavigatorsUnder(BuildContext root) {
  final found = <BranchNavigator>[];
  void visit(
    Element element, {
    required bool handled,
    required bool inside,
    required bool shown,
  }) {
    final widget = element.widget;
    final shownHere = shown && !_hides(widget);
    // ponytail: a hidden subtree is walked down to its first navigator (a
    // tab's own); a hidden tab with no navigator is walked whole, at scan
    // time only, never per frame.
    if (!shownHere && inside) return;
    final handledHere = handled || (!inside && _answersBack(widget));
    final isNavigator =
        element is StatefulElement && element.state is NavigatorState;
    if (element case StatefulElement(state: final NavigatorState navigator)) {
      found.add((
        navigator: navigator,
        handled: handledHere,
        onScreen: shownHere,
      ));
    }
    final insideHere = inside || isNavigator;
    element.visitChildren((child) {
      visit(
        child,
        handled: handledHere,
        inside: insideHere,
        shown: shownHere && _shows(element, child),
      );
    });
  }

  root.visitChildElements(
    (child) => visit(child, handled: false, inside: false, shown: true),
  );
  return found;
}
```

(A hidden navigator's children see `shown` false and `inside` true, so the walk returns at them: no extra `return` after `found.add`.)

- [ ] **Step 5: the shell**

In `liquid_shell.dart`, `_scanBranches`: replace `_checkBranches();` with `_checkBranches(rescan: false);` (the call in `_armBranchCheck` stays `_checkBranches();`).

Replace `_checkBranches` (from `  void _checkBranches() {` to its closing `  }`) with the lines below; they add three lines to its doc comment above it:

```dart
  ///
  /// A navigator that came on screen or went off it since the scan (a tab a
  /// router shows frames after the selection) asks for a new scan: its
  /// nested navigators were not walked.
  void _checkBranches({bool rescan = true}) {
    final body = _bodyKey.currentContext;
    var canPop = false;
    for (final b in _branches) {
      final onScreen =
          body != null &&
          b.navigator.mounted &&
          isOnScreenUnder(b.navigator.context, body);
      if (rescan && onScreen != b.onScreen && b.navigator.mounted) {
        _scanBranches();
        return;
      }
      if (onScreen && b.navigator.canPop()) canPop = true;
    }
    if (canPop != _branchCanPop) setState(() => _branchCanPop = canPop);
  }
```

In `_popBranch`, replace the two lines

```dart
    for (final (:navigator, :handled) in _branches.reversed) {
      if (!navigator.mounted || !navigator.canPop()) continue;
```

with

```dart
    for (final (:navigator, :handled, :onScreen) in _branches.reversed) {
      if (!onScreen || !navigator.mounted || !navigator.canPop()) continue;
```

- [ ] **Step 6: see them green, and the file**

Run: `flutter test test/widget/pushed_shell_back_test.dart`
Expected: `+81: All tests passed!`

- [ ] **Step 7: CHANGELOG**

Append under `## 0.1.0-dev.8`, after Task 1's line:

```markdown
- **Fix (VK-680).** Back and the iOS edge swipe pop the page of a tab that
  a router shows a few frames after the selection (the end of a
  cross-fade), also with no `PopScope` of the app's own; before, they
  popped the whole shell.
```

- [ ] **Step 8: commit**

```bash
dart format lib test && cd .. && .githooks/pre-commit && git add liquid_shell/lib/src/shell/branch_navigators.dart liquid_shell/lib/src/shell/liquid_shell.dart liquid_shell/test/widget/pushed_shell_back_test.dart liquid_shell/CHANGELOG.md && git commit -m "fix(shell): back finds a tab a router shows frames after the selection (VK-680)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 9: the mutations**

Each on the committed code, whole package (`flutter test --exclude-tags golden,impeller,liquid_golden`), record, revert with `git checkout -- lib/src/shell/<file>`, `git status` clean:

| | File | Mutation | Red tests | Prototype |
|---|---|---|---|---|
| M2 | `liquid_shell.dart` | `if (rescan && onScreen != b.onScreen && b.navigator.mounted) {` → `if (false) {` | `a branch with a nested flow on screen 300 ms` | red (2) |
| M3 | `branch_navigators.dart` | `if (!shownHere && inside) return;` → `if (!shownHere) return;` | the three `no app PopScope` tests | red (6) |
| M4 | `liquid_shell.dart` | drop `!onScreen \|\| ` from the `_popBranch` loop's `continue` line | `tabs as kept-alive PageView pages: back pops the page of the tab on screen` | red (2) |

(The prototype ran these on the final code of Task 3, where `navigator` reads `target`; the result is the same.)

---

### Task 3 (VK-774): a nested shell answers back in its own order

**Files:**
- Modify: `liquid_shell/test/widget/pushed_shell_back_test.dart` (`_Pushed.pump` takes `size`; `_Inner` after `_pushOn`; three tests after Task 2's)
- Modify: `liquid_shell/lib/src/shell/branch_navigators.dart` (`BranchNavigator`, `NestedShellBack`, the walk)
- Modify: `liquid_shell/lib/src/shell/liquid_shell.dart` (`_LiquidShellState`, `_checkBranches`, `_popBranch`, `_backScope`)
- Modify: `liquid_shell/doc/router_integration.md`, `liquid_shell/CHANGELOG.md`

**Interfaces:** Produces `abstract interface class NestedShellBack { bool get claimsBack; void handleBack(); }` in `branch_navigators.dart` (not exported); `BranchNavigator.navigator` becomes `State target`.

- [ ] **Step 1: the harness**

In `_Pushed.pump`, add the parameter `Size size = kPhone,` after `bool pushed = true,`, and pass it to `pumpShell`: insert `size: size,` right before `padding: mode == _Mode.native`.

After `_pushOn` (before `void main() {`), add:

```dart

/// A shell with its own tabs (sub-tabs) as the root page of tab 1 of a
/// [_Pushed] app, on its search tab, Flutter chrome; [tabs] holds its tab
/// navigators.
class _Inner {
  final List<GlobalKey<NavigatorState>> tabs = [
    for (var i = 0; i < 3; i++) GlobalKey<NavigatorState>(),
  ];
  final search = LiquidSearchController();

  /// Pumps [app] with this shell in tab 1, then selects it.
  Future<void> pump(
    _Pushed app,
    WidgetTester tester, {
    Size size = kPhone,
  }) async {
    addTearDown(search.dispose);
    await app.pump(
      tester,
      size: size,
      root: (i) => i != 1
          ? null
          : TestShell(
              nativeChrome: LiquidNativeChrome.off,
              destinations: _destinations,
              initialIndex: 2,
              search: LiquidSearch(controller: search),
              pageBuilder: (j) => Navigator(
                key: tabs[j],
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => LiquidPage(
                    title: 'Inner ${_destinations[j].label}',
                    child: TestPage(label: 'Inner ${_destinations[j].label}'),
                  ),
                ),
              ),
            ),
    );
    await app.select(tester, 1);
  }
}
```

- [ ] **Step 2: the failing tests**

After Task 2's tests, before the `});` that closes the group, add:

```dart

      // VK-774: a shell nested in a tab (sub-tabs) answers back in its own
      // order: its overlay sidebar, then its active search, then its tab's
      // page. The outer shell hands it back instead of popping its tabs.
      testWidgets('a shell nested in a tab, its search active over a pushed '
          'page: back deactivates the inner search first', (tester) async {
        final app = _Pushed(mode);
        final inner = _Inner();
        await inner.pump(app, tester);
        await _pushOn(tester, inner.tabs[2], 'Deep');
        inner.search.activate();
        await tester.pumpAndSettle();
        expect(inner.search.isActive, isTrue, reason: 'precondition');
        await back(app, tester);
        expect(
          inner.search.isActive,
          isFalse,
          reason: "the inner shell's order",
        );
        expect(_page('Deep'), findsOneWidget, reason: 'search first');
        expect(app.shellPopped, isFalse);
        await back(app, tester);
        expect(_page('Deep'), findsNothing, reason: 'the page next');
        expect(app.shellPopped, isFalse);
      });

      testWidgets('a shell nested in a tab, its search active at the tab '
          'root: back deactivates the inner search, not the shell', (
        tester,
      ) async {
        final app = _Pushed(mode);
        final inner = _Inner();
        await inner.pump(app, tester);
        inner.search.activate();
        await tester.pumpAndSettle();
        expect(inner.search.isActive, isTrue, reason: 'precondition');
        await back(app, tester);
        expect(
          inner.search.isActive,
          isFalse,
          reason: "the inner shell's order",
        );
        expect(app.shellPopped, isFalse);
        await back(app, tester);
        expect(app.shellPopped, isTrue, reason: 'nothing left inside');
      });

      testWidgets('iPad, a shell nested in a tab, its overlay sidebar open '
          'over its active search and a pushed page: back closes the '
          'sidebar, then the search, then pops the page', (tester) async {
        final app = _Pushed(mode);
        final inner = _Inner();
        await inner.pump(app, tester, size: kTabletPortrait);
        await _pushOn(tester, inner.tabs[2], 'Deep');
        inner.search.activate();
        await tester.pumpAndSettle();
        // The outer shell's bar covers the inner one's button: the inner
        // shell's scope opens its sidebar, as the button does.
        LiquidShellScopeData scope() =>
            LiquidShellScope.of(tester.element(_page('Deep')));
        scope().setSidebarVisible(true);
        await tester.pumpAndSettle();
        expect(
          scope().chromeKind,
          LiquidChromeKind.sidebarOverlay,
          reason: 'precondition',
        );
        expect(inner.search.isActive, isTrue, reason: 'precondition');

        await back(app, tester);
        expect(_page('Deep'), findsOneWidget, reason: 'the sidebar first');
        expect(scope().chromeKind, isNot(LiquidChromeKind.sidebarOverlay));
        expect(inner.search.isActive, isTrue, reason: 'the sidebar first');
        expect(app.shellPopped, isFalse);

        await back(app, tester);
        expect(inner.search.isActive, isFalse, reason: 'the search next');
        expect(_page('Deep'), findsOneWidget);
        expect(app.shellPopped, isFalse);

        await back(app, tester);
        expect(_page('Deep'), findsNothing, reason: 'the page last');
        expect(app.shellPopped, isFalse);
      });
```

- [ ] **Step 3: see them red**

Run: `flutter test test/widget/pushed_shell_back_test.dart --plain-name "a shell nested in a tab"`
Expected: FAIL, all six (`+0 -6`):

- `its search active over a pushed page` (both modes):
  ```
  Expected: exactly one matching candidate
    Actual: _TextWidgetFinder:<Found 0 widgets with text "Deep page: 0": []>
  search first
  ```
- `its search active at the tab root` (both modes): `Expected: false  Actual: <true>` (`app.shellPopped`, the outer shell popped).
- `iPad, …` (both modes): `Found 0 widgets with text "Deep page: 0"`, reason `the sidebar first`.

(The outer shell pops the inner shell's tab navigator directly, past its sidebar and its search.)

- [ ] **Step 4: the record and the interface**

In `branch_navigators.dart`, replace

```dart
/// so the per-frame check can see it come on screen.
typedef BranchNavigator = ({
  NavigatorState navigator,
  bool handled,
  bool onScreen,
});
```

with

```dart
/// so the per-frame check can see it come on screen.
///
/// `target` is a `NavigatorState`, or a [NestedShellBack]: a shell nested in
/// the body (sub-tabs), which answers back in its own order.
typedef BranchNavigator = ({State target, bool handled, bool onScreen});

/// A shell in another shell's body: the outer one hands it back, as its
/// own route would (overlay sidebar, then search, then its tab's page).
abstract interface class NestedShellBack {
  /// Whether it would block a pop now.
  bool get claimsBack;

  /// Back, blocked: it closes, deactivates or pops one thing.
  void handleBack();
}
```

- [ ] **Step 5: the walk stops at a nested shell**

In the doc comment of `onScreenNavigatorsUnder`, replace

```dart
/// A branch hidden by [_hides] or [_shows] is skipped, but for its first
/// navigator (a hidden tab's own), recorded with `onScreen` false.
```

with

```dart
/// A branch hidden by [_hides] or [_shows] is skipped, but for its first
/// navigator (a hidden tab's own), recorded with `onScreen` false. A
/// shell nested in the body ([NestedShellBack]) is recorded, not walked:
/// its tabs are its own.
```

In `visit`, replace

```dart
    if (element case StatefulElement(state: final NavigatorState navigator)) {
      found.add((
        navigator: navigator,
        handled: handledHere,
        onScreen: shownHere,
      ));
    }
```

with

```dart
    if (element case StatefulElement(state: final NestedShellBack _)) {
      // Its tab navigators are its own to pop (VK-774).
      found.add((
        target: element.state,
        handled: handledHere,
        onScreen: shownHere,
      ));
      return;
    }
    if (element case StatefulElement(state: final NavigatorState navigator)) {
      found.add((target: navigator, handled: handledHere, onScreen: shownHere));
    }
```

- [ ] **Step 6: the shell delegates and is delegated to**

In `liquid_shell.dart`:

1. `class _LiquidShellState extends State<LiquidShell>` gets the interface: `implements HideChromeRegistry, PageRegistry, NestedShellBack {`.
2. After `bool _branchCheckArmed = false;` add:

   ```dart
     // What the last build's [_backScope] blocks for (VK-774).
     bool _backOverlay = false;
     bool _backSearch = false;
   ```

3. In `_checkBranches`, replace the loop body's navigator reads:

   ```dart
         final onScreen =
             body != null &&
             b.target.mounted &&
             isOnScreenUnder(b.target.context, body);
         if (rescan && onScreen != b.onScreen && b.target.mounted) {
           _scanBranches();
           return;
         }
         if (onScreen && _canPop(b.target)) canPop = true;
   ```

4. In `_popBranch`, replace the loop (from `for (final (:navigator, :handled, :onScreen) in _branches.reversed) {` to its closing `}`) with:

   ```dart
       for (final (:target, :handled, :onScreen) in _branches.reversed) {
         if (!onScreen || !target.mounted || !_canPop(target)) continue;
         // The app's NavigatorPopHandler around it asks the same navigator in
         // the same turn: a second ask would close a drawer and pop its page.
         if (handled) return;
         if (target is NestedShellBack) {
           (target as NestedShellBack).handleBack();
           return;
         }
         final navigator = target as NavigatorState;
         unawaited(
           _maybePop(navigator).whenComplete(() {
             if (mounted) _scheduleBranchScan();
           }),
         );
         return;
       }
   ```

5. Replace `_backScope` (from `  Widget _backScope({` to `  );`, keeping its doc comment) with:

   ```dart
     Widget _backScope({
       required bool overlay,
       required bool searchActive,
       required Widget child,
     }) {
       _backOverlay = overlay;
       _backSearch = searchActive;
       return PopScope(
         canPop: !claimsBack,
         onPopInvokedWithResult: (didPop, _) {
           if (!didPop) handleBack();
         },
         child: child,
       );
     }

     @override
     bool get claimsBack => _backOverlay || _backSearch || _branchCanPop;

     @override
     void handleBack() {
       if (_backOverlay) {
         _setSidebarVisible(false);
       } else if (_backSearch) {
         _search.deactivate();
       } else {
         _popBranch();
       }
     }

     static bool _canPop(State target) => switch (target) {
       NavigatorState() => target.canPop(),
       NestedShellBack() => (target as NestedShellBack).claimsBack,
       _ => false,
     };
   ```

- [ ] **Step 7: see them green, the file, the package, analyze**

Run: `flutter test test/widget/pushed_shell_back_test.dart` then `flutter test --exclude-tags golden,impeller,liquid_golden` then `flutter analyze`
Expected: `+87: All tests passed!`, `+1272: All tests passed!`, `No issues found!`

- [ ] **Step 8: docs**

In `doc/router_integration.md`, under "Known limits:", delete the bullet that starts `- **A shell nested in another shell's body (sub-tabs).**` (six lines, up to `the outer shell's.`), and add to the list above it, after the `A navigator inside a tab's page` bullet:

```markdown
- **A shell nested in another shell's body (sub-tabs)** answers back in
  its own order, as back to its own route would: its overlay sidebar
  closes, then its active search ends, then its tab's page pops. The
  outer shell's route and edge swipe wait until it has nothing left.
```

Append under `## 0.1.0-dev.8` in `CHANGELOG.md`, after Task 2's line:

```markdown
- **Fix (VK-774).** A shell nested in another shell's body (sub-tabs)
  answers back in its own order: its overlay sidebar closes, then its
  active search ends, then its tab's page pops. Before, the outer shell
  popped the inner shell's tab page directly.
- **Behaviour change (VK-774).** With a nested shell's search active at
  its tab's root, back ends that search instead of popping the outer
  shell's route.
```

Check from the repo root: `tool/check_public_docs.sh` → `✓ public docs clean`.

- [ ] **Step 9: commit**

```bash
dart format lib test && cd .. && .githooks/pre-commit && git add liquid_shell/lib/src/shell/branch_navigators.dart liquid_shell/lib/src/shell/liquid_shell.dart liquid_shell/test/widget/pushed_shell_back_test.dart liquid_shell/doc/router_integration.md liquid_shell/CHANGELOG.md && git commit -m "fix(shell): a nested shell answers back in its own order (VK-774)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 10: the mutations**

Each on the committed code, whole package (`flutter test --exclude-tags golden,impeller,liquid_golden`), record, revert with `git checkout -- lib/src/shell/<file>`, `git status` clean:

| | File | Mutation | Red tests | Prototype |
|---|---|---|---|---|
| M6 | `branch_navigators.dart` | delete the `return;` after the `NestedShellBack` `found.add(…)` (the walk goes into the nested shell) | `its search active over a pushed page`, `iPad, …` | red (4) |
| M7 | `liquid_shell.dart` | `NestedShellBack() => (target as NestedShellBack).claimsBack,` → `NestedShellBack() => false,` | the three nested-shell tests | red (6) |
| M8 | `liquid_shell.dart` | in `handleBack`, swap the overlay and search branches (search first) | `iPad, …` | red (2) |
| M9 | `liquid_shell.dart` | `claimsBack => _backOverlay \|\| _backSearch \|\| _branchCanPop` → `_backOverlay \|\| _branchCanPop` | `its search active at the tab root` and 5 search tests in `native_search_test.dart`, `search_fallback_test.dart` | red (7) |
| M10 | `liquid_shell.dart` | delete `(target as NestedShellBack).handleBack();` in `_popBranch` | the three nested-shell tests | red (6) |

---

### Task 4: the branch

- [ ] **Step 1: `make verify`**

From the repo root: `make verify`. Expected: every step green but `goldens`, red only at the 8 band images of the Global Constraints. Paste the tail into the task report.
