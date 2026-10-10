import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/native/native_host.dart';
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

/// iPhone portrait with UIKit's compact tab bar copied into the bottom
/// safe area (34 home indicator + 49).
const _compactPadding = EdgeInsets.only(top: 62, bottom: 83);

/// UIKit's compact size class: the floating tab bar at the bottom.
const _compact = LiquidNativeShellState(installed: true, compact: true);

/// What native does to Flutter's bottom safe area: [bottom] is 83 with the
/// compact bar shown, 34 (the home indicator) with it hidden.
void _setBottomPadding(WidgetTester tester, double bottom) {
  final padding = FakeViewPadding(top: _compactPadding.top, bottom: bottom);
  tester.view
    ..padding = padding
    ..viewPadding = padding;
}

Future<void> _pumpNative(
  WidgetTester tester, {
  Widget? shell,
  Size size = kTabletLandscape,
  Size? screen,
  EdgeInsets padding = _nativePadding,
  bool settle = true,
}) => pumpShell(
  tester,
  shell ?? const TestShell(destinations: kNative),
  size: size,
  screen: screen,
  padding: padding,
  settle: settle,
);

bool _flutterChrome() =>
    find.byType(LiquidTabBar).evaluate().isNotEmpty ||
    find.byType(LiquidSidebar).evaluate().isNotEmpty;

/// Runs [body] with `debugPrint` captured and the once-only logs re-armed.
/// Restores `debugPrint` before the test ends: testWidgets checks it.
Future<List<String>> _logsOf(Future<void> Function() body) async {
  NativeChromeHost.debugResetLogs();
  final logs = <String>[];
  final original = debugPrint;
  debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
  try {
    await body();
  } finally {
    debugPrint = original;
  }
  return logs;
}

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

    // Owner D1: the native bar on every iOS 26 iPhone and iPad, compact
    // windows included. UIKit's compact bar is in the bottom safe area.
    testWidgets('compact: the native bottom bar, compact scope', (
      tester,
    ) async {
      final native = installFakeNative(state: _compact);
      await _pumpNative(tester, size: kPhone, padding: _compactPadding);
      expect(_flutterChrome(), isFalse);
      final scope = _scope(tester);
      expect(scope.nativeChrome, isTrue);
      expect(scope.sizeClass, LiquidSizeClass.compact);
      expect(scope.chromeKind, LiquidChromeKind.bottomBar);
      expect(scope.chromeInsets, const EdgeInsets.only(bottom: 83));
      expect(scope.sidebarVisible, isFalse);
      expect(native.last.engaged, isTrue);
      expect(native.last.visible, isTrue);
    });

    // P1 parity: the compact bar has no sidebar, so a sidebar-only
    // selection is hidden there and the app hears about it.
    testWidgets('compact: a sidebar-only selection is reported hidden', (
      tester,
    ) async {
      final native = installFakeNative(state: _compact);
      final hidden = <int>[];
      await _pumpNative(
        tester,
        shell: TestShell(
          destinations: kNative,
          initialIndex: 2,
          onHidden: hidden.add,
        ),
        size: kPhone,
        padding: _compactPadding,
      );
      // The native path, not a Flutter compact bar.
      expect(_scope(tester).nativeChrome, isTrue);
      expect(native.last.engaged, isTrue);
      expect(hidden, [2]);
    });

    // Split View or Stage Manager narrows a regular iPad window: the
    // presentation stays wide, only UIKit's size class turns compact.
    testWidgets('narrowed to compact: a sidebar-only selection is reported '
        'hidden, once per entry', (tester) async {
      final native = installFakeNative();
      final hidden = <int>[];
      await _pumpNative(
        tester,
        shell: TestShell(
          destinations: kNative,
          initialIndex: 2,
          onHidden: hidden.add,
        ),
      );
      expect(hidden, isEmpty);

      native.pushState(_compact);
      await tester.pumpAndSettle();
      expect(_scope(tester).nativeChrome, isTrue);
      expect(_scope(tester).chromeKind, LiquidChromeKind.bottomBar);
      expect(hidden, [2]);

      native.pushState(kInstalled);
      await tester.pumpAndSettle();
      native.pushState(_compact);
      await tester.pumpAndSettle();
      expect(hidden, [2, 2]);
    });

    // UIKit decides the bar, not the shell's own width.
    testWidgets('a compact platform at a regular shell width: bottom bar', (
      tester,
    ) async {
      installFakeNative(state: _compact);
      await _pumpNative(tester);
      expect(_scope(tester).chromeKind, LiquidChromeKind.bottomBar);
      expect(_scope(tester).sizeClass, LiquidSizeClass.compact);
    });

    testWidgets('a regular platform at a phone shell width: top bar', (
      tester,
    ) async {
      installFakeNative();
      await _pumpNative(tester, size: kPhone);
      expect(_scope(tester).chromeKind, LiquidChromeKind.topBar);
      expect(_scope(tester).sizeClass, LiquidSizeClass.regular);
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

    testWidgets('auto → off releases the chrome: dormant, Flutter chrome', (
      tester,
    ) async {
      final native = installFakeNative();
      await _pumpNative(tester);
      expect(native.last.engaged, isTrue);
      await _pumpNative(
        tester,
        shell: const TestShell(
          destinations: kNative,
          nativeChrome: LiquidNativeChrome.off,
        ),
      );
      expect(native.last, LiquidNativeChromeConfig.dormant);
      expect(_flutterChrome(), isTrue);
      expect(_scope(tester).nativeChrome, isFalse);
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

    // D1: an iPhone may install native chrome too, so it waits like an
    // iPad, at its own size class.
    testWidgets('pending at phone width waits too, compact', (tester) async {
      installFakeNative().attachGate = Completer<LiquidNativeShellState>();
      await _pumpNative(tester, size: kPhone, settle: false);
      expect(_flutterChrome(), isFalse);
      final scope = _scope(tester);
      expect(scope.sizeClass, LiquidSizeClass.compact);
      expect(scope.chromeKind, LiquidChromeKind.hidden);
    });

    testWidgets('pending on an iPhone in landscape waits too', (tester) async {
      installFakeNative().attachGate = Completer<LiquidNativeShellState>();
      await _pumpNative(tester, size: kPhoneLandscape, settle: false);
      expect(_flutterChrome(), isFalse);
    });

    testWidgets('pending in an iPad window narrower than its screen still '
        'waits', (tester) async {
      installFakeNative().attachGate = Completer<LiquidNativeShellState>();
      await _pumpNative(
        tester,
        size: const Size(744, 834),
        screen: kTabletLandscape,
        settle: false,
      );
      expect(_flutterChrome(), isFalse);
    });

    testWidgets('pending on an iPad app that has not opted in (no '
        'sfSymbols): Flutter chrome on the first frame', (tester) async {
      installFakeNative().attachGate = Completer<LiquidNativeShellState>();
      await _pumpNative(tester, shell: const TestShell(), settle: false);
      expect(_flutterChrome(), isTrue);
      expect(_scope(tester).chromeKind, isNot(LiquidChromeKind.hidden));
    });

    testWidgets('pending with a chromeBuilder: Flutter chrome at once', (
      tester,
    ) async {
      installFakeNative().attachGate = Completer<LiquidNativeShellState>();
      await _pumpNative(
        tester,
        shell: TestShell(
          destinations: kNative,
          chromeBuilder: (context, details, chrome) => chrome,
        ),
        settle: false,
      );
      expect(_flutterChrome(), isTrue);
    });

    testWidgets('a window resized across the size class swaps the native '
        'bar; the body keeps its state', (tester) async {
      final native = installFakeNative();
      await _pumpNative(tester);
      final counter = find.byKey(const ValueKey('counter-Home'));
      await tester.tap(counter);
      await tester.pump();

      native.pushState(_compact);
      await tester.pumpAndSettle();
      expect(_flutterChrome(), isFalse);
      expect(_scope(tester).chromeKind, LiquidChromeKind.bottomBar);
      expect(native.last.engaged, isTrue);

      native.pushState(kInstalled);
      await tester.pumpAndSettle();
      expect(_flutterChrome(), isFalse);
      expect(_scope(tester).chromeKind, LiquidChromeKind.topBar);
      // §5.6: the body never moved, so its State survived both switches.
      expect(find.text('Home page: 1'), findsOneWidget);
    });
  });

  group('debug logs (spec P2 §7.1): once per process', () {
    testWidgets('not enabled: logged once, across hosts', (tester) async {
      const notEnabled = LiquidNativeShellState(
        installed: false,
        unavailableReason: LiquidNativeUnavailableReason.notEnabled,
      );
      final logs = await _logsOf(() async {
        installFakeNative(state: notEnabled);
        await _pumpNative(tester);
        // A new host (a hot restart, the next test) asks again.
        await tester.pumpWidget(const SizedBox());
        debugResetLiquidNative();
        await _pumpNative(tester);
      });
      expect(logs.where((l) => l.contains('not enabled')), hasLength(1));
    });
  });

  group('missing-symbol hint (spec P2 §15, E2): one line per shell', () {
    final plainSearch = LiquidTabAction(
      icon: const Icon(Icons.search),
      onPressed: () {},
      semanticLabel: 'Search',
    );
    Iterable<String> hints(List<String> logs) =>
        logs.where((l) => l.contains('sfSymbol'));

    testWidgets('installed: one line naming every destination and the '
        'trailing action without a symbol', (tester) async {
      final logs = await _logsOf(() async {
        installFakeNative();
        await _pumpNative(tester, shell: TestShell(trailing: plainSearch));
      });
      expect(hints(logs), hasLength(1));
      final hint = hints(logs).single;
      for (final label in ['Home', 'Inbox', 'Reports', 'Settings']) {
        expect(hint, contains('"$label"'));
      }
      expect(hint, contains('tabBarTrailing "Search"'));
    });

    testWidgets('pending: logged before the platform answers', (tester) async {
      final logs = await _logsOf(() async {
        installFakeNative().attachGate = Completer<LiquidNativeShellState>();
        await _pumpNative(tester, shell: const TestShell(), settle: false);
      });
      expect(hints(logs), hasLength(1));
    });

    testWidgets('a rebuild does not log it again', (tester) async {
      final logs = await _logsOf(() async {
        final native = installFakeNative();
        await _pumpNative(tester, shell: const TestShell());
        await tester.tap(find.text('Inbox').first);
        await tester.pumpAndSettle();
        native.pushState(_compact);
        await tester.pumpAndSettle();
        // A new widget for the same shell.
        await _pumpNative(
          tester,
          shell: const TestShell(minimizeOnScroll: false),
        );
      });
      expect(hints(logs), hasLength(1));
    });

    testWidgets('two shells: one line each', (tester) async {
      final logs = await _logsOf(() async {
        installFakeNative();
        await _pumpNative(tester, shell: const TestShell());
        // A second shell without symbols, pushed above the first.
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .push(
              MaterialPageRoute<void>(builder: (_) => const TestShell()),
            )
            .ignore();
        await tester.pumpAndSettle();
      });
      expect(hints(logs), hasLength(2));
    });

    testWidgets('quiet where native chrome is impossible anyway, and for a '
        'describable shell', (tester) async {
      final logs = await _logsOf(() async {
        // The default platform: no native chrome.
        await _pumpNative(tester, shell: const TestShell());
        await tester.pumpWidget(const SizedBox());
        debugResetLiquidNative();
        installFakeNative();
        await _pumpNative(
          tester,
          shell: const TestShell(nativeChrome: LiquidNativeChrome.off),
        );
        await _pumpNative(
          tester,
          shell: TestShell(
            chromeBuilder: (context, details, chrome) => chrome,
          ),
        );
        await _pumpNative(tester);
      });
      expect(hints(logs), isEmpty);
    });
  });

  group('scene reconnect (spec P2 §5.7)', () {
    testWidgets('a state report re-sends the whole config, selection too', (
      tester,
    ) async {
      final native = installFakeNative();
      await _pumpNative(tester);
      native.emitNative(const LiquidNativeDestinationTapped(1));
      await tester.pumpAndSettle();
      final shown = native.last;
      expect(shown.selectedIndex, 1);
      final before = native.configs.length;

      // A reconnected scene gets a fresh native controller with no config.
      // Its first layout reports the state, unchanged: the shell's config
      // is unchanged too, and must still reach it.
      native.pushState(kInstalled);
      await tester.pumpAndSettle();
      expect(native.configs.length, before + 1);
      expect(native.last, shown);
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

    testWidgets('RTL tiled: the sidebar is on the right; the body loses it', (
      tester,
    ) async {
      installFakeNative(
        state: const LiquidNativeShellState(
          installed: true,
          sidebar: LiquidNativeSidebar.tiled,
        ),
      );
      await pumpShell(
        tester,
        const TestShell(destinations: kNative),
        size: kTabletLandscape,
        padding: const EdgeInsets.only(right: 300, top: 24, bottom: 20),
        direction: TextDirection.rtl,
      );
      expect(_flutterChrome(), isFalse);
      final page = tester.element(find.byType(TestPage).first);
      expect(MediaQuery.sizeOf(page).width, kTabletLandscape.width - 300);
      expect(MediaQuery.paddingOf(page).right, 0);
      expect(tester.getTopLeft(find.byType(TestPage).first).dx, 0);
      expect(
        tester.getTopRight(find.byType(TestPage).first).dx,
        kTabletLandscape.width - 300,
      );
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

    testWidgets('while the guard runs the chrome is inert, so the native '
        'overlay closes before its dialog shows', (tester) async {
      final native = installFakeNative(
        state: const LiquidNativeShellState(
          installed: true,
          sidebar: LiquidNativeSidebar.overlay,
        ),
      );
      final gate = Completer<bool>();
      final selections = <int>[];
      await _pumpNative(
        tester,
        size: kTabletPortrait,
        shell: TestShell(
          destinations: kNative,
          selections: selections,
          guard: (i) => gate.future,
        ),
      );
      expect(native.last.interactive, isTrue);
      native.emitNative(const LiquidNativeDestinationTapped(1));
      await tester.pump();
      await tester.pump();
      // The guard has shown nothing on a route yet (or shows it elsewhere):
      // the pending guard alone makes the config inert, which closes an
      // overlay sidebar natively.
      expect(native.last.interactive, isFalse);
      expect(native.last.selectedIndex, 0);

      gate.complete(false);
      await tester.pumpAndSettle();
      expect(selections, isEmpty);
      expect(native.last.interactive, isTrue);
      expect(native.last.selectedIndex, 0);
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

    testWidgets('reselect runs the same path and re-sends the selection', (
      tester,
    ) async {
      final native = installFakeNative();
      final selections = <int>[];
      await _pumpNative(
        tester,
        shell: TestShell(destinations: kNative, selections: selections),
      );
      final before = native.configs.length;
      native.emitNative(const LiquidNativeDestinationTapped(0));
      await tester.pumpAndSettle();
      expect(selections, [0]);
      // The config is unchanged, but UIKit's safety net may show another
      // tab: the current one is sent again.
      expect(native.configs.length, before + 1);
      expect(native.last.selectedIndex, 0);
    });

    testWidgets('single flight: a tap during the guard is dropped and the '
        'selection re-sent', (tester) async {
      final native = installFakeNative();
      final gate = Completer<bool>();
      final guarded = <int>[];
      final selections = <int>[];
      await _pumpNative(
        tester,
        shell: TestShell(
          destinations: kNative,
          selections: selections,
          guard: (i) {
            guarded.add(i);
            return gate.future;
          },
        ),
      );
      native.emitNative(const LiquidNativeDestinationTapped(1));
      await tester.pump();
      final before = native.configs.length;
      native.emitNative(const LiquidNativeDestinationTapped(3));
      await tester.pump();
      await tester.pump();
      expect(guarded, [1]);
      expect(native.configs.length, before + 1);
      expect(native.last.selectedIndex, 0);

      gate.complete(true);
      await tester.pumpAndSettle();
      expect(selections, [1]);
      expect(native.last.selectedIndex, 1);
    });

    testWidgets('a guard that throws refuses, and the selection is re-sent', (
      tester,
    ) async {
      final native = installFakeNative();
      final selections = <int>[];
      await _pumpNative(
        tester,
        shell: TestShell(
          destinations: kNative,
          selections: selections,
          guard: (i) async => throw StateError('form check failed'),
        ),
      );
      final before = native.configs.length;
      native.emitNative(const LiquidNativeDestinationTapped(1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isA<StateError>());
      expect(selections, isEmpty);
      expect(native.configs.length, before + 1);
      expect(native.last.selectedIndex, 0);
    });

    testWidgets('a destination gone while the guard ran: dropped, re-sent', (
      tester,
    ) async {
      final native = installFakeNative();
      final gate = Completer<bool>();
      final selections = <int>[];
      Widget shell(List<LiquidDestination> destinations) => TestShell(
        destinations: destinations,
        selections: selections,
        guard: (i) => gate.future,
      );
      await _pumpNative(tester, shell: shell(kNative));
      native.emitNative(const LiquidNativeDestinationTapped(2));
      await tester.pump();
      // 'Reports' disappears while the guard is pending.
      await _pumpNative(
        tester,
        shell: shell([kNative[0], kNative[1], kNative[3]]),
      );
      final before = native.configs.length;
      gate.complete(true);
      await tester.pumpAndSettle();
      expect(selections, isEmpty);
      expect(native.configs.length, before + 1);
      expect(native.last.selectedIndex, 0);
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

    // Routes that never drive the shell route's secondaryAnimation: the
    // Overlay turns the shell's tickers off once the page covers it.
    final noSecondary = <String, Route<void> Function()>{
      'a fullscreenDialog page': () => MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const LiquidNoChrome(child: Text('above')),
      ),
      'a PageRouteBuilder page': () => PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => const LiquidNoChrome(child: Text('above')),
      ),
    };
    for (final MapEntry(key: name, value: route) in noSecondary.entries) {
      testWidgets('$name above hides the chrome until it pops', (
        tester,
      ) async {
        final native = installFakeNative();
        await _pumpNative(tester);
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.push(route()).ignore();
        // Mid-push the chrome still shows (§7.4), but it is already inert:
        // no native tap can change the branch under the page coming in.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(native.last.interactive, isFalse);
        await tester.pumpAndSettle();
        expect(native.last.hidden, isTrue);
        expect(native.last.visible, isFalse);

        navigator.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(native.last.hidden, isFalse);
        await tester.pumpAndSettle();
        expect(native.last.visible, isTrue);
      });
    }

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

    // D1 on iPhone: the compact native bar is drawn above the Flutter view,
    // so it would cover a sheet's bottom (or a dialog's) drawn in Flutter.
    // There it hides while anything is above the shell, as for a page.
    testWidgets('compact: a sheet above hides the native bar until it pops', (
      tester,
    ) async {
      final native = installFakeNative(state: _compact);
      await _pumpNative(tester, size: kPhone, padding: _compactPadding);
      unawaited(
        showModalBottomSheet<void>(
          context: tester.element(find.byType(TestPage).first),
          builder: (_) => const Text('sheet'),
        ),
      );
      await tester.pumpAndSettle();
      expect(native.last.hidden, isTrue);
      expect(native.last.interactive, isFalse);

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(native.last.hidden, isFalse);
      expect(native.last.interactive, isTrue);
    });

    // Owner decision (7b review): a sheet, dialog or menu hides the
    // compact bar, but the body keeps the bar's inset, so nothing behind
    // the overlay jumps 49pt and back. The overlay itself lays out against
    // the home indicator.
    for (final (name, open) in <(String, void Function(BuildContext))>[
      (
        'a sheet',
        (context) => unawaited(
          showModalBottomSheet<void>(
            context: context,
            builder: (_) => const Text('above'),
          ),
        ),
      ),
      (
        'a dialog',
        (context) => unawaited(
          showDialog<void>(
            context: context,
            builder: (_) => const Text('above'),
          ),
        ),
      ),
    ]) {
      testWidgets('compact: $name hides the bar but the body keeps its '
          'inset', (tester) async {
        final native = installFakeNative(state: _compact);
        await _pumpNative(tester, size: kPhone, padding: _compactPadding);
        final page = find.byType(TestPage).first;
        double body() => MediaQuery.paddingOf(tester.element(page)).bottom;
        open(tester.element(page));
        await tester.pumpAndSettle();
        expect(native.last.hidden, isTrue);

        _setBottomPadding(tester, 34);
        await tester.pump();
        expect(body(), 83);
        expect(_scope(tester).chromeInsets, const EdgeInsets.only(bottom: 83));
        // Above the shell (where the overlay is laid out): the window's own.
        expect(
          MediaQuery.paddingOf(tester.element(find.byType(Navigator))).bottom,
          34,
        );

        // Popped: until native shows the bar again, the body keeps 83.
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pump();
        await tester.pump();
        expect(native.last.hidden, isFalse);
        expect(body(), 83);
        _setBottomPadding(tester, 83);
        await tester.pumpAndSettle();
        expect(body(), 83);
        expect(_scope(tester).chromeInsets, const EdgeInsets.only(bottom: 83));
      });
    }

    // Hide on push: the page covers the body, so the bar's inset goes.
    testWidgets('compact: a page pushed above drops the bar inset', (
      tester,
    ) async {
      final native = installFakeNative(state: _compact);
      await _pumpNative(tester, size: kPhone, padding: _compactPadding);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator
          .push(
            MaterialPageRoute<void>(
              builder: (_) => const LiquidNoChrome(child: Text('above')),
            ),
          )
          .ignore();
      await tester.pumpAndSettle();
      expect(native.last.hidden, isTrue);

      _setBottomPadding(tester, 34);
      await tester.pump();
      expect(_scope(tester).chromeInsets, const EdgeInsets.only(bottom: 34));

      navigator.pop();
      _setBottomPadding(tester, 83);
      await tester.pumpAndSettle();
      expect(_scope(tester).chromeInsets, const EdgeInsets.only(bottom: 83));
    });

    // Hide on push (§7.4) holds under the compact bar too, from the first
    // frame of the push to the first frame of the pop.
    testWidgets('compact: a page pushed above hides the native bar until it '
        'pops', (tester) async {
      final native = installFakeNative(state: _compact);
      await _pumpNative(tester, size: kPhone, padding: _compactPadding);
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
      expect(_scope(tester).chromeKind, LiquidChromeKind.bottomBar);
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
      // Mid-push: the first shell no longer owns the native chrome, and it
      // must not draw Flutter chrome beside the second one's.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_flutterChrome(), isFalse);
      await tester.pumpAndSettle();
      expect(native.last.tabs.single.title, 'Starred');

      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_flutterChrome(), isFalse);
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
