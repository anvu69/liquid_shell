import 'package:liquid_shell_ios/src/native_shell_api.g.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

// The channel boundary: Pigeon types never leave this package.

/// Native state → interface state.
LiquidNativeShellState stateFromNative(
  NativeShellState state,
) => LiquidNativeShellState(
  installed: state.installed,
  compact: state.compact,
  sidebar: switch (state.sidebar) {
    NativeSidebar.hidden => LiquidNativeSidebar.hidden,
    NativeSidebar.overlay => LiquidNativeSidebar.overlay,
    NativeSidebar.tiled => LiquidNativeSidebar.tiled,
  },
  unavailableReason: switch (state.unavailableReason) {
    null => null,
    NativeUnavailableReason.notIPad => LiquidNativeUnavailableReason.notIPad,
    NativeUnavailableReason.osTooOld => LiquidNativeUnavailableReason.osTooOld,
    NativeUnavailableReason.iPadAppOnMac =>
      LiquidNativeUnavailableReason.iPadAppOnMac,
    NativeUnavailableReason.notEnabled =>
      LiquidNativeUnavailableReason.notEnabled,
    NativeUnavailableReason.disabledByEnvironment =>
      LiquidNativeUnavailableReason.disabledByEnvironment,
    NativeUnavailableReason.rootNotFlutter =>
      LiquidNativeUnavailableReason.rootNotFlutter,
    NativeUnavailableReason.registeredLate =>
      LiquidNativeUnavailableReason.registeredLate,
  },
);

/// Window controls from the channel, checked at the boundary: a negative
/// or non-finite field becomes 0.
LiquidWindowControls controlsFromNative(NativeWindowControls controls) =>
    LiquidWindowControls.sanitized(
      leading: controls.leading,
      top: controls.top,
    );

/// Interface config → native config.
NativeChromeConfig configToNative(LiquidNativeChromeConfig config) =>
    NativeChromeConfig(
      engaged: config.engaged,
      tabs: [
        for (final tab in config.tabs)
          NativeTab(
            title: tab.title,
            sfSymbol: tab.sfSymbol,
            badge: tab.badge,
            sidebarOnly: tab.sidebarOnly,
          ),
      ],
      selectedIndex: config.selectedIndex,
      trailing: switch (config.trailing) {
        null => null,
        final action => NativeAction(
          title: action.title,
          sfSymbol: action.sfSymbol,
        ),
      },
      footer: switch (config.footer) {
        null => null,
        final footer => NativeFooter(
          title: footer.title,
          subtitle: footer.subtitle,
          sfSymbol: footer.sfSymbol,
          semanticLabel: footer.semanticLabel,
        ),
      },
      tintArgb: config.tintArgb,
      dark: config.dark,
      rtl: config.rtl,
      hidden: config.hidden,
      interactive: config.interactive,
    );
