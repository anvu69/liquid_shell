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

  /// The back button's long-press menu pops UIKit without its
  /// `backAction`: Flutter must pop too, or it keeps the detail page with
  /// no back button (Task 12 finding).
  /// Searches "ho hoan" and opens the result's detail page; returns the
  /// app, the native back button and the detail's heading.
  private func openDetail() -> (XCUIApplication, XCUIElement, XCUIElement) {
    let app = launch()
    let tab = searchTabButton(app)
    XCTAssertTrue(tab.waitForExistence(timeout: timeout))
    tab.tap()
    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 10))
    field.tap()
    field.typeText("ho hoan")
    let result = flutterRow(app, "Hồ Hoàn Kiếm")
    XCTAssertTrue(result.waitForExistence(timeout: 10))
    result.tap()
    let back = app.navigationBars.buttons["BackButton"]
    XCTAssertTrue(back.waitForExistence(timeout: 10), "the native glass back button")
    let heading = app.staticTexts["Hồ Hoàn Kiếm"]
    XCTAssertTrue(heading.waitForExistence(timeout: 10), "the detail")
    return (app, back, heading)
  }

  func testTheBackMenuPopsTheFlutterPageToo() {
    let (app, back, heading) = openDetail()

    // Hold, then lift away from the button: the menu stays open.
    back.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
      .press(forDuration: 1.5, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
    // The menu's entry, not the back button or the (selected) Search tab
    // of an iPad's top tab bar.
    let entry = app.buttons.matching(
      NSPredicate(format: "label == 'Search' AND identifier != 'BackButton' AND selected == NO")
    ).allElementsBoundByIndex.first { $0.frame.minY < app.frame.midY }
    XCTAssertNotNil(entry, "the back menu's entry for the search root")
    entry?.tap()

    XCTAssertTrue(back.waitForNonExistence(timeout: 10), "native popped")
    XCTAssertTrue(heading.waitForNonExistence(timeout: 10), "Flutter popped the detail too")
    XCTAssertTrue(flutterRow(app, "Hồ Hoàn Kiếm").waitForExistence(timeout: 10), "the results")
  }

  /// Q14: Flutter owns the edge swipe; the native bar follows its pop.
  func testAnEdgeSwipePopsFlutterAndTheNativeBarFollows() {
    let (app, back, heading) = openDetail()
    app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: 2, dy: 0))
      .press(
        forDuration: 0.05,
        thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
    XCTAssertTrue(heading.waitForNonExistence(timeout: 10), "Flutter popped the detail")
    XCTAssertTrue(back.waitForNonExistence(timeout: 10), "the native bar followed")
    XCTAssertTrue(flutterRow(app, "Hồ Hoàn Kiếm").waitForExistence(timeout: 10), "the results")
  }

  /// Apple Music's large title shares the bar row, right under the status
  /// bar (UIKit's `.inline`), not a row below it (Task 12 side by side).
  func testTheSearchRootsLargeTitleSitsOnTheBarRow() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "iPhone only")
    let app = launch()
    let tab = searchTabButton(app)
    XCTAssertTrue(tab.waitForExistence(timeout: timeout))
    tab.tap()
    let bar = app.navigationBars["Search"]
    let title = bar.staticTexts["Search"]
    XCTAssertTrue(title.waitForExistence(timeout: 10), "the native large title")
    XCTAssertEqual(bar.frame.height, 54, accuracy: 1, "no title row under the bar row")
    XCTAssertLessThanOrEqual(title.frame.maxY, bar.frame.maxY + 0.5, "on the bar row")
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
