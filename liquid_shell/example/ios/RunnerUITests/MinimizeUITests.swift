import XCTest

/// Spec VK-600 §12.5: real swipes on Flutter content minimize the native
/// tab bar; UIKit's rules bring it back.
///
/// "Minimized" is read from UIKit's accessibility tree, the signal Task 8
/// recorded on iOS 26.5 and 27.0 (docs/qa/vk600/acceptance.md): the
/// unselected tab buttons leave the tree, and the selected one shrinks
/// from 94 to a 48 pt circle.
final class MinimizeUITests: XCTestCase {
  private let timeout: TimeInterval = 90

  override func setUp() { continueAfterFailure = false }

  private func launch(_ demo: String = "tabs") -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["LIQUID_SHELL_EXAMPLE_DEMO"] = demo
    app.launch()
    XCTAssertTrue(tabButton(app, "Home").waitForExistence(timeout: timeout))
    return app
  }

  /// A tab's button. The iPhone's bar is a tab bar in the accessibility
  /// tree; the iPad 27 top bar is not (its buttons sit in a plain group).
  private func tabButton(_ app: XCUIApplication, _ name: String) -> XCUIElement {
    UIDevice.current.userInterfaceIdiom == .phone
      ? app.tabBars.buttons[name] : app.buttons[name].firstMatch
  }

  /// The signal Step 1 recorded (it flips on 26.5 and 27): [other], an
  /// unselected tab, is gone or covered, or [selected] is the circle.
  /// Mid-animation UIKit shows both forms of a tab (two "Home" buttons, the
  /// circle and the full one), so every match counts.
  private func isMinimized(
    _ app: XCUIApplication, selected: String = "Home", other: String = "Explore"
  ) -> Bool {
    let others = app.tabBars.buttons.matching(identifier: other).allElementsBoundByIndex
    if !others.contains(where: { $0.exists && $0.isHittable }) { return true }
    return app.tabBars.buttons.matching(identifier: selected).allElementsBoundByIndex
      .allSatisfy { !$0.exists || $0.frame.width < 60 }
  }

  private func waitMinimized(
    _ app: XCUIApplication, _ want: Bool, _ why: String,
    selected: String = "Home", other: String = "Explore",
    file: StaticString = #filePath, line: UInt = #line
  ) {
    let minimized = { self.isMinimized(app, selected: selected, other: other) }
    let deadline = Date().addingTimeInterval(5)
    while Date() < deadline, minimized() != want { usleep(100_000) }
    XCTAssertEqual(minimized(), want, why, file: file, line: line)
  }

  /// Like [waitMinimized], but the state must also hold for a while: an
  /// expand would start within UIKit's animation, not at once.
  private func staysMinimized(
    _ app: XCUIApplication, _ why: String,
    file: StaticString = #filePath, line: UInt = #line
  ) {
    let deadline = Date().addingTimeInterval(1.5)
    repeat {
      XCTAssertTrue(isMinimized(app), why, file: file, line: line)
      usleep(250_000)
    } while Date() < deadline
  }

  /// A drag on the list over [seconds]: [dy] < 0 scrolls the content down.
  /// The hold at the end stops a fling, so a slow reverse stays mid-content.
  /// Window-relative: an iPad window need not start at the screen's origin.
  private func drag(_ app: XCUIApplication, dy: CGFloat, seconds: CGFloat = 0.3) {
    let start = app.windows.firstMatch
      .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: dy < 0 ? 0.7 : 0.3))
    start.press(
      forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: dy)),
      withVelocity: XCUIGestureVelocity(abs(dy) / seconds), thenHoldForDuration: 0.2)
  }

  /// A Flutter row (semantics on): its title and subtitle merge into one
  /// label, which starts with the title.
  private func flutterRow(_ app: XCUIApplication, _ title: String) -> XCUIElement {
    app.descendants(matching: .any)
      .matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
  }

  /// Polls [condition] until it holds or [timeout] passes: a loaded runner
  /// stretches Flutter's animations as well as UIKit's.
  private func wait(timeout: TimeInterval = 10, until condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
      if condition() { return true }
      RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    } while Date() < deadline
    return condition()
  }

  func testAScrollMinimizesAndAFlingToTheTopExpands() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "compact bar")
    let app = launch()
    drag(app, dy: -300)
    waitMinimized(app, true, "a swipe up minimizes")
    drag(app, dy: 100, seconds: 1.0)
    staysMinimized(app, "a slow reverse drag in mid-content keeps it")
    app.windows.firstMatch.swipeDown(velocity: .fast)
    app.windows.firstMatch.swipeDown(velocity: .fast)
    waitMinimized(app, false, "a fling that reaches the top expands")
  }

  func testATapOnTheCircleExpands() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "compact bar")
    let app = launch()
    drag(app, dy: -300)
    waitMinimized(app, true, "minimized")
    app.tabBars.buttons["Home"].tap()
    waitMinimized(app, false, "the circle expands")
  }

  func testTheRegularTopBarNeverMinimizes() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad")
    let app = launch()
    let row = flutterRow(app, "Home item 12")
    XCTAssertTrue(row.waitForExistence(timeout: 10), "Flutter's rows")
    let before = row.frame.minY
    drag(app, dy: -300)
    sleep(2)
    XCTAssertLessThan(row.frame.minY, before - 200, "the drag scrolled the list")
    XCTAssertTrue(tabButton(app, "Explore").isHittable)
    XCTAssertGreaterThan(tabButton(app, "Home").frame.width, 60, "Home is not a circle")
  }

  /// The pan on the Flutter view only observes: Flutter still gets the
  /// drag (its list moves under the finger) and, minimized, a tap. The tap
  /// is the app's own tab change, which expands the bar (Q4): UIKit alone
  /// keeps it minimized on a programmatic selection (spike §3.2).
  func testFlutterGetsTheDragAndTheTapAndTheAppsTabChangeExpands() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "compact bar")
    let app = launch("minimize")
    let row = flutterRow(app, "Home item 6")
    XCTAssertTrue(row.waitForExistence(timeout: 10), "Flutter's rows")
    let before = row.frame.minY
    drag(app, dy: -300)
    waitMinimized(app, true, "a swipe up minimizes")
    XCTAssertLessThan(row.frame.minY, before - 200, "the drag scrolled Flutter's list")

    app.buttons["Next tab"].tap()
    XCTAssertTrue(
      flutterRow(app, "Explore item 1").waitForExistence(timeout: 10), "the tap reached Flutter")
    waitMinimized(
      app, false, "the app's tab change expands", selected: "Explore", other: "Home")
    XCTAssertTrue(app.tabBars.buttons["Explore"].firstMatch.isSelected, "native follows the app")
  }

  /// A programmatic scroll to the top expands the bar (Q3): the status-bar
  /// tap reaches Flutter's own scroll view (no proxy competes for it, Q10),
  /// the Scaffold animates the list to the top, and Dart asks native to
  /// expand. UIKit alone would keep it minimized (spike §3.2).
  func testAStatusBarTapScrollsToTheTopAndExpands() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "compact bar")
    let app = launch("minimize")
    let row = flutterRow(app, "Home item 6")
    XCTAssertTrue(row.waitForExistence(timeout: 10), "Flutter's rows")
    let top = row.frame.minY
    drag(app, dy: -300)
    waitMinimized(app, true, "a swipe up minimizes")
    XCTAssertLessThan(row.frame.minY, top - 200, "scrolled")

    // On the status bar, clear of the Dynamic Island. The first tap can
    // land on Flutter's accessibility mirror of the list instead
    // (FlutterSemanticsScrollView, scrollsToTop on while semantics are, as
    // under XCUITest or VoiceOver): UIKit scrolls the mirror to the top and
    // Flutter does not move. The next tap reaches Flutter's status-bar view
    // (lldb, docs/qa/vk600/acceptance.md). Native chrome or not, the same;
    // liquid_shell's proxies never take it (scrollsToTop off, Q10).
    let statusBar = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
      .withOffset(CGVector(dx: app.windows.firstMatch.frame.width * 0.85, dy: 15))
    let atTop = { abs(row.frame.minY - top) < 2 }
    statusBar.tap()
    if !wait(timeout: 3, until: atTop) { statusBar.tap() }
    XCTAssertTrue(wait(until: atTop), "at the top again: \(row.frame)")
    waitMinimized(app, false, "a programmatic scroll to the top expands")
  }

  /// Q5: no minimize while the search tab is selected. A minimized bar's ⌕
  /// opens the search as before, with VK-550's scopes, and the keyboard
  /// comes only with a tap on the field (Q13). Leaving search expands.
  func testTheSearchTabFromAMinimizedBarKeepsItsFieldScopesAndKeyboard() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "compact bar")
    let app = launch("search")
    app.tabBars.buttons["Library"].tap()
    XCTAssertTrue(flutterRow(app, "Diễm xưa").waitForExistence(timeout: 10), "Library's list")
    drag(app, dy: -300)
    waitMinimized(app, true, "a swipe up minimizes", selected: "Library", other: "Home")

    let inBar = app.tabBars.buttons["Search"]
    let search = inBar.exists ? inBar : app.buttons["Search"].firstMatch
    XCTAssertTrue(search.waitForExistence(timeout: 10), "the ⌕")
    search.tap()
    let field = app.searchFields.firstMatch
    XCTAssertTrue(field.waitForExistence(timeout: 10), "the native field")
    XCTAssertFalse(app.keyboards.firstMatch.exists, "selected, not focused (Q13)")

    // A drag on the search page minimizes nothing: the bar keeps its form.
    let fieldFrame = field.frame
    drag(app, dy: -300)
    sleep(2)
    XCTAssertEqual(field.frame, fieldFrame, "the search keeps its bar")

    field.tap()
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 30), "the keyboard")
    field.typeText("pho")
    let place = flutterRow(app, "Phố cổ Hà Nội")
    XCTAssertTrue(place.waitForExistence(timeout: 10), "All: a place")
    let scopes = app.segmentedControls.firstMatch
    XCTAssertTrue(scopes.waitForExistence(timeout: 10), "UIKit's scope bar")
    XCTAssertLessThan(scopes.frame.minY, 120, "at the top: \(scopes.frame)")
    scopes.buttons["Songs"].tap()
    XCTAssertTrue(place.waitForNonExistence(timeout: 10), "Songs: no place")

    let cancel = app.buttons.matching(
      NSPredicate(format: "label IN %@", ["Cancel", "Close", "Hủy", "Đóng"])
    ).firstMatch
    XCTAssertTrue(cancel.waitForExistence(timeout: 10), "×")
    cancel.tap()
    XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 10), "dismissed")

    let library = app.buttons["Library"].firstMatch
    XCTAssertTrue(library.waitForExistence(timeout: 10), "the previous tab's circle")
    library.tap()
    XCTAssertTrue(
      wait { app.tabBars.buttons["Library"].firstMatch.isSelected }, "Library again")
    waitMinimized(app, false, "leaving search expands", selected: "Library", other: "Home")
  }

  /// Q6: a narrow iPad window is compact, with the iPhone's bottom bar,
  /// and minimizes as an iPhone does. In Windowed Apps (iPadOS 26) the
  /// window has SpringBoard's resize grabber: the test narrows the window
  /// with it, and widens it back after, since iPadOS keeps the size for
  /// the next launch.
  func testANarrowIPadWindowMinimizesLikeAnIPhone() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad")
    let app = launch()
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let grabber = springboard.otherElements["resize-grabber"]
    try XCTSkipUnless(grabber.waitForExistence(timeout: 10), "Windowed Apps: a resize grabber")
    addTeardownBlock {
      grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
        forDuration: 0.6,
        thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1)))
    }
    let handle = grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    handle.press(
      forDuration: 0.6,
      thenDragTo: handle.withOffset(CGVector(dx: -springboard.frame.width / 2, dy: 0)))
    let window = app.windows.firstMatch
    let home = app.tabBars.buttons["Home"].firstMatch
    XCTAssertTrue(
      wait { home.exists && home.frame.minY > window.frame.midY },
      "compact: the bottom bar in \(window.frame)")
    XCTAssertLessThan(window.frame.width, springboard.frame.width / 2 + 1, "narrow")

    let row = flutterRow(app, "Home item 8")
    XCTAssertTrue(row.waitForExistence(timeout: 10), "Flutter's rows")
    let before = row.frame.minY
    drag(app, dy: -300)
    waitMinimized(app, true, "a swipe up minimizes in a narrow window")
    XCTAssertLessThan(row.frame.minY, before - 200, "the drag scrolled the list")
    window.swipeDown(velocity: .fast)
    window.swipeDown(velocity: .fast)
    waitMinimized(app, false, "a fling that reaches the top expands")
  }
}
