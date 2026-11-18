import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/src/native/native_host.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

import '../helpers/fake_native_platform.dart';

// The hand-over epoch (spec 2026-11-18 applied-epoch §2.1): the host stamps
// every config it sends, and bumps the epoch only when a hand-over starts.

const _engaged = LiquidNativeChromeConfig(
  engaged: true,
  tabs: [LiquidNativeTab(title: 'Home', sfSymbol: 'house')],
);
const _other = LiquidNativeChromeConfig(
  engaged: true,
  tabs: [LiquidNativeTab(title: 'Home', sfSymbol: 'house')],
  dark: true,
);
const LiquidNativeChromeConfig _off = LiquidNativeChromeConfig.dormant;

void main() {
  late FakeNativePlatform fake;
  late NativeChromeHost host;

  /// Lets the attach answer and the platform calls run.
  Future<void> flush() => Future<void>.delayed(Duration.zero);

  setUp(() {
    fake = installFakeNative();
    NativeChromeHost.debugReset();
    host = NativeChromeHost.instance;
  });

  tearDown(NativeChromeHost.debugReset);

  Future<NativeChromeClaim> claimed([LiquidNativeChromeConfig? config]) async {
    final claim = host.claim((_) {});
    await flush();
    unawaited(claim.update(config ?? _engaged));
    await flush();
    return claim;
  }

  test('every config is stamped; the first epoch is not 0', () async {
    final claim = await claimed();
    expect(fake.last.epoch, greaterThan(0));
    expect(claim.epoch, fake.last.epoch);
  });

  test('a change within the same hand-over keeps the epoch', () async {
    final claim = await claimed();
    final epoch = fake.last.epoch;
    unawaited(claim.update(_other));
    await flush();
    expect(fake.last.dark, isTrue);
    expect(fake.last.epoch, epoch);
  });

  test('a new claim bumps the epoch', () async {
    await claimed();
    final first = fake.last.epoch;
    final second = host.claim((_) {});
    unawaited(second.update(_engaged));
    await flush();
    expect(fake.last.epoch, greaterThan(first));
    expect(second.epoch, fake.last.epoch);
  });

  test("the owner's release bumps the epoch and resends the previous "
      "claim's config", () async {
    final first = await claimed();
    final second = host.claim((_) {});
    unawaited(second.update(_other));
    await flush();
    final secondEpoch = fake.last.epoch;
    second.release();
    await flush();
    expect(fake.last.dark, isFalse, reason: "the first claim's config");
    expect(fake.last.epoch, greaterThan(secondEpoch));
    expect(first.epoch, fake.last.epoch);
    expect(second.releaseEpoch, fake.last.epoch);
  });

  test('the last release sends the dormant config with a new epoch', () async {
    final claim = await claimed();
    final epoch = fake.last.epoch;
    claim.release();
    await flush();
    expect(fake.last.engaged, isFalse);
    expect(fake.last.tabs, isEmpty);
    expect(fake.last.epoch, greaterThan(epoch));
    expect(claim.releaseEpoch, fake.last.epoch);
  });

  test('an engaged flip bumps the epoch, both ways', () async {
    final claim = await claimed();
    final engaged = fake.last.epoch;
    unawaited(claim.update(_off));
    await flush();
    final off = fake.last.epoch;
    expect(off, greaterThan(engaged));
    expect(claim.releaseEpoch, off, reason: 'its own disengaged config');
    unawaited(claim.update(_engaged));
    await flush();
    expect(fake.last.epoch, greaterThan(off));
    expect(claim.releaseEpoch, isNull, reason: 'engaged again');
  });

  test("a release epoch is unknown until the disengaged config's send", () {
    final claim = host.claim((_) {});
    expect(claim.epoch, isNull);
    expect(claim.releaseEpoch, isNull);
  });

  test('the forced resend after a state keeps the epoch', () async {
    await claimed();
    final sent = fake.configs.length;
    final epoch = fake.last.epoch;
    fake.pushState(
      const LiquidNativeShellState(installed: true, compact: true),
    );
    await flush();
    expect(fake.configs.length, sent + 1, reason: 'resent whole');
    expect(fake.last.epoch, epoch);
  });

  test('deduplication compares the stamped config', () async {
    final claim = await claimed();
    final sent = fake.configs.length;
    unawaited(claim.update(_engaged));
    await flush();
    expect(fake.configs.length, sent, reason: 'nothing changed');
  });

  test("attach seeds the counter above native's applied epoch", () async {
    fake.state = const LiquidNativeShellState(
      installed: true,
      engagedApplied: true,
      appliedEpoch: 41,
    );
    await claimed();
    expect(fake.last.epoch, greaterThan(41));
  });

  test(
    "appliedConfig is the last config sent with the state's epoch",
    () async {
      final claim = await claimed();
      expect(host.appliedConfig, isNull, reason: 'epoch 0: not echoed');
      final epoch = fake.last.epoch;
      unawaited(claim.update(_other.copyWithHidden()));
      await flush();
      fake.pushState(
        LiquidNativeShellState(
          installed: true,
          engagedApplied: true,
          appliedEpoch: epoch,
        ),
      );
      await flush();
      expect(host.appliedConfig?.hidden, isTrue);
      expect(host.appliedConfig?.epoch, epoch);
    },
  );

  group('the fake native model', () {
    test('echoes the epoch and engaged of each config it applies', () async {
      fake.echoEpochs = true;
      await claimed();
      expect(host.state.value?.engagedApplied, isTrue);
      expect(host.state.value?.appliedEpoch, fake.last.epoch);
    });

    test('held: applies only on applyLast', () async {
      fake
        ..echoEpochs = true
        ..autoApply = false;
      await claimed();
      expect(host.state.value?.appliedEpoch, 0);
      fake.applyLast();
      await flush();
      expect(host.state.value?.appliedEpoch, fake.last.epoch);
    });
  });
}

extension on LiquidNativeChromeConfig {
  LiquidNativeChromeConfig copyWithHidden() => LiquidNativeChromeConfig(
    engaged: engaged,
    tabs: tabs,
    dark: dark,
    hidden: true,
  );
}
