import UIKit

/// Reads the iPadOS 26 window-controls cluster from a view (spec §8.1).
enum WindowControlsReader {
  /// None on an iPhone: window controls are an iPadOS windowing feature,
  /// and a landscape iPhone's corner-adapted safe area reads a phantom 18pt
  /// top (iPhone 17 Pro, iOS 26.5).
  static func read(
    _ view: UIView?, measure: (UIView) -> NativeWindowControls = measure
  ) -> NativeWindowControls {
    guard let view, view.traitCollection.userInterfaceIdiom != .phone else {
      return NativeWindowControls(leading: 0, top: 0)
    }
    return measure(view)
  }

  /// The cluster from the corner-adapted safe area.
  static func measure(_ view: UIView) -> NativeWindowControls {
    guard #available(iOS 26.0, *) else { return NativeWindowControls(leading: 0, top: 0) }
    let safe = view.safeAreaInsets
    let rtl = view.effectiveUserInterfaceLayoutDirection == .rightToLeft
    let horizontal = view.directionalEdgeInsets(for: .safeArea(cornerAdaptation: .horizontal))
    let vertical = view.directionalEdgeInsets(for: .safeArea(cornerAdaptation: .vertical))
    let cluster = ShellMath.windowControls(
      safeLeading: Double(rtl ? safe.right : safe.left),
      safeTop: Double(safe.top),
      horizontalLeading: Double(horizontal.leading),
      verticalTop: Double(vertical.top))
    return NativeWindowControls(leading: cluster.leading, top: cluster.top)
  }
}
