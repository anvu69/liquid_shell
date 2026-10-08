// Fails when line coverage of lib/ in an lcov report is below a floor.
//
// Usage: dart run tool/check_coverage.dart <lcov.info> <min-percent>
import 'dart:io';

/// Line coverage summed over the `lib/` records of an lcov report.
class LineCoverage {
  /// Creates a coverage summary from raw counts.
  const LineCoverage({required this.found, required this.hit});

  /// Parses an lcov report. Records whose `SF:` path has no `lib/` segment
  /// (test helpers, generated test files) are ignored.
  factory LineCoverage.parse(String lcov) {
    var found = 0;
    var hit = 0;
    var inLib = false;
    for (final line in lcov.split('\n')) {
      if (line.startsWith('SF:')) {
        final path = line.substring(3).replaceAll(r'\', '/');
        inLib = path.startsWith('lib/') || path.contains('/lib/');
      } else if (inLib && line.startsWith('LF:')) {
        found += int.parse(line.substring(3));
      } else if (inLib && line.startsWith('LH:')) {
        hit += int.parse(line.substring(3));
      }
    }
    return LineCoverage(found: found, hit: hit);
  }

  /// Instrumented lines.
  final int found;

  /// Lines executed at least once.
  final int hit;

  /// Percentage of [found] lines that were hit. 100 when nothing is
  /// instrumented.
  double get percent => found == 0 ? 100 : hit * 100 / found;

  /// Whether [percent] is at least [floor].
  bool meets(double floor) => percent >= floor;
}

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('usage: check_coverage.dart <lcov.info> <min-percent>');
    exit(64);
  }
  final file = File(args[0]);
  if (!file.existsSync()) {
    stderr.writeln('✗ ${args[0]} not found. Run flutter test --coverage.');
    exit(1);
  }
  final floor = double.parse(args[1]);
  final coverage = LineCoverage.parse(file.readAsStringSync());
  final summary =
      '${coverage.percent.toStringAsFixed(2)}% '
      '(${coverage.hit}/${coverage.found} lines) in ${args[0]}';
  if (!coverage.meets(floor)) {
    stderr.writeln('✗ coverage $summary is below $floor%');
    exit(1);
  }
  stdout.writeln('✓ coverage $summary ≥ $floor%');
}
