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
    func swipeFromTheEdge() {
      app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: 2, dy: 0))
        .press(
          forDuration: 0.05,
          thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
    }
    swipeFromTheEdge()
    // A loaded CI runner can drop the first drag's events (seen on shared
    // macOS runners): one more swipe, and a broken back gesture still fails.
    if !heading.waitForNonExistence(timeout: 5) { swipeFromTheEdge() }
    XCTAssertTrue(heading.waitForNonExistence(timeout: 10), "Flutter popped the detail")
    XCTAssertTrue(back.waitForNonExistence(timeout: 10), "the native bar followed")
    XCTAssertTrue(flutterRow(app, "Hồ Hoàn Kiếm").waitForExistence(timeout: 10), "the results")
  }

  /// The tab button for [label]: in the bar, or the iPhone's collapsed
  /// circle (which carries the previous tab's label).
  private func tabButton(_ app: XCUIApplication, _ label: String) -> XCUIElement {
    let inBar = app.tabBars.buttons[label]
    return inBar.exists ? inBar : app.buttons[label].firstMatch
  }

  /// VK-502: a tab keeps its pages while another tab is selected. Back on
  /// Search the detail is there, and native neither pops to the root nor
  /// pushes the detail again, animated. XCUITest waits for animations to
  /// end, so the example counts the animated stack changes
  /// (LIQUID_SHELL_EXAMPLE_TRACE_NAV, AppDelegate.swift).
  func testReturningToTheSearchTabKeepsItsPageWithNoPush() {
    let app = XCUIApplication()
    app.launchEnvironment["LIQUID_SHELL_EXAMPLE_DEMO"] = "search"
    app.launchEnvironment["LIQUID_SHELL_EXAMPLE_TRACE_NAV"] = "1"
    app.launch()
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
    let changes = app.staticTexts["animatedStackChanges"]
    XCTAssertTrue(changes.waitForExistence(timeout: 10), "the trace")
    XCTAssertEqual(changes.label, "animated stack changes: 1", "the push")

    let home = tabButton(app, "Home")
    XCTAssertTrue(home.waitForExistence(timeout: 10), "the Home tab")
    home.tap()
    XCTAssertTrue(flutterRow(app, "Diễm xưa").waitForExistence(timeout: 10), "Home's list")
    searchTabButton(app).tap()
    XCTAssertTrue(heading.waitForExistence(timeout: 10), "the detail, kept")
    XCTAssertTrue(back.waitForExistence(timeout: 10), "its back button")
    XCTAssertTrue(app.navigationBars["Hồ Hoàn Kiếm"].exists, "its bar")
    // Late messages would come within a second.
    RunLoop.current.run(until: Date().addingTimeInterval(1))
    XCTAssertEqual(changes.label, "animated stack changes: 1", "no pop and push again")
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

/// VK-551: an edge swipe with the keyboard up, the search case pushed
/// above the case list as a person opens it. UIKit offers no swipe back
/// while a bar's search is active: the case stays and the keyboard can be
/// dismissed, never left behind with no field. On a page pushed inside the
/// search tab the swipe pops that page (Apple Music) and the search stays
/// as it was there.
extension SearchUITests {
  /// A drag from x = 2 to 90% of the width, mid-height: Flutter's back
  /// gesture (the native bar's own is off, Q14).
  fileprivate func swipeFromTheLeftEdge(_ app: XCUIApplication) {
    app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: 2, dy: 0))
      .press(
        forDuration: 0.05,
        thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
  }

  /// The search case above the case list ([demo]), the search tab
  /// selected and its field focused with "ho hoan" typed.
  fileprivate func typeAboveTheCaseList(_ demo: String) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["LIQUID_SHELL_EXAMPLE_DEMO"] = demo
    app.launch()
    let tab = searchTabButton(app)
    XCTAssertTrue(tab.waitForExistence(timeout: timeout))
    tab.tap()
    let native = app.searchFields.firstMatch
    let flutter = app.textFields.firstMatch
    XCTAssertTrue(
      native.waitForExistence(timeout: 10) || flutter.waitForExistence(timeout: 10), "a field")
    let field = native.exists ? native : flutter
    field.tap()
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 30), "the keyboard")
    field.typeText("ho hoan")
    XCTAssertTrue(flutterRow(app, "Hồ Hoàn Kiếm").waitForExistence(timeout: 10), "the results")
    return app
  }

  /// The × that ends the search: UIKit's ("Cancel", "Close") or the
  /// Flutter field's ("Cancel search"); the iPad's stacked field has only
  /// its ⓧ ("Clear text"), which does the same. Never the iPhone field's
  /// own ⓧ, which only clears.
  fileprivate func searchExit(_ app: XCUIApplication) -> XCUIElement {
    let cancel = app.buttons.matching(
      NSPredicate(format: "label IN %@", ["Cancel", "Close", "Hủy", "Đóng", "Cancel search"])
    ).firstMatch
    if cancel.waitForExistence(timeout: 5) || UIDevice.current.userInterfaceIdiom == .phone {
      return cancel
    }
    return app.buttons["Clear text"].firstMatch
  }

  /// Off the search root the swipe has nothing of the shell's to pop: the
  /// case stays, the keyboard with it, and × still dismisses it.
  fileprivate func expectAnEdgeSwipeOffTheRootKeepsTheCase(_ demo: String) {
    let app = typeAboveTheCaseList(demo)
    swipeFromTheLeftEdge(app)
    XCTAssertFalse(flutterRow(app, "Search tab").waitForExistence(timeout: 3), "the case stays")
    XCTAssertTrue(flutterRow(app, "Hồ Hoàn Kiếm").exists, "its results")
    let exit = searchExit(app)
    XCTAssertTrue(exit.waitForExistence(timeout: 10), "× or ⓧ, to dismiss the keyboard")
    exit.tap()
    XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 10), "dismissed")
  }

  func testNativeAnEdgeSwipeOffTheSearchRootKeepsTheCaseAndTheKeyboardDismissable() {
    expectAnEdgeSwipeOffTheRootKeepsTheCase("search-above")
  }

  func testFlutterAnEdgeSwipeOffTheSearchRootKeepsTheCaseAndTheKeyboardDismissable() {
    expectAnEdgeSwipeOffTheRootKeepsTheCase("search-above-liquid")
  }

  /// Natively the search stays active on the result's page (its keyboard
  /// goes down there): the swipe pops that page, not the whole case, and
  /// the search comes back as it was, × included.
  func testNativeAnEdgeSwipeOnAResultPagePopsThatPage() {
    let app = typeAboveTheCaseList("search-above")
    flutterRow(app, "Hồ Hoàn Kiếm").tap()
    let back = app.navigationBars.buttons["BackButton"]
    XCTAssertTrue(back.waitForExistence(timeout: 30), "the native glass back button")
    let heading = app.staticTexts["Hồ Hoàn Kiếm"]
    XCTAssertTrue(heading.waitForExistence(timeout: 10), "the detail")
    swipeFromTheLeftEdge(app)
    // A loaded runner can drop the first drag's events.
    if !heading.waitForNonExistence(timeout: 5), !flutterRow(app, "Search tab").exists {
      swipeFromTheLeftEdge(app)
    }
    XCTAssertTrue(heading.waitForNonExistence(timeout: 10), "the detail popped")
    XCTAssertFalse(flutterRow(app, "Search tab").exists, "not the whole case")
    XCTAssertTrue(back.waitForNonExistence(timeout: 10), "the native bar followed")
    XCTAssertTrue(flutterRow(app, "Hồ Hoàn Kiếm").waitForExistence(timeout: 10), "the results")
    let exit = searchExit(app)
    XCTAssertTrue(exit.waitForExistence(timeout: 10), "the search is still active")
    exit.tap()
    XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 2), "no keyboard left")
  }
}
