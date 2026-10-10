import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/glass/glass_scope.dart';
import 'package:liquid_shell/src/glass/glass_theme.dart';
import 'package:liquid_shell/src/glass/policy.dart';
import 'package:liquid_shell/src/glass/renderer.dart';
import 'package:liquid_shell/src/glass/shader_program.dart';
import 'package:liquid_shell/src/glass/signals_controller.dart';

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
  late final Listenable _changes = Listenable.merge([
    _signals,
    LiquidShaderProgram.instance,
  ]);

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
      final platform = _signals.value;
      final policy = LiquidGlassScope.policyOf(context);
      // policy.resolve, then rendererFor, probing each renderer once.
      final renderer = resolveGlassRenderer(
        policy,
        context,
        LiquidGlassSignals(
          reduceTransparency: platform.reduceTransparency,
          highContrast: MediaQuery.highContrastOf(context),
          powerSave: platform.powerSave,
          blurDisabled: platform.blurDisabled,
          lowEnd: platform.lowEnd,
          glesOnly: platform.glesOnly,
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
