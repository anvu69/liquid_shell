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

  /// The vertical bar's screen side; `.none` without one, before iOS 27.1,
  /// or on an SDK without the API.
  static func side(_ view: UIView) -> NativeVerticalBarSide {
    #if canImport(UIKit, _version: 9127.0.85)
      if #available(iOS 27.1, *) {
        // ShellMath takes 1 leading / 2 trailing; map the cases, not raw values.
        let edge: Int
        switch view.traitCollection.verticalBarEdge {
        case .leading: edge = 1
        case .trailing: edge = 2
        default: edge = 0
        }
        return ShellMath.verticalBarSide(
          edge: edge,
          rightToLeft: view.effectiveUserInterfaceLayoutDirection == .rightToLeft)
      }
    #endif
    return .none
  }

  /// Calls [handler] with [owner] when the traits that place the vertical
  /// bar change (a fold or unfold). The edge may be the same afterwards
  /// (UIKit's header says so): compare. Nothing before iOS 27.1 or on an
  /// SDK without the API.
  @MainActor
  static func observeChanges<Owner: UIViewController>(
    _ owner: Owner, _ handler: @escaping (Owner) -> Void
  ) {
    #if canImport(UIKit, _version: 9127.0.85)
      if #available(iOS 27.1, *) {
        owner.registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge) {
          (owner: Owner, _: UITraitCollection) in handler(owner)
        }
      }
    #endif
  }
}
