import UIKit

/// The search tab's `UISearchController` and its delegates (spec P3b
/// §7.4). It reports only what the user did, and writes Dart's text only
/// outside an IME composition, so Vietnamese Telex is never disturbed.
///
/// The scope bar is UIKit's own (spec VK-550 §10): `.manual` activation,
/// shown by `willPresent` and hidden by `willDismiss`, the only setup
/// drawn on iPhone and iPad, iOS 26.5 and 27 (spike §1). Shown only while
/// the search is active: a presentation UIKit refuses runs `willPresent`
/// too, and `activate` hides it again (VK-634).
@available(iOS 26.0, *)
final class SearchBridge: NSObject, UISearchResultsUpdating, UISearchControllerDelegate,
  UISearchBarDelegate
{
  let controller = UISearchController(searchResultsController: nil)
  /// Whether a user edit may be reported now (the tabs controller: the
  /// search tab is selected and Dart's config is not being applied).
  var canReport: () -> Bool = { false }
  /// Whether a refused activation may wait for the search root (the tabs
  /// controller: the root is the top of its tab's stack). A page pushed
  /// over the root keeps none: the activation is dropped, as before VK-634
  /// (the owner's choice, 2026-10-16).
  var canKeepActivation: () -> Bool = { true }
  var onText: (String, Bool) -> Void = { _, _ in }
  var onActive: (Bool) -> Void = { _ in }
  var onSubmit: (String) -> Void = { _ in }
  /// A user's scope change (once, on lift; never Dart's own index).
  var onScope: (Int) -> Void = { _ in }
  /// Whether an IME composition (marked text) is in progress. Injectable
  /// for tests: XCTest cannot type marked text.
  var isComposing: () -> Bool = { false }
  /// Dart's text, held while a composition runs. The user's input wins:
  /// any edit, the commit included, discards it.
  private(set) var pendingText: String?
  /// The system placeholder, put back when Dart sends none.
  private(set) var defaultPlaceholder: String?
  /// The text to keep through a dismissal Dart asked for (UIKit empties
  /// the field). Reset when that dismissal ends, or by the next presentation.
  private var keepOnDismiss: String?
  /// Dart asked for activation while a dismissal was still running, which
  /// UIKit ignores: activate once it ends.
  private var activateAfterDismiss = false
  /// Dart asked for activation while the search root was in no window,
  /// which UIKit refuses ("not in the window hierarchy"): a deep link that
  /// selects the search tab and activates lands before the tab's view is
  /// installed (VK-634). The root's `viewDidAppear` applies it
  /// (`applyPendingActivation`). Dart's deactivate, leaving the tab, a
  /// rebuild and hidden chrome (all `dismissKeepingText`), any
  /// presentation (`willPresent`) and a page pushed over the root
  /// (`dropPendingActivation`) end it; over such a page it is never kept
  /// (`canKeepActivation`).
  private(set) var activationPending = false
  /// What Dart knows: its own last write, or the last edit reported. UIKit
  /// calls back without a change (after a programmatic `text =`, probe P8;
  /// when the search presents or dismisses): only a change is a user edit.
  private var known = Known(text: "", composing: false)
  private struct Known: Equatable {
    let text: String
    let composing: Bool
  }
  /// True while Dart's text, scope titles or scope index is assigned: UIKit
  /// may call back synchronously.
  private var writing = false
  /// What Dart knows of the scope: its own last index (unclamped), or the
  /// last user change reported. A delegate call with it is no change.
  private(set) var knownScope = 0

  override init() {
    super.init()
    controller.searchResultsUpdater = self
    controller.delegate = self
    controller.searchBar.delegate = self
    controller.obscuresBackgroundDuringPresentation = false
    // UIKit's default (.automatic) never draws the scope bar in a search
    // tab (spike §1): the delegate shows it while the search is active.
    controller.scopeBarActivation = .manual
    defaultPlaceholder = controller.searchBar.placeholder
    isComposing = { [weak self] in
      self?.controller.searchBar.searchTextField.markedTextRange != nil
    }
  }

  var text: String { controller.searchBar.text ?? "" }

  /// Whether the search bar has scopes to show.
  private var hasScopes: Bool { !(controller.searchBar.scopeButtonTitles ?? []).isEmpty }

  /// Dart's titles; nil or fewer than two hide the scope bar (spec VK-550
  /// §10.1). Shown at once while the search is active; Dart's index is
  /// selected again, clamped to the new titles.
  func setScopes(_ titles: [String]?) {
    let wanted = (titles?.count ?? 0) >= 2 ? titles : nil
    let bar = controller.searchBar
    if (bar.scopeButtonTitles ?? []) != (wanted ?? []) {
      writing = true
      bar.scopeButtonTitles = wanted
      writing = false
    }
    syncScopeBar()
    selectKnownScope()
  }

  /// The scope bar while the search is active, and only then: Dart's
  /// titles and UIKit's `isActive`. A presentation UIKit refused ran
  /// `willPresent`, which showed it, but is not active (VK-634).
  private func syncScopeBar() {
    let bar = controller.searchBar
    let show = hasScopes && controller.isActive
    if bar.showsScopeBar != show { bar.setShowsScope(show, animated: false) }
  }

  /// Dart's index, clamped. Never reported back.
  func setScope(_ index: Int) {
    knownScope = index
    selectKnownScope()
  }

  /// Selects Dart's index, clamped to the titles. A programmatic selection
  /// does not call the delegate (spike §1); `writing` guards it anyway.
  private func selectKnownScope() {
    let count = controller.searchBar.scopeButtonTitles?.count ?? 0
    guard count > 0 else { return }
    let index = min(max(knownScope, 0), count - 1)
    guard controller.searchBar.selectedScopeButtonIndex != index else { return }
    writing = true
    controller.searchBar.selectedScopeButtonIndex = index
    writing = false
  }

  /// The text the field will show once UIKit is done: the text a
  /// dismissal Dart asked for keeps (UIKit has emptied the field), else
  /// Dart's text held for a composition, else the field's.
  var newestText: String { keepOnDismiss ?? pendingText ?? text }

  /// Dart's text: now, or once the composition ends.
  func setText(_ new: String) {
    if keepOnDismiss != nil {
      // A dismissal Dart asked for is running: UIKit empties the field,
      // then `didDismiss` puts back Dart's newest text.
      keepOnDismiss = new
      pendingText = nil
      return
    }
    if isComposing() {
      pendingText = new
      return
    }
    pendingText = nil
    guard new != text else { return }
    write(new)
  }

  /// Presents the search and focuses the field (research spike: the first
  /// responder must be asked on the next run-loop turn). UIKit refuses the
  /// presentation while the search root is in no window: the activation
  /// is kept until the root appears (VK-634).
  func activate() {
    activateAfterDismiss = false
    activationPending = false
    controller.isActive = true
    if !controller.isActive {
      if controller.transitionCoordinator != nil {
        // A dismissal is still running (a quick deactivate → activate):
        // `didDismiss` restores the text, then activates.
        activateAfterDismiss = true
        return
      }
      // Refused: the search root is in no window yet. Its `viewDidAppear`
      // applies the activation; a focus on the next turn would race
      // UIKit's layout (it lost about one time in seven). Under a pushed
      // page the activation is dropped instead. `willPresent` has shown
      // the scope bar of a search that is not active.
      activationPending = canKeepActivation()
      syncScopeBar()
      return
    }
    // No dismissal runs: a kept text left over is the text.
    restoreKept()
    DispatchQueue.main.async { [weak self] in
      _ = self?.controller.searchBar.searchTextField.becomeFirstResponder()
    }
  }

  /// The search root is in a window now (its `viewDidAppear`): an
  /// activation UIKit refused before is applied (VK-634).
  func applyPendingActivation() {
    guard activationPending else { return }
    activationPending = false
    if !controller.isActive { activate() }
  }

  /// A page pushed over the search root ends a kept activation: the pop
  /// back must not bring the search (VK-634, the owner's choice).
  func dropPendingActivation() {
    activationPending = false
  }

  /// Dismisses the search and keeps the text: a dismissal Dart asked for
  /// (a dialog above, another tab) is not the user's ×. Dart text held for
  /// a composition is newer than the field's. An activation kept for the
  /// root's window ends here too, before the guard: it is not active
  /// (VK-634).
  func dismissKeepingText() {
    activateAfterDismiss = false
    activationPending = false
    guard controller.isActive else { return }
    keepOnDismiss = pendingText ?? text
    pendingText = nil
    controller.isActive = false
  }

  /// Puts the keyboard away and keeps the search (VK-571), as a drag on
  /// Apple Music's results does: the field resigns first responder;
  /// `isActive`, the text and Cancel stay. Nothing is written. Resigning
  /// commits marked text, which UIKit may not report as a change: the
  /// field is read once more, so the commit reaches Dart like any edit.
  func dismissKeyboard() {
    guard controller.isActive else { return }
    let field = controller.searchBar.searchTextField
    if field.isFirstResponder { _ = field.resignFirstResponder() }
    updateSearchResults(for: controller)
  }

  #if DEBUG
    /// Debug builds: what UIKit does for a tap on × (clear, then dismiss).
    func debugCancel() {
      controller.searchBar.text = ""
      updateSearchResults(for: controller)
      controller.isActive = false
    }
  #endif

  private func write(_ new: String) {
    writing = true
    known = Known(text: new, composing: false)
    controller.searchBar.text = new
    writing = false
  }

  private func restoreKept() {
    guard let kept = keepOnDismiss else { return }
    keepOnDismiss = nil
    if kept != text { write(kept) }
  }

  // MARK: UISearchResultsUpdating

  func updateSearchResults(for searchController: UISearchController) {
    // Dart's own write, or UIKit emptying the field for a dismissal Dart
    // asked for: not user input.
    if writing || keepOnDismiss != nil { return }
    let now = Known(text: text, composing: isComposing())
    if now != known {
      // User input wins over Dart text held for the composition.
      pendingText = nil
      guard canReport() else { return }
      known = now
      onText(now.text, now.composing)
    } else if !now.composing, let pending = pendingText {
      setText(pending)
    }
  }

  // MARK: UISearchControllerDelegate

  /// Any presentation, the user's tap included (it never runs `activate`),
  /// ends a dismissal Dart asked for: one whose end UIKit never reported
  /// would otherwise keep the bridge from reporting the user's edits. It
  /// ends a kept activation too: the search came, and a later appearance
  /// of the root must not bring it back once the user closed it (VK-634).
  func willPresentSearchController(_ searchController: UISearchController) {
    activateAfterDismiss = false
    activationPending = false
    restoreKept()
    if hasScopes { controller.searchBar.setShowsScope(true, animated: true) }
  }

  /// The scope bar goes with the search (Music: shown only while active).
  func willDismissSearchController(_ searchController: UISearchController) {
    controller.searchBar.setShowsScope(false, animated: true)
  }

  func didPresentSearchController(_ searchController: UISearchController) {
    if canReport() { onActive(true) }
  }

  func didDismissSearchController(_ searchController: UISearchController) {
    restoreKept()
    if activateAfterDismiss {
      // Dart wants the search active again: no inactive report, unless
      // UIKit refuses the activation.
      activateAfterDismiss = false
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.activate()
        if !self.controller.isActive, !self.activateAfterDismiss { self.onActive(false) }
      }
      return
    }
    // Always: inactive is idempotent on the Dart side.
    onActive(false)
  }

  // MARK: UISearchBarDelegate

  func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
    if canReport() { onSubmit(text) }
  }

  /// A user's scope change: once, at touch-up or at the end of a drag
  /// (spike §1). Dart's own index is no change.
  func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
    guard !writing, canReport(), selectedScope != knownScope else { return }
    knownScope = selectedScope
    onScope(selectedScope)
  }
}
