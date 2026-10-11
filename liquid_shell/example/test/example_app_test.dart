import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_example/cases/search.dart';
import 'package:liquid_shell_example/main.dart';

void main() {
  testWidgets('no demo: the case list', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.byType(CaseList), findsOneWidget);
    expect(find.byType(SearchCase), findsNothing);
  });

  testWidgets('demo search: the search case, with semantics on (XCUITest)', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ExampleApp(demo: 'search'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchCase), findsOneWidget);
    expect(find.byType(CaseList), findsNothing);
    expect(tester.binding.semanticsEnabled, isTrue);
    debugReleaseDemoSemantics();
  });

  testWidgets('demo search-guarded: the search case with guarded details', (
    tester,
  ) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(393, 852);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ExampleApp(demo: 'search-guarded'));
    await tester.pumpAndSettle();
    final shown = tester.widget<SearchCase>(find.byType(SearchCase));
    // flutter_test checks for live semantics handles before any tear-down.
    debugReleaseDemoSemantics();
    expect(shown.guardDetails, isTrue);
  });

  testWidgets('an unknown demo falls back to the case list', (tester) async {
    await tester.pumpWidget(const ExampleApp(demo: 'nope'));
    expect(find.byType(CaseList), findsOneWidget);
    debugReleaseDemoSemantics();
  });
}
