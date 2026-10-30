import Flutter
import UIKit
import XCTest

@testable import liquid_shell_ios

/// A key, visible window in the test host's scene, showing [root].
func makeSceneWindow(root: UIViewController) throws -> UIWindow {
  let scene = try XCTUnwrap(
    UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
  let window = UIWindow(windowScene: scene)
  window.frame = scene.coordinateSpace.bounds
  window.rootViewController = root
  window.makeKeyAndVisible()
  return window
}

/// Unit tests of liquid_shell_ios's native shell: the pure arithmetic, the
/// install rule, the pass-through hit test (spec P2 §9.3), and the UIKit
/// shell in a window of the test host. They live in
/// the example's RunnerTests target because a plugin has no test target of
/// its own under CocoaPods. Run with `make ios-unit`.
final class ShellMathTests: XCTestCase {
  func testFloatingWindowClusterIsTheCornerDelta() {
    let c = ShellMath.windowControls(
      safeLeading: 0, safeTop: 0, horizontalLeading: 66, verticalTop: 30)
    XCTAssertEqual(c.leading, 66)
    XCTAssertEqual(c.top, 30)
  }

  func testChromeAlreadyClearOfTheClusterGivesZero() {
    let c = ShellMath.windowControls(
      safeLeading: 0, safeTop: 96, horizontalLeading: 0, verticalTop: 96)
    XCTAssertEqual(c.leading, 0)
    XCTAssertEqual(c.top, 0)
  }

  func testNegativeAndNonFiniteDeltasAreZero() {
    let negative = ShellMath.windowControls(
      safeLeading: 20, safeTop: 30, horizontalLeading: 10, verticalTop: 10)
    XCTAssertEqual(negative.leading, 0)
    XCTAssertEqual(negative.top, 0)
    let nan = ShellMath.windowControls(
      safeLeading: 0, safeTop: 0, horizontalLeading: .nan, verticalTop: .infinity)
    XCTAssertEqual(nan.leading, 0)
    XCTAssertEqual(nan.top, 0)
  }

  func testMissingVerticalAdaptationFallsBackToTheClusterHeight() {
    let c = ShellMath.windowControls(
      safeLeading: 0, safeTop: 24, horizontalLeading: 66, verticalTop: 24)
    XCTAssertEqual(c.leading, 66)
    XCTAssertEqual(c.top, ShellMath.fallbackClusterTop)
  }

  func testARoundedCornerAloneIsNotACluster() {
    // Full-screen iPad Air, iOS 26.5: 9.5pt leading, no vertical delta.
    let c = ShellMath.windowControls(
      safeLeading: 0, safeTop: 24, horizontalLeading: 9.5, verticalTop: 24)
    XCTAssertEqual(c.leading, 0)
    XCTAssertEqual(c.top, 0)
  }

  func testMeasuredClusterOnARealIPadAir() {
    // iPad Air 11-inch (M3), iPadOS 27 (docs/qa/p2/spike.md). Windowed at
    // every size: safe.top 32, v.top 75, h.leading 66.
    let windowed = ShellMath.windowControls(
      safeLeading: 0, safeTop: 32, horizontalLeading: 66, verticalTop: 75)
    XCTAssertEqual(windowed.leading, 66)
    XCTAssertEqual(windowed.top, 43)
    // A short window: safe.top 10, v.top 53. Same cluster.
    let short = ShellMath.windowControls(
      safeLeading: 0, safeTop: 10, horizontalLeading: 66, verticalTop: 53)
    XCTAssertEqual(short.leading, 66)
    XCTAssertEqual(short.top, 43)
    // Full screen after a windowed spell: 5.5pt of rounded corner, no
    // vertical delta.
    let fullScreen = ShellMath.windowControls(
      safeLeading: 0, safeTop: 32, horizontalLeading: 5.5, verticalTop: 32)
    XCTAssertEqual(fullScreen.leading, 0)
    XCTAssertEqual(fullScreen.top, 0)
  }

  func testALeadingOfExactly24IsACluster() {
    let c = ShellMath.windowControls(
      safeLeading: 0, safeTop: 0, horizontalLeading: 24, verticalTop: 0)
    XCTAssertEqual(c.leading, 24)
    XCTAssertEqual(c.top, ShellMath.fallbackClusterTop)
    let below = ShellMath.windowControls(
      safeLeading: 0, safeTop: 0, horizontalLeading: 23.9, verticalTop: 0)
    XCTAssertEqual(below.leading, 0)
    XCTAssertEqual(below.top, 0)
  }

  func testAdditionalInsetsFillOnlyWhatIsMissing() {
    let need = ShellMath.additionalInsets(
      want: ShellInsets(top: 96, left: 300, bottom: 20, right: 0),
      current: ShellInsets(top: 24, left: 0, bottom: 20, right: 0),
      added: .zero)
    XCTAssertEqual(need, ShellInsets(top: 72, left: 300, bottom: 0, right: 0))
    // Already applied: the same value again, not double.
    let again = ShellMath.additionalInsets(
      want: ShellInsets(top: 96, left: 300, bottom: 20, right: 0),
      current: ShellInsets(top: 96, left: 300, bottom: 20, right: 0),
      added: need)
    XCTAssertEqual(again, need)
  }

  func testTiledMeansTheHostSafeAreaGrewOnOneSide() {
    let root = ShellInsets(top: 24, left: 0, bottom: 20, right: 0)
    XCTAssertTrue(ShellMath.isTiled(host: ShellInsets(top: 24, left: 300, bottom: 20, right: 0), root: root))
    XCTAssertTrue(ShellMath.isTiled(host: ShellInsets(top: 24, left: 0, bottom: 20, right: 300), root: root))
    XCTAssertFalse(ShellMath.isTiled(host: ShellInsets(top: 96, left: 0.4, bottom: 20, right: 0), root: root))
  }

  func testWindowControlsChangeNeedsHalfAPoint() {
    XCTAssertTrue(ShellMath.differs(nil, (0, 0)))
    XCTAssertFalse(ShellMath.differs((66, 30), (66.4, 30.2)))
    XCTAssertTrue(ShellMath.differs((66, 30), (66.5, 30)))
    XCTAssertTrue(ShellMath.differs((66, 30), (66, 29.5)))
  }
}

@available(iOS 17.0, *)
final class SearchMathTests: XCTestCase {
  func testAnIPhoneKeepsUIKitsTabHostedFieldAndALargeTitle() {
    XCTAssertEqual(
      SearchMath.style(isPad: false, osMajor: 26, rootLargeTitle: nil),
      SearchTabStyle(
        placement: .automatic, hidesWhenScrolling: nil, titleMode: .inline, titleItem: false,
        prominent: false))
  }

  func testAnIPhoneOnIOS27MakesTheSearchTabProminent() {
    XCTAssertTrue(SearchMath.style(isPad: false, osMajor: 27, rootLargeTitle: nil).prominent)
  }

  /// UIKit draws no title for a `UISearchTab`'s root on an iPad, whatever
  /// the small-title mode (Task 12): the small title "Search" next to the
  /// window controls (Apple Music) is a leading title item.
  func testAnIPadIsStackedUnderATitleItemAndNeverProminent() {
    for os in [26, 27] {
      XCTAssertEqual(
        SearchMath.style(isPad: true, osMajor: os, rootLargeTitle: nil),
        SearchTabStyle(
          placement: .stacked, hidesWhenScrolling: false, titleMode: .never, titleItem: true,
          prominent: false))
    }
  }

  /// A large title on an iPad is `.always`: UIKit drops a `UISearchTab`
  /// root's `.inline` title there too.
  func testTheAppsLargeTitleChoiceWins() {
    let phone = SearchMath.style(isPad: false, osMajor: 26, rootLargeTitle: false)
    XCTAssertEqual(phone.titleMode, .never)
    XCTAssertFalse(phone.titleItem)
    let pad = SearchMath.style(isPad: true, osMajor: 27, rootLargeTitle: true)
    XCTAssertEqual(pad.titleMode, .always)
    XCTAssertFalse(pad.titleItem)
  }

  /// Spec P3b-2 §4.2, decision 12: `largeTitle: true` on the iPhone's
  /// search root is the collapsing row, as on every tab (it was the bar
  /// row, `.inline`, which is now `null`'s).
  func testAnIPhoneSearchRootWithALargeTitleCollapses() {
    for os in [26, 27] {
      XCTAssertEqual(
        SearchMath.style(isPad: false, osMajor: os, rootLargeTitle: true).titleMode, .always)
      XCTAssertEqual(
        SearchMath.style(isPad: false, osMajor: os, rootLargeTitle: nil).titleMode, .inline)
    }
  }

  func testTheTopIsHeldOnlyWhileTheProxyIsScrolled() {
    XCTAssertEqual(SearchMath.heldTop(current: 116, resting: 168.7, scrolled: true), 168.7)
    XCTAssertEqual(SearchMath.heldTop(current: 116, resting: 168.7, scrolled: false), 116)
    XCTAssertEqual(SearchMath.heldTop(current: 172, resting: 168.7, scrolled: true), 172)
  }

  func testAFieldFrameChangeNeedsHalfAPoint() {
    let a = NativeRect(x: 8, y: 490, width: 330, height: 48)
    XCTAssertTrue(SearchMath.frameChanged(nil, a))
    XCTAssertFalse(SearchMath.frameChanged(a, NativeRect(x: 8.2, y: 490.4, width: 330, height: 48)))
    XCTAssertTrue(SearchMath.frameChanged(a, NativeRect(x: 8, y: 489, width: 330, height: 48)))
  }
}

/// Spec P3b-2 §4.2: the native half of the page title table, row by row
/// (a plain tab; the search tab keeps `SearchMath.style`). The rows, and
/// the cases each covers, are those of the Flutter bar's suite
/// (`liquid_shell/test/unit/page_bar_test.dart`, group `pageTitleModeFor:
/// the title table`): 6 rows, 24 cases (page × largeTitle × width ×
/// actions). The native bar has no page actions yet: its 12 cases without
/// actions are checked here; branch B4 adds actions to `PageTitleMath` and
/// checks the other 12 (spec §8.4).
@available(iOS 26.0, *)
final class PageTitleMathTests: XCTestCase {
  /// (page, largeTitle, size class, actions, mode), each cell as the
  /// spec's table writes it; the same records as the Dart suite.
  private typealias Row = (String, String, String, String, String)

  private static let table: [Row] = [
    ("pushed", "any", "any", "any", "inline"),
    ("root", "true", "any", "any", "largeCollapsing"),
    ("root", "null", "compact", "any", "largeInRow"),
    ("root", "null", "regular", "none", "hidden"),
    ("root", "false", "any", "none", "hidden"),
    ("root", "null (regular) or false", "as left", "≥ 1", "inline"),
  ]

  private struct Case: Hashable {
    let root: Bool
    let largeTitle: Bool?
    let compact: Bool
    let hasActions: Bool
  }

  private static func largeTitles(_ cell: String) -> [Bool?] {
    switch cell {
    case "any": return [true, nil, false]
    case "true": return [true]
    case "null": return [nil]
    case "false": return [false]
    default: preconditionFailure("largeTitle \(cell)")
    }
  }

  /// Compact (true) and regular (false) width.
  private static func widths(_ cell: String) -> [Bool] {
    switch cell {
    case "any": return [true, false]
    case "compact": return [true]
    case "regular": return [false]
    default: preconditionFailure("size class \(cell)")
    }
  }

  /// Every concrete case a row covers, as the Dart suite's `_casesOf`.
  private static func cases(of row: Row) -> [Case] {
    let (page, largeTitle, size, actions, _) = row
    let root: Bool
    switch page {
    case "pushed": root = false
    case "root": root = true
    default: preconditionFailure("page \(page)")
    }
    let titlesAndWidths: [(Bool?, Bool)] =
      (largeTitle, size) == ("null (regular) or false", "as left")
      ? [(nil, false), (false, true), (false, false)]
      : largeTitles(largeTitle).flatMap { title in widths(size).map { (title, $0) } }
    let withActions: [Bool]
    switch actions {
    case "any": withActions = [false, true]
    case "none": withActions = [false]
    case "≥ 1": withActions = [true]
    default: preconditionFailure("actions \(actions)")
    }
    return titlesAndWidths.flatMap { title, compact in
      withActions.map {
        Case(root: root, largeTitle: title, compact: compact, hasActions: $0)
      }
    }
  }

  func testTheRowsCoverEveryCaseExactlyOnce() {
    let all = Self.table.flatMap { Self.cases(of: $0) }
    // page × largeTitle × size class × actions
    XCTAssertEqual(all.count, 2 * 3 * 2 * 2)
    XCTAssertEqual(Set(all).count, all.count)
  }

  func testPageTitleMathFollowsTheTitleTable() {
    func page(_ largeTitle: Bool?) -> NativePage {
      NativePage(title: "Page", largeTitle: largeTitle)
    }
    var checked = 0
    for (i, row) in Self.table.enumerated() {
      for c in Self.cases(of: row) where !c.hasActions {
        let label = "row \(i + 1) (\(row.4)): \(c)"
        // A pushed page sits on a root without a large title.
        let pages = c.root ? [page(c.largeTitle)] : [page(nil), page(c.largeTitle)]
        let mode =
          c.root
          ? PageTitleMath.rootMode(largeTitle: c.largeTitle, compact: c.compact)
          : PageTitleMath.pushedMode
        let hidden = PageTitleMath.barHidden(pages: pages, compact: c.compact)
        switch row.4 {
        case "inline":
          XCTAssertEqual(mode, .never, label)
          XCTAssertFalse(hidden, label)
        case "largeCollapsing":
          XCTAssertEqual(mode, .always, label)
          XCTAssertFalse(hidden, label)
        case "largeInRow":
          XCTAssertEqual(mode, .inline, label)
          XCTAssertFalse(hidden, label)
        case "hidden":
          XCTAssertEqual(mode, .never, label)
          XCTAssertTrue(hidden, label)
        default:
          XCTFail("mode \(row.4)")
        }
        checked += 1
      }
    }
    // Rows 1–5 without actions: 6 + 2 + 1 + 1 + 2.
    XCTAssertEqual(checked, 12)
  }

  /// No pages: the tab does not use LiquidPage, and looks as before.
  func testATabWithoutPagesHidesItsBar() {
    for compact in [true, false] {
      XCTAssertTrue(PageTitleMath.barHidden(pages: [], compact: compact))
    }
  }
}

final class ArgbColorTests: XCTestCase {
  func testArgbIsDartsToArgb32() {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    XCTAssertTrue(
      UIColor(argb: 0x80FF_4020).getRed(&red, green: &green, blue: &blue, alpha: &alpha))
    XCTAssertEqual(alpha, 128 / 255, accuracy: 1e-6)
    XCTAssertEqual(red, 1, accuracy: 1e-6)
    XCTAssertEqual(green, 64 / 255, accuracy: 1e-6)
    XCTAssertEqual(blue, 32 / 255, accuracy: 1e-6)
  }
}

final class InstallPolicyTests: XCTestCase {
  private let ok = InstallFacts(
    osAtLeast26: true, isiOSAppOnMac: false, enabledInInfoPlist: true,
    disabledByEnvironment: false, registeredLate: false, rootIsFlutter: true)

  func testInstallsWhenEveryFactHolds() {
    XCTAssertNil(InstallPolicy.decide(ok))
  }

  func testEachFailingFactNamesItsReasonInOrder() {
    var facts = ok
    facts.rootIsFlutter = false
    XCTAssertEqual(InstallPolicy.decide(facts), .rootNotFlutter)
    facts.registeredLate = true
    XCTAssertEqual(InstallPolicy.decide(facts), .registeredLate)
    facts.disabledByEnvironment = true
    XCTAssertEqual(InstallPolicy.decide(facts), .disabledByEnvironment)
    facts.enabledInInfoPlist = false
    XCTAssertEqual(InstallPolicy.decide(facts), .notEnabled)
    facts.isiOSAppOnMac = true
    XCTAssertEqual(InstallPolicy.decide(facts), .iPadAppOnMac)
    facts.osAtLeast26 = false
    XCTAssertEqual(InstallPolicy.decide(facts), .osTooOld)
  }

  func testKeysAreThePublishedNames() {
    XCTAssertEqual(InstallPolicy.infoPlistKey, "LiquidShellNativeChrome")
    XCTAssertEqual(InstallPolicy.disableEnvironmentKey, "LIQUID_SHELL_NATIVE_OFF")
  }
}

final class WindowControlsReaderTests: XCTestCase {
  /// Window controls are an iPadOS windowing feature. A landscape iPhone
  /// (iOS 26.5, iPhone 17 Pro) reads a phantom 18pt top from its
  /// corner-adapted safe area: an iPhone has none, whatever the read says.
  func testAnIPhoneHasNoWindowControls() {
    let measured = NativeWindowControls(leading: 0, top: 18)
    let read = WindowControlsReader.read(UIView(), measure: { _ in measured })
    if UIDevice.current.userInterfaceIdiom == .phone {
      XCTAssertEqual(read, NativeWindowControls(leading: 0, top: 0))
    } else {
      XCTAssertEqual(read, measured, "an iPad reads its cluster")
    }
  }
}

@available(iOS 26.0, *)
final class PassThroughTests: XCTestCase {
  func testBackgroundIsNilTheTabsViewAndTheSelectedHostChain() {
    let tabsView = UIView()
    let transition = UIView()
    let host = UIView()
    let chrome = UIView()
    tabsView.addSubview(transition)
    transition.addSubview(host)
    tabsView.addSubview(chrome)

    XCTAssertTrue(PassThroughView.isBackground(nil, chainFrom: host, tabsView: tabsView))
    XCTAssertTrue(PassThroughView.isBackground(tabsView, chainFrom: host, tabsView: tabsView))
    XCTAssertTrue(PassThroughView.isBackground(host, chainFrom: host, tabsView: tabsView))
    XCTAssertTrue(PassThroughView.isBackground(transition, chainFrom: host, tabsView: tabsView))
    XCTAssertFalse(PassThroughView.isBackground(chrome, chainFrom: host, tabsView: tabsView))
    // No selected host yet: only nil and the tabs view are background.
    XCTAssertFalse(PassThroughView.isBackground(transition, chainFrom: nil, tabsView: tabsView))
  }

  func testTheChainStartsAtANavigationControllersTopPage() {
    let tabsView = UIView()
    let navView = UIView()
    let transition = UIView()
    let wrapper = UIView()
    let top = UIView()
    let bar = UIView()
    tabsView.addSubview(navView)
    navView.addSubview(transition)
    transition.addSubview(wrapper)
    wrapper.addSubview(top)
    navView.addSubview(bar)
    for view in [top, wrapper, transition, navView, tabsView] {
      XCTAssertTrue(PassThroughView.isBackground(view, chainFrom: top, tabsView: tabsView))
    }
    XCTAssertFalse(
      PassThroughView.isBackground(bar, chainFrom: top, tabsView: tabsView),
      "the navigation bar stays with UIKit")
  }
}

@available(iOS 26.0, *)
final class MinimizeProxyTests: XCTestCase {
  private var window: UIWindow?

  override func tearDown() {
    window?.isHidden = true
    window?.rootViewController = nil
    window = nil
    super.tearDown()
  }

  private func proxy() -> MinimizeProxy {
    let host = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
    let proxy = MinimizeProxy(frame: host.bounds)
    host.addSubview(proxy)
    return proxy
  }

  /// A proxy in a shown window: UIKit runs a scroll animation only on screen.
  private func proxyOnScreen() throws -> MinimizeProxy {
    let scene = try XCTUnwrap(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    window.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
    window.rootViewController = UIViewController()
    window.isHidden = false
    self.window = window
    let root = try XCTUnwrap(window.rootViewController?.view)
    let proxy = MinimizeProxy(frame: root.bounds)
    root.addSubview(proxy)
    return proxy
  }

  /// Counts the scroll animations UIKit finishes.
  private final class AnimationRecorder: NSObject, UIScrollViewDelegate {
    var ended = 0
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) { ended += 1 }
  }

  /// Runs the run loop until [done] holds or [timeout] passes: a wait, so
  /// a slow host still lets an animation that does start finish.
  private func wait(timeout: TimeInterval = 3, until done: () -> Bool) {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline, !done() {
      RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }
  }

  /// A plain scroll view beside [proxy], of the same size and content: the
  /// lock tests' clock. Started right after the proxy's, its animation of a
  /// longer move ends no sooner than the proxy's would, so a passing test
  /// waits for UIKit, not for a timeout.
  private func referenceClock(
    beside proxy: MinimizeProxy
  ) throws -> (UIScrollView, AnimationRecorder) {
    let reference = UIScrollView(frame: proxy.frame)
    reference.contentSize = proxy.contentSize
    try XCTUnwrap(proxy.superview).addSubview(reference)
    let recorder = AnimationRecorder()
    reference.delegate = recorder
    return (reference, recorder)
  }

  /// Waits until the [clock]'s animation has ended, then one more turn.
  private func waitForTheClock(_ clock: AnimationRecorder) {
    wait { clock.ended > 0 }
    XCTAssertEqual(clock.ended, 1, "precondition: UIKit animated the reference")
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
  }

  /// Task 3 review: an animated move starts no UIKit scroll animation (one
  /// would run with every frame dropped by the setter lock), so only Dart
  /// moves the proxy.
  func testAnAnimatedOffsetChangeStartsNoScrollAnimation() throws {
    let proxy = try proxyOnScreen()
    proxy.setOffset(120)
    let y = proxy.contentOffset.y
    let recorder = AnimationRecorder()
    proxy.delegate = recorder
    let (reference, clock) = try referenceClock(beside: proxy)
    proxy.setContentOffset(CGPoint(x: 0, y: 555), animated: true)
    reference.setContentOffset(CGPoint(x: 0, y: 2_000), animated: true)
    waitForTheClock(clock)
    XCTAssertEqual(proxy.contentOffset.y, y)
    XCTAssertEqual(recorder.ended, 0, "no scroll animation ran")
    XCTAssertEqual(proxy.offset, 120)
  }

  /// Likewise `scrollRectToVisible`, animated or not.
  func testScrollRectToVisibleDoesNotMoveIt() throws {
    let proxy = try proxyOnScreen()
    proxy.setOffset(120)
    let y = proxy.contentOffset.y
    let recorder = AnimationRecorder()
    proxy.delegate = recorder
    let (reference, clock) = try referenceClock(beside: proxy)
    proxy.scrollRectToVisible(CGRect(x: 0, y: 5_000, width: 1, height: 1), animated: true)
    reference.scrollRectToVisible(CGRect(x: 0, y: 9_000, width: 1, height: 1), animated: true)
    waitForTheClock(clock)
    proxy.scrollRectToVisible(CGRect(x: 0, y: 9_000, width: 1, height: 1), animated: false)
    XCTAssertEqual(proxy.contentOffset.y, y)
    XCTAssertEqual(recorder.ended, 0, "no scroll animation ran")
    XCTAssertEqual(proxy.offset, 120)
  }

  /// Q7, the wiring of `begins(over:content:)`: the proxy's own pan does
  /// not begin where the content's hit view is a platform view; with the
  /// content itself hit, UIKit decides as without a content view; another
  /// recognizer is never gated.
  func testThePanGateAsksTheContentsHitView() {
    let proxy = proxy()
    let pan = proxy.panGestureRecognizer
    let unGated = proxy.gestureRecognizerShouldBegin(pan)
    let content = UIView(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
    proxy.contentView = content
    XCTAssertEqual(proxy.gestureRecognizerShouldBegin(pan), unGated, "over the content itself")
    let platformView = UIView(frame: content.bounds)
    content.addSubview(platformView)
    XCTAssertFalse(proxy.gestureRecognizerShouldBegin(pan), "over a platform view")
    let tap = UITapGestureRecognizer()
    proxy.addGestureRecognizer(tap)
    XCTAssertTrue(proxy.gestureRecognizerShouldBegin(tap), "only the proxy's own pan is gated")
  }

  /// Spike C8: only Dart moves it; UIKit's own writes (its pan, its
  /// deceleration, an inset adjustment) are dropped.
  func testOnlySetOffsetMovesIt() {
    let proxy = proxy()
    proxy.setOffset(120)
    let y = proxy.contentOffset.y
    XCTAssertEqual(y, -proxy.adjustedContentInset.top + 120)
    proxy.contentOffset = CGPoint(x: 0, y: 999)
    proxy.setContentOffset(CGPoint(x: 0, y: 555), animated: false)
    XCTAssertEqual(proxy.contentOffset.y, y)
    XCTAssertEqual(proxy.offset, 120)
  }

  /// Task 6 review: nothing clamps the offset, so a long feed past the
  /// first content would leave the proxy in its bottom overscroll, where
  /// UIKit likely stops minimizing. `setOffset` grows the content ahead of
  /// it, never shrinks it, and the lock holds.
  func testALongFeedGrowsTheContentAheadOfTheOffset() {
    let proxy = proxy()
    proxy.setOffset(250_000)
    XCTAssertEqual(proxy.contentOffset.y, -proxy.adjustedContentInset.top + 250_000)
    let bottom = proxy.contentOffset.y + proxy.bounds.height
    XCTAssertGreaterThan(proxy.contentSize.height, 250_000 + proxy.bounds.height)
    XCTAssertGreaterThanOrEqual(
      proxy.contentSize.height + proxy.adjustedContentInset.bottom - bottom, 10_000,
      "a margin of content below the visible bottom, not the overscroll")
    let y = proxy.contentOffset.y
    proxy.contentOffset = CGPoint(x: 0, y: 999)
    proxy.setContentOffset(CGPoint(x: 0, y: 555), animated: false)
    XCTAssertEqual(proxy.contentOffset.y, y, "only setOffset moves it")
    let grown = proxy.contentSize.height
    proxy.setOffset(10)
    XCTAssertEqual(proxy.contentSize.height, grown, "it never shrinks")
    XCTAssertEqual(proxy.contentOffset.y, -proxy.adjustedContentInset.top + 10)
  }

  func testANonFiniteOffsetIsIgnored() {
    let proxy = proxy()
    proxy.setOffset(40)
    proxy.setOffset(.nan)
    proxy.setOffset(.infinity)
    XCTAssertEqual(proxy.offset, 40)
  }

  /// Spike §2: the lock also drops UIKit's inset adjustment, so an inset
  /// change re-applies Dart's offset.
  func testAnInsetChangeKeepsDartsOffset() {
    let proxy = proxy()
    proxy.setOffset(50)
    proxy.contentInset.top = 30
    XCTAssertEqual(proxy.contentOffset.y, -proxy.adjustedContentInset.top + 50)
  }

  /// Spec §8.4, Q8: never the status-bar target, invisible to VoiceOver,
  /// direct touches only: no trackpad or wheel scroll, no Apple Pencil (a
  /// narrow iPad window, where Scribble writes into Flutter's fields) and
  /// no pointer drag.
  func testItLeavesTheStatusBarAccessibilityTrackpadAndPencilAlone() {
    let proxy = proxy()
    XCTAssertFalse(proxy.scrollsToTop)
    XCTAssertFalse(proxy.isUserInteractionEnabled)
    XCTAssertFalse(proxy.isAccessibilityElement)
    XCTAssertTrue(proxy.accessibilityElementsHidden)
    XCTAssertEqual(proxy.panGestureRecognizer.allowedScrollTypesMask, [])
    XCTAssertEqual(
      proxy.panGestureRecognizer.allowedTouchTypes,
      [NSNumber(value: UITouch.TouchType.direct.rawValue)], "direct touches only")
    XCTAssertGreaterThan(proxy.contentSize.height, 10_000)
  }

  /// Q7: a pan that starts over a platform view (a subview of the Flutter
  /// view) does not begin.
  func testThePanBeginsOnlyOverTheContentItself() {
    let content = UIView()
    let platformView = UIView()
    content.addSubview(platformView)
    XCTAssertTrue(MinimizeProxy.begins(over: content, content: content))
    XCTAssertFalse(MinimizeProxy.begins(over: platformView, content: content))
    XCTAssertTrue(MinimizeProxy.begins(over: platformView, content: nil))
  }
}

/// Records every native → Dart call; every send succeeds.
final class RecordingEvents: NativeShellFlutterApiProtocol {
  var sent: [String] = []
  var controls: [NativeWindowControls] = []

  func onDestinationTapped(
    index indexArg: Int64, completion: @escaping (Result<Void, PigeonError>) -> Void
  ) {
    sent.append("destination \(indexArg)")
    completion(.success(()))
  }

  func onTrailingTapped(completion: @escaping (Result<Void, PigeonError>) -> Void) {
    sent.append("trailing")
    completion(.success(()))
  }

  func onFooterTapped(completion: @escaping (Result<Void, PigeonError>) -> Void) {
    sent.append("footer")
    completion(.success(()))
  }

  func onStateChanged(
    state stateArg: NativeShellState, completion: @escaping (Result<Void, PigeonError>) -> Void
  ) {
    sent.append("state")
    completion(.success(()))
  }

  func onWindowControlsChanged(
    controls controlsArg: NativeWindowControls,
    completion: @escaping (Result<Void, PigeonError>) -> Void
  ) {
    sent.append("controls")
    controls.append(controlsArg)
    completion(.success(()))
  }

  var searchTexts: [(String, Bool)] = []
  var fieldFrames: [NativeRect] = []

  func onSearchTextChanged(
    text textArg: String, composing composingArg: Bool,
    completion: @escaping (Result<Void, PigeonError>) -> Void
  ) {
    sent.append("searchText \(textArg)")
    searchTexts.append((textArg, composingArg))
    completion(.success(()))
  }

  func onSearchActiveChanged(
    active activeArg: Bool, completion: @escaping (Result<Void, PigeonError>) -> Void
  ) {
    sent.append("searchActive \(activeArg)")
    completion(.success(()))
  }

  func onSearchSubmitted(
    text textArg: String, completion: @escaping (Result<Void, PigeonError>) -> Void
  ) {
    sent.append("searchSubmitted \(textArg)")
    completion(.success(()))
  }

  func onSearchFieldChanged(
    frame frameArg: NativeRect, completion: @escaping (Result<Void, PigeonError>) -> Void
  ) {
    sent.append("field")
    fieldFrames.append(frameArg)
    completion(.success(()))
  }

  func onSearchScopeChanged(
    index indexArg: Int64, completion: @escaping (Result<Void, PigeonError>) -> Void
  ) {
    sent.append("searchScope \(indexArg)")
    completion(.success(()))
  }

  func onBackTapped(tab tabArg: Int64, completion: @escaping (Result<Void, PigeonError>) -> Void) {
    sent.append("back \(tabArg)")
    completion(.success(()))
  }

  func onPopToPage(
    tab tabArg: Int64, index indexArg: Int64,
    completion: @escaping (Result<Void, PigeonError>) -> Void
  ) {
    sent.append("popTo \(tabArg) \(indexArg)")
    completion(.success(()))
  }
}

/// The UIKit half of the shell (`NativeTabsController` inside the container)
/// in a real window of the test host. A plain view controller stands in for
/// the Flutter one: the shell only moves its view and sets its safe area.
@available(iOS 26.0, *)
final class NativeTabsTests: XCTestCase {
  private var window: UIWindow?
  private var extraWindows: [UIWindow] = []
  private var events = RecordingEvents()

  override func tearDown() {
    for window in [window].compactMap({ $0 }) + extraWindows {
      window.isHidden = true
      window.rootViewController = nil
    }
    window = nil
    extraWindows = []
    super.tearDown()
  }

  private func config(
    engaged: Bool = true, hidden: Bool = false, interactive: Bool = true,
    footer: Bool = false, trailing: Bool = false, reports: Bool = false, selected: Int64 = 0,
    minimize: Bool = false
  ) -> NativeChromeConfig {
    NativeChromeConfig(
      engaged: engaged,
      tabs: [
        NativeTab(title: "Home", sfSymbol: "house", sidebarOnly: false, search: false, pages: []),
        NativeTab(title: "Inbox", sfSymbol: "tray", sidebarOnly: false, search: false, pages: []),
      ]
        + (reports
          ? [
            NativeTab(
              title: "Reports", sfSymbol: "chart.bar", sidebarOnly: true, search: false, pages: [])
          ]
          : []),
      selectedIndex: selected,
      // Not UISearchTab's own "Search" and magnifyingglass: the app's
      // label must be seen to reach the tab.
      trailing: trailing ? NativeAction(title: "Find", sfSymbol: "sparkle.magnifyingglass") : nil,
      footer: footer
        ? NativeFooter(
          title: "Ann Lee", subtitle: "Account", sfSymbol: "person.crop.circle",
          semanticLabel: "Account, Ann Lee")
        : nil,
      tintArgb: 0xFF00_7AFF, dark: false, rtl: false, hidden: hidden, interactive: interactive,
      minimizeOnScroll: minimize, tabBarHidden: false)
  }

  /// Lets UIKit finish layout and any sidebar transition.
  private func settle() {
    RunLoop.current.run(until: Date().addingTimeInterval(0.5))
  }

  /// Polls until [sample] gives the same value twice in a row (0.1 s
  /// apart) and [ready] holds for it, or [timeout] passes; returns the last
  /// sample. UIKit lays out and animates on its own passes, which a slow
  /// runner stretches past a fixed settle: a wait, not a retry, so a
  /// layout that never gets there still fails the asserts that follow.
  private func stable<T: Equatable>(
    timeout: TimeInterval = 5, _ sample: () throws -> T, until ready: (T) -> Bool = { _ in true }
  ) rethrows -> T {
    let deadline = Date().addingTimeInterval(timeout)
    var last = try sample()
    while Date() < deadline {
      RunLoop.current.run(until: Date().addingTimeInterval(0.1))
      let next = try sample()
      if next == last, ready(next) { return next }
      last = next
    }
    return last
  }

  /// A shown window of the test host's scene, portrait whatever the
  /// simulator's orientation: in landscape UIKit tiles the sidebar, and the
  /// overlay tests need it over the content. A simulator keeps its last
  /// orientation (a landscape screenshot run leaves it there), and iPadOS 26
  /// refuses to rotate it from a test (`requestGeometryUpdate`: "the current
  /// windowing mode does not allow" it; `XCUIDevice`: UI tests only).
  /// `landscape`: the same window turned on its side (wide enough for UIKit
  /// to tile the sidebar), whatever the simulator's orientation.
  private func portraitWindow(
    root: UIViewController, landscape: Bool = false, width: CGFloat? = nil
  ) throws -> UIWindow {
    let scene = try XCTUnwrap(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    let bounds = scene.coordinateSpace.bounds
    let short = min(bounds.width, bounds.height)
    let long = max(bounds.width, bounds.height)
    window.frame = CGRect(
      x: 0, y: 0, width: width ?? (landscape ? long : short), height: landscape ? short : long)
    window.rootViewController = root
    window.isHidden = false
    return window
  }

  /// A shell installed in its own window with the first config applied.
  /// `sizeClass`: the container's horizontal size class, overriding the
  /// window's (a compact iPad window, or a regular one on an iPhone).
  private func installedShell(
    footer: Bool = false, trailing: Bool = false, reports: Bool = false,
    landscape: Bool = false, sizeClass: UIUserInterfaceSizeClass? = nil, selected: Int64 = 0,
    width: CGFloat? = nil
  ) throws -> NativeTabsController {
    let flutter = UIViewController()
    let tabs = NativeTabsController(flutter: flutter, events: events)
    let window = try portraitWindow(root: UIViewController(), landscape: landscape, width: width)
    let container = ShellContainerController(tabs: tabs, flutter: flutter)
    if let sizeClass { container.traitOverrides.horizontalSizeClass = sizeClass }
    window.rootViewController = container
    self.window = window
    tabs.apply(config(footer: footer, trailing: trailing, reports: reports, selected: selected))
    settle()
    return tabs
  }

  /// The overlay, tiled and top-bar tests need a regular-width iPad: an
  /// iPhone window is compact, where UIKit draws the bottom tab bar.
  private func requireIPad() throws {
    try XCTSkipUnless(
      UIDevice.current.userInterfaceIdiom == .pad, "an iPad layout (overlay, tiled, top bar)")
  }

  /// Every iPhone is compact, also at a regular size class (a Plus or Max
  /// iPhone in landscape): only an iPad shows the top bar and sidebar.
  private func requirePhone() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "an iPhone")
  }

  func testHidingTheChromeClosesAnOverlaySidebar() throws {
    try requireIPad()
    let tabs = try installedShell()
    tabs.setSidebarVisible(true)
    settle()
    XCTAssertEqual(tabs.currentState().sidebar, .overlay, "precondition: a portrait iPad overlays")

    tabs.apply(config(hidden: true))
    settle()
    XCTAssertTrue(tabs.sidebar.isHidden, "hiding closes an overlay sidebar (spec §5.5 step 6)")

    tabs.apply(config())
    settle()
    XCTAssertEqual(tabs.currentState().sidebar, .hidden, "the overlay does not come back")
  }

  func testGoingDormantClosesAnOverlaySidebar() throws {
    try requireIPad()
    let tabs = try installedShell()
    tabs.setSidebarVisible(true)
    settle()
    XCTAssertEqual(tabs.currentState().sidebar, .overlay, "precondition: a portrait iPad overlays")

    tabs.apply(config(engaged: false))
    settle()
    XCTAssertTrue(tabs.sidebar.isHidden, "dormant closes an overlay sidebar (spec §5.5 step 6)")
  }

  /// A guard's dialog is drawn in the Flutter view, below the overlay
  /// sidebar and its dimming view: a non-interactive config (a dialog
  /// above the shell, or a guard pending) closes the overlay first.
  func testANonInteractiveConfigClosesAnOverlaySidebar() throws {
    try requireIPad()
    let tabs = try installedShell()
    tabs.setSidebarVisible(true)
    settle()
    XCTAssertEqual(tabs.currentState().sidebar, .overlay, "precondition: a portrait iPad overlays")

    tabs.apply(config(interactive: false))
    settle()
    XCTAssertTrue(tabs.sidebar.isHidden, "nothing native covers the dialog")
    XCTAssertTrue(tabs.chromeVisible, "the chrome itself stays, inert")

    tabs.apply(config())
    settle()
    XCTAssertEqual(tabs.currentState().sidebar, .hidden, "the overlay does not come back")
  }

  // MARK: - Hit testing on UIKit's real view tree (spec §5.3)

  /// Opens the sidebar and waits for UIKit's open animation to end: while
  /// the tab bar morphs into the sidebar (about 1.25s on iOS 26.5) the
  /// sidebar's own view is still hidden.
  private func openSidebar(_ tabs: NativeTabsController) {
    tabs.setSidebarVisible(true)
    let deadline = Date().addingTimeInterval(4)
    repeat {
      RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    } while labelCentre("Inbox", in: sidebarView(tabs) ?? UIView(), tabs) == nil
      && Date() < deadline
    settle()
  }

  /// The sidebar's view (`UITabBarController.Sidebar` has no public one):
  /// the ancestor of the footer that is a direct child of the tab container.
  private func sidebarView(_ tabs: NativeTabsController) -> UIView? {
    func all(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(all) }
    return all(tabs.view).first { view in
      view.subviews.contains { $0 is UICollectionView && "\(type(of: $0))".contains("Sidebar") }
        || "\(type(of: view))".contains("Outline")
    }
  }

  /// Where a touch at [point] (container coordinates) lands.
  private func hit(_ tabs: NativeTabsController, _ point: CGPoint) throws -> UIView? {
    try XCTUnwrap(tabs.parent?.view).hitTest(point, with: nil)
  }

  /// A UIKit view of the native chrome, not the Flutter view below it.
  private func isNative(_ view: UIView?, _ tabs: NativeTabsController) -> Bool {
    guard let view else { return false }
    return view !== tabs.flutter.view && view.isDescendant(of: tabs.view)
  }

  /// The on-screen label [text] inside [container] (a label with no hidden
  /// ancestor), if any.
  private func shownLabel(_ text: String, in container: UIView) -> UILabel? {
    func labels(_ view: UIView) -> [UILabel] {
      ((view as? UILabel).map { [$0] } ?? []) + view.subviews.flatMap(labels)
    }
    func shown(_ view: UIView) -> Bool {
      var node: UIView? = view
      while let current = node {
        if current.isHidden || current.alpha < 0.01 { return false }
        node = current.superview
      }
      return true
    }
    return labels(container).first { $0.text == text && shown($0) }
  }

  /// The centre, in container coordinates, of the on-screen label [text]
  /// inside [container], if any.
  private func labelCentre(
    _ text: String, in container: UIView, _ tabs: NativeTabsController
  ) -> CGPoint? {
    guard let root = tabs.parent?.view, let label = shownLabel(text, in: container) else {
      return nil
    }
    return label.convert(CGPoint(x: label.bounds.midX, y: label.bounds.midY), to: root)
  }

  private func centreOfLabel(
    _ text: String, in container: UIView, _ tabs: NativeTabsController
  ) throws -> CGPoint {
    try XCTUnwrap(labelCentre(text, in: container, tabs), "no visible \(text) label")
  }

  /// The floating tab bar: its items stay with UIKit; beside the pill,
  /// just below the bar row and in the content, touches reach Flutter.
  func testTouchesBesideAndBelowThePillReachFlutter() throws {
    try requireIPad()
    let tabs = try installedShell()
    let root = try XCTUnwrap(tabs.parent?.view)
    let inbox = try centreOfLabel("Inbox", in: tabs.view, tabs)
    let barBottom = tabs.selectedViewController?.view.safeAreaInsets.top ?? 0
    XCTAssertGreaterThan(barBottom, inbox.y, "precondition: the bar row is in the safe area")

    XCTAssertTrue(isNative(try hit(tabs, inbox), tabs), "a tab bar item")
    XCTAssertTrue(
      try hit(tabs, CGPoint(x: 40, y: inbox.y)) === tabs.flutter.view, "beside the pill")
    XCTAssertTrue(
      try hit(tabs, CGPoint(x: root.bounds.width - 40, y: inbox.y)) === tabs.flutter.view,
      "beside the pill, trailing side")
    XCTAssertTrue(
      try hit(tabs, CGPoint(x: inbox.x, y: barBottom + 4)) === tabs.flutter.view,
      "just below the bar row")
    XCTAssertTrue(
      try hit(tabs, CGPoint(x: root.bounds.midX, y: root.bounds.midY)) === tabs.flutter.view,
      "the centre")
    XCTAssertTrue(
      try hit(tabs, CGPoint(x: root.bounds.midX, y: root.bounds.height - 4)) === tabs.flutter.view,
      "the bottom edge")

    // Under a dialog the pill lets touches through to its barrier; hidden,
    // it is not there at all.
    tabs.apply(config(interactive: false))
    XCTAssertTrue(try hit(tabs, inbox) === tabs.flutter.view, "inert under a dialog")
    tabs.apply(config(hidden: true))
    settle()
    XCTAssertTrue(try hit(tabs, inbox) === tabs.flutter.view, "hidden")
  }

  /// The portrait overlay sidebar: its rows, its empty area below the rows
  /// and its footer stay with UIKit (spec §5.3: "the sidebar"), and so does
  /// the dimming view beside it, whose tap closes the overlay.
  func testTheOverlaySidebarAndItsDimmingKeepTheirTouches() throws {
    try requireIPad()
    let tabs = try installedShell(footer: true)
    let root = try XCTUnwrap(tabs.parent?.view)
    openSidebar(tabs)
    XCTAssertEqual(tabs.currentState().sidebar, .overlay, "precondition: a portrait iPad overlays")
    let footer = try footerView(tabs)
    let row = try centreOfLabel("Inbox", in: try XCTUnwrap(sidebarView(tabs)), tabs)
    let footerTop = footer.convert(footer.bounds, to: root).minY
    XCTAssertGreaterThan(footerTop - row.y, 200, "precondition: empty sidebar below the rows")

    XCTAssertTrue(isNative(try hit(tabs, row), tabs), "a sidebar row")
    XCTAssertTrue(
      isNative(try hit(tabs, CGPoint(x: row.x, y: (row.y + footerTop) / 2)), tabs),
      "the sidebar's empty area")
    XCTAssertTrue(
      isNative(try hit(tabs, CGPoint(x: row.x, y: footerTop + 20)), tabs), "the footer")
    XCTAssertTrue(
      isNative(try hit(tabs, CGPoint(x: root.bounds.width - 40, y: root.bounds.midY)), tabs),
      "the dimming view")
  }

  /// Landscape tiles the sidebar: its rows stay with UIKit, and the content
  /// beside it reaches Flutter.
  func testBesideATiledSidebarTouchesReachFlutter() throws {
    try requireIPad()
    let tabs = try installedShell(landscape: true)
    let root = try XCTUnwrap(tabs.parent?.view)
    openSidebar(tabs)
    XCTAssertEqual(tabs.currentState().sidebar, .tiled, "precondition: a landscape iPad tiles")
    let sidebarEdge = tabs.selectedViewController?.view.safeAreaInsets.left ?? 0
    let row = try centreOfLabel("Inbox", in: try XCTUnwrap(sidebarView(tabs)), tabs)
    XCTAssertLessThan(row.x, sidebarEdge, "precondition: the row is in the sidebar")

    XCTAssertTrue(isNative(try hit(tabs, row), tabs), "a sidebar row")
    XCTAssertTrue(
      try hit(tabs, CGPoint(x: sidebarEdge + 4, y: root.bounds.midY)) === tabs.flutter.view,
      "just beside the sidebar")
    XCTAssertTrue(
      try hit(tabs, CGPoint(x: (sidebarEdge + root.bounds.width) / 2, y: root.bounds.midY))
        === tabs.flutter.view, "the content's centre")
  }

  /// A shell installed by the installer, as a scene connection does.
  private func installedByInstaller() throws -> (NativeShellInstaller, UIWindow) {
    let scene = try XCTUnwrap(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    let flutter = UIViewController()
    window.rootViewController = flutter
    window.isHidden = false
    self.window = window
    let installer = NativeShellInstaller(
      events: events, ownViewController: { flutter }, ownsFlutter: { $0 === flutter })
    installer.install(flutter, in: window)
    settle()
    return (installer, window)
  }

  private func tabs(in window: UIWindow) throws -> NativeTabsController {
    try XCTUnwrap((window.rootViewController as? ShellContainerController)?.tabs)
  }

  /// The window owns the shell; the installer must not, or engine → plugin
  /// → installer → shell → Flutter view controller → engine is a cycle.
  func testTheInstallerDoesNotKeepTheShellAlive() throws {
    weak var shell: NativeTabsController?
    // Inside a pool: UIKit autoreleases the controllers it hands out.
    let installer = try autoreleasepool { () throws -> NativeShellInstaller in
      let (installer, window) = try installedByInstaller()
      shell = try tabs(in: window)
      XCTAssertTrue(try installer.attach().installed)
      window.rootViewController = UIViewController()
      return installer
    }
    settle()
    XCTAssertNil(shell, "released with the window's root")
    XCTAssertFalse(try installer.attach().installed)
  }

  /// Until Dart attaches nothing receives native → Dart calls: sending
  /// only fails (and logs).
  func testStateAndWindowControlsWaitForDartToAttach() throws {
    let (installer, window) = try installedByInstaller()
    let shell = try tabs(in: window)
    shell.syncFlutter()
    XCTAssertEqual(events.sent, [], "nothing sent before attach")

    _ = try installer.attach()
    shell.syncFlutter()
    XCTAssertTrue(events.sent.contains("state"))
    XCTAssertTrue(events.sent.contains("controls"))
  }

  /// Under visible native chrome UIKit's tab bar and sidebar make room for
  /// the window controls themselves, and Flutter content starts below or
  /// beside them. A windowed read there (a 66pt leading delta with no
  /// vertical one below the bar row reads as `{66, 44}`) must not reach
  /// Dart as a cluster, pushed or read. Once the chrome hides (a page
  /// covers the shell) Flutter has the whole window and the read counts.
  func testWindowControlsAreZeroWhileTheNativeChromeIsVisible() throws {
    try requireIPad()
    let (installer, window) = try installedByInstaller()
    let shell = try tabs(in: window)
    let windowed = NativeWindowControls(leading: 66, top: 44)
    let zero = NativeWindowControls(leading: 0, top: 0)
    shell.readWindowControls = { _ in windowed }
    _ = try installer.attach()
    try installer.update(config: config())
    settle()
    XCTAssertTrue(shell.chromeVisible)
    XCTAssertEqual(events.controls.last, zero, "pushed")
    XCTAssertEqual(try installer.windowControls(), zero, "read")

    try installer.update(config: config(hidden: true))
    settle()
    XCTAssertEqual(events.controls.last, windowed, "pushed, chrome hidden")
    XCTAssertEqual(try installer.windowControls(), windowed, "read, chrome hidden")
  }

  /// Dart attached before a scene reconnect: the new shell sends at once.
  func testAShellInstalledAfterDartAttachedSends() throws {
    let scene = try XCTUnwrap(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    let flutter = UIViewController()
    window.rootViewController = flutter
    window.isHidden = false
    self.window = window
    let installer = NativeShellInstaller(
      events: events, ownViewController: { flutter }, ownsFlutter: { $0 === flutter })
    XCTAssertFalse(try installer.attach().installed)

    installer.install(flutter, in: window)
    settle()
    XCTAssertTrue(events.sent.contains("state"))
  }

  /// A scene reconnect with the engine alive: the new shell shows Dart's
  /// last config at once, also one Dart sent while no shell was installed
  /// (spec §5.7).
  func testAReinstallAfterASceneReconnectAppliesTheLastConfig() throws {
    let (installer, window) = try installedByInstaller()
    try installer.update(config: config())
    // The scene goes away: its window and shell are released.
    window.rootViewController = UIViewController()
    settle()
    try installer.update(config: config(selected: 1))

    let scene = try XCTUnwrap(window.windowScene)
    let next = UIWindow(windowScene: scene)
    let flutter = UIViewController()
    next.rootViewController = flutter
    next.isHidden = false
    extraWindows.append(next)
    installer.install(flutter, in: next)
    settle()

    let shell = try tabs(in: next)
    XCTAssertEqual(shell.config, config(selected: 1))
    XCTAssertTrue(shell.chromeVisible)
    XCTAssertFalse(shell.view.isHidden)
    XCTAssertEqual(shell.selectedTab?.identifier, "destination1")
  }

  // MARK: - Compact: UIKit's floating tab bar at the bottom (owner D1)

  /// iPhone, or an iPad window too narrow for the top bar: the native bar
  /// is UIKit's compact floating tab bar at the bottom. The Flutter view
  /// keeps the whole window; the bar's height reaches Flutter as its
  /// bottom safe area, and UIKit reports compact with no sidebar.
  func testACompactShellShowsTheBottomTabBarInFluttersBottomSafeArea() throws {
    let tabs = try installedShell(trailing: true, sizeClass: .compact)
    let root = try XCTUnwrap(tabs.parent?.view)
    let host = try XCTUnwrap(tabs.selectedViewController?.view)
    let state = tabs.currentState()
    XCTAssertTrue(state.compact)
    XCTAssertEqual(state.sidebar, .hidden)
    XCTAssertEqual(tabs.flutter.view.frame, root.bounds, "Flutter keeps the whole window")
    XCTAssertGreaterThan(
      host.safeAreaInsets.bottom, root.safeAreaInsets.bottom + 40, "the bar is in the host's safe area")
    XCTAssertEqual(
      tabs.flutter.view.safeAreaInsets.bottom, host.safeAreaInsets.bottom,
      "and so in Flutter's")
    let inbox = try centreOfLabel("Inbox", in: tabs.view, tabs)
    XCTAssertGreaterThan(inbox.y, root.bounds.height - host.safeAreaInsets.bottom, "a bottom bar")
  }

  /// A real narrow iPad window, no trait override: a 375pt-wide window is
  /// compact to UIKit itself (the Split View or Stage Manager size), so
  /// the shell shows the bottom bar, reports compact and leaves the
  /// sidebar-only tab out.
  func testANarrowIPadWindowIsCompactWithoutAnOverride() throws {
    try requireIPad()
    let tabs = try installedShell(trailing: true, reports: true, width: 375)
    let root = try XCTUnwrap(tabs.parent?.view)
    XCTAssertEqual(root.bounds.width, 375, "precondition: a narrow window")
    XCTAssertEqual(tabs.traitCollection.horizontalSizeClass, .compact, "UIKit's own size class")
    XCTAssertTrue(tabs.currentState().compact)
    XCTAssertFalse(tabs.tabs.contains { $0.identifier == "destination2" }, "sidebar-only left out")
    let host = try XCTUnwrap(tabs.selectedViewController?.view)
    XCTAssertGreaterThan(host.safeAreaInsets.bottom, root.safeAreaInsets.bottom + 40, "a bottom bar")
    XCTAssertEqual(tabs.flutter.view.safeAreaInsets.bottom, host.safeAreaInsets.bottom)
    let inbox = try centreOfLabel("Inbox", in: tabs.view, tabs)
    XCTAssertGreaterThan(inbox.y, root.bounds.height - host.safeAreaInsets.bottom)
  }

  /// The compact bar's items stay with UIKit; the content, and the row
  /// just above the bar, reach Flutter. The bar's own top, not the safe
  /// area's: on iPadOS 27 the pill rises 5pt above the 72pt safe area.
  /// The ⌕ circle: `testTheTrailingActionIsTheSeparateCircleAfterThePill`.
  func testTouchesAboveTheCompactBarReachFlutter() throws {
    let tabs = try installedShell(trailing: true, sizeClass: .compact)
    let root = try XCTUnwrap(tabs.parent?.view)
    let barTop = tabs.tabBar.convert(tabs.tabBar.bounds, to: root).minY
    let inbox = try centreOfLabel("Inbox", in: tabs.view, tabs)

    XCTAssertTrue(isNative(try hit(tabs, inbox), tabs), "a tab bar item")
    XCTAssertTrue(
      try hit(tabs, CGPoint(x: inbox.x, y: barTop - 4)) === tabs.flutter.view,
      "just above the bar")
    XCTAssertTrue(
      try hit(tabs, CGPoint(x: root.bounds.midX, y: root.bounds.midY)) === tabs.flutter.view,
      "the centre")
    XCTAssertTrue(
      try hit(tabs, CGPoint(x: root.bounds.midX, y: 4)) === tabs.flutter.view, "the top edge")
    tabs.apply(config(interactive: false, trailing: true))
    XCTAssertTrue(try hit(tabs, inbox) === tabs.flutter.view, "inert under a dialog")
  }

  /// The trailing action is the separate ⌕ circle after the pill on every
  /// compact bar (spec §14), not one more item inside it. iOS 27 draws
  /// the circle only for the prominent tab (`prominentTabIdentifier`),
  /// which a search tab is by default only when it activates the system
  /// search field. The circle is native; the gap before it is Flutter's.
  func testTheTrailingActionIsTheSeparateCircleAfterThePill() throws {
    let tabs = try installedShell(trailing: true, sizeClass: .compact)
    // UIKit lays the bar out on its own passes: wait until it is drawn
    // with the circle and holds still, so both hits land on the settled
    // bar. Without the circle (iOS 27 with ⌕ in the pill) the asserts
    // below fail after the deadline.
    var bar = stable({ compactBar(tabs) }, until: { $0.circle != nil && $0.find == nil })
    // Drawn and still is not hit-testable (VK-569): on a slow runner UIKit
    // enables the circle a few passes later, and the hit falls through to
    // Flutter. Wait, capped, until a hit at the circle lands on native chrome.
    let hitDeadline = Date().addingTimeInterval(10)
    while Date() < hitDeadline {
      if let ring = bar.circle,
        isNative(try hit(tabs, CGPoint(x: ring.midX, y: ring.midY)), tabs)
      {
        break
      }
      RunLoop.current.run(until: Date().addingTimeInterval(0.1))
      bar = compactBar(tabs)
    }
    XCTAssertNil(bar.find, "no Find item inside the pill; \(bar)")
    let inbox = try XCTUnwrap(bar.inbox, "the Inbox label; \(bar)")
    let pill = try XCTUnwrap(bar.pill, "the pill; \(bar)")
    let ring = try XCTUnwrap(bar.circle, "the ⌕ circle; \(bar)")
    let onRing = try hit(tabs, CGPoint(x: ring.midX, y: ring.midY))
    XCTAssertTrue(isNative(onRing, tabs), "the ⌕ circle; hit \(viewType(onRing)); \(bar)")
    XCTAssertGreaterThan(
      ring.minX - pill.maxX, 8, "precondition: a gap between pill and circle; \(bar)")
    let inGap = try hit(tabs, CGPoint(x: (pill.maxX + ring.minX) / 2, y: inbox.y))
    XCTAssertTrue(
      inGap === tabs.flutter.view,
      "the gap between the pill and the circle; hit \(viewType(inGap)); \(bar)")
  }

  private func viewType(_ view: UIView?) -> String {
    view.map { "\(type(of: $0))" } ?? "nil"
  }

  /// The compact bar as drawn, in container coordinates: the drawn tab bar
  /// subviews, the pill (the one around the Inbox label), the separate ⌕
  /// circle if UIKit draws one (the drawn subview furthest to the trailing
  /// side that does not overlap the pill), and a shown "Find" label, which
  /// only an item inside the pill has (the circle's title is hidden).
  /// Drawn: shown, with something shown inside (UIKit keeps an empty
  /// circle container when the search tab sits in the pill). Its
  /// description goes into failure messages.
  private struct CompactBar: CustomStringConvertible, Equatable {
    var drawn: [CGRect] = []
    var inbox: CGPoint?
    var pill: CGRect?
    var circle: CGRect?
    var find: String?

    var description: String {
      "inbox \(String(describing: inbox)), pill \(String(describing: pill)), "
        + "circle \(String(describing: circle)), drawn tab bar subviews \(drawn), "
        + "shown Find label \(find ?? "none")"
    }
  }

  private func compactBar(_ tabs: NativeTabsController) -> CompactBar {
    func drawn(_ view: UIView) -> Bool {
      !view.isHidden && view.alpha > 0.01 && !view.bounds.isEmpty
        && (view.subviews.isEmpty || view.subviews.contains(where: drawn))
    }
    var bar = CompactBar()
    guard let root = tabs.parent?.view else { return bar }
    bar.drawn = tabs.tabBar.subviews.filter(drawn).map { $0.convert($0.bounds, to: root) }
    bar.inbox = labelCentre("Inbox", in: tabs.view, tabs)
    if let inbox = bar.inbox { bar.pill = bar.drawn.first { $0.contains(inbox) } }
    if let pill = bar.pill {
      bar.circle = bar.drawn.filter { !$0.intersects(pill) }.max { $0.maxX < $1.maxX }
    }
    if let find = shownLabel("Find", in: tabs.view) {
      bar.find = "\(find.convert(find.bounds, to: root)) in \(viewType(find.superview))"
    }
    return bar
  }

  /// Hidden (a sheet or dialog above the shell, or a page pushed), the
  /// compact bar is not there for touch, and Flutter's bottom safe area is
  /// the window's own (the home indicator): a sheet lays out against it.
  func testAHiddenCompactBarLeavesFlutterTheWindowsSafeArea() throws {
    let tabs = try installedShell(trailing: true, sizeClass: .compact)
    let root = try XCTUnwrap(tabs.parent?.view)
    let inbox = try centreOfLabel("Inbox", in: tabs.view, tabs)

    tabs.apply(config(hidden: true, trailing: true))
    settle()
    XCTAssertEqual(tabs.flutter.view.frame, root.bounds)
    XCTAssertEqual(
      tabs.flutter.view.safeAreaInsets.bottom, root.safeAreaInsets.bottom, "the home indicator")
    XCTAssertTrue(try hit(tabs, inbox) === tabs.flutter.view, "hidden")
  }

  /// Compact has no sidebar, so a sidebar-only destination is left out of
  /// the compact bar (as P1 leaves it out of the Flutter one) and comes
  /// back at regular width, selected again if Dart still selects it.
  /// Neither is a user's selection: nothing is proposed to Dart.
  func testASidebarOnlyDestinationIsLeftOutOfTheCompactBar() throws {
    try requireIPad()  // An iPhone stays compact at a regular size class.
    let tabs = try installedShell(reports: true, sizeClass: .compact)
    let container = try XCTUnwrap(tabs.parent)
    func shown() -> [String] { tabs.tabs.map(\.identifier) }
    XCTAssertEqual(shown(), ["destination0", "destination1"])
    XCTAssertNil(labelCentre("Reports", in: tabs.view, tabs))

    tabs.apply(config(reports: true, selected: 2))
    settle()
    XCTAssertEqual(tabs.selectedTab?.identifier, "destination0", "hidden: not selectable")

    container.traitOverrides.horizontalSizeClass = .regular
    settle()
    XCTAssertEqual(shown(), ["destination0", "destination1", "destination2"])
    XCTAssertEqual(tabs.selectedTab?.identifier, "destination2", "Dart's selection, back")
    XCTAssertFalse(events.sent.contains { $0.hasPrefix("destination") })
  }

  /// The last shell leaving sends the dormant config (no tabs), and the
  /// next shell's config follows (a route replaced, a test re-pumped). The
  /// dormant spell must not empty UIKit's tabs: emptied and refilled, the
  /// compact bar came back hidden under the content, with the host's (and
  /// so Flutter's) bottom safe area down to the home indicator (iPhone,
  /// iOS 26.5, Task 7 dry run).
  func testADormantSpellKeepsTheTabsSoTheCompactBarComesBack() throws {
    let tabs = try installedShell(trailing: true, sizeClass: .compact)
    let root = try XCTUnwrap(tabs.parent?.view)
    let shown = tabs.tabs.map(\.identifier)

    tabs.apply(
      NativeChromeConfig(
        engaged: false, tabs: [], selectedIndex: 0, tintArgb: 0xFF00_7AFF, dark: false,
        rtl: false, hidden: false, interactive: true, minimizeOnScroll: false,
        tabBarHidden: false))
    settle()
    XCTAssertFalse(tabs.chromeVisible)
    XCTAssertEqual(tabs.tabs.map(\.identifier), shown, "dormant leaves the tabs alone")

    tabs.apply(config(trailing: true))
    settle()
    let host = try XCTUnwrap(tabs.selectedViewController?.view)
    XCTAssertGreaterThan(host.safeAreaInsets.bottom, root.safeAreaInsets.bottom + 40)
    XCTAssertEqual(tabs.flutter.view.safeAreaInsets.bottom, host.safeAreaInsets.bottom)
  }

  /// Compact has no sidebar: Dart's request is ignored.
  func testTheSidebarStaysClosedWhenCompact() throws {
    let tabs = try installedShell(sizeClass: .compact)
    tabs.setSidebarVisible(true)
    settle()
    XCTAssertEqual(tabs.currentState().sidebar, .hidden)
  }

  /// The compact bar is at the bottom and does not clear the window
  /// controls at the top: Flutter content must, so the read reaches Dart.
  func testWindowControlsAreReadUnderACompactBar() throws {
    let tabs = try installedShell(sizeClass: .compact)
    let windowed = NativeWindowControls(leading: 66, top: 44)
    tabs.readWindowControls = { _ in windowed }
    tabs.dartAttached = true
    tabs.syncFlutter()
    XCTAssertTrue(tabs.chromeVisible)
    XCTAssertEqual(events.controls.last, windowed, "pushed")
    XCTAssertEqual(tabs.windowControls(), windowed, "read")
  }

  /// The trailing action is a search-role tab (`UISearchTab`): the
  /// separate ⌕ at the end of the compact bar, the trailing end of the top
  /// bar, the first sidebar row. A tap only calls the app.
  func testTheTrailingActionIsASearchTabThatOnlyCallsTheApp() throws {
    let tabs = try installedShell(trailing: true, sizeClass: .compact)
    let search = try XCTUnwrap(tabs.tabs.first as? UISearchTab)
    XCTAssertEqual(search.title, "Find", "the app's label, read by VoiceOver")
    XCTAssertEqual(search.image, UIImage(systemName: "sparkle.magnifyingglass"), "the app's symbol")
    XCTAssertFalse(tabs.tabBarController(tabs, shouldSelectTab: search))
    XCTAssertEqual(events.sent.last, "trailing")
    XCTAssertEqual(tabs.selectedTab?.identifier, "destination0", "nothing selected")
  }

  /// A window resized across the size-class boundary (Stage Manager,
  /// Split View): UIKit swaps the bar, and Dart hears the new state.
  func testResizingAcrossTheSizeClassRepublishesTheState() throws {
    try requireIPad()  // An iPhone stays compact at a regular size class.
    let tabs = try installedShell(sizeClass: .regular)
    let container = try XCTUnwrap(tabs.parent)
    tabs.dartAttached = true
    tabs.syncFlutter()
    XCTAssertFalse(tabs.currentState().compact)
    let before = events.sent.filter { $0 == "state" }.count

    container.traitOverrides.horizontalSizeClass = .compact
    settle()
    XCTAssertTrue(tabs.currentState().compact)
    XCTAssertEqual(events.sent.filter { $0 == "state" }.count, before + 1)
    XCTAssertEqual(tabs.flutter.view.frame, container.view.bounds)

    container.traitOverrides.horizontalSizeClass = .regular
    settle()
    XCTAssertFalse(tabs.currentState().compact)
    XCTAssertEqual(events.sent.filter { $0 == "state" }.count, before + 2)
  }

  /// A sidebar-only selection is left out of the compact bar. UIKit would
  /// then pick a tab itself, and its first tab is the ⌕ search tab: a
  /// selected search tab is the compact bar's search state, which the
  /// trailing action must never enter. The shell selects the first shown
  /// destination instead and proposes nothing: Dart keeps its selection
  /// and tells the app it is hidden (`onSelectedDestinationHidden`).
  /// (a) A regular iPad window narrows (Split View, Stage Manager).
  func testANarrowedWindowWithAHiddenSelectionNeverSelectsTheSearchTab() throws {
    try requireIPad()
    let tabs = try installedShell(trailing: true, reports: true, sizeClass: .regular, selected: 2)
    let container = try XCTUnwrap(tabs.parent)
    XCTAssertEqual(tabs.selectedTab?.identifier, "destination2", "precondition")

    container.traitOverrides.horizontalSizeClass = .compact
    settle()
    XCTAssertFalse(tabs.tabs.contains { $0.identifier == "destination2" }, "precondition: left out")
    XCTAssertFalse(tabs.selectedTab is UISearchTab, "never the search tab")
    XCTAssertEqual(tabs.selectedTab?.identifier, "destination0", "the first shown destination")
    XCTAssertFalse(events.sent.contains { $0.hasPrefix("destination") || $0 == "trailing" })
  }

  /// (b) The first config already selects a sidebar-only destination at
  /// compact width (an iPhone, a narrow iPad window).
  func testAHiddenSelectionAtInstallNeverSelectsTheSearchTab() throws {
    let tabs = try installedShell(trailing: true, reports: true, sizeClass: .compact, selected: 2)
    XCTAssertFalse(tabs.tabs.contains { $0.identifier == "destination2" }, "precondition: left out")
    XCTAssertFalse(tabs.selectedTab is UISearchTab, "never the search tab")
    XCTAssertEqual(tabs.selectedTab?.identifier, "destination0", "the first shown destination")
    XCTAssertFalse(events.sent.contains { $0.hasPrefix("destination") || $0 == "trailing" })
  }

  /// A size-class change while dormant (no shell asks for the chrome)
  /// leaves UIKit's tabs and selection alone, as the dormant config does.
  func testASizeClassChangeWhileDormantLeavesTheSelectionAlone() throws {
    let tabs = try installedShell(sizeClass: .regular, selected: 1)
    let container = try XCTUnwrap(tabs.parent)
    XCTAssertEqual(tabs.selectedTab?.identifier, "destination1", "precondition")
    tabs.apply(
      NativeChromeConfig(
        engaged: false, tabs: [], selectedIndex: 0, tintArgb: 0xFF00_7AFF, dark: false,
        rtl: false, hidden: false, interactive: true, minimizeOnScroll: false,
        tabBarHidden: false))
    settle()

    container.traitOverrides.horizontalSizeClass = .compact
    settle()
    XCTAssertEqual(tabs.selectedTab?.identifier, "destination1", "dormant: not moved")
  }

  /// Every iPhone is compact (owner D1), also where its size class is
  /// regular: a Plus or Max iPhone, or the iPhone Air, in landscape. UIKit
  /// draws the bottom bar there, never the top bar or a sidebar, so the
  /// shell must say compact (Dart maps it to the bottom bar, hides it
  /// under sheets) and leave sidebar-only tabs out.
  func testAnIPhoneAtARegularSizeClassIsCompact() throws {
    try requirePhone()
    let tabs = try installedShell(trailing: true, reports: true, sizeClass: .regular)
    XCTAssertEqual(tabs.traitCollection.horizontalSizeClass, .regular, "precondition")
    let state = tabs.currentState()
    XCTAssertTrue(state.compact, "compact")
    XCTAssertEqual(state.sidebar, .hidden, "no sidebar")
    XCTAssertFalse(tabs.tabs.contains { $0.identifier == "destination2" }, "sidebar-only left out")

    tabs.setSidebarVisible(true)
    settle()
    XCTAssertEqual(tabs.currentState().sidebar, .hidden, "the request is ignored")

    let windowed = NativeWindowControls(leading: 66, top: 44)
    tabs.readWindowControls = { _ in windowed }
    XCTAssertEqual(tabs.windowControls(), windowed, "read, as under any compact bar")
  }

  /// VK-403 guard: a tiled sidebar does not resize the Flutter view; its
  /// width reaches Flutter as the start safe area (Dart then lays the body
  /// out beside it). Measured equal on iPadOS 26.5 and 27.0.
  func testATiledSidebarIsFluttersStartSafeArea() throws {
    try requireIPad()
    let tabs = try installedShell(landscape: true)
    let root = try XCTUnwrap(tabs.parent?.view)
    openSidebar(tabs)
    XCTAssertEqual(tabs.currentState().sidebar, .tiled, "precondition: a landscape iPad tiles")
    let host = try XCTUnwrap(tabs.selectedViewController?.view)
    XCTAssertGreaterThan(host.safeAreaInsets.left, 200, "the sidebar's width")
    XCTAssertEqual(tabs.flutter.view.frame, root.bounds)
    XCTAssertEqual(tabs.flutter.view.safeAreaInsets.left, host.safeAreaInsets.left)
  }

  private func footerView(_ tabs: NativeTabsController) throws -> SidebarFooterView {
    try XCTUnwrap(tabs.sidebar.bottomBarView as? SidebarFooterView)
  }

  /// Q8: under a Flutter dialog the chrome is inert for VoiceOver too.
  func testANonInteractiveChromeIsHiddenFromVoiceOver() throws {
    let tabs = try installedShell(footer: true)
    let footer = try footerView(tabs)
    XCTAssertFalse(tabs.view.accessibilityElementsHidden)
    XCTAssertFalse(footer.accessibilityElementsHidden)

    tabs.apply(config(interactive: false, footer: true))
    XCTAssertTrue(tabs.view.accessibilityElementsHidden, "tab bar and sidebar")
    XCTAssertTrue(footer.accessibilityElementsHidden, "footer")

    tabs.apply(config(footer: true))
    XCTAssertFalse(tabs.view.accessibilityElementsHidden)
    XCTAssertFalse(footer.accessibilityElementsHidden)
  }

  func testVoiceOverCannotActivateTheFooterUnderADialog() throws {
    let tabs = try installedShell(footer: true)
    let footer = try footerView(tabs)

    tabs.apply(config(interactive: false, footer: true))
    XCTAssertFalse(footer.accessibilityActivate())
    XCTAssertFalse(events.sent.contains("footer"), "no footer callback under a dialog")

    tabs.apply(config(footer: true))
    XCTAssertTrue(footer.accessibilityActivate())
    XCTAssertEqual(events.sent.filter { $0 == "footer" }.count, 1)
  }

  // MARK: - VK-600: minimize on scroll

  /// Spec VK-600 §8.5: the shell's minimizeOnScroll picks the behaviour.
  func testTheConfigSetsTheMinimizeBehaviour() throws {
    let tabs = try installedShell()
    tabs.apply(config(minimize: true))
    XCTAssertEqual(tabs.tabBarMinimizeBehavior, .onScrollDown)
    tabs.apply(config(minimize: false))
    XCTAssertEqual(tabs.tabBarMinimizeBehavior, .never)
  }

  /// §8.2, §8.6: each destination's root page has a proxy for the bottom
  /// edge (spec P3b-2 §6.8), and Dart's offset reaches that tab's proxy
  /// only.
  func testAMinimizeOffsetReachesItsTabsProxy() throws {
    let tabs = try installedShell()
    let host = try XCTUnwrap(tabs.topHost(ofTab: 0))
    let home = try XCTUnwrap(tabs.minimizeProxy(ofTab: 0))
    let inbox = try XCTUnwrap(tabs.minimizeProxy(ofTab: 1))
    host.loadViewIfNeeded()
    XCTAssertTrue(host.contentScrollView(for: .bottom) === home)
    tabs.setMinimizeScroll(tab: 1, offset: 240)
    tabs.setMinimizeScroll(tab: 0, offset: .nan)
    tabs.setMinimizeScroll(tab: 9, offset: 50)
    XCTAssertEqual(inbox.offset, 240)
    XCTAssertEqual(home.offset, 0)
  }

  /// §8.5, spike §3.2: the toggle is the public "expand now"; it does
  /// nothing while minimize is off.
  func testExpandTogglesOnlyWhileMinimizeIsOn() throws {
    let tabs = try installedShell()
    tabs.apply(config(minimize: true))
    tabs.expandMinimizedBar()
    XCTAssertEqual(tabs.minimizeExpands, 1)
    XCTAssertEqual(tabs.tabBarMinimizeBehavior, .onScrollDown)
    tabs.apply(config(minimize: false))
    tabs.expandMinimizedBar()
    XCTAssertEqual(tabs.minimizeExpands, 1)
    XCTAssertEqual(tabs.tabBarMinimizeBehavior, .never)
  }

  /// The channel: the installer forwards both calls to the shell.
  func testTheInstallerForwardsMinimizeCalls() throws {
    let (installer, window) = try installedByInstaller()
    _ = try installer.attach()
    var minimizing = config(minimize: true)
    minimizing.selectedIndex = 0
    try installer.update(config: minimizing)
    settle()
    let shell = try tabs(in: window)
    try installer.setMinimizeScroll(tab: 0, offset: 77)
    try installer.expandTabBar()
    XCTAssertEqual(shell.minimizeProxy(ofTab: 0)?.offset, 77)
    XCTAssertEqual(shell.minimizeExpands, 1)
  }

  private func panIsOnFlutter(_ tabs: NativeTabsController, host index: Int) -> Bool {
    guard let pan = tabs.minimizeProxy(ofTab: index)?.panGestureRecognizer else { return false }
    return tabs.flutter.view.gestureRecognizers?.contains(pan) ?? false
  }

  /// The pan recognizers on [view]: the test's stand-in Flutter view has
  /// none of its own, so every one is a proxy's.
  private func pans(on view: UIView) -> Int {
    view.gestureRecognizers?.filter { $0 is UIPanGestureRecognizer }.count ?? 0
  }

  /// Spec VK-600 §8.3: compact, shown, interactive, minimize on, a
  /// non-search tab → the selected tab's pan is on the Flutter view and
  /// never cancels or delays a touch.
  func testTheSelectedTabsPanSitsOnTheFlutterViewInCompact() throws {
    let tabs = try installedShell(sizeClass: .compact)
    tabs.apply(config(minimize: true))
    settle()
    XCTAssertTrue(panIsOnFlutter(tabs, host: 0))
    let pan = try XCTUnwrap(tabs.minimizeProxy(ofTab: 0)?.panGestureRecognizer)
    XCTAssertFalse(pan.cancelsTouchesInView)
    XCTAssertFalse(pan.delaysTouchesBegan)
    XCTAssertFalse(pan.delaysTouchesEnded)
    XCTAssertTrue(tabs.minimizeProxy(ofTab: 0)?.contentView === tabs.flutter.view)
    XCTAssertTrue(tabs.debugSnapshot().minimizePanAttached)
  }

  /// The attached pan takes no trackpad or mouse scroll (Q8), and it stays
  /// the only one. Whether a real touch still reaches Flutter with it there
  /// is MinimizeUITests' (a hit test never consults gesture recognizers).
  func testTheAttachedPanIsAloneAndTakesNoScrollEvents() throws {
    let tabs = try installedShell(sizeClass: .compact)
    tabs.apply(config(minimize: true))
    settle()
    XCTAssertTrue(panIsOnFlutter(tabs, host: 0), "precondition: attached")
    let root = try XCTUnwrap(tabs.parent?.view)
    XCTAssertTrue(
      try hit(tabs, CGPoint(x: root.bounds.midX, y: root.bounds.midY)) === tabs.flutter.view,
      "PassThroughView guard: the body's point still hit-tests to the Flutter view")
    let pan = try XCTUnwrap(tabs.minimizeProxy(ofTab: 0)?.panGestureRecognizer)
    XCTAssertEqual(pan.allowedScrollTypesMask, [])
    XCTAssertEqual(pans(on: tabs.flutter.view), 1)
    tabs.apply(config(minimize: true))
    XCTAssertEqual(pans(on: tabs.flutter.view), 1, "a repeated config adds none")
  }

  /// An iPhone is always compact (`isCompact`), so regular needs an iPad.
  func testNoPanAtRegularWidthAndTheProxiesGoBackToTheTop() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "regular needs an iPad")
    let tabs = try installedShell(sizeClass: .regular)
    tabs.apply(config(minimize: true))
    tabs.setMinimizeScroll(tab: 0, offset: 300)
    tabs.apply(config(selected: 1, minimize: true))
    settle()
    XCTAssertFalse(panIsOnFlutter(tabs, host: 0))
    XCTAssertFalse(panIsOnFlutter(tabs, host: 1))
    XCTAssertEqual(tabs.minimizeProxy(ofTab: 0)?.offset, 0)
  }

  /// Spec §10: a window narrowed to compact takes the pan; widened to
  /// regular it gives it back and every proxy returns to the top.
  func testASizeClassChangeMovesThePan() throws {
    try requireIPad()  // An iPhone stays compact at a regular size class.
    let tabs = try installedShell(sizeClass: .regular)
    let container = try XCTUnwrap(tabs.parent)
    tabs.apply(config(minimize: true))
    XCTAssertFalse(panIsOnFlutter(tabs, host: 0), "precondition: regular")

    container.traitOverrides.horizontalSizeClass = .compact
    XCTAssertTrue(stable({ panIsOnFlutter(tabs, host: 0) }, until: { $0 }), "narrowed")
    tabs.setMinimizeScroll(tab: 0, offset: 120)

    container.traitOverrides.horizontalSizeClass = .regular
    XCTAssertFalse(stable({ panIsOnFlutter(tabs, host: 0) }, until: { !$0 }), "widened")
    XCTAssertEqual(tabs.minimizeProxy(ofTab: 0)?.offset, 0)
    XCTAssertEqual(pans(on: tabs.flutter.view), 0)
  }

  func testNoPanWhenMinimizeIsOffHiddenOrInert() throws {
    let tabs = try installedShell(sizeClass: .compact)
    tabs.apply(config(minimize: false))
    XCTAssertFalse(panIsOnFlutter(tabs, host: 0))
    tabs.apply(config(hidden: true, minimize: true))
    XCTAssertFalse(panIsOnFlutter(tabs, host: 0))
    tabs.apply(config(interactive: false, minimize: true))
    XCTAssertFalse(panIsOnFlutter(tabs, host: 0))
    tabs.apply(config(minimize: true))
    XCTAssertTrue(panIsOnFlutter(tabs, host: 0))
  }

  /// Task 3 review: every end of eligibility takes the pan off the Flutter
  /// view, back to its proxy: minimize off, hidden, inert, dormant.
  func testEveryEndOfEligibilityGivesThePanBack() throws {
    let tabs = try installedShell(sizeClass: .compact)
    let home = try XCTUnwrap(tabs.minimizeProxy(ofTab: 0))
    for (label, ineligible) in [
      ("minimize off", config(minimize: false)),
      ("hidden", config(hidden: true, minimize: true)),
      ("inert", config(interactive: false, minimize: true)),
      ("dormant", config(engaged: false, minimize: true)),
    ] {
      tabs.apply(config(minimize: true))
      XCTAssertTrue(panIsOnFlutter(tabs, host: 0), "precondition before \(label)")
      tabs.apply(ineligible)
      XCTAssertEqual(pans(on: tabs.flutter.view), 0, label)
      XCTAssertTrue(home.gestureRecognizers?.contains(home.panGestureRecognizer) ?? false, label)
      XCTAssertNil(tabs.attachedMinimizeProxy, label)
      XCTAssertFalse(tabs.debugSnapshot().minimizePanAttached, label)
    }
  }

  /// The pan follows the selection; the old one goes back to its proxy.
  func testThePanFollowsTheSelection() throws {
    let tabs = try installedShell(sizeClass: .compact)
    tabs.apply(config(minimize: true))
    tabs.apply(config(selected: 1, minimize: true))
    settle()
    XCTAssertTrue(panIsOnFlutter(tabs, host: 1))
    XCTAssertFalse(panIsOnFlutter(tabs, host: 0))
    let home = try XCTUnwrap(tabs.minimizeProxy(ofTab: 0))
    XCTAssertTrue(home.gestureRecognizers?.contains(home.panGestureRecognizer) ?? false)
  }

  /// Q5: no pan while the search destination is selected; back on an
  /// ordinary tab it returns.
  func testNoPanWhileTheSearchTabIsSelected() throws {
    let tabs = try installedSearchShell(sizeClass: .compact)
    tabs.apply(searchConfig(minimize: true))
    settle()
    XCTAssertTrue(panIsOnFlutter(tabs, host: 0), "precondition: Home")

    tabs.apply(searchConfig(selected: 2, minimize: true))
    settle()
    XCTAssertEqual(pans(on: tabs.flutter.view), 0)
    XCTAssertNil(tabs.attachedMinimizeProxy)
    XCTAssertFalse(tabs.debugSnapshot().minimizePanAttached)

    tabs.apply(searchConfig(selected: 1, minimize: true))
    settle()
    XCTAssertTrue(panIsOnFlutter(tabs, host: 1))
  }

  /// A structure change builds new hosts: the old host's pan leaves the
  /// Flutter view with it, and the new selected host's takes its place.
  func testARebuildLeavesOnlyTheNewHostsPan() throws {
    let tabs = try installedShell(sizeClass: .compact)
    weak var old: MinimizeProxy?
    autoreleasepool {
      tabs.apply(config(minimize: true))
      old = tabs.minimizeProxy(ofTab: 0)
      XCTAssertTrue(panIsOnFlutter(tabs, host: 0), "precondition")
      tabs.apply(config(trailing: true, minimize: true))
    }
    settle()
    XCTAssertFalse(tabs.minimizeProxy(ofTab: 0) === old, "precondition: a new host")
    XCTAssertTrue(panIsOnFlutter(tabs, host: 0))
    XCTAssertEqual(pans(on: tabs.flutter.view), 1)
  }

  /// A scene reconnect: the old shell gives its pan back as its scene
  /// goes, whether or not it is released; the new shell attaches its own.
  func testASceneReconnectTakesTheOldShellsPanOff() throws {
    let (installer, window) = try installedByInstaller()
    _ = try installer.attach()
    try installer.update(config: config(minimize: true))
    let old = try tabs(in: window)
    try XCTUnwrap(old.parent).traitOverrides.horizontalSizeClass = .compact
    XCTAssertTrue(stable({ panIsOnFlutter(old, host: 0) }, until: { $0 }), "precondition")

    let next = try reconnect(installer, from: window)
    XCTAssertEqual(pans(on: old.flutter.view), 0)
    XCTAssertNil(old.attachedMinimizeProxy)
    let shell = try tabs(in: next)
    try XCTUnwrap(shell.parent).traitOverrides.horizontalSizeClass = .compact
    XCTAssertTrue(stable({ panIsOnFlutter(shell, host: 0) }, until: { $0 }), "the new shell's")
  }

  /// Final review M1: once its scene went, the old shell never puts its pan
  /// back on the Flutter view, which a new shell may own by then. Its
  /// size-class handler can still run while its window is torn down, and
  /// so can a late apply.
  func testAShellWhoseSceneWentNeverPutsItsPanBack() throws {
    let (installer, window) = try installedByInstaller()
    _ = try installer.attach()
    try installer.update(config: config(minimize: true))
    let old = try tabs(in: window)
    let container = try XCTUnwrap(old.parent)
    container.traitOverrides.horizontalSizeClass = .compact
    XCTAssertTrue(stable({ panIsOnFlutter(old, host: 0) }, until: { $0 }), "precondition")

    installer.sceneDisconnected()
    XCTAssertEqual(pans(on: old.flutter.view), 0, "precondition: detached")
    container.traitOverrides.horizontalSizeClass = .regular
    container.traitOverrides.horizontalSizeClass = .compact
    old.updateMinimizePan()
    old.apply(config(minimize: true))
    settle()
    XCTAssertEqual(pans(on: old.flutter.view), 0, "never back on the Flutter view")
    XCTAssertNil(old.attachedMinimizeProxy)
  }

  /// Never a pan without its proxy on the Flutter view: a shell released
  /// while the Flutter view lives on (an app replacing the root) takes
  /// its pan back first.
  func testAReleasedShellLeavesNoPanOnTheFlutterView() throws {
    weak var shell: NativeTabsController?
    // Inside a pool: UIKit autoreleases the controllers it hands out.
    let flutterView = try autoreleasepool { () throws -> UIView in
      let tabs = try installedShell(sizeClass: .compact)
      tabs.apply(config(minimize: true))
      XCTAssertTrue(panIsOnFlutter(tabs, host: 0), "precondition")
      shell = tabs
      window?.rootViewController = UIViewController()
      return tabs.flutter.view
    }
    settle()
    XCTAssertNil(shell, "precondition: released with the window's root")
    XCTAssertEqual(pans(on: flutterView), 0)
  }

  /// Q4: a selection change expands; re-applying the same one does not.
  func testASelectionChangeExpandsTheBar() throws {
    let tabs = try installedShell(sizeClass: .compact)
    tabs.apply(config(minimize: true))
    let before = tabs.minimizeExpands
    tabs.apply(config(minimize: true))
    XCTAssertEqual(tabs.minimizeExpands, before)
    tabs.apply(config(selected: 1, minimize: true))
    XCTAssertEqual(tabs.minimizeExpands, before + 1)
  }

  /// Task 4 review: Q4's expand is for the ordinary tabs. Entering search
  /// toggles nothing (Q5: search keeps UIKit's own form, spike §3.2, as a
  /// real scroll view does), so the VK-550 scope bar and the keyboard come
  /// and go with the search as before. Leaving search expands.
  func testEnteringSearchTogglesNothingAndLeavesTheScopeBarAndKeyboardAlone() throws {
    let tabs = try installedSearchShell(sizeClass: .compact, scopes: Self.scopes)
    let bar = tabs.searchBridge.controller.searchBar
    let field = bar.searchTextField
    tabs.apply(searchConfig(scopes: Self.scopes, minimize: true))
    let before = tabs.minimizeExpands

    tabs.apply(searchConfig(selected: 2, scopes: Self.scopes, minimize: true))
    XCTAssertEqual(tabs.minimizeExpands, before, "no toggle into search")
    XCTAssertEqual(tabs.tabBarMinimizeBehavior, .onScrollDown)
    XCTAssertFalse(field.isFirstResponder, "entering search raises no keyboard")
    // Dart's activation right after the selection, as a deep link sends it:
    // the search root is not in the window yet, and UIKit refuses the
    // presentation. The bridge keeps it until the root appears (VK-634).
    // Before, the search came only when a focus on the next run-loop turn
    // beat UIKit's layout, about six times in seven. The guard of the
    // product's own sequence; the deterministic test is
    // `testAnActivationBeforeTheSearchRootIsInAWindowIsAppliedOnceItAppears`.
    settle(sending: "searchActive true") {
      tabs.setSearchActive(true)
      // Same turn, the root still in no window: UIKit ran `willPresent`
      // (the scope bar shown) and then refused. `syncScopeBar()` hides it
      // at once, so no scope bar stands on an inactive search (VK-634).
      let bridge = tabs.searchBridge
      XCTAssertTrue(
        bridge.controller.isActive || !bar.showsScopeBar,
        "a refused presentation draws no scope bar")
    }
    XCTAssertTrue(field.isFirstResponder, "the keyboard comes with the search")
    XCTAssertTrue(bar.showsScopeBar)
    let scope = stable { tabs.debugSnapshot().scopeFrame } until: { $0.width > 0 }
    XCTAssertGreaterThan(scope.width, 100, "the scope bar is drawn: \(scope)")

    tabs.apply(searchConfig(scopes: Self.scopes, minimize: true))
    XCTAssertEqual(tabs.minimizeExpands, before + 1, "leaving search expands")
    XCTAssertFalse(stable({ field.isFirstResponder }, until: { !$0 }), "the keyboard went")
  }

  /// Q10: no proxy competes with Flutter for the status-bar tap.
  func testThePageProxyLeavesTheStatusBarTapToFlutter() {
    let page = PageHostController(minimizes: true)
    page.loadViewIfNeeded()
    XCTAssertFalse(page.proxy.scrollsToTop)
    XCTAssertTrue(page.proxy.accessibilityElementsHidden)
  }

  /// Q14 = A′ (owner, acceptance §7): the proxies, the bottom edge's
  /// content scroll views, turn on UIKit's bottom scroll-edge effect. With
  /// minimize on it shows, the native look; with `minimizeOnScroll: false`
  /// every proxy hides it, so the bar looks as before VK-600. Also after a
  /// rebuild (new hosts) and back again.
  func testTheBottomEdgeEffectShowsOnlyWhileTheBarMayMinimize() throws {
    let tabs = try installedShell(sizeClass: .compact)
    for (minimize, trailing) in [(true, false), (false, false), (false, true), (true, true)] {
      tabs.apply(config(trailing: trailing, minimize: minimize))
      for index in [0, 1] {
        let proxy = try XCTUnwrap(tabs.minimizeProxy(ofTab: index))
        XCTAssertEqual(
          proxy.bottomEdgeEffect.isHidden, !minimize,
          "tab \(index), minimize \(minimize), trailing \(trailing)")
      }
    }
  }
}

/// What `attach` reports when no scene of this engine connected after the
/// plugin registered (spec §5.7, §11).
final class InstallerReasonTests: XCTestCase {
  private func installer(
    enabled: Bool = true, flutterViewOnScreen: Bool
  ) -> NativeShellInstaller {
    NativeShellInstaller(
      events: RecordingEvents(),
      ownViewController: { nil },
      ownsFlutter: { _ in true },
      readFacts: { registeredLate, rootIsFlutter in
        InstallFacts(
          osAtLeast26: true, isiOSAppOnMac: false, enabledInInfoPlist: enabled,
          disabledByEnvironment: false, registeredLate: registeredLate,
          rootIsFlutter: rootIsFlutter)
      },
      flutterViewOnScreen: { flutterViewOnScreen })
  }

  private func reason(_ installer: NativeShellInstaller) throws -> NativeUnavailableReason? {
    installer.start()
    defer { installer.stop() }
    return try installer.attach().unavailableReason
  }

  func testAPluginRegisteredAfterItsSceneConnectedReportsRegisteredLate() throws {
    XCTAssertEqual(try reason(installer(flutterViewOnScreen: true)), .registeredLate)
  }

  func testNoSceneOfThisEngineConnectedReportsRootNotFlutter() throws {
    // Add-to-app, or a scene whose root is another engine's view controller.
    XCTAssertEqual(try reason(installer(flutterViewOnScreen: false)), .rootNotFlutter)
  }

  func testAnEarlierFailingFactStillWins() throws {
    XCTAssertEqual(try reason(installer(enabled: false, flutterViewOnScreen: true)), .notEnabled)
  }
}

/// Real Flutter engines in the test host: which engine's scene the
/// installer may claim (spec §5.1 fact 7), and where a Flutter view is
/// already on screen.
@available(iOS 26.0, *)
final class InstallerEngineTests: XCTestCase {
  private var engines: [FlutterEngine] = []
  private var windows: [UIWindow] = []

  override func tearDown() {
    for window in windows {
      window.isHidden = true
      window.rootViewController = nil
    }
    windows = []
    engines.forEach { $0.destroyContext() }
    engines = []
    super.tearDown()
  }

  private func engine(_ name: String) throws -> FlutterEngine {
    let engine = FlutterEngine(name: name, project: nil, allowHeadlessExecution: true)
    XCTAssertTrue(engine.run())
    engines.append(engine)
    return engine
  }

  /// [engine]'s plugin, published under its registrar key as
  /// `register(with:)` does.
  private func publishedPlugin(on engine: FlutterEngine) throws -> LiquidShellPlugin {
    let plugin = LiquidShellPlugin()
    try XCTUnwrap(engine.registrar(forPlugin: LiquidShellPlugin.registrarKey)).publish(plugin)
    return plugin
  }

  private func window(root: UIViewController) throws -> UIWindow {
    let window = try makeSceneWindow(root: root)
    windows.append(window)
    return window
  }

  private func installer(owns: @escaping (UIViewController) -> Bool) -> NativeShellInstaller {
    NativeShellInstaller(
      events: RecordingEvents(),
      // At willConnect the registrar's view controller is still nil.
      ownViewController: { nil },
      ownsFlutter: owns,
      readFacts: { registeredLate, rootIsFlutter in
        InstallFacts(
          osAtLeast26: true, isiOSAppOnMac: false, enabledInInfoPlist: true,
          disabledByEnvironment: false, registeredLate: registeredLate,
          rootIsFlutter: rootIsFlutter)
      },
      flutterViewOnScreen: { false })
  }

  func testOnlyThePluginItsEnginePublishedOwnsAFlutterViewController() throws {
    let app = try engine("app")
    let appPlugin = try publishedPlugin(on: app)
    // A second, headless engine (background work, add-to-app) with its
    // own copy of the plugin.
    let headlessPlugin = try publishedPlugin(on: try engine("headless"))
    let flutter = FlutterViewController(engine: app, nibName: nil, bundle: nil)

    XCTAssertTrue(LiquidShellPlugin.owns(flutter, plugin: appPlugin))
    XCTAssertFalse(LiquidShellPlugin.owns(flutter, plugin: headlessPlugin))
    XCTAssertFalse(LiquidShellPlugin.owns(UIViewController(), plugin: appPlugin))
  }

  func testAHeadlessEnginesInstallerLeavesTheScreenOfAnotherEngineAlone() throws {
    let app = try engine("app")
    let appPlugin = try publishedPlugin(on: app)
    let headlessPlugin = try publishedPlugin(on: try engine("headless"))
    let flutter = FlutterViewController(engine: app, nibName: nil, bundle: nil)
    let window = try window(root: flutter)

    let headless = installer { LiquidShellPlugin.owns($0, plugin: headlessPlugin) }
    headless.connect(window: window, scene: window.windowScene)
    XCTAssertTrue(window.rootViewController === flutter, "not claimed by the headless engine")
    XCTAssertEqual(try headless.attach().installed, false)

    let own = installer { LiquidShellPlugin.owns($0, plugin: appPlugin) }
    own.connect(window: window, scene: window.windowScene)
    XCTAssertTrue(window.rootViewController is ShellContainerController, "claimed by its engine")
  }

  /// A Flutter view inside our container is on screen too: a plugin that
  /// registers after the shell was installed (another engine, a late
  /// registration) must see it.
  func testAFlutterViewInsideTheShellContainerIsOnScreen() throws {
    let flutter = UIViewController()
    let tabs = NativeTabsController(flutter: flutter, events: RecordingEvents())
    let window = try window(root: ShellContainerController(tabs: tabs, flutter: flutter))
    RunLoop.current.run(until: Date().addingTimeInterval(0.2))
    XCTAssertTrue(NativeShellInstaller.isFlutterViewOnScreen(in: [window]))

    let empty = try self.window(root: UIViewController())
    XCTAssertFalse(NativeShellInstaller.isFlutterViewOnScreen(in: [empty]))
  }
}

// MARK: - P3b-1: the search tab

@available(iOS 26.0, *)
extension NativeTabsTests {
  /// Home · Library · [Reports, sidebar only] · Find (search, last).
  fileprivate func searchConfig(
    selected: Int64 = 0, pages: [NativePage] = [], placeholder: String? = nil,
    reports: Bool = false, hidden: Bool = false, interactive: Bool = true,
    scopes: [String]? = nil, minimize: Bool = false
  ) -> NativeChromeConfig {
    var tabs = [
      NativeTab(title: "Home", sfSymbol: "house", sidebarOnly: false, search: false, pages: []),
      NativeTab(
        title: "Library", sfSymbol: "books.vertical", sidebarOnly: false, search: false, pages: []),
    ]
    if reports {
      tabs.append(
        NativeTab(title: "Reports", sfSymbol: "chart.bar", sidebarOnly: true, search: false, pages: []))
    }
    tabs.append(NativeTab(title: "Find", sfSymbol: "", sidebarOnly: false, search: true, pages: pages))
    return NativeChromeConfig(
      engaged: true, tabs: tabs, selectedIndex: selected,
      search: NativeSearchConfig(placeholder: placeholder, scopes: scopes), tintArgb: 0xFF00_7AFF,
      dark: false,
      rtl: false, hidden: hidden, interactive: interactive, minimizeOnScroll: minimize,
      tabBarHidden: false)
  }

  fileprivate func installedSearchShell(
    selected: Int64 = 0, pages: [NativePage] = [], placeholder: String? = nil,
    reports: Bool = false, sizeClass: UIUserInterfaceSizeClass? = nil, scopes: [String]? = nil
  ) throws -> NativeTabsController {
    let flutter = UIViewController()
    let tabs = NativeTabsController(flutter: flutter, events: events)
    let window = try portraitWindow(root: UIViewController())
    let container = ShellContainerController(tabs: tabs, flutter: flutter)
    if let sizeClass { container.traitOverrides.horizontalSizeClass = sizeClass }
    window.rootViewController = container
    self.window = window
    tabs.dartAttached = true
    tabs.apply(
      searchConfig(
        selected: selected, pages: pages, placeholder: placeholder, reports: reports,
        scopes: scopes))
    settle()
    return tabs
  }

  /// Runs [action] and waits until it has sent [message] once more: the
  /// search controller's present and dismiss transitions outlast `settle`
  /// while the keyboard moves (up to 0.7 s on iPhone 27.0). 10 s, the UI
  /// suite's: the CI runner stalls for seconds at a time, and 3 s ran out
  /// on reports that came at 3.0-3.5 s (VK-626). A wait longer than 3 s is
  /// printed, so a report that slows down shows (the test host's stdout,
  /// in the result bundle).
  fileprivate func settle(
    sending message: String, within timeout: TimeInterval = 10, _ action: () -> Void
  ) {
    let count = { self.events.sent.filter { $0 == message }.count }
    let before = count()
    let start = Date()
    action()
    let deadline = start.addingTimeInterval(timeout)
    while count() == before, Date() < deadline {
      RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }
    let waited = Date().timeIntervalSince(start)
    if count() == before {
      XCTFail("no \(message) within \(Int(timeout)) s: \(events.sent)")
    } else if waited > 3 {
      print("NativeTabsTests: \(message) took \(String(format: "%.1f", waited)) s")
    }
    settle()
  }

  /// A user edit typed into the field.
  fileprivate func userTypes(_ text: String, into bridge: SearchBridge) {
    bridge.controller.searchBar.text = text
    bridge.updateSearchResults(for: bridge.controller)
  }

  /// A scene reconnect: the scene goes away (its window and shell are
  /// released), [meanwhile] runs with no shell installed, and the installer
  /// installs a new shell in a new window of the scene, as a reconnect does.
  /// Returns that window.
  fileprivate func reconnect(
    _ installer: NativeShellInstaller, from window: UIWindow, meanwhile: () throws -> Void = {}
  ) throws -> UIWindow {
    installer.sceneDisconnected()
    window.rootViewController = UIViewController()
    settle()
    try meanwhile()

    let scene = try XCTUnwrap(window.windowScene)
    let next = UIWindow(windowScene: scene)
    let flutter = UIViewController()
    next.rootViewController = flutter
    next.isHidden = false
    extraWindows.append(next)
    installer.install(flutter, in: next)
    settle()
    return next
  }

  /// VK-626 (1B): a report that comes late, and comes, counts. The CI
  /// runner stalls for seconds at a time (a test whose longest wait is
  /// 0.5 s took 15-38 s there), and the old 3 s ran out on a report that
  /// came at 3.0-3.5 s. The default is the UI suite's 10 s; a wait over
  /// 3 s is printed.
  func testAReportLaterThanThreeSecondsStillCounts() {
    settle(sending: "searchActive true") {
      DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
        self.events.onSearchActiveChanged(active: true) { _ in }
      }
    }
    XCTAssertEqual(events.sent, ["searchActive true"])
  }

  /// A scene reconnect whose first state report differs from the last one
  /// (spec §7.10): to Dart that is a live size-class change, and it never
  /// sends the user's own text back (the one-way rule). The installer
  /// carries the old field's text to the reinstalled shell instead,
  /// without reporting it as an edit.
  func testASceneReconnectCarriesTheUsersSearchTextToTheNewShell() throws {
    let (installer, window) = try installedByInstaller()
    _ = try installer.attach()
    try installer.update(config: searchConfig(selected: 2))
    settle()
    userTypes("hồ", into: try tabs(in: window).searchBridge)
    let edits = events.searchTexts.count
    let next = try reconnect(installer, from: window)

    let shell = try tabs(in: next)
    XCTAssertTrue(shell.selectedTab === shell.searchTab)
    XCTAssertEqual(shell.searchBridge.text, "hồ")
    XCTAssertEqual(events.searchTexts.count, edits, "not an edit")
  }

  /// Dart's newest text, held while another tab was selected, is the text
  /// to carry: newer than the field's.
  func testASceneReconnectCarriesDartsHeldTextOverTheField() throws {
    let (installer, window) = try installedByInstaller()
    _ = try installer.attach()
    try installer.update(config: searchConfig(selected: 2))
    settle()
    userTypes("hồ", into: try tabs(in: window).searchBridge)
    try installer.update(config: searchConfig(selected: 0))
    settle()
    try installer.setSearchText(text: "hà")
    let next = try reconnect(installer, from: window)
    try installer.update(config: searchConfig(selected: 2))
    settle()

    XCTAssertEqual(try tabs(in: next).searchBridge.text, "hà")
  }

  /// A scene disconnect while a dismissal Dart asked for is running: UIKit
  /// empties the field, and the text to carry is the one the dismissal
  /// keeps, not "" (Task 11 review). Dart text held for a composition is
  /// newer than the field's too.
  func testTheCarriedTextIsDartsNewestDuringADismissalOrAComposition() throws {
    let tabs = try installedSearchShell(selected: 2)
    let bridge = tabs.searchBridge
    tabs.setSearchText("phố")
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    settle(sending: "searchActive false") {
      tabs.setSearchActive(false)
      tabs.setSearchText("hồ")
      XCTAssertEqual(tabs.carriedSearchText, "hồ", "the dismissal's kept text")
    }
    XCTAssertEqual(bridge.text, "hồ", "precondition: the dismissal put it back")

    bridge.isComposing = { true }
    tabs.setSearchText("hà")
    XCTAssertEqual(tabs.carriedSearchText, "hà", "held for the composition")
  }

  func testTheSearchDestinationIsUIKitsSearchTabWithTheAppsTitle() throws {
    let tabs = try installedSearchShell()
    let search = try XCTUnwrap(tabs.searchTab)
    XCTAssertTrue(tabs.tabs.contains { $0 === search })
    XCTAssertEqual(tabs.searchIndex, 2)
    XCTAssertEqual(search.title, "Find", "the app's label")
    XCTAssertEqual(search.image, UIImage(systemName: "magnifyingglass"), "no symbol: the system's")
    XCTAssertFalse(search.automaticallyActivatesSearch, "the video's state 2: not focused")
  }

  func testSelectingTheSearchTabOnlyProposesThenDartSelectsIt() throws {
    let tabs = try installedSearchShell()
    let search = try XCTUnwrap(tabs.searchTab)
    XCTAssertFalse(tabs.tabBarController(tabs, shouldSelectTab: search))
    XCTAssertEqual(events.sent.last, "destination 2")
    XCTAssertFalse(tabs.selectedTab === search, "nothing selected before Dart answers")
    tabs.apply(searchConfig(selected: 2))
    settle()
    XCTAssertTrue(tabs.selectedTab === search)
    XCTAssertTrue(tabs.selectedViewController is ShellNavController)
  }

  func testTheSearchRootOwnsTheSearchControllerAndThePlaceholder() throws {
    let tabs = try installedSearchShell(selected: 2, placeholder: "Songs, places")
    let nav = try XCTUnwrap(tabs.navControllers[2])
    XCTAssertTrue(nav.rootHost.navigationItem.searchController === tabs.searchBridge.controller)
    XCTAssertEqual(tabs.searchBridge.controller.searchBar.placeholder, "Songs, places")
    XCTAssertFalse(tabs.searchBridge.controller.obscuresBackgroundDuringPresentation)
    tabs.apply(searchConfig(selected: 2))
    XCTAssertEqual(
      tabs.searchBridge.controller.searchBar.placeholder, tabs.searchBridge.defaultPlaceholder,
      "no placeholder: the system's")
  }

  func testThePlacementFollowsTheIdiom() throws {
    let tabs = try installedSearchShell(selected: 2)
    let item = try XCTUnwrap(tabs.navControllers[2]).rootHost.navigationItem
    if UIDevice.current.userInterfaceIdiom == .pad {
      XCTAssertEqual(item.preferredSearchBarPlacement, .stacked)
      XCTAssertFalse(item.hidesSearchBarWhenScrolling)
      XCTAssertEqual(item.largeTitleDisplayMode, .never)
    } else {
      XCTAssertEqual(item.preferredSearchBarPlacement, .automatic)
      XCTAssertEqual(item.largeTitleDisplayMode, .inline)
    }
  }

  /// A narrow iPad window: the search root's small title is a leading item,
  /// which UIKit puts right of the window controls, with the stacked field
  /// on the row below (Apple Music). It follows the root's title, and a
  /// regular width (the top tab bar names the tab) has none.
  func testANarrowIPadShowsTheSearchRootsTitleAsALeadingItem() throws {
    try requireIPad()
    let flutter = UIViewController()
    let tabs = NativeTabsController(flutter: flutter, events: events)
    let window = try portraitWindow(root: UIViewController(), width: 375)
    let container = ShellContainerController(tabs: tabs, flutter: flutter)
    window.rootViewController = container
    self.window = window
    tabs.dartAttached = true
    tabs.apply(searchConfig(selected: 2))
    settle()
    let root = try XCTUnwrap(tabs.navControllers[2]).rootHost
    func titleItem() -> String? {
      (root.navigationItem.leftBarButtonItem?.customView as? UILabel)?.text
    }
    XCTAssertEqual(titleItem(), "Find", "no pages: the destination's label")
    tabs.apply(searchConfig(selected: 2, pages: [NativePage(title: "Search")]))
    settle()
    XCTAssertEqual(titleItem(), "Search")
    XCTAssertEqual(root.navigationItem.largeTitleDisplayMode, .never)
    window.frame.size.width = window.windowScene!.coordinateSpace.bounds.width
    settle()
    XCTAssertEqual(tabs.traitCollection.horizontalSizeClass, .regular, "precondition")
    XCTAssertNil(root.navigationItem.leftBarButtonItem, "regular: no title item")
  }

  /// Apple Music's large title shares the bar row with its trailing items,
  /// right under the status bar: UIKit's `.inline` large title. `.always`
  /// puts it on a 52pt row below the bar, about 60pt lower (Task 12).
  func testTheSearchRootsLargeTitleSharesTheBarRow() throws {
    try requirePhone()
    let tabs = try installedSearchShell(selected: 2)
    let nav = try XCTUnwrap(tabs.navControllers[2])
    let item = nav.rootHost.navigationItem
    XCTAssertEqual(item.largeTitleDisplayMode, .inline)
    let height = nav.navigationBar.frame.height
    XCTAssertEqual(
      tabs.flutter.view.safeAreaInsets.top, nav.navigationBar.frame.maxY, accuracy: 0.5,
      "Flutter's content starts right under the bar")
    item.largeTitleDisplayMode = .never
    settle()
    XCTAssertEqual(
      nav.navigationBar.frame.height, height, accuracy: 0.5,
      "as tall as a bar with no large title: no title row under the bar row")
  }

  func testOnlyAnIPhoneOnIOS27MakesTheSearchTabProminent() throws {
    #if compiler(>=6.4)
      guard #available(iOS 27.0, *) else { throw XCTSkip("prominentTabIdentifier is iOS 27 API") }
      let tabs = try installedSearchShell()
      let search = try XCTUnwrap(tabs.searchTab)
      if UIDevice.current.userInterfaceIdiom == .phone {
        XCTAssertEqual(tabs.prominentTabIdentifier, search.identifier)
      } else {
        XCTAssertNil(tabs.prominentTabIdentifier)
      }
    #else
      throw XCTSkip("prominentTabIdentifier needs the iOS 27 SDK")
    #endif
  }

  /// One rule after `setTabs` (probe; VK-426): the trailing action on any
  /// idiom, the search destination on an iPhone only (Q1, Q10), else none.
  /// Each change of shell re-applies it.
  func testTheProminentTabIsOneRuleForTheTrailingActionAndTheSearchTab() throws {
    #if compiler(>=6.4)
      guard #available(iOS 27.0, *) else { throw XCTSkip("prominentTabIdentifier is iOS 27 API") }
      let tabs = try installedSearchShell()
      tabs.apply(config(trailing: true))
      settle()
      let trailing = try XCTUnwrap(tabs.tabs.first as? UISearchTab)
      XCTAssertNil(tabs.searchTab, "precondition: no search destination")
      XCTAssertEqual(tabs.prominentTabIdentifier, trailing.identifier, "trailing: any idiom")
      tabs.apply(config())
      settle()
      XCTAssertNil(tabs.prominentTabIdentifier, "neither")
      tabs.apply(searchConfig())
      settle()
      let search = try XCTUnwrap(tabs.searchTab)
      XCTAssertEqual(
        tabs.prominentTabIdentifier,
        UIDevice.current.userInterfaceIdiom == .phone ? search.identifier : nil)
    #else
      throw XCTSkip("prominentTabIdentifier needs the iOS 27 SDK")
    #endif
  }

  /// Q9: never both. Dart asserts; should both arrive, native keeps the
  /// search destination and drops the trailing action (UIKit gives both
  /// the same identifier).
  func testASearchDestinationDropsATrailingAction() throws {
    let tabs = try installedSearchShell()
    var both = searchConfig()
    both.trailing = NativeAction(title: "Compose", sfSymbol: "square.and.pencil")
    tabs.apply(both)
    settle()
    let search = try XCTUnwrap(tabs.searchTab)
    XCTAssertEqual(tabs.tabs.filter { $0 is UISearchTab }.count, 1)
    XCTAssertTrue(tabs.tabs.contains { $0 === search })
    XCTAssertFalse(tabs.tabBarController(tabs, shouldSelectTab: search))
    XCTAssertEqual(events.sent.last, "destination 2")
    XCTAssertFalse(events.sent.contains("trailing"))
  }

  /// Probe P2 (Q19): with UIKit's default, a page pushed in the search tab
  /// already shows the full bar, without the bottom field.
  func testAPageInTheSearchTabKeepsTheTabBar() {
    XCTAssertFalse(ShellNavController.hidesBarWhenPushed)
  }

  func testDartsTextIsAppliedAndNeverEchoed() throws {
    let tabs = try installedSearchShell(selected: 2)
    let bridge = tabs.searchBridge
    tabs.setSearchText("hồ")
    XCTAssertEqual(bridge.text, "hồ")
    bridge.updateSearchResults(for: bridge.controller)  // UIKit may call back (probe P8)
    XCTAssertFalse(events.sent.contains("searchText hồ"), "Dart's own write is not an edit")
    bridge.controller.searchBar.text = "hồ h"  // the user types
    bridge.updateSearchResults(for: bridge.controller)
    XCTAssertEqual(events.sent.last, "searchText hồ h")
    XCTAssertEqual(events.searchTexts.last?.1, false, "no composition")
  }

  /// UIKit calls back again with the same text when the search presents
  /// and when it dismisses: no change, so no user edit (probe note 2).
  func testPresentingAndDismissingNeverEchoDartsText() throws {
    let tabs = try installedSearchShell(selected: 2)
    tabs.setSearchText("phố")
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    settle(sending: "searchActive false") { tabs.setSearchActive(false) }
    XCTAssertEqual(tabs.searchBridge.text, "phố")
    XCTAssertFalse(events.sent.contains { $0.hasPrefix("searchText") }, "\(events.sent)")
  }

  func testDartsTextWaitsForTheIMECompositionToEnd() throws {
    let tabs = try installedSearchShell(selected: 2)
    let bridge = tabs.searchBridge
    var composing = true
    bridge.isComposing = { composing }
    tabs.setSearchText("ho")
    XCTAssertEqual(bridge.text, "", "never written into a composition")
    XCTAssertEqual(bridge.pendingText, "ho")
    composing = false
    bridge.updateSearchResults(for: bridge.controller)
    XCTAssertEqual(bridge.text, "ho")
    XCTAssertNil(bridge.pendingText)
  }

  func testUserEditsAreReportedOnlyWhileTheSearchTabIsSelected() throws {
    let tabs = try installedSearchShell(selected: 0)
    let bridge = tabs.searchBridge
    bridge.controller.searchBar.text = "x"
    bridge.updateSearchResults(for: bridge.controller)
    XCTAssertFalse(events.sent.contains("searchText x"))
    tabs.apply(searchConfig(selected: 2))
    settle()
    bridge.controller.searchBar.text = "xy"
    bridge.updateSearchResults(for: bridge.controller)
    XCTAssertEqual(events.sent.last, "searchText xy")
    bridge.searchBarSearchButtonClicked(bridge.controller.searchBar)
    XCTAssertEqual(events.sent.last, "searchSubmitted xy")
  }

  func testActivationNeedsTheSearchTabAndADartDismissalKeepsTheText() throws {
    let tabs = try installedSearchShell(selected: 0)
    let bridge = tabs.searchBridge
    tabs.setSearchActive(true)
    settle()
    XCTAssertFalse(bridge.controller.isActive, "not while another tab is selected")
    tabs.apply(searchConfig(selected: 2))
    settle()
    XCTAssertFalse(bridge.controller.isActive, "nor once it is selected (Q13)")
    tabs.setSearchText("hội")
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    XCTAssertTrue(bridge.controller.isActive)
    XCTAssertTrue(events.sent.contains("searchActive true"))
    settle(sending: "searchActive false") { tabs.setSearchActive(false) }
    XCTAssertFalse(bridge.controller.isActive)
    XCTAssertEqual(bridge.text, "hội", "kept (Q2: only × clears)")
    XCTAssertFalse(events.sent.contains("searchText "), "not reported as a user clear")
  }

  func testLeavingTheSearchTabWhileActiveKeepsTheText() throws {
    let tabs = try installedSearchShell(selected: 2)
    let bridge = tabs.searchBridge
    tabs.setSearchText("phố")
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    settle(sending: "searchActive false") { tabs.apply(searchConfig(selected: 0)) }
    XCTAssertFalse(bridge.controller.isActive)
    XCTAssertEqual(bridge.text, "phố")
    XCTAssertFalse(events.sent.contains("searchText "))
  }

  /// VK-551: the chrome hidden (a shell that left sends the dormant
  /// config, a dialog the hidden one) ends an active search, keeping its
  /// text, as any dismissal Dart asks for does. Kept, its field stayed
  /// first responder under the hidden chrome: the keyboard stayed up with
  /// no field and no × to dismiss it.
  func testHiddenChromeEndsAnActiveSearchAndKeepsTheText() throws {
    let dormant = NativeChromeConfig(
      engaged: false, tabs: [], selectedIndex: 0, tintArgb: 0xFF00_7AFF, dark: false,
      rtl: false, hidden: false, interactive: true, minimizeOnScroll: false,
      tabBarHidden: false)
    for (name, hide) in [("dormant", dormant), ("hidden", searchConfig(selected: 2, hidden: true))] {
      let tabs = try installedSearchShell(selected: 2)
      let bridge = tabs.searchBridge
      let field = bridge.controller.searchBar.searchTextField
      tabs.setSearchText("phố")
      settle(sending: "searchActive true") { tabs.setSearchActive(true) }
      XCTAssertTrue(field.isFirstResponder, "\(name): precondition, the keyboard is up")
      settle(sending: "searchActive false") { tabs.apply(hide) }
      XCTAssertFalse(tabs.chromeVisible, name)
      XCTAssertFalse(bridge.controller.isActive, "\(name): the search ended")
      XCTAssertFalse(field.isFirstResponder, "\(name): the keyboard went with it")
      XCTAssertEqual(bridge.text, "phố", "\(name): kept")
      XCTAssertFalse(events.sent.contains("searchText "), "\(name): not a user clear")
      events.sent.removeAll()
    }
  }

  /// VK-551 review I-2: Dart's activation while the chrome is hidden (a
  /// `LiquidHideChrome` page in the search tab, a dialog above the shell)
  /// is ignored: it would present the search in a hidden view, its field
  /// first responder with no field shown to dismiss the keyboard.
  func testAnActivationWhileTheChromeIsHiddenIsIgnored() throws {
    let tabs = try installedSearchShell(selected: 2)
    let bridge = tabs.searchBridge
    tabs.apply(searchConfig(selected: 2, hidden: true))
    settle()
    XCTAssertFalse(tabs.chromeVisible, "precondition")
    tabs.setSearchActive(true)
    let deadline = Date().addingTimeInterval(1.5)
    while Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
    XCTAssertFalse(bridge.controller.isActive, "not presented in hidden chrome")
    XCTAssertFalse(bridge.controller.searchBar.searchTextField.isFirstResponder, "no keyboard")
    XCTAssertFalse(events.sent.contains("searchActive true"))
    // Shown again, the same activation works.
    tabs.apply(searchConfig(selected: 2))
    settle()
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    XCTAssertTrue(bridge.controller.isActive)
  }

  /// VK-571: a drag on the results or a scope tap puts the keyboard away
  /// and keeps the search, as Apple Music and Settings do: the field
  /// resigns first responder, the search stays active with its text and
  /// Cancel. No presentation change, no text write, nothing reported.
  func testDismissingTheSearchKeyboardKeepsTheSearchAndItsText() throws {
    let tabs = try installedSearchShell(selected: 2)
    let bridge = tabs.searchBridge
    let field = bridge.controller.searchBar.searchTextField
    tabs.setSearchText("phố")
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    XCTAssertTrue(field.isFirstResponder, "precondition: the keyboard is up")
    events.sent.removeAll()
    tabs.dismissSearchKeyboard()
    settle()
    XCTAssertFalse(field.isFirstResponder, "the keyboard went")
    XCTAssertTrue(bridge.controller.isActive, "the search stays")
    XCTAssertEqual(bridge.text, "phố", "the query stays")
    XCTAssertEqual(events.sent, [], "nothing to report: \(events.sent)")
    // A tap on the field (Dart's activate) brings the keyboard back.
    tabs.setSearchActive(true)
    settle()
    XCTAssertTrue(field.isFirstResponder)
    XCTAssertTrue(bridge.controller.isActive)
  }

  /// VK-571: resigning commits marked text (UIKit unmarks it); the commit
  /// reaches Dart once, the composed text kept. XCTest cannot type marked
  /// text: the composition is injected.
  func testDismissingTheKeyboardMidCompositionReportsTheCommit() throws {
    let tabs = try installedSearchShell(selected: 2)
    let bridge = tabs.searchBridge
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    var composing = true
    bridge.isComposing = { composing }
    userTypes("phố", into: bridge)
    XCTAssertEqual(events.searchTexts.last?.1, true, "precondition: composing")
    composing = false
    tabs.dismissSearchKeyboard()
    XCTAssertEqual(bridge.text, "phố")
    XCTAssertEqual(events.searchTexts.filter { $0.0 == "phố" && !$0.1 }.count, 1)
    XCTAssertTrue(bridge.controller.isActive)
  }

  /// VK-571: no search tab selected, or no active search: nothing happens.
  func testDismissingTheKeyboardWithoutAnActiveSearchDoesNothing() throws {
    let tabs = try installedSearchShell(selected: 2)
    let bridge = tabs.searchBridge
    tabs.dismissSearchKeyboard()
    settle()
    XCTAssertFalse(bridge.controller.isActive, "never presents")
    XCTAssertEqual(events.sent.filter { $0.hasPrefix("search") }, [])
  }

  /// The last text report Dart got, as "<text> composing=<bool>".
  fileprivate func lastTextReport() -> String {
    events.searchTexts.last.map { "\($0.0) composing=\($0.1)" } ?? "none"
  }

  /// The search active, the user composing "かな" (marked text, injected:
  /// XCTest cannot type it). Returns the tabs and what resigning does to
  /// the marked text: it commits it.
  fileprivate func composingSearch() throws -> (NativeTabsController, commit: () -> Void) {
    let tabs = try installedSearchShell(selected: 2)
    let bridge = tabs.searchBridge
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    var composing = true
    bridge.isComposing = { composing }
    userTypes("かな", into: bridge)
    XCTAssertEqual(lastTextReport(), "かな composing=true", "precondition: Dart heard it")
    return (tabs, { composing = false })
  }

  /// VK-572, native behaviour that stays as it is: a dismissal Dart asks
  /// for mid-composition ends in `searchActive false` with the composed
  /// text kept, and native does not report the commit (`keepOnDismiss`
  /// swallows UIKit's callback, `restoreKept` updates `known` only). Dart
  /// ends `composing` with the search itself (`ShellSearch._endSearch`).
  /// Native reporting the commit one day changes this test and that rule
  /// together.
  func testADeactivateMidCompositionEndsInactiveWithNoCommitReport() throws {
    let (tabs, commit) = try composingSearch()
    settle(sending: "searchActive false") {
      commit()
      tabs.setSearchActive(false)
    }
    XCTAssertFalse(tabs.searchBridge.controller.isActive)
    XCTAssertEqual(tabs.searchBridge.text, "かな", "the composed text is kept")
    XCTAssertEqual(lastTextReport(), "かな composing=true", "sent: \(events.sent)")
  }

  /// VK-572: the same through the user's tab tap (Dart answers with Home).
  /// Native could not report the commit here anyway: the search tab is no
  /// longer selected.
  func testATabChangeMidCompositionEndsInactiveWithNoCommitReport() throws {
    let (tabs, commit) = try composingSearch()
    settle(sending: "searchActive false") {
      commit()
      tabs.apply(searchConfig(selected: 0))
    }
    XCTAssertFalse(tabs.searchBridge.controller.isActive)
    XCTAssertEqual(tabs.searchBridge.text, "かな", "the composed text is kept")
    XCTAssertEqual(lastTextReport(), "かな composing=true", "sent: \(events.sent)")
  }

  /// VK-572 bug B's premise: Dart's deactivate for a native search that is
  /// not active is dropped (`dismissKeepingText` guards on `isActive`):
  /// native never answers it, so Dart ends a search native took over by
  /// itself (`ShellSearch.releaseField`).
  func testDeactivatingAnInactiveSearchSendsNothing() throws {
    let tabs = try installedSearchShell(selected: 2)
    events.sent.removeAll()
    tabs.setSearchActive(false)
    RunLoop.current.run(until: Date().addingTimeInterval(1.5))
    XCTAssertFalse(tabs.searchBridge.controller.isActive)
    XCTAssertEqual(events.sent.filter { $0.hasPrefix("searchActive") }, [])
  }

  /// Q2: the user's × clears the text and dismisses; Dart hears both.
  func testTheCancelButtonClearsTheText() throws {
    let tabs = try installedSearchShell(selected: 2)
    let bridge = tabs.searchBridge
    tabs.setSearchText("phố")
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    XCTAssertTrue(bridge.controller.isActive, "precondition")
    settle(sending: "searchActive false") { bridge.debugCancel() }
    XCTAssertFalse(bridge.controller.isActive)
    XCTAssertEqual(bridge.text, "")
    XCTAssertTrue(events.sent.contains("searchText "), "the user's clear is reported")
    XCTAssertEqual(events.sent.filter { $0.hasPrefix("searchActive") }.last, "searchActive false")
  }

  /// Dart's newest text wins over the text a dismissal keeps.
  func testDartsTextSentDuringADismissalIsTheTextKept() throws {
    let tabs = try installedSearchShell(selected: 2)
    let bridge = tabs.searchBridge
    tabs.setSearchText("phố")
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    settle(sending: "searchActive false") {
      tabs.setSearchActive(false)
      tabs.setSearchText("hồ")
    }
    XCTAssertEqual(bridge.text, "hồ")
    XCTAssertFalse(events.sent.contains { $0.hasPrefix("searchText") }, "Dart's writes only")
  }

  /// A structure change builds a new search root; the one search
  /// controller moves there and leaves the old root.
  func testARebuildMovesTheSearchControllerToTheNewRoot() throws {
    let tabs = try installedSearchShell(selected: 2)
    let old = try XCTUnwrap(tabs.navControllers[2]).rootHost
    tabs.apply(searchConfig(selected: 3, reports: true))
    settle()
    let new = try XCTUnwrap(tabs.navControllers[3]).rootHost
    XCTAssertFalse(new === old, "precondition: rebuilt")
    XCTAssertNil(old.navigationItem.searchController)
    XCTAssertTrue(new.navigationItem.searchController === tabs.searchBridge.controller)
  }

  /// A quick deactivate → activate (a dialog that opens and closes) does
  /// not leave the bridge holding a dismissal: the text is kept, the search
  /// stays active and the user's edits are reported again.
  func testAQuickDeactivateThenActivateKeepsReportingEdits() throws {
    let tabs = try installedSearchShell(selected: 2)
    let bridge = tabs.searchBridge
    tabs.setSearchText("phố")
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    tabs.setSearchActive(false)
    tabs.setSearchActive(true)
    RunLoop.current.run(until: Date().addingTimeInterval(1.5))
    XCTAssertEqual(bridge.text, "phố")
    XCTAssertTrue(bridge.controller.isActive)
    XCTAssertEqual(events.sent.filter { $0.hasPrefix("searchActive") }.last, "searchActive true")
    XCTAssertFalse(events.sent.contains("searchText "), "UIKit's clear is not the user's")
    userTypes("phốc", into: bridge)
    XCTAssertEqual(events.sent.last, "searchText phốc", "\(events.sent)")
  }

  /// A dismissal whose end UIKit never reports must not leave the bridge
  /// mute: the next activation resets the kept text.
  func testAnActivationResetsADismissalThatNeverEnded() throws {
    let tabs = try installedSearchShell(selected: 2)
    let bridge = tabs.searchBridge
    tabs.setSearchText("phố")
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    bridge.controller.delegate = nil  // no `didDismiss`
    tabs.setSearchActive(false)
    RunLoop.current.run(until: Date().addingTimeInterval(1.5))
    bridge.controller.delegate = bridge
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    XCTAssertEqual(bridge.text, "phố")
    userTypes("phốc", into: bridge)
    XCTAssertEqual(events.sent.last, "searchText phốc", "\(events.sent)")
  }

  /// The same, when the user's tap presents the search: UIKit presents it
  /// without Dart's `activate()`, and the bridge must not stay mute
  /// (final review Minor 1).
  func testAUserPresentationResetsADismissalThatNeverEnded() throws {
    let tabs = try installedSearchShell(selected: 2)
    let bridge = tabs.searchBridge
    tabs.setSearchText("phố")
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    bridge.controller.delegate = nil  // no `didDismiss`
    tabs.setSearchActive(false)
    RunLoop.current.run(until: Date().addingTimeInterval(1.5))
    bridge.controller.delegate = bridge
    // The user's tap: UIKit presents the search itself.
    settle(sending: "searchActive true") { bridge.controller.isActive = true }
    XCTAssertEqual(bridge.text, "phố")
    userTypes("phốc", into: bridge)
    XCTAssertEqual(events.sent.last, "searchText phốc", "\(events.sent)")
  }

  /// IMEs with marked text: the user's committed input wins over Dart text
  /// held for the composition; the commit is reported once.
  func testAnIMECommitWinsOverDartsPendingText() throws {
    let tabs = try installedSearchShell(selected: 2)
    let bridge = tabs.searchBridge
    var composing = true
    bridge.isComposing = { composing }
    userTypes("hô", into: bridge)
    tabs.setSearchText("ho")
    XCTAssertEqual(bridge.pendingText, "ho", "precondition: held for the composition")
    composing = false
    bridge.updateSearchResults(for: bridge.controller)
    bridge.updateSearchResults(for: bridge.controller)
    XCTAssertEqual(bridge.text, "hô", "the user's input wins")
    XCTAssertNil(bridge.pendingText)
    XCTAssertEqual(events.searchTexts.filter { $0.0 == "hô" && !$0.1 }.count, 1)
    XCTAssertEqual(events.searchTexts.last?.0, "hô")
  }

  /// Dart text held for a composition is the text a dismissal keeps.
  func testDartsTextHeldForACompositionIsKeptThroughADismissal() throws {
    let tabs = try installedSearchShell(selected: 2)
    let bridge = tabs.searchBridge
    tabs.setSearchText("phố")
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    var composing = true
    bridge.isComposing = { composing }
    tabs.setSearchText("hồ")
    settle(sending: "searchActive false") {
      composing = false
      tabs.setSearchActive(false)
    }
    XCTAssertEqual(bridge.text, "hồ")
    XCTAssertNil(bridge.pendingText)
    XCTAssertFalse(events.sent.contains { $0.hasPrefix("searchText") }, "\(events.sent)")
  }

  /// A structure change while the search is active dismisses it and keeps
  /// the text, as leaving the tab does.
  func testARebuildDuringAnActiveSearchKeepsTheText() throws {
    let tabs = try installedSearchShell(selected: 2)
    let bridge = tabs.searchBridge
    tabs.setSearchText("phố")
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    settle(sending: "searchActive false") { tabs.apply(searchConfig(selected: 3, reports: true)) }
    XCTAssertEqual(bridge.text, "phố")
    XCTAssertFalse(events.sent.contains { $0.hasPrefix("searchText") }, "\(events.sent)")
    userTypes("phốc", into: bridge)
    XCTAssertEqual(events.sent.last, "searchText phốc", "still reporting")
  }

  /// After a rebuild that keeps the search tab selected, iOS 26.5 keeps
  /// reporting a stale `selectedTab`: a later config with the same
  /// selection must not dismiss an active search.
  func testAConfigAfterARebuildKeepsAnActiveSearch() throws {
    let tabs = try installedSearchShell(selected: 2)
    tabs.apply(searchConfig(selected: 3, reports: true))
    settle()
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    events.sent.removeAll()
    tabs.apply(searchConfig(selected: 3, placeholder: "Songs", reports: true))
    settle()
    XCTAssertTrue(tabs.searchBridge.controller.isActive, "\(events.sent)")
    XCTAssertFalse(events.sent.contains("searchActive false"), "\(events.sent)")
  }

  /// Spec §7.4: Dart's text sent before the search tab is selected waits
  /// for the selection.
  func testDartsTextBeforeSelectionWaitsForTheSearchTab() throws {
    let tabs = try installedSearchShell(selected: 0)
    tabs.setSearchText("phố")
    XCTAssertEqual(tabs.searchBridge.text, "", "held until the search tab is selected")
    tabs.apply(searchConfig(selected: 2))
    settle()
    XCTAssertEqual(tabs.searchBridge.text, "phố")
    XCTAssertFalse(events.sent.contains { $0.hasPrefix("searchText") }, "\(events.sent)")
  }

  func testAHiddenSelectionNeverSelectsTheSearchDestination() throws {
    let tabs = try installedSearchShell(selected: 2, reports: true, sizeClass: .compact)
    XCTAssertEqual(tabs.selectedTab?.identifier, "destination0", "Reports is left out; Home, not Find")
    XCTAssertFalse(tabs.selectedTab === tabs.searchTab)
  }

  private func titles(_ nav: ShellNavController) -> [String] {
    nav.viewControllers.map { $0.title ?? "" }
  }

  func testPagesArePushedAndPoppedWithTheirTitles() throws {
    let tabs = try installedSearchShell(selected: 2)
    let nav = try XCTUnwrap(tabs.navControllers[2])
    XCTAssertEqual(titles(nav), ["Find"], "no pages: the destination's label")
    tabs.apply(
      searchConfig(
        selected: 2,
        pages: [NativePage(title: "Search", largeTitle: nil), NativePage(title: "Hồ Hoàn Kiếm")]))
    settle()
    XCTAssertEqual(titles(nav), ["Search", "Hồ Hoàn Kiếm"])
    let top = try XCTUnwrap(nav.topViewController as? PageHostController)
    XCTAssertNotNil(top.navigationItem.backAction, "the back tap is a proposal")
    XCTAssertEqual(top.navigationItem.largeTitleDisplayMode, .never)
    XCTAssertEqual(top.hidesBottomBarWhenPushed, ShellNavController.hidesBarWhenPushed)
    tabs.apply(searchConfig(selected: 2, pages: [NativePage(title: "Search", largeTitle: nil)]))
    settle()
    XCTAssertEqual(titles(nav), ["Search"])
  }

  /// VK-502: a tab's stack applied with the config that selects the tab
  /// is a restore, never animated: the tab was offstage. Either the stack
  /// it kept (nothing to do) or one that changed while it was away (set
  /// without a transition). Nor is one applied as the tab is left. At both
  /// widths on an iPad.
  func testAStackAppliedWithItsTabsSelectionIsNotAnimated() throws {
    let pages = [NativePage(title: "Search"), NativePage(title: "Hồ Hoàn Kiếm")]
    let widths: [UIUserInterfaceSizeClass?] =
      UIDevice.current.userInterfaceIdiom == .pad ? [.regular, .compact] : [nil]
    for width in widths {
      let tabs = try installedSearchShell(selected: 2, pages: pages, sizeClass: width)
      let nav = try XCTUnwrap(tabs.navControllers[2])
      let kept = nav.viewControllers
      tabs.apply(searchConfig(selected: 0, pages: pages))
      settle()
      tabs.apply(searchConfig(selected: 2, pages: pages))
      XCTAssertNil(nav.transitionCoordinator, "kept: no transition (\(String(describing: width)))")
      XCTAssertEqual(nav.viewControllers, kept, "the same hosts")
      settle()

      tabs.apply(searchConfig(selected: 0, pages: [pages[0]]))
      XCTAssertNil(nav.transitionCoordinator, "left with a shorter stack: no pop")
      settle()
      tabs.apply(searchConfig(selected: 2, pages: pages))
      XCTAssertNil(nav.transitionCoordinator, "changed while away: set, not pushed")
      XCTAssertEqual(titles(nav), ["Search", "Hồ Hoàn Kiếm"])
      settle()

      // Away and back before UIKit takes the tab's view out of the window.
      tabs.apply(searchConfig(selected: 0, pages: pages))
      tabs.apply(searchConfig(selected: 2, pages: [pages[0]]))
      XCTAssertNil(nav.transitionCoordinator, "a quick return: set, not popped")
      settle()
    }
  }

  func testTheNativeBackButtonOnlyProposes() throws {
    let tabs = try installedSearchShell(
      selected: 2, pages: [NativePage(title: "Search"), NativePage(title: "Detail")])
    let nav = try XCTUnwrap(tabs.navControllers[2])
    let top = try XCTUnwrap(nav.topViewController as? PageHostController)
    top.onBack?()
    XCTAssertEqual(events.sent.last, "back 2")
    XCTAssertEqual(nav.viewControllers.count, 2, "Dart pops; native follows")
  }

  /// Every pop UIKit starts by itself is a proposal, like the back tap:
  /// the back button's long-press menu (UIKit calls `popToViewController`
  /// from `_tryRequestPopToItem`), a pop (an accessibility escape, a
  /// keyboard back), a pop-to-root (a tab reselect). Native keeps its
  /// stack; Dart pops the Flutter pages and the next config pops here.
  func testEveryUIKitPopIsAProposalForDart() throws {
    let tabs = try installedSearchShell(
      selected: 2,
      pages: [NativePage(title: "Search"), NativePage(title: "A"), NativePage(title: "B")])
    let nav = try XCTUnwrap(tabs.navControllers[2])
    let lastPop = { self.events.sent.last { $0.hasPrefix("popTo") } }
    XCTAssertEqual(nav.popToViewController(nav.viewControllers[0], animated: false) ?? [], [])
    XCTAssertEqual(lastPop(), "popTo 2 0", "the back menu")
    XCTAssertNil(nav.popViewController(animated: false))
    XCTAssertEqual(lastPop(), "popTo 2 1", "a pop")
    XCTAssertEqual(nav.popToRootViewController(animated: false) ?? [], [])
    XCTAssertEqual(lastPop(), "popTo 2 0", "a pop-to-root")
    settle()
    XCTAssertEqual(titles(nav), ["Search", "A", "B"], "Dart pops; native follows")
    // Q14: Flutter owns the swipe; UIKit's own swipes stay off.
    XCTAssertEqual(nav.interactivePopGestureRecognizer?.isEnabled, false)
    XCTAssertEqual(nav.interactiveContentPopGestureRecognizer?.isEnabled, false)
    tabs.apply(searchConfig(selected: 2, pages: [NativePage(title: "Search")]))
    settle()
    XCTAssertEqual(titles(nav), ["Search"], "Dart's shorter stack pops natively")
  }

  func testFlutterKeepsTheTabsFrameAndGetsTheTopPagesInsets() throws {
    let tabs = try installedSearchShell(
      selected: 2, pages: [NativePage(title: "Search"), NativePage(title: "Detail")])
    let root = try XCTUnwrap(tabs.parent?.view)
    let nav = try XCTUnwrap(tabs.navControllers[2])
    let top = try XCTUnwrap(nav.topViewController)
    XCTAssertEqual(tabs.flutter.view.frame, nav.view.convert(nav.view.bounds, to: root))
    XCTAssertEqual(
      tabs.flutter.view.safeAreaInsets.top, top.view.safeAreaInsets.top, accuracy: 0.5,
      "the native bar is Flutter's top padding")
  }

  /// An out-of-line large title (`.always`) collapses under the proxy while
  /// Flutter's top is held. The iPhone search root's `.inline` title sits
  /// on the bar row and moves nothing, and UIKit then shows a pushed page's
  /// title small; an iPad search root that asks for a large title is
  /// `.always`.
  func testTheProxyCollapsesTheLargeTitleWhileFlutterKeepsItsTop() throws {
    try requireIPad()
    let tabs = try installedSearchShell(
      selected: 2, pages: [NativePage(title: "Search", largeTitle: true)])
    let host = try XCTUnwrap(tabs.topHost(ofTab: 2))
    XCTAssertEqual(host.navigationItem.largeTitleDisplayMode, .always, "precondition")
    let restingFlutterTop = tabs.flutter.view.safeAreaInsets.top
    let restingHostTop = host.view.safeAreaInsets.top
    tabs.setPageScroll(tab: 2, offset: 400)
    settle()
    XCTAssertLessThan(host.view.safeAreaInsets.top, restingHostTop - 20, "the title collapsed")
    XCTAssertEqual(
      tabs.flutter.view.safeAreaInsets.top, restingFlutterTop, accuracy: 0.5,
      "held: Flutter's padding does not move under the finger")
    tabs.setPageScroll(tab: 2, offset: 0)
    settle()
    XCTAssertEqual(host.view.safeAreaInsets.top, restingHostTop, accuracy: 0.5)
  }

  /// Spec §7.7: the proxy's base is the top at offset 0 with the search
  /// inactive. A search on a scrolled page (it re-reads the held top on
  /// purpose) must not leave the large title collapsed.
  func testTheLargeTitleReturnsAfterASearchOnAScrolledPage() throws {
    try requirePhone()
    let tabs = try installedSearchShell(selected: 2)
    let host = try XCTUnwrap(tabs.topHost(ofTab: 2))
    let expanded = host.view.safeAreaInsets.top
    tabs.setPageScroll(tab: 2, offset: 400)
    settle()
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    settle(sending: "searchActive false") { tabs.setSearchActive(false) }
    tabs.setPageScroll(tab: 2, offset: 0)
    settle()
    XCTAssertEqual(host.view.safeAreaInsets.top, expanded, accuracy: 0.5, "the large title is back")
  }

  /// The results scrolled while the search is active, then ×: back at 0 the
  /// large title returns.
  func testTheLargeTitleReturnsAfterScrollingTheResultsAndCancelling() throws {
    try requirePhone()
    let tabs = try installedSearchShell(selected: 2)
    let host = try XCTUnwrap(tabs.topHost(ofTab: 2))
    let expanded = host.view.safeAreaInsets.top
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    tabs.setPageScroll(tab: 2, offset: 400)
    settle()
    settle(sending: "searchActive false") { tabs.debugTap(.searchCancel, index: 2) }
    tabs.setPageScroll(tab: 2, offset: 0)
    settle()
    XCTAssertEqual(host.view.safeAreaInsets.top, expanded, accuracy: 0.5, "the large title is back")
  }

  /// Spec §7.9: Flutter is synced once more when a push ends, whatever
  /// changed during the animation.
  func testThePushsCompletionSyncsFlutter() throws {
    let tabs = try installedSearchShell(selected: 2, pages: [NativePage(title: "Search")])
    let nav = try XCTUnwrap(tabs.navControllers[2])
    tabs.apply(
      searchConfig(selected: 2, pages: [NativePage(title: "Search"), NativePage(title: "Detail")]))
    let coordinator = try XCTUnwrap(nav.transitionCoordinator, "an animated push")
    var ended = false
    coordinator.animate(
      alongsideTransition: { _ in
        tabs.flutter.additionalSafeAreaInsets = UIEdgeInsets(top: 300, left: 0, bottom: 0, right: 0)
      }, completion: { _ in ended = true })
    let deadline = Date().addingTimeInterval(3)
    while !ended, Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
    XCTAssertTrue(ended, "the push ended")
    let top = try XCTUnwrap(nav.topViewController)
    XCTAssertEqual(
      tabs.flutter.view.safeAreaInsets.top, top.view.safeAreaInsets.top, accuracy: 0.5,
      "re-synced when the push ended")
  }

  func testTheFieldFrameIsPublishedInFlutterCoordinatesWhileSelected() throws {
    let tabs = try installedSearchShell(selected: 2)
    let frame = try XCTUnwrap(events.fieldFrames.last)
    XCTAssertGreaterThan(frame.width, 100, "the field is on screen")
    XCTAssertGreaterThan(frame.height, 30)
    tabs.apply(searchConfig(selected: 0))
    settle()
    XCTAssertEqual(events.fieldFrames.last?.width, 0, "not selected: zero")
  }

  func testWindowControlsAreZeroUnderTheSearchNavigationBar() throws {
    let tabs = try installedSearchShell(selected: 2, sizeClass: .compact)
    let windowed = NativeWindowControls(leading: 66, top: 44)
    tabs.readWindowControls = { _ in windowed }
    XCTAssertEqual(tabs.windowControls(), NativeWindowControls(leading: 0, top: 0))
    tabs.apply(searchConfig(selected: 0))
    settle()
    XCTAssertEqual(tabs.windowControls(), windowed, "Home has no native bar: the compact read")
  }

  func testInEveryPhaseTheFieldIsNativeAndTheBodyIsFlutters() throws {
    let tabs = try installedSearchShell(selected: 2)
    let root = try XCTUnwrap(tabs.parent?.view)
    func fieldCentre() throws -> CGPoint {
      let field = tabs.searchBridge.controller.searchBar.searchTextField
      XCTAssertNotNil(field.window, "the field is on screen")
      let frame = field.convert(field.bounds, to: root)
      return CGPoint(x: frame.midX, y: frame.midY)
    }
    // Selected: wait until the field is on screen and holds still (a slow
    // runner is still laying the bar out after the install's settle).
    let field = tabs.searchBridge.controller.searchBar.searchTextField
    _ = stable({ field.convert(field.bounds, to: root) }, until: { _ in field.window != nil })
    XCTAssertTrue(isNative(try hit(tabs, try fieldCentre()), tabs), "selected: the field")
    XCTAssertTrue(
      try hit(tabs, CGPoint(x: root.bounds.midX, y: root.bounds.midY)) === tabs.flutter.view,
      "selected: the body")
    // Active: wait for the presentation to end (the iPad's stacked field
    // rises; a slow runner outlasts a fixed settle).
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    XCTAssertTrue(isNative(try hit(tabs, try fieldCentre()), tabs), "active: the field")
    let body = CGPoint(x: root.bounds.midX, y: root.bounds.height * 0.35)
    XCTAssertTrue(try hit(tabs, body) === tabs.flutter.view, "active: the body")
    // Inert under a dialog.
    tabs.apply(searchConfig(selected: 2, interactive: false))
    XCTAssertTrue(try hit(tabs, try fieldCentre()) === tabs.flutter.view, "inert")
  }

  func testAPushedPagesBackButtonIsNative() throws {
    let tabs = try installedSearchShell(
      selected: 2, pages: [NativePage(title: "Search"), NativePage(title: "Detail")])
    let root = try XCTUnwrap(tabs.parent?.view)
    let bar = try XCTUnwrap(tabs.navControllers[2]).navigationBar
    // A slow runner is still laying the bar out after the install: wait until
    // the bar is on screen and holds still, then hit its back button.
    let frame = stable({ bar.convert(bar.bounds, to: root) }, until: { _ in bar.window != nil })
    XCTAssertTrue(isNative(try hit(tabs, CGPoint(x: frame.minX + 38, y: frame.midY)), tabs))
  }

  func testTheDebugSnapshotDescribesTheSearchTab() throws {
    let tabs = try installedSearchShell(
      selected: 2, pages: [NativePage(title: "Search"), NativePage(title: "Detail")])
    tabs.setSearchText("ho")
    let snapshot = tabs.debugSnapshot()
    XCTAssertEqual(snapshot.selectedTab, "destination2")
    XCTAssertEqual(snapshot.searchText, "ho")
    XCTAssertEqual(snapshot.pageTitles, ["Search", "Detail"])
    if UIDevice.current.userInterfaceIdiom == .pad {
      XCTAssertEqual(snapshot.placement, "stacked")
    }
    XCTAssertFalse(snapshot.searchActive)
    XCTAssertEqual(snapshot.scopeTitles, [])
    XCTAssertFalse(snapshot.scopeShown)
  }
}

// MARK: - VK-550: the native scope bar in the shell

@available(iOS 26.0, *)
extension NativeTabsTests {
  fileprivate static let scopes = ["All", "Songs", "Places"]

  /// What UIKit does for a user's scope tap: the segment changes, then the
  /// delegate hears it once, on lift (spike §1).
  fileprivate func userSelectsScope(_ index: Int, in bridge: SearchBridge) {
    bridge.controller.searchBar.selectedScopeButtonIndex = index
    bridge.searchBar(bridge.controller.searchBar, selectedScopeButtonIndexDidChange: index)
  }

  func testTheConfigsScopesReachTheSearchBarAndTheSnapshot() throws {
    let tabs = try installedSearchShell(selected: 2, scopes: Self.scopes)
    let bar = tabs.searchBridge.controller.searchBar
    XCTAssertEqual(bar.scopeButtonTitles, Self.scopes)
    XCTAssertFalse(bar.showsScopeBar, "only while the search is active")
    tabs.apply(searchConfig(selected: 2))
    XCTAssertEqual(bar.scopeButtonTitles ?? [], [], "a config without scopes clears them")
    tabs.apply(searchConfig(selected: 2, scopes: Self.scopes))
    tabs.setSearchScope(1)
    let snapshot = tabs.debugSnapshot()
    XCTAssertEqual(snapshot.scopeTitles, Self.scopes)
    XCTAssertFalse(snapshot.scopeShown)
    XCTAssertEqual(snapshot.selectedScope, 1)
  }

  /// UIKit presents and dismisses the search (the real delegate calls):
  /// the scope bar shows only while the search is active (spike §1). The
  /// debug snapshot gives its frame in the Flutter view (VK-550 Task 11):
  /// at the top on an iPhone, above the field UIKit hosts by the tab bar
  /// (iOS 26); under the risen stacked field on an iPad and on an iPhone
  /// from iOS 27.0. Zero once hidden.
  func testTheScopeBarShowsOnlyWhileTheSearchIsActive() throws {
    let tabs = try installedSearchShell(selected: 2, scopes: Self.scopes)
    let bar = tabs.searchBridge.controller.searchBar
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    XCTAssertTrue(bar.showsScopeBar)
    XCTAssertTrue(tabs.debugSnapshot().scopeShown)
    let scope = stable { tabs.debugSnapshot().scopeFrame } until: { $0.width > 0 }
    let snapshot = tabs.debugSnapshot()
    let field = snapshot.fieldFrame
    XCTAssertGreaterThan(scope.width, 100, "\(scope)")
    XCTAssertGreaterThan(scope.height, 20, "\(scope)")
    // UIKit realises a stacked field on an iPad, and on an iPhone from
    // iOS 27.0 (VK-698: the active field rises to the top there).
    // VK-777: on an iPhone UIKit makes that choice (`SearchMath.style`
    // asks for `.automatic`), so it is pinned per OS: a change in UIKit
    // fails here instead of quietly taking the other branch.
    if UIDevice.current.userInterfaceIdiom == .phone {
      let major = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
      XCTAssertEqual(snapshot.placement, major >= 27 ? "stacked" : "inline", "iOS \(major)")
    }
    if snapshot.placement == "stacked" {
      XCTAssertGreaterThanOrEqual(scope.y, field.y + field.height - 1, "under the field: \(field)")
    } else {
      XCTAssertLessThan(scope.y + scope.height, field.y, "above the field: \(field)")
    }
    settle(sending: "searchActive false") { tabs.setSearchActive(false) }
    XCTAssertFalse(bar.showsScopeBar)
    let hidden = stable { tabs.debugSnapshot().scopeFrame } until: { $0.width == 0 }
    XCTAssertEqual(hidden.width, 0, "hidden: zero")
  }

  func testAUserScopeChangeIsSentToDartOnce() throws {
    let tabs = try installedSearchShell(selected: 2, scopes: Self.scopes)
    let bridge = tabs.searchBridge
    userSelectsScope(1, in: bridge)
    bridge.searchBar(bridge.controller.searchBar, selectedScopeButtonIndexDidChange: 1)
    XCTAssertEqual(events.sent.filter { $0.hasPrefix("searchScope") }, ["searchScope 1"])
  }

  func testDartsScopeIsNeverSentBack() throws {
    let tabs = try installedSearchShell(selected: 2, scopes: Self.scopes)
    let bridge = tabs.searchBridge
    tabs.setSearchScope(2)
    XCTAssertEqual(bridge.controller.searchBar.selectedScopeButtonIndex, 2)
    bridge.searchBar(bridge.controller.searchBar, selectedScopeButtonIndexDidChange: 2)
    XCTAssertEqual(events.sent.filter { $0.hasPrefix("searchScope") }, [])
  }

  /// A user's tap on UIKit's scope bar keeps the keyboard up (measured,
  /// iOS 26.5 iPhone, VK-550 Task 10): the shell puts it away and keeps the
  /// search, as a tap on Flutter's scope bar does (VK-571).
  func testAUserScopeChangePutsTheKeyboardAwayAndKeepsTheSearch() throws {
    let tabs = try installedSearchShell(selected: 2, scopes: Self.scopes)
    let bridge = tabs.searchBridge
    let field = bridge.controller.searchBar.searchTextField
    tabs.setSearchText("phố")
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    XCTAssertTrue(field.isFirstResponder, "precondition: the keyboard is up")
    userSelectsScope(1, in: bridge)
    settle()
    XCTAssertFalse(field.isFirstResponder, "the keyboard went")
    XCTAssertTrue(bridge.controller.isActive, "the search stays")
    XCTAssertTrue(bridge.controller.searchBar.showsScopeBar, "its scope bar too")
    XCTAssertEqual(bridge.text, "phố", "the query stays")
    XCTAssertEqual(events.sent.filter { $0.hasPrefix("searchScope") }, ["searchScope 1"])
    XCTAssertFalse(events.sent.contains("searchActive false"), "\(events.sent)")
  }

  /// As Dart's text: a scope sent while another tab is selected waits for
  /// the search tab.
  func testDartsScopeWaitsForTheSearchTab() throws {
    let tabs = try installedSearchShell(selected: 0, scopes: Self.scopes)
    let bar = tabs.searchBridge.controller.searchBar
    tabs.setSearchScope(2)
    XCTAssertEqual(bar.selectedScopeButtonIndex, 0, "held")
    tabs.apply(searchConfig(selected: 2, scopes: Self.scopes))
    settle()
    XCTAssertEqual(bar.selectedScopeButtonIndex, 2)
    XCTAssertEqual(events.sent.filter { $0.hasPrefix("searchScope") }, [])
  }

  /// The selected scope of [window]'s shell.
  private func selectedScope(in window: UIWindow) throws -> Int {
    try tabs(in: window).searchBridge.controller.searchBar.selectedScopeButtonIndex
  }

  /// A scene reconnect whose first state report differs: Dart sends no
  /// scope after a changed state, since a resend could undo a user's tap
  /// still on its way (Task 10 review M1). The installer carries the old
  /// bar's scope to the reinstalled shell instead, as it carries the text,
  /// and reports nothing.
  func testASceneReconnectCarriesTheUsersScopeToTheNewShell() throws {
    let (installer, window) = try installedByInstaller()
    _ = try installer.attach()
    try installer.update(config: searchConfig(selected: 2, scopes: Self.scopes))
    settle()
    userSelectsScope(2, in: try tabs(in: window).searchBridge)
    let reports = events.sent.filter { $0.hasPrefix("searchScope") }
    XCTAssertEqual(reports, ["searchScope 2"], "precondition: the user's change")
    let next = try reconnect(installer, from: window)
    XCTAssertEqual(try selectedScope(in: next), 2)
    XCTAssertEqual(
      events.sent.filter { $0.hasPrefix("searchScope") }, reports, "not a user change")
  }

  /// Dart's scope held while another tab was selected is newer than the
  /// bar's: it is the one to carry.
  func testASceneReconnectCarriesDartsHeldScopeOverTheBars() throws {
    let (installer, window) = try installedByInstaller()
    _ = try installer.attach()
    try installer.update(config: searchConfig(selected: 2, scopes: Self.scopes))
    settle()
    userSelectsScope(2, in: try tabs(in: window).searchBridge)
    try installer.update(config: searchConfig(selected: 0, scopes: Self.scopes))
    settle()
    try installer.setSearchScope(index: 1)
    let next = try reconnect(installer, from: window)
    try installer.update(config: searchConfig(selected: 2, scopes: Self.scopes))
    settle()
    XCTAssertEqual(try selectedScope(in: next), 1)
  }

  /// Dart's scope sent while no shell is installed (the scene is
  /// reconnecting) reaches the next one: Dart does not send it again after
  /// a changed state report.
  func testDartsScopeSentWhileNoShellIsInstalledReachesTheNextOne() throws {
    let (installer, window) = try installedByInstaller()
    _ = try installer.attach()
    try installer.update(config: searchConfig(selected: 2, scopes: Self.scopes))
    settle()
    let next = try reconnect(installer, from: window) {
      try installer.setSearchScope(index: 2)
    }
    XCTAssertEqual(try selectedScope(in: next), 2)
    XCTAssertEqual(events.sent.filter { $0.hasPrefix("searchScope") }, [])
  }
}

// MARK: - VK-634: an activation before the search root is in a window

@available(iOS 26.0, *)
extension NativeTabsTests {
  /// A search shell with Dart's config applied (the search tab selected)
  /// but in no window yet: its search root is provably in none, so UIKit
  /// refuses a presentation there ("not in the window hierarchy"), as it
  /// does for a deep link that lands before the selected tab's view is
  /// installed. Held as long as the test likes; the product's own sequence
  /// (the root installed a layout pass later) is the guard,
  /// `testEnteringSearchTogglesNothingAndLeavesTheScopeBarAndKeyboardAlone`.
  fileprivate func unshownSearchShell(
    scopes: [String]? = nil
  ) throws -> (NativeTabsController, ShellContainerController) {
    let flutter = UIViewController()
    let tabs = NativeTabsController(flutter: flutter, events: events)
    let container = ShellContainerController(tabs: tabs, flutter: flutter)
    tabs.dartAttached = true
    tabs.apply(searchConfig(selected: 2, scopes: scopes))
    let nav = try XCTUnwrap(tabs.navControllers[2])
    XCTAssertTrue(tabs.selectedViewController === nav, "precondition: the search tab is selected")
    XCTAssertTrue(tabs.chromeVisible, "precondition: the chrome is shown")
    XCTAssertNil(nav.rootHost.view.window, "precondition: the search root is in no window")
    return (tabs, container)
  }

  /// Puts [container] in [window] and applies [config] again, as
  /// `NativeShellInstaller.install` does: the search root appears.
  fileprivate func showShell(
    _ container: ShellContainerController, in window: UIWindow, config: NativeChromeConfig
  ) {
    window.rootViewController = container
    container.tabs.apply(config)
  }

  /// VK-634: Dart's activation while the search root is in no window (a
  /// deep link right after the selection) is refused by UIKit. It is kept,
  /// with no scope bar on the inactive search, and applied once the root
  /// appears: the search presents, the keyboard comes, Dart hears it once.
  func testAnActivationBeforeTheSearchRootIsInAWindowIsAppliedOnceItAppears() throws {
    let config = searchConfig(selected: 2, scopes: Self.scopes)
    let (tabs, container) = try unshownSearchShell(scopes: Self.scopes)
    let bridge = tabs.searchBridge
    let bar = bridge.controller.searchBar
    let field = bar.searchTextField

    tabs.setSearchActive(true)
    // The next run-loop turns pass with the root still in no window.
    RunLoop.current.run(until: Date().addingTimeInterval(1))
    XCTAssertFalse(bridge.controller.isActive, "UIKit refused: no window")
    XCTAssertFalse(bar.showsScopeBar, "a refused presentation draws no scope bar")
    XCTAssertFalse(field.isFirstResponder, "no keyboard yet")
    XCTAssertFalse(events.sent.contains("searchActive true"), "\(events.sent)")

    let window = try portraitWindow(root: UIViewController())
    extraWindows.append(window)
    settle(sending: "searchActive true") { showShell(container, in: window, config: config) }
    XCTAssertTrue(bridge.controller.isActive, "applied once the root appeared")
    XCTAssertTrue(field.isFirstResponder, "the keyboard comes with the search")
    XCTAssertTrue(bar.showsScopeBar, "the scope bar comes with it")
    XCTAssertEqual(events.sent.filter { $0.hasPrefix("searchActive") }, ["searchActive true"])
  }

  /// VK-634: a kept activation is Dart's to take back. Each of these ends
  /// it: Dart's deactivate; another tab (for one config); hidden chrome
  /// (VK-551); a presentation that already came (UIKit's own, as for the
  /// user's tap); a page pushed over the search root (the owner's choice,
  /// 2026-10-16). Once the root appears, nothing presents, nothing takes
  /// the keyboard, and Dart hears nothing.
  func testAKeptActivationEndsWithADeactivateALeaveHiddenChromeOrAPresentation() throws {
    let shown = searchConfig(selected: 2)
    let ends: [(String, (NativeTabsController) -> Void)] = [
      ("deactivate", { $0.setSearchActive(false) }),
      (
        "another tab",
        { tabs in
          tabs.apply(self.searchConfig(selected: 0))
          tabs.apply(shown)
        }
      ),
      (
        "hidden chrome",
        { tabs in
          tabs.apply(self.searchConfig(selected: 2, hidden: true))
          tabs.apply(shown)
        }
      ),
      (
        "a presentation",
        { tabs in
          tabs.searchBridge.willPresentSearchController(tabs.searchBridge.controller)
        }
      ),
      (
        "a push",
        { tabs in
          tabs.apply(
            self.searchConfig(
              selected: 2, pages: [NativePage(title: "Find"), NativePage(title: "Detail")]))
        }
      ),
    ]
    for (name, end) in ends {
      let (tabs, container) = try unshownSearchShell()
      let bridge = tabs.searchBridge
      tabs.setSearchActive(true)
      RunLoop.current.run(until: Date().addingTimeInterval(0.5))
      XCTAssertFalse(bridge.controller.isActive, "\(name): precondition, refused")
      end(tabs)
      let window = try portraitWindow(root: UIViewController())
      extraWindows.append(window)
      showShell(container, in: window, config: shown)
      RunLoop.current.run(until: Date().addingTimeInterval(2))
      XCTAssertFalse(bridge.controller.isActive, "\(name): nothing presents")
      XCTAssertFalse(
        bridge.controller.searchBar.searchTextField.isFirstResponder, "\(name): no keyboard")
      XCTAssertFalse(events.sent.contains("searchActive true"), "\(name): \(events.sent)")
      window.isHidden = true
      window.rootViewController = nil
      events.sent.removeAll()
    }
  }

  /// VK-634, the owner's choice (2026-10-16): a page pushed over the search
  /// root keeps no activation. Dart's activation while the page covers the
  /// root is refused by UIKit and dropped, as before the fix: no scope bar,
  /// and the pop back to the root brings no search, no keyboard and no
  /// report. A deep link pops to the root and activates at once: the root
  /// is the top of the stack again, so that activation is kept until the
  /// root appears, and the search comes.
  func testAnActivationOverAPushedPageIsDroppedAndOneRightAfterThePopIsApplied() throws {
    let root = [NativePage(title: "Find")]
    let pushed = root + [NativePage(title: "Detail")]
    let tabs = try installedSearchShell(selected: 2, pages: pushed, scopes: Self.scopes)
    let bridge = tabs.searchBridge
    let bar = bridge.controller.searchBar
    let field = bar.searchTextField
    let nav = try XCTUnwrap(tabs.navControllers[2])
    let config = { (pages: [NativePage]) in
      self.searchConfig(selected: 2, pages: pages, scopes: Self.scopes)
    }

    // A deep link: pop to the root, then activate at once.
    settle(sending: "searchActive true") {
      tabs.apply(config(root))
      tabs.setSearchActive(true)
    }
    // Refused while the pop runs, applied by the root's `viewDidAppear`.
    // The keyboard is not asserted: after an animated pop the field does
    // not take it, before VK-634 as after (probed 5 of 5, iOS 26.5).
    XCTAssertTrue(bridge.controller.isActive, "after the pop: the search came")
    XCTAssertTrue(bar.showsScopeBar, "the scope bar comes with it")
    settle(sending: "searchActive false") { tabs.setSearchActive(false) }

    // Over a pushed page: refused, and dropped.
    tabs.apply(config(pushed))
    XCTAssertTrue(
      stable({ nav.rootHost.viewIfLoaded?.window == nil }, until: { $0 }),
      "precondition: the page covers the search root")
    events.sent.removeAll()
    tabs.setSearchActive(true)
    RunLoop.current.run(until: Date().addingTimeInterval(1))
    XCTAssertFalse(bridge.controller.isActive, "precondition: UIKit refused over the page")
    XCTAssertFalse(bar.showsScopeBar, "a refused presentation draws no scope bar")
    tabs.apply(config(root))
    XCTAssertTrue(
      stable(
        { nav.rootHost.viewIfLoaded?.window != nil && nav.transitionCoordinator == nil },
        until: { $0 }),
      "precondition: back on the search root, the pop finished")
    RunLoop.current.run(until: Date().addingTimeInterval(1))
    XCTAssertFalse(bridge.controller.isActive, "dropped: the pop brings no search")
    XCTAssertFalse(field.isFirstResponder, "dropped: no keyboard")
    XCTAssertFalse(events.sent.contains("searchActive true"), "dropped: \(events.sent)")
  }

  /// VK-634: a refused activation is kept only while the search tab is
  /// selected and the chrome shown. `didDismiss`'s deferred `activate()`
  /// runs a turn later and does not look again: if Dart left the search tab
  /// in between, nothing is kept, and selecting the tab later brings no
  /// search, no keyboard and no report.
  func testAnActivationRefusedAfterLeavingTheSearchTabIsNotKept() throws {
    let (tabs, container) = try unshownSearchShell(scopes: Self.scopes)
    let bridge = tabs.searchBridge
    let bar = bridge.controller.searchBar

    tabs.apply(searchConfig(selected: 0, scopes: Self.scopes))
    bridge.activate()
    XCTAssertFalse(bridge.activationPending, "not kept: the search tab is not selected")

    let window = try portraitWindow(root: UIViewController())
    extraWindows.append(window)
    showShell(container, in: window, config: searchConfig(selected: 2, scopes: Self.scopes))
    RunLoop.current.run(until: Date().addingTimeInterval(2))
    XCTAssertFalse(bridge.controller.isActive, "nothing presents")
    XCTAssertFalse(bridge.activationPending, "nothing is pending")
    XCTAssertFalse(bar.searchTextField.isFirstResponder, "no keyboard")
    XCTAssertFalse(bar.showsScopeBar, "no scope bar")
    XCTAssertFalse(events.sent.contains("searchActive true"), "\(events.sent)")
  }
}

// MARK: - P3b-2: a navigation controller on every tab (spec P3b-2 §6.1, §6.8)

@available(iOS 26.0, *)
extension NativeTabsTests {
  /// [config()] with [home] as Home's pages (root first); Inbox has none.
  fileprivate func pagesConfig(
    _ home: [NativePage], selected: Int64 = 0, minimize: Bool = false,
    tabBarHidden: Bool = false
  ) -> NativeChromeConfig {
    var result = config(selected: selected, minimize: minimize)
    result.tabs[0].pages = home
    result.tabBarHidden = tabBarHidden
    return result
  }

  func testEveryDestinationTabIsANavigationController() throws {
    let tabs = try installedShell()
    for index in [0, 1] {
      let nav = try XCTUnwrap(tabs.navControllers[index], "tab \(index)")
      XCTAssertEqual(nav.viewControllers.count, 1, "its root, built with the tabs")
    }
    XCTAssertTrue(tabs.selectedViewController === tabs.navControllers[0])
  }

  func testATabWithoutPagesHidesItsNavigationBar() throws {
    let tabs = try installedShell()
    for index in [0, 1] {
      let nav = try XCTUnwrap(tabs.navControllers[index], "tab \(index)")
      XCTAssertTrue(nav.isNavigationBarHidden, "tab \(index): no LiquidPage, no bar")
    }
    let page = try XCTUnwrap(tabs.topHost(ofTab: 0)?.view)
    XCTAssertEqual(
      tabs.flutter.view.safeAreaInsets.top, page.safeAreaInsets.top, accuracy: 0.5,
      "Flutter's top has no bar in it")
  }

  /// The title table's plain-tab rows on the real tree (spec P3b-2 §4.2):
  /// a root with no title row hides the bar, a push shows it with the back
  /// circle, the pop hides it again; `null` is on the bar row at compact
  /// width only; `true` is the collapsing row.
  func testAnInlineRootHidesTheBarAndAPushShowsIt() throws {
    let tabs = try installedShell()
    let nav = try XCTUnwrap(tabs.navControllers[0])
    let compact = tabs.isCompact
    tabs.apply(pagesConfig([NativePage(title: "Home", largeTitle: false)]))
    settle()
    XCTAssertTrue(nav.isNavigationBarHidden, "a root with no title row")
    tabs.apply(
      pagesConfig([NativePage(title: "Home", largeTitle: false), NativePage(title: "Detail")]))
    settle()
    XCTAssertFalse(nav.isNavigationBarHidden, "a pushed page shows the bar")
    let top = try XCTUnwrap(nav.topViewController)
    XCTAssertEqual(top.title, "Detail")
    XCTAssertEqual(top.navigationItem.largeTitleDisplayMode, .never, "pushed: inline")
    XCTAssertNotNil(top.navigationItem.backAction, "the back circle proposes")
    tabs.apply(pagesConfig([NativePage(title: "Home", largeTitle: false)]))
    settle()
    XCTAssertTrue(nav.isNavigationBarHidden, "popped back to the root")
    tabs.apply(pagesConfig([NativePage(title: "Home")]))
    settle()
    XCTAssertEqual(nav.isNavigationBarHidden, !compact, "null: the bar row at compact width")
    XCTAssertEqual(nav.rootHost.navigationItem.largeTitleDisplayMode, compact ? .inline : .never)
    tabs.apply(pagesConfig([NativePage(title: "Home", largeTitle: true)]))
    settle()
    XCTAssertFalse(nav.isNavigationBarHidden)
    XCTAssertEqual(nav.rootHost.navigationItem.largeTitleDisplayMode, .always)
  }

  /// Spec P3b-2 §6.8: the pan and Dart's offset follow the selected tab's
  /// top page, pushed pages included.
  func testMinimizeFollowsTheTopPageOfAnyTab() throws {
    let tabs = try installedShell(sizeClass: .compact)
    tabs.apply(pagesConfig([NativePage(title: "Home")], minimize: true))
    settle()
    let nav = try XCTUnwrap(tabs.navControllers[0])
    let root = try XCTUnwrap(nav.rootHost.minimizeProxy)
    XCTAssertTrue(tabs.attachedMinimizeProxy === root, "the root page's")
    tabs.apply(
      pagesConfig([NativePage(title: "Home"), NativePage(title: "Detail")], minimize: true))
    settle()
    let pushed = try XCTUnwrap(tabs.minimizeProxy(ofTab: 0))
    XCTAssertFalse(pushed === root, "a pushed page has its own")
    XCTAssertTrue(nav.topViewController?.contentScrollView(for: .bottom) === pushed)
    XCTAssertTrue(tabs.attachedMinimizeProxy === pushed, "the pan moved to the pushed page")
    XCTAssertEqual(pans(on: tabs.flutter.view), 1)
    tabs.setMinimizeScroll(tab: 0, offset: 320)
    XCTAssertEqual(pushed.offset, 320, "Dart's offset reaches the top page")
    XCTAssertEqual(root.offset, 0)
    tabs.apply(
      pagesConfig([NativePage(title: "Home"), NativePage(title: "Detail")], minimize: false))
    XCTAssertTrue(pushed.bottomEdgeEffect.isHidden, "the edge policy reaches pushed pages")
    XCTAssertTrue(root.bottomEdgeEffect.isHidden)
  }

  func testTheRootHostKeepsItsMinimizeProxyThroughAPushAndAPop() throws {
    let tabs = try installedShell(sizeClass: .compact)
    tabs.apply(pagesConfig([NativePage(title: "Home")], minimize: true))
    let nav = try XCTUnwrap(tabs.navControllers[0])
    let host = nav.rootHost
    let proxy = try XCTUnwrap(host.minimizeProxy)
    tabs.apply(
      pagesConfig([NativePage(title: "Home"), NativePage(title: "Detail")], minimize: true))
    settle()
    tabs.apply(pagesConfig([NativePage(title: "Home")], minimize: true))
    settle()
    XCTAssertTrue(tabs.navControllers[0] === nav, "no rebuild")
    XCTAssertTrue(nav.rootHost === host)
    XCTAssertTrue(tabs.minimizeProxy(ofTab: 0) === proxy)
    XCTAssertTrue(tabs.attachedMinimizeProxy === proxy, "the pan is back on the root's")
  }

  func testAPoppedHostGivesItsPanBack() throws {
    let tabs = try installedShell(sizeClass: .compact)
    weak var popped: MinimizeProxy?
    autoreleasepool {
      tabs.apply(
        pagesConfig([NativePage(title: "Home"), NativePage(title: "Detail")], minimize: true))
      settle()
      popped = tabs.minimizeProxy(ofTab: 0)
      XCTAssertTrue(tabs.attachedMinimizeProxy === popped, "precondition: the pushed page's")
      tabs.apply(pagesConfig([NativePage(title: "Home")], minimize: true))
      settle()
    }
    settle()
    XCTAssertEqual(pans(on: tabs.flutter.view), 1, "only the root's")
    XCTAssertTrue(tabs.attachedMinimizeProxy === tabs.navControllers[0]?.rootHost.minimizeProxy)
    if let popped {
      XCTAssertTrue(
        popped.gestureRecognizers?.contains(popped.panGestureRecognizer) ?? false, "given back")
    }
  }

  /// Spec P3b-2 §6.1: under the compact bar the cluster is real while the
  /// selected tab's navigation bar is hidden, zero while it shows.
  func testWindowControlsAreRealUnderAHiddenBarAndZeroUnderAShownOne() throws {
    let tabs = try installedShell(sizeClass: .compact)
    let windowed = NativeWindowControls(leading: 66, top: 44)
    tabs.readWindowControls = { _ in windowed }
    XCTAssertEqual(tabs.windowControls(), windowed, "no pages: the bar is hidden")
    tabs.apply(pagesConfig([NativePage(title: "Home"), NativePage(title: "Detail")]))
    settle()
    XCTAssertEqual(tabs.windowControls(), NativeWindowControls(leading: 0, top: 0), "it shows")
  }
}

// MARK: - P3b-2: size classes and the hidden bar (spec P3b-2 §6.1)

@available(iOS 26.0, *)
extension NativeTabsTests {
  /// Spec P3b-2 §6.1: a window crossing compact/regular re-applies the
  /// title modes and the bar at once, without a config from Dart.
  func testASizeClassChangeReappliesTheTitleModes() throws {
    try requireIPad()
    let tabs = try installedShell(sizeClass: .regular)
    let container = try XCTUnwrap(tabs.parent)
    tabs.apply(pagesConfig([NativePage(title: "Home")]))
    settle()
    let nav = try XCTUnwrap(tabs.navControllers[0])
    XCTAssertTrue(nav.isNavigationBarHidden, "regular: no title row")
    container.traitOverrides.horizontalSizeClass = .compact
    settle()
    XCTAssertFalse(nav.isNavigationBarHidden, "compact: the large title on the bar row")
    XCTAssertEqual(nav.rootHost.navigationItem.largeTitleDisplayMode, .inline)
    container.traitOverrides.horizontalSizeClass = .regular
    settle()
    XCTAssertTrue(nav.isNavigationBarHidden, "regular again")
    XCTAssertEqual(nav.rootHost.navigationItem.largeTitleDisplayMode, .never)
  }

  /// A native swipe-back shortens the stack before Dart confirms the pop; a
  /// size-class change then rebuilds the missing host, which must follow the
  /// edge policy like the others (VK-441).
  func testASizeClassReapplyHidesTheBottomEdgeEffectOnNewHosts() throws {
    try requireIPad()
    let tabs = try installedShell(sizeClass: .regular)
    let container = try XCTUnwrap(tabs.parent)
    tabs.apply(
      pagesConfig([NativePage(title: "Home"), NativePage(title: "Detail")], minimize: false))
    settle()
    let nav = try XCTUnwrap(tabs.navControllers[0])
    nav.setViewControllers([nav.rootHost], animated: false)  // the swipe's pop
    XCTAssertEqual(nav.hosts.count, 1, "precondition: shorter than the config")
    container.traitOverrides.horizontalSizeClass = .compact
    settle()
    XCTAssertEqual(nav.hosts.count, 2, "the trait handler rebuilt the host")
    for host in nav.hosts {
      XCTAssertTrue(host.minimizeProxy?.bottomEdgeEffect.isHidden ?? false, "every host's")
    }
  }

  /// Spec P3b-2 §6.1: a hidden bar is not hit; its band reaches Flutter.
  func testTheBodyUnderAHiddenNavigationBarReachesFlutter() throws {
    let tabs = try installedShell(sizeClass: .compact)
    let root = try XCTUnwrap(tabs.parent?.view)
    let nav = try XCTUnwrap(tabs.navControllers[0])
    XCTAssertTrue(nav.isNavigationBarHidden, "precondition: no pages")
    let top = root.safeAreaInsets.top
    XCTAssertTrue(
      try hit(tabs, CGPoint(x: root.bounds.midX, y: top + 22)) === tabs.flutter.view,
      "where the title would be")
    XCTAssertTrue(
      try hit(tabs, CGPoint(x: 30, y: top + 22)) === tabs.flutter.view,
      "where the back circle would be")
  }
}

// MARK: - P3b-2: the tab bar hidden for a page (spec P3b-2 §4.4, §6.6)

@available(iOS 26.0, *)
extension NativeTabsTests {
  /// The tab bar hides, the navigation bar stays; Flutter gets the top
  /// page's insets, the band where the tab bar was, no minimize pan and
  /// no window controls (the navigation bar clears them).
  func testTabBarHiddenKeepsTheNavigationBar() throws {
    let tabs = try installedShell(sizeClass: .compact)
    let pages = [NativePage(title: "Home"), NativePage(title: "Photo")]
    tabs.apply(pagesConfig(pages, minimize: true))
    settle()
    let nav = try XCTUnwrap(tabs.navControllers[0])
    let root = try XCTUnwrap(tabs.parent?.view)
    let inbox = try centreOfLabel("Inbox", in: tabs.view, tabs)
    XCTAssertNotNil(tabs.attachedMinimizeProxy, "precondition: the pan")
    tabs.readWindowControls = { _ in NativeWindowControls(leading: 66, top: 44) }

    tabs.apply(pagesConfig(pages, minimize: true, tabBarHidden: true))
    settle()
    XCTAssertTrue(tabs.isTabBarHidden)
    XCTAssertTrue(tabs.chromeVisible, "only the tab bar hides")
    XCTAssertFalse(nav.isNavigationBarHidden, "the page keeps its bar")
    let page = try XCTUnwrap(nav.topViewController?.view)
    XCTAssertEqual(
      tabs.flutter.view.safeAreaInsets.bottom, root.safeAreaInsets.bottom, accuracy: 1,
      "the home indicator")
    XCTAssertEqual(tabs.flutter.view.safeAreaInsets.top, page.safeAreaInsets.top, accuracy: 0.5)
    XCTAssertTrue(try hit(tabs, inbox) === tabs.flutter.view, "where the tab bar was")
    XCTAssertNil(tabs.attachedMinimizeProxy, "no minimize under a hidden tab bar")
    XCTAssertEqual(tabs.windowControls(), NativeWindowControls(leading: 0, top: 0))

    tabs.apply(pagesConfig(pages, minimize: true))
    settle()
    XCTAssertFalse(tabs.isTabBarHidden, "the request ended")
    XCTAssertNotNil(tabs.attachedMinimizeProxy)
  }

  func testTabBarHiddenPutsATiledSidebarBack() throws {
    try requireIPad()
    let tabs = try installedShell(landscape: true)
    openSidebar(tabs)
    XCTAssertEqual(tabs.currentState().sidebar, .tiled, "precondition: a landscape iPad tiles")
    let pages = [NativePage(title: "Home"), NativePage(title: "Photo")]
    tabs.apply(pagesConfig(pages))
    settle()
    let tiledLeft = tabs.flutter.view.safeAreaInsets.left
    XCTAssertGreaterThan(tiledLeft, 200, "precondition: the sidebar's width")
    tabs.apply(pagesConfig(pages, tabBarHidden: true))
    settle()
    XCTAssertTrue(tabs.sidebar.isHidden, "the sidebar hides with the tab bar")
    XCTAssertEqual(tabs.flutter.view.safeAreaInsets.left, 0, accuracy: 0.5)
    tabs.setSidebarVisible(true)
    XCTAssertTrue(tabs.sidebar.isHidden, "Dart cannot open it meanwhile")
    tabs.apply(pagesConfig(pages))
    _ = stable({ tabs.flutter.view.safeAreaInsets.left }, until: { $0 > 200 })
    XCTAssertEqual(tabs.currentState().sidebar, .tiled, "tiled again")
    XCTAssertEqual(tabs.flutter.view.safeAreaInsets.left, tiledLeft, accuracy: 0.5)
  }

  /// Hidden at regular width, shown while compact (Split View, Stage
  /// Manager): back at regular width, the tiled sidebar is still there.
  func testATiledSidebarHiddenWithTheTabBarSurvivesACompactShow() throws {
    try requireIPad()
    let tabs = try installedShell(landscape: true)
    let container = try XCTUnwrap(tabs.parent)
    openSidebar(tabs)
    XCTAssertEqual(tabs.currentState().sidebar, .tiled, "precondition: a landscape iPad tiles")
    let pages = [NativePage(title: "Home"), NativePage(title: "Photo")]
    tabs.apply(pagesConfig(pages))
    settle()
    let tiledLeft = tabs.flutter.view.safeAreaInsets.left
    tabs.apply(pagesConfig(pages, tabBarHidden: true))
    settle()
    XCTAssertTrue(tabs.sidebar.isHidden, "precondition: hidden with the tab bar")
    container.traitOverrides.horizontalSizeClass = .compact
    settle()
    tabs.apply(pagesConfig(pages))
    settle()
    container.traitOverrides.horizontalSizeClass = .regular
    let left = stable({ tabs.flutter.view.safeAreaInsets.left }, until: { $0 > 200 })
    XCTAssertEqual(tabs.currentState().sidebar, .tiled, "tiled again")
    XCTAssertEqual(left, tiledLeft, accuracy: 0.5)
  }

  /// Hidden while compact, back to regular width before the request ends:
  /// the tiled sidebar does not show under the hidden tab bar, and comes
  /// back when the request ends.
  func testATiledSidebarStaysHiddenWhenTheWindowWidensDuringTheRequest() throws {
    try requireIPad()
    let tabs = try installedShell(landscape: true)
    let container = try XCTUnwrap(tabs.parent)
    openSidebar(tabs)
    XCTAssertEqual(tabs.currentState().sidebar, .tiled, "precondition: a landscape iPad tiles")
    let pages = [NativePage(title: "Home"), NativePage(title: "Photo")]
    tabs.apply(pagesConfig(pages))
    settle()
    let tiledLeft = tabs.flutter.view.safeAreaInsets.left
    container.traitOverrides.horizontalSizeClass = .compact
    settle()
    tabs.apply(pagesConfig(pages, tabBarHidden: true))
    settle()
    container.traitOverrides.horizontalSizeClass = .regular
    let hiddenLeft = stable({ tabs.flutter.view.safeAreaInsets.left })
    XCTAssertTrue(tabs.sidebar.isHidden, "not under the hidden tab bar")
    XCTAssertEqual(hiddenLeft, 0, accuracy: 0.5)
    tabs.apply(pagesConfig(pages))
    let left = stable({ tabs.flutter.view.safeAreaInsets.left }, until: { $0 > 200 })
    XCTAssertEqual(tabs.currentState().sidebar, .tiled, "tiled again")
    XCTAssertEqual(left, tiledLeft, accuracy: 0.5)
  }

  func testTabBarHiddenDismissesAnActiveSearchKeepingItsText() throws {
    let tabs = try installedSearchShell(selected: 2)
    let bridge = tabs.searchBridge
    tabs.setSearchText("phố")
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    var hiding = searchConfig(selected: 2, pages: [NativePage(title: "Search")])
    hiding.tabBarHidden = true
    settle(sending: "searchActive false") { tabs.apply(hiding) }
    XCTAssertTrue(tabs.isTabBarHidden)
    XCTAssertTrue(tabs.chromeVisible)
    XCTAssertFalse(bridge.controller.isActive, "the search ended")
    XCTAssertEqual(bridge.text, "phố", "kept")
  }
}

// MARK: - VK-441: a large title that turns on on screen (measure.md M5)

@available(iOS 26.0, *)
extension NativeTabsTests {
  /// The navigation bar's height once UIKit has settled it.
  fileprivate func barHeight(of nav: UINavigationController) -> CGFloat {
    settle()
    return stable { nav.navigationBar.frame.height }
  }

  /// Hides and drops a baseline's window before the test installs its own
  /// shell.
  fileprivate func takeDownWindow() {
    window?.isHidden = true
    window?.rootViewController = nil
    window = nil
  }

  /// Inbox's bar with [pages] applied while Home is selected, then Inbox
  /// selected: its root enters the window for the first time with its mode
  /// set, and UIKit lays the large title out expanded by itself (M5, P2).
  /// The baseline of the tests below, in place of a device constant.
  fileprivate func expandedBarHeight(_ pages: [NativePage]) throws -> CGFloat {
    let tabs = try installedShell()
    var inbox = config()
    inbox.tabs[1].pages = pages
    tabs.apply(inbox)
    settle()
    inbox.selectedIndex = 1
    tabs.apply(inbox)
    let height = try barHeight(of: XCTUnwrap(tabs.navControllers[1]))
    takeDownWindow()
    return height
  }

  /// Library's case: a plain tab's pages reach native once the tab shows,
  /// so its root turns `.always` on screen. UIKit alone keeps that title
  /// collapsed (M5, P1: 54 pt against 106 on both devices, 26.5 and 27.0).
  func testALargeTitleThatTurnsOnOnScreenIsDrawnOut() throws {
    let library = [NativePage(title: "Library", largeTitle: true)]
    let expanded = try expandedBarHeight(library)
    let tabs = try installedShell()
    let nav = try XCTUnwrap(tabs.navControllers[0])
    XCTAssertTrue(nav.isNavigationBarHidden, "precondition: no pages, no bar")
    XCTAssertNotNil(nav.rootHost.viewIfLoaded?.window, "precondition: the root is on screen")
    tabs.apply(pagesConfig(library))
    XCTAssertEqual(barHeight(of: nav), expanded, accuracy: 0.5, "the large title is out at rest")
  }

  /// The proxy's base is learned with the title out: Flutter's offset 0,
  /// sent in the same turn as the pages, keeps it out, and after a scroll
  /// offset 0 brings it back (M5: P1 + offset 0 stays 54; P17a: 400 → 0
  /// gives 106).
  func testALargeTitleDrawnOutOnScreenStaysOutAtZeroAndReturns() throws {
    let library = [NativePage(title: "Library", largeTitle: true)]
    let expanded = try expandedBarHeight(library)
    let tabs = try installedShell()
    let nav = try XCTUnwrap(tabs.navControllers[0])
    tabs.apply(pagesConfig(library))
    tabs.setPageScroll(tab: 0, offset: 0)
    XCTAssertEqual(barHeight(of: nav), expanded, accuracy: 0.5, "out at Flutter's offset 0")
    XCTAssertEqual(
      nav.rootHost.expandedTop, nav.rootHost.view.safeAreaInsets.top, accuracy: 0.5,
      "the proxy's base is the expanded top")
    tabs.setPageScroll(tab: 0, offset: 400)
    XCTAssertLessThan(barHeight(of: nav), expanded - 20, "a scroll collapses it")
    tabs.setPageScroll(tab: 0, offset: 0)
    XCTAssertEqual(barHeight(of: nav), expanded, accuracy: 0.5, "back at 0, the title returns")
  }

  /// The search root flips its mode in place too: an iPad search root on
  /// screen asking for a large title (M5, P15: the bar kept its height,
  /// 114 pt on 26.5, 108 on 27.0).
  func testASearchRootAskingForALargeTitleOnScreenShowsIt() throws {
    try requireIPad()
    let large = [NativePage(title: "Search", largeTitle: true)]
    let baseline = try installedSearchShell(selected: 2, pages: large)
    let expanded = try barHeight(of: XCTUnwrap(baseline.navControllers[2]))
    takeDownWindow()
    let tabs = try installedSearchShell(
      selected: 2, pages: [NativePage(title: "Search", largeTitle: false)])
    let nav = try XCTUnwrap(tabs.navControllers[2])
    XCTAssertLessThan(barHeight(of: nav), expanded - 20, "precondition: no large title row")
    tabs.apply(searchConfig(selected: 2, pages: large))
    XCTAssertEqual(barHeight(of: nav), expanded, accuracy: 0.5, "the large title is out")
  }

  /// A large title that turns on on screen while Flutter is scrolled stays
  /// collapsed while scrolled, and comes out once Flutter is back at 0: the
  /// reveal waits for the top instead of being dropped.
  func testALargeTitleTurnedOnWhileScrolledComesOutAtTheTop() throws {
    let library = [NativePage(title: "Library", largeTitle: true)]
    let expanded = try expandedBarHeight(library)
    let tabs = try installedShell()
    let nav = try XCTUnwrap(tabs.navControllers[0])
    tabs.setPageScroll(tab: 0, offset: 400)
    tabs.apply(pagesConfig(library))
    XCTAssertLessThan(barHeight(of: nav), expanded - 20, "scrolled: collapsed")
    tabs.setPageScroll(tab: 0, offset: 0)
    XCTAssertEqual(barHeight(of: nav), expanded, accuracy: 0.5, "at the top, the title is out")
  }

  /// The same with the scroll arriving while the reveal waits for the bar's
  /// show animation.
  func testALargeTitleScrolledBeforeItsRevealComesOutAtTheTop() throws {
    let library = [NativePage(title: "Library", largeTitle: true)]
    let expanded = try expandedBarHeight(library)
    let tabs = try installedShell()
    let nav = try XCTUnwrap(tabs.navControllers[0])
    tabs.apply(pagesConfig(library))
    tabs.setPageScroll(tab: 0, offset: 400)
    XCTAssertLessThan(barHeight(of: nav), expanded - 20, "scrolled: collapsed")
    tabs.setPageScroll(tab: 0, offset: 0)
    XCTAssertEqual(barHeight(of: nav), expanded, accuracy: 0.5, "at the top, the title is out")
  }

  /// The same with the scroll arriving right after the pull, before the
  /// proxy is put back: the base is learned from the pulled, expanded bar.
  func testALargeTitleScrolledDuringItsRevealComesOutAtTheTop() throws {
    let library = [NativePage(title: "Library", largeTitle: true)]
    let expanded = try expandedBarHeight(library)
    let tabs = try installedShell()
    let nav = try XCTUnwrap(tabs.navControllers[0])
    let proxy = nav.rootHost.proxy
    var pulled = false
    let observation = proxy.observe(\.contentOffset) { proxy, _ in
      guard !pulled, proxy.contentOffset.y < -proxy.adjustedContentInset.top - 50 else { return }
      pulled = true
      tabs.setPageScroll(tab: 0, offset: 400)
    }
    tabs.apply(pagesConfig(library))
    XCTAssertLessThan(barHeight(of: nav), expanded - 20, "scrolled: collapsed")
    observation.invalidate()
    XCTAssertTrue(pulled, "precondition: the reveal pulled")
    tabs.setPageScroll(tab: 0, offset: 0)
    XCTAssertEqual(barHeight(of: nav), expanded, accuracy: 0.5, "at the top, the title is out")
  }

  /// An iPad search root asking for a large title while its search is
  /// active: the search hides the title on purpose; after it, the title is
  /// out.
  func testASearchRootAskingForALargeTitleUnderASearchShowsItAfter() throws {
    try requireIPad()
    let large = [NativePage(title: "Search", largeTitle: true)]
    let baseline = try installedSearchShell(selected: 2, pages: large)
    let expanded = try barHeight(of: XCTUnwrap(baseline.navControllers[2]))
    takeDownWindow()
    let tabs = try installedSearchShell(
      selected: 2, pages: [NativePage(title: "Search", largeTitle: false)])
    let nav = try XCTUnwrap(tabs.navControllers[2])
    settle(sending: "searchActive true") { tabs.setSearchActive(true) }
    tabs.apply(searchConfig(selected: 2, pages: large))
    settle()
    XCTAssertTrue(tabs.searchBridge.controller.isActive, "precondition: the search stays active")
    settle(sending: "searchActive false") { tabs.setSearchActive(false) }
    XCTAssertEqual(barHeight(of: nav), expanded, accuracy: 0.5, "the large title is out after it")
  }
}

// MARK: - P3b-2: the per-tab debug snapshot (spec P3b-2 §5.2)

@available(iOS 26.0, *)
extension NativeTabsTests {
  func testTheDebugSnapshotListsEveryTab() throws {
    let tabs = try installedShell()
    tabs.apply(
      pagesConfig([NativePage(title: "Home", largeTitle: true), NativePage(title: "Detail")]))
    settle()
    let snapshot = tabs.debugSnapshot().tabs
    XCTAssertEqual(snapshot.map(\.tab), [0, 1])
    XCTAssertEqual(snapshot.first?.pageTitles, ["Home", "Detail"])
    XCTAssertEqual(snapshot.first?.barHidden, false)
    XCTAssertEqual(snapshot.first?.titleModes, ["always", "never"])
    XCTAssertEqual(snapshot.last?.pageTitles, ["Inbox"], "no pages: the destination's label")
    XCTAssertEqual(snapshot.last?.barHidden, true)
    let home = try XCTUnwrap(tabs.navControllers[0])
    XCTAssertEqual(
      snapshot.first?.barHeight ?? -1, Double(home.navigationBar.frame.height), accuracy: 0.5,
      "the bar as UIKit lays it out")
    XCTAssertGreaterThan(snapshot.first?.barHeight ?? 0, 0)
    XCTAssertEqual(snapshot.last?.barHeight, 0, "a hidden bar")
  }
}

// MARK: - VK-550: SearchBridge's scope bar (no window)

/// The scope half of `SearchBridge` (spec VK-550 §10): UIKit's own scope
/// bar, `.manual`, shown by the controller's delegate while the search is
/// active (spike §1), and a one-way bridge: only the user's changes are
/// reported, once each; Dart's index is never reported back.
@available(iOS 26.0, *)
final class SearchScopeBridgeTests: XCTestCase {
  private static let scopes = ["All", "Songs", "Places"]
  private var reported: [Int] = []
  private var reporting = true

  private func makeBridge() -> SearchBridge {
    let bridge = SearchBridge()
    bridge.canReport = { [unowned self] in self.reporting }
    bridge.onScope = { [unowned self] in self.reported.append($0) }
    return bridge
  }

  /// UIKit for a user's tap: the segment changes, then the delegate.
  private func userSelects(_ index: Int, in bridge: SearchBridge) {
    bridge.controller.searchBar.selectedScopeButtonIndex = index
    bridge.searchBar(bridge.controller.searchBar, selectedScopeButtonIndexDidChange: index)
  }

  func testScopesSetTheTitlesWithManualActivation() {
    let bridge = makeBridge()
    XCTAssertEqual(bridge.controller.scopeBarActivation, .manual)
    bridge.setScopes(Self.scopes)
    XCTAssertEqual(bridge.controller.searchBar.scopeButtonTitles, Self.scopes)
    XCTAssertFalse(bridge.controller.searchBar.showsScopeBar, "only while active")
  }

  func testPresentingShowsTheScopeBarAndDismissingHidesIt() {
    let bridge = makeBridge()
    bridge.setScopes(Self.scopes)
    bridge.willPresentSearchController(bridge.controller)
    XCTAssertTrue(bridge.controller.searchBar.showsScopeBar)
    bridge.willDismissSearchController(bridge.controller)
    XCTAssertFalse(bridge.controller.searchBar.showsScopeBar)
  }

  func testNoScopesOrFewerThanTwoClearTheScopeBar() {
    let bridge = makeBridge()
    bridge.setScopes(Self.scopes)
    bridge.willPresentSearchController(bridge.controller)
    bridge.setScopes(nil)
    XCTAssertEqual(bridge.controller.searchBar.scopeButtonTitles ?? [], [])
    XCTAssertFalse(bridge.controller.searchBar.showsScopeBar, "hidden at once")
    bridge.willPresentSearchController(bridge.controller)
    XCTAssertFalse(bridge.controller.searchBar.showsScopeBar, "nothing to show")
    bridge.setScopes(["All"])
    XCTAssertEqual(bridge.controller.searchBar.scopeButtonTitles ?? [], [], "one title: none")
    XCTAssertFalse(bridge.controller.searchBar.showsScopeBar)
  }

  func testDartsIndexIsClampedAndNeverReported() {
    let bridge = makeBridge()
    bridge.setScopes(Self.scopes)
    bridge.setScope(5)
    XCTAssertEqual(bridge.controller.searchBar.selectedScopeButtonIndex, 2)
    bridge.setScope(-1)
    XCTAssertEqual(bridge.controller.searchBar.selectedScopeButtonIndex, 0)
    XCTAssertEqual(reported, [])
  }

  func testAUserChangeIsReportedOnce() {
    let bridge = makeBridge()
    bridge.setScopes(Self.scopes)
    userSelects(1, in: bridge)
    XCTAssertEqual(reported, [1])
    bridge.searchBar(bridge.controller.searchBar, selectedScopeButtonIndexDidChange: 1)
    XCTAssertEqual(reported, [1], "a repeat reports nothing")
  }

  func testDartsOwnIndexIsNotReportedBack() {
    let bridge = makeBridge()
    bridge.setScopes(Self.scopes)
    bridge.setScope(2)
    bridge.searchBar(bridge.controller.searchBar, selectedScopeButtonIndexDidChange: 2)
    XCTAssertEqual(reported, [])
  }

  func testAChangeIsNotReportedWhileReportingIsOff() {
    let bridge = makeBridge()
    bridge.setScopes(Self.scopes)
    reporting = false
    userSelects(1, in: bridge)
    XCTAssertEqual(reported, [])
  }

  /// Titles that arrive after Dart's index still show it.
  func testNewTitlesKeepDartsIndex() {
    let bridge = makeBridge()
    bridge.setScope(2)
    bridge.setScopes(Self.scopes)
    XCTAssertEqual(bridge.controller.searchBar.selectedScopeButtonIndex, 2)
    bridge.setScopes(["All", "Songs"])
    XCTAssertEqual(bridge.controller.searchBar.selectedScopeButtonIndex, 1, "clamped")
    bridge.setScopes(Self.scopes)
    XCTAssertEqual(bridge.controller.searchBar.selectedScopeButtonIndex, 2, "Dart's again")
    XCTAssertEqual(reported, [])
  }
}

// MARK: - Native dialogs (spec P3a §9.3)

final class DialogMathTests: XCTestCase {
  func testReasonsInOrder() {
    XCTAssertEqual(
      DialogMath.unavailableReason(
        disabledByEnvironment: true, requireGlass: true, osAtLeast26: false, hasWindow: false),
      .disabledByEnvironment)
    XCTAssertEqual(
      DialogMath.unavailableReason(
        disabledByEnvironment: false, requireGlass: true, osAtLeast26: false, hasWindow: false),
      .osTooOld)
    XCTAssertEqual(
      DialogMath.unavailableReason(
        disabledByEnvironment: false, requireGlass: false, osAtLeast26: false, hasWindow: false),
      .noWindow)
    XCTAssertNil(
      DialogMath.unavailableReason(
        disabledByEnvironment: false, requireGlass: false, osAtLeast26: false, hasWindow: true))
    XCTAssertNil(
      DialogMath.unavailableReason(
        disabledByEnvironment: false, requireGlass: true, osAtLeast26: true, hasWindow: true))
  }

  func testSourceRectIsTheAnchorClippedToTheView() {
    let bounds = CGRect(x: 0, y: 0, width: 400, height: 800)
    XCTAssertEqual(
      DialogMath.sourceRect(anchor: CGRect(x: 10, y: 20, width: 80, height: 44), in: bounds),
      CGRect(x: 10, y: 20, width: 80, height: 44))
    XCTAssertEqual(
      DialogMath.sourceRect(anchor: CGRect(x: 380, y: 780, width: 80, height: 44), in: bounds),
      CGRect(x: 380, y: 780, width: 20, height: 20))
    // A point still points: at least 1×1.
    XCTAssertEqual(
      DialogMath.sourceRect(anchor: CGRect(x: 50, y: 60, width: 0, height: 0), in: bounds),
      CGRect(x: 50, y: 60, width: 1, height: 1))
  }

  func testUnusableAnchorsAreNil() {
    let bounds = CGRect(x: 0, y: 0, width: 400, height: 800)
    XCTAssertNil(DialogMath.sourceRect(anchor: nil, in: bounds))
    XCTAssertNil(
      DialogMath.sourceRect(anchor: CGRect(x: 500, y: 900, width: 10, height: 10), in: bounds))
    XCTAssertNil(
      DialogMath.sourceRect(
        anchor: CGRect(x: CGFloat.nan, y: 0, width: 10, height: 10), in: bounds))
    XCTAssertNil(
      DialogMath.sourceRect(
        anchor: CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 10), in: bounds))
  }

  func testPreferredIndexMustNameAnAction() {
    XCTAssertEqual(DialogMath.preferredIndex(1, count: 2), 1)
    XCTAssertNil(DialogMath.preferredIndex(2, count: 2))
    XCTAssertNil(DialogMath.preferredIndex(-1, count: 2))
    XCTAssertNil(DialogMath.preferredIndex(nil, count: 2))
  }

  func testACompletionAnswersOnce() {
    var answers: [NativeDialogResult] = []
    let done = DialogCompletion { answers.append($0) }
    XCTAssertFalse(done.isFinished)
    done.finish(.chose(1))
    done.finish(.dismissed())
    done.finish(.unavailable(.refused))
    XCTAssertTrue(done.isFinished)
    XCTAssertEqual(answers, [.chose(1)])
  }
}

/// The presenter in a real window of the test host. A plain view controller
/// stands in for the Flutter one: the presenter only reads its view and window.
final class NativeDialogPresenterTests: XCTestCase {
  private var windows: [UIWindow] = []
  private var root: UIViewController!

  final class Answers {
    var all: [NativeDialogResult] = []
  }

  /// A root that never presents: UIKit's refusal, made deterministic.
  final class RefusingController: UIViewController {
    override func present(
      _ viewControllerToPresent: UIViewController, animated flag: Bool,
      completion: (() -> Void)? = nil
    ) {}
  }

  override func setUpWithError() throws {
    root = try window().rootViewController
  }

  override func tearDown() {
    for window in windows {
      window.rootViewController?.presentedViewController?.dismiss(animated: false)
      window.isHidden = true
      window.rootViewController = nil
    }
    windows = []
    root = nil
    super.tearDown()
  }

  private func window(root: UIViewController = UIViewController()) throws -> UIWindow {
    let window = try makeSceneWindow(root: root)
    windows.append(window)
    return window
  }

  private func settle(_ seconds: TimeInterval = 0.8) {
    RunLoop.current.run(until: Date().addingTimeInterval(seconds))
  }

  private func presenter(
    os26: Bool = true, off: Bool = false, flutter: UIViewController? = nil
  ) -> NativeDialogPresenter {
    let fallback = root
    return NativeDialogPresenter(
      flutterViewController: { flutter ?? fallback }, osAtLeast26: { os26 },
      disabledByEnvironment: { off })
  }

  private func request(
    kind: NativeDialogKind = .alert, anchor: NativeRect? = nil, requireGlass: Bool = true,
    rtl: Bool = false
  ) -> NativeDialogRequest {
    NativeDialogRequest(
      kind: kind, title: "Discard changes?", message: "Your edits will be lost.",
      actions: [
        NativeDialogAction(label: "Keep editing", style: .cancel, enabled: true),
        NativeDialogAction(label: "Discard", style: .destructive, enabled: true),
        NativeDialogAction(label: "Later", style: .standard, enabled: false),
      ],
      preferredIndex: kind == .alert ? 1 : nil, anchor: anchor, tintArgb: 0xFF00_7AFF,
      dark: true, rtl: rtl, requireGlass: requireGlass)
  }

  private func present(
    _ presenter: NativeDialogPresenter, _ request: NativeDialogRequest
  ) -> Answers {
    let answers = Answers()
    presenter.present(request: request) { result in
      if case .success(let value) = result { answers.all.append(value) }
    }
    return answers
  }

  func testAnAlertCarriesEveryField() throws {
    let answers = present(presenter(), request())
    settle()
    let alert = try XCTUnwrap(root.presentedViewController as? UIAlertController)
    XCTAssertEqual(alert.preferredStyle, .alert)
    XCTAssertEqual(alert.title, "Discard changes?")
    XCTAssertEqual(alert.message, "Your edits will be lost.")
    XCTAssertEqual(alert.actions.map(\.title), ["Keep editing", "Discard", "Later"])
    XCTAssertEqual(alert.actions.map(\.style), [.cancel, .destructive, .default])
    XCTAssertEqual(alert.actions.map(\.isEnabled), [true, true, false])
    XCTAssertTrue(alert.preferredAction === alert.actions[1])
    XCTAssertEqual(alert.overrideUserInterfaceStyle, .dark)
    XCTAssertEqual(alert.view.tintColor, UIColor(argb: 0xFF00_7AFF))
    XCTAssertTrue(answers.all.isEmpty)
  }

  func testAnActionSheetPointsAtItsAnchorInTheFlutterView() throws {
    _ = present(
      presenter(),
      request(kind: .actionSheet, anchor: NativeRect(x: 100, y: 200, width: 80, height: 44)))
    settle()
    let alert = try XCTUnwrap(root.presentedViewController as? UIAlertController)
    XCTAssertEqual(alert.preferredStyle, .actionSheet)
    XCTAssertNil(alert.preferredAction)
    let popover = try XCTUnwrap(alert.popoverPresentationController)
    XCTAssertTrue(popover.sourceView === root.view)
    XCTAssertEqual(popover.sourceRect, CGRect(x: 100, y: 200, width: 80, height: 44))
  }

  func testAnActionSheetWithoutAnAnchorUsesTheCentreWithoutAnArrow() throws {
    _ = present(presenter(), request(kind: .actionSheet))
    settle()
    let alert = try XCTUnwrap(root.presentedViewController as? UIAlertController)
    let popover = try XCTUnwrap(alert.popoverPresentationController)
    XCTAssertEqual(popover.permittedArrowDirections, [])
    XCTAssertEqual(popover.sourceRect.midX, root.view.bounds.midX, accuracy: 0.5)
    XCTAssertEqual(popover.sourceRect.midY, root.view.bounds.midY, accuracy: 0.5)
  }

  func testUnavailableReasonsShowNothing() {
    let off = present(presenter(off: true), request())
    let old = present(presenter(os26: false), request())
    let hidden = present(presenter(flutter: UIViewController()), request())
    settle()
    XCTAssertEqual(off.all, [.unavailable(.disabledByEnvironment)])
    XCTAssertEqual(old.all, [.unavailable(.osTooOld)])
    XCTAssertEqual(hidden.all, [.unavailable(.noWindow)])
    XCTAssertNil(root.presentedViewController)
  }

  /// A Flutter view that is loaded but not in a window (add-to-app before
  /// showing): answered at once, exactly once, so Dart falls back.
  func testALoadedViewOutsideAWindowAnswersNoWindowOnce() {
    let detached = UIViewController()
    detached.loadViewIfNeeded()
    let answers = present(presenter(flutter: detached), request())
    XCTAssertEqual(answers.all, [.unavailable(.noWindow)])
    settle()
    XCTAssertEqual(answers.all, [.unavailable(.noWindow)])
    XCTAssertNil(root.presentedViewController)
  }

  func testWithoutRequiringGlassAnOldOSPresents() throws {
    let answers = present(presenter(os26: false), request(requireGlass: false))
    settle()
    XCTAssertNotNil(root.presentedViewController as? UIAlertController)
    XCTAssertTrue(answers.all.isEmpty)
  }

  func testRespondAnswersOnceAndDismisses() throws {
    let dialogs = presenter()
    let answers = present(dialogs, request())
    settle()
    XCTAssertEqual(try dialogs.debugCurrent()?.labels, ["Keep editing", "Discard", "Later"])
    try dialogs.debugRespond(actionIndex: 1)
    settle()
    try dialogs.debugRespond(actionIndex: 0)
    settle()
    XCTAssertEqual(answers.all, [.chose(1)])
    XCTAssertNil(root.presentedViewController)
    XCTAssertNil(try dialogs.debugCurrent())
  }

  func testRespondMinusOneIsDismissed() throws {
    let dialogs = presenter()
    let answers = present(dialogs, request())
    settle()
    try dialogs.debugRespond(actionIndex: -1)
    settle()
    XCTAssertEqual(answers.all, [.dismissed()])
  }

  func testADismissalBySomeoneElseAnswersDismissedOnce() {
    // Present and dismiss each in its own pool and wait on the run loop,
    // not in a main-queue block: as in an app, where each is its own
    // run-loop turn. Otherwise iOS 27 keeps the alert alive (in the test's
    // pool, or behind the blocked main queue) until the test returns.
    let answers = autoreleasepool { present(presenter(), request()) }
    settle()
    autoreleasepool { root.dismiss(animated: false) }
    // The alert is released once UIKit lets go of it.
    settle()
    XCTAssertEqual(answers.all, [.dismissed()])
  }

  func testASecondDialogWaitsForTheFirstToLeave() throws {
    let dialogs = presenter()
    _ = present(dialogs, request())
    settle()
    let first = try XCTUnwrap(root.presentedViewController as? UIAlertController)
    // As when an app answers the first alert with a second one: UIKit is
    // still dismissing the first when the second request arrives.
    first.dismiss(animated: true)
    let second = present(dialogs, request(kind: .actionSheet))
    settle(1.5)
    let shown = try XCTUnwrap(root.presentedViewController as? UIAlertController)
    XCTAssertEqual(shown.preferredStyle, .actionSheet)
    XCTAssertTrue(second.all.isEmpty)
  }

  /// UIKit may decline to queue the wait (`animate(alongsideTransition:
  /// completion:)` returns false) and then never runs it. The presenter
  /// still asks the user: it retries after the transition, and never
  /// answers "dismissed" for a dialog nobody saw. Only the first wait is
  /// declined; later ones are UIKit's, so the outcome does not depend on
  /// the runner's speed.
  func testAWaitUIKitDoesNotQueueRetriesAfterTheTransition() throws {
    var declined = 0
    let dialogs = NativeDialogPresenter(
      flutterViewController: { [root] in root }, osAtLeast26: { true },
      disabledByEnvironment: { false },
      afterTransition: { coordinator, then in
        guard declined > 0 else {
          declined += 1
          return false
        }
        return coordinator.animate(alongsideTransition: nil) { _ in then() }
      })
    _ = present(dialogs, request())
    settle()
    let first = try XCTUnwrap(root.presentedViewController as? UIAlertController)
    first.dismiss(animated: true)
    let second = autoreleasepool { present(dialogs, request(kind: .actionSheet)) }
    settle(1.5)
    XCTAssertEqual(declined, 1, "the second request met the first one's transition")
    XCTAssertTrue(second.all.isEmpty, "answered \(second.all) without asking the user")
    let shown = try XCTUnwrap(root.presentedViewController as? UIAlertController)
    XCTAssertEqual(shown.preferredStyle, .actionSheet)
  }

  /// `rtl: true` lays the alert out right to left (iOS 17+: a trait
  /// override; earlier: the view's semantic content attribute).
  func testAnRtlRequestLaysTheAlertOutRightToLeft() throws {
    _ = present(presenter(), request(rtl: true))
    settle()
    let alert = try XCTUnwrap(root.presentedViewController as? UIAlertController)
    XCTAssertEqual(alert.traitCollection.layoutDirection, .rightToLeft)
    XCTAssertEqual(root.traitCollection.layoutDirection, .leftToRight)
  }

  func testARefusedPresentationIsUnavailableSoDartFallsBack() throws {
    let refusing = RefusingController()
    _ = try window(root: refusing)
    let answers = present(presenter(flutter: refusing), request())
    settle()
    XCTAssertEqual(answers.all, [.unavailable(.refused)])
  }

  func testEachEngineUsesItsOwnWindow() throws {
    let other = try window().rootViewController!
    _ = present(presenter(flutter: other), request())
    settle()
    XCTAssertNotNil(other.presentedViewController as? UIAlertController)
    XCTAssertNil(root.presentedViewController)
  }

  func testDismissAllAnswersDismissed() {
    let dialogs = presenter()
    let answers = present(dialogs, request())
    settle()
    dialogs.dismissAll()
    settle()
    XCTAssertEqual(answers.all, [.dismissed()])
    XCTAssertNil(root.presentedViewController)
  }

  /// Two dialogs pending at once (two calls in a row stack the second on
  /// the first): the engine's detach answers both, once each.
  func testDismissAllAnswersEveryPendingDialogOnce() throws {
    let dialogs = presenter()
    let first = present(dialogs, request())
    settle()
    let second = present(dialogs, request())
    settle()
    XCTAssertNotNil(
      root.presentedViewController?.presentedViewController as? UIAlertController,
      "the second alert stacks on the first")
    dialogs.dismissAll()
    settle()
    XCTAssertEqual(first.all, [.dismissed()])
    XCTAssertEqual(second.all, [.dismissed()])
    XCTAssertNil(root.presentedViewController)
  }

  /// A request still waiting for a transition when the engine detaches is
  /// answered then, and never shown.
  func testDismissAllAnswersARequestWaitingForATransition() throws {
    let dialogs = presenter()
    _ = present(dialogs, request())
    settle()
    let first = try XCTUnwrap(root.presentedViewController as? UIAlertController)
    first.dismiss(animated: true)
    let waiting = present(dialogs, request(kind: .actionSheet))
    dialogs.dismissAll()
    XCTAssertEqual(waiting.all, [.dismissed()])
    settle(1.5)
    XCTAssertEqual(waiting.all, [.dismissed()])
    XCTAssertNil(root.presentedViewController)
  }

  /// The scene closes while an alert is up: its window lets go of the
  /// Flutter view controller, and UIKit of the alert, unanswered. Dart's
  /// future still ends, once.
  func testAnAlertWhoseSceneClosesAnswersDismissedOnce() throws {
    var host: UIViewController? = UIViewController()
    var answers = Answers()
    try autoreleasepool {
      let window = try self.window(root: host!)
      let dialogs = NativeDialogPresenter(
        flutterViewController: { [weak host] in host }, osAtLeast26: { true },
        disabledByEnvironment: { false })
      answers = present(dialogs, request())
      settle()
      XCTAssertNotNil(host?.presentedViewController as? UIAlertController)
      XCTAssertTrue(answers.all.isEmpty)
      window.isHidden = true
      window.rootViewController = nil
      windows.removeAll { $0 === window }
      host = nil
    }
    settle()
    XCTAssertEqual(answers.all, [.dismissed()])
    settle()
    XCTAssertEqual(answers.all, [.dismissed()])
  }

  /// UIKit tells the popover's delegate when a tap outside closes it.
  func testAPopoverClosedByATapOutsideAnswersDismissedOnce() throws {
    let answers = present(presenter(), request(kind: .actionSheet))
    settle()
    let alert = try XCTUnwrap(root.presentedViewController as? UIAlertController)
    let popover = try XCTUnwrap(alert.popoverPresentationController)
    let delegate = try XCTUnwrap(popover.delegate)
    delegate.presentationControllerDidDismiss?(popover)
    delegate.presentationControllerDidDismiss?(popover)
    XCTAssertEqual(answers.all, [.dismissed()])
  }

  func testTopmostOfAControllerPresentingNothingIsItself() {
    let base = UIViewController()
    XCTAssertTrue(NativeDialogPresenter.topmost(from: base) === base)
    XCTAssertNil(NativeDialogPresenter.topmost(from: nil))
  }
}

/// The plugin's dialog wiring on a real engine (spec P3a §5.4): `register`
/// presents from the registrar's Flutter view controller, and
/// `detachFromEngine` (the engine going away) answers what is still shown.
final class PluginDialogWiringTests: XCTestCase {
  func testDetachingFromTheEngineAnswersAnOpenAlertDismissed() throws {
    let engine = FlutterEngine(name: "dialogs", project: nil, allowHeadlessExecution: true)
    XCTAssertTrue(engine.run())
    addTeardownBlock { engine.destroyContext() }
    let registrar = try XCTUnwrap(engine.registrar(forPlugin: LiquidShellPlugin.registrarKey))
    LiquidShellPlugin.register(with: registrar)
    let plugin = try XCTUnwrap(
      engine.valuePublished(byPlugin: LiquidShellPlugin.registrarKey) as? LiquidShellPlugin)
    let flutter = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
    let window = try makeSceneWindow(root: flutter)
    addTeardownBlock {
      window.isHidden = true
      window.rootViewController = nil
    }

    var answers: [NativeDialogResult] = []
    try XCTUnwrap(plugin.dialogs).present(
      request: NativeDialogRequest(
        kind: .alert, title: "Discard changes?", message: nil,
        actions: [NativeDialogAction(label: "Discard", style: .destructive, enabled: true)],
        preferredIndex: nil, anchor: nil, tintArgb: 0xFF00_7AFF, dark: false, rtl: false,
        requireGlass: false)
    ) { result in
      if case .success(let value) = result { answers.append(value) }
    }
    waitUntil("the alert is shown") { flutter.presentedViewController is UIAlertController }
    XCTAssertTrue(answers.isEmpty)

    plugin.detachFromEngine(for: registrar)
    waitUntil("the alert is gone") { flutter.presentedViewController == nil }
    XCTAssertEqual(answers, [.dismissed()])
  }

  /// Polls [condition] instead of waiting a fixed time: slow CI runners.
  private func waitUntil(_ what: String, _ condition: @escaping () -> Bool) {
    let met = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in condition() }, object: nil)
    met.expectationDescription = what
    wait(for: [met], timeout: 10)
  }
}

// MARK: Signals payload (spec 2026-10-10 §7.2)

final class SignalsPayloadTests: XCTestCase {
  func testLowPowerModeIsPowerSave() {
    XCTAssertEqual(
      LiquidShellPlugin.signalsPayload(reduceTransparency: false, lowPowerMode: true),
      [
        "reduceTransparency": false, "powerSave": true, "blurDisabled": false,
        "lowEnd": false, "glesOnly": false,
      ])
  }

  func testReduceTransparencyAloneIsReported() {
    XCTAssertEqual(
      LiquidShellPlugin.signalsPayload(reduceTransparency: true, lowPowerMode: false),
      [
        "reduceTransparency": true, "powerSave": false, "blurDisabled": false,
        "lowEnd": false, "glesOnly": false,
      ])
  }
}

// MARK: - VK-441: a large title set in the config that selects its tab

/// Samples a navigation bar's height on every display frame.
@available(iOS 26.0, *)
private final class BarHeightSampler: NSObject {
  private let nav: UINavigationController
  private(set) var highest: CGFloat = 0
  private var link: CADisplayLink?
  init(_ nav: UINavigationController) { self.nav = nav }
  func start() {
    link = CADisplayLink(target: self, selector: #selector(tick))
    link?.add(to: .main, forMode: .common)
  }
  @objc private func tick() {
    highest = max(highest, nav.isNavigationBarHidden ? 0 : nav.navigationBar.frame.height)
  }
  func stop() {
    link?.invalidate()
    link = nil
  }
}

@available(iOS 26.0, *)
extension NativeTabsTests {
  /// Library as the app sends it: its pages come in the config that
  /// selects the tab, so `applyPages` turns the root `.always` before
  /// `select` puts it in the window. iOS 26.5 animates the switch and
  /// lays the bar out collapsed (54 pt against 106; 27.0 switches at once).
  func testALargeTitleSetInTheConfigThatSelectsItsTabIsDrawnOut() throws {
    let library = [NativePage(title: "Library", largeTitle: true)]
    let expanded = try expandedBarHeight(library)
    let tabs = try installedShell()
    let nav = try XCTUnwrap(tabs.navControllers[1])
    XCTAssertNil(nav.rootHost.viewIfLoaded?.window, "precondition: the root is off screen")
    let sampler = BarHeightSampler(nav)
    sampler.start()
    var selecting = config()
    selecting.tabs[1].pages = library
    selecting.selectedIndex = 1
    tabs.apply(selecting)
    tabs.setPageScroll(tab: 1, offset: 0)
    let height = barHeight(of: nav)
    sampler.stop()
    XCTAssertEqual(height, expanded, accuracy: 0.5, "the large title is out at rest")
    XCTAssertLessThanOrEqual(sampler.highest, expanded + 0.5, "never pulled past expanded")
    tabs.setPageScroll(tab: 1, offset: 400)
    XCTAssertLessThan(barHeight(of: nav), expanded - 20, "a scroll collapses it")
    tabs.setPageScroll(tab: 1, offset: 0)
    XCTAssertEqual(barHeight(of: nav), expanded, accuracy: 0.5, "back at 0, the title returns")
  }

  /// A title UIKit lays out by itself (pages a turn before the selection,
  /// M5 P2) is revealed too: the pull must not stretch it.
  func testALargeTitleSetOffScreenBeforeItsTabIsSelectedIsNotStretched() throws {
    let library = [NativePage(title: "Library", largeTitle: true)]
    let tabs = try installedShell()
    let nav = try XCTUnwrap(tabs.navControllers[1])
    var pages = config()
    pages.tabs[1].pages = library
    tabs.apply(pages)
    settle()
    let sampler = BarHeightSampler(nav)
    sampler.start()
    pages.selectedIndex = 1
    tabs.apply(pages)
    let height = barHeight(of: nav)
    sampler.stop()
    XCTAssertGreaterThan(height, 80, "the large title is out at rest")
    XCTAssertLessThanOrEqual(sampler.highest, height + 0.5, "never pulled past expanded")
  }
}
