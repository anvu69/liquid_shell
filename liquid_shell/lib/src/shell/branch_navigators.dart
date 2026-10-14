import 'package:flutter/widgets.dart';

/// The navigators on screen nearest under [root] (VK-567): the selected
/// tab's own navigator, as an app or a router keeps one per tab in the
/// shell's body.
///
/// A branch hidden with `Visibility` (an `IndexedStack`), `Offstage` or
/// `TickerMode` (a router's indexed-stack shell route) is skipped: "on
/// screen" as `LiquidHideChrome` reads it. The walk stops at each
/// navigator found; a navigator nested in one of its pages belongs to
/// that page's route.
///
/// It walks elements, so call it outside a build (after the frame).
List<NavigatorState> onScreenNavigatorsUnder(BuildContext root) {
  final found = <NavigatorState>[];
  void visit(Element element) {
    switch (element.widget) {
      case Visibility(visible: false) ||
          Offstage(offstage: true) ||
          TickerMode(enabled: false):
        return;
    }
    if (element case StatefulElement(state: final NavigatorState navigator)) {
      found.add(navigator);
      return;
    }
    element.visitChildren(visit);
  }

  root.visitChildElements(visit);
  return found;
}
