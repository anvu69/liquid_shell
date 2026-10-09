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

    testWidgets('compact window: the title moves past the cluster', (
      tester,
    ) async {
      _installWindowed();
      await pumpShell(tester, titled, size: const Size(600, 800));
      expect(titleX(tester), 66);
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
