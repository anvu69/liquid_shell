import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/native/native_host.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

import '../helpers/fake_native_platform.dart';
import '../helpers/shell_harness.dart';

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

final _searchNavigator = GlobalKey<NavigatorState>();

/// The search page: a branch navigator whose root is a LiquidPage.
Widget _page(int index) => switch (index) {
  2 => Navigator(
    key: _searchNavigator,
    onGenerateRoute: (_) => MaterialPageRoute<void>(
      builder: (_) => const LiquidPage(
        title: 'Search',
        child: TestPage(label: 'Search'),
      ),
    ),
  ),
  _ => TestPage(label: _destinations[index].label),
};

Future<(FakeNativePlatform, LiquidSearchController, List<String>)> _pump(
  WidgetTester tester, {
  int initialIndex = 2,
  LiquidBeforeDestinationChange? guard,
  List<String>? submitted,
  Widget Function(int index) pageBuilder = _page,
  bool settle = true,
  FakeNativePlatform? platform,
}) async {
  final fake = platform ?? installFakeNative(state: _compact);
  final controller = LiquidSearchController();
  addTearDown(controller.dispose);
  final changes = <String>[];
  await pumpShell(
    tester,
    TestShell(
      destinations: _destinations,
      initialIndex: initialIndex,
      guard: guard,
      pageBuilder: pageBuilder,
      search: LiquidSearch(
        controller: controller,
        placeholder: 'Songs, places',
        onChanged: changes.add,
        onSubmitted: submitted?.add,
      ),
    ),
    padding: _compactPadding,
    settle: settle,
  );
  // The first native entry replays the (empty) text (spec §7.10); the
  // tests below are about what happens after it.
  if (settle) fake.searchTexts.clear();
  return (fake, controller, changes);
}

LiquidShellScopeData _scope(WidgetTester tester, [String label = 'Search']) =>
    scopeOf(tester, label);

/// [_page] with the search tab's root page built by [root].
Widget Function(int) _withSearchRoot(Widget Function() root) =>
    (index) => index == 2
    ? Navigator(
        key: _searchNavigator,
        onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => root()),
      )
    : _page(index);

final _homeNavigator = GlobalKey<NavigatorState>();

/// [_page] with a branch navigator on Home too.
Widget _homeNavigatorPage(int index) => index == 0
    ? Navigator(
        key: _homeNavigator,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => const LiquidPage(
            title: 'Home',
            child: TestPage(label: 'Home'),
          ),
        ),
      )
    : _page(index);

/// [_page] with Home as a LiquidPage of the shell's own route.
Widget _homeLiquidPage(int index) => index == 0
    ? const LiquidPage(
        title: 'Home',
        child: TestPage(label: 'Home'),
      )
    : _page(index);

/// Pushes a detail page on [navigator] (the search tab's by default).
Future<void> _pushDetail(
  WidgetTester tester, {
  GlobalKey<NavigatorState>? navigator,
}) async {
  (navigator ?? _searchNavigator).currentState!
      .push(
        MaterialPageRoute<void>(
          builder: (_) => const LiquidPage(
            title: 'Hồ Hoàn Kiếm',
            child: TestPage(label: 'Detail'),
          ),
        ),
      )
      .ignore();
  await tester.pumpAndSettle();
}

/// The scroll position of the page of [label], even while it is offstage.
ScrollPosition _position(WidgetTester tester, String label) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(ValueKey('list-$label'), skipOffstage: false),
            matching: find.byType(Scrollable, skipOffstage: false),
          )
          .first,
    )
    .position;

/// The search tab's page titles in every config sent from [from] on.
List<List<String>> _searchStacks(FakeNativePlatform fake, int from) => [
  for (final config in fake.configs.skip(from))
    [for (final page in config.tabs.last.pages) page.title],
];

/// A list that keeps its offset in the route's PageStorage.
class _StoredList extends StatelessWidget {
  const _StoredList();

  @override
  Widget build(BuildContext context) => ListView(
    key: const PageStorageKey('stored-list'),
    children: [
      for (var i = 0; i < 60; i++) SizedBox(height: 40, child: Text('row $i')),
    ],
  );
}

void main() {
  setUp(debugResetLiquidNative);

  testWidgets('the config marks the search tab and carries the placeholder', (
    tester,
  ) async {
    final (fake, _, _) = await _pump(tester);
    expect(fake.last.tabs.map((t) => t.search), [false, false, true]);
    expect(fake.last.search?.placeholder, 'Songs, places');
    expect(fake.last.selectedIndex, 2);
    expect(fake.last.tabs.last.pages.map((p) => p.title), ['Search']);
  });

  testWidgets(
    'a native tap on the search tab runs the guard, then selects it',
    (
      tester,
    ) async {
      final asked = <int>[];
      final (fake, _, _) = await _pump(
        tester,
        initialIndex: 0,
        guard: (i) async {
          asked.add(i);
          return true;
        },
      );
      fake.emitNative(const LiquidNativeDestinationTapped(2));
      await tester.pumpAndSettle();
      expect(asked, [2]);
      expect(fake.last.selectedIndex, 2);
      expect(_scope(tester).searchPhase, LiquidSearchPhase.selected);
    },
  );

  testWidgets('native text reaches the controller and onChanged, not back', (
    tester,
  ) async {
    final (fake, controller, changes) = await _pump(tester);
    fake.emitNative(const LiquidNativeSearchTextChanged('hô', composing: true));
    await tester.pump();
    expect(controller.value.text, 'hô');
    expect(controller.value.composing, isTrue);
    expect(changes, ['hô']);
    expect(fake.searchTexts, isEmpty, reason: 'never echoed');
  });

  testWidgets('text while another tab is selected is dropped', (tester) async {
    final (fake, controller, _) = await _pump(tester, initialIndex: 0);
    fake.emitNative(const LiquidNativeSearchTextChanged('x', composing: false));
    await tester.pump();
    expect(controller.text, '');
  });

  testWidgets('the app sets the text: native gets it', (tester) async {
    final (fake, controller, changes) = await _pump(tester);
    controller.text = 'ho';
    await tester.pump();
    expect(fake.searchTexts, ['ho']);
    expect(changes, isEmpty, reason: 'onChanged is for the user');
  });

  testWidgets('submit calls onSubmitted', (tester) async {
    final submitted = <String>[];
    final (fake, _, _) = await _pump(tester, submitted: submitted);
    fake.emitNative(const LiquidNativeSearchSubmitted('hồ'));
    await tester.pump();
    expect(submitted, ['hồ']);
  });

  testWidgets('reselecting the search tab restores the kept query (Q2)', (
    tester,
  ) async {
    final (fake, controller, _) = await _pump(tester);
    fake.emitNative(
      const LiquidNativeSearchTextChanged('hà', composing: false),
    );
    await tester.pump();
    fake.emitNative(const LiquidNativeDestinationTapped(0));
    await tester.pumpAndSettle();
    expect(fake.last.selectedIndex, 0);
    expect(controller.text, 'hà', reason: 'kept while away');
    fake.searchTexts.clear();
    fake.emitNative(const LiquidNativeDestinationTapped(2));
    await tester.pumpAndSettle();
    expect(fake.last.selectedIndex, 2);
    expect(fake.searchTexts, ['hà'], reason: 'sent after the selecting config');
  });

  testWidgets('leaving the search tab while active makes it inactive', (
    tester,
  ) async {
    final (fake, controller, _) = await _pump(tester);
    fake.emitNative(const LiquidNativeSearchActiveChanged(true));
    await tester.pump();
    expect(controller.isActive, isTrue);
    expect(_scope(tester).searchPhase, LiquidSearchPhase.active);
    fake.emitNative(const LiquidNativeDestinationTapped(0));
    await tester.pumpAndSettle();
    expect(controller.isActive, isFalse);
  });

  testWidgets('activate unfocuses Flutter and asks native; ignored elsewhere', (
    tester,
  ) async {
    final (fake, controller, _) = await _pump(tester, initialIndex: 0);
    // One debug line (spec §14), captured so the test output stays clean.
    final logs = <String?>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message);
    try {
      controller.activate();
    } finally {
      debugPrint = original;
    }
    await tester.pump();
    expect(fake.searchActives, isEmpty, reason: 'search tab not selected');
    expect(logs, [contains('activate() ignored')]);
    fake.emitNative(const LiquidNativeDestinationTapped(2));
    await tester.pumpAndSettle();
    // A Flutter text field elsewhere has the focus (first-responder rule,
    // spec §7.4): activation takes it away before native focuses its field.
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final entry = OverlayEntry(
      builder: (_) => Material(child: TextField(focusNode: focus)),
    );
    Overlay.of(
      tester.element(find.byKey(const ValueKey('list-Search'))),
    ).insert(entry);
    addTearDown(entry.remove);
    await tester.pump();
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    controller.activate();
    await tester.pump();
    expect(fake.searchActives, [true]);
    expect(focus.hasFocus, isFalse);
    controller.deactivate();
    await tester.pump();
    expect(fake.searchActives, [true, false]);
  });

  testWidgets('a dialog above an active search deactivates it first', (
    tester,
  ) async {
    final (fake, _, _) = await _pump(tester);
    fake.emitNative(const LiquidNativeSearchActiveChanged(true));
    await tester.pump();
    showDialog<void>(
      context: tester.element(find.byKey(const ValueKey('list-Search'))),
      builder: (_) => const AlertDialog(title: Text('Hi')),
    ).ignore();
    await tester.pumpAndSettle();
    expect(fake.searchActives, [false]);
  });

  testWidgets('the field above the keyboard moves the bottom inset', (
    tester,
  ) async {
    final (fake, _, _) = await _pump(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 328);
    addTearDown(tester.view.resetViewInsets);
    fake
      ..emitNative(const LiquidNativeSearchActiveChanged(true))
      ..emitNative(
        const LiquidNativeSearchFieldChanged(Rect.fromLTWH(8, 490, 330, 48)),
      );
    await tester.pump();
    // max(852 − 490, 328 + 48 + 16) on the 393×852 harness window.
    expect(_scope(tester).chromeInsets.bottom, 392);
  });

  testWidgets('pages reach the config; native back pops the top page', (
    tester,
  ) async {
    final (fake, _, _) = await _pump(tester);
    _searchNavigator.currentState!
        .push(
          MaterialPageRoute<void>(
            builder: (_) => const LiquidPage(
              title: 'Hồ Hoàn Kiếm',
              child: TestPage(label: 'Detail'),
            ),
          ),
        )
        .ignore();
    await tester.pumpAndSettle();
    expect(fake.last.tabs.last.pages.map((p) => p.title), [
      'Search',
      'Hồ Hoàn Kiếm',
    ]);
    fake.emitNative(const LiquidNativeBackTapped(2));
    await tester.pumpAndSettle();
    expect(fake.last.tabs.last.pages.map((p) => p.title), ['Search']);
    expect(find.byKey(const ValueKey('list-Detail')), findsNothing);
  });

  testWidgets('a page that refuses to pop stays', (tester) async {
    final (fake, _, _) = await _pump(tester);
    _searchNavigator.currentState!
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
    fake.emitNative(const LiquidNativeBackTapped(2));
    await tester.pumpAndSettle();
    expect(fake.last.tabs.last.pages, hasLength(2));
  });

  testWidgets('a back tap for another tab is dropped', (tester) async {
    final (fake, _, _) = await _pump(tester);
    _searchNavigator.currentState!
        .push(
          MaterialPageRoute<void>(
            builder: (_) => const LiquidPage(
              title: 'D',
              child: TestPage(label: 'D'),
            ),
          ),
        )
        .ignore();
    await tester.pumpAndSettle();
    fake.emitNative(const LiquidNativeBackTapped(0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('list-D')), findsOneWidget);
  });

  // Replaces the plan's version, whose controls were set after the pump
  // and never read, so it could not fail (review I-3).
  testWidgets('the search tab has a native bar: no Flutter bar, no controls', (
    tester,
  ) async {
    const controls = LiquidWindowControls(leading: 66, top: 24);
    final (fake, _, _) = await _pump(tester, initialIndex: 0);
    fake.emitNative(const LiquidWindowControlsChanged(controls));
    await tester.pump();
    expect(_scope(tester, 'Home').nativePageBar, isFalse);
    expect(
      _scope(tester, 'Home').windowControls,
      controls,
      reason: "the compact bar is at the bottom: the top is the page's",
    );
    fake.emitNative(const LiquidNativeDestinationTapped(2));
    await tester.pumpAndSettle();
    final scope = _scope(tester);
    expect(scope.nativePageBar, isTrue);
    expect(scope.windowControls, LiquidWindowControls.zero);
    expect(find.byType(LiquidBackButton), findsNothing);
    expect(find.text('Search'), findsNothing, reason: 'UIKit draws the title');
  });

  testWidgets('the top page scroll goes to native, tagged with its tab', (
    tester,
  ) async {
    final (fake, _, _) = await _pump(tester);
    await tester.drag(
      find.byKey(const ValueKey('list-Search')),
      const Offset(0, -300),
    );
    await tester.pump();
    expect(fake.pageScrolls, isNotEmpty);
    expect(fake.pageScrolls.last.$1, 2);
    expect(fake.pageScrolls.last.$2, greaterThan(100));
  });
  group('carry-over: scope, attach and host', () {
    testWidgets('LiquidShellScope.searchPhaseOf follows the search tab', (
      tester,
    ) async {
      final (fake, _, _) = await _pump(tester);
      LiquidSearchPhase? phaseOf(String label) =>
          LiquidShellScope.searchPhaseOf(
            tester.element(find.byKey(ValueKey('list-$label'))),
          );
      expect(phaseOf('Search'), LiquidSearchPhase.selected);
      fake.emitNative(const LiquidNativeSearchActiveChanged(true));
      await tester.pump();
      expect(phaseOf('Search'), LiquidSearchPhase.active);
      fake.emitNative(const LiquidNativeDestinationTapped(0));
      await tester.pumpAndSettle();
      expect(phaseOf('Home'), LiquidSearchPhase.idle);
    });

    testWidgets('searchPhaseOf: null without a search tab; the Flutter '
        'chrome publishes it too', (tester) async {
      await pumpShell(tester, const TestShell());
      expect(
        LiquidShellScope.searchPhaseOf(
          tester.element(find.byKey(const ValueKey('list-Home'))),
        ),
        isNull,
      );
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      await pumpShell(
        tester,
        TestShell(
          // A new State: a reused one would keep its selection.
          key: const ValueKey('with search'),
          destinations: _destinations,
          initialIndex: 2,
          pageBuilder: _page,
          search: LiquidSearch(controller: controller),
        ),
      );
      expect(
        LiquidShellScope.searchPhaseOf(
          tester.element(find.byKey(const ValueKey('list-Search'))),
        ),
        LiquidSearchPhase.selected,
      );
    });

    testWidgets('the host forwards search and back events to the newest '
        'claim only', (tester) async {
      final fake = installFakeNative();
      final first = <LiquidNativeEvent>[];
      final second = <LiquidNativeEvent>[];
      final a = NativeChromeHost.instance.claim(first.add);
      final b = NativeChromeHost.instance.claim(second.add);
      const events = <LiquidNativeEvent>[
        LiquidNativeSearchTextChanged('a', composing: false),
        LiquidNativeSearchActiveChanged(true),
        LiquidNativeSearchSubmitted('a'),
        LiquidNativeSearchFieldChanged(Rect.fromLTWH(8, 490, 330, 48)),
        LiquidNativeBackTapped(2),
      ];
      void emitAll() => events.forEach(fake.emitNative);

      emitAll();
      await tester.pump();
      expect(first, isEmpty);
      expect(second, events);
      b.release();
      emitAll();
      await tester.pump();
      expect(first, events);
      expect(second, hasLength(events.length));
      a.release();
    });

    testWidgets('a new shell key: the old shell lets go of the controller '
        'before the new one takes it', (tester) async {
      final fake = installFakeNative(state: _compact);
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      Widget shell(int key) => TestShell(
        key: ValueKey(key),
        destinations: _destinations,
        initialIndex: 2,
        pageBuilder: _page,
        search: LiquidSearch(controller: controller),
      );
      await pumpShell(tester, shell(1), padding: _compactPadding);
      await pumpShell(tester, shell(2), padding: _compactPadding);
      expect(tester.takeException(), isNull);
      fake.searchTexts.clear();
      controller.text = 'x';
      await tester.pump();
      expect(fake.searchTexts, ['x']);
    });

    testWidgets('a shell moved with a GlobalKey keeps driving the search', (
      tester,
    ) async {
      final fake = installFakeNative(state: _compact);
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      // One LiquidShell for both places: the move then updates no widget
      // (no didUpdateWidget), so only `activate` can take the controller
      // again.
      final shell = LiquidShell(
        key: GlobalKey(),
        destinations: _destinations,
        selectedIndex: 2,
        onDestinationSelected: (_) {},
        search: LiquidSearch(controller: controller),
        body: IndexedStack(
          index: 2,
          children: [for (var i = 0; i < 3; i++) _page(i)],
        ),
      );
      Widget at({required bool padded}) {
        return padded
            ? Padding(padding: EdgeInsets.zero, child: shell)
            : SizedBox.expand(child: shell);
      }

      await pumpShell(tester, at(padded: false), padding: _compactPadding);
      await pumpShell(tester, at(padded: true), padding: _compactPadding);
      expect(tester.takeException(), isNull);
      fake.searchTexts.clear();
      controller.text = 'y';
      await tester.pump();
      expect(fake.searchTexts, ['y']);
      controller.activate();
      await tester.pump();
      expect(fake.searchActives, [true]);
    });

    testWidgets('a new controller: the shell drives it and lets the old go', (
      tester,
    ) async {
      final fake = installFakeNative(state: _compact);
      final first = LiquidSearchController();
      final second = LiquidSearchController(text: 'hồ');
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      Widget shell(LiquidSearchController controller) => TestShell(
        destinations: _destinations,
        initialIndex: 2,
        pageBuilder: _page,
        search: LiquidSearch(controller: controller),
      );
      await pumpShell(tester, shell(first), padding: _compactPadding);
      fake.searchTexts.clear();
      fake.emitNative(const LiquidNativeSearchActiveChanged(true));
      await tester.pump();
      await pumpShell(tester, shell(second), padding: _compactPadding);
      expect(fake.searchTexts, ['hồ'], reason: 'the field shows the new query');
      expect(second.isActive, isTrue, reason: 'the field still has focus');

      first
        ..text = 'a'
        ..activate();
      await tester.pump();
      expect(fake.searchTexts, ['hồ'], reason: 'the old one is let go');
      expect(fake.searchActives, isEmpty);
      fake.emitNative(
        const LiquidNativeSearchTextChanged('hồ g', composing: false),
      );
      await tester.pump();
      expect(second.text, 'hồ g');
      expect(first.text, 'a');
    });

    testWidgets('an app that mirrors the query sends nothing back (Telex)', (
      tester,
    ) async {
      final fake = installFakeNative(state: _compact);
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      // The app writes back what it hears, as a two-way binding would.
      controller.addListener(() => controller.text = controller.value.text);
      await pumpShell(
        tester,
        TestShell(
          destinations: _destinations,
          initialIndex: 2,
          pageBuilder: _page,
          search: LiquidSearch(
            controller: controller,
            onChanged: (text) => controller.text = text,
          ),
        ),
        padding: _compactPadding,
      );
      fake.searchTexts.clear();
      for (final (text, composing) in const [
        ('h', false),
        ('ho', false),
        ('hoo', false),
        ('hô', false),
        ('hôf', true),
        ('hồ', false),
      ]) {
        fake.emitNative(
          LiquidNativeSearchTextChanged(text, composing: composing),
        );
        await tester.pump();
      }
      expect(controller.text, 'hồ');
      expect(fake.searchTexts, isEmpty);
    });
  });

  group('carry-over: pages', () {
    testWidgets('the Flutter chrome gives LiquidPage the strings', (
      tester,
    ) async {
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      await pumpShell(
        tester,
        TestShell(
          destinations: _destinations,
          initialIndex: 2,
          pageBuilder: _page,
          strings: const LiquidShellStrings(back: 'Go back'),
          search: LiquidSearch(controller: controller),
        ),
      );
      await _pushDetail(tester);
      expect(find.bySemanticsLabel('Go back'), findsOneWidget);
    });

    testWidgets('native chrome gives a Flutter page bar the strings', (
      tester,
    ) async {
      installFakeNative(state: _compact);
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      await pumpShell(
        tester,
        TestShell(
          destinations: _destinations,
          pageBuilder: _homeNavigatorPage,
          strings: const LiquidShellStrings(back: 'Go back'),
          search: LiquidSearch(controller: controller),
        ),
        padding: _compactPadding,
      );
      expect(scopeOf(tester).nativeChrome, isTrue);
      await _pushDetail(tester, navigator: _homeNavigator);
      expect(find.bySemanticsLabel('Go back'), findsOneWidget);
    });

    testWidgets('a page pushed above the shell keeps the stack: no re-push '
        'when it pops', (tester) async {
      final (fake, _, _) = await _pump(tester);
      await _pushDetail(tester);
      final from = fake.configs.length;
      final root = Navigator.of(
        tester.element(find.byKey(const ValueKey('list-Detail'))),
        rootNavigator: true,
      );
      root
          .push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Above')),
            ),
          )
          .ignore();
      await tester.pumpAndSettle();
      expect(find.text('Above'), findsOneWidget);
      root.pop();
      await tester.pumpAndSettle();
      expect(_searchStacks(fake, from), isNotEmpty);
      expect(
        _searchStacks(fake, from),
        everyElement(['Search', 'Hồ Hoàn Kiếm']),
      );
    });

    testWidgets('a sheet in the tab navigator keeps the stack: no pop to '
        'root', (tester) async {
      final (fake, _, _) = await _pump(tester);
      await _pushDetail(tester);
      final from = fake.configs.length;
      showModalBottomSheet<void>(
        context: tester.element(find.byKey(const ValueKey('list-Detail'))),
        builder: (_) => const SizedBox(height: 200, child: Text('Sheet')),
      ).ignore();
      await tester.pumpAndSettle();
      expect(find.text('Sheet'), findsOneWidget);
      expect(fake.last.tabs.last.pages.map((p) => p.title), [
        'Search',
        'Hồ Hoàn Kiếm',
      ]);
      _searchNavigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Sheet'), findsNothing);
      expect(
        _searchStacks(fake, from),
        everyElement(['Search', 'Hồ Hoàn Kiếm']),
      );
      expect(fake.last.tabs.last.pages, hasLength(2));
    });
  });

  group('carry-over: scroll', () {
    testWidgets("one message per frame, with the frame's last offset", (
      tester,
    ) async {
      final (fake, _, _) = await _pump(tester);
      fake.pageScrolls.clear();
      _position(tester, 'Search')
        ..jumpTo(50)
        ..jumpTo(120)
        ..jumpTo(180);
      await tester.pump();
      await tester.pump();
      expect(fake.pageScrolls, [(2, 180.0)]);
    });

    testWidgets('nothing for a tab without a native bar or a covered page', (
      tester,
    ) async {
      final (fake, _, _) = await _pump(
        tester,
        initialIndex: 0,
        pageBuilder: _homeLiquidPage,
      );
      _position(tester, 'Home').jumpTo(200);
      await tester.pump();
      await tester.pump();
      expect(fake.pageScrolls, isEmpty, reason: 'Home has no native bar');

      fake.emitNative(const LiquidNativeDestinationTapped(2));
      await tester.pumpAndSettle();
      await _pushDetail(tester);
      fake.pageScrolls.clear();
      _position(tester, 'Search').jumpTo(200);
      await tester.pump();
      await tester.pump();
      expect(fake.pageScrolls, isEmpty, reason: 'covered by the detail');
      _position(tester, 'Detail').jumpTo(90);
      await tester.pump();
      expect(fake.pageScrolls, [(2, 90.0)]);
    });

    testWidgets('a page moved with a GlobalKey sends its offset again', (
      tester,
    ) async {
      final moved = ValueNotifier(false);
      addTearDown(moved.dispose);
      final pageKey = GlobalKey();
      final (fake, _, _) = await _pump(
        tester,
        pageBuilder: _withSearchRoot(
          () => ValueListenableBuilder<bool>(
            valueListenable: moved,
            builder: (_, isMoved, _) {
              final page = LiquidPage(
                key: pageKey,
                title: 'Search',
                child: const TestPage(label: 'Search'),
              );
              return isMoved
                  ? Padding(padding: EdgeInsets.zero, child: page)
                  : SizedBox.expand(child: page);
            },
          ),
        ),
      );
      fake.pageScrolls.clear();
      _position(tester, 'Search').jumpTo(200);
      await tester.pump();
      expect(fake.pageScrolls, [(2, 200.0)]);
      fake.pageScrolls.clear();
      moved.value = true;
      await tester.pumpAndSettle();
      expect(_position(tester, 'Search').pixels, 200);
      expect(fake.pageScrolls, [(2, 200.0)]);
    });

    testWidgets('a page restored from PageStorage sends its offset', (
      tester,
    ) async {
      final shown = ValueNotifier(true);
      addTearDown(shown.dispose);
      final (fake, _, _) = await _pump(
        tester,
        pageBuilder: _withSearchRoot(
          () => ValueListenableBuilder<bool>(
            valueListenable: shown,
            builder: (_, isShown, _) => isShown
                ? const LiquidPage(title: 'Search', child: _StoredList())
                : const SizedBox.shrink(),
          ),
        ),
      );
      final list = find.byKey(const PageStorageKey('stored-list'));
      fake.pageScrolls.clear();
      tester
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)),
          )
          .position
          .jumpTo(240);
      await tester.pump();
      expect(fake.pageScrolls, [(2, 240.0)]);
      fake.pageScrolls.clear();
      shown.value = false;
      await tester.pumpAndSettle();
      shown.value = true;
      await tester.pumpAndSettle();
      expect(
        tester
            .state<ScrollableState>(
              find.descendant(of: list, matching: find.byType(Scrollable)),
            )
            .position
            .pixels,
        240,
        reason: 'restored from PageStorage',
      );
      expect(fake.pageScrolls, [(2, 240.0)]);
    });

    testWidgets('an offset scrolled before native engages is sent once it '
        'does', (tester) async {
      final fake = installFakeNative(state: _compact)
        ..attachGate = Completer<LiquidNativeShellState>();
      await _pump(tester, platform: fake, settle: false);
      await tester.pump();
      _position(tester, 'Search').jumpTo(150);
      await tester.pump();
      await tester.pump();
      expect(fake.pageScrolls, isEmpty);
      fake.attachGate!.complete(_compact);
      await tester.pumpAndSettle();
      expect(fake.pageScrolls, [(2, 150.0)]);
    });
  });
  group('review fixes', () {
    Widget searchShell(
      LiquidSearchController controller, {
      int initialIndex = 2,
      LiquidNativeChrome nativeChrome = LiquidNativeChrome.auto,
    }) => TestShell(
      destinations: _destinations,
      initialIndex: initialIndex,
      pageBuilder: _page,
      nativeChrome: nativeChrome,
      search: LiquidSearch(controller: controller),
    );

    testWidgets('I-1: the text reaches native once it engages (cold start)', (
      tester,
    ) async {
      final fake = installFakeNative(state: _compact)
        ..attachGate = Completer<LiquidNativeShellState>();
      final controller = LiquidSearchController(text: 'hồ');
      addTearDown(controller.dispose);
      await pumpShell(
        tester,
        searchShell(controller),
        padding: _compactPadding,
        settle: false,
      );
      await tester.pump();
      await tester.pump();
      expect(fake.searchTexts, isEmpty, reason: 'nothing installed yet');
      fake.attachGate!.complete(_compact);
      await tester.pumpAndSettle();
      expect(fake.searchTexts, ['hồ']);
    });

    testWidgets('I-1: an app write while pending reaches native too', (
      tester,
    ) async {
      final fake = installFakeNative(state: _compact)
        ..attachGate = Completer<LiquidNativeShellState>();
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      await pumpShell(
        tester,
        searchShell(controller),
        padding: _compactPadding,
        settle: false,
      );
      await tester.pump();
      controller.text = 'hà nội';
      await tester.pump();
      fake.attachGate!.complete(_compact);
      await tester.pumpAndSettle();
      expect(fake.searchTexts, ['hà nội']);
    });

    testWidgets('I-1: the first native entry sends the text even when empty '
        '(hot restart: native may still show the old one)', (tester) async {
      final fake = installFakeNative(state: _compact);
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      await pumpShell(
        tester,
        searchShell(controller),
        padding: _compactPadding,
      );
      expect(fake.searchTexts, ['']);
      fake.emitNative(const LiquidNativeDestinationTapped(0));
      await tester.pumpAndSettle();
      fake.emitNative(const LiquidNativeDestinationTapped(2));
      await tester.pumpAndSettle();
      expect(fake.searchTexts, [''], reason: 'an empty kept query: no resend');
    });

    testWidgets('I-1: after Flutter chrome, native shows the text again', (
      tester,
    ) async {
      final fake = installFakeNative(state: _compact);
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      await pumpShell(
        tester,
        searchShell(controller),
        padding: _compactPadding,
      );
      fake.emitNative(
        const LiquidNativeSearchTextChanged('hà', composing: false),
      );
      await tester.pump();
      await pumpShell(
        tester,
        searchShell(controller, nativeChrome: LiquidNativeChrome.off),
        padding: _compactPadding,
      );
      fake.searchTexts.clear();
      await pumpShell(
        tester,
        searchShell(controller),
        padding: _compactPadding,
      );
      expect(fake.searchTexts, ['hà']);
    });

    testWidgets('native takes over a focused, composing Flutter field: it '
        'lets go', (tester) async {
      installFakeNative(state: _compact);
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      await pumpShell(
        tester,
        searchShell(controller, nativeChrome: LiquidNativeChrome.off),
        padding: _compactPadding,
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      final editing = tester
          .widget<TextField>(find.byType(TextField))
          .controller!;
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'hoo',
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange(start: 0, end: 3),
        ),
      );
      await tester.pump();
      controller.text = 'phố';
      await tester.pump();
      expect(editing.text, 'hoo', reason: 'held while composing');

      await pumpShell(
        tester,
        searchShell(controller),
        padding: _compactPadding,
      );
      expect(find.byType(TextField), findsNothing, reason: 'native now');
      expect(
        FocusManager.instance.primaryFocus?.debugLabel,
        isNot('LiquidShell search'),
      );
      expect(editing.value.composing.isCollapsed, isTrue);
      expect(editing.text, 'phố', reason: 'the held app write is applied');
      expect(controller.value.composing, isFalse);
    });

    testWidgets('scene reconnect: the text is replayed after the resend', (
      tester,
    ) async {
      final (fake, _, _) = await _pump(tester);
      fake.emitNative(
        const LiquidNativeSearchTextChanged('hà', composing: false),
      );
      await tester.pump();
      fake.searchTexts.clear();
      final configs = fake.configs.length;
      // A reconnected scene reports its state, maybe the same one.
      fake.pushState(_compact);
      await tester.pumpAndSettle();
      expect(fake.configs.length, greaterThan(configs), reason: 'resent');
      expect(fake.searchTexts, ['hà']);
    });

    testWidgets('scene reconnect on another tab: replayed on entry', (
      tester,
    ) async {
      final (fake, _, _) = await _pump(tester);
      fake
        ..emitNative(
          const LiquidNativeSearchTextChanged('hà', composing: false),
        )
        ..emitNative(const LiquidNativeDestinationTapped(0));
      await tester.pumpAndSettle();
      fake.searchTexts.clear();
      fake.pushState(_compact);
      await tester.pumpAndSettle();
      expect(fake.searchTexts, isEmpty);
      fake.emitNative(const LiquidNativeDestinationTapped(2));
      await tester.pumpAndSettle();
      expect(fake.searchTexts, ['hà']);
    });

    testWidgets('I-2: a plain page above a LiquidPage in the tab: the stack '
        'empties (spec §8.4 rule 3), and comes back when it pops', (
      tester,
    ) async {
      final (fake, _, _) = await _pump(tester);
      await _pushDetail(tester);
      _searchNavigator.currentState!
          .push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Plain')),
            ),
          )
          .ignore();
      await tester.pumpAndSettle();
      expect(find.text('Plain'), findsOneWidget);
      expect(fake.last.tabs.last.pages, isEmpty);
      _searchNavigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(fake.last.tabs.last.pages.map((p) => p.title), [
        'Search',
        'Hồ Hoàn Kiếm',
      ]);
    });

    testWidgets('m-1: a replaced top page sends its offset (zero)', (
      tester,
    ) async {
      final (fake, _, _) = await _pump(tester);
      await _pushDetail(tester);
      _position(tester, 'Detail').jumpTo(300);
      await tester.pump();
      expect(fake.pageScrolls.last, (2, 300.0));
      _searchNavigator.currentState!
          .pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => const LiquidPage(
                title: 'Other',
                child: TestPage(label: 'Other'),
              ),
            ),
          )
          .ignore();
      await tester.pumpAndSettle();
      expect(fake.last.tabs.last.pages.map((p) => p.title), [
        'Search',
        'Other',
      ]);
      expect(fake.pageScrolls.last, (2, 0.0));
    });

    testWidgets('m-4: a guard that refuses the search tab keeps Home', (
      tester,
    ) async {
      final asked = <int>[];
      final (fake, _, _) = await _pump(
        tester,
        initialIndex: 0,
        guard: (i) async {
          asked.add(i);
          return false;
        },
      );
      final sent = fake.configs.length;
      fake.emitNative(const LiquidNativeDestinationTapped(2));
      await tester.pumpAndSettle();
      expect(asked, [2]);
      expect(fake.configs.length, greaterThan(sent), reason: 'forced resync');
      expect(fake.last.selectedIndex, 0);
      expect(fake.searchTexts, isEmpty);
      expect(_scope(tester, 'Home').searchPhase, LiquidSearchPhase.idle);
    });

    testWidgets('C1: a page above the shell deactivates an active search', (
      tester,
    ) async {
      final (fake, controller, _) = await _pump(tester);
      fake.emitNative(const LiquidNativeSearchActiveChanged(true));
      await tester.pump();
      Navigator.of(
            tester.element(find.byKey(const ValueKey('list-Search'))),
            rootNavigator: true,
          )
          .push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Above')),
            ),
          )
          .ignore();
      await tester.pumpAndSettle();
      expect(fake.searchActives, [false]);
      expect(controller.text, '', reason: 'the text is kept (none here)');
    });
  });
  group('re-review fixes', () {
    const regular = LiquidNativeShellState(installed: true);

    testWidgets("N-2: a size-class report never sends the user's own text "
        'back (Telex one-way rule)', (tester) async {
      final (fake, _, _) = await _pump(tester);
      fake
        ..emitNative(const LiquidNativeSearchActiveChanged(true))
        ..emitNative(
          const LiquidNativeSearchTextChanged('hồ', composing: false),
        );
      await tester.pump();
      // A live controller reports only a changed state (iPad: the window
      // crossed the size class) while the user may still be typing.
      fake.pushState(regular);
      await tester.pumpAndSettle();
      expect(fake.searchTexts, isEmpty);
      fake.pushState(_compact);
      await tester.pumpAndSettle();
      expect(fake.searchTexts, isEmpty);
    });

    testWidgets('N-2: a changed state report still replays an app-set text', (
      tester,
    ) async {
      final (fake, controller, _) = await _pump(tester);
      fake.emitNative(
        const LiquidNativeSearchTextChanged('hồ', composing: false),
      );
      await tester.pump();
      // The app's write replaces the user's text: that one is replayed.
      controller.text = 'hà';
      await tester.pump();
      fake.searchTexts.clear();
      fake.pushState(regular);
      await tester.pumpAndSettle();
      expect(fake.searchTexts, ['hà']);
    });

    testWidgets('N-1: a query cleared while native chrome is off reaches '
        'native when it is back', (tester) async {
      final fake = installFakeNative(state: _compact);
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      Widget shell(LiquidNativeChrome mode) => TestShell(
        destinations: _destinations,
        initialIndex: 2,
        pageBuilder: _page,
        nativeChrome: mode,
        search: LiquidSearch(controller: controller),
      );
      await pumpShell(
        tester,
        shell(LiquidNativeChrome.auto),
        padding: _compactPadding,
      );
      fake.emitNative(
        const LiquidNativeSearchTextChanged('hà', composing: false),
      );
      await tester.pump();
      await pumpShell(
        tester,
        shell(LiquidNativeChrome.off),
        padding: _compactPadding,
      );
      controller.text = '';
      await tester.pump();
      fake.searchTexts.clear();
      await pumpShell(
        tester,
        shell(LiquidNativeChrome.auto),
        padding: _compactPadding,
      );
      expect(fake.searchTexts, ['']);
    });

    testWidgets("N-3: a root page in the shell's own route keeps the stack "
        'under a page above the shell', (tester) async {
      final (fake, _, _) = await _pump(
        tester,
        pageBuilder: (index) => index == 2
            ? const LiquidPage(
                title: 'Find',
                child: TestPage(label: 'Search'),
              )
            : _page(index),
      );
      expect(fake.last.tabs.last.pages.map((p) => p.title), ['Find']);
      final from = fake.configs.length;
      final root = Navigator.of(
        tester.element(find.byKey(const ValueKey('list-Search'))),
      );
      root
          .push(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Above')),
            ),
          )
          .ignore();
      await tester.pumpAndSettle();
      root.pop();
      await tester.pumpAndSettle();
      expect(_searchStacks(fake, from), isNotEmpty);
      expect(_searchStacks(fake, from), everyElement(['Find']));
    });
  });
}
