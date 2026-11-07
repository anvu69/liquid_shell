import UIKit

/// The top bar region beside an iPhone Duo's vertical bar (spec VK-930 §3.2).
enum VerticalBarReader {
  /// The region's top while the trait reports a vertical bar; nil without
  /// one, before iOS 27.1, or on an SDK without the API. The guard is the
  /// iOS 27.1 SDK's UIKit (9127.0.85): the 27.0 SDK is Swift 6.4 too, so
  /// `compiler(>=6.4)` cannot tell them apart.
  static func topBarRegionTop(_ view: UIView) -> Double? {
    #if canImport(UIKit, _version: 9127.0.85)
      if #available(iOS 27.1, *) {
        guard view.traitCollection.verticalBarEdge != .unspecified else { return nil }
        // `bar(onEdge:extent:)` takes a UIRectEdge or an
        // NSDirectionalRectEdge; a bare `.top` is ambiguous.
        return Double(view.edgeInsets(for: .bar(onEdge: UIRectEdge.top, extent: 44)).top)
      }
    #endif
    return nil
  }
}
