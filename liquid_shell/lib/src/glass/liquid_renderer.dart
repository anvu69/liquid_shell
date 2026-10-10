import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/glass/liquid_backdrop.dart';
import 'package:liquid_shell/src/glass/liquid_optics.dart';
import 'package:liquid_shell/src/glass/outside_shadow.dart';
import 'package:liquid_shell/src/glass/renderer.dart';
import 'package:liquid_shell/src/glass/shader_program.dart';
import 'package:liquid_shell/src/glass/signals_controller.dart';
import 'package:liquid_shell/src/glass/tier.dart';

/// Built-in liquid tier: the clean-room lens shader over a light blur,
/// then the outside shadow (spec 2026-10-10 §5.2).
class LiquidShaderRenderer extends LiquidGlassRenderer {
  /// Creates the liquid renderer.
  const LiquidShaderRenderer();

  @override
  LiquidGlassTier get tier => LiquidGlassTier.liquid;

  /// Shader filters are supported, the program is loaded, and the glass is
  /// not inside another [BackdropFilter]: there the shader's coordinates
  /// start at that filter's region, not the screen (spec §3.2 case I).
  @override
  bool isSupported(BuildContext context) =>
      liquidGlassCanRefract() &&
      LiquidShaderProgram.instance.value != null &&
      context.findAncestorWidgetOfExactType<BackdropFilter>() == null;

  @override
  Widget buildBackground(BuildContext context, LiquidGlassSpec spec) {
    final shadow = OutsideShadow(
      borderRadius: spec.borderRadius,
      shadow: spec.theme.shadow,
    );
    final program = LiquidShaderProgram.instance.value;
    // isSupported guarantees a program; this keeps a stray call harmless.
    if (program == null) return shadow;
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: spec.borderRadius,
          child: LiquidBackdrop(
            program: program,
            borderRadius: spec.borderRadius,
            params: LiquidOpticsParams.fromTheme(spec.theme),
          ),
        ),
        // Above the lens, so the lens never samples the shadow.
        shadow,
      ],
    );
  }
}
