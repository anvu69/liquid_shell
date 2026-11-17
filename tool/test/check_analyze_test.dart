import 'package:test/test.dart';

import '../check_analyze.dart';

// Lines as `dart analyze --format=machine` prints them (captured on Flutter
// 3.50.0, paths shortened).
const _material =
    "INFO|HINT|DEPRECATED_MEMBER_USE|/r/liquid_shell/example/lib/a.dart|5|1|39|'package:flutter/material.dart' is deprecated and shouldn't be used. Use package:material_ui/material_ui.dart instead. This feature was deprecated after v3.47.0-0.0.pre.";
const _cupertino =
    "INFO|HINT|DEPRECATED_MEMBER_USE|/r/liquid_shell/test/b_test.dart|3|1|40|'package:flutter/cupertino.dart' is deprecated and shouldn't be used. Use package:cupertino_ui/cupertino_ui.dart instead. This feature was deprecated after v3.47.0-0.0.pre.";
const _ignore =
    "INFO|LINT|UNNECESSARY_IGNORE|/r/tool/pigeon/pigeons/native_shell.dart|13|21|35|The diagnostic 'avoid_positional_boolean_parameters' isn't produced in this file so it doesn't need to be ignored.";
const _otherDeprecated =
    "INFO|HINT|DEPRECATED_MEMBER_USE|/r/liquid_shell/lib/c.dart|9|3|12|'withOpacity' is deprecated and shouldn't be used. Use .withValues() to avoid precision loss.";
const _otherIgnore =
    "INFO|LINT|UNNECESSARY_IGNORE|/r/liquid_shell/lib/d.dart|2|4|20|The diagnostic 'unused_element' isn't produced at this location so it doesn't need to be ignored.";
const _otherInfo =
    'INFO|LINT|PREFER_CONST_CONSTRUCTORS|/r/liquid_shell/lib/e.dart|7|5|10|Use const with the constructor to improve performance.';
const _warning =
    'WARNING|STATIC_WARNING|DEAD_CODE|/r/liquid_shell/lib/f.dart|4|1|8|Dead code.';
const _error =
    "ERROR|COMPILE_TIME_ERROR|URI_DOES_NOT_EXIST|/r/liquid_shell/lib/g.dart|1|8|30|Target of URI doesn't exist: 'package:x/x.dart'.";

const _goRouterExample = '/r/liquid_shell/example_go_router/lib/y.dart';
const _nativeChrome =
    '/r/liquid_shell_platform_interface/lib/src/native_chrome.dart';

/// [line] with its path field replaced by [path].
String _at(String line, String path) {
  final fields = line.split('|');
  fields[3] = path;
  return fields.join('|');
}

AnalyzeReport _judge(List<String> lines, {int exitCode = 0}) =>
    judgeAnalyze(lines.join('\n'), exitCode: exitCode);

void main() {
  group('AnalyzerIssue.tryParse', () {
    test('reads every field of a machine line', () {
      final issue = AnalyzerIssue.tryParse(_ignore)!;
      expect(issue.severity, 'INFO');
      expect(issue.code, 'unnecessary_ignore');
      expect(issue.path, '/r/tool/pigeon/pigeons/native_shell.dart');
      expect(issue.line, 13);
      expect(issue.column, 21);
      expect(issue.message, startsWith("The diagnostic 'avoid_positional"));
    });

    test(r'unescapes \| and \\ in the message', () {
      final issue = AnalyzerIssue.tryParse(
        r'INFO|LINT|SOME_LINT|/r/a.dart|1|1|1|a \| b \\ c',
      )!;
      expect(issue.message, r'a | b \ c');
    });

    test('returns null for a line that is not an issue', () {
      expect(AnalyzerIssue.tryParse('Analyzing tool...'), isNull);
      expect(AnalyzerIssue.tryParse('INFO|LINT|X|/r/a.dart|one|1|1|m'), isNull);
    });
  });

  group('judgeAnalyze', () {
    test('no output and exit 0 passes', () {
      expect(_judge([]).passed, isTrue);
    });

    test('an error fails', () {
      expect(_judge([_error], exitCode: 3).passed, isFalse);
    });

    test('a warning fails', () {
      expect(_judge([_warning], exitCode: 2).passed, isFalse);
    });

    test('an info outside the allowlist fails', () {
      final report = _judge([_otherInfo]);
      expect(report.passed, isFalse);
      expect(report.blocking.single.code, 'prefer_const_constructors');
    });

    test('the deprecated material library in an example is tolerated', () {
      final report = _judge([_material]);
      expect(report.passed, isTrue);
      expect(report.tolerated, hasLength(1));
      expect(
        toleratedBecause(report.tolerated.single),
        'R1, VK-1077 (examples: README)',
      );
    });

    test('the deprecated material library in example_go_router is '
        'tolerated', () {
      expect(_judge([_at(_material, _goRouterExample)]).passed, isTrue);
    });

    test('the deprecated material library in lib/ fails', () {
      expect(
        _judge([_at(_material, '/r/liquid_shell/lib/a.dart')]).passed,
        isFalse,
      );
    });

    test('the deprecated cupertino library in test/ fails', () {
      expect(_judge([_cupertino]).passed, isFalse);
    });

    test('a directory that only starts like an example fails', () {
      expect(
        _judge([
          _at(_material, '/r/liquid_shell/example_extra/lib/z.dart'),
        ]).passed,
        isFalse,
      );
    });

    test('an unnecessary avoid_positional_boolean_parameters ignore in the '
        'Pigeon source is tolerated', () {
      final report = _judge([_ignore]);
      expect(report.passed, isTrue);
      expect(
        toleratedBecause(report.tolerated.single),
        'R2, VK-1078 (floor < Dart 3.14)',
      );
    });

    test('the same ignore in the platform interface event is tolerated', () {
      expect(_judge([_at(_ignore, _nativeChrome)]).passed, isTrue);
    });

    test('the same ignore anywhere else fails', () {
      for (final path in [
        '/r/liquid_shell/lib/src/chrome/lens_motion.dart',
        '/r/liquid_shell/test/widget/shell_chrome_test.dart',
        '/r/liquid_shell_platform_interface/lib/src/other.dart',
      ]) {
        expect(_judge([_at(_ignore, path)]).passed, isFalse, reason: path);
      }
    });

    test('any other deprecated API fails', () {
      expect(_judge([_material, _otherDeprecated]).passed, isFalse);
    });

    test('an unnecessary ignore of another lint fails', () {
      expect(_judge([_ignore, _otherIgnore]).passed, isFalse);
    });

    test('an allowlisted message at warning severity fails', () {
      expect(
        _judge([
          _material.replaceFirst('INFO|', 'WARNING|'),
        ], exitCode: 2).passed,
        isFalse,
      );
    });

    test('a non-zero exit without a blocking issue fails', () {
      final report = _judge([_material], exitCode: 64);
      expect(report.passed, isFalse);
      expect(report.render(), contains('64'));
    });

    test('a line it cannot parse fails', () {
      final report = _judge([_material, 'Unhandled exception: boom']);
      expect(report.passed, isFalse);
      expect(report.unparsed, ['Unhandled exception: boom']);
    });

    test('blank lines are ignored', () {
      expect(_judge(['', _material, '  ']).passed, isTrue);
    });
  });

  group('AnalyzeReport.render', () {
    test('prints one line per tolerated issue, then a count', () {
      final text = _judge([
        _material,
        _at(_material, _goRouterExample),
        _ignore,
      ]).render();
      final lines = text.split('\n');
      expect(
        lines.where((l) => l.startsWith('~ tolerated')),
        hasLength(3),
      );
      expect(text, contains('/r/liquid_shell/example/lib/a.dart:5:1'));
      expect(text, contains('/r/tool/pigeon/pigeons/native_shell.dart:13:21'));
      expect(text, contains('3 tolerated'));
      expect(text, contains('✓'));
    });

    test('prints each blocking issue with its location and code', () {
      final text = _judge([_error, _material], exitCode: 3).render();
      expect(text, contains('✗ ERROR uri_does_not_exist'));
      expect(text, contains('/r/liquid_shell/lib/g.dart:1:8'));
      expect(text, contains('1 blocking'));
    });
  });
}
