import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:liquid_shell/src/chrome/fit_label.dart';
import 'package:liquid_shell/src/chrome/large_content_viewer.dart';
import 'package:liquid_shell/src/chrome/text_scale.dart';
import 'package:liquid_shell/src/destinations/badge.dart';
import 'package:liquid_shell/src/destinations/destination.dart';
import 'package:liquid_shell/src/destinations/tab_action.dart';
import 'package:liquid_shell/src/glass/glass_theme.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';
import 'package:liquid_shell/src/shell/strings.dart';

/// Where a [LiquidTabBar] sits, which sets its cell layout.
enum LiquidTabBarPosition {
  /// Compact: floating at the bottom, icon over label, 62pt pill.
  bottom,

  /// Regular: floating at the top, icon beside label, 52pt pill.
  top,
}

/// The gap between the pill and the trailing circle.
const double kLiquidTabBarTrailingGap = 8;

/// Below this width (logical pixels) the bottom tab bar is *narrow*: its
/// pill padding drops from 8 to 4, and `LiquidShell` shrinks the row margin
/// from 16 to 8, so 5 tabs plus a trailing action keep 44pt-wide cells down
/// to 320 at text scale 1 (iPad Slide Over, ⅓ Split View, small phones).
/// Larger text grows the pill, and the square trailing circle with it, so
/// cells can drop below 44pt there.
///
/// A narrow bar also fits its labels (Q18): a label that does not fit its
/// cell first takes the cell's side padding, then shrinks down to 10pt, and
/// only then ellipsizes.
const double kLiquidNarrowWidth = 340;

/// A floating glass pill of destinations, with an optional separate glass
/// circle for a [LiquidTabAction].
///
/// `LiquidShell` places it for you. Use it directly to build your own
/// chrome. It draws the row only: the caller adds the outer margins.
///
/// Standalone use needs a [Directionality] and an [Overlay] above it: the
/// trailing tooltip and the large content viewer (long press at accessibility
/// text sizes) show in the overlay. Inside a route of a `MaterialApp` both
/// are present; in `MaterialApp.builder`, above the `Navigator`, there is no
/// [Overlay]. Debug builds assert both. ([MediaQuery] always comes from the
/// enclosing `View`.)
class LiquidTabBar extends StatelessWidget {
  /// Creates a tab bar.
  const LiquidTabBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.position = LiquidTabBarPosition.bottom,
    this.trailing,
    this.minimized = false,
    this.onExpand,
    this.strings = const LiquidShellStrings(),
    this.narrow,
    super.key,
  });

  /// All destinations. Only [LiquidPlacement.everywhere] ones are shown.
  final List<LiquidDestination> destinations;

  /// Index into [destinations]. A hidden (sidebar-only) index highlights
  /// nothing.
  final int selectedIndex;

  /// Called with an index into [destinations] when a cell is tapped while
  /// the bar is not minimised.
  final ValueChanged<int> onDestinationSelected;

  /// Bottom (compact) or top (regular) layout.
  final LiquidTabBarPosition position;

  /// Optional action in a separate circle at the trailing end.
  final LiquidTabAction? trailing;

  /// Shows only the selected cell. A tap then calls [onExpand] and does not
  /// change the destination.
  final bool minimized;

  /// Called when the minimised bar is tapped. When null, the minimised bar
  /// neither announces an expansion nor carries the expand hint.
  final VoidCallback? onExpand;

  /// Strings for the minimised hint, the expand announcement and badges.
  final LiquidShellStrings strings;

  /// Whether to use the narrow pill padding (4 instead of 8 at each end of
  /// the bottom pill) and fit the bottom labels (they take the cell's side
  /// padding, then shrink to 10pt, before they ellipsize). Null: narrow when
  /// `MediaQuery.sizeOf(context).width` is below [kLiquidNarrowWidth]. The
  /// top bar is the same either way.
  ///
  /// `MediaQuery` is the window. When the bar sits in a pane narrower than
  /// the window (an in-app split view, a fixed-width column), pass [narrow]
  /// yourself, for example `constraints.maxWidth < kLiquidNarrowWidth` from
  /// a `LayoutBuilder` around the pane. The same goes for a `LiquidShell`
  /// `chromeBuilder` that builds its own [LiquidTabBar] while the shell is
  /// narrower than the window: the shell decides from its own width, the
  /// default here from the window's.
  final bool? narrow;

  @override
  Widget build(BuildContext context) {
    assert(
      debugCheckHasDirectionality(context),
      'LiquidTabBar needs a Directionality ancestor.',
    );
    assert(
      debugCheckHasOverlay(context),
      'LiquidTabBar needs an Overlay ancestor.',
    );
    final visible = [
      for (final (i, destination) in destinations.indexed)
        if (destination.placement == LiquidPlacement.everywhere) i,
    ];
    final shown = !minimized || visible.isEmpty
        ? visible
        : [
            if (visible.contains(selectedIndex))
              selectedIndex
            else
              visible.first,
          ];
    final top = position == LiquidTabBarPosition.top;
    final ax = isAxTextScale(context);

    void handleTap(int index) {
      if (!minimized) {
        onDestinationSelected(index);
        return;
      }
      final expand = onExpand;
      // Nothing opens without onExpand, so there is nothing to announce.
      if (expand == null) return;
      expand();
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          strings.tabBarExpanded,
          Directionality.of(context),
        ),
      );
    }

    final narrow =
        this.narrow ?? MediaQuery.sizeOf(context).width < kLiquidNarrowWidth;
    final cells = Padding(
      padding: top
          ? const EdgeInsets.all(4)
          : EdgeInsets.symmetric(horizontal: narrow ? 4 : 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final i in shown)
            Flexible(
              child: _Cell(
                destination: destinations[i],
                selected: i == selectedIndex,
                minimized: minimized,
                expandable: onExpand != null,
                top: top,
                narrow: narrow && !top,
                ax: ax,
                strings: strings,
                onTap: () => handleTap(i),
              ),
            ),
        ],
      ),
    );
    // The size animates INSIDE the glass, so the glass background (its
    // rounded shape and outside shadow) follows the animated size instead of
    // being laid out at full size and clipped square by AnimatedSize.
    final pill = LiquidGlass(
      child: MediaQuery.disableAnimationsOf(context)
          ? cells
          : AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: cells,
            ),
    );

    final action = trailing;
    return Material(
      type: MaterialType.transparency,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(child: pill),
            if (action != null) ...[
              const SizedBox(width: kLiquidTabBarTrailingGap),
              LiquidActionCircle(action: action),
            ],
          ],
        ),
      ),
    );
  }
}

/// Side padding of a bottom cell.
const double _cellSidePadding = 8;

class _Cell extends StatelessWidget {
  const _Cell({
    required this.destination,
    required this.selected,
    required this.minimized,
    required this.expandable,
    required this.top,
    required this.narrow,
    required this.ax,
    required this.strings,
    required this.onTap,
  });

  final LiquidDestination destination;
  final bool selected;
  final bool minimized;

  /// Whether a tap on the minimised cell opens the bar ([LiquidTabBar.onExpand]
  /// is set). Without it the cell carries no expand hint.
  final bool expandable;
  final bool top;

  /// Narrow bottom cell: the label fits itself (Q18).
  final bool narrow;
  final bool ax;
  final LiquidShellStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    final base = top ? 22.0 : 28.0;
    final iconSize = ax ? axIconSize(context, base) : base;
    final icon = _BadgedIcon(
      icon: selected
          ? destination.selectedIcon ?? destination.icon
          : destination.icon,
      badge: destination.badge,
      size: iconSize,
      color: color,
    );
    final labelStyle = top
        ? theme.textTheme.labelMedium?.copyWith(color: color)
        : LiquidGlassTheme.of(context).labelStyle.copyWith(color: color);
    final label = ax
        ? null
        : narrow
        // The label may take the cell's side padding before it shrinks.
        ? FitLabel(
            destination.label,
            style: labelStyle,
            slack: 2 * _cellSidePadding,
          )
        : Text(
            destination.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          );
    final decoration = BoxDecoration(
      color: selected ? scheme.primaryContainer : Colors.transparent,
      borderRadius: const BorderRadius.all(Radius.circular(999)),
    );

    final content = top
        ? Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: decoration,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                if (label != null) ...[
                  const SizedBox(width: 8),
                  Flexible(child: label),
                ],
              ],
            ),
          )
        : Container(
            constraints: const BoxConstraints(maxWidth: 88),
            // Narrow: the side padding moves onto the icon, so the cell keeps
            // its width while the label may use the padding.
            padding: EdgeInsets.symmetric(
              horizontal: narrow ? 0 : _cellSidePadding,
              vertical: 4,
            ),
            decoration: decoration,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (narrow)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _cellSidePadding,
                    ),
                    child: icon,
                  )
                else
                  icon,
                if (label != null) ...[const SizedBox(height: 4), label],
              ],
            ),
          );

    return Semantics(
      container: true,
      button: true,
      // While minimised a tap expands the bar instead of selecting, so the
      // node must not claim a selected state at all.
      selected: minimized ? null : selected,
      label: badgeSemanticsLabel(destination.label, destination.badge, strings),
      hint: minimized && expandable ? strings.expandTabBarHint : null,
      onTap: onTap,
      excludeSemantics: true,
      child: LargeContentViewer(
        icon: destination.icon,
        label: destination.label,
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          onTap: onTap,
          child: content,
        ),
      ),
    );
  }
}

class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({
    required this.icon,
    required this.badge,
    required this.size,
    required this.color,
  });

  final Widget icon;
  final LiquidBadge? badge;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final themed = IconTheme.merge(
      data: IconThemeData(size: size, color: color),
      child: icon,
    );
    final badge = this.badge;
    if (!badgeVisible(badge)) return themed;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        themed,
        PositionedDirectional(
          top: -4,
          end: -8,
          child: LiquidBadgeView(badge: badge!),
        ),
      ],
    );
  }
}

/// A glass circle for a [LiquidTabAction]: square, as tall as its row.
class LiquidActionCircle extends StatelessWidget {
  /// Creates the circle.
  const LiquidActionCircle({required this.action, super.key});

  /// The action.
  final LiquidTabAction action;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    button: true,
    label: action.semanticLabel,
    onTap: action.onPressed,
    excludeSemantics: true,
    child: Tooltip(
      message: action.semanticLabel,
      excludeFromSemantics: true,
      child: LiquidGlass(
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: action.onPressed,
          child: AspectRatio(
            aspectRatio: 1,
            child: Center(
              child: IconTheme.merge(
                data: IconThemeData(
                  size: 26,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                child: action.icon,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
