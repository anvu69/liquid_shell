import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/destinations/badge.dart';

void main() {
  group('LiquidDestination', () {
    test('defaults: everywhere, no badge, no selected icon', () {
      const destination = LiquidDestination(
        icon: Icon(Icons.home_outlined),
        label: 'Home',
      );
      expect(destination.placement, LiquidPlacement.everywhere);
      expect(destination.badge, isNull);
      expect(destination.selectedIcon, isNull);
    });

    test('== compares every field', () {
      const icon = Icon(Icons.home_outlined);
      expect(
        const LiquidDestination(icon: icon, label: 'Home'),
        const LiquidDestination(icon: icon, label: 'Home'),
      );
      expect(
        const LiquidDestination(icon: icon, label: 'Home').hashCode,
        const LiquidDestination(icon: icon, label: 'Home').hashCode,
      );
      expect(
        const LiquidDestination(icon: icon, label: 'Home'),
        isNot(
          const LiquidDestination(
            icon: icon,
            label: 'Home',
            placement: LiquidPlacement.sidebarOnly,
          ),
        ),
      );
      expect(
        const LiquidDestination(icon: icon, label: 'Home'),
        isNot(
          const LiquidDestination(
            icon: icon,
            label: 'Home',
            badge: LiquidBadge.dot(),
          ),
        ),
      );
    });
  });

  group('LiquidBadge', () {
    test('count defaults max to 99', () {
      const badge = LiquidBadge.count(3);
      expect(badge, isA<LiquidCountBadge>());
      expect((badge as LiquidCountBadge).max, 99);
      expect(badge.count, 3);
    });

    test('count asserts a non-negative count and a positive max', () {
      expect(() => LiquidCountBadge(-1), throwsAssertionError);
      expect(() => LiquidCountBadge(1, max: 0), throwsAssertionError);
    });

    test('== by value', () {
      expect(const LiquidBadge.count(3), const LiquidBadge.count(3));
      expect(
        const LiquidBadge.count(3).hashCode,
        const LiquidBadge.count(3).hashCode,
      );
      expect(
        const LiquidBadge.count(3),
        isNot(const LiquidBadge.count(3, max: 9)),
      );
      expect(const LiquidBadge.dot(), const LiquidBadge.dot());
      expect(
        const LiquidBadge.dot().hashCode,
        const LiquidBadge.dot().hashCode,
      );
    });

    test('text shows max+ above max', () {
      expect(badgeText(const LiquidCountBadge(3)), '3');
      expect(badgeText(const LiquidCountBadge(99)), '99');
      expect(badgeText(const LiquidCountBadge(120)), '99+');
      expect(badgeText(const LiquidCountBadge(10, max: 9)), '9+');
    });

    test('visibility: count 0 is hidden, dot is shown', () {
      expect(badgeVisible(null), isFalse);
      expect(badgeVisible(const LiquidCountBadge(0)), isFalse);
      expect(badgeVisible(const LiquidCountBadge(1)), isTrue);
      expect(badgeVisible(const LiquidDotBadge()), isTrue);
    });

    test('semantics label appends the badge', () {
      const strings = LiquidShellStrings();
      expect(badgeSemanticsLabel('Inbox', null, strings), 'Inbox');
      expect(
        badgeSemanticsLabel('Inbox', const LiquidCountBadge(0), strings),
        'Inbox',
      );
      expect(
        badgeSemanticsLabel('Inbox', const LiquidCountBadge(120), strings),
        'Inbox, 120 new',
      );
      expect(
        badgeSemanticsLabel('Inbox', const LiquidDotBadge(), strings),
        'Inbox, New',
      );
    });
  });

  group('LiquidTabAction', () {
    test('== compares every field', () {
      void onPressed() {}
      const icon = Icon(Icons.search);
      expect(
        LiquidTabAction(icon: icon, onPressed: onPressed, semanticLabel: 'S'),
        LiquidTabAction(icon: icon, onPressed: onPressed, semanticLabel: 'S'),
      );
      expect(
        LiquidTabAction(
          icon: icon,
          onPressed: onPressed,
          semanticLabel: 'S',
        ).hashCode,
        LiquidTabAction(
          icon: icon,
          onPressed: onPressed,
          semanticLabel: 'S',
        ).hashCode,
      );
      expect(
        LiquidTabAction(icon: icon, onPressed: onPressed, semanticLabel: 'S'),
        isNot(
          LiquidTabAction(icon: icon, onPressed: onPressed, semanticLabel: 'T'),
        ),
      );
    });
  });

  group('LiquidShellStrings', () {
    test('English defaults', () {
      const strings = LiquidShellStrings();
      expect(strings.showSidebar, 'Show sidebar');
      expect(strings.hideSidebar, 'Hide sidebar');
      expect(strings.tabBarExpanded, 'Navigation bar opened');
      expect(strings.expandTabBarHint, 'Tap to open the navigation bar');
      expect(strings.badgeDot, 'New');
      expect(strings.badgeCount(3), '3 new');
      expect(LiquidShellStrings.defaultBadgeCount(7), '7 new');
    });

    test('== compares every field', () {
      expect(const LiquidShellStrings(), const LiquidShellStrings());
      expect(
        const LiquidShellStrings().hashCode,
        const LiquidShellStrings().hashCode,
      );
      expect(
        const LiquidShellStrings(),
        isNot(const LiquidShellStrings(badgeDot: 'Mới')),
      );
    });
  });
}
