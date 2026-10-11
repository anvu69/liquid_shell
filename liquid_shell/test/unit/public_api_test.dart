// The barrel decides the public API of a published package. Internal glass
// helpers (`resolveGlassFor`, `liquidGlassChanges`, `LiquidLens`) must stay
// out of it (spec VK-503, global constraint "Public API").
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The export directives of `lib/liquid_shell.dart`, one string each, with
/// whitespace collapsed.
List<String> _exports() => File('lib/liquid_shell.dart')
    .readAsStringSync()
    .split(';')
    .map((d) => d.replaceAll(RegExp(r'\s+'), ' ').trim())
    .where((d) => d.contains('export '))
    .map((d) => d.substring(d.indexOf('export ')))
    .toList();

void main() {
  test('liquid_glass.dart exports only LiquidGlass', () {
    expect(
      _exports().where((e) => e.contains("'src/glass/liquid_glass.dart'")),
      ["export 'src/glass/liquid_glass.dart' show LiquidGlass"],
    );
  });

  test('liquid_lens.dart is not exported', () {
    expect(
      _exports().where((e) => e.contains('liquid_lens.dart')),
      isEmpty,
    );
  });
}
