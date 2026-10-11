import Flutter
import UIKit

/// The iOS side of liquid_shell.
///
/// - Streams Reduce Transparency over the `vn.lasoai.liquid_shell/signals`
///   event channel (spec P1 §6). Battery saver and blur-disabled are always
///   false here: the system's own glass ignores Low Power Mode.
/// - Installs the native iPadOS 26 shell and answers the Pigeon channel
///   (`NativeShellInstaller`, spec P2 §5).
/// - Presents native alerts and action sheets (`NativeDialogPresenter`, spec P3a §5).
public final class LiquidShellPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var observer: NSObjectProtocol?
  private var installer: NativeShellInstaller?
  /// Readable by the example's XCTests (`@testable`): the engine-teardown test.
  private(set) var dialogs: NativeDialogPresenter?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = LiquidShellPlugin()
    let channel = FlutterEventChannel(
      name: "vn.lasoai.liquid_shell/signals",
      binaryMessenger: registrar.messenger()
    )
    channel.setStreamHandler(plugin)

    let messenger = registrar.messenger()
    let installer = NativeShellInstaller(
      events: NativeShellFlutterApi(binaryMessenger: messenger),
      ownViewController: { [weak registrar] in registrar?.viewController },
      // Weak: the engine keeps the plugin, the plugin the installer.
      ownsFlutter: { [weak plugin] flutter in
        plugin.map { LiquidShellPlugin.owns(flutter, plugin: $0) } ?? false
      })
    NativeShellHostApiSetup.setUp(binaryMessenger: messenger, api: installer)
    installer.start()
    plugin.installer = installer
    let dialogs = NativeDialogPresenter(
      flutterViewController: { [weak registrar] in registrar?.viewController })
    NativeDialogHostApiSetup.setUp(binaryMessenger: messenger, api: dialogs)
    plugin.dialogs = dialogs
    registrar.publish(plugin)
  }

  /// The key the plugin registrant registers this plugin under.
  static let registrarKey = "LiquidShellPlugin"

  /// Whether [flutter] is a view controller of the engine that [plugin]
  /// registered with: that engine published [plugin] under
  /// [registrarKey]. Unlike `registrar.viewController`, this is known when
  /// the scene connects, so a second engine (headless, add-to-app) never
  /// claims another engine's scene.
  static func owns(_ flutter: UIViewController, plugin: LiquidShellPlugin) -> Bool {
    guard let registry = flutter as? FlutterPluginRegistry else { return false }
    return registry.valuePublished(byPlugin: registrarKey) === plugin
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    installer?.stop()
    NativeShellHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
    dialogs?.dismissAll()
    NativeDialogHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
    removeObserver()
  }

  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    sink = events
    removeObserver()
    observer = NotificationCenter.default.addObserver(
      forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.send()
    }
    send()
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    removeObserver()
    sink = nil
    return nil
  }

  private func removeObserver() {
    if let observer = observer {
      NotificationCenter.default.removeObserver(observer)
    }
    observer = nil
  }

  private func send() {
    sink?([
      "reduceTransparency": UIAccessibility.isReduceTransparencyEnabled,
      "powerSave": false,
      "blurDisabled": false,
    ])
  }
}
