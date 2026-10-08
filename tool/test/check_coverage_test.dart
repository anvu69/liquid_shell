import 'package:test/test.dart';

import '../check_coverage.dart';
import '../gen_coverage_helper.dart';

void main() {
  group('LineCoverage.parse', () {
    test('sums LF and LH over every record', () {
      const lcov = '''
SF:lib/a.dart
DA:1,1
LF:10
LH:9
end_of_record
SF:lib/b.dart
LF:30
LH:21
end_of_record
''';
      final coverage = LineCoverage.parse(lcov);
      expect(coverage.found, 40);
      expect(coverage.hit, 30);
      expect(coverage.percent, 75);
    });

    test('an empty report instruments nothing and never passes', () {
      final coverage = LineCoverage.parse('');
      expect(coverage.isEmpty, isTrue);
      expect(coverage.meets(0), isFalse);
    });

    test('a report with only non-lib records is empty too', () {
      const lcov = 'SF:test/helper.dart\nLF:10\nLH:10\nend_of_record\n';
      expect(LineCoverage.parse(lcov).meets(0), isFalse);
    });

    test('ignores records outside lib/', () {
      const lcov = '''
SF:test/helper.dart
LF:10
LH:0
end_of_record
SF:lib/a.dart
LF:4
LH:4
end_of_record
''';
      expect(LineCoverage.parse(lcov).percent, 100);
    });
  });

  group('renderCoverageHelper', () {
    test('imports every lib file by package URI, sorted', () {
      final source = renderCoverageHelper('pkg', [
        'lib/src/b.dart',
        'lib/pkg.dart',
        'lib/src/a.dart',
      ]);
      final imports = RegExp(
        r"import 'package:[^']+' as _i\d+;",
      ).allMatches(source).map((m) => m.group(0)).toList();
      expect(imports, [
        "import 'package:pkg/pkg.dart' as _i0;",
        "import 'package:pkg/src/a.dart' as _i1;",
        "import 'package:pkg/src/b.dart' as _i2;",
      ]);
    });

    test('has a main so flutter test accepts it', () {
      expect(
        renderCoverageHelper('pkg', ['lib/a.dart']),
        contains('void main'),
      );
    });
  });

  group('LineCoverage.meets', () {
    test('is inclusive of the floor', () {
      const coverage = LineCoverage(found: 10, hit: 9);
      expect(coverage.meets(90), isTrue);
      expect(coverage.meets(90.1), isFalse);
    });
  });
}
