/// The iOS implementation of liquid_shell.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:liquid_shell_ios/src/native_shell_api.g.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

export 'src/native_shell_api.g.dart' show NativeTapTarget;

/// The iOS platform: the event-channel signal reader plus the native
/// iPadOS 26 shell and window controls over the Pigeon channel.
///
/// Registered by the generated plugin registrant. Apps never use it.
class LiquidShellIOS extends EventChannelLiquidShellPlatform
    implements NativeShellFlutterApi {
  /// Creates the platform. [hostApi] is for tests.
  ///
  /// Touches no channel: `registerWith` runs before `main`, when no
  /// binding exists yet. Native events are received from the first
  /// [attachNativeChrome], [readWindowControls] or [nativeEvents] listener.
  LiquidShellIOS({NativeShellHostApi? hostApi})
    : _host = hostApi ?? NativeShellHostApi();

  /// Makes a [LiquidShellIOS] the active implementation.
  static void registerWith() {
    LiquidShellPlatform.instance = LiquidShellIOS();
  }

  final NativeShellHostApi _host;
  late final StreamController<LiquidNativeEvent> _events =
      StreamController.broadcast(onListen: _receive);
  final Set<String> _loggedFailures = {};
  bool _receiving = false;

  /// Starts receiving native → Dart calls. Idempotent.
  void _receive() {
    if (_receiving) return;
    _receiving = true;
    NativeShellFlutterApi.setUp(this);
  }

  @override
  bool get supportsNativeChrome => true;

  @override
  Stream<LiquidNativeEvent> get nativeEvents => _events.stream;

  @override
  Future<LiquidNativeShellState> attachNativeChrome() async {
    _receive();
    try {
      return stateFromNative(await _host.attach());
    } on PlatformException catch (error) {
      _logOnce('attach', error);
      return const LiquidNativeShellState(
        installed: false,
        unavailableReason: LiquidNativeUnavailableReason.channelError,
      );
    }
  }

  @override
  Future<void> updateNativeChrome(LiquidNativeChromeConfig config) =>
      _send('update', () => _host.update(configToNative(config)));

  @override
  Future<void> setNativeSidebarVisible({required bool visible}) =>
      _send('setSidebarVisible', () => _host.setSidebarVisible(visible));

  @override
  Future<LiquidWindowControls> readWindowControls() async {
    _receive();
    try {
      return controlsFromNative(await _host.windowControls());
    } on PlatformException catch (error) {
      _logOnce('windowControls', error);
      return LiquidWindowControls.zero;
    }
  }

  /// Debug builds of the plugin run the code path of a user tap on
  /// [target]; release builds ignore it. For integration tests.
  @visibleForTesting
  Future<void> debugTap(NativeTapTarget target, [int index = 0]) =>
      _host.debugTap(target, index);

  Future<void> _send(String what, Future<void> Function() call) async {
    try {
      await call();
    } on PlatformException catch (error) {
      _logOnce(what, error);
    }
  }

  /// Channel failures never throw into the shell: they fall back (Flutter
  /// chrome, zero window controls) and are logged once per call in debug.
  void _logOnce(String what, PlatformException error) {
    if (!kDebugMode || !_loggedFailures.add(what)) return;
    debugPrint(
      'liquid_shell native: $what failed (${error.code}); falling back',
    );
  }

  // --- NativeShellFlutterApi (native → Dart) ---------------------------

  @override
  void onDestinationTapped(int index) =>
      _events.add(LiquidNativeDestinationTapped(index));

  @override
  void onTrailingTapped() => _events.add(const LiquidNativeTrailingTapped());

  @override
  void onFooterTapped() => _events.add(const LiquidNativeFooterTapped());

  @override
  void onStateChanged(NativeShellState state) =>
      _events.add(LiquidNativeStateChanged(stateFromNative(state)));

  @override
  void onWindowControlsChanged(NativeWindowControls controls) =>
      _events.add(LiquidWindowControlsChanged(controlsFromNative(controls)));
}

/// Native state → interface state.
@visibleForTesting
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
@visibleForTesting
LiquidWindowControls controlsFromNative(NativeWindowControls controls) =>
    LiquidWindowControls.sanitized(
      leading: controls.leading,
      top: controls.top,
    );

/// Interface config → native config.
@visibleForTesting
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
