import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Consecutive slow windows that demote liquid to frosted (spec §7.4).
const kLiquidSlowWindows = 3;

/// Frames per measuring window.
const kLiquidWindowFrames = 60;

/// The nearest-rank 90th percentile of [durations]; zero when empty.
Duration p90(List<Duration> durations) {
  if (durations.isEmpty) return Duration.zero;
  final sorted = [...durations]..sort();
  final rank = (0.9 * sorted.length).ceil() - 1;
  return sorted[rank.clamp(0, sorted.length - 1)];
}

/// Whether the last [kLiquidSlowWindows] window p90s are all above
/// 1.25 × [budget].
bool liquidFramesTooSlow(List<Duration> windowP90s, Duration budget) {
  if (windowP90s.length < kLiquidSlowWindows) return false;
  final limit = budget * 1.25;
  return windowP90s
      .sublist(windowP90s.length - kLiquidSlowWindows)
      .every((p) => p > limit);
}

/// Test hook: runs the guard in debug builds too.
@visibleForTesting
bool debugLiquidFrameGuardEnabled = false;

/// Watches raster times while liquid glass is on screen and turns
/// [value] (`slowFrames`) on for the rest of the process when they stay
/// over budget (spec §7.4). Sticky: frosted is cheaper, so switching
/// back would oscillate.
class LiquidFrameGuard extends ValueNotifier<bool> {
  LiquidFrameGuard._() : super(false);

  /// The single instance.
  static final instance = LiquidFrameGuard._();

  int _users = 0;
  bool _subscribed = false;
  bool _logged = false;
  final List<Duration> _window = [];
  // The p90s of the last windows, all measured against [_p90Budget].
  final List<Duration> _p90s = [];
  Duration? _p90Budget;

  bool get _enabled =>
      kProfileMode || kReleaseMode || debugLiquidFrameGuardEnabled;

  /// The frame budget of the first display (60 Hz when unknown).
  ///
  /// Never below 1/60 s: an app capped at 60 Hz on a 120 Hz ProMotion
  /// panel still reports 120 Hz, and must not be demoted for that.
  Duration get budget {
    final views = SchedulerBinding.instance.platformDispatcher.views;
    final hz = views.isEmpty ? 60.0 : views.first.display.refreshRate;
    final micros = (1e6 / (hz > 0 ? hz : 60)).round();
    return Duration(microseconds: micros < 16667 ? 16667 : micros);
  }

  /// One liquid surface is on screen.
  void acquire() {
    _users++;
    _update();
  }

  /// One liquid surface left the screen.
  void release() {
    if (_users > 0) _users--;
    _update();
  }

  void _update() {
    final wanted = _enabled && _users > 0 && !value;
    if (wanted && !_subscribed) {
      SchedulerBinding.instance.addTimingsCallback(_onTimings);
      _subscribed = true;
    } else if (!wanted && _subscribed) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
      _subscribed = false;
      // "Consecutive" means while liquid is shown: windows from before a
      // detach do not carry over to the next attach.
      _window.clear();
      _p90s.clear();
    }
  }

  void _onTimings(List<ui.FrameTiming> timings) =>
      addRasterTimes([for (final t in timings) t.rasterDuration]);

  /// Feeds raster times; the timings callback calls it, and so may tests.
  @visibleForTesting
  void addRasterTimes(Iterable<Duration> rasters) {
    if (value) return;
    for (final raster in rasters) {
      _window.add(raster);
      if (_window.length < kLiquidWindowFrames) continue;
      // Read once per window. Windows measured at another refresh rate
      // are not comparable, so a change starts the run again.
      final windowBudget = budget;
      if (windowBudget != _p90Budget) {
        _p90s.clear();
        _p90Budget = windowBudget;
      }
      _p90s.add(p90(_window));
      _window.clear();
      if (_p90s.length > kLiquidSlowWindows) _p90s.removeAt(0);
      if (liquidFramesTooSlow(_p90s, windowBudget)) {
        if (kDebugMode && !_logged) {
          _logged = true;
          debugPrint(
            'liquid_shell: raster p90 ${_p90s.last.inMicroseconds}µs over '
            'a ${windowBudget.inMicroseconds}µs budget; drawing frosted.',
          );
        }
        value = true;
        _update();
        return;
      }
    }
  }

  /// Number of liquid surfaces on screen, for tests.
  @visibleForTesting
  int get debugUsers => _users;

  /// Whether the timings callback is registered, for tests.
  @visibleForTesting
  bool get debugSubscribed => _subscribed;

  /// Test hook: forgets everything. Called by
  /// `debugResetLiquidGlassSignals` (not annotated `@visibleForTesting`,
  /// because that function lives in `lib/`).
  void debugReset() {
    if (_subscribed) {
      SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    }
    _subscribed = false;
    _users = 0;
    _logged = false;
    _window.clear();
    _p90s.clear();
    _p90Budget = null;
    value = false;
  }
}
