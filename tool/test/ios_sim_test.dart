import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

import 'fake_sim.dart';

// tool/ios_sim.sh against fake simulator tools (spec VK-625 §5, §12).
void main() {
  const script = 'tool/ios_sim.sh';
  const udid = 'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE';
  // VK-627's note, before ": <label> (attempt <k> of 2); …".
  const vk627 =
      'ios_sim: VK-627: Flutter skipped the deployment-target raise '
      '(xcodebuild -showBuildSettings timed out)';
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

    test('a non-numeric timeout warns and falls back to the default, '
        'it never loops', () {
      // Capped at 25 s: before the guard the poll loop spun until the cap.
      final script25 = File('tool/ios_sim.sh').absolute.path;
      final r = sim.run(
        'tool/with_timeout.sh',
        ['25', 'bash', script25, 'warmup', udid],
        env: {
          'IOS_WARMUP_TIMEOUT': 'abc',
          'IOS_WARMUP_READY_TIMEOUT': 'xyz',
          'FAKE_VM_DELAY': '0',
        },
      );
      expect(r.exitCode, 0, reason: outputOf(r));
      expect(
        outputOf(r),
        contains('IOS_WARMUP_TIMEOUT=abc is not a number, using 180'),
      );
      expect(
        outputOf(r),
        contains('IOS_WARMUP_READY_TIMEOUT=xyz is not a number, using 30'),
      );
      expect(outputOf(r), contains('ios_sim: warm-up ok after'));
      expect(outputOf(r), isNot(contains('unbound variable')));
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

    group('the log stream reader', () {
      // The reader is started through tool/with_timeout.sh, so its pid is the
      // wrapper's and a TERM stops its whole group (T1-m2, I-1).
      void expectReaderStopped() {
        expect(sim.readerPids, hasLength(1));
        expect(FakeSim.alive(sim.readerPids.single), isFalse);
      }

      test('is dead after a warm-up that passed', () {
        final r = sim.run(
          script,
          ['warmup', udid],
          env: {'FAKE_VM_DELAY': '0'},
        );
        expect(r.exitCode, 0, reason: outputOf(r));
        expectReaderStopped();
      });

      test('is dead after a warm-up timeout', () {
        final r = sim.run(
          script,
          ['warmup', udid],
          env: {'IOS_WARMUP_TIMEOUT': '1'},
        );
        expect(r.exitCode, 0, reason: outputOf(r));
        expectReaderStopped();
      });

      test('is dead after a failed launch', () {
        final r = sim.run(
          script,
          ['warmup', udid],
          env: {'FAKE_LAUNCH_FAILS': '1'},
        );
        expect(r.exitCode, 0, reason: outputOf(r));
        expectReaderStopped();
      });

      test('is dead when the script is terminated mid warm-up', () async {
        final p = await Process.start(
          'bash',
          [
            File(script).absolute.path,
            'warmup',
            udid,
          ],
          environment: {
            'PATH': '${sim.dir.path}:${Platform.environment['PATH']}',
            'FAKE_DIR': sim.dir.path,
            'IOS_DIAG_DIR': sim.diagDir,
            'IOS_WARMUP_TIMEOUT': '60',
          },
        );
        unawaited(p.stdout.drain<void>());
        unawaited(p.stderr.drain<void>());
        for (var i = 0; i < 100 && sim.indexOf('simctl launch') < 0; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(sim.indexOf('simctl launch'), isNot(-1));
        p.kill();
        await p.exitCode.timeout(const Duration(seconds: 30));
        expectReaderStopped();
      });
    });

    test('a timeout dump keeps the reader log and when the launch was', () {
      final r = sim.run(
        script,
        ['warmup', udid],
        env: {'IOS_WARMUP_TIMEOUT': '1'},
      );
      expect(r.exitCode, 0, reason: outputOf(r));
      final dump = sim.dumps.single.path;
      expect(
        File('$dump/warm-up-reader.log').readAsStringSync(),
        contains('Filtering the log data'),
      );
      final meta = File('$dump/meta.txt').readAsStringSync();
      expect(meta, contains(RegExp(r'launched: 20\d\d-\d\d-\d\dT\S+Z')));
      expect(meta, contains('(local 20'));
      expect(meta, contains('reader ready: yes'));
      expect(meta, contains('app pid: 4242'));
    });

    test('a reader that printed no header is recorded as not ready', () {
      final r = sim.run(
        script,
        ['warmup', udid],
        env: {
          'IOS_WARMUP_TIMEOUT': '1',
          'IOS_WARMUP_READY_TIMEOUT': '1',
          'FAKE_NO_HEADER': '1',
        },
      );
      expect(r.exitCode, 0, reason: outputOf(r));
      expect(
        File('${sim.dumps.single.path}/meta.txt').readAsStringSync(),
        contains('reader ready: no'),
      );
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
      expect(
        sim.callsWith('xcodebuild build '),
        hasLength(1),
        reason: 'a failure without the VK-627 signature is not retried',
      );
    });

    // VK-627: the generated plugin package kept .iOS("13.0") and Xcode's
    // Target Integrity check failed the build. Both steps run once more.
    test('--build runs a build that failed with the VK-627 signature once '
        'more, both steps, then warms up', () {
      final r = sim.run(
        script,
        ['warmup', udid, '--build'],
        env: {'FAKE_VM_DELAY': '0', 'FAKE_BUILDS': 'vk627'},
      );
      expect(r.exitCode, 0, reason: outputOf(r));
      expect(
        outputOf(r),
        contains(
          '$vk627: build on $udid (attempt 1 of 2); building again once',
        ),
      );
      final configs = sim.indicesOf('flutter build ios --config-only');
      final builds = sim.indicesOf('xcodebuild build ');
      expect(configs, hasLength(2));
      expect(builds, hasLength(2));
      expect(
        configs.last,
        greaterThan(builds.first),
        reason: sim.calls.join('\n'),
      );
      expect(outputOf(r), isNot(contains('warm-up skipped')));
      expect(sim.callsWith('simctl launch'), hasLength(1));
    });

    test('--build with the VK-627 signature twice gives up and skips the '
        'launch', () {
      final r = sim.run(
        script,
        ['warmup', udid, '--build'],
        env: {'FAKE_BUILDS': 'vk627 vk627'},
      );
      expect(r.exitCode, 0, reason: outputOf(r));
      expect(
        outputOf(r),
        contains('$vk627: build on $udid (attempt 2 of 2); giving up'),
      );
      expect(
        outputOf(r),
        contains('ios_sim: warm-up skipped: the build failed'),
      );
      expect(sim.callsWith('xcodebuild build '), hasLength(2));
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
      expect(read('meta.txt'), contains('app pid: 4242'));
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

    test('the app pid is the app, never the XCTest runner', () {
      final r = sim.run(
        script,
        ['diagnose', udid, 'x'],
        env: {
          'FAKE_LAUNCHCTL':
              r'5555\t0\tUIKitApplication:vn.lasoai.liquidShellExample.RunnerUITests.xctrunner[a][b]\n'
              r'4242\t0\tUIKitApplication:vn.lasoai.liquidShellExample[b61d][rb-legacy]',
        },
      );
      expect(r.exitCode, 0, reason: outputOf(r));
      expect(sim.callsWith('sample 4242 5'), hasLength(1));
      expect(sim.callsWith('sample 5555'), isEmpty);
    });

    test('app pid is none when the app is not running', () {
      sim.run(script, ['diagnose', udid, 'x'], env: {'FAKE_LAUNCHCTL': ''});
      expect(
        File('${sim.dumps.single.path}/meta.txt').readAsStringSync(),
        contains('app pid: none'),
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

    test('a drive whose build failed with the VK-627 signature runs once '
        'more, in a fresh flutter process', () {
      final r = sim.run(script, drive, env: {'FAKE_DRIVES': 'vk627'});
      expect(r.exitCode, 0, reason: outputOf(r));
      expect(
        outputOf(r),
        contains(
          '$vk627: a_test.dart on iPhone (attempt 1 of 2); building again once',
        ),
      );
      expect(
        outputOf(r),
        contains('Target Integrity (Xcode)'),
        reason: "the drive's own output still reaches the log",
      );
      expect(drives(), hasLength(2));
      expect(sim.callsWith('simctl terminate'), isEmpty, reason: 'no app ran');
      expect(sim.dumps, isEmpty);
    });

    test('the VK-627 signature twice gives up with the drive status', () {
      final r = sim.run(script, drive, env: {'FAKE_DRIVES': 'vk627 vk627'});
      expect(r.exitCode, 1);
      expect(
        outputOf(r),
        contains('$vk627: a_test.dart on iPhone (attempt 2 of 2); giving up'),
      );
      expect(drives(), hasLength(2));
    });

    test('a stall and the VK-627 signature share the one retry', () {
      final r = sim.run(script, drive, env: {'FAKE_DRIVES': 'stall vk627'});
      expect(r.exitCode, 1, reason: outputOf(r));
      expect(outputOf(r), contains('(attempt 1 of 2); terminating the app'));
      expect(outputOf(r), contains('(attempt 2 of 2); giving up'));
      expect(drives(), hasLength(2));
    });

    test('the VK-627 signature, then a stall: two drives, 124', () {
      final r = sim.run(script, drive, env: {'FAKE_DRIVES': 'vk627 stall'});
      expect(r.exitCode, 124, reason: outputOf(r));
      expect(outputOf(r), contains('(attempt 1 of 2); building again once'));
      expect(
        outputOf(r),
        contains('stall guard fired: a_test.dart on iPhone (attempt 2 of 2)'),
      );
      expect(drives(), hasLength(2));
    });

    test('a process that keeps the drive output open holds the guard at '
        'most a few seconds', () {
      final watch = Stopwatch()..start();
      final r = sim.run(script, drive, env: {'FAKE_DRIVE': 'linger'});
      watch.stop();
      final lingerer = int.parse(
        File('${sim.dir.path}/lingerer').readAsStringSync().trim(),
      );
      addTearDown(() => Process.killPid(lingerer));
      expect(r.exitCode, 0, reason: outputOf(r));
      expect(watch.elapsed, lessThan(const Duration(seconds: 40)));
    });
  });

  test('a wrong call prints usage and exits 2', () {
    expect(sim.run(script, []).exitCode, 2);
    expect(sim.run(script, ['warmup']).exitCode, 2);
    expect(sim.run(script, ['guard', udid, 'x', '5']).exitCode, 2);
    expect(sim.run(script, ['build', udid]).exitCode, 2);
    expect(sim.run(script, ['nope', udid]).exitCode, 2);
  });
}
