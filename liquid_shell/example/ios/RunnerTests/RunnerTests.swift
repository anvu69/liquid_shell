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
    isPad: true, osAtLeast26: true, isiOSAppOnMac: false, enabledInInfoPlist: true,
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
    facts.isPad = false
    XCTAssertEqual(InstallPolicy.decide(facts), .notIPad)
  }

  func testKeysAreThePublishedNames() {
    XCTAssertEqual(InstallPolicy.infoPlistKey, "LiquidShellNativeChrome")
    XCTAssertEqual(InstallPolicy.disableEnvironmentKey, "LIQUID_SHELL_NATIVE_OFF")
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
    footer: Bool = false, selected: Int64 = 0
  ) -> NativeChromeConfig {
    NativeChromeConfig(
      engaged: engaged,
      tabs: [
        NativeTab(title: "Home", sfSymbol: "house", sidebarOnly: false),
        NativeTab(title: "Inbox", sfSymbol: "tray", sidebarOnly: false),
      ],
      selectedIndex: selected,
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
    root: UIViewController, landscape: Bool = false
  ) throws -> UIWindow {
    let scene = try XCTUnwrap(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    let bounds = scene.coordinateSpace.bounds
    let short = min(bounds.width, bounds.height)
    let long = max(bounds.width, bounds.height)
    window.frame = CGRect(
      x: 0, y: 0, width: landscape ? long : short, height: landscape ? short : long)
    window.rootViewController = root
    window.isHidden = false
    return window
  }

  /// A shell installed in its own window with the first config applied.
  private func installedShell(
    footer: Bool = false, landscape: Bool = false
  ) throws -> NativeTabsController {
    let flutter = UIViewController()
    let tabs = NativeTabsController(flutter: flutter, events: events)
    let window = try portraitWindow(root: UIViewController(), landscape: landscape)
    window.rootViewController = ShellContainerController(tabs: tabs, flutter: flutter)
    self.window = window
    tabs.apply(config(footer: footer))
    settle()
    return tabs
  }

  func testHidingTheChromeClosesAnOverlaySidebar() throws {
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
    isPad: Bool = true, enabled: Bool = true, flutterViewOnScreen: Bool
  ) -> NativeShellInstaller {
    NativeShellInstaller(
      events: RecordingEvents(),
      ownViewController: { nil },
      ownsFlutter: { _ in true },
      readFacts: { registeredLate, rootIsFlutter in
        InstallFacts(
          isPad: isPad, osAtLeast26: true, isiOSAppOnMac: false, enabledInInfoPlist: enabled,
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
    XCTAssertEqual(try reason(installer(isPad: false, flutterViewOnScreen: true)), .notIPad)
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
          isPad: true, osAtLeast26: true, isiOSAppOnMac: false, enabledInInfoPlist: true,
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
