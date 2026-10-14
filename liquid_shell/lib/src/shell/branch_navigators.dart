import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A navigator on screen under the shell's body (VK-567), and whether an
/// enabled `NavigatorPopHandler` between the body and it answers system
/// back for it (an app that wraps its branch, as the README once showed).
typedef BranchNavigator = ({NavigatorState navigator, bool handled});

/// Whether [widget] takes its subtree off screen: `Visibility`,
/// `Offstage`, or `TickerMode` (a router's indexed-stack shell route).
bool _hides(Widget widget) => switch (widget) {
  Visibility(visible: false) ||
  Offstage(offstage: true) ||
  TickerMode(enabled: false) => true,
  _ => false,
};

/// Whether [parent] shows its child [child]. An `IndexedStack` shows only
/// the child at its index, and its render object is what says so: from
/// Flutter 3.47 it no longer wraps the others in a `Visibility` widget
/// (a private scope does that job), so no widget above them hides them.
bool _shows(Element parent, Element child) {
  if (parent is! RenderObjectElement) return true;
  final render = parent.renderObject;
  if (render is! RenderIndexedStack) return true;
  var position = 0;
  var shown = false;
  parent.visitChildren((element) {
    if (identical(element, child)) shown = position == render.index;
    position++;
  });
  return shown;
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
    final handledHere =
        handled || (widget is NavigatorPopHandler && widget.enabled);
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
