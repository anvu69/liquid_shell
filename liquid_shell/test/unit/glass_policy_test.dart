import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/glass/frosted_renderer.dart';
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
  group('LiquidGlassSignals.prefersSolid', () {
    test('is false with every signal off', () {
      expect(const LiquidGlassSignals().prefersSolid, isFalse);
    });

    test('is true for each signal alone', () {
      expect(
        const LiquidGlassSignals(reduceTransparency: true).prefersSolid,
        isTrue,
      );
      expect(const LiquidGlassSignals(highContrast: true).prefersSolid, isTrue);
      expect(const LiquidGlassSignals(powerSave: true).prefersSolid, isTrue);
      expect(const LiquidGlassSignals(blurDisabled: true).prefersSolid, isTrue);
      expect(const LiquidGlassSignals(canBlur: false).prefersSolid, isTrue);
    });

    test('== and hashCode compare every field', () {
      expect(
        const LiquidGlassSignals(powerSave: true),
        const LiquidGlassSignals(powerSave: true),
      );
      expect(
        const LiquidGlassSignals(powerSave: true).hashCode,
        const LiquidGlassSignals(powerSave: true).hashCode,
      );
      expect(
        const LiquidGlassSignals(powerSave: true),
        isNot(const LiquidGlassSignals(canBlur: false)),
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

    testWidgets('each signal alone → solid', (tester) async {
      final context = await _context(tester);
      const policy = LiquidGlassPolicy(
        renderers: [_FakeRenderer(LiquidGlassTier.liquid)],
      );
      for (final signals in const [
        LiquidGlassSignals(reduceTransparency: true),
        LiquidGlassSignals(highContrast: true),
        LiquidGlassSignals(powerSave: true),
        LiquidGlassSignals(blurDisabled: true),
        LiquidGlassSignals(canBlur: false),
      ]) {
        expect(policy.resolve(context, signals), LiquidGlassTier.solid);
      }
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
          const LiquidGlassSignals(powerSave: true),
        ),
        isA<SolidGlassRenderer>(),
      );
      expect(
        resolveGlassRenderer(
          const LiquidGlassPolicy(forcedTier: LiquidGlassTier.liquid),
          context,
          const LiquidGlassSignals(powerSave: true),
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

  test('== compares forcedTier and renderers', () {
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
