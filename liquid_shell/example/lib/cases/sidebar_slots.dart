import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// A title in the sidebar header and a profile footer.
class SidebarSlotsCase extends StatefulWidget {
  /// Creates the case.
  const SidebarSlotsCase({super.key});

  @override
  State<SidebarSlotsCase> createState() => _SidebarSlotsCaseState();
}

class _SidebarSlotsCaseState extends State<SidebarSlotsCase> {
  // #docregion readme
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LiquidShell(
      destinations: kDemoDestinations,
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      sidebarHeader: Text('Acme Notes', style: theme.textTheme.titleLarge),
      sidebarFooter: const ListTile(
        leading: CircleAvatar(child: Text('A')),
        title: Text('Ana Lima'),
        subtitle: Text('ana@example.com'),
      ),
      body: DemoPage(title: kDemoDestinations[_index].label),
    );
  }

  // #enddocregion readme
}
