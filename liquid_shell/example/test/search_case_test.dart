import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/search.dart';
import 'package:liquid_shell_example/support/search_data.dart';

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(393, 852),
  bool guardDetails = false,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size
    ..padding = const FakeViewPadding(top: 59, bottom: 34)
    ..viewPadding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: SearchCase(guardDetails: guardDetails)),
  );
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

    test('foldVietnamese: every vowel with each tone, upper case, NFC and '
        'NFD, and đ (spec §12.1)', () {
      // Precomposed (NFC): the base, then grave, acute, hook, tilde, dot.
      const nfc = {
        'a': ['aàáảãạ', 'ăằắẳẵặ', 'âầấẩẫậ'],
        'e': ['eèéẻẽẹ', 'êềếểễệ'],
        'i': ['iìíỉĩị'],
        'o': ['oòóỏõọ', 'ôồốổỗộ', 'ơờớởỡợ'],
        'u': ['uùúủũụ', 'ưừứửữự'],
        'y': ['yỳýỷỹỵ'],
      };
      // Decomposed (NFD): the base letter, its vowel mark, then the tone.
      const vowelMarks = {
        'ă': 'a\u0306',
        'â': 'a\u0302',
        'ê': 'e\u0302',
        'ô': 'o\u0302',
        'ơ': 'o\u031B',
        'ư': 'u\u031B',
      };
      const tones = ['', '\u0300', '\u0301', '\u0309', '\u0303', '\u0323'];
      var cases = 0;
      for (final MapEntry(key: base, value: rows) in nfc.entries) {
        for (final row in rows) {
          final letters = row.runes.map(String.fromCharCode).toList();
          expect(letters, hasLength(6), reason: row);
          final vowel = letters.first;
          for (final (tone, composed) in letters.indexed) {
            final decomposed = '${vowelMarks[vowel] ?? vowel}${tones[tone]}';
            for (final form in [composed, decomposed]) {
              for (final text in [form, form.toUpperCase()]) {
                expect(foldVietnamese(text), base, reason: text);
                cases++;
              }
            }
          }
        }
      }
      expect(foldVietnamese('đ'), 'd');
      expect(foldVietnamese('Đ'), 'd');
      expect(cases + 2, 290);
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

    testWidgets('tapping a recent search fills the field', (tester) async {
      await _pump(tester);
      await _openSearch(tester);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'da lat');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'da lat'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'da lat',
      );
      expect(find.text('Đà Lạt'), findsOneWidget);
    });

    testWidgets('a recent tapped mid-composition lands once it ends', (
      tester,
    ) async {
      await _pump(tester);
      await _openSearch(tester);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'da lat');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      // The IME composes a blank: the recents still show.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: ' ',
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange(start: 0, end: 1),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'da lat'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, ' ', reason: 'held during composition');
      // The composition ends: the library applies the held write.
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: ' ',
          selection: TextSelection.collapsed(offset: 1),
        ),
      );
      await tester.pumpAndSettle();
      expect(field.controller!.text, 'da lat');
      expect(find.text('Đà Lạt'), findsOneWidget);
    });

    testWidgets('a scope narrows the live results', (tester) async {
      await _pump(tester);
      await _openSearch(tester);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'ha noi');
      await tester.pumpAndSettle();
      expect(find.text('Hồ Hoàn Kiếm'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Songs'));
      await tester.pumpAndSettle();
      expect(find.text('Hồ Hoàn Kiếm'), findsNothing);
      expect(find.text('Nồng nàn Hà Nội'), findsOneWidget);
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

    for (final guarded in [false, true]) {
      testWidgets('guardDetails $guarded: a detail '
          '${guarded ? 'refuses' : 'accepts'} the back', (tester) async {
        await _pump(tester, guardDetails: guarded);
        await _openSearch(tester);
        await tester.tap(find.text('Nhạc Trịnh').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Diễm xưa'));
        await tester.pumpAndSettle();
        expect(find.byType(Chip), findsOneWidget, reason: 'the detail');
        await tester.tap(find.byType(LiquidBackButton));
        await tester.pumpAndSettle();
        expect(find.byType(Chip), guarded ? findsOneWidget : findsNothing);
      });
    }
  });
}
