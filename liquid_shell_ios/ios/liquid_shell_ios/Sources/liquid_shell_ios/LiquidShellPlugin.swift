import Flutter
import UIKit

/// Streams the accessibility signals liquid_shell needs on iOS over the
/// `vn.lasoai.liquid_shell/signals` event channel (spec §6).
///
/// iOS reports Reduce Transparency only. Battery saver and blur-disabled are
/// always false here: the system's own glass ignores Low Power Mode.
public final class LiquidShellPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var observer: NSObjectProtocol?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterEventChannel(
      name: "vn.lasoai.liquid_shell/signals",
      binaryMessenger: registrar.messenger()
    )
    channel.setStreamHandler(LiquidShellPlugin())
  }

  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    sink = events
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
    if let observer = observer {
      NotificationCenter.default.removeObserver(observer)
    }
    observer = nil
    sink = nil
    return nil
  }

  private func send() {
    sink?([
      "reduceTransparency": UIAccessibility.isReduceTransparencyEnabled,
      "powerSave": false,
      "blurDisabled": false,
    ])
  }
}
