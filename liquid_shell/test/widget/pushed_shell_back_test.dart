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
    Widget? Function(int index)? bare,
    bool pushed = true,
    Size size = kPhone,
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
      // [bare]: a tab's page with no navigator between (VK-776).
      pageBuilder: (i) => bare?.call(i) ?? branch(i, wrap: wrap),
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
      size: size,
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

/// A shell with its own tabs (sub-tabs), Flutter chrome. Tab `j`'s page is
/// `bare(j)` when that is not null (no navigator between), otherwise a
/// navigator keyed `tabs[j]` whose root is the test page of [label] and the
/// tab's label ('Inner Home'). [sidebarHeader] and [breakpoints] are the
/// shell's.
Widget _subTabs(
  String label, {
  required List<GlobalKey<NavigatorState>> tabs,
  required LiquidSearchController search,
  Key? key,
  int initialIndex = 0,
  Widget? Function(int index)? bare,
  Widget? sidebarHeader,
  LiquidShellBreakpoints breakpoints = const LiquidShellBreakpoints(),
}) => TestShell(
  key: key,
  nativeChrome: LiquidNativeChrome.off,
  destinations: _destinations,
  initialIndex: initialIndex,
  sidebarHeader: sidebarHeader,
  breakpoints: breakpoints,
  search: LiquidSearch(controller: search),
  pageBuilder: (j) =>
      bare?.call(j) ??
      Navigator(
        key: tabs[j],
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => LiquidPage(
            title: '$label ${_destinations[j].label}',
            child: TestPage(label: '$label ${_destinations[j].label}'),
          ),
        ),
      ),
);

/// [_subTabs]' `bare` for tabs with no navigators: tab `j`'s page is the
/// test page of [label] and the tab's label.
Widget? Function(int index) _plainTabs(String label) =>
    (j) => TestPage(label: '$label ${_destinations[j].label}');

/// A shell with its own tabs (sub-tabs) as the root page of tab 1 of a
/// [_Pushed] app, on its search tab, Flutter chrome; [tabs] holds its tab
/// navigators.
class _Inner {
  final List<GlobalKey<NavigatorState>> tabs = [
    for (var i = 0; i < 3; i++) GlobalKey<NavigatorState>(),
  ];
  final search = LiquidSearchController();

  /// Pumps [app] with this shell in tab 1, then selects it; [wrap] as
  /// [_Pushed.pump]'s.
  Future<void> pump(
    _Pushed app,
    WidgetTester tester, {
    Size size = kPhone,
    Widget Function(int, Widget)? wrap,
  }) async {
    addTearDown(search.dispose);
    await app.pump(
      tester,
      size: size,
      wrap: wrap,
      root: (i) => i != 1
          ? null
          : _subTabs('Inner', tabs: tabs, search: search, initialIndex: 2),
    );
    await app.select(tester, 1);
  }
}

/// VK-776: a shell with its own tabs as the page of tab 1 of a [_Pushed]
/// app, with no navigator between, so its `PopScope` sits on the outer
/// shell's route. Flutter chrome; [tabs] holds its tab navigators.
class _SameRoute {
  final shell = GlobalKey<TestShellState>();
  final List<GlobalKey<NavigatorState>> tabs = [
    for (var i = 0; i < 3; i++) GlobalKey<NavigatorState>(),
  ];
  final search = LiquidSearchController();
  final _loaded = Completer<void>();

  /// Pumps [app] with this shell as tab 1's page, then selects tab 1;
  /// [bare], [sidebarHeader] and [breakpoints] as [_subTabs]'. With
  /// [loading], a `FutureBuilder` stands in for the shell until [load].
  Future<void> pump(
    _Pushed app,
    WidgetTester tester, {
    Size size = kPhone,
    bool pushed = true,
    int initialIndex = 0,
    Widget? Function(int index)? bare,
    Widget? sidebarHeader,
    LiquidShellBreakpoints breakpoints = const LiquidShellBreakpoints(),
    bool loading = false,
  }) async {
    addTearDown(search.dispose);
    Widget inner() => _subTabs(
      'Inner',
      key: shell,
      tabs: tabs,
      search: search,
      initialIndex: initialIndex,
      bare: bare,
      sidebarHeader: sidebarHeader,
      breakpoints: breakpoints,
    );
    await app.pump(
      tester,
      size: size,
      pushed: pushed,
      bare: (i) => i != 1
          ? null
          : !loading
          ? inner()
          : FutureBuilder<void>(
              future: _loaded.future,
              builder: (_, snapshot) =>
                  snapshot.connectionState == ConnectionState.done
                  ? inner()
                  : const SizedBox.expand(),
            ),
    );
    await app.select(tester, 1);
  }

  /// Ends the load of a shell pumped `loading`: it is built after the
  /// outer shell last walked its body, with no navigator event to tell.
  Future<void> load(WidgetTester tester) async {
    expect(find.byKey(shell), findsNothing, reason: 'loading');
    _loaded.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(shell), findsOneWidget, reason: 'loaded');
  }
}

/// Pushes a page titled [title] on [navigator] that refuses to pop, as an
/// unsaved form does: each refusal asks "Discard?" in a dialog. Returns how
/// many times it asked so far.
Future<int Function()> _pushForm(
  WidgetTester tester,
  GlobalKey<NavigatorState> navigator,
  String title,
) async {
  var asks = 0;
  navigator.currentState!
      .push(
        MaterialPageRoute<void>(
          builder: (context) => PopScope<Object?>(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              asks++;
              showDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(title: Text('Discard?')),
              ).ignore();
            },
            child: Scaffold(body: Center(child: Text('$title page: 0'))),
          ),
        ),
      )
      .ignore();
  await tester.pumpAndSettle();
  return () => asks;
}

/// What the framework tells Android about back: each
/// `setFrameworkHandlesBack` argument, and how often it let the app leave
/// (`SystemNavigator.pop`).
class _AndroidBack {
  final claims = <Object?>[];
  int exits = 0;
}

/// Runs [body] as on an Android device, recording [_AndroidBack].
Future<void> _onAndroid(
  WidgetTester tester,
  Future<void> Function(_AndroidBack android) body,
) async {
  final android = _AndroidBack();
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
        android.claims.add(call.arguments);
      } else if (call.method == 'SystemNavigator.pop') {
        android.exits++;
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
    await body(android);
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
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

      // VK-776: a shell that is a tab's page with no navigator between puts
      // its PopScope on the outer shell's route, which calls every PopScope
      // on it. The inner shell steps aside; the outer one hands it back in
      // its own order, and only while it is on screen.
      testWidgets('VK-776: a shell nested with no navigator between: an '
          'unsaved form in its tab asks once per back', (tester) async {
        final app = _Pushed(mode);
        final inner = _SameRoute();
        await inner.pump(app, tester);
        final asks = await _pushForm(tester, inner.tabs[0], 'Form');
        await back(app, tester);
        expect(asks(), 1, reason: 'one back, one ask');
        expect(find.text('Discard?'), findsOneWidget, reason: 'one dialog');
        expect(_page('Form'), findsOneWidget);
        expect(app.shellPopped, isFalse);
      });

      testWidgets('VK-776: three shells on one route: the form asks once', (
        tester,
      ) async {
        final app = _Pushed(mode);
        final middle = _SameRoute();
        final leafTabs = [
          for (var i = 0; i < 3; i++) GlobalKey<NavigatorState>(),
        ];
        final leafSearch = LiquidSearchController();
        addTearDown(leafSearch.dispose);
        await middle.pump(
          app,
          tester,
          initialIndex: 1,
          bare: (j) => j != 1
              ? null
              : _subTabs('Leaf', tabs: leafTabs, search: leafSearch),
        );
        final asks = await _pushForm(tester, leafTabs[0], 'Form');
        await back(app, tester);
        expect(asks(), 1, reason: 'one ask, not one per shell');
        expect(find.text('Discard?'), findsOneWidget);
      });

      testWidgets('VK-776: a nested shell in a hidden tab, a page in its '
          "tab: back pops the shell's route", (tester) async {
        final app = _Pushed(mode);
        final inner = _SameRoute();
        await inner.pump(app, tester);
        await _pushOn(tester, inner.tabs[0], 'Hidden');
        await app.select(tester, 0);
        await back(app, tester);
        expect(app.shellPopped, isTrue, reason: 'Home is at its root');
      });

      testWidgets('VK-776: the outer search active, a nested shell hidden '
          'with a page: back ends the outer search only', (tester) async {
        final app = _Pushed(mode);
        final inner = _SameRoute();
        await inner.pump(app, tester);
        await _pushOn(tester, inner.tabs[0], 'Hidden');
        await app.select(tester, 2);
        app.search.activate();
        // Natively, the search is active once UIKit says so.
        app.fake?.emitNative(const LiquidNativeSearchActiveChanged(true));
        await tester.pumpAndSettle();
        expect(app.search.isActive, isTrue, reason: 'precondition');
        await back(app, tester);
        if (app.fake case final fake?) {
          // The shell asks UIKit to end it; the fake never answers.
          expect(fake.searchActives.last, isFalse);
        } else {
          expect(app.search.isActive, isFalse);
        }
        expect(
          find.text('Hidden page: 0', skipOffstage: false),
          findsOneWidget,
          reason: 'the hidden page stays',
        );
        expect(app.shellPopped, isFalse);
      });

      if (mode == _Mode.flutter) {
        testWidgets('VK-776: iPad, the outer overlay sidebar open over a '
            'nested shell with a page: back closes the sidebar only', (
          tester,
        ) async {
          final app = _Pushed(mode);
          final inner = _SameRoute();
          await inner.pump(app, tester, size: kTabletPortrait);
          await _pushOn(tester, inner.tabs[0], 'Deep');
          // The outer shell's scope, as seen by the inner shell.
          LiquidShellScopeData outer() =>
              LiquidShellScope.of(tester.element(find.byKey(inner.shell)));
          outer().setSidebarVisible(true);
          await tester.pumpAndSettle();
          expect(
            outer().chromeKind,
            LiquidChromeKind.sidebarOverlay,
            reason: 'precondition',
          );
          await back(app, tester);
          expect(outer().sidebarVisible, isFalse);
          expect(_page('Deep'), findsOneWidget, reason: 'the sidebar only');
          await back(app, tester);
          expect(_page('Deep'), findsNothing, reason: 'the page next');
          expect(app.shellPopped, isFalse);
        });
      }

      testWidgets("VK-776: the edge swipe on a nested shell's page pops "
          'that page, not the shell', (tester) async {
        final app = _Pushed(mode);
        final inner = _SameRoute();
        await inner.pump(app, tester);
        await _pushOn(tester, inner.tabs[0], 'Swiped');
        await _swipeFromTheEdge(tester);
        expect(_page('Swiped'), findsNothing);
        expect(app.shellPopped, isFalse);
      });

      testWidgets("VK-776: a nested shell's search active over a page: back "
          'ends the search, then pops the page', (tester) async {
        final app = _Pushed(mode);
        final inner = _SameRoute();
        await inner.pump(app, tester, initialIndex: 2);
        await _pushOn(tester, inner.tabs[2], 'Deep');
        inner.search.activate();
        await tester.pumpAndSettle();
        expect(inner.search.isActive, isTrue, reason: 'precondition');
        await back(app, tester);
        expect(inner.search.isActive, isFalse, reason: 'the search first');
        expect(_page('Deep'), findsOneWidget);
        await back(app, tester);
        expect(_page('Deep'), findsNothing, reason: 'the page next');
        expect(app.shellPopped, isFalse);
      });

      // The route check: with a navigator between, the inner shell keeps
      // its own PopScope (on the tab's root route), where the app's
      // NavigatorPopHandler finds it.
      testWidgets('VK-776: a nested shell at the root of a tab navigator '
          "inside the app's NavigatorPopHandler: back ends its search", (
        tester,
      ) async {
        final app = _Pushed(mode);
        final inner = _Inner();
        await inner.pump(app, tester, wrap: _popHandlers(app));
        inner.search.activate();
        await tester.pumpAndSettle();
        expect(inner.search.isActive, isTrue, reason: 'precondition');
        await back(app, tester);
        expect(inner.search.isActive, isFalse);
        expect(app.shellPopped, isFalse);
      });

      // At its tab root, with no page, a nested shell's search and overlay
      // sidebar hold back only through the outer shell's per-frame check.
      testWidgets("VK-776: a nested shell's search active at its tab root: "
          'back ends the search, then pops the shell', (tester) async {
        final app = _Pushed(mode);
        final inner = _SameRoute();
        await inner.pump(app, tester, initialIndex: 2);
        inner.search.activate();
        await tester.pumpAndSettle();
        expect(inner.search.isActive, isTrue, reason: 'precondition');
        await back(app, tester);
        expect(inner.search.isActive, isFalse, reason: 'the search only');
        expect(app.shellPopped, isFalse);
        await back(app, tester);
        expect(app.shellPopped, isTrue, reason: 'nothing left inside');
      });

      testWidgets("VK-776: iPad, a nested shell's overlay sidebar open at its "
          'tab root: back closes the sidebar, then pops the shell', (
        tester,
      ) async {
        final app = _Pushed(mode);
        final inner = _SameRoute();
        await inner.pump(app, tester, size: kTabletPortrait);
        // The outer shell's bar covers the inner one's button: the inner
        // shell's scope opens its sidebar, as the button does.
        LiquidShellScopeData scope() =>
            LiquidShellScope.of(tester.element(_page('Inner Home')));
        scope().setSidebarVisible(true);
        await tester.pumpAndSettle();
        expect(
          scope().chromeKind,
          LiquidChromeKind.sidebarOverlay,
          reason: 'precondition',
        );
        await back(app, tester);
        expect(scope().sidebarVisible, isFalse, reason: 'the sidebar only');
        expect(app.shellPopped, isFalse);
        await back(app, tester);
        expect(app.shellPopped, isTrue, reason: 'nothing left inside');
      });

      // A nested shell built after the outer shell last walked its body (a
      // loader's result, its tabs with no navigators) sends the outer shell
      // nothing: the nested shell tells it.
      testWidgets('VK-776: a nested shell built after a loader, its search '
          'active: back ends the search', (tester) async {
        final app = _Pushed(mode);
        final inner = _SameRoute();
        await inner.pump(
          app,
          tester,
          initialIndex: 2,
          bare: _plainTabs('Inner'),
          loading: true,
        );
        await inner.load(tester);
        inner.search.activate();
        await tester.pumpAndSettle();
        expect(inner.search.isActive, isTrue, reason: 'precondition');
        await back(app, tester);
        expect(app.shellPopped, isFalse, reason: 'the search first');
        expect(inner.search.isActive, isFalse);
      });

      // A shell in a nested shell's sidebar header is on the same route but
      // in no body the outer shells walk: it keeps its own PopScope.
      testWidgets("VK-776: iPad, a shell in a nested shell's sidebar header, "
          'its search active: back ends that search', (tester) async {
        final app = _Pushed(mode);
        final inner = _SameRoute();
        final header = GlobalKey<TestShellState>();
        final headerSearch = LiquidSearchController();
        addTearDown(headerSearch.dispose);
        await inner.pump(
          app,
          tester,
          size: kTabletLandscape,
          // Tiled at the outer shell's body width, so the header shows.
          breakpoints: const LiquidShellBreakpoints(
            regular: 400,
            tiledSidebar: 400,
          ),
          sidebarHeader: SizedBox(
            height: 300,
            child: _subTabs(
              'Header',
              key: header,
              tabs: const [],
              search: headerSearch,
              initialIndex: 2,
              bare: _plainTabs('Header'),
            ),
          ),
        );
        expect(find.byKey(header), findsOneWidget, reason: 'precondition');
        headerSearch.activate();
        await tester.pumpAndSettle();
        expect(headerSearch.isActive, isTrue, reason: 'precondition');
        await back(app, tester);
        expect(app.shellPopped, isFalse, reason: "the header shell's search");
        expect(headerSearch.isActive, isFalse);
      });
    });
  }

  // VK-567 review M5: Android asks the framework before its predictive
  // back. A root shell claims back while the tab can pop, and gives it
  // back at the tab's root, so the app can be left.
  testWidgets('Android, a root shell: the framework claims back only while '
      'the tab can pop', (tester) async {
    await _onAndroid(tester, (android) async {
      final app = _Pushed(_Mode.flutter);
      await app.pump(tester, pushed: false);
      await app.push(tester, 0, 'Detail');
      expect(android.claims.last, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_page('Detail'), findsNothing);
      expect(_page('Home'), findsOneWidget);
      expect(android.claims.last, isFalse);
    });
  });

  // VK-776: a shell nested with no navigator between, in a root shell.
  testWidgets('Android, a root shell, a nested shell in a hidden tab with a '
      'page: at the root of the tab shown, back leaves the app', (
    tester,
  ) async {
    await _onAndroid(tester, (android) async {
      final app = _Pushed(_Mode.flutter);
      final inner = _SameRoute();
      await inner.pump(app, tester, pushed: false);
      await _pushOn(tester, inner.tabs[0], 'Hidden');
      expect(android.claims.last, isTrue, reason: 'shown, it can pop');
      await app.select(tester, 0);
      expect(android.claims.last, isFalse, reason: 'Home is at its root');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(android.exits, 1, reason: 'the app leaves');
      expect(
        find.text('Hidden page: 0', skipOffstage: false),
        findsOneWidget,
        reason: 'the hidden page stays',
      );
    });
  });

  testWidgets('Android, a root shell, a nested shell shown with an unsaved '
      'form: one back asks once', (tester) async {
    await _onAndroid(tester, (android) async {
      final app = _Pushed(_Mode.flutter);
      final inner = _SameRoute();
      await inner.pump(app, tester, pushed: false);
      final asks = await _pushForm(tester, inner.tabs[0], 'Form');
      expect(android.claims.last, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(asks(), 1, reason: 'one back, one ask');
      expect(find.text('Discard?'), findsOneWidget);
      expect(android.exits, 0);
    });
  });

  testWidgets('Android, a root shell, a nested shell built after a loader, '
      'its search active: back ends the search, the app stays', (
    tester,
  ) async {
    await _onAndroid(tester, (android) async {
      final app = _Pushed(_Mode.flutter);
      final inner = _SameRoute();
      await inner.pump(
        app,
        tester,
        pushed: false,
        initialIndex: 2,
        bare: _plainTabs('Inner'),
        loading: true,
      );
      await inner.load(tester);
      inner.search.activate();
      await tester.pumpAndSettle();
      final claimed = android.claims.last;
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(android.exits, 0, reason: 'the app stays');
      expect(inner.search.isActive, isFalse);
      expect(claimed, isTrue, reason: 'the search held back');
    });
  });
}
