import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// A compose circle at the end of the tab bar, opening a page above the
/// shell. (Search is a tab: see SearchCase.)
class TrailingActionCase extends StatefulWidget {
  /// Creates the case.
  const TrailingActionCase({super.key});

  @override
  State<TrailingActionCase> createState() => _TrailingActionCaseState();
}

class _TrailingActionCaseState extends State<TrailingActionCase> {
  // #docregion readme
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return LiquidShell(
      destinations: kDemoDestinations,
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      tabBarTrailing: LiquidTabAction(
        icon: const Icon(Icons.edit_outlined),
        semanticLabel: 'Compose',
        sfSymbol: 'square.and.pencil',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: _composePage),
        ),
      ),
      body: DemoPage(title: kDemoDestinations[_index].label),
    );
  }

  // #docregion no-chrome
  // Pushed above the shell (on the app's navigator): no chrome covers it.
  Widget _composePage(BuildContext context) => const LiquidNoChrome(
    child: Scaffold(
      body: DemoPage(
        title: 'New message',
        children: [TextField(decoration: InputDecoration(hintText: 'Message'))],
      ),
    ),
  );
  // #enddocregion no-chrome
  // #enddocregion readme
}
