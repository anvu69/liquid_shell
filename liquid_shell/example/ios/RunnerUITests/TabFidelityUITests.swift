import XCTest

/// Drives the native tab bar through the acceptance sequences of spec
/// VK-503 §17.4 while tool/tab_frames.sh records the screen, and checks
/// the selected tab after each one. Launched with
/// LIQUID_SHELL_EXAMPLE_DEMO=tabs (the basic case, native chrome: Home,
/// Explore, Settings). Every point is taken from the tab buttons' frames,
/// so it runs on any iPhone, not only the iPhone 17 Pro of the recordings.
final class TabFidelityUITests: XCTestCase {
  private let timeout: TimeInterval = 60

  override func setUp() {
    continueAfterFailure = false
  }

  private func idle() { Thread.sleep(forTimeInterval: 1.0) }

  /// A screen point, as the sequences give them.
  private func point(_ app: XCUIApplication, _ p: CGPoint) -> XCUICoordinate {
    app.coordinate(withNormalizedOffset: .zero)
      .withOffset(CGVector(dx: p.x, dy: p.y))
  }

  private func centre(_ element: XCUIElement) -> CGPoint {
    CGPoint(x: element.frame.midX, y: element.frame.midY)
  }

  /// Polls [condition] until it holds or [timeout] passes: a loaded
  /// runner stretches UIKit's animations.
  private func wait(timeout: TimeInterval = 5, until condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
      if condition() { return true }
      RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    } while Date() < deadline
    return condition()
  }

  /// Whether [element] is on screen to be tapped (false when it is gone).
  private func shown(_ element: XCUIElement) -> Bool {
    element.exists && element.isHittable
  }

  /// Waits until [tab] is the selected one and the others are not.
  private func expectSelected(
    _ tab: String, among tabs: [String: XCUIElement], after step: String,
    file: StaticString = #filePath, line: UInt = #line
  ) {
    let selected = NSPredicate(format: "selected == YES")
    let shown = expectation(for: selected, evaluatedWith: tabs[tab]!)
    XCTAssertEqual(
      XCTWaiter().wait(for: [shown], timeout: 5), .completed,
      "\(step): \(tab) is selected", file: file, line: line)
    for (name, button) in tabs where name != tab {
      XCTAssertFalse(button.isSelected, "\(step): \(name) is not selected", file: file, line: line)
    }
  }

  func testSequences() throws {
    // The sequences are the iPhone's bottom bar; an iPad's tab bar is at
    // the top (make ios-ui runs on both).
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "iPhone only")
    let app = XCUIApplication()
    app.launchEnvironment["LIQUID_SHELL_EXAMPLE_DEMO"] = "tabs"
    app.launch()
    let bar = app.tabBars.firstMatch
    XCTAssertTrue(bar.waitForExistence(timeout: timeout))
    let tabs = [
      "Home": bar.buttons["Home"],
      "Explore": bar.buttons["Explore"],
      "Settings": bar.buttons["Settings"],
    ]
    for (name, button) in tabs {
      XCTAssertTrue(button.waitForExistence(timeout: 10), "the \(name) tab")
    }
    expectSelected("Home", among: tabs, after: "launch")
    let home = centre(tabs["Home"]!)
    let explore = centre(tabs["Explore"]!)
    let settings = centre(tabs["Settings"]!)
    XCTAssertLessThan(home.x, explore.x)
    XCTAssertLessThan(explore.x, settings.x)

    // tool/tab_frames.sh cuts the recording here.
    print("TABFID start")
    idle(); idle()
    // tap_1_2, tap_2_3, tap_3_1
    for (name, p) in [("Explore", explore), ("Settings", settings), ("Home", home)] {
      point(app, p).tap()
      idle()
      expectSelected(name, among: tabs, after: "tap \(name)")
    }
    // press_hold on the selected tab: it stays selected.
    point(app, home).press(forDuration: 1.0); idle()
    expectSelected("Home", among: tabs, after: "press_hold")
    // slow_drag: Home → Settings at 90 pt/s. No hold before the lift, as in
    // the Flutter run: a held finger makes the release a motion onset of
    // its own, and tool/tab_strips.dart would pair every later strip
    // wrongly.
    point(app, home).press(
      forDuration: 0.05, thenDragTo: point(app, settings),
      withVelocity: XCUIGestureVelocity(90), thenHoldForDuration: 0)
    idle()
    expectSelected("Settings", among: tabs, after: "slow_drag")
    // fast_flick: Settings → Home at 1500 pt/s
    point(app, settings).press(
      forDuration: 0.05, thenDragTo: point(app, home),
      withVelocity: XCUIGestureVelocity(1500), thenHoldForDuration: 0)
    idle()
    expectSelected("Home", among: tabs, after: "fast_flick")
    // The minimize, then the expand by a tap on the circle. Since VK-600
    // the native bar minimizes on a Flutter scroll too (`minimizeOnScroll`
    // drives both bars), so native strips 7 and 8 are UIKit's own minimize
    // and expand, as the Flutter run's are. Before VK-600 the native swipe
    // only scrolled the page (docs/qa/vk503/acceptance.md).
    app.swipeUp(); idle()
    XCTAssertTrue(
      wait { !shown(tabs["Explore"]!) && !shown(tabs["Settings"]!) },
      "native: the swipe minimizes the bar (VK-600)")
    // The bar sits as far from the screen's side as from its bottom, so
    // the circle's centre is that far in from the leading edge: the
    // Flutter circle's, and UIKit's minimized one's (VK-600).
    let window = app.windows.firstMatch.frame
    let inset = window.maxY - home.y
    point(app, CGPoint(x: window.minX + inset, y: home.y)).tap()
    idle()
    // Mid-expand UIKit shows both forms of Home (the circle and the whole
    // tab, docs/qa/vk600/acceptance.md §2), and `bar.buttons["Home"]`
    // would match two: wait for the whole bar first.
    XCTAssertTrue(
      wait(timeout: 10) {
        bar.buttons.matching(identifier: "Home").count == 1 && shown(tabs["Explore"]!)
      }, "whole again: one Home, and Explore")
    expectSelected("Home", among: tabs, after: "the tap at the circle")
  }
}
