import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/glass/glass_theme.dart';
import 'package:liquid_shell/src/glass/liquid_backdrop.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';
import 'package:liquid_shell/src/glass/liquid_optics.dart';
import 'package:liquid_shell/src/glass/liquid_renderer.dart';
import 'package:liquid_shell/src/glass/outside_shadow.dart';
import 'package:liquid_shell/src/glass/shader_program.dart';
import 'package:liquid_shell/src/glass/signals_controller.dart';
import 'package:liquid_shell/src/glass/tier.dart';

/// The shadow under an engaged tab lens (spec VK-503 §7.2).
const BoxShadow kLensShadow = BoxShadow(
  color: Color(0x1A000000),
  offset: Offset(0, 2),
  blurRadius: 10,
);

/// The engaged tab lens: a second glass pass that refracts the page behind
/// the bar (spec VK-503 §7). It fills its box as a capsule. In the liquid
/// tier it shares the nearest `BackdropGroup`'s backdrop with the pill, so
/// it samples the page, not the pill.
class LiquidLens extends StatefulWidget {
  /// Creates a lens; [engage] scales the rim and shadow, [refraction] the
  /// thickness and dispersion.
  const LiquidLens({required this.engage, required this.refraction, super.key});

  /// 0–1.
  final double engage;

  /// 0–1.
  final double refraction;

  @override
  State<LiquidLens> createState() => _LiquidLensState();
}

class _LiquidLensState extends State<LiquidLens> {
  final LiquidSignalsController _signals = LiquidSignalsController.instance;
  late final Listenable _changes = liquidGlassChanges();

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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _changes,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.biggest.shortestSide;
        final radius = BorderRadius.all(Radius.circular(h / 2));
        final theme = LiquidGlassTheme.of(context);
        final renderer = resolveGlassFor(context);
        final engage = widget.engage.clamp(0.0, 1.0);
        final refraction = widget.refraction.clamp(0.0, 1.0);
        final rim = const Color(0xFFFFFFFF).withValues(alpha: 0.35 * engage);
        final program = LiquidShaderProgram.instance.value;
        final Widget body;
        if (renderer is LiquidShaderRenderer && program != null) {
          body = ClipRRect(
            borderRadius: radius,
            child: LiquidBackdrop(
              program: program,
              borderRadius: radius,
              params: LiquidOpticsParams(
                tint: const Color(0x00000000),
                rim: rim,
                refraction: 1.6 * refraction,
                dispersion: 0.6 * refraction,
                blurSigma: 0,
                bezel: h / 2,
                rimWidth: 1,
              ),
            ),
          );
        } else if (renderer.tier == LiquidGlassTier.solid) {
          body = DecoratedBox(
            decoration: BoxDecoration(
              color: Color.alphaBlend(theme.selectionFill, theme.solid),
              borderRadius: radius,
              border: MediaQuery.highContrastOf(context)
                  ? Border.all(color: theme.border, width: theme.borderWidth)
                  : null,
            ),
          );
        } else {
          body = ClipRRect(
            borderRadius: radius,
            child: BackdropFilter.grouped(
              filter: ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF).withValues(
                    alpha: 0.10 * engage,
                  ),
                  borderRadius: radius,
                  border: Border.all(color: rim),
                ),
              ),
            ),
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            body,
            // Above the lens, so the lens never samples its own shadow.
            OutsideShadow(
              borderRadius: radius,
              shadow: BoxShadow(
                color: kLensShadow.color.withValues(
                  alpha: kLensShadow.color.a * engage,
                ),
                offset: kLensShadow.offset,
                blurRadius: kLensShadow.blurRadius,
              ),
            ),
          ],
        );
      },
    ),
  );
}
