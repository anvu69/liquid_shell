import 'package:test/test.dart';

import '../check_readme_snippets.dart';

void main() {
  group('extractRegions', () {
    test('returns each named region, dedented', () {
      const source = '''
class A {
  Widget build() {
    // #docregion readme
    return Text(
      'hi',
    );
    // #enddocregion readme
  }
  // #docregion other
  int x = 1;
  // #enddocregion other
}
''';
      expect(extractRegions(source), {
        'readme': "return Text(\n  'hi',\n);",
        'other': 'int x = 1;',
      });
    });

    test('an unterminated region is an error', () {
      expect(
        () => extractRegions('// #docregion readme\nint x;\n'),
        throwsFormatException,
      );
    });

    test('a region opened twice is an error', () {
      expect(
        () => extractRegions(
          '// #docregion readme\nint x;\n// #enddocregion readme\n'
          '// #docregion readme\nint y;\n// #enddocregion readme\n',
        ),
        throwsA(_formatError(contains('readme'))),
      );
    });

    test('an #enddocregion with no open region is an error', () {
      expect(
        () => extractRegions('int x;\n// #enddocregion readme\n'),
        throwsA(_formatError(contains('readme'))),
      );
    });

    test('a mistyped region marker is an error, not code', () {
      for (final typo in [
        '//#docregion readme',
        '// #docregion',
        '// #docregion readme extra',
        '// #enddocregion  ',
        '// #docregon readme',
      ]) {
        expect(
          () => extractRegions('$typo\nint x;\n'),
          throwsFormatException,
          reason: typo,
        );
      }
    });

    test('regions may nest and overlap', () {
      const source = '''
// #docregion readme
int a;
// #docregion inner
int b;
// #enddocregion inner
// #enddocregion readme
''';
      expect(extractRegions(source), {
        'readme': 'int a;\nint b;',
        'inner': 'int b;',
      });
    });
  });

  group('findExcerpts', () {
    test('pairs each marker with the dart block that follows it', () {
      const readme = '''
# Title

<?code-excerpt "basic_tabs.dart (readme)"?>
```dart
return 1;
```

Text.

<?code-excerpt "badges.dart (other)"?>
```dart
int x = 1;
```
''';
      final excerpts = findExcerpts(readme);
      expect(excerpts.map((e) => (e.file, e.region, e.code)), [
        ('basic_tabs.dart', 'readme', 'return 1;'),
        ('badges.dart', 'other', 'int x = 1;'),
      ]);
    });

    test('an unclosed marked block is an error', () {
      expect(
        () => findExcerpts(
          '<?code-excerpt "a.dart (readme)"?>\n```dart\nreturn 1;\n',
        ),
        throwsA(_formatError(contains('line 2'))),
      );
    });

    test('an unclosed unmarked block is an error too', () {
      expect(
        () => findExcerpts('Text.\n\n```sh\nflutter pub add x\n'),
        throwsA(_formatError(contains('line 3'))),
      );
    });

    test('a mistyped marker is an error, not an unchecked block', () {
      for (final typo in [
        '<?code-excerpt "a.dart(readme)"?>',
        '<?code-excerpt  "a.dart (readme)"?>',
        "<?code-excerpt 'a.dart (readme)'?>",
        '<?code-excerpt "a.dart (readme)">',
        '<?code-excerpt "a.dart"?>',
      ]) {
        expect(
          () => findExcerpts('$typo\n```dart\nx\n```\n'),
          throwsA(_formatError(contains('line 1'))),
          reason: typo,
        );
      }
    });
  });

  group('checkSnippets', () {
    const regions = {
      'a.dart': {'readme': 'return 1;'},
    };

    test('passes when every snippet equals its region', () {
      const readme =
          '<?code-excerpt "a.dart (readme)"?>\n```dart\nreturn 1;\n```\n';
      expect(checkSnippets(readme, regions), isEmpty);
    });

    test('reports a drifted snippet', () {
      const readme =
          '<?code-excerpt "a.dart (readme)"?>\n```dart\nreturn 2;\n```\n';
      expect(
        checkSnippets(readme, regions).single,
        contains('a.dart (readme)'),
      );
    });

    test('reports a missing file or region', () {
      const readme =
          '<?code-excerpt "b.dart (readme)"?>\n```dart\nx\n```\n'
          '<?code-excerpt "a.dart (nope)"?>\n```dart\nx\n```\n';
      expect(checkSnippets(readme, regions), hasLength(2));
    });

    test('fixSnippets rewrites drifted blocks from the regions', () {
      const readme =
          '<?code-excerpt "a.dart (readme)"?>\n```dart\nreturn 2;\n```\n';
      final fixed = fixSnippets(readme, regions);
      expect(checkSnippets(fixed, regions), isEmpty);
    });

    test('fixSnippets refuses to run when a region is missing', () {
      const readme =
          '<?code-excerpt "a.dart (readme)"?>\n```dart\nreturn 2;\n```\n'
          '<?code-excerpt "a.dart (nope)"?>\n```dart\nx\n```\n';
      expect(
        () => fixSnippets(readme, regions),
        throwsA(_formatError(contains('a.dart (nope)'))),
      );
    });
  });

  group('unusedRegions', () {
    const regions = {
      'a.dart': {'readme': 'return 1;', 'extra': 'int x;'},
      'b.dart': {'readme': 'return 2;'},
    };

    test('names every region no document marks', () {
      const readme = '<?code-excerpt "a.dart (readme)"?>\n```dart\nx\n```\n';
      const guide = '<?code-excerpt "b.dart (readme)"?>\n```dart\nx\n```\n';
      expect(unusedRegions(regions, [readme]), [
        'a.dart (extra)',
        'b.dart (readme)',
      ]);
      expect(unusedRegions(regions, [readme, guide]), ['a.dart (extra)']);
    });
  });
}

Matcher _formatError(Matcher message) => isA<FormatException>().having(
  (e) => e.message,
  'message',
  message,
);
