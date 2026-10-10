import UIKit

/// The search tab's `UISearchController` and its delegates (spec P3b
/// §7.4). It reports only what the user did, and writes Dart's text only
/// outside an IME composition, so Vietnamese Telex is never disturbed.
@available(iOS 26.0, *)
final class SearchBridge: NSObject, UISearchResultsUpdating, UISearchControllerDelegate,
  UISearchBarDelegate
{
  let controller = UISearchController(searchResultsController: nil)
  /// Whether a user edit may be reported now (the tabs controller: the
  /// search tab is selected and Dart's config is not being applied).
  var canReport: () -> Bool = { false }
  var onText: (String, Bool) -> Void = { _, _ in }
  var onActive: (Bool) -> Void = { _ in }
  var onSubmit: (String) -> Void = { _ in }
  /// Whether an IME composition (marked text) is in progress. Injectable
  /// for tests: XCTest cannot type marked text.
  var isComposing: () -> Bool = { false }
  /// Dart's text, held while a composition runs. The user's input wins:
  /// any edit, the commit included, discards it.
  private(set) var pendingText: String?
  /// The system placeholder, put back when Dart sends none.
  private(set) var defaultPlaceholder: String?
  /// The text to keep through a dismissal Dart asked for (UIKit empties
  /// the field). Reset when that dismissal ends, or by the next activation.
  private var keepOnDismiss: String?
  /// Dart asked for activation while a dismissal was still running, which
  /// UIKit ignores: activate once it ends.
  private var activateAfterDismiss = false
  /// What Dart knows: its own last write, or the last edit reported. UIKit
  /// calls back without a change (after a programmatic `text =`, probe P8;
  /// when the search presents or dismisses): only a change is a user edit.
  private var known = Known(text: "", composing: false)
  private struct Known: Equatable {
    let text: String
    let composing: Bool
  }
  /// True while Dart's text is assigned: UIKit may call back synchronously.
  private var writing = false

  override init() {
    super.init()
    controller.searchResultsUpdater = self
    controller.delegate = self
    controller.searchBar.delegate = self
    controller.obscuresBackgroundDuringPresentation = false
    defaultPlaceholder = controller.searchBar.placeholder
    isComposing = { [weak self] in
      self?.controller.searchBar.searchTextField.markedTextRange != nil
    }
  }

  var text: String { controller.searchBar.text ?? "" }

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
  /// responder must be asked on the next run-loop turn).
  func activate() {
    activateAfterDismiss = false
    controller.isActive = true
    if !controller.isActive, controller.transitionCoordinator != nil {
      // A dismissal is still running (a quick deactivate → activate):
      // `didDismiss` restores the text, then activates.
      activateAfterDismiss = true
      return
    }
    // No dismissal runs: a kept text left over is the text.
    restoreKept()
    DispatchQueue.main.async { [weak self] in
      _ = self?.controller.searchBar.searchTextField.becomeFirstResponder()
    }
  }

  /// Dismisses the search and keeps the text: a dismissal Dart asked for
  /// (a dialog above, another tab) is not the user's ×. Dart text held for
  /// a composition is newer than the field's.
  func dismissKeepingText() {
    activateAfterDismiss = false
    guard controller.isActive else { return }
    keepOnDismiss = pendingText ?? text
    pendingText = nil
    controller.isActive = false
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
}
