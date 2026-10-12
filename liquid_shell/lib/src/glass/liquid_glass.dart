import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/glass/frame_guard.dart';
import 'package:liquid_shell/src/glass/glass_scope.dart';
import 'package:liquid_shell/src/glass/glass_theme.dart';
import 'package:liquid_shell/src/glass/policy.dart';
import 'package:liquid_shell/src/glass/renderer.dart';
import 'package:liquid_shell/src/glass/shader_program.dart';
import 'package:liquid_shell/src/glass/signals_controller.dart';

/// Everything that can change which renderer a glass uses (liquid tier
/// §5.5): platform signals, the shader program, the frame guard.
Listenable liquidGlassChanges() => Listenable.merge([
  LiquidSignalsController.instance,
  LiquidShaderProgram.instance,
  LiquidFrameGuard.instance,
]);

/// The renderer a glass at [context] uses now. `LiquidGlass` and
/// `LiquidLens` share it, so the tab pill and its lens never disagree
/// (spec VK-503 §7.3).
LiquidGlassRenderer resolveGlassFor(BuildContext context) {
  final platform = LiquidSignalsController.instance.value;
  return resolveGlassRenderer(
    LiquidGlassScope.policyOf(context),
    context,
    LiquidGlassSignals(
      reduceTransparency: platform.reduceTransparency,
      highContrast: MediaQuery.highContrastOf(context),
      powerSave: platform.powerSave,
      blurDisabled: platform.blurDisabled,
      lowEnd: platform.lowEnd,
      glesOnly: platform.glesOnly,
      slowFrames: LiquidFrameGuard.instance.value,
    ),
  );
}

/// A glass surface.
///
/// The background comes from the renderer the [LiquidGlassPolicy] picks
/// (see [LiquidGlassScope]); [child] is drawn on top. A tier change
/// cross-fades over 200ms (instantly under reduce motion) and never
/// rebuilds [child], so focus and scroll position survive.
///
/// Limits of the liquid tier (see `doc/liquid.md`):
///
/// * It writes opaque pixels. Over a transparent window or in an image
///   capture of a subtree it is a solid tint, not see-through; an
///   `Opacity` ancestor fades it normally. Force
///   `LiquidGlassTier.frosted` there with [LiquidGlassPolicy.forcedTier].
/// * Under a scaling or rotating ancestor the lens uses the glass's
///   bounding box, with the corner radii, bezel and rim unscaled.
/// * Moves other than the nearest route's transition or the nearest
///   `Scrollable`'s scroll (a `CompositedTransformFollower`, an outer
///   `Navigator` or `Scrollable`) place the lens one frame late.
class LiquidGlass extends StatefulWidget {
  /// Creates a glass surface around [child].
  const LiquidGlass({required this.child, this.borderRadius, super.key});

  /// The content, drawn above the glass.
  final Widget child;

  /// Shape of the surface. `null` uses [LiquidGlassTheme.borderRadius].
  final BorderRadius? borderRadius;

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();

  /// Loads the liquid lens shader now, so the first frame can already be
  /// liquid. Optional: without it the first frame or two are frosted and
  /// then cross-fade. Safe to call more than once; never throws.
  ///
  /// ```dart
  /// Future<void> main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await LiquidGlass.precache();
  ///   runApp(const MyApp());
  /// }
  /// ```
  static Future<void> precache() => LiquidShaderProgram.instance.load();
}

class _LiquidGlassState extends State<LiquidGlass> {
  static const _fade = Duration(milliseconds: 200);
  final LiquidSignalsController _signals = LiquidSignalsController.instance;
  late final Listenable _changes = liquidGlassChanges();

  @override
  void initState() {
    super.initState();
    _signals.acquire();
    if (liquidGlassCanRefract()) {
      unawaited(LiquidShaderProgram.instance.load());
    }
  }

  @override
  void dispose() {
    _signals.release();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => ListenableBuilder(
    listenable: _changes,
    child: widget.child,
    builder: (context, child) {
      final renderer = resolveGlassFor(context);
      final theme = LiquidGlassTheme.of(context);
      final background = KeyedSubtree(
        // Tier and type, not identity: a custom renderer built anew on every
        // rebuild must not look like a tier change.
        key: ValueKey((renderer.tier, renderer.runtimeType)),
        child: renderer.buildBackground(
          context,
          LiquidGlassSpec(
            borderRadius: widget.borderRadius ?? theme.borderRadius,
            theme: theme,
          ),
        ),
      );
      return Stack(
        children: [
          Positioned.fill(
            child: MediaQuery.disableAnimationsOf(context)
                ? background
                : AnimatedSwitcher(
                    duration: _fade,
                    layoutBuilder: (current, previous) => Stack(
                      fit: StackFit.expand,
                      children: [...previous, ?current],
                    ),
                    child: background,
                  ),
          ),
          child!,
        ],
      );
    },
  );
}
