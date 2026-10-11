import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:liquid_shell/src/glass/glass_theme.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';
import 'package:liquid_shell/src/glass/signals_controller.dart';
import 'package:liquid_shell/src/glass/tier.dart';

/// Height of the scroll-edge pocket (research §5: 147.8 pt).
const double kScrollPocketExtent = 148;

/// The pocket (tests).
const kScrollPocketKey = ValueKey<String>('liquid-scroll-pocket');

/// An approximation of iOS 26's scroll-edge pocket under the bottom bar
/// (spec VK-503 §15, Q13): three blur bands (σ 0.5, 1.0, 1.6, top to
/// bottom) and a faint dim. Flutter has no progressive backdrop blur, so
/// it is banded. Liquid tier only; it draws nothing in frosted and solid.
class ScrollEdgePocket extends StatefulWidget {
  /// Creates the pocket; the shell sizes it to [kScrollPocketExtent].
  const ScrollEdgePocket({super.key});

  @override
  State<ScrollEdgePocket> createState() => _ScrollEdgePocketState();
}

class _ScrollEdgePocketState extends State<ScrollEdgePocket> {
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
    builder: (context, _) {
      final theme = LiquidGlassTheme.of(context);
      if (resolveGlassFor(context).tier != LiquidGlassTier.liquid ||
          theme.liquidBlurSigma <= 0) {
        return const SizedBox.shrink();
      }
      final dark = Theme.of(context).brightness == Brightness.dark;
      return IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                for (final sigma in const [0.5, 1.0, 1.6])
                  Expanded(
                    child: ClipRect(
                      child: BackdropFilter.grouped(
                        filter: ui.ImageFilter.blur(
                          sigmaX: sigma,
                          sigmaY: sigma,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
              ],
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0x00000000),
                    // Research §5: the band reads 252, not 255 (light).
                    if (dark)
                      const Color(0x14000000)
                    else
                      const Color(0x03000000),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
