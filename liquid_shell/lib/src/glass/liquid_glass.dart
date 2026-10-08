import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/glass/glass_scope.dart';
import 'package:liquid_shell/src/glass/glass_theme.dart';
import 'package:liquid_shell/src/glass/policy.dart';
import 'package:liquid_shell/src/glass/renderer.dart';
import 'package:liquid_shell/src/glass/signals_controller.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// A glass surface.
///
/// The background comes from the renderer the [LiquidGlassPolicy] picks
/// (see [LiquidGlassScope]); [child] is drawn on top. A tier change
/// cross-fades over 200ms (instantly under reduce motion) and never
/// rebuilds [child], so focus and scroll position survive.
class LiquidGlass extends StatefulWidget {
  /// Creates a glass surface around [child].
  const LiquidGlass({required this.child, this.borderRadius, super.key});

  /// The content, drawn above the glass.
  final Widget child;

  /// Shape of the surface. `null` uses [LiquidGlassTheme.borderRadius].
  final BorderRadius? borderRadius;

  @override
  State<LiquidGlass> createState() => _LiquidGlassState();
}

class _LiquidGlassState extends State<LiquidGlass> {
  static const _fade = Duration(milliseconds: 200);
  final LiquidSignalsController _signals = LiquidSignalsController.instance;

  @override
  void initState() {
    super.initState();
    _signals.acquire();
  }

  @override
  void dispose() {
    _signals.release();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<LiquidPlatformSignals>(
    valueListenable: _signals,
    child: widget.child,
    builder: (context, platform, child) {
      final policy = LiquidGlassScope.policyOf(context);
      // One probe per build: resolve and rendererFor would probe twice.
      final renderer = resolveGlassRenderer(
        policy,
        context,
        LiquidGlassSignals(
          reduceTransparency: platform.reduceTransparency,
          highContrast: MediaQuery.highContrastOf(context),
          powerSave: platform.powerSave,
          blurDisabled: platform.blurDisabled,
          canBlur: liquidGlassCanBlur(),
        ),
      );
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
