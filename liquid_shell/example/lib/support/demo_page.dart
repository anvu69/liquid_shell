import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/wallpaper.dart';

/// A long page over the [Wallpaper]. Its list is padded with
/// [LiquidShellScope.contentPaddingOf], so content scrolls under the glass
/// chrome but starts and ends clear of it.
class DemoPage extends StatelessWidget {
  /// Creates a page titled [title].
  const DemoPage({required this.title, this.children = const [], super.key});

  /// Page title, shown as the first row.
  final String title;

  /// Rows shown under the title, before the filler rows.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The nearest navigator with a page to pop: a branch navigator while it
    // holds a pushed page, otherwise the app's (back to the case list).
    final local = Navigator.of(context);
    final navigator = local.canPop()
        ? local
        : Navigator.of(context, rootNavigator: true);
    // Transparent Material: list tiles, switches and segmented buttons need
    // one, and the wallpaper must stay visible.
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          const Positioned.fill(child: Wallpaper()),
          ListView(
            padding: LiquidShellScope.contentPaddingOf(
              context,
            ).add(const EdgeInsets.symmetric(horizontal: 16)),
            children: [
              Row(
                children: [
                  if (navigator.canPop())
                    BackButton(onPressed: navigator.maybePop),
                  Expanded(
                    child: Text(title, style: theme.textTheme.headlineMedium),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...children,
              for (var i = 1; i <= 24; i++)
                Card(
                  color: theme.colorScheme.surface.withValues(alpha: 0.8),
                  child: ListTile(
                    title: Text('$title item $i'),
                    subtitle: const Text('Scroll to see the glass chrome blur'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The three destinations most cases share.
const kDemoDestinations = [
  LiquidDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home),
    label: 'Home',
  ),
  LiquidDestination(
    icon: Icon(Icons.explore_outlined),
    selectedIcon: Icon(Icons.explore),
    label: 'Explore',
  ),
  LiquidDestination(
    icon: Icon(Icons.settings_outlined),
    selectedIcon: Icon(Icons.settings),
    label: 'Settings',
  ),
];
