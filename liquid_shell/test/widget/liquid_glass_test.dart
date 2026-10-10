import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_shell/liquid_shell.dart';
import 'package:liquid_shell/src/glass/liquid_backdrop.dart';

import '../helpers/fake_signals_platform.dart';

final _scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF3366CC));

Widget _app({
  Widget child = const SizedBox(width: 120, height: 40),
  MediaQueryData mediaQuery = const MediaQueryData(),
  LiquidGlassPolicy? policy,
  List<ThemeExtension<dynamic>> extensions = const [],
  BorderRadius? borderRadius,
}) {
  Widget glass = Center(
    child: LiquidGlass(borderRadius: borderRadius, child: child),
  );
  if (policy != null) glass = LiquidGlassScope(policy: policy, child: glass);
  return MediaQuery(
    data: mediaQuery,
    child: MaterialApp(
      theme: ThemeData(colorScheme: _scheme, extensions: extensions),
      home: glass,
    ),
  );
}

Iterable<BoxDecoration> _fills(WidgetTester tester, Color color) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .map((box) => box.decoration)
    .whereType<BoxDecoration>()
    .where((d) => d.color == color);

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => count++),
    child: Text('count $count', textDirection: TextDirection.ltr),
  );
}

class _Stateful extends StatefulWidget {
  const _Stateful();

  @override
  State<_Stateful> createState() => _StatefulState();
}

class _StatefulState extends State<_Stateful> {
  static int created = 0;
  @override
  void initState() {
    super.initState();
    created++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

/// A non-const custom renderer: equal in kind, never identical.
class _CustomRenderer extends LiquidGlassRenderer {
  _CustomRenderer();

  @override
  LiquidGlassTier get tier => LiquidGlassTier.liquid;

  @override
  Widget buildBackground(BuildContext context, LiquidGlassSpec spec) =>
      const _Stateful();
}

/// Overrides only [resolve], as an app with its own tier rule would.
class _AlwaysSolidPolicy extends LiquidGlassPolicy {
  const _AlwaysSolidPolicy();

  @override
  LiquidGlassTier resolve(BuildContext context, LiquidGlassSignals signals) =>
      LiquidGlassTier.solid;
}

/// Builds blurs instead of shader filters: `ImageFilter.shader` throws
/// without Impeller.
void _installBlurFactory() {
  debugLiquidFilterFactory = (shader, sigma) =>
      ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
  addTearDown(() => debugLiquidFilterFactory = null);
}

/// Shader filters on, the program loaded, blur in place of the shader.
Future<void> _enableLiquid(WidgetTester tester) async {
  debugLiquidGlassCanRefractOverride = true;
  _installBlurFactory();
  await tester.runAsync(LiquidGlass.precache);
}

void main() {
  final glassTheme = LiquidGlassTheme.fromColorScheme(_scheme);

  testWidgets('frosted by default', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(_fills(tester, glassTheme.tint), hasLength(1));
  });

  testWidgets('reduce transparency or blur disabled → solid; none → back', (
    tester,
  ) async {
    final platform = installFakeSignals();
    await tester.pumpWidget(_app());
    await tester.pump();

    for (final signals in const [
      LiquidPlatformSignals(reduceTransparency: true),
      LiquidPlatformSignals(blurDisabled: true),
    ]) {
      platform.emit(signals);
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing, reason: '$signals');
      expect(_fills(tester, glassTheme.solid), hasLength(1));

      platform.emit(LiquidPlatformSignals.none);
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsOneWidget);
    }
  });

  testWidgets('battery saver, low end and GLES only → frosted, not liquid', (
    tester,
  ) async {
    await _enableLiquid(tester);
    final platform = installFakeSignals();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byType(LiquidBackdrop), findsOneWidget);

    for (final signals in const [
      LiquidPlatformSignals(powerSave: true),
      LiquidPlatformSignals(powerSave: true, blurDisabled: true),
      LiquidPlatformSignals(lowEnd: true),
      LiquidPlatformSignals(glesOnly: true),
    ]) {
      platform.emit(signals);
      await tester.pumpAndSettle();
      expect(find.byType(LiquidBackdrop), findsNothing, reason: '$signals');
      expect(_fills(tester, glassTheme.tint), hasLength(1));

      platform.emit(LiquidPlatformSignals.none);
      await tester.pumpAndSettle();
      expect(find.byType(LiquidBackdrop), findsOneWidget);
    }
  });

  testWidgets('high contrast → solid', (tester) async {
    await tester.pumpWidget(
      _app(mediaQuery: const MediaQueryData(highContrast: true)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('no shader filters → frosted, on every platform', (
    tester,
  ) async {
    debugLiquidGlassCanRefractOverride = false;
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      debugDefaultTargetPlatformOverride = platform;
      await tester.pumpWidget(_app(child: SizedBox(width: platform.index + 1)));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(LiquidBackdrop), findsNothing);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('liquid by default with shader filters and the program', (
    tester,
  ) async {
    await _enableLiquid(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byType(LiquidBackdrop), findsOneWidget);
    expect(_fills(tester, glassTheme.tint), isEmpty);
  });

  testWidgets('frosted until the program loads, then liquid; child kept', (
    tester,
  ) async {
    debugLiquidGlassCanRefractOverride = true;
    _installBlurFactory();
    _StatefulState.created = 0;
    // The first frame is built before the load (started on mount) ends.
    await tester.pumpWidget(_app(child: const _Stateful()));
    expect(find.byType(LiquidBackdrop), findsNothing);

    await tester.runAsync(LiquidGlass.precache);
    await tester.pumpAndSettle();
    expect(find.byType(LiquidBackdrop), findsOneWidget);
    expect(_StatefulState.created, 1);
  });

  testWidgets('inside another BackdropFilter → frosted (Q10)', (tester) async {
    await _enableLiquid(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: const Center(
            child: LiquidGlass(child: SizedBox(width: 120, height: 40)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LiquidBackdrop), findsNothing);
  });

  testWidgets('inside another LiquidGlass child it stays liquid', (
    tester,
  ) async {
    await _enableLiquid(tester);
    await tester.pumpWidget(
      _app(
        child: const SizedBox(
          width: 200,
          height: 100,
          child: Center(
            child: LiquidGlass(child: SizedBox(width: 80, height: 40)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LiquidBackdrop), findsNWidgets(2));
  });

  testWidgets('a forced tier from LiquidGlassScope wins', (tester) async {
    await tester.pumpWidget(
      _app(policy: const LiquidGlassPolicy(forcedTier: LiquidGlassTier.solid)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('an overridden resolve picks the tier LiquidGlass draws', (
    tester,
  ) async {
    await tester.pumpWidget(_app(policy: const _AlwaysSolidPolicy()));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
    expect(_fills(tester, glassTheme.solid), hasLength(1));
  });

  testWidgets('swapping in a policy subclass re-resolves the tier', (
    tester,
  ) async {
    await tester.pumpWidget(_app(policy: const LiquidGlassPolicy()));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsOneWidget);

    await tester.pumpWidget(_app(policy: const _AlwaysSolidPolicy()));
    await tester.pumpAndSettle();
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('a tier change cross-fades over 200ms, then drops the blur', (
    tester,
  ) async {
    final platform = installFakeSignals();
    await tester.pumpWidget(_app());
    await tester.pump();

    platform.emit(const LiquidPlatformSignals(reduceTransparency: true));
    await tester.pump(); // delivers the event
    await tester.pump(); // rebuilds; the fade starts here
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(BackdropFilter), findsOneWidget, reason: 'mid-fade');
    expect(_fills(tester, glassTheme.solid), hasLength(1));

    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('under disableAnimations the switch is instant', (tester) async {
    final platform = installFakeSignals();
    await tester.pumpWidget(
      _app(mediaQuery: const MediaQueryData(disableAnimations: true)),
    );
    await tester.pump();
    expect(find.byType(AnimatedSwitcher), findsNothing);

    platform.emit(const LiquidPlatformSignals(reduceTransparency: true));
    await tester.pump(); // delivers the event
    await tester.pump(); // rebuilds with no fade
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('a tier change keeps the child state', (tester) async {
    final platform = installFakeSignals();
    await tester.pumpWidget(_app(child: const _Counter()));
    await tester.pump();
    await tester.tap(find.byType(_Counter));
    await tester.pump();
    expect(find.text('count 1'), findsOneWidget);

    platform.emit(const LiquidPlatformSignals(reduceTransparency: true));
    await tester.pumpAndSettle();
    expect(find.text('count 1'), findsOneWidget);
  });

  testWidgets('an error event falls back to no signals', (tester) async {
    final platform = installFakeSignals();
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    try {
      await tester.pumpWidget(_app());
      await tester.pump();
      platform.emit(const LiquidPlatformSignals(reduceTransparency: true));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing);

      platform.emitError(StateError('channel broke'));
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsOneWidget);
    } finally {
      debugPrint = original;
    }
    expect(logs.single, contains('channel broke'));
  });

  testWidgets('an equal but non-identical renderer neither fades nor resets', (
    tester,
  ) async {
    _StatefulState.created = 0;
    Widget app() => _app(
      policy: LiquidGlassPolicy(renderers: [_CustomRenderer()]),
    );
    await tester.pumpWidget(app());
    await tester.pump();
    expect(_StatefulState.created, 1);

    await tester.pumpWidget(app()); // a fresh renderer instance
    await tester.pump(const Duration(milliseconds: 50));
    expect(_StatefulState.created, 1, reason: 'background state kept');
    expect(find.byType(_Stateful), findsOneWidget, reason: 'no fade-out copy');
  });

  testWidgets('a burst of error events logs once', (tester) async {
    final platform = installFakeSignals();
    final logs = <String>[];
    final original = debugPrint;
    debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
    try {
      await tester.pumpWidget(_app());
      await tester.pump();
      platform.emitError(StateError('first'));
      await tester.pump();
      platform.emitError(StateError('second'));
      await tester.pump();
    } finally {
      debugPrint = original;
    }
    expect(logs, hasLength(1));
    expect(logs.single, contains('first'));
  });

  testWidgets('listens while any glass is mounted, stops after the last', (
    tester,
  ) async {
    final platform = installFakeSignals();
    await tester.pumpWidget(
      Column(
        children: [
          _app(),
          _app(child: const SizedBox(width: 10, height: 10)),
        ],
      ),
    );
    await tester.pump();
    expect(platform.listeners, 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(platform.listeners, 0);

    await tester.pumpWidget(_app());
    await tester.pump();
    expect(platform.listeners, 1);
  });

  testWidgets('honours a custom theme extension and borderRadius', (
    tester,
  ) async {
    final custom = glassTheme.copyWith(tint: const Color(0x80FF0000));
    await tester.pumpWidget(
      _app(extensions: [custom], borderRadius: BorderRadius.circular(8)),
    );
    await tester.pump();
    final fill = _fills(tester, const Color(0x80FF0000)).single;
    expect(fill.borderRadius, BorderRadius.circular(8));
  });

  testWidgets('without a theme extension nothing throws', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: LiquidGlass(child: SizedBox(width: 10))),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
