// liquid_shell/lib/src/native/native_minimize.dart
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid_shell_platform_interface/liquid_shell_platform_interface.dart';

/// What one scroll notification did to a [MinimizeScrollTracker].
enum MinimizeScrollResult {
  /// Nothing to send.
  none,

  /// The tab's offset changed.
  moved,

  /// The offset changed, and a fling or a programmatic scroll carried the
  /// content up to its top edge: expand the tab bar.
  expand,
}

/// The smallest offset while the scrolled view is away from its top: the
/// native bar never sees "at the top" before the content is.
const double kMinimizeAwayFromTop = 1;

/// One virtual scroll offset per destination for the native tab bar's
/// minimize: the pixels of a single scroll view, kept
/// continuous across several while they scroll, snapped to the top edge
/// when the scrolled view reaches its own, and lowered to that view's own
/// at the end of each scroll, never raised. A view nested in another
/// vertical one moves it but is never its top.
final class MinimizeScrollTracker {
  final Map<int, double> _offsets = {};
  final Set<int> _expanded = {};

  /// The offset of [tab]: positive below the top, zero or negative at it.
  double offsetOf(int tab) => _offsets[tab] ?? 0;

  /// A new scroll on [tab]: it may expand once.
  MinimizeScrollResult start({required int tab}) {
    _expanded.remove(tab);
    return MinimizeScrollResult.none;
  }

  /// The scrolled view of [tab] moved by [delta] to [pixels].
  ///
  /// A [nested] view sits inside another vertical one: it moves the offset,
  /// but its own top is not the page's, so it never reaches the top nor
  /// expands (a small list in a card, a NestedScrollView's inner list).
  MinimizeScrollResult update({
    required int tab,
    required double pixels,
    required double minScrollExtent,
    required double delta,
    required bool dragging,
    bool nested = false,
  }) {
    final before = offsetOf(tab);
    final atTop = !nested && pixels <= minScrollExtent;
    final next = atTop
        ? pixels - minScrollExtent
        : math.max(before + delta, kMinimizeAwayFromTop);
    _offsets[tab] = next;
    // UIKit's rule (spike §3.1): a deceleration that reaches the top
    // expands; a drag into it does not, nor does the bounce back.
    if (!dragging && delta < 0 && atTop && _expanded.add(tab)) {
      return MinimizeScrollResult.expand;
    }
    return next == before
        ? MinimizeScrollResult.none
        : MinimizeScrollResult.moved;
  }

  /// The scroll of [tab]'s view ended at [pixels]. At rest the offset drops
  /// to that view's own, so what the deltas missed (a view replaced, pixels
  /// corrected without a notification) does not outlive one scroll.
  ///
  /// It never rises to it. After a flick UIKit's own deceleration on the
  /// proxy may still be running and reads Dart's writes (spike C11), so a
  /// jump down there (several views in one tab, corrected pixels) would read
  /// as a scroll down and minimize. A view at its top still gives its own
  /// (zero or less); a view below its top lifts an offset at the top only
  /// to [kMinimizeAwayFromTop].
  MinimizeScrollResult end({
    required int tab,
    required double pixels,
    required double minScrollExtent,
  }) {
    final before = offsetOf(tab);
    final extent = pixels - minScrollExtent;
    final next = extent <= 0
        ? extent
        : math.min(
            math.max(extent, kMinimizeAwayFromTop),
            math.max(before, kMinimizeAwayFromTop),
          );
    _offsets[tab] = next;
    return next == before
        ? MinimizeScrollResult.none
        : MinimizeScrollResult.moved;
  }

  /// The shell's adapter: vertical notifications at any depth. A view
  /// nested in another vertical one moves the offset only ([update]); the
  /// end of a scroll that is not nested puts the offset at rest ([end]).
  MinimizeScrollResult handleNotification(
    ScrollNotification n, {
    required int tab,
  }) {
    final metrics = n.metrics;
    if (metrics.axis != Axis.vertical) return MinimizeScrollResult.none;
    return switch (n) {
      ScrollStartNotification() => start(tab: tab),
      ScrollUpdateNotification(:final scrollDelta, :final dragDetails) =>
        update(
          tab: tab,
          pixels: metrics.pixels,
          minScrollExtent: metrics.minScrollExtent,
          delta: scrollDelta ?? 0,
          dragging: dragDetails != null,
          nested: _nestedInVertical(n),
        ),
      ScrollEndNotification() when !_nestedInVertical(n) => end(
        tab: tab,
        pixels: metrics.pixels,
        minScrollExtent: metrics.minScrollExtent,
      ),
      _ => MinimizeScrollResult.none,
    };
  }

  /// Whether [n]'s view sits inside another vertical scroll view below the
  /// listener. [ScrollNotification.depth] counts the viewports it passed on
  /// the way up: zero, the common case, needs no walk; otherwise as many
  /// enclosing scroll views are looked at, so a page in a horizontal
  /// `PageView` is still the page.
  static bool _nestedInVertical(ScrollNotification n) {
    var enclosing = n.depth;
    if (enclosing == 0) return false;
    // The sender first: the notification's context is inside it.
    var scrollable = n.context?.findAncestorStateOfType<ScrollableState>();
    while (scrollable != null && enclosing-- > 0) {
      scrollable = scrollable.context
          .findAncestorStateOfType<ScrollableState>();
      if (scrollable?.widget.axis == Axis.vertical) return true;
    }
    return false;
  }

  /// [tab] left the destinations.
  void forget(int tab) {
    _offsets.remove(tab);
    _expanded.remove(tab);
  }
}

/// Whether sending [next] after [previous] may rebuild the native tabs,
/// whose new hosts start at offset 0: the shell then
/// sends the offset again. Any change of the tabs or the trailing action
/// counts, a superset of what the platform rebuilds for. Null [previous]:
/// nothing built yet.
bool nativeTabsMayRebuild(
  LiquidNativeChromeConfig? previous,
  LiquidNativeChromeConfig next,
) =>
    previous == null ||
    !listEquals(previous.tabs, next.tabs) ||
    previous.trailing != next.trailing;

/// Whether the shell drives the native tab bar's minimize; the native side
/// attaches its pan under the same facts.
bool nativeMinimizeActive({
  required bool owner,
  required bool engaged,
  required bool compact,
  required bool minimizeOnScroll,
  required bool searchSelected,
  required bool hidden,
  required bool routeCurrent,
}) =>
    owner &&
    engaged &&
    compact &&
    minimizeOnScroll &&
    !searchSelected &&
    !hidden &&
    routeCurrent;
