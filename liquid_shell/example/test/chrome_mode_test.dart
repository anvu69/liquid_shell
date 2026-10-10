import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/main.dart';
import 'package:liquid_shell_example/support/chrome_mode.dart';

Future<void> _open(WidgetTester tester, String id) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(393, 852);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ExampleApp());
  final row = find.byKey(ValueKey('case-$id'));
  await tester.scrollUntilVisible(row, 100);
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

LiquidGlassTier? _forced(WidgetTester tester) => LiquidGlassScope.policyOf(
  tester.element(find.byType(LiquidShell)),
).forcedTier;

void main() {
  testWidgets('every case shows the switch, starting at native', (
    tester,
  ) async {
    await _open(tester, 'basic');
    expect(find.byKey(const ValueKey('chrome-mode')), findsOneWidget);

    expect(find.text('Auto'), findsOneWidget); // not iOS in flutter test
    expect(_forced(tester), isNull);
  });

  testWidgets('the form factors case shows it too', (tester) async {
    await _open(tester, 'form_factors');
    // Its own switch, then one per framed DemoPage.
    expect(find.byKey(const ValueKey('chrome-mode')), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Flutter liquid forces the liquid tier and keeps the case', (
    tester,
  ) async {
    await _open(tester, 'basic');
    final shell = tester.state(find.byType(LiquidShell));
    await tester.tap(find.text('Flutter liquid'));
    await tester.pumpAndSettle();
    expect(_forced(tester), LiquidGlassTier.liquid);
    expect(tester.state(find.byType(LiquidShell)), same(shell));
  });

  testWidgets('the mode is shared by every case', (tester) async {
    await _open(tester, 'basic');
    await tester.tap(find.text('Flutter liquid'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('case-badges')));
    await tester.pumpAndSettle();
    expect(_forced(tester), LiquidGlassTier.liquid);
  });

  testWidgets('the forced-tier case keeps its own tier (inner scope)', (
    tester,
  ) async {
    await _open(tester, 'forced_tier');
    await tester.tap(find.text('Flutter liquid'));
    await tester.pumpAndSettle();
    expect(_forced(tester), LiquidGlassTier.frosted);
  });

  testWidgets(
    'on iOS the first segment reads Native',
    (tester) async {
      await _open(tester, 'basic');
      expect(find.text('Native'), findsOneWidget);
      expect(find.text('Auto'), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('switching back to Auto drops the forced tier', (tester) async {
    await _open(tester, 'basic');
    await tester.tap(find.text('Flutter liquid'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Auto'));
    await tester.pumpAndSettle();
    expect(_forced(tester), isNull);
  });

  testWidgets('a case that picks its own tier shows the switch disabled', (
    tester,
  ) async {
    await _open(tester, 'forced_tier');
    expect(find.text('This case picks its own tier'), findsOneWidget);
    final button = tester.widget<SegmentedButton<ExampleChromeMode>>(
      find.byKey(const ValueKey('chrome-mode')),
    );
    expect(button.onSelectionChanged, isNull);
  });

  testWidgets('other cases show it enabled, without the note', (tester) async {
    await _open(tester, 'basic');
    expect(find.text('This case picks its own tier'), findsNothing);
    final button = tester.widget<SegmentedButton<ExampleChromeMode>>(
      find.byKey(const ValueKey('chrome-mode')),
    );
    expect(button.onSelectionChanged, isNotNull);
  });
}
