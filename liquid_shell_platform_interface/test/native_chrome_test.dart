import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

const _tab = LiquidNativeTab(title: 'Home', sfSymbol: 'house');

void main() {
  group('LiquidNativeShellState', () {
    test('unavailable is not installed, for an unsupported platform', () {
      const state = LiquidNativeShellState.unavailable;
      expect(state.installed, isFalse);
      expect(
        state.unavailableReason,
        LiquidNativeUnavailableReason.unsupportedPlatform,
      );
      expect(state.sidebarVisible, isFalse);
    });

    test('sidebarVisible is true for overlay and tiled', () {
      for (final sidebar in LiquidNativeSidebar.values) {
        final state = LiquidNativeShellState(installed: true, sidebar: sidebar);
        expect(state.sidebarVisible, sidebar != LiquidNativeSidebar.hidden);
      }
    });

    test('== compares every field', () {
      const a = LiquidNativeShellState(installed: true);
      expect(a, const LiquidNativeShellState(installed: true));
      expect(
        a.hashCode,
        const LiquidNativeShellState(installed: true).hashCode,
      );
      expect(a, isNot(const LiquidNativeShellState(installed: false)));
      expect(
        a,
        isNot(const LiquidNativeShellState(installed: true, compact: true)),
      );
      expect(
        a,
        isNot(
          const LiquidNativeShellState(
            installed: true,
            sidebar: LiquidNativeSidebar.tiled,
          ),
        ),
      );
      expect(
        a,
        isNot(
          const LiquidNativeShellState(
            installed: true,
            unavailableReason: LiquidNativeUnavailableReason.osTooOld,
          ),
        ),
      );
      expect(a.toString(), contains('installed: true'));
    });
  });

  group('value classes', () {
    test('LiquidNativeTab == compares every field', () {
      expect(_tab, const LiquidNativeTab(title: 'Home', sfSymbol: 'house'));
      expect(
        _tab.hashCode,
        const LiquidNativeTab(title: 'Home', sfSymbol: 'house').hashCode,
      );
      expect(
        _tab,
        isNot(const LiquidNativeTab(title: 'Away', sfSymbol: 'house')),
      );
      expect(
        _tab,
        isNot(const LiquidNativeTab(title: 'Home', sfSymbol: 'car')),
      );
      expect(
        _tab,
        isNot(
          const LiquidNativeTab(title: 'Home', sfSymbol: 'house', badge: ''),
        ),
      );
      expect(
        _tab,
        isNot(
          const LiquidNativeTab(
            title: 'Home',
            sfSymbol: 'house',
            sidebarOnly: true,
          ),
        ),
      );
    });

    test(
      'LiquidNativeAction and LiquidNativeFooter == compare every field',
      () {
        const action = LiquidNativeAction(
          title: 'Search',
          sfSymbol: 'magnifyingglass',
        );
        expect(
          action,
          const LiquidNativeAction(
            title: 'Search',
            sfSymbol: 'magnifyingglass',
          ),
        );
        expect(
          action.hashCode,
          const LiquidNativeAction(
            title: 'Search',
            sfSymbol: 'magnifyingglass',
          ).hashCode,
        );
        expect(
          action,
          isNot(
            const LiquidNativeAction(
              title: 'Find',
              sfSymbol: 'magnifyingglass',
            ),
          ),
        );
        expect(
          action,
          isNot(const LiquidNativeAction(title: 'Search', sfSymbol: 'x')),
        );

        const footer = LiquidNativeFooter(
          title: 'Ann',
          subtitle: 'Profile',
          sfSymbol: 'person',
          semanticLabel: 'Ann, profile',
        );
        expect(
          footer,
          const LiquidNativeFooter(
            title: 'Ann',
            subtitle: 'Profile',
            sfSymbol: 'person',
            semanticLabel: 'Ann, profile',
          ),
        );
        expect(
          footer.hashCode,
          const LiquidNativeFooter(
            title: 'Ann',
            subtitle: 'Profile',
            sfSymbol: 'person',
            semanticLabel: 'Ann, profile',
          ).hashCode,
        );
        for (final other in const [
          LiquidNativeFooter(
            title: 'X',
            subtitle: 'Profile',
            sfSymbol: 'person',
            semanticLabel: 'Ann, profile',
          ),
          LiquidNativeFooter(
            title: 'Ann',
            subtitle: 'X',
            sfSymbol: 'person',
            semanticLabel: 'Ann, profile',
          ),
          LiquidNativeFooter(
            title: 'Ann',
            subtitle: 'Profile',
            sfSymbol: 'X',
            semanticLabel: 'Ann, profile',
          ),
          LiquidNativeFooter(
            title: 'Ann',
            subtitle: 'Profile',
            sfSymbol: 'person',
            semanticLabel: 'X',
          ),
        ]) {
          expect(footer, isNot(other));
        }
      },
    );

    test('LiquidNativeChromeConfig == compares every field, tabs by value', () {
      const base = LiquidNativeChromeConfig(engaged: true, tabs: [_tab]);
      expect(
        base,
        const LiquidNativeChromeConfig(
          engaged: true,
          tabs: [LiquidNativeTab(title: 'Home', sfSymbol: 'house')],
        ),
      );
      expect(
        base.hashCode,
        const LiquidNativeChromeConfig(engaged: true, tabs: [_tab]).hashCode,
      );
      for (final other in const [
        LiquidNativeChromeConfig(engaged: false, tabs: [_tab]),
        LiquidNativeChromeConfig(engaged: true),
        LiquidNativeChromeConfig(engaged: true, tabs: [_tab], selectedIndex: 1),
        LiquidNativeChromeConfig(
          engaged: true,
          tabs: [_tab],
          trailing: LiquidNativeAction(title: 'S', sfSymbol: 's'),
        ),
        LiquidNativeChromeConfig(
          engaged: true,
          tabs: [_tab],
          footer: LiquidNativeFooter(
            title: 'a',
            subtitle: 'b',
            sfSymbol: 'c',
            semanticLabel: 'd',
          ),
        ),
        LiquidNativeChromeConfig(engaged: true, tabs: [_tab], tintArgb: 1),
        LiquidNativeChromeConfig(engaged: true, tabs: [_tab], dark: true),
        LiquidNativeChromeConfig(engaged: true, tabs: [_tab], rtl: true),
        LiquidNativeChromeConfig(engaged: true, tabs: [_tab], hidden: true),
        LiquidNativeChromeConfig(
          engaged: true,
          tabs: [_tab],
          interactive: false,
        ),
      ]) {
        expect(base, isNot(other));
      }
    });

    test('visible needs engaged and not hidden', () {
      expect(LiquidNativeChromeConfig.dormant.visible, isFalse);
      expect(const LiquidNativeChromeConfig(engaged: true).visible, isTrue);
      expect(
        const LiquidNativeChromeConfig(engaged: true, hidden: true).visible,
        isFalse,
      );
    });
  });

  test('events compare by value', () {
    expect(
      const LiquidNativeDestinationTapped(2),
      const LiquidNativeDestinationTapped(2),
    );
    expect(
      const LiquidNativeDestinationTapped(2).hashCode,
      const LiquidNativeDestinationTapped(2).hashCode,
    );
    expect(
      const LiquidNativeDestinationTapped(2),
      isNot(const LiquidNativeDestinationTapped(1)),
    );
    expect(
      const LiquidNativeStateChanged(LiquidNativeShellState.unavailable).state,
      LiquidNativeShellState.unavailable,
    );
    expect(
      const LiquidWindowControlsChanged(LiquidWindowControls.zero).controls,
      LiquidWindowControls.zero,
    );
    expect(const LiquidNativeTrailingTapped(), isA<LiquidNativeEvent>());
    expect(const LiquidNativeFooterTapped(), isA<LiquidNativeEvent>());
  });

  test('events that carry a value compare by it, not by identity', () {
    // Built at run time (no const canonicalisation), as the channel does.
    LiquidNativeEvent state({required bool installed}) =>
        LiquidNativeStateChanged(LiquidNativeShellState(installed: installed));
    LiquidNativeEvent controls(double leading) =>
        LiquidWindowControlsChanged(LiquidWindowControls(leading: leading));
    expect(state(installed: true), state(installed: true));
    expect(
      state(installed: true).hashCode,
      state(installed: true).hashCode,
    );
    expect(state(installed: true), isNot(state(installed: false)));
    expect(controls(66), controls(66));
    expect(controls(66).hashCode, controls(66).hashCode);
    expect(controls(66), isNot(controls(9)));
  });

  test('argument-less events are equal to any instance of their type', () {
    // Calling a tear-off builds a new, non-canonical instance.
    const trailing = LiquidNativeTrailingTapped.new;
    const footer = LiquidNativeFooterTapped.new;
    expect(trailing(), trailing());
    expect(trailing().hashCode, trailing().hashCode);
    expect(footer(), footer());
    expect(footer().hashCode, footer().hashCode);
    expect(trailing(), isNot(footer()));
  });

  test('toString names the type and every field', () {
    expect(
      const LiquidNativeTab(
        title: 'Home',
        sfSymbol: 'house',
        badge: '3',
      ).toString(),
      'LiquidNativeTab(title: Home, sfSymbol: house, badge: 3, '
      'sidebarOnly: false)',
    );
    expect(
      const LiquidNativeAction(
        title: 'Search',
        sfSymbol: 'magnifyingglass',
      ).toString(),
      'LiquidNativeAction(title: Search, sfSymbol: magnifyingglass)',
    );
    expect(
      const LiquidNativeFooter(
        title: 'Ann',
        subtitle: 'Profile',
        sfSymbol: 'person',
        semanticLabel: 'Ann, profile',
      ).toString(),
      'LiquidNativeFooter(title: Ann, subtitle: Profile, sfSymbol: person, '
      'semanticLabel: Ann, profile)',
    );
    final config = const LiquidNativeChromeConfig(
      engaged: true,
      tabs: [_tab],
      selectedIndex: 2,
      tintArgb: 0xFF3D5AFE,
    ).toString();
    expect(config, startsWith('LiquidNativeChromeConfig(engaged: true, '));
    for (final field in [
      'tabs: [LiquidNativeTab(title: Home',
      'selectedIndex: 2',
      'trailing: null',
      'footer: null',
      'tintArgb: 0xff3d5afe',
      'dark: false',
      'rtl: false',
      'hidden: false',
      'interactive: true',
    ]) {
      expect(config, contains(field));
    }
    expect(
      const LiquidNativeDestinationTapped(2).toString(),
      'LiquidNativeDestinationTapped(2)',
    );
    expect(
      const LiquidNativeTrailingTapped().toString(),
      'LiquidNativeTrailingTapped()',
    );
    expect(
      const LiquidNativeFooterTapped().toString(),
      'LiquidNativeFooterTapped()',
    );
    expect(
      const LiquidNativeStateChanged(
        LiquidNativeShellState.unavailable,
      ).toString(),
      'LiquidNativeStateChanged(${LiquidNativeShellState.unavailable})',
    );
    expect(
      const LiquidWindowControlsChanged(LiquidWindowControls.zero).toString(),
      'LiquidWindowControlsChanged(${LiquidWindowControls.zero})',
    );
  });
}
