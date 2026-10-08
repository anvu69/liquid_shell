import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/glass/frosted_renderer.dart';
import 'package:liquid_shell/src/glass/renderer.dart';
import 'package:liquid_shell/src/glass/solid_renderer.dart';
import 'package:liquid_shell/src/glass/tier.dart';

/// Everything [LiquidGlassPolicy.resolve] looks at besides the renderers.
@immutable
class LiquidGlassSignals {
  /// Creates a set of signals. Defaults describe a device with no
  /// accessibility or power restriction that can blur.
  const LiquidGlassSignals({
    this.reduceTransparency = false,
    this.highContrast = false,
    this.powerSave = false,
    this.blurDisabled = false,
    this.canBlur = true,
  });

  /// iOS Reduce Transparency; Android animations off or high contrast.
  final bool reduceTransparency;

  /// `MediaQuery.highContrastOf` (reported by iOS only).
  final bool highContrast;

  /// Android battery saver.
  final bool powerSave;

  /// Android 12+: the system disabled window blurs.
  final bool blurDisabled;

  /// False on Android without Impeller (no shader filters, API ≤ 28).
  final bool canBlur;

  /// Whether any signal asks for the solid tier.
  bool get prefersSolid =>
      reduceTransparency ||
      highContrast ||
      powerSave ||
      blurDisabled ||
      !canBlur;

  @override
  bool operator ==(Object other) =>
      other is LiquidGlassSignals &&
      other.reduceTransparency == reduceTransparency &&
      other.highContrast == highContrast &&
      other.powerSave == powerSave &&
      other.blurDisabled == blurDisabled &&
      other.canBlur == canBlur;

  @override
  int get hashCode => Object.hash(
    reduceTransparency,
    highContrast,
    powerSave,
    blurDisabled,
    canBlur,
  );
}

/// Picks the renderer for [signals], probing each registered renderer once.
///
/// `LiquidGlass` calls this instead of `resolve` followed by `rendererFor`,
/// which would probe `isSupported` twice per build and report a throwing
/// probe twice. Not exported.
LiquidGlassRenderer resolveGlassRenderer(
  LiquidGlassPolicy policy,
  BuildContext context,
  LiquidGlassSignals signals,
) {
  final forced = policy.forcedTier;
  if (forced != null) {
    final renderer = policy.rendererFor(context, forced);
    if (renderer.tier != forced) _logForcedFallback(forced, renderer.tier);
    return renderer;
  }
  return policy.rendererFor(
    context,
    signals.prefersSolid ? LiquidGlassTier.solid : LiquidGlassTier.liquid,
  );
}

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
  /// the built-in frosted and solid renderers.
  const LiquidGlassPolicy({this.forcedTier, this.renderers = const []});

  /// App override. Wins over every signal. `null` picks automatically.
  final LiquidGlassTier? forcedTier;

  /// Extra renderers, for example a liquid adapter. For each tier the first
  /// supported registered renderer wins; the built-in frosted and solid
  /// renderers fill the rest. Solid is always available.
  final List<LiquidGlassRenderer> renderers;

  static const _frosted = FrostedGlassRenderer();
  static const _solid = SolidGlassRenderer();

  /// The tier to draw.
  ///
  /// 1. [forcedTier], stepping down liquid → frosted → solid when it has no
  ///    supported renderer (logged once in debug builds).
  /// 2. [LiquidGlassSignals.prefersSolid] → solid.
  /// 3. Otherwise liquid when a supported liquid renderer is registered,
  ///    else frosted.
  LiquidGlassTier resolve(BuildContext context, LiquidGlassSignals signals) =>
      resolveGlassRenderer(this, context, signals).tier;

  /// The renderer that will draw [tier], after fallbacks.
  LiquidGlassRenderer rendererFor(BuildContext context, LiquidGlassTier tier) {
    final registered = _registered(context, tier);
    if (registered != null) return registered;
    return switch (tier) {
      LiquidGlassTier.liquid => rendererFor(context, LiquidGlassTier.frosted),
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
      other.forcedTier == forcedTier &&
      listEquals(other.renderers, renderers);

  @override
  int get hashCode => Object.hash(forcedTier, Object.hashAll(renderers));
}
