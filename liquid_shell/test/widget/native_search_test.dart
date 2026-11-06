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
  // The first native entry replays the (empty) text (spec §7.10) and
  // tells native the search is inactive; the tests below are about what
  // happens after it.
  if (settle) {
    fake.searchTexts.clear();
    fake.searchActives.clear();
  }
  return (fake, controller, changes);
}

/// A shell on [_page] driving [controller], native chrome per [nativeChrome].
Widget _searchShell(
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
    (tester) async {
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
    expect(fake.searchActives, [false], reason: 'the first native entry');
    fake.searchActives.clear();
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

  // VK-594, measured on an iPhone 17 Pro, iOS 26.5: in landscape the
  // keyboard lifts the field into the upper half of the view. The page's
  // padding still clears the field and the keyboard below it.
  testWidgets('landscape: the raised field still moves the bottom inset', (
    tester,
  ) async {
    final fake = installFakeNative(state: _compact);
    final controller = LiquidSearchController();
    addTearDown(controller.dispose);
    await pumpShell(
      tester,
      _searchShell(controller),
      size: const Size(874, 402),
      padding: const EdgeInsets.fromLTRB(62, 68, 62, 64),
    );
    // The keyboard is up: Flutter's padding loses the bottom safe area.
    tester.view
      ..viewInsets = const FakeViewPadding(bottom: 208)
      ..padding = const FakeViewPadding(left: 62, top: 68, right: 62);
    fake
      ..emitNative(const LiquidNativeSearchActiveChanged(true))
      ..emitNative(
        const LiquidNativeSearchFieldChanged(Rect.fromLTWH(80, 142, 662, 44)),
      );
    await tester.pump();
    final page = tester.element(find.byKey(const ValueKey('list-Search')));
    // max(402 − 142, 208 + 44 + 16), as portrait's.
    expect(LiquidShellScope.contentPaddingOf(page).bottom, 268);
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

  /// Pushes [titles] as LiquidPages in the search tab; [guarded] refuses to
  /// pop (PopScope).
  Future<void> pushPages(
    WidgetTester tester,
    List<String> titles, {
    String? guarded,
  }) async {
    for (final title in titles) {
      final page = LiquidPage(
        title: title,
        child: TestPage(label: title),
      );
      _searchNavigator.currentState!
          .push(
            MaterialPageRoute<void>(
              builder: (_) => title == guarded
                  ? PopScope(canPop: false, child: page)
                  : page,
            ),
          )
          .ignore();
      await tester.pumpAndSettle();
    }
  }

  List<String> pages(FakeNativePlatform fake) =>
      fake.last.tabs.last.pages.map((p) => p.title).toList();

  testWidgets('a native pop to the root (the back menu) pops every page '
      'above it', (tester) async {
    final (fake, _, _) = await _pump(tester);
    await pushPages(tester, ['A', 'B']);
    expect(pages(fake), ['Search', 'A', 'B']);
    fake.emitNative(const LiquidNativePopToPage(2, index: 0));
    await tester.pumpAndSettle();
    expect(pages(fake), ['Search']);
    expect(find.byKey(const ValueKey('list-A')), findsNothing);
  });

  testWidgets('a native pop to the previous page pops one page', (
    tester,
  ) async {
    final (fake, _, _) = await _pump(tester);
    await pushPages(tester, ['A', 'B']);
    fake.emitNative(const LiquidNativePopToPage(2, index: 1));
    await tester.pumpAndSettle();
    expect(pages(fake), ['Search', 'A']);
  });

  testWidgets('a native pop-to stops at a page that refuses to pop', (
    tester,
  ) async {
    final (fake, _, _) = await _pump(tester);
    await pushPages(tester, ['A', 'Form', 'B'], guarded: 'Form');
    fake.emitNative(const LiquidNativePopToPage(2, index: 0));
    await tester.pumpAndSettle();
    expect(pages(fake), ['Search', 'A', 'Form']);
  });

  testWidgets('a native pop-to for another tab, the top page or out of '
      'range is dropped', (tester) async {
    final (fake, _, _) = await _pump(tester);
    await pushPages(tester, ['A']);
    for (final event in const [
      LiquidNativePopToPage(0, index: 0),
      LiquidNativePopToPage(2, index: 1),
      LiquidNativePopToPage(2, index: 5),
      LiquidNativePopToPage(2, index: -1),
    ]) {
      fake.emitNative(event);
      await tester.pumpAndSettle();
      expect(pages(fake), ['Search', 'A'], reason: '$event');
    }
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
  // and never read, so it could not fail (review I-3). P3b-2: every tab has
  // a native bar; Home's is hidden (no pages), so native reports the real
  // cluster, and Dart passes it on.
  testWidgets('every tab has a native bar; the search tab has no controls', (
    tester,
  ) async {
    const controls = LiquidWindowControls(leading: 66, top: 24);
    final (fake, _, _) = await _pump(tester, initialIndex: 0);
    fake.emitNative(const LiquidWindowControlsChanged(controls));
    await tester.pump();
    expect(_scope(tester, 'Home').nativePageBar, isTrue);
    expect(
      _scope(tester, 'Home').windowControls,
      controls,
      reason: "Home's bar is hidden: native's report is the page's to clear",
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
      fake.searchActives.clear();
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
      fake.searchActives.clear();
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

    // P3b-2: an engaged shell draws no Flutter page bar on any tab; one
    // still waiting for the platform does, with the shell's strings.
    testWidgets('a pending native shell gives a Flutter page bar the '
        'strings', (tester) async {
      installFakeNative(state: _compact).attachGate =
          Completer<LiquidNativeShellState>();
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
      expect(scopeOf(tester).nativePageBar, isFalse, reason: 'pending');
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

    testWidgets(
      'no minimize offsets while the search tab is selected (VK-600 Q5)',
      (tester) async {
        final (native, _, _) = await _pump(tester); // initialIndex 2: search
        await tester.drag(
          find.byKey(const ValueKey('list-Search')),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
        expect(native.minimizeScrolls, isEmpty);
      },
    );

    // P3b-2: every tab has a native bar, so Home's top page sends too.
    testWidgets("every tab's top page sends its offset; a covered page "
        'sends nothing', (tester) async {
      final (fake, _, _) = await _pump(
        tester,
        initialIndex: 0,
        pageBuilder: _homeLiquidPage,
      );
      fake.pageScrolls.clear();
      _position(tester, 'Home').jumpTo(200);
      await tester.pump();
      await tester.pump();
      expect(fake.pageScrolls, [(0, 200.0)], reason: 'Home has a native bar');

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
    testWidgets('I-1: the text reaches native once it engages (cold start)', (
      tester,
    ) async {
      final fake = installFakeNative(state: _compact)
        ..attachGate = Completer<LiquidNativeShellState>();
      final controller = LiquidSearchController(text: 'hồ');
      addTearDown(controller.dispose);
      await pumpShell(
        tester,
        _searchShell(controller),
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
        _searchShell(controller),
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
        _searchShell(controller),
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
        _searchShell(controller),
        padding: _compactPadding,
      );
      fake.emitNative(
        const LiquidNativeSearchTextChanged('hà', composing: false),
      );
      await tester.pump();
      await pumpShell(
        tester,
        _searchShell(controller, nativeChrome: LiquidNativeChrome.off),
        padding: _compactPadding,
      );
      fake.searchTexts.clear();
      await pumpShell(
        tester,
        _searchShell(controller),
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
        _searchShell(controller, nativeChrome: LiquidNativeChrome.off),
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
        _searchShell(controller),
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

  group('integration carry-overs (Task 11)', () {
    testWidgets('N-4: a replacing page without a scroll view sends zero: '
        'the reused native host drops the old offset', (tester) async {
      final (fake, _, _) = await _pump(tester);
      await _pushDetail(tester);
      _position(tester, 'Detail').jumpTo(300);
      await tester.pump();
      expect(fake.pageScrolls.last, (2, 300.0));
      _searchNavigator.currentState!
          .pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) =>
                  const LiquidPage(title: 'Plain', child: Text('No scroll')),
            ),
          )
          .ignore();
      await tester.pumpAndSettle();
      expect(fake.last.tabs.last.pages.map((p) => p.title), [
        'Search',
        'Plain',
      ]);
      expect(fake.pageScrolls.last, (2, 0.0));
    });

    testWidgets('N-4: a page whose scroll view reports late still sends its '
        'own offset', (tester) async {
      final (fake, _, _) = await _pump(tester);
      await _pushDetail(tester);
      _position(tester, 'Detail').jumpTo(300);
      await tester.pump();
      fake.pageScrolls.clear();
      // The new page has no scroll view at first, then gets one.
      final show = ValueNotifier(false);
      addTearDown(show.dispose);
      _searchNavigator.currentState!
          .pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => LiquidPage(
                title: 'Late',
                child: ValueListenableBuilder(
                  valueListenable: show,
                  builder: (_, shown, _) => shown
                      ? const TestPage(label: 'Late')
                      : const Text('Loading'),
                ),
              ),
            ),
          )
          .ignore();
      await tester.pumpAndSettle();
      show.value = true;
      await tester.pumpAndSettle();
      _position(tester, 'Late').jumpTo(120);
      await tester.pump();
      await tester.pump();
      expect(fake.pageScrolls.last, (2, 120.0));
    });

    testWidgets('N-5: the native back under a sheet in the tab closes the '
        'sheet, as its barrier does', (tester) async {
      final (fake, _, _) = await _pump(tester);
      await _pushDetail(tester);
      showModalBottomSheet<void>(
        context: tester.element(find.byKey(const ValueKey('list-Detail'))),
        builder: (_) => const SizedBox(height: 200, child: Text('Sheet')),
      ).ignore();
      await tester.pumpAndSettle();
      expect(find.text('Sheet'), findsOneWidget);
      expect(fake.last.interactive, isTrue, reason: 'the back is live');
      fake.emitNative(const LiquidNativeBackTapped(2));
      await tester.pumpAndSettle();
      expect(find.text('Sheet'), findsNothing);
      expect(find.byKey(const ValueKey('list-Detail')), findsOneWidget);
      expect(fake.last.tabs.last.pages.map((p) => p.title), [
        'Search',
        'Hồ Hoàn Kiếm',
      ]);
    });

    testWidgets('a native pop-to under a sheet in the tab ends at the sheet: '
        'no page pops', (tester) async {
      final (fake, _, _) = await _pump(tester);
      await pushPages(tester, ['A', 'B']);
      showModalBottomSheet<void>(
        context: tester.element(find.byKey(const ValueKey('list-B'))),
        builder: (_) => const SizedBox(height: 200, child: Text('Sheet')),
      ).ignore();
      await tester.pumpAndSettle();
      fake.emitNative(const LiquidNativePopToPage(2, index: 0));
      await tester.pumpAndSettle();
      expect(find.text('Sheet'), findsOneWidget);
      expect(pages(fake), ['Search', 'A', 'B']);
    });

    testWidgets('a native pop-to under a page above the shell pops nothing', (
      tester,
    ) async {
      final (fake, _, _) = await _pump(tester);
      await pushPages(tester, ['A', 'B']);
      final root = Navigator.of(
        tester.element(find.byKey(const ValueKey('list-B'))),
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
      fake.emitNative(const LiquidNativePopToPage(2, index: 0));
      await tester.pumpAndSettle();
      expect(find.text('Above'), findsOneWidget);
      root.pop();
      await tester.pumpAndSettle();
      expect(pages(fake), ['Search', 'A', 'B']);
    });

    testWidgets('N-5: a back tap under a page above the shell pops nothing '
        '(the chrome is not interactive there)', (tester) async {
      final (fake, _, _) = await _pump(tester);
      await _pushDetail(tester);
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
      expect(fake.last.interactive, isFalse);
      fake.emitNative(const LiquidNativeBackTapped(2));
      await tester.pumpAndSettle();
      expect(find.text('Above'), findsOneWidget);
      root.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('list-Detail')), findsOneWidget);
    });
  });

  group('final-review fixes', () {
    /// The Flutter field's text (the shell's fallback field).
    String fieldText(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).controller!.text;

    testWidgets('I-1: a lost install shows the native query in the Flutter '
        'field', (tester) async {
      final (fake, controller, _) = await _pump(tester);
      fake.emitNative(
        const LiquidNativeSearchTextChanged('Diễm xưa', composing: false),
      );
      await tester.pump();
      fake.pushState(const LiquidNativeShellState(installed: false));
      await tester.pumpAndSettle();
      expect(controller.text, 'Diễm xưa');
      expect(fieldText(tester), 'Diễm xưa');
    });

    testWidgets('I-1: native chrome turned off shows the native query in the '
        'Flutter field', (tester) async {
      final fake = installFakeNative(state: _compact);
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      await pumpShell(
        tester,
        _searchShell(controller),
        padding: _compactPadding,
      );
      fake.emitNative(
        const LiquidNativeSearchTextChanged('Diễm xưa', composing: false),
      );
      await tester.pump();
      await pumpShell(
        tester,
        _searchShell(controller, nativeChrome: LiquidNativeChrome.off),
        padding: _compactPadding,
      );
      expect(fieldText(tester), 'Diễm xưa');
    });

    testWidgets('I-1: an app write while native also reaches the Flutter '
        'field after the switch', (tester) async {
      final (fake, controller, _) = await _pump(tester);
      controller.text = 'phố cổ';
      await tester.pump();
      fake.pushState(const LiquidNativeShellState(installed: false));
      await tester.pumpAndSettle();
      expect(fieldText(tester), 'phố cổ');
    });

    testWidgets('Minor 3: a reconnected field starts inactive: Dart follows '
        'and tells native on entry', (tester) async {
      final (fake, controller, _) = await _pump(tester);
      fake.emitNative(const LiquidNativeSearchActiveChanged(true));
      await tester.pump();
      expect(controller.isActive, isTrue, reason: 'precondition');
      fake.searchActives.clear();
      // The same state again: a rebuilt native controller (spec §7.10).
      fake.pushState(_compact);
      await tester.pumpAndSettle();
      expect(controller.isActive, isFalse);
      expect(fake.searchActives, [false]);
    });

    testWidgets('Minor 3: the first native entry after an attach (a hot '
        'restart) tells native the search is inactive', (tester) async {
      final fake = installFakeNative(state: _compact);
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      await pumpShell(
        tester,
        _searchShell(controller),
        padding: _compactPadding,
      );
      expect(fake.searchActives, [false]);
      await tester.pumpAndSettle();
      expect(fake.searchActives, [false], reason: 'once');
    });

    testWidgets('Minor 3: an activation asked before the entry is not '
        'undone', (tester) async {
      final (fake, controller, _) = await _pump(tester);
      fake.pushState(_compact);
      controller.activate();
      await tester.pumpAndSettle();
      expect(fake.searchActives, [true]);
    });
  });

  group("VK-491: the search tab never shows another tab's pages", () {
    // Switching tabs, the shell computes the new tab's stack before the
    // pages of the old and the new branch hear that their visibility
    // changed: the old tab's page still says it is the one on screen.

    testWidgets('a native tap from Home sends only the search stack', (
      tester,
    ) async {
      final (fake, _, _) = await _pump(
        tester,
        initialIndex: 0,
        pageBuilder: _homeNavigatorPage,
      );
      final from = fake.configs.length;
      fake.emitNative(const LiquidNativeDestinationTapped(2));
      await tester.pumpAndSettle();
      expect(fake.last.selectedIndex, 2);
      expect(_searchStacks(fake, from), isNotEmpty);
      expect(_searchStacks(fake, from), everyElement(['Search']));
    });

    testWidgets('an app selection from Home sends only the search stack', (
      tester,
    ) async {
      final (fake, _, _) = await _pump(
        tester,
        initialIndex: 0,
        pageBuilder: _homeNavigatorPage,
      );
      final from = fake.configs.length;
      tester.state<TestShellState>(find.byType(TestShell)).select(2);
      await tester.pumpAndSettle();
      expect(fake.last.selectedIndex, 2);
      expect(_searchStacks(fake, from), isNotEmpty);
      expect(_searchStacks(fake, from), everyElement(['Search']));
    });

    testWidgets('back to a search tab with a pushed page: its whole stack, '
        'no pop and push again', (tester) async {
      final (fake, _, _) = await _pump(tester, pageBuilder: _homeNavigatorPage);
      await _pushDetail(tester);
      fake.emitNative(const LiquidNativeDestinationTapped(0));
      await tester.pumpAndSettle();
      expect(fake.last.selectedIndex, 0);
      final from = fake.configs.length;
      fake.emitNative(const LiquidNativeDestinationTapped(2));
      await tester.pumpAndSettle();
      expect(fake.last.selectedIndex, 2);
      expect(_searchStacks(fake, from), isNotEmpty);
      expect(
        _searchStacks(fake, from),
        everyElement(['Search', 'Hồ Hoàn Kiếm']),
      );
    });

    testWidgets("Home as a page of the shell's own route: only the search "
        'stack', (tester) async {
      final (fake, _, _) = await _pump(
        tester,
        initialIndex: 0,
        pageBuilder: _homeLiquidPage,
      );
      final from = fake.configs.length;
      fake.emitNative(const LiquidNativeDestinationTapped(2));
      await tester.pumpAndSettle();
      expect(fake.last.selectedIndex, 2);
      expect(_searchStacks(fake, from), isNotEmpty);
      expect(_searchStacks(fake, from), everyElement(['Search']));
    });

    testWidgets('a pop while the search tab is away: the return sends the '
        'shorter stack, never the kept one', (tester) async {
      final (fake, _, _) = await _pump(tester, pageBuilder: _homeNavigatorPage);
      await _pushDetail(tester);
      fake.emitNative(const LiquidNativeDestinationTapped(0));
      await tester.pumpAndSettle();
      _searchNavigator.currentState!.pop();
      await tester.pumpAndSettle();
      final from = fake.configs.length;
      fake.emitNative(const LiquidNativeDestinationTapped(2));
      await tester.pumpAndSettle();
      expect(fake.last.selectedIndex, 2);
      expect(_searchStacks(fake, from), everyElement(['Search']));
    });

    testWidgets('a push while the search tab is away: the return sends the '
        'longer stack', (tester) async {
      final (fake, _, _) = await _pump(tester, pageBuilder: _homeNavigatorPage);
      fake.emitNative(const LiquidNativeDestinationTapped(0));
      await tester.pumpAndSettle();
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
      final from = fake.configs.length;
      fake.emitNative(const LiquidNativeDestinationTapped(2));
      await tester.pumpAndSettle();
      expect(fake.last.selectedIndex, 2);
      expect(_searchStacks(fake, from), isNotEmpty);
      expect(
        _searchStacks(fake, from),
        everyElement(['Search', 'Hồ Hoàn Kiếm']),
      );
    });
  });

  group('VK-502: a tab keeps its pages while offstage', () {
    // iPhone; iPad at regular width (top bar); iPad at compact width (a
    // narrow window: UIKit's compact bar). Branches kept alive by an
    // IndexedStack (Visibility) or, as a router's shell route does, by
    // Offstage + TickerMode.
    const forms = [
      ('iPhone', _compact, kPhone, _compactPadding),
      (
        'iPad regular',
        LiquidNativeShellState(installed: true),
        kTabletLandscape,
        EdgeInsets.only(top: 74, bottom: 20),
      ),
      ('iPad narrow', _compact, Size(375, 1194), _compactPadding),
    ];
    for (final (form, state, size, padding) in forms) {
      for (final offstage in [false, true]) {
        final branches = offstage ? 'Offstage branches' : 'an IndexedStack';
        testWidgets('$form, $branches: away and back, every config keeps the '
            'search stack', (tester) async {
          final fake = installFakeNative(state: state);
          final controller = LiquidSearchController();
          addTearDown(controller.dispose);
          await pumpShell(
            tester,
            TestShell(
              destinations: _destinations,
              initialIndex: 2,
              pageBuilder: _homeNavigatorPage,
              offstageBranches: offstage,
              search: LiquidSearch(controller: controller),
            ),
            size: size,
            padding: padding,
          );
          await _pushDetail(tester);
          expect(fake.last.tabs.last.pages.map((p) => p.title), [
            'Search',
            'Hồ Hoàn Kiếm',
          ]);
          final from = fake.configs.length;
          fake.emitNative(const LiquidNativeDestinationTapped(0));
          await tester.pumpAndSettle();
          expect(fake.last.selectedIndex, 0);
          fake.emitNative(const LiquidNativeDestinationTapped(2));
          await tester.pumpAndSettle();
          expect(fake.last.selectedIndex, 2);
          expect(_searchStacks(fake, from), isNotEmpty);
          expect(
            _searchStacks(fake, from),
            everyElement(['Search', 'Hồ Hoàn Kiếm']),
          );
        });
      }
    }
  });

  group('VK-551: an edge swipe while the native search is active', () {
    final outer = GlobalKey<NavigatorState>();

    /// The shell as a page above a list, as the example's case list pushes
    /// it: its search root has nothing to pop, so an edge swipe there
    /// would pop the shell.
    Widget aboveAList(Widget shell) => Navigator(
      key: outer,
      onGenerateInitialRoutes: (_, _) => [
        MaterialPageRoute<void>(builder: (_) => const Text('The list')),
        MaterialPageRoute<void>(builder: (_) => shell),
      ],
    );

    Future<(FakeNativePlatform, LiquidSearchController)> pumpAbove(
      WidgetTester tester, {
      bool active = true,
    }) async {
      final fake = installFakeNative(state: _compact);
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      await pumpShell(
        tester,
        aboveAList(_searchShell(controller)),
        padding: _compactPadding,
      );
      if (active) {
        fake.emitNative(const LiquidNativeSearchActiveChanged(true));
        await tester.pump();
      }
      fake.searchActives.clear();
      return (fake, controller);
    }

    Future<void> swipeFromTheEdge(WidgetTester tester) async {
      await tester.dragFrom(const Offset(2, 400), const Offset(300, 0));
      await tester.pumpAndSettle();
    }

    // While the search is active the shell's route stays, as in the
    // Flutter field (spec P3b §9.4). Popping it left UIKit's search
    // active, its field first responder under the hidden chrome: the
    // keyboard stayed with nothing to dismiss it.
    testWidgets('off the search root: the shell stays, the search too', (
      tester,
    ) async {
      final (fake, controller) = await pumpAbove(tester);
      await swipeFromTheEdge(tester);
      expect(find.text('The list'), findsNothing);
      expect(fake.last.tabs, isNotEmpty, reason: 'not dormant');
      expect(controller.isActive, isTrue);
      expect(fake.searchActives, isEmpty);
    });

    testWidgets('system back deactivates the search, then pops', (
      tester,
    ) async {
      final (fake, _) = await pumpAbove(tester);
      await outer.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('The list'), findsNothing);
      expect(fake.searchActives, [false]);
      fake.emitNative(const LiquidNativeSearchActiveChanged(false));
      await tester.pump();
      await outer.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('The list'), findsOneWidget);
    });

    testWidgets('inactive: the edge swipe pops the shell', (tester) async {
      final (fake, _) = await pumpAbove(tester, active: false);
      await swipeFromTheEdge(tester);
      expect(find.text('The list'), findsOneWidget);
      expect(fake.last.tabs, isEmpty, reason: 'dormant');
    });

    // Apple Music: an edge swipe on a pushed page pops that page. The
    // shell's route, hit first, took the swipe and popped the whole shell.
    testWidgets('a page pushed in the search tab: the swipe pops that page, '
        'the search stays active', (tester) async {
      final (fake, controller) = await pumpAbove(tester);
      await _pushDetail(tester);
      await swipeFromTheEdge(tester);
      expect(find.text('The list'), findsNothing);
      expect(fake.last.tabs.last.pages.map((p) => p.title), ['Search']);
      expect(controller.isActive, isTrue);
      expect(fake.searchActives, isEmpty);
    });
  });

  // VK-571: a drag on the results, or a scope tap, puts UIKit's keyboard
  // away and keeps its search: the field resigns first responder, the
  // search stays active with its text and Cancel. Never an `isActive`
  // change, never a text write.
  group('VK-571: the keyboard goes, the search stays', () {
    Future<(FakeNativePlatform, LiquidSearchController)> active(
      WidgetTester tester, {
      Widget Function(int index) pageBuilder = _page,
      bool dismissKeyboardOnDrag = true,
      LiquidSearchController? search,
    }) async {
      final fake = installFakeNative(state: _compact);
      final controller = search ?? LiquidSearchController();
      addTearDown(controller.dispose);
      await pumpShell(
        tester,
        TestShell(
          destinations: _destinations,
          initialIndex: 2,
          pageBuilder: pageBuilder,
          search: LiquidSearch(
            controller: controller,
            dismissKeyboardOnDrag: dismissKeyboardOnDrag,
          ),
        ),
        padding: _compactPadding,
      );
      fake
        ..emitNative(const LiquidNativeSearchActiveChanged(true))
        ..emitNative(
          const LiquidNativeSearchTextChanged('hồ', composing: false),
        );
      await tester.pump();
      fake.searchTexts.clear();
      fake.searchActives.clear();
      return (fake, controller);
    }

    void expectSearchKept(
      WidgetTester tester,
      FakeNativePlatform fake,
      LiquidSearchController controller, {
      String page = 'Search',
    }) {
      expect(fake.searchActives, isEmpty, reason: 'isActive untouched');
      expect(fake.searchTexts, isEmpty, reason: 'no write (Telex)');
      expect(controller.text, 'hồ');
      expect(controller.isActive, isTrue);
      expect(_scope(tester, page).searchPhase, LiquidSearchPhase.active);
    }

    Future<void> dragResults(WidgetTester tester) async {
      await tester.drag(
        find.byKey(const ValueKey('list-Search')),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('dismissKeyboard asks native once, the search stays', (
      tester,
    ) async {
      final (fake, controller) = await active(tester);
      controller.dismissKeyboard();
      await tester.pump();
      expect(fake.searchKeyboardDismissals, 1);
      expectSearchKept(tester, fake, controller);
    });

    testWidgets('inactive: dismissKeyboard sends nothing', (tester) async {
      final (fake, controller, _) = await _pump(tester);
      controller.dismissKeyboard();
      await tester.pump();
      expect(fake.searchKeyboardDismissals, 0);
    });

    testWidgets('a user drag on the results: one dismissal per drag', (
      tester,
    ) async {
      final (fake, controller) = await active(tester);
      await dragResults(tester);
      expect(fake.searchKeyboardDismissals, 1);
      expectSearchKept(tester, fake, controller);
      await dragResults(tester);
      expect(fake.searchKeyboardDismissals, 2);
    });

    testWidgets('a programmatic scroll sends nothing', (tester) async {
      final (fake, _) = await active(tester);
      final position = _position(tester, 'Search')..jumpTo(160);
      await tester.pump();
      unawaited(
        position.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.linear,
        ),
      );
      await tester.pumpAndSettle();
      expect(position.pixels, 0);
      expect(fake.searchKeyboardDismissals, 0);
    });

    // VK-551's edge swipe: over the vertical list it wins the arena alone
    // and starts a drag there. A thumb drifts, so the list may scroll a
    // little; a drag mostly across the list's axis is not a scroll of the
    // results and keeps the keyboard.
    for (final (name, drift) in [('flat', 0.0), ('drifting', 24.0)]) {
      testWidgets('a near-horizontal edge swipe ($name) sends nothing', (
        tester,
      ) async {
        final (fake, controller) = await active(tester);
        await tester.dragFrom(const Offset(2, 400), Offset(300, drift));
        await tester.pumpAndSettle();
        expect(fake.searchKeyboardDismissals, 0);
        expect(controller.isActive, isTrue);
      });
    }

    testWidgets('a mostly vertical drag with some sideways drift dismisses', (
      tester,
    ) async {
      final (fake, _) = await active(tester);
      await tester.drag(
        find.byKey(const ValueKey('list-Search')),
        const Offset(40, -200),
      );
      await tester.pumpAndSettle();
      expect(fake.searchKeyboardDismissals, 1);
    });

    testWidgets('a scope tap selects it and dismisses the keyboard', (
      tester,
    ) async {
      final controller = LiquidSearchController();
      final (fake, _) = await active(
        tester,
        search: controller,
        pageBuilder: _withSearchRoot(
          () => Builder(
            builder: (context) => ListView(
              key: const ValueKey('list-Scopes'),
              padding: LiquidShellScope.contentPaddingOf(context),
              children: [
                LiquidSearchScopeBar(
                  controller: controller,
                  scopes: const ['All', 'Songs', 'Places'],
                ),
              ],
            ),
          ),
        ),
      );
      // The segment's node takes the touch (VK-550: the label is drawn
      // once per weight).
      await tester.tap(find.bySemanticsLabel('Songs'));
      await tester.pump();
      expect(controller.scopeIndex, 1);
      expect(fake.searchKeyboardDismissals, 1);
      expectSearchKept(tester, fake, controller, page: 'Scopes');
    });

    testWidgets('dismissKeyboardOnDrag: false sends nothing on a drag', (
      tester,
    ) async {
      final (fake, _) = await active(tester, dismissKeyboardOnDrag: false);
      await dragResults(tester);
      expect(fake.searchKeyboardDismissals, 0);
    });

    testWidgets('a drag on another tab sends nothing', (tester) async {
      final (fake, _) = await active(tester);
      fake.emitNative(const LiquidNativeDestinationTapped(0));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('list-Home')),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(fake.searchKeyboardDismissals, 0);
    });
  });

  // VK-550 §10: the native scope bar. Native chrome draws the scopes the app
  // gives LiquidSearch.scopes; Flutter's LiquidSearchScopeBar then builds
  // nothing. The bridge is one-way: native reports the user's changes,
  // Dart sends the app's.
  group('VK-550: the native scope bar', () {
    const scopes = ['All', 'Songs', 'Places'];

    /// [gate]: native has not answered yet (pending) until it completes.
    Future<(FakeNativePlatform, LiquidSearchController)> scoped(
      WidgetTester tester, {
      List<String>? titles = scopes,
      int initialIndex = 2,
      Completer<LiquidNativeShellState>? gate,
    }) async {
      final fake = installFakeNative(state: _compact)..attachGate = gate;
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      await pumpShell(
        tester,
        TestShell(
          destinations: _destinations,
          initialIndex: initialIndex,
          pageBuilder: _withSearchRoot(
            () => ListView(
              key: const ValueKey('list-Scopes'),
              children: [
                LiquidSearchScopeBar(controller: controller, scopes: scopes),
              ],
            ),
          ),
          search: LiquidSearch(controller: controller, scopes: titles),
        ),
        padding: _compactPadding,
        settle: gate == null,
      );
      return (fake, controller);
    }

    // Task 10 review M3: while native has not answered (pending) or another
    // shell owns it (standby), the shell draws no chrome; its page must not
    // draw the scope bar either, or the bar shows and then vanishes (a
    // jump of the results) when native engages.
    testWidgets('pending: Flutter draws no scope bar before native answers', (
      tester,
    ) async {
      final gate = Completer<LiquidNativeShellState>();
      await scoped(tester, gate: gate);
      await tester.pump();
      expect(_scope(tester, 'Scopes').chromeKind, LiquidChromeKind.hidden);
      expect(_scope(tester, 'Scopes').nativeSearchScopes, isTrue);
      expect(find.byType(LiquidSegmentedControl), findsNothing);

      gate.complete(_compact);
      await tester.pumpAndSettle();
      expect(_scope(tester, 'Scopes').nativeChrome, isTrue);
      expect(find.byType(LiquidSegmentedControl), findsNothing);
    });

    testWidgets('pending, then not installed: Flutter draws the scope bar', (
      tester,
    ) async {
      final gate = Completer<LiquidNativeShellState>();
      await scoped(tester, gate: gate);
      await tester.pump();
      gate.complete(
        const LiquidNativeShellState(
          installed: false,
          unavailableReason: LiquidNativeUnavailableReason.notEnabled,
        ),
      );
      await tester.pumpAndSettle();
      expect(_scope(tester, 'Scopes').nativeSearchScopes, isFalse);
      expect(find.byType(LiquidSegmentedControl), findsOneWidget);
    });

    testWidgets('standby: no scope bar while a shell pushed above owns the '
        'chrome', (tester) async {
      await scoped(tester);
      final page = find.byKey(const ValueKey('list-Scopes'));
      Navigator.of(tester.element(page), rootNavigator: true)
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
      // Mid-push the first shell is on screen without the chrome.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_scope(tester, 'Scopes').nativeChrome, isFalse);
      expect(_scope(tester, 'Scopes').nativeSearchScopes, isTrue);
      expect(find.byType(LiquidSegmentedControl), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('the config carries the scopes; Flutter draws no scope bar', (
      tester,
    ) async {
      final (fake, _) = await scoped(tester);
      expect(fake.last.search?.scopes, scopes);
      expect(_scope(tester, 'Scopes').nativeSearchScopes, isTrue);
      expect(find.byType(LiquidSegmentedControl), findsNothing);
    });

    testWidgets('without scopes native draws none', (tester) async {
      final (fake, controller) = await scoped(tester, titles: null);
      expect(fake.last.search?.scopes, isNull);
      expect(_scope(tester, 'Scopes').nativeSearchScopes, isFalse);
      // The app's own bar, without LiquidSearch.scopes: Flutter draws it.
      expect(find.byType(LiquidSegmentedControl), findsOneWidget);
      expect(controller.scopeIndex, 0);
    });

    testWidgets('a user change reaches the controller; an app write goes '
        'to native once', (tester) async {
      final (fake, controller) = await scoped(tester);
      fake.searchScopes.clear();
      fake.emitNative(const LiquidNativeSearchScopeChanged(1));
      await tester.pump();
      expect(controller.scopeIndex, 1);
      expect(fake.searchScopes, isEmpty, reason: 'never echoed');
      controller.scopeIndex = 2;
      await tester.pump();
      expect(fake.searchScopes, [2]);
    });

    testWidgets('entering the search tab sends the scope', (tester) async {
      final (fake, controller) = await scoped(tester, initialIndex: 0);
      controller.scopeIndex = 2;
      await tester.pump();
      expect(fake.searchScopes, isEmpty, reason: 'another tab is selected');
      fake.emitNative(const LiquidNativeDestinationTapped(2));
      await tester.pumpAndSettle();
      expect(fake.searchScopes, [2]);
    });

    /// The search tab with [titles] as `LiquidSearch.scopes`; its page's
    /// bar reads them from the shell. Pump it again to change them.
    Future<void> titled(
      WidgetTester tester,
      LiquidSearchController controller,
      List<String> titles,
    ) => pumpShell(
      tester,
      TestShell(
        destinations: _destinations,
        initialIndex: 2,
        pageBuilder: _withSearchRoot(
          () => ListView(
            key: const ValueKey('list-Scopes'),
            children: [LiquidSearchScopeBar(controller: controller)],
          ),
        ),
        search: LiquidSearch(controller: controller, scopes: titles),
      ),
      padding: _compactPadding,
    );

    // VK-604 (VK-550 review C9): the app changes its scopes at run time.
    testWidgets('scopes changed at run time reach native; Flutter draws no '
        'bar', (tester) async {
      final fake = installFakeNative(state: _compact);
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      await titled(tester, controller, scopes);
      expect(fake.last.search?.scopes, scopes);
      await titled(tester, controller, const ['All', 'Songs']);
      expect(fake.last.search?.scopes, ['All', 'Songs']);
      expect(_scope(tester, 'Scopes').searchScopes, ['All', 'Songs']);
      expect(_scope(tester, 'Scopes').nativeSearchScopes, isTrue);
      expect(find.byType(LiquidSegmentedControl), findsNothing);
    });

    // VK-604 (VK-550 review C1): a user tap on the old last scope, still in
    // flight when the app shortened the titles. Dart ignores the index;
    // native's bar showed the tap and clamps it to the new titles. Dart
    // sends its own scope back, once.
    testWidgets('a native index past the new titles: native gets the '
        "controller's scope back, once", (tester) async {
      final fake = installFakeNative(state: _compact);
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      await titled(tester, controller, scopes);
      await titled(tester, controller, const ['All', 'Songs']);
      fake.searchScopes.clear();
      fake.emitNative(const LiquidNativeSearchScopeChanged(2));
      await tester.pump();
      expect(controller.scopeIndex, 0, reason: 'ignored');
      expect(fake.searchScopes, [0]);
    });
  });

  // VK-572 bug A. A dismissal Dart asks for (deactivate, another tab, a
  // dialog above, hidden chrome) or a reconnected scene ends the native
  // search mid-composition. The field resigns, which commits the marked
  // text, and native reports only `searchActive false`: it swallows that
  // commit while it keeps the text (RunnerTests, VK-572). Natively the
  // composition ends with the search, the text kept, and onChanged is not
  // called: the text did not change.
  group('VK-572: the native composition ends with the search', () {
    Future<(FakeNativePlatform, LiquidSearchController, List<String>)>
    composing(WidgetTester tester) async {
      final (fake, controller, changes) = await _pump(tester);
      fake
        ..emitNative(const LiquidNativeSearchActiveChanged(true))
        ..emitNative(
          const LiquidNativeSearchTextChanged('かな', composing: true),
        );
      await tester.pump();
      expect(controller.value.composing, isTrue, reason: 'precondition');
      changes.clear();
      return (fake, controller, changes);
    }

    void expectEnded(LiquidSearchController controller, List<String> changes) {
      expect(controller.isActive, isFalse);
      expect(controller.text, 'かな', reason: 'the composed text is kept');
      expect(controller.value.composing, isFalse);
      expect(changes, isEmpty, reason: 'the text did not change');
    }

    testWidgets('A1: deactivate(): native answers inactive only', (
      tester,
    ) async {
      final (fake, controller, changes) = await composing(tester);
      controller.deactivate();
      await tester.pump();
      expect(fake.searchActives, [false]);
      fake.emitNative(const LiquidNativeSearchActiveChanged(false));
      await tester.pump();
      expectEnded(controller, changes);
    });

    // doc/search.md: "check `composing` before writing". Before VK-572 such
    // an app held its write although no composition was open.
    testWidgets('A3: an app write that checks composing lands', (
      tester,
    ) async {
      final (fake, controller, _) = await composing(tester);
      controller.deactivate();
      fake.emitNative(const LiquidNativeSearchActiveChanged(false));
      await tester.pump();
      fake.searchTexts.clear();
      // A recent search tapped, written only outside a composition.
      if (!controller.value.composing) controller.text = 'phở';
      await tester.pump();
      expect(fake.searchTexts, ['phở']);
    });

    // Dart ends the search when the tab is left, before native's report:
    // the composition ends then too. Native cannot report it on this path
    // (the search tab is no longer selected), and Dart would drop it.
    testWidgets('A2, A4: the user taps another tab mid-composition', (
      tester,
    ) async {
      final (fake, controller, changes) = await composing(tester);
      fake.emitNative(const LiquidNativeDestinationTapped(0));
      await tester.pumpAndSettle();
      expectEnded(controller, changes);
      fake.emitNative(const LiquidNativeSearchActiveChanged(false));
      await tester.pump();
      expectEnded(controller, changes);
      fake.emitNative(const LiquidNativeDestinationTapped(2));
      await tester.pumpAndSettle();
      expectEnded(controller, changes);
    });

    testWidgets('A5: a scene reconnect mid-composition', (tester) async {
      final (fake, controller, changes) = await composing(tester);
      fake.pushState(_compact);
      await tester.pumpAndSettle();
      expectEnded(controller, changes);
    });

    testWidgets('R1: an active search keeps its composition', (tester) async {
      final (fake, controller, _) = await composing(tester);
      fake.emitNative(const LiquidNativeSearchActiveChanged(true));
      await tester.pump();
      expect(controller.isActive, isTrue);
      expect(controller.value.composing, isTrue);
    });

    // The end native reports itself (the VK-571 resign re-reads the field)
    // is a user edit, as before: onChanged hears it.
    testWidgets('R2: a composition end native reports still calls onChanged', (
      tester,
    ) async {
      final (fake, controller, changes) = await composing(tester);
      fake.emitNative(
        const LiquidNativeSearchTextChanged('かな', composing: false),
      );
      await tester.pump();
      expect(controller.value.composing, isFalse);
      expect(changes, ['かな']);
    });

    // Flutter chrome under the shell's claim (not installed): the Flutter
    // field ends its own composition when it lets go, and reports it.
    testWidgets('R3: Flutter mode: the field still reports its own end', (
      tester,
    ) async {
      installFakeNative(state: const LiquidNativeShellState(installed: false));
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      final changes = <String>[];
      await pumpShell(
        tester,
        TestShell(
          destinations: _destinations,
          initialIndex: 2,
          pageBuilder: _page,
          search: LiquidSearch(controller: controller, onChanged: changes.add),
        ),
        padding: _compactPadding,
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'かな',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump();
      expect(controller.value.composing, isTrue, reason: 'precondition');
      changes.clear();
      tester.state<TestShellState>(find.byType(TestShell)).select(0);
      await tester.pumpAndSettle();
      expect(controller.isActive, isFalse);
      expect(controller.value.composing, isFalse);
      expect(changes, ['かな'], reason: "the field's own end is reported");
    });
  });

  // VK-572 bug B (VK-571 review M-6, M-8). Native chrome engages while the
  // Flutter field holds the search: focused, keyboard-down (VK-571) or
  // composing. The shell releases the field (`holdsField`), and the Flutter
  // search ends there, its text kept, as Flutter mode ends it for hidden
  // chrome: native starts inactive and never answers a deactivate for an
  // inactive search (RunnerTests, VK-572).
  group('VK-572: native takes over a Flutter search', () {
    /// Flutter chrome first (`nativeChrome: off`), the field focused. The
    /// next build with `auto` claims native chrome through pending: the
    /// host has no state yet.
    Future<LiquidSearchController> viaPending(WidgetTester tester) async {
      installFakeNative(state: _compact);
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      await pumpShell(
        tester,
        _searchShell(controller, nativeChrome: LiquidNativeChrome.off),
        padding: _compactPadding,
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(controller.isActive, isTrue, reason: 'precondition: active');
      return controller;
    }

    /// auto, off, then the field focused: the host already knows the
    /// state, so the next build with `auto` engages at once.
    Future<LiquidSearchController> viaOff(WidgetTester tester) async {
      installFakeNative(state: _compact);
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      await pumpShell(
        tester,
        _searchShell(controller),
        padding: _compactPadding,
      );
      await pumpShell(
        tester,
        _searchShell(controller, nativeChrome: LiquidNativeChrome.off),
        padding: _compactPadding,
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(controller.isActive, isTrue, reason: 'precondition: active');
      return controller;
    }

    /// Not installed (Flutter chrome), the field focused; [installLate]
    /// then pushes `installed: true`, as a native install after the attach
    /// does.
    Future<(FakeNativePlatform, LiquidSearchController)> viaState(
      WidgetTester tester,
    ) async {
      final fake = installFakeNative(
        state: const LiquidNativeShellState(installed: false),
      );
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      await pumpShell(
        tester,
        _searchShell(controller),
        padding: _compactPadding,
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(controller.isActive, isTrue, reason: 'precondition: active');
      return (fake, controller);
    }

    Future<void> engage(
      WidgetTester tester,
      LiquidSearchController controller,
    ) async {
      await pumpShell(
        tester,
        _searchShell(controller),
        padding: _compactPadding,
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing, reason: 'native now');
    }

    Future<void> installLate(
      WidgetTester tester,
      FakeNativePlatform fake,
    ) async {
      fake.pushState(_compact);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing, reason: 'native now');
    }

    void dismissKeyboard(LiquidSearchController controller) {
      controller.dismissKeyboard();
      expect(controller.isActive, isTrue, reason: 'precondition: kept');
    }

    // Green before VK-572: the first claim builds pending, with `native`
    // still false. It guards `holdsField` (VK-571) too.
    testWidgets('B2: keyboard-down, the first claim (pending): the search '
        'ends', (tester) async {
      final controller = await viaPending(tester);
      dismissKeyboard(controller);
      await tester.pump();
      await engage(tester, controller);
      expect(controller.isActive, isFalse);
    });

    testWidgets('B5: focused, auto -> off -> auto: the search ends', (
      tester,
    ) async {
      final controller = await viaOff(tester);
      await engage(tester, controller);
      expect(controller.isActive, isFalse);
    });

    testWidgets('B6: keyboard-down, auto -> off -> auto: the search ends', (
      tester,
    ) async {
      final controller = await viaOff(tester);
      dismissKeyboard(controller);
      await tester.pump();
      await engage(tester, controller);
      expect(controller.isActive, isFalse);
    });

    testWidgets('B7: focused, a late native install: the search ends', (
      tester,
    ) async {
      final (fake, controller) = await viaState(tester);
      await installLate(tester, fake);
      expect(controller.isActive, isFalse);
    });

    testWidgets('B8: keyboard-down, a late native install: the search ends', (
      tester,
    ) async {
      final (fake, controller) = await viaState(tester);
      dismissKeyboard(controller);
      await tester.pump();
      await installLate(tester, fake);
      expect(controller.isActive, isFalse);
    });

    testWidgets('B9: composing, a late native install: the composition '
        'ends, the text kept', (tester) async {
      final (fake, controller) = await viaState(tester);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'かな',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        ),
      );
      await tester.pump();
      expect(controller.value.composing, isTrue, reason: 'precondition');
      await installLate(tester, fake);
      expect(controller.isActive, isFalse);
      expect(controller.text, 'かな');
      expect(controller.value.composing, isFalse);
    });

    testWidgets('B10: deactivate() after a late install leaves the search '
        'inactive', (tester) async {
      final (fake, controller) = await viaState(tester);
      await installLate(tester, fake);
      controller.deactivate();
      await tester.pumpAndSettle();
      expect(controller.isActive, isFalse);
    });

    // The entry runs while the Flutter field still holds the search, so it
    // cannot send the inactive state; the release sends it once the search
    // ended (PR #20 review). A native field left active (a hot restart)
    // would otherwise stay active over an inactive controller.
    testWidgets('B12: a late install over an active Flutter search tells '
        'native the search is inactive', (tester) async {
      final (fake, controller) = await viaState(tester);
      await installLate(tester, fake);
      expect(controller.isActive, isFalse);
      expect(fake.searchActives, [false]);
    });

    testWidgets('B11: a pushed shell pops after a late install over an '
        'active Flutter search', (tester) async {
      final outer = GlobalKey<NavigatorState>();
      final fake = installFakeNative(
        state: const LiquidNativeShellState(installed: false),
      );
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      await pumpShell(
        tester,
        Navigator(
          key: outer,
          onGenerateInitialRoutes: (_, _) => [
            MaterialPageRoute<void>(builder: (_) => const Text('The list')),
            MaterialPageRoute<void>(builder: (_) => _searchShell(controller)),
          ],
        ),
        padding: _compactPadding,
      );
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(controller.isActive, isTrue, reason: 'precondition');
      await installLate(tester, fake);
      fake.searchActives.clear();
      await outer.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(
        find.text('The list'),
        findsOneWidget,
        reason:
            'back blocked: sent ${fake.searchActives}, '
            'isActive ${controller.isActive}',
      );
    });
  });

  // VK-699. The reverse of VK-572 bug B: an active native search,
  // mid-composition (marked text), is handed back to Flutter chrome. The
  // search ends there, its text kept, as any native end does (VK-572 §4):
  // inactive, not composing, onChanged not called.
  group('VK-699: Flutter chrome takes over a native search', () {
    Widget shell(
      LiquidSearchController controller,
      List<String> changes, {
      LiquidNativeChrome nativeChrome = LiquidNativeChrome.auto,
      LiquidGlassTier? forcedTier,
    }) => LiquidGlassScope(
      policy: LiquidGlassPolicy(forcedTier: forcedTier),
      child: TestShell(
        destinations: _destinations,
        initialIndex: 2,
        pageBuilder: _page,
        nativeChrome: nativeChrome,
        search: LiquidSearch(controller: controller, onChanged: changes.add),
      ),
    );

    Future<(FakeNativePlatform, LiquidSearchController, List<String>)>
    composing(WidgetTester tester) async {
      final fake = installFakeNative(state: _compact);
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      final changes = <String>[];
      await pumpShell(
        tester,
        shell(controller, changes),
        padding: _compactPadding,
      );
      fake
        ..emitNative(const LiquidNativeSearchActiveChanged(true))
        ..emitNative(
          const LiquidNativeSearchTextChanged('かな', composing: true),
        );
      await tester.pump();
      expect(controller.isActive, isTrue, reason: 'precondition');
      expect(controller.value.composing, isTrue, reason: 'precondition');
      changes.clear();
      return (fake, controller, changes);
    }

    void expectEnded(LiquidSearchController controller, List<String> changes) {
      expect(controller.isActive, isFalse);
      expect(controller.text, 'かな', reason: 'the composed text is kept');
      expect(controller.value.composing, isFalse);
      expect(changes, isEmpty, reason: 'the text did not change');
    }

    // The claim is released in the same build, so native's own
    // `searchActive false` (if any) never reaches the shell.
    testWidgets('P1: nativeChrome turned off mid-composition', (
      tester,
    ) async {
      final (fake, controller, changes) = await composing(tester);
      await pumpShell(
        tester,
        shell(controller, changes, nativeChrome: LiquidNativeChrome.off),
        padding: _compactPadding,
      );
      fake.emitNative(const LiquidNativeSearchActiveChanged(false));
      await tester.pumpAndSettle();
      expectEnded(controller, changes);
    });

    testWidgets('P2: a lost install mid-composition', (tester) async {
      final (fake, controller, changes) = await composing(tester);
      fake.pushState(const LiquidNativeShellState(installed: false));
      await tester.pumpAndSettle();
      expectEnded(controller, changes);
    });

    // The claim survives a lost install: native's late report arrives
    // after Dart switched to Flutter mode.
    testWidgets('P2b: a lost install, then native reports inactive', (
      tester,
    ) async {
      final (fake, controller, changes) = await composing(tester);
      fake.pushState(const LiquidNativeShellState(installed: false));
      await tester.pumpAndSettle();
      fake.emitNative(const LiquidNativeSearchActiveChanged(false));
      await tester.pumpAndSettle();
      expectEnded(controller, changes);
    });

    // A forced glass tier leaves native chrome through the same setter.
    testWidgets('P3: a forced glass tier mid-composition', (tester) async {
      final (_, controller, changes) = await composing(tester);
      await pumpShell(
        tester,
        shell(controller, changes, forcedTier: LiquidGlassTier.liquid),
        padding: _compactPadding,
      );
      expectEnded(controller, changes);
    });

    // Standby keeps the claim with another shell, not with native gone: the
    // search ends in the controller, so the next entry must tell native too.
    testWidgets('P4: standby, then the claim returns: native told inactive', (
      tester,
    ) async {
      final (fake, controller, _) = await composing(tester);
      final page = find.byKey(const ValueKey('list-Search'));
      Navigator.of(tester.element(page), rootNavigator: true)
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
      expect(controller.isActive, isFalse, reason: 'standby ends the search');
      fake.searchActives.clear();
      Navigator.of(
        tester.element(find.byType(TestShell).last),
        rootNavigator: true,
      ).pop();
      await tester.pumpAndSettle();
      expect(fake.searchActives, contains(false));
    });
  });
}
