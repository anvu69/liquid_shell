import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/dialogs/dialog_plan.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

enum _Pick { keep, discard, later }

const _keep = LiquidAlertAction<_Pick>(
  label: 'Keep editing',
  value: _Pick.keep,
  style: LiquidAlertActionStyle.cancel,
);
const _discard = LiquidAlertAction<_Pick>(
  label: 'Discard',
  value: _Pick.discard,
  style: LiquidAlertActionStyle.destructive,
);
const _later = LiquidAlertAction<_Pick>(label: 'Later', value: _Pick.later);

void main() {
  group('checkAlertActions', () {
    test('accepts a normal set', () {
      checkAlertActions(const [_keep, _discard]);
    });

    test('rejects what UIKit would crash on or draw blank', () {
      final bad = <List<LiquidAlertAction<_Pick>>>[
        const [],
        const [_keep, _keep],
        const [
          LiquidAlertAction(label: 'A', value: _Pick.keep, preferred: true),
          LiquidAlertAction(label: 'B', value: _Pick.later, preferred: true),
        ],
        const [LiquidAlertAction(label: '  ', value: _Pick.keep)],
      ];
      for (final actions in bad) {
        expect(() => checkAlertActions(actions), throwsArgumentError);
      }
    });
  });

  group('dialogValue', () {
    test('an index picks its action', () {
      expect(dialogValue(const [_keep, _discard], 1), _Pick.discard);
    });

    test('a dismissal picks the cancel action, else null', () {
      expect(dialogValue(const [_discard, _keep], null), _Pick.keep);
      expect(dialogValue(const [_discard, _later], null), isNull);
    });
  });

  group('NativeDialogMemory', () {
    tearDown(NativeDialogMemory.debugReset);

    test('remembers what cannot change while the process runs', () {
      final memory = NativeDialogMemory.instance;
      expect(memory.refuses(requireGlass: true), isFalse);
      memory.remember(
        LiquidNativeDialogUnavailableReason.osTooOld,
        requireGlass: true,
      );
      expect(memory.refuses(requireGlass: true), isTrue);
      expect(memory.refuses(requireGlass: false), isFalse);
      memory.remember(
        LiquidNativeDialogUnavailableReason.disabledByEnvironment,
        requireGlass: false,
      );
      expect(memory.refuses(requireGlass: false), isTrue);
    });

    test('forgets nothing it should retry', () {
      final memory = NativeDialogMemory.instance;
      for (final reason in [
        LiquidNativeDialogUnavailableReason.noWindow,
        LiquidNativeDialogUnavailableReason.refused,
        LiquidNativeDialogUnavailableReason.channelError,
        LiquidNativeDialogUnavailableReason.unsupportedPlatform,
      ]) {
        memory.remember(reason, requireGlass: true);
      }
      expect(memory.refuses(requireGlass: true), isFalse);
    });

    test('debugResetLiquidNative forgets', () {
      NativeDialogMemory.instance.remember(
        LiquidNativeDialogUnavailableReason.disabledByEnvironment,
        requireGlass: true,
      );
      debugResetLiquidNative();
      expect(NativeDialogMemory.instance.refuses(requireGlass: true), isFalse);
    });
  });

  test('LiquidAlertAction == compares every field', () {
    expect(
      _keep,
      const LiquidAlertAction(
        label: 'Keep editing',
        value: _Pick.keep,
        style: LiquidAlertActionStyle.cancel,
      ),
    );
    expect(_keep, isNot(_discard));
    expect(
      _later,
      isNot(
        const LiquidAlertAction(
          label: 'Later',
          value: _Pick.later,
          enabled: false,
        ),
      ),
    );
    expect(
      _later,
      isNot(
        const LiquidAlertAction(
          label: 'Later',
          value: _Pick.later,
          preferred: true,
        ),
      ),
    );
  });
}
