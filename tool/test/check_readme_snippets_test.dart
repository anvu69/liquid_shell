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
  });
}
