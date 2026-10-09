import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// The process-wide window-controls value (spec P2 §8.2).
///
/// Starts when the first user acquires it and stops when the last releases
/// it, like the glass signals. Values arrive two ways: pushed by native
/// chrome on every layout, and read after every metrics change (the only
/// way while native chrome is not installed).
final class WindowControlsSource with WidgetsBindingObserver {
  WindowControlsSource._();

  /// The source. Replaced by [debugReset].
  static WindowControlsSource instance = WindowControlsSource._();

  /// Drops listeners and subscriptions. Tests only, through
  /// `debugResetLiquidNative`.
  static void debugReset() {
    instance._stop();
    instance = WindowControlsSource._();
  }

  final ValueNotifier<LiquidWindowControls> _value = ValueNotifier(
    LiquidWindowControls.zero,
  );
  int _users = 0;
  StreamSubscription<LiquidNativeEvent>? _events;

  /// The latest value.
  ValueListenable<LiquidWindowControls> get value => _value;

  /// Starts the source on the first call.
  void acquire() {
    if (_users++ > 0) return;
    final platform = LiquidShellPlatform.instance;
    if (!platform.supportsNativeChrome) return;
    _events = platform.nativeEvents.listen((event) {
      if (event is LiquidWindowControlsChanged) _value.value = event.controls;
    });
    WidgetsBinding.instance.addObserver(this);
    unawaited(_read());
  }

  /// Stops the source after the last call.
  void release() {
    if (_users == 0 || --_users > 0) return;
    _stop();
  }

  void _stop() {
    _users = 0;
    unawaited(_events?.cancel());
    if (_events != null) WidgetsBinding.instance.removeObserver(this);
    _events = null;
  }

  @override
  void didChangeMetrics() {
    // The corner region settles after the resize: read after the frame.
    SchedulerBinding.instance.addPostFrameCallback((_) => unawaited(_read()));
  }

  Future<void> _read() async {
    final controls = await LiquidShellPlatform.instance.readWindowControls();
    if (_events != null) _value.value = controls;
  }
}

/// Moves [child] past the iPadOS 26 window controls when its row sits in
/// their band: a start padding of `LiquidWindowControls.indentFor(rowTop:)`
/// (spec P2 §8.3).
///
/// Use it on a page's top row, for example a large title. Works anywhere,
/// inside a shell or not. Animates over 200ms, and jumps when the platform
/// asks to reduce motion. Zero (no padding) on every other platform.
class LiquidWindowControlsClearance extends StatefulWidget {
  /// Creates the clearance.
  const LiquidWindowControlsClearance({
    required this.child,
    this.rowTop = 0,
    super.key,
  });

  /// The row.
  final Widget child;

  /// Distance of the row's top edge below `MediaQuery.paddingOf(context).top`.
  final double rowTop;

  @override
  State<LiquidWindowControlsClearance> createState() =>
      _LiquidWindowControlsClearanceState();
}

class _LiquidWindowControlsClearanceState
    extends State<LiquidWindowControlsClearance> {
  final WindowControlsSource _source = WindowControlsSource.instance;

  @override
  void initState() {
    super.initState();
    _source.acquire();
  }

  @override
  void dispose() {
    _source.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<LiquidWindowControls>(
        valueListenable: _source.value,
        builder: (context, controls, child) {
          final padding = EdgeInsetsDirectional.only(
            start: controls.indentFor(rowTop: widget.rowTop),
          );
          if (MediaQuery.disableAnimationsOf(context)) {
            return Padding(padding: padding, child: child);
          }
          return AnimatedPadding(
            padding: padding,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: child,
          );
        },
        child: widget.child,
      );
}
