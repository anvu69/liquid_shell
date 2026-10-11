import 'dart:io';

import 'package:test/test.dart';

// Runs tool/integration_android.sh against a fake adb and a fake flutter,
// up to its first `flutter drive`. The fake flutter records its arguments
// and fails, which stops the script there.
void main() {
  final script = File('tool/integration_android.sh').absolute.path;

  // [meminfo] is what `adb shell cat /proc/meminfo` prints; null makes that
  // read fail.
  ({ProcessResult result, String? flutterArgs}) run({String? meminfo}) {
    final dir = Directory.systemTemp.createTempSync('integration_android_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final args = File('${dir.path}/flutter_args');
    File('${dir.path}/adb').writeAsStringSync(r'''
#!/usr/bin/env bash
case "$*" in
  'shell getprop ro.build.version.sdk') echo 34 ;;
  'shell settings get global animator_duration_scale') echo 1 ;;
  'shell getprop ro.surface_flinger.supports_background_blur') echo 1 ;;
  'shell getprop ro.config.low_ram') echo false ;;
  'shell pm has-feature android.hardware.vulkan.version 4198400') echo true ;;
  'shell cat /proc/meminfo')
    [ -n "${FAKE_MEMINFO+set}" ] || exit 1
    printf '%s' "$FAKE_MEMINFO" ;;
esac
''');
    File('${dir.path}/flutter').writeAsStringSync('''
#!/usr/bin/env bash
echo "\$*" > '${args.path}'
exit 1
''');
    Process.runSync('chmod', ['+x', '${dir.path}/adb', '${dir.path}/flutter']);
    final result = Process.runSync(
      'bash',
      [script],
      environment: {
        'PATH': '${dir.path}:${Platform.environment['PATH']}',
        'ANDROID_SERIAL': 'emulator-5554',
        'FLUTTER': '${dir.path}/flutter',
        'FAKE_MEMINFO': ?meminfo,
      },
    );
    return (
      result: result,
      flutterArgs: args.existsSync() ? args.readAsStringSync() : null,
    );
  }

  test('MemTotal under 3 GiB expects a low-end device', () {
    final (:result, :flutterArgs) = run(
      meminfo: 'MemTotal:        2097152 kB\r\nMemFree: 1 kB\r\n',
    );
    expect(
      flutterArgs,
      contains('EXPECT_LOW_END=true'),
      reason: result.stderr as String,
    );
  });

  test('MemTotal of 8 GiB expects a device that is not low end', () {
    final (:result, :flutterArgs) = run(
      meminfo: 'MemTotal:        8388608 kB\r\n',
    );
    expect(
      flutterArgs,
      contains('EXPECT_LOW_END=false'),
      reason: result.stderr as String,
    );
  });

  test('no MemTotal in /proc/meminfo stops with a message', () {
    final (:result, :flutterArgs) = run(meminfo: 'MemFree: 1 kB\r\n');
    expect(result.exitCode, isNot(0));
    expect(result.stderr as String, contains('MemTotal'));
    expect(flutterArgs, isNull, reason: 'no run on a guessed expectation');
  });

  test('a failed /proc/meminfo read stops with a message', () {
    final (:result, :flutterArgs) = run();
    expect(result.exitCode, isNot(0));
    expect(result.stderr as String, contains('/proc/meminfo'));
    expect(flutterArgs, isNull);
  });
}
