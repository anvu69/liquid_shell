import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory repo;
  final script = File('tool/check_glass_seam.sh').absolute;

  setUp(() {
    repo = Directory.systemTemp.createTempSync('glass_seam_');
    Directory('${repo.path}/tool').createSync();
    Directory(
      '${repo.path}/liquid_shell/lib/src/glass',
    ).createSync(recursive: true);
    Directory('${repo.path}/liquid_shell/lib/src/chrome').createSync();
    script.copySync('${repo.path}/tool/check_glass_seam.sh');
    Process.runSync('git', ['init', '-q'], workingDirectory: repo.path);
  });

  tearDown(() => repo.deleteSync(recursive: true));

  int run(String path, String content) {
    File('${repo.path}/$path').writeAsStringSync(content);
    return Process.runSync('bash', [
      'tool/check_glass_seam.sh',
    ], workingDirectory: repo.path).exitCode;
  }

  test('a backdrop filter inside lib/src/glass/ passes', () {
    expect(
      run('liquid_shell/lib/src/glass/x.dart', 'BackdropFilter(filter: f)'),
      0,
    );
  });

  test('a backdrop filter elsewhere in lib fails', () {
    expect(
      run('liquid_shell/lib/src/chrome/x.dart', 'BackdropFilter(filter: f)'),
      1,
    );
  });

  test('ImageFilter.blur, .shader and .compose elsewhere fail', () {
    for (final call in ['blur', 'shader', 'compose']) {
      expect(
        run('liquid_shell/lib/src/chrome/x.dart', 'ImageFilter.$call(a)'),
        1,
        reason: call,
      );
    }
  });

  test('BackdropGroup is allowed', () {
    expect(
      run('liquid_shell/lib/src/chrome/x.dart', 'BackdropGroup(child: c)'),
      0,
    );
  });
}
