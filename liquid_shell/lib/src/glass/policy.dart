import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/glass/frosted_renderer.dart';
import 'package:liquid_shell/src/glass/liquid_renderer.dart';
import 'package:liquid_shell/src/glass/renderer.dart';
import 'package:liquid_shell/src/glass/solid_renderer.dart';
import 'package:liquid_shell/src/glass/tier.dart';

/// Everything [LiquidGlassPolicy.resolve] looks at besides the renderers.
@immutable
class LiquidGlassSignals {
  /// Creates a set of signals. Defaults describe a device with no
  /// accessibility, power or performance restriction.
  const LiquidGlassSignals({
    this.reduceTransparency = false,
    this.highContrast = false,
    this.powerSave = false,
    this.blurDisabled = false,
    this.lowEnd = false,
    this.glesOnly = false,
    this.slowFrames = false,
  });

  /// iOS Reduce Transparency; Android animations off or high contrast.
  final bool reduceTransparency;

  /// `MediaQuery.highContrastOf` (reported by iOS only).
  final bool highContrast;

  /// Android battery saver; iOS Low Power Mode.
  final bool powerSave;

  /// Android 12+: the system disabled window blurs. Battery saver does
  /// that too, so it counts only while [powerSave] is off.
  final bool blurDisabled;

  /// Android: a low-RAM device or under 3 GiB of memory.
  final bool lowEnd;

  /// Android 10+ without Vulkan 1.1 (Flutter renders with OpenGL ES).
  final bool glesOnly;

  /// Frames were too slow while liquid glass was shown (the frame guard).
  final bool slowFrames;

  /// Whether a signal asks for the solid tier: reduce transparency, high
  /// contrast, or blur disabled for a reason other than battery saver.
  bool get prefersSolid =>
      reduceTransparency || highContrast || (blurDisabled && !powerSave);

  /// Whether a signal asks for frosted instead of liquid.
  bool get prefersFrosted => powerSave || lowEnd || glesOnly || slowFrames;

  @override
  bool operator ==(Object other) =>
      other is LiquidGlassSignals &&
      other.reduceTransparency == reduceTransparency &&
      other.highContrast == highContrast &&
      other.powerSave == powerSave &&
      other.blurDisabled == blurDisabled &&
      other.lowEnd == lowEnd &&
      other.glesOnly == glesOnly &&
      other.slowFrames == slowFrames;

  @override
  int get hashCode => Object.hash(
    reduceTransparency,
    highContrast,
    powerSave,
    blurDisabled,
    lowEnd,
    glesOnly,
    slowFrames,
  );
}

/// Picks the renderer for [signals]: `policy.resolve`, then
/// `policy.rendererFor` the tier it returns.
///
/// Both may probe the same registered renderer (the default `resolve` asks
/// whether a liquid renderer is supported, `rendererFor` asks again). For
/// the length of this call every `isSupported` answer is remembered, so each
/// renderer is probed, and a throwing probe reported, once per call however
/// `resolve` is overridden. `LiquidGlass` calls this once per build. Not
/// exported.
LiquidGlassRenderer resolveGlassRenderer(
  LiquidGlassPolicy policy,
  BuildContext context,
  LiquidGlassSignals signals,
) {
  final outer = _probes;
  _probes = outer ?? Map.identity();
  try {
    return policy.rendererFor(context, policy.resolve(context, signals));
  } finally {
    _probes = outer;
  }
}

/// `isSupported` answers memoised during one [resolveGlassRenderer] call;
/// null outside one.
Map<LiquidGlassRenderer, bool>? _probes;

bool _loggedForcedFallback = false;

/// Resets the once-only debug log. Called by `debugResetLiquidGlassSignals`.
void debugResetPolicyLogging() => _loggedForcedFallback = false;

void _logForcedFallback(LiquidGlassTier forced, LiquidGlassTier used) {
  if (_loggedForcedFallback) return;
  _loggedForcedFallback = true;
  if (kDebugMode) {
    debugPrint(
      'liquid_shell: forced tier ${forced.name} has no supported renderer; '
      'drawing ${used.name}.',
    );
  }
}

/// Chooses the tier and the renderer for every `LiquidGlass`.
@immutable
class LiquidGlassPolicy {
  /// Creates a policy. With no arguments it picks automatically and uses
  /// the built-in liquid, frosted and solid renderers.
  const LiquidGlassPolicy({this.forcedTier, this.renderers = const []});

  /// App override. Wins over every signal. `null` picks automatically.
  ///
  /// A forced tier also keeps every `LiquidShell` under this policy on
  /// Flutter chrome, even where native chrome could engage: forcing a tier
  /// asks for Flutter glass (spec 2026-10-10 §9.1).
  final LiquidGlassTier? forcedTier;

  /// Extra renderers. For each tier the first supported registered
  /// renderer wins; the built-in liquid, frosted and solid renderers fill
  /// the rest. Solid is always available.
  final List<LiquidGlassRenderer> renderers;

  static const _liquid = LiquidShaderRenderer();
  static const _frosted = FrostedGlassRenderer();
  static const _solid = SolidGlassRenderer();

  /// The tier to draw.
  ///
  /// 1. [forcedTier], stepping down liquid → frosted → solid when it has no
  ///    supported renderer (logged once in debug builds).
  /// 2. [LiquidGlassSignals.prefersSolid] → solid.
  /// 3. [LiquidGlassSignals.prefersFrosted] → frosted.
  /// 4. Otherwise liquid when a liquid renderer is supported (a registered
  ///    one, else the built-in lens), else frosted.
  ///
  /// Override it to change the rule, for example to force solid on some
  /// devices; every `LiquidGlass` under this policy then draws
  /// `rendererFor(context, resolve(context, signals))`.
  LiquidGlassTier resolve(BuildContext context, LiquidGlassSignals signals) {
    final forced = forcedTier;
    if (forced != null) {
      final used = rendererFor(context, forced).tier;
      if (used != forced) _logForcedFallback(forced, used);
      return used;
    }
    if (signals.prefersSolid) return LiquidGlassTier.solid;
    if (signals.prefersFrosted) {
      return rendererFor(context, LiquidGlassTier.frosted).tier;
    }
    return rendererFor(context, LiquidGlassTier.liquid).tier;
  }

  /// The renderer that will draw [tier], after fallbacks.
  LiquidGlassRenderer rendererFor(BuildContext context, LiquidGlassTier tier) {
    final registered = _registered(context, tier);
    if (registered != null) return registered;
    return switch (tier) {
      LiquidGlassTier.liquid =>
        _supported(_liquid, context)
            ? _liquid
            : rendererFor(context, LiquidGlassTier.frosted),
      LiquidGlassTier.frosted => _frosted,
      LiquidGlassTier.solid => _solid,
    };
  }

  LiquidGlassRenderer? _registered(BuildContext context, LiquidGlassTier tier) {
    for (final renderer in renderers) {
      if (renderer.tier == tier && _supported(renderer, context)) {
        return renderer;
      }
    }
    return null;
  }

  static bool _supported(LiquidGlassRenderer renderer, BuildContext context) {
    final probes = _probes;
    if (probes == null) return _probe(renderer, context);
    return probes[renderer] ??= _probe(renderer, context);
  }

  static bool _probe(LiquidGlassRenderer renderer, BuildContext context) {
    try {
      return renderer.isSupported(context);
    } on Object catch (exception, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'liquid_shell',
          context: ErrorDescription(
            'while checking ${renderer.runtimeType}.isSupported',
          ),
        ),
      );
      return false;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is LiquidGlassPolicy &&
      // A subclass may resolve differently, so it never equals the base.
      other.runtimeType == runtimeType &&
      other.forcedTier == forcedTier &&
      listEquals(other.renderers, renderers);

  @override
  int get hashCode =>
      Object.hash(runtimeType, forcedTier, Object.hashAll(renderers));
}
