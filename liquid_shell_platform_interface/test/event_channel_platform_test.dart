import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = EventChannelLiquidShellPlatform.channel;
  final methods = MethodChannel(channel.name);

  late List<String> logs;
  late DebugPrintCallback originalDebugPrint;

  setUp(() {
    logs = [];
    originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    EventChannelLiquidShellPlatform.debugResetLogging();
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
    messenger
      ..setMockStreamHandler(channel, null)
      ..setMockMethodCallHandler(methods, null);
  });

  test('uses the agreed channel name', () {
    expect(channel.name, 'vn.lasoai.liquid_shell/signals');
  });

  test('decodes events and keeps listening after an error event', () async {
    messenger.setMockStreamHandler(
      channel,
      MockStreamHandler.inline(
        onListen: (arguments, events) {
          events
            ..success(const {'reduceTransparency': true})
            ..error(code: 'read-failed')
            ..success(const {'powerSave': true, 'blurDisabled': 'yes'})
            ..endOfStream();
        },
      ),
    );

    final events = await EventChannelLiquidShellPlatform()
        .watchSignals()
        .toList();

    expect(events, const [
      LiquidPlatformSignals(reduceTransparency: true),
      LiquidPlatformSignals.none,
      LiquidPlatformSignals(powerSave: true),
    ]);
    expect(logs.single, contains('read-failed'));
  });

  test('MissingPluginException on listen emits none and logs once', () async {
    final first = await EventChannelLiquidShellPlatform().watchSignals().first;
    final second = await EventChannelLiquidShellPlatform().watchSignals().first;

    expect(first, LiquidPlatformSignals.none);
    expect(second, LiquidPlatformSignals.none);
    expect(logs, hasLength(1));
    expect(logs.single, contains('MissingPluginException'));
  });

  test('PlatformException on listen emits none', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      throw PlatformException(code: 'denied');
    });

    final first = await EventChannelLiquidShellPlatform().watchSignals().first;

    expect(first, LiquidPlatformSignals.none);
    expect(logs.single, contains('denied'));
  });

  test('cancel tells the native side to remove its observers', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call.method);
      return null;
    });

    final subscription = EventChannelLiquidShellPlatform()
        .watchSignals()
        .listen((_) {});
    await pumpEventQueue();
    await subscription.cancel();

    expect(calls, ['listen', 'cancel']);
  });

  test('concurrent listeners share one native stream; cancelling one '
      'leaves the other receiving', () async {
    final calls = <String>[];
    late MockStreamHandlerEventSink sink;
    messenger.setMockStreamHandler(
      channel,
      MockStreamHandler.inline(
        onListen: (arguments, events) {
          calls.add('listen');
          sink = events..success(const {'reduceTransparency': true});
        },
        onCancel: (arguments) => calls.add('cancel'),
      ),
    );

    final first = <LiquidPlatformSignals>[];
    final second = <LiquidPlatformSignals>[];
    final a = EventChannelLiquidShellPlatform().watchSignals().listen(
      first.add,
    );
    await pumpEventQueue();
    final b = EventChannelLiquidShellPlatform().watchSignals().listen(
      second.add,
    );
    await pumpEventQueue();
    await a.cancel();
    sink.success(const {'powerSave': true});
    await pumpEventQueue();
    await b.cancel();

    expect(first, const [LiquidPlatformSignals(reduceTransparency: true)]);
    expect(second, const [
      LiquidPlatformSignals(reduceTransparency: true),
      LiquidPlatformSignals(powerSave: true),
    ]);
    expect(calls, ['listen', 'cancel']);
  });

  test(
    'listening again after the last cancel restarts the native side',
    () async {
      final calls = <String>[];
      messenger.setMockStreamHandler(
        channel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            calls.add('listen');
            events.success(const {'powerSave': true});
          },
          onCancel: (arguments) => calls.add('cancel'),
        ),
      );

      final platform = EventChannelLiquidShellPlatform();
      final first = await platform.watchSignals().first;
      final second = await platform.watchSignals().first;

      expect(first, const LiquidPlatformSignals(powerSave: true));
      expect(second, const LiquidPlatformSignals(powerSave: true));
      expect(calls, ['listen', 'cancel', 'listen', 'cancel']);
    },
  );

  test('a cancel that fails natively is swallowed', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      if (call.method == 'cancel') throw PlatformException(code: 'gone');
      return null;
    });

    final subscription = EventChannelLiquidShellPlatform()
        .watchSignals()
        .listen((_) {});
    await pumpEventQueue();

    await expectLater(subscription.cancel(), completes);
  });
}
