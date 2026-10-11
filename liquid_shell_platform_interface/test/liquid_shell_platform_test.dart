import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

class _ExtendsFake extends LiquidShellPlatform {
  @override
  Stream<LiquidPlatformSignals> watchSignals() =>
      Stream.value(const LiquidPlatformSignals(powerSave: true));
}

class _ImplementsFake implements LiquidShellPlatform {
  @override
  Stream<LiquidPlatformSignals> watchSignals() => const Stream.empty();

  // Members added after P1 (native chrome, window controls) are not
  // implemented here on purpose: `implements` must still be rejected.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late LiquidShellPlatform original;

  setUp(() => original = LiquidShellPlatform.instance);
  tearDown(() => LiquidShellPlatform.instance = original);

  test('the default instance emits none once, without a channel', () async {
    final events = await LiquidShellPlatform.instance.watchSignals().toList();
    expect(events, [LiquidPlatformSignals.none]);
  });

  test('accepts an implementation that extends the interface', () async {
    LiquidShellPlatform.instance = _ExtendsFake();
    final first = await LiquidShellPlatform.instance.watchSignals().first;
    expect(first.powerSave, isTrue);
  });

  test('the default instance has no native chrome and no channel', () async {
    final platform = LiquidShellPlatform.instance;
    expect(platform.supportsNativeChrome, isFalse);
    expect(
      await platform.attachNativeChrome(),
      LiquidNativeShellState.unavailable,
    );
    await platform.updateNativeChrome(LiquidNativeChromeConfig.dormant);
    await platform.setNativeSidebarVisible(visible: true);
    expect(await platform.readWindowControls(), LiquidWindowControls.zero);
    expect(await platform.nativeEvents.isEmpty, isTrue);
  });

  test('rejects an implementation that only implements the interface', () {
    expect(
      () => LiquidShellPlatform.instance = _ImplementsFake(),
      throwsA(isA<AssertionError>()),
    );
  });

  test('the P3b members default to nothing and touch no channel', () async {
    final platform = _ExtendsFake();
    await platform.setNativeSearchText('x');
    await platform.setNativeSearchActive(active: true);
    await platform.setNativePageScroll(tab: 0, offset: 12);
    // No binding, no channel: reaching here without a MissingPluginException
    // is the assertion.
  });
}
