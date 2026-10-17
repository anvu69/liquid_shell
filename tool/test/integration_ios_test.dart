import 'dart:io';

import 'package:test/test.dart';

import 'fake_sim.dart';

// tool/integration_ios.sh and tool/integration_ios_native.sh against fake
// simulator tools (spec VK-625 §7, §12): the warm-up comes before the first
// drive, and a stalled drive is retried on the same booted simulator.
void main() {
  const native = 'tool/integration_ios_native.sh';
  const signals = 'tool/integration_ios.sh';
  const udid = 'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE';
  const listed = '11111111-2222-3333-4444-555555555555';
  late FakeSim sim;

  setUp(() => sim = FakeSim());
  tearDown(() => sim.delete());

  ProcessResult runNative({Map<String, String> env = const {}}) => sim.run(
    native,
    [],
    env: {
      'NATIVE_DEVICES': '$udid=true',
      'NATIVE_TARGETS': 'a_test.dart b_test.dart',
      'IOS_DRIVE_TIMEOUT': '2',
      'FAKE_VM_DELAY': '0',
      ...env,
    },
  );

  ProcessResult runSignals({Map<String, String> env = const {}}) => sim.run(
    signals,
    [],
    env: {
      'IOS_RUNTIME': '',
      'IOS_DEVICES': 'iPhone 17 Pro',
      'IOS_DRIVE_TIMEOUT': '2',
      'FAKE_VM_DELAY': '0',
      ...env,
    },
  );

  group('integration_ios_native.sh', () {
    test('builds, boots and warms the simulator up before the first drive', () {
      final r = runNative();
      expect(r.exitCode, 0, reason: outputOf(r));
      sim.expectInOrder([
        'xcodebuild build ',
        'simctl bootstatus $udid -b',
        'simctl launch $udid',
        'simctl terminate $udid',
        '--target=integration_test/a_test.dart',
        '--target=integration_test/b_test.dart',
      ]);
      expect(
        sim.callsWith('simctl launch'),
        hasLength(1),
        reason: 'one warm-up',
      );
    });

    test('a stalled drive is retried once without a reboot', () {
      final r = runNative(env: {'FAKE_DRIVE': 'stall-once'});
      expect(r.exitCode, 0, reason: outputOf(r));
      expect(
        sim.callsWith('--target=integration_test/a_test.dart'),
        hasLength(2),
      );
      expect(
        sim.callsWith('--target=integration_test/b_test.dart'),
        hasLength(1),
      );
      expect(sim.callsWith('simctl shutdown'), isEmpty);
      expect(
        sim.callsWith('simctl boot '),
        hasLength(1),
        reason: 'the warm-up',
      );
      expect(sim.dumps.single.path, contains('-a_test.dart_on_'));
      expect(sim.dumps.single.path, endsWith('_stall_1'));
    });

    test('a failing drive stops the run with its status', () {
      final r = runNative(env: {'FAKE_DRIVE': 'fail'});
      expect(r.exitCode, 1);
      expect(sim.callsWith('flutter drive'), hasLength(1));
    });

    test('a drive whose build failed with the VK-627 signature runs once '
        'more', () {
      final r = runNative(env: {'FAKE_DRIVES': 'vk627'});
      expect(r.exitCode, 0, reason: outputOf(r));
      expect(
        sim.callsWith('--target=integration_test/a_test.dart'),
        hasLength(2),
      );
      expect(
        sim.callsWith('--target=integration_test/b_test.dart'),
        hasLength(1),
      );
      expect(outputOf(r), contains('ios_sim: VK-627: '));
    });
  });

  group('integration_ios.sh', () {
    test('warms the simulator up, then drives the signals test', () {
      final r = runSignals();
      expect(r.exitCode, 0, reason: outputOf(r));
      sim.expectInOrder([
        'xcodebuild build ',
        'simctl launch $listed',
        'simctl terminate $listed',
        '--target=integration_test/signals_test.dart',
      ]);
    });

    test('a stalled drive is retried once without a reboot', () {
      final r = runSignals(env: {'FAKE_DRIVE': 'stall-once'});
      expect(r.exitCode, 0, reason: outputOf(r));
      expect(sim.callsWith('flutter drive'), hasLength(2));
      expect(sim.callsWith('simctl shutdown'), isEmpty);
      expect(
        outputOf(r),
        contains('stall guard fired: signals_test.dart on iPhone 17 Pro'),
      );
    });

    test('a drive whose build failed with the VK-627 signature runs once '
        'more', () {
      final r = runSignals(env: {'FAKE_DRIVES': 'vk627'});
      expect(r.exitCode, 0, reason: outputOf(r));
      expect(sim.callsWith('flutter drive'), hasLength(2));
      expect(outputOf(r), contains('ios_sim: VK-627: '));
    });
  });
}
