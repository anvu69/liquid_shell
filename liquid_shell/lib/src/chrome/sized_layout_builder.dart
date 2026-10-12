import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A [LayoutBuilder] that also answers intrinsic sizes and dry layout, from
/// [sizeFor]: the size the builder's widget takes under some constraints.
///
/// A plain `LayoutBuilder` throws when an ancestor asks for intrinsic sizes
/// (`IntrinsicWidth`, `IntrinsicHeight`, an `AlertDialog`'s content). As
/// `FitLabelBox` does for a tab label, the render object answers them
/// itself; here from the same pure geometry the builder lays out, so the
/// answer and the layout cannot disagree.
class SizedLayoutBuilder extends SingleChildRenderObjectWidget {
  /// Creates the builder; [sizeFor] must be pure and match [builder]'s size.
  SizedLayoutBuilder({
    required this.sizeFor,
    required LayoutWidgetBuilder builder,
    super.key,
  }) : super(child: LayoutBuilder(builder: builder));

  /// The size under some constraints, before [BoxConstraints.constrain].
  final Size Function(BoxConstraints constraints) sizeFor;

  @override
  RenderSizedLayout createRenderObject(BuildContext context) =>
      RenderSizedLayout(sizeFor);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSizedLayout renderObject,
  ) {
    renderObject.sizeFor = sizeFor;
  }
}

/// The render object of [SizedLayoutBuilder]: lays out its child as a proxy
/// does, and answers intrinsics and dry layout from [sizeFor].
class RenderSizedLayout extends RenderProxyBox {
  /// Creates the render object.
  RenderSizedLayout(this._sizeFor);

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
}
