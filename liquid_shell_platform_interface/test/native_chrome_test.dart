import 'dart:ui';

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
      'sidebarOnly: false, search: false, pages: [])',
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
      'search: null',
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

  group('P3b search and pages', () {
    test('LiquidNativePage compares field by field', () {
      expect(
        const LiquidNativePage(title: 'Detail', largeTitle: false),
        const LiquidNativePage(title: 'Detail', largeTitle: false),
      );
      expect(
        const LiquidNativePage(title: 'Detail'),
        isNot(const LiquidNativePage(title: 'Detail', largeTitle: true)),
      );
      expect(
        const LiquidNativePage(title: 'A').hashCode,
        const LiquidNativePage(title: 'A').hashCode,
      );
      expect(
        const LiquidNativePage(title: 'A', largeTitle: true).toString(),
        'LiquidNativePage(title: A, largeTitle: true)',
      );
    });

    test('LiquidNativeTab includes search and pages in ==', () {
      const base = LiquidNativeTab(title: 'Search', sfSymbol: '');
      expect(base.search, isFalse);
      expect(base.pages, isEmpty);
      expect(
        const LiquidNativeTab(title: 'Search', sfSymbol: '', search: true),
        isNot(base),
      );
      expect(
        const LiquidNativeTab(
          title: 'Search',
          sfSymbol: '',
          pages: [LiquidNativePage(title: 'Search')],
        ),
        isNot(base),
      );
      expect(
        const LiquidNativeTab(
          title: 'Search',
          sfSymbol: '',
          pages: [LiquidNativePage(title: 'Search')],
        ),
        const LiquidNativeTab(
          title: 'Search',
          sfSymbol: '',
          pages: [LiquidNativePage(title: 'Search')],
        ),
      );
    });

    test('LiquidNativeSearchConfig and the config field', () {
      const a = LiquidNativeSearchConfig(placeholder: 'Songs, places');
      expect(a, const LiquidNativeSearchConfig(placeholder: 'Songs, places'));
      expect(a, isNot(const LiquidNativeSearchConfig()));
      expect(
        const LiquidNativeChromeConfig(engaged: true, search: a),
        isNot(const LiquidNativeChromeConfig(engaged: true)),
      );
      expect(LiquidNativeChromeConfig.dormant.search, isNull);
      expect(
        const LiquidNativeChromeConfig(engaged: true, search: a).toString(),
        contains(
          'search: LiquidNativeSearchConfig(placeholder: Songs, places)',
        ),
      );
    });

    test('search and back events compare by value', () {
      expect(
        const LiquidNativeSearchTextChanged('hồ', composing: true),
        const LiquidNativeSearchTextChanged('hồ', composing: true),
      );
      expect(
        const LiquidNativeSearchTextChanged('hồ', composing: true),
        isNot(const LiquidNativeSearchTextChanged('hồ', composing: false)),
      );
      expect(
        const LiquidNativeSearchActiveChanged(true),
        const LiquidNativeSearchActiveChanged(true),
      );
      expect(
        const LiquidNativeSearchSubmitted('ho'),
        isNot(const LiquidNativeSearchSubmitted('ha')),
      );
      expect(
        const LiquidNativeSearchFieldChanged(Rect.fromLTWH(8, 490, 330, 48)),
        const LiquidNativeSearchFieldChanged(Rect.fromLTWH(8, 490, 330, 48)),
      );
      expect(const LiquidNativeBackTapped(2), const LiquidNativeBackTapped(2));
      expect(
        const LiquidNativeBackTapped(2),
        isNot(const LiquidNativeBackTapped(1)),
      );
      expect(
        const LiquidNativePopToPage(2, index: 0),
        const LiquidNativePopToPage(2, index: 0),
      );
      expect(
        const LiquidNativePopToPage(2, index: 0),
        isNot(const LiquidNativePopToPage(2, index: 1)),
      );
      expect(
        const LiquidNativePopToPage(2, index: 0),
        isNot(const LiquidNativePopToPage(1, index: 0)),
      );
      expect(
        const LiquidNativeSearchTextChanged('a', composing: false).toString(),
        'LiquidNativeSearchTextChanged(a, composing: false)',
      );
    });

    test('the P3b types hash by value and name their fields', () {
      const frame = Rect.fromLTWH(8, 490, 330, 48);
      final pairs = <(Object, Object, String)>[
        (
          const LiquidNativeSearchConfig(placeholder: 'x'),
          const LiquidNativeSearchConfig(placeholder: 'x'),
          'LiquidNativeSearchConfig(placeholder: x)',
        ),
        (
          const LiquidNativeSearchTextChanged('a', composing: true),
          const LiquidNativeSearchTextChanged('a', composing: true),
          'LiquidNativeSearchTextChanged(a, composing: true)',
        ),
        (
          const LiquidNativeSearchActiveChanged(false),
          const LiquidNativeSearchActiveChanged(false),
          'LiquidNativeSearchActiveChanged(false)',
        ),
        (
          const LiquidNativeSearchSubmitted('ho'),
          const LiquidNativeSearchSubmitted('ho'),
          'LiquidNativeSearchSubmitted(ho)',
        ),
        (
          const LiquidNativeSearchFieldChanged(frame),
          const LiquidNativeSearchFieldChanged(frame),
          'LiquidNativeSearchFieldChanged($frame)',
        ),
        (
          const LiquidNativeBackTapped(1),
          const LiquidNativeBackTapped(1),
          'LiquidNativeBackTapped(1)',
        ),
        (
          const LiquidNativePopToPage(1, index: 0),
          const LiquidNativePopToPage(1, index: 0),
          'LiquidNativePopToPage(1, index: 0)',
        ),
      ];
      for (final (a, b, text) in pairs) {
        expect(a.hashCode, b.hashCode, reason: text);
        expect(a.toString(), text);
      }
    });
  });
}
