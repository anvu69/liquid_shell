import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/dialogs/dialog_layout.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

const _cancel = LiquidNativeDialogAction(
  label: 'Cancel',
  style: LiquidNativeDialogActionStyle.cancel,
);
const _a = LiquidNativeDialogAction(label: 'A');
const _b = LiquidNativeDialogAction(label: 'B');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('alertDisplayOrder', () {
    test('side by side, the cancel action leads', () {
      expect(alertDisplayOrder(const [_a, _cancel], sideBySide: true), [1, 0]);
      expect(alertDisplayOrder(const [_cancel, _a], sideBySide: true), [0, 1]);
    });

    test('stacked, the cancel action comes last', () {
      expect(alertDisplayOrder(const [_cancel, _a, _b], sideBySide: false), [
        1,
        2,
        0,
      ]);
    });

    test("without a cancel action the order is the app's", () {
      expect(alertDisplayOrder(const [_b, _a], sideBySide: true), [0, 1]);
    });
  });

  test('sheetGroups keeps the cancel action apart', () {
    // A record compares its list field by identity, so check field by field.
    final apart = sheetGroups(const [_a, _cancel, _b]);
    expect(apart.main, [0, 2]);
    expect(apart.cancel, 1);
    final none = sheetGroups(const [_a, _b]);
    expect(none.main, [0, 1]);
    expect(none.cancel, isNull);
  });

  group('alertActionsSideBySide', () {
    const style = TextStyle(fontSize: 17);
    bool fits(List<String> labels, {double scale = 1}) =>
        alertActionsSideBySide(
          labels: labels,
          style: style,
          textScaler: TextScaler.linear(scale),
          textDirection: TextDirection.ltr,
          rowWidth: 260,
        );

    // flutter_test's font draws every glyph 1em wide: 17pt per character.
    test('two short labels fit', () => expect(fits(['No', 'OK']), isTrue));
    test('one or three actions never sit side by side', () {
      expect(fits(['OK']), isFalse);
      expect(fits(['A', 'B', 'C']), isFalse);
    });
    test('a long label stacks', () {
      expect(fits(['Cancel', 'Discard every change on this page']), isFalse);
    });
    test('large text stacks', () {
      expect(fits(['Keep editing', 'Discard'], scale: 3), isFalse);
    });
  });

  group('anchoredCardOffset', () {
    const screen = Size(1194, 834);
    const padding = EdgeInsets.only(top: 24, bottom: 20);
    const card = Size(320, 200);

    test('below the anchor, centred on it', () {
      final offset = anchoredCardOffset(
        screen: screen,
        padding: padding,
        card: card,
        anchor: const Rect.fromLTWH(400, 100, 120, 44),
      );
      expect(offset, const Offset(300, 152));
    });

    test('above the anchor when there is no room below', () {
      final offset = anchoredCardOffset(
        screen: screen,
        padding: padding,
        card: card,
        anchor: const Rect.fromLTWH(400, 700, 120, 44),
      );
      expect(offset.dy, 700 - 8 - 200);
    });

    test('clamped to the screen edge', () {
      final offset = anchoredCardOffset(
        screen: screen,
        padding: padding,
        card: card,
        anchor: const Rect.fromLTWH(1150, 100, 40, 40),
      );
      expect(offset.dx, 1194 - 8 - 320);
    });

    test('centred without an anchor', () {
      final offset = anchoredCardOffset(
        screen: screen,
        padding: padding,
        card: card,
        anchor: null,
      );
      expect(offset, const Offset((1194 - 320) / 2, (834 - 200) / 2));
    });
  });
}
