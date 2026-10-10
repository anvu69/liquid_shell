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
  /// Sidebar-only flags plus "has trailing": a change rebuilds the tabs.
  private var structure: [Bool] = []
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
        tab.image = UIImage(systemName: spec.sfSymbol)
        tab.badgeValue = spec.badge
      }
      if let tab = trailingTab, let action = new.trailing {
        tab.title = action.title
        tab.image = UIImage(systemName: action.sfSymbol)
      }
      showTabs(new)
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
  /// UIKit.
  private func rebuildTabsIfNeeded(_ new: NativeChromeConfig) {
    let wanted = new.tabs.map(\.sidebarOnly) + [new.trailing != nil]
    guard wanted != structure else { return }
    structure = wanted
    destinationTabs = new.tabs.enumerated().map { index, spec in
      let tab = UITab(title: "", image: nil, identifier: "destination\(index)") { _ in
        TabHostController()
      }
      // `.fixed`: nothing to add, remove or reorder, so no sidebar "Edit".
      tab.preferredPlacement = spec.sidebarOnly ? .sidebarOnly : .fixed
      return tab
    }
    trailingTab = new.trailing.map { _ in
      // Pinned by default: the trailing end of the bar, the first sidebar row.
      UISearchTab { _ in TabHostController() }
    }
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
    let wanted = (trailingTab.map { [$0] } ?? []) + shown
    guard wanted.map(ObjectIdentifier.init) != tabs.map(ObjectIdentifier.init) else { return }
    applyingFromDart = true
    setTabs(wanted, animated: false)
    applyingFromDart = false
  }

  /// Selects destination [index]. A sidebar-only one is left out of the
  /// compact bar: then the first shown destination. UIKit would otherwise
  /// pick a tab itself, and its first tab is the search tab, whose
  /// selection is the compact bar's search state. Dart keeps its own
  /// selection and tells the app it is hidden; nothing is proposed.
  private func select(_ index: Int) {
    guard destinationTabs.indices.contains(index) else { return }
    let wanted = destinationTabs[index]
    let shown = tabs.contains { $0 === wanted }
    guard let tab = shown ? wanted : tabs.first(where: { $0 !== trailingTab }),
      selectedTab !== tab
    else { return }
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
      }
    #endif
  }
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
