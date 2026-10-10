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
  /// The search field and its delegates; one per shell, re-hosted when the
  /// tabs are rebuilt.
  let searchBridge = SearchBridge()
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
      guard let self, let searchTab = self.searchTab else { return false }
      return self.selectedTab === searchTab && !self.applyingFromDart
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
      self?.syncFlutter()
    }
    searchBridge.onSubmit = { [weak self] text in
      self?.send("onSearchSubmitted") { self?.events.onSearchSubmitted(text: text, completion: $0) }
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
    registerForTraitChanges([UITraitHorizontalSizeClass.self]) {
      (self: NativeTabsController, _: UITraitCollection) in
      // Dormant (no tabs in the config): leave UIKit's tabs and selection
      // alone, as `apply` does.
      if let config = self.config, !config.tabs.isEmpty {
        self.showTabs(config)
        self.select(Int(config.selectedIndex))
      }
      // Defensive: the layout pass that follows a size-class change syncs
      // too (`viewDidLayoutSubviews`), and no test tells the two apart.
      self.syncFlutter()
    }
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
      select(Int(new.selectedIndex))
    }
    setFooter(new.footer)
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
    if chromeVisible != wasVisible { setChromeVisible(chromeVisible, closingOverlay: overlayOpen) }
    syncFlutter()
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
    // One search controller, one navigation item at a time.
    for nav in navControllers.values { nav.rootHost.navigationItem.searchController = nil }
    searchTab = nil
    searchIndex = nil
    navControllers = [:]
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
      let tab = UITab(title: "", image: nil, identifier: "destination\(index)") { _ in
        TabHostController()
      }
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

  private func searchStyle(rootLargeTitle: Bool?) -> SearchTabStyle {
    SearchMath.style(
      isPad: traitCollection.userInterfaceIdiom == .pad,
      osMajor: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
      rootLargeTitle: rootLargeTitle)
  }

  /// Placeholder and placement of the search tab (spec §7.2).
  private func applySearch(_ new: NativeChromeConfig) {
    guard let searchIndex, new.tabs.indices.contains(searchIndex),
      let nav = navControllers[searchIndex]
    else { return }
    searchBridge.controller.searchBar.placeholder =
      new.search?.placeholder ?? searchBridge.defaultPlaceholder
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
  /// search dismisses it and keeps its text (Q2).
  private func select(_ index: Int) {
    guard destinationTabs.indices.contains(index) else { return }
    let wanted = destinationTabs[index]
    let shown = tabs.contains { $0 === wanted }
    guard
      let tab = shown
        ? wanted : tabs.first(where: { $0 !== trailingTab && $0 !== searchTab }),
      selectedTab !== tab
    else { return }
    if let searchTab, selectedTab === searchTab { searchBridge.dismissKeepingText() }
    applyingFromDart = true
    selectedTab = tab
    applyingFromDart = false
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
      var want = ShellInsets(host.view.safeAreaInsets)
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
    if chromeVisible, !isCompact { return NativeWindowControls(leading: 0, top: 0) }
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
      case .searchField, .searchCancel, .back:
        break
      }
    #endif
  }

  // MARK: - Search (spec P3b §7.4)

  /// Dart's text: applied outside a composition, never echoed.
  func setSearchText(_ text: String) {
    searchBridge.setText(text)
  }

  /// Dart's activate / deactivate. Activation needs the search tab
  /// selected; deactivation keeps the text.
  func setSearchActive(_ active: Bool) {
    if active {
      guard let searchTab, selectedTab === searchTab else { return }
      searchBridge.activate()
    } else {
      searchBridge.dismissKeepingText()
    }
  }

  // MARK: - Pages (P3b-1 Task 3 stubs; Task 5 implements)

  func setPageScroll(tab: Int, offset: Double) {}
  func debugSnapshot() -> NativeDebugSnapshot { .empty }
}

/// The empty, transparent controller of every tab. The Flutter view never
/// moves in here: the host only reports its frame and safe area.
@available(iOS 26.0, *)
final class TabHostController: UIViewController {
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
      fieldFrame: NativeRect(x: 0, y: 0, width: 0, height: 0), firstResponderIsSearch: false)
  }
}
