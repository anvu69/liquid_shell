import CoreGraphics
import Foundation

/// The pure rules of native dialogs (spec P3a §5). There is no UIKit here,
/// so XCTest covers them without a window.
enum DialogMath {
  /// Why a dialog cannot be presented natively, or nil when it can. The
  /// facts are checked in this order (spec §5.2).
  static func unavailableReason(
    disabledByEnvironment: Bool, requireGlass: Bool, osAtLeast26: Bool, hasWindow: Bool
  ) -> NativeDialogUnavailableReason? {
    if disabledByEnvironment { return .disabledByEnvironment }
    if requireGlass && !osAtLeast26 { return .osTooOld }
    if !hasWindow { return .noWindow }
    return nil
  }

  /// The popover source rect for [anchor] in a view of [bounds]: the anchor
  /// clipped to the view, at least 1×1. Nil (the view's centre, no arrow)
  /// when there is no anchor, or it is not finite, has a negative size or
  /// lies outside the view.
  static func sourceRect(anchor: CGRect?, in bounds: CGRect) -> CGRect? {
    guard let anchor,
      anchor.origin.x.isFinite, anchor.origin.y.isFinite,
      anchor.size.width.isFinite, anchor.size.height.isFinite,
      anchor.size.width >= 0, anchor.size.height >= 0
    else { return nil }
    let clipped = anchor.intersection(bounds)
    if clipped.isNull { return nil }
    return CGRect(
      x: clipped.minX, y: clipped.minY,
      width: max(clipped.width, 1), height: max(clipped.height, 1))
  }

  /// [index] when it names one of [count] actions, else nil.
  static func preferredIndex(_ index: Int64?, count: Int) -> Int? {
    guard let index, index >= 0, index < Int64(count) else { return nil }
    return Int(index)
  }
}

/// Ends one Dart future exactly once (spec §5.4). Every later answer is
/// dropped.
final class DialogCompletion {
  private var body: ((NativeDialogResult) -> Void)?

  init(_ body: @escaping (NativeDialogResult) -> Void) {
    self.body = body
  }

  var isFinished: Bool { body == nil }

  func finish(_ result: NativeDialogResult) {
    guard let body else { return }
    self.body = nil
    body(result)
  }
}

extension NativeDialogResult {
  static func chose(_ index: Int) -> NativeDialogResult {
    NativeDialogResult(outcome: .chose, actionIndex: Int64(index))
  }

  static func dismissed() -> NativeDialogResult {
    NativeDialogResult(outcome: .dismissed)
  }

  static func unavailable(_ reason: NativeDialogUnavailableReason) -> NativeDialogResult {
    NativeDialogResult(outcome: .unavailable, reason: reason)
  }
}
