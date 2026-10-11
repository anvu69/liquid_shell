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
