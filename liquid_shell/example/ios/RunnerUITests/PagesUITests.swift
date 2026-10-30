import XCTest

/// Spec P3b-2 §8.2: real taps and swipes on a plain tab's pushed page with
/// native chrome (the example's `pages` demo): UIKit's bar, its glass back
/// circle, Flutter's edge swipe, and `LiquidHideChrome` keeping the page's
/// bar.
final class PagesUITests: XCTestCase {
  private let timeout: TimeInterval = 90

  override func setUp() { continueAfterFailure = false }

  private func launch() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["LIQUID_SHELL_EXAMPLE_DEMO"] = "pages"
    app.launch()
    XCTAssertTrue(row(app, "Detail 1").waitForExistence(timeout: timeout), "Home's rows")
    return app
  }

  /// A Flutter row (semantics on): its label starts with [title].
  private func row(_ app: XCUIApplication, _ title: String) -> XCUIElement {
    app.descendants(matching: .any)
      .matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
  }

  /// A tab's button: in the iPhone's tab bar, or the iPad's top bar.
  private func tabButton(_ app: XCUIApplication, _ name: String) -> XCUIElement {
    let inBar = app.tabBars.buttons[name]
    return inBar.exists ? inBar : app.buttons[name].firstMatch
  }

  /// A swipe from the leading edge across most of the window: Flutter's
  /// Cupertino back gesture starts within 20 pt of the edge.
  private func swipeFromTheEdge(_ app: XCUIApplication) {
    app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)).withOffset(CGVector(dx: 2, dy: 0))
      .press(
        forDuration: 0.05,
        thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
  }

  func testABackTapAndSwipeOnHomesPushedPage() {
    let app = launch()
    row(app, "Detail 1").tap()
    let bar = app.navigationBars["Detail 1"]
    XCTAssertTrue(bar.waitForExistence(timeout: 10), "UIKit's bar on Home's pushed page")
    let back = app.navigationBars.buttons["BackButton"]
    XCTAssertTrue(back.waitForExistence(timeout: 10), "the native glass back button")
    XCTAssertTrue(row(app, "Detail 1 item 1").exists, "the Flutter page under it")
    back.tap()
    XCTAssertTrue(bar.waitForNonExistence(timeout: 10), "the back tap pops")
    XCTAssertTrue(row(app, "Detail 2").waitForExistence(timeout: 10), "Home again")

    // Q13: the edge swipe is Flutter's; the native bar follows at release.
    row(app, "Detail 2").tap()
    let second = app.navigationBars["Detail 2"]
    XCTAssertTrue(second.waitForExistence(timeout: 10), "pushed again")
    let heading = row(app, "Detail 2 item 1")
    XCTAssertTrue(heading.waitForExistence(timeout: 10))
    swipeFromTheEdge(app)
    // A loaded CI runner can drop the first drag's events (SearchUITests):
    // one more swipe, and a broken back gesture still fails.
    if !heading.waitForNonExistence(timeout: 5) { swipeFromTheEdge(app) }
    XCTAssertTrue(heading.waitForNonExistence(timeout: 10), "Flutter popped the page")
    XCTAssertTrue(second.waitForNonExistence(timeout: 10), "the native bar followed")
  }

  /// Spec P3b-2 §4.4: `LiquidHideChrome` over a `LiquidPage` hides the tab
  /// bar and keeps the page's navigation bar; back brings the tab bar back.
  func testHideChromeOverAPageKeepsTheNavigationBar() {
    let app = launch()
    XCTAssertTrue(tabButton(app, "Library").exists, "precondition: the tab bar")
    row(app, "Photo").tap()
    let bar = app.navigationBars["Photo"]
    XCTAssertTrue(bar.waitForExistence(timeout: 10), "the page keeps its bar")
    XCTAssertTrue(
      tabButton(app, "Library").waitForNonExistence(timeout: 10), "the tab bar hides")
    app.navigationBars.buttons["BackButton"].tap()
    XCTAssertTrue(bar.waitForNonExistence(timeout: 10), "popped")
    XCTAssertTrue(tabButton(app, "Library").waitForExistence(timeout: 10), "the tab bar is back")
  }
}
