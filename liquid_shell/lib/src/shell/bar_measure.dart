import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Reports the height of [child] once it has been stable for two frames.
///
/// It never calls back during layout, and never once per frame while the
/// bar animates: a new height must repeat on the next frame first. It only
/// reports when the height or [tag] changes, so there is no loop. A new
/// [tag] (size class or text scale) re-reports even an unchanged height, so
/// every tag gets its own measurement.
class BarMeasure extends SingleChildRenderObjectWidget {
  /// Creates a reporter.
  const BarMeasure({
    required this.tag,
    required this.onHeight,
    required super.child,
    super.key,
  });

  /// What the measurement belongs to.
  final Object tag;

  /// Receives the settled height.
  final ValueChanged<double> onHeight;

  @override
  RenderBarMeasure createRenderObject(BuildContext context) =>
      RenderBarMeasure(tag, onHeight);

  @override
  void updateRenderObject(BuildContext context, RenderBarMeasure renderObject) {
    renderObject
      ..tag = tag
      ..onHeight = onHeight;
  }
}

/// Render object of [BarMeasure].
class RenderBarMeasure extends RenderProxyBox {
  /// Creates the render object.
  RenderBarMeasure(this._tag, this.onHeight);

  /// Receives the settled height.
  ValueChanged<double> onHeight;

  (Object, double)? _reported;
  double? _settling;
  bool _checking = false;

  Object _tag;

  /// What the measurement belongs to.
  Object get tag => _tag;
  set tag(Object value) {
    if (value == _tag) return;
    _tag = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    super.performLayout();
    if ((_tag, size.height) == _reported || _checking) return;
    _checking = true;
    _settling = null;
    SchedulerBinding.instance.addPostFrameCallback(_check);
  }

  void _check(Duration _) {
    if (!attached) {
      _checking = false;
      return;
    }
    final height = size.height;
    if (height != _settling) {
      // Changed, or the first check: look again on the next frame.
      _settling = height;
      SchedulerBinding.instance
        ..addPostFrameCallback(_check)
        ..scheduleFrame();
      return;
    }
    _checking = false;
    final reported = (_tag, height);
    if (reported == _reported) return;
    _reported = reported;
    onHeight(height);
  }
}
