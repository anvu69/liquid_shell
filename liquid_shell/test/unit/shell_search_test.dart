import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/search/shell_search.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

void main() {
  ShellSearch bridge() {
    final search = ShellSearch(claim: () => null, onChange: () {});
    addTearDown(search.dispose);
    return search;
  }

  group('ShellSearch (spec P3b §8.2, §14)', () {
    test('a search destination without LiquidShell.search: an internal '
        'controller keeps the field working', () {
      final search = bridge()..configure(null, hasSearchDestination: true);
      final internal = search.controller;
      expect(internal, isNotNull);
      search
        ..selected = true
        ..onNativeEvent(
          const LiquidNativeSearchTextChanged('hà', composing: false),
        );
      expect(internal!.text, 'hà');
      search.configure(null, hasSearchDestination: true);
      expect(search.controller, same(internal), reason: 'kept across builds');
    });

    test('the app controller replaces the internal one', () {
      final app = LiquidSearchController();
      addTearDown(app.dispose);
      final search = bridge()..configure(null, hasSearchDestination: true);
      final internal = search.controller!;
      search.configure(
        LiquidSearch(controller: app),
        hasSearchDestination: true,
      );
      expect(search.controller, same(app));
      search
        ..selected = true
        ..onNativeEvent(
          const LiquidNativeSearchTextChanged('x', composing: false),
        );
      expect(app.text, 'x');
      expect(internal.text, '');
    });

    test('no search destination: no controller, native events dropped', () {
      final search = bridge()..configure(null, hasSearchDestination: false);
      expect(search.controller, isNull);
      search
        ..selected = true
        ..onNativeEvent(
          const LiquidNativeSearchTextChanged('x', composing: false),
        )
        ..onNativeEvent(const LiquidNativeSearchSubmitted('x'));
      expect(search.controller, isNull);
    });

    test('detach lets the controller go; configure takes it again', () {
      final app = LiquidSearchController();
      addTearDown(app.dispose);
      final config = LiquidSearch(controller: app);
      final search = bridge()
        ..configure(config, hasSearchDestination: true)
        ..detach();
      expect(search.controller, isNull);
      // Another shell may now attach without the one-shell assert.
      final other = bridge()..configure(config, hasSearchDestination: true);
      expect(other.controller, same(app));
      other.detach();
      search.configure(config, hasSearchDestination: true);
      expect(search.controller, same(app));
    });
  });
}
