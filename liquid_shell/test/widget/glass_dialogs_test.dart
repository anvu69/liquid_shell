import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/dialogs/dialog_metrics.dart';
import 'package:liquid_shell/src/dialogs/glass_dialogs.dart';
import 'package:liquid_shell/src/glass/liquid_backdrop.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

const _cancel = LiquidNativeDialogAction(
  label: 'Keep editing',
  style: LiquidNativeDialogActionStyle.cancel,
);
const _discard = LiquidNativeDialogAction(
  label: 'Discard',
  style: LiquidNativeDialogActionStyle.destructive,
);
const _share = LiquidNativeDialogAction(label: 'Share');
// Short enough to sit side by side in flutter_test's font, which draws
// every glyph 1em wide.
const _no = LiquidNativeDialogAction(
  label: 'No',
  style: LiquidNativeDialogActionStyle.cancel,
);
const _yes = LiquidNativeDialogAction(
  label: 'Yes',
  style: LiquidNativeDialogActionStyle.destructive,
);

LiquidNativeDialogRequest _request({
  LiquidNativeDialogKind kind = LiquidNativeDialogKind.alert,
  List<LiquidNativeDialogAction> actions = const [_cancel, _discard],
  int? preferredIndex,
  Rect? anchor,
}) => LiquidNativeDialogRequest(
  kind: kind,
  title: 'Discard changes?',
  message: 'Your edits will be lost.',
  actions: actions,
  preferredIndex: preferredIndex,
  anchor: anchor,
  tintArgb: 0,
  dark: false,
  rtl: false,
  requireGlass: true,
);

const _phone = Size(393, 852);
const _tablet = Size(1194, 834);

/// Opens [request] from a button; returns the answers it completes with.
Future<List<int?>> _open(
  WidgetTester tester,
  LiquidNativeDialogRequest request, {
  Size size = _phone,
  TextDirection direction = TextDirection.ltr,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);
  final answers = <int?>[];
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: Builder(
        builder: (context) => Align(
          alignment: Alignment.bottomCenter,
          child: TextButton(
            onPressed: () async =>
                answers.add(await showGlassDialog(context, request)),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return answers;
}

Finder _in(Type dialog, Finder finder) =>
    find.descendant(of: find.byType(dialog), matching: finder);

void main() {
  test('strings: dismiss defaults to English and joins ==', () {
    expect(const LiquidShellStrings().dismiss, 'Dismiss');
    expect(
      const LiquidShellStrings(dismiss: 'Đóng'),
      isNot(const LiquidShellStrings()),
    );
  });

  group('alert', () {
    testWidgets('shows its text on glass; a tap answers the index', (
      tester,
    ) async {
      final answers = await _open(tester, _request());
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text('Your edits will be lost.'), findsOneWidget);
      expect(_in(GlassAlert, find.byType(LiquidGlass)), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(answers, [1]);
      expect(find.byType(GlassAlert), findsNothing);
    });

    testWidgets('two short actions sit side by side, cancel leading', (
      tester,
    ) async {
      await _open(tester, _request(actions: const [_yes, _no]));
      final no = tester.getCenter(find.text('No'));
      final yes = tester.getCenter(find.text('Yes'));
      expect(no.dy, yes.dy);
      expect(no.dx, lessThan(yes.dx));
    });

    testWidgets('right to left mirrors the pair', (tester) async {
      await _open(
        tester,
        _request(actions: const [_no, _yes]),
        direction: TextDirection.rtl,
      );
      expect(
        tester.getCenter(find.text('No')).dx,
        greaterThan(tester.getCenter(find.text('Yes')).dx),
      );
    });

    testWidgets('three actions stack, cancel last', (tester) async {
      await _open(tester, _request(actions: const [_cancel, _share, _discard]));
      final ys = [
        for (final label in ['Share', 'Discard', 'Keep editing'])
          tester.getCenter(find.text(label)).dy,
      ];
      expect(ys[0], lessThan(ys[1]));
      expect(ys[1], lessThan(ys[2]));
    });

    testWidgets('a label too long for half the row stacks', (tester) async {
      const long = LiquidNativeDialogAction(
        label: 'Discard every change on this page',
      );
      await _open(tester, _request(actions: const [_cancel, long]));
      expect(
        tester.getCenter(find.text('Keep editing')).dy,
        greaterThan(tester.getCenter(find.text(long.label)).dy),
      );
    });

    testWidgets('the barrier does not dismiss an alert', (tester) async {
      final answers = await _open(tester, _request());
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byType(GlassAlert), findsOneWidget);
      expect(answers, isEmpty);
    });

    testWidgets('Escape answers cancel, Enter the preferred action', (
      tester,
    ) async {
      final answers = await _open(tester, _request(preferredIndex: 1));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(answers, [0, 1]);
    });

    // Measured on iOS 26.5 (docs/qa/p3a/metrics.md): a preferred standard
    // action is a filled capsule; a preferred destructive one is only bold.
    group('the preferred action', () {
      Color? fill(WidgetTester tester, String label) => tester
          .widget<Material>(
            find
                .ancestor(of: find.text(label), matching: find.byType(Material))
                .first,
          )
          .color;
      const ok = LiquidNativeDialogAction(label: 'OK');

      testWidgets('is filled with the primary colour', (tester) async {
        await _open(
          tester,
          _request(actions: const [_cancel, ok, _discard], preferredIndex: 1),
        );
        final scheme = Theme.of(tester.element(find.text('OK'))).colorScheme;
        expect(fill(tester, 'OK'), scheme.primary);
        expect(fill(tester, 'Discard'), fill(tester, 'Keep editing'));
      });

      testWidgets('is not filled when destructive', (tester) async {
        await _open(tester, _request(preferredIndex: 1));
        expect(fill(tester, 'Discard'), fill(tester, 'Keep editing'));
      });
    });

    testWidgets('a disabled action does not answer', (tester) async {
      const later = LiquidNativeDialogAction(label: 'Later', enabled: false);
      final answers = await _open(
        tester,
        _request(actions: const [_cancel, later]),
      );
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(answers, isEmpty);
      expect(find.byType(GlassAlert), findsOneWidget);
    });

    // Review VK-406 T4 #1: Enter is Return-for-default only when there is
    // an enabled default; otherwise it activates the focused button.
    testWidgets('without a preferred action Enter activates the focused one', (
      tester,
    ) async {
      final answers = await _open(tester, _request());
      // Stacked in this font: Discard first (focused), then Keep editing.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(answers, [0]);
    });

    // Review VK-406 T4 #2: a disabled preferred action cannot take focus;
    // focus must still land below the key bindings.
    testWidgets('with a disabled preferred action Escape still cancels', (
      tester,
    ) async {
      const later = LiquidNativeDialogAction(label: 'Later', enabled: false);
      final answers = await _open(
        tester,
        _request(actions: const [_cancel, later], preferredIndex: 1),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(answers, [0]);
    });

    testWidgets('scales in; reduce motion only fades', (tester) async {
      Finder scale() => find.ancestor(
        of: find.byType(GlassAlert),
        matching: find.byType(ScaleTransition),
      );
      await _open(tester, _request());
      expect(scale(), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(scale(), findsNothing);
    });

    testWidgets('the route is named by its title', (tester) async {
      final semantics = tester.ensureSemantics();
      await _open(tester, _request());
      expect(find.bySemanticsLabel('Discard changes?'), findsWidgets);
      semantics.dispose();
    });
  });

  group('action sheet', () {
    LiquidNativeDialogRequest sheet({Rect? anchor}) => _request(
      kind: LiquidNativeDialogKind.actionSheet,
      actions: const [_discard, _share, _cancel],
      anchor: anchor,
    );

    testWidgets('on a phone the cancel action sits apart, below', (
      tester,
    ) async {
      final answers = await _open(tester, sheet());
      expect(_in(GlassActionSheet, find.byType(LiquidGlass)), findsNWidgets(2));
      expect(
        tester.getCenter(find.text('Keep editing')).dy,
        greaterThan(tester.getCenter(find.text('Share')).dy),
      );
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(answers, [1]);
    });

    testWidgets('a tap outside or Escape answers null', (tester) async {
      final answers = await _open(tester, sheet());
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(answers, [null, null]);
    });

    testWidgets('the barrier is labelled with strings.dismiss', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _open(tester, sheet());
      expect(find.bySemanticsLabel('Dismiss'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('on a tablet a card below the anchor, no cancel row', (
      tester,
    ) async {
      const anchor = Rect.fromLTWH(100, 200, 120, 44);
      final answers = await _open(tester, sheet(anchor: anchor), size: _tablet);
      expect(find.text('Keep editing'), findsNothing);
      final card = tester.getRect(
        _in(GlassActionSheet, find.byType(LiquidGlass)),
      );
      expect(card.top, greaterThanOrEqualTo(anchor.bottom));
      expect(card.width, kSheetPopoverWidth);
      await tester.tapAt(const Offset(1100, 60));
      await tester.pumpAndSettle();
      expect(answers, [null]);
    });

    testWidgets('an anchor near the bottom puts the card above it', (
      tester,
    ) async {
      const anchor = Rect.fromLTWH(100, 760, 120, 44);
      await _open(tester, sheet(anchor: anchor), size: _tablet);
      final card = tester.getRect(
        _in(GlassActionSheet, find.byType(LiquidGlass)),
      );
      expect(card.bottom, lessThanOrEqualTo(anchor.top));
    });
  });

  // Review VK-406 T4 #3/#4: at large text the content scrolls instead of
  // overflowing (UIKit does not clamp Dynamic Type in alerts either).
  testWidgets('at text scale 2 nothing overflows', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final long = List.filled(12, 'Your edits will be lost.').join(' ');
    LiquidNativeDialogRequest request(LiquidNativeDialogKind kind) =>
        LiquidNativeDialogRequest(
          kind: kind,
          title: 'Discard changes?',
          message: long,
          actions: const [_cancel, _share, _discard],
          tintArgb: 0,
          dark: false,
          rtl: false,
          requireGlass: true,
        );

    // An alert on a phone in landscape.
    await _open(
      tester,
      request(LiquidNativeDialogKind.alert),
      size: const Size(852, 393),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Keep editing'), findsOneWidget);
    await tester.tap(find.text('Keep editing'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // A compact action sheet on a phone in portrait.
    await tester.pumpWidget(const SizedBox());
    await _open(tester, request(LiquidNativeDialogKind.actionSheet));
    expect(tester.takeException(), isNull);
  });

  // Owner decision L3: the Flutter dialogs are LiquidGlass, so they take the
  // liquid tier wherever the shell's own glass does.
  testWidgets('alert and action sheet draw the liquid tier where it exists', (
    tester,
  ) async {
    debugLiquidGlassCanRefractOverride = true;
    // `ImageFilter.shader` throws without Impeller: a blur stands in.
    debugLiquidFilterFactory = (shader, sigma) =>
        ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
    addTearDown(() => debugLiquidFilterFactory = null);
    await tester.runAsync(LiquidGlass.precache);

    await _open(tester, _request());
    expect(_in(GlassAlert, find.byType(LiquidBackdrop)), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await _open(
      tester,
      _request(
        kind: LiquidNativeDialogKind.actionSheet,
        actions: const [_share, _cancel],
      ),
    );
    final sheetGlass = tester.widgetList(
      _in(GlassActionSheet, find.byType(LiquidGlass)),
    );
    expect(sheetGlass, isNotEmpty);
    expect(
      _in(GlassActionSheet, find.byType(LiquidBackdrop)),
      findsNWidgets(sheetGlass.length),
    );
  });
}
