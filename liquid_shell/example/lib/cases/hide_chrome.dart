import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// A full-frame detail page pushed inside a branch's own `Navigator`, which
/// hides every piece of chrome while it is mounted.
class HideChromeCase extends StatefulWidget {
  /// Creates the case.
  const HideChromeCase({super.key});

  @override
  State<HideChromeCase> createState() => _HideChromeCaseState();
}

class _HideChromeCaseState extends State<HideChromeCase> {
  // #docregion readme
  static const _rootKey = ValueKey<String>('root');
  static const _detailKey = ValueKey<String>('detail');
  final _branchKey = GlobalKey<NavigatorState>();
  int _index = 0;
  bool _detailOpen = false;

  @override
  Widget build(BuildContext context) => LiquidShell(
    destinations: kDemoDestinations,
    selectedIndex: _index,
    onDestinationSelected: (i) => setState(() {
      _index = i;
      _detailOpen = false;
    }),
    body: _branch(),
  );

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
  // #enddocregion readme
}
