import Flutter
import UIKit
import XCTest

@testable import liquid_shell_ios

/// Unit tests of liquid_shell_ios's native shell: the pure arithmetic, the
/// install rule and the pass-through hit test (spec P2 §9.3). They live in
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
    // Full screen: 9.5pt of rounded corner, no vertical delta.
    let fullScreen = ShellMath.windowControls(
      safeLeading: 0, safeTop: 32, horizontalLeading: 9.5, verticalTop: 32)
    XCTAssertEqual(fullScreen.leading, 0)
    XCTAssertEqual(fullScreen.top, 0)
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
    completion(.success(()))
  }
}

/// The UIKit half of the shell (`NativeTabsController` inside the container)
/// in a real window of the test host. A plain view controller stands in for
/// the Flutter one: the shell only moves its view and sets its safe area.
@available(iOS 26.0, *)
final class NativeTabsTests: XCTestCase {
  private var window: UIWindow?
  private var events = RecordingEvents()

  override func tearDown() {
    window?.isHidden = true
    window?.rootViewController = nil
    window = nil
    super.tearDown()
  }

  private func config(
    engaged: Bool = true, hidden: Bool = false, interactive: Bool = true,
    footer: Bool = false
  ) -> NativeChromeConfig {
    NativeChromeConfig(
      engaged: engaged,
      tabs: [
        NativeTab(title: "Home", sfSymbol: "house", sidebarOnly: false),
        NativeTab(title: "Inbox", sfSymbol: "tray", sidebarOnly: false),
      ],
      selectedIndex: 0,
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

  /// A shell installed in its own window with the first config applied.
  private func installedShell(footer: Bool = false) throws -> NativeTabsController {
    let scene = try XCTUnwrap(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let flutter = UIViewController()
    let tabs = NativeTabsController(flutter: flutter, events: events)
    let window = UIWindow(windowScene: scene)
    window.rootViewController = ShellContainerController(tabs: tabs, flutter: flutter)
    window.isHidden = false
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
}
