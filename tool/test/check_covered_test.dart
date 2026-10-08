import 'package:test/test.dart';

import '../check_covered.dart';

void main() {
  group('hasExecutableCode', () {
    test('a barrel of comments, library and exports has none', () {
      const source = '''
/// The public API.
///
/// Apps depend on this package.
library;

// A line comment.
/* A block
   comment. */
export 'src/a.dart';
export 'src/b.dart'
    show B, C
    hide D;
import 'package:x/x.dart' as x;
part 'src/c.dart';
''';
      expect(hasExecutableCode(source), isFalse);
    });

    test('an empty file has none', () {
      expect(hasExecutableCode(''), isFalse);
    });

    test('a class declaration counts', () {
      const source = '''
library;

/// Registers things.
abstract final class Registrar {
  static void registerWith() {}
}
''';
      expect(hasExecutableCode(source), isTrue);
    });

    test('a top-level function counts', () {
      expect(hasExecutableCode('void main() {}\n'), isTrue);
    });

    test('a part file with code counts', () {
      expect(hasExecutableCode("part of 'a.dart';\nconst x = 1;\n"), isTrue);
    });
  });

  group('missingFromCovered', () {
    test('lists packages with lib code that COVERED leaves out', () {
      final missing = missingFromCovered(
        {
          'barrel': ['library;\nexport "src/a.dart";\n'],
          'listed': ['class A {}'],
          'unlisted': ['library;', 'class B {}'],
        },
        covered: {'listed'},
      );
      expect(missing, ['unlisted']);
    });

    test('is empty when every package with code is covered', () {
      final missing = missingFromCovered(
        {
          'a': ['class A {}'],
          'b': ['library;'],
        },
        covered: {'a'},
      );
      expect(missing, isEmpty);
    });
  });
}
