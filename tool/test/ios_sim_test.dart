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

    test('--build builds the example for the simulator and installs it', () {
      final r = sim.run(
        script,
        ['warmup', udid, '--build'],
        env: {'FAKE_VM_DELAY': '0'},
      );
      expect(r.exitCode, 0, reason: outputOf(r));
      expect(
        sim.indexOf('flutter build ios --config-only --simulator --debug'),
        isNot(-1),
      );
      final build = sim.callsWith('xcodebuild build ').single;
      expect(build, contains('-destination id=$udid'));
      expect(build, contains('build/ios-derived'));
      expect(
        sim.callsWith('simctl install').single,
        endsWith(
          'build/ios-derived/Build/Products/Debug-iphonesimulator/Runner.app',
        ),
      );
    });

    test('--build that fails still boots, skips the launch, exits 0', () {
      final r = sim.run(
        script,
        ['warmup', udid, '--build'],
        env: {'FAKE_BUILD': 'fail'},
      );
      expect(r.exitCode, 0);
      expect(
        outputOf(r),
        contains('ios_sim: warm-up skipped: the build failed'),
      );
      expect(sim.callsWith('simctl bootstatus'), hasLength(1));
      expect(sim.callsWith('simctl launch'), isEmpty);
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

  group('guard', () {
    const drive = [
      'guard',
      udid,
      'a_test.dart on iPhone',
      '2',
      'flutter',
      'drive',
      '--target=a_test.dart',
    ];

    List<int> drives() => [
      for (var i = 0; i < sim.calls.length; i++)
        if (sim.calls[i].startsWith('flutter drive')) i,
    ];

    test('a drive that passes runs once', () {
      final r = sim.run(script, drive);
      expect(r.exitCode, 0);
      expect(sim.callsWith('flutter drive'), hasLength(1));
      expect(sim.callsWith('simctl terminate'), isEmpty);
    });

    test('a failing drive is never retried', () {
      final r = sim.run(script, drive, env: {'FAKE_DRIVE': 'fail'});
      expect(r.exitCode, 1);
      expect(sim.callsWith('flutter drive'), hasLength(1));
      expect(sim.dumps, isEmpty);
    });

    test('a stall is diagnosed, the app terminated, and the drive retried '
        'once on the same booted simulator', () {
      final r = sim.run(script, drive, env: {'FAKE_DRIVE': 'stall-once'});
      expect(r.exitCode, 0, reason: outputOf(r));
      expect(
        outputOf(r),
        contains(
          'ios_sim: stall guard fired: a_test.dart on iPhone (attempt 1 of 2)',
        ),
      );
      expect(drives(), hasLength(2));
      sim.expectInOrder(['log show --last 15m', 'simctl terminate']);
      final terminate = sim.indexOf('simctl terminate');
      expect(terminate, inExclusiveRange(drives().first, drives().last));
      expect(sim.callsWith('simctl shutdown'), isEmpty, reason: 'no reboot');
      expect(sim.callsWith('simctl boot'), isEmpty, reason: 'no reboot');
      expect(sim.dumps.single.path, endsWith('-a_test.dart_on_iPhone_stall_1'));
    });

    test('a second stall gives up with 124 after two dumps', () {
      final r = sim.run(script, drive, env: {'FAKE_DRIVE': 'stall'});
      expect(r.exitCode, 124);
      expect(outputOf(r), contains('(attempt 2 of 2); giving up'));
      expect(sim.callsWith('flutter drive'), hasLength(2));
      expect(sim.dumps, hasLength(2));
    });
  });

  test('a wrong call prints usage and exits 2', () {
    expect(sim.run(script, []).exitCode, 2);
    expect(sim.run(script, ['warmup']).exitCode, 2);
    expect(sim.run(script, ['guard', udid, 'x', '5']).exitCode, 2);
    expect(sim.run(script, ['nope', udid]).exitCode, 2);
  });
}
