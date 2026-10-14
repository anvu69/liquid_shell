// liquid_shell/lib/src/native/native_minimize.dart
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// What one scroll notification did to a [MinimizeScrollTracker].
enum MinimizeScrollResult {
  /// Nothing to send.
  none,

  /// The tab's offset changed.
  moved,

  /// The offset changed, and a fling or a programmatic scroll carried the
  /// content up to its top edge: expand the tab bar (spec VK-600 §9.1).
  expand,
}

/// The smallest offset while the scrolled view is away from its top: the
/// native bar never sees "at the top" before the content is.
const double kMinimizeAwayFromTop = 1;

/// One virtual scroll offset per destination for the native tab bar's
/// minimize (spec VK-600 §9.1): the pixels of a single scroll view, kept
/// continuous across several, snapped to the top edge when the scrolled
/// view reaches its own.
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
  MinimizeScrollResult update({
    required int tab,
    required double pixels,
    required double minScrollExtent,
    required double delta,
    required bool dragging,
  }) {
    final before = offsetOf(tab);
    final atTop = pixels <= minScrollExtent;
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

  /// The shell's adapter: vertical notifications at any depth.
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
        ),
      _ => MinimizeScrollResult.none,
    };
  }

  /// [tab] left the destinations.
  void forget(int tab) {
    _offsets.remove(tab);
    _expanded.remove(tab);
  }
}

/// Whether the shell drives the native tab bar's minimize (spec VK-600
/// §9.2); the native side attaches its pan under the same facts (§8.3).
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
