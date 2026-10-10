import CoreGraphics
import Foundation

/// Insets without UIKit, so the arithmetic below is testable anywhere.
struct ShellInsets: Equatable {
  var top: Double
  var left: Double
  var bottom: Double
  var right: Double

  static let zero = ShellInsets(top: 0, left: 0, bottom: 0, right: 0)
}

/// The native shell's pure arithmetic (spec §8.1). No UIKit, no Flutter.
enum ShellMath {
  /// Cluster height used when the vertical corner adaptation reads 0 while
  /// the horizontal one does not (spec §8.1). At least the measured cluster:
  /// a windowed iPad Air (M3, iPadOS 27) reports 66 × 43pt at every size
  /// (docs/qa/p2/spike.md). Flutter chrome only: under visible native
  /// chrome the value is zero without a read
  /// (`NativeTabsController.windowControls`), because there the bar row,
  /// not a missing adaptation, makes the vertical delta 0.
  static let fallbackClusterTop = 44.0

  /// Below this the horizontal delta is the display's rounded corner, not
  /// window controls: a full-screen iPad Air reports 5.5–9.5pt with no
  /// cluster at all (iOS 26.5 simulator and a real M3 on iPadOS 27).
  static let minimumClusterLeading = 24.0

  /// The window-controls cluster from corner-adapted insets: how far past
  /// the plain safe area the `.horizontal` region starts (leading) and the
  /// `.vertical` region starts (top). Negative or non-finite → 0.
  static func windowControls(
    safeLeading: Double,
    safeTop: Double,
    horizontalLeading: Double,
    verticalTop: Double
  ) -> (leading: Double, top: Double) {
    let leading = clean(horizontalLeading - safeLeading)
    var top = clean(verticalTop - safeTop)
    if top == 0 {
      // No vertical adaptation: only a cluster-sized leading delta counts.
      guard leading >= minimumClusterLeading else { return (0, 0) }
      top = fallbackClusterTop
    }
    return (leading, top)
  }

  /// The `additionalSafeAreaInsets` that make a view whose safe area is
  /// [current] (of which [added] is ours) end up with [want] on every side.
  static func additionalInsets(
    want: ShellInsets,
    current: ShellInsets,
    added: ShellInsets
  ) -> ShellInsets {
    ShellInsets(
      top: max(0, want.top - (current.top - added.top)),
      left: max(0, want.left - (current.left - added.left)),
      bottom: max(0, want.bottom - (current.bottom - added.bottom)),
      right: max(0, want.right - (current.right - added.right)))
  }

  /// A tiled sidebar does not resize the tab host; UIKit only grows the
  /// host's safe area on the sidebar's side. Overlay leaves it alone.
  static func isTiled(host: ShellInsets, root: ShellInsets) -> Bool {
    host.left > root.left + 0.5 || host.right > root.right + 0.5
  }

  /// Whether two window-control values differ by at least half a point.
  static func differs(
    _ a: (leading: Double, top: Double)?,
    _ b: (leading: Double, top: Double)
  ) -> Bool {
    guard let a else { return true }
    return abs(a.leading - b.leading) >= 0.5 || abs(a.top - b.top) >= 0.5
  }

  private static func clean(_ value: Double) -> Double {
    value.isFinite && value > 0 ? value : 0
  }
}
