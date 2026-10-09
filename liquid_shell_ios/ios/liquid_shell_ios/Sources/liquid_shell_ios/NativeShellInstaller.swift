import Flutter
import UIKit

/// Installs the native shell when the scene connects (spec §5.1) and answers
/// Dart's calls.
///
/// Installs only when `InstallPolicy` says so; every other path keeps the
/// Flutter chrome, and Dart learns why from `attach()`.
final class NativeShellInstaller: NSObject, NativeShellHostApi {
  private let events: NativeShellFlutterApiProtocol
  /// The engine's own view controller, once known (not yet when the scene
  /// connects): where window controls are read before a scene connects.
  private let ownViewController: () -> UIViewController?
  /// Whether a Flutter view controller belongs to this installer's engine,
  /// to ignore scenes of other engines (`LiquidShellPlugin.owns`).
  private let ownsFlutter: (UIViewController) -> Bool
  /// The install facts, given the two the installer works out itself.
  /// Injectable for tests.
  private let readFacts: (_ registeredLate: Bool, _ rootIsFlutter: Bool) -> InstallFacts
  /// Whether a Flutter view of this app is already in a window. Injectable
  /// for tests.
  private let flutterViewOnScreen: () -> Bool
  private var observers: [NSObjectProtocol] = []
  private var registeredLate = false
  /// Why the shell is not installed; seeded by `start()`.
  private var reason: NativeUnavailableReason = .rootNotFlutter

  /// The Flutter view controller seen at scene connection, installed or not
  /// (window controls are read from it either way).
  private weak var flutter: FlutterViewController?
  private weak var scene: UIWindowScene?
  /// `NativeTabsController` once installed. `AnyObject`: that class needs iOS 26.
  /// Weak: the window's root (the container) owns it. A strong reference
  /// closes engine → plugin → installer → shell → Flutter view controller
  /// → engine, which leaks the engine when an app replaces the root.
  private weak var shell: AnyObject?
  /// Dart called `attach`, so native → Dart calls have a receiver. Kept
  /// here, not in the shell: a reinstall after a scene reconnect inherits it.
  private var dartAttached = false
  /// Dart's last config, also one sent while no shell was installed. A
  /// reinstall after a scene reconnect applies it at once, so the chrome
  /// is back before Dart answers the new shell's first state report.
  private var lastConfig: NativeChromeConfig?

  init(
    events: NativeShellFlutterApiProtocol,
    ownViewController: @escaping () -> UIViewController?,
    ownsFlutter: @escaping (UIViewController) -> Bool,
    readFacts: @escaping (_ registeredLate: Bool, _ rootIsFlutter: Bool) -> InstallFacts =
      NativeShellInstaller.systemFacts(registeredLate:rootIsFlutter:),
    flutterViewOnScreen: @escaping () -> Bool = NativeShellInstaller.isFlutterViewOnScreen
  ) {
    self.events = events
    self.ownViewController = ownViewController
    self.ownsFlutter = ownsFlutter
    self.readFacts = readFacts
    self.flutterViewOnScreen = flutterViewOnScreen
  }

  /// The facts of this device, OS, bundle and process (spec §5.1).
  static func systemFacts(registeredLate: Bool, rootIsFlutter: Bool) -> InstallFacts {
    InstallFacts(
      isPad: UIDevice.current.userInterfaceIdiom == .pad,
      osAtLeast26: { if #available(iOS 26.0, *) { return true } else { return false } }(),
      isiOSAppOnMac: ProcessInfo.processInfo.isiOSAppOnMac
        || ProcessInfo.processInfo.isMacCatalystApp,
      enabledInInfoPlist: Bundle.main.object(forInfoDictionaryKey: InstallPolicy.infoPlistKey)
        as? Bool == true,
      disabledByEnvironment: ProcessInfo.processInfo.environment[
        InstallPolicy.disableEnvironmentKey] == "1",
      registeredLate: registeredLate,
      rootIsFlutter: rootIsFlutter)
  }

  /// A Flutter view already in a window means the scene connected before
  /// the plugin registered: detaching it now would lose its surface.
  static func isFlutterViewOnScreen() -> Bool {
    isFlutterViewOnScreen(
      in: UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap(\.windows))
  }

  /// Whether one of [windows] shows a Flutter view: as the root, or inside
  /// an installed shell container (another engine's, or ours before a
  /// re-registration).
  static func isFlutterViewOnScreen(in windows: [UIWindow]) -> Bool {
    windows.contains { window in
      let root = window.rootViewController
      if root is FlutterViewController { return root?.viewIfLoaded?.window != nil }
      if #available(iOS 26.0, *), let container = root as? ShellContainerController {
        return container.flutter.viewIfLoaded?.window != nil
      }
      return false
    }
  }

  /// Arms the scene observers. Called from `register(with:)`, which runs
  /// while the storyboard creates the Flutter view controller, before
  /// `UIScene.willConnectNotification`.
  func start() {
    guard observers.isEmpty else { return }
    registeredLate = flutterViewOnScreen()
    // What `attach` reports if no scene of this engine connects (late
    // registration, add-to-app, another engine's scene): every fact known
    // now, with no Flutter root yet. A connect refines it.
    reason = InstallPolicy.decide(readFacts(registeredLate, false)) ?? .rootNotFlutter
    let center = NotificationCenter.default
    // `queue: nil`: runs synchronously while the scene connects. One run
    // loop turn later the Flutter view is already the visible root, and
    // detaching it then leaves the splash screen up for good.
    observers.append(
      center.addObserver(forName: UIScene.willConnectNotification, object: nil, queue: nil) {
        [weak self] note in self?.connect(note.object as? UIWindowScene)
      })
    observers.append(
      center.addObserver(forName: UIScene.didDisconnectNotification, object: nil, queue: nil) {
        [weak self] note in self?.disconnect(note.object as? UIScene)
      })
  }

  /// Removes the observers (engine detach).
  func stop() {
    observers.forEach(NotificationCenter.default.removeObserver)
    observers = []
  }

  private func connect(_ scene: UIWindowScene?) {
    guard let scene else { return }
    let sceneWindow = (scene.delegate as? UIWindowSceneDelegate)?.window ?? nil
    connect(window: scene.windows.first ?? sceneWindow, scene: scene)
  }

  /// The install decision for [window], the first window of [scene].
  /// Internal for tests.
  func connect(window: UIWindow?, scene: UIWindowScene?) {
    let root = window?.rootViewController
    let flutter = root as? FlutterViewController
    // Another engine's scene: not ours to touch.
    if let flutter, !ownsFlutter(flutter) { return }
    if let flutter { self.flutter = flutter }
    self.scene = scene
    if let reason = InstallPolicy.decide(readFacts(registeredLate, flutter != nil)) {
      self.reason = reason
      #if DEBUG
        NSLog("[liquid_shell] native shell not installed: %@", String(describing: reason))
      #endif
      return
    }
    guard #available(iOS 26.0, *), let flutter, let window else { return }
    install(flutter, in: window)
  }

  /// Makes the shell container the window's root, around [flutter] (spec §5.2).
  @available(iOS 26.0, *)
  func install(_ flutter: UIViewController, in window: UIWindow) {
    let tabs = NativeTabsController(flutter: flutter, events: events)
    tabs.dartAttached = dartAttached
    // Detach the Flutter view controller from the root role first, or
    // `addChild` throws UIViewControllerHierarchyInconsistency.
    window.rootViewController = nil
    flutter.view.removeFromSuperview()
    window.rootViewController = ShellContainerController(tabs: tabs, flutter: flutter)
    shell = tabs
    if let lastConfig { tabs.apply(lastConfig) }
  }

  private func disconnect(_ scene: UIScene?) {
    guard let scene, scene === self.scene else { return }
    // A reconnect gets a fresh install from the willConnect observer, which
    // stays armed, with `lastConfig` applied; until then Dart sees "not
    // installed". Dart's forced re-send after the new shell's first state
    // report confirms it.
    shell = nil
    flutter = nil
    self.scene = nil
  }

  @available(iOS 26.0, *)
  private var tabs: NativeTabsController? {
    guard let tabs = shell as? NativeTabsController, tabs.viewIfLoaded?.window != nil || !tabs.isViewLoaded
    else { return nil }
    return tabs
  }

  // MARK: - NativeShellHostApi (Dart → native)

  func attach() throws -> NativeShellState {
    dartAttached = true
    if #available(iOS 26.0, *), let tabs {
      tabs.dartAttached = true
      return tabs.currentState()
    }
    return NativeShellState(
      installed: false, compact: false, sidebar: .hidden, unavailableReason: reason)
  }

  func update(config: NativeChromeConfig) throws {
    lastConfig = config
    if #available(iOS 26.0, *) { tabs?.apply(config) }
  }

  func setSidebarVisible(visible: Bool) throws {
    if #available(iOS 26.0, *) { tabs?.setSidebarVisible(visible) }
  }

  func windowControls() throws -> NativeWindowControls {
    let view = flutter?.viewIfLoaded ?? ownViewController()?.viewIfLoaded
    return WindowControlsReader.read(view)
  }

  func debugTap(target: NativeTapTarget, index: Int64) throws {
    if #available(iOS 26.0, *) { tabs?.debugTap(target, index: Int(index)) }
  }
}
