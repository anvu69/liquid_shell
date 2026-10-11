import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:liquid_shell/src/chrome/fit_label.dart';
import 'package:liquid_shell/src/chrome/large_content_viewer.dart';
import 'package:liquid_shell/src/chrome/lens_gesture.dart';
import 'package:liquid_shell/src/chrome/lens_motion.dart';
import 'package:liquid_shell/src/chrome/tab_bar.dart' show LiquidActionCircle;
import 'package:liquid_shell/src/chrome/tab_geometry.dart';
import 'package:liquid_shell/src/chrome/tab_springs.dart';
import 'package:liquid_shell/src/chrome/text_scale.dart';
import 'package:liquid_shell/src/destinations/badge.dart';
import 'package:liquid_shell/src/destinations/destination.dart';
import 'package:liquid_shell/src/destinations/tab_action.dart';
import 'package:liquid_shell/src/glass/glass_theme.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';
import 'package:liquid_shell/src/glass/liquid_lens.dart';
import 'package:liquid_shell/src/shell/strings.dart';

/// The pill glass (tests).
const kTabPillKey = ValueKey<String>('liquid-tab-pill');

/// The normal copy's clip (tests).
const kTabNormalKey = ValueKey<String>('liquid-tab-normal');

/// The tinted copy's clip (tests).
const kTabTintedKey = ValueKey<String>('liquid-tab-tinted');

/// The trailing circle (tests).
const kTabTrailingKey = ValueKey<String>('liquid-tab-trailing');

const _capsule = BorderRadius.all(Radius.circular(999));

/// The smallest tap area a tab keeps (P1 Q17, Apple's 44 pt target).
const double _minTapWidth = 44;

/// Rewrites every frame before it is painted: goldens of the engaged lens
/// (spec VK-503 §17.3). Reset it to null after use.
@visibleForTesting
LensFrame Function(LensFrame frame)? debugTabLensOverride;

/// Goldens: when non-null, every tab bar draws its lens pressed (×1.17 /
/// ×1.30, engaged, pill ×1.052, highlight 0.845) and shifted by this many
/// points in x. Reset it to null after use.
@visibleForTesting
double? debugTabLensPress;

/// Acceptance traces (spec VK-503 §17.4): called once per bar tick with
/// the global lens centre and the frame's scalars. Reset to null after use.
@visibleForTesting
void Function(Map<String, double> sample)? debugTabTrace;

/// The Flutter tab bar of spec VK-503. Internal: `LiquidTabBar` and the
/// shell build it. It fills the width it is given (the row between the
/// margins) and places its pill per spec §5; gaps pass touches through.
class GlassTabBar extends StatefulWidget {
  /// Creates the bar.
  const GlassTabBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    this.form = TabBarForm.compact,
    this.trailing,
    this.minimized = false,
    this.onCollapsedTap,
    this.announceExpand = true,
    this.collapsedKey,
    this.strings = const LiquidShellStrings(),
    this.narrow = false,
    this.externalTarget,
    this.reserveTrailing = false,
    this.collapseDelay = true,
    this.tintCollapsed = true,
    super.key,
  }) : assert(
         externalTarget == null || trailing == null,
         'One drop target: the shell draws the ⌕ (externalTarget) or the '
         'bar draws its trailing circle, not both.',
       );

  /// All destinations; only `everywhere` ones get a slot.
  final List<LiquidDestination> destinations;

  /// Index into [destinations]; a hidden one highlights nothing.
  final int selectedIndex;

  /// Called on commit with an index into [destinations].
  final ValueChanged<int> onSelect;

  /// Compact, landscape or top (spec §5).
  final TabBarForm form;

  /// The trailing circle's action.
  final LiquidTabAction? trailing;

  /// Collapsed to the 48 pt circle (spec §10).
  final bool minimized;

  /// Tap on the collapsed circle; null makes it inert.
  final VoidCallback? onCollapsedTap;

  /// Whether a collapsed tap announces `tabBarExpanded` and the node
  /// carries the expand hint (false for the search collapse, spec §11).
  final bool announceExpand;

  /// Key of the collapsed circle's node (`kSearchCollapsedKey`, spec §11).
  final Key? collapsedKey;

  /// Strings for hints, announcements and badges.
  final LiquidShellStrings strings;

  /// Narrow labels fit themselves (P1 Q18).
  final bool narrow;

  /// A drop target the shell owns (the search ⌕), bar-local.
  final TabDragTarget? externalTarget;

  /// Lay out as if a trailing circle were there (the search ⌕ is drawn by
  /// the shell, spec §11).
  final bool reserveTrailing;

  /// A collapse waits 0.24 s (scroll); false for the search collapse.
  final bool collapseDelay;

  /// Whether the collapsed circle tints the selected tab's icon. False for
  /// the search collapse: the circle holds the previous tab, not the
  /// current one, in the unselected colour (spec VK-503 §11).
  final bool tintCollapsed;

  @override
  State<GlassTabBar> createState() => _GlassTabBarState();
}

class _GlassTabBarState extends State<GlassTabBar>
    with SingleTickerProviderStateMixin {
  LensMotion? _motion;

  /// Created on the first touch: a bar nobody touches never makes one, and
  /// `dispose` must not create it (no ancestor lookups there).
  Ticker? _ticker;
  Duration _last = Duration.zero;

  /// The group a standalone bar opens, so the lens samples the page and
  /// not the pill (spec §7.2). One key for the bar's life.
  final BackdropKey _backdropKey = BackdropKey();

  late final MinimizeMotion _minimize = MinimizeMotion(
    minimized: widget.minimized,
  );

  /// The last laid-out geometry: the trailing target's rect reads it.
  TabBarGeometry? _geometry;

  /// The trailing circle's drop target, while there is a trailing action.
  TabDragTarget? _ownTarget;

  TabDragTarget? get _target => widget.externalTarget ?? _ownTarget;

  @override
  void initState() {
    super.initState();
    _syncOwnTarget();
  }

  void _syncOwnTarget() {
    final action = widget.trailing;
    if (action == null) {
      _ownTarget?.dispose();
      _ownTarget = null;
    } else {
      _ownTarget ??= TabDragTarget(
        rect: () => _geometry?.trailing ?? Rect.zero,
        onRelease: () => widget.trailing?.onPressed(),
      );
    }
  }

  @override
  void didUpdateWidget(GlassTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncOwnTarget();
    if (oldWidget.minimized != widget.minimized) {
      // A minimize takes the touch away: no stale hover, no late commit.
      if (widget.minimized) _cancel(building: true);
      _minimize
        ..reduceMotion = MediaQuery.disableAnimationsOf(context)
        ..set(widget.minimized, delayed: widget.collapseDelay);
      _kick();
    }
  }

  @override
  void dispose() {
    _ownTarget?.dispose();
    _ticker?.dispose();
    super.dispose();
  }

  List<int> get _shown => [
    for (final (i, d) in widget.destinations.indexed)
      if (d.placement == LiquidPlacement.everywhere) i,
  ];

  int? _slotOf(int index) {
    final s = _shown.indexOf(index);
    return s < 0 ? null : s;
  }

  /// 0 = full bar, 1 = minimized circle; below 0 in the expand overshoot.
  double get _morph => _minimize.value;

  LensMotion _sync(TabBarGeometry g) {
    final selected = _slotOf(widget.selectedIndex);
    final m = (_motion ??= LensMotion(geometry: g, selected: selected))
      ..reduceMotion = MediaQuery.disableAnimationsOf(context)
      ..geometry = g;
    if (m.pending != null) {
      if (selected == m.pending) m.accept();
    } else if (selected != m.committed && !m.interacting) {
      m.show(selected);
    }
    return m;
  }

  void _kick() {
    if (!mounted) return;
    final ticker = _ticker ??= createTicker(_onTick);
    if (ticker.isActive) return;
    _last = Duration.zero;
    unawaited(ticker.start());
  }

  void _onTick(Duration elapsed) {
    // Wall time, as Core Animation: a long frame moves the lens on. The
    // springs cap one step at SpringValue.maxAdvance (VK-503 Task 16: a
    // 1/30 s cap left the lens 10 ms behind after a 44 ms first frame).
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(
      0.0,
      SpringValue.maxAdvance,
    );
    _last = elapsed;
    final minimizing = _minimize.advance(dt);
    final m = _motion;
    var moving = m != null && m.advance(dt);
    if (m != null) {
      for (final _ in m.takeCrossings()) {
        // Spec §9 / Q6: one selection click per slot crossing while
        // dragging.
        unawaited(HapticFeedback.selectionClick());
      }
      if (!moving) {
        final selected = _slotOf(widget.selectedIndex);
        if (m.pending != null && m.pending != selected) {
          // The app did not adopt the commit (spec §8.7).
          m.returnTo(selected);
          moving = true;
        } else {
          m.accept();
        }
      }
    }
    if (!moving && !minimizing) _ticker?.stop();
    final trace = debugTabTrace;
    if (trace != null && m != null && mounted) {
      final box = context.findRenderObject() as RenderBox?;
      final f = m.frame;
      final centre = box == null
          ? f.lens.center
          : box.localToGlobal(f.lens.center);
      trace({
        't': elapsed.inMicroseconds / 1e6,
        'x': centre.dx,
        'y': centre.dy,
        'w': f.lens.width,
        'h': f.lens.height,
        'engage': f.engage,
        'scale': f.pillScale,
        'glow': f.glowOpacity,
        'glowD': f.glowDiameter,
        'pop': f.popScale,
        'morph': _minimize.value,
      });
    }
    setState(() {});
  }

  void _down(Offset p) {
    _motion?.down(p);
    _kick();
  }

  void _move(Offset p) {
    _motion?.move(p);
    final t = _target;
    if (t != null) {
      t.hovered.value =
          (_motion?.interacting ?? false) && t.rect().inflate(4).contains(p);
    }
  }

  void _up(Offset p, double velocity) {
    final t = _target;
    if (t != null && t.hovered.value) {
      // Released over the target: it fires, no slot commits (spec §8.8).
      t.hovered.value = false;
      _motion?.cancel();
      _kick();
      t.onRelease();
      return;
    }
    final m = _motion;
    if (m == null) return;
    // The slot under the finger is the one whose tap area holds it (the
    // 44 pt rule of [_hitRect]), not merely the nearest centre: the motion
    // takes that slot's centre as the release point. A drag ignores it.
    final under = _slotUnder(m.geometry, p.dx);
    final at = under == null ? p : Offset(m.geometry.centreOf(under), p.dy);
    final slot = m.up(at, velocity: velocity);
    _kick();
    if (slot != null) widget.onSelect(_shown[slot]);
  }

  /// [building]: called from `didUpdateWidget`. The shell's ⌕ listens to
  /// an external target from outside this bar, so it is cleared after the
  /// frame instead of marking that listener dirty mid-build.
  void _cancel({bool building = false}) {
    final t = _target;
    if (t != null && building && identical(t, widget.externalTarget)) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        // Gone or handed back: the shell clears a target it stops feeding.
        if (mounted && identical(widget.externalTarget, t)) {
          t.hovered.value = false;
        }
      });
    } else {
      t?.hovered.value = false;
    }
    _motion?.cancel();
    _kick();
  }

  void _select(int slot) {
    _motion?.tapSlot(slot);
    _kick();
    widget.onSelect(_shown[slot]);
  }

  void _collapsedTap() {
    final tap = widget.onCollapsedTap;
    if (tap == null) return;
    tap();
    if (!widget.announceExpand) return;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        widget.strings.tabBarExpanded,
        Directionality.of(context),
      ),
    );
  }

  TextStyle _labelStyle(LiquidGlassTheme theme, {required bool tinted}) =>
      switch (widget.form) {
        TabBarForm.compact => theme.labelStyle.copyWith(
          fontWeight: tinted ? FontWeight.w600 : theme.labelStyle.fontWeight,
        ),
        TabBarForm.landscape => theme.labelStyle.copyWith(
          fontSize: 12,
          fontWeight: tinted ? FontWeight.w600 : FontWeight.w400,
        ),
        TabBarForm.top => theme.labelStyle.copyWith(
          fontSize: 17,
          fontWeight: tinted ? FontWeight.w600 : FontWeight.w500,
        ),
      };

  /// What [_labelCache] was measured for: the labels, the resolved style,
  /// the scaler and the direction.
  (List<String>, TextStyle, TextScaler, TextDirection)? _labelKey;
  List<double> _labelCache = const [];

  /// Label widths in the tinted (widest) weight, so the slots never move
  /// when the selection does. Measured as `Text` draws them: the ambient
  /// style, the text scaler and Bold Text. Cached: the bar rebuilds on
  /// every animation frame.
  List<double> _labelWidths(BuildContext context, TextStyle style) {
    var base = DefaultTextStyle.of(context).style.merge(style);
    if (MediaQuery.boldTextOf(context)) {
      base = base.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final labels = [for (final i in _shown) widget.destinations[i].label];
    final key = _labelKey;
    if (key != null &&
        listEquals(key.$1, labels) &&
        key.$2 == base &&
        key.$3 == scaler &&
        key.$4 == direction) {
      return _labelCache;
    }
    _labelKey = (labels, base, scaler, direction);
    return _labelCache = [
      for (final label in labels)
        () {
          final painter = TextPainter(
            text: TextSpan(text: label, style: base),
            textDirection: direction,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final width = painter.width;
          painter.dispose();
          return width;
        }(),
    ];
  }

  /// Whether [d] draws its icon alone in the top form (spec §5.3).
  bool _topIconOnly(LiquidDestination d) =>
      widget.form == TabBarForm.top && d.role == LiquidDestinationRole.search;

  TabBarGeometry _geometryFor(
    BuildContext context,
    double maxWidth,
    TextDirection direction,
    double extent,
  ) {
    final theme = LiquidGlassTheme.of(context);
    final trailing = widget.trailing != null || widget.reserveTrailing;
    return switch (widget.form) {
      TabBarForm.compact => compactTabGeometry(
        count: _shown.length,
        maxWidth: maxWidth,
        trailing: trailing,
        direction: direction,
        extent: extent,
      ),
      TabBarForm.landscape => landscapeTabGeometry(
        // AX sizes draw the icon alone (P1 §5.10): no label room.
        labelWidths: isAxTextScale(context)
            ? [for (final _ in _shown) 0.0]
            : _labelWidths(context, _labelStyle(theme, tinted: true)),
        maxWidth: maxWidth,
        trailing: trailing,
        direction: direction,
      ),
      TabBarForm.top => topTabGeometry(
        labelWidths: _labelWidths(context, _labelStyle(theme, tinted: true)),
        iconOnly: [
          for (final i in _shown)
            _topIconOnly(widget.destinations[i]) || isAxTextScale(context),
        ],
        maxWidth: maxWidth,
        trailing: trailing,
        direction: direction,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final theme = LiquidGlassTheme.of(context);
    final ax = isAxTextScale(context);
    final style = theme.labelStyle;
    final lineHeight = ax
        ? TabMetrics.labelHeight
        : MediaQuery.textScalerOf(context).scale(style.fontSize ?? 10) *
              (style.height ?? 1.2);
    final extent =
        TabMetrics.pillExtent +
        math.max(0.0, lineHeight - TabMetrics.labelHeight);
    // The Material sits above the LayoutBuilder: the labels are measured
    // in the same DefaultTextStyle the cells draw them in.
    final bar = Material(
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final g = _geometry = _geometryFor(
            context,
            constraints.maxWidth,
            direction,
            extent,
          );
          final motion = _sync(g);
          final override = debugTabLensOverride;
          var shown = override == null ? motion.frame : override(motion.frame);
          final press = debugTabLensPress;
          if (press != null) {
            shown = shown.copyWith(
              engage: 1,
              refraction: 1,
              pillScale: TabSprings.pressScale,
              highlight: TabSprings.highlightPress,
              lens: Rect.fromCenter(
                center: shown.lens.center.translate(press, 0),
                width: shown.lens.width * TabSprings.pressWidthFactor,
                height: shown.lens.height * TabSprings.pressHeightFactor,
              ),
            );
          }
          return SizedBox.fromSize(
            size: g.size,
            child: _layers(context, g, shown, theme, lineHeight, ax),
          );
        },
      ),
    );
    // In the shell the bar uses the shell's group.
    return BackdropGroup.of(context) == null
        ? BackdropGroup(backdropKey: _backdropKey, child: bar)
        : bar;
  }

  static Rect _scaleAbout(Rect r, double s) => Rect.fromCenter(
    center: r.center,
    width: r.width * s,
    height: r.height * s,
  );

  Widget _layers(
    BuildContext context,
    TabBarGeometry g,
    LensFrame frame,
    LiquidGlassTheme theme,
    double lineHeight,
    bool ax,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final direction = Directionality.of(context);
    // Unclamped: the expand overshoot extrapolates the rects.
    final morph = _morph;
    final eager =
        !ax && Scrollable.maybeOf(context, axis: Axis.vertical) == null;
    final fade = 1 - (morph / 0.4).clamp(0.0, 1.0);
    final dip = _minimize.dip;
    final glass = _scaleAbout(
      Rect.lerp(g.pill, g.minimized, morph)!,
      frame.pillScale * dip,
    );
    final origin = g.pill.topLeft;
    final slots = [for (final s in g.slots) s.shift(-origin)];
    final lens = frame.lens.shift(-origin);
    final shown = [for (final i in _shown) widget.destinations[i]];
    final selectedSlot = _slotOf(widget.selectedIndex);
    final collapsedSlot = selectedSlot ?? 0;
    final restOpacity = frame.visible
        ? frame.restOpacity * (1 - frame.engage)
        : 0.0;

    Widget cells({required bool tinted}) => _Cells(
      form: widget.form,
      destinations: shown,
      iconOnly: [for (final d in shown) _topIconOnly(d)],
      slots: slots,
      color: tinted ? scheme.primary : theme.tabForeground,
      style: _labelStyle(
        theme,
        tinted: tinted,
      ).copyWith(color: tinted ? scheme.primary : theme.tabForeground),
      lineHeight: lineHeight,
      ax: ax,
      narrow: widget.narrow,
      popSlot: tinted ? frame.popSlot : null,
      popScale: frame.popScale,
    );

    final children = <Widget>[
      // 1. The pill glass, alone: the content is not squashed by the morph.
      Positioned.fromRect(
        rect: glass,
        child: const LiquidGlass(
          key: kTabPillKey,
          borderRadius: _capsule,
          child: SizedBox.expand(),
        ),
      ),
      // 2. Content at the full pill rect, scaled with the pill, faded by
      //    the morph, built only while visible. Never takes touches, and
      //    adds no semantics: the slot nodes carry it (spec §8.9).
      if (fade > 0)
        Positioned.fromRect(
          rect: g.pill,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Transform.scale(
                scale: frame.pillScale * dip,
                child: Opacity(
                  opacity: fade,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _PillPainter(
                            lens: lens,
                            fill: theme.selectionFill,
                            fillOpacity: restOpacity,
                            ghost: frame.ghost?.shift(-origin),
                            ghostOpacity: frame.ghostOpacity,
                            highlight: frame.highlight * (dark ? 0.25 : 0.85),
                            glowCenter: frame.glowCenter?.translate(
                              -origin.dx,
                              -origin.dy,
                            ),
                            glowDiameter: frame.glowDiameter,
                            glowOpacity: frame.glowOpacity,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: ClipPath(
                          key: kTabNormalKey,
                          clipper: _LensClip(
                            frame.visible ? lens : Rect.zero,
                            inside: false,
                          ),
                          child: cells(tinted: false),
                        ),
                      ),
                      if (frame.visible && frame.engage > 0.001)
                        Positioned.fromRect(
                          rect: lens,
                          // The one fade of the whole lens: the shader
                          // writes alpha 1 and the lens is engage-agnostic
                          // (spec §7.2).
                          child: Opacity(
                            opacity: frame.engage,
                            child: LiquidLens(refraction: frame.refraction),
                          ),
                        ),
                      Positioned.fill(
                        child: ClipPath(
                          key: kTabTintedKey,
                          clipper: _LensClip(
                            frame.visible ? lens : Rect.zero,
                            inside: true,
                          ),
                          child: Transform(
                            alignment: Alignment.topLeft,
                            transform: Matrix4.identity()
                              ..translateByDouble(
                                lens.center.dx,
                                lens.center.dy,
                                0,
                                1,
                              )
                              ..scaleByDouble(
                                frame.magnify,
                                frame.magnify,
                                1,
                                1,
                              )
                              ..translateByDouble(
                                -lens.center.dx,
                                -lens.center.dy,
                                0,
                                1,
                              ),
                            child: cells(tinted: true),
                          ),
                        ),
                      ),
                      _Badges(
                        destinations: shown,
                        slots: slots,
                        width: g.pill.width,
                        direction: direction,
                        ax: ax,
                        parts: (slot, d) => _cellParts(
                          form: widget.form,
                          slot: slot,
                          iconOnly: _topIconOnly(d),
                          ax: ax,
                          lineHeight: lineHeight,
                          direction: direction,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      // 3. The collapsed icon moving into the circle.
      if (morph > 0 && shown.isNotEmpty)
        Positioned.fromRect(
          rect: Rect.lerp(
            _collapsedFrom(g.slots[collapsedSlot], lineHeight, direction),
            Rect.fromCenter(
              center: g.minimized.center,
              width: TabMetrics.iconFrame.width,
              height: TabMetrics.iconFrame.height,
            ),
            morph,
          )!,
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: Opacity(
                opacity: (morph / 0.4).clamp(0.0, 1.0),
                child: _CollapsedIcon(
                  destination: shown[collapsedSlot],
                  color: selectedSlot == null || !widget.tintCollapsed
                      ? theme.tabForeground
                      : scheme.primary,
                ),
              ),
            ),
          ),
        ),
      // 4. The trailing circle.
      if (widget.trailing case final action?)
        Positioned.fromRect(
          key: kTabTrailingKey,
          rect: Rect.lerp(g.trailing, g.minimizedTrailing, morph)!,
          child: LiquidActionCircle(
            action: action,
            highlight: _ownTarget!.hovered,
          ),
        ),
      // 5. Touches and semantics: one recognizer for the whole row (spec
      //    §8.6), fed only by the slots' tap areas. It waits instead of
      //    winning on touch-down at AX sizes (the large content viewer)
      //    and inside a vertical scroll view, whose scroll it must not
      //    take.
      if (morph < 0.5)
        Positioned.fromRect(
          rect: g.pill,
          child: RawGestureDetector(
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
                      ..onDown = ((p) => _down(p + g.pill.topLeft))
                      ..onMove = ((p) => _move(p + g.pill.topLeft))
                      ..onUp = ((p, v) => _up(p + g.pill.topLeft, v))
                      ..onCancel = _cancel,
                  ),
            },
            child: Stack(
              children: [
                for (final (s, d) in shown.indexed)
                  Positioned.fromRect(
                    rect: slots[s],
                    child: _slotNode(s, d, ax, _hitRect(slots, s)),
                  ),
              ],
            ),
          ),
        )
      else if (shown.isNotEmpty)
        Positioned.fromRect(
          rect: glass,
          child: _collapsedNode(shown[collapsedSlot]),
        ),
    ];
    return Stack(clipBehavior: Clip.none, children: children);
  }

  /// Where the collapsed icon starts: the slot's icon frame (compact), or
  /// a frame of the same size around the slot's icon (landscape).
  Rect _collapsedFrom(Rect slot, double lineHeight, TextDirection direction) {
    if (widget.form == TabBarForm.compact) return tabIconFrame(slot);
    final (icon, _) = _cellParts(
      form: widget.form,
      slot: slot,
      iconOnly: false,
      ax: false,
      lineHeight: lineHeight,
      direction: direction,
    );
    return Rect.fromCenter(
      center: (icon ?? Offset.zero & slot.size).shift(slot.topLeft).center,
      width: TabMetrics.iconFrame.width,
      height: TabMetrics.iconFrame.height,
    );
  }

  /// The part of `slots[s]` that takes its touches, slot-local.
  ///
  /// Neighbouring capsules overlap by 8. Each overlap is split at its
  /// midpoint, so a tap goes to the nearest slot, as on native. When that
  /// leaves a slot narrower than [_minTapWidth] (P1 Q17: 5 tabs and a circle
  /// at 320, pitch 43.6), the narrow slots get [_minTapWidth] and the others
  /// share the rest of the row evenly: the end slots give up some of their
  /// outer room, and every area stays inside its own capsule. The semantics
  /// node keeps the whole capsule.
  static Rect _hitRect(List<Rect> slots, int s) {
    final order = [for (var i = 0; i < slots.length; i++) i]
      ..sort((a, b) => slots[a].center.dx.compareTo(slots[b].center.dx));
    final n = order.length;
    final first = slots[order.first];
    final last = slots[order.last];
    // Edges between visual neighbours, at the overlap midpoints.
    final edges = [
      first.left,
      for (var k = 0; k + 1 < n; k++)
        (slots[order[k]].right + slots[order[k + 1]].left) / 2,
      last.right,
    ];
    final widths = [for (var k = 0; k < n; k++) edges[k + 1] - edges[k]];
    final span = last.right - first.left;
    final floor = math.min(_minTapWidth, span / n);
    final narrow = widths.where((w) => w < floor).length;
    if (narrow > 0) {
      final rest = (span - narrow * floor) / (n - narrow);
      for (var k = 0; k < n; k++) {
        widths[k] = widths[k] < floor ? floor : rest;
      }
      for (var k = 0; k < n; k++) {
        edges[k + 1] = edges[k] + widths[k];
      }
    }
    final k = order.indexOf(s);
    final r = slots[s];
    return Rect.fromLTRB(
      math.max(edges[k], r.left),
      r.top,
      math.min(edges[k + 1], r.right),
      r.bottom,
    ).shift(-r.topLeft);
  }

  /// The slot whose tap area holds bar-local [x], or null.
  static int? _slotUnder(TabBarGeometry g, double x) {
    for (var s = 0; s < g.slots.length; s++) {
      final hit = _hitRect(g.slots, s).shift(g.slots[s].topLeft);
      if (x >= hit.left && x < hit.right) return s;
    }
    return null;
  }

  Widget _slotNode(int slot, LiquidDestination d, bool ax, Rect hit) =>
      Semantics(
        container: true,
        button: true,
        selected: _shown[slot] == widget.selectedIndex,
        label: badgeSemanticsLabel(d.label, d.badge, widget.strings),
        onTap: () => _select(slot),
        excludeSemantics: true,
        child: Stack(
          children: [
            Positioned.fromRect(
              rect: hit,
              child: LargeContentViewer(
                icon: d.selectedIcon ?? d.icon,
                label: d.label,
                // Takes the touch for the row's recognizer above.
                child: const MetaData(
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _collapsedNode(LiquidDestination d) {
    final expandable = widget.onCollapsedTap != null;
    // The key sits above the node, so finders can look for the label
    // inside it (P3b tests: `descendant(of: kSearchCollapsedKey, …)`).
    return KeyedSubtree(
      key: widget.collapsedKey,
      child: Semantics(
        container: true,
        button: true,
        label: badgeSemanticsLabel(d.label, d.badge, widget.strings),
        hint: expandable && widget.announceExpand
            ? widget.strings.expandTabBarHint
            : null,
        // Always tappable (P1): `_collapsedTap` does nothing without
        // `onCollapsedTap`, and the hint and announcement stay gated.
        onTap: _collapsedTap,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _collapsedTap,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Icon and label rects inside [slot], slot-local (spec §5.1–§5.3). At
/// AX sizes and for an icon-only slot, the icon takes the whole slot.
(Rect?, Rect?) _cellParts({
  required TabBarForm form,
  required Rect slot,
  required bool iconOnly,
  required bool ax,
  required double lineHeight,
  required TextDirection direction,
}) {
  final local = Offset.zero & slot.size;
  if (ax || iconOnly) return (local, null);
  Rect m(Rect r) => direction == TextDirection.rtl
      ? Rect.fromLTRB(
          slot.width - r.right,
          r.top,
          slot.width - r.left,
          r.bottom,
        )
      : r;
  return switch (form) {
    TabBarForm.compact => (
      tabIconFrame(slot).shift(-slot.topLeft),
      tabLabelBox(slot, lineHeight).shift(-slot.topLeft),
    ),
    // Icon at x + 6, the label after it (spec §5.2).
    TabBarForm.landscape => (
      m(Rect.fromLTWH(6, (slot.height - 25) / 2, 25, 25)),
      m(
        Rect.fromLTWH(
          37,
          0,
          math.max(0, slot.width - TabMetrics.landscapeItemPadding),
          slot.height,
        ),
      ),
    ),
    TabBarForm.top => (null, local),
  };
}

/// One copy of the row: icon and label per slot, pill-local.
class _Cells extends StatelessWidget {
  const _Cells({
    required this.form,
    required this.destinations,
    required this.iconOnly,
    required this.slots,
    required this.color,
    required this.style,
    required this.lineHeight,
    required this.ax,
    required this.narrow,
    this.popSlot,
    this.popScale = 1,
  });

  final TabBarForm form;
  final List<LiquidDestination> destinations;

  /// Per slot: the top form's search item draws its icon alone.
  final List<bool> iconOnly;
  final List<Rect> slots;
  final Color color;

  /// The label style of this copy, colour included.
  final TextStyle style;
  final double lineHeight;
  final bool ax;
  final bool narrow;
  final int? popSlot;
  final double popScale;

  @override
  Widget build(BuildContext context) {
    final theme = LiquidGlassTheme.of(context);
    final direction = Directionality.of(context);
    final base = form == TabBarForm.compact ? theme.tabIconSize : 22.0;
    final iconSize = ax ? axIconSize(context, base) : base;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final (s, d) in destinations.indexed)
          Positioned.fromRect(
            rect: slots[s],
            child: Transform.scale(
              scale: s == popSlot ? popScale : 1,
              child: () {
                final (icon, label) = _cellParts(
                  form: form,
                  slot: slots[s],
                  iconOnly: iconOnly[s],
                  ax: ax,
                  lineHeight: lineHeight,
                  direction: direction,
                );
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (icon != null)
                      Positioned.fromRect(
                        rect: icon,
                        child: Center(
                          child: IconTheme.merge(
                            data: IconThemeData(size: iconSize, color: color),
                            child: d.selectedIcon ?? d.icon,
                          ),
                        ),
                      ),
                    if (label != null)
                      Positioned.fromRect(
                        rect: label,
                        child: Align(
                          alignment: form == TabBarForm.landscape
                              ? AlignmentDirectional.centerStart
                              : Alignment.center,
                          child: narrow && form == TabBarForm.compact
                              ? FitLabel(d.label, style: style)
                              : Text(
                                  d.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: form == TabBarForm.landscape
                                      ? TextAlign.start
                                      : TextAlign.center,
                                  style: style,
                                ),
                        ),
                      ),
                  ],
                );
              }(),
            ),
          ),
      ],
    );
  }
}

/// Badges above both copies, never clipped or magnified.
class _Badges extends StatelessWidget {
  const _Badges({
    required this.destinations,
    required this.slots,
    required this.width,
    required this.direction,
    required this.ax,
    required this.parts,
  });

  final List<LiquidDestination> destinations;
  final List<Rect> slots;
  final double width;
  final TextDirection direction;
  final bool ax;

  /// Icon and label rects of a slot, slot-local ([_cellParts]).
  final (Rect?, Rect?) Function(Rect slot, LiquidDestination d) parts;

  /// The frame the badge sits on: the icon frame, or the label box
  /// deflated to its text when there is no icon (top form), or the slot
  /// deflated by 8 at AX sizes.
  Rect _frame(Rect slot, LiquidDestination d) {
    if (ax) return slot.deflate(8);
    final (icon, label) = parts(slot, d);
    return (icon ?? label!.deflate(8)).shift(slot.topLeft);
  }

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      for (final (s, d) in destinations.indexed)
        if (badgeVisible(d.badge))
          () {
            final frame = _frame(slots[s], d);
            final rtl = direction == TextDirection.rtl;
            return Positioned(
              left: rtl ? null : frame.right - TabMetrics.badgeOutset,
              right: rtl ? width - (frame.left + TabMetrics.badgeOutset) : null,
              top: frame.top - TabMetrics.badgeOutset,
              child: LiquidBadgeView(badge: d.badge!),
            );
          }(),
    ],
  );
}

class _CollapsedIcon extends StatelessWidget {
  const _CollapsedIcon({required this.destination, required this.color});

  final LiquidDestination destination;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = LiquidGlassTheme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Center(
          child: IconTheme.merge(
            data: IconThemeData(size: theme.tabIconSize, color: color),
            child: destination.selectedIcon ?? destination.icon,
          ),
        ),
        if (badgeVisible(destination.badge))
          PositionedDirectional(
            end: -TabMetrics.badgeOutset * 2,
            top: -TabMetrics.badgeOutset,
            child: LiquidBadgeView(badge: destination.badge!),
          ),
      ],
    );
  }
}

/// Inside or outside the lens capsule, pill-local.
class _LensClip extends CustomClipper<Path> {
  const _LensClip(this.lens, {required this.inside});

  final Rect lens;
  final bool inside;

  @override
  Path getClip(Size size) {
    final capsule = Path()
      ..addRRect(
        RRect.fromRectAndRadius(lens, Radius.circular(lens.shortestSide / 2)),
      );
    if (inside) return capsule;
    return Path.combine(
      PathOperation.difference,
      Path()..addRect((Offset.zero & size).inflate(64)),
      capsule,
    );
  }

  @override
  bool shouldReclip(_LensClip oldClipper) =>
      oldClipper.lens != lens || oldClipper.inside != inside;
}

/// Highlight, rest fill (and the reduce-motion ghost), and the finger glow,
/// all pill-local and clipped to the pill capsule.
class _PillPainter extends CustomPainter {
  const _PillPainter({
    required this.lens,
    required this.fill,
    required this.fillOpacity,
    required this.ghost,
    required this.ghostOpacity,
    required this.highlight,
    required this.glowCenter,
    required this.glowDiameter,
    required this.glowOpacity,
  });

  final Rect lens;
  final Color fill;
  final double fillOpacity;
  final Rect? ghost;
  final double ghostOpacity;
  final double highlight;
  final Offset? glowCenter;
  final double glowDiameter;
  final double glowOpacity;

  static RRect _capsule(Rect r) =>
      RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide / 2));

  @override
  void paint(Canvas canvas, Size size) {
    final pill = _capsule(Offset.zero & size);
    if (highlight > 0) {
      canvas.drawRRect(
        pill,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: highlight),
      );
    }
    final ghost = this.ghost;
    if (ghost != null && ghostOpacity > 0) {
      canvas.drawRRect(
        _capsule(ghost),
        Paint()..color = fill.withValues(alpha: fill.a * ghostOpacity),
      );
    }
    if (fillOpacity > 0) {
      canvas.drawRRect(
        _capsule(lens),
        Paint()..color = fill.withValues(alpha: fill.a * fillOpacity),
      );
    }
    final glow = glowCenter;
    if (glow != null && glowOpacity > 0 && glowDiameter > 0) {
      final circle = Rect.fromCircle(center: glow, radius: glowDiameter / 2);
      canvas
        ..save()
        ..clipRRect(pill)
        ..drawCircle(
          glow,
          glowDiameter / 2,
          Paint()
            ..shader = RadialGradient(
              colors: [
                const Color(0xFFFFFFFF).withValues(alpha: glowOpacity),
                const Color(0x00FFFFFF),
              ],
            ).createShader(circle),
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_PillPainter old) =>
      old.lens != lens ||
      old.fill != fill ||
      old.fillOpacity != fillOpacity ||
      old.ghost != ghost ||
      old.ghostOpacity != ghostOpacity ||
      old.highlight != highlight ||
      old.glowCenter != glowCenter ||
      old.glowDiameter != glowDiameter ||
      old.glowOpacity != glowOpacity;
}

/// A drop target for the lens drag (spec VK-503 §8.8): the trailing circle
/// or the search ⌕. The lens stays clamped to the pill; a release while
/// [hovered] fires [onRelease] instead of committing a slot.
class TabDragTarget {
  /// Creates a target whose [rect] is bar-local.
  TabDragTarget({required this.rect, required this.onRelease});

  /// Where it is now, bar-local.
  final Rect Function() rect;

  /// Released over it.
  final VoidCallback onRelease;

  /// The finger is over it.
  final ValueNotifier<bool> hovered = ValueNotifier(false);

  /// Releases [hovered].
  void dispose() => hovered.dispose();
}

/// The white press/hover overlay on a glass circle (spec §8.8): 0.85 in
/// light, 0.25 in dark.
class TabHoverHighlight extends StatelessWidget {
  /// Creates the overlay over [child].
  const TabHoverHighlight({
    required this.hovered,
    required this.child,
    super.key,
  });

  /// When true, the overlay shows.
  final ValueListenable<bool> hovered;

  /// The circle.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        IgnorePointer(
          child: ValueListenableBuilder<bool>(
            valueListenable: hovered,
            builder: (context, on, _) => AnimatedOpacity(
              opacity: on ? 1 : 0,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 100),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFFFFF).withValues(
                    alpha: dark ? 0.25 : 0.85,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
