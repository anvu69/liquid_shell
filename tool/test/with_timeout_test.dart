import 'dart:io';

import 'package:test/test.dart';

void main() {
  final script = File('tool/with_timeout.sh').absolute.path;

  ProcessResult run(List<String> args) =>
      Process.runSync('bash', [script, ...args]);

  test('passes the exit status of a command that finishes in time', () {
    expect(run(['5', 'true']).exitCode, 0);
    expect(run(['5', 'bash', '-c', 'exit 3']).exitCode, 3);
  });

  test('a stalled command is stopped with 124 and a message', () {
    final watch = Stopwatch()..start();
    final result = run(['1', 'sleep', '60']);
    expect(result.exitCode, 124);
    expect(result.stderr as String, contains('stalled'));
    expect(watch.elapsed, lessThan(const Duration(seconds: 30)));
  });

  test('the stop also reaches the children of the command', () {
    final dir = Directory.systemTemp.createTempSync('with_timeout_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final pidFile = '${dir.path}/child.pid';
    final result = run([
      '1',
      'bash',
      '-c',
      r'sleep 60 & echo $! > "$0"; wait',
      pidFile,
    ]);
    expect(result.exitCode, 124);
    final child = File(pidFile).readAsStringSync().trim();
    expect(Process.runSync('kill', ['-0', child]).exitCode, isNot(0));
  });

  test('without a deadline and a command it prints usage and exits 2', () {
    expect(run(['5']).exitCode, 2);
  });
}
