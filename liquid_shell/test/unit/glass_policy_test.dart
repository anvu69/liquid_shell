import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/glass/frosted_renderer.dart';
import 'package:liquid_shell/src/glass/liquid_renderer.dart';
import 'package:liquid_shell/src/glass/policy.dart';
import 'package:liquid_shell/src/glass/solid_renderer.dart';

class _FakeRenderer extends LiquidGlassRenderer {
  const _FakeRenderer(this.tier, {this.supported = true, this.throws = false});

  @override
  final LiquidGlassTier tier;
  final bool supported;
  final bool throws;

  @override
  bool isSupported(BuildContext context) {
    if (throws) throw StateError('probe failed');
    return supported;
  }

  @override
  Widget buildBackground(BuildContext context, LiquidGlassSpec spec) =>
      const SizedBox.expand();
}

/// Overrides [resolve] to answer [tier], optionally after running the
/// default algorithm.
class _TierPolicy extends LiquidGlassPolicy {
  const _TierPolicy(this.tier, {this.callSuper = false, super.renderers});

  final LiquidGlassTier tier;
  final bool callSuper;

  @override
  LiquidGlassTier resolve(BuildContext context, LiquidGlassSignals signals) {
    if (callSuper) super.resolve(context, signals);
    return tier;
  }
}

Future<BuildContext> _context(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    Builder(
      builder: (c) {
        context = c;
        return const SizedBox();
      },
    ),
  );
  return context;
}

/// Runs [body] with `debugPrint` captured. Restores it before the test
/// ends, because testWidgets checks that foundation hooks are unset.
Future<List<String>> _captureLogs(Future<void> Function() body) async {
  final logs = <String>[];
  final original = debugPrint;
  debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
  try {
    await body();
  } finally {
    debugPrint = original;
  }
  return logs;
}

void main() {
  group('LiquidGlassSignals (spec 2026-10-10 §6.1)', () {
    test('every signal off prefers neither solid nor frosted', () {
      expect(const LiquidGlassSignals().prefersSolid, isFalse);
      expect(const LiquidGlassSignals().prefersFrosted, isFalse);
    });

    test('solid: reduce transparency, high contrast, blur disabled', () {
      for (final signals in const [
        LiquidGlassSignals(reduceTransparency: true),
        LiquidGlassSignals(highContrast: true),
        LiquidGlassSignals(blurDisabled: true),
      ]) {
        expect(signals.prefersSolid, isTrue);
      }
    });

    test('frosted: power save, low end, GLES only, slow frames', () {
      for (final signals in const [
        LiquidGlassSignals(powerSave: true),
        LiquidGlassSignals(lowEnd: true),
        LiquidGlassSignals(glesOnly: true),
        LiquidGlassSignals(slowFrames: true),
      ]) {
        expect(signals.prefersFrosted, isTrue);
        expect(signals.prefersSolid, isFalse);
      }
    });

    test('battery saver disables blur too: frosted, not solid (Q9)', () {
      const signals = LiquidGlassSignals(powerSave: true, blurDisabled: true);
      expect(signals.prefersSolid, isFalse);
      expect(signals.prefersFrosted, isTrue);
    });

    test('== and hashCode compare every field', () {
      const each = [
        LiquidGlassSignals(reduceTransparency: true),
        LiquidGlassSignals(highContrast: true),
        LiquidGlassSignals(powerSave: true),
        LiquidGlassSignals(blurDisabled: true),
        LiquidGlassSignals(lowEnd: true),
        LiquidGlassSignals(glesOnly: true),
        LiquidGlassSignals(slowFrames: true),
      ];
      for (var a = 0; a < each.length; a++) {
        for (var b = 0; b < each.length; b++) {
          expect(each[a] == each[b], a == b, reason: '$a vs $b');
        }
      }
      expect(
        const LiquidGlassSignals(lowEnd: true).hashCode,
        const LiquidGlassSignals(lowEnd: true).hashCode,
      );
    });
  });

  group('LiquidGlassPolicy.resolve', () {
    testWidgets('no signals → frosted', (tester) async {
      final context = await _context(tester);
      expect(
        const LiquidGlassPolicy().resolve(context, const LiquidGlassSignals()),
        LiquidGlassTier.frosted,
      );
    });

    testWidgets('each signal → its tier (spec §6.3)', (tester) async {
      final context = await _context(tester);
      const policy = LiquidGlassPolicy(
        renderers: [_FakeRenderer(LiquidGlassTier.liquid)],
      );
      for (final (signals, tier) in const [
        (LiquidGlassSignals(), LiquidGlassTier.liquid),
        (LiquidGlassSignals(reduceTransparency: true), LiquidGlassTier.solid),
        (LiquidGlassSignals(highContrast: true), LiquidGlassTier.solid),
        (LiquidGlassSignals(blurDisabled: true), LiquidGlassTier.solid),
        (LiquidGlassSignals(powerSave: true), LiquidGlassTier.frosted),
        (
          LiquidGlassSignals(powerSave: true, blurDisabled: true),
          LiquidGlassTier.frosted,
        ),
        (LiquidGlassSignals(lowEnd: true), LiquidGlassTier.frosted),
        (LiquidGlassSignals(glesOnly: true), LiquidGlassTier.frosted),
        (LiquidGlassSignals(slowFrames: true), LiquidGlassTier.frosted),
      ]) {
        expect(policy.resolve(context, signals), tier);
      }
    });

    testWidgets('a forced liquid tier wins over the frosted signals', (
      tester,
    ) async {
      final context = await _context(tester);
      const policy = LiquidGlassPolicy(
        forcedTier: LiquidGlassTier.liquid,
        renderers: [_FakeRenderer(LiquidGlassTier.liquid)],
      );
      expect(
        policy.resolve(
          context,
          const LiquidGlassSignals(
            powerSave: true,
            lowEnd: true,
            glesOnly: true,
            slowFrames: true,
          ),
        ),
        LiquidGlassTier.liquid,
      );
    });

    testWidgets('a supported liquid renderer → liquid', (tester) async {
      final context = await _context(tester);
      const policy = LiquidGlassPolicy(
        renderers: [_FakeRenderer(LiquidGlassTier.liquid)],
      );
      expect(
        policy.resolve(context, const LiquidGlassSignals()),
        LiquidGlassTier.liquid,
      );
    });

    testWidgets('an unsupported liquid renderer → frosted', (tester) async {
      final context = await _context(tester);
      const policy = LiquidGlassPolicy(
        renderers: [_FakeRenderer(LiquidGlassTier.liquid, supported: false)],
      );
      expect(
        policy.resolve(context, const LiquidGlassSignals()),
        LiquidGlassTier.frosted,
      );
    });

    testWidgets('forcedTier wins over every signal', (tester) async {
      final context = await _context(tester);
      const solidSignals = LiquidGlassSignals(reduceTransparency: true);
      final logs = await _captureLogs(() async {
        expect(
          const LiquidGlassPolicy(
            forcedTier: LiquidGlassTier.frosted,
          ).resolve(context, solidSignals),
          LiquidGlassTier.frosted,
        );
        expect(
          const LiquidGlassPolicy(
            forcedTier: LiquidGlassTier.solid,
          ).resolve(context, const LiquidGlassSignals()),
          LiquidGlassTier.solid,
        );
        expect(
          const LiquidGlassPolicy(
            forcedTier: LiquidGlassTier.liquid,
            renderers: [_FakeRenderer(LiquidGlassTier.liquid)],
          ).resolve(context, solidSignals),
          LiquidGlassTier.liquid,
        );
      });
      expect(logs, isEmpty);
    });

    testWidgets('forced liquid without a renderer → frosted, logged once', (
      tester,
    ) async {
      final context = await _context(tester);
      const policy = LiquidGlassPolicy(forcedTier: LiquidGlassTier.liquid);
      final logs = await _captureLogs(() async {
        for (var i = 0; i < 2; i++) {
          expect(
            policy.resolve(context, const LiquidGlassSignals()),
            LiquidGlassTier.frosted,
          );
        }
      });
      expect(logs, hasLength(1));
      expect(logs.single, contains('liquid'));
    });

    testWidgets('isSupported that throws counts as unsupported and is '
        'reported', (tester) async {
      final context = await _context(tester);
      const policy = LiquidGlassPolicy(
        renderers: [_FakeRenderer(LiquidGlassTier.liquid, throws: true)],
      );
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = errors.add;
      try {
        expect(
          policy.resolve(context, const LiquidGlassSignals()),
          LiquidGlassTier.frosted,
        );
      } finally {
        FlutterError.onError = originalOnError;
      }
      expect(errors.single.library, 'liquid_shell');
      expect(errors.single.exception, isA<StateError>());
    });
  });

  group('resolveGlassRenderer', () {
    testWidgets('goes through an overridden resolve', (tester) async {
      final context = await _context(tester);
      expect(
        resolveGlassRenderer(
          const _TierPolicy(LiquidGlassTier.solid),
          context,
          const LiquidGlassSignals(),
        ),
        isA<SolidGlassRenderer>(),
      );
    });

    testWidgets('an overridden resolve that probes still reports a throwing '
        'renderer once per call', (tester) async {
      final context = await _context(tester);
      // super.resolve probes the liquid renderer, then rendererFor(liquid)
      // would probe it again.
      const policy = _TierPolicy(
        LiquidGlassTier.liquid,
        callSuper: true,
        renderers: [_FakeRenderer(LiquidGlassTier.liquid, throws: true)],
      );
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = errors.add;
      try {
        final renderer = resolveGlassRenderer(
          policy,
          context,
          const LiquidGlassSignals(),
        );
        expect(renderer, isA<FrostedGlassRenderer>());
        // A new call probes afresh.
        resolveGlassRenderer(policy, context, const LiquidGlassSignals());
      } finally {
        FlutterError.onError = originalOnError;
      }
      expect(errors, hasLength(2));
    });

    testWidgets('probes a throwing renderer once per call', (tester) async {
      final context = await _context(tester);
      const policy = LiquidGlassPolicy(
        renderers: [_FakeRenderer(LiquidGlassTier.liquid, throws: true)],
      );
      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = errors.add;
      try {
        final renderer = resolveGlassRenderer(
          policy,
          context,
          const LiquidGlassSignals(),
        );
        expect(renderer, isA<FrostedGlassRenderer>());
      } finally {
        FlutterError.onError = originalOnError;
      }
      expect(errors, hasLength(1));
    });

    testWidgets('prefersSolid picks solid; forced tier steps down', (
      tester,
    ) async {
      final context = await _context(tester);
      expect(
        resolveGlassRenderer(
          const LiquidGlassPolicy(),
          context,
          const LiquidGlassSignals(reduceTransparency: true),
        ),
        isA<SolidGlassRenderer>(),
      );
      expect(
        resolveGlassRenderer(
          const LiquidGlassPolicy(forcedTier: LiquidGlassTier.liquid),
          context,
          const LiquidGlassSignals(reduceTransparency: true),
        ),
        isA<FrostedGlassRenderer>(),
      );
    });
  });

  group('LiquidGlassPolicy.rendererFor', () {
    testWidgets('built-ins fill the tiers nobody registered', (tester) async {
      final context = await _context(tester);
      const policy = LiquidGlassPolicy();
      expect(
        policy.rendererFor(context, LiquidGlassTier.frosted),
        isA<FrostedGlassRenderer>(),
      );
      expect(
        policy.rendererFor(context, LiquidGlassTier.solid),
        isA<SolidGlassRenderer>(),
      );
      expect(
        policy.rendererFor(context, LiquidGlassTier.liquid),
        isA<FrostedGlassRenderer>(),
      );
    });

    testWidgets('the first supported registered renderer wins', (
      tester,
    ) async {
      final context = await _context(tester);
      const unsupported = _FakeRenderer(
        LiquidGlassTier.frosted,
        supported: false,
      );
      const first = _FakeRenderer(LiquidGlassTier.frosted);
      const second = _FakeRenderer(LiquidGlassTier.frosted);
      const policy = LiquidGlassPolicy(
        renderers: [unsupported, first, second],
      );
      expect(
        identical(policy.rendererFor(context, LiquidGlassTier.frosted), first),
        isTrue,
      );
    });
  });

  group('the built-in liquid renderer (spec §5.2, §6.2)', () {
    testWidgets('without shader filters liquid falls back to frosted', (
      tester,
    ) async {
      debugLiquidGlassCanRefractOverride = false;
      await tester.runAsync(LiquidGlass.precache);
      final context = await _context(tester);
      expect(
        const LiquidGlassPolicy().rendererFor(context, LiquidGlassTier.liquid),
        isA<FrostedGlassRenderer>(),
      );
    });

    testWidgets('before the program loads liquid falls back to frosted', (
      tester,
    ) async {
      debugLiquidGlassCanRefractOverride = true;
      final context = await _context(tester);
      expect(
        const LiquidGlassPolicy().resolve(context, const LiquidGlassSignals()),
        LiquidGlassTier.frosted,
      );
    });

    testWidgets('with shader filters and the program it is the default', (
      tester,
    ) async {
      debugLiquidGlassCanRefractOverride = true;
      await tester.runAsync(LiquidGlass.precache);
      final context = await _context(tester);
      const policy = LiquidGlassPolicy();
      expect(
        policy.rendererFor(context, LiquidGlassTier.liquid),
        isA<LiquidShaderRenderer>(),
      );
      expect(
        policy.resolve(context, const LiquidGlassSignals()),
        LiquidGlassTier.liquid,
      );
    });

    testWidgets('a registered liquid renderer wins over the built-in one', (
      tester,
    ) async {
      debugLiquidGlassCanRefractOverride = true;
      await tester.runAsync(LiquidGlass.precache);
      final context = await _context(tester);
      const mine = _FakeRenderer(LiquidGlassTier.liquid);
      expect(
        identical(
          const LiquidGlassPolicy(
            renderers: [mine],
          ).rendererFor(context, LiquidGlassTier.liquid),
          mine,
        ),
        isTrue,
      );
    });

    testWidgets('inside another BackdropFilter it is unsupported (Q10)', (
      tester,
    ) async {
      debugLiquidGlassCanRefractOverride = true;
      await tester.runAsync(LiquidGlass.precache);
      late BuildContext inner;
      await tester.pumpWidget(
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Builder(
            builder: (context) {
              inner = context;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(const LiquidShaderRenderer().isSupported(inner), isFalse);
      expect(
        const LiquidGlassPolicy().rendererFor(inner, LiquidGlassTier.liquid),
        isA<FrostedGlassRenderer>(),
      );
    });
  });

  test('== compares the type, forcedTier and renderers', () {
    expect(
      const LiquidGlassPolicy(),
      isNot(const _TierPolicy(LiquidGlassTier.solid)),
      reason: 'a subclass may resolve differently',
    );
    const renderer = _FakeRenderer(LiquidGlassTier.liquid);
    expect(
      const LiquidGlassPolicy(renderers: [renderer]),
      const LiquidGlassPolicy(renderers: [renderer]),
    );
    expect(
      const LiquidGlassPolicy().hashCode,
      const LiquidGlassPolicy().hashCode,
    );
    expect(
      const LiquidGlassPolicy(),
      isNot(const LiquidGlassPolicy(forcedTier: LiquidGlassTier.solid)),
    );
  });

  testWidgets('LiquidGlassScope.policyOf', (tester) async {
    const policy = LiquidGlassPolicy(forcedTier: LiquidGlassTier.solid);
    late LiquidGlassPolicy inside;
    late LiquidGlassPolicy outside;
    await tester.pumpWidget(
      Column(
        children: [
          Builder(
            builder: (context) {
              outside = LiquidGlassScope.policyOf(context);
              return const SizedBox();
            },
          ),
          LiquidGlassScope(
            policy: policy,
            child: Builder(
              builder: (context) {
                inside = LiquidGlassScope.policyOf(context);
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
    expect(inside, policy);
    expect(outside, const LiquidGlassPolicy());
  });
}
