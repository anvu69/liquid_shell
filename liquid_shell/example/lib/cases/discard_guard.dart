import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// Asks "Discard changes?" before leaving a tab with unsaved edits.
class DiscardGuardCase extends StatefulWidget {
  /// Creates the case.
  const DiscardGuardCase({super.key});

  @override
  State<DiscardGuardCase> createState() => _DiscardGuardCaseState();
}

class _DiscardGuardCaseState extends State<DiscardGuardCase> {
  // #docregion readme
  int _index = 0;
  bool _dirty = true;

  Future<bool> _confirmLeave(int index) async {
    if (!_dirty || index == _index) return true;
    final discard = await showLiquidAlert<bool>(
      context,
      title: 'Discard changes?',
      actions: const [
        LiquidAlertAction(
          label: 'Keep editing',
          value: false,
          style: LiquidAlertActionStyle.cancel,
        ),
        LiquidAlertAction(
          label: 'Discard',
          value: true,
          style: LiquidAlertActionStyle.destructive,
        ),
      ],
    );
    return discard ?? false;
  }

  @override
  Widget build(BuildContext context) => LiquidShell(
    destinations: kDemoDestinations,
    selectedIndex: _index,
    beforeDestinationChange: _confirmLeave,
    onDestinationSelected: (i) => setState(() {
      if (i != _index) _dirty = false;
      _index = i;
    }),
    body: DemoPage(
      title: kDemoDestinations[_index].label,
      children: [
        SwitchListTile(
          title: const Text('Unsaved changes'),
          value: _dirty,
          onChanged: (value) => setState(() => _dirty = value),
        ),
      ],
    ),
  );
  // #enddocregion readme
}
