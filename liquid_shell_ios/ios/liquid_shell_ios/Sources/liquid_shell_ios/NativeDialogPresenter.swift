import Flutter
import ObjectiveC
import UIKit

/// Presents native alerts and action sheets for one engine (spec P3a §5).
///
/// It presents in the window of this engine's own Flutter view controller,
/// from the top-most presented view controller, after any transition in
/// flight. Every request ends its Dart future exactly once.
final class NativeDialogPresenter: NSObject, NativeDialogHostApi {
  /// The engine's Flutter view controller, once known.
  private let flutterViewController: () -> UIViewController?
  private let osAtLeast26: () -> Bool
  private let disabledByEnvironment: () -> Bool
  /// Runs a block when a transition ends; false when UIKit did not queue it.
  private let afterTransition: TransitionWait
  /// The newest dialog this presenter shows (debug hooks).
  private weak var current: UIAlertController?
  private var currentCompletion: DialogCompletion?
  private var currentKind: NativeDialogKind = .alert
  /// Every request not yet answered, oldest first: detach answers them all
  /// (two calls in a row stack one alert on another).
  private var pending: [PendingDialog] = []

  init(
    flutterViewController: @escaping () -> UIViewController?,
    osAtLeast26: @escaping () -> Bool = {
      if #available(iOS 26.0, *) { return true } else { return false }
    },
    disabledByEnvironment: @escaping () -> Bool = {
      ProcessInfo.processInfo.environment[InstallPolicy.disableEnvironmentKey] == "1"
    },
    afterTransition: @escaping TransitionWait = { coordinator, then in
      coordinator.animate(alongsideTransition: nil) { _ in then() }
    }
  ) {
    self.flutterViewController = flutterViewController
    self.osAtLeast26 = osAtLeast26
    self.disabledByEnvironment = disabledByEnvironment
    self.afterTransition = afterTransition
  }

  /// Queues a block for the end of a transition. Returns UIKit's answer:
  /// false when the block was not queued and will never run.
  typealias TransitionWait = (
    _ coordinator: UIViewControllerTransitionCoordinator, _ then: @escaping () -> Void
  ) -> Bool

  /// The view controller to present from: follow `presentedViewController`
  /// from [root] while the next one is not leaving.
  static func topmost(from root: UIViewController?) -> UIViewController? {
    var top = root
    while let next = top?.presentedViewController, !next.isBeingDismissed { top = next }
    return top
  }

  // MARK: - NativeDialogHostApi

  func present(
    request: NativeDialogRequest,
    completion: @escaping (Result<NativeDialogResult, Error>) -> Void
  ) {
    let done = DialogCompletion { completion(.success($0)) }
    let flutter = flutterViewController()
    let window = flutter?.viewIfLoaded?.window
    let reason = DialogMath.unavailableReason(
      disabledByEnvironment: disabledByEnvironment(), requireGlass: request.requireGlass,
      osAtLeast26: osAtLeast26(), hasWindow: window != nil)
    // One exit for every "cannot present": no path leaves the future pending.
    guard reason == nil, let flutter, let window else {
      done.finish(.unavailable(reason ?? .noWindow))
      return
    }
    let alert = build(request, sourceView: flutter.view, done: done)
    pending.removeAll { $0.done.isFinished }
    pending.append(PendingDialog(alert: alert, done: done))
    show(alert, kind: request.kind, in: window, done: done, waits: 3)
  }

  func debugCurrent() throws -> NativeDialogSnapshot? {
    #if DEBUG
      guard let alert = current, currentCompletion?.isFinished == false else { return nil }
      let preferred = alert.preferredAction.flatMap { preferred in
        alert.actions.firstIndex { $0 === preferred }
      }
      let source = currentKind == .actionSheet ? alert.popoverPresentationController : nil
      return NativeDialogSnapshot(
        kind: currentKind, title: alert.title, message: alert.message,
        labels: alert.actions.map { $0.title ?? "" },
        preferredIndex: preferred.map(Int64.init),
        sourceRect: source.map {
          NativeRect(
            x: Double($0.sourceRect.minX), y: Double($0.sourceRect.minY),
            width: Double($0.sourceRect.width), height: Double($0.sourceRect.height))
        })
    #else
      return nil
    #endif
  }

  func debugRespond(actionIndex: Int64) throws {
    #if DEBUG
      guard let alert = current, let done = currentCompletion, !done.isFinished else { return }
      let count = alert.actions.count
      // Dismiss first, then answer: a chained dialog from Dart's answer
      // then meets no transition, as after a real tap.
      alert.dismiss(animated: false) {
        if actionIndex >= 0, actionIndex < Int64(count) {
          done.finish(.chose(Int(actionIndex)))
        } else {
          done.finish(.dismissed())
        }
      }
    #endif
  }

  /// Engine detach: nobody will receive an answer. Closes what is shown
  /// and answers every pending request, each once, including one still
  /// waiting for a transition (it is then never shown).
  func dismissAll() {
    let all = pending
    pending = []
    // Dismissing the oldest from its presenter closes those stacked on it.
    for entry in all where !entry.done.isFinished {
      entry.alert?.presentingViewController?.dismiss(animated: false)
    }
    for entry in all { entry.done.finish(.dismissed()) }
    current = nil
    currentCompletion = nil
  }

  // MARK: - Building and showing

  private func build(
    _ request: NativeDialogRequest, sourceView: UIView, done: DialogCompletion
  ) -> UIAlertController {
    let alert = UIAlertController(
      title: request.title, message: request.message,
      preferredStyle: request.kind == .alert ? .alert : .actionSheet)
    for (index, action) in request.actions.enumerated() {
      let item = UIAlertAction(title: action.label, style: Self.style(action.style)) { _ in
        done.finish(.chose(index))
      }
      item.isEnabled = action.enabled
      alert.addAction(item)
    }
    if request.kind == .alert,
      let preferred = DialogMath.preferredIndex(request.preferredIndex, count: alert.actions.count)
    {
      alert.preferredAction = alert.actions[preferred]
    }
    // Ends the future when the alert goes without an answer (spec §5.4).
    let lifetime = DialogLifetime(done)
    objc_setAssociatedObject(
      alert, &DialogLifetime.key, lifetime, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    if let popover = alert.popoverPresentationController {
      popover.sourceView = sourceView
      let anchor = request.anchor.map {
        CGRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height)
      }
      if let rect = DialogMath.sourceRect(anchor: anchor, in: sourceView.bounds) {
        popover.sourceRect = rect
      } else {
        let bounds = sourceView.bounds
        popover.sourceRect = CGRect(x: bounds.midX, y: bounds.midY, width: 0, height: 0)
        popover.permittedArrowDirections = []
      }
      popover.delegate = lifetime
    }
    alert.view.tintColor = UIColor(argb: request.tintArgb)
    alert.overrideUserInterfaceStyle = request.dark ? .dark : .light
    if request.rtl {
      if #available(iOS 17.0, *) {
        alert.traitOverrides.layoutDirection = .rightToLeft
      } else {
        alert.view.semanticContentAttribute = .forceRightToLeft
      }
    }
    return alert
  }

  /// Presents [alert] from the top of [window], after any presentation or
  /// dismissal in flight: UIKit refuses a present during one (spec §5.1).
  private func show(
    _ alert: UIAlertController, kind: NativeDialogKind, in window: UIWindow,
    done: DialogCompletion, waits: Int
  ) {
    // Answered while waiting for a transition (detach): never shown.
    guard !done.isFinished else { return }
    guard let top = Self.topmost(from: window.rootViewController) else {
      done.finish(.unavailable(.noWindow))
      return
    }
    if waits > 0,
      let coordinator = top.presentedViewController?.transitionCoordinator
        ?? top.transitionCoordinator
    {
      let retry = { [weak self, weak window] in
        guard let self, let window else {
          done.finish(.unavailable(.noWindow))
          return
        }
        self.show(alert, kind: kind, in: window, done: done, waits: waits - 1)
      }
      // A cancelled transition still runs the block; the retry then finds
      // the new top. When UIKit does not queue it at all, the block would
      // never run and the alert, unshown, would answer "dismissed": retry
      // once the transition's time is up instead. Out of waits, `present`
      // either shows the alert or is refused, and Dart falls back.
      if !afterTransition(coordinator, retry) {
        DispatchQueue.main.asyncAfter(
          deadline: .now() + coordinator.transitionDuration, execute: retry)
      }
      return
    }
    top.present(alert, animated: true)
    guard alert.presentingViewController != nil else {
      // Refused: Dart draws its own dialog instead.
      done.finish(.unavailable(.refused))
      return
    }
    current = alert
    currentCompletion = done
    currentKind = kind
  }

  private static func style(_ style: NativeDialogActionStyle) -> UIAlertAction.Style {
    switch style {
    case .standard: return .default
    case .cancel: return .cancel
    case .destructive: return .destructive
    }
  }
}

/// A request [NativeDialogPresenter] has not answered yet.
private struct PendingDialog {
  weak var alert: UIAlertController?
  let done: DialogCompletion
}

/// Attached to the alert (spec §5.4). It answers `dismissed` when a popover
/// is dismissed by a tap outside, and when the alert is released without
/// an answer (dismissed by someone else).
final class DialogLifetime: NSObject, UIPopoverPresentationControllerDelegate {
  static var key: UInt8 = 0
  private let done: DialogCompletion

  init(_ done: DialogCompletion) {
    self.done = done
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    done.finish(.dismissed())
  }

  deinit {
    done.finish(.dismissed())
  }
}
