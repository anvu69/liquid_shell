import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_shell/src/chrome/large_content_viewer.dart';
import 'package:liquid_shell/src/chrome/lens_clip.dart';
import 'package:liquid_shell/src/chrome/lens_gesture.dart';
import 'package:liquid_shell/src/chrome/lens_motion.dart';
import 'package:liquid_shell/src/chrome/lens_profile.dart';
import 'package:liquid_shell/src/chrome/lens_ticker.dart';
import 'package:liquid_shell/src/chrome/sf_tracking.dart';
import 'package:liquid_shell/src/chrome/sized_layout_builder.dart';
import 'package:liquid_shell/src/chrome/text_scale.dart';
import 'package:liquid_shell/src/glass/glass_theme.dart';
import 'package:liquid_shell/src/glass/liquid_lens.dart';
import 'package:liquid_shell/src/segmented/segment_geometry.dart';

/// The track, for tests.
@visibleForTesting
const kSegmentTrackKey = ValueKey<String>('liquid-segment-track');

/// The rest thumb, for tests.
@visibleForTesting
const kSegmentThumbKey = ValueKey<String>('liquid-segment-thumb');

/// The normal (w400) label row's clip, for tests.
@visibleForTesting
const kSegmentNormalKey = ValueKey<String>('liquid-segment-normal');

/// The selected (w500) label row's clip, for tests.
@visibleForTesting
const kSegmentSelectedKey = ValueKey<String>('liquid-segment-selected');

/// Reduce motion: the outgoing rest thumb, for tests.
@visibleForTesting
const kSegmentGhostKey = ValueKey<String>('liquid-segment-ghost');

/// The keyboard focus ring around a segment, for tests.
@visibleForTesting
const kSegmentFocusKey = ValueKey<String>('liquid-segment-focus');

/// Acceptance traces: called once per control tick with
/// the global lens centre (`x`, `y`), the lens size (`w`, `h`), `engage`
/// and the ticker time `t` in seconds. Reset it to null after use.
@visibleForTesting
void Function(Map<String, double> sample)? debugSegmentTrace;

/// Goldens: when non-null, every segmented control draws its lens pressed
/// (the press growth, engaged) and shifted by this many points in x. Reset
/// it to null after use.
@visibleForTesting
double? debugSegmentLensPress;

const BorderRadius _capsule = BorderRadius.all(Radius.circular(999));

/// A held unselected segment's label fades to this opacity over
/// [_pressedLabelFade].
const double _pressedLabelOpacity = 0.2;

/// See [_pressedLabelOpacity].
const Duration _pressedLabelFade = Duration(milliseconds: 450);

/// One segment of a [LiquidSegmentedControl].
@immutable
class LiquidSegment with Diagnosticable {
  /// Creates a text segment.
  const LiquidSegment({
    required this.label,
    this.enabled = true,
    this.semanticLabel,
  });

  /// The title, one line; it ellipsizes when it does not fit.
  final String label;

  /// Whether the segment can be chosen. A disabled segment draws its label
  /// at half opacity and is never committed.
  final bool enabled;

  /// What a screen reader says instead of [label].
  final String? semanticLabel;

  @override
  bool operator ==(Object other) =>
      other is LiquidSegment &&
      other.label == label &&
      other.enabled == enabled &&
      other.semanticLabel == semanticLabel;

  @override
  int get hashCode => Object.hash(label, enabled, semanticLabel);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('label', label))
      ..add(FlagProperty('enabled', value: enabled, ifFalse: 'disabled'))
      ..add(StringProperty('semanticLabel', semanticLabel, defaultValue: null));
  }
}

/// A segmented control drawn after iOS 26's `UISegmentedControl`, with a
/// liquid lens for its selection. Controlled: rebuild it with
/// the index [onChanged] reports.
///
/// The visible track is 32 pt tall, centred in a 44 pt box, so every
/// segment's hit target is the full box height × its width. Segments are at
/// least 44 pt wide, except in a width below 44 pt per segment (see
/// [expand]). It never overflows its parent and never cuts a segment off.
///
/// A negative [selectedIndex] fails at construction; fewer than two
/// [segments] or a [selectedIndex] past the last segment fail at build (a
/// const constructor cannot read a list's length).
class LiquidSegmentedControl extends StatefulWidget {
  /// Creates a segmented control of at least two [segments].
  const LiquidSegmentedControl({
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
    this.expand = true,
    this.semanticLabel,
    super.key,
  }) : assert(
         selectedIndex == null || selectedIndex >= 0,
         'selectedIndex must not be negative.',
       );

  /// The segments, two or more, in index order (right to left in RTL).
  final List<LiquidSegment> segments;

  /// The selected segment, or null for none.
  final int? selectedIndex;

  /// Called with the index of the segment the user chose, in [segments].
  /// Not called for the segment already selected or for a disabled one.
  /// Null disables the whole control (drawn at half opacity).
  final ValueChanged<int>? onChanged;

  /// Fill the incoming width (true) or size to the labels (false): every
  /// segment as wide as the widest label (Medium weight) plus 18 pt, and at
  /// least 44 pt.
  ///
  /// - Under an unbounded width (in a `Row` without `Expanded`, or asked
  ///   for its intrinsic width) the control sizes to the labels either way.
  /// - It never overflows: when the width it is given is narrower than it
  ///   asks for, every segment shrinks equally to fit, as native's do.
  ///   Below 44 pt per segment, hit targets follow the segment width, and
  ///   labels that do not fit ellipsize.
  final bool expand;

  /// What a screen reader says for the control as a whole.
  final String? semanticLabel;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IterableProperty<LiquidSegment>('segments', segments))
      ..add(IntProperty('selectedIndex', selectedIndex, ifNull: 'none'))
      ..add(
        FlagProperty('enabled', value: onChanged != null, ifFalse: 'disabled'),
      )
      ..add(
        FlagProperty(
          'expand',
          value: expand,
          ifTrue: 'expand',
          ifFalse: 'intrinsic',
        ),
      )
      ..add(StringProperty('semanticLabel', semanticLabel, defaultValue: null));
  }

  @override
  State<LiquidSegmentedControl> createState() => _LiquidSegmentedControlState();
}

class _LiquidSegmentedControlState extends State<LiquidSegmentedControl>
    with SingleTickerProviderStateMixin {
  LensMotion? _motion;

  /// The frame loop shared with the tab bar: haptics per crossing, a
  /// refused commit handed back, the trace. Its ticker is made on the
  /// first kick, so a control nobody touches never makes one.
  late final LensTicker _ticker = LensTicker(
    vsync: this,
    motion: () => _motion,
    selected: () => widget.selectedIndex,
    onFrame: () => setState(() {}),
    trace: _trace,
  );

  /// The group the control opens, so the lens samples what lies behind
  /// it. One key for the control's life, as `GlassTabBar`'s.
  final BackdropKey _backdropKey = BackdropKey();

  /// The last laid-out geometry: the gesture handlers read it.
  SegmentGeometry? _geometry;

  /// The unselected segment held down: its w400 label fades (native
  /// `pressOther`).
  int? _pressed;

  /// The segment that shows the keyboard focus ring, if any.
  int? _focused;

  bool get _enabled => widget.onChanged != null;

  bool _canCommit(int i) => widget.segments[i].enabled;

  @override
  void didUpdateWidget(LiquidSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Disabled mid-touch: the recognizer goes with the touch, so no up or
    // cancel will come; the lens lets go now.
    if (!_enabled && (_motion?.interacting ?? false)) _cancel();
    // Its focus node went with its segment, and will not report the loss.
    if ((_focused ?? -1) >= widget.segments.length) _focused = null;
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// Keeps the motion on the laid-out track, and follows the app: a
  /// commit it adopts is accepted; a selection it changes on its own
  /// slides there.
  LensMotion _sync(SegmentGeometry g) {
    final selected = widget.selectedIndex;
    final m =
        (_motion ??= LensMotion(
            geometry: g,
            selected: selected,
            profile: LensProfile.segment,
          ))
          ..reduceMotion = MediaQuery.disableAnimationsOf(context)
          ..geometry = g;
    if (m.follow(selected)) _ticker.kick();
    return m;
  }

  /// [debugSegmentTrace]'s sample: the global lens centre and size.
  void _trace(Duration elapsed, LensFrame f) {
    final trace = debugSegmentTrace;
    if (trace == null || !mounted) return;
    trace(lensTraceSample(context, elapsed, f));
  }

  /// Whether [p] (control-local) is in the selected segment's column.
  bool _onThumb(Offset p) {
    final selected = widget.selectedIndex;
    return selected != null && _geometry?.segmentAt(p) == selected;
  }

  void _setPressed(int? i) {
    if (_pressed != i) setState(() => _pressed = i);
  }

  void _down(Offset p) {
    final m = _motion;
    final g = _geometry;
    if (m == null || g == null) return;
    m.down(p);
    final i = g.segmentAt(p);
    final selected = widget.selectedIndex;
    // With nothing selected the lens grows under the finger instead.
    _setPressed(
      i != null && selected != null && i != selected && _canCommit(i)
          ? i
          : null,
    );
    _ticker.kick();
  }

  void _move(Offset p) {
    final m = _motion;
    if (m == null) return;
    m.move(p);
    // A drag is not a press: the label comes back as the lens follows.
    if (m.phase == LensPhase.dragging) _setPressed(null);
  }

  void _up(Offset p, double velocity) {
    final m = _motion;
    final g = _geometry;
    _setPressed(null);
    if (m == null || g == null) return;
    // The segment whose column holds the finger: its centre is the tap's
    // release point. A drag ignores it (the lens decides).
    final under = g.segmentAt(Offset(p.dx, g.size.height / 2));
    if (m.phase == LensPhase.pressed && (under == null || !_canCommit(under))) {
      // A tap on a disabled segment does nothing.
      m.cancel();
      _ticker.kick();
      return;
    }
    final at = under == null ? p : Offset(g.centreOf(under), p.dy);
    final slot = m.up(at, velocity: velocity, canCommit: _canCommit);
    _ticker.kick();
    if (slot != null && slot != widget.selectedIndex) {
      widget.onChanged?.call(slot);
    }
  }

  void _cancel() {
    _setPressed(null);
    _motion?.cancel();
    _ticker.kick();
  }

  /// A semantics tap, Enter or Space: the tap path without a press. The
  /// selected segment calls nothing, as a touch on it does.
  void _activate(int i) {
    if (!_enabled || !_canCommit(i) || i == widget.selectedIndex) return;
    _motion?.tapSlot(i);
    _ticker.kick();
    widget.onChanged!(i);
  }

  void _focus(int i, bool on) {
    if (on) {
      if (_focused != i) setState(() => _focused = i);
    } else if (_focused == i) {
      setState(() => _focused = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.segments.length;
    final selected = widget.selectedIndex;
    assert(count >= 2, 'LiquidSegmentedControl needs two segments or more.');
    assert(
      selected == null || (selected >= 0 && selected < count),
      'selectedIndex $selected is outside 0..${count - 1}.',
    );
    final theme = LiquidGlassTheme.of(context);
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: SegmentMetrics.maxTextScale);
    // An override without a size or a line height keeps the spec's 13 pt
    // on 15.67, so the drawn line and the geometry's agree. Without its own
    // family it takes the app's, as the tab bar's labels do; size, weights
    // and colour stay native's. The theme's, not the ambient style's: under
    // a MaterialApp with no Material above, that is the monospace error one.
    final themed = theme.segmentLabelStyle;
    final app = themed.fontFamily == null
        ? Theme.of(context).textTheme.labelLarge
        : null;
    final fontSize = themed.fontSize ?? SegmentMetrics.labelSize;
    final family = themed.fontFamily ?? app?.fontFamily;
    // UIKit tracks its system font by size and Flutter's text engine does
    // not: without it the labels, and an intrinsic control, came out wider
    // than native's ("Places" 41.27 against 40.67, VK-550 Task 15). For the
    // drawn size, since Flutter does not scale a letterSpacing with the
    // text. An app's own font keeps its spacing.
    final tracking =
        themed.letterSpacing ??
        (isAppleSystemFont(family, Theme.of(context).platform)
            ? sfTracking(scaler.scale(fontSize))
            : null);
    final style = themed.copyWith(
      fontSize: fontSize,
      height:
          themed.height ?? SegmentMetrics.labelLine / SegmentMetrics.labelSize,
      fontFamily: app?.fontFamily,
      fontFamilyFallback: themed.fontFamilyFallback ?? app?.fontFamilyFallback,
      letterSpacing: tracking,
    );
    final medium = style.copyWith(fontWeight: FontWeight.w500);
    final lineHeight = scaler.scale(fontSize) * style.height!;
    List<double>? widths;

    SegmentGeometry geometryFor(BoxConstraints constraints) {
      SegmentGeometry fill(double width) => segmentGeometry(
        count: count,
        maxWidth: width,
        lineHeight: lineHeight,
        direction: direction,
      );
      final maxWidth = constraints.maxWidth;
      if (widget.expand && maxWidth.isFinite) return fill(maxWidth);
      final intrinsic = segmentGeometry(
        count: count,
        maxWidth: double.infinity,
        lineHeight: lineHeight,
        direction: direction,
        mediumLabelWidths: widths ??= [
          for (final s in widget.segments)
            _width(s.label, medium, scaler, direction),
        ],
      );
      // Never cut a segment off: too narrow for the labels, shrink to fit.
      return intrinsic.size.width > maxWidth ? fill(maxWidth) : intrinsic;
    }

    // The labels' baseline, as the Stack answers it: the highest of every
    // label's (a label in another script may fall back to a font with
    // other metrics). Every label box has one top, and a one-line label's
    // baseline does not depend on its width. Alphabetic for either kind,
    // as RenderParagraph answers (flutter/flutter#22625). Measured once
    // per build, only when asked.
    double? labelBaseline;
    double? baselineFor(BoxConstraints constraints, TextBaseline _) {
      labelBaseline ??= widget.segments
          .map((s) {
            final painter = TextPainter(
              text: TextSpan(text: s.label, style: style),
              textScaler: scaler,
              textDirection: direction,
              maxLines: 1,
            )..layout();
            final distance = painter.computeDistanceToActualBaseline(
              TextBaseline.alphabetic,
            );
            painter.dispose();
            return distance;
          })
          .reduce(math.min);
      return geometryFor(constraints).labels.first.top + labelBaseline!;
    }

    final ax = isAxTextScale(context);
    // Waits instead of winning on touch-down at AX sizes (the large
    // content viewer) and inside a vertical scroll view (spec §8.1).
    final eager =
        !ax && Scrollable.maybeOf(context, axis: Axis.vertical) == null;
    // Inside a horizontal scroller (a page view, a row of chips) only a
    // drag that starts on the thumb is the lens's, as native's; any other
    // drag scrolls, and a tap still commits (spec §8.1).
    final horizontal =
        Scrollable.maybeOf(context, axis: Axis.horizontal) != null;

    return BackdropGroup(
      backdropKey: _backdropKey,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: widget.semanticLabel,
        // Orders the segments' nodes visually, right to left in RTL.
        textDirection: direction,
        // Answers intrinsic sizes, which a LayoutBuilder cannot (an
        // IntrinsicWidth, an AlertDialog's content).
        child: SizedLayoutBuilder(
          sizeFor: (constraints) => geometryFor(constraints).size,
          baselineFor: baselineFor,
          builder: (context, constraints) {
            final g = _geometry = geometryFor(constraints);
            final m = _sync(g);
            var f = m.frame;
            final press = debugSegmentLensPress;
            if (press != null) {
              final grow = (m.profile.envelope as SegmentEnvelope).pressGrow;
              f = f.copyWith(
                engage: 1,
                refraction: 1,
                lens: Rect.fromCenter(
                  center: f.lens.center.translate(press, 0),
                  width: f.lens.width + grow.width,
                  height: f.lens.height + grow.height,
                ),
              );
            }
            return SizedBox.fromSize(
              size: g.size,
              child: Opacity(
                opacity: _enabled ? 1 : 0.5,
                child: Stack(
                  // The pressed and lifted lens overflows the track, and
                  // in flight the 44 pt box (spec §7).
                  clipBehavior: Clip.none,
                  children: [
                    ..._layers(g, f, theme, style, medium, scaler),
                    _touches(g, eager, onThumbOnly: horizontal),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Track, thumbs, both label rows and the lens, control-local: the lens above
  /// the normal row, below the w500 row. Keyed: the layers that come and go
  /// never shift the others' state (the touch recognizer, the focus nodes, the
  /// label fade) to a new element.
  List<Widget> _layers(
    SegmentGeometry g,
    LensFrame f,
    LiquidGlassTheme theme,
    TextStyle style,
    TextStyle medium,
    TextScaler scaler,
  ) {
    final lens = f.lens;
    final thumb = theme.segmentThumb;
    final ghost = f.ghost;
    // The rest thumb gives way to the lens as it engages, and fades in
    // under reduce motion.
    final rest = f.restOpacity * (1 - f.engage);
    final lensDrawn = f.visible && f.engage > 0.001;
    return [
      Positioned.fromRect(
        key: const ValueKey<String>('track'),
        rect: g.track,
        child: DecoratedBox(
          key: kSegmentTrackKey,
          decoration: BoxDecoration(
            color: theme.segmentTrack,
            borderRadius: _capsule,
          ),
        ),
      ),
      if (ghost != null && f.ghostOpacity > 0)
        Positioned.fromRect(
          key: const ValueKey<String>('ghost'),
          rect: ghost,
          child: DecoratedBox(
            key: kSegmentGhostKey,
            decoration: BoxDecoration(
              color: thumb.withValues(alpha: thumb.a * f.ghostOpacity),
              borderRadius: _capsule,
            ),
          ),
        ),
      // While the lens is drawn it draws the rest fill itself, once (R8).
      if (f.visible && !lensDrawn)
        Positioned.fromRect(
          key: const ValueKey<String>('thumb'),
          rect: lens,
          child: DecoratedBox(
            key: kSegmentThumbKey,
            decoration: BoxDecoration(
              color: rest == 1
                  ? thumb
                  : thumb.withValues(alpha: thumb.a * rest),
              borderRadius: _capsule,
            ),
          ),
        ),
      Positioned.fill(
        key: const ValueKey<String>('normal'),
        child: ClipPath(
          key: kSegmentNormalKey,
          clipper: LensClip(f.visible ? lens : Rect.zero, inside: false),
          child: _row(g, style, scaler, pressed: _pressed),
        ),
      ),
      if (lensDrawn)
        Positioned.fromRect(
          key: const ValueKey<String>('lens'),
          rect: lens,
          // The lens fades itself: an Opacity over the liquid pass reads
          // the wrong backdrop (VK-503 §7.2).
          child: LiquidLens(
            refraction: f.refraction,
            engage: f.engage,
            // Fades in with the rest thumb (reduce motion), as the tab
            // lens's.
            restFill: thumb.withValues(alpha: thumb.a * f.restOpacity),
            look: _motion!.profile.look,
          ),
        ),
      if (f.visible)
        Positioned.fill(
          key: const ValueKey<String>('selected'),
          child: ClipPath(
            key: kSegmentSelectedKey,
            clipper: LensClip(lens, inside: true),
            child: Transform(
              transform: Matrix4.identity()
                ..translateByDouble(lens.center.dx, lens.center.dy, 0, 1)
                ..scaleByDouble(f.magnify, f.magnify, 1, 1)
                ..translateByDouble(-lens.center.dx, -lens.center.dy, 0, 1),
              child: _row(g, medium, scaler, lensCopy: true),
            ),
          ),
        ),
      // A ring whose segment is gone (fewer segments) is not drawn.
      if (_focused case final i? when i < g.slots.length)
        Positioned.fromRect(
          key: const ValueKey<String>('focus'),
          rect: g.slots[i],
          child: IgnorePointer(
            child: DecoratedBox(
              key: kSegmentFocusKey,
              decoration: BoxDecoration(
                borderRadius: _capsule,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
    ];
  }

  /// The segments' nodes: semantics, keyboard focus and the large content
  /// viewer, each over its full column. One recognizer over the whole box
  /// takes their touches, as the tab bar's row does.
  Widget _touches(SegmentGeometry g, bool eager, {required bool onThumbOnly}) {
    final nodes = Stack(
      children: [
        for (final (i, s) in widget.segments.indexed)
          Positioned(
            left: g.segments[i].left,
            width: g.segments[i].width,
            top: 0,
            bottom: 0,
            child: _node(i, s),
          ),
      ],
    );
    return Positioned.fill(
      key: const ValueKey<String>('touches'),
      child: !_enabled
          ? nodes
          : RawGestureDetector(
              gestures: {
                LensGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<LensGestureRecognizer>(
                      () => LensGestureRecognizer(debugOwner: this),
                      (r) => r
                        // The screen's slop, as the scroll views around use.
                        ..gestureSettings = MediaQuery.maybeGestureSettingsOf(
                          context,
                        )
                        ..eager = eager
                        ..claimsDragAt = onThumbOnly ? _onThumb : null
                        ..onDown = _down
                        ..onMove = _move
                        ..onUp = _up
                        ..onCancel = _cancel,
                    ),
              },
              child: nodes,
            ),
    );
  }

  Widget _node(int i, LiquidSegment s) {
    final active = _enabled && s.enabled;
    return Semantics(
      container: true,
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: i == widget.selectedIndex,
      enabled: active,
      label: s.semanticLabel ?? s.label,
      onTap: active ? () => _activate(i) : null,
      // The focus node's own flags stay out of the segment's node.
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: active,
        mouseCursor: active ? SystemMouseCursors.click : MouseCursor.defer,
        // Enter and Space on a focused segment. Touches never reach these
        // actions: they go to the recognizer, so a segment commits once
        // whichever way it is chosen.
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => _activate(i),
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (_) => _activate(i),
          ),
        },
        onShowFocusHighlight: (on) => _focus(i, on),
        child: LargeContentViewer(
          label: s.label,
          // Takes the touch for the recognizer above.
          child: const MetaData(
            behavior: HitTestBehavior.opaque,
            child: SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  /// Every label in [style], one line, centred in its label box. The rows
  /// draw only: the segment nodes carry the semantics. The DefaultTextStyle
  /// keeps the ambient one out: under a MaterialApp with no Material above,
  /// it is the yellow-underlined error style, and [style] inherits.
  /// [pressed]: that label fades as native's held segment does.
  /// [lensCopy]: the selected row, drawn by [_LensLabel] so that
  /// `find.text` sees each title once.
  Widget _row(
    SegmentGeometry g,
    TextStyle style,
    TextScaler scaler, {
    int? pressed,
    bool lensCopy = false,
  }) => IgnorePointer(
    child: ExcludeSemantics(
      child: DefaultTextStyle(
        style: style,
        child: Stack(
          children: [
            for (final (i, s) in widget.segments.indexed)
              Positioned.fromRect(
                rect: g.labels[i],
                child: AnimatedOpacity(
                  opacity: i == pressed ? _pressedLabelOpacity : 1,
                  // In over native's fade; back at once on the up.
                  duration: i == pressed ? _pressedLabelFade : Duration.zero,
                  curve: Curves.easeInOut,
                  child: Opacity(
                    opacity: s.enabled ? 1 : 0.5,
                    child: lensCopy
                        ? _LensLabel(s.label, style: style, scaler: scaler)
                        : Text(
                            s.label,
                            style: style,
                            textScaler: scaler,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  static double _width(
    String label,
    TextStyle style,
    TextScaler scaler,
    TextDirection direction,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textScaler: scaler,
      textDirection: direction,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}

/// The lens copy of a label: the [RichText] that `Text(label, style: style,
/// textScaler: scaler, …)` in [_LiquidSegmentedControlState._row] builds,
/// same pixels, but not a `Text`. A finder's `find.text` (and an app's
/// widget tests) then see each title once, in the normal row. It never
/// registers with a `SelectionArea`, so a title is not selected twice.
class _LensLabel extends StatelessWidget {
  const _LensLabel(this.label, {required this.style, required this.scaler});

  final String label;
  final TextStyle style;
  final TextScaler scaler;

  @override
  Widget build(BuildContext context) {
    final ambient = DefaultTextStyle.of(context);
    var effective = ambient.style.merge(style);
    if (MediaQuery.boldTextOf(context)) {
      effective = effective.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    return RichText(
      textAlign: TextAlign.center,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      textScaler: scaler,
      maxLines: 1,
      textWidthBasis: ambient.textWidthBasis,
      textHeightBehavior:
          ambient.textHeightBehavior ??
          DefaultTextHeightBehavior.maybeOf(context),
      text: TextSpan(style: effective, text: label),
    );
  }
}
