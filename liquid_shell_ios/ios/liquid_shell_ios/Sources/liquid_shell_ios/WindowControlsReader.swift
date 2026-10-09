import UIKit

/// Reads the iPadOS 26 window-controls cluster from a view (spec §8.1).
enum WindowControlsReader {
  static func read(_ view: UIView?) -> NativeWindowControls {
    guard #available(iOS 26.0, *), let view else {
      return NativeWindowControls(leading: 0, top: 0)
    }
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
