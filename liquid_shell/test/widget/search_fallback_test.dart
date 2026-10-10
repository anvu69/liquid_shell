import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/search/search_chrome.dart';

import '../helpers/shell_harness.dart';

const _destinations = [
  LiquidDestination(icon: Icon(Icons.home), label: 'Home'),
  LiquidDestination(icon: Icon(Icons.book), label: 'Library'),
  LiquidDestination(
    icon: Icon(Icons.search),
    label: 'Search',
    role: LiquidDestinationRole.search,
  ),
];

const double _rowBottom = 852.0 - 21;

Future<(LiquidSearchController, List<int>, List<String>)> _pump(
  WidgetTester tester, {
  Size size = kPhone,
  int initialIndex = 0,
  TextDirection direction = TextDirection.ltr,
  TargetPlatform platform = TargetPlatform.iOS,
  LiquidChromeBuilder? chromeBuilder,
}) async {
  final controller = LiquidSearchController();
  addTearDown(controller.dispose);
  final selections = <int>[];
  final changes = <String>[];
  await pumpShell(
    tester,
    TestShell(
      destinations: _destinations,
      initialIndex: initialIndex,
      selections: selections,
      chromeBuilder: chromeBuilder,
      search: LiquidSearch(controller: controller, onChanged: changes.add),
    ),
    size: size,
    direction: direction,
    platform: platform,
  );
  return (controller, selections, changes);
}

Rect _rect(WidgetTester tester, Key key) => tester.getRect(find.byKey(key));

double _opacity(WidgetTester tester, Key key) => tester
    .widget<AnimatedOpacity>(
      find
          .descendant(
            of: find.byKey(key),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    )
    .opacity;

void main() {
  testWidgets('idle: the pill without Search, and a separate ⌕ circle', (
    tester,
  ) async {
    await _pump(tester);
    final bar = tester.widget<LiquidTabBar>(find.byType(LiquidTabBar));
    expect(bar.destinations.map((d) => d.label), ['Home', 'Library']);
    expect(
      _rect(tester, kSearchFieldKey),
      const Rect.fromLTWH(393 - 16 - 62, _rowBottom - 62, 62, 62),
    );
    expect(find.bySemanticsLabel('Search'), findsOneWidget);
    expect(scopeOf(tester).searchPhase, LiquidSearchPhase.idle);
  });

  testWidgets('tap ⌕: the search tab is selected, the field is not focused', (
    tester,
  ) async {
    final (_, selections, _) = await _pump(tester);
    await tester.tap(find.bySemanticsLabel('Search'));
    await tester.pumpAndSettle();
    expect(selections, [2]);
    expect(
      _rect(tester, kSearchFieldKey),
      const Rect.fromLTRB(88, _rowBottom - 55, 393 - 28, _rowBottom - 7),
    );
    expect(
      _rect(tester, kSearchCollapsedKey),
      const Rect.fromLTWH(28, _rowBottom - 55, 48, 48),
    );
    expect(_opacity(tester, kSearchCollapsedKey), 1);
    expect(
      find.bySemanticsLabel('Home'),
      findsWidgets,
      reason: 'the previous tab',
    );
    expect(tester.testTextInput.isVisible, isFalse);
    expect(scopeOf(tester, 'Search').searchPhase, LiquidSearchPhase.selected);
  });

  testWidgets('tap the field: active above the keyboard with ×', (
    tester,
  ) async {
    final (controller, _, changes) = await _pump(tester, initialIndex: 2);
    await tester.tap(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(controller.isActive, isTrue);
    const bottom = 852.0 - 336 - 8;
    expect(
      _rect(tester, kSearchFieldKey),
      const Rect.fromLTRB(8, bottom - 48, 393 - 64, bottom),
    );
    expect(
      _rect(tester, kSearchCancelKey),
      const Rect.fromLTWH(393 - 56, bottom - 48, 48, 48),
    );
    expect(_opacity(tester, kSearchCollapsedKey), 0);
    expect(
      scopeOf(tester, 'Search').chromeInsets.bottom,
      852 - (bottom - 48) + 8,
    );
    await tester.enterText(find.byType(TextField), 'ho');
    await tester.pump();
    expect(controller.text, 'ho');
    expect(changes, ['ho']);
  });

  testWidgets('× clears and unfocuses: back to selected', (tester) async {
    final (controller, _, changes) = await _pump(tester, initialIndex: 2);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'ho');
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Cancel search'));
    await tester.pumpAndSettle();
    expect(controller.text, '');
    expect(controller.isActive, isFalse);
    expect(changes.last, '');
    expect(scopeOf(tester, 'Search').searchPhase, LiquidSearchPhase.selected);
  });

  testWidgets('the collapsed circle returns to the previous tab', (
    tester,
  ) async {
    final (_, selections, _) = await _pump(tester, initialIndex: 1);
    await tester.tap(find.bySemanticsLabel('Search'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kSearchCollapsedKey));
    await tester.pumpAndSettle();
    expect(selections, [2, 1]);
  });

  testWidgets('the field is never rebuilt across phases', (tester) async {
    await _pump(tester, initialIndex: 2);
    final selected = tester.element(find.byType(TextField));
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(identical(tester.element(find.byType(TextField)), selected), isTrue);
    await tester.tap(find.bySemanticsLabel('Cancel search'));
    await tester.pumpAndSettle();
    expect(identical(tester.element(find.byType(TextField)), selected), isTrue);
  });

  testWidgets('an app write waits for the IME composition to end', (
    tester,
  ) async {
    final (controller, _, _) = await _pump(tester, initialIndex: 2);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    field.controller!.value = const TextEditingValue(
      text: 'hoo',
      composing: TextRange(start: 0, end: 3),
    );
    await tester.pump();
    expect(controller.value.composing, isTrue);
    controller.text = 'phố';
    expect(
      field.controller!.text,
      'hoo',
      reason: 'never written into a composition',
    );
    field.controller!.value = const TextEditingValue(text: 'hồ');
    await tester.pump();
    expect(field.controller!.text, 'phố', reason: 'applied once it ended');
  });

  testWidgets('a composing field survives rebuilds: no write, same element', (
    tester,
  ) async {
    final (controller, _, changes) = await _pump(tester, initialIndex: 2);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final element = tester.element(find.byType(TextField));
    final editing = tester
        .widget<TextField>(find.byType(TextField))
        .controller!;
    const composing = TextEditingValue(
      text: 'hoo',
      selection: TextSelection.collapsed(offset: 3),
      composing: TextRange(start: 0, end: 3),
    );
    editing.value = composing;
    await tester.pump();
    expect(controller.value.composing, isTrue);
    // The keyboard rises mid-composition: the shell rebuilds and the field
    // animates to its active rect.
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    // The app writes the same text: a no-op, also during a composition.
    controller.text = 'hoo';
    await tester.pump();
    expect(identical(tester.element(find.byType(TextField)), element), isTrue);
    final after = tester.widget<TextField>(find.byType(TextField));
    expect(identical(after.controller, editing), isTrue);
    expect(after.focusNode!.hasFocus, isTrue);
    expect(editing.value, composing, reason: 'never written into');
    expect(controller.value.composing, isTrue);
    expect(changes, ['hoo']);
  });

  testWidgets('regular: the field is not rebuilt when it activates', (
    tester,
  ) async {
    await _pump(tester, size: kTabletPortrait, initialIndex: 2);
    final selected = tester.element(find.byType(TextField));
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(identical(tester.element(find.byType(TextField)), selected), isTrue);
    await tester.tap(find.byTooltip('Cancel search'));
    await tester.pumpAndSettle();
    expect(identical(tester.element(find.byType(TextField)), selected), isTrue);
  });

  testWidgets('compact → regular while focused unfocuses first', (
    tester,
  ) async {
    final (controller, _, _) = await _pump(tester, initialIndex: 2);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(controller.isActive, isTrue);
    await resize(tester, kTabletPortrait);
    expect(controller.isActive, isFalse);
    expect(scopeOf(tester, 'Search').searchPhase, LiquidSearchPhase.selected);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'regular: the field below the bar; active, it takes the bar row',
    (
      tester,
    ) async {
      final (controller, _, _) = await _pump(
        tester,
        size: kTabletPortrait,
        initialIndex: 2,
      );
      final selectedTop = _rect(tester, kSearchFieldKey).top;
      expect(selectedTop, 59 + 20 + 52 + 8);
      expect(_rect(tester, kSearchFieldKey).height, 44);
      expect(scopeOf(tester, 'Search').chromeInsets.top, selectedTop + 44 + 8);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(controller.isActive, isTrue);
      expect(_rect(tester, kSearchFieldKey).top, 59 + 20);
      final barOpacity = tester
          .widgetList<AnimatedOpacity>(
            find.ancestor(
              of: find.byType(LiquidTabBar),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .first
          .opacity;
      expect(barOpacity, 0);
    },
  );

  testWidgets('Android back deactivates instead of popping', (tester) async {
    final (controller, _, _) = await _pump(
      tester,
      initialIndex: 2,
      platform: TargetPlatform.android,
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(controller.isActive, isFalse);
    expect(find.byType(LiquidShell), findsOneWidget);
  });

  testWidgets('Esc deactivates', (tester) async {
    final (controller, _, _) = await _pump(tester, initialIndex: 2);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(controller.isActive, isFalse);
  });

  testWidgets('reduce motion: the morph is instant', (tester) async {
    await _pump(tester);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Search'));
    await tester.pump();
    await tester.pump();
    expect(
      _rect(tester, kSearchFieldKey),
      const Rect.fromLTRB(88, _rowBottom - 55, 393 - 28, _rowBottom - 7),
    );
  });

  testWidgets('RTL: the collapsed circle is on the right', (tester) async {
    await _pump(tester, initialIndex: 2, direction: TextDirection.rtl);
    expect(_rect(tester, kSearchCollapsedKey).right, 393 - 28);
  });

  testWidgets('a chromeBuilder gets the searchField slot with the phase', (
    tester,
  ) async {
    final seen = <LiquidSearchPhase?>[];
    await _pump(
      tester,
      initialIndex: 2,
      chromeBuilder: (context, details, chrome) {
        if (details.slot == LiquidChromeSlot.searchField) {
          seen.add(details.search?.phase);
        }
        return chrome;
      },
    );
    expect(seen, contains(LiquidSearchPhase.selected));
  });

  testWidgets('a previous tab that is gone falls back to the first', (
    tester,
  ) async {
    final controller = LiquidSearchController();
    addTearDown(controller.dispose);
    Future<void> show(List<LiquidDestination> destinations, int index) =>
        pumpShell(
          tester,
          LiquidShell(
            destinations: destinations,
            selectedIndex: index,
            onDestinationSelected: (_) {},
            search: LiquidSearch(controller: controller),
            body: const SizedBox.expand(),
          ),
        );
    const places = LiquidDestination(icon: Icon(Icons.map), label: 'Places');
    await show([..._destinations.take(2), places, _destinations[2]], 2);
    await show([..._destinations.take(2), places, _destinations[2]], 3);
    String previous() => tester
        .widget<CompactSearchChrome>(find.byType(CompactSearchChrome))
        .previous
        .label;
    // Index 2 is now the search tab itself.
    await show(_destinations, 2);
    expect(tester.takeException(), isNull);
    expect(previous(), 'Home');
    // Index 2 is now out of range.
    await show([_destinations.first, _destinations[2]], 1);
    expect(tester.takeException(), isNull);
    expect(previous(), 'Home');
  });

  testWidgets('LiquidSearchScopeBar selects a scope', (tester) async {
    final controller = LiquidSearchController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LiquidSearchScopeBar(
            controller: controller,
            scopes: const ['All', 'Songs', 'Places'],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Places'));
    await tester.pump();
    expect(controller.scopeIndex, 2);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Places')),
      isSemantics(
        isButton: true,
        isSelected: true,
        hasTapAction: true,
        label: 'Places',
      ),
    );
  });
}
