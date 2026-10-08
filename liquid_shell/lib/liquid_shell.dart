/// Adaptive navigation shell with a Liquid Glass look for iOS and Android.
library;

export 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart'
    show LiquidPlatformSignals;

export 'src/destinations/badge.dart'
    show LiquidBadge, LiquidCountBadge, LiquidDotBadge;
export 'src/destinations/destination.dart';
export 'src/destinations/tab_action.dart';
export 'src/glass/glass_scope.dart';
export 'src/glass/glass_theme.dart';
export 'src/glass/liquid_glass.dart';
export 'src/glass/policy.dart' show LiquidGlassPolicy, LiquidGlassSignals;
export 'src/glass/renderer.dart';
export 'src/glass/signals_controller.dart'
    show debugLiquidGlassCanBlurOverride, debugResetLiquidGlassSignals;
export 'src/glass/tier.dart';
export 'src/shell/strings.dart';
