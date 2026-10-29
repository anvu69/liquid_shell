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

  /// One read of the bottom bar: the frames of every match of [selected]
  /// (mid-animation UIKit shows both forms of a tab: two "Home" buttons,
  /// the circle and the full one), and whether [other], an unselected tab,
  /// is in the bar. A snapshot, so a button that leaves the tree between
  /// two queries cannot fail the read. No bar: no frames.
  private func bar(
    _ app: XCUIApplication, selected: String, other: String
  ) -> (selected: [CGRect], otherShown: Bool) {
    guard let tree = try? app.tabBars.firstMatch.snapshot() else { return ([], false) }
    var buttons: [XCUIElementSnapshot] = []
    func collect(_ node: XCUIElementSnapshot) {
      if node.elementType == .button { buttons.append(node) }
      node.children.forEach(collect)
    }
    collect(tree)
    let named = { (name: String) in
      buttons.filter { $0.identifier == name || $0.label == name }.map(\.frame)
    }
    return (named(selected), named(other).contains { !$0.isEmpty })
  }

  /// The signal Step 1 recorded (it flips on 26.5 and 27): [selected] is
  /// the circle, and [other] is gone or every match of [selected] is the
  /// circle. Positive evidence only: with no bar (hidden, gone, the iPad's
  /// top bar) it is false.
  private func isMinimized(
    _ app: XCUIApplication, selected: String = "Home", other: String = "Explore"
  ) -> Bool {
    let bar = bar(app, selected: selected, other: other)
    let circles = bar.selected.filter { $0.width < 60 }
    return !circles.isEmpty && (!bar.otherShown || circles.count == bar.selected.count)
  }

  /// The whole bar: [other] is in it and every match of [selected] is
  /// wider than the circle. False with no bar, as [isMinimized] is.
  private func isExpanded(
    _ app: XCUIApplication, selected: String = "Home", other: String = "Explore"
  ) -> Bool {
    let bar = bar(app, selected: selected, other: other)
    return bar.otherShown && !bar.selected.isEmpty && bar.selected.allSatisfy { $0.width >= 60 }
  }

  /// Waits for the minimized bar ([want] true) or the whole one (false). A
  /// missing bar is neither, so it fails both.
  private func waitMinimized(
    _ app: XCUIApplication, _ want: Bool, _ why: String,
    selected: String = "Home", other: String = "Explore",
    file: StaticString = #filePath, line: UInt = #line
  ) {
    let reached = {
      want
        ? self.isMinimized(app, selected: selected, other: other)
        : self.isExpanded(app, selected: selected, other: other)
    }
    // The suite's 10 s, as every other wait: a slow runner stretches
    // UIKit's animations.
    XCTAssertTrue(wait(until: reached), why, file: file, line: line)
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
  /// The hold at the end stops a fling, so a slow reverse stays mid-content,
  /// unless a stalled main thread hands Flutter the moves, the hold and the
  /// lift in one burst: then the list flings on (VK-633), and a row read
  /// after the drag may have left the tree (`frameInTree`).
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

  /// [element]'s frame, or nil when it is not in the accessibility tree.
  /// Flutter drops a row scrolled past its cache from its semantics tree,
  /// and `frame` on a missing element fails the test: on a stalled CI
  /// runner a 300 pt drag became an 830-860 pt fling (VK-633). One
  /// snapshot, as `bar` reads the tab bar, so a row that leaves between two
  /// queries cannot fail the read.
  private func frameInTree(_ element: XCUIElement) -> CGRect? {
    (try? element.snapshot())?.frame
  }

  /// Whether [row] went up by more than [distance] from [start]. A row
  /// that left the tree went further still (VK-633).
  private func scrolled(
    _ row: XCUIElement, from start: CGFloat, by distance: CGFloat = 200
  ) -> Bool {
    guard let frame = frameInTree(row) else { return true }
    return frame.minY < start - distance
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

  /// [element]'s frame once two reads 0.5 s apart agree, or nil after
  /// 10 s: an element that morphs in (the search field from the ⌕) is
  /// still moving when it first exists.
  private func restingFrame(_ element: XCUIElement) -> CGRect? {
    var last = element.frame
    let deadline = Date().addingTimeInterval(10)
    while Date() < deadline {
      RunLoop.current.run(until: Date().addingTimeInterval(0.5))
      let now = element.frame
      if now == last { return now }
      last = now
    }
    return nil
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

  /// Spec P3b-2 §6.8: a page pushed on a plain tab minimizes the bar too,
  /// and the pop keeps its form (M2). The `pages` demo: Home's detail.
  func testAPushedPageOnHomeMinimizesTheBar() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "compact bar")
    let app = launch("pages")
    let detail = flutterRow(app, "Detail 1")
    XCTAssertTrue(detail.waitForExistence(timeout: 10), "Home's rows")
    detail.tap()
    let bar = app.navigationBars["Detail 1"]
    XCTAssertTrue(bar.waitForExistence(timeout: 10), "precondition: Home's pushed page")
    drag(app, dy: -300)
    waitMinimized(app, true, "a swipe on the pushed page minimizes", other: "Library")
    app.navigationBars.buttons["BackButton"].tap()
    XCTAssertTrue(bar.waitForNonExistence(timeout: 10), "popped")
    sleep(1)
    XCTAssertTrue(isMinimized(app, other: "Library"), "the pop keeps the bar's form")
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
    XCTAssertTrue(scrolled(row, from: before), "the drag scrolled the list")
    XCTAssertTrue(tabButton(app, "Explore").isHittable)
    XCTAssertGreaterThan(tabButton(app, "Home").frame.width, 60, "Home is not a circle")
    // On iPad 27 the top bar is not a tab bar in the tree (acceptance.md
    // §2): no bottom bar is not a minimized one.
    XCTAssertFalse(isMinimized(app), "the top bar is not read as minimized")
  }

  /// The lock, end to end (final review M5a): the pan on the Flutter view
  /// tracks a drag that moves no Flutter content, and the bar stays whole.
  /// XCTest pins the proxy's setters; this pins UIKit's own pan path. The
  /// drag starts on "Next tab", above the list (Flutter gives it to the
  /// button, which drops the tap once the finger moves), and goes up past
  /// UIKit's 20–40 pt: an unlocked proxy would scroll down and minimize.
  func testADragThatMovesNoContentKeepsTheBarWhole() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "compact bar")
    let app = launch("minimize")
    let row = flutterRow(app, "Home item 6")
    XCTAssertTrue(row.waitForExistence(timeout: 10), "Flutter's rows")
    waitMinimized(app, false, "precondition: the whole bar")
    let next = app.buttons["Next tab"]
    XCTAssertTrue(next.waitForExistence(timeout: 10), "the button above the list")
    let rowY = row.frame.minY
    let rise = next.frame.midY - app.windows.firstMatch.frame.minY - 4
    XCTAssertGreaterThan(rise, 60, "room to minimize above the button: \(next.frame)")
    let start = next.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    start.press(
      forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -rise)),
      withVelocity: XCUIGestureVelocity(rise / 0.3), thenHoldForDuration: 0.2)
    let deadline = Date().addingTimeInterval(2)
    repeat {
      XCTAssertTrue(isExpanded(app), "the bar stays whole")
      usleep(250_000)
    } while Date() < deadline
    XCTAssertEqual(row.frame.minY, rowY, "no Flutter content moved")
    XCTAssertTrue(app.tabBars.buttons["Home"].firstMatch.isSelected, "no tap: still Home")
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
    XCTAssertTrue(scrolled(row, from: before), "the drag scrolled Flutter's list")

    app.buttons["Next tab"].tap()
    XCTAssertTrue(
      flutterRow(app, "Explore item 1").waitForExistence(timeout: 10), "the tap reached Flutter")
    waitMinimized(
      app, false, "the app's tab change expands", selected: "Explore", other: "Home")
    XCTAssertTrue(app.tabBars.buttons["Explore"].firstMatch.isSelected, "native follows the app")
  }

  /// A programmatic scroll to the top expands the bar (Q3): the status-bar
  /// tap reaches Flutter's own scroll view, the Scaffold animates the list
  /// to the top, and Dart asks native to expand. UIKit alone would keep it
  /// minimized (spike §3.2). Q10 (the proxies' scrollsToTop off) is
  /// XCTest's: with up to two taps this test cannot tell who took the
  /// first.
  func testAStatusBarTapScrollsToTheTopAndExpands() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "compact bar")
    let app = launch("minimize")
    let row = flutterRow(app, "Home item 6")
    XCTAssertTrue(row.waitForExistence(timeout: 10), "Flutter's rows")
    let top = row.frame.minY
    drag(app, dy: -300)
    waitMinimized(app, true, "a swipe up minimizes")
    XCTAssertTrue(scrolled(row, from: top), "scrolled")

    // On the status bar, clear of the Dynamic Island. The first tap can
    // land on Flutter's accessibility mirror of the list instead
    // (FlutterSemanticsScrollView, scrollsToTop on; it exists while
    // semantics are on, always on a simulator, on a device under
    // VoiceOver, Switch Control or Speak Screen): UIKit scrolls the mirror
    // to the top and Flutter does not move. A tap after that reaches
    // Flutter's status-bar view (lldb, docs/qa/vk600/acceptance.md §3), so
    // the test taps again when the list is not at the top within 3 s.
    // Native chrome or not, the same.
    let statusBar = app.windows.firstMatch.coordinate(withNormalizedOffset: .zero)
      .withOffset(CGVector(dx: app.windows.firstMatch.frame.width * 0.85, dy: 15))
    // A row out of the tree is not back yet (VK-633).
    let atTop = { self.frameInTree(row).map { abs($0.minY - top) < 2 } ?? false }
    statusBar.tap()
    if !wait(timeout: 3, until: atTop) { statusBar.tap() }
    XCTAssertTrue(wait(until: atTop), "at the top again: \(String(describing: frameInTree(row)))")
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
    let fieldFrame = try XCTUnwrap(restingFrame(field), "the field comes to rest")
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
  /// the next launch. Every length comes from the window, so it runs on
  /// any iPad; one whose narrowest window stays regular skips.
  func testANarrowIPadWindowMinimizesLikeAnIPhone() throws {
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad")
    let app = launch()
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let grabber = springboard.otherElements["resize-grabber"]
    try XCTSkipUnless(grabber.waitForExistence(timeout: 10), "Windowed Apps: a resize grabber")
    let window = app.windows.firstMatch
    let wide = window.frame
    addTeardownBlock {
      grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
        forDuration: 0.6,
        thenDragTo: springboard.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1)))
      // A window left narrow would fail the next iPad test for no reason
      // of its own.
      XCTAssertTrue(
        self.wait { window.frame.width >= wide.width - 1 },
        "widened back: \(window.frame), was \(wide)")
    }
    // iPadOS's narrowest window is 375–410 pt (Task 8): ask for 375.
    let handle = grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    handle.press(
      forDuration: 0.6,
      thenDragTo: handle.withOffset(CGVector(dx: -(wide.width - 375), dy: 0)))
    let home = app.tabBars.buttons["Home"].firstMatch
    guard wait(until: { home.exists && home.frame.minY > window.frame.midY }) else {
      throw XCTSkip("the narrowest window stays regular: \(window.frame), was \(wide)")
    }
    XCTAssertLessThan(window.frame.width, wide.width, "narrowed")

    let row = flutterRow(app, "Home item 8")
    XCTAssertTrue(row.waitForExistence(timeout: 10), "Flutter's rows")
    let before = row.frame.minY
    drag(app, dy: -300)
    waitMinimized(app, true, "a swipe up minimizes in a narrow window")
    XCTAssertTrue(scrolled(row, from: before), "the drag scrolled the list")
    window.swipeDown(velocity: .fast)
    window.swipeDown(velocity: .fast)
    waitMinimized(app, false, "a fling that reaches the top expands")
  }
}
