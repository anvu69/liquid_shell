// Checks that every README snippet equals its #docregion in
// liquid_shell/example/lib/cases (spec §12.3, Q13).
//
// A snippet is a ```dart block right after a marker line:
//   <?code-excerpt "basic_tabs.dart (readme)"?>
// Usage: dart run tool/check_readme_snippets.dart [--fix]
import 'dart:io';

/// One README snippet and where it claims to come from.
typedef Excerpt = ({
  String file,
  String region,
  String code,
  int start,
  int end,
});

final _marker = RegExp(r'^<\?code-excerpt "([^" ]+) \(([^)]+)\)"\?>$');
final _open = RegExp(r'^\s*// #docregion (\S+)\s*$');
final _close = RegExp(r'^\s*// #enddocregion (\S+)\s*$');

/// The named regions of a Dart [source], each dedented by its common
/// leading whitespace.
Map<String, String> extractRegions(String source) {
  final regions = <String, List<String>>{};
  final open = <String>{};
  for (final line in source.split('\n')) {
    final start = _open.firstMatch(line);
    final end = _close.firstMatch(line);
    if (start != null) {
      open.add(start[1]!);
      regions[start[1]!] = [];
    } else if (end != null) {
      open.remove(end[1]);
    } else {
      for (final name in open) {
        regions[name]!.add(line);
      }
    }
  }
  if (open.isNotEmpty) {
    throw FormatException('unterminated #docregion ${open.join(', ')}');
  }
  return {for (final e in regions.entries) e.key: _dedent(e.value)};
}

String _dedent(List<String> lines) {
  final indents = [
    for (final line in lines)
      if (line.trim().isNotEmpty) line.length - line.trimLeft().length,
  ];
  final cut = indents.isEmpty ? 0 : indents.reduce((a, b) => a < b ? a : b);
  return lines
      .map((l) => l.trim().isEmpty ? '' : l.substring(cut))
      .join('\n')
      .trim();
}

/// Every marked ```dart block in [markdown].
List<Excerpt> findExcerpts(String markdown) {
  final lines = markdown.split('\n');
  final excerpts = <Excerpt>[];
  for (var i = 0; i < lines.length; i++) {
    final marker = _marker.firstMatch(lines[i].trim());
    if (marker == null) continue;
    if (i + 1 >= lines.length || lines[i + 1].trim() != '```dart') {
      throw FormatException(
        'marker on line ${i + 1} is not followed by ```dart',
      );
    }
    final start = i + 2;
    var end = start;
    while (end < lines.length && lines[end].trim() != '```') {
      end++;
    }
    excerpts.add((
      file: marker[1]!,
      region: marker[2]!,
      code: lines.sublist(start, end).join('\n').trim(),
      start: start,
      end: end,
    ));
    i = end;
  }
  return excerpts;
}

/// Problems found in [readme] against [regions] (file → region → code).
List<String> checkSnippets(
  String readme,
  Map<String, Map<String, String>> regions,
) {
  final problems = <String>[];
  for (final e in findExcerpts(readme)) {
    final code = regions[e.file]?[e.region];
    if (code == null) {
      problems.add('${e.file} (${e.region}): no such #docregion');
    } else if (code != e.code) {
      problems.add('${e.file} (${e.region}): README snippet differs');
    }
  }
  return problems;
}

/// [readme] with every marked block replaced by its region.
String fixSnippets(String readme, Map<String, Map<String, String>> regions) {
  final lines = readme.split('\n');
  for (final e in findExcerpts(readme).reversed) {
    final code = regions[e.file]?[e.region];
    if (code == null) continue;
    lines.replaceRange(e.start, e.end, code.split('\n'));
  }
  return lines.join('\n');
}

void main(List<String> args) {
  final root = File.fromUri(Platform.script).parent.parent.path;
  final casesDir = Directory('$root/liquid_shell/example/lib/cases');
  final readmeFile = File('$root/liquid_shell/README.md');
  final regions = {
    for (final file in casesDir.listSync().whereType<File>())
      if (file.path.endsWith('.dart'))
        file.uri.pathSegments.last: extractRegions(file.readAsStringSync()),
  };
  final readme = readmeFile.readAsStringSync();
  if (args.contains('--fix')) {
    readmeFile.writeAsStringSync(fixSnippets(readme, regions));
    stdout.writeln('✓ README snippets rewritten from #docregion');
    return;
  }
  final problems = checkSnippets(readme, regions);
  final count = findExcerpts(readme).length;
  if (problems.isNotEmpty) {
    problems.forEach(stderr.writeln);
    stderr.writeln(
      '✗ README snippets drifted. Run: dart run '
      'tool/check_readme_snippets.dart --fix',
    );
    exit(1);
  }
  stdout.writeln('✓ $count README snippets match their #docregion');
}
