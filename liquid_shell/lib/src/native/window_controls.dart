import 'dart:async';
import 'dart:ui' show FlutterView;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
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

/// Moves [child] past the iPadOS 26 window controls when its row is under
/// them: a start padding of `LiquidWindowControls.indentFor(rowTop:)`
/// (spec P2 §8.3).
///
/// The cluster sits in the window's top-leading corner, so a row is under
/// it only when both hold:
/// - vertically, [rowTop] is above `LiquidWindowControls.top`;
/// - horizontally, the row's start edge is less than
///   `LiquidWindowControls.leading` from the window's safe-area start edge.
///   A page beside a tiled sidebar starts past the cluster and never moves.
///
/// The horizontal position is measured after layout, so a row that mounts
/// under a non-zero cluster settles on its second frame, without animating.
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

  /// The row's start edge from the window's safe-area start edge; null
  /// until the first layout has been measured.
  double? _start;

  /// The first measurement applies at once instead of animating.
  bool _jump = false;
  bool _measureScheduled = false;
  late FlutterView _view;
  TextDirection _direction = TextDirection.ltr;

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

  /// Measures the row's position after the frame (never during layout,
  /// when ancestors may not have placed it yet).
  void _scheduleMeasure() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      _jump = false;
      final box = mounted ? context.findRenderObject() : null;
      if (box is! RenderBox || !box.attached || !box.hasSize) return;
      final start = _startOf(box);
      if (start != _start) {
        setState(() {
          _jump = _start == null;
          _start = start;
        });
      }
    });
  }

  double _startOf(RenderBox box) {
    final ratio = _view.devicePixelRatio;
    final padding = _view.padding;
    if (_direction == TextDirection.rtl) {
      final right = box.localToGlobal(Offset(box.size.width, 0)).dx;
      return _view.physicalSize.width / ratio - right - padding.right / ratio;
    }
    return box.localToGlobal(Offset.zero).dx - padding.left / ratio;
  }

  @override
  Widget build(BuildContext context) {
    _view = View.of(context);
    _direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
    _scheduleMeasure();
    return _LayoutProbe(
      onLayout: _scheduleMeasure,
      child: ValueListenableBuilder<LiquidWindowControls>(
        valueListenable: _source.value,
        builder: (context, controls, child) {
          // Unmeasured: assume under the cluster (the common top row).
          final start = _start;
          final under = start == null || start < controls.leading;
          final padding = EdgeInsetsDirectional.only(
            start: under ? controls.indentFor(rowTop: widget.rowTop) : 0,
          );
          if (MediaQuery.disableAnimationsOf(context)) {
            return Padding(padding: padding, child: child);
          }
          return AnimatedPadding(
            padding: padding,
            duration: _jump ? Duration.zero : const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Calls [onLayout] after every layout of its child: a row moves when its
/// constraints change (a sidebar tiles beside the body, the window resizes).
class _LayoutProbe extends SingleChildRenderObjectWidget {
  const _LayoutProbe({required this.onLayout, required super.child});

  final VoidCallback onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLayoutProbe(onLayout);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderLayoutProbe renderObject,
  ) => renderObject.onLayout = onLayout;
}

class _RenderLayoutProbe extends RenderProxyBox {
  _RenderLayoutProbe(this.onLayout);

  VoidCallback onLayout;

  @override
  void performLayout() {
    super.performLayout();
    onLayout();
  }
}
