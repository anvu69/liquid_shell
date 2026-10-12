import XCTest

/// Drives the native tab bar through the acceptance sequences of spec
/// VK-503 §17.4 while tool/tab_frames.sh records the screen. Launched with
/// LIQUID_SHELL_EXAMPLE_DEMO=tabs (the basic case, native chrome).
/// Coordinates are in points on the iPhone 17 Pro (402 × 874).
final class TabFidelityUITests: XCTestCase {
  private let y: CGFloat = 874 - 21 - 31

  private func point(_ app: XCUIApplication, _ x: CGFloat) -> XCUICoordinate {
    app.coordinate(withNormalizedOffset: .zero)
      .withOffset(CGVector(dx: x, dy: y))
  }

  private func idle() { Thread.sleep(forTimeInterval: 1.0) }

  func testSequences() throws {
    // The sequences and coordinates are the iPhone 17 Pro's bottom bar; an
    // iPad's tab bar is at the top (make ios-ui runs on both).
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "iPhone only")
    let app = XCUIApplication()
    app.launchEnvironment["LIQUID_SHELL_EXAMPLE_DEMO"] = "tabs"
    app.launch()
    XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 60))
    // tool/tab_frames.sh cuts the recording here.
    print("TABFID start")
    idle(); idle()
    // tap_1_2, tap_2_3, tap_3_1
    for x: CGFloat in [201, 287, 115] { point(app, x).tap(); idle() }
    // press_hold
    point(app, 115).press(forDuration: 1.0); idle()
    // slow_drag: 115 → 287 at 90 pt/s. No hold before the lift, as in the
    // Flutter run: a held finger makes the release a motion onset of its
    // own, and tool/tab_strips.dart would pair every later strip wrongly.
    point(app, 115).press(
      forDuration: 0.05, thenDragTo: point(app, 287),
      withVelocity: XCUIGestureVelocity(90), thenHoldForDuration: 0)
    idle()
    // fast_flick: 287 → 115 at 1500 pt/s
    point(app, 287).press(
      forDuration: 0.05, thenDragTo: point(app, 115),
      withVelocity: XCUIGestureVelocity(1500), thenHoldForDuration: 0)
    idle()
    // minimize, then expand by a tap on the circle
    app.swipeUp(); idle()
    app.coordinate(withNormalizedOffset: .zero)
      .withOffset(CGVector(dx: 52, dy: 822)).tap()
    idle()
  }
}
