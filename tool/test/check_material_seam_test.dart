import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory repo;
  final script = File('tool/check_material_seam.sh').absolute;

  setUp(() {
    repo = Directory.systemTemp.createTempSync('material_seam_');
    Directory('${repo.path}/tool').createSync();
    for (final dir in ['lib/src', 'test', 'example/lib']) {
      Directory('${repo.path}/liquid_shell/$dir').createSync(recursive: true);
    }
    script.copySync('${repo.path}/tool/check_material_seam.sh');
    Process.runSync('git', ['init', '-q'], workingDirectory: repo.path);
  });

  tearDown(() => repo.deleteSync(recursive: true));

  int run(String path, String content) {
    File('${repo.path}/$path').writeAsStringSync(content);
    return Process.runSync('bash', [
      'tool/check_material_seam.sh',
    ], workingDirectory: repo.path).exitCode;
  }

  const material = "import 'package:flutter/material.dart';\n";

  test('an empty tree passes', () {
    expect(run('liquid_shell/lib/src/x.dart', 'void f() {}\n'), 0);
  });

  test('the SDK material import in lib fails', () {
    expect(run('liquid_shell/lib/src/x.dart', material), 1);
  });

  test('the SDK material import in test fails', () {
    expect(run('liquid_shell/test/x_test.dart', material), 1);
  });

  test('the SDK cupertino import fails', () {
    expect(
      run(
        'liquid_shell/test/x_test.dart',
        'import "package:flutter/cupertino.dart" as c;\n',
      ),
      1,
    );
  });

  test('an export of the SDK material library fails', () {
    expect(
      run(
        'liquid_shell/lib/src/x.dart',
        "  export 'package:flutter/material.dart' show Theme;\n",
      ),
      1,
    );
  });

  test('the barrel exporting src/material files passes', () {
    expect(
      run(
        'liquid_shell/lib/src/material_sdk.dart',
        "export 'package:flutter/src/material/theme.dart';\n"
            "export 'package:flutter/widgets.dart';\n",
      ),
      0,
    );
  });

  test('an example app keeps the SDK import', () {
    expect(run('liquid_shell/example/lib/main.dart', material), 0);
  });

  test('a comment or a dartdoc snippet naming the import passes', () {
    expect(
      run(
        'liquid_shell/lib/src/x.dart',
        '// Not $material'
            '/// ```dart\n/// $material/// ```\n',
      ),
      0,
    );
  });
}
