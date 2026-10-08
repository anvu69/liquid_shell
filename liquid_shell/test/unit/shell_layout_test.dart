import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/shell/shell_layout.dart';

void main() {
  const breakpoints = LiquidShellBreakpoints();

  group('LiquidShellBreakpoints', () {
    test('defaults 700 / 1024; compact below 700', () {
      expect(breakpoints.regular, 700);
      expect(breakpoints.tiledSidebar, 1024);
      expect(breakpoints.sizeClassOf(699), LiquidSizeClass.compact);
      expect(breakpoints.sizeClassOf(699.9), LiquidSizeClass.compact);
      expect(breakpoints.sizeClassOf(700), LiquidSizeClass.regular);
    });

    test('asserts regular > 0 and tiledSidebar >= regular', () {
      expect(
        () => LiquidShellBreakpoints(regular: 0),
        throwsAssertionError,
      );
      expect(
        () => LiquidShellBreakpoints(regular: 800, tiledSidebar: 700),
        throwsAssertionError,
      );
    });

    test('==', () {
      expect(const LiquidShellBreakpoints(), const LiquidShellBreakpoints());
      expect(
        const LiquidShellBreakpoints().hashCode,
        const LiquidShellBreakpoints().hashCode,
      );
      expect(
        const LiquidShellBreakpoints(),
        isNot(const LiquidShellBreakpoints(regular: 600)),
      );
      expect(
        const LiquidShellBreakpoints(),
        isNot(const LiquidShellBreakpoints(tiledSidebar: 1200)),
      );
    });

    test('toString names both thresholds', () {
      expect(
        '${const LiquidShellBreakpoints(regular: 600, tiledSidebar: 1200)}',
        'LiquidShellBreakpoints(regular: 600.0, tiledSidebar: 1200.0)',
      );
    });
  });

  group('presentationFor', () {
    ShellPresentation of(double w, double h) =>
        presentationFor(Size(w, h), breakpoints);

    test('reference devices (spec §5.1)', () {
      expect(of(393, 852), ShellPresentation.compact); // iPhone
      expect(of(932, 430), ShellPresentation.overlay); // Pro Max landscape
      expect(of(834, 1194), ShellPresentation.overlay); // iPad 11" portrait
      expect(of(1194, 834), ShellPresentation.tiled); // iPad 11" landscape
      expect(of(412, 915), ShellPresentation.compact); // Android phone
      expect(of(1280, 800), ShellPresentation.tiled); // Android tablet
    });

    test('tiled needs landscape AND width ≥ tiledSidebar', () {
      expect(of(1023, 700), ShellPresentation.overlay);
      expect(of(1024, 700), ShellPresentation.tiled);
      expect(of(1025, 700), ShellPresentation.tiled);
      expect(of(1024, 1366), ShellPresentation.overlay); // portrait
      expect(of(1100, 1100), ShellPresentation.overlay); // square is not w > h
      expect(of(1024, 1024), ShellPresentation.overlay); // square at the edge
      expect(of(1100, 1099), ShellPresentation.tiled); // just landscape
    });

    test('size class at 699 / 700', () {
      expect(of(699, 400), ShellPresentation.compact);
      expect(of(700, 400), ShellPresentation.overlay);
      expect(sizeClassOf(ShellPresentation.compact), LiquidSizeClass.compact);
      expect(sizeClassOf(ShellPresentation.overlay), LiquidSizeClass.regular);
      expect(sizeClassOf(ShellPresentation.tiled), LiquidSizeClass.regular);
    });
  });

  group('chromeKindFor (every cell of §5.1)', () {
    LiquidChromeKind kind(
      ShellPresentation p, {
      bool visible = false,
      bool hidden = false,
    }) =>
        chromeKindFor(presentation: p, sidebarVisible: visible, hidden: hidden);

    test('compact → bottomBar', () {
      expect(kind(ShellPresentation.compact), LiquidChromeKind.bottomBar);
    });

    test('regular with the sidebar hidden → topBar', () {
      expect(kind(ShellPresentation.overlay), LiquidChromeKind.topBar);
      expect(kind(ShellPresentation.tiled), LiquidChromeKind.topBar);
    });

    test('sidebar shown → sidebarOverlay / sidebarTiled', () {
      expect(
        kind(ShellPresentation.overlay, visible: true),
        LiquidChromeKind.sidebarOverlay,
      );
      expect(
        kind(ShellPresentation.tiled, visible: true),
        LiquidChromeKind.sidebarTiled,
      );
    });

    test('hide-chrome wins everywhere', () {
      for (final p in ShellPresentation.values) {
        for (final visible in [false, true]) {
          expect(
            kind(p, visible: visible, hidden: true),
            LiquidChromeKind.hidden,
          );
        }
      }
    });
  });

  group('sidebarVisibleFor (state machine, Q2)', () {
    test('initial value per presentation', () {
      for (final (p, expected) in [
        (ShellPresentation.compact, false),
        (ShellPresentation.overlay, false),
        (ShellPresentation.tiled, true),
      ]) {
        expect(
          sidebarVisibleFor(previous: null, current: p, visible: !expected),
          expected,
        );
      }
    });

    test('keeps the value while the presentation stays', () {
      expect(
        sidebarVisibleFor(
          previous: ShellPresentation.overlay,
          current: ShellPresentation.overlay,
          visible: true,
        ),
        isTrue,
      );
      expect(
        sidebarVisibleFor(
          previous: ShellPresentation.tiled,
          current: ShellPresentation.tiled,
          visible: false,
        ),
        isFalse,
      );
    });

    test('resets to the default when the presentation changes', () {
      expect(
        sidebarVisibleFor(
          previous: ShellPresentation.tiled,
          current: ShellPresentation.overlay,
          visible: true,
        ),
        isFalse,
      );
      expect(
        sidebarVisibleFor(
          previous: ShellPresentation.overlay,
          current: ShellPresentation.tiled,
          visible: false,
        ),
        isTrue,
      );
    });

    test('compact is always false and ignores setters', () {
      expect(
        sidebarVisibleFor(
          previous: ShellPresentation.compact,
          current: ShellPresentation.compact,
          visible: true,
        ),
        isFalse,
      );
    });
  });

  group('bottomGapFor (Q9)', () {
    test('21 over a gesture area: always on iOS', () {
      expect(
        bottomGapFor(
          platform: TargetPlatform.iOS,
          viewPaddingBottom: 34,
          gestureInsetBottom: 0,
        ),
        21,
      );
    });

    test('21 on Android gesture navigation', () {
      expect(
        bottomGapFor(
          platform: TargetPlatform.android,
          viewPaddingBottom: 24,
          gestureInsetBottom: 24,
        ),
        21,
      );
    });

    test('max(21, viewPadding + 8) otherwise', () {
      expect(
        bottomGapFor(
          platform: TargetPlatform.android,
          viewPaddingBottom: 48,
          gestureInsetBottom: 0,
        ),
        56,
      );
      expect(
        bottomGapFor(
          platform: TargetPlatform.android,
          viewPaddingBottom: 0,
          gestureInsetBottom: 0,
        ),
        21,
      );
    });
  });

  group('chromeInsetsFor (§5.3)', () {
    EdgeInsets insets(LiquidChromeKind kind, {double? measured}) =>
        chromeInsetsFor(
          kind: kind,
          topPadding: 24,
          measuredBar: measured,
          bottomGap: 21,
        );

    test('bottomBar: measured row + gap, 83 before measurement', () {
      expect(
        insets(LiquidChromeKind.bottomBar),
        const EdgeInsets.only(bottom: 83),
      );
      expect(
        insets(LiquidChromeKind.bottomBar, measured: 100),
        const EdgeInsets.only(bottom: 121),
      );
    });

    test('topBar and sidebarOverlay: pad.top + 20 + pill, +72 before '
        'measurement', () {
      for (final kind in [
        LiquidChromeKind.topBar,
        LiquidChromeKind.sidebarOverlay,
      ]) {
        expect(insets(kind), const EdgeInsets.only(top: 96));
        expect(insets(kind, measured: 60), const EdgeInsets.only(top: 104));
      }
    });

    test('sidebarTiled and hidden: zero', () {
      expect(insets(LiquidChromeKind.sidebarTiled), EdgeInsets.zero);
      expect(insets(LiquidChromeKind.hidden), EdgeInsets.zero);
    });
  });

  test('resolveSelectedIndex maps out-of-range to 0 (release)', () {
    expect(resolveSelectedIndex(2, 3), 2);
    expect(resolveSelectedIndex(3, 3), 0);
    expect(resolveSelectedIndex(-1, 3), 0);
  });

  test('tabBarIndices lists everywhere destinations only', () {
    const destinations = [
      LiquidDestination(icon: SizedBox(), label: 'A'),
      LiquidDestination(
        icon: SizedBox(),
        label: 'B',
        placement: LiquidPlacement.sidebarOnly,
      ),
      LiquidDestination(icon: SizedBox(), label: 'C'),
    ];
    expect(tabBarIndices(destinations), [0, 2]);
  });
}
