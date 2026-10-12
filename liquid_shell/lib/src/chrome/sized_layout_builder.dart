import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A [LayoutBuilder] that also answers intrinsic sizes and dry layout, from
/// [sizeFor]: the size the builder's widget takes under some constraints.
///
/// A plain `LayoutBuilder` throws when an ancestor asks for intrinsic sizes
/// (`IntrinsicWidth`, `IntrinsicHeight`, an `AlertDialog`'s content). As
/// `FitLabelBox` does for a tab label, the render object answers them
/// itself; here from the same pure geometry the builder lays out, so the
/// answer and the layout cannot disagree. The dry baseline comes from
/// [baselineFor] the same way (a `LayoutBuilder` throws there too, in
/// debug).
class SizedLayoutBuilder extends SingleChildRenderObjectWidget {
  /// Creates the builder; [sizeFor] must be pure and match [builder]'s size.
  SizedLayoutBuilder({
    required this.sizeFor,
    required LayoutWidgetBuilder builder,
    this.baselineFor,
    super.key,
  }) : super(child: LayoutBuilder(builder: builder));

  /// The size under some constraints, before [BoxConstraints.constrain].
  final Size Function(BoxConstraints constraints) sizeFor;

  /// The distance to [TextBaseline] under some constraints, as the
  /// builder's widget lays it out; null when it has none. Without it the dry
  /// baseline is null.
  final double? Function(BoxConstraints constraints, TextBaseline baseline)?
  baselineFor;

  @override
  RenderSizedLayout createRenderObject(BuildContext context) =>
      RenderSizedLayout(sizeFor, baselineFor);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSizedLayout renderObject,
  ) {
    renderObject
      ..sizeFor = sizeFor
      ..baselineFor = baselineFor;
  }
}

/// The render object of [SizedLayoutBuilder]: lays out its child as a proxy
/// does, and answers intrinsics and dry layout from [sizeFor].
class RenderSizedLayout extends RenderProxyBox {
  /// Creates the render object.
  RenderSizedLayout(this._sizeFor, [this._baselineFor]);

  /// The dry baseline under some constraints (see
  /// [SizedLayoutBuilder.baselineFor]).
  double? Function(BoxConstraints constraints, TextBaseline baseline)?
  get baselineFor => _baselineFor;
  double? Function(BoxConstraints constraints, TextBaseline baseline)?
  _baselineFor;
  set baselineFor(
    double? Function(BoxConstraints constraints, TextBaseline baseline)? value,
  ) {
    if (identical(value, _baselineFor)) return;
    _baselineFor = value;
    // Drops the cached dry baselines.
    markNeedsLayout();
  }

  /// The size under some constraints.
  Size Function(BoxConstraints constraints) get sizeFor => _sizeFor;
  Size Function(BoxConstraints constraints) _sizeFor;
  set sizeFor(Size Function(BoxConstraints constraints) value) {
    if (identical(value, _sizeFor)) return;
    _sizeFor = value;
    // Drops the cached intrinsics; the child rebuilds with the same inputs.
    markNeedsLayout();
  }

  Size _at({double width = double.infinity, double height = double.infinity}) =>
      sizeFor(BoxConstraints(maxWidth: width, maxHeight: height));

  @override
  double computeMinIntrinsicWidth(double height) => _at(height: height).width;

  @override
  double computeMaxIntrinsicWidth(double height) => _at(height: height).width;

  @override
  double computeMinIntrinsicHeight(double width) => _at(width: width).height;

  @override
  double computeMaxIntrinsicHeight(double width) => _at(width: width).height;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.constrain(sizeFor(constraints));

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) => baselineFor?.call(constraints, baseline);
}
