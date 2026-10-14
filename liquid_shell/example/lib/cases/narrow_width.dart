import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// Five tabs plus a trailing action in a 320pt-wide shell, as in iPad Slide
/// Over or ⅓ Split View. Below [kLiquidNarrowWidth] the shell trims the row
/// margin from 21 to 8, so every tab keeps a tap area at least 44pt wide at
/// text scale 1 (Q17), and the labels fit untruncated (Q18).
/// The shell decides from its own width, not the screen's.
class NarrowWidthCase extends StatefulWidget {
  /// Creates the case.
  const NarrowWidthCase({super.key});

  @override
  State<NarrowWidthCase> createState() => _NarrowWidthCaseState();
}

class _NarrowWidthCaseState extends State<NarrowWidthCase> {
  // #docregion readme
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const destinations = [
      LiquidDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      LiquidDestination(
        icon: Icon(Icons.map_outlined),
        selectedIcon: Icon(Icons.map),
        label: 'Explore',
      ),
      LiquidDestination(
        icon: Icon(Icons.inbox_outlined),
        selectedIcon: Icon(Icons.inbox),
        label: 'Inbox',
      ),
      LiquidDestination(
        icon: Icon(Icons.bookmark_outline),
        selectedIcon: Icon(Icons.bookmark),
        label: 'Saved',
      ),
      LiquidDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: 'Settings',
      ),
    ];
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Center(
        // The 320pt shell stands for a narrow window, which clips what it
        // draws.
        child: ClipRect(
          child: SizedBox(
            width: 320, // below kLiquidNarrowWidth (340)
            child: LiquidShell(
              destinations: destinations,
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              // Native chrome spans the window, not this 320pt shell.
              nativeChrome: LiquidNativeChrome.off,
              tabBarTrailing: LiquidTabAction(
                icon: const Icon(Icons.edit_outlined),
                semanticLabel: 'Compose',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LiquidNoChrome(
                      child: Scaffold(
                        body: DemoPage(
                          title: 'New message',
                          children: [
                            TextField(
                              decoration: InputDecoration(hintText: 'Message'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              body: DemoPage(
                title: destinations[_index].label,
                children: const [
                  Text(
                    'This shell is 320pt wide, below kLiquidNarrowWidth '
                    '(340): row margin 8, tap areas of at least 44pt.',
                  ),
                  SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // #enddocregion readme
}
