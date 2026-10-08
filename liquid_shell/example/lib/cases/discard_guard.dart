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
  final _branch = GlobalKey<NavigatorState>();
  int _index = 0;
  bool _dirty = true;
  bool _detailOpen = false;

  // #docregion readme
  Future<bool> _confirmLeave(int index) async {
    if (!_dirty || index == _index) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }
  // #enddocregion readme

  @override
  Widget build(BuildContext context) => LiquidShell(
    destinations: kDemoDestinations,
    selectedIndex: _index,
    beforeDestinationChange: _confirmLeave,
    onDestinationSelected: (i) => setState(() {
      if (i != _index) _dirty = false;
      _index = i;
    }),
    // The branch has its own navigator, as a router's shell branch does:
    // the detail page is pushed inside it, under the shell, which is where
    // LiquidHideChrome can reach the shell. System back pops it first.
    body: NavigatorPopHandler(
      onPopWithResult: (_) => _branch.currentState?.maybePop(),
      child: Navigator(
        key: _branch,
        pages: [
          MaterialPage<void>(
            key: const ValueKey('branch'),
            child: DemoPage(
              title: kDemoDestinations[_index].label,
              children: [
                SwitchListTile(
                  title: const Text('Unsaved changes'),
                  value: _dirty,
                  onChanged: (value) => setState(() => _dirty = value),
                ),
                ListTile(
                  title: const Text('Open a full-frame detail page'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => setState(() => _detailOpen = true),
                ),
              ],
            ),
          ),
          if (_detailOpen)
            const MaterialPage<void>(
              key: ValueKey('detail'),
              child: DetailPage(),
            ),
        ],
        onDidRemovePage: (page) {
          if (page.key == const ValueKey('detail')) {
            setState(() => _detailOpen = false);
          }
        },
      ),
    ),
  );
}

/// A detail page, pushed inside the branch, that hides the chrome while it
/// is open.
class DetailPage extends StatelessWidget {
  /// Creates the page.
  const DetailPage({super.key});

  @override
  Widget build(BuildContext context) => const LiquidHideChrome(
    child: Scaffold(body: DemoPage(title: 'Detail')),
  );
}
