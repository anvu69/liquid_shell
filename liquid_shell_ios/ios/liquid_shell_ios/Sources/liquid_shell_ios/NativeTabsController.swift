import Flutter
import UIKit

/// The transparent `UITabBarController(.tabSidebar)` over the Flutter view
/// (spec §5): tab bar, sidebar toggle, sidebar, trailing action and footer
/// are real UIKit. Regular width shows the top bar and the sidebar; compact
/// width (every iPhone, a narrow iPad window) shows UIKit's floating tab
/// bar at the bottom (owner D1).
///
/// Sources of truth: Dart owns the selection (a tap only proposes it,
/// `onDestinationTapped`, and Dart answers with `update`); UIKit owns the
/// sidebar (shown/hidden, overlay/tiled) and the size class, pushed to Dart
/// with `onStateChanged`.
@available(iOS 26.0, *)
final class NativeTabsController: UITabBarController, UITabBarControllerDelegate,
  UITabBarController.Sidebar.Delegate
{
  /// The Flutter view controller. Only its view and safe area are touched,
  /// so `UIViewController` is enough, and tests host the shell without an
  /// engine.
  let flutter: UIViewController
  private let events: NativeShellFlutterApiProtocol

  private var destinationTabs: [UITab] = []
  /// The trailing action: a search-role tab, the separate ⌕ at the end of
  /// the compact bar, the trailing end of the top bar, the first sidebar
  /// row. It is never selected (`shouldSelectTab`).
  private var trailingTab: UISearchTab?
  /// The search destination (role search): UIKit's search tab, hosting the
  /// search field (spec P3b §7). nil without one.
  private(set) var searchTab: UISearchTab?
  /// Its index in Dart's destinations.
  private(set) var searchIndex: Int?
  /// Tabs with a native navigation bar, by destination index (P3b-1: the
  /// search tab only).
  private(set) var navControllers: [Int: ShellNavController] = [:]
  /// The host of every non-search destination, by index: its proxy takes
  /// Dart's minimize offset (spec VK-600 §8.2). Built with the tabs.
  private var minimizeHosts: [Int: TabHostController] = [:]
  /// The search field and its delegates; one per shell, re-hosted when the
  /// tabs are rebuilt.
  let searchBridge = SearchBridge()
  /// Dart's text sent while another tab is selected: applied when the
  /// search tab is (spec §7.4).
  private var heldSearchText: String?
  /// Dart's scope sent while another tab is selected, likewise (spec
  /// VK-550 §10.2).
  private var heldSearchScope: Int?
  /// Per destination 0 fixed, 1 sidebar-only, 2 search; plus 1 when there
  /// is a trailing action: a change rebuilds the tabs.
  private var structure: [Int] = []
  private let footer = SidebarFooterView()

  /// The last config from Dart; nil until the first `update`.
  private(set) var config: NativeChromeConfig?

  /// True while Dart's selection is applied: `didSelectTab` also fires for
  /// programmatic changes.
  private var applyingFromDart = false

  /// `safe.top` while the sidebar did not overlay: kept while it does, so
  /// the content under the dimming view does not jump up.
  private var heldTop: CGFloat = 0
  /// Whether Dart attached. Before that, state and window-control sends
  /// have no receiver and only fail; `attach` returns the state, and Dart
  /// reads the window controls itself.
  var dartAttached = false
  private var lastState: NativeShellState?
  private var lastControls: (leading: Double, top: Double)?
  /// Reads the window controls from the Flutter view. Injectable for tests.
  var readWindowControls: (UIView?) -> NativeWindowControls = { WindowControlsReader.read($0) }
  private var rereadScheduled = false

  init(flutter: UIViewController, events: NativeShellFlutterApiProtocol) {
    self.flutter = flutter
    self.events = events
    super.init(nibName: nil, bundle: nil)
    mode = .tabSidebar
    delegate = self
    sidebar.delegate = self
    searchBridge.canReport = { [weak self] in
      guard let self else { return false }
      return self.isSearchSelected && !self.applyingFromDart
    }
    // Kept only where `setSearchActive` would apply it: the search tab
    // selected, the chrome shown, no page over the search root (VK-634).
    searchBridge.canKeepActivation = { [weak self] in
      guard let self else { return false }
      return self.isSearchSelected && self.chromeVisible && self.isSearchRootOnTop
    }
    searchBridge.onText = { [weak self] text, composing in
      self?.send("onSearchTextChanged") {
        self?.events.onSearchTextChanged(text: text, composing: composing, completion: $0)
      }
    }
    searchBridge.onActive = { [weak self] active in
      self?.send("onSearchActiveChanged") {
        self?.events.onSearchActiveChanged(active: active, completion: $0)
      }
      if let self, let index = self.searchIndex { self.topHost(ofTab: index)?.rereadRestingTop(force: true) }
      self?.syncFlutter()
    }
    searchBridge.onSubmit = { [weak self] text in
      self?.send("onSearchSubmitted") { self?.events.onSearchSubmitted(text: text, completion: $0) }
    }
    searchBridge.onScope = { [weak self] index in
      self?.send("onSearchScopeChanged") {
        self?.events.onSearchScopeChanged(index: Int64(index), completion: $0)
      }
      // UIKit keeps the keyboard up on a scope tap (measured, iOS 26.5):
      // put it away and keep the search, as Flutter's scope bar does
      // (VK-571).
      self?.dismissSearchKeyboard()
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { nil }

  /// Compact: UIKit's floating tab bar at the bottom, no top bar, no
  /// sidebar. Every iPhone, also at a regular size class (a Plus or Max
  /// iPhone, or the iPhone Air, in landscape: UIKit keeps the bottom bar
  /// there), and an iPad window of compact width. The one signal for the
  /// tabs shown, the sidebar, the state sent to Dart and the window
  /// controls.
  var isCompact: Bool {
    traitCollection.userInterfaceIdiom == .phone || traitCollection.horizontalSizeClass == .compact
  }

  /// Whether the chrome is on screen: a shell engaged it and nothing hides it.
  var chromeVisible: Bool {
    guard let config else { return false }
    return config.engaged && !config.hidden
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    view.isHidden = true
    footer.onTap = { [weak self] in self?.footerTapped() }
    // The iPhone field rides on the keyboard: publish its end position.
    for name in [
      UIResponder.keyboardDidChangeFrameNotification, UIResponder.keyboardDidHideNotification,
    ] {
      keyboardObservers.append(
        NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
          [weak self] _ in self?.publishSearchField()
        })
    }
    registerForTraitChanges([UITraitHorizontalSizeClass.self]) {
      (self: NativeTabsController, _: UITraitCollection) in
      // Dormant (no tabs in the config): leave UIKit's tabs and selection
      // alone, as `apply` does.
      if let config = self.config, !config.tabs.isEmpty {
        self.showTabs(config)
        self.select(Int(config.selectedIndex))
      }
      // Regular takes the pan back and resets the proxies; compact again
      // puts it back (spec VK-600 §8.3).
      self.updateMinimizePan()
      // Defensive: the layout pass that follows a size-class change syncs
      // too (`viewDidLayoutSubviews`), and no test tells the two apart.
      self.syncFlutter()
    }
  }

  deinit {
    for observer in keyboardObservers { NotificationCenter.default.removeObserver(observer) }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    syncFlutter()
  }

  // MARK: - Dart → native

  /// Applies a whole config in a fixed order: tabs, selection, footer,
  /// style (tint, appearance, direction), interaction, then visibility
  /// (spec §5.5).
  func apply(_ new: NativeChromeConfig) {
    loadViewIfNeeded()
    let wasVisible = chromeVisible
    // Read before `config` changes: once the new config hides the chrome,
    // `currentSidebar()` reports `.hidden` and an open overlay is missed.
    let overlayOpen = currentSidebar() == .overlay
    // The dormant config has no tabs: it hides the chrome and leaves the
    // tabs alone. Emptied and refilled, UIKit brought the compact bar back
    // hidden, with no bar in the host's safe area (iOS 26.5).
    if !new.tabs.isEmpty {
      rebuildTabsIfNeeded(new)
      for (tab, spec) in zip(destinationTabs, new.tabs) {
        tab.title = spec.title
        // A search tab without a symbol keeps the system's magnifying glass.
        tab.image = UIImage(
          systemName: spec.search && spec.sfSymbol.isEmpty ? "magnifyingglass" : spec.sfSymbol)
        tab.badgeValue = spec.badge
      }
      if let tab = trailingTab, let action = new.trailing {
        tab.title = action.title
        tab.image = UIImage(systemName: action.sfSymbol)
      }
      showTabs(new)
      applySearch(new)
      for (index, nav) in navControllers where new.tabs.indices.contains(index) {
        nav.applyPages(
          new.tabs[index].pages, rootTitle: new.tabs[index].title, tabIndex: index,
          // Before `select`: the tab shown now, and still after it.
          shown: selectedViewController === nav && Int(new.selectedIndex) == index,
          events: events)
      }
      // A page pushed over the search root drops a kept activation: the
      // pop back must not bring the search (VK-634, `isSearchRootOnTop`).
      if !isSearchRootOnTop { searchBridge.dropPendingActivation() }
      select(Int(new.selectedIndex))
    }
    setFooter(new.footer)
    let behavior: UITabBarController.MinimizeBehavior = new.minimizeOnScroll ? .onScrollDown : .never
    if tabBarMinimizeBehavior != behavior { tabBarMinimizeBehavior = behavior }
    // Q14: the policy is `MinimizeProxy.hidesBottomEdgeEffect`'s.
    let hidesEdge = MinimizeProxy.hidesBottomEdgeEffect(minimizeOnScroll: new.minimizeOnScroll)
    for host in minimizeHosts.values { host.minimizeProxy.bottomEdgeEffect.isHidden = hidesEdge }
    view.tintColor = UIColor(argb: new.tintArgb)
    traitOverrides.userInterfaceStyle = new.dark ? .dark : .light
    traitOverrides.layoutDirection = new.rtl ? .rightToLeft : .leftToRight
    config = new
    // Under a Flutter dialog (Q8) the chrome is inert for touch and for
    // VoiceOver alike: touches fall through to the barrier, and VoiceOver
    // neither reads nor activates the tab bar, the sidebar or the footer.
    view.isUserInteractionEnabled = new.interactive
    view.accessibilityElementsHidden = !new.interactive
    footer.interactive = new.interactive
    // The dialog (or the pending guard's dialog) is drawn in the Flutter
    // view, below an overlay sidebar and its dimming view: close the
    // overlay, which is transient. A tiled sidebar stays.
    if overlayOpen, !new.interactive { sidebar.isHidden = true }
    // Hidden chrome holds no search (VK-551): a shell that left (the
    // dormant config) or hid the chrome would leave the field first
    // responder under it, the keyboard up with no field and no × to
    // dismiss it. The text is kept, as for any dismissal Dart asks for.
    if !chromeVisible { searchBridge.dismissKeepingText() }
    if chromeVisible != wasVisible { setChromeVisible(chromeVisible, closingOverlay: overlayOpen) }
    syncFlutter()
    updateMinimizePan()
  }

  func setSidebarVisible(_ visible: Bool) {
    guard chromeVisible, !isCompact else { return }
    sidebar.isHidden = !visible
  }

  /// Creates the tabs when the structure changes; `showTabs` hands them to
  /// UIKit. A live `UITab` is never reused for a new controller (UIKit
  /// asserts): a structure change builds new tabs and controllers.
  private func rebuildTabsIfNeeded(_ new: NativeChromeConfig) {
    let wanted =
      new.tabs.map { $0.search ? 2 : ($0.sidebarOnly ? 1 : 0) } + [new.trailing != nil ? 1 : 0]
    guard wanted != structure else { return }
    structure = wanted
    // One search controller, one navigation item at a time. An active
    // search is dismissed first and keeps its text, as leaving the tab does.
    searchBridge.dismissKeepingText()
    for nav in navControllers.values { nav.rootHost.navigationItem.searchController = nil }
    searchTab = nil
    searchIndex = nil
    navControllers = [:]
    minimizeHosts = [:]
    destinationTabs = new.tabs.enumerated().map { index, spec in
      if spec.search {
        let root = PageHostController()
        root.installSearch(
          searchBridge, style: searchStyle(rootLargeTitle: spec.pages.first?.largeTitle ?? nil))
        let nav = ShellNavController(root: root)
        navControllers[index] = nav
        let tab = UISearchTab { _ in nav }
        // The video's state 2: selecting search does not focus the field (Q13).
        tab.automaticallyActivatesSearch = false
        searchTab = tab
        searchIndex = index
        return tab
      }
      // Created now, not in the provider: Dart's minimize offset reaches
      // a host UIKit has not asked for yet. The provider runs once per tab.
      let host = TabHostController()
      minimizeHosts[index] = host
      let tab = UITab(title: "", image: nil, identifier: "destination\(index)") { _ in host }
      // `.fixed`: nothing to add, remove or reorder, so no sidebar "Edit".
      tab.preferredPlacement = spec.sidebarOnly ? .sidebarOnly : .fixed
      return tab
    }
    // Q9: never together. Dart asserts; should both arrive, the search
    // destination wins (UIKit gives both search tabs one identifier).
    trailingTab =
      searchTab != nil
      ? nil
      : new.trailing.map { _ in
        // Pinned by default: the trailing end of the bar, the first sidebar row.
        UISearchTab { _ in TabHostController() }
      }
  }

  /// Whether the search destination is selected, read from the selected
  /// controller: after a rebuild that keeps the search tab selected, iOS
  /// 26.5 reports a `selectedTab` that is not the new search tab (both
  /// carry UIKit's one search identifier) while it shows the new one.
  private var isSearchSelected: Bool {
    guard let searchIndex, let nav = navControllers[searchIndex] else { return false }
    return selectedViewController === nav
  }

  /// Whether the search root is the top of the search tab's stack. A page
  /// pushed over it keeps no activation (VK-634, the owner's choice,
  /// 2026-10-16): one UIKit refuses there is dropped, as before, and a
  /// push drops one kept before. A pop to the root, then an activation (a
  /// deep link), is kept: the stack's top is the root at once.
  private var isSearchRootOnTop: Bool {
    guard let searchIndex, let nav = navControllers[searchIndex] else { return false }
    return nav.topViewController === nav.rootHost
  }

  private func searchStyle(rootLargeTitle: Bool?) -> SearchTabStyle {
    SearchMath.style(
      isPad: traitCollection.userInterfaceIdiom == .pad,
      osMajor: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
      rootLargeTitle: rootLargeTitle)
  }

  /// Placeholder, scopes and placement of the search tab (spec §7.2,
  /// VK-550 §10.1).
  private func applySearch(_ new: NativeChromeConfig) {
    guard let searchIndex, new.tabs.indices.contains(searchIndex),
      let nav = navControllers[searchIndex]
    else { return }
    searchBridge.controller.searchBar.placeholder =
      new.search?.placeholder ?? searchBridge.defaultPlaceholder
    searchBridge.setScopes(new.search?.scopes)
    nav.rootHost.applySearchStyle(
      searchStyle(rootLargeTitle: new.tabs[searchIndex].pages.first?.largeTitle ?? nil))
  }

  /// The tabs UIKit shows. Compact has no sidebar, and UIKit's compact bar
  /// shows a `.sidebarOnly` tab anyway (`UITab.isHidden` does not hide it
  /// there, iOS 26.5): leave sidebar-only destinations out, as P1's bar
  /// does, and put them back at regular width. Dart tells the app about a
  /// hidden selection (`onSelectedDestinationHidden`). Not a user's
  /// selection: nothing is proposed to Dart.
  private func showTabs(_ config: NativeChromeConfig) {
    guard !config.tabs.isEmpty else { return }
    let compact = isCompact
    let shown = zip(destinationTabs, config.tabs).filter { !(compact && $1.sidebarOnly) }.map(\.0)
    // The search tab is pinned like the trailing one: first in the array
    // is the trailing end of the bar and the first sidebar row.
    let pinned = shown.filter { $0 === searchTab }
    let wanted = (trailingTab.map { [$0] } ?? []) + pinned + shown.filter { $0 !== searchTab }
    guard wanted.map(ObjectIdentifier.init) != tabs.map(ObjectIdentifier.init) else { return }
    applyingFromDart = true
    setTabs(wanted, animated: false)
    applyingFromDart = false
    applyProminentTab()
  }

  /// One rule for the prominent tab, after `setTabs` (probe; spec P3b
  /// §7.2). iOS 27 draws the separate circle after the compact bar's pill
  /// only for the prominent tab, and a search tab is prominent by default
  /// only when it activates the system search field, which neither of ours
  /// does on selection:
  /// - the trailing action, on every idiom: without it iOS 27 puts the ⌕
  ///   inside the pill as one more destination (VK-426);
  /// - the search destination, on an iPhone only (Q10); on an iPad Search
  ///   stays inside the bar (Q1);
  /// - neither: nil.
  /// A shell never has both (Q9). The iOS 27 SDK (Swift 6.4) declares the
  /// property.
  private func applyProminentTab() {
    #if compiler(>=6.4)
      if #available(iOS 27.0, *) {
        let search = searchStyle(rootLargeTitle: nil).prominent ? searchTab : nil
        let want = (trailingTab ?? search)?.identifier
        if prominentTabIdentifier != want { prominentTabIdentifier = want }
      }
    #endif
  }

  /// Selects destination [index]. A sidebar-only one is left out of the
  /// compact bar: then the first shown ordinary destination, never the
  /// search or the trailing tab (their selection is a search state). UIKit
  /// would otherwise pick a tab itself. Dart keeps its own selection and
  /// tells the app it is hidden; nothing is proposed. Leaving an active
  /// search dismisses it and keeps its text (Q2). Whether the search tab
  /// is already selected is `isSearchSelected`: after a rebuild iOS 26.5
  /// keeps a stale `selectedTab`, and every later config would dismiss an
  /// active search.
  private func select(_ index: Int) {
    guard destinationTabs.indices.contains(index) else { return }
    let wanted = destinationTabs[index]
    let shown = tabs.contains { $0 === wanted }
    guard
      let tab = shown
        ? wanted : tabs.first(where: { $0 !== trailingTab && $0 !== searchTab }),
      tab === searchTab ? !isSearchSelected : selectedTab !== tab
    else { return }
    if isSearchSelected { searchBridge.dismissKeepingText() }
    applyingFromDart = true
    selectedTab = tab
    // Q4: UIKit keeps a minimized bar through a programmatic change. Not
    // into search, which keeps UIKit's own form (Q5; spike §3.2, as with a
    // real scroll view): the toggle stays out of the scope bar's way.
    if !isSearchSelected { expandMinimizedBar() }
    applyingFromDart = false
    if isSearchSelected, let held = heldSearchText {
      heldSearchText = nil
      searchBridge.setText(held)
    }
    if isSearchSelected, let held = heldSearchScope {
      heldSearchScope = nil
      searchBridge.setScope(held)
    }
  }

  private func setFooter(_ data: NativeFooter?) {
    guard let data else {
      sidebar.bottomBarView = nil
      return
    }
    footer.update(data)
    if sidebar.bottomBarView !== footer { sidebar.bottomBarView = footer }
  }

  private func setChromeVisible(_ visible: Bool, closingOverlay overlayOpen: Bool) {
    // An overlay sidebar is transient: it does not come back with the chrome.
    // A tiled one keeps its state.
    if !visible, overlayOpen { sidebar.isHidden = true }
    view.isHidden = !visible
    guard visible, !UIAccessibility.isReduceMotionEnabled else { return }
    view.alpha = 0
    UIView.animate(withDuration: 0.2) { self.view.alpha = 1 }
  }

  // MARK: - State

  private var isTiled: Bool {
    guard let host = selectedViewController?.viewIfLoaded else { return false }
    return ShellMath.isTiled(host: ShellInsets(host.safeAreaInsets), root: ShellInsets(view.safeAreaInsets))
  }

  private func currentSidebar() -> NativeSidebar {
    guard chromeVisible, !isCompact, !sidebar.isHidden else { return .hidden }
    return isTiled ? .tiled : .overlay
  }

  func currentState() -> NativeShellState {
    NativeShellState(
      installed: true,
      compact: isCompact,
      sidebar: currentSidebar())
  }

  // MARK: - Flutter frame and safe area (spec §5.4)

  /// Flutter view frame = the selected host's frame; the host's safe area
  /// that Flutter lacks goes into the FVC's `additionalSafeAreaInsets`.
  /// While the chrome is hidden Flutter gets the whole window. Assigns only
  /// on change, then publishes state and window controls.
  func syncFlutter() {
    guard isViewLoaded, let root = view.superview else { return }
    if chromeVisible, let host = selectedViewController, host.isViewLoaded {
      let frame = host.view.convert(host.view.bounds, to: root)
      if flutter.view.frame != frame { flutter.view.frame = frame }
      // A navigation controller's top page carries the bar, the large title
      // and the stacked field in its safe area; its frame slides during a
      // push, so the frame above stays the tab's (spec §7.9).
      let page = (host as? UINavigationController)?.topViewController
      var want = ShellInsets(page?.viewIfLoaded?.safeAreaInsets ?? host.view.safeAreaInsets)
      if let page = page as? PageHostController, page.isViewLoaded {
        want.top = Double(page.flutterTop)
      }
      // Portrait overlay: the tab bar hides and safe.top drops; keep the
      // closed value so Flutter sees no metrics change.
      if currentSidebar() == .overlay {
        want.top = max(want.top, Double(heldTop))
      } else {
        heldTop = CGFloat(want.top)
      }
      let need = ShellMath.additionalInsets(
        want: want,
        current: ShellInsets(flutter.view.safeAreaInsets),
        added: ShellInsets(flutter.additionalSafeAreaInsets))
      if need != ShellInsets(flutter.additionalSafeAreaInsets) {
        flutter.additionalSafeAreaInsets = need.uiEdgeInsets
      }
    } else {
      if flutter.view.frame != root.bounds { flutter.view.frame = root.bounds }
      if flutter.additionalSafeAreaInsets != .zero { flutter.additionalSafeAreaInsets = .zero }
    }
    publishState()
    publishWindowControls()
    publishSearchField()
    scheduleControlsReread()
  }

  private func publishState() {
    guard dartAttached else { return }
    let state = currentState()
    guard state != lastState else { return }
    lastState = state
    // A failed send forgets `lastState`, so the next pass sends again.
    send("onStateChanged", onFailure: { [weak self] in
      if self?.lastState == state { self?.lastState = nil }
    }) { self.events.onStateChanged(state: state, completion: $0) }
  }

  func publishWindowControls() {
    guard dartAttached else { return }
    let read = windowControls()
    let value = (leading: read.leading, top: read.top)
    guard ShellMath.differs(lastControls, value) else { return }
    lastControls = value
    send("onWindowControlsChanged", onFailure: { [weak self] in self?.lastControls = nil }) {
      self.events.onWindowControlsChanged(controls: read, completion: $0)
    }
  }

  /// The window controls Flutter must clear (spec §8.1). None while the
  /// regular native chrome is visible: UIKit's top bar and sidebar make
  /// room for the cluster themselves, as its navigation bar does, and
  /// Flutter content starts below the bar row or beside the sidebar. The
  /// corner read is meaningless there: Flutter's safe top (the bar row) is
  /// below the cluster, so the vertical delta is 0 and the leading one
  /// alone would read as a cluster (`ShellMath.fallbackClusterTop`). The
  /// compact bar is at the bottom: the top is Flutter's, so it is read.
  func windowControls() -> NativeWindowControls {
    if chromeVisible, !isCompact || selectedHasNavigationBar {
      return NativeWindowControls(leading: 0, top: 0)
    }
    return readWindowControls(flutter.viewIfLoaded)
  }

  /// The corner-adapted region can lag one layout pass: read once more on
  /// the next run loop turn. Reads and sends only, never re-syncs.
  private func scheduleControlsReread() {
    guard !rereadScheduled else { return }
    rereadScheduled = true
    DispatchQueue.main.async { [weak self] in
      self?.rereadScheduled = false
      self?.publishWindowControls()
    }
  }

  /// Native → Dart. A failed send is logged in debug builds (spec §11).
  private func send(
    _ what: String,
    onFailure: (() -> Void)? = nil,
    _ call: (@escaping (Result<Void, PigeonError>) -> Void) -> Void
  ) {
    call { result in
      guard case .failure(let error) = result else { return }
      #if DEBUG
        NSLog("[liquid_shell] sending %@ to Dart failed: %@", what, String(describing: error))
      #endif
      onFailure?()
    }
  }

  // MARK: - Taps (native → Dart)

  private func closeOverlay() {
    if currentSidebar() == .overlay { sidebar.isHidden = true }
  }

  private func footerTapped() {
    closeOverlay()
    send("onFooterTapped") { self.events.onFooterTapped(completion: $0) }
  }

  func tabBarController(_ tabBarController: UITabBarController, shouldSelectTab tab: UITab) -> Bool {
    if tab === trailingTab {
      closeOverlay()
      send("onTrailingTapped") { self.events.onTrailingTapped(completion: $0) }
      return false
    }
    if let index = destinationTabs.firstIndex(where: { $0 === tab }) {
      // Propose, do not select: Dart runs the guard, then answers with
      // `update`, which selects the tab and closes an overlay sidebar. A
      // config sent while the guard runs is non-interactive and closes the
      // overlay before the guard's dialog shows.
      send("onDestinationTapped") { self.events.onDestinationTapped(index: Int64(index), completion: $0) }
      return false
    }
    return true
  }

  func tabBarController(
    _ tabBarController: UITabBarController, didSelectTab selectedTab: UITab, previousTab: UITab?
  ) {
    // Safety net for a selection UIKit makes without asking: report it; Dart
    // answers with the selection it accepts.
    guard !applyingFromDart, selectedTab !== previousTab,
      let index = destinationTabs.firstIndex(where: { $0 === selectedTab })
    else { return }
    send("onDestinationTapped") { self.events.onDestinationTapped(index: Int64(index), completion: $0) }
  }

  func tabBarController(
    _ tabBarController: UITabBarController,
    sidebarVisibilityWillChange sidebar: UITabBarController.Sidebar,
    animator: any UITabBarController.Sidebar.Animating
  ) {
    // Publish the end value, read once the transition is done.
    animator.addCompletion { [weak self] in self?.syncFlutter() }
  }

  /// Debug builds: the code path of a user tap, for integration tests.
  func debugTap(_ target: NativeTapTarget, index: Int) {
    #if DEBUG
      switch target {
      case .destination:
        guard destinationTabs.indices.contains(index) else { return }
        _ = tabBarController(self, shouldSelectTab: destinationTabs[index])
      case .trailing:
        guard let trailingTab else { return }
        _ = tabBarController(self, shouldSelectTab: trailingTab)
      case .footer:
        footerTapped()
      case .searchField:
        // A tap on the field: UIKit presents the search and reports it.
        guard isSearchSelected else { return }
        searchBridge.activate()
      case .searchCancel:
        searchBridge.debugCancel()
      case .back:
        topHost(ofTab: index)?.onBack?()
      }
    #endif
  }

  // MARK: - Search (spec P3b §7.4)

  /// Dart's text: applied outside a composition, never echoed; held while
  /// another tab is selected.
  func setSearchText(_ text: String) {
    guard isSearchSelected else {
      heldSearchText = text
      return
    }
    heldSearchText = nil
    searchBridge.setText(text)
  }

  /// The text a shell installed after a scene reconnect starts with (spec
  /// §7.10): Dart's newest write, held for another tab, kept through a
  /// dismissal or held for a composition, else the field's.
  var carriedSearchText: String {
    heldSearchText ?? searchBridge.newestText
  }

  /// Dart's activate / deactivate. Activation needs the search tab
  /// selected and the chrome shown: hidden chrome holds no search
  /// (VK-551, `apply`). Deactivation keeps the text. An activation UIKit
  /// refuses because the search root is not in the window yet (a deep
  /// link right after the selection) waits for the root
  /// (`searchRootAppeared`, VK-634), unless a page is pushed over it
  /// (`isSearchRootOnTop`).
  func setSearchActive(_ active: Bool) {
    if active {
      guard isSearchSelected, chromeVisible else { return }
      searchBridge.activate()
    } else {
      searchBridge.dismissKeepingText()
    }
  }

  /// The search root appeared (its `viewDidAppear`): it is in a window, so
  /// an activation UIKit refused before is applied now (VK-634), under the
  /// rule of `setSearchActive`: the search tab selected, the chrome shown.
  func searchRootAppeared(_ host: PageHostController) {
    guard let searchIndex, navControllers[searchIndex]?.rootHost === host, isSearchSelected,
      chromeVisible
    else { return }
    searchBridge.applyPendingActivation()
  }

  /// The scope a shell installed after a scene reconnect starts with, as
  /// `carriedSearchText`: Dart's newest index held for another tab, else
  /// the bar's (Dart's last write, or the user's last change reported).
  var carriedSearchScope: Int {
    heldSearchScope ?? searchBridge.knownScope
  }

  /// Dart's scope: selected in the scope bar, never reported back; held
  /// while another tab is selected.
  func setSearchScope(_ index: Int) {
    guard isSearchSelected else {
      heldSearchScope = index
      return
    }
    heldSearchScope = nil
    searchBridge.setScope(index)
  }

  /// Dart's dismissKeyboard (VK-571): a drag on the results or a scope
  /// tap. The keyboard goes, the search stays active with its text.
  func dismissSearchKeyboard() {
    guard isSearchSelected else { return }
    searchBridge.dismissKeyboard()
  }

  // MARK: - Pages (spec P3b §7.6, §7.7)

  /// The top page of tab [index], when it has a native navigation bar.
  func topHost(ofTab index: Int) -> PageHostController? {
    navControllers[index]?.topViewController as? PageHostController
  }

  private var selectedHasNavigationBar: Bool { selectedViewController is ShellNavController }

  /// The selected destination's index in Dart's list, nil when none is. The
  /// search destination is read from the selected controller
  /// (`isSearchSelected`): `selectedTab` can name a replaced search tab.
  private var selectedDestination: Int? {
    if isSearchSelected { return searchIndex }
    return destinationTabs.firstIndex { $0 === selectedTab && $0 !== searchTab }
  }

  /// The selected destination's index in Dart's list (0 when none is).
  var selectedDestinationIndex: Int { selectedDestination ?? 0 }

  /// The top page's scroll offset (proxy, spec §7.7).
  func setPageScroll(tab: Int, offset: Double) {
    guard offset.isFinite, let host = topHost(ofTab: tab) else { return }
    host.setScrollOffset(offset)
    syncFlutter()
  }

  // MARK: - Minimize on scroll (spec VK-600 §8)

  /// Number of expand toggles (tests).
  private(set) var minimizeExpands = 0

  /// The proxy whose pan is on the Flutter view, if any (spec §8.3).
  private(set) weak var attachedMinimizeProxy: MinimizeProxy?

  /// This shell's scene went (`retire`): the Flutter view may be a new
  /// shell's now. A flag, not a window check: the old window lives on, with
  /// this shell in it, until UIKit lets it go.
  private(set) var retired = false

  /// Puts the selected tab's proxy pan on the Flutter view when the native
  /// bar may minimize, and takes it back otherwise. Leaving compact resets
  /// every proxy, so the top bar's edge effect never sees an old offset.
  func updateMinimizePan() {
    var want: MinimizeProxy?
    if !retired, let config, chromeVisible, config.interactive, config.minimizeOnScroll,
      isCompact, let host = selectedViewController as? TabHostController,
      let content = flutter.viewIfLoaded
    {
      host.minimizeProxy.contentView = content
      want = host.minimizeProxy
    }
    if !isCompact { for host in minimizeHosts.values { host.minimizeProxy.setOffset(0) } }
    guard want !== attachedMinimizeProxy else { return }
    detachMinimizePan()
    guard let proxy = want, let content = flutter.viewIfLoaded else { return }
    let pan = proxy.panGestureRecognizer
    pan.cancelsTouchesInView = false
    pan.delaysTouchesBegan = false
    pan.delaysTouchesEnded = false
    content.addGestureRecognizer(pan)
    attachedMinimizeProxy = proxy
  }

  /// Gives the attached pan back to its proxy.
  func detachMinimizePan() {
    // A recognizer has one view: adding it elsewhere moves it.
    if let old = attachedMinimizeProxy { old.addGestureRecognizer(old.panGestureRecognizer) }
    attachedMinimizeProxy = nil
  }

  /// This shell's scene went (`NativeShellInstaller`): its pan leaves the
  /// Flutter view now, not when the shell is released, and never comes
  /// back, since a new shell may take the Flutter view. Its size-class
  /// handler and a late apply can still run (final review M1).
  func retire() {
    retired = true
    detachMinimizePan()
  }

  func minimizeHost(_ index: Int) -> TabHostController? { minimizeHosts[index] }

  /// Dart's body offset for destination [tab] (spec §8.6).
  func setMinimizeScroll(tab: Int, offset: Double) {
    guard offset.isFinite, let host = minimizeHosts[tab] else { return }
    host.minimizeProxy.setOffset(offset)
  }

  /// Expands a minimized bar: `.never` then `.onScrollDown` (spike §3.2;
  /// nothing changes on an expanded bar). Only while minimize is on.
  func expandMinimizedBar() {
    guard tabBarMinimizeBehavior == .onScrollDown else { return }
    minimizeExpands += 1
    tabBarMinimizeBehavior = .never
    tabBarMinimizeBehavior = .onScrollDown
  }

  // MARK: - Search field frame (spec P3b §7.5)

  private var lastField: NativeRect?
  private var keyboardObservers: [NSObjectProtocol] = []

  /// The search field's frame in the Flutter view, or zero when the search
  /// tab is not selected or the field is not shown (spec §7.5).
  func currentFieldFrame() -> NativeRect {
    let field = searchBridge.controller.searchBar.searchTextField
    guard chromeVisible, isSearchSelected, field.window != nil, Self.isDrawn(field),
      let flutterView = flutter.viewIfLoaded
    else { return Self.zeroRect }
    let frame = field.convert(field.bounds, to: flutterView)
    return NativeRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height)
  }

  private static let zeroRect = NativeRect(x: 0, y: 0, width: 0, height: 0)

  /// Whether [view] and every view above it are drawn (not hidden, not
  /// transparent).
  private static func isDrawn(_ view: UIView) -> Bool {
    var node: UIView? = view
    while let current = node {
      if current.isHidden || current.alpha < 0.01 { return false }
      node = current.superview
    }
    return true
  }

  func publishSearchField() {
    guard dartAttached, searchTab != nil else { return }
    let frame = currentFieldFrame()
    guard SearchMath.frameChanged(lastField, frame) else { return }
    lastField = frame
    send("onSearchFieldChanged", onFailure: { [weak self] in self?.lastField = nil }) {
      self.events.onSearchFieldChanged(frame: frame, completion: $0)
    }
  }

  #if DEBUG
    /// Debug builds: the scope bar's segmented control in the Flutter view,
    /// or zero when it is not drawn. UIKit places it (iPhone: under the
    /// status bar; iPad: under the field, spike §1) and keeps it private,
    /// so it is found in the window by its titles.
    func currentScopeFrame() -> NativeRect {
      let bar = searchBridge.controller.searchBar
      guard chromeVisible, isSearchSelected, bar.showsScopeBar,
        let titles = bar.scopeButtonTitles, !titles.isEmpty,
        let root = view.window, let flutterView = flutter.viewIfLoaded
      else { return Self.zeroRect }
      guard
        let control = Self.segmentedControls(in: root).first(where: { control in
          control.numberOfSegments == titles.count
            && titles.indices.allSatisfy { control.titleForSegment(at: $0) == titles[$0] }
            && !control.bounds.isEmpty && Self.isDrawn(control)
        })
      else { return Self.zeroRect }
      let frame = control.convert(control.bounds, to: flutterView)
      return NativeRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height)
    }

    private static func segmentedControls(in view: UIView) -> [UISegmentedControl] {
      ((view as? UISegmentedControl).map { [$0] } ?? [])
        + view.subviews.flatMap { segmentedControls(in: $0) }
    }
  #endif

  /// Debug builds: the native search and page state (integration tests).
  func debugSnapshot() -> NativeDebugSnapshot {
    #if DEBUG
      let nav = searchIndex.flatMap { navControllers[$0] }
      let placement: String
      switch nav?.rootHost.navigationItem.searchBarPlacement {
      case .stacked?: placement = "stacked"
      case .inline?: placement = "inline"
      case .integrated?: placement = "integrated"
      case .integratedCentered?: placement = "integratedCentered"
      case .integratedButton?: placement = "integratedButton"
      default: placement = ""
      }
      let minimizeBehavior: String
      switch tabBarMinimizeBehavior {
      case .automatic: minimizeBehavior = "automatic"
      case .never: minimizeBehavior = "never"
      case .onScrollDown: minimizeBehavior = "onScrollDown"
      case .onScrollUp: minimizeBehavior = "onScrollUp"
      @unknown default: minimizeBehavior = ""
      }
      return NativeDebugSnapshot(
        selectedTab: selectedDestination.map { "destination\($0)" } ?? "",
        searchActive: searchBridge.controller.isActive,
        searchText: searchBridge.text,
        placement: placement,
        pageTitles: nav?.viewControllers.map { $0.title ?? "" } ?? [],
        fieldFrame: currentFieldFrame(),
        firstResponderIsSearch: searchBridge.controller.searchBar.searchTextField.isFirstResponder,
        scopeTitles: searchBridge.controller.searchBar.scopeButtonTitles ?? [],
        scopeShown: searchBridge.controller.searchBar.showsScopeBar,
        selectedScope: Int64(searchBridge.controller.searchBar.selectedScopeButtonIndex),
        scopeFrame: currentScopeFrame(),
        minimizeBehavior: minimizeBehavior,
        minimizePanAttached: attachedMinimizeProxy != nil)
    #else
      return .empty
    #endif
  }
}

/// The empty, transparent controller of every tab. The Flutter view never
/// moves in here: the host only reports its frame and safe area.
@available(iOS 26.0, *)
final class TabHostController: UIViewController {
  private var shell: NativeTabsController? { tabBarController as? NativeTabsController }

  /// The proxy UIKit's tab bar minimize follows (spec VK-600 §8.2).
  let minimizeProxy = MinimizeProxy()

  /// A host goes with its tabs (a rebuild, the shell's release) while its
  /// pan may still be on the Flutter view, which outlives it: UIKit leaves
  /// a dead scroll view's pan where it is. Take it back first.
  ///
  /// Swift 6: this `deinit` is nonisolated and calls main-actor UIKit API,
  /// which Swift 5 mode allows. The Swift 6 language mode needs
  /// `isolated deinit` (SE-0371) or `MainActor.assumeIsolated` here.
  deinit {
    minimizeProxy.addGestureRecognizer(minimizeProxy.panGestureRecognizer)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    minimizeProxy.frame = view.bounds
    minimizeProxy.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.addSubview(minimizeProxy)
    setContentScrollView(minimizeProxy, for: .bottom)
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
}

extension ShellInsets {
  init(_ insets: UIEdgeInsets) {
    self.init(
      top: Double(insets.top), left: Double(insets.left),
      bottom: Double(insets.bottom), right: Double(insets.right))
  }

  var uiEdgeInsets: UIEdgeInsets {
    UIEdgeInsets(
      top: CGFloat(top), left: CGFloat(left), bottom: CGFloat(bottom), right: CGFloat(right))
  }
}

extension UIColor {
  /// Dart's `Color.toARGB32()`.
  convenience init(argb: Int64) {
    let value = UInt32(truncatingIfNeeded: argb)
    self.init(
      red: CGFloat((value >> 16) & 0xFF) / 255,
      green: CGFloat((value >> 8) & 0xFF) / 255,
      blue: CGFloat(value & 0xFF) / 255,
      alpha: CGFloat((value >> 24) & 0xFF) / 255)
  }
}

extension NativeDebugSnapshot {
  /// Release builds and "nothing installed".
  static var empty: NativeDebugSnapshot {
    NativeDebugSnapshot(
      selectedTab: "", searchActive: false, searchText: "", placement: "", pageTitles: [],
      fieldFrame: NativeRect(x: 0, y: 0, width: 0, height: 0), firstResponderIsSearch: false,
      scopeTitles: [], scopeShown: false, selectedScope: 0,
      scopeFrame: NativeRect(x: 0, y: 0, width: 0, height: 0), minimizeBehavior: "",
      minimizePanAttached: false)
  }
}
