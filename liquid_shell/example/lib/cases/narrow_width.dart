import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/cases/trailing_action.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// The width of the shell in this case: below [kLiquidNarrowWidth].
const double kNarrowShellWidth = 320;

/// Five tab bar destinations, the most a shell takes.
const kNarrowDestinations = [
  LiquidDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
  LiquidDestination(icon: Icon(Icons.explore_outlined), label: 'Explore'),
  LiquidDestination(icon: Icon(Icons.inbox_outlined), label: 'Inbox'),
  LiquidDestination(icon: Icon(Icons.bookmark_outline), label: 'Saved'),
  LiquidDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
];

/// Five tabs plus a trailing action in a 320pt-wide shell, as in iPad Slide
/// Over or ⅓ Split View. Below [kLiquidNarrowWidth] the shell trims the row
/// margin to 8 and the pill padding to 4, so every cell stays at least
/// 44pt wide at text scale 1 (Q17), and the labels fit untruncated (Q18).
/// The shell decides from its own width, not the screen's.
class NarrowWidthCase extends StatefulWidget {
  /// Creates the case.
  const NarrowWidthCase({super.key});

  @override
  State<NarrowWidthCase> createState() => _NarrowWidthCaseState();
}

class _NarrowWidthCaseState extends State<NarrowWidthCase> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerLowest,
    child: Center(
      // The 320pt shell stands for a narrow window, which clips what it
      // draws: the wallpaper discs stay inside it.
      child: ClipRect(
        // #docregion readme
        child: SizedBox(
          width: kNarrowShellWidth,
          child: LiquidShell(
            destinations: kNarrowDestinations,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            tabBarTrailing: LiquidTabAction(
              icon: const Icon(Icons.search),
              semanticLabel: 'Search',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SearchPage()),
              ),
            ),
            body: DemoPage(
              title: kNarrowDestinations[_index].label,
              children: const [
                Text(
                  'This shell is 320pt wide, below kLiquidNarrowWidth (340): '
                  'row margin 8, pill padding 4, 45.2pt cells.',
                ),
                SizedBox(height: 12),
              ],
            ),
          ),
        ),
        // #enddocregion readme
      ),
    ),
  );
}
