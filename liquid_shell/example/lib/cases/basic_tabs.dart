import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// The smallest shell: three tabs over an `IndexedStack`. Native chrome on
/// iOS 26, Flutter chrome elsewhere.
class BasicTabsCase extends StatefulWidget {
  /// Creates the case.
  const BasicTabsCase({super.key});

  @override
  State<BasicTabsCase> createState() => _BasicTabsCaseState();
}

class _BasicTabsCaseState extends State<BasicTabsCase> {
  // #docregion readme
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return LiquidShell(
      // sfSymbol: the native chrome's icon on iOS 26.
      destinations: const [
        LiquidDestination(
          icon: Icon(Icons.home_outlined),
          label: 'Home',
          sfSymbol: 'house',
        ),
        LiquidDestination(
          icon: Icon(Icons.explore_outlined),
          label: 'Explore',
          sfSymbol: 'map',
        ),
        LiquidDestination(
          icon: Icon(Icons.settings_outlined),
          label: 'Settings',
          sfSymbol: 'gear',
        ),
      ],
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      body: IndexedStack(
        index: _index,
        children: const [
          DemoPage(title: 'Home'),
          DemoPage(title: 'Explore'),
          DemoPage(title: 'Settings'),
        ],
      ),
    );
  }

  // #enddocregion readme
}
