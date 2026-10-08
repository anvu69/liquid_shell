import 'package:test/test.dart';

import '../check_coverage.dart';

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

    test('an empty report is 100 percent (nothing to cover)', () {
      expect(LineCoverage.parse('').percent, 100);
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

  group('LineCoverage.meets', () {
    test('is inclusive of the floor', () {
      const coverage = LineCoverage(found: 10, hit: 9);
      expect(coverage.meets(90), isTrue);
      expect(coverage.meets(90.1), isFalse);
    });
  });
}
