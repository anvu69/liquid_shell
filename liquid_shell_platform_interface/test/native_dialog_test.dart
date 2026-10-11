import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// The interface's defaults, with no platform behind them.
class _Bare extends LiquidShellPlatform {
  @override
  Stream<LiquidPlatformSignals> watchSignals() => const Stream.empty();
}

const _actions = [
  LiquidNativeDialogAction(
    label: 'Delete',
    style: LiquidNativeDialogActionStyle.destructive,
  ),
  LiquidNativeDialogAction(
    label: 'Cancel',
    style: LiquidNativeDialogActionStyle.cancel,
  ),
];

const _request = LiquidNativeDialogRequest(
  kind: LiquidNativeDialogKind.actionSheet,
  title: 'Delete?',
  message: 'It cannot be undone.',
  actions: _actions,
  preferredIndex: 0,
  anchor: Rect.fromLTWH(10, 20, 30, 40),
  tintArgb: 0xFF3D5AFE,
  dark: true,
  rtl: false,
  requireGlass: true,
);

LiquidNativeDialogRequest _with({
  LiquidNativeDialogKind kind = LiquidNativeDialogKind.actionSheet,
  String? title = 'Delete?',
  String? message = 'It cannot be undone.',
  List<LiquidNativeDialogAction> actions = _actions,
  int? preferredIndex = 0,
  Rect? anchor = const Rect.fromLTWH(10, 20, 30, 40),
  int tintArgb = 0xFF3D5AFE,
  bool dark = true,
  bool rtl = false,
  bool requireGlass = true,
}) => LiquidNativeDialogRequest(
  kind: kind,
  title: title,
  message: message,
  actions: actions,
  preferredIndex: preferredIndex,
  anchor: anchor,
  tintArgb: tintArgb,
  dark: dark,
  rtl: rtl,
  requireGlass: requireGlass,
);

void main() {
  group('LiquidNativeDialogAction', () {
    test('defaults to a standard, enabled action', () {
      const action = LiquidNativeDialogAction(label: 'OK');
      expect(action.style, LiquidNativeDialogActionStyle.standard);
      expect(action.enabled, isTrue);
    });

    test('== and hashCode compare every field', () {
      const a = LiquidNativeDialogAction(label: 'OK');
      expect(a, const LiquidNativeDialogAction(label: 'OK'));
      expect(a.hashCode, const LiquidNativeDialogAction(label: 'OK').hashCode);
      expect(a, isNot(const LiquidNativeDialogAction(label: 'No')));
      expect(
        a,
        isNot(
          const LiquidNativeDialogAction(
            label: 'OK',
            style: LiquidNativeDialogActionStyle.cancel,
          ),
        ),
      );
      expect(
        a,
        isNot(const LiquidNativeDialogAction(label: 'OK', enabled: false)),
      );
    });
  });

  group('LiquidNativeDialogRequest', () {
    test('== compares every field, the actions by value', () {
      expect(_with(), _request);
      expect(_with().hashCode, _request.hashCode);
      expect(_with(actions: List.of(_actions)), _request);
      for (final other in [
        _with(kind: LiquidNativeDialogKind.alert),
        _with(title: 'Other'),
        _with(message: null),
        _with(actions: const [LiquidNativeDialogAction(label: 'OK')]),
        _with(preferredIndex: 1),
        _with(anchor: const Rect.fromLTWH(0, 0, 1, 1)),
        _with(tintArgb: 0),
        _with(dark: false),
        _with(rtl: true),
        _with(requireGlass: false),
      ]) {
        expect(other, isNot(_request));
      }
    });
  });

  group('LiquidNativeDialogResult', () {
    test('results compare by value', () {
      expect(
        const LiquidNativeDialogChose(1),
        const LiquidNativeDialogChose(1),
      );
      expect(
        const LiquidNativeDialogChose(1),
        isNot(const LiquidNativeDialogChose(2)),
      );
      expect(
        const LiquidNativeDialogDismissed(),
        const LiquidNativeDialogDismissed(),
      );
      expect(
        const LiquidNativeDialogUnavailable(
          LiquidNativeDialogUnavailableReason.osTooOld,
        ),
        const LiquidNativeDialogUnavailable(
          LiquidNativeDialogUnavailableReason.osTooOld,
        ),
      );
      expect(
        const LiquidNativeDialogUnavailable(
          LiquidNativeDialogUnavailableReason.osTooOld,
        ),
        isNot(
          const LiquidNativeDialogUnavailable(
            LiquidNativeDialogUnavailableReason.noWindow,
          ),
        ),
      );
    });

    test('a switch over the sealed result needs no default', () {
      String name(LiquidNativeDialogResult result) => switch (result) {
        LiquidNativeDialogChose(:final index) => 'chose $index',
        LiquidNativeDialogDismissed() => 'dismissed',
        LiquidNativeDialogUnavailable(:final reason) => reason.name,
      };
      expect(name(const LiquidNativeDialogChose(2)), 'chose 2');
      expect(name(const LiquidNativeDialogDismissed()), 'dismissed');
    });
  });

  test('the default platform has no native dialogs', () async {
    final platform = _Bare();
    expect(platform.supportsNativeDialogs, isFalse);
    expect(
      await platform.presentNativeDialog(_request),
      const LiquidNativeDialogUnavailable(
        LiquidNativeDialogUnavailableReason.unsupportedPlatform,
      ),
    );
  });
}
