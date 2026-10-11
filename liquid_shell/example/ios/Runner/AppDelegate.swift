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
