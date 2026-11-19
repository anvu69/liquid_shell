import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/material_sdk.dart';
import 'package:liquid_shell/src/native/native_layout.dart';
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

    testWidgets(
      'known gap: a hot restart over a hidden config (a dialog was up) draws '
      'its own page bar until its own config is applied',
      // Follow-up (accepted): after a hot restart the host has no record of
      // native's config, so it cannot see hidden; treating that as "nothing on
      // screen" would draw a second bar under the native one in the common case
      // (a hot restart over shown chrome) instead.
      skip: true,
      (tester) async {
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
        await pumpShell(
          tester,
          _shell('Home'),
          padding: _window,
          settle: false,
        );
        await tester.pump();
        await tester.pump();
        expect(fake.last.epoch, greaterThan(41));
        expect(_flutterBars(tester, 'Home'), 1, reason: 'nothing on screen');
      },
    );

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

    testWidgets('iPad landscape, tiled sidebar: a bar-less root replaced by '
        "a bar-less root keeps native's layout on every frame", (
      tester,
    ) async {
      const tiled = LiquidNativeShellState(
        installed: true,
        sidebar: LiquidNativeSidebar.tiled,
      );
      const padding = EdgeInsets.only(left: 300, top: 24, bottom: 20);
      final fake = await _engaged(
        tester,
        app: _shell(
          'Home',
          key: const ValueKey('a'),
          actions: false,
          largeTitle: null,
        ),
        state: tiled,
        size: kTabletLandscape,
        window: padding,
        native: padding,
      );
      void same(String when) {
        final row = find.byKey(const ValueKey('counter-Feed'));
        final scope = LiquidShellScope.of(tester.element(row));
        expect(scope.chromeKind, LiquidChromeKind.sidebarTiled, reason: when);
        expect(scope.nativeChrome, isTrue, reason: when);
        expect(tester.getTopLeft(row).dx, 300, reason: '$when: dx');
        expect(_flutterBars(tester, 'Feed'), 0, reason: when);
      }

      await pumpShell(
        tester,
        _shell(
          'Feed',
          key: const ValueKey('b'),
          actions: false,
          largeTitle: null,
        ),
        size: kTabletLandscape,
        padding: padding,
        settle: false,
      );
      same('replaced');
      await tester.pump();
      same('sent');
      fake.applyLast();
      await tester.pump();
      same('mine');
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

    testWidgets('a plain page pushed and popped over a same-route nested '
        "shell's route leaves the outer pages' Flutter bars (the owner never "
        'changed)', (tester) async {
      final fake = installFakeNative(state: _compact)..echoEpochs = true;
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
      Finder outerBars() => find.descendant(
        of: find.byWidgetPredicate(
          (widget) => widget is LiquidPage && widget.title == 'Outer 0',
        ),
        matching: find.byType(FlutterPageBar),
      );
      expect(outerBars(), findsOneWidget, reason: 'precondition');
      final navigator = Navigator.of(
        tester.element(find.byType(LiquidShell).first),
      );
      navigator
          .push(
            MaterialPageRoute<void>(builder: (_) => const Text('a plain page')),
          )
          .ignore();
      await tester.pumpAndSettle();
      navigator.pop();
      await tester.pumpAndSettle();
      expect(fake.last.hidden, isFalse, reason: "the inner's config shown");
      expect(
        nativeConfigShowsPageBar(fake.last, compact: true),
        isTrue,
        reason: 'precondition: native shows a page bar',
      );
      expect(outerBars(), findsOneWidget, reason: 'after the pop');
      await tester.pump(const Duration(milliseconds: 300));
      expect(outerBars(), findsOneWidget, reason: 'later');
    });
  });

  group("VK-1074: a disengaging shell keeps native's layout until native "
      'let go', () {
    bool flutterTabBar() => find.byType(LiquidTabBar).evaluate().isNotEmpty;

    Future<void> mode(WidgetTester tester, LiquidNativeChrome mode) async {
      await pumpShell(
        tester,
        _shell('Home', mode: mode),
        padding: _native,
        settle: false,
      );
      _setPadding(tester, _native);
      await tester.pump();
    }

    /// The dormant (or this shell's disengaged) config native applies.
    LiquidNativeChromeConfig disengaged(FakeNativePlatform fake) =>
        fake.configs.lastWhere((config) => !config.engaged);

    void releasing(WidgetTester tester, String when) {
      _check(tester, 'Home', flutterBar: false, y: 116, when: when);
      expect(flutterTabBar(), isFalse, reason: '$when: no Flutter tab bar');
    }

    void flutterLayout(WidgetTester tester, String when) {
      _check(tester, 'Home', flutterBar: true, y: 116, when: when);
      expect(flutterTabBar(), isTrue, reason: '$when: Flutter tab bar');
    }

    /// Home under a mode the test flips with [chrome], so the flip does not
    /// reset the view (size, padding, view insets) as `pumpShell` would.
    Widget flippable(ValueNotifier<LiquidNativeChrome> chrome) =>
        ValueListenableBuilder<LiquidNativeChrome>(
          valueListenable: chrome,
          builder: (_, mode, _) => _shell('Home', mode: mode),
        );

    Future<void> flip(
      WidgetTester tester,
      ValueNotifier<LiquidNativeChrome> chrome,
      LiquidNativeChrome mode,
    ) async {
      chrome.value = mode;
      await tester.pump();
      await tester.pump();
    }

    /// The body's bottom safe area at Home's first row.
    void bodyBottom(
      WidgetTester tester, {
      required double padding,
      required double view,
      required String when,
    }) {
      final row = tester.element(find.byKey(const ValueKey('counter-Home')));
      expect(MediaQuery.paddingOf(row).bottom, padding, reason: '$when: pad');
      expect(
        MediaQuery.viewPaddingOf(row).bottom,
        view,
        reason: '$when: viewPad',
      );
    }

    testWidgets("mode off, metrics first: native's layout until the ack, "
        "then the Flutter bars where native's were", (tester) async {
      final fake = await _engaged(tester);
      await mode(tester, LiquidNativeChrome.off);
      expect(fake.last.engaged, isFalse, reason: 'dormant sent');
      releasing(tester, 'off, not applied');
      _setPadding(tester, _window);
      await tester.pump();
      releasing(tester, 'metrics before the ack');
      fake.apply(disengaged(fake));
      await tester.pump();
      flutterLayout(tester, 'released');
      bodyBottom(tester, padding: 34, view: 34, when: 'released');
      await tester.pump(const Duration(milliseconds: 300));
      flutterLayout(tester, 'later');
    });

    testWidgets("mode off, ack first: the Flutter bar held where native's "
        'was until the metrics drop', (tester) async {
      final fake = await _engaged(tester);
      await mode(tester, LiquidNativeChrome.off);
      fake.apply(disengaged(fake));
      await tester.pump();
      flutterLayout(tester, 'released, old metrics');
      _setPadding(tester, _window);
      await tester.pump();
      flutterLayout(tester, 'metrics after the ack');
      await tester.pump(const Duration(milliseconds: 300));
      flutterLayout(tester, 'later');
    });

    testWidgets(
      'known gap: during the mirror the Flutter tab bar sits on the window '
      "bottom, not native's bar height above it",
      // Follow-up to VK-1074 (accepted residual): in the ack-first order the
      // bottom inset is still native's (83 pt) for one round trip; Dart does
      // not know the window's own bottom then.
      skip: true,
      (tester) async {
        final fake = await _engaged(tester);
        await mode(tester, LiquidNativeChrome.off);
        fake.apply(disengaged(fake));
        await tester.pump();
        flutterLayout(tester, 'mirror');
        // The window's bottom inset is 34 pt; native's bar is gone.
        expect(
          tester.getBottomLeft(find.byType(LiquidTabBar)).dy,
          lessThanOrEqualTo(kPhone.height - _window.bottom),
        );
        expect(
          tester.getBottomLeft(find.byType(LiquidTabBar)).dy,
          greaterThan(kPhone.height - _native.bottom),
          reason: "not native's bar height above it",
        );
      },
    );

    testWidgets(
      'rotated between the engage and the disengage: the mirror holds no '
      'bottom',
      variant: iosDevice,
      (tester) async {
        final chrome = ValueNotifier(LiquidNativeChrome.auto);
        addTearDown(chrome.dispose);
        final fake = await _engaged(tester, app: flippable(chrome));
        // The window bottom was seen in portrait only.
        const landscape = EdgeInsets.only(top: 44, bottom: 70);
        tester.view.physicalSize = kPhoneLandscape;
        tester.view.display.size = kPhoneLandscape;
        _setPadding(tester, landscape);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await flip(tester, chrome, LiquidNativeChrome.off);
        fake.apply(disengaged(fake));
        await tester.pump();
        expect(_flutterBars(tester, 'Home'), 1, reason: 'mirror: Flutter bar');
        bodyBottom(tester, padding: 70, view: 70, when: 'mirror');
      },
    );

    testWidgets(
      'a takeover start never saw the window: the mirror holds no bottom',
      variant: iosDevice,
      (tester) async {
        // The hot-restart attach of the VK-1075 group: native's insets from
        // the first frame.
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
        await pumpShell(
          tester,
          _shell('Home'),
          padding: _native,
          settle: false,
        );
        await tester.pump();
        await tester.pump();
        expect(fake.last.epoch, greaterThan(41));
        fake.applyLast();
        await tester.pump();
        releasing(tester, 'mine');
        await mode(tester, LiquidNativeChrome.off);
        fake.apply(disengaged(fake));
        await tester.pump();
        flutterLayout(tester, 'mirror');
        bodyBottom(tester, padding: 83, view: 83, when: 'mirror');
      },
    );

    testWidgets('a platform that does not echo epochs: the Flutter layout at '
        'the real top at once (the dev.13 rule)', (tester) async {
      installFakeNative(state: _compact);
      await pumpShell(tester, _shell('Home'), padding: _native);
      expect(_rowY(tester, 'Home'), 116);
      await mode(tester, LiquidNativeChrome.off);
      expect(_flutterBars(tester, 'Home'), 1);
      expect(_rowY(tester, 'Home'), 170, reason: "native's inset, no hold");
    });

    testWidgets('no ack: the Flutter layout 250 ms after the disengage', (
      tester,
    ) async {
      await _engaged(tester);
      await mode(tester, LiquidNativeChrome.off);
      await tester.pump(const Duration(milliseconds: 240));
      releasing(tester, 'still releasing');
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump();
      expect(_flutterBars(tester, 'Home'), 1, reason: 'the fallback');
      expect(flutterTabBar(), isTrue);
    });

    testWidgets('a destination losing its symbol (the claim kept) releases '
        'on its own disengaged config', (tester) async {
      final fake = await _engaged(tester);
      const plain = [
        LiquidDestination(
          icon: Icon(Icons.home),
          label: 'Home',
          sfSymbol: 'house',
        ),
        LiquidDestination(icon: Icon(Icons.book), label: 'Library'),
      ];
      await pumpShell(
        tester,
        _shell('Home', destinations: plain),
        padding: _native,
        settle: false,
      );
      _setPadding(tester, _native);
      await tester.pump();
      releasing(tester, 'flapped');
      await tester.pump();
      expect(fake.last.engaged, isFalse, reason: 'its own disengaged config');
      releasing(tester, 'sent');
      fake.applyLast();
      await tester.pump();
      flutterLayout(tester, 'released');
    });

    testWidgets('a re-engage while releasing is a takeover: no Flutter bar', (
      tester,
    ) async {
      final fake = await _engaged(tester);
      await mode(tester, LiquidNativeChrome.off);
      releasing(tester, 'off');
      await mode(tester, LiquidNativeChrome.auto);
      releasing(tester, 'auto again');
      await tester.pump();
      releasing(tester, 'sent');
      fake.applyLast();
      await tester.pump();
      releasing(tester, 'mine');
    });
  });

  group('IME across the hand-overs', () {
    /// Home with Add and a text field under its first row.
    Widget fieldShell({LiquidNativeChrome mode = LiquidNativeChrome.auto}) =>
        TestShell(
          destinations: _destinations,
          nativeChrome: mode,
          pageBuilder: (index) => Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => index == 0
                  ? const LiquidPage(
                      title: 'Home',
                      largeTitle: false,
                      actions: [_add],
                      child: _FieldPage(),
                    )
                  : TestPage(label: 'Tab $index'),
            ),
          ),
        );

    Future<EditableTextState> compose(WidgetTester tester) async {
      await tester.tap(find.byType(TextField));
      await tester.pump();
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'hoa',
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange(start: 0, end: 3),
        ),
      );
      await tester.pump();
      tester.testTextInput.log.clear();
      return tester.state<EditableTextState>(find.byType(EditableText));
    }

    void expectKept(
      WidgetTester tester,
      EditableTextState field,
      String when, {
      bool focused = true,
    }) {
      final now = tester.state<EditableTextState>(
        find.byType(EditableText, skipOffstage: false),
      );
      expect(now, same(field), reason: when);
      expect(now.textEditingValue.text, 'hoa', reason: when);
      if (!focused) return;
      expect(now.widget.focusNode.hasFocus, isTrue, reason: when);
      expect(
        now.textEditingValue.composing,
        const TextRange(start: 0, end: 3),
        reason: when,
      );
      final methods = [
        for (final call in tester.testTextInput.log) call.method,
      ];
      expect(methods, isNot(contains('TextInput.clearClient')), reason: when);
      expect(methods, isNot(contains('TextInput.setClient')), reason: when);
      expect(
        methods,
        isNot(contains('TextInput.setEditingState')),
        reason: when,
      );
    }

    Future<void> mode(WidgetTester tester, LiquidNativeChrome mode) async {
      await pumpShell(
        tester,
        fieldShell(mode: mode),
        padding: _native,
        settle: false,
      );
      _setPadding(tester, _native);
      await tester.pump();
    }

    testWidgets('a composing field keeps its state, focus and composing '
        'range through a release, a takeover and a mirror hold', (
      tester,
    ) async {
      final fake = await _engaged(tester, app: fieldShell());
      final field = await compose(tester);
      await mode(tester, LiquidNativeChrome.off);
      expectKept(tester, field, 'releasing');
      await mode(tester, LiquidNativeChrome.auto);
      expectKept(tester, field, 'takeover');
      await tester.pump();
      fake.applyLast();
      await tester.pump();
      expectKept(tester, field, 'mine');
      await mode(tester, LiquidNativeChrome.off);
      fake.apply(fake.configs.lastWhere((config) => !config.engaged));
      await tester.pump();
      expectKept(tester, field, 'mirror');
      _setPadding(tester, _window);
      await tester.pump(const Duration(milliseconds: 300));
      expectKept(tester, field, 'Flutter layout');
    });

    testWidgets('a composing field under a pushed shell keeps its State and '
        'its value through the push and the pop, as under a plain page '
        '(standby)', (tester) async {
      await _engaged(tester, hold: false, app: fieldShell());
      final field = await compose(tester);
      final value = field.textEditingValue;
      final navigator = Navigator.of(
        tester.element(find.byType(LiquidShell)),
      );
      // The pushed route takes focus by Flutter's own rules (its navigators
      // autofocus), so the field's connection closes and reopens on the
      // pop, and its focus loss ends the composition: the same as under a
      // plain page with no shell (measured). What the shell must not do is
      // rebuild the field or write it.
      List<String> methods() => [
        for (final call in tester.testTextInput.log) call.method,
      ];
      void same(String when) {
        expectKept(tester, field, when, focused: false);
        final now = tester.state<EditableTextState>(
          find.byType(EditableText, skipOffstage: false),
        );
        expect(now.textEditingValue.text, value.text, reason: when);
        expect(
          now.textEditingValue.selection,
          value.selection,
          reason: when,
        );
      }

      navigator
          .push(MaterialPageRoute<void>(builder: (_) => _shell('Feed')))
          .ignore();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        same('push $i');
        expect(methods(), isNot(contains('TextInput.setClient')));
        expect(methods(), isNot(contains('TextInput.setEditingState')));
      }
      tester.testTextInput.log.clear();
      navigator.pop();
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        same('pop $i');
        expect(methods(), isNot(contains('TextInput.clearClient')));
      }
      // Focus back: the field's own reopen sends the value it kept.
      final sent = [
        for (final call in tester.testTextInput.log)
          if (call.method == 'TextInput.setEditingState') call.arguments,
      ];
      for (final state in sent) {
        expect((state as Map)['text'], 'hoa');
        expect(state['selectionBase'], 3);
      }
    });
  });
}

/// A first row (the counter key the checks read) and a text field.
class _FieldPage extends StatelessWidget {
  const _FieldPage();

  @override
  Widget build(BuildContext context) => Material(
    child: ListView(
      padding: LiquidShellScope.contentPaddingOf(context),
      children: const [
        SizedBox(key: ValueKey('counter-Home'), height: 40),
        TextField(),
      ],
    ),
  );
}
