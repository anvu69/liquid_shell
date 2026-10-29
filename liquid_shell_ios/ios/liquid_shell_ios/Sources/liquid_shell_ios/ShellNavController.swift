import UIKit

/// The clear navigation controller of every destination tab (spec P3b
/// §7.1; P3b-2 §6.1). Its pages are clear `PageHostController`s that
/// mirror the tab's Flutter pages; the Flutter view stays underneath and
/// never moves. A plain tab hides its bar while it has no title to show
/// (`PageTitleMath.barHidden`); the search tab's holds the field and
/// always shows.
@available(iOS 26.0, *)
final class ShellNavController: UINavigationController {
  /// iPhone, a page pushed inside the search tab: whether it hides the tab
  /// bar and the tab-hosted field (probe P2, Q19). docs/qa/p3b/probe.md:
  /// no. With UIKit's default the field and the collapsed circle leave the
  /// pushed page and the full compact bar comes back under it.
  static var hidesBarWhenPushed = false

  let rootHost: PageHostController
  /// The search tab's: its bar is never hidden, its root's title mode is
  /// `SearchMath.style`'s, and its pages do not minimize the tab bar.
  let isSearch: Bool

  /// [root] is built with the tabs and kept for their life. A plain tab
  /// starts with its bar hidden: it has no pages yet.
  init(root: PageHostController, search: Bool) {
    rootHost = root
    isSearch = search
    super.init(nibName: nil, bundle: nil)
    setViewControllers([root], animated: false)
    if !search { setNavigationBarHidden(true, animated: false) }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  /// The page hosts, root first.
  var hosts: [PageHostController] { viewControllers.compactMap { $0 as? PageHostController } }

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
  /// route and the next stack pops here. Animated only when [shown]: the
  /// tab is selected and stays so (VK-502). A stack applied with the config
  /// that selects the tab, or leaves it, is a restore, set without a
  /// transition. The window does not tell: UIKit keeps a tab just left in
  /// it for a while (iOS 26.5), and longer after a transition ran as the
  /// tab went. Title modes and a plain tab's bar follow the title table
  /// (`PageTitleMath`, spec P3b-2 §4.2) at UIKit's size class [compact].
  func applyPages(
    _ pages: [NativePage], rootTitle: String, tabIndex: Int, shown: Bool, compact: Bool,
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
    // Read before this config: whether the root's large title showed.
    let hadLargeTitle =
      !isNavigationBarHidden && rootHost.navigationItem.largeTitleDisplayMode == .always
    rootHost.title = wanted[0].title
    if !isSearch {
      rootHost.navigationItem.largeTitleDisplayMode = PageTitleMath.rootMode(
        largeTitle: wanted[0].largeTitle, compact: compact)
    }
    var hosts = self.hosts
    if hosts.count > wanted.count { hosts = Array(hosts.prefix(wanted.count)) }
    while hosts.count < wanted.count {
      // A plain tab's pushed pages minimize the tab bar too (spec P3b-2
      // §6.8); the search tab's never do (VK-600 Q5).
      let host = PageHostController(minimizes: !isSearch)
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
      host.navigationItem.largeTitleDisplayMode = PageTitleMath.pushedMode
    }
    let animated =
      shown && viewIfLoaded?.window != nil && !UIAccessibility.isReduceMotionEnabled
    let hideBar = !isSearch && PageTitleMath.barHidden(pages: pages, compact: compact)
    if isNavigationBarHidden != hideBar { setNavigationBarHidden(hideBar, animated: animated) }
    // UIKit keeps a large title collapsed when it turns on, or its bar
    // shows, while the root is on screen (VK-441): pull it out once the bar
    // has finished showing. Only for a root that stays on top.
    if !isSearch, !hadLargeTitle, wanted.count == 1, !isNavigationBarHidden,
      rootHost.navigationItem.largeTitleDisplayMode == .always
    {
      rootHost.revealLargeTitle(
        after: animated ? TimeInterval(UINavigationController.hideShowBarDuration) : 0)
    }
    guard hosts.map(ObjectIdentifier.init) != viewControllers.map(ObjectIdentifier.init) else {
      return
    }
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

  /// The tab bar's minimize proxy (spec VK-600 §8.2, P3b-2 §6.8): this
  /// page's `.bottom` content scroll view, so UIKit's tab bar follows the
  /// top page of a plain tab. nil on the search tab, which never
  /// minimizes (VK-600 Q5).
  let minimizeProxy: MinimizeProxy?

  init(minimizes: Bool) {
    minimizeProxy = minimizes ? MinimizeProxy() : nil
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  /// A host goes (a pop, a rebuild, the shell's release) while its pan may
  /// still be on the Flutter view, which outlives it: take it back first,
  /// as `TabHostController` does (Swift 5 mode, see its `deinit`).
  deinit {
    if let minimizeProxy { minimizeProxy.addGestureRecognizer(minimizeProxy.panGestureRecognizer) }
  }

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
  /// A reveal (`revealLargeTitle`) is under way: Flutter's offset waits for
  /// its end, and the expanded top is not learned from the collapsed bar.
  private var revealing = false
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
    // A reveal puts the proxy back at this offset when it ends.
    guard !revealing else { return }
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
    if offset <= 0, !revealing, !(navigationItem.searchController?.isActive ?? false) {
      expandedTop = view.safeAreaInsets.top
    }
  }

  /// How far past rest `revealLargeTitle` pulls the proxy: more than the
  /// large title's 52 pt row. 100 pt brought the title out on the iPhone 17
  /// Pro, iOS 26.5 and 27.0 (probe P17a), 60 pt did too (P11); at rest, or
  /// pre-set to rest, nothing does (P1, P6). docs/qa/p3b2/measure.md, "M5:
  /// a large title that turns on on screen".
  static let largeTitlePull: CGFloat = 100

  /// Brings out a large title UIKit keeps collapsed (VK-441). When a page's
  /// mode becomes `.always`, or its bar shows with it, while the page is on
  /// top in a window and the proxy rests at the top, UIKit lays the bar out
  /// collapsed and keeps it so (iOS 26.5 and 27.0 alike); a pull past rest
  /// brings the title out, as on a real scroll view. So, [delay] seconds
  /// from now (the bar's show animation): lay out, pull, and on the next
  /// run-loop turn put the proxy back at Flutter's offset. Off screen UIKit
  /// lays the title out by itself (P2); scrolled, or under an active
  /// search, a collapsed title is right.
  func revealLargeTitle(after delay: TimeInterval = 0) {
    guard !revealing, isOnTopInAWindow, offset <= 0,
      !(navigationItem.searchController?.isActive ?? false)
    else { return }
    revealing = true
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
      guard let self else { return }
      if self.offset <= 0, self.isOnTopInAWindow {
        self.navigationController?.view.layoutIfNeeded()
        self.proxy.contentOffset.y =
          -self.proxy.adjustedContentInset.top - PageHostController.largeTitlePull
      }
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.revealing = false
        self.navigationController?.view.layoutIfNeeded()
        self.rereadRestingTop()
        self.setScrollOffset(self.offset)
        self.shell?.syncFlutter()
      }
    }
  }

  private var isOnTopInAWindow: Bool {
    viewIfLoaded?.window != nil && navigationController?.topViewController === self
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    registerForTraitChanges([UITraitHorizontalSizeClass.self]) { (host: Self, _) in
      host.updateTitleItem()
    }
    view.backgroundColor = .clear
    proxy.frame = view.bounds
    proxy.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    proxy.isUserInteractionEnabled = false
    proxy.backgroundColor = .clear
    proxy.showsVerticalScrollIndicator = false
    proxy.contentInsetAdjustmentBehavior = .always
    proxy.contentSize = CGSize(width: 1, height: 100_000)
    // Spec VK-600 §8.4 (Q10): iOS scrolls to the top on a status-bar tap
    // only while one scroll view on screen may; that one is Flutter's.
    proxy.scrollsToTop = false
    proxy.isAccessibilityElement = false
    proxy.accessibilityElementsHidden = true
    view.addSubview(proxy)
    setContentScrollView(proxy, for: .top)
    if let minimizeProxy {
      minimizeProxy.frame = view.bounds
      minimizeProxy.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      view.addSubview(minimizeProxy)
      setContentScrollView(minimizeProxy, for: .bottom)
    }
  }

  override func viewIsAppearing(_ animated: Bool) {
    super.viewIsAppearing(animated)
    shell?.syncFlutter()
  }

  /// UIKit presents the search only from a root in a window: an activation
  /// it refused before is applied once the root has appeared, after the
  /// appearance transition, not inside it (VK-634).
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    shell?.searchRootAppeared(self)
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
    // `.inline` on an iPhone: the large title on the bar row, right under
    // the status bar, as Apple Music draws it; `.always` adds a 52pt row.
    let hadLargeTitle = navigationItem.largeTitleDisplayMode == .always
    navigationItem.largeTitleDisplayMode = style.titleMode
    wantsTitleItem = style.titleItem
    // The search root's mode changes in place too (VK-441, probe P15).
    if !hadLargeTitle, style.titleMode == .always { revealLargeTitle() }
  }

  /// Whether the small title is a leading item (an iPad's search root,
  /// spec §7.2): shown at compact width, where Apple Music puts "Search"
  /// right of the window controls with the field on the row below. At
  /// regular width the top tab bar names the tab.
  private var wantsTitleItem = false {
    didSet { updateTitleItem() }
  }

  private var titleLabel: UILabel?

  override var title: String? {
    didSet { titleLabel?.text = title }
  }

  private func updateTitleItem() {
    guard wantsTitleItem, traitCollection.horizontalSizeClass == .compact else {
      if navigationItem.leftBarButtonItem != nil { navigationItem.leftBarButtonItem = nil }
      titleLabel = nil
      return
    }
    guard titleLabel == nil else { return }
    let label = UILabel()
    label.text = title
    label.font = .preferredFont(forTextStyle: .headline)
    label.adjustsFontForContentSizeCategory = true
    label.accessibilityTraits = .header
    let item = UIBarButtonItem(customView: label)
    // Text, not a button: no glass platter behind it.
    item.hidesSharedBackground = true
    titleLabel = label
    navigationItem.leftBarButtonItem = item
  }
}
