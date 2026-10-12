import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/shell/shell_scope.dart';

import '../helpers/shell_harness.dart';

const _scopes = ['All', 'Songs', 'Places'];

const _destinations = [
  LiquidDestination(icon: Icon(Icons.home), label: 'Home'),
  LiquidDestination(
    icon: Icon(Icons.search),
    label: 'Search',
    role: LiquidDestinationRole.search,
  ),
];

/// The segment of [title]: its semantics node takes the touch (the label
/// is drawn twice, once per weight).
Finder _segment(String title) => find.byWidgetPredicate(
  (w) =>
      w is Semantics &&
      w.properties.button == true &&
      w.properties.label == title,
);

/// [bar] alone, outside a shell, or under [scope] when given.
Future<void> _pumpBar(
  WidgetTester tester,
  Widget bar, {
  LiquidShellScopeData? scope,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: LiquidGlassScope(
        // No shader in widget tests (as segmented_control_test.dart).
        policy: const LiquidGlassPolicy(forcedTier: LiquidGlassTier.solid),
        child: Scaffold(
          body: Center(
            child: scope == null
                ? bar
                : ShellScopeMarker(data: scope, registry: null, child: bar),
          ),
        ),
      ),
    ),
  );
}

LiquidShellScopeData _data({
  bool nativeSearchScopes = false,
  List<String>? searchScopes,
}) => LiquidShellScopeData(
  sizeClass: LiquidSizeClass.compact,
  chromeKind: LiquidChromeKind.bottomBar,
  chromeInsets: EdgeInsets.zero,
  sidebarVisible: false,
  setSidebarVisible: (_) {},
  nativeSearchScopes: nativeSearchScopes,
  searchScopes: searchScopes,
);

LiquidSearchController _controller({int scopeIndex = 0}) {
  final controller = LiquidSearchController(scopeIndex: scopeIndex);
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  group('LiquidSearchScopeBar (spec VK-550 §11)', () {
    testWidgets('Flutter mode: a LiquidSegmentedControl bound to the '
        "controller's scope", (tester) async {
      final controller = _controller(scopeIndex: 2);
      await _pumpBar(
        tester,
        LiquidSearchScopeBar(controller: controller, scopes: _scopes),
      );
      final control = tester.widget<LiquidSegmentedControl>(
        find.byType(LiquidSegmentedControl),
      );
      expect(control.segments.map((s) => s.label), _scopes);
      expect(control.selectedIndex, controller.scopeIndex);
      expect(control.expand, isTrue);

      await tester.tap(_segment('Songs'));
      await tester.pumpAndSettle();
      expect(controller.scopeIndex, 1);
      expect(
        tester
            .widget<LiquidSegmentedControl>(
              find.byType(LiquidSegmentedControl),
            )
            .selectedIndex,
        1,
        reason: 'rebuilt from the controller',
      );

      controller.scopeIndex = 0;
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LiquidSegmentedControl>(
              find.byType(LiquidSegmentedControl),
            )
            .selectedIndex,
        0,
        reason: "the app's write shows",
      );
    });

    testWidgets('a scope index past the titles shows the last one', (
      tester,
    ) async {
      final controller = _controller(scopeIndex: 7);
      await _pumpBar(
        tester,
        LiquidSearchScopeBar(controller: controller, scopes: _scopes),
      );
      expect(
        tester
            .widget<LiquidSegmentedControl>(
              find.byType(LiquidSegmentedControl),
            )
            .selectedIndex,
        2,
      );
      expect(controller.scopeIndex, 7, reason: 'the bar never writes back');
    });

    testWidgets('native draws the scopes: the bar builds nothing', (
      tester,
    ) async {
      final controller = _controller();
      await _pumpBar(
        tester,
        LiquidSearchScopeBar(controller: controller),
        scope: _data(nativeSearchScopes: true, searchScopes: _scopes),
      );
      expect(find.byType(LiquidSegmentedControl), findsNothing);
      expect(
        find.descendant(
          of: find.byType(LiquidSearchScopeBar),
          matching: find.byType(SizedBox),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(find.byType(LiquidSearchScopeBar)), Size.zero);
    });

    testWidgets("scopes: null reads the shell's LiquidSearch.scopes", (
      tester,
    ) async {
      final controller = _controller();
      await pumpShell(
        tester,
        TestShell(
          destinations: _destinations,
          initialIndex: 1,
          search: LiquidSearch(controller: controller, scopes: _scopes),
          pageBuilder: (i) => i == 1
              ? Center(child: LiquidSearchScopeBar(controller: controller))
              : const SizedBox.shrink(),
        ),
      );
      final control = tester.widget<LiquidSegmentedControl>(
        find.byType(LiquidSegmentedControl),
      );
      expect(control.segments.map((s) => s.label), _scopes);
      await tester.tap(_segment('Places'));
      await tester.pumpAndSettle();
      expect(controller.scopeIndex, 2);
    });

    testWidgets('explicit scopes that differ from the shell assert', (
      tester,
    ) async {
      final controller = _controller();
      await _pumpBar(
        tester,
        LiquidSearchScopeBar(controller: controller, scopes: const ['A', 'B']),
        scope: _data(searchScopes: _scopes),
      );
      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('explicit scopes equal to the shell are fine', (tester) async {
      final controller = _controller();
      await _pumpBar(
        tester,
        LiquidSearchScopeBar(
          controller: controller,
          scopes: List.of(_scopes),
        ),
        scope: _data(searchScopes: _scopes),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(LiquidSegmentedControl), findsOneWidget);
    });

    testWidgets('no scopes anywhere asserts', (tester) async {
      final controller = _controller();
      await _pumpBar(tester, LiquidSearchScopeBar(controller: controller));
      expect(tester.takeException(), isAssertionError);
    });
  });

  group('LiquidShellScopeData search scopes', () {
    test('compare by value', () {
      expect(_data(searchScopes: ['A', 'B']), _data(searchScopes: ['A', 'B']));
      expect(
        _data(searchScopes: ['A', 'B']).hashCode,
        _data(searchScopes: ['A', 'B']).hashCode,
      );
      expect(_data(searchScopes: ['A', 'B']), isNot(_data()));
      expect(_data(nativeSearchScopes: true), isNot(_data()));
      expect(_data().nativeSearchScopes, isFalse);
      expect(_data().searchScopes, isNull);
    });

    testWidgets("the shell publishes its LiquidSearch.scopes, not native's "
        'in Flutter mode', (tester) async {
      final controller = _controller();
      await pumpShell(
        tester,
        TestShell(
          destinations: _destinations,
          search: LiquidSearch(controller: controller, scopes: _scopes),
        ),
      );
      final scope = scopeOf(tester);
      expect(scope.searchScopes, _scopes);
      expect(scope.nativeSearchScopes, isFalse);
    });
  });
}
