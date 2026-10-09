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
