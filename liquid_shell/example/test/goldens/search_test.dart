@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_example/cases/search.dart';

import '../support/golden_harness.dart';

/// The search tab drawn by Flutter (spec P3b §12.3).
void main() {
  Future<void> openSearch(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Search'));
    await tester.pumpAndSettle();
  }

  testWidgets('case_search_phone_selected', (tester) async {
    await pumpGolden(tester, const SearchCase(), device: iphone);
    await openSearch(tester);
    await expectDocImage(tester, 'case_search_phone_selected');
  });

  testWidgets('case_search_phone_active', (tester) async {
    await pumpGolden(tester, const SearchCase(), device: iphone);
    await openSearch(tester);
    await tester.tap(find.byType(TextField));
    tester.view.viewInsets = const FakeViewPadding(
      bottom: 336 * goldenPixelRatio,
    );
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await expectDocImage(tester, 'case_search_phone_active');
  });

  testWidgets('case_search_phone_results', (tester) async {
    await pumpGolden(tester, const SearchCase(), device: iphone);
    await openSearch(tester);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'ho');
    await tester.pumpAndSettle();
    await expectDocImage(tester, 'case_search_phone_results');
  });

  testWidgets('case_search_tablet_selected', (tester) async {
    await pumpGolden(tester, const SearchCase(), device: ipadPortrait);
    await openSearch(tester);
    await expectDocImage(tester, 'case_search_tablet_selected');
  });

  testWidgets('case_search_tablet_active', (tester) async {
    await pumpGolden(tester, const SearchCase(), device: ipadPortrait);
    await openSearch(tester);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await expectDocImage(tester, 'case_search_tablet_active');
  });

  testWidgets('case_search_detail', (tester) async {
    await pumpGolden(tester, const SearchCase(), device: iphone);
    await openSearch(tester);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'ho hoan');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hồ Hoàn Kiếm'));
    await tester.pumpAndSettle();
    await expectDocImage(tester, 'case_search_detail');
  });
}
