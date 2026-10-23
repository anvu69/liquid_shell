import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A navigator on screen under the shell's body, and whether a
/// `NavigatorPopHandler` with a callback lies between the body and the first
/// navigator above it (the tab's own): the shell's route calls that callback
/// on every blocked back, enabled or not, so the app answers back for it. A
/// handler inside a tab's page sits on the page's route, which system back
/// never calls, so it does not count.
///
/// `onScreen` false: a tab's own navigator that is hidden at the scan (an
/// unselected tab, or one a router shows frames after the selection), kept
/// so the per-frame check can see it come on screen.
typedef BranchNavigator = ({
  NavigatorState navigator,
  bool handled,
  bool onScreen,
});

/// Whether a `NavigatorPopHandler` answers back: it has a callback.
bool _answersBack(Widget widget) => switch (widget) {
  NavigatorPopHandler(:final onPopWithResult) when onPopWithResult != null =>
    true,
  // The deprecated callback still runs.
  // ignore: deprecated_member_use
  NavigatorPopHandler(:final onPop) when onPop != null => true,
  _ => false,
};

/// Whether [widget] takes its subtree off screen: `Visibility`,
/// `Offstage`, or `TickerMode` (a router's indexed-stack shell route).
bool _hides(Widget widget) => switch (widget) {
  Visibility(visible: false) ||
  Offstage(offstage: true) ||
  TickerMode(enabled: false) => true,
  _ => false,
};

/// Whether [parent] shows its child [child]:
/// - an `IndexedStack` shows only the child at its index, and its render
///   object is what says so: from Flutter 3.47 it no longer wraps the
///   others in a `Visibility` widget;
/// - a scrolling list (`PageView`, `ListView`) shows a child laid out in
///   its visible window, not one kept alive or in the cache extent;
/// - a navigator's overlay shows a page under another route (a dialog, a
///   sheet, a page) without letting it pop first: a child with a route's
///   barrier after it is not shown. Other entries (a toast) do not count.
bool _shows(Element parent, Element child) {
  if (parent is! RenderObjectElement) return true;
  final render = parent.renderObject;
  if (render is RenderIndexedStack) {
    return _position(parent, child) == render.index;
  }
  if (render is RenderSliverMultiBoxAdaptor) return _inWindow(render, child);
  if (_isOverlayTheater(parent)) return !_routeAfter(parent, child);
  return true;
}

int _position(Element parent, Element child) {
  var position = 0;
  var found = -1;
  parent.visitChildren((element) {
    if (identical(element, child)) found = position;
    position++;
  });
  return found;
}

bool _inWindow(RenderSliverMultiBoxAdaptor sliver, Element child) {
  final box = child.renderObject;
  if (box is! RenderBox || !box.hasSize) return false;
  final data = box.parentData;
  if (data is! SliverMultiBoxAdaptorParentData || data.keptAlive) {
    return false;
  }
  final start = sliver.childScrollOffset(box);
  if (start == null) return false;
  final constraints = sliver.constraints;
  final extent = constraints.axis == Axis.horizontal
      ? box.size.width
      : box.size.height;
  final windowStart = constraints.scrollOffset;
  final windowEnd = windowStart + constraints.remainingPaintExtent;
  return start < windowEnd && start + extent > windowStart;
}

/// Whether [element] is an `Overlay`'s list of entries (its only child).
bool _isOverlayTheater(Element element) {
  var theater = false;
  element.visitAncestorElements((parent) {
    theater = parent is StatefulElement && parent.state is OverlayState;
    return false;
  });
  return theater;
}

/// Whether an entry after [child] in [theater] is a route's barrier.
bool _routeAfter(Element theater, Element child) {
  var after = false;
  var barrier = false;
  theater.visitChildren((entry) {
    if (barrier) return;
    if (after && _hasBarrier(entry, _barrierDepth)) barrier = true;
    if (identical(entry, child)) after = true;
  });
  return barrier;
}

/// How deep a route's barrier sits under its overlay entry, with room to
/// spare (6 on Flutter 3.44).
const _barrierDepth = 12;

bool _hasBarrier(Element element, int depth) {
  // A route that is closing (or dismissed) wraps its barrier in an
  // IgnorePointer that ignores: its page no longer covers the one under it
  // (VK-775).
  if (element.widget case IgnorePointer(ignoring: true)) return false;
  if (element.widget is ModalBarrier ||
      element.widget is AnimatedModalBarrier) {
    return true;
  }
  if (depth == 0) return false;
  var found = false;
  element.visitChildren((child) {
    if (!found) found = _hasBarrier(child, depth - 1);
  });
  return found;
}

/// The navigators on screen under [root], in tree order: the selected
/// tab's own navigator, as an app or a router keeps one per tab in the
/// shell's body, then the navigators nested in its top page. A nested one
/// comes after the navigator it is in, so "the last that can pop" pops it
/// first, as iOS does.
///
/// A branch hidden by [_hides] or [_shows] is skipped, but for its first
/// navigator (a hidden tab's own), recorded with `onScreen` false.
///
/// It walks elements, so call it outside a build (after the frame).
List<BranchNavigator> onScreenNavigatorsUnder(BuildContext root) {
  final found = <BranchNavigator>[];
  void visit(
    Element element, {
    required bool handled,
    required bool inside,
    required bool shown,
  }) {
    final widget = element.widget;
    final shownHere = shown && !_hides(widget);
    // A hidden subtree is walked down to its first navigator (a tab's own);
    // a hidden tab with no navigator is walked whole, at scan time only,
    // never per frame.
    if (!shownHere && inside) return;
    final handledHere = handled || (!inside && _answersBack(widget));
    final isNavigator =
        element is StatefulElement && element.state is NavigatorState;
    if (element case StatefulElement(state: final NavigatorState navigator)) {
      found.add((
        navigator: navigator,
        handled: handledHere,
        onScreen: shownHere,
      ));
    }
    final insideHere = inside || isNavigator;
    element.visitChildren((child) {
      visit(
        child,
        handled: handledHere,
        inside: insideHere,
        shown: shownHere && _shows(element, child),
      );
    });
  }

  root.visitChildElements(
    (child) => visit(child, handled: false, inside: false, shown: true),
  );
  return found;
}

/// Whether [context] is still on screen under [root]: nothing between them
/// hides it. It walks the ancestors plus, at a navigator's overlay, the
/// entries after the one on the path (up to 12 levels each, looking for a
/// route barrier), so it is cheap enough for every frame.
bool isOnScreenUnder(BuildContext context, BuildContext root) {
  var onScreen = true;
  var below = context as Element;
  context.visitAncestorElements((element) {
    if (identical(element, root)) return false;
    if (_hides(element.widget) || !_shows(element, below)) {
      onScreen = false;
      return false;
    }
    below = element;
    return true;
  });
  return onScreen;
}
