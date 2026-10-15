// liquid_shell/test/widget/native_minimize_test.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/native/native_host.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

import '../helpers/fake_native_platform.dart';
import '../helpers/shell_harness.dart';

const _compactPadding = EdgeInsets.only(top: 62, bottom: 83);
const _compact = LiquidNativeShellState(installed: true, compact: true);

Future<FakeNativePlatform> _pump(
  WidgetTester tester, {
  LiquidNativeShellState state = _compact,
  bool minimizeOnScroll = true,
  Size size = kPhone,
}) async {
  final native = installFakeNative(state: state);
  await pumpShell(
    tester,
    TestShell(destinations: kNative, minimizeOnScroll: minimizeOnScroll),
    size: size,
    padding: _compactPadding,
  );
  return native;
}

ScrollPosition _position(WidgetTester tester, String label) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byKey(ValueKey('list-$label')),
        matching: find.byType(Scrollable),
      ),
    )
    .position;

/// A compact native platform that also records the order of configs and
/// minimize offsets.
class _OrderedNative extends FakeNativePlatform {
  _OrderedNative() : super(state: _compact);

  final calls = <String>[];

  @override
  Future<void> updateNativeChrome(LiquidNativeChromeConfig config) {
    calls.add('config');
    return super.updateNativeChrome(config);
  }

  @override
  Future<void> setNativeMinimizeScroll({
    required int tab,
    required double offset,
  }) {
    calls.add('offset $tab');
    return super.setNativeMinimizeScroll(tab: tab, offset: offset);
  }
}

void main() {
  group('native minimize (spec VK-600 §9)', () {
    testWidgets('compact: the dragged offset reaches native, once per value', (
      tester,
    ) async {
      final native = await _pump(tester);
      expect(native.last.minimizeOnScroll, isTrue);
      await tester.drag(
        find.byKey(const ValueKey('list-Home')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      final pixels = _position(tester, 'Home').pixels;
      expect(native.minimizeScrolls.last, (0, pixels));
      final sent = native.minimizeScrolls.length;
      await tester.pump(const Duration(seconds: 1));
      expect(native.minimizeScrolls.length, sent, reason: 'deduplicated');
    });

    testWidgets('regular width sends nothing', (tester) async {
      final native = await _pump(
        tester,
        state: kInstalled,
        size: kTabletLandscape,
      );
      await tester.drag(
        find.byKey(const ValueKey('list-Home')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(native.minimizeScrolls, isEmpty);
    });

    testWidgets('minimizeOnScroll: false sends nothing and says so', (
      tester,
    ) async {
      final native = await _pump(tester, minimizeOnScroll: false);
      await tester.drag(
        find.byKey(const ValueKey('list-Home')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(native.minimizeScrolls, isEmpty);
      expect(native.last.minimizeOnScroll, isFalse);
    });

    testWidgets('a dialog above the shell stops the sends', (tester) async {
      final native = await _pump(tester);
      final context = tester.element(find.byKey(const ValueKey('list-Home')));
      unawaited(
        showDialog<void>(context: context, builder: (_) => const SizedBox()),
      );
      await tester.pumpAndSettle();
      final sent = native.minimizeScrolls.length;
      // The body still scrolls (the app's code), but the shell's route is
      // not current: nothing may reach the hidden native bar.
      _position(tester, 'Home').jumpTo(400);
      await tester.pumpAndSettle();
      expect(native.minimizeScrolls.length, sent);
    });

    testWidgets('a selection change sends the new tab its offset', (
      tester,
    ) async {
      final native = await _pump(tester);
      tester.state<TestShellState>(find.byType(TestShell)).select(1);
      await tester.pumpAndSettle();
      expect(native.minimizeScrolls.last.$1, 1);
    });

    testWidgets('animateTo(0) and a fling to the top expand; a drag does not', (
      tester,
    ) async {
      final native = await _pump(tester);
      final list = find.byKey(const ValueKey('list-Home'));
      await tester.drag(list, const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.drag(list, const Offset(0, 900)); // drag to the top
      await tester.pumpAndSettle();
      expect(native.tabBarExpands, 0);
      await tester.drag(list, const Offset(0, -600));
      await tester.pumpAndSettle();
      // Not awaited: its future completes on a frame, and only pumps make
      // frames here (awaiting it never returns).
      unawaited(
        _position(tester, 'Home').animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        ),
      );
      await tester.pumpAndSettle();
      expect(native.tabBarExpands, 1);
      await tester.drag(list, const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.fling(list, const Offset(0, 500), 4000);
      await tester.pumpAndSettle();
      expect(native.tabBarExpands, 2);
    });
  });

  group('native minimize: carried review items (VK-600 Task 1, Task 4)', () {
    testWidgets('the claim sends only while it owns the chrome', (
      tester,
    ) async {
      final native = installFakeNative(state: _compact);
      final first = NativeChromeHost.instance.claim((_) {});
      final second = NativeChromeHost.instance.claim((_) {});
      first
        ..setMinimizeScroll(tab: 0, offset: 40)
        ..expandTabBar();
      expect(native.minimizeScrolls, isEmpty);
      expect(native.tabBarExpands, 0);
      second
        ..setMinimizeScroll(tab: 1, offset: 80)
        ..expandTabBar();
      expect(native.minimizeScrolls, [(1, 80.0)]);
      expect(native.tabBarExpands, 1);
      second
        ..release()
        ..setMinimizeScroll(tab: 1, offset: 90)
        ..expandTabBar();
      expect(native.minimizeScrolls, [(1, 80.0)], reason: 'released');
      first.release();
    });

    testWidgets('a reconnected scene gets the offset again', (tester) async {
      final native = await _pump(tester);
      await tester.drag(
        find.byKey(const ValueKey('list-Home')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      final pixels = _position(tester, 'Home').pixels;
      final sent = native.minimizeScrolls.length;
      // A reconnected scene reports the state again, maybe unchanged; its
      // new tab hosts start at offset 0.
      native.pushState(_compact);
      await tester.pumpAndSettle();
      expect(native.minimizeScrolls.length, sent + 1);
      expect(native.minimizeScrolls.last, (0, pixels));
    });

    testWidgets('a config that may rebuild the native tabs is followed by '
        'the offset', (tester) async {
      final native = _OrderedNative();
      final original = LiquidShellPlatform.instance;
      LiquidShellPlatform.instance = native;
      addTearDown(() => LiquidShellPlatform.instance = original);
      await pumpShell(
        tester,
        const TestShell(destinations: kNative),
        padding: _compactPadding,
      );
      await tester.drag(
        find.byKey(const ValueKey('list-Home')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      final pixels = _position(tester, 'Home').pixels;
      native.calls.clear();
      // A trailing action changes the native tab structure: new hosts, at
      // offset 0, after this config.
      await pumpShell(
        tester,
        TestShell(
          destinations: kNative,
          trailing: LiquidTabAction(
            icon: const Icon(Icons.add),
            onPressed: () {},
            semanticLabel: 'Add',
            sfSymbol: 'plus',
          ),
        ),
        padding: _compactPadding,
      );
      expect(native.calls, ['config', 'offset 0']);
      expect(native.minimizeScrolls.last, (0, pixels));
    });

    testWidgets("a list in another tab moves nothing (an IndexedStack's)", (
      tester,
    ) async {
      final native = await _pump(tester);
      await tester.drag(
        find.byKey(const ValueKey('list-Home')),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      final home = _position(tester, 'Home');
      tester.state<TestShellState>(find.byType(TestShell)).select(1);
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('list-Inbox')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      final inbox = _position(tester, 'Inbox').pixels;
      final sent = native.minimizeScrolls.length;
      // The app scrolls the hidden Home list back to its top.
      home.jumpTo(0);
      await tester.pumpAndSettle();
      expect(native.tabBarExpands, 0);
      expect(native.minimizeScrolls.length, sent);
      expect(native.minimizeScrolls.last, (1, inbox));
    });

    testWidgets("at rest the offset is the list's own, also after the list "
        'was replaced', (tester) async {
      final generation = ValueNotifier(0);
      addTearDown(generation.dispose);
      final native = installFakeNative(state: _compact);
      await pumpShell(
        tester,
        TestShell(
          destinations: kNative,
          pageBuilder: (i) => i == 0
              ? ValueListenableBuilder<int>(
                  valueListenable: generation,
                  builder: (_, g, _) =>
                      TestPage(key: ValueKey(g), label: 'Home'),
                )
              : TestPage(label: kNative[i].label),
        ),
        padding: _compactPadding,
      );
      final list = find.byKey(const ValueKey('list-Home'));
      await tester.drag(list, const Offset(0, -300));
      await tester.pumpAndSettle();
      // A new list, at its top: no notification tells the tracker.
      generation.value = 1;
      await tester.pumpAndSettle();
      await tester.drag(list, const Offset(0, -100));
      await tester.pumpAndSettle();
      final pixels = _position(tester, 'Home').pixels;
      expect(pixels, lessThan(200));
      expect(native.minimizeScrolls.last, (0, pixels));
    });

    testWidgets('a destination that leaves the list forgets its offset', (
      tester,
    ) async {
      final native = await _pump(tester);
      final shell = tester.state<TestShellState>(find.byType(TestShell))
        ..select(3);
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('list-Settings')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      shell.select(0);
      await tester.pumpAndSettle();
      Future<void> destinations(List<LiquidDestination> list) => pumpShell(
        tester,
        TestShell(destinations: list),
        padding: _compactPadding,
      );
      await destinations(kNative.sublist(0, 3));
      await destinations(kNative);
      shell.select(3);
      await tester.pumpAndSettle();
      expect(native.minimizeScrolls.last, (3, 0.0));
    });
  });
}
