import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// Native iPadOS 26 chrome: the platform's own tab bar and sidebar. Every
/// destination and the trailing action carry an SF Symbol, and the sidebar
/// footer is native data. Elsewhere this case draws the Flutter chrome.
class NativeChromeCase extends StatefulWidget {
  /// Creates the case.
  const NativeChromeCase({super.key});

  @override
  State<NativeChromeCase> createState() => _NativeChromeCaseState();
}

class _NativeChromeCaseState extends State<NativeChromeCase> {
  // #docregion readme
  int _index = 0;
  int _searches = 0;

  static const _destinations = [
    LiquidDestination(
      icon: Icon(Icons.home_outlined),
      label: 'Home',
      sfSymbol: 'house',
    ),
    LiquidDestination(
      icon: Icon(Icons.inbox_outlined),
      label: 'Inbox',
      badge: LiquidBadge.count(3),
      sfSymbol: 'tray',
    ),
    LiquidDestination(
      icon: Icon(Icons.bar_chart),
      label: 'Reports',
      placement: LiquidPlacement.sidebarOnly,
      sfSymbol: 'chart.bar',
    ),
    LiquidDestination(
      icon: Icon(Icons.settings_outlined),
      label: 'Settings',
      sfSymbol: 'gear',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LiquidShell(
      destinations: _destinations,
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      tabBarTrailing: LiquidTabAction(
        icon: const Icon(Icons.search),
        semanticLabel: 'Search',
        sfSymbol: 'magnifyingglass',
        onPressed: () => setState(() => _searches++),
      ),
      nativeSidebarFooter: LiquidNativeSidebarFooter(
        title: 'Ann Lee',
        subtitle: 'Active profile',
        sfSymbol: 'person.crop.circle',
        semanticLabel: 'Ann Lee, active profile',
        onPressed: () => setState(() => _index = 3),
      ),
      body: DemoPage(
        title: _destinations[_index].label,
        children: [Text('Searches: $_searches')],
      ),
    );
  }

  // #enddocregion readme
}
