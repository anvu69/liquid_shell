import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

import '../helpers/fake_native_platform.dart';
import '../helpers/shell_harness.dart';

// Native page bars on every tab (spec P3b-2 §4.4, §4.5, §6.1, §6.7).

const _destinations = [
  LiquidDestination(icon: Icon(Icons.home), label: 'Home', sfSymbol: 'house'),
  LiquidDestination(
    icon: Icon(Icons.book),
    label: 'Library',
    sfSymbol: 'books.vertical',
  ),
  LiquidDestination(
    icon: Icon(Icons.settings),
    label: 'Settings',
    sfSymbol: 'gear',
  ),
];

/// iPhone portrait with UIKit's compact bar in the bottom safe area.
const _compactPadding = EdgeInsets.only(top: 62, bottom: 83);
const _compact = LiquidNativeShellState(installed: true, compact: true);

final List<GlobalKey<NavigatorState>> _navigators = [
  for (var i = 0; i < 3; i++) GlobalKey<NavigatorState>(),
];

/// Home: a LiquidPage root. Library: a LiquidPage root with a large
/// title. Settings: a root without LiquidPage. Each in its own navigator.
Widget _page(int index) => Navigator(
  key: _navigators[index],
  onGenerateRoute: (_) => MaterialPageRoute<void>(
    builder: (_) => switch (index) {
      0 => const LiquidPage(
        title: 'Home',
        child: TestPage(label: 'Home'),
      ),
      1 => const LiquidPage(
        title: 'Library',
        largeTitle: true,
        child: TestPage(label: 'Library'),
      ),
      _ => const TestPage(label: 'Settings'),
    },
  ),
);

Future<FakeNativePlatform> _pump(
  WidgetTester tester, {
  int initialIndex = 0,
  LiquidNativeShellState state = _compact,
  Size size = kPhone,
  EdgeInsets padding = _compactPadding,
}) async {
  final fake = installFakeNative(state: state);
  await pumpShell(
    tester,
    TestShell(
      destinations: _destinations,
      initialIndex: initialIndex,
      pageBuilder: _page,
    ),
    size: size,
    padding: padding,
  );
  return fake;
}

/// Pushes [page] on tab [tab]'s navigator and settles.
Future<void> _push(WidgetTester tester, int tab, Widget page) async {
  _navigators[tab].currentState!
      .push(MaterialPageRoute<void>(builder: (_) => page))
      .ignore();
  await tester.pumpAndSettle();
}

/// A LiquidPage titled [title] over a [TestPage] labelled the same.
Widget _liquid(String title) => LiquidPage(
  title: title,
  child: TestPage(label: title),
);

/// The titles of tab [tab]'s native stack in the last config.
List<String> _titles(FakeNativePlatform fake, int tab) => [
  for (final page in fake.last.tabs[tab].pages) page.title,
];

/// A shell with `nativeChrome: off` whose body is the navigator [inner],
/// with a LiquidPage 'Inner' at its root. Built straight in a tab of the
/// outer shell (no navigator between), it is on the outer shell's route.
Widget _nestedShell(GlobalKey<NavigatorState> inner) => LiquidShell(
  nativeChrome: LiquidNativeChrome.off,
  destinations: const [
    LiquidDestination(icon: Icon(Icons.inbox), label: 'Inbox'),
    LiquidDestination(icon: Icon(Icons.send), label: 'Sent'),
  ],
  selectedIndex: 0,
  onDestinationSelected: (_) {},
  body: Navigator(
    key: inner,
    onGenerateRoute: (_) => MaterialPageRoute<void>(
      builder: (_) => _liquid('Inner'),
    ),
  ),
);

/// Pushes 'Inner 2' on [inner], then 'Form', a page whose PopScope blocks
/// every pop and counts the asks, and settles. Returns the count.
Future<int Function()> _pushInnerForm(
  WidgetTester tester,
  GlobalKey<NavigatorState> inner,
) async {
  var asks = 0;
  inner.currentState!
      .push(MaterialPageRoute<void>(builder: (_) => _liquid('Inner 2')))
      .ignore();
  await tester.pumpAndSettle();
  inner.currentState!
      .push(
        MaterialPageRoute<void>(
          builder: (_) => PopScope<void>(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) asks++;
            },
            child: _liquid('Form'),
          ),
        ),
      )
      .ignore();
  await tester.pumpAndSettle();
  return () => asks;
}

void main() {
  group('VK-442: every tab of an engaged shell', () {
    testWidgets('has a native page bar: LiquidPage draws only its child', (
      tester,
    ) async {
      await _pump(tester);
      expect(scopeOf(tester).nativePageBar, isTrue);
      expect(find.byType(LiquidBackButton), findsNothing);
    });

    testWidgets('sends the pages pushed on it', (tester) async {
      final fake = await _pump(tester);
      await _push(tester, 0, _liquid('Detail'));
      expect(_titles(fake, 0), ['Home', 'Detail']);
      expect(find.byType(LiquidBackButton), findsNothing);
    });

    testWidgets('Library keeps its large title in the config', (tester) async {
      final fake = await _pump(tester, initialIndex: 1);
      expect(fake.last.tabs[1].pages, const [
        LiquidNativePage(title: 'Library', largeTitle: true),
      ]);
    });
  });

  group('VK-442: the stand-in root (spec §6.1)', () {
    testWidgets('a LiquidPage above a root without one gets a root titled '
        "with the destination's label", (tester) async {
      final fake = await _pump(tester, initialIndex: 2);
      expect(fake.last.tabs[2].pages, isEmpty, reason: 'no LiquidPage yet');
      await _push(tester, 2, _liquid('About'));
      expect(fake.last.tabs[2].pages, const [
        LiquidNativePage(title: 'Settings', largeTitle: false),
        LiquidNativePage(title: 'About'),
      ]);
    });

    testWidgets('a native pop to the stand-in root pops every page', (
      tester,
    ) async {
      final fake = await _pump(tester, initialIndex: 2);
      await _push(tester, 2, _liquid('About'));
      await _push(tester, 2, _liquid('Profile'));
      expect(_titles(fake, 2), ['Settings', 'About', 'Profile']);
      fake.emitNative(const LiquidNativePopToPage(2, index: 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('list-About')), findsNothing);
      expect(find.byKey(const ValueKey('list-Settings')), findsOneWidget);
      expect(fake.last.tabs[2].pages, isEmpty);
    });

    testWidgets('a native pop-to above the stand-in maps its index', (
      tester,
    ) async {
      final fake = await _pump(tester, initialIndex: 2);
      for (final title in ['About', 'Profile', 'Licences']) {
        await _push(tester, 2, _liquid(title));
      }
      fake.emitNative(const LiquidNativePopToPage(2, index: 1));
      await tester.pumpAndSettle();
      expect(_titles(fake, 2), ['Settings', 'About']);
    });

    testWidgets('the back circle over the stand-in pops the page', (
      tester,
    ) async {
      final fake = await _pump(tester, initialIndex: 2);
      await _push(tester, 2, _liquid('About'));
      fake.emitNative(const LiquidNativeBackTapped(2));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('list-About')), findsNothing);
      expect(fake.last.tabs[2].pages, isEmpty);
    });

    testWidgets('a LiquidPage root of its navigator gets none', (
      tester,
    ) async {
      final fake = await _pump(tester);
      await _push(tester, 0, _liquid('Detail'));
      expect(fake.last.tabs[0].pages.first.title, 'Home');
      expect(fake.last.tabs[0].pages, hasLength(2));
    });
  });

  group("VK-442: LiquidHideChrome keeps a page's native bar (spec §4.4)", () {
    const photo = LiquidHideChrome(
      child: LiquidPage(
        title: 'Photo',
        child: TestPage(label: 'Photo'),
      ),
    );

    testWidgets('over a LiquidPage: the tab bar hides, the chrome stays', (
      tester,
    ) async {
      final fake = await _pump(tester);
      await _push(tester, 0, photo);
      expect(_titles(fake, 0), ['Home', 'Photo']);
      expect(fake.last.tabBarHidden, isTrue);
      expect(fake.last.hidden, isFalse);
      final scope = scopeOf(tester, 'Photo');
      expect(scope.chromeKind, LiquidChromeKind.hidden);
      expect(scope.chromeInsets, EdgeInsets.zero);
      expect(scope.nativePageBar, isTrue, reason: 'the page keeps its bar');

      _navigators[0].currentState!.pop();
      await tester.pumpAndSettle();
      expect(fake.last.tabBarHidden, isFalse, reason: 'the request ended');
      expect(fake.last.hidden, isFalse);
    });

    testWidgets('over a page without LiquidPage: the whole chrome hides', (
      tester,
    ) async {
      final fake = await _pump(tester, initialIndex: 2);
      await _push(
        tester,
        2,
        const LiquidHideChrome(child: TestPage(label: 'Plain')),
      );
      expect(fake.last.tabs[2].pages, isEmpty);
      expect(fake.last.hidden, isTrue);
      expect(fake.last.tabBarHidden, isFalse);
    });
  });

  // Spec §6.7, Q13: Flutter owns the edge swipe on every tab; the native
  // bar switches when the gesture ends. Guards kept whatever the spike
  // decides (VK-444).
  group("VK-444: the edge swipe stays Flutter's", () {
    /// Home's native stack in every config sent from [from] on.
    List<List<LiquidNativePage>> homeStacks(
      FakeNativePlatform fake,
      int from,
    ) => [for (final config in fake.configs.skip(from)) config.tabs[0].pages];

    /// Drags [gesture] [steps] × 20 pt to the right, a frame per step.
    Future<void> drag(
      WidgetTester tester,
      TestGesture gesture,
      int steps,
    ) async {
      for (var i = 0; i < steps; i++) {
        await gesture.moveBy(const Offset(20, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    testWidgets('a back swipe in progress sends no stack change; the commit '
        'sends the shorter stack once', (tester) async {
      final fake = await _pump(tester);
      await _push(tester, 0, _liquid('Detail'));
      final from = fake.configs.length;
      final before = fake.last.tabs[0].pages;
      final gesture = await tester.startGesture(const Offset(2, 400));
      await drag(tester, gesture, 6);
      expect(
        find.byKey(const ValueKey('list-Home')),
        findsOneWidget,
        reason: 'precondition: the swipe shows the page below',
      );
      expect(homeStacks(fake, from), everyElement(before), reason: 'mid-swipe');
      expect(before, const [
        LiquidNativePage(title: 'Home'),
        LiquidNativePage(title: 'Detail'),
      ]);
      await drag(tester, gesture, 10);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('list-Detail')), findsNothing);
      final stacks = homeStacks(fake, from);
      expect(stacks.where((stack) => stack.length == 1), hasLength(1));
      expect(stacks.last, const [LiquidNativePage(title: 'Home')]);
    });

    testWidgets('a cancelled swipe sends nothing', (tester) async {
      final fake = await _pump(tester);
      await _push(tester, 0, _liquid('Detail'));
      final from = fake.configs.length;
      final before = fake.last.tabs[0].pages;
      final gesture = await tester.startGesture(const Offset(2, 400));
      await drag(tester, gesture, 4);
      expect(
        find.byKey(const ValueKey('list-Home')),
        findsOneWidget,
        reason: 'precondition: the swipe started',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('list-Detail')), findsOneWidget);
      expect(homeStacks(fake, from), everyElement(before));
      expect(_titles(fake, 0), ['Home', 'Detail']);
    });
  });

  // Spec §5.4: the page's child keeps its GlobalKey through every bar
  // switch, so a focused, composing field keeps its IME connection.
  group('VK-442: IME safety across a bar switch', () {
    testWidgets('a composing field keeps its state, focus and composing '
        'range when native chrome engages and when LiquidHideChrome '
        'toggles', (tester) async {
      final fake = installFakeNative(state: _compact)
        ..attachGate = Completer<LiquidNativeShellState>();
      final hide = ValueNotifier(false);
      addTearDown(hide.dispose);
      await pumpShell(
        tester,
        const TestShell(
          destinations: _destinations,
          initialIndex: 2,
          pageBuilder: _page,
        ),
        padding: _compactPadding,
      );
      await _push(
        tester,
        2,
        ValueListenableBuilder<bool>(
          valueListenable: hide,
          builder: (_, hidden, child) =>
              LiquidHideChrome(enabled: hidden, child: child!),
          child: const LiquidPage(
            title: 'Profile',
            child: Material(child: Center(child: TextField())),
          ),
        ),
      );
      LiquidShellScopeData scope() =>
          LiquidShellScope.of(tester.element(find.byType(TextField)));
      expect(scope().nativePageBar, isFalse, reason: 'pending: Flutter bar');
      expect(find.byType(LiquidBackButton), findsOneWidget);

      await tester.tap(find.byType(TextField));
      await tester.pump();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'hoa',
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange(start: 0, end: 3),
        ),
      );
      await tester.pump();
      final field = tester.state<EditableTextState>(find.byType(EditableText));
      tester.testTextInput.log.clear();

      void expectKept(String when) {
        final now = tester.state<EditableTextState>(find.byType(EditableText));
        expect(now, same(field), reason: when);
        expect(now.widget.focusNode.hasFocus, isTrue, reason: when);
        expect(
          now.textEditingValue.composing,
          const TextRange(start: 0, end: 3),
          reason: when,
        );
        final methods = [
          for (final call in tester.testTextInput.log) call.method,
        ];
        expect(methods, isNot(contains('TextInput.clearClient')));
        expect(methods, isNot(contains('TextInput.setClient')));
      }

      fake.attachGate!.complete(_compact);
      await tester.pumpAndSettle();
      expect(scope().nativePageBar, isTrue, reason: 'precondition: engaged');
      expect(find.byType(LiquidBackButton), findsNothing);
      expectKept('native chrome engaged');

      hide.value = true;
      await tester.pumpAndSettle();
      expectKept('hide request');
      hide.value = false;
      await tester.pumpAndSettle();
      expectKept('hide request ended');
    });
  });

  // Spec §6.10: a nested shell must use nativeChrome: off; its pages
  // register with it and draw the Flutter bar.
  testWidgets("a nested shell's pages draw the Flutter bar and stay out of "
      "the outer tab's stack", (tester) async {
    final fake = installFakeNative(state: _compact);
    final inner = GlobalKey<NavigatorState>();
    await pumpShell(
      tester,
      TestShell(
        destinations: _destinations,
        pageBuilder: (index) => index == 0 ? _nestedShell(inner) : _page(index),
      ),
      padding: _compactPadding,
    );
    inner.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => _liquid('Inner 2')))
        .ignore();
    await tester.pumpAndSettle();
    expect(find.byType(LiquidBackButton), findsOneWidget);
    expect(scopeOf(tester, 'Inner 2').nativePageBar, isFalse);
    expect(fake.last.tabs[0].pages, isEmpty);
  });

  // S's rule (VK-776): a shell in another shell's body with no navigator
  // between is on that shell's route; its own back handler steps aside,
  // and the outer shell's walk hands back to it. The native back pops a
  // page directly (no handleBack): it must never reach such a shell's
  // pages, and when it lands on the outer shell's route the outer order
  // runs, once.
  group('VK-442: native back and a same-route nested shell', () {
    testWidgets('the native back never reaches a same-route nested '
        "shell's page; system back asks its page once, in the outer "
        "shell's order", (tester) async {
      final fake = installFakeNative(state: _compact);
      final inner = GlobalKey<NavigatorState>();
      await pumpShell(
        tester,
        TestShell(
          destinations: _destinations,
          pageBuilder: (index) =>
              index == 0 ? _nestedShell(inner) : _page(index),
        ),
        padding: _compactPadding,
      );
      final asks = await _pushInnerForm(tester, inner);
      expect(fake.last.tabs[0].pages, isEmpty);

      fake.emitNative(const LiquidNativeBackTapped(0));
      await tester.pumpAndSettle();
      expect(asks(), 0, reason: 'the native back');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(asks(), 1, reason: 'one back, one ask');
      expect(find.text('Form page: 0'), findsOneWidget);
    });

    testWidgets('a native back on a LiquidPage around a same-route nested '
        "shell runs the outer shell's order: the nested shell's page is "
        'asked once', (tester) async {
      final fake = installFakeNative(state: _compact);
      final inner = GlobalKey<NavigatorState>();
      await pumpShell(
        tester,
        TestShell(
          destinations: _destinations,
          pageBuilder: (index) => index == 0
              ? LiquidPage(title: 'Mail', child: _nestedShell(inner))
              : _page(index),
        ),
        padding: _compactPadding,
      );
      final asks = await _pushInnerForm(tester, inner);
      expect(_titles(fake, 0), ['Mail']);

      fake.emitNative(const LiquidNativeBackTapped(0));
      await tester.pumpAndSettle();
      expect(asks(), 1, reason: 'one back, one ask');
      expect(find.text('Form page: 0'), findsOneWidget);
      expect(find.byType(TestShell), findsOneWidget, reason: 'the shell');
    });
  });

  group('VK-442: window controls (spec §4.5)', () {
    const controls = LiquidWindowControls(leading: 66, top: 24);

    testWidgets('a tab without pages under the compact native bar keeps '
        "native's window controls", (tester) async {
      final fake = await _pump(tester, initialIndex: 2);
      fake.emitNative(const LiquidWindowControlsChanged(controls));
      await tester.pump();
      expect(scopeOf(tester, 'Settings').windowControls, controls);
    });

    testWidgets("LiquidHideChrome at regular width passes native's window "
        'controls', (tester) async {
      final fake = await _pump(
        tester,
        initialIndex: 2,
        state: kInstalled,
        size: kTabletLandscape,
        padding: const EdgeInsets.only(top: 74, bottom: 20),
      );
      await _push(
        tester,
        2,
        const LiquidHideChrome(child: TestPage(label: 'Plain')),
      );
      fake.emitNative(const LiquidWindowControlsChanged(controls));
      await tester.pump();
      expect(scopeOf(tester, 'Plain').windowControls, controls);
    });
  });
}
