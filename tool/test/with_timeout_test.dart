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

  // CI cancels a job with SIGINT then SIGTERM, and a developer presses
  // Ctrl-C. The command runs in its own process group, so neither signal
  // reaches it unless the wrapper passes it on.
  for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
    test('$signal to the wrapper stops the command and its children', () async {
      final dir = Directory.systemTemp.createTempSync('with_timeout_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final pidFile = File('${dir.path}/child.pid');
      final wrapper = await Process.start('bash', [
        script,
        '60',
        'bash',
        '-c',
        r'sleep 60 & echo $! > "$0"; wait',
        pidFile.path,
      ]);
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (!pidFile.existsSync() || pidFile.readAsStringSync().isEmpty) {
        if (DateTime.now().isAfter(deadline)) fail('the command never started');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      final child = pidFile.readAsStringSync().trim();
      addTearDown(() => Process.runSync('kill', ['-KILL', child]));

      wrapper.kill(signal);
      final code = await wrapper.exitCode.timeout(const Duration(seconds: 15));
      expect(code, isNot(0));
      expect(
        Process.runSync('kill', ['-0', child]).exitCode,
        isNot(0),
        reason: 'the child of the command must not outlive the wrapper',
      );
    });
  }

  test('without a deadline and a command it prints usage and exits 2', () {
    expect(run(['5']).exitCode, 2);
  });
}
