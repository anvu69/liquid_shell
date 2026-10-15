import 'dart:io';

import 'package:test/test.dart';

import 'fake_sim.dart';

// tool/ios_sim.sh against fake simulator tools (spec VK-625 §5, §12).
void main() {
  const script = 'tool/ios_sim.sh';
  const udid = 'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE';
  late FakeSim sim;

  setUp(() => sim = FakeSim());
  tearDown(() => sim.delete());

  group('warmup', () {
    test('boots, installs, launches once, waits for the VM service line '
        'and terminates', () {
      final r = sim.run(
        script,
        ['warmup', udid, '/apps/Runner.app'],
        env: {'FAKE_VM_DELAY': '1'},
      );
      expect(r.exitCode, 0, reason: outputOf(r));
      expect(outputOf(r), contains('ios_sim: warm-up ok after'));
      sim.expectInOrder([
        'simctl boot $udid',
        'simctl bootstatus $udid -b',
        'simctl install $udid /apps/Runner.app',
        'log stream',
        'simctl launch $udid vn.lasoai.liquidShellExample',
        'simctl terminate $udid vn.lasoai.liquidShellExample',
      ]);
      expect(sim.callsWith('simctl launch'), hasLength(1));
      expect(sim.dumps, isEmpty);
    });

    test('without an app it launches the one installed', () {
      final r = sim.run(
        script,
        ['warmup', udid],
        env: {'FAKE_VM_DELAY': '0'},
      );
      expect(r.exitCode, 0);
      expect(sim.callsWith('simctl install'), isEmpty);
      expect(sim.callsWith('simctl launch'), hasLength(1));
    });

    test('a launch with no VM service line in time is diagnosed and '
        'still exits 0', () {
      final watch = Stopwatch()..start();
      final r = sim.run(
        script,
        ['warmup', udid],
        env: {'IOS_WARMUP_TIMEOUT': '2'},
      );
      expect(r.exitCode, 0, reason: outputOf(r));
      expect(outputOf(r), contains('ios_sim: warm-up timeout after 2s'));
      expect(watch.elapsed, lessThan(const Duration(seconds: 60)));
      expect(sim.dumps, hasLength(1));
      expect(sim.dumps.single.path, endsWith('-warm-up'));
      // The dump sees the app before it is terminated.
      sim.expectInOrder(['sample 4242 5', 'simctl terminate']);
    });

    test('on GitHub Actions a timeout is an annotation', () {
      final r = sim.run(
        script,
        ['warmup', udid],
        env: {'IOS_WARMUP_TIMEOUT': '1', 'GITHUB_ACTIONS': 'true'},
      );
      expect(
        r.stdout as String,
        contains('::warning::ios_sim: warm-up timeout after 1s'),
      );
    });

    test('a failed launch is reported and never fails the job', () {
      final r = sim.run(
        script,
        ['warmup', udid],
        env: {'FAKE_LAUNCH_FAILS': '1'},
      );
      expect(r.exitCode, 0);
      expect(outputOf(r), contains('ios_sim: warm-up skipped'));
      expect(sim.dumps, isEmpty);
    });
  });

  group('diagnose', () {
    test('writes the VM service log, the launchd entry, a sample and '
        'timestamps', () {
      final r = sim.run(script, ['diagnose', udid, 'drive 1 stall']);
      expect(r.exitCode, 0, reason: outputOf(r));
      final dump = sim.dumps.single;
      expect(dump.path, endsWith('-drive_1_stall'));
      String read(String name) => File('${dump.path}/$name').readAsStringSync();
      expect(read('vm-service.log'), contains('Dart VM service is listening'));
      expect(read('launchctl.txt'), contains('4242'));
      expect(read('sample.txt'), contains('FAKE SAMPLE'));
      expect(read('meta.txt'), contains('dump started: 20'));
      expect(read('meta.txt'), contains('dump finished: 20'));
      expect(sim.callsWith('log show --last 15m'), hasLength(1));
      expect(sim.callsWith('sample 4242 5'), hasLength(1));
    });

    test('an app that is not running is not sampled', () {
      final r = sim.run(
        script,
        ['diagnose', udid, 'x'],
        env: {'FAKE_LAUNCHCTL': ''},
      );
      expect(r.exitCode, 0);
      expect(sim.callsWith('sample'), isEmpty);
      expect(
        File('${sim.dumps.single.path}/sample.txt').readAsStringSync(),
        contains('not running'),
      );
    });

    test('a window widens the log', () {
      sim.run(script, ['diagnose', udid, 'x', '25m']);
      expect(sim.callsWith('log show --last 25m'), hasLength(1));
    });
  });

  test('a wrong call prints usage and exits 2', () {
    expect(sim.run(script, []).exitCode, 2);
    expect(sim.run(script, ['warmup']).exitCode, 2);
    expect(sim.run(script, ['nope', udid]).exitCode, 2);
  });
}
