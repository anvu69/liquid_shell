import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_example/support/launch_demo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(launchDemoChannel, null));

  test('the Runner answers the demo it was launched with', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(launchDemoChannel, (call) async {
      calls.add(call.method);
      return 'sheet';
    });
    expect(await launchDemo(), 'sheet');
    expect(calls, ['demo']);
  });

  test('no demo: null', () async {
    messenger.setMockMethodCallHandler(launchDemoChannel, (_) async => null);
    expect(await launchDemo(), isNull);
  });

  test('a platform without the channel has no demo', () async {
    expect(await launchDemo(), isNull);
  });

  test('a channel error has no demo', () async {
    messenger.setMockMethodCallHandler(
      launchDemoChannel,
      (_) async => throw PlatformException(code: 'boom'),
    );
    expect(await launchDemo(), isNull);
  });
}
