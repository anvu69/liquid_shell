import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

import '../helpers/fake_native_platform.dart';
import '../helpers/shell_harness.dart';

/// [kDestinations] with SF Symbols, so native chrome can describe them.
const kNative = [
  LiquidDestination(
    icon: Icon(Icons.home_outlined),
    label: 'Home',
    sfSymbol: 'house',
  ),
  LiquidDestination(
    icon: Icon(Icons.inbox_outlined),
    label: 'Inbox',
    badge: LiquidBadge.count(3),
    sfSymbol: 'tray',
  ),
  LiquidDestination(
    icon: Icon(Icons.bar_chart),
    label: 'Reports',
    placement: LiquidPlacement.sidebarOnly,
    sfSymbol: 'chart.bar',
  ),
  LiquidDestination(
    icon: Icon(Icons.settings_outlined),
    label: 'Settings',
    badge: LiquidBadge.dot(),
    sfSymbol: 'gear',
  ),
];

/// iPad landscape with the native tab bar's 72pt row copied into the top
/// safe area (24 status bar + 72).
const _nativePadding = EdgeInsets.only(top: 96, bottom: 20);

Future<void> _pumpNative(
  WidgetTester tester, {
  Widget? shell,
  Size size = kTabletLandscape,
  EdgeInsets padding = _nativePadding,
  bool settle = true,
}) => pumpShell(
  tester,
  shell ?? const TestShell(destinations: kNative),
  size: size,
  padding: padding,
  settle: settle,
);

bool _flutterChrome() =>
    find.byType(LiquidTabBar).evaluate().isNotEmpty ||
    find.byType(LiquidSidebar).evaluate().isNotEmpty;

LiquidShellScopeData _scope(WidgetTester tester) => LiquidShellScope.of(
  tester.element(find.byType(TestPage, skipOffstage: false).first),
);

void main() {
  group('engagement (spec P2 §5.1)', () {
    testWidgets('installed, regular, describable: native chrome only', (
      tester,
    ) async {
      final native = installFakeNative();
      await _pumpNative(tester);

      expect(_flutterChrome(), isFalse);
      // No Flutter overlay barrier: UIKit dims under its own sidebar.
      expect(
        find.byWidgetPredicate(
          (w) => w is ModalBarrier && w.semanticsLabel == 'Hide sidebar',
        ),
        findsNothing,
      );
      final scope = _scope(tester);
      expect(scope.nativeChrome, isTrue);
      expect(scope.chromeKind, LiquidChromeKind.topBar);
      expect(scope.chromeInsets, const EdgeInsets.only(top: 96));
      expect(native.last.engaged, isTrue);
      expect(native.last.visible, isTrue);
      expect(native.last.tabs, const [
        LiquidNativeTab(title: 'Home', sfSymbol: 'house'),
        LiquidNativeTab(title: 'Inbox', sfSymbol: 'tray', badge: '3'),
        LiquidNativeTab(
          title: 'Reports',
          sfSymbol: 'chart.bar',
          sidebarOnly: true,
        ),
        LiquidNativeTab(title: 'Settings', sfSymbol: 'gear', badge: ''),
      ]);
      expect(native.last.selectedIndex, 0);
      expect(native.last.interactive, isTrue);
    });

    testWidgets('compact width draws the Flutter bottom bar', (tester) async {
      final native = installFakeNative();
      await _pumpNative(tester, size: kPhone);
      expect(find.byType(LiquidTabBar), findsOneWidget);
      expect(_scope(tester).nativeChrome, isFalse);
      expect(native.last.engaged, isFalse);
    });

    testWidgets('a compact platform size class draws Flutter chrome', (
      tester,
    ) async {
      final native = installFakeNative(
        state: const LiquidNativeShellState(installed: true, compact: true),
      );
      await _pumpNative(tester);
      expect(_flutterChrome(), isTrue);
      expect(native.last.engaged, isFalse);
    });

    testWidgets('a destination without sfSymbol keeps Flutter chrome', (
      tester,
    ) async {
      final native = installFakeNative();
      await _pumpNative(tester, shell: const TestShell());
      expect(_flutterChrome(), isTrue);
      expect(native.last.engaged, isFalse);
    });

    testWidgets('a trailing action without sfSymbol keeps Flutter chrome', (
      tester,
    ) async {
      installFakeNative();
      await _pumpNative(
        tester,
        shell: TestShell(
          destinations: kNative,
          trailing: LiquidTabAction(
            icon: const Icon(Icons.search),
            onPressed: () {},
            semanticLabel: 'Search',
          ),
        ),
      );
      expect(_flutterChrome(), isTrue);
    });

    testWidgets('a chromeBuilder keeps Flutter chrome', (tester) async {
      installFakeNative();
      await _pumpNative(
        tester,
        shell: TestShell(
          destinations: kNative,
          chromeBuilder: (context, details, chrome) => chrome,
        ),
      );
      expect(_flutterChrome(), isTrue);
    });

    testWidgets('nativeChrome off never claims and sends nothing', (
      tester,
    ) async {
      final native = installFakeNative();
      await _pumpNative(
        tester,
        shell: const TestShell(
          destinations: kNative,
          nativeChrome: LiquidNativeChrome.off,
        ),
      );
      expect(_flutterChrome(), isTrue);
      expect(native.configs, isEmpty);
    });

    testWidgets('not installed: Flutter chrome and no config sent', (
      tester,
    ) async {
      final native = installFakeNative(
        state: const LiquidNativeShellState(
          installed: false,
          unavailableReason: LiquidNativeUnavailableReason.notEnabled,
        ),
      );
      await _pumpNative(tester);
      expect(_flutterChrome(), isTrue);
      expect(native.configs, isEmpty);
    });

    testWidgets('pending: no chrome at all until the platform answers', (
      tester,
    ) async {
      final native = installFakeNative()
        ..attachGate = Completer<LiquidNativeShellState>();
      await _pumpNative(tester, settle: false);
      await tester.pump();
      expect(_flutterChrome(), isFalse);
      expect(_scope(tester).chromeKind, LiquidChromeKind.hidden);

      native.attachGate!.complete(kInstalled);
      await tester.pumpAndSettle();
      expect(_scope(tester).nativeChrome, isTrue);
      expect(native.last.engaged, isTrue);
    });

    testWidgets('the state flipping to compact falls back, and back again', (
      tester,
    ) async {
      final native = installFakeNative();
      await _pumpNative(tester);
      final counter = find.byKey(const ValueKey('counter-Home'));
      await tester.tap(counter);
      await tester.pump();

      native.pushState(
        const LiquidNativeShellState(installed: true, compact: true),
      );
      await tester.pumpAndSettle();
      expect(_flutterChrome(), isTrue);
      expect(native.last.engaged, isFalse);

      native.pushState(kInstalled);
      await tester.pumpAndSettle();
      expect(_flutterChrome(), isFalse);
      // §5.6: the body never moved, so its State survived both switches.
      expect(find.text('Home page: 1'), findsOneWidget);
    });
  });

  group('layout', () {
    testWidgets('tiled: the body loses the sidebar width and its padding', (
      tester,
    ) async {
      installFakeNative(
        state: const LiquidNativeShellState(
          installed: true,
          sidebar: LiquidNativeSidebar.tiled,
        ),
      );
      await _pumpNative(
        tester,
        padding: const EdgeInsets.only(left: 300, top: 24, bottom: 20),
      );
      // P1's own tiled sidebar is 300 wide too: check that it is native.
      expect(_flutterChrome(), isFalse);
      final scope = _scope(tester);
      expect(scope.nativeChrome, isTrue);
      expect(scope.chromeKind, LiquidChromeKind.sidebarTiled);
      expect(scope.sidebarVisible, isTrue);
      expect(scope.chromeInsets, EdgeInsets.zero);
      final page = tester.element(find.byType(TestPage).first);
      expect(MediaQuery.sizeOf(page).width, kTabletLandscape.width - 300);
      expect(MediaQuery.paddingOf(page).left, 0);
      expect(tester.getTopLeft(find.byType(TestPage).first).dx, 300);
    });

    testWidgets('overlay: system back closes the native sidebar', (
      tester,
    ) async {
      final native = installFakeNative(
        state: const LiquidNativeShellState(
          installed: true,
          sidebar: LiquidNativeSidebar.overlay,
        ),
      );
      await _pumpNative(tester, size: kTabletPortrait);
      expect(_scope(tester).chromeKind, LiquidChromeKind.sidebarOverlay);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(native.sidebarCalls, [false]);
    });

    testWidgets('setSidebarVisible from a page reaches the platform', (
      tester,
    ) async {
      final native = installFakeNative();
      await _pumpNative(tester);
      _scope(tester).setSidebarVisible(true);
      await tester.pump();
      expect(native.sidebarCalls, [true]);
    });

    testWidgets('LiquidHideChrome hides the native chrome', (tester) async {
      final native = installFakeNative();
      await _pumpNative(
        tester,
        shell: TestShell(
          destinations: kNative,
          pageBuilder: (i) =>
              const LiquidHideChrome(child: TestPage(label: 'x')),
        ),
      );
      expect(native.last.hidden, isTrue);
      expect(native.last.visible, isFalse);
      expect(_scope(tester).chromeKind, LiquidChromeKind.hidden);
    });
  });

  group('selection (spec P2 §7.3)', () {
    testWidgets('a native tap runs the guard, selects, closes the overlay', (
      tester,
    ) async {
      final native = installFakeNative(
        state: const LiquidNativeShellState(
          installed: true,
          sidebar: LiquidNativeSidebar.overlay,
        ),
      );
      final guarded = <int>[];
      final selections = <int>[];
      await _pumpNative(
        tester,
        size: kTabletPortrait,
        shell: TestShell(
          destinations: kNative,
          selections: selections,
          guard: (i) async {
            guarded.add(i);
            return true;
          },
        ),
      );
      native.emitNative(const LiquidNativeDestinationTapped(1));
      await tester.pumpAndSettle();
      expect(guarded, [1]);
      expect(selections, [1]);
      expect(native.last.selectedIndex, 1);
      expect(native.sidebarCalls, [false]);
    });

    testWidgets('a refused tap re-sends the current selection', (tester) async {
      final native = installFakeNative();
      final selections = <int>[];
      await _pumpNative(
        tester,
        shell: TestShell(
          destinations: kNative,
          selections: selections,
          guard: (i) async => false,
        ),
      );
      final before = native.configs.length;
      native.emitNative(const LiquidNativeDestinationTapped(2));
      await tester.pumpAndSettle();
      expect(selections, isEmpty);
      expect(native.configs.length, before + 1);
      expect(native.last.selectedIndex, 0);
    });

    testWidgets('reselect runs the same path', (tester) async {
      final native = installFakeNative();
      final selections = <int>[];
      await _pumpNative(
        tester,
        shell: TestShell(destinations: kNative, selections: selections),
      );
      native.emitNative(const LiquidNativeDestinationTapped(0));
      await tester.pumpAndSettle();
      expect(selections, [0]);
    });

    testWidgets('an out-of-range index from the platform is ignored', (
      tester,
    ) async {
      final native = installFakeNative();
      final selections = <int>[];
      await _pumpNative(
        tester,
        shell: TestShell(destinations: kNative, selections: selections),
      );
      native
        ..emitNative(const LiquidNativeDestinationTapped(9))
        ..emitNative(const LiquidNativeDestinationTapped(-1));
      await tester.pumpAndSettle();
      expect(selections, isEmpty);
    });

    testWidgets('trailing and footer taps call the app', (tester) async {
      final native = installFakeNative();
      final calls = <String>[];
      await _pumpNative(
        tester,
        shell: TestShell(
          destinations: kNative,
          trailing: LiquidTabAction(
            icon: const Icon(Icons.search),
            onPressed: () => calls.add('trailing'),
            semanticLabel: 'Search',
            sfSymbol: 'magnifyingglass',
          ),
          nativeSidebarFooter: LiquidNativeSidebarFooter(
            title: 'Ann',
            subtitle: 'Active profile',
            sfSymbol: 'person.crop.circle',
            semanticLabel: 'Ann, active profile',
            onPressed: () => calls.add('footer'),
          ),
        ),
      );
      expect(
        native.last.trailing,
        const LiquidNativeAction(title: 'Search', sfSymbol: 'magnifyingglass'),
      );
      expect(native.last.footer?.title, 'Ann');
      native
        ..emitNative(const LiquidNativeTrailingTapped())
        ..emitNative(const LiquidNativeFooterTapped());
      await tester.pumpAndSettle();
      expect(calls, ['trailing', 'footer']);
    });
  });

  group('routes above the shell (spec P2 §7.4)', () {
    testWidgets('a page pushed above hides the chrome until it pops', (
      tester,
    ) async {
      final native = installFakeNative();
      await _pumpNative(tester);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator
          .push(
            MaterialPageRoute<void>(
              builder: (_) => const LiquidNoChrome(child: Text('above')),
            ),
          )
          .ignore();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(native.last.hidden, isTrue);
      await tester.pumpAndSettle();
      expect(native.last.hidden, isTrue);

      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(native.last.hidden, isFalse);
      await tester.pumpAndSettle();
      expect(native.last.visible, isTrue);
    });

    testWidgets('a dialog above makes the chrome non-interactive', (
      tester,
    ) async {
      final native = installFakeNative();
      await _pumpNative(tester);
      unawaited(
        showDialog<void>(
          context: tester.element(find.byType(TestPage).first),
          builder: (_) => const Text('dialog'),
        ),
      );
      await tester.pumpAndSettle();
      expect(native.last.interactive, isFalse);
      expect(native.last.hidden, isFalse);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(native.last.interactive, isTrue);
    });

    testWidgets('a second shell owns the chrome; the first gets it back', (
      tester,
    ) async {
      final native = installFakeNative();
      await _pumpNative(tester);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator
          .push(
            MaterialPageRoute<void>(
              builder: (_) => const TestShell(
                destinations: [
                  LiquidDestination(
                    icon: Icon(Icons.star),
                    label: 'Starred',
                    sfSymbol: 'star',
                  ),
                ],
              ),
            ),
          )
          .ignore();
      await tester.pumpAndSettle();
      expect(native.last.tabs.single.title, 'Starred');

      navigator.pop();
      await tester.pumpAndSettle();
      expect(native.last.tabs.first.title, 'Home');
      expect(native.last.visible, isTrue);
    });

    testWidgets('the last shell leaving sends the dormant config', (
      tester,
    ) async {
      final native = installFakeNative();
      await _pumpNative(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(native.last, LiquidNativeChromeConfig.dormant);
    });
  });
}
