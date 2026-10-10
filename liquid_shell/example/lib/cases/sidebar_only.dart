import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// Two destinations that live in the sidebar only.
class SidebarOnlyCase extends StatefulWidget {
  /// Creates the case.
  const SidebarOnlyCase({super.key});

  @override
  State<SidebarOnlyCase> createState() => _SidebarOnlyCaseState();
}

class _SidebarOnlyCaseState extends State<SidebarOnlyCase> {
  // #docregion readme
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return LiquidShell(
      destinations: const [
        ...kDemoDestinations,
        LiquidDestination(
          icon: Icon(Icons.bar_chart),
          label: 'Reports',
          placement: LiquidPlacement.sidebarOnly,
          sfSymbol: 'chart.bar',
        ),
        LiquidDestination(
          icon: Icon(Icons.archive_outlined),
          label: 'Archive',
          placement: LiquidPlacement.sidebarOnly,
          sfSymbol: 'archivebox',
        ),
      ],
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      // Phones have no sidebar: fall back to the first tab.
      onSelectedDestinationHidden: (_) => setState(() => _index = 0),
      body: DemoPage(title: 'Destination ${_index + 1}'),
    );
  }

  // #enddocregion readme
}
