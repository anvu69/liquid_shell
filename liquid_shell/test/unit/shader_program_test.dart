import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/glass/shader_program.dart';

void main() {
  tearDown(LiquidShaderProgram.instance.debugReset);

  test('tries the package key first, then the root-package key', () {
    expect(LiquidShaderProgram.assetKeys, [
      'packages/liquid_shell/shaders/liquid_glass.frag',
      'shaders/liquid_glass.frag',
    ]);
  });

  testWidgets('precache loads the program once', (tester) async {
    expect(LiquidShaderProgram.instance.value, isNull);
    await tester.runAsync(LiquidGlass.precache);
    final first = LiquidShaderProgram.instance.value;
    expect(first, isNotNull);
    await tester.runAsync(LiquidGlass.precache);
    expect(LiquidShaderProgram.instance.value, same(first));
  });

  testWidgets('a missing asset leaves it null and logs once', (tester) async {
    final logs = <String>[];
    LiquidShaderProgram.debugAssetKeysOverride = ['shaders/nope.frag'];
    addTearDown(() => LiquidShaderProgram.debugAssetKeysOverride = null);
    // Restored before the test ends: testWidgets checks foundation hooks.
    final saved = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    try {
      await tester.runAsync(LiquidShaderProgram.instance.load);
      await tester.runAsync(LiquidShaderProgram.instance.load);
    } finally {
      debugPrint = saved;
    }
    expect(LiquidShaderProgram.instance.value, isNull);
    expect(
      logs.where((l) => l.contains('liquid glass shader failed to load')),
      hasLength(1),
    );
  });

  testWidgets('notifies listeners when loaded', (tester) async {
    var notified = 0;
    void listener() => notified++;
    LiquidShaderProgram.instance.addListener(listener);
    addTearDown(() => LiquidShaderProgram.instance.removeListener(listener));
    await tester.runAsync(LiquidShaderProgram.instance.load);
    expect(notified, 1);
  });
}
