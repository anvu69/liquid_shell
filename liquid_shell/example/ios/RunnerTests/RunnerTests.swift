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
  private func portraitWindow(root: UIViewController) throws -> UIWindow {
    let scene = try XCTUnwrap(
      UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    let window = UIWindow(windowScene: scene)
    let bounds = scene.coordinateSpace.bounds
    window.frame = CGRect(
      x: 0, y: 0, width: min(bounds.width, bounds.height),
      height: max(bounds.width, bounds.height))
    window.rootViewController = root
    window.isHidden = false
    return window
  }

  /// A shell installed in its own window with the first config applied.
  private func installedShell(footer: Bool = false) throws -> NativeTabsController {
    let flutter = UIViewController()
    let tabs = NativeTabsController(flutter: flutter, events: events)
    let window = try portraitWindow(root: UIViewController())
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
