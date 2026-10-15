import 'dart:io';

import 'package:test/test.dart';

import 'fake_sim.dart';

// tool/ios_xctest.sh against fake simulator tools (spec VK-625 §6, §12).
void main() {
  const script = 'tool/ios_xctest.sh';
  const udid = 'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE';
  late FakeSim sim;
  late String result;

  setUp(() {
    sim = FakeSim();
    result = '${sim.dir.path}/ios-ui.xcresult';
  });
  tearDown(() => sim.delete());

  ProcessResult run({
    String suite = '30',
    Map<String, String> env = const {},
  }) => sim.run(
    script,
    [udid, result, suite, '180', '300', '-only-testing:RunnerUITests'],
    env: {'FAKE_VM_DELAY': '0', ...env},
  );

  test('builds for testing, warms the simulator up, then runs the suite '
      'without building', () {
    final r = run();
    expect(r.exitCode, 0, reason: outputOf(r));
    sim.expectInOrder([
      'flutter build ios --config-only --simulator --debug',
      'xcodebuild build-for-testing',
      'simctl bootstatus $udid -b',
      'simctl launch $udid',
      'simctl terminate $udid',
      'xcodebuild test-without-building',
    ]);
    final build = sim.callsWith('build-for-testing').single;
    final test = sim.callsWith('test-without-building').single;
    for (final call in [build, test]) {
      expect(call, contains('-destination id=$udid'));
      expect(call, contains('-derivedDataPath '));
      expect(call, contains('-only-testing:RunnerUITests'));
    }
    expect(
      test,
      contains(
        '-default-test-execution-time-allowance 180 '
        '-maximum-test-execution-time-allowance 300',
      ),
    );
    expect(test, contains('-collect-test-diagnostics never'));
    expect(test, contains('-resultBundlePath $result'));
    expect(
      sim.callsWith('simctl install').single,
      endsWith(
        'build/ios-derived/Build/Products/Debug-iphonesimulator/Runner.app',
      ),
    );
  });

  test('the warm-up is outside the suite cap', () {
    final r = run(suite: '2', env: {'FAKE_VM_DELAY': '4'});
    expect(r.exitCode, 0, reason: outputOf(r));
    expect(outputOf(r), contains('ios_sim: warm-up ok'));
  });

  test('a warm-up timeout never fails the run', () {
    final r = run(env: {'FAKE_VM_DELAY': '', 'IOS_WARMUP_TIMEOUT': '1'});
    expect(r.exitCode, 0, reason: outputOf(r));
    expect(outputOf(r), contains('ios_sim: warm-up timeout'));
    expect(sim.callsWith('test-without-building'), hasLength(1));
  });

  test('a red suite prints the result summary and keeps its status', () {
    final r = run(env: {'FAKE_TEST': 'fail'});
    expect(r.exitCode, 65);
    expect(outputOf(r), contains('FAKE SUMMARY'));
    expect(sim.dumps, isEmpty, reason: 'a failure is not a stall');
  });

  test('a stalled suite is diagnosed before the stop and exits 124', () {
    final r = run(suite: '2', env: {'FAKE_TEST': 'stall'});
    expect(r.exitCode, 124, reason: outputOf(r));
    expect(sim.dumps.single.path, endsWith('-ios-ui_stall'));
  });

  test('a green run that selected no test is red', () {
    final r = run(env: {'FAKE_TOTAL': '0'});
    expect(r.exitCode, 1, reason: outputOf(r));
    expect(outputOf(r), contains('ran 0 tests'));
  });

  test('a green run that ran tests stays green', () {
    final r = run(env: {'FAKE_TOTAL': '3'});
    expect(r.exitCode, 0, reason: outputOf(r));
  });

  test('a failed build stops before the warm-up', () {
    final r = run(env: {'FAKE_BUILD': 'fail'});
    expect(r.exitCode, 65);
    expect(sim.callsWith('simctl'), isEmpty);
    expect(sim.callsWith('test-without-building'), isEmpty);
  });

  test('too few arguments print usage and exit 2', () {
    expect(sim.run(script, [udid, result, '30']).exitCode, 2);
  });
}
