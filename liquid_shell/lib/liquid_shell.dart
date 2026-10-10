/// Adaptive navigation shell with a Liquid Glass look for iOS and Android.
library;

export 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart'
    show LiquidPlatformSignals, LiquidWindowControls;

export 'src/chrome/sidebar.dart';
export 'src/chrome/tab_bar.dart'
    show LiquidTabBar, LiquidTabBarPosition, kLiquidNarrowWidth;
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
export 'src/native/native_chrome.dart';
export 'src/native/native_reset.dart';
export 'src/native/window_controls.dart' show LiquidWindowControlsClearance;
export 'src/pages/liquid_page.dart';
export 'src/search/search.dart';
export 'src/search/search_controller.dart'
    show LiquidSearchController, LiquidSearchPhase, LiquidSearchValue;
export 'src/shell/breakpoints.dart';
export 'src/shell/chrome_builder.dart';
export 'src/shell/liquid_shell.dart';
export 'src/shell/shell_layout.dart' show LiquidChromeKind;
export 'src/shell/shell_scope.dart'
    show
        LiquidContentInset,
        LiquidHideChrome,
        LiquidNoChrome,
        LiquidShellScope,
        LiquidShellScopeData;
export 'src/shell/strings.dart';
