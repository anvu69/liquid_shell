import UIKit

/// Where the search tab's field goes (spec P3b §7.2).
enum SearchPlacement: Equatable {
  /// UIKit decides: on an iPhone the field is hosted in the tab bar.
  case automatic
  /// Below the title row; rises into it when active (the owner's iPad video).
  case stacked
}

/// The search tab's navigation item settings for one device and OS.
struct SearchTabStyle: Equatable {
  let placement: SearchPlacement
  /// nil keeps UIKit's default.
  let hidesWhenScrolling: Bool?
  /// The root's `largeTitleDisplayMode`.
  let titleMode: UINavigationItem.LargeTitleDisplayMode
  /// The root's small title as a leading item, at compact width: UIKit
  /// draws no title for a `UISearchTab`'s root on an iPad.
  let titleItem: Bool
  /// `UITabBarController.prominentTabIdentifier` = the search tab (iOS 27).
  let prominent: Bool
}

/// Pure decisions of the search tab, unit-tested without UIKit.
enum SearchMath {
  /// iPhone: UIKit's tab-hosted field, a large title on the bar row
  /// (`.inline`, Apple Music), and on iOS 27 the prominent search tab
  /// (without it 27 makes Search an inline tab). iPad (any width): the
  /// stacked field, always visible, under a small title; never prominent
  /// (Q1). The app's `largeTitle` wins when set.
  ///
  /// UIKit draws no `.never` or `.inline` title for a `UISearchTab`'s root
  /// on an iPad (measured on 26.5 and 27.0; a plain `UITab`'s root shows
  /// it). The small title is therefore a leading item there, and a large
  /// one is `.always`, the only mode UIKit still draws.
  @available(iOS 17.0, *)
  static func style(isPad: Bool, osMajor: Int, rootLargeTitle: Bool?) -> SearchTabStyle {
    if isPad {
      let large = rootLargeTitle ?? false
      return SearchTabStyle(
        placement: .stacked, hidesWhenScrolling: false, titleMode: large ? .always : .never,
        titleItem: !large, prominent: false)
    }
    return SearchTabStyle(
      placement: .automatic, hidesWhenScrolling: nil,
      titleMode: (rootLargeTitle ?? true) ? .inline : .never, titleItem: false,
      prominent: osMajor >= 27)
  }

  /// Flutter's top inset while a page's proxy scroll view is scrolled: the
  /// resting value, so the padding does not shrink as the large title
  /// collapses (spec §7.7). At rest: the current value.
  static func heldTop(current: CGFloat, resting: CGFloat, scrolled: Bool) -> CGFloat {
    scrolled ? max(current, resting) : current
  }

  /// Whether a field frame moved enough to send (≥ 0.5pt on any edge).
  static func frameChanged(_ old: NativeRect?, _ new: NativeRect) -> Bool {
    guard let old else { return true }
    return abs(old.x - new.x) >= 0.5 || abs(old.y - new.y) >= 0.5
      || abs(old.width - new.width) >= 0.5 || abs(old.height - new.height) >= 0.5
  }
}
