# liquid_shell VK-593: back and the edge swipe find the right navigator, Implementation Plan

> **Approval:** the owner approved the spec `docs/specs/2026-10-23-nested-back-design.md` ("Ổn", 2026-10-23). This plan implements it. Its §12 lists what the prototype changed against the first draft of the spec.
>
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** System back and the iOS edge swipe pop the page the user sees: the deepest navigator on screen that can pop, exactly once (spec §1).

**Architecture:** All the logic stays in `liquid_shell/lib/src/shell/branch_navigators.dart`: which navigators are on screen, and whether the app answers back for one. `_popBranch` in `liquid_shell.dart` keeps its rule, "the last in tree order that can pop": once the walk goes on into navigators, a nested navigator comes after the one it is in, so that rule pops it first (spec §12). T1 is a one-line guard in `window_controls.dart`. Every test is a widget test; the back tests extend the VK-567 harness in `pushed_shell_back_test.dart` and run in both chrome modes (native through the fake platform, and Flutter).

**Tech Stack:** Dart 3.12 / Flutter 3.44.6; `flutter_test`.

**Prototype (2026-10-23).** Every test and every line of production code below ran in the worktree before this plan was written, then was removed:
- each red-first test was red at `8bd7353` for the reason the task gives, and green with the task's code;
- the mutations in the tables of Tasks 2–5 were run; all turned their tests red but Task 2's B, which stayed green, as the spec allows (§5);
- `make verify` passed every step but `goldens`: the same 8 `liquid`/`tab_lens` band images that are red on this machine on `main` too (GPU, not code; CI `goldens (3.44.x)` is the reference). `liquid_shell` coverage 97.69 %, 1254 tests.

## Global Constraints

- Run `.githooks/pre-commit` by hand before every commit (`.githooks/pre-commit && git commit …`). Never `--no-verify`. Never change git config; never set `core.hooksPath`.
- Commit messages `<type>(<scope>): <summary> (VK-593)`, scope `shell` (tests too) or `docs`. Every commit ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- No pushes, no remotes, no publishing: the controller pushes.
- TDD: run each red-first test and see it red for the reason the task gives before writing the production code.
- No public API change. No Swift, no Pigeon, no platform-interface change, no version bump. CHANGELOG lines go under the existing `## 0.1.0-dev.8` of `liquid_shell/CHANGELOG.md`.
- Never loosen `analysis_options.yaml`. `dart format` before committing.
- `make verify` red only at `goldens` with the 8 band images `tab_lens_pressed`, `tab_lens_straddle`, `tab_lens_pressed_dark`, `tab_glow_release_dark`, `liquid_default`, `liquid_refraction_0`, `liquid_refraction_2`, `liquid_dispersion_03` is this machine, not the branch: report it, do not touch goldens.
- Run commands from `liquid_shell/` unless a step says otherwise. Python, if needed, with `python3 -I`.

## File map

| File | Tasks | Responsibility |
|---|---|---|
| `liquid_shell/lib/src/native/window_controls.dart` | 1 | the NaN guard |
| `liquid_shell/lib/src/shell/branch_navigators.dart` | 3, 4, 5 | which navigators are on screen, `handled` |
| `liquid_shell/test/helpers/kept_alive.dart` (new) | 1 | `KeptAlive`, shared by two test files |
| `liquid_shell/test/widget/window_controls_test.dart` | 1 | T1 test |
| `liquid_shell/test/widget/pushed_shell_back_test.dart` | 2, 3, 4, 5 | harness additions and the back tests |
| `liquid_shell/doc/router_integration.md`, `liquid_shell/README.md` | 3, 4, 5 | the back rules and known limits |
| `liquid_shell/CHANGELOG.md` | 1, 3, 4, 5 | one Fixed line each |

---

### Task 1 (VK-686): a row kept alive off screen does not rebuild every frame

**Files:**
- Create: `liquid_shell/test/helpers/kept_alive.dart`
- Modify: `liquid_shell/test/widget/window_controls_test.dart` (import; one test in group `LiquidWindowControlsClearance`, before `'a metrics change reads the controls again'`)
- Modify: `liquid_shell/lib/src/native/window_controls.dart:185-191`
- Modify: `liquid_shell/CHANGELOG.md`

**Interfaces:** Produces `KeptAlive({required Widget child})` in `test/helpers/kept_alive.dart` (Task 4 uses it).

- [ ] **Step 1: the shared test helper**

`liquid_shell/test/helpers/kept_alive.dart`:

```dart
import 'package:flutter/widgets.dart';

/// Keeps a scroll child (a `PageView` page) alive once built: off screen
/// it stays in the tree, not laid out.
class KeptAlive extends StatefulWidget {
  /// Keeps [child] alive.
  const KeptAlive({required this.child, super.key});

  /// The page.
  final Widget child;

  @override
  State<KeptAlive> createState() => _KeptAliveState();
}

class _KeptAliveState extends State<KeptAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
```

- [ ] **Step 2: the failing test**

In `window_controls_test.dart`, add `import '../helpers/kept_alive.dart';` after the `fake_native_platform.dart` import, and this test before `'a metrics change reads the controls again'` (`_titlePage` exists in the file):

```dart
    // VK-593 T1: a row kept alive off screen measures NaN; NaN != NaN, so
    // each measure set it again and asked for another frame, for ever.
    testWidgets('a row kept alive off screen does not rebuild every frame', (
      tester,
    ) async {
      final pages = PageController();
      addTearDown(pages.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: PageView(
            controller: pages,
            children: [
              for (var i = 0; i < 2; i++) KeptAlive(child: _titlePage(i)),
            ],
          ),
        ),
      );
      pages.jumpToPage(1);
      await tester.pumpAndSettle();
      pages.jumpToPage(0);
      await tester.pumpAndSettle();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
```

- [ ] **Step 3: see it red**

Run: `flutter test test/widget/window_controls_test.dart --plain-name "kept alive off screen"`
Expected: FAIL, `pumpAndSettle timed out` (each post-frame measure of the off-screen row reads `NaN` and calls `setState`).

- [ ] **Step 4: the guard**

In `window_controls.dart`, `_scheduleMeasure`, replace `if (start != _start) {` with:

```dart
      // A row kept alive off screen (a PageView page) measures NaN, and
      // NaN != NaN: without this, every frame would set it again.
      final same = start == _start || (start.isNaN && (_start?.isNaN ?? false));
      if (!same) {
```

- [ ] **Step 5: see it green, and the file's other tests**

Run: `flutter test test/widget/window_controls_test.dart`
Expected: `All tests passed!`

- [ ] **Step 6: CHANGELOG**

Append to the list under `## 0.1.0-dev.8`:

```markdown
- A page title kept alive off screen (a `PageView` page) no longer
  rebuilds on every frame (VK-593).
```

- [ ] **Step 7: commit**

```bash
dart format lib test && cd .. && .githooks/pre-commit && git add liquid_shell/test/helpers/kept_alive.dart liquid_shell/test/widget/window_controls_test.dart liquid_shell/lib/src/native/window_controls.dart liquid_shell/CHANGELOG.md && git commit -m "fix(shell): a title kept alive off screen stops rebuilding every frame (VK-593)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2 (VK-687): lock the re-scan mechanisms of `_popBranch`

Tests only; no production change. Each test is checked with a temporary mutation that removes one mechanism.

**Files:**
- Modify: `liquid_shell/test/widget/pushed_shell_back_test.dart`

**Interfaces:** Produces in `pushed_shell_back_test.dart`: the class `_LateShow({required int index, required List<Widget> children})`; the group `'VK-593 (${mode.name}): back finds the right navigator'` inside the `for (final mode in _Mode.values)` loop, after the VK-567 group, with the local helper `back(_Pushed app, WidgetTester tester)`. Tasks 3–5 add their tests to this group.

- [ ] **Step 1: the late-show body**

Add after the class `_LateHideState` (before `void main()`):

```dart
/// Branches kept as a router keeps them, but the one selected comes on
/// screen 300 ms after the selection (the end of a cross-fade), the one
/// left at once: for a moment no branch is on screen.
class _LateShow extends StatefulWidget {
  const _LateShow({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_LateShow> createState() => _LateShowState();
}

class _LateShowState extends State<_LateShow> {
  late int? _shown = widget.index;
  Timer? _timer;

  @override
  void didUpdateWidget(_LateShow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    _shown = null;
    _timer?.cancel();
    _timer = Timer(
      const Duration(milliseconds: 300),
      () => setState(() => _shown = widget.index),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      for (final (i, child) in widget.children.indexed)
        Offstage(offstage: i != _shown, child: child),
    ],
  );
}
```

- [ ] **Step 2: the group and the three tests**

Inside the `for (final mode in _Mode.values)` loop, after the closing `});` of the `'VK-567 (${mode.name}): …'` group, add:

```dart
    group('VK-593 (${mode.name}): back finds the right navigator', () {
      Future<void> back(_Pushed app, WidgetTester tester) async {
        await app.outer.currentState!.maybePop();
        await tester.pumpAndSettle();
      }

      // T2: the three re-scan mechanisms of `_popBranch`, each locked.
      // An app's PopScope blocks the shell's route, so `_popBranch` runs
      // even when the shell's own answer is stale.
      testWidgets('T2: back reaches a branch that came on screen after the '
          'last scan', (tester) async {
        final app = _Pushed(mode);
        await app.pump(
          tester,
          around: (shell) => PopScope<Object?>(canPop: false, child: shell),
          body: (index, pages) => _LateShow(index: index, children: pages),
        );
        await app.select(tester, 1);
        await app.push(tester, 1, 'Kept');
        await app.select(tester, 0);
        app.shell.currentState!.select(1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await back(app, tester);
        expect(_page('Kept'), findsNothing, reason: 'the fresh scan found it');
        expect(_page('Library'), findsOneWidget);
      });

      testWidgets("T2: after back pops a branch's last page, the next back "
          "pops the shell's route", (tester) async {
        final app = _Pushed(mode);
        await app.pump(tester);
        await app.push(tester, 0, 'Detail');
        await back(app, tester);
        expect(_page('Home'), findsOneWidget);
        await back(app, tester);
        expect(app.shellPopped, isTrue);
      });

      testWidgets('T2: two navigators as deep on screen: back pops the last '
          'in tree order', (tester) async {
        final app = _Pushed(mode);
        await app.pump(
          tester,
          body: (_, pages) => Row(
            children: [
              Expanded(child: pages[0]),
              Expanded(child: pages[1]),
            ],
          ),
        );
        await app.push(tester, 0, 'Master');
        await app.push(tester, 1, 'Detail');
        await back(app, tester);
        expect(_page('Detail'), findsNothing);
        expect(
          _page('Master'),
          findsOneWidget,
          reason: 'the earlier one stays',
        );
      });
    });
```

- [ ] **Step 3: run them**

Run: `flutter test test/widget/pushed_shell_back_test.dart --plain-name "T2:"`
Expected: `All tests passed!` (6 tests: three per mode). They lock today's behaviour.

- [ ] **Step 4: the mutations**

Apply each mutation to `liquid_shell/lib/src/shell/liquid_shell.dart` (`_popBranch`), run the named test, record the result in the task report, revert (`git checkout -- lib/src/shell/liquid_shell.dart`), and check `git status` is clean in `lib/` before the next one:

| | Mutation | Test (`--plain-name`) | Prototype result |
|---|---|---|---|
| A | delete the `if (SchedulerBinding.instance.schedulerPhase != …) { _scanBranches(); }` block | `came on screen after the last scan` | red (2) |
| B | replace `_maybePop(navigator).whenComplete(() { if (mounted) _scheduleBranchScan(); })` with `_maybePop(navigator)` | `last page, the next back` | **green**: the pop's own `NavigationNotification` re-scans. Spec §5: report, keep the mechanism; the owner decides |
| C | `_branches.reversed` → `_branches` | `two navigators as deep` | red (2) |

- [ ] **Step 5: commit**

```bash
dart format test && cd .. && .githooks/pre-commit && git add liquid_shell/test/widget/pushed_shell_back_test.dart && git commit -m "test(shell): lock the re-scans of the shell's branch pop (VK-593)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3 (VK-688): a `NavigatorPopHandler` with a callback answers back, enabled or not

**Files:**
- Modify: `liquid_shell/lib/src/shell/branch_navigators.dart` (typedef doc, new `_answersBack`, one line in `onScreenNavigatorsUnder`)
- Modify: `liquid_shell/test/widget/pushed_shell_back_test.dart` (group `VK-593`)
- Modify: `liquid_shell/doc/router_integration.md:77-80`, `liquid_shell/CHANGELOG.md`

**Interfaces:** `BranchNavigator` keeps its shape `({NavigatorState navigator, bool handled})`; only the meaning of `handled` changes.

- [ ] **Step 1: the tests**

Add to the `VK-593` group:

```dart
      // T3: Flutter calls a disabled handler's callback too when the
      // shell blocks the route; the shell must not pop again. A callback
      // that pops at once shows it: the shell's `maybePop` then finds the
      // next page on top (a `maybePop` callback is saved by the
      // navigator's own check that its top did not change).
      testWidgets('a disabled NavigatorPopHandler with a callback: one back '
          'pops one page', (tester) async {
        final app = _Pushed(mode);
        await app.pump(
          tester,
          wrap: (i, navigator) => NavigatorPopHandler(
            enabled: false,
            onPopWithResult: (_) => app.tabs[i].currentState?.pop(),
            child: navigator,
          ),
        );
        await app.push(tester, 0, 'One');
        await app.push(tester, 0, 'Two');
        await back(app, tester);
        expect(_page('Two'), findsNothing);
        expect(_page('One'), findsOneWidget, reason: 'not two pages');
      });

      // T3: a handler with no callback answers nothing; the shell pops.
      testWidgets('a NavigatorPopHandler with no callback: back still pops '
          'the page', (tester) async {
        final app = _Pushed(mode);
        await app.pump(
          tester,
          wrap: (_, navigator) => NavigatorPopHandler(child: navigator),
        );
        await app.push(tester, 0, 'Detail');
        await back(app, tester);
        expect(_page('Detail'), findsNothing, reason: 'back not swallowed');
        expect(_page('Home'), findsOneWidget);
        expect(app.shellPopped, isFalse);
      });
```

- [ ] **Step 2: see them**

Run: `flutter test test/widget/pushed_shell_back_test.dart --plain-name "NavigatorPopHandler with"`
Expected: `a NavigatorPopHandler with no callback` FAILS in both modes: `Expected: no matching candidates`, `Actual: … "Detail page: 0"` (back swallowed). `a disabled NavigatorPopHandler with a callback` PASSES today (spec §12: the double pop does not happen on 3.44.6); it guards the change.

- [ ] **Step 3: the rule**

In `branch_navigators.dart`, replace the typedef and its doc with:

```dart
/// A navigator on screen under the shell's body, and whether a
/// `NavigatorPopHandler` with a callback lies between the body and it: the
/// route calls that callback on every blocked back, enabled or not, so the
/// app answers back for it.
typedef BranchNavigator = ({NavigatorState navigator, bool handled});
```

add after `_hides`:

```dart
/// Whether a `NavigatorPopHandler` answers back: it has a callback.
bool _answersBack(Widget widget) => switch (widget) {
  NavigatorPopHandler(:final onPopWithResult) when onPopWithResult != null =>
    true,
  // The deprecated callback still runs.
  // ignore: deprecated_member_use
  NavigatorPopHandler(:final onPop) when onPop != null => true,
  _ => false,
};
```

and in `onScreenNavigatorsUnder` replace

```dart
    final handledHere =
        handled || (widget is NavigatorPopHandler && widget.enabled);
```

with

```dart
    final handledHere = handled || _answersBack(widget);
```

- [ ] **Step 4: see them green, and the file**

Run: `flutter test test/widget/pushed_shell_back_test.dart`
Expected: `All tests passed!`

- [ ] **Step 5: the mutation**

Replace `_answersBack(widget)` with `widget is NavigatorPopHandler`; run `--plain-name "with no callback"`; expected red (prototype: 2); revert.

- [ ] **Step 6: docs**

In `doc/router_integration.md`, replace the bullet that starts `- **Remove a \`NavigatorPopHandler\` around a branch navigator**` with:

```markdown
- **Remove a `NavigatorPopHandler` around a branch navigator**: the shell
  does its job. One the app keeps with a callback (`onPopWithResult`)
  answers back for its navigator, enabled or not (Flutter calls it on
  every blocked back), and the shell then only blocks its own route, so
  one back is still one step: an open drawer or sheet closes, and its page
  stays. One without a callback is ignored.
```

Append under `## 0.1.0-dev.8` in `CHANGELOG.md`:

```markdown
- Back is no longer swallowed by a `NavigatorPopHandler` with no callback
  around a branch navigator; one with a callback answers back whether
  `enabled` or not (VK-593).
```

- [ ] **Step 7: commit**

```bash
dart format lib test && cd .. && .githooks/pre-commit && git add liquid_shell/lib/src/shell/branch_navigators.dart liquid_shell/test/widget/pushed_shell_back_test.dart liquid_shell/doc/router_integration.md liquid_shell/CHANGELOG.md && git commit -m "fix(shell): a NavigatorPopHandler answers back by its callback, not its enabled flag (VK-593)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4 (VK-689): a scroll child off screen does not count

**Files:**
- Modify: `liquid_shell/lib/src/shell/branch_navigators.dart` (`_shows`, new `_position`, `_inWindow`)
- Modify: `liquid_shell/test/widget/pushed_shell_back_test.dart` (import, `_PagedBody`, three tests)
- Modify: `liquid_shell/doc/router_integration.md:83-85`, `liquid_shell/CHANGELOG.md`

**Interfaces:** Consumes `KeptAlive` (Task 1). Produces `_PagedBody({required int index, required List<Widget> children, bool cached = false})` in the test file.

- [ ] **Step 1: the paged body**

In `pushed_shell_back_test.dart` add `import '../helpers/kept_alive.dart';` after the `fake_native_platform.dart` import, and before `void main()`:

```dart
/// The tabs as the pages of a `PageView`, the selected one jumped to. Each
/// is kept alive (the tab left stays in the tree, not laid out), or, with
/// [cached], laid out in the cache extent beside the one on screen.
class _PagedBody extends StatefulWidget {
  const _PagedBody({
    required this.index,
    required this.children,
    this.cached = false,
  });

  final int index;
  final List<Widget> children;
  final bool cached;

  @override
  State<_PagedBody> createState() => _PagedBodyState();
}

class _PagedBodyState extends State<_PagedBody> {
  late final _controller = PageController(initialPage: widget.index);

  @override
  void didUpdateWidget(_PagedBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) _controller.jumpToPage(widget.index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageView(
    controller: _controller,
    allowImplicitScrolling: widget.cached,
    children: [
      for (final child in widget.children)
        widget.cached ? child : KeptAlive(child: child),
    ],
  );
}
```

- [ ] **Step 2: the tests**

Add to the `VK-593` group:

```dart
      // T4: a tab kept alive in a PageView, off screen.
      testWidgets('tabs as kept-alive PageView pages: back never pops the '
          'page of a tab off screen', (tester) async {
        final app = _Pushed(mode);
        await app.pump(
          tester,
          body: (index, pages) => _PagedBody(index: index, children: pages),
        );
        await app.select(tester, 1);
        await app.push(tester, 1, 'Kept');
        await app.select(tester, 0);
        final library = app.tabs[1].currentState!;
        await app.outer.currentState!.maybePop();
        // One frame: a pop it asked for has landed, the shell still mounted.
        await tester.pump();
        expect(library.canPop(), isTrue, reason: "Library's page is kept");
        await tester.pumpAndSettle();
        expect(app.shellPopped, isTrue, reason: 'Home is at its root');
      });

      testWidgets('tabs as kept-alive PageView pages: back pops the page of '
          'the tab on screen', (tester) async {
        final app = _Pushed(mode);
        await app.pump(
          tester,
          body: (index, pages) => _PagedBody(index: index, children: pages),
        );
        await app.select(tester, 1);
        await app.push(tester, 1, 'Kept');
        await app.select(tester, 0);
        await app.push(tester, 0, 'Detail');
        await back(app, tester);
        expect(_page('Detail'), findsNothing);
        expect(app.tabs[1].currentState!.canPop(), isTrue, reason: 'kept');
        expect(app.shellPopped, isFalse);
      });

      // T4: a page laid out in the cache extent, not on screen.
      testWidgets('tabs as PageView pages in the cache extent: back never '
          'pops the page of a tab off screen', (tester) async {
        final app = _Pushed(mode);
        await app.pump(
          tester,
          body: (index, pages) =>
              _PagedBody(index: index, cached: true, children: pages),
        );
        await app.select(tester, 1);
        await app.push(tester, 1, 'Kept');
        await app.select(tester, 0);
        final library = app.tabs[1].currentState!;
        expect(library.mounted, isTrue, reason: 'in the cache extent');
        await app.outer.currentState!.maybePop();
        await tester.pump();
        expect(library.canPop(), isTrue, reason: "Library's page is kept");
        await tester.pumpAndSettle();
        expect(app.shellPopped, isTrue, reason: 'Home is at its root');
      });
```

- [ ] **Step 3: see them red**

Run: `flutter test test/widget/pushed_shell_back_test.dart --plain-name "PageView pages"`
Expected: all six FAIL: `back never pops …` with `Expected: true`, `Actual: <false>` (Library's hidden page was popped); `back pops the page of the tab on screen` with `Expected: no matching candidates`, `Actual: … "Detail page: 0"` (Library's page popped instead). Without Task 1 they time out in `pumpAndSettle` instead: Task 1 must be in.

- [ ] **Step 4: the rule**

In `branch_navigators.dart`, replace `_shows` and its doc with:

```dart
/// Whether [parent] shows its child [child]:
/// - an `IndexedStack` shows only the child at its index, and its render
///   object is what says so: from Flutter 3.47 it no longer wraps the
///   others in a `Visibility` widget;
/// - a scrolling list (`PageView`, `ListView`) shows a child laid out in
///   its visible window, not one kept alive or in the cache extent.
bool _shows(Element parent, Element child) {
  if (parent is! RenderObjectElement) return true;
  final render = parent.renderObject;
  if (render is RenderIndexedStack) {
    return _position(parent, child) == render.index;
  }
  if (render is RenderSliverMultiBoxAdaptor) return _inWindow(render, child);
  return true;
}

int _position(Element parent, Element child) {
  var position = 0;
  var found = -1;
  parent.visitChildren((element) {
    if (identical(element, child)) found = position;
    position++;
  });
  return found;
}

bool _inWindow(RenderSliverMultiBoxAdaptor sliver, Element child) {
  final box = child.renderObject;
  if (box is! RenderBox || !box.hasSize) return false;
  final data = box.parentData;
  if (data is! SliverMultiBoxAdaptorParentData || data.keptAlive) {
    return false;
  }
  final start = sliver.childScrollOffset(box);
  if (start == null) return false;
  final constraints = sliver.constraints;
  final extent = constraints.axis == Axis.horizontal
      ? box.size.width
      : box.size.height;
  final windowStart = constraints.scrollOffset;
  final windowEnd = windowStart + constraints.remainingPaintExtent;
  return start < windowEnd && start + extent > windowStart;
}
```

- [ ] **Step 5: see them green, and the file**

Run: `flutter test test/widget/pushed_shell_back_test.dart`
Expected: `All tests passed!`

- [ ] **Step 6: the mutation**

Replace `return start < windowEnd && start + extent > windowStart;` with `return true;`; run `--plain-name "cache extent"`; expected red (prototype: 2); revert.

- [ ] **Step 7: docs**

In `doc/router_integration.md`, replace the bullet `- **Several navigators on screen** (an iPad detail beside its master, or a \`PageView\` whose neighbours stay alive): back pops the last one in tree order that can pop.` with:

```markdown
- **Several navigators on screen** (an iPad detail beside its master):
  back pops the last one in tree order that can pop. A `PageView` or list
  page off screen (kept alive, or in the cache extent) does not count.
```

Append under `## 0.1.0-dev.8` in `CHANGELOG.md`:

```markdown
- Back no longer pops a page in a `PageView` or list page that is off
  screen (kept alive, or in the cache extent) (VK-593).
```

- [ ] **Step 8: commit**

```bash
dart format lib test && cd .. && .githooks/pre-commit && git add liquid_shell/lib/src/shell/branch_navigators.dart liquid_shell/test/widget/pushed_shell_back_test.dart liquid_shell/doc/router_integration.md liquid_shell/CHANGELOG.md && git commit -m "fix(shell): back skips a PageView page off screen (VK-593)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5 (VK-690): the inner navigator of a tab's page pops first

**Files:**
- Modify: `liquid_shell/lib/src/shell/branch_navigators.dart` (overlay rule; the walk goes on into navigators)
- Modify: `liquid_shell/test/widget/pushed_shell_back_test.dart` (harness `root`, `_flow`, `_pushOn`, five tests)
- Modify: `liquid_shell/doc/router_integration.md` (known limit), `liquid_shell/README.md` (known issue), `liquid_shell/CHANGELOG.md`

**Interfaces:** `BranchNavigator` and `liquid_shell.dart` do not change. `_popBranch` already pops "the last in tree order that can pop"; the walk now lists a nested navigator right after the one it is in, so it pops first.

- [ ] **Step 1: the harness takes a root page**

In class `_Pushed`, after `late final LiquidSearchController search;`, add:

```dart
  /// The root page of a tab, when a test gives its own (a nested flow);
  /// null keeps the default.
  Widget? Function(int index)? root;
```

In `branch`, replace `builder: (_) => LiquidPage(title: label, child: TestPage(label: label)),` with:

```dart
        builder: (_) =>
            root?.call(index) ??
            LiquidPage(
              title: label,
              child: TestPage(label: label),
            ),
```

In `pump`, add the parameter `Widget? Function(int index)? root,` after `body`, and `this.root = root;` as the first line of the body. Then add before `void main()`:

```dart
/// A page that holds its own navigator (a nested flow): its root is the
/// test page of [label].
Widget _flow(GlobalKey<NavigatorState> inner, String label) => Navigator(
  key: inner,
  onGenerateRoute: (_) => MaterialPageRoute<void>(
    builder: (_) => LiquidPage(
      title: label,
      child: TestPage(label: label),
    ),
  ),
);

/// Pushes a plain page titled [title] on [navigator].
Future<void> _pushOn(
  WidgetTester tester,
  GlobalKey<NavigatorState> navigator,
  String title,
) async {
  navigator.currentState!
      .push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(body: Center(child: Text('$title page: 0'))),
        ),
      )
      .ignore();
  await tester.pumpAndSettle();
}
```

- [ ] **Step 2: the tests**

Add to the `VK-593` group:

```dart
      // T5: a nested flow in the tab's root page.
      testWidgets("a nested flow at the tab's root: back pops the inner page, "
          'then the shell', (tester) async {
        final inner = GlobalKey<NavigatorState>();
        final app = _Pushed(mode);
        await app.pump(
          tester,
          root: (i) => i == 0 ? _flow(inner, 'Home') : null,
        );
        await _pushOn(tester, inner, 'Inner');
        await back(app, tester);
        expect(_page('Inner'), findsNothing);
        expect(_page('Home'), findsOneWidget);
        expect(app.shellPopped, isFalse);
        await back(app, tester);
        expect(app.shellPopped, isTrue);
      });

      testWidgets("a nested flow at the tab's root: the edge swipe pops the "
          'inner page, not the shell', (tester) async {
        final inner = GlobalKey<NavigatorState>();
        final app = _Pushed(mode);
        await app.pump(
          tester,
          root: (i) => i == 0 ? _flow(inner, 'Home') : null,
        );
        await _pushOn(tester, inner, 'Inner');
        await _swipeFromTheEdge(tester);
        expect(app.shellPopped, isFalse);
        expect(_page('Inner'), findsNothing);
        expect(_page('Home'), findsOneWidget);
      });

      testWidgets('a nested flow on a pushed page: the inner page pops '
          "first, then the tab's page", (tester) async {
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
        await back(app, tester);
        expect(_page('Inner'), findsNothing);
        expect(_page('Flow'), findsOneWidget, reason: 'the inner page only');
        await back(app, tester);
        expect(_page('Flow'), findsNothing);
        expect(_page('Home'), findsOneWidget);
        expect(app.shellPopped, isFalse);
      });

      testWidgets('a dialog over a page with a nested flow: back closes the '
          'dialog, the inner page stays', (tester) async {
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
        await back(app, tester);
        expect(find.text('The dialog'), findsNothing);
        expect(_page('Inner'), findsOneWidget, reason: 'under the dialog');
      });

      // T5: an entry an app inserts in the tab's overlay (a toast) is not a
      // route: the nested flow under it still pops first.
      testWidgets('a toast in the tab overlay over a nested flow: back still '
          'pops the inner page', (tester) async {
        final inner = GlobalKey<NavigatorState>();
        final app = _Pushed(mode);
        await app.pump(
          tester,
          root: (i) => i == 0 ? _flow(inner, 'Home') : null,
        );
        await _pushOn(tester, inner, 'Inner');
        final toast = OverlayEntry(builder: (_) => const Text('The toast'));
        app.tabs[0].currentState!.overlay!.insert(toast);
        addTearDown(toast.remove);
        await tester.pumpAndSettle();
        await back(app, tester);
        expect(_page('Inner'), findsNothing);
        expect(_page('Home'), findsOneWidget);
        expect(app.shellPopped, isFalse);
      });
```

- [ ] **Step 3: see them**

Run: `flutter test test/widget/pushed_shell_back_test.dart --plain-name "nested flow"`
Expected:
- `a nested flow at the tab's root: back pops …` FAILS: `Expected: exactly one matching candidate`, `Actual: … "Home page: 0": []` (the shell popped);
- `… the edge swipe pops …` FAILS: `Expected: false`, `Actual: <true>` (`shellPopped`);
- `a nested flow on a pushed page …` FAILS: `Actual: … "Flow page: 0": []` (the tab's page popped with the flow);
- `a toast in the tab overlay …` FAILS as the first;
- `a dialog over a page with a nested flow …` PASSES today; it guards the change.

- [ ] **Step 4: the walk goes on into navigators**

In `branch_navigators.dart`:

1. Replace `_shows` and its doc with:

```dart
/// Whether [parent] shows its child [child]:
/// - an `IndexedStack` shows only the child at its index, and its render
///   object is what says so: from Flutter 3.47 it no longer wraps the
///   others in a `Visibility` widget;
/// - a scrolling list (`PageView`, `ListView`) shows a child laid out in
///   its visible window, not one kept alive or in the cache extent;
/// - a navigator's overlay shows a page under another route (a dialog, a
///   sheet, a page) without letting it pop first: a child with a route's
///   barrier after it is not shown. Other entries (a toast) do not count.
bool _shows(Element parent, Element child) {
  if (parent is! RenderObjectElement) return true;
  final render = parent.renderObject;
  if (render is RenderIndexedStack) {
    return _position(parent, child) == render.index;
  }
  if (render is RenderSliverMultiBoxAdaptor) return _inWindow(render, child);
  if (_isOverlayTheater(parent)) return !_routeAfter(parent, child);
  return true;
}
```

2. After `_inWindow`, add:

```dart
/// Whether [element] is an `Overlay`'s list of entries (its only child).
bool _isOverlayTheater(Element element) {
  var theater = false;
  element.visitAncestorElements((parent) {
    theater = parent is StatefulElement && parent.state is OverlayState;
    return false;
  });
  return theater;
}

/// Whether an entry after [child] in [theater] is a route's barrier.
bool _routeAfter(Element theater, Element child) {
  var after = false;
  var barrier = false;
  theater.visitChildren((entry) {
    if (barrier) return;
    if (after && _hasBarrier(entry, _barrierDepth)) barrier = true;
    if (identical(entry, child)) after = true;
  });
  return barrier;
}

/// How deep a route's barrier sits under its overlay entry, with room to
/// spare (6 on Flutter 3.44).
const _barrierDepth = 12;

bool _hasBarrier(Element element, int depth) {
  if (element.widget is ModalBarrier ||
      element.widget is AnimatedModalBarrier) {
    return true;
  }
  if (depth == 0) return false;
  var found = false;
  element.visitChildren((child) {
    if (!found) found = _hasBarrier(child, depth - 1);
  });
  return found;
}
```

3. Replace `onScreenNavigatorsUnder` and its doc with:

```dart
/// The navigators on screen under [root], in tree order: the selected
/// tab's own navigator, as an app or a router keeps one per tab in the
/// shell's body, then the navigators nested in its top page. A nested one
/// comes after the navigator it is in, so "the last that can pop" pops it
/// first, as iOS does.
///
/// A branch hidden by [_hides] or [_shows] is skipped.
///
/// It walks elements, so call it outside a build (after the frame).
List<BranchNavigator> onScreenNavigatorsUnder(BuildContext root) {
  final found = <BranchNavigator>[];
  void visit(Element element, {required bool handled}) {
    final widget = element.widget;
    if (_hides(widget)) return;
    final handledHere = handled || _answersBack(widget);
    if (element case StatefulElement(state: final NavigatorState navigator)) {
      found.add((navigator: navigator, handled: handledHere));
    }
    element.visitChildren((child) {
      if (_shows(element, child)) visit(child, handled: handledHere);
    });
  }
```

- [ ] **Step 5: see them green, and the whole package**

Run: `flutter test test/widget/pushed_shell_back_test.dart` then `flutter test`
Expected: `All tests passed!` both (the prototype: 69 in the back test file).

- [ ] **Step 6: the mutations**

Each on `branch_navigators.dart`, run, record, revert, `git status` clean in `lib/`:

| | Mutation | `--plain-name` | Prototype |
|---|---|---|---|
| D | after `found.add((navigator: navigator, handled: handledHere));` add `return;` (stop at the first navigator) | `nested flow` | red (8) |
| E | delete the line `if (_isOverlayTheater(parent)) return !_routeAfter(parent, child);` | `a dialog over a page` | red (2) |
| F | `if (after && _hasBarrier(entry, _barrierDepth)) barrier = true;` → `if (after) barrier = true;` | `a toast in the tab overlay` | red (2) |

- [ ] **Step 7: docs**

In `doc/router_integration.md`, under "Known limits:", delete the bullet that starts `- **A navigator inside a tab's page**`, and add to the list above it (after the `Several navigators on screen` bullet):

```markdown
- **A navigator inside a tab's page** (a flow nested in a page, or a
  go_router `ShellRoute` inside a branch) pops first, as on iOS: back and
  the edge swipe pop its page, then the tab's. It counts only while its
  page is the top route of its navigator: a dialog or sheet above it
  closes first. An overlay entry the app inserts (a toast) is not a route.
```

In `README.md`, under `## Known issues`, delete the bullet that starts `- **A navigator inside a tab's page is not looked at for back.**` (four more lines, up to `at its root.`).

Append under `## 0.1.0-dev.8` in `CHANGELOG.md`:

```markdown
- Back and the iOS edge swipe pop a navigator nested in a tab's page
  first (a nested flow, a go_router `ShellRoute` in a branch), then the
  tab's page; before, they popped the tab's page or the whole shell
  (VK-593).
```

- [ ] **Step 8: commit**

```bash
dart format lib test && cd .. && .githooks/pre-commit && git add liquid_shell/lib/src/shell/branch_navigators.dart liquid_shell/test/widget/pushed_shell_back_test.dart liquid_shell/doc/router_integration.md liquid_shell/README.md liquid_shell/CHANGELOG.md && git commit -m "fix(shell): back pops a navigator nested in a tab's page first (VK-593)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 9: the branch**

From the repo root: `make verify`. Expected: every step green but `goldens`, red only at the 8 band images of the Global Constraints. Paste the tail into the task report.
