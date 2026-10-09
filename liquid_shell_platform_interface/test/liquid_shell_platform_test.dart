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

  test('rejects an implementation that only implements the interface', () {
    expect(
      () => LiquidShellPlatform.instance = _ImplementsFake(),
      throwsA(isA<AssertionError>()),
    );
  });
}
