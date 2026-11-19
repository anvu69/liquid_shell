import 'dart:convert';
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
    String selection = '-only-testing:RunnerUITests',
    Map<String, String> env = const {},
  }) => sim.run(
    script,
    [udid, result, suite, '180', '300', selection],
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

  /// The app logs written so far (`<time>-<label>-app.log`, VK-1046).
  List<File> appLogs() {
    final root = Directory(sim.diagDir);
    if (!root.existsSync()) return const [];
    return root
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('-app.log'))
        .toList();
  }

  test('a red suite prints the result summary and keeps its status', () {
    final r = run(env: {'FAKE_TEST': 'fail'});
    expect(r.exitCode, 65);
    expect(outputOf(r), contains('FAKE SUMMARY'));
    expect(sim.dumps, isEmpty, reason: 'a failure is not a stall');
  });

  test("a red suite saves the app's liquid_shell lines of the whole suite", () {
    final r = run(env: {'FAKE_TEST': 'fail'});
    expect(r.exitCode, 65, reason: outputOf(r));
    expect(appLogs().single.path, endsWith('-ios-ui-app.log'));
    expect(
      appLogs().single.readAsStringSync(),
      contains('liquid_shell: native page action tap dropped'),
    );
    sim.expectInOrder(['test-without-building', 'log show', 'xcresulttool']);
    final last = RegExp(
      r'--last (\d+)s',
    ).firstMatch(sim.callsWith('log show').single);
    expect(last, isNotNull);
    expect(int.parse(last!.group(1)!), greaterThanOrEqualTo(60));
  });

  test("a failed read of the app's log keeps the suite's status", () {
    final r = run(env: {'FAKE_TEST': 'fail', 'FAKE_LOG_SHOW': 'fail'});
    expect(r.exitCode, 65, reason: outputOf(r));
    expect(outputOf(r), contains('FAKE SUMMARY'));
  });

  test('a stalled suite is diagnosed before the stop and exits 124', () {
    final r = run(suite: '2', env: {'FAKE_TEST': 'stall'});
    expect(r.exitCode, 124, reason: outputOf(r));
    expect(sim.dumps.single.path, endsWith('-ios-ui_stall'));
    expect(appLogs(), hasLength(1), reason: 'a stall is a red suite too');
  });

  test('a green suite saves no app log', () {
    final r = run();
    expect(r.exitCode, 0, reason: outputOf(r));
    expect(appLogs(), isEmpty);
    expect(sim.callsWith('eventMessage CONTAINS "liquid_shell"'), isEmpty);
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
    expect(
      sim.callsWith('build-for-testing'),
      hasLength(1),
      reason: 'a failure without the VK-627 signature is not retried',
    );
  });

  // VK-627: `flutter build ios --config-only` left the generated plugin
  // package at .iOS("13.0"), and build-for-testing failed Xcode's Target
  // Integrity check. Both steps run once more.
  test('a build that failed with the VK-627 signature runs once more, both '
      'steps, then the suite runs', () {
    final r = run(env: {'FAKE_BUILDS': 'vk627'});
    expect(r.exitCode, 0, reason: outputOf(r));
    expect(
      outputOf(r),
      contains(
        'ios_sim: VK-627: Flutter skipped the deployment-target raise '
        '(xcodebuild -showBuildSettings timed out): build-for-testing on '
        '$udid (attempt 1 of 2); building again once',
      ),
    );
    expect(sim.callsWith('flutter build ios --config-only'), hasLength(2));
    expect(sim.callsWith('xcodebuild build-for-testing'), hasLength(2));
    expect(sim.callsWith('test-without-building'), hasLength(1));
  });

  test('the VK-627 signature twice stops before the warm-up', () {
    final r = run(env: {'FAKE_BUILDS': 'vk627 vk627'});
    expect(r.exitCode, 65, reason: outputOf(r));
    expect(outputOf(r), contains('(attempt 2 of 2); giving up'));
    expect(sim.callsWith('xcodebuild build-for-testing'), hasLength(2));
    expect(sim.callsWith('simctl'), isEmpty);
  });

  test('too few arguments print usage and exit 2', () {
    expect(sim.run(script, [udid, result, '30']).exitCode, 2);
  });

  // VK-1083: XCTest failed to terminate the previous test's app inside
  // launch() on a stalled runner. Only that failure, and only its tests,
  // run once more.
  group('terminate rerun', () {
    const minimize = '-only-testing:RunnerUITests/MinimizeUITests';
    const scrollId =
        'RunnerUITests/MinimizeUITests/'
        'testAScrollMinimizesAndAFlingToTheTopExpands';
    const scroll = '-only-testing:$scrollId';
    const circle =
        '-only-testing:RunnerUITests/MinimizeUITests/'
        'testATapOnTheCircleExpands';
    String rerun() => '${sim.dir.path}/ios-ui-rerun.xcresult';

    /// H2's failure entry (spec §1), from its real summary.
    Map<String, Object?> h2Entry() {
      final summary =
          jsonDecode(
                File(
                  'tool/test/fixtures/h2-terminate-summary.json',
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      return (summary['testFailures']! as List<Object?>).single!
          as Map<String, Object?>;
    }

    /// H2's entry, for [test] of MinimizeUITests and with [text] when given.
    Map<String, Object?> entry(String test, {String? text}) => {
      ...h2Entry(),
      'testIdentifierString': 'MinimizeUITests/$test()',
      'testName': '$test()',
      'failureText': ?text,
    };

    /// A red first run whose summary lists [failures], `failedTests`
    /// [failed] (default: their count), then [tests] outcomes.
    ProcessResult redRun(
      List<Map<String, Object?>> failures, {
      int? failed,
      String tests = 'fail pass',
      Map<String, String> env = const {},
    }) => run(
      selection: minimize,
      env: {
        'FAKE_TESTS': tests,
        'FAKE_FAILURES': jsonEncode(failures),
        'FAKE_FAILED': '${failed ?? failures.length}',
        ...env,
      },
    );

    List<String> testCalls() => sim.callsWith('test-without-building');

    test("a red run whose only failure is H2's reruns that test alone, "
        'once, and passes', () {
      final r = redRun([h2Entry()]);
      expect(r.exitCode, 0, reason: outputOf(r));
      expect(testCalls(), hasLength(2), reason: sim.calls.join('\n'));
      final second = testCalls()[1].split(' ');
      expect(second, contains(scroll));
      expect(second, isNot(contains(minimize)));
      expect(testCalls()[1], contains('-resultBundlePath ${rerun()}'));
      expect(
        outputOf(r),
        contains(
          '::warning::ios_xctest: XCTest failed to terminate the previous '
          'app before $scrollId (VK-1083); '
          'rerunning only those, once',
        ),
      );
      expect(outputOf(r), contains('ios_xctest: the rerun is capped at 420 s'));
      expect(sim.dumps.single.path, endsWith('-ios-ui_terminate'));
    });

    /// The files directly in the diagnostics root whose name ends with
    /// [suffix].
    List<File> diagFiles(String suffix) {
      final root = Directory(sim.diagDir);
      if (!root.existsSync()) return const [];
      return root
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith(suffix))
          .toList();
    }

    test('a rescued run keeps the first summary and the termination log in '
        'the diagnostics root', () {
      final r = redRun([h2Entry()]);
      expect(r.exitCode, 0, reason: outputOf(r));
      final copy = diagFiles('-ios-ui-terminate-rerun.json').single;
      final summary =
          jsonDecode(copy.readAsStringSync()) as Map<String, Object?>;
      expect(summary['testFailures'], [h2Entry()]);
      expect(diagFiles('-ios-ui-term.log'), hasLength(1));
      final termlog = sim.callsWith('process == "runningboardd"').single;
      final last = RegExp(r'--last (\d+)s').firstMatch(termlog);
      expect(int.parse(last!.group(1)!), greaterThanOrEqualTo(60));
      sim.expectInOrder([
        'xcresulttool',
        'launchctl list',
        'process == "runningboardd"',
        '-rerun.xcresult',
      ]);
    });

    test('a run that is not rerun keeps no terminate record', () {
      final r = redRun([h2Entry()], failed: 2);
      expect(r.exitCode, 65, reason: outputOf(r));
      expect(diagFiles('-terminate-rerun.json'), isEmpty);
      expect(diagFiles('-term.log'), isEmpty);
    });

    test('two terminate failures rerun both, capped for two', () {
      final r = redRun([h2Entry(), entry('testATapOnTheCircleExpands')]);
      expect(r.exitCode, 0, reason: outputOf(r));
      final second = testCalls()[1].split(' ');
      expect(
        second,
        containsAll([scroll, circle]),
      );
      expect(outputOf(r), contains('the rerun is capped at 720 s'));
    });

    /// Expects the first run's status and no rerun.
    void expectNoRerun(ProcessResult r, {int status = 65}) {
      expect(r.exitCode, status, reason: outputOf(r));
      expect(testCalls(), hasLength(1), reason: sim.calls.join('\n'));
      expect(outputOf(r), isNot(contains('rerunning only those')));
    }

    test('a failedTests count above the listed failures is not rerun (the '
        'list is not exhaustive)', () {
      final r = redRun([h2Entry()], failed: 2);
      expectNoRerun(r);
      expect(outputOf(r), contains('ios_xctest: no terminate rerun:'));
    });

    test('three terminate failures are not rerun', () {
      expectNoRerun(
        redRun([
          h2Entry(),
          entry('testATapOnTheCircleExpands'),
          entry('testAStatusBarTapScrollsToTheTopAndExpands'),
        ]),
      );
    });

    test('a terminate failure beside any other failure is not rerun', () {
      expectNoRerun(
        redRun([
          h2Entry(),
          entry(
            'testAPushedPageOnHomeMinimizesTheBar',
            text: 'XCTAssertTrue failed - Flutter popped the page',
          ),
        ]),
      );
    });

    test('a terminate failure of another app is not rerun', () {
      expectNoRerun(
        redRun([
          entry(
            'testATapOnTheCircleExpands',
            text: 'Failed to terminate com.apple.Preferences:12: x',
          ),
        ]),
      );
    });

    test('a red run with no listed failure is not rerun', () {
      expectNoRerun(redRun([], failed: 0));
    });

    test('a test id of an unexpected shape is not rerun', () {
      expectNoRerun(
        redRun([
          {...h2Entry(), 'testIdentifierString': 'MinimizeUITests/test(x:)'},
        ]),
      );
    });

    test('an unreadable summary is not rerun', () {
      expectNoRerun(redRun([h2Entry()], env: {'FAKE_SUMMARY': 'broken'}));
    });

    test('an absent result bundle is not rerun', () {
      expectNoRerun(redRun([h2Entry()], env: {'FAKE_RESULT_MISSING': '1'}));
    });

    test('a stalled suite is not rerun', () {
      final r = run(
        suite: '2',
        selection: minimize,
        env: {
          'FAKE_TESTS': 'stall',
          'FAKE_FAILURES': jsonEncode([h2Entry()]),
        },
      );
      expectNoRerun(r, status: 124);
    });

    test('a red rerun exits with its own status and prints both '
        'summaries', () {
      final r = redRun([h2Entry()], tests: 'fail fail');
      expect(r.exitCode, 65, reason: outputOf(r));
      expect(testCalls(), hasLength(2));
      expect('FAKE SUMMARY'.allMatches(outputOf(r)), hasLength(2));
      expect(sim.callsWith('xcresulttool').last, endsWith(rerun()));
    });

    test('a green rerun that ran 0 tests is red', () {
      final r = redRun([h2Entry()], env: {'FAKE_RERUN_TOTAL': '0'});
      expect(r.exitCode, 1, reason: outputOf(r));
      expect(outputOf(r), contains('ran 0 tests'));
    });
  });
}
