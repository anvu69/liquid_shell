import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/destinations/badge.dart';

String _otherBadgeCount(int count) => '$count unread';

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

    test('equal fields are equal with equal hash codes', () {
      const icon = Icon(Icons.home_outlined);
      expect(
        const LiquidDestination(icon: icon, label: 'Home'),
        const LiquidDestination(icon: icon, label: 'Home'),
      );
      expect(
        const LiquidDestination(icon: icon, label: 'Home').hashCode,
        const LiquidDestination(icon: icon, label: 'Home').hashCode,
      );
    });

    // Shared instances: under `flutter test` widget-creation tracking makes
    // two `const Icon(...)` at different source lines non-identical, and
    // widgets compare by identity.
    const home = Icon(Icons.home_outlined);
    const homeFilled = Icon(Icons.home);
    const inbox = Icon(Icons.inbox_outlined);
    LiquidDestination destination({
      Widget icon = home,
      Widget? selectedIcon = homeFilled,
      String label = 'Home',
      LiquidBadge? badge = const LiquidBadge.count(3),
      LiquidPlacement placement = LiquidPlacement.everywhere,
    }) => LiquidDestination(
      icon: icon,
      selectedIcon: selectedIcon,
      label: label,
      badge: badge,
      placement: placement,
    );

    test('the shared builder is equal to itself', () {
      expect(destination(), destination());
      expect(destination().hashCode, destination().hashCode);
    });

    for (final (field, other) in [
      ('icon', () => destination(icon: inbox)),
      ('selectedIcon', () => destination(selectedIcon: inbox)),
      ('label', () => destination(label: 'Start')),
      ('badge', () => destination(badge: const LiquidBadge.count(4))),
      (
        'placement',
        () => destination(placement: LiquidPlacement.sidebarOnly),
      ),
    ]) {
      test('== sees a different $field alone', () {
        expect(destination(), isNot(other()));
      });
    }
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
      expect(const LiquidBadge.count(3), isNot(const LiquidBadge.count(4)));
      expect(const LiquidBadge.count(1), isNot(const LiquidBadge.dot()));
      expect(const LiquidBadge.dot(), isNot(const LiquidBadge.count(1)));
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

    test('semantics label speaks the overridden badge strings', () {
      final strings = LiquidShellStrings(
        badgeDot: 'Unread',
        badgeCount: (count) => count == 1 ? '1 message' : '$count messages',
      );
      expect(
        badgeSemanticsLabel('Inbox', const LiquidCountBadge(1), strings),
        'Inbox, 1 message',
      );
      expect(
        badgeSemanticsLabel('Inbox', const LiquidCountBadge(120), strings),
        'Inbox, 120 messages',
      );
      expect(
        badgeSemanticsLabel('Inbox', const LiquidDotBadge(), strings),
        'Inbox, Unread',
      );
    });
  });

  group('LiquidTabAction', () {
    void search() {}
    void dictate() {}
    LiquidTabAction action({
      Widget icon = const Icon(Icons.search),
      VoidCallback? onPressed,
      String semanticLabel = 'Search',
    }) => LiquidTabAction(
      icon: icon,
      onPressed: onPressed ?? search,
      semanticLabel: semanticLabel,
    );

    test('equal fields are equal with equal hash codes', () {
      expect(action(), action());
      expect(action().hashCode, action().hashCode);
    });

    for (final (field, other) in [
      ('icon', () => action(icon: const Icon(Icons.mic))),
      ('onPressed', () => action(onPressed: dictate)),
      ('semanticLabel', () => action(semanticLabel: 'Find')),
    ]) {
      test('== sees a different $field alone', () {
        expect(action(), isNot(other()));
      });
    }
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

    test('equal fields are equal with equal hash codes', () {
      expect(const LiquidShellStrings(), const LiquidShellStrings());
      expect(
        const LiquidShellStrings().hashCode,
        const LiquidShellStrings().hashCode,
      );
    });

    for (final (field, other) in [
      ('showSidebar', const LiquidShellStrings(showSidebar: 'x')),
      ('hideSidebar', const LiquidShellStrings(hideSidebar: 'x')),
      ('tabBarExpanded', const LiquidShellStrings(tabBarExpanded: 'x')),
      ('expandTabBarHint', const LiquidShellStrings(expandTabBarHint: 'x')),
      ('badgeDot', const LiquidShellStrings(badgeDot: 'x')),
      ('badgeCount', const LiquidShellStrings(badgeCount: _otherBadgeCount)),
    ]) {
      test('== sees a different $field alone', () {
        expect(const LiquidShellStrings(), isNot(other));
      });
    }
  });
}
