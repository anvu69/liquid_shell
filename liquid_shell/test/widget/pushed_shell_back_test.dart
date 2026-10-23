import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

import '../helpers/fake_native_platform.dart';
import '../helpers/kept_alive.dart';
import '../helpers/shell_harness.dart';

// VK-567: a shell that is itself a pushed route (the example's cases sit
// above the case list), the search inactive. As on iOS, the left-edge
// swipe and system back pop the innermost page of the selected tab; only
// a tab at its root lets them pop the shell's own route. Flutter hands
// the swipe to the outer route first (its back gesture detector is hit
// before the branch route's), so without the shell's say the swipe on a
// page pushed in any tab popped the whole shell, in both modes.

const _destinations = [
  LiquidDestination(icon: Icon(Icons.home), label: 'Home', sfSymbol: 'house'),
  LiquidDestination(
    icon: Icon(Icons.book),
    label: 'Library',
    sfSymbol: 'books.vertical',
  ),
  LiquidDestination(
    icon: Icon(Icons.search),
    label: 'Search',
    role: LiquidDestinationRole.search,
  ),
];

/// iPhone portrait with UIKit's compact bar in the bottom safe area.
const _compactPadding = EdgeInsets.only(top: 62, bottom: 83);
const _compact = LiquidNativeShellState(installed: true, compact: true);

/// The chrome a test runs under: UIKit's (fake platform) or Flutter's.
enum _Mode { native, flutter }

/// The shell above a list, one navigator per tab, as the example's search
/// case: [tabs] holds the tab navigators, [outer] the shell's own.
class _Pushed {
  _Pushed(this.mode);

  final _Mode mode;
  final outer = GlobalKey<NavigatorState>();
  final shell = GlobalKey<TestShellState>();
  final List<GlobalKey<NavigatorState>> tabs = [
    for (var i = 0; i < 3; i++) GlobalKey<NavigatorState>(),
  ];
  FakeNativePlatform? fake;
  late final LiquidSearchController search;

  /// The root page of a tab, when a test gives its own (a nested flow);
  /// null keeps the default.
  Widget? Function(int index)? root;

  /// A tab's navigator, its root a LiquidPage; [wrap] decorates it (an
  /// app's `NavigatorPopHandler`).
  Widget branch(int index, {Widget Function(int, Widget)? wrap}) {
    final label = _destinations[index].label;
    final navigator = Navigator(
      key: tabs[index],
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) =>
            root?.call(index) ??
            LiquidPage(
              title: label,
              child: TestPage(label: label),
            ),
      ),
    );
    return wrap?.call(index, navigator) ?? navigator;
  }

  Future<void> pump(
    WidgetTester tester, {
    int initialIndex = 0,
    bool offstageBranches = false,
    Widget Function(int, Widget)? wrap,
    Widget Function(Widget shell)? around,
    Widget Function(int index, List<Widget> pages)? body,
    Widget? Function(int index)? root,
    bool pushed = true,
  }) async {
    this.root = root;
    if (mode == _Mode.native) fake = installFakeNative(state: _compact);
    search = LiquidSearchController();
    addTearDown(search.dispose);
    final shellWidget = TestShell(
      key: shell,
      destinations: _destinations,
      initialIndex: initialIndex,
      offstageBranches: offstageBranches,
      bodyBuilder: body,
      pageBuilder: (i) => branch(i, wrap: wrap),
      search: LiquidSearch(controller: search),
    );
    final inRoute = around?.call(shellWidget) ?? shellWidget;
    await pumpShell(
      tester,
      pushed
          ? Navigator(
              key: outer,
              onGenerateInitialRoutes: (_, _) => [
                MaterialPageRoute<void>(builder: (_) => const Text('The list')),
                MaterialPageRoute<void>(builder: (_) => inRoute),
              ],
            )
          : inRoute,
      padding: mode == _Mode.native
          ? _compactPadding
          : const EdgeInsets.only(top: 59, bottom: 34),
    );
    final label = _destinations[initialIndex].label;
    expect(
      scopeOf(tester, label).nativeChrome,
      mode == _Mode.native,
      reason: 'the chrome under test',
    );
    if (mode == _Mode.native) expect(fake!.last.tabs, isNotEmpty);
  }

  /// Pushes a page titled [title] in tab [index]: a LiquidPage, or a plain
  /// page when [liquidPage] is false.
  Future<void> push(
    WidgetTester tester,
    int index,
    String title, {
    bool liquidPage = true,
  }) async {
    tabs[index].currentState!
        .push(
          MaterialPageRoute<void>(
            builder: (_) => liquidPage
                ? LiquidPage(
                    title: title,
                    child: TestPage(label: title),
                  )
                : Scaffold(body: Center(child: Text('$title page: 0'))),
          ),
        )
        .ignore();
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, int index) async {
    shell.currentState!.select(index);
    await tester.pumpAndSettle();
  }

  bool get shellPopped => find.text('The list').evaluate().isNotEmpty;
}

Future<void> _swipeFromTheEdge(WidgetTester tester) async {
  await tester.dragFrom(const Offset(2, 400), const Offset(300, 0));
  await tester.pumpAndSettle();
}

Finder _page(String label) => find.text('$label page: 0');

/// The route of the page of [label]: a `Scaffold` drawer or a persistent
/// bottom sheet adds its local-history entry there.
ModalRoute<Object?> _routeOf(WidgetTester tester, String label) =>
    ModalRoute.of(tester.element(find.byKey(ValueKey('list-$label'))))!;

/// A `NavigatorPopHandler` around a tab's navigator, as the README's
/// "Hide the chrome" case had it before VK-567.
Widget Function(int, Widget) _popHandlers(_Pushed app) =>
    (i, navigator) => NavigatorPopHandler(
      onPopWithResult: (_) => app.tabs[i].currentState?.maybePop(),
      child: navigator,
    );

/// An indexed stack with no widget around its children, as `IndexedStack`
/// is built from Flutter 3.47 on: only its render object (and a private
/// scope) hides the others. Before, it wrapped each child in `Visibility`.
class _BareIndexedStack extends Stack {
  const _BareIndexedStack({required this.index, super.children})
    : super(fit: StackFit.expand);

  final int index;

  @override
  RenderIndexedStack createRenderObject(BuildContext context) =>
      RenderIndexedStack(
        index: index,
        fit: fit,
        textDirection: Directionality.maybeOf(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderIndexedStack renderObject,
  ) {
    super.updateRenderObject(context, renderObject);
    renderObject.index = index;
  }
}

/// Branches kept as a router keeps them, but the one left goes offstage
/// 300 ms after the selection (the end of a cross-fade), not in the same
/// frame.
class _LateHide extends StatefulWidget {
  const _LateHide({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_LateHide> createState() => _LateHideState();
}

class _LateHideState extends State<_LateHide> {
  int? _leaving;
  Timer? _timer;

  @override
  void didUpdateWidget(_LateHide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    _leaving = oldWidget.index;
    _timer?.cancel();
    _timer = Timer(
      const Duration(milliseconds: 300),
      () => setState(() => _leaving = null),
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
        Offstage(
          offstage: i != widget.index && i != _leaving,
          child: TickerMode(
            enabled: i == widget.index || i == _leaving,
            child: child,
          ),
        ),
    ],
  );
}

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
        if (widget.cached) child else KeptAlive(child: child),
    ],
  );
}

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

/// [_flow] inside the standard `NavigatorPopHandler`, in the tab's page: its
/// PopScope is on the tab page's route, which system back never calls.
Widget _handledFlow(GlobalKey<NavigatorState> inner, String label) =>
    NavigatorPopHandler(
      onPopWithResult: (_) => inner.currentState?.maybePop(),
      child: _flow(inner, label),
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

void main() {
  setUp(debugResetLiquidNative);

  for (final mode in _Mode.values) {
    group('VK-567 (${mode.name}): a pushed shell, the search inactive', () {
      testWidgets('the edge swipe on a page pushed in a tab pops that page, '
          'not the shell', (tester) async {
        final app = _Pushed(mode);
        await app.pump(tester);
        await app.push(tester, 0, 'Detail');
        await _swipeFromTheEdge(tester);
        expect(app.shellPopped, isFalse, reason: 'the shell stays');
        expect(_page('Detail'), findsNothing, reason: 'the page popped');
        expect(_page('Home'), findsOneWidget, reason: "the tab's root");
      });

      testWidgets('at the tab root the swipe pops the shell', (tester) async {
        final app = _Pushed(mode);
        await app.pump(tester);
        await _swipeFromTheEdge(tester);
        expect(app.shellPopped, isTrue);
      });

      testWidgets('two pages deep: one swipe per page, then the shell', (
        tester,
      ) async {
        final app = _Pushed(mode);
        await app.pump(tester);
        await app.push(tester, 0, 'One');
        await app.push(tester, 0, 'Two');
        await _swipeFromTheEdge(tester);
        expect(app.shellPopped, isFalse);
        expect(_page('One'), findsOneWidget);
        await _swipeFromTheEdge(tester);
        expect(app.shellPopped, isFalse);
        expect(_page('Home'), findsOneWidget);
        await _swipeFromTheEdge(tester);
        expect(app.shellPopped, isTrue);
      });

      testWidgets('a pushed page that is not a LiquidPage pops alone too', (
        tester,
      ) async {
        final app = _Pushed(mode);
        await app.pump(tester);
        await app.push(tester, 0, 'Plain', liquidPage: false);
        await _swipeFromTheEdge(tester);
        expect(app.shellPopped, isFalse);
        expect(_page('Plain'), findsNothing);
        expect(_page('Home'), findsOneWidget);
      });

      testWidgets('a page pushed in the search tab, the search inactive', (
        tester,
      ) async {
        final app = _Pushed(mode);
        await app.pump(tester, initialIndex: 2);
        await app.push(tester, 2, 'Result');
        if (mode == _Mode.native) {
          expect(app.fake!.last.tabs.last.pages.map((p) => p.title), [
            'Search',
            'Result',
          ]);
        }
        await _swipeFromTheEdge(tester);
        expect(app.shellPopped, isFalse);
        expect(_page('Result'), findsNothing);
        expect(app.search.isActive, isFalse);
        if (mode == _Mode.native) {
          expect(
            app.fake!.last.tabs.last.pages.map((p) => p.title),
            ['Search'],
            reason: 'the native bar followed',
          );
        }
      });

      // Only the selected tab counts; the tab left keeps its page (VK-491,
      // VK-502), and its swipe pops it once selected again.
      testWidgets('a page kept in another tab: the selected root pops the '
          'shell, the kept page stays its own tab', (tester) async {
        final app = _Pushed(mode);
        await app.pump(tester);
        await app.push(tester, 1, 'Kept');
        await app.select(tester, 1);
        expect(_page('Kept'), findsOneWidget);
        await app.select(tester, 0);
        expect(_page('Home'), findsOneWidget);
        expect(_page('Kept').hitTestable(), findsNothing);
        await app.select(tester, 1);
        expect(_page('Kept').hitTestable(), findsOneWidget, reason: 'kept');
        await _swipeFromTheEdge(tester);
        expect(app.shellPopped, isFalse);
        expect(_page('Kept'), findsNothing);
        await app.push(tester, 1, 'Kept');
        await app.select(tester, 0);
        await _swipeFromTheEdge(tester);
        expect(app.shellPopped, isTrue, reason: 'Home is at its root');
      });

      testWidgets('router-style branches (Offstage + TickerMode)', (
        tester,
      ) async {
        final app = _Pushed(mode);
        await app.pump(tester, offstageBranches: true);
        await app.push(tester, 1, 'Kept');
        await app.push(tester, 0, 'Detail');
        await _swipeFromTheEdge(tester);
        expect(app.shellPopped, isFalse);
        expect(_page('Home'), findsOneWidget);
        await _swipeFromTheEdge(tester);
        expect(app.shellPopped, isTrue, reason: "Library's page is offstage");
      });

      testWidgets('system back pops the inner page first, then the shell', (
        tester,
      ) async {
        final app = _Pushed(mode);
        await app.pump(tester);
        await app.push(tester, 0, 'Detail');
        await app.outer.currentState!.maybePop();
        await tester.pumpAndSettle();
        expect(app.shellPopped, isFalse);
        expect(_page('Detail'), findsNothing);
        expect(_page('Home'), findsOneWidget);
        await app.outer.currentState!.maybePop();
        await tester.pumpAndSettle();
        expect(app.shellPopped, isTrue);
      });

      // An app that kept the NavigatorPopHandler the README used to show
      // around its branch: one back, one page.
      testWidgets('a NavigatorPopHandler around the branch: one back pops '
          'one page', (tester) async {
        final app = _Pushed(mode);
        await app.pump(tester, wrap: _popHandlers(app));
        await app.push(tester, 0, 'One');
        await app.push(tester, 0, 'Two');
        await app.outer.currentState!.maybePop();
        await tester.pumpAndSettle();
        expect(_page('Two'), findsNothing);
        expect(_page('One'), findsOneWidget, reason: 'not two pages');
        await _swipeFromTheEdge(tester);
        expect(app.shellPopped, isFalse);
        expect(_page('Home'), findsOneWidget);
      });

      // An app's own PopScope on the shell's route (an exit confirmation)
      // keeps its say: at the tab's root it decides, as before. While the
      // tab can pop, back pops that page, and the app's handler hears
      // `didPop: false` too (doc/router_integration.md).
      testWidgets("an app's PopScope on the shell's route", (tester) async {
        final invoked = <bool>[];
        final app = _Pushed(mode);
        await app.pump(
          tester,
          around: (shell) => PopScope<Object?>(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) => invoked.add(didPop),
            child: shell,
          ),
        );
        await app.push(tester, 0, 'Detail');
        await app.outer.currentState!.maybePop();
        await tester.pumpAndSettle();
        expect(_page('Detail'), findsNothing);
        expect(invoked, [false]);
        await app.outer.currentState!.maybePop();
        await tester.pumpAndSettle();
        await _swipeFromTheEdge(tester);
        expect(app.shellPopped, isFalse, reason: 'the app refused');
        expect(_page('Home'), findsOneWidget);
        expect(invoked, [false, false]);
      });

      // The same rule without an outer page: system back (Android) pops
      // the tab's page instead of leaving the app.
      testWidgets("a shell at the app's root: system back pops the tab's "
          'page first', (tester) async {
        final app = _Pushed(mode);
        await app.pump(tester, pushed: false);
        await app.push(tester, 0, 'Detail');
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(_page('Detail'), findsNothing);
        expect(_page('Home'), findsOneWidget);
      });

      // VK-567 review I1(a): a drawer, a persistent bottom sheet or any
      // local-history entry changes `canPop()` with no navigation event.
      testWidgets('a drawer opened at the tab root: back closes it first', (
        tester,
      ) async {
        final app = _Pushed(mode);
        await app.pump(tester);
        var removed = 0;
        _routeOf(
          tester,
          'Home',
        ).addLocalHistoryEntry(LocalHistoryEntry(onRemove: () => removed++));
        await tester.pumpAndSettle();
        await app.outer.currentState!.maybePop();
        await tester.pumpAndSettle();
        expect(removed, 1);
        expect(app.shellPopped, isFalse, reason: 'only the drawer');
        await app.outer.currentState!.maybePop();
        await tester.pumpAndSettle();
        expect(app.shellPopped, isTrue);
      });

      testWidgets('a drawer seen by a tab round-trip, then closed by back: '
          'the next back pops the shell', (tester) async {
        final app = _Pushed(mode);
        await app.pump(tester);
        var removed = 0;
        _routeOf(
          tester,
          'Home',
        ).addLocalHistoryEntry(LocalHistoryEntry(onRemove: () => removed++));
        await tester.pumpAndSettle();
        await app.select(tester, 1);
        await app.select(tester, 0);
        await app.outer.currentState!.maybePop();
        await tester.pumpAndSettle();
        expect(removed, 1);
        expect(app.shellPopped, isFalse);
        await app.outer.currentState!.maybePop();
        await tester.pumpAndSettle();
        expect(app.shellPopped, isTrue, reason: 'not stuck at the root');
      });

      testWidgets('a drawer closed by its scrim: the swipe pops the shell', (
        tester,
      ) async {
        final app = _Pushed(mode);
        await app.pump(tester);
        final drawer = LocalHistoryEntry();
        _routeOf(tester, 'Home').addLocalHistoryEntry(drawer);
        await tester.pumpAndSettle();
        await app.select(tester, 1);
        await app.select(tester, 0);
        drawer.remove();
        await tester.pumpAndSettle();
        await _swipeFromTheEdge(tester);
        expect(app.shellPopped, isTrue, reason: 'not stuck at the root');
      });

      // VK-567 review I1(b).
      testWidgets('a tab hidden a few frames late: back pops the shell, never '
          "the hidden tab's page", (tester) async {
        final app = _Pushed(mode);
        await app.pump(
          tester,
          body: (index, pages) => _LateHide(index: index, children: pages),
        );
        await app.push(tester, 0, 'Detail');
        await app.select(tester, 1);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        final home = app.tabs[0].currentState!;
        await app.outer.currentState!.maybePop();
        // One frame: a pop it asked for has landed, the shell still mounted.
        await tester.pump();
        expect(home.canPop(), isTrue, reason: "Home's page is kept");
        await tester.pumpAndSettle();
        expect(app.shellPopped, isTrue, reason: 'Library is at its root');
      });

      // VK-567 review I2: one back, one step, whether or not the app kept
      // the NavigatorPopHandler the README used to show.
      for (final handler in [false, true]) {
        testWidgets('a drawer on a pushed page'
            '${handler ? ', a NavigatorPopHandler around the branch' : ''}: '
            'one back closes only the drawer', (tester) async {
          final app = _Pushed(mode);
          await app.pump(tester, wrap: handler ? _popHandlers(app) : null);
          await app.push(tester, 0, 'Two');
          var removed = 0;
          _routeOf(tester, 'Two').addLocalHistoryEntry(
            LocalHistoryEntry(onRemove: () => removed++),
          );
          await tester.pumpAndSettle();
          await app.outer.currentState!.maybePop();
          await tester.pumpAndSettle();
          expect(removed, 1);
          expect(_page('Two'), findsOneWidget, reason: 'the page stays');
          await app.outer.currentState!.maybePop();
          await tester.pumpAndSettle();
          expect(_page('Two'), findsNothing);
          expect(_page('Home'), findsOneWidget);
          expect(app.shellPopped, isFalse);
        });
      }

      // PR #13 on Flutter 3.47: IndexedStack no longer wraps its children
      // in `Visibility`; its render object alone hides them.
      testWidgets('a page kept in a tab an indexed stack hides: the swipe at '
          'the selected root pops the shell', (tester) async {
        final app = _Pushed(mode);
        await app.pump(
          tester,
          body: (index, pages) =>
              _BareIndexedStack(index: index, children: pages),
        );
        await app.push(tester, 1, 'Kept');
        await _swipeFromTheEdge(tester);
        expect(app.shellPopped, isTrue, reason: 'Home is at its root');
      });

      testWidgets('a page kept in a tab an indexed stack hides: back pops '
          'the shell, never that page', (tester) async {
        final app = _Pushed(mode);
        await app.pump(
          tester,
          body: (index, pages) =>
              _BareIndexedStack(index: index, children: pages),
        );
        await app.push(tester, 1, 'Kept');
        final library = app.tabs[1].currentState!;
        await app.outer.currentState!.maybePop();
        // One frame: a pop it asked for has landed, the shell still mounted.
        await tester.pump();
        expect(library.canPop(), isTrue, reason: "Library's page is kept");
        await tester.pumpAndSettle();
        expect(app.shellPopped, isTrue, reason: 'Home is at its root');
      });

      // VK-567 review M5: TickerMode alone hides a branch.
      testWidgets('a branch hidden by TickerMode alone does not hold back', (
        tester,
      ) async {
        final app = _Pushed(mode);
        await app.pump(
          tester,
          body: (index, pages) => Stack(
            fit: StackFit.expand,
            children: [
              for (final (i, page) in pages.indexed)
                TickerMode(enabled: i == index, child: page),
            ],
          ),
        );
        await app.push(tester, 1, 'Kept');
        await app.outer.currentState!.maybePop();
        await tester.pumpAndSettle();
        expect(app.shellPopped, isTrue);
      });

      // A refusing page keeps its route: the shell does not go instead.
      testWidgets("a page's PopScope refusal holds the swipe and back", (
        tester,
      ) async {
        final app = _Pushed(mode);
        await app.pump(tester);
        app.tabs[0].currentState!
            .push(
              MaterialPageRoute<void>(
                builder: (_) => const PopScope(
                  canPop: false,
                  child: LiquidPage(
                    title: 'Form',
                    child: TestPage(label: 'Form'),
                  ),
                ),
              ),
            )
            .ignore();
        await tester.pumpAndSettle();
        await _swipeFromTheEdge(tester);
        expect(app.shellPopped, isFalse);
        expect(_page('Form'), findsOneWidget);
        await app.outer.currentState!.maybePop();
        await tester.pumpAndSettle();
        expect(app.shellPopped, isFalse);
        expect(_page('Form'), findsOneWidget);
      });
    });

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

      testWidgets('a NavigatorPopHandler inside a pushed page: back pops the '
          'inner page', (tester) async {
        final inner = GlobalKey<NavigatorState>();
        final app = _Pushed(mode);
        await app.pump(tester);
        app.tabs[0].currentState!
            .push(
              MaterialPageRoute<void>(
                builder: (_) => _handledFlow(inner, 'Flow'),
              ),
            )
            .ignore();
        await tester.pumpAndSettle();
        await _pushOn(tester, inner, 'Inner');
        await back(app, tester);
        expect(_page('Inner'), findsNothing);
        expect(_page('Flow'), findsOneWidget);
        expect(app.shellPopped, isFalse);
      });

      testWidgets("a NavigatorPopHandler in the tab's root page: back pops "
          'the inner page, the shell stays', (tester) async {
        final inner = GlobalKey<NavigatorState>();
        final app = _Pushed(mode);
        await app.pump(
          tester,
          root: (i) => i == 0 ? _handledFlow(inner, 'Home') : null,
        );
        await _pushOn(tester, inner, 'Inner');
        await back(app, tester);
        expect(_page('Inner'), findsNothing);
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
    });
  }

  // VK-567 review M5: Android asks the framework before its predictive
  // back. A root shell claims back while the tab can pop, and gives it
  // back at the tab's root, so the app can be left.
  testWidgets('Android, a root shell: the framework claims back only while '
      'the tab can pop', (tester) async {
    final claims = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
          claims.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final app = _Pushed(_Mode.flutter);
      await app.pump(tester, pushed: false);
      await app.push(tester, 0, 'Detail');
      expect(claims.last, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_page('Detail'), findsNothing);
      expect(_page('Home'), findsOneWidget);
      expect(claims.last, isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
