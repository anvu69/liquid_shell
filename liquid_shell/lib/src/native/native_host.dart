import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// The process-wide link to the window's native chrome (spec P2 §7.2).
///
/// A window has one native chrome. Shells [claim] it; the most recent
/// claim owns it, and only the owner's config reaches the platform. When
/// the owner releases, the previous claim owns it again; with no claim
/// left the chrome goes dormant.
final class NativeChromeHost extends ChangeNotifier {
  NativeChromeHost._();

  /// The host. Replaced by [debugReset].
  static NativeChromeHost instance = NativeChromeHost._();

  /// Drops every claim and subscription. Tests only, through
  /// `debugResetLiquidNative`.
  static void debugReset() {
    instance._close();
    instance = NativeChromeHost._();
  }

  /// Keys of the debug logs already printed. Static, not per host, so the
  /// hosts that tests replace do not print them again. Statics live as long
  /// as the isolate: a log prints once per run (again after a hot
  /// restart) and once per test file.
  static final Set<String> _logged = {};

  /// Prints [message] in debug builds, once per process for [key].
  static void debugLogOnce(String key, String message) {
    if (kDebugMode && _logged.add(key)) debugPrint(message);
  }

  /// Re-arms the once-only debug logs. Tests only.
  @visibleForTesting
  static void debugResetLogs() => _logged.clear();

  final ValueNotifier<LiquidNativeShellState?> _state = ValueNotifier(null);
  final List<NativeChromeClaim> _claims = [];
  StreamSubscription<LiquidNativeEvent>? _events;
  LiquidNativeChromeConfig? _sent;
  bool _started = false;

  /// The platform's report; null until the first answer (pending).
  ValueListenable<LiquidNativeShellState?> get state => _state;

  /// Asks the platform once. Platforms without native chrome answer
  /// synchronously, so a shell there never waits.
  void _start() {
    if (_started) return;
    _started = true;
    final platform = LiquidShellPlatform.instance;
    if (!platform.supportsNativeChrome) {
      _state.value = LiquidNativeShellState.unavailable;
      return;
    }
    _events = platform.nativeEvents.listen(_onEvent);
    unawaited(
      platform.attachNativeChrome().then((state) {
        if (!_started) return;
        _setState(state);
        // After a hot restart the native chrome still shows the old
        // config: send the owner's again, whole.
        _sendOwner(force: true);
      }),
    );
  }

  void _setState(LiquidNativeShellState state) {
    _state.value = state;
    if (!state.installed &&
        state.unavailableReason == LiquidNativeUnavailableReason.notEnabled) {
      debugLogOnce(
        'notEnabled',
        'liquid_shell: native iOS chrome is available on this device but '
            'not enabled; add <key>LiquidShellNativeChrome</key><true/> to '
            'Info.plist to use it.',
      );
    }
  }

  void _onEvent(LiquidNativeEvent event) {
    switch (event) {
      case LiquidNativeStateChanged(:final state):
        _setState(state);
        // After a scene reconnect the platform builds a fresh controller;
        // its first layout reports the state, which may equal the last
        // one. The iOS installer already applied the last config it got;
        // forget what was sent and send the owner's config whole anyway
        // (tabs, then the selection, in one apply), so the native chrome
        // matches this shell whatever the platform kept. State reports are
        // rare and the native apply is idempotent.
        _sent = null;
        _sendOwner(force: true);
      case LiquidWindowControlsChanged():
        break;
      case LiquidNativeSearchTextChanged() ||
          LiquidNativeSearchActiveChanged() ||
          LiquidNativeSearchSubmitted() ||
          LiquidNativeSearchFieldChanged() ||
          LiquidNativeBackTapped():
        if (_claims.isNotEmpty) _claims.last._onEvent(event);
      case LiquidNativeDestinationTapped() ||
          LiquidNativeTrailingTapped() ||
          LiquidNativeFooterTapped():
        if (_claims.isNotEmpty) _claims.last._onEvent(event);
    }
  }

  /// Registers a shell. The newest claim owns the native chrome.
  NativeChromeClaim claim(ValueChanged<LiquidNativeEvent> onEvent) {
    _start();
    final claim = NativeChromeClaim._(this, onEvent);
    _claims.add(claim);
    notifyListeners();
    return claim;
  }

  /// Whether [claim] owns the native chrome.
  bool isOwner(NativeChromeClaim claim) =>
      _claims.isNotEmpty && identical(_claims.last, claim);

  void _release(NativeChromeClaim claim) {
    final wasOwner = isOwner(claim);
    _claims.remove(claim);
    if (wasOwner) _sendOwner(force: false);
    notifyListeners();
  }

  void _sendOwner({required bool force}) {
    final config = _claims.isEmpty
        ? LiquidNativeChromeConfig.dormant
        : _claims.last._config;
    if (config != null) _send(config, force: force);
  }

  void _send(LiquidNativeChromeConfig config, {required bool force}) {
    final state = _state.value;
    // Nothing installed: nobody listens natively.
    if (state == null || !state.installed) return;
    if (!force && config == _sent) return;
    _sent = config;
    unawaited(LiquidShellPlatform.instance.updateNativeChrome(config));
  }

  /// Forgets every claim and stops listening. Shells still holding a claim
  /// can release it safely afterwards; nothing here is disposed.
  void _close() {
    _started = false;
    unawaited(_events?.cancel());
    _events = null;
    _claims.clear();
  }
}

/// One shell's claim on the native chrome.
final class NativeChromeClaim {
  NativeChromeClaim._(this._host, this._handler);

  final NativeChromeHost _host;
  final ValueChanged<LiquidNativeEvent> _handler;
  LiquidNativeChromeConfig? _config;
  bool _released = false;

  /// Whether this claim owns the native chrome.
  bool get isOwner => !_released && _host.isOwner(this);

  /// Sets this shell's config; sent when this claim owns the chrome and it
  /// changed, or always with [force] (re-sync after a refused selection).
  void update(LiquidNativeChromeConfig config, {bool force = false}) {
    if (_released) return;
    _config = config;
    if (isOwner) _host._send(config, force: force);
  }

  /// Shows or hides the native sidebar, when this claim owns it.
  void setSidebarVisible({required bool visible}) {
    if (!isOwner) return;
    unawaited(
      LiquidShellPlatform.instance.setNativeSidebarVisible(visible: visible),
    );
  }

  /// Gives the chrome back. Idempotent.
  void release() {
    if (_released) return;
    _released = true;
    _host._release(this);
  }

  void _onEvent(LiquidNativeEvent event) {
    if (!_released) _handler(event);
  }
}
