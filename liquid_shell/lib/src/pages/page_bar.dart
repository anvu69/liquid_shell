import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:liquid_shell/src/native/window_controls.dart';
import 'package:liquid_shell/src/pages/liquid_page.dart';
import 'package:liquid_shell/src/pages/page_title.dart';
import 'package:liquid_shell/src/shell/shell_scope.dart';

/// Height of the bar row (iOS 26: 54pt).
const double kPageBarExtent = 54;

/// Height of the large-title row under the bar row (a root page's
/// collapsing large title).
const double kLargeTitleExtent = 52;

/// Fade height of the scroll-edge effect under the bar.
const double _kEdgeFade = 24;

/// The collapse of a collapsing large title at scroll [offset] (points
/// scrolled below the top): the large row moves up by `largeShift`, from 0
/// to [extent]; the inline title's opacity rises from 0 at half of [extent]
/// to 1 at [extent].
({double largeShift, double inlineOpacity}) pageBarCollapse(
  double offset, {
  double extent = kLargeTitleExtent,
}) {
  final half = extent / 2;
  return (
    largeShift: offset.clamp(0.0, extent),
    inlineOpacity: ((offset - half) / half).clamp(0.0, 1.0),
  );
}

/// A `LiquidPage`'s bar where no native bar draws it: the glass back
/// circle, the title as its [PageTitleMode] draws it, and a scroll-edge
/// fade. Its child gets the bar's height added to its top padding, so
/// `LiquidShellScope.contentPaddingOf` keeps content below it. A collapsing
/// large title keeps that padding while it collapses, as UIKit holds the
/// top inset, so the page is never rebuilt for a scroll frame.
class FlutterPageBar extends StatelessWidget {
  /// Creates the bar. A [PageTitleMode.hidden] title has no bar.
  const FlutterPageBar({
    required this.title,
    required this.mode,
    required this.canPop,
    required this.hideLargeTitle,
    required this.child,
    this.scrollOffset,
    super.key,
  }) : assert(mode != PageTitleMode.hidden, 'a hidden title has no bar');

  /// The title.
  final String title;

  /// How the title is drawn.
  final PageTitleMode mode;

  /// Whether the page's navigator can pop: the back button shows.
  final bool canPop;

  /// Hides the large title (an active search hides it, as UIKit does).
  final bool hideLargeTitle;

  /// The scroll offset of the page's first vertical scroll view: it
  /// collapses a [PageTitleMode.largeCollapsing] title. Null: the title
  /// stays expanded.
  final ValueListenable<double>? scrollOffset;

  /// The page.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final offset = scrollOffset;
    if (mode != PageTitleMode.largeCollapsing || offset == null) {
      return _bar(context, pageBarCollapse(0), child);
    }
    // Rebuilds the title rows and the fade for a scroll frame, never the
    // page: it is the builder's child.
    return ValueListenableBuilder<double>(
      valueListenable: offset,
      builder: (context, value, page) =>
          _bar(context, pageBarCollapse(value), page!),
      child: child,
    );
  }

  Widget _bar(
    BuildContext context,
    ({double largeShift, double inlineOpacity}) collapse,
    Widget page,
  ) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    // Below the shell's own chrome at the top (a Flutter top tab bar).
    final barTop = LiquidShellScope.contentPaddingOf(context).top;
    final rowBottom = barTop + kPageBarExtent;
    final showLargeRow =
        mode == PageTitleMode.largeCollapsing && !hideLargeTitle;
    // The page's top padding: it stays under the large row while the row
    // collapses.
    final bottom = rowBottom + (showLargeRow ? kLargeTitleExtent : 0);
    // Content shows below what is left of the large row.
    final fadeEnd = bottom - (showLargeRow ? collapse.largeShift : 0);
    final largeStyle = theme.textTheme.headlineLarge?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final inline = Text(
      title,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
    final rowTitle = switch (mode) {
      PageTitleMode.inline => inline,
      PageTitleMode.largeInRow when !hideLargeTitle => Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: largeStyle,
      ),
      PageTitleMode.largeCollapsing when showLargeRow => Opacity(
        opacity: collapse.inlineOpacity,
        child: inline,
      ),
      // Hidden by an active search.
      _ => const SizedBox.shrink(),
    };
    final padded = media.copyWith(
      padding: media.padding.copyWith(top: bottom),
      viewPadding: media.viewPadding.copyWith(top: bottom),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: MediaQuery(
            data: padded,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) {
                // Content must not scroll through the bar row or what is
                // left of the large row.
                final end = rect.height == 0 ? 0.0 : fadeEnd / rect.height;
                final start = rect.height == 0
                    ? 0.0
                    : (fadeEnd - _kEdgeFade) / rect.height;
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [Color(0x00000000), Color(0xFF000000)],
                  stops: [start.clamp(0, 1), end.clamp(0, 1)],
                ).createShader(rect);
              },
              child: page,
            ),
          ),
        ),
        Positioned(
          top: barTop,
          left: 0,
          right: 0,
          height: kPageBarExtent,
          // Like the shell's chrome: the titles get the theme's text style
          // even with no Material above the page (a page that is not a
          // Scaffold, or one whose Scaffold is its child).
          child: _Typography(
            child: LiquidWindowControlsClearance(
              rowTop: barTop - media.padding.top,
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  if (canPop) const LiquidBackButton(),
                  Expanded(child: rowTitle),
                  // Keeps an inline title centred against the back button.
                  SizedBox(width: canPop ? 16 + LiquidBackButton.size : 16),
                ],
              ),
            ),
          ),
        ),
        if (showLargeRow)
          Positioned(
            top: rowBottom,
            left: 0,
            right: 0,
            height: kLargeTitleExtent,
            // The row scrolls up under the bar row, clipped to its own box.
            child: ClipRect(
              child: Transform.translate(
                offset: Offset(0, -collapse.largeShift),
                child: _Typography(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: largeStyle,
                      ),
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

/// A transparent [Material], as the tab bar and the sidebar use: its
/// `DefaultTextStyle` is the theme's body style, never the red,
/// double-underlined fallback.
class _Typography extends StatelessWidget {
  const _Typography({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Material(type: MaterialType.transparency, child: child);
}
