import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_shell/src/glass/drift_guard.dart';
import 'package:liquid_shell/src/glass/liquid_optics.dart';
import 'package:liquid_shell/src/glass/shader_program.dart';

/// Builds the filter of one liquid surface from its [shader], whose
/// uniforms are already set, and the logical blur sigma.
typedef LiquidFilterFactory =
    ui.ImageFilter Function(ui.FragmentShader shader, double blurSigma);

/// The production filter: the engine blur, then the lens (spec §3.3).
ui.ImageFilter liquidLensFilter(ui.FragmentShader shader, double blurSigma) {
  final lens = ui.ImageFilter.shader(shader);
  if (blurSigma <= 0) return lens;
  return ui.ImageFilter.compose(
    outer: lens,
    inner: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
  );
}

/// Test hook replacing [liquidLensFilter]: `ImageFilter.shader` throws
/// without Impeller, so widget tests build a blur instead.
@visibleForTesting
LiquidFilterFactory? debugLiquidFilterFactory;

/// The liquid lens over the backdrop behind this box (spec §5.3).
///
/// Repaints in the same frame when an enclosing route animates or an
/// enclosing scrollable scrolls; any other move that skips its paint is
/// corrected one frame later by [LiquidDriftGuard].
class LiquidBackdrop extends StatefulWidget {
  /// Creates the lens for a box of shape [borderRadius].
  const LiquidBackdrop({
    required this.program,
    required this.borderRadius,
    required this.params,
    super.key,
  });

  /// The loaded lens program.
  final ui.FragmentProgram program;

  /// The drawn shape (clipped by the caller).
  final BorderRadius borderRadius;

  /// Tint, rim and strength, from the theme.
  final LiquidOpticsParams params;

  @override
  State<LiquidBackdrop> createState() => _LiquidBackdropState();
}

class _LiquidBackdropState extends State<LiquidBackdrop> {
  final List<Listenable> _movers = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _unlisten();
    final route = ModalRoute.of(context);
    _movers.addAll([
      ?route?.animation,
      ?route?.secondaryAnimation,
      ?Scrollable.maybeOf(context)?.position,
    ]);
    for (final mover in _movers) {
      mover.addListener(_moved);
    }
  }

  // An inactive element has no render object to repaint. Reactivation
  // always runs didChangeDependencies (this state depends on ModalRoute
  // and Scrollable, found or not), which subscribes again.
  @override
  void deactivate() {
    _unlisten();
    super.deactivate();
  }

  @override
  void dispose() {
    _unlisten();
    super.dispose();
  }

  void _unlisten() {
    for (final mover in _movers) {
      mover.removeListener(_moved);
    }
    _movers.clear();
  }

  void _moved() {
    final render = context.findRenderObject();
    if (render is RenderLiquidBackdrop) render.markNeedsPaint();
  }

  @override
  Widget build(BuildContext context) => _LiquidBackdropBox(
    program: widget.program,
    borderRadius: widget.borderRadius,
    params: widget.params,
    backdropKey: BackdropGroup.of(context)?.backdropKey,
    child: const SizedBox.expand(),
  );
}

class _LiquidBackdropBox extends SingleChildRenderObjectWidget {
  const _LiquidBackdropBox({
    required this.program,
    required this.borderRadius,
    required this.params,
    required this.backdropKey,
    super.child,
  });

  final ui.FragmentProgram program;
  final BorderRadius borderRadius;
  final LiquidOpticsParams params;
  final BackdropKey? backdropKey;

  @override
  RenderLiquidBackdrop createRenderObject(BuildContext context) =>
      RenderLiquidBackdrop(
        program: program,
        borderRadius: borderRadius,
        params: params,
        backdropKey: backdropKey,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderLiquidBackdrop renderObject,
  ) {
    renderObject
      ..program = program
      ..borderRadius = borderRadius
      ..params = params
      ..backdropKey = backdropKey;
  }
}

/// Pushes a backdrop filter layer whose lens is placed from this box's
/// rect in pass pixels, computed at paint time (spec §5.3).
class RenderLiquidBackdrop extends RenderProxyBox {
  /// Creates the render object.
  RenderLiquidBackdrop({
    required this._program,
    required this._borderRadius,
    required this._params,
    this._backdropKey,
  });

  /// The lens program.
  ui.FragmentProgram get program => _program;
  ui.FragmentProgram _program;
  set program(ui.FragmentProgram value) {
    if (identical(value, _program)) return;
    _program = value;
    _invalidate();
  }

  /// The drawn shape.
  BorderRadius get borderRadius => _borderRadius;
  BorderRadius _borderRadius;
  set borderRadius(BorderRadius value) {
    if (value == _borderRadius) return;
    _borderRadius = value;
    _invalidate();
  }

  /// Tint, rim and strength.
  LiquidOpticsParams get params => _params;
  LiquidOpticsParams _params;
  set params(LiquidOpticsParams value) {
    if (value == _params) return;
    _params = value;
    _invalidate();
  }

  /// The shared backdrop of the nearest `BackdropGroup`, if any.
  BackdropKey? get backdropKey => _backdropKey;
  BackdropKey? _backdropKey;
  set backdropKey(BackdropKey? value) {
    if (value == _backdropKey) return;
    _backdropKey = value;
    markNeedsPaint();
  }

  ui.FragmentShader? _shader;
  bool _lensFailed = false;
  Float32List? _uniforms;
  ui.ImageFilter? _filter;
  Rect? _paintedRect;

  /// The rect of the last paint in pass pixels; null before it.
  @visibleForTesting
  Rect? get debugPaintedRect => _paintedRect;

  /// The uniforms of the current filter; null before the first paint.
  @visibleForTesting
  Float32List? get debugUniforms => _uniforms;

  @override
  BackdropFilterLayer? get layer => super.layer as BackdropFilterLayer?;

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    LiquidDriftGuard.instance.add(this);
  }

  @override
  void detach() {
    LiquidDriftGuard.instance.remove(this);
    // Off screen nothing samples the shader; a reattach paints a new one.
    _disposeShader();
    super.detach();
  }

  @override
  void dispose() {
    _disposeShader();
    super.dispose();
  }

  void _disposeShader() {
    _shader?.dispose();
    _shader = null;
    _filter = null;
  }

  void _invalidate() {
    _filter = null;
    markNeedsPaint();
  }

  /// This box in pass pixels, pass pixels per logical pixel, and the pass
  /// size in pixels (spec §5.3, §5.4).
  ({Rect rect, double scale, Size pass}) passGeometry() {
    final box = Offset.zero & size;
    final root = owner?.rootNode;
    if (root is RenderView) {
      final config = root.configuration;
      final transform = config.toMatrix()..multiply(getTransformTo(null));
      return (
        rect: MatrixUtils.transformRect(transform, box),
        scale: config.devicePixelRatio,
        pass: root.size * config.devicePixelRatio,
      );
    }
    assert(false, 'RenderLiquidBackdrop is not under a RenderView');
    return (
      rect: MatrixUtils.transformRect(getTransformTo(null), box),
      scale: 1,
      pass: Size.infinite,
    );
  }

  /// Repaints when this box moved since its last paint (the drift guard).
  void checkDrift() {
    final painted = _paintedRect;
    if (!attached || painted == null) return;
    final now = passGeometry().rect;
    if ((now.left - painted.left).abs() > 0.5 ||
        (now.top - painted.top).abs() > 0.5 ||
        (now.right - painted.right).abs() > 0.5 ||
        (now.bottom - painted.bottom).abs() > 0.5) {
      markNeedsPaint();
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      layer = null;
      return;
    }
    final geometry = passGeometry();
    final uniforms = liquidUniforms(
      rect: geometry.rect,
      radii: _borderRadius,
      params: _params,
      scale: geometry.scale,
      pass: geometry.pass,
    );
    ui.FragmentShader? retired;
    if (_filter == null || !_sameFloats(uniforms, _uniforms)) {
      retired = _shader;
      _shader = null;
      _filter = _lensFailed ? _blurOnly() : _lens(uniforms);
      _uniforms = uniforms;
    }
    _paintedRect = geometry.rect;
    layer ??= BackdropFilterLayer();
    layer!
      ..filter = _filter
      ..blendMode = BlendMode.srcOver
      ..backdropKey = _backdropKey;
    retired?.dispose();
    context.pushLayer(layer!, super.paint, offset);
  }

  /// A fresh shader per change: ImageFilter.shader equality compares the
  /// shader object, so mutating the current one could leave the layer's
  /// filter unchanged (spec §5.3).
  ui.ImageFilter _lens(Float32List uniforms) {
    ui.FragmentShader? shader;
    try {
      shader = _program.fragmentShader();
      for (var i = 0; i < uniforms.length; i++) {
        shader.setFloat(LiquidOptics.firstIndex + i, uniforms[i]);
      }
      final filter = (debugLiquidFilterFactory ?? liquidLensFilter)(
        shader,
        _params.blurSigma,
      );
      _shader = shader;
      return filter;
    } on Object catch (error, stack) {
      // The engine cannot draw the lens: blur alone until the glass
      // rebuilds as frosted (spec §14).
      shader?.dispose();
      _lensFailed = true;
      LiquidShaderProgram.instance.disable(error, stack);
      return _blurOnly();
    }
  }

  ui.ImageFilter _blurOnly() => ui.ImageFilter.blur(
    sigmaX: _params.blurSigma,
    sigmaY: _params.blurSigma,
  );

  static bool _sameFloats(Float32List a, Float32List? b) {
    if (b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
