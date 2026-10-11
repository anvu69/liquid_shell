import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/native/native_layout.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

const _installed = LiquidNativeShellState(installed: true);

bool _engaged({
  LiquidNativeChrome mode = LiquidNativeChrome.auto,
  bool owner = true,
  LiquidNativeShellState? state = _installed,
  bool hasChromeBuilder = false,
  bool describable = true,
  bool glassTierForced = false,
}) => nativeChromeEngaged(
  mode: mode,
  owner: owner,
  state: state,
  hasChromeBuilder: hasChromeBuilder,
  describable: describable,
  glassTierForced: glassTierForced,
);

void main() {
  group('nativeChromeEngaged', () {
    test('every condition holds → engaged, at either size class (D1)', () {
      expect(_engaged(), isTrue);
      expect(
        _engaged(
          state: const LiquidNativeShellState(installed: true, compact: true),
        ),
        isTrue,
      );
    });

    test('each failing condition disengages', () {
      expect(_engaged(mode: LiquidNativeChrome.off), isFalse);
      expect(_engaged(owner: false), isFalse);
      expect(_engaged(state: null), isFalse);
      expect(
        _engaged(state: const LiquidNativeShellState(installed: false)),
        isFalse,
      );
      expect(_engaged(hasChromeBuilder: true), isFalse);
      expect(_engaged(describable: false), isFalse);
      expect(_engaged(glassTierForced: true), isFalse);
    });
  });

  group('nativeChromePossible (what Dart knows before the platform)', () {
    bool possible({
      LiquidNativeChrome mode = LiquidNativeChrome.auto,
      bool hasChromeBuilder = false,
      bool describable = true,
      bool glassTierForced = false,
    }) => nativeChromePossible(
      mode: mode,
      hasChromeBuilder: hasChromeBuilder,
      describable: describable,
      glassTierForced: glassTierForced,
    );

    test('auto, no chromeBuilder, describable → possible', () {
      expect(possible(), isTrue);
    });

    test('each failing condition rules it out', () {
      expect(possible(mode: LiquidNativeChrome.off), isFalse);
      expect(possible(hasChromeBuilder: true), isFalse);
      expect(possible(describable: false), isFalse);
      expect(possible(glassTierForced: true), isFalse);
    });
  });

  group('nativeSymbolHint (spec P2 §15, E2)', () {
    const home = LiquidDestination(
      icon: Icon(Icons.home),
      label: 'Home',
      sfSymbol: 'house',
    );
    const star = LiquidDestination(icon: Icon(Icons.star), label: 'Star');
    const moon = LiquidDestination(icon: Icon(Icons.bedtime), label: 'Moon');
    void noop() {}
    final plainSearch = LiquidTabAction(
      icon: const Icon(Icons.search),
      onPressed: noop,
      semanticLabel: 'Search',
    );
    final search = LiquidTabAction(
      icon: const Icon(Icons.search),
      onPressed: noop,
      semanticLabel: 'Search',
      sfSymbol: 'magnifyingglass',
    );

    test('null when every destination and the trailing action have one', () {
      expect(nativeSymbolHint(const [home], null), isNull);
      expect(nativeSymbolHint(const [home], search), isNull);
    });

    test('names each destination without one, and only those', () {
      final one = nativeSymbolHint(const [home, star], search)!;
      expect(one, contains('destination "Star"'));
      expect(one, isNot(contains('Home')));
      expect(one, isNot(contains('tabBarTrailing')));

      final two = nativeSymbolHint(const [star, home, moon], null)!;
      expect(two, contains('destinations "Star", "Moon"'));
    });

    test('names the trailing action by its semantic label', () {
      final trailing = nativeSymbolHint(const [home], plainSearch)!;
      expect(trailing, contains('tabBarTrailing "Search"'));
      expect(trailing, isNot(contains('destination')));

      final both = nativeSymbolHint(const [star], plainSearch)!;
      expect(both, contains('destination "Star"'));
      expect(both, contains('tabBarTrailing "Search"'));
    });

    test('is one line that says how to fix or silence it', () {
      final hint = nativeSymbolHint(const [star], plainSearch)!;
      expect(hint, startsWith('liquid_shell: '));
      expect(hint, isNot(contains('\n')));
      expect(hint, contains('sfSymbol'));
      expect(hint, contains('nativeChrome: LiquidNativeChrome.off'));
    });
  });

  test('nativeDescribable needs every symbol, the trailing one too', () {
    const home = LiquidDestination(
      icon: Icon(Icons.home),
      label: 'Home',
      sfSymbol: 'house',
    );
    const plain = LiquidDestination(icon: Icon(Icons.star), label: 'Star');
    void noop() {}
    expect(nativeDescribable(const [home], null), isTrue);
    expect(nativeDescribable(const [home, plain], null), isFalse);
    expect(nativeDescribable(const [], null), isFalse);
    expect(
      nativeDescribable(
        const [
          home,
        ],
        LiquidTabAction(
          icon: const Icon(Icons.search),
          onPressed: noop,
          semanticLabel: 'S',
        ),
      ),
      isFalse,
    );
    expect(
      nativeDescribable(
        const [
          home,
        ],
        LiquidTabAction(
          icon: const Icon(Icons.search),
          onPressed: noop,
          semanticLabel: 'S',
          sfSymbol: 'magnifyingglass',
        ),
      ),
      isTrue,
    );
  });

  test('nativeBadgeText follows the Flutter badge', () {
    expect(nativeBadgeText(null), isNull);
    expect(nativeBadgeText(const LiquidBadge.count(0)), isNull);
    expect(nativeBadgeText(const LiquidBadge.count(7)), '7');
    expect(nativeBadgeText(const LiquidBadge.count(120)), '99+');
    expect(nativeBadgeText(const LiquidBadge.count(12, max: 9)), '9+');
    expect(nativeBadgeText(const LiquidBadge.dot()), '');
  });

  test('nativeChromeKind maps the sidebar; compact is the bottom bar; '
      'hidden wins', () {
    LiquidChromeKind kind(
      LiquidNativeSidebar sidebar, {
      bool compact = false,
      bool hidden = false,
    }) => nativeChromeKind(
      state: LiquidNativeShellState(
        installed: true,
        compact: compact,
        sidebar: sidebar,
      ),
      hidden: hidden,
    );
    expect(
      kind(LiquidNativeSidebar.hidden, compact: true),
      LiquidChromeKind.bottomBar,
    );
    expect(
      kind(LiquidNativeSidebar.hidden, compact: true, hidden: true),
      LiquidChromeKind.hidden,
    );
    expect(kind(LiquidNativeSidebar.hidden), LiquidChromeKind.topBar);
    expect(kind(LiquidNativeSidebar.overlay), LiquidChromeKind.sidebarOverlay);
    expect(kind(LiquidNativeSidebar.tiled), LiquidChromeKind.sidebarTiled);
    expect(
      kind(LiquidNativeSidebar.tiled, hidden: true),
      LiquidChromeKind.hidden,
    );
  });

  test('nativeChromeInsets: the padding on the side of the bar, else zero', () {
    const padding = EdgeInsets.only(top: 96, bottom: 83);
    for (final kind in LiquidChromeKind.values) {
      expect(
        nativeChromeInsets(kind: kind, padding: padding),
        switch (kind) {
          LiquidChromeKind.topBar ||
          LiquidChromeKind.sidebarOverlay => const EdgeInsets.only(top: 96),
          LiquidChromeKind.bottomBar => const EdgeInsets.only(bottom: 83),
          _ => EdgeInsets.zero,
        },
      );
    }
  });

  test('nativeConfigFor maps every field', () {
    void noop() {}
    final config = nativeConfigFor(
      engaged: true,
      destinations: const [
        LiquidDestination(
          icon: Icon(Icons.home),
          label: 'Home',
          sfSymbol: 'house',
          badge: LiquidBadge.count(2),
        ),
        LiquidDestination(
          icon: Icon(Icons.bar_chart),
          label: 'Reports',
          sfSymbol: 'chart.bar',
          placement: LiquidPlacement.sidebarOnly,
        ),
      ],
      selectedIndex: 1,
      trailing: LiquidTabAction(
        icon: const Icon(Icons.search),
        onPressed: noop,
        semanticLabel: 'Search',
        sfSymbol: 'magnifyingglass',
      ),
      footer: LiquidNativeSidebarFooter(
        title: 'Ann',
        subtitle: 'Profile',
        sfSymbol: 'person',
        semanticLabel: 'Ann, profile',
        onPressed: noop,
      ),
      tint: const Color(0xFF3D5AFE),
      dark: true,
      rtl: true,
      hidden: true,
      interactive: false,
    );
    expect(
      config,
      const LiquidNativeChromeConfig(
        engaged: true,
        tabs: [
          LiquidNativeTab(title: 'Home', sfSymbol: 'house', badge: '2'),
          LiquidNativeTab(
            title: 'Reports',
            sfSymbol: 'chart.bar',
            sidebarOnly: true,
          ),
        ],
        selectedIndex: 1,
        trailing: LiquidNativeAction(
          title: 'Search',
          sfSymbol: 'magnifyingglass',
        ),
        footer: LiquidNativeFooter(
          title: 'Ann',
          subtitle: 'Profile',
          sfSymbol: 'person',
          semanticLabel: 'Ann, profile',
        ),
        tintArgb: 0xFF3D5AFE,
        dark: true,
        rtl: true,
        hidden: true,
        interactive: false,
      ),
    );
  });
}
