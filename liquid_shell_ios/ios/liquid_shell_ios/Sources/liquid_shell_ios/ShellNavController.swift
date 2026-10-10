import UIKit

/// The clear navigation controller of a tab with a native navigation bar
/// (spec P3b §7.1; P3b-1: the search tab). Its pages are clear
/// `PageHostController`s that mirror the tab's Flutter pages; the Flutter
/// view stays underneath and never moves.
@available(iOS 26.0, *)
final class ShellNavController: UINavigationController {
  /// iPhone, a page pushed inside the search tab: whether it hides the tab
  /// bar and the tab-hosted field (probe P2, Q19). docs/qa/p3b/probe.md:
  /// no. With UIKit's default the field and the collapsed circle leave the
  /// pushed page and the full compact bar comes back under it.
  static var hidesBarWhenPushed = false

  let rootHost: PageHostController

  init(root: PageHostController) {
    rootHost = root
    super.init(nibName: nil, bundle: nil)
    setViewControllers([root], animated: false)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    navigationBar.prefersLargeTitles = true
    // Q14: Flutter owns the swipe-back in P3b-1; the native bar follows
    // when the Flutter route commits (spec §7.6).
    interactivePopGestureRecognizer?.isEnabled = false
    interactiveContentPopGestureRecognizer?.isEnabled = false
  }
}

/// One clear page of a `ShellNavController`: a title for the native bar
/// over the Flutter page of the same depth. Reports layout to the shell as
/// `TabHostController` does.
@available(iOS 26.0, *)
final class PageHostController: UIViewController {
  private var shell: NativeTabsController? { tabBarController as? NativeTabsController }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    shell?.syncFlutter()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    shell?.syncFlutter()
  }

  override func viewSafeAreaInsetsDidChange() {
    super.viewSafeAreaInsetsDidChange()
    shell?.syncFlutter()
  }

  /// The search tab's root: host the search controller.
  func installSearch(_ bridge: SearchBridge, style: SearchTabStyle) {
    navigationItem.searchController = bridge.controller
    applySearchStyle(style)
  }

  func applySearchStyle(_ style: SearchTabStyle) {
    navigationItem.preferredSearchBarPlacement =
      style.placement == .stacked ? .stacked : .automatic
    if let hides = style.hidesWhenScrolling { navigationItem.hidesSearchBarWhenScrolling = hides }
    navigationItem.largeTitleDisplayMode = style.largeTitle ? .always : .never
  }
}
