import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// Asks "Discard changes?" before leaving a tab with unsaved edits, and
/// opens a full-frame detail page that hides the chrome.
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

  @override
  Widget build(BuildContext context) => LiquidShell(
    destinations: kDemoDestinations,
    selectedIndex: _index,
    beforeDestinationChange: _confirmLeave,
    onDestinationSelected: (i) => setState(() {
      if (i != _index) _dirty = false;
      _index = i;
    }),
    body: _branch(),
  );
  // #enddocregion readme

  // #docregion hide-chrome
  static const _rootKey = ValueKey<String>('root');
  static const _detailKey = ValueKey<String>('detail');
  final _branchKey = GlobalKey<NavigatorState>();
  bool _detailOpen = false;

  // The branch has its own navigator, as a router's shell branch does. The
  // detail page is pushed inside it, under the shell, which is where
  // LiquidHideChrome reaches the shell. System back pops it first.
  Widget _branch() => NavigatorPopHandler(
    onPopWithResult: (_) => _branchKey.currentState?.maybePop(),
    child: Navigator(
      key: _branchKey,
      pages: [
        MaterialPage<void>(
          key: _rootKey,
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
            key: _detailKey,
            // Full frame: every piece of chrome hides while it is mounted.
            child: LiquidHideChrome(
              child: Scaffold(body: DemoPage(title: 'Detail')),
            ),
          ),
      ],
      onDidRemovePage: (page) {
        if (page.key == _detailKey) setState(() => _detailOpen = false);
      },
    ),
  );
  // #enddocregion hide-chrome
}
