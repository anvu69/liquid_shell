import 'dart:async';
import 'dart:math' as math;

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

/// The Flutter tab bar of spec VK-503. Internal: `LiquidTabBar` and the
/// shell build it. It fills the width it is given (the row between the
/// margins) and places its pill per spec §5; gaps pass touches through.
class GlassTabBar extends StatefulWidget {
  /// Creates the bar.
  const GlassTabBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    this.trailing,
    this.minimized = false,
    this.onCollapsedTap,
    this.announceExpand = true,
    this.collapsedKey,
    this.strings = const LiquidShellStrings(),
    this.narrow = false,
    super.key,
  });

  /// All destinations; only `everywhere` ones get a slot.
  final List<LiquidDestination> destinations;

  /// Index into [destinations]; a hidden one highlights nothing.
  final int selectedIndex;

  /// Called on commit with an index into [destinations].
  final ValueChanged<int> onSelect;

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

  @override
  void dispose() {
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

  /// 0 = full bar, 1 = minimized circle. Task 9 animates it.
  double get _morph => widget.minimized ? 1 : 0;

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
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 1 / 30);
    _last = elapsed;
    final m = _motion;
    if (m == null) return;
    var moving = m.advance(dt);
    for (final _ in m.takeCrossings()) {
      // Spec §9 / Q6: one selection click per slot crossing while dragging.
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
        _ticker?.stop();
      }
    }
    setState(() {});
  }

  void _down(Offset p) {
    _motion?.down(p);
    _kick();
  }

  void _move(Offset p) => _motion?.move(p);

  void _up(Offset p, double velocity) {
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

  void _cancel() {
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

  TabBarGeometry _geometryFor(
    double maxWidth,
    TextDirection direction,
    double extent,
  ) => compactTabGeometry(
    count: _shown.length,
    maxWidth: maxWidth,
    trailing: widget.trailing != null,
    direction: direction,
    extent: extent,
  );

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final g = _geometryFor(constraints.maxWidth, direction, extent);
        final motion = _sync(g);
        final override = debugTabLensOverride;
        final frame = override == null ? motion.frame : override(motion.frame);
        return Material(
          type: MaterialType.transparency,
          child: SizedBox.fromSize(
            size: g.size,
            child: _layers(context, g, frame, theme, lineHeight, ax),
          ),
        );
      },
    );
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
    final morph = _morph.clamp(0.0, 1.0);
    final eager =
        !ax && Scrollable.maybeOf(context, axis: Axis.vertical) == null;
    final fade = 1 - (morph / 0.4).clamp(0.0, 1.0);
    final dip = 1 - TabSprings.dip * math.sin(math.pi * morph);
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
      destinations: shown,
      slots: slots,
      color: tinted ? scheme.primary : theme.tabForeground,
      weight: tinted ? FontWeight.w600 : theme.labelStyle.fontWeight,
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
                      // Task 8 inserts the engaged LiquidLens here.
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
            tabIconFrame(g.slots[collapsedSlot]),
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
                  color: selectedSlot == null
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
          child: LiquidActionCircle(action: action),
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

/// One copy of the row: icon and label per slot, pill-local.
class _Cells extends StatelessWidget {
  const _Cells({
    required this.destinations,
    required this.slots,
    required this.color,
    required this.weight,
    required this.lineHeight,
    required this.ax,
    required this.narrow,
    this.popSlot,
    this.popScale = 1,
  });

  final List<LiquidDestination> destinations;
  final List<Rect> slots;
  final Color color;
  final FontWeight? weight;
  final double lineHeight;
  final bool ax;
  final bool narrow;
  final int? popSlot;
  final double popScale;

  @override
  Widget build(BuildContext context) {
    final theme = LiquidGlassTheme.of(context);
    final iconSize = ax
        ? axIconSize(context, theme.tabIconSize)
        : theme.tabIconSize;
    final style = theme.labelStyle.copyWith(color: color, fontWeight: weight);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final (s, d) in destinations.indexed)
          Positioned.fromRect(
            rect: slots[s],
            child: Transform.scale(
              scale: s == popSlot ? popScale : 1,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fromRect(
                    rect: (ax ? slots[s] : tabIconFrame(slots[s])).shift(
                      -slots[s].topLeft,
                    ),
                    child: Center(
                      child: IconTheme.merge(
                        data: IconThemeData(size: iconSize, color: color),
                        child: d.selectedIcon ?? d.icon,
                      ),
                    ),
                  ),
                  if (!ax)
                    Positioned.fromRect(
                      rect: tabLabelBox(
                        slots[s],
                        lineHeight,
                      ).shift(-slots[s].topLeft),
                      child: Center(
                        child: narrow
                            ? FitLabel(d.label, style: style)
                            : Text(
                                d.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: style,
                              ),
                      ),
                    ),
                ],
              ),
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
  });

  final List<LiquidDestination> destinations;
  final List<Rect> slots;
  final double width;
  final TextDirection direction;
  final bool ax;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      for (final (s, d) in destinations.indexed)
        if (badgeVisible(d.badge))
          () {
            final frame = ax ? slots[s].deflate(8) : tabIconFrame(slots[s]);
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
