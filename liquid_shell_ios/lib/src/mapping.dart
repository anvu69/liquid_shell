import 'dart:ui' show Rect;

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
            search: tab.search,
            pages: [
              for (final page in tab.pages)
                NativePage(title: page.title, largeTitle: page.largeTitle),
            ],
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
      search: switch (config.search) {
        null => null,
        final search => NativeSearchConfig(placeholder: search.placeholder),
      },
      tintArgb: config.tintArgb,
      dark: config.dark,
      rtl: config.rtl,
      hidden: config.hidden,
      interactive: config.interactive,
    );

/// A native rect, checked at the boundary: any non-finite field makes it
/// [Rect.zero] ("not on screen").
Rect rectFromNative(NativeRect rect) {
  final values = [rect.x, rect.y, rect.width, rect.height];
  if (values.any((v) => !v.isFinite)) return Rect.zero;
  return Rect.fromLTWH(rect.x, rect.y, rect.width, rect.height);
}

/// Interface dialog request → native request. A non-finite anchor is not
/// sent (spec P3a §6).
NativeDialogRequest dialogRequestToNative(LiquidNativeDialogRequest request) =>
    NativeDialogRequest(
      kind: switch (request.kind) {
        LiquidNativeDialogKind.alert => NativeDialogKind.alert,
        LiquidNativeDialogKind.actionSheet => NativeDialogKind.actionSheet,
      },
      title: request.title,
      message: request.message,
      actions: [
        for (final action in request.actions)
          NativeDialogAction(
            label: action.label,
            style: switch (action.style) {
              LiquidNativeDialogActionStyle.standard =>
                NativeDialogActionStyle.standard,
              LiquidNativeDialogActionStyle.cancel =>
                NativeDialogActionStyle.cancel,
              LiquidNativeDialogActionStyle.destructive =>
                NativeDialogActionStyle.destructive,
            },
            enabled: action.enabled,
          ),
      ],
      preferredIndex: request.preferredIndex,
      anchor: switch (request.anchor) {
        final Rect rect? when rect.isFinite => NativeRect(
          x: rect.left,
          y: rect.top,
          width: rect.width,
          height: rect.height,
        ),
        _ => null,
      },
      tintArgb: request.tintArgb,
      dark: request.dark,
      rtl: request.rtl,
      requireGlass: request.requireGlass,
    );

/// Native result → interface result, checked at the boundary: an index
/// outside the request's [actionCount] actions is a dismissal, and an
/// unavailable answer without a reason is a channel error.
LiquidNativeDialogResult dialogResultFromNative(
  NativeDialogResult result, {
  required int actionCount,
}) => switch (result.outcome) {
  NativeDialogOutcome.chose => switch (result.actionIndex) {
    final int index? when index >= 0 && index < actionCount =>
      LiquidNativeDialogChose(index),
    _ => const LiquidNativeDialogDismissed(),
  },
  NativeDialogOutcome.dismissed => const LiquidNativeDialogDismissed(),
  NativeDialogOutcome.unavailable => LiquidNativeDialogUnavailable(
    switch (result.reason) {
      NativeDialogUnavailableReason.osTooOld =>
        LiquidNativeDialogUnavailableReason.osTooOld,
      NativeDialogUnavailableReason.noWindow =>
        LiquidNativeDialogUnavailableReason.noWindow,
      NativeDialogUnavailableReason.refused =>
        LiquidNativeDialogUnavailableReason.refused,
      NativeDialogUnavailableReason.disabledByEnvironment =>
        LiquidNativeDialogUnavailableReason.disabledByEnvironment,
      null => LiquidNativeDialogUnavailableReason.channelError,
    },
  ),
};
