import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory repo;
  final script = File('tool/check_public_docs.sh').absolute;

  setUp(() {
    repo = Directory.systemTemp.createTempSync('public_docs_');
    Directory('${repo.path}/tool').createSync();
    script.copySync('${repo.path}/tool/check_public_docs.sh');
    Process.runSync('git', ['init', '-q'], workingDirectory: repo.path);
  });

  tearDown(() => repo.deleteSync(recursive: true));

  int run(String path, String content) {
    File('${repo.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
    return Process.runSync(
      'bash',
      ['tool/check_public_docs.sh'],
      workingDirectory: repo.path,
    ).exitCode;
  }

  const lib = 'liquid_shell/lib/src/probe.dart';

  test('a clean dartdoc passes', () {
    expect(run(lib, '/// Shows the tab bar.\nvoid f() {}\n'), 0);
  });

  for (final ref in ['(spec §7.4)', 'VK-572', 'P3b-2', 'P2', '(Q9)']) {
    test('a dartdoc with "$ref" fails', () {
      expect(run(lib, '/// The rule $ref.\nvoid f() {}\n'), 1);
    });
  }

  test('a plain // comment may keep a reference', () {
    expect(run(lib, '// VK-572: why.\nvoid f() {}\n'), 0);
  });

  test('p90, iPhone 17 Pro, API 31 and PNG pass', () {
    expect(
      run(
        'liquid_shell/README.md',
        'raster p90, iPhone 17 Pro, API 31+, PNG\n',
      ),
      0,
    );
  });

  test('a README reference fails, in any package', () {
    expect(run('liquid_shell_ios/README.md', 'See P3b.\n'), 1);
  });

  test('a doc page reference fails', () {
    expect(run('liquid_shell/doc/search.md', 'As spec §7 says.\n'), 1);
  });

  test('a CHANGELOG may keep references', () {
    expect(run('liquid_shell/CHANGELOG.md', '- Fix (VK-572).\n'), 0);
  });

  test('generated code is skipped', () {
    expect(run('liquid_shell_ios/lib/src/api.g.dart', '/// VK-1\n'), 0);
  });
}
