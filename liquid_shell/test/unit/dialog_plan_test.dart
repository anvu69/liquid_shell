import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
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

/// Takes its parent's size and never lays out, paints or describes its
/// child, so the child's box is attached but has no size.
class _NeverLaysOut extends SingleChildRenderObjectWidget {
  const _NeverLaysOut({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderNeverLaysOut();
}

class _RenderNeverLaysOut extends RenderProxyBox {
  @override
  void performLayout() => size = constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {}

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {}
}

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

    test('rejects a dialog the user could never leave', () {
      final trapped = <List<LiquidAlertAction<_Pick>>>[
        const [
          LiquidAlertAction(label: 'A', value: _Pick.keep, enabled: false),
        ],
        const [
          LiquidAlertAction(
            label: 'Keep editing',
            value: _Pick.keep,
            style: LiquidAlertActionStyle.cancel,
            enabled: false,
          ),
          LiquidAlertAction(label: 'B', value: _Pick.later, enabled: false),
        ],
        const [
          _keep,
          LiquidAlertAction(
            label: 'Discard',
            value: _Pick.discard,
            preferred: true,
            enabled: false,
          ),
        ],
      ];
      for (final actions in trapped) {
        expect(
          () => checkAlertActions(actions),
          throwsArgumentError,
          reason: '$actions',
        );
      }
    });

    test('accepts a disabled action beside an enabled one', () {
      checkAlertActions(const [
        _keep,
        LiquidAlertAction(label: 'Later', value: _Pick.later, enabled: false),
      ]);
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

  group('anchorOf', () {
    testWidgets('is null before layout', (tester) async {
      Rect? during = const Rect.fromLTWH(1, 1, 1, 1);
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            during = anchorOf(context);
            return const SizedBox(width: 10, height: 10);
          },
        ),
      );
      expect(during, isNull);
    });

    testWidgets('is null for a box that was never laid out', (tester) async {
      const key = Key('unsized');
      await tester.pumpWidget(
        const _NeverLaysOut(child: SizedBox(key: key, width: 10, height: 10)),
      );
      expect(anchorOf(tester.element(find.byKey(key))), isNull);
    });

    testWidgets('is null for a context without a box', (tester) async {
      late BuildContext sliver;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: CustomScrollView(
            slivers: [
              Builder(
                builder: (context) {
                  sliver = context;
                  return const SliverToBoxAdapter(
                    child: SizedBox(height: 10),
                  );
                },
              ),
            ],
          ),
        ),
      );
      expect(anchorOf(sliver), isNull);
    });

    testWidgets('is the laid-out box in global coordinates', (tester) async {
      const key = Key('box');
      await tester.pumpWidget(
        const Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 30, top: 50),
            child: SizedBox(key: key, width: 20, height: 10),
          ),
        ),
      );
      expect(
        anchorOf(tester.element(find.byKey(key))),
        const Rect.fromLTWH(30, 50, 20, 10),
      );
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
