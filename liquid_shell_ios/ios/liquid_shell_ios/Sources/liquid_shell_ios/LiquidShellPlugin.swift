import Flutter
import UIKit

/// The iOS side of liquid_shell.
///
/// - Streams Reduce Transparency over the `vn.lasoai.liquid_shell/signals`
///   event channel (spec P1 §6). Battery saver and blur-disabled are always
///   false here: the system's own glass ignores Low Power Mode.
/// - Installs the native iPadOS 26 shell and answers the Pigeon channel
///   (`NativeShellInstaller`, spec P2 §5).
public final class LiquidShellPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var observer: NSObjectProtocol?
  private var installer: NativeShellInstaller?

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
      ownViewController: { [weak registrar] in registrar?.viewController })
    NativeShellHostApiSetup.setUp(binaryMessenger: messenger, api: installer)
    installer.start()
    plugin.installer = installer
    registrar.publish(plugin)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    installer?.stop()
    NativeShellHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: nil)
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
