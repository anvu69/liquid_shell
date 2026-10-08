import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// A search circle at the end of the tab bar, opening a page above the shell.
class TrailingActionCase extends StatefulWidget {
  /// Creates the case.
  const TrailingActionCase({super.key});

  @override
  State<TrailingActionCase> createState() => _TrailingActionCaseState();
}

class _TrailingActionCaseState extends State<TrailingActionCase> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    // #docregion readme
    return LiquidShell(
      destinations: kDemoDestinations,
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      tabBarTrailing: LiquidTabAction(
        icon: const Icon(Icons.search),
        semanticLabel: 'Search',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SearchPage()),
        ),
      ),
      body: DemoPage(title: kDemoDestinations[_index].label),
    );
    // #enddocregion readme
  }
}

/// A page pushed above the shell: no chrome covers it.
class SearchPage extends StatelessWidget {
  /// Creates the page.
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) => const LiquidNoChrome(
    child: Scaffold(
      body: DemoPage(
        title: 'Search',
        children: [TextField(decoration: InputDecoration(hintText: 'Find'))],
      ),
    ),
  );
}
