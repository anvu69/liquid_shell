import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_shell/liquid_shell.dart';

/// liquid_shell under go_router: three branches in a
/// `StatefulShellRoute.indexedStack`, a full-frame page inside a branch,
/// and a page above the shell.
class GoRouterApp extends StatefulWidget {
  /// Creates the app.
  const GoRouterApp({super.key});

  @override
  State<GoRouterApp> createState() => _GoRouterAppState();
}

class _GoRouterAppState extends State<GoRouterApp> {
  final _rootKey = GlobalKey<NavigatorState>();
  final _search = LiquidSearchController();
  late final GoRouter _router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home',
    routes: [_shell(), _above()],
  );

  static const _destinations = [
    LiquidDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
      sfSymbol: 'house',
    ),
    LiquidDestination(
      icon: Icon(Icons.map_outlined),
      selectedIcon: Icon(Icons.map),
      label: 'Explore',
      sfSymbol: 'map',
    ),
    LiquidDestination(
      icon: Icon(Icons.search),
      label: 'Search',
      role: LiquidDestinationRole.search,
    ),
  ];

  // #docregion shell
  RouteBase _shell() => StatefulShellRoute.indexedStack(
    builder: (context, state, shell) => LiquidShell(
      destinations: _destinations,
      selectedIndex: shell.currentIndex,
      // Reselecting a tab goes back to its first page.
      onDestinationSelected: (i) =>
          shell.goBranch(i, initialLocation: i == shell.currentIndex),
      search: LiquidSearch(controller: _search),
      // The indexed stack keeps every branch alive and hides the others
      // with Offstage and TickerMode, which the shell reads as off screen.
      body: shell,
    ),
    branches: _branches(),
  );
  // #enddocregion shell

  // #docregion branches
  List<StatefulShellBranch> _branches() => [
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const _HomePage(),
          routes: [
            // Inside the branch, under the shell: LiquidHideChrome hides
            // the chrome while the page is on screen.
            GoRoute(
              path: 'detail',
              builder: (context, state) => const LiquidHideChrome(
                child: _Page(title: 'Detail page'),
              ),
            ),
          ],
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/explore',
          builder: (context, state) => const _Page(title: 'Explore page'),
        ),
      ],
    ),
    StatefulShellBranch(
      routes: [
        GoRoute(
          path: '/search',
          builder: (context, state) => const _Page(title: 'Search page'),
        ),
      ],
    ),
  ];
  // #enddocregion branches

  // #docregion above
  // Above the shell, on the root navigator: the page covers the chrome,
  // and LiquidNoChrome makes its insets ignore it.
  RouteBase _above() => GoRoute(
    path: '/compose',
    parentNavigatorKey: _rootKey,
    builder: (context, state) =>
        const LiquidNoChrome(child: _Page(title: 'Compose page')),
  );
  // #enddocregion above

  @override
  void dispose() {
    _router.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      MaterialApp.router(routerConfig: _router);
}

/// Home: a counter (branch state) and the two ways to open a page.
class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  int _count = 0;

  @override
  Widget build(BuildContext context) => _Page(
    title: 'Home page',
    children: [
      ListTile(
        title: Text('Count: $_count'),
        onTap: () => setState(() => _count++),
      ),
      ListTile(
        title: const Text('Open the detail page'),
        onTap: () => context.go('/home/detail'),
      ),
      ListTile(
        title: const Text('Compose'),
        onTap: () => context.push('/compose'),
      ),
    ],
  );
}

/// A page padded clear of the chrome.
class _Page extends StatelessWidget {
  const _Page({required this.title, this.children = const []});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      padding: LiquidShellScope.contentPaddingOf(context),
      children: [
        ListTile(title: Text(title)),
        ...children,
      ],
    ),
  );
}
