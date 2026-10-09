import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/chrome/sidebar_toggle.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

import '../helpers/fake_native_platform.dart';
import '../helpers/shell_harness.dart';

/// A floating iPad window: the cluster is 66pt wide, 30pt tall.
const _controls = LiquidWindowControls(leading: 66, top: 30);

/// The native shell is not installed (the app did not opt in): Flutter
/// chrome, but the window controls are still read (spec P2 §8.1).
FakeNativePlatform _installWindowed() => installFakeNative(
  state: const LiquidNativeShellState(
    installed: false,
    unavailableReason: LiquidNativeUnavailableReason.notEnabled,
  ),
)..controls = _controls;

Widget _row({double rowTop = 0}) => MaterialApp(
  home: Align(
    alignment: Alignment.topLeft,
    child: LiquidWindowControlsClearance(
      rowTop: rowTop,
      child: const Text('Title'),
    ),
  ),
);

Widget _titlePage(int index) => Align(
  alignment: AlignmentDirectional.topStart,
  child: LiquidWindowControlsClearance(child: Text('Title $index')),
);

void main() {
  group('LiquidWindowControlsClearance', () {
    testWidgets('no platform support: no indent', (tester) async {
      await tester.pumpWidget(_row());
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Title')).dx, 0);
    });

    testWidgets('a row in the band starts past the cluster', (tester) async {
      _installWindowed();
      await tester.pumpWidget(_row());
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Title')).dx, 66);
    });

    testWidgets('a row below the band is not indented', (tester) async {
      _installWindowed();
      await tester.pumpWidget(_row(rowTop: 30));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Title')).dx, 0);
    });

    testWidgets('pushed values animate in; reduce motion jumps', (
      tester,
    ) async {
      final native = installFakeNative();
      await tester.pumpWidget(_row());
      await tester.pumpAndSettle();
      native.emitNative(const LiquidWindowControlsChanged(_controls));
      // The event lands during this frame; the rebuild starts the animation.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final mid = tester.getTopLeft(find.text('Title')).dx;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(66));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Title')).dx, 66);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _row(),
        ),
      );
      native.emitNative(
        const LiquidWindowControlsChanged(LiquidWindowControls.zero),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(AnimatedPadding), findsNothing);
      expect(tester.getTopLeft(find.text('Title')).dx, 0);
    });

    testWidgets('a new row past the cluster settles at once, no slide', (
      tester,
    ) async {
      _installWindowed();
      await tester.pumpWidget(_row());
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Title')).dx, 66);

      await tester.pumpWidget(
        MaterialApp(
          home: Padding(
            padding: const EdgeInsets.only(left: 200),
            child: Align(
              alignment: Alignment.topLeft,
              child: LiquidWindowControlsClearance(
                key: UniqueKey(),
                child: const Text('Title'),
              ),
            ),
          ),
        ),
      );
      // First frame: not measured yet. Second: measured, applied at once.
      await tester.pump();
      expect(tester.getTopLeft(find.text('Title')).dx, 200);
    });

    testWidgets('a metrics change reads the controls again', (tester) async {
      final native = _installWindowed();
      await tester.pumpWidget(_row());
      await tester.pumpAndSettle();
      final reads = native.controlReads;
      tester.view.physicalSize = const Size(900, 700);
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();
      expect(native.controlReads, greaterThan(reads));
    });
  });

  group('page titles: only rows under the cluster move', () {
    /// A shell whose pages are a top-left title in the clearance.
    const titled = TestShell(pageBuilder: _titlePage);

    double titleX(WidgetTester tester) =>
        tester.getTopLeft(find.text('Title 0')).dx;

    testWidgets('tiled: the page sits past the sidebar, not under it', (
      tester,
    ) async {
      _installWindowed();
      await pumpShell(tester, titled, size: kTabletLandscape);
      // The body starts at the sidebar's edge; the title stays there.
      expect(titleX(tester), 300);
    });

    testWidgets('RTL tiled: the cluster is on the right; neither moves', (
      tester,
    ) async {
      _installWindowed();
      await pumpShell(
        tester,
        titled,
        size: kTabletLandscape,
        direction: TextDirection.rtl,
      );
      expect(
        tester.getTopRight(find.text('Title 0')).dx,
        kTabletLandscape.width - 300,
      );
    });

    testWidgets('overlay window: the title moves past the cluster', (
      tester,
    ) async {
      _installWindowed();
      await pumpShell(tester, titled, size: kTabletPortrait);
      expect(titleX(tester), 66);
    });

    testWidgets('a resize that tiles the sidebar moves the title back', (
      tester,
    ) async {
      _installWindowed();
      await pumpShell(tester, titled, size: kTabletPortrait);
      expect(titleX(tester), 66);
      await resize(tester, kTabletLandscape);
      expect(titleX(tester), 300);
      await resize(tester, kTabletPortrait);
      expect(titleX(tester), 66);
    });

    testWidgets('tiled: a newly built page title is past the sidebar from '
        'its first frame', (tester) async {
      _installWindowed();
      // One page at a time, built on selection, like a lazy router branch.
      var index = 0;
      await pumpShell(
        tester,
        StatefulBuilder(
          builder: (context, setState) => LiquidShell(
            destinations: kDestinations,
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => index = i),
            body: KeyedSubtree(key: ValueKey(index), child: _titlePage(index)),
          ),
        ),
        size: kTabletLandscape,
      );
      expect(titleX(tester), 300);
      await tester.tap(find.text('Inbox'));
      await tester.pump();
      expect(tester.getTopLeft(find.text('Title 1')).dx, 300);
    });

    // A route transition moves the page with a paint transform. Measured
    // through it, a title under the cluster looked past it mid-push and
    // slid 66 → 0 → 66.
    final pushes = <String, Route<void> Function(Widget page)>{
      'a MaterialPageRoute (iOS slide)': (page) =>
          MaterialPageRoute<void>(builder: (_) => page),
      'a slow PageRouteBuilder slide': (page) => PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, animation, _, child) => SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
    };
    for (final MapEntry(key: name, value: route) in pushes.entries) {
      testWidgets('$name: a title under the cluster keeps its indent on '
          'every frame of the push', (tester) async {
        _installWindowed();
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = kTabletPortrait;
        addTearDown(tester.view.reset);
        // The home page already shows a title, so the controls are known
        // before the push, as in an app.
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(platform: TargetPlatform.iOS),
            home: _titlePage(0),
          ),
        );
        await tester.pumpAndSettle();
        const pageKey = Key('pushed page');
        tester
            .state<NavigatorState>(find.byType(Navigator))
            .push(
              route(SizedBox.expand(key: pageKey, child: _titlePage(1))),
            )
            .ignore();
        double indent() =>
            tester.getTopLeft(find.text('Title 1')).dx -
            tester.getTopLeft(find.byKey(pageKey)).dx;
        final seen = <double>[];
        await tester.pump();
        for (var ms = 0; ms < 1000; ms += 20) {
          await tester.pump(const Duration(milliseconds: 20));
          seen.add(indent());
        }
        await tester.pumpAndSettle();
        seen.add(indent());
        expect(seen, everyElement(closeTo(66, 0.01)));
      });
    }

    testWidgets('compact window: the title moves past the cluster', (
      tester,
    ) async {
      _installWindowed();
      await pumpShell(tester, titled, size: const Size(600, 800));
      expect(titleX(tester), 66);
    });
  });

  group('native chrome (spec P2 §8.3)', () {
    testWidgets('a visible native chrome clears the cluster itself: no '
        'indent, whatever the platform reads', (tester) async {
      // A windowed read below the native bar row: a 66pt leading delta
      // and no vertical one read as {66, 44}.
      final native = installFakeNative()
        ..controls = const LiquidWindowControls(leading: 66, top: 44);
      await pumpShell(
        tester,
        const TestShell(
          destinations: [
            LiquidDestination(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
              sfSymbol: 'house',
            ),
            LiquidDestination(
              icon: Icon(Icons.inbox_outlined),
              label: 'Inbox',
              sfSymbol: 'tray',
            ),
          ],
          pageBuilder: _titlePage,
        ),
        size: kTabletPortrait,
        padding: const EdgeInsets.only(top: 96, bottom: 20),
      );
      native.emitNative(
        const LiquidWindowControlsChanged(
          LiquidWindowControls(leading: 66, top: 44),
        ),
      );
      await tester.pumpAndSettle();
      final scope = LiquidShellScope.of(
        tester.element(find.text('Title 0')),
      );
      expect(scope.nativeChrome, isTrue);
      expect(scope.windowControls, LiquidWindowControls.zero);
      expect(tester.getTopLeft(find.text('Title 0')).dx, 0);
    });
  });

  group('scope', () {
    testWidgets('the shell and LiquidNoChrome publish the controls', (
      tester,
    ) async {
      _installWindowed();
      await pumpShell(tester, const TestShell(), size: kTabletLandscape);
      expect(
        LiquidShellScope.of(
          tester.element(find.byType(TestPage).first),
        ).windowControls,
        _controls,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LiquidNoChrome(
            child: Builder(
              builder: (context) {
                final scope = LiquidShellScope.of(context);
                return Text(
                  '${scope.chromeKind.name} ${scope.windowControls.leading}',
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('hidden 66.0'), findsOneWidget);
    });
  });

  group('Flutter chrome clears the cluster (spec P2 §8.3)', () {
    testWidgets('the top bar toggle and pill move past it', (tester) async {
      _installWindowed();
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletPortrait,
        padding: const EdgeInsets.only(top: 24, bottom: 20),
      );
      expect(
        tester.getTopLeft(find.byType(SidebarToggle)).dx,
        kSidebarToggleInset + 66,
      );
      // Equal reserves keep the pill centred.
      final pill = tester.getRect(find.byType(LiquidTabBar));
      expect(pill.center.dx, closeTo(kTabletPortrait.width / 2, 0.5));
    });

    testWidgets('RTL: the toggle moves past it on the right', (tester) async {
      _installWindowed();
      await pumpShell(
        tester,
        const TestShell(),
        size: kTabletPortrait,
        padding: const EdgeInsets.only(top: 24, bottom: 20),
        direction: TextDirection.rtl,
      );
      expect(
        tester.getTopRight(find.byType(SidebarToggle)).dx,
        kTabletPortrait.width - kSidebarToggleInset - 66,
      );
      final pill = tester.getRect(find.byType(LiquidTabBar));
      expect(pill.center.dx, closeTo(kTabletPortrait.width / 2, 0.5));
    });

    testWidgets('the sidebar header row moves past it', (tester) async {
      _installWindowed();
      await pumpShell(
        tester,
        const TestShell(sidebarHeader: Text('My app')),
        size: kTabletLandscape,
        padding: const EdgeInsets.only(top: 24, bottom: 20),
      );
      // Tiled sidebar: 16 inner padding + 66.
      expect(tester.getTopLeft(find.text('My app')).dx, 16 + 66);
    });

    testWidgets('no cluster: P1 positions are unchanged', (tester) async {
      await pumpShell(
        tester,
        const TestShell(sidebarHeader: Text('My app')),
        size: kTabletLandscape,
        padding: const EdgeInsets.only(top: 24, bottom: 20),
      );
      expect(tester.getTopLeft(find.text('My app')).dx, 16);
    });
  });
}
