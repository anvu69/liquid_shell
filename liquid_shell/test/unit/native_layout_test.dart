import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/native/native_layout.dart';
import 'package:liquid_shell/src/shell/shell_layout.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

const _installed = LiquidNativeShellState(installed: true);

bool _engaged({
  LiquidNativeChrome mode = LiquidNativeChrome.auto,
  bool owner = true,
  LiquidNativeShellState? state = _installed,
  ShellPresentation presentation = ShellPresentation.tiled,
  bool hasChromeBuilder = false,
  bool describable = true,
}) => nativeChromeEngaged(
  mode: mode,
  owner: owner,
  state: state,
  presentation: presentation,
  hasChromeBuilder: hasChromeBuilder,
  describable: describable,
);

void main() {
  group('nativeChromeEngaged', () {
    test('every condition holds → engaged', () {
      expect(_engaged(), isTrue);
      expect(_engaged(presentation: ShellPresentation.overlay), isTrue);
    });

    test('each failing condition disengages', () {
      expect(_engaged(mode: LiquidNativeChrome.off), isFalse);
      expect(_engaged(owner: false), isFalse);
      expect(_engaged(state: null), isFalse);
      expect(
        _engaged(state: const LiquidNativeShellState(installed: false)),
        isFalse,
      );
      expect(
        _engaged(
          state: const LiquidNativeShellState(installed: true, compact: true),
        ),
        isFalse,
      );
      expect(_engaged(presentation: ShellPresentation.compact), isFalse);
      expect(_engaged(hasChromeBuilder: true), isFalse);
      expect(_engaged(describable: false), isFalse);
    });
  });

  group('nativeChromePossible (what Dart knows before the platform)', () {
    bool possible({
      LiquidNativeChrome mode = LiquidNativeChrome.auto,
      ShellPresentation presentation = ShellPresentation.tiled,
      bool hasChromeBuilder = false,
      bool describable = true,
    }) => nativeChromePossible(
      mode: mode,
      presentation: presentation,
      hasChromeBuilder: hasChromeBuilder,
      describable: describable,
    );

    test('auto, regular, no chromeBuilder, describable → possible', () {
      expect(possible(), isTrue);
      expect(possible(presentation: ShellPresentation.overlay), isTrue);
    });

    test('each failing condition rules it out', () {
      expect(possible(mode: LiquidNativeChrome.off), isFalse);
      expect(possible(presentation: ShellPresentation.compact), isFalse);
      expect(possible(hasChromeBuilder: true), isFalse);
      expect(possible(describable: false), isFalse);
    });
  });

  test('nativeChromeScreenPossible: an iPad screen, not an iPhone one', () {
    // iPad mini (744 × 1133) is the smallest iPad.
    expect(nativeChromeScreenPossible(const Size(744, 1133)), isTrue);
    expect(nativeChromeScreenPossible(const Size(1194, 834)), isTrue);
    // iPhone 17 Pro Max, either way round: 440pt short side.
    expect(nativeChromeScreenPossible(const Size(956, 440)), isFalse);
    expect(nativeChromeScreenPossible(const Size(440, 956)), isFalse);
    // Unknown screen: possible (wait for the platform, as before).
    expect(nativeChromeScreenPossible(Size.zero), isTrue);
    // A display not described yet (ratio 0): the caller's size / ratio is
    // NaN (empty) or infinite. Unknown too, never a NaN comparison.
    expect(nativeChromeScreenPossible(Size.zero / 0), isTrue);
    expect(nativeChromeScreenPossible(const Size(2388, 1668) / 0), isTrue);
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

  test('nativeChromeKind maps the sidebar; hidden wins', () {
    LiquidChromeKind kind(LiquidNativeSidebar sidebar, {bool hidden = false}) =>
        nativeChromeKind(
          state: LiquidNativeShellState(installed: true, sidebar: sidebar),
          hidden: hidden,
        );
    expect(kind(LiquidNativeSidebar.hidden), LiquidChromeKind.topBar);
    expect(kind(LiquidNativeSidebar.overlay), LiquidChromeKind.sidebarOverlay);
    expect(kind(LiquidNativeSidebar.tiled), LiquidChromeKind.sidebarTiled);
    expect(
      kind(LiquidNativeSidebar.tiled, hidden: true),
      LiquidChromeKind.hidden,
    );
  });

  test('nativeChromeInsets: the top padding under the bar, else zero', () {
    for (final kind in LiquidChromeKind.values) {
      final insets = nativeChromeInsets(kind: kind, topPadding: 96);
      final covered =
          kind == LiquidChromeKind.topBar ||
          kind == LiquidChromeKind.sidebarOverlay;
      expect(
        insets,
        covered ? const EdgeInsets.only(top: 96) : EdgeInsets.zero,
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
