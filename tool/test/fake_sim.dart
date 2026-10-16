import 'dart:io';

import 'package:test/test.dart';

/// Fake `xcrun`, `xcodebuild`, `flutter` and `sample` first on `PATH`, for
/// the iOS simulator scripts (spec VK-625 §12). Each call appends one line,
/// the tool's name and its arguments, to [calls]. `FAKE_*` variables steer
/// the answers:
///
/// - `FAKE_VM_DELAY`: seconds after which `log stream` logs the app's VM
///   service line; unset, it never does.
/// - `FAKE_NO_HEADER`: `log stream` prints nothing at all, not even its
///   header.
/// - `FAKE_LAUNCH_FAILS`: `simctl launch` fails.
/// - `FAKE_LAUNCHCTL`: what `launchctl list` prints (default: the app,
///   pid 4242).
/// - `FAKE_TOTAL`: the `totalTestCount` that `xcresulttool` reports
///   (default 6).
/// - `FAKE_BUILD`: `fail` makes `xcodebuild build` and `build-for-testing`
///   fail.
/// - `FAKE_TEST`: `fail` or `stall` for `xcodebuild test-without-building`.
/// - `FAKE_DRIVE`: `fail`, `stall` (every drive) or `stall-once` (the first
///   drive only) for `flutter drive`.
class FakeSim {
  /// Writes the fakes into a new temporary directory.
  FakeSim() : dir = Directory.systemTemp.createTempSync('fake_sim_') {
    _tool('xcrun', _xcrun);
    _tool('xcodebuild', _xcodebuild);
    _tool('flutter', _flutter);
    _tool('sample', _sample);
  }

  /// Holds the fakes, the call log and [diagDir].
  final Directory dir;

  /// Where the scripts write their diagnostics (`IOS_DIAG_DIR`).
  String get diagDir => '${dir.path}/diag';

  /// Every call so far, in order, such as `xcrun simctl boot U`.
  List<String> get calls {
    final log = File('${dir.path}/calls');
    return log.existsSync() ? log.readAsLinesSync() : const [];
  }

  /// The pids of every `log stream` reader started so far (each fake reader
  /// appends its own pid to `readers`).
  List<int> get readerPids {
    final file = File('${dir.path}/readers');
    if (!file.existsSync()) return const [];
    return file.readAsLinesSync().map(int.parse).toList();
  }

  /// Whether process [pid] still exists.
  static bool alive(int pid) =>
      Process.runSync('kill', ['-0', '$pid']).exitCode == 0;

  /// The calls that contain [part], in order.
  List<String> callsWith(String part) =>
      calls.where((c) => c.contains(part)).toList();

  /// The index in [calls] of the first call that contains [part], or -1.
  int indexOf(String part) => calls.indexWhere((c) => c.contains(part));

  /// Expects a call containing each of [parts], in this order.
  void expectInOrder(List<String> parts) {
    final at = parts.map(indexOf).toList();
    expect(at, isNot(contains(-1)), reason: '$parts in\n${calls.join('\n')}');
    expect(at, orderedEquals([...at]..sort()), reason: calls.join('\n'));
  }

  /// The diagnostics folders written so far, by name.
  List<Directory> get dumps {
    final root = Directory(diagDir);
    if (!root.existsSync()) return const [];
    return root.listSync().whereType<Directory>().toList()
      ..sort((a, b) => a.path.compareTo(b.path));
  }

  /// Runs `bash script args` with the fakes first on `PATH`, `FLUTTER` set
  /// to the fake, diagnostics in [diagDir], outside GitHub Actions, plus
  /// [env].
  ProcessResult run(
    String script,
    List<String> args, {
    Map<String, String> env = const {},
  }) => Process.runSync(
    'bash',
    [File(script).absolute.path, ...args],
    environment: {
      'PATH': '${dir.path}:${Platform.environment['PATH']}',
      'FAKE_DIR': dir.path,
      'FLUTTER': '${dir.path}/flutter',
      'IOS_DIAG_DIR': diagDir,
      'GITHUB_ACTIONS': '',
      ...env,
    },
  );

  /// Removes the fakes and everything they recorded.
  void delete() => dir.deleteSync(recursive: true);

  void _tool(String name, String body) {
    final file = File('${dir.path}/$name')
      ..writeAsStringSync('#!/usr/bin/env bash\n$body');
    Process.runSync('chmod', ['+x', file.path]);
  }
}

/// What a script printed, stdout then stderr.
String outputOf(ProcessResult result) => '${result.stdout}${result.stderr}';

const _xcrun = r'''
echo "xcrun $*" >> "$FAKE_DIR/calls"
case "$*" in
  'simctl list devices available'*)
    echo '-- iOS 26.5 --'
    echo '    iPhone 17 Pro (11111111-2222-3333-4444-555555555555) (Shutdown)' ;;
  'simctl launch '*)
    [ -z "${FAKE_LAUNCH_FAILS:-}" ] || exit 1
    echo "$4: 4242" ;;
  simctl\ spawn\ *\ log\ stream*)
    echo $$ >> "$FAKE_DIR/readers"
    [ -z "${FAKE_NO_HEADER:-}" ] || exec sleep 300
    echo 'Filtering the log data using "process == ..."'
    if [ -n "${FAKE_VM_DELAY:-}" ]; then
      sleep "$FAKE_VM_DELAY"
      echo '2026-10-16 10:00:00.000 Df Runner[4242:1] (Flutter) flutter: The Dart VM service is listening on http://127.0.0.1:1/a=/'
    fi
    sleep 300 ;;
  simctl\ spawn\ *\ log\ show*)
    echo '2026-10-16 10:00:00.000 Df Runner[4242:1] (Flutter) flutter: The Dart VM service is listening on http://127.0.0.1:1/a=/' ;;
  simctl\ spawn\ *\ launchctl\ list)
    printf '%b\n' "${FAKE_LAUNCHCTL-4242\t0\tUIKitApplication:vn.lasoai.liquidShellExample[b61d][rb-legacy]}" ;;
  'xcresulttool get test-results summary'*)
    echo 'FAKE SUMMARY'
    echo "{ \"totalTestCount\" : ${FAKE_TOTAL:-6} }" ;;
esac
exit 0
''';

const _xcodebuild = r'''
echo "xcodebuild $*" >> "$FAKE_DIR/calls"
case "$1" in
  build|build-for-testing) [ "${FAKE_BUILD:-}" != fail ] || exit 65 ;;
  test-without-building)
    case "${FAKE_TEST:-}" in
      fail)
        while [ $# -gt 0 ] && [ "$1" != -resultBundlePath ]; do shift; done
        mkdir -p "$2"
        exit 65 ;;
      stall) sleep 300 ;;
      *)
        while [ $# -gt 0 ] && [ "$1" != -resultBundlePath ]; do shift; done
        [ $# -lt 2 ] || mkdir -p "$2" ;;
    esac ;;
esac
exit 0
''';

const _flutter = r'''
echo "flutter $*" >> "$FAKE_DIR/calls"
[ "$1" = drive ] || exit 0
case "${FAKE_DRIVE:-}" in
  fail) exit 1 ;;
  stall) sleep 300 ;;
  stall-once)
    if [ ! -f "$FAKE_DIR/stalled" ]; then
      touch "$FAKE_DIR/stalled"
      sleep 300
    fi ;;
esac
exit 0
''';

const _sample = r'''
echo "sample $*" >> "$FAKE_DIR/calls"
while [ $# -gt 0 ] && [ "$1" != -file ]; do shift; done
[ $# -lt 2 ] || echo 'FAKE SAMPLE' > "$2"
''';
