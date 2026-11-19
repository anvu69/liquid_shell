import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// The process-wide link to the window's native chrome.
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
  // The hand-over epoch every config goes out with (spec 2026-11-18
  // applied-epoch §2.1). 0 is never sent: a state that reports 0 does not
  // echo epochs. Bumped only when a hand-over starts (an owner change, an
  // engaged flip), never by the forced resend after a state.
  int _epoch = 1;
  // The last config sent, never forgotten (unlike [_sent]): its `engaged`
  // tells an engaged flip from a resend.
  LiquidNativeChromeConfig? _last;
  // The last config sent with each recent epoch: what native shows for the
  // epoch its state reports.
  final Map<int, LiquidNativeChromeConfig> _byEpoch = {};
  // The platform call that sent [_sent]: a deduped send answers it, so a
  // caller waiting for native to have the config still waits for it.
  Future<void>? _delivered;
  bool _started = false;

  /// The platform's report; null until the first answer (pending).
  ValueListenable<LiquidNativeShellState?> get state => _state;

  /// The last config sent with the epoch the platform reports applied
  /// ([LiquidNativeShellState.appliedEpoch]); null when the platform does
  /// not echo epochs, or the config is no longer known (a hot restart, an
  /// epoch older than the ones kept).
  ///
  /// A prediction, not a confirmation: native confirms the epoch only, and
  /// a later config of the same epoch (a page change, a `hidden` toggle)
  /// may still be on its way.
  LiquidNativeChromeConfig? get appliedConfig {
    final epoch = _state.value?.appliedEpoch ?? 0;
    return epoch == 0 ? null : _byEpoch[epoch];
  }

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
        // A hot restart: native still has the old run's epoch; never
        // stamp one it could mistake for it.
        if (state.appliedEpoch >= _epoch) _epoch = state.appliedEpoch + 1;
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
        // Then the owner: what the config does not carry (the search
        // text) is the shell's to replay.
        if (_claims.isNotEmpty) _claims.last._onEvent(event);
      case LiquidWindowControlsChanged():
        break;
      case LiquidNativeSearchTextChanged() ||
          LiquidNativeSearchActiveChanged() ||
          LiquidNativeSearchSubmitted() ||
          LiquidNativeSearchScopeChanged() ||
          LiquidNativeSearchFieldChanged() ||
          LiquidNativeBackTapped() ||
          LiquidNativePopToPage() ||
          LiquidNativePageActionTapped():
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
    // A new owner: a new hand-over.
    _epoch++;
    notifyListeners();
    return claim;
  }

  /// The claim that owns the native chrome; null with none.
  NativeChromeClaim? get owner => _claims.isEmpty ? null : _claims.last;

  /// Whether [claim] owns the native chrome.
  bool isOwner(NativeChromeClaim claim) =>
      _claims.isNotEmpty && identical(_claims.last, claim);

  void _release(NativeChromeClaim claim) {
    final wasOwner = isOwner(claim);
    _claims.remove(claim);
    if (wasOwner) {
      // The previous claim (or dormant) owns it again: a new hand-over.
      _epoch++;
      _sendOwner(force: false);
    }
    claim._releaseEpoch = _epoch;
    notifyListeners();
  }

  void _sendOwner({required bool force}) {
    final owner = _claims.isEmpty ? null : _claims.last;
    final config = owner == null
        ? LiquidNativeChromeConfig.dormant
        : owner._config;
    if (config != null) unawaited(_send(config, force: force, owner: owner));
  }

  /// The platform call that delivers [config]: this send's, or the earlier
  /// one's when [config] was already sent; null when nothing listens.
  Future<void>? _send(
    LiquidNativeChromeConfig config, {
    required bool force,
    NativeChromeClaim? owner,
  }) {
    final state = _state.value;
    // Nothing installed: nobody listens natively.
    if (state == null || !state.installed) return null;
    final last = _last;
    if (last != null && last.engaged != config.engaged) _epoch++;
    final stamped = config.copyWithEpoch(_epoch);
    if (!force && stamped == _sent) return _delivered;
    _sent = stamped;
    _last = stamped;
    _byEpoch[_epoch] = stamped;
    _byEpoch.removeWhere((epoch, _) => epoch < _epoch - _keptEpochs);
    owner?._sentEpoch = _epoch;
    owner?._sentEngaged = config.engaged;
    final sent = LiquidShellPlatform.instance.updateNativeChrome(stamped);
    unawaited(sent);
    return _delivered = sent;
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

/// How many epochs before the current one [NativeChromeHost.appliedConfig]
/// still knows: native is at most a few hand-overs behind.
const int _keptEpochs = 8;

/// One shell's claim on the native chrome.
final class NativeChromeClaim {
  NativeChromeClaim._(this._host, this._handler);

  final NativeChromeHost _host;
  final ValueChanged<LiquidNativeEvent> _handler;
  LiquidNativeChromeConfig? _config;
  bool _released = false;
  int? _sentEpoch;
  bool? _sentEngaged;
  int? _releaseEpoch;

  /// The epoch of the last config sent for this claim; null until one is.
  int? get epoch => _sentEpoch;

  /// The epoch of the config that replaced this claim's engaged one: the
  /// next owner's or the dormant one after [release], or this claim's own
  /// disengaged config. Null while that config is not sent yet (or this
  /// claim's last config is engaged): native has not been asked to let go.
  int? get releaseEpoch =>
      _releaseEpoch ?? (_sentEngaged == false ? _sentEpoch : null);

  /// Whether this claim owns the native chrome.
  bool get isOwner => !_released && _host.isOwner(this);

  /// Sets this shell's config; sent when this claim owns the chrome and it
  /// changed, or always with [force] (re-sync after a refused selection).
  /// Returns the platform call that delivers it (this one's, or the earlier
  /// one's when unchanged): it completes once the platform has applied the
  /// config. Null when it is not sent.
  Future<void>? update(LiquidNativeChromeConfig config, {bool force = false}) {
    if (_released) return null;
    _config = config;
    return isOwner ? _host._send(config, force: force, owner: this) : null;
  }

  /// Shows or hides the native sidebar, when this claim owns it.
  void setSidebarVisible({required bool visible}) {
    if (!isOwner) return;
    unawaited(
      LiquidShellPlatform.instance.setNativeSidebarVisible(visible: visible),
    );
  }

  /// Sets the native search text, when this claim owns the chrome.
  void setSearchText(String text) {
    if (!isOwner) return;
    unawaited(LiquidShellPlatform.instance.setNativeSearchText(text));
  }

  /// Activates or deactivates the native search, when this claim owns it.
  void setSearchActive({required bool active}) {
    if (!isOwner) return;
    unawaited(
      LiquidShellPlatform.instance.setNativeSearchActive(active: active),
    );
  }

  /// Selects scope [index] in the native scope bar, when this claim owns
  /// the chrome.
  void setSearchScope(int index) {
    if (!isOwner) return;
    unawaited(LiquidShellPlatform.instance.setNativeSearchScope(index));
  }

  /// Puts the native search keyboard away and keeps the search active,
  /// when this claim owns the chrome.
  void dismissSearchKeyboard() {
    if (!isOwner) return;
    unawaited(LiquidShellPlatform.instance.dismissNativeSearchKeyboard());
  }

  /// Sends the top page's scroll offset of [tab], when this claim owns it.
  void setPageScroll({required int tab, required double offset}) {
    if (!isOwner) return;
    unawaited(
      LiquidShellPlatform.instance.setNativePageScroll(
        tab: tab,
        offset: offset,
      ),
    );
  }

  /// Sends [tab]'s body scroll offset for the native minimize, when this
  /// claim owns the chrome.
  void setMinimizeScroll({required int tab, required double offset}) {
    if (!isOwner) return;
    unawaited(
      LiquidShellPlatform.instance.setNativeMinimizeScroll(
        tab: tab,
        offset: offset,
      ),
    );
  }

  /// Expands the minimized native bar, when this claim owns the chrome.
  void expandTabBar() {
    if (!isOwner) return;
    unawaited(LiquidShellPlatform.instance.expandNativeTabBar());
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
