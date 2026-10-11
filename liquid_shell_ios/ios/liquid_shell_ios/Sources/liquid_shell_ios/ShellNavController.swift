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

  /// Dart's answer to every pop UIKit starts by itself (spec P3b §7.6):
  /// the page index that should end on top. Set by `applyPages`.
  private var proposePop: ((Int) -> Void)?

  // UIKit pops without the back button's `backAction` from its long-press
  // menu (`_tryRequestPopToItem` → `popToViewController`), an
  // accessibility escape or a keyboard back (`popViewController`) and a
  // pop-to-root. Each is a proposal here, as the back tap is: native keeps
  // its stack, Dart pops the Flutter pages (their PopScope runs), and the
  // next config pops natively through `setViewControllers`. Popping here
  // would leave Flutter on the old page with no back button.

  override func popViewController(animated: Bool) -> UIViewController? {
    guard proposePop != nil, viewControllers.count > 1 else {
      return super.popViewController(animated: animated)
    }
    proposePop?(viewControllers.count - 2)
    return nil
  }

  override func popToViewController(
    _ viewController: UIViewController, animated: Bool
  ) -> [UIViewController]? {
    guard proposePop != nil, let index = viewControllers.firstIndex(of: viewController) else {
      return super.popToViewController(viewController, animated: animated)
    }
    if index < viewControllers.count - 1 { proposePop?(index) }
    return []
  }

  override func popToRootViewController(animated: Bool) -> [UIViewController]? {
    guard proposePop != nil else { return super.popToRootViewController(animated: animated) }
    if viewControllers.count > 1 { proposePop?(0) }
    return []
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    navigationBar.prefersLargeTitles = true
    // Q14: Flutter owns the swipe-back in P3b-1; the native bar follows
    // when the Flutter route commits (spec §7.6).
    interactivePopGestureRecognizer?.isEnabled = false
    interactiveContentPopGestureRecognizer?.isEnabled = false
  }

  /// Mirrors the tab's Flutter pages (spec §7.6): push for a longer stack,
  /// pop for a shorter one, retitle in place. The root's title is the first
  /// page's, or the destination's label without pages. Each pushed page's
  /// back button only proposes (`onBackTapped`); Dart pops the Flutter
  /// route and the next stack pops here.
  func applyPages(
    _ pages: [NativePage], rootTitle: String, tabIndex: Int,
    events: NativeShellFlutterApiProtocol
  ) {
    let wanted = pages.isEmpty ? [NativePage(title: rootTitle, largeTitle: nil)] : pages
    proposePop = { index in
      events.onPopToPage(tab: Int64(tabIndex), index: Int64(index)) { result in
        #if DEBUG
          if case .failure(let error) = result {
            NSLog("[liquid_shell] sending onPopToPage to Dart failed: %@", String(describing: error))
          }
        #endif
      }
    }
    rootHost.title = wanted[0].title
    var hosts = viewControllers.compactMap { $0 as? PageHostController }
    if hosts.count > wanted.count { hosts = Array(hosts.prefix(wanted.count)) }
    while hosts.count < wanted.count {
      let host = PageHostController()
      host.hidesBottomBarWhenPushed = Self.hidesBarWhenPushed
      host.onBack = {
        events.onBackTapped(tab: Int64(tabIndex)) { result in
          #if DEBUG
            if case .failure(let error) = result {
              NSLog("[liquid_shell] sending onBackTapped to Dart failed: %@", String(describing: error))
            }
          #endif
        }
      }
      hosts.append(host)
    }
    for (host, page) in zip(hosts, wanted).dropFirst() {
      host.title = page.title
      host.navigationItem.largeTitleDisplayMode = (page.largeTitle ?? false) ? .always : .never
    }
    guard hosts.map(ObjectIdentifier.init) != viewControllers.map(ObjectIdentifier.init) else {
      return
    }
    let animated = viewIfLoaded?.window != nil && !UIAccessibility.isReduceMotionEnabled
    setViewControllers(hosts, animated: animated)
    // Spec §7.9: once more when the push or pop ends, so Flutter ends on the
    // new top page's insets. Without an animation the shell syncs at the end
    // of `apply`.
    transitionCoordinator?.animate(alongsideTransition: nil) { [weak self] _ in
      (self?.tabBarController as? NativeTabsController)?.syncFlutter()
    }
  }
}

/// One clear page of a `ShellNavController`: a title for the native bar
/// over the Flutter page of the same depth. Reports layout to the shell as
/// `TabHostController` does.
@available(iOS 26.0, *)
final class PageHostController: UIViewController {
  private var shell: NativeTabsController? { tabBarController as? NativeTabsController }

  /// Invisible scroll view UIKit reads for the large title's collapse and
  /// the scroll-edge effect, moved by code from Flutter's scroll offset
  /// (spec §7.7; research §4.1).
  let proxy = UIScrollView()
  /// Flutter's held top: the top safe-area inset with the proxy at rest,
  /// re-read on purpose when the search's active state changes.
  private(set) var restingTop: CGFloat = 0
  /// The proxy's base (spec §7.7): the top inset at offset 0 with the
  /// search inactive, i.e. with the large title out. Never force-read: an
  /// active search hides the title on purpose, and the title must come back
  /// after it.
  private(set) var expandedTop: CGFloat = 0
  private var offset: Double = 0
  /// The native back button's proposal (set for pushed pages).
  var onBack: (() -> Void)? {
    didSet {
      navigationItem.backAction = onBack.map { back in UIAction { _ in back() } }
    }
  }

  /// Flutter's top inset for this page: held while scrolled.
  var flutterTop: CGFloat {
    SearchMath.heldTop(current: view.safeAreaInsets.top, resting: restingTop, scrolled: offset > 0)
  }

  func setScrollOffset(_ value: Double) {
    loadViewIfNeeded()
    offset = max(0, value)
    // From the expanded top, not the current inset: once the title has
    // collapsed the proxy's inset is the small bar's, and offset 0 must pull
    // the large title back out, as a real scroll view does.
    let top = max(expandedTop, proxy.adjustedContentInset.top)
    proxy.contentOffset.y = -top + CGFloat(offset)
  }

  /// Re-reads the resting top: at rest, or always with [force] (a search
  /// activation hides the large title on purpose; that is not a scroll).
  /// The expanded top only at rest with the search inactive.
  func rereadRestingTop(force: Bool = false) {
    if force || offset <= 0 { restingTop = view.safeAreaInsets.top }
    if offset <= 0, !(navigationItem.searchController?.isActive ?? false) {
      expandedTop = view.safeAreaInsets.top
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    proxy.frame = view.bounds
    proxy.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    proxy.isUserInteractionEnabled = false
    proxy.backgroundColor = .clear
    proxy.showsVerticalScrollIndicator = false
    proxy.contentInsetAdjustmentBehavior = .always
    proxy.contentSize = CGSize(width: 1, height: 100_000)
    view.addSubview(proxy)
    setContentScrollView(proxy, for: .top)
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
    rereadRestingTop()
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
    // `.inline`: the large title on the bar row, right under the status
    // bar, as Apple Music draws it; `.always` adds a 52pt row under the bar.
    navigationItem.largeTitleDisplayMode = style.largeTitle ? .inline : .never
  }
}
