import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/search.dart';
import 'package:liquid_shell_example/support/search_data.dart';

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(393, 852),
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size
    ..padding = const FakeViewPadding(top: 59, bottom: 34)
    ..viewPadding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: SearchCase()));
  await tester.pumpAndSettle();
}

Future<void> _openSearch(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Search'));
  await tester.pumpAndSettle();
}

void main() {
  group('data', () {
    test('foldVietnamese strips every tone and vowel mark, and đ', () {
      expect(foldVietnamese('Hồ Hoàn Kiếm'), 'ho hoan kiem');
      expect(foldVietnamese('ĐÀ LẠT'), 'da lat');
      expect(foldVietnamese('ưởng ợ ỹ'), 'uong o y');
      // Decomposed input (combining marks) folds the same.
      expect(foldVietnamese('Hồ'), 'ho');
    });

    test('a query matches when every word starts a word of the item', () {
      SearchItem find(String title) =>
          kSearchItems.firstWhere((i) => i.title == title);
      expect(searchMatches(find('Hồ Hoàn Kiếm'), 'ho hoan kiem'), isTrue);
      expect(searchMatches(find('Hồ Hoàn Kiếm'), 'Hồ hoan'), isTrue);
      expect(searchMatches(find('Phố cổ Hội An'), 'hoi an'), isTrue);
      expect(searchMatches(find('Đà Lạt'), 'da lat'), isTrue);
      expect(searchMatches(find('Hồ Hoàn Kiếm'), 'oan'), isFalse);
      expect(searchMatches(find('Hồ Hoàn Kiếm'), '   '), isFalse);
    });

    test('scopes filter songs and places', () {
      expect(searchResults('ha noi', scope: 0).length, greaterThan(1));
      expect(
        searchResults(
          'ha noi',
          scope: 1,
        ).every((i) => i.kind == SearchKind.song),
        isTrue,
      );
      expect(
        searchResults(
          'ha noi',
          scope: 2,
        ).every((i) => i.kind == SearchKind.place),
        isTrue,
      );
      expect(searchResults('zzz', scope: 0), isEmpty);
    });

    test('recents: newest first, folded duplicates removed, six at most', () {
      var recents = <String>[];
      for (final q in ['a', 'b', 'c', 'd', 'e', 'f', 'g']) {
        recents = rememberQuery(recents, q);
      }
      expect(recents, ['g', 'f', 'e', 'd', 'c', 'b']);
      expect(rememberQuery(['Hà Nội', 'x'], 'ha noi'), ['ha noi', 'x']);
      expect(rememberQuery(['x'], '  '), ['x']);
    });
  });

  group('SearchCase (Flutter chrome)', () {
    testWidgets('selected: categories; active: scope bar and recents', (
      tester,
    ) async {
      await _pump(tester);
      await _openSearch(tester);
      expect(find.text('Nhạc Trịnh'), findsOneWidget);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.byType(LiquidSearchScopeBar), findsOneWidget);
      expect(find.text('Recently searched'), findsOneWidget);
      expect(find.text('Nhạc Trịnh'), findsNothing);
    });

    testWidgets('live results, accent-insensitive; an empty state', (
      tester,
    ) async {
      await _pump(tester);
      await _openSearch(tester);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'ho hoan');
      await tester.pumpAndSettle();
      expect(find.text('Hồ Hoàn Kiếm'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No results for "zzz"'), findsOneWidget);
    });

    testWidgets(
      'a result pushes a detail inside the tab, with the back button',
      (
        tester,
      ) async {
        await _pump(tester);
        await _openSearch(tester);
        await tester.tap(find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'ho hoan');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hồ Hoàn Kiếm'));
        await tester.pumpAndSettle();
        expect(find.byType(LiquidBackButton), findsOneWidget);
        expect(
          find.byType(LiquidShell),
          findsOneWidget,
          reason: 'inside the tab',
        );
        await tester.tap(find.byType(LiquidBackButton));
        await tester.pumpAndSettle();
        expect(find.byType(LiquidBackButton), findsNothing);
        expect(find.text('Hồ Hoàn Kiếm'), findsOneWidget);
      },
    );

    testWidgets('submit remembers the query; Clear empties the recents', (
      tester,
    ) async {
      await _pump(tester);
      await _openSearch(tester);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'da lat');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'da lat'), findsOneWidget);
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'da lat'), findsNothing);
    });

    testWidgets('the query is kept across tab switches', (tester) async {
      await _pump(tester);
      await _openSearch(tester);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'ho hoan');
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Home').first);
      await tester.pumpAndSettle();
      await _openSearch(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'ho hoan',
      );
      expect(find.text('Hồ Hoàn Kiếm'), findsOneWidget);
    });

    testWidgets('a category opens its page', (tester) async {
      await _pump(tester);
      await _openSearch(tester);
      await tester.tap(find.text('Hà Nội').first);
      await tester.pumpAndSettle();
      expect(find.text('Hồ Hoàn Kiếm'), findsOneWidget);
      expect(find.byType(LiquidBackButton), findsOneWidget);
    });
  });
}
