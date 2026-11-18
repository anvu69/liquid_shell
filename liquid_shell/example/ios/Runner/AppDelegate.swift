import Flutter
import UIKit

// UIScene life cycle: apps built with the iOS 27 SDK do not launch without it.
// Plugins register on the implicit engine that FlutterSceneDelegate creates.
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if ProcessInfo.processInfo.environment["LIQUID_SHELL_EXAMPLE_TRACE_NAV"] != nil {
      AnimatedStackTrace.install()
    }
    if ProcessInfo.processInfo.environment["LIQUID_SHELL_EXAMPLE_DEMO"] != nil {
      FlutterUIProbe.install()
    }
    #if DEBUG
      // tool/segment_frames.sh: UIKit's segmented controls instead of
      // Flutter's, at the same frames (spec VK-550 §14.5).
      if ProcessInfo.processInfo.environment["LIQUID_SHELL_EXAMPLE_DEMO"] == "segments-native" {
        SegmentReferenceViewController.showWhenActive()
      }
    #endif
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // UI tests launch the example on one demo (LIQUID_SHELL_EXAMPLE_DEMO,
    // lib/support/launch_demo.dart). Dart cannot read the process
    // environment on iOS, so it asks here.
    FlutterMethodChannel(
      name: "liquid_shell_example/launch",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    ).setMethodCallHandler { call, result in
      guard call.method == "demo" else { return result(FlutterMethodNotImplemented) }
      result(ProcessInfo.processInfo.environment["LIQUID_SHELL_EXAMPLE_DEMO"])
    }
  }
}

/// UI tests only (LIQUID_SHELL_EXAMPLE_DEMO, VK-1081): whether the Flutter
/// UI is displayed, as an accessibility label ("flutterUI: displayed" or
/// "flutterUI: not displayed") and a `[liquid_shell] example:` log line. A
/// launch can show the native chrome over a white screen that never gets
/// Flutter's first frame; the tests relaunch once on this signal.
///
/// KVO on `displayingFlutterUI`, not `setFlutterViewDidRenderCallback`: that
/// slot is single, and the app's to use. Armed when the scene activates,
/// after the plugin's install in `willConnect`, and never reads
/// `flutter.view`, so it cannot change the launch it observes.
enum FlutterUIProbe {
  static let label: UILabel = {
    let label = UILabel(frame: CGRect(x: 0, y: 0, width: 2, height: 2))
    label.textColor = .clear
    label.isUserInteractionEnabled = false
    label.accessibilityIdentifier = "flutterUIProbe"
    return label
  }()
  private static var launchedAt: CFTimeInterval = 0
  private static var activation: NSObjectProtocol?
  private static weak var observed: FlutterViewController?
  private static var observation: NSKeyValueObservation?

  static func install() {
    launchedAt = CACurrentMediaTime()
    activation = NotificationCenter.default.addObserver(
      forName: UIScene.didActivateNotification, object: nil, queue: .main
    ) { note in
      guard let scene = note.object as? UIWindowScene else { return }
      attach(in: scene)
    }
  }

  private static func attach(in scene: UIWindowScene) {
    guard
      let window = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first,
      let flutter = find(in: window.rootViewController),
      flutter !== observed
    else { return }
    observed = flutter
    // `.initial`: the first frame may already be up.
    observation = flutter.observe(\.isDisplayingFlutterUI, options: [.initial, .new]) {
      [weak window] flutter, _ in
      report(flutter.isDisplayingFlutterUI, in: window)
    }
  }

  /// The Flutter view controller: the root, or a descendant of it (the
  /// plugin's shell container holds it as a child).
  private static func find(in controller: UIViewController?) -> FlutterViewController? {
    guard let controller else { return nil }
    if let flutter = controller as? FlutterViewController { return flutter }
    for child in controller.children {
      if let flutter = find(in: child) { return flutter }
    }
    return nil
  }

  private static func report(_ displayed: Bool, in window: UIWindow?) {
    label.accessibilityLabel = "flutterUI: \(displayed ? "displayed" : "not displayed")"
    NSLog(
      "[liquid_shell] example: Flutter UI displayed %d after %.0f ms", displayed ? 1 : 0,
      (CACurrentMediaTime() - launchedAt) * 1000)
    guard let window else { return }
    if label.superview !== window { window.addSubview(label) }
    window.bringSubviewToFront(label)
  }
}

/// UI tests only (LIQUID_SHELL_EXAMPLE_TRACE_NAV): counts the animated
/// stack changes of every navigation controller and shows the count as an
/// accessibility label ("animated stack changes: N"), so a test can tell a
/// restore from a push again (VK-502), which XCUITest cannot see: it waits
/// for animations to end.
enum AnimatedStackTrace {
  static var count = 0
  static let label: UILabel = {
    let label = UILabel(frame: CGRect(x: 0, y: 0, width: 2, height: 2))
    label.textColor = .clear
    label.isUserInteractionEnabled = false
    label.accessibilityIdentifier = "animatedStackChanges"
    return label
  }()

  static func install() {
    guard
      let original = class_getInstanceMethod(
        UINavigationController.self, #selector(UINavigationController.setViewControllers(_:animated:))),
      let traced = class_getInstanceMethod(
        UINavigationController.self, #selector(UINavigationController.traced_setViewControllers(_:animated:)))
    else { return }
    method_exchangeImplementations(original, traced)
  }

  static func record(animated: Bool, in window: UIWindow?) {
    if animated { count += 1 }
    label.accessibilityLabel = "animated stack changes: \(count)"
    guard let window else { return }
    if label.superview !== window { window.addSubview(label) }
    window.bringSubviewToFront(label)
  }
}

extension UINavigationController {
  @objc func traced_setViewControllers(_ controllers: [UIViewController], animated: Bool) {
    AnimatedStackTrace.record(
      animated: animated, in: viewIfLoaded?.window ?? controllers.last?.viewIfLoaded?.window)
    // Swapped: this calls UIKit's original.
    traced_setViewControllers(controllers, animated: animated)
  }
}
