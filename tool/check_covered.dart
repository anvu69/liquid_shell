// Fails when a package whose lib/ has executable code is missing from the
// Makefile's COVERED list. A barrel-only package (comments, `library;`,
// directives) instruments no lines, so it is allowed to stay out; anything
// more must join the coverage gate (spec Q14).
//
// Usage: dart run tool/check_covered.dart "<PACKAGES>" "<COVERED>"
//        (each argument a space-separated list of package directories)
import 'dart:io';

final _blockComment = RegExp(r'/\*.*?\*/', dotAll: true);
final _lineComment = RegExp(r'//[^\n]*');
final _directive = RegExp(r'\b(library|import|export|part)\b[^;]*;');

/// Whether a Dart [source] holds more than comments and directives
/// (`library`, `import`, `export`, `part`, `part of`).
bool hasExecutableCode(String source) => source
    .replaceAll(_blockComment, '')
    .replaceAll(_lineComment, '')
    .replaceAll(_directive, '')
    .trim()
    .isNotEmpty;

/// The packages of [libSources] (package → sources of its lib/ files) that
/// have executable code but are not in [covered], in input order.
List<String> missingFromCovered(
  Map<String, List<String>> libSources, {
  required Set<String> covered,
}) => [
  for (final MapEntry(key: package, value: sources) in libSources.entries)
    if (!covered.contains(package) && sources.any(hasExecutableCode)) package,
];

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('usage: check_covered.dart "<PACKAGES>" "<COVERED>"');
    exit(64);
  }
  List<String> words(String s) =>
      s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final libSources = {
    for (final package in words(args[0]))
      package: [
        if (Directory('$package/lib').existsSync())
          for (final file in Directory(
            '$package/lib',
          ).listSync(recursive: true))
            if (file is File && file.path.endsWith('.dart'))
              file.readAsStringSync(),
      ],
  };
  final missing = missingFromCovered(
    libSources,
    covered: words(args[1]).toSet(),
  );
  if (missing.isNotEmpty) {
    stderr.writeln(
      '✗ coverage: ${missing.join(', ')} '
      '${missing.length == 1 ? 'has' : 'have'} lib/ code but '
      '${missing.length == 1 ? 'is' : 'are'} not in COVERED (Makefile)',
    );
    exit(1);
  }
  stdout.writeln('✓ every package with lib/ code is in COVERED');
}
