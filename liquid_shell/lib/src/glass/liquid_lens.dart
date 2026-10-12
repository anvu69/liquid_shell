import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
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

/// The engaged lens's veil over the page: native's milky core (spec VK-503
/// §7.2, about 10 % of the backdrop passes).
const double kLensVeil = 0.90;

/// The engaged lens's refracting ring, in points (spec §7.2).
const double kLensBezel = 14;

/// The blur before the lens shader, logical sigma (spec §7.2).
const double kLensBlurSigma = 2;

/// The engaged tab lens: a second glass pass that refracts the page behind
/// the bar (spec VK-503 §7). It fills its box as a capsule. In the liquid
/// tier it shares the nearest `BackdropGroup`'s backdrop with the pill, so
/// it samples the page, not the pill.
///
/// It fades with [engage] (spec §7.2). The liquid pass cannot sit under an
/// `Opacity`: inside the opacity layer its backdrop read is wrong, and a
/// dark lens at engage 0.9 drew 116 luma between its 18 and the rest
/// capsule's 55 (VK-503 Task 16 review, the grey flash). So the liquid
/// lens blends its optics toward the pill's own glass and draws
/// [restFill] over itself at 1 − [engage]: at 0 it is the pill with its
/// rest capsule. The frosted and solid lenses fade with one `Opacity`.
class LiquidLens extends StatefulWidget {
  /// Creates a lens; [refraction] scales the thickness and dispersion.
  const LiquidLens({
    required this.refraction,
    this.engage = 1,
    this.restFill,
    super.key,
  });

  /// 0–1.
  final double refraction;

  /// 0 (the pill at rest) to 1 (the engaged lens).
  final double engage;

  /// The rest capsule's fill, drawn over the liquid lens at 1 − [engage].
  final Color? restFill;

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
    // Idempotent: a lens mounted without its pill still turns liquid.
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _changes,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.biggest.shortestSide;
        final radius = BorderRadius.all(Radius.circular(h / 2));
        final theme = LiquidGlassTheme.of(context);
        final renderer = resolveGlassFor(context);
        final refraction = widget.refraction.clamp(0.0, 1.0);
        final engage = widget.engage.clamp(0.0, 1.0);
        final rim = const Color(0xFFFFFFFF).withValues(alpha: 0.35);
        final pill = LiquidOpticsParams.fromTheme(theme);
        final scheme = Theme.of(context).colorScheme;
        final veil = scheme.brightness == Brightness.light
            ? const Color(0xFFFFFFFF)
            : scheme.surface;
        final program = LiquidShaderProgram.instance.value;
        final Widget body;
        if (renderer is LiquidShaderRenderer && program != null) {
          body = ClipRRect(
            borderRadius: radius,
            child: LiquidBackdrop(
              program: program,
              borderRadius: radius,
              params: LiquidOpticsParams(
                tint: Color.lerp(
                  pill.tint,
                  veil.withValues(alpha: kLensVeil),
                  engage,
                )!,
                rim: Color.lerp(pill.rim, rim, engage)!,
                refraction: 1.6 * refraction,
                dispersion: 0.6 * refraction,
                blurSigma: ui.lerpDouble(
                  pill.blurSigma,
                  kLensBlurSigma,
                  engage,
                )!,
                bezel: ui.lerpDouble(LiquidOptics.bezel, kLensBezel, engage),
                rimWidth: ui.lerpDouble(LiquidOptics.rimWidth, 1, engage),
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
                  color: const Color(0xFFFFFFFF).withValues(alpha: 0.10),
                  borderRadius: radius,
                  border: Border.all(color: rim),
                ),
              ),
            ),
          );
        }
        final liquid = renderer is LiquidShaderRenderer && program != null;
        final fill = widget.restFill;
        final lens = Stack(
          fit: StackFit.expand,
          children: [
            body,
            if (liquid && fill != null && engage < 1)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: fill.withValues(alpha: fill.a * (1 - engage)),
                  borderRadius: radius,
                ),
              ),
            // Above the lens, so the lens never samples its own shadow.
            OutsideShadow(
              borderRadius: radius,
              shadow: liquid
                  ? kLensShadow.copyWith(
                      color: kLensShadow.color.withValues(
                        alpha: kLensShadow.color.a * engage,
                      ),
                    )
                  : kLensShadow,
            ),
          ],
        );
        return liquid ? lens : Opacity(opacity: engage, child: lens);
      },
    ),
  );
}
