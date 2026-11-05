import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/pages/page_registry.dart';

// Spec P3b-2 §8.4 (VK-443): a page entry compares its actions by what the
// bars show, never by their callbacks.

PageEntry _entry(List<LiquidPageAction> actions) => PageEntry(
  title: 'Detail',
  largeTitle: null,
  route: null,
  navigator: null,
  sequence: 1,
  onScreen: true,
  current: true,
  active: true,
  actions: actions,
);

LiquidPageAction _action({
  String sfSymbol = 'heart',
  String label = 'Favourite',
  VoidCallback? onPressed,
}) => LiquidPageAction(
  sfSymbol: sfSymbol,
  icon: const Icon(Icons.favorite_border),
  label: label,
  onPressed: onPressed,
);

void main() {
  group('PageEntry.sameAs and actions', () {
    test('no actions by default', () {
      const entry = PageEntry(
        title: 'Detail',
        largeTitle: null,
        route: null,
        navigator: null,
        sequence: 1,
        onScreen: true,
        current: true,
        active: true,
      );
      expect(entry.actions, isEmpty);
      expect(entry.sameAs(_entry(const [])), isTrue);
    });

    test('a new callback alone is the same page', () {
      expect(
        _entry([_action(onPressed: () {})]).sameAs(
          _entry([_action(onPressed: () {})]),
        ),
        isTrue,
      );
    });

    test('a symbol, a label, the enabled state or the count makes another '
        'page', () {
      final base = _entry([_action(onPressed: () {})]);
      for (final (name, other) in [
        ('symbol', _entry([_action(sfSymbol: 'heart.fill', onPressed: () {})])),
        ('label', _entry([_action(label: 'Like', onPressed: () {})])),
        ('enabled', _entry([_action()])),
        ('count', _entry(const [])),
        (
          'order',
          _entry([
            _action(sfSymbol: 'trash', onPressed: () {}),
            _action(onPressed: () {}),
          ]),
        ),
      ]) {
        expect(other.sameAs(base), isFalse, reason: name);
        expect(base.sameAs(other), isFalse, reason: name);
      }
    });
  });
}
