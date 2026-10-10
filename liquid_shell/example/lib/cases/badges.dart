import 'package:flutter/material.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell_example/support/demo_page.dart';

/// Count, overflowing count and dot badges.
class BadgesCase extends StatefulWidget {
  /// Creates the case.
  const BadgesCase({super.key});

  @override
  State<BadgesCase> createState() => _BadgesCaseState();
}

class _BadgesCaseState extends State<BadgesCase> {
  // #docregion readme
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    const destinations = [
      LiquidDestination(
        icon: Icon(Icons.inbox_outlined),
        label: 'Inbox',
        badge: LiquidBadge.count(3),
        sfSymbol: 'tray',
      ),
      LiquidDestination(
        icon: Icon(Icons.forum_outlined),
        label: 'Chats',
        badge: LiquidBadge.count(120), // shows "99+"
        sfSymbol: 'bubble.left.and.bubble.right',
      ),
      LiquidDestination(
        icon: Icon(Icons.notifications_outlined),
        label: 'Alerts',
        badge: LiquidBadge.dot(),
        sfSymbol: 'bell',
      ),
    ];
    return LiquidShell(
      destinations: destinations,
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() => _index = i),
      body: DemoPage(title: destinations[_index].label),
    );
  }

  // #enddocregion readme
}
