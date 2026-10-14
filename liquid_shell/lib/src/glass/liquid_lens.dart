import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_shell/src/glass/glass_theme.dart';
import 'package:liquid_shell/src/glass/lens_look.dart';
import 'package:liquid_shell/src/glass/liquid_backdrop.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';
import 'package:liquid_shell/src/glass/liquid_optics.dart';
import 'package:liquid_shell/src/glass/liquid_renderer.dart';
import 'package:liquid_shell/src/glass/outside_shadow.dart';
import 'package:liquid_shell/src/glass/shader_program.dart';
import 'package:liquid_shell/src/glass/signals_controller.dart';
import 'package:liquid_shell/src/glass/tier.dart';

export 'package:liquid_shell/src/glass/lens_look.dart';

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
    this.look = LensLook.tab,
    super.key,
  });

  /// 0–1.
  final double refraction;

  /// 0 (the pill at rest) to 1 (the engaged lens).
  final double engage;

  /// The rest capsule's fill, drawn over the liquid lens at 1 − [engage].
  final Color? restFill;

  /// The engaged lens's optics: [LensLook.tab] for a tab lens,
  /// [LensLook.segment] for a segment lens (spec VK-550 §7).
  final LensLook look;

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
        // The frosted lens's rim (VK-503 §7.3), whatever the look.
        final rim = const Color(0xFFFFFFFF).withValues(alpha: 0.35);
        final look = widget.look;
        final light =
            Theme.of(context).colorScheme.brightness == Brightness.light;
        final veil = light ? look.veilLight : look.veilDark;
        // Engage 0: over glass, the pill's own optics (the lens is the pill
        // there); over a flat fill, clear glass that bends nothing, so the
        // lens is the rest fill it draws over the page (spec VK-550 §7).
        final pill = LiquidOpticsParams.fromTheme(theme);
        final from = look.overGlass
            ? (
                tint: pill.tint,
                rim: pill.rim,
                blur: pill.blurSigma,
                bezel: LiquidOptics.bezel,
                rimWidth: LiquidOptics.rimWidth,
              )
            : (
                tint: veil.withValues(alpha: 0),
                rim: look.rim.withValues(alpha: 0),
                blur: 0.0,
                bezel: look.bezel,
                rimWidth: look.rimWidth,
              );
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
                  from.tint,
                  veil.withValues(alpha: look.veil),
                  engage,
                )!,
                rim: Color.lerp(from.rim, look.rim, engage)!,
                refraction: look.thickness * refraction,
                dispersion: look.dispersion * refraction,
                blurSigma: ui.lerpDouble(from.blur, look.blurSigma, engage)!,
                bezel: ui.lerpDouble(from.bezel, look.bezel, engage),
                rimWidth: ui.lerpDouble(from.rimWidth, look.rimWidth, engage),
                // The tab's milky core and clear ring (spec VK-503 §7.2,
                // Task 16 part B).
                veilFalloff:
                    engage *
                    (light ? look.veilFalloffLight : look.veilFalloffDark),
                saturation: look.saturation,
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
        if (liquid) return lens;
        final faded = Opacity(opacity: engage, child: lens);
        // Off glass the host draws no rest fill under the lens: it fades
        // here, under the fading glass (spec VK-550 §7, R8).
        if (look.overGlass || fill == null || engage >= 1) return faded;
        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: fill.withValues(alpha: fill.a * (1 - engage)),
                borderRadius: radius,
              ),
            ),
            faded,
          ],
        );
      },
    ),
  );
}

/// The lens warm-up's 1 × 1 lens, for tests.
@visibleForTesting
const kLensWarmUpKey = ValueKey<String>('liquid-lens-warm-up');

/// Lets the next [LiquidLensWarmUp] warm the pipeline again, for tests.
@visibleForTesting
void debugResetLensWarmUp() => _LiquidLensWarmUpState._done = false;

/// Builds the lens shader's pipeline before the first press (VK-550 Task
/// 15): on the simulator the first engaged lens after launch dropped a
/// frame (33-50 ms) while the engine built it. Once per process, in the
/// liquid tier, it draws one frame of a 1 × 1 lens that bends, tints and
/// rims nothing (so its pixel is the page's) with the lens's shadow at an
/// alpha that rounds to nothing, then nothing. A host whose
/// lens may be the first liquid glass on screen (the segmented control)
/// places it anywhere in its box.
class LiquidLensWarmUp extends StatefulWidget {
  /// Creates the warm-up.
  const LiquidLensWarmUp({super.key});

  @override
  State<LiquidLensWarmUp> createState() => _LiquidLensWarmUpState();
}

class _LiquidLensWarmUpState extends State<LiquidLensWarmUp> {
  static bool _done = false;

  late final Listenable _changes = liquidGlassChanges();
  bool _scheduled = false;

  /// The segment lens with nothing to bend, tint or rim, and the colours
  /// as they are: the same layers and pipelines, a pixel that is the
  /// page's.
  static const LensLook _clear = LensLook(
    overGlass: false,
    veil: 0,
    veilLight: Color(0x00000000),
    veilDark: Color(0x00000000),
    veilFalloffLight: 0,
    veilFalloffDark: 0,
    thickness: 0,
    dispersion: 0,
    blurSigma: 0,
    bezel: 9,
    rim: Color(0x00000000),
    rimWidth: 1,
    saturation: 1,
  );

  /// The lens's shadow at 1/255 alpha (a transparent one is not drawn),
  /// which rounds to nothing in 8 bits.
  static final double _engage = 1 / 255 / kLensShadow.color.a;

  @override
  void initState() {
    super.initState();
    // A control alone on screen: nothing else loads the program.
    if (!_done && liquidGlassCanRefract()) {
      unawaited(LiquidShaderProgram.instance.load());
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _changes,
    builder: (context, _) {
      if (_done ||
          LiquidShaderProgram.instance.value == null ||
          resolveGlassFor(context) is! LiquidShaderRenderer) {
        return const SizedBox.shrink();
      }
      if (!_scheduled) {
        _scheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _done = true;
          if (mounted) setState(() {});
        }, debugLabel: 'LiquidLensWarmUp');
      }
      // A real lens, so every layer the first press builds (its clip, the
      // pass, its shadow and the signals) is built here first.
      return SizedBox(
        key: kLensWarmUpKey,
        width: 1,
        height: 1,
        child: LiquidLens(refraction: 0, engage: _engage, look: _clear),
      );
    },
  );
}
