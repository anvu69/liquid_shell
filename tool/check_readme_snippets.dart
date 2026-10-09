// Checks that every README and doc/*.md snippet equals its #docregion in
// liquid_shell/example/lib (spec §12.3, Q13).
//
// A snippet is a ```dart block right after a marker line:
//   <?code-excerpt "basic_tabs.dart (readme)"?>
// Every region must be used by at least one marker. Anything malformed (a
// mistyped marker or region line, an unclosed fence, a duplicate or stray
// region) is an error, never silently skipped.
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
final _regionLike = RegExp('#(end)?docreg');
final _fence = RegExp(r'^\s*```');

/// The named regions of a Dart [source], each dedented by its common
/// leading whitespace. Regions may nest or overlap.
Map<String, String> extractRegions(String source) {
  final regions = <String, List<String>>{};
  final open = <String>{};
  for (final (i, line) in source.split('\n').indexed) {
    final start = _open.firstMatch(line);
    final end = _close.firstMatch(line);
    if (start != null) {
      final name = start[1]!;
      if (regions.containsKey(name)) {
        throw FormatException(
          'line ${i + 1}: #docregion $name is opened a second time',
        );
      }
      open.add(name);
      regions[name] = [];
    } else if (end != null) {
      if (!open.remove(end[1])) {
        throw FormatException(
          'line ${i + 1}: #enddocregion ${end[1]} has no open region',
        );
      }
    } else if (_regionLike.hasMatch(line)) {
      throw FormatException(
        'line ${i + 1}: malformed region line "${line.trim()}" '
        '(expected "// #docregion <name>" or "// #enddocregion <name>")',
      );
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

/// Every marked ```dart block in [markdown]. Throws a [FormatException] on a
/// code fence that never closes and on a marker line that does not parse.
List<Excerpt> findExcerpts(String markdown) {
  final lines = markdown.split('\n');
  _checkFences(lines);
  final excerpts = <Excerpt>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (!line.startsWith('<?code-excerpt')) continue;
    final marker = _marker.firstMatch(line);
    if (marker == null) {
      throw FormatException(
        'line ${i + 1}: malformed marker $line '
        '(expected <?code-excerpt "file.dart (region)"?>)',
      );
    }
    if (i + 1 >= lines.length || lines[i + 1].trim() != '```dart') {
      throw FormatException(
        'marker on line ${i + 1} is not followed by ```dart',
      );
    }
    final start = i + 2;
    var end = start;
    while (lines[end].trim() != '```') {
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

void _checkFences(List<String> lines) {
  int? opened;
  for (final (i, line) in lines.indexed) {
    if (!_fence.hasMatch(line)) continue;
    if (opened == null) {
      opened = i;
    } else if (line.trim() == '```') {
      opened = null;
    }
  }
  if (opened != null) {
    throw FormatException('line ${opened + 1}: code fence is never closed');
  }
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

/// [readme] with every marked block replaced by its region. Throws a
/// [FormatException], and changes nothing, when a marker names a region
/// that does not exist.
String fixSnippets(String readme, Map<String, Map<String, String>> regions) {
  final excerpts = findExcerpts(readme);
  final missing = [
    for (final e in excerpts)
      if (regions[e.file]?[e.region] == null) '${e.file} (${e.region})',
  ];
  if (missing.isNotEmpty) {
    throw FormatException('no such #docregion: ${missing.join(', ')}');
  }
  final lines = readme.split('\n');
  for (final e in excerpts.reversed) {
    lines.replaceRange(e.start, e.end, regions[e.file]![e.region]!.split('\n'));
  }
  return lines.join('\n');
}

/// Every region in [regions] that no marker in [documents] uses, as
/// `file (region)`, sorted.
List<String> unusedRegions(
  Map<String, Map<String, String>> regions,
  Iterable<String> documents,
) {
  final used = {
    for (final document in documents)
      for (final e in findExcerpts(document)) '${e.file} (${e.region})',
  };
  return [
    for (final MapEntry(key: file, value: named) in regions.entries)
      for (final region in named.keys)
        if (!used.contains('$file ($region)')) '$file ($region)',
  ]..sort();
}

/// The regions of every Dart file under [dir], keyed by file name. Two files
/// with regions may not share a name.
Map<String, Map<String, String>> regionsUnder(Directory dir) {
  final regions = <String, Map<String, String>>{};
  final files = dir.listSync(recursive: true).whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    if (!file.path.endsWith('.dart')) continue;
    final name = file.uri.pathSegments.last;
    final Map<String, String> named;
    try {
      named = extractRegions(file.readAsStringSync());
    } on FormatException catch (e) {
      throw FormatException('${file.path}: ${e.message}');
    }
    if (named.isEmpty) continue;
    if (regions.containsKey(name)) {
      throw FormatException('two files with regions are named $name');
    }
    regions[name] = named;
  }
  return regions;
}

void main(List<String> args) {
  final root = File.fromUri(Platform.script).parent.parent.path;
  final package = '$root/liquid_shell';
  final docs = [
    File('$package/README.md'),
    ...Directory('$package/doc').listSync().whereType<File>().where(
      (f) => f.path.endsWith('.md'),
    ),
  ]..sort((a, b) => a.path.compareTo(b.path));

  void fail(List<String> problems, String hint) {
    problems.forEach(stderr.writeln);
    stderr.writeln('✗ $hint');
    exit(1);
  }

  try {
    final regions = regionsUnder(Directory('$package/example/lib'));
    final texts = {for (final doc in docs) doc: doc.readAsStringSync()};
    String name(File doc) => doc.path.substring(package.length + 1);
    if (args.contains('--fix')) {
      // Compute every rewrite first, so a bad marker writes nothing.
      final fixed = {
        for (final MapEntry(key: doc, value: text) in texts.entries)
          doc: _in(name(doc), () => fixSnippets(text, regions)),
      };
      for (final MapEntry(key: doc, value: text) in fixed.entries) {
        doc.writeAsStringSync(text);
      }
      stdout.writeln('✓ README and doc snippets rewritten from #docregion');
      return;
    }
    var count = 0;
    final problems = <String>[];
    for (final MapEntry(key: doc, value: text) in texts.entries) {
      for (final problem in _in(
        name(doc),
        () => checkSnippets(text, regions),
      )) {
        problems.add('${name(doc)}: $problem');
      }
      count += findExcerpts(text).length;
    }
    for (final unused in unusedRegions(regions, texts.values)) {
      problems.add('$unused: no README or doc snippet uses this region');
    }
    if (problems.isNotEmpty) {
      fail(
        problems,
        'README or doc snippets drifted (fix with: dart run '
        'tool/check_readme_snippets.dart --fix), or a region is unused '
        '(mark it in a snippet or delete it).',
      );
    }
    stdout.writeln('✓ $count README and doc snippets match their #docregion');
  } on FormatException catch (e) {
    fail([e.message], 'README snippet check failed');
  }
}

T _in<T>(String where, T Function() body) {
  try {
    return body();
  } on FormatException catch (e) {
    throw FormatException('$where: ${e.message}');
  }
}
