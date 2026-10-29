import UIKit

/// The native bar's half of the page title table (spec P3b-2 §4.2), for
/// a plain tab: pure, tested row by row without a view tree. The Flutter
/// bar decides from the same table. The search tab keeps its own root
/// rules (`SearchMath.style`): its bar holds the field and never hides.
@available(iOS 26.0, *)
enum PageTitleMath {
  /// A pushed page's title: always inline, small and centred.
  static let pushedMode: UINavigationItem.LargeTitleDisplayMode = .never

  /// A plain tab's root page. `true`: the large title on a row of its own,
  /// which collapses as the page scrolls (the page proxy drives it).
  /// `nil` at compact width: the large title on the bar row (`.inline`,
  /// as Apple Music). Otherwise no title row.
  static func rootMode(
    largeTitle: Bool?, compact: Bool
  ) -> UINavigationItem.LargeTitleDisplayMode {
    switch largeTitle {
    case true?: return .always
    case nil where compact: return .inline
    default: return .never
    }
  }

  /// Whether a plain tab hides its navigation bar: without pages (the
  /// tab's pages do not use `LiquidPage`), and for a single root page with
  /// no title row. A pushed page always shows it, with the back circle.
  static func barHidden(pages: [NativePage], compact: Bool) -> Bool {
    guard pages.count <= 1 else { return false }
    guard let root = pages.first else { return true }
    return rootMode(largeTitle: root.largeTitle, compact: compact) == .never
  }
}
