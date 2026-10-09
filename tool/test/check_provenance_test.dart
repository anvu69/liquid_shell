import 'dart:io';

import 'package:test/test.dart';

void main() {
  late Directory repo;
  final script = File('tool/check_provenance.sh').absolute;

  setUp(() {
    repo = Directory.systemTemp.createTempSync('provenance_');
    Directory('${repo.path}/tool').createSync();
    script.copySync('${repo.path}/tool/check_provenance.sh');
    Process.runSync('git', ['init', '-q'], workingDirectory: repo.path);
  });

  tearDown(() => repo.deleteSync(recursive: true));

  int run(String content) {
    File('${repo.path}/probe.dart').writeAsStringSync(content);
    return Process.runSync(
      'bash',
      ['tool/check_provenance.sh'],
      workingDirectory: repo.path,
    ).exitCode;
  }

  test('identifiers that merely contain "getit" pass', () {
    expect(run('final widgetItem = 1; var budgetItems; int targetItem;'), 0);
  });

  test('GetIt as a whole word fails', () {
    expect(run('final i = GetIt.I;'), 1);
  });

  test('other banned names still match case-insensitively', () {
    expect(run('// from VanKhan'), 1);
    expect(run('// from VANKHAN'), 1);
    expect(run('import "easy_localization";'), 1);
  });
}
