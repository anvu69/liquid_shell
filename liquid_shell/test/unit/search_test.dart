import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/search/search_controller.dart';
import 'package:liquid_shell/src/search/search_layout.dart';

class _Driver implements SearchDriver {
  final calls = <String>[];

  @override
  void activate() => calls.add('activate');

  @override
  void deactivate() => calls.add('deactivate');

  @override
  void textSetByApp(String text) => calls.add('text $text');
}

void main() {
  group('LiquidSearchValue', () {
    test('compares field by field and copies', () {
      const value = LiquidSearchValue(text: 'hồ', composing: true);
      expect(value, const LiquidSearchValue(text: 'hồ', composing: true));
      expect(value, isNot(const LiquidSearchValue(text: 'hồ')));
      expect(value.copyWith(active: true).active, isTrue);
      expect(value.copyWith(scopeIndex: 2).text, 'hồ');
      const empty = LiquidSearchValue.empty;
      expect(
        (empty.text, empty.composing, empty.active, empty.scopeIndex),
        ('', false, false, 0),
      );
      expect(
        value.toString(),
        'LiquidSearchValue(text: hồ, composing: true, active: false, '
        'scopeIndex: 0)',
      );
    });
  });

  group('LiquidSearchController', () {
    test(
      'the app sets the text: listeners hear it and the driver sends it',
      () {
        final controller = LiquidSearchController(text: 'a');
        addTearDown(controller.dispose);
        final driver = _Driver();
        attachSearchDriver(controller, driver);
        var heard = 0;
        controller
          ..addListener(() => heard++)
          ..text = 'ab';
        expect(controller.text, 'ab');
        expect(heard, 1);
        expect(driver.calls, ['text ab']);
        controller.text = 'ab';
        expect(heard, 1, reason: 'same text: nothing');
        controller.clear();
        expect(driver.calls, ['text ab', 'text ']);
      },
    );

    test('commands reach the driver; without one they do nothing', () {
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      controller
        ..activate()
        ..deactivate();
      final driver = _Driver();
      attachSearchDriver(controller, driver);
      controller
        ..activate()
        ..deactivate();
      expect(driver.calls, ['activate', 'deactivate']);
      detachSearchDriver(controller, driver);
      controller.activate();
      expect(driver.calls, ['activate', 'deactivate']);
    });

    test('a platform edit changes the value without reaching the driver', () {
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      final driver = _Driver();
      attachSearchDriver(controller, driver);
      applySearchEdit(
        controller,
        const LiquidSearchValue(text: 'hô', composing: true, active: true),
      );
      expect(controller.value.composing, isTrue);
      expect(controller.isActive, isTrue);
      expect(driver.calls, isEmpty);
    });

    test('scopeIndex notifies', () {
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      var heard = 0;
      controller
        ..addListener(() => heard++)
        ..scopeIndex = 1;
      expect(controller.scopeIndex, 1);
      expect(heard, 1);
    });

    test('a user edit is never echoed back, even when the app listens and '
        'writes the same text (Telex: no marked text)', () {
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      final driver = _Driver();
      attachSearchDriver(controller, driver);
      final heard = <LiquidSearchValue>[];
      controller.addListener(() {
        heard.add(controller.value);
        // An app that mirrors the query back into the controller.
        final mirrored = controller.value.text;
        controller.text = mirrored;
      });
      for (final text in ['h', 'ho', 'hoo', 'hô']) {
        applySearchEdit(
          controller,
          LiquidSearchValue(text: text, active: true),
        );
      }
      expect(heard.map((v) => v.text), ['h', 'ho', 'hoo', 'hô']);
      expect(driver.calls, isEmpty, reason: 'no setText back for user edits');
    });

    test('the app setting the same text while composing changes nothing '
        '(review I-1)', () {
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      final driver = _Driver();
      attachSearchDriver(controller, driver);
      var heard = 0;
      controller.addListener(() {
        heard++;
        final mirrored = controller.value.text;
        controller.text = mirrored;
      });
      applySearchEdit(
        controller,
        const LiquidSearchValue(text: 'か', composing: true, active: true),
      );
      expect(driver.calls, isEmpty);
      expect(controller.value.composing, isTrue);
      expect(heard, 1);
    });

    test('value= is the app path: a text change reaches the field '
        '(review I-2)', () {
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      final driver = _Driver();
      attachSearchDriver(controller, driver);
      controller.value = controller.value.copyWith(text: 'x');
      expect(controller.text, 'x');
      expect(driver.calls, ['text x']);
    });

    test('value= keeps the platform-owned active and composing '
        '(review I-2)', () {
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      final driver = _Driver();
      attachSearchDriver(controller, driver);
      var heard = 0;
      controller
        ..addListener(() => heard++)
        ..value = controller.value.copyWith(active: true, composing: true);
      expect(controller.isActive, isFalse);
      expect(controller.value.composing, isFalse);
      expect(heard, 0);
      expect(driver.calls, isEmpty);

      applySearchEdit(
        controller,
        const LiquidSearchValue(text: 'か', composing: true, active: true),
      );
      controller.value = controller.value.copyWith(scopeIndex: 1);
      expect(
        controller.value,
        const LiquidSearchValue(
          text: 'か',
          composing: true,
          active: true,
          scopeIndex: 1,
        ),
      );
      expect(driver.calls, isEmpty, reason: 'same text: no setText');

      controller.value = controller.value.copyWith(text: 'き');
      expect(controller.value.composing, isFalse);
      expect(controller.isActive, isTrue);
      expect(driver.calls, ['text き']);
    });

    test('a negative scopeIndex asserts (review M-3)', () {
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      expect(() => controller.scopeIndex = -1, throwsAssertionError);
    });

    test('a second driver asserts', () {
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      attachSearchDriver(controller, _Driver());
      expect(
        () => attachSearchDriver(controller, _Driver()),
        throwsAssertionError,
      );
    });
  });

  group('LiquidSearch', () {
    test('compares field by field', () {
      final controller = LiquidSearchController();
      addTearDown(controller.dispose);
      void submitted(String _) {}
      expect(
        LiquidSearch(
          controller: controller,
          placeholder: 'x',
          onSubmitted: submitted,
        ),
        LiquidSearch(
          controller: controller,
          placeholder: 'x',
          onSubmitted: submitted,
        ),
      );
      expect(
        LiquidSearch(controller: controller),
        isNot(LiquidSearch(controller: controller, placeholder: 'x')),
      );
    });
  });

  group('layout', () {
    const search = LiquidDestination(
      icon: Icon(Icons.search),
      label: 'Search',
      role: LiquidDestinationRole.search,
    );
    const home = LiquidDestination(icon: Icon(Icons.home), label: 'Home');

    test('searchIndexOf finds the first search destination', () {
      expect(searchIndexOf(const [home]), isNull);
      expect(searchIndexOf(const [home, search]), 1);
    });

    test('searchPhaseFor', () {
      expect(
        searchPhaseFor(selected: 0, searchIndex: 1, active: true),
        LiquidSearchPhase.idle,
      );
      expect(
        searchPhaseFor(selected: 1, searchIndex: 1, active: false),
        LiquidSearchPhase.selected,
      );
      expect(
        searchPhaseFor(selected: 1, searchIndex: 1, active: true),
        LiquidSearchPhase.active,
      );
      expect(
        searchPhaseFor(selected: 0, searchIndex: null, active: false),
        LiquidSearchPhase.idle,
      );
    });

    group('nativeSearchBottomInset', () {
      const size = Size(402, 874);
      const padding = EdgeInsets.only(top: 62, bottom: 83);

      test('no field, or a field at the top: nothing', () {
        expect(
          nativeSearchBottomInset(
            field: Rect.zero,
            size: size,
            padding: padding,
            viewInsets: EdgeInsets.zero,
            active: true,
          ),
          0,
        );
        expect(
          nativeSearchBottomInset(
            field: const Rect.fromLTWH(16, 86, 370, 44),
            size: size,
            padding: padding,
            viewInsets: EdgeInsets.zero,
            active: true,
          ),
          0,
        );
      });

      test('selected (field in the tab bar area): the bottom padding', () {
        expect(
          nativeSearchBottomInset(
            field: const Rect.fromLTWH(88, 798, 286, 48),
            size: size,
            padding: padding,
            viewInsets: EdgeInsets.zero,
            active: false,
          ),
          83,
        );
      });

      test(
        'active above the keyboard: down to the field top or the keyboard',
        () {
          // Settled: keyboard 328, field 8pt above it at y 490:
          // max(874 − 490, 328 + 48 + 16) = 392.
          expect(
            nativeSearchBottomInset(
              field: const Rect.fromLTWH(8, 490, 330, 48),
              size: size,
              padding: EdgeInsets.zero,
              viewInsets: const EdgeInsets.only(bottom: 328),
              active: true,
            ),
            392,
          );
          // Keyboard still rising (Flutter's insets animate first): the
          // keyboard-based term leads: max(874 − 798, 200 + 48 + 16) = 264.
          expect(
            nativeSearchBottomInset(
              field: const Rect.fromLTWH(88, 798, 286, 48),
              size: size,
              padding: EdgeInsets.zero,
              viewInsets: const EdgeInsets.only(bottom: 200),
              active: true,
            ),
            264,
          );
        },
      );
    });
  });

  group('fallback geometry', () {
    const size = Size(393, 852);
    // P1's bottom row: 62pt pill, 21pt gap above the screen edge.
    const rowBottom = 852.0 - 21;

    CompactSearchRects rects(
      LiquidSearchPhase phase, {
      double keyboard = 0,
      TextDirection direction = TextDirection.ltr,
    }) => compactSearchRects(
      phase: phase,
      size: size,
      rowBottom: rowBottom,
      rowExtent: 62,
      margin: 16,
      keyboard: keyboard,
      direction: direction,
    );

    test('idle: the ⌕ circle at the trailing end of the row', () {
      expect(
        rects(LiquidSearchPhase.idle).field,
        const Rect.fromLTWH(393 - 16 - 62, rowBottom - 62, 62, 62),
      );
    });

    test('selected: circle at 28, field from 88 to 28 from the end', () {
      final r = rects(LiquidSearchPhase.selected);
      expect(r.circle, const Rect.fromLTWH(28, rowBottom - 62 + 7, 48, 48));
      expect(
        r.field,
        const Rect.fromLTRB(
          88,
          rowBottom - 62 + 7,
          393 - 28,
          rowBottom - 62 + 55,
        ),
      );
    });

    test('active: field and × 8pt above the keyboard', () {
      final r = rects(LiquidSearchPhase.active, keyboard: 336);
      const bottom = 852.0 - 336 - 8;
      expect(
        r.field,
        const Rect.fromLTRB(8, bottom - 48, 393 - 8 - 48 - 8, bottom),
      );
      expect(r.cancel, const Rect.fromLTWH(393 - 8 - 48, bottom - 48, 48, 48));
    });

    test('active without a software keyboard stays in the row', () {
      final r = rects(LiquidSearchPhase.active);
      expect(r.field.bottom, rowBottom - 62 + 55);
    });

    test('RTL mirrors every rect', () {
      final ltr = rects(LiquidSearchPhase.selected);
      final rtl = rects(
        LiquidSearchPhase.selected,
        direction: TextDirection.rtl,
      );
      expect(rtl.circle.left, 393 - ltr.circle.right);
      expect(rtl.field.right, 393 - ltr.field.left);
    });

    test(
      'regular field top: one row below the bar, the bar row when active',
      () {
        expect(
          regularSearchFieldTop(
            phase: LiquidSearchPhase.selected,
            paddingTop: 24,
            barExtent: 52,
            tiled: false,
          ),
          24 + 20 + 52 + 8,
        );
        expect(
          regularSearchFieldTop(
            phase: LiquidSearchPhase.active,
            paddingTop: 24,
            barExtent: 52,
            tiled: false,
          ),
          24 + 20,
        );
        expect(
          regularSearchFieldTop(
            phase: LiquidSearchPhase.selected,
            paddingTop: 24,
            barExtent: 52,
            tiled: true,
          ),
          24 + 54,
        );
        expect(
          regularSearchFieldTop(
            phase: LiquidSearchPhase.active,
            paddingTop: 24,
            barExtent: 52,
            tiled: true,
          ),
          24 + 5,
        );
      },
    );
  });
}
