import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_ios/src/mapping.dart';
import 'package:liquid_shell_ios/src/native_shell_api.g.dart';
import 'package:liquid_shell_ios/src/platform.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// Records Dart → native dialog calls; answers with [answer].
class _FakeDialogs extends NativeDialogHostApi {
  final requests = <NativeDialogRequest>[];
  final responses = <int>[];
  NativeDialogResult answer = NativeDialogResult(
    outcome: NativeDialogOutcome.chose,
    actionIndex: 1,
  );
  NativeDialogSnapshot? snapshot;
  PlatformException? failure;

  @override
  Future<NativeDialogResult> present(NativeDialogRequest request) async {
    requests.add(request);
    final error = failure;
    if (error != null) throw error;
    return answer;
  }

  @override
  Future<NativeDialogSnapshot?> debugCurrent() async => snapshot;

  @override
  Future<void> debugRespond(int actionIndex) async =>
      responses.add(actionIndex);
}

const _sheet = LiquidNativeDialogRequest(
  kind: LiquidNativeDialogKind.actionSheet,
  title: 'Photo',
  message: 'Choose',
  actions: [
    LiquidNativeDialogAction(
      label: 'Delete',
      style: LiquidNativeDialogActionStyle.destructive,
    ),
    LiquidNativeDialogAction(label: 'Share', enabled: false),
    LiquidNativeDialogAction(
      label: 'Cancel',
      style: LiquidNativeDialogActionStyle.cancel,
    ),
  ],
  anchor: Rect.fromLTWH(10, 20, 30, 40),
  tintArgb: 0xFF3D5AFE,
  dark: true,
  rtl: true,
  requireGlass: false,
);

const _alert = LiquidNativeDialogRequest(
  kind: LiquidNativeDialogKind.alert,
  title: 'Discard changes?',
  actions: [
    LiquidNativeDialogAction(
      label: 'Keep editing',
      style: LiquidNativeDialogActionStyle.cancel,
    ),
    LiquidNativeDialogAction(label: 'Discard'),
  ],
  preferredIndex: 1,
  tintArgb: 0xFF000000,
  dark: false,
  rtl: false,
  requireGlass: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeDialogs dialogs;
  late LiquidShellIOS ios;
  setUp(() {
    dialogs = _FakeDialogs();
    ios = liquidShellIOSWithHost(NativeShellHostApi(), dialogs: dialogs);
  });

  test('iOS offers native dialogs', () {
    expect(ios.supportsNativeDialogs, isTrue);
  });

  test('an action sheet request carries every field', () async {
    await ios.presentNativeDialog(_sheet);
    final sent = dialogs.requests.single;
    expect(sent.kind, NativeDialogKind.actionSheet);
    expect(sent.title, 'Photo');
    expect(sent.message, 'Choose');
    expect(
      [for (final a in sent.actions) a.label],
      [
        'Delete',
        'Share',
        'Cancel',
      ],
    );
    expect(
      [for (final a in sent.actions) a.style],
      [
        NativeDialogActionStyle.destructive,
        NativeDialogActionStyle.standard,
        NativeDialogActionStyle.cancel,
      ],
    );
    expect([for (final a in sent.actions) a.enabled], [true, false, true]);
    expect(sent.preferredIndex, isNull);
    expect(
      [sent.anchor!.x, sent.anchor!.y, sent.anchor!.width, sent.anchor!.height],
      [10, 20, 30, 40],
    );
    expect(sent.tintArgb, 0xFF3D5AFE);
    expect(sent.dark, isTrue);
    expect(sent.rtl, isTrue);
    expect(sent.requireGlass, isFalse);
  });

  test('an alert request carries its preferred action and no anchor', () async {
    await ios.presentNativeDialog(_alert);
    final sent = dialogs.requests.single;
    expect(sent.kind, NativeDialogKind.alert);
    expect(sent.message, isNull);
    expect(sent.preferredIndex, 1);
    expect(sent.anchor, isNull);
    expect(sent.requireGlass, isTrue);
  });

  test('a non-finite anchor is not sent', () {
    const nan = LiquidNativeDialogRequest(
      kind: LiquidNativeDialogKind.actionSheet,
      actions: [LiquidNativeDialogAction(label: 'OK')],
      anchor: Rect.fromLTWH(double.nan, 0, 1, 1),
      tintArgb: 0,
      dark: false,
      rtl: false,
      requireGlass: true,
    );
    expect(dialogRequestToNative(nan).anchor, isNull);
  });

  group('results', () {
    Future<LiquidNativeDialogResult> answer(NativeDialogResult result) {
      dialogs.answer = result;
      return ios.presentNativeDialog(_alert);
    }

    test('a chosen index in range', () async {
      expect(
        await answer(
          NativeDialogResult(
            outcome: NativeDialogOutcome.chose,
            actionIndex: 0,
          ),
        ),
        const LiquidNativeDialogChose(0),
      );
    });

    test('a chosen index out of range is dismissed', () async {
      for (final index in [-1, 2, null]) {
        expect(
          await answer(
            NativeDialogResult(
              outcome: NativeDialogOutcome.chose,
              actionIndex: index,
            ),
          ),
          const LiquidNativeDialogDismissed(),
        );
      }
    });

    test('dismissed', () async {
      expect(
        await answer(
          NativeDialogResult(outcome: NativeDialogOutcome.dismissed),
        ),
        const LiquidNativeDialogDismissed(),
      );
    });

    test(
      'every unavailable reason maps; a missing one is a channel error',
      () async {
        const expected = {
          NativeDialogUnavailableReason.osTooOld:
              LiquidNativeDialogUnavailableReason.osTooOld,
          NativeDialogUnavailableReason.noWindow:
              LiquidNativeDialogUnavailableReason.noWindow,
          NativeDialogUnavailableReason.refused:
              LiquidNativeDialogUnavailableReason.refused,
          NativeDialogUnavailableReason.disabledByEnvironment:
              LiquidNativeDialogUnavailableReason.disabledByEnvironment,
        };
        for (final MapEntry(:key, :value) in expected.entries) {
          expect(
            await answer(
              NativeDialogResult(
                outcome: NativeDialogOutcome.unavailable,
                reason: key,
              ),
            ),
            LiquidNativeDialogUnavailable(value),
          );
        }
        expect(
          await answer(
            NativeDialogResult(outcome: NativeDialogOutcome.unavailable),
          ),
          const LiquidNativeDialogUnavailable(
            LiquidNativeDialogUnavailableReason.channelError,
          ),
        );
      },
    );
  });

  test('a channel failure is unavailable, logged once', () async {
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = original);
    dialogs.failure = PlatformException(code: 'boom');
    for (var i = 0; i < 2; i++) {
      expect(
        await ios.presentNativeDialog(_alert),
        const LiquidNativeDialogUnavailable(
          LiquidNativeDialogUnavailableReason.channelError,
        ),
      );
    }
    expect(logs.where((l) => l.contains('presentDialog')), hasLength(1));
  });

  test('debug hooks read the snapshot and respond', () async {
    expect(await ios.debugNativeDialog(), isNull);
    dialogs.snapshot = NativeDialogSnapshot(
      kind: NativeDialogKind.actionSheet,
      title: 'Photo',
      labels: ['Delete', 'Cancel'],
      sourceRect: NativeRect(x: 1, y: 2, width: 3, height: 4),
    );
    final shot = (await ios.debugNativeDialog())!;
    expect(shot.actionSheet, isTrue);
    expect(shot.title, 'Photo');
    expect(shot.message, isNull);
    expect(shot.labels, ['Delete', 'Cancel']);
    expect(shot.preferredIndex, isNull);
    expect(shot.sourceRect, const Rect.fromLTWH(1, 2, 3, 4));
    await ios.debugRespondToNativeDialog(-1);
    expect(dialogs.responses, [-1]);
  });

  test('present travels on the generated channel', () async {
    const name =
        'dev.flutter.pigeon.liquid_shell_ios.NativeDialogHostApi.present';
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    Object? received;
    messenger.setMockMessageHandler(name, (message) async {
      received = NativeDialogHostApi.pigeonChannelCodec.decodeMessage(message);
      return NativeDialogHostApi.pigeonChannelCodec.encodeMessage(<Object?>[
        NativeDialogResult(outcome: NativeDialogOutcome.chose, actionIndex: 0),
      ]);
    });
    addTearDown(() => messenger.setMockMessageHandler(name, null));
    expect(
      await LiquidShellIOS().presentNativeDialog(_alert),
      const LiquidNativeDialogChose(0),
    );
    expect((received! as List<Object?>).single, isA<NativeDialogRequest>());
  });
}
