import XCTest

/// Real taps on the native search tab (spec P3b §12.6). Launched with
/// LIQUID_SHELL_EXAMPLE_DEMO=search, the example opens the search case
/// with Flutter semantics on, so Flutter's rows are accessibility elements.
final class SearchUITests: XCTestCase {
  private let timeout: TimeInterval = 90

  override func setUp() {
    continueAfterFailure = false
  }

  private func launch(demo: String = "search") -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["LIQUID_SHELL_EXAMPLE_DEMO"] = demo
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

  /// The first element of [query] that [accept]s, waited for: a menu
  /// appears after its animation.
  private func waitForFirst(
    _ query: XCUIElementQuery, timeout: TimeInterval = 10,
    where accept: (XCUIElement) -> Bool
  ) -> XCUIElement? {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
      if let found = query.allElementsBoundByIndex.first(where: accept) { return found }
      RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    } while Date() < deadline
    return nil
  }

  /// Opens the back button's history menu and returns its entry for the
  /// page titled [title]: hold, then lift away from the button, and the
  /// menu stays open. The entry is not the back button, nor the (selected)
  /// Search tab of an iPad's top tab bar, nor the iPhone's ⌕ at the bottom.
  private func backMenuEntry(
    _ app: XCUIApplication, _ back: XCUIElement, _ title: String
  ) -> XCUIElement? {
    back.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
      .press(
        forDuration: 1.5,
        thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
    let entries = app.buttons.matching(
      NSPredicate(
        format: "label == %@ AND identifier != 'BackButton' AND selected == NO", title))
    return waitForFirst(entries) { $0.frame.minY < app.frame.midY }
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
    let back = app.navigationBars.buttons["BackButton"]
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

  /// The back button's long-press menu pops UIKit without its
  /// `backAction`: Flutter must pop too, or it keeps the detail page with
  /// no back button (Task 12 finding).
  func testTheBackMenuPopsTheFlutterPageToo() {
    let (app, back, heading) = openDetail()
    let entry = backMenuEntry(app, back, "Search")
    XCTAssertNotNil(entry, "the back menu's entry for the search root")
    entry?.tap()

    XCTAssertTrue(back.waitForNonExistence(timeout: 10), "native popped")
    XCTAssertTrue(heading.waitForNonExistence(timeout: 10), "Flutter popped the detail too")
    XCTAssertTrue(flutterRow(app, "Hồ Hoàn Kiếm").waitForExistence(timeout: 10), "the results")
  }

  /// A pop the page refuses (`PopScope`), picked from the back menu two
  /// pages up: Flutter's walk stops at that page, and UIKit, which never
  /// popped by itself, keeps the page and its bar (Task 12 review).
  func testARefusedPopFromTheBackMenuKeepsThePageAndItsBar() {
    let app = launch(demo: "search-guarded")
    let tab = searchTabButton(app)
    XCTAssertTrue(tab.waitForExistence(timeout: timeout))
    tab.tap()
    let category = flutterRow(app, "Nhạc Trịnh")
    XCTAssertTrue(category.waitForExistence(timeout: 10), "the category grid")
    category.tap()
    let song = flutterRow(app, "Diễm xưa")
    XCTAssertTrue(song.waitForExistence(timeout: 10), "the category's page")
    song.tap()
    let back = app.navigationBars.buttons["BackButton"]
    XCTAssertTrue(back.waitForExistence(timeout: 10), "the native glass back button")
    // Flutter's detail: the subtitle line is its own text only there.
    let detail = app.staticTexts["Trịnh Công Sơn"]
    XCTAssertTrue(detail.waitForExistence(timeout: 10), "the guarded detail")
    let bar = app.navigationBars["Diễm xưa"]
    XCTAssertTrue(bar.waitForExistence(timeout: 10), "the detail's native bar")

    let entry = backMenuEntry(app, back, "Search")
    XCTAssertNotNil(entry, "the back menu's entry for the search root")
    entry?.tap()
    XCTAssertFalse(detail.waitForNonExistence(timeout: 3), "the page refused")
    XCTAssertTrue(bar.exists, "the bar still shows the detail")
    XCTAssertTrue(back.isHittable, "and its back button")

    // A plain back is still a proposal: refused too, nothing moves.
    back.tap()
    XCTAssertFalse(detail.waitForNonExistence(timeout: 3), "the page refused")
    XCTAssertTrue(bar.exists, "the bar still shows the detail")
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
