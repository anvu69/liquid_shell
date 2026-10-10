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
  let largeTitle: Bool
  /// `UITabBarController.prominentTabIdentifier` = the search tab (iOS 27).
  let prominent: Bool
}

/// Pure decisions of the search tab, unit-tested without UIKit.
enum SearchMath {
  /// iPhone: UIKit's tab-hosted field, a large title, and on iOS 27 the
  /// prominent search tab (without it 27 makes Search an inline tab).
  /// iPad (any width): the stacked field under an inline title, always
  /// visible; never prominent (Q1). The app's `largeTitle` wins when set.
  static func style(isPad: Bool, osMajor: Int, rootLargeTitle: Bool?) -> SearchTabStyle {
    if isPad {
      return SearchTabStyle(
        placement: .stacked, hidesWhenScrolling: false, largeTitle: rootLargeTitle ?? false,
        prominent: false)
    }
    return SearchTabStyle(
      placement: .automatic, hidesWhenScrolling: nil, largeTitle: rootLargeTitle ?? true,
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
