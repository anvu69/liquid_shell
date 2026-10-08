import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// Wraps the default tab bar and replaces the sidebar.
class CustomChromeCase extends StatefulWidget {
  /// Creates the case.
  const CustomChromeCase({super.key});

  @override
  State<CustomChromeCase> createState() => _CustomChromeCaseState();
}

class _CustomChromeCaseState extends State<CustomChromeCase> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => LiquidShell(
    destinations: kDemoDestinations,
    selectedIndex: _index,
    onDestinationSelected: (i) => setState(() => _index = i),
    chromeBuilder: _chrome,
    body: DemoPage(title: kDemoDestinations[_index].label),
  );

  // #docregion readme
  Widget _chrome(
    BuildContext context,
    LiquidChromeDetails details,
    Widget defaultChrome,
  ) {
    if (details.slot == LiquidChromeSlot.tabBar) {
      // Wrap: a caption above the default bar.
      final scheme = Theme.of(context).colorScheme;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: ShapeDecoration(
              color: scheme.tertiaryContainer,
              shape: const StadiumBorder(),
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text('Beta'),
            ),
          ),
          const SizedBox(height: 8),
          defaultChrome,
        ],
      );
    }
    // Replace: a plain list instead of the glass sidebar.
    return Material(
      child: ListView(
        // Like LiquidSidebar: leave the route's scroll controller (status-bar
        // tap to top) to the body list.
        primary: false,
        children: [
          for (final i in details.visibleIndices)
            ListTile(
              leading: details.destinations[i].icon,
              title: Text(details.destinations[i].label),
              selected: i == details.selectedIndex,
              onTap: () => details.select(i),
            ),
        ],
      ),
    );
  }

  // #enddocregion readme
}
