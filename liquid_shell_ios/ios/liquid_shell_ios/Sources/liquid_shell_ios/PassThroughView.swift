import UIKit

/// The container's view. Touches on the native chrome (tab bar, sidebar,
/// the overlay sidebar's dimming view, the footer) stay with UIKit; touches
/// on the transparent "background" of the tab bar controller go to the
/// Flutter view underneath (spec §5.3).
///
/// Tracked debt: "background" means the selected tab's host view and its
/// ancestors up to and including the tab bar controller's view. That is
/// public API, but a new iOS that reshapes the view tree breaks it, so the
/// native integration test runs on every Xcode/iOS bump.
@available(iOS 26.0, *)
final class PassThroughView: UIView {
  weak var shell: NativeTabsController?
  weak var flutterView: UIView?

  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard let shell, let flutterView, let tabsView = shell.viewIfLoaded else {
      return super.hitTest(point, with: event)
    }
    let hit = tabsView.hitTest(convert(point, to: tabsView), with: event)
    guard Self.isBackground(hit, selected: shell.selectedViewController?.viewIfLoaded, tabsView: tabsView)
    else { return hit }
    // Platform views inside Flutter are subviews of the Flutter view, so its
    // own hitTest finds them.
    return flutterView.hitTest(convert(point, to: flutterView), with: event)
  }

  /// nil (chrome hidden, not interactive, or fully transparent), the tab bar
  /// controller's own view, or the selected host and its ancestors.
  static func isBackground(_ hit: UIView?, selected: UIView?, tabsView: UIView) -> Bool {
    guard let hit else { return true }
    if hit === tabsView { return true }
    var node = selected
    while let current = node {
      if current === hit { return true }
      if current === tabsView { break }
      node = current.superview
    }
    return false
  }
}
