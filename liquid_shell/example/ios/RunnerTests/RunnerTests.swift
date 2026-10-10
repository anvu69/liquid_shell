import Flutter
import UIKit
import XCTest

@testable import liquid_shell_ios

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

final class SearchMathTests: XCTestCase {
  func testAnIPhoneKeepsUIKitsTabHostedFieldAndALargeTitle() {
    XCTAssertEqual(
      SearchMath.style(isPad: false, osMajor: 26, rootLargeTitle: nil),
      SearchTabStyle(placement: .automatic, hidesWhenScrolling: nil, largeTitle: true, prominent: false))
  }

  func testAnIPhoneOnIOS27MakesTheSearchTabProminent() {
    XCTAssertTrue(SearchMath.style(isPad: false, osMajor: 27, rootLargeTitle: nil).prominent)
  }

  func testAnIPadIsStackedInlineAndNeverProminent() {
    for os in [26, 27] {
      XCTAssertEqual(
        SearchMath.style(isPad: true, osMajor: os, rootLargeTitle: nil),
        SearchTabStyle(placement: .stacked, hidesWhenScrolling: false, largeTitle: false, prominent: false))
    }
  }

  func testTheAppsLargeTitleChoiceWins() {
    XCTAssertFalse(SearchMath.style(isPad: false, osMajor: 26, rootLargeTitle: false).largeTitle)
    XCTAssertTrue(SearchMath.style(isPad: true, osMajor: 27, rootLargeTitle: true).largeTitle)
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

  func onBackTapped(tab tabArg: Int64, completion: @escaping (Result<Void, PigeonError>) -> Void) {
    sent.append("back \(tabArg)")
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
    footer: Bool = false, trailing: Bool = false, reports: Bool = false, selected: Int64 = 0
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
      tintArgb: 0xFF00_7AFF, dark: false, rtl: false, hidden: hidden, interactive: interactive)
  }

  /// Lets UIKit finish layout and any sidebar transition.
  private func settle() {
    RunLoop.current.run(until: Date().addingTimeInterval(0.5))
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
    // UIKit lays the bar out on its own passes: poll with a deadline, as
    // `openSidebar` does. Without the circle (iOS 27 with ⌕ in the pill)
    // the bar is stable and the asserts below fail after the deadline.
    let deadline = Date().addingTimeInterval(3)
    var bar = compactBar(tabs)
    while bar.circle == nil || bar.find != nil, Date() < deadline {
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
  private struct CompactBar: CustomStringConvertible {
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
        rtl: false, hidden: false, interactive: true))
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
        rtl: false, hidden: false, interactive: true))
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
    let scene = try XCTUnwrap(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    window.rootViewController = root
    window.isHidden = false
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
    reports: Bool = false, hidden: Bool = false, interactive: Bool = true
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
      search: NativeSearchConfig(placeholder: placeholder), tintArgb: 0xFF00_7AFF, dark: false,
      rtl: false, hidden: hidden, interactive: interactive)
  }

  fileprivate func installedSearchShell(
    selected: Int64 = 0, pages: [NativePage] = [], placeholder: String? = nil,
    reports: Bool = false, sizeClass: UIUserInterfaceSizeClass? = nil
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
      searchConfig(selected: selected, pages: pages, placeholder: placeholder, reports: reports))
    settle()
    return tabs
  }

  /// Runs [action] and waits until it has sent [message] once more: the
  /// search controller's present and dismiss transitions outlast `settle`
  /// while the keyboard moves (up to 0.7 s on iPhone 27.0).
  fileprivate func settle(sending message: String, _ action: () -> Void) {
    let count = { self.events.sent.filter { $0 == message }.count }
    let before = count()
    action()
    let deadline = Date().addingTimeInterval(3)
    while count() == before, Date() < deadline {
      RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }
    if count() == before { XCTFail("no \(message) within 3 s: \(events.sent)") }
    settle()
  }

  /// A user edit typed into the field.
  fileprivate func userTypes(_ text: String, into bridge: SearchBridge) {
    bridge.controller.searchBar.text = text
    bridge.updateSearchResults(for: bridge.controller)
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
    // The scene goes away: its window and shell are released.
    installer.sceneDisconnected()
    window.rootViewController = UIViewController()
    settle()

    let scene = try XCTUnwrap(window.windowScene)
    let next = UIWindow(windowScene: scene)
    let flutter = UIViewController()
    next.rootViewController = flutter
    next.isHidden = false
    extraWindows.append(next)
    installer.install(flutter, in: next)
    settle()

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
    installer.sceneDisconnected()
    window.rootViewController = UIViewController()
    settle()

    let scene = try XCTUnwrap(window.windowScene)
    let next = UIWindow(windowScene: scene)
    let flutter = UIViewController()
    next.rootViewController = flutter
    next.isHidden = false
    extraWindows.append(next)
    installer.install(flutter, in: next)
    try installer.update(config: searchConfig(selected: 2))
    settle()

    XCTAssertEqual(try tabs(in: next).searchBridge.text, "hà")
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
      XCTAssertEqual(item.largeTitleDisplayMode, .always)
    }
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

  func testTheNativeBackButtonOnlyProposes() throws {
    let tabs = try installedSearchShell(
      selected: 2, pages: [NativePage(title: "Search"), NativePage(title: "Detail")])
    let nav = try XCTUnwrap(tabs.navControllers[2])
    let top = try XCTUnwrap(nav.topViewController as? PageHostController)
    top.onBack?()
    XCTAssertEqual(events.sent.last, "back 2")
    XCTAssertEqual(nav.viewControllers.count, 2, "Dart pops; native follows")
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

  func testTheProxyCollapsesTheLargeTitleWhileFlutterKeepsItsTop() throws {
    try requirePhone()
    let tabs = try installedSearchShell(selected: 2)
    let host = try XCTUnwrap(tabs.topHost(ofTab: 2))
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
    // Selected.
    XCTAssertTrue(isNative(try hit(tabs, try fieldCentre()), tabs), "selected: the field")
    XCTAssertTrue(
      try hit(tabs, CGPoint(x: root.bounds.midX, y: root.bounds.midY)) === tabs.flutter.view,
      "selected: the body")
    // Active.
    tabs.setSearchActive(true)
    settle()
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
    let frame = bar.convert(bar.bounds, to: root)
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
  }
}
