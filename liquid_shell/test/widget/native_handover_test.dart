import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/material_sdk.dart';
import 'package:liquid_shell/src/pages/page_bar.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

import '../helpers/fake_native_platform.dart';
import '../helpers/shell_harness.dart';

// The hand-over follows the config native has applied, per config (spec
// 2026-11-18 applied-epoch, VK-1074, VK-1075, VK-1082). The fake echoes
// epochs (its native model), and holds each config until `applyLast`.

const _destinations = [
  LiquidDestination(icon: Icon(Icons.home), label: 'Home', sfSymbol: 'house'),
  LiquidDestination(icon: Icon(Icons.book), label: 'Library', sfSymbol: 'book'),
];

const _add = LiquidPageAction(
  sfSymbol: 'plus',
  icon: Icon(Icons.add),
  label: 'Add',
  onPressed: _noop,
);

/// iPhone: the window's padding, and native's with Home's inline bar.
const _window = EdgeInsets.only(top: 62, bottom: 34);
const _native = EdgeInsets.only(top: 116, bottom: 83);
const _compact = LiquidNativeShellState(installed: true, compact: true);

void _noop() {}

/// A shell whose first tab is a LiquidPage root labelled [label].
Widget _shell(
  String label, {
  Key? key,
  bool actions = true,
  bool? largeTitle = false,
  LiquidNativeChrome mode = LiquidNativeChrome.auto,
  List<LiquidDestination> destinations = _destinations,
}) => TestShell(
  key: key,
  destinations: destinations,
  nativeChrome: mode,
  pageBuilder: (index) => Navigator(
    onGenerateRoute: (_) => MaterialPageRoute<void>(
      builder: (_) => index == 0
          ? LiquidPage(
              title: label,
              largeTitle: largeTitle,
              actions: actions ? const [_add] : const [],
              child: TestPage(label: label),
            )
          : TestPage(label: '$label $index'),
    ),
  ),
);

void _setPadding(WidgetTester tester, EdgeInsets padding) {
  final view = FakeViewPadding(top: padding.top, bottom: padding.bottom);
  tester.view
    ..padding = view
    ..viewPadding = view;
}

double _rowY(WidgetTester tester, String label) =>
    tester.getTopLeft(find.byKey(ValueKey('counter-$label'))).dy;

int _flutterBars(WidgetTester tester, String label) => find
    .ancestor(
      of: find.byKey(ValueKey('counter-$label')),
      matching: find.byType(LiquidPage),
    )
    .evaluate()
    .where(
      (page) => find
          .descendant(
            of: find.byWidget(page.widget),
            matching: find.byType(FlutterPageBar),
          )
          .evaluate()
          .isNotEmpty,
    )
    .length;

bool _nativePageBar(WidgetTester tester, String label) => LiquidShellScope.of(
  tester.element(find.byKey(ValueKey('counter-$label'))),
).nativePageBar;

/// Asserts what the frame shows for [label]: its Flutter bar or not, and
/// its first row at [y].
void _check(
  WidgetTester tester,
  String label, {
  required bool flutterBar,
  required double y,
  required String when,
}) {
  expect(_flutterBars(tester, label), flutterBar ? 1 : 0, reason: when);
  expect(_nativePageBar(tester, label), !flutterBar, reason: '$when: scope');
  expect(_rowY(tester, label), y, reason: '$when: row');
}

/// Shell A (Home with Add) engaged and settled under the native model, on
/// an iPhone with native's insets; its config is applied as it arrives
/// until [hold] (then each one waits for `applyLast`).
Future<FakeNativePlatform> _engaged(
  WidgetTester tester, {
  Widget? app,
  bool hold = true,
  LiquidNativeShellState state = _compact,
  Size size = kPhone,
  EdgeInsets window = _window,
  EdgeInsets native = _native,
}) async {
  final fake = installFakeNative(state: state)
    ..autoAck = false
    ..echoEpochs = true;
  await pumpShell(tester, app ?? _shell('Home'), size: size, padding: window);
  _setPadding(tester, native);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
  expect(fake.state.engagedApplied, isTrue, reason: 'precondition: engaged');
  expect(fake.state.appliedEpoch, fake.last.epoch);
  if (hold) fake.autoApply = false;
  return fake;
}

void main() {
  group('VK-1075: a new owner takes the native chrome over', () {
    testWidgets("a quick off → auto keeps native's layout and the row while "
        'native still shows the old config, also when it applies the '
        'dormant one in between', (tester) async {
      final fake = await _engaged(tester);
      final y = _rowY(tester, 'Home');
      expect(y, 116);
      Future<void> mode(LiquidNativeChrome mode) async {
        await pumpShell(
          tester,
          _shell('Home', mode: mode),
          padding: _native,
          settle: false,
        );
        _setPadding(tester, _native);
        await tester.pump();
      }

      await mode(LiquidNativeChrome.off);
      await mode(LiquidNativeChrome.auto);
      _check(tester, 'Home', flutterBar: false, y: y, when: 'auto again');
      // Native applies the dormant config (its state is not engaged, the
      // insets drop), then the engaged one again.
      fake.apply(fake.configs.lastWhere((config) => !config.engaged));
      _setPadding(tester, _window);
      await tester.pump();
      _check(tester, 'Home', flutterBar: false, y: y, when: 'dormant applied');
      fake.applyLast();
      _setPadding(tester, _native);
      await tester.pump();
      _check(tester, 'Home', flutterBar: false, y: y, when: 'mine applied');
      await tester.pump(const Duration(milliseconds: 300));
      _check(tester, 'Home', flutterBar: false, y: y, when: 'later');
    });

    testWidgets('a hot restart over a shown chrome holds the row until its '
        'own config is applied', (tester) async {
      final fake =
          installFakeNative(
              state: const LiquidNativeShellState(
                installed: true,
                compact: true,
                engagedApplied: true,
                appliedEpoch: 41,
              ),
            )
            ..echoEpochs = true
            ..autoApply = false;
      await pumpShell(tester, _shell('Home'), padding: _native, settle: false);
      await tester.pump();
      await tester.pump();
      expect(fake.last.epoch, greaterThan(41));
      final y = _rowY(tester, 'Home');
      _check(tester, 'Home', flutterBar: false, y: y, when: 'attached');
      // The old run's chrome had no bar: native moves the top first.
      _setPadding(tester, _window);
      await tester.pump();
      _check(tester, 'Home', flutterBar: false, y: y, when: 'metrics first');
      fake.applyLast();
      _setPadding(tester, _native);
      await tester.pump();
      _check(tester, 'Home', flutterBar: false, y: 116, when: 'mine');
    });

    testWidgets('takeover falls back to the real top 250 ms after native got '
        'the config', (tester) async {
      final fake =
          installFakeNative(
              state: const LiquidNativeShellState(
                installed: true,
                compact: true,
                engagedApplied: true,
                appliedEpoch: 41,
              ),
            )
            ..echoEpochs = true
            ..autoApply = false;
      await pumpShell(tester, _shell('Home'), padding: _native, settle: false);
      await tester.pump();
      await tester.pump();
      _setPadding(tester, _window);
      expect(fake.last.engaged, isTrue);
      await tester.pump(const Duration(milliseconds: 240));
      expect(_rowY(tester, 'Home'), 116, reason: 'still held');
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump();
      expect(_rowY(tester, 'Home'), 62, reason: 'the fallback: the real top');
    });

    testWidgets('D3: on an iPad a default root (no bar) replaced by a root '
        'with actions draws its Flutter bar until its own config is '
        'applied', (tester) async {
      const ipad = LiquidNativeShellState(installed: true);
      const top = EdgeInsets.only(top: 74, bottom: 20);
      final fake = await _engaged(
        tester,
        app: _shell(
          'Home',
          key: const ValueKey('a'),
          actions: false,
          largeTitle: null,
        ),
        state: ipad,
        size: kTabletPortrait,
        window: top,
        native: top,
      );
      expect(_flutterBars(tester, 'Home'), 0);
      await pumpShell(
        tester,
        _shell('Feed', key: const ValueKey('b')),
        size: kTabletPortrait,
        padding: top,
        settle: false,
      );
      await tester.pump();
      final y = _rowY(tester, 'Feed');
      expect(_flutterBars(tester, 'Feed'), 1, reason: 'no native bar there');
      expect(_nativePageBar(tester, 'Feed'), isFalse);
      await tester.pump();
      expect(_flutterBars(tester, 'Feed'), 1, reason: 'not applied yet');
      fake.applyLast();
      await tester.pump();
      expect(_flutterBars(tester, 'Feed'), 0, reason: 'mine: handed over');
      expect(_rowY(tester, 'Feed'), y, reason: 'held below the bar');
    });

    testWidgets('a root replaced in one frame with the same bar: no Flutter '
        'bar, the row held, until its own config is applied', (tester) async {
      final fake = await _engaged(
        tester,
        app: _shell('Home', key: const ValueKey('a')),
      );
      await pumpShell(
        tester,
        _shell('Feed', key: const ValueKey('b')),
        padding: _native,
        settle: false,
      );
      _setPadding(tester, _native);
      await tester.pump();
      _check(tester, 'Feed', flutterBar: false, y: 116, when: 'replaced');
      await tester.pump();
      _check(tester, 'Feed', flutterBar: false, y: 116, when: 'sent');
      fake.applyLast();
      await tester.pump();
      _check(tester, 'Feed', flutterBar: false, y: 116, when: 'mine');
    });

    testWidgets('a shell pushed over a hidden config (a dialog covered the '
        'owner) waits with its Flutter bar', (tester) async {
      final fake = await _engaged(tester, hold: false);
      final context = tester.element(find.byType(LiquidShell));
      final root = Navigator.of(context, rootNavigator: true);
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => const Text('dialog'),
        ),
      );
      await tester.pumpAndSettle();
      expect(fake.last.hidden, isTrue, reason: 'precondition: hidden');
      expect(fake.state.appliedEpoch, fake.last.epoch);
      fake.autoApply = false;
      root
          .push(MaterialPageRoute<void>(builder: (_) => _shell('Feed')))
          .ignore();
      await tester.pump();
      await tester.pump();
      expect(_flutterBars(tester, 'Feed'), 1, reason: 'nothing on screen');
      fake.applyLast();
      await tester.pump();
      expect(_flutterBars(tester, 'Feed'), 0, reason: 'mine');
    });
  });

  group('VK-1082: a shell in standby under a pushed shell (S-1)', () {
    /// A's row and Flutter bars on every frame where A is on screen.
    void checkA(WidgetTester tester, String when) {
      final row = find.byKey(const ValueKey('counter-Home'));
      if (row.evaluate().isEmpty) return;
      _check(tester, 'Home', flutterBar: false, y: 116, when: when);
    }

    testWidgets('A keeps no Flutter bar and its row through the push and '
        'the pop', (tester) async {
      final fake = await _engaged(tester, hold: false);
      final navigator = Navigator.of(
        tester.element(find.byType(LiquidShell)),
      );
      navigator
          .push(MaterialPageRoute<void>(builder: (_) => _shell('Feed')))
          .ignore();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        checkA(tester, 'push frame $i');
      }
      await tester.pumpAndSettle();
      expect(fake.state.appliedEpoch, fake.last.epoch, reason: "B's applied");
      navigator.pop();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        checkA(tester, 'pop frame $i');
      }
      await tester.pumpAndSettle();
      checkA(tester, 'settled');
      expect(fake.last.tabs.first.title, 'Home', reason: 'A owns it again');
    });

    testWidgets('over a shell whose root has no bar, A draws its own through '
        'the pop and holds its row until its own config is applied', (
      tester,
    ) async {
      final fake = await _engaged(tester, hold: false);
      final navigator = Navigator.of(
        tester.element(find.byType(LiquidShell)),
      );
      navigator
          .push(
            MaterialPageRoute<void>(
              builder: (_) => _shell('Feed', actions: false),
            ),
          )
          .ignore();
      await tester.pumpAndSettle();
      // B's root has no bar: native's top is the window's.
      _setPadding(tester, _window);
      await tester.pumpAndSettle();
      fake.autoApply = false;
      navigator.pop();
      // Native shows B's root, which has no bar: A draws its own, through
      // the pop and until its own config is applied (no frame without one).
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        _check(tester, 'Home', flutterBar: true, y: 116, when: 'pop $i');
      }
      await tester.pumpAndSettle();
      _check(tester, 'Home', flutterBar: true, y: 116, when: 'popped');
      expect(fake.last.epoch, greaterThan(fake.state.appliedEpoch));
      fake.applyLast();
      _setPadding(tester, _native);
      await tester.pump();
      _check(tester, 'Home', flutterBar: false, y: 116, when: 'mine');
    });

    testWidgets("a same-route nested shell on auto leaves the outer pages' "
        'Flutter bars (not covered by a route)', (tester) async {
      installFakeNative(state: _compact).echoEpochs = true;
      await pumpShell(
        tester,
        TestShell(
          destinations: _destinations,
          pageBuilder: (index) => LiquidPage(
            title: 'Outer $index',
            actions: const [_add],
            largeTitle: false,
            child: index == 0
                ? _shell('Inner')
                : TestPage(label: 'Outer $index'),
          ),
        ),
        padding: _native,
      );
      expect(
        find.ancestor(
          of: find.byType(FlutterPageBar),
          matching: find.byType(LiquidPage),
        ),
        findsWidgets,
        reason: "the outer page's own bar stays",
      );
    });
  });
}
