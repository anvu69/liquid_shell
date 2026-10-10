import 'package:flutter/material.dart';
import 'package:liquid_shell/src/native/window_controls.dart';
import 'package:liquid_shell/src/pages/liquid_page.dart';
import 'package:liquid_shell/src/shell/shell_scope.dart';

/// Height of the bar row (iOS 26: 54pt).
const double kPageBarExtent = 54;

/// Height of the large title row.
const double kLargeTitleExtent = 52;

/// Fade height of the scroll-edge effect under the bar.
const double _kEdgeFade = 24;

/// A `LiquidPage`'s bar where no native bar draws it (spec P3b §9.5): the
/// glass back circle, the inline or large title, and a scroll-edge fade.
/// Its child gets the bar's height added to its top padding, so
/// `LiquidShellScope.contentPaddingOf` keeps content below it.
class FlutterPageBar extends StatelessWidget {
  /// Creates the bar.
  const FlutterPageBar({
    required this.title,
    required this.large,
    required this.canPop,
    required this.hideLargeTitle,
    required this.child,
    super.key,
  });

  /// The title.
  final String title;

  /// Large title (otherwise inline in the bar row).
  final bool large;

  /// Whether the page's navigator can pop: the back button shows.
  final bool canPop;

  /// Hides the large title (an active search hides it, as UIKit does).
  final bool hideLargeTitle;

  /// The page.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    // Below the shell's own chrome at the top (a Flutter top tab bar).
    final barTop = LiquidShellScope.contentPaddingOf(context).top;
    final showLarge = large && !hideLargeTitle;
    final bottom =
        barTop + kPageBarExtent + (showLarge ? kLargeTitleExtent : 0);
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
                // Ends under the large title row too: that title does not
                // collapse here, so content must not scroll through it.
                final end = rect.height == 0 ? 0.0 : bottom / rect.height;
                final start = rect.height == 0
                    ? 0.0
                    : (bottom - _kEdgeFade) / rect.height;
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [Color(0x00000000), Color(0xFF000000)],
                  stops: [start.clamp(0, 1), end.clamp(0, 1)],
                ).createShader(rect);
              },
              child: child,
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
                  Expanded(
                    child: large
                        ? const SizedBox.shrink()
                        : Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  // Keeps an inline title centred against the back button.
                  SizedBox(width: canPop ? 16 + LiquidBackButton.size : 16),
                ],
              ),
            ),
          ),
        ),
        if (showLarge)
          PositionedDirectional(
            top: barTop + kPageBarExtent,
            start: 16,
            end: 16,
            height: kLargeTitleExtent,
            child: _Typography(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w700,
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
