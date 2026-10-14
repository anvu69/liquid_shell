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

  /// The × that ends the search: UIKit's ("Cancel" or "Close") or the
  /// Flutter field's ("Cancel search"), which clear and unfocus. The iPad's
  /// stacked field has no ×; its ⓧ ("Clear text") does the same. Never the
  /// iPhone field's own ⓧ, which only clears: the × is there first.
  private func searchExit(_ app: XCUIApplication) -> XCUIElement {
    let cancel = app.buttons.matching(
      NSPredicate(format: "label IN %@", ["Cancel", "Close", "Hủy", "Đóng", "Cancel search"])
    ).firstMatch
    return cancel.waitForExistence(timeout: 5) ? cancel : app.buttons["Clear text"].firstMatch
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
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 30), "the keyboard")
    field.typeText("ho hoan")
    let result = flutterRow(app, "Hồ Hoàn Kiếm")
    XCTAssertTrue(result.waitForExistence(timeout: 10), "Flutter's live results")

    result.tap()
    let back = app.navigationBars.buttons["BackButton"]
    XCTAssertTrue(back.waitForExistence(timeout: 10), "the native glass back button")
    back.tap()
    XCTAssertTrue(flutterRow(app, "Hồ Hoàn Kiếm").waitForExistence(timeout: 10))

    let exit = searchExit(app)
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
    // Typing before the keyboard is up drops the text (seen under load).
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 30), "the keyboard")
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
    // Typing before the keyboard is up drops the text (seen under load).
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 30), "the keyboard")
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
/// above the case list as a person opens it. While the search is active
/// the case stays, as in the Flutter field (spec P3b §9.4), and the
/// keyboard can be dismissed, never left behind with no field. On a page
/// pushed inside the search tab the swipe pops that page (Apple Music) and
/// the search stays as it was there.
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
    // One wait for either field: the Flutter case has no native one, and
    // waiting that out first cost every Flutter run the whole 10 s.
    let native = app.searchFields.firstMatch
    let flutter = app.textFields.firstMatch
    let either = app.descendants(matching: .any).matching(
      NSPredicate(
        format: "elementType IN %@",
        [XCUIElement.ElementType.searchField, .textField].map(\.rawValue))
    ).firstMatch
    XCTAssertTrue(either.waitForExistence(timeout: 10), "a field")
    let field = native.exists ? native : flutter
    field.tap()
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 30), "the keyboard")
    field.typeText("ho hoan")
    XCTAssertTrue(flutterRow(app, "Hồ Hoàn Kiếm").waitForExistence(timeout: 10), "the results")
    return app
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
    // A loaded runner can drop the first drag's events. The retry is
    // recorded (activity and log), so a regression that always needs two
    // swipes shows; a first swipe that popped the whole case still fails.
    if !heading.waitForNonExistence(timeout: 5), !flutterRow(app, "Search tab").exists {
      XCTContext.runActivity(named: "VK-551: retry the edge swipe (the first was dropped)") { _ in
        print("SearchUITests: the first edge swipe was dropped; swiping again")
        swipeFromTheLeftEdge(app)
      }
    }
    XCTAssertTrue(heading.waitForNonExistence(timeout: 10), "the detail popped")
    XCTAssertFalse(flutterRow(app, "Search tab").exists, "not the whole case")
    XCTAssertTrue(back.waitForNonExistence(timeout: 10), "the native bar followed")
    XCTAssertTrue(flutterRow(app, "Hồ Hoàn Kiếm").waitForExistence(timeout: 10), "the results")
    let exit = searchExit(app)
    XCTAssertTrue(exit.waitForExistence(timeout: 10), "the search is still active")
    exit.tap()
    XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 10), "no keyboard left")
  }
}

/// VK-571: with the native search active and the keyboard up, a drag on
/// the results or a tap on a scope puts the keyboard away and keeps the
/// search, as Apple Music and Settings do: the query stays in the field,
/// the results stay, and the search stays active (the iPhone's ×, the
/// iPad's field in the title row).
extension SearchUITests {
  /// The native search tab active, "ho hoan" typed, its result shown.
  fileprivate func typeInTheNativeSearch() -> (XCUIApplication, XCUIElement) {
    let app = launch()
    let tab = searchTabButton(app)
    XCTAssertTrue(tab.waitForExistence(timeout: timeout))
    tab.tap()
    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 10), "the native field")
    field.tap()
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 30), "the keyboard")
    field.typeText("ho hoan")
    XCTAssertTrue(flutterRow(app, "Hồ Hoàn Kiếm").waitForExistence(timeout: 10), "the results")
    return (app, field)
  }

  /// The keyboard is gone; the field keeps "ho hoan" and the results stay.
  /// The search is still active, as native shows it with the keyboard
  /// down (measured on iOS 26.5 simulators):
  /// - iPhone: UIKit's × ("Close" / "Cancel") beside the field.
  /// - iPad: no ×; the stacked field stays risen into the title row, where
  ///   it was while focused ([activeFrame]; an ended search drops it to the
  ///   row below), with its ⓧ ("Clear text") for the kept text.
  fileprivate func expectTheKeyboardGoneAndTheSearchKept(
    _ app: XCUIApplication, _ field: XCUIElement, activeFrame: CGRect
  ) {
    XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 10), "the keyboard went")
    XCTAssertEqual(field.value as? String, "ho hoan", "the query stays")
    XCTAssertTrue(flutterRow(app, "Hồ Hoàn Kiếm").exists, "the results stay")
    if UIDevice.current.userInterfaceIdiom == .pad {
      XCTAssertEqual(field.frame, activeFrame, "still risen into the title row: active")
      XCTAssertTrue(app.buttons["Clear text"].exists, "the field's ⓧ for the kept text")
    } else {
      let close = app.buttons.matching(
        NSPredicate(format: "label IN %@", ["Cancel", "Close", "Hủy", "Đóng"])
      ).firstMatch
      XCTAssertTrue(close.waitForExistence(timeout: 5), "UIKit's ×: the search is active")
    }
  }

  func testNativeADragOnTheResultsDismissesTheKeyboardAndKeepsTheSearch() {
    let (app, field) = typeInTheNativeSearch()
    let activeFrame = field.frame
    let row = flutterRow(app, "Hồ Hoàn Kiếm")
    row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
      .press(
        forDuration: 0.05,
        thenDragTo: row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -1.5)))
    expectTheKeyboardGoneAndTheSearchKept(app, field, activeFrame: activeFrame)
    // A tap on the field brings the keyboard back, the query intact.
    field.tap()
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10), "the keyboard again")
    XCTAssertEqual(field.value as? String, "ho hoan")
  }

  func testNativeAScopeTapDismissesTheKeyboardAndKeepsTheSearch() {
    let (app, field) = typeInTheNativeSearch()
    let activeFrame = field.frame
    let places = app.buttons["Places"].firstMatch
    XCTAssertTrue(places.waitForExistence(timeout: 10), "the scope bar")
    places.tap()
    expectTheKeyboardGoneAndTheSearchKept(app, field, activeFrame: activeFrame)
    XCTAssertTrue(places.isSelected, "the scope changed")
  }
}

/// VK-567: the search case pushed above the case list, as a person opens
/// it (a shell that is itself a pushed page), its search inactive. As on
/// iOS the left-edge swipe pops the selected tab's top page, in Home (a
/// Flutter page bar) and in the search tab (the native bar follows); only a
/// tab at its root lets it pop the whole case. Flutter used to give the
/// swipe to the case's route first: every swipe popped the whole case.
extension SearchUITests {
  /// A left-edge swipe that should pop [page]. A loaded runner can drop
  /// the first drag's events: one more swipe, recorded, while [page] is
  /// still there and the case list is not, so a swipe that popped the
  /// whole case still fails.
  fileprivate func swipeBack(_ app: XCUIApplication, popping page: XCUIElement) {
    swipeFromTheLeftEdge(app)
    if !page.waitForNonExistence(timeout: 5), !flutterRow(app, "Search tab").exists {
      XCTContext.runActivity(named: "VK-567: retry the edge swipe (the first was dropped)") { _ in
        print("SearchUITests: the first edge swipe was dropped; swiping again")
        swipeFromTheLeftEdge(app)
      }
    }
  }

  func testNativeAPushedCaseTheEdgeSwipePopsTheTabsPageThenTheCase() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "iPhone only")
    let app = launch(demo: "search-above")
    let caseList = flutterRow(app, "Search tab")

    // Home: a song's page, pushed in Home's own navigator.
    let song = flutterRow(app, "Diễm xưa")
    XCTAssertTrue(song.waitForExistence(timeout: timeout), "Home's songs")
    song.tap()
    let songPage = app.staticTexts["Trịnh Công Sơn"].firstMatch
    XCTAssertTrue(songPage.waitForExistence(timeout: 30), "the song's page")
    swipeBack(app, popping: songPage)
    XCTAssertTrue(songPage.waitForNonExistence(timeout: 10), "the song's page popped")
    XCTAssertFalse(caseList.exists, "not the whole case")
    XCTAssertTrue(song.waitForExistence(timeout: 10), "Home's songs again")

    // The search tab, the search inactive: a category's page under the
    // native bar.
    searchTabButton(app).tap()
    let category = flutterRow(app, "Bolero")
    XCTAssertTrue(category.waitForExistence(timeout: 30), "the categories")
    category.tap()
    let back = app.navigationBars.buttons["BackButton"]
    XCTAssertTrue(back.waitForExistence(timeout: 30), "the native glass back button")
    let categoryPage = flutterRow(app, "Thành phố buồn")
    XCTAssertTrue(categoryPage.waitForExistence(timeout: 10), "the category's page")
    swipeBack(app, popping: categoryPage)
    XCTAssertTrue(categoryPage.waitForNonExistence(timeout: 10), "the category's page popped")
    XCTAssertFalse(caseList.exists, "not the whole case")
    XCTAssertTrue(back.waitForNonExistence(timeout: 10), "the native bar followed")
    XCTAssertTrue(flutterRow(app, "Nhạc Trịnh").waitForExistence(timeout: 10), "the categories again")
    XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 10), "the search inactive")

    // At the tab's root the swipe pops the case.
    swipeFromTheLeftEdge(app)
    if !caseList.waitForExistence(timeout: 5) {
      XCTContext.runActivity(named: "VK-567: retry the edge swipe (the first was dropped)") { _ in
        print("SearchUITests: the first edge swipe was dropped; swiping again")
        swipeFromTheLeftEdge(app)
      }
    }
    XCTAssertTrue(caseList.waitForExistence(timeout: 10), "the case popped at the tab's root")
  }
}
