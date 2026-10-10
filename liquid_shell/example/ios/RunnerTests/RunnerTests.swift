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

    XCTAssertTrue(PassThroughView.isBackground(nil, selected: host, tabsView: tabsView))
    XCTAssertTrue(PassThroughView.isBackground(tabsView, selected: host, tabsView: tabsView))
    XCTAssertTrue(PassThroughView.isBackground(host, selected: host, tabsView: tabsView))
    XCTAssertTrue(PassThroughView.isBackground(transition, selected: host, tabsView: tabsView))
    XCTAssertFalse(PassThroughView.isBackground(chrome, selected: host, tabsView: tabsView))
    // No selected host yet: only nil and the tabs view are background.
    XCTAssertFalse(PassThroughView.isBackground(transition, selected: nil, tabsView: tabsView))
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
        NativeTab(title: "Home", sfSymbol: "house", sidebarOnly: false),
        NativeTab(title: "Inbox", sfSymbol: "tray", sidebarOnly: false),
      ] + (reports ? [NativeTab(title: "Reports", sfSymbol: "chart.bar", sidebarOnly: true)] : []),
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

  /// The centre, in container coordinates, of the on-screen label [text]
  /// inside [container] (a label with no hidden ancestor), if any.
  private func labelCentre(
    _ text: String, in container: UIView, _ tabs: NativeTabsController
  ) -> CGPoint? {
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
    guard let root = tabs.parent?.view,
      let label = labels(container).first(where: { $0.text == text && shown($0) })
    else { return nil }
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
    // The separate ⌕ circle is native, the gap before it is Flutter's. An
    // iPhone always draws the circle; iPadOS 27 at the 820pt compact
    // override puts the search tab inside the pill instead.
    let (pill, circle) = try compactBarParts(tabs, inbox: inbox)
    if UIDevice.current.userInterfaceIdiom == .phone { XCTAssertNotNil(circle, "the ⌕ circle") }
    if let circle {
      XCTAssertTrue(
        isNative(try hit(tabs, CGPoint(x: circle.midX, y: circle.midY)), tabs), "the ⌕ circle")
      XCTAssertGreaterThan(circle.minX - pill.maxX, 8, "precondition: a gap between pill and circle")
      XCTAssertTrue(
        try hit(tabs, CGPoint(x: (pill.maxX + circle.minX) / 2, y: inbox.y)) === tabs.flutter.view,
        "the gap between the pill and the circle")
    }
    tabs.apply(config(interactive: false, trailing: true))
    XCTAssertTrue(try hit(tabs, inbox) === tabs.flutter.view, "inert under a dialog")
  }

  /// The compact bar's pill (the drawn tab bar subview around [inbox]) and
  /// the separate ⌕ circle, if UIKit draws one: the drawn subview furthest
  /// to the trailing side that does not overlap the pill. Drawn: shown,
  /// with something shown inside (UIKit keeps an empty circle container
  /// when the search tab sits in the pill).
  private func compactBarParts(
    _ tabs: NativeTabsController, inbox: CGPoint
  ) throws -> (pill: CGRect, circle: CGRect?) {
    func drawn(_ view: UIView) -> Bool {
      !view.isHidden && view.alpha > 0.01 && !view.bounds.isEmpty
        && (view.subviews.isEmpty || view.subviews.contains(where: drawn))
    }
    let root = try XCTUnwrap(tabs.parent?.view)
    let frames = tabs.tabBar.subviews.filter(drawn).map { $0.convert($0.bounds, to: root) }
    let pill = try XCTUnwrap(frames.first { $0.contains(inbox) }, "the pill")
    let circle = frames.filter { !$0.intersects(pill) }.max { $0.maxX < $1.maxX }
    return (pill, circle)
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
    let scene = try XCTUnwrap(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    window.frame = scene.coordinateSpace.bounds
    window.rootViewController = root
    window.makeKeyAndVisible()
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
    kind: NativeDialogKind = .alert, anchor: NativeRect? = nil, requireGlass: Bool = true
  ) -> NativeDialogRequest {
    NativeDialogRequest(
      kind: kind, title: "Discard changes?", message: "Your edits will be lost.",
      actions: [
        NativeDialogAction(label: "Keep editing", style: .cancel, enabled: true),
        NativeDialogAction(label: "Discard", style: .destructive, enabled: true),
        NativeDialogAction(label: "Later", style: .standard, enabled: false),
      ],
      preferredIndex: kind == .alert ? 1 : nil, anchor: anchor, tintArgb: 0xFF00_7AFF,
      dark: true, rtl: false, requireGlass: requireGlass)
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
  private var window: UIWindow?

  override func tearDown() {
    window?.isHidden = true
    window?.rootViewController = nil
    window = nil
    super.tearDown()
  }

  func testDetachingFromTheEngineAnswersAnOpenAlertDismissed() throws {
    let engine = FlutterEngine(name: "dialogs", project: nil, allowHeadlessExecution: true)
    XCTAssertTrue(engine.run())
    let registrar = try XCTUnwrap(engine.registrar(forPlugin: LiquidShellPlugin.registrarKey))
    LiquidShellPlugin.register(with: registrar)
    let plugin = try XCTUnwrap(
      engine.valuePublished(byPlugin: LiquidShellPlugin.registrarKey) as? LiquidShellPlugin)
    let flutter = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
    let scene = try XCTUnwrap(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    window.frame = scene.coordinateSpace.bounds
    window.rootViewController = flutter
    window.makeKeyAndVisible()
    self.window = window

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
    RunLoop.current.run(until: Date().addingTimeInterval(0.8))
    XCTAssertNotNil(flutter.presentedViewController as? UIAlertController)
    XCTAssertTrue(answers.isEmpty)

    plugin.detachFromEngine(for: registrar)
    RunLoop.current.run(until: Date().addingTimeInterval(0.8))
    XCTAssertEqual(answers, [.dismissed()])
    XCTAssertNil(flutter.presentedViewController)
    engine.destroyContext()
  }
}
