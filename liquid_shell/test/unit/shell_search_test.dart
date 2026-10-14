import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/native/native_host.dart';
import 'package:liquid_shell/src/search/shell_search.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

import '../helpers/fake_native_platform.dart';

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

  // VK-550 §10.2: the native scope bar's one-way bridge. Native reports
  // only the user's changes; Dart sends only the app's writes and the
  // replay on entering the search tab natively. Nothing echoes.
  group('native scopes (spec VK-550 §10.2)', () {
    late FakeNativePlatform fake;
    late LiquidSearchController controller;

    /// A bridge on [controller] over an owned native claim, the search tab
    /// shown natively (entered) unless [selected] is false.
    ShellSearch nativeBridge({bool selected = true}) {
      fake = installFakeNative();
      final claim = NativeChromeHost.instance.claim((_) {});
      addTearDown(claim.release);
      final search = ShellSearch(claim: () => claim, onChange: () {});
      addTearDown(search.dispose);
      search
        ..configure(
          LiquidSearch(
            controller: controller,
            scopes: const ['All', 'Songs', 'Places'],
          ),
          hasSearchDestination: true,
        )
        ..native = true
        ..selected = selected
        ..afterConfigSent();
      fake
        ..searchScopes.clear()
        ..searchTexts.clear()
        ..searchActives.clear();
      return search;
    }

    setUp(() => controller = LiquidSearchController());
    tearDown(() => controller.dispose());

    test('a user change reaches the controller once, never sent back', () {
      final search = nativeBridge();
      var heard = 0;
      controller.addListener(() => heard++);
      search.onNativeEvent(const LiquidNativeSearchScopeChanged(1));
      expect(controller.scopeIndex, 1);
      expect(heard, 1, reason: "the app's listener hears it once");
      search.onNativeEvent(const LiquidNativeSearchScopeChanged(1));
      expect(heard, 1, reason: 'the same index again changes nothing');
      search.afterConfigSent();
      expect(
        fake.searchScopes,
        isEmpty,
        reason:
            'a native change never '
            'causes setNativeSearchScope',
      );
    });

    test('a change while the search tab is not selected is ignored', () {
      final search = nativeBridge(selected: false)
        ..onNativeEvent(const LiquidNativeSearchScopeChanged(2));
      expect(controller.scopeIndex, 0);
      expect(search.controller, same(controller));
    });

    test('a negative index from the platform is ignored', () {
      nativeBridge().onNativeEvent(const LiquidNativeSearchScopeChanged(-1));
      expect(controller.scopeIndex, 0);
    });

    test("the app's write goes to native once, only while native and "
        'selected', () {
      final search = nativeBridge();
      controller.scopeIndex = 2;
      expect(fake.searchScopes, [2]);
      controller.scopeIndex = 2;
      expect(fake.searchScopes, [2], reason: 'the same index sends nothing');
      search.selected = false;
      controller.scopeIndex = 1;
      search
        ..native = false
        ..selected = true;
      controller.scopeIndex = 0;
      expect(fake.searchScopes, [2], reason: 'Flutter mode, or another tab');
      expect(fake.searchTexts, isEmpty);
    });

    test('entering the search tab natively sends the scope with the text', () {
      final search = nativeBridge(selected: false);
      controller
        ..text = 'hồ'
        ..scopeIndex = 2;
      expect(fake.searchScopes, isEmpty, reason: 'held for the entry');
      fake.searchTexts.clear();
      search
        ..selected = true
        ..afterConfigSent();
      expect(fake.searchTexts, ['hồ']);
      expect(fake.searchScopes, [2]);
      search.afterConfigSent();
      expect(fake.searchScopes, [2], reason: 'once per entry');
    });

    test('a native state report replays the scope, the user text kept', () {
      final search = nativeBridge()
        ..onNativeEvent(
          const LiquidNativeSearchTextChanged('hồ', composing: false),
        )
        ..onNativeEvent(const LiquidNativeSearchScopeChanged(1))
        // A changed state (a reconnected scene whose first report differs,
        // or an iPad crossing the size class): the user's text is never
        // sent back, but the scope is Dart's to restore.
        ..replay(reconnect: false)
        ..afterConfigSent();
      expect(fake.searchTexts, isEmpty);
      expect(fake.searchScopes, [1]);
      search.afterConfigSent();
      expect(fake.searchScopes, [1]);
    });

    test("a new controller's scope goes to native", () {
      final search = nativeBridge();
      final next = LiquidSearchController(scopeIndex: 2);
      addTearDown(next.dispose);
      search.configure(
        LiquidSearch(controller: next, scopes: const ['All', 'Songs']),
        hasSearchDestination: true,
      );
      expect(fake.searchScopes, [2]);
    });
  });
}
