import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A navigator on screen under the shell's body, and whether a
/// `NavigatorPopHandler` with a callback lies between the body and it: the
/// route calls that callback on every blocked back, enabled or not, so the
/// app answers back for it.
typedef BranchNavigator = ({NavigatorState navigator, bool handled});

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
///   its visible window, not one kept alive or in the cache extent.
bool _shows(Element parent, Element child) {
  if (parent is! RenderObjectElement) return true;
  final render = parent.renderObject;
  if (render is RenderIndexedStack) {
    return _position(parent, child) == render.index;
  }
  if (render is RenderSliverMultiBoxAdaptor) return _inWindow(render, child);
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

/// The navigators on screen nearest under [root]: the selected tab's own
/// navigator, as an app or a router keeps one per tab in the shell's body.
///
/// A branch hidden by [_hides] is skipped. The walk stops at each navigator
/// found; a navigator nested in one of its pages is not looked at.
///
/// It walks elements, so call it outside a build (after the frame).
List<BranchNavigator> onScreenNavigatorsUnder(BuildContext root) {
  final found = <BranchNavigator>[];
  void visit(Element element, {required bool handled}) {
    final widget = element.widget;
    if (_hides(widget)) return;
    final handledHere = handled || _answersBack(widget);
    if (element case StatefulElement(state: final NavigatorState navigator)) {
      found.add((navigator: navigator, handled: handledHere));
      return;
    }
    element.visitChildren((child) {
      if (_shows(element, child)) visit(child, handled: handledHere);
    });
  }

  root.visitChildElements((child) => visit(child, handled: false));
  return found;
}

/// Whether [context] is still on screen under [root]: nothing between them
/// hides it. It walks ancestors only, so it is cheap enough for every frame.
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
