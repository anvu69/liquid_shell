import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// `LiquidTabBar` and `LiquidSidebar` without a `LiquidShell`: the app's
/// own `Scaffold` places them, a bar at the bottom of a phone and a sidebar
/// beside the page in a wide window.
class StandaloneWidgetsCase extends StatefulWidget {
  /// Creates the case.
  const StandaloneWidgetsCase({super.key});

  @override
  State<StandaloneWidgetsCase> createState() => _StandaloneWidgetsCaseState();
}

class _StandaloneWidgetsCaseState extends State<StandaloneWidgetsCase> {
  // #docregion readme
  int _index = 0;

  // Both widgets need a Directionality and an Overlay above them (tooltips,
  // the large-text label viewer). A route of a MaterialApp has both;
  // MaterialApp.builder, above the Navigator, has no Overlay.
  @override
  Widget build(BuildContext context) {
    final page = DemoPage(title: kDemoDestinations[_index].label);
    void select(int index) => setState(() => _index = index);
    if (MediaQuery.sizeOf(context).width >= 700) {
      return Scaffold(
        body: Row(
          children: [
            LiquidSidebar(
              destinations: kDemoDestinations,
              selectedIndex: _index,
              onDestinationSelected: select,
              header: Text(
                'Acme Notes',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(child: page),
          ],
        ),
      );
    }
    return Scaffold(
      // The page scrolls under the floating bar; Scaffold pads it clear.
      extendBody: true,
      body: page,
      bottomNavigationBar: SafeArea(
        top: false,
        // The bar draws the row only: the margins are yours.
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Center(
          heightFactor: 1,
          child: LiquidTabBar(
            destinations: kDemoDestinations,
            selectedIndex: _index,
            onDestinationSelected: select,
          ),
        ),
      ),
    );
  }

  // #enddocregion readme
}
