import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example_go_router/go_router_app.dart';

/// An iPhone-sized window: the shell shows its tab bar.
Future<void> pumpApp(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1179, 2556)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const GoRouterApp());
  await tester.pumpAndSettle();
}

/// The tab bar is on screen when its labels are. With a search destination
/// the shell draws it as a `GlassTabBar`, not a `LiquidTabBar`, so the tests
/// look for the label, which no page uses as its own text.
Finder chrome() => find.text('Explore');

/// The chrome kind the shell reports to the page that shows [text].
LiquidChromeKind kindAt(WidgetTester tester, String text) =>
    LiquidShellScope.of(
      tester.element(find.text(text, skipOffstage: false).first),
    ).chromeKind;

/// The tab bar draws each label twice (plain and tinted).
Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a branch keeps its state across tab switches', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Count: 0'));
    await tester.pumpAndSettle();
    await tapTab(tester, 'Explore');
    expect(find.text('Explore page'), findsOneWidget);
    await tapTab(tester, 'Home');
    expect(find.text('Count: 1'), findsOneWidget);
  });

  testWidgets('a full-frame page inside the branch hides the chrome; back '
      'shows it again', (tester) async {
    await pumpApp(tester);
    expect(chrome(), findsWidgets);
    await tester.tap(find.text('Open the detail page'));
    await tester.pumpAndSettle();
    expect(find.text('Detail page'), findsOneWidget);
    expect(chrome(), findsNothing);
    expect(kindAt(tester, 'Detail page'), LiquidChromeKind.hidden);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Detail page'), findsNothing);
    expect(chrome(), findsWidgets);
    expect(kindAt(tester, 'Home page'), isNot(LiquidChromeKind.hidden));
  });

  testWidgets('a page above the shell closes with back; the shell stays', (
    tester,
  ) async {
    await pumpApp(tester);
    final before = kindAt(tester, 'Home page');
    await tester.tap(find.text('Compose'));
    await tester.pumpAndSettle();
    expect(find.text('Compose page'), findsOneWidget);
    expect(kindAt(tester, 'Home page'), before);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Compose page'), findsNothing);
    expect(chrome(), findsWidgets);
  });
}
