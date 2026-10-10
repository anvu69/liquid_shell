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
  /// Dart's text, held while a composition runs.
  private(set) var pendingText: String?
  /// The system placeholder, put back when Dart sends none.
  private(set) var defaultPlaceholder: String?
  /// The text to keep through a dismissal Dart asked for (UIKit may clear it).
  private var keepOnDismiss: String?
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
    if isComposing() {
      pendingText = new
      return
    }
    pendingText = nil
    if keepOnDismiss != nil {
      // A dismissal Dart asked for is running: UIKit empties the field,
      // then `didDismiss` puts back Dart's newest text.
      keepOnDismiss = new
      return
    }
    guard new != text else { return }
    write(new)
  }

  /// Presents the search and focuses the field (research spike: the first
  /// responder must be asked on the next run-loop turn).
  func activate() {
    controller.isActive = true
    DispatchQueue.main.async { [weak self] in
      _ = self?.controller.searchBar.searchTextField.becomeFirstResponder()
    }
  }

  /// Dismisses the search and keeps the text: a dismissal Dart asked for
  /// (a dialog above, another tab) is not the user's ×.
  func dismissKeepingText() {
    guard controller.isActive else { return }
    keepOnDismiss = text
    controller.isActive = false
  }

  /// Debug builds: what UIKit does for a tap on × (clear, then dismiss).
  func debugCancel() {
    controller.searchBar.text = ""
    updateSearchResults(for: controller)
    controller.isActive = false
  }

  private func write(_ new: String) {
    writing = true
    known = Known(text: new, composing: false)
    controller.searchBar.text = new
    writing = false
  }

  // MARK: UISearchResultsUpdating

  func updateSearchResults(for searchController: UISearchController) {
    let composing = isComposing()
    if !composing, let pending = pendingText {
      setText(pending)
      return
    }
    if writing || keepOnDismiss != nil { return }
    let now = Known(text: text, composing: composing)
    guard now != known, canReport() else { return }
    known = now
    onText(now.text, now.composing)
  }

  // MARK: UISearchControllerDelegate

  func didPresentSearchController(_ searchController: UISearchController) {
    if canReport() { onActive(true) }
  }

  func didDismissSearchController(_ searchController: UISearchController) {
    if let kept = keepOnDismiss {
      keepOnDismiss = nil
      if kept != text { write(kept) }
    }
    // Always: inactive is idempotent on the Dart side.
    onActive(false)
  }

  // MARK: UISearchBarDelegate

  func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
    if canReport() { onSubmit(text) }
  }
}
