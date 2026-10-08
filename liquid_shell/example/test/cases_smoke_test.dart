import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/cases.dart';
import 'package:liquid_shell_example/main.dart';

/// The destination labels of the only [LiquidShell] on screen.
List<String> shellLabels(WidgetTester tester) => [
  for (final d
      in tester.widget<LiquidShell>(find.byType(LiquidShell)).destinations)
    d.label,
];

const _sizes = {'phone': Size(393, 852), 'tablet': Size(1194, 834)};

Future<void> _openCase(WidgetTester tester, String id) async {
  await tester.pumpWidget(const ExampleApp());
  final row = find.byKey(ValueKey('case-$id'));
  await tester.scrollUntilVisible(row, 100);
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

void main() {
  for (final MapEntry(key: sizeName, value: size) in _sizes.entries) {
    for (final entry in kCases) {
      testWidgets('${entry.id} on a $sizeName opens without errors', (
        tester,
      ) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = size;
        addTearDown(tester.view.reset);
        await _openCase(tester, entry.id);
        expect(tester.takeException(), isNull);
        expect(find.byType(LiquidShell), findsWidgets);
      });
    }
  }

  testWidgets('the guard asks before leaving dirty edits', (tester) async {
    await _openCase(tester, 'guard');
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Home item 1'), findsOneWidget);
  });

  testWidgets('the guard moves on and clears the edits after "Discard"', (
    tester,
  ) async {
    await _openCase(tester, 'guard');
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Explore item 1'), findsOneWidget);
    expect(find.text('Home item 1'), findsNothing);

    // The edits are gone, so the next change does not ask again.
    final dirty = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(dirty.value, isFalse);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Home item 1'), findsOneWidget);
  });

  testWidgets('the detail page hides the chrome', (tester) async {
    await _openCase(tester, 'hide_chrome');
    await tester.tap(find.text('Open a full-frame detail page'));
    await tester.pumpAndSettle();
    expect(find.text('Detail item 1'), findsOneWidget);
    // Offstage too: a page pushed above the shell would only cover the bar.
    expect(find.byType(LiquidTabBar, skipOffstage: false), findsNothing);
    final detail = tester.element(find.text('Detail item 1'));
    expect(LiquidShellScope.of(detail).chromeKind, LiquidChromeKind.hidden);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(LiquidTabBar), findsOneWidget);
    expect(find.text('Home item 1'), findsOneWidget);
  });

  testWidgets('trailing search opens a page with no chrome', (tester) async {
    await _openCase(tester, 'trailing');
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    final field = tester.element(find.byType(TextField));
    expect(LiquidShellScope.of(field), LiquidShellScopeData.none());
  });

  testWidgets('a sidebar-only selection falls back to the first tab on a '
      'phone', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(834, 1194);
    addTearDown(tester.view.reset);
    await _openCase(tester, 'sidebar_only');
    await tester.tap(find.byTooltip('Show sidebar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.text('Destination 4'), findsOneWidget);

    tester.view.physicalSize = const Size(393, 852);
    await tester.pumpAndSettle();
    expect(find.text('Destination 1'), findsOneWidget);
  });

  testWidgets('the replacement sidebar leaves the primary scroll controller '
      'to the body', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(1194, 834);
    addTearDown(tester.view.reset);
    await _openCase(tester, 'custom_chrome');
    // A list that takes the route's controller hides it from its own
    // descendants, so ask from above both lists.
    final route = tester.element(find.byType(LiquidShell));
    // Tiled: the body list and the custom sidebar list sit side by side; a
    // status-bar tap must scroll the body only.
    expect(find.text('Home item 1'), findsOneWidget);
    expect(PrimaryScrollController.of(route).positions, hasLength(1));
  });

  testWidgets('narrow: 5 tabs + trailing in a 320pt shell keep 44pt cells at '
      'text scale 1 (Q17)', (tester) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    await _openCase(tester, 'narrow');
    expect(tester.takeException(), isNull, reason: 'no overflow');

    final shell = tester.getRect(find.byType(LiquidShell));
    expect(shell.width, 320);
    final bar = find.byType(LiquidTabBar);
    final cells = [
      for (final label in shellLabels(tester))
        tester.getRect(
          find.ancestor(
            of: find.descendant(of: bar, matching: find.text(label)),
            matching: find.byType(InkWell),
          ),
        ),
    ];
    expect(cells, hasLength(5));
    // (320 − 2×8 margin − 62 circle − 8 gap − 2×4 pill padding) / 5.
    for (final cell in cells) {
      expect(cell.width, moreOrLessEquals(45.2, epsilon: 0.01));
      expect(cell.width, greaterThanOrEqualTo(44));
    }
    // The narrow row margin is 8 on both sides of the shell, not the screen.
    expect(cells.first.left - shell.left, 8 + 4);
    final circle = tester.getRect(
      find.ancestor(
        of: find.descendant(of: bar, matching: find.byIcon(Icons.search)),
        matching: find.byType(LiquidGlass),
      ),
    );
    expect(shell.right - circle.right, 8);
  });
}
