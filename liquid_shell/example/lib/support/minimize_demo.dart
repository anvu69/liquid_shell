import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// The `minimize` demo of the UI tests (spec VK-600 §12.5): the three demo
/// tabs, with the two app-driven changes a minimized native bar must
/// follow.
///
/// The [Scaffold] above the shell turns a status-bar tap into a scroll of
/// the page to the top, a programmatic scroll. "Next tab" selects the next
/// destination from the app, not from the bar. It sits at the top, clear of
/// the compact bar and of the list a test drags.
class MinimizeDemo extends StatefulWidget {
  /// Creates the demo.
  const MinimizeDemo({super.key});

  @override
  State<MinimizeDemo> createState() => _MinimizeDemoState();
}

class _MinimizeDemoState extends State<MinimizeDemo> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () =>
          setState(() => _index = (_index + 1) % kDemoDestinations.length),
      label: const Text('Next tab'),
    ),
    body: LiquidShell(
      destinations: kDemoDestinations,
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      body: IndexedStack(
        index: _index,
        children: [
          for (final destination in kDemoDestinations)
            DemoPage(title: destination.label),
        ],
      ),
    ),
  );
}
