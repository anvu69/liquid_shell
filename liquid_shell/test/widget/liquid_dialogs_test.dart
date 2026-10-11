import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/dialogs/glass_dialogs.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

import '../helpers/fake_native_platform.dart';

enum _Pick { keep, discard }

const _keep = LiquidAlertAction<_Pick>(
  label: 'Keep editing',
  value: _Pick.keep,
  style: LiquidAlertActionStyle.cancel,
);
const _discard = LiquidAlertAction<_Pick>(
  label: 'Discard',
  value: _Pick.discard,
  style: LiquidAlertActionStyle.destructive,
  preferred: true,
);

/// A page with one button that runs [show] and records its answers.
Future<List<Object?>> _launcher(
  WidgetTester tester,
  Future<Object?> Function(BuildContext button) show, {
  ThemeData? theme,
  TextDirection direction = TextDirection.ltr,
}) async {
  final answers = <Object?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 40, top: 120),
          child: Builder(
            builder: (button) => TextButton(
              key: const Key('open'),
              onPressed: () async => answers.add(await show(button)),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  return answers;
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
}

Future<_Pick?> _alert(
  BuildContext context, {
  LiquidDialogPresentation presentation = LiquidDialogPresentation.auto,
}) => showLiquidAlert(
  context,
  title: 'Discard changes?',
  message: 'Your edits will be lost.',
  actions: const [_keep, _discard],
  presentation: presentation,
);

/// A platform whose dialog channel fails with something other than a
/// `PlatformException`, such as a reply it cannot decode: [sync] throws at
/// once, otherwise the returned future fails.
class _BrokenNative extends FakeNativePlatform {
  _BrokenNative({required this.sync});

  final bool sync;

  @override
  Future<LiquidNativeDialogResult> presentNativeDialog(
    LiquidNativeDialogRequest request,
  ) {
    dialogRequests.add(request);
    const error = FormatException('undecodable reply');
    if (sync) throw error;
    return Future.error(error);
  }
}

/// Installs a [_BrokenNative] until the current test ends.
_BrokenNative _installBroken({required bool sync}) {
  final original = LiquidShellPlatform.instance;
  final broken = _BrokenNative(sync: sync);
  LiquidShellPlatform.instance = broken;
  addTearDown(() => LiquidShellPlatform.instance = original);
  return broken;
}

void main() {
  group('native', () {
    testWidgets('a native answer completes with its value, nothing Flutter', (
      tester,
    ) async {
      final fake = installFakeNative()
        ..dialogAnswers.add(const LiquidNativeDialogChose(1));
      final answers = await _launcher(tester, _alert);
      await _open(tester);
      expect(answers, [_Pick.discard]);
      expect(find.byType(GlassAlert), findsNothing);
      final request = fake.dialogRequests.single;
      expect(request.kind, LiquidNativeDialogKind.alert);
      expect(request.title, 'Discard changes?');
      expect(request.message, 'Your edits will be lost.');
      expect(request.actions, const [
        LiquidNativeDialogAction(
          label: 'Keep editing',
          style: LiquidNativeDialogActionStyle.cancel,
        ),
        LiquidNativeDialogAction(
          label: 'Discard',
          style: LiquidNativeDialogActionStyle.destructive,
        ),
      ]);
      expect(request.preferredIndex, 1);
      expect(request.anchor, isNull);
      expect(request.requireGlass, isTrue);
    });

    testWidgets('a dismissal is the cancel value, or null without one', (
      tester,
    ) async {
      final fake = installFakeNative()
        ..dialogAnswers.addAll(const [
          LiquidNativeDialogDismissed(),
          LiquidNativeDialogDismissed(),
        ]);
      final answers = await _launcher(
        tester,
        (context) async => [
          await _alert(context),
          await showLiquidAlert(
            context,
            title: 'Saved',
            actions: const [LiquidAlertAction(label: 'OK', value: 1)],
          ),
        ],
      );
      await _open(tester);
      expect(answers.single, [_Pick.keep, null]);
      expect(fake.dialogRequests, hasLength(2));
    });

    testWidgets('theme, direction and tint reach the platform', (
      tester,
    ) async {
      final fake = installFakeNative()
        ..dialogAnswers.add(const LiquidNativeDialogChose(0));
      final theme = ThemeData(
        colorSchemeSeed: const Color(0xFF3D5AFE),
        brightness: Brightness.dark,
      );
      await _launcher(
        tester,
        _alert,
        theme: theme,
        direction: TextDirection.rtl,
      );
      await _open(tester);
      final request = fake.dialogRequests.single;
      expect(request.dark, isTrue);
      expect(request.rtl, isTrue);
      expect(request.tintArgb, theme.colorScheme.primary.toARGB32());
    });

    testWidgets('system asks for the native dialog without glass', (
      tester,
    ) async {
      final fake = installFakeNative()
        ..dialogAnswers.add(const LiquidNativeDialogChose(0));
      await _launcher(
        tester,
        (c) => _alert(c, presentation: LiquidDialogPresentation.system),
      );
      await _open(tester);
      expect(fake.dialogRequests.single.requireGlass, isFalse);
    });

    testWidgets('a disabled action reaches the platform disabled', (
      tester,
    ) async {
      final fake = installFakeNative()
        ..dialogAnswers.add(const LiquidNativeDialogChose(0));
      await _launcher(
        tester,
        (context) => showLiquidAlert(
          context,
          title: 'Discard changes?',
          actions: const [
            _keep,
            LiquidAlertAction(
              label: 'Discard',
              value: _Pick.discard,
              style: LiquidAlertActionStyle.destructive,
              enabled: false,
            ),
          ],
        ),
      );
      await _open(tester);
      expect(
        fake.dialogRequests.single.actions.map((a) => a.enabled),
        [isTrue, isFalse],
      );
    });
  });

  group('fallback', () {
    testWidgets('osTooOld draws Flutter glass, and is not asked again', (
      tester,
    ) async {
      final fake = installFakeNative()
        ..dialogAnswers.add(
          const LiquidNativeDialogUnavailable(
            LiquidNativeDialogUnavailableReason.osTooOld,
          ),
        );
      final answers = await _launcher(tester, _alert);
      await _open(tester);
      expect(find.byType(GlassAlert), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();
      expect(answers, [_Pick.discard]);
      await _open(tester);
      expect(find.byType(GlassAlert), findsOneWidget);
      expect(fake.dialogRequests, hasLength(1));
    });

    testWidgets('noWindow falls back, and is asked again next time', (
      tester,
    ) async {
      final fake = installFakeNative()
        ..dialogAnswers.addAll(const [
          LiquidNativeDialogUnavailable(
            LiquidNativeDialogUnavailableReason.noWindow,
          ),
          LiquidNativeDialogChose(0),
        ]);
      final answers = await _launcher(tester, _alert);
      await _open(tester);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      await _open(tester);
      expect(answers, [_Pick.keep, _Pick.keep]);
      expect(fake.dialogRequests, hasLength(2));
    });

    testWidgets('flutter never asks the platform', (tester) async {
      final fake = installFakeNative();
      await _launcher(
        tester,
        (c) => _alert(c, presentation: LiquidDialogPresentation.flutter),
      );
      await _open(tester);
      expect(find.byType(GlassAlert), findsOneWidget);
      expect(fake.dialogRequests, isEmpty);
    });

    testWidgets('a platform without native dialogs draws Flutter at once', (
      tester,
    ) async {
      final fake = installFakeNative()..nativeDialogs = false;
      await _launcher(tester, _alert);
      await tester.tap(find.byKey(const Key('open')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byType(GlassAlert), findsOneWidget);
      expect(fake.dialogRequests, isEmpty);
    });

    testWidgets('a context gone before the fallback answers null', (
      tester,
    ) async {
      final fake = installFakeNative()..dialogGate = Completer();
      final answers = await _launcher(tester, _alert);
      await _open(tester);
      await tester.pumpWidget(const SizedBox());
      fake.dialogGate!.complete(
        const LiquidNativeDialogUnavailable(
          LiquidNativeDialogUnavailableReason.noWindow,
        ),
      );
      await tester.pumpAndSettle();
      expect(answers, [null]);
      expect(find.byType(GlassAlert), findsNothing);
    });

    for (final sync in [false, true]) {
      testWidgets(
        'a platform that throws ${sync ? 'at once' : 'later'} falls back, '
        'is reported, and is asked again',
        (tester) async {
          final broken = _installBroken(sync: sync);
          final answers = await _launcher(tester, _alert);
          await _open(tester);
          expect(tester.takeException(), isFormatException);
          expect(find.byType(GlassAlert), findsOneWidget);
          await tester.tap(find.text('Discard'));
          await tester.pumpAndSettle();
          expect(answers, [_Pick.discard]);
          await _open(tester);
          expect(tester.takeException(), isFormatException);
          expect(find.byType(GlassAlert), findsOneWidget);
          expect(broken.dialogRequests, hasLength(2));
        },
      );
    }
  });

  group('action sheet', () {
    Future<_Pick?> sheet(BuildContext button, {Rect? anchor}) =>
        showLiquidActionSheet(
          button,
          title: 'Photo',
          actions: const [_discard, _keep],
          anchor: anchor,
        );

    testWidgets('points at the tapped widget; never preferred', (
      tester,
    ) async {
      final fake = installFakeNative()
        ..dialogAnswers.add(const LiquidNativeDialogChose(0));
      final answers = await _launcher(tester, sheet);
      await _open(tester);
      final request = fake.dialogRequests.single;
      expect(request.kind, LiquidNativeDialogKind.actionSheet);
      expect(request.anchor, tester.getRect(find.byKey(const Key('open'))));
      expect(request.preferredIndex, isNull);
      expect(answers, [_Pick.discard]);
    });

    testWidgets('an explicit anchor wins', (tester) async {
      final fake = installFakeNative()
        ..dialogAnswers.add(const LiquidNativeDialogChose(1));
      const anchor = Rect.fromLTWH(1, 2, 3, 4);
      await _launcher(tester, (b) => sheet(b, anchor: anchor));
      await _open(tester);
      expect(fake.dialogRequests.single.anchor, anchor);
    });
  });

  group('validation', () {
    testWidgets('throws before anything is shown', (tester) async {
      final fake = installFakeNative();
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(
        () => showLiquidAlert<int>(context, title: 'T', actions: const []),
        throwsArgumentError,
      );
      expect(
        () => showLiquidAlert(
          context,
          title: ' ',
          actions: const [LiquidAlertAction(label: 'OK', value: 1)],
        ),
        throwsArgumentError,
      );
      expect(
        () => showLiquidActionSheet(context, actions: const [_keep, _keep]),
        throwsArgumentError,
      );
      expect(fake.dialogRequests, isEmpty);
    });
  });

  group('native chrome (spec P3a §8)', () {
    Widget shell(
      Widget body, {
      Future<bool> Function(int)? guard,
      ValueChanged<int>? onSelect,
    }) => MaterialApp(
      home: LiquidShell(
        destinations: const [
          LiquidDestination(
            icon: Icon(Icons.home),
            label: 'Home',
            sfSymbol: 'house',
          ),
          LiquidDestination(
            icon: Icon(Icons.inbox),
            label: 'Inbox',
            sfSymbol: 'tray',
          ),
        ],
        selectedIndex: 0,
        beforeDestinationChange: guard,
        onDestinationSelected: onSelect ?? (_) {},
        body: body,
      ),
    );

    testWidgets('a native alert leaves the compact native bar alone', (
      tester,
    ) async {
      final fake = installFakeNative(
        state: const LiquidNativeShellState(installed: true, compact: true),
      )..dialogGate = Completer();
      await tester.pumpWidget(
        shell(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => _alert(context),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = fake.configs.length;
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(fake.dialogRequests, hasLength(1));
      // No Flutter route above the shell: nothing changes natively.
      expect(fake.configs.length, before);
      expect(fake.last.interactive, isTrue);
      expect(fake.last.hidden, isFalse);
      fake.dialogGate!.complete(const LiquidNativeDialogChose(0));
      await tester.pumpAndSettle();
    });

    testWidgets('the Flutter fallback still hides the compact bar (P2)', (
      tester,
    ) async {
      final fake = installFakeNative(
        state: const LiquidNativeShellState(installed: true, compact: true),
      );
      await tester.pumpWidget(
        shell(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => _alert(
                context,
                presentation: LiquidDialogPresentation.flutter,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(fake.last.hidden, isTrue);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(fake.last.hidden, isFalse);
    });

    testWidgets('a native tap guarded by a native alert moves on "Discard"', (
      tester,
    ) async {
      final fake = installFakeNative()..dialogGate = Completer();
      final selected = <int>[];
      late BuildContext page;
      await tester.pumpWidget(
        shell(
          Builder(
            builder: (context) {
              page = context;
              return const SizedBox();
            },
          ),
          guard: (index) async =>
              (await showLiquidAlert<bool>(
                page,
                title: 'Discard changes?',
                actions: const [
                  LiquidAlertAction(
                    label: 'Keep editing',
                    value: false,
                    style: LiquidAlertActionStyle.cancel,
                  ),
                  LiquidAlertAction(
                    label: 'Discard',
                    value: true,
                    style: LiquidAlertActionStyle.destructive,
                  ),
                ],
              )) ??
              false,
          onSelect: selected.add,
        ),
      );
      await tester.pumpAndSettle();
      fake.emitNative(const LiquidNativeDestinationTapped(1));
      await tester.pumpAndSettle();
      expect(fake.dialogRequests.single.title, 'Discard changes?');
      expect(fake.last.interactive, isFalse);
      fake.dialogGate!.complete(const LiquidNativeDialogChose(1));
      await tester.pumpAndSettle();
      expect(selected, [1]);
    });
  });
}
