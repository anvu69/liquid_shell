import XCTest

/// Real taps on the native search tab (spec P3b §12.6). Launched with
/// LIQUID_SHELL_EXAMPLE_DEMO=search, the example opens the search case
/// with Flutter semantics on, so Flutter's rows are accessibility elements.
final class SearchUITests: XCTestCase {
  private let timeout: TimeInterval = 90

  override func setUp() {
    continueAfterFailure = false
  }

  private func launch() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["LIQUID_SHELL_EXAMPLE_DEMO"] = "search"
    app.launch()
    return app
  }

  /// The search tab's button: inside the bar (iPad 27) or the detached ⌕.
  private func searchTabButton(_ app: XCUIApplication) -> XCUIElement {
    let inBar = app.tabBars.buttons["Search"]
    return inBar.exists ? inBar : app.buttons["Search"].firstMatch
  }

  /// A Flutter row. Its semantics merge the title with the subtitle into one
  /// button ("Hồ Hoàn Kiếm\nPlace · Hà Nội"), so the label starts with it.
  private func flutterRow(_ app: XCUIApplication, _ title: String) -> XCUIElement {
    app.descendants(matching: .any)
      .matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
  }

  func testTheSearchTabFieldResultsAndBack() {
    let app = launch()
    let tab = searchTabButton(app)
    XCTAssertTrue(tab.waitForExistence(timeout: timeout))
    tab.tap()

    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 10), "the native field")
    XCTAssertFalse(app.keyboards.firstMatch.exists, "selected, not focused (Q13)")

    field.tap()
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
    field.typeText("ho hoan")
    let result = flutterRow(app, "Hồ Hoàn Kiếm")
    XCTAssertTrue(result.waitForExistence(timeout: 10), "Flutter's live results")

    result.tap()
    let back = app.navigationBars.buttons.element(boundBy: 0)
    XCTAssertTrue(back.waitForExistence(timeout: 10), "the native glass back button")
    back.tap()
    XCTAssertTrue(flutterRow(app, "Hồ Hoàn Kiếm").waitForExistence(timeout: 10))

    // × (UIKit labels it "Cancel" or "Close"): clears and unfocuses. The
    // iPad's stacked field has no ×; its ⓧ ("Clear text") does the same.
    let cancel = app.buttons.matching(
      NSPredicate(format: "label IN %@", ["Cancel", "Close", "Hủy", "Đóng"])
    ).firstMatch
    let clear = app.buttons["Clear text"].firstMatch
    let exit = cancel.waitForExistence(timeout: 5) ? cancel : clear
    XCTAssertTrue(exit.waitForExistence(timeout: 10), "× or ⓧ")
    exit.tap()
    XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 10))
    XCTAssertEqual((field.value as? String) ?? "", field.placeholderValue ?? "")
  }

  func testTheCollapsedCircleReturnsToThePreviousTab() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "iPhone only")
    let app = launch()
    let tab = searchTabButton(app)
    XCTAssertTrue(tab.waitForExistence(timeout: timeout))
    tab.tap()
    XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 10))
    // The collapsed circle carries the previous tab's label.
    let home = app.buttons["Home"].firstMatch
    XCTAssertTrue(home.waitForExistence(timeout: 10))
    home.tap()
    XCTAssertTrue(flutterRow(app, "Diễm xưa").waitForExistence(timeout: 10), "Home's list")
  }
}
