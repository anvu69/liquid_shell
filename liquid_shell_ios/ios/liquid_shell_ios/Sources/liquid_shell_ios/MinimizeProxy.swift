import UIKit

/// The invisible scroll view UIKit's tab bar minimize follows (spec
/// VK-600 §8.1). Locked: only `setOffset` moves it, so the bar follows the
/// Flutter content, never a drag that moves nothing. Its own pan, attached
/// to the Flutter view, makes it "user-tracked" (spike C8); its own
/// deceleration is left running, which the expand at the top needs (C11).
@available(iOS 26.0, *)
final class MinimizeProxy: UIScrollView {
  /// Dart's last offset: points below the top, zero or negative at it.
  private(set) var offset: Double = 0
  /// The Flutter view: a pan that starts over one of its subviews (a
  /// platform view) does not begin.
  weak var contentView: UIView?

  override init(frame: CGRect) {
    super.init(frame: frame)
    backgroundColor = .clear
    isUserInteractionEnabled = false
    showsVerticalScrollIndicator = false
    showsHorizontalScrollIndicator = false
    scrollsToTop = false
    contentInsetAdjustmentBehavior = .always
    contentSize = CGSize(width: 1, height: 100_000)
    isAccessibilityElement = false
    accessibilityElementsHidden = true
    panGestureRecognizer.allowedScrollTypesMask = []
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  /// UIKit's writes are dropped; `apply` writes through `super`.
  override var contentOffset: CGPoint {
    get { super.contentOffset }
    set {}
  }

  func setOffset(_ value: Double) {
    guard value.isFinite else { return }
    offset = value
    apply()
  }

  private func apply() {
    super.contentOffset = CGPoint(x: 0, y: -adjustedContentInset.top + CGFloat(offset))
  }

  override func adjustedContentInsetDidChange() {
    super.adjustedContentInsetDidChange()
    apply()
  }

  /// Whether the pan may begin over [hit], the content's hit view.
  static func begins(over hit: UIView?, content: UIView?) -> Bool {
    guard let content, let hit else { return true }
    return hit === content
  }

  override func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
    if recognizer === panGestureRecognizer, let content = contentView {
      let hit = content.hitTest(recognizer.location(in: content), with: nil)
      if !Self.begins(over: hit, content: content) { return false }
    }
    return super.gestureRecognizerShouldBegin(recognizer)
  }
}
