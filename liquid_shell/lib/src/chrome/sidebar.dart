import 'package:flutter/material.dart';
import 'package:liquid_shell/src/destinations/badge.dart';
import 'package:liquid_shell/src/destinations/destination.dart';
import 'package:liquid_shell/src/destinations/tab_action.dart';
import 'package:liquid_shell/src/glass/liquid_glass.dart';
import 'package:liquid_shell/src/native/window_controls.dart';
import 'package:liquid_shell/src/shell/strings.dart';

/// Space between the safe-area top and the first sidebar row.
const double _kSidebarTopPadding = 24;

/// A full-height glass sidebar of destinations.
///
/// From top to bottom: a header row (`header` and the hide button, left
/// out when neither is set), the [trailing] action as a row, every
/// destination in list order, and the [footer] pinned to the bottom. It
/// never takes the route's `PrimaryScrollController`, so a body list beside
/// it keeps status-bar scroll-to-top. `LiquidShell` shows it in regular widths;
/// use it directly to build your own chrome.
class LiquidSidebar extends StatelessWidget {
  /// Creates a sidebar.
  const LiquidSidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.onHide,
    this.header,
    this.footer,
    this.trailing,
    this.width = 300,
    this.strings = const LiquidShellStrings(),
    super.key,
  });

  /// All destinations, sidebar-only ones included, in display order.
  final List<LiquidDestination> destinations;

  /// Index into [destinations] of the selected row.
  final int selectedIndex;

  /// Called with an index into [destinations] when a row is tapped.
  final ValueChanged<int> onDestinationSelected;

  /// Shows the hide button when not null.
  final VoidCallback? onHide;

  /// Leading part of the header row.
  final Widget? header;

  /// Pinned to the bottom.
  final Widget? footer;

  /// Shown as the first row (icon and `semanticLabel`), never selected.
  final LiquidTabAction? trailing;

  /// Width in logical pixels.
  final double width;

  /// Hide-button tooltip and badge semantics.
  final LiquidShellStrings strings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pad = MediaQuery.paddingOf(context);
    final start = Directionality.of(context) == TextDirection.ltr
        ? pad.left
        : pad.right;
    final onHide = this.onHide;
    final action = trailing;
    final rows = <Widget>[
      // No header row (and no gap after it) when it would be empty.
      if (header != null || onHide != null)
        // iPadOS 26 windowed: the header row starts past the window
        // controls (spec P2 §8.3). 24 is the list's top padding below the
        // safe area.
        LiquidWindowControlsClearance(
          rowTop: _kSidebarTopPadding,
          child: Row(
            children: [
              Expanded(child: header ?? const SizedBox.shrink()),
              if (onHide != null)
                IconButton(
                  onPressed: onHide,
                  tooltip: strings.hideSidebar,
                  color: scheme.onSurfaceVariant,
                  icon: const Icon(Icons.view_sidebar_outlined),
                ),
            ],
          ),
        ),
      if (action != null)
        _SidebarRow(
          icon: action.icon,
          label: action.semanticLabel,
          semanticsLabel: action.semanticLabel,
          onTap: action.onPressed,
        ),
      for (final (i, destination) in destinations.indexed)
        _SidebarRow(
          icon: i == selectedIndex
              ? destination.selectedIcon ?? destination.icon
              : destination.icon,
          label: destination.label,
          semanticsLabel: badgeSemanticsLabel(
            destination.label,
            destination.badge,
            strings,
          ),
          badge: destination.badge,
          selected: i == selectedIndex,
          onTap: () => onDestinationSelected(i),
        ),
    ];

    return SizedBox(
      width: width,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: BorderDirectional(
            end: BorderSide(color: scheme.outlineVariant),
          ),
        ),
        child: LiquidGlass(
          borderRadius: BorderRadius.zero,
          child: Material(
            type: MaterialType.transparency,
            child: CustomScrollView(
              // Never the route's primary scroll view: beside a body list
              // (tiled layout) a status-bar tap must scroll the body only.
              primary: false,
              slivers: [
                SliverPadding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                    16 + start,
                    _kSidebarTopPadding + pad.top,
                    16,
                    0,
                  ),
                  sliver: SliverList.separated(
                    itemCount: rows.length,
                    itemBuilder: (context, i) => rows[i],
                    separatorBuilder: (context, i) => const SizedBox(height: 8),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      16 + start,
                      8,
                      16,
                      24 + pad.bottom,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.bottomStart,
                      child: footer ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarRow extends StatelessWidget {
  const _SidebarRow({
    required this.icon,
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
    this.badge,
    this.selected,
  });

  final Widget icon;
  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;
  final LiquidBadge? badge;

  /// `null` for the trailing action row, which is never a selection.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSelected = selected ?? false;
    final color = isSelected ? scheme.onPrimaryContainer : scheme.onSurface;
    final badge = this.badge;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: semanticsLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: isSelected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                spacing: 12,
                children: [
                  IconTheme.merge(
                    data: IconThemeData(size: 22, color: color),
                    child: icon,
                  ),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: color,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (badgeVisible(badge)) LiquidBadgeView(badge: badge!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
