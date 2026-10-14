import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

import '../helpers/fake_native_platform.dart';
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

  /// A tab's navigator, its root a LiquidPage; [wrap] decorates it (an
  /// app's `NavigatorPopHandler`).
  Widget branch(int index, {Widget Function(int, Widget)? wrap}) {
    final label = _destinations[index].label;
    final navigator = Navigator(
      key: tabs[index],
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => LiquidPage(
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
    bool pushed = true,
  }) async {
    if (mode == _Mode.native) fake = installFakeNative(state: _compact);
    search = LiquidSearchController();
    addTearDown(search.dispose);
    final shellWidget = TestShell(
      key: shell,
      destinations: _destinations,
      initialIndex: initialIndex,
      offstageBranches: offstageBranches,
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

      // An app that already wraps its branch in a NavigatorPopHandler, as
      // doc/router_integration.md advises: one back, one page.
      testWidgets('a NavigatorPopHandler around the branch: one back pops '
          'one page', (tester) async {
        final app = _Pushed(mode);
        await app.pump(
          tester,
          wrap: (i, navigator) => NavigatorPopHandler(
            onPopWithResult: (_) => app.tabs[i].currentState?.maybePop(),
            child: navigator,
          ),
        );
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
  }
}
