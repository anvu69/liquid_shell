import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The smallest size, in logical pixels, a narrow tab label shrinks to
/// before it ellipsizes (Q18).
const double kLiquidMinLabelSize = 10;

/// A one-line label for a narrow tab cell that fits its width in three
/// steps (Q18):
///
/// 1. it asks for [slack] extra width (the cell's side padding) and gives it
///    up first;
/// 2. it shrinks, as a uniform scale of the drawn [Text], down to
///    [kLiquidMinLabelSize] (or its own size when that is smaller: it never
///    grows);
/// 3. only then does it ellipsize, at that minimum.
///
/// The size is measured on [style] after the ambient text scaler, so the
/// label is measured exactly as it is drawn. The box keeps the unscaled line
/// height, so fitting never changes the height of the bar. Unlike a
/// `LayoutBuilder`, it answers intrinsic sizes, which the bar's
/// `IntrinsicHeight` needs.
class FitLabel extends StatelessWidget {
  /// Creates a fitted label.
  const FitLabel(this.text, {required this.style, this.slack = 0, super.key});

  /// The label.
  final String text;

  /// The label style (merged over the ambient `DefaultTextStyle`).
  final TextStyle? style;

  /// Extra width the label asks for and gives up before it shrinks.
  final double slack;

  @override
  Widget build(BuildContext context) {
    final size = DefaultTextStyle.of(context).style.merge(style).fontSize ?? 14;
    final drawn = MediaQuery.textScalerOf(context).scale(size);
    return FitLabelBox(
      minScale: drawn <= kLiquidMinLabelSize ? 1 : kLiquidMinLabelSize / drawn,
      slack: slack,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

/// Lays out and paints a one-line text child the way [FitLabel] describes.
class FitLabelBox extends SingleChildRenderObjectWidget {
  /// Creates the box.
  const FitLabelBox({
    required this.minScale,
    required this.slack,
    required Widget super.child,
    super.key,
  });

  /// The smallest scale the child is painted at, in (0, 1].
  final double minScale;

  /// Extra width asked for and given up first.
  final double slack;

  @override
  RenderFitLabel createRenderObject(BuildContext context) =>
      RenderFitLabel(minScale: minScale, slack: slack);

  @override
  void updateRenderObject(BuildContext context, RenderFitLabel renderObject) {
    renderObject
      ..minScale = minScale
      ..slack = slack;
  }
}

/// The render object of [FitLabelBox].
class RenderFitLabel extends RenderBox
    with RenderObjectWithChildMixin<RenderBox> {
  /// Creates the render object.
  RenderFitLabel({required double minScale, required double slack})
    : assert(minScale > 0 && minScale <= 1, 'minScale is in (0, 1]'),
      assert(slack >= 0, 'slack is not negative'),
      _minScale = minScale,
      _slack = slack;

  /// The smallest scale the child is painted at.
  double get minScale => _minScale;
  double _minScale;
  set minScale(double value) {
    if (value == _minScale) return;
    _minScale = value;
    markNeedsLayout();
  }

  /// Extra width asked for and given up first.
  double get slack => _slack;
  double _slack;
  set slack(double value) {
    if (value == _slack) return;
    _slack = value;
    markNeedsLayout();
  }

  /// The scale the child is painted at after the last layout.
  double get scale => _scale;
  double _scale = 1;

  Matrix4 _transform = Matrix4.identity();
  final _layer = LayerHandle<TransformLayer>();

  ({double scale, double width, BoxConstraints child}) _fit(
    double maxWidth,
    RenderBox child,
  ) {
    final natural = child.getMaxIntrinsicWidth(double.infinity);
    // Unbounded child constraints while the text fits, so rounding can never
    // trigger the ellipsis.
    if (natural + slack <= maxWidth) {
      return (scale: 1, width: natural + slack, child: const BoxConstraints());
    }
    if (natural <= maxWidth) {
      return (scale: 1, width: maxWidth, child: const BoxConstraints());
    }
    final fitting = maxWidth / natural;
    if (fitting >= minScale) {
      return (scale: fitting, width: maxWidth, child: const BoxConstraints());
    }
    return (
      scale: minScale,
      width: maxWidth,
      child: BoxConstraints(maxWidth: maxWidth / minScale),
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      (child?.getMinIntrinsicWidth(height) ?? 0) * minScale;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      (child?.getMaxIntrinsicWidth(height) ?? 0) + slack;

  // One line: the height does not depend on the width.
  @override
  double computeMinIntrinsicHeight(double width) =>
      child?.getMinIntrinsicHeight(double.infinity) ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) =>
      child?.getMaxIntrinsicHeight(double.infinity) ?? 0;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    final fit = _fit(constraints.maxWidth, child);
    final height = child.getDryLayout(fit.child).height;
    return constraints.constrain(Size(fit.width, height));
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      _scale = 1;
      _transform = Matrix4.identity();
      return;
    }
    final fit = _fit(constraints.maxWidth, child);
    child.layout(fit.child, parentUsesSize: true);
    size = constraints.constrain(Size(fit.width, child.size.height));
    _scale = fit.scale;
    final drawn = child.size * _scale;
    _transform = Matrix4.translationValues(
      (size.width - drawn.width) / 2,
      (size.height - drawn.height) / 2,
      0,
    )..scaleByDouble(_scale, _scale, 1, 1);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) {
      _layer.layer = null;
      return;
    }
    _layer.layer = context.pushTransform(
      needsCompositing,
      offset,
      _transform,
      (context, offset) => context.paintChild(child, offset),
      oldLayer: _layer.layer,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.multiply(_transform);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintTransform(
      transform: _transform,
      position: position,
      hitTest: (result, position) => child.hitTest(result, position: position),
    );
  }

  @override
  void dispose() {
    _layer.layer = null;
    super.dispose();
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('minScale', minScale))
      ..add(DoubleProperty('slack', slack))
      ..add(DoubleProperty('scale', scale));
  }
}
