// `make analyze-stable`: static analysis for CI's latest-stable leg (VK-1076).
//
// Runs `dart analyze --format=machine` with the SDK that runs this script
// and fails on every error, every warning and every info, except two info
// classes that only the newer SDK reports and that cannot be fixed without
// breaking the 3.44 floor:
//
// - R1: `deprecated_member_use` of `package:flutter/material.dart` or
//   `package:flutter/cupertino.dart` (Flutter 3.50 moves them to
//   material_ui / cupertino_ui). Exit: VK-1077.
// - R2: `unnecessary_ignore` of `avoid_positional_boolean_parameters` (the
//   3.50 linter no longer reports it where 3.44 and 3.47 still do).
//   Exit: VK-1078.
//
// Each tolerated issue is printed. `make analyze` (the floor, `make verify`,
// the pre-commit hook) keeps `--fatal-infos` and knows nothing of this list.
//
// Usage: dart run tool/check_analyze.dart <path>...
import 'dart:io';

/// One issue line of `dart analyze --format=machine`:
/// `SEVERITY|TYPE|CODE|PATH|LINE|COLUMN|LENGTH|MESSAGE`, with `|` and `\`
/// escaped by a backslash.
class AnalyzerIssue {
  /// Creates an issue from its fields.
  const AnalyzerIssue({
    required this.severity,
    required this.type,
    required this.code,
    required this.path,
    required this.line,
    required this.column,
    required this.message,
  });

  /// Parses one machine line, or returns null when [text] is not one.
  static AnalyzerIssue? tryParse(String text) {
    final fields = <String>[];
    final field = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == r'\' && i + 1 < text.length) {
        field.write(text[++i]);
      } else if (char == '|') {
        fields.add(field.toString());
        field.clear();
      } else {
        field.write(char);
      }
    }
    fields.add(field.toString());
    if (fields.length != 8) return null;
    final line = int.tryParse(fields[4]);
    final column = int.tryParse(fields[5]);
    if (line == null || column == null) return null;
    if (!const {'ERROR', 'WARNING', 'INFO'}.contains(fields[0])) return null;
    return AnalyzerIssue(
      severity: fields[0],
      type: fields[1],
      code: fields[2].toLowerCase(),
      path: fields[3],
      line: line,
      column: column,
      message: fields[7],
    );
  }

  /// `ERROR`, `WARNING` or `INFO`.
  final String severity;

  /// The diagnostic type (`HINT`, `LINT`, `COMPILE_TIME_ERROR`, …).
  final String type;

  /// The diagnostic code in lower case, as `analysis_options.yaml` names it.
  final String code;

  /// The file the issue is in.
  final String path;

  /// 1-based line.
  final int line;

  /// 1-based column.
  final int column;

  /// The analyzer's message, unescaped.
  final String message;

  /// `path:line:column`.
  String get location => '$path:$line:$column';

  @override
  String toString() => '$severity $code $location: $message';
}

final _sdkUiLibrary = RegExp(
  r"^'package:flutter/(material|cupertino)\.dart' is deprecated",
);

/// Why [issue] is tolerated on the stable leg, or null when it blocks.
/// Only infos are ever tolerated.
String? toleratedBecause(AnalyzerIssue issue) {
  if (issue.severity != 'INFO') return null;
  if (issue.code == 'deprecated_member_use' &&
      _sdkUiLibrary.hasMatch(issue.message)) {
    return 'R1, VK-1077';
  }
  if (issue.code == 'unnecessary_ignore' &&
      issue.message.contains("'avoid_positional_boolean_parameters'")) {
    return 'R2, VK-1078';
  }
  return null;
}

/// The verdict on one analyzer run.
class AnalyzeReport {
  /// Creates a report from its parts.
  const AnalyzeReport({
    required this.blocking,
    required this.tolerated,
    required this.unparsed,
    required this.exitCode,
  });

  /// Issues that fail the run.
  final List<AnalyzerIssue> blocking;

  /// Allowlisted issues, printed but not failing.
  final List<AnalyzerIssue> tolerated;

  /// Non-blank output lines that are not issues (a crash, a usage error).
  final List<String> unparsed;

  /// The analyzer's exit code.
  final int exitCode;

  /// Whether nothing blocks, every line parsed and the analyzer exited 0.
  bool get passed => blocking.isEmpty && unparsed.isEmpty && exitCode == 0;

  /// The lines to print: each tolerated and blocking issue, then a summary.
  String render() {
    final counts = '${blocking.length} blocking, ${tolerated.length} tolerated';
    final out = <String>[
      for (final issue in tolerated)
        '~ tolerated (${toleratedBecause(issue)}) ${_describe(issue)}',
      for (final issue in blocking) '✗ ${issue.severity} ${_describe(issue)}',
      for (final line in unparsed) '✗ unexpected analyzer output: $line',
      if (exitCode != 0 && blocking.isEmpty)
        '✗ dart analyze exited $exitCode without reporting a blocking issue',
      if (passed) '✓ analyze-stable: $counts' else '✗ analyze-stable: $counts',
    ];
    return out.join('\n');
  }

  static String _describe(AnalyzerIssue issue) =>
      '${issue.code} ${issue.location}: ${issue.message}';
}

/// Judges the machine [output] of `dart analyze` that exited [exitCode].
AnalyzeReport judgeAnalyze(String output, {required int exitCode}) {
  final blocking = <AnalyzerIssue>[];
  final tolerated = <AnalyzerIssue>[];
  final unparsed = <String>[];
  for (final line in output.split('\n')) {
    if (line.trim().isEmpty) continue;
    final issue = AnalyzerIssue.tryParse(line);
    if (issue == null) {
      unparsed.add(line);
    } else if (toleratedBecause(issue) != null) {
      tolerated.add(issue);
    } else {
      blocking.add(issue);
    }
  }
  return AnalyzeReport(
    blocking: blocking,
    tolerated: tolerated,
    unparsed: unparsed,
    exitCode: exitCode,
  );
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('usage: check_analyze.dart <path>...');
    exit(64);
  }
  // The `dart` that runs this script, so `make DART=...` picks the SDK.
  final result = await Process.run(Platform.resolvedExecutable, [
    'analyze',
    '--format=machine',
    ...args,
  ]);
  final report = judgeAnalyze(
    '${result.stdout}\n${result.stderr}',
    exitCode: result.exitCode,
  );
  stdout.writeln(report.render());
  exit(report.passed ? 0 : 1);
}
