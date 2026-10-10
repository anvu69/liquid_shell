import Flutter
import UIKit

/// The window's real root ("approach C", spec §5.2). Two children:
///
/// 1. the `FlutterViewController`, whose view sits at the bottom and never
///    changes parent or leaves the window, so Flutter never sees
///    `inactive`/`hidden`/`paused` when a tab changes;
/// 2. the `NativeTabsController`, transparent, covering everything; touches
///    on its background fall through to Flutter (`PassThroughView`).
@available(iOS 26.0, *)
final class ShellContainerController: UIViewController {
  let tabs: NativeTabsController
  /// The Flutter view controller (`UIViewController`: see `NativeTabsController.flutter`).
  let flutter: UIViewController

  init(tabs: NativeTabsController, flutter: UIViewController) {
    self.tabs = tabs
    self.flutter = flutter
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  override func loadView() {
    let root = PassThroughView()
    root.shell = tabs
    root.flutterView = flutter.view
    view = root
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    addChild(flutter)
    flutter.view.frame = view.bounds
    view.addSubview(flutter.view)
    flutter.didMove(toParent: self)

    addChild(tabs)
    tabs.view.frame = view.bounds
    tabs.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(tabs.view)
    tabs.didMove(toParent: self)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    // While the chrome is hidden no host lays out; keep Flutter full size.
    tabs.syncFlutter()
  }

  // Status bar, home indicator, edge gestures and rotation: Flutter decides,
  // as when it was the root.
  override var childForStatusBarStyle: UIViewController? { flutter }
  override var childForStatusBarHidden: UIViewController? { flutter }
  override var childForHomeIndicatorAutoHidden: UIViewController? { flutter }
  override var childForScreenEdgesDeferringSystemGestures: UIViewController? { flutter }
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    flutter.supportedInterfaceOrientations
  }
}
