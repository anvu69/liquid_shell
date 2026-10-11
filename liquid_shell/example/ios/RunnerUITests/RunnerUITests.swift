import XCTest

/// Real taps on native dialogs (spec P3a §9.4). Launched with
/// LIQUID_SHELL_EXAMPLE_DEMO, the example shows the dialog by itself and
/// answers every choice with a second native alert, "Result: <value>",
/// which a UI test reads without Flutter's semantics. That covers tap →
/// UIKit handler → channel → Dart value → a new native presentation while
/// the first is still leaving.
final class NativeDialogUITests: XCTestCase {
  private let timeout: TimeInterval = 90

  override func setUp() {
    continueAfterFailure = false
  }

  private func launch(_ demo: String) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["LIQUID_SHELL_EXAMPLE_DEMO"] = demo
    app.launch()
    return app
  }

  private func expectResult(_ app: XCUIApplication, _ title: String) {
    let result = app.alerts[title]
    XCTAssertTrue(result.waitForExistence(timeout: 15), "no \"\(title)\" alert")
    result.buttons["OK"].tap()
    XCTAssertTrue(result.waitForNonExistence(timeout: 5))
  }

  func testTappingAnAlertButtonAnswersDart() {
    let app = launch("alert")
    let alert = app.alerts["Discard changes?"]
    XCTAssertTrue(alert.waitForExistence(timeout: timeout))
    alert.buttons["Discard"].tap()
    expectResult(app, "Result: discard")
  }

  func testTappingCancelAnswersTheCancelValue() {
    let app = launch("alert")
    let alert = app.alerts["Discard changes?"]
    XCTAssertTrue(alert.waitForExistence(timeout: timeout))
    alert.buttons["Keep editing"].tap()
    expectResult(app, "Result: keep")
  }

  func testTappingAnActionSheetButtonAnswersDart() {
    let app = launch("sheet")
    let delete = app.buttons["Delete photo"]
    XCTAssertTrue(delete.waitForExistence(timeout: timeout))
    delete.tap()
    expectResult(app, "Result: delete")
  }

  func testTappingOutsideAnActionSheetAnswersTheCancelValue() {
    let app = launch("sheet")
    XCTAssertTrue(app.buttons["Delete photo"].waitForExistence(timeout: timeout))
    // Near the top-trailing corner: beside the iPad popover, which sits
    // over the rows near the top, and on the iPhone's dimming view.
    app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.15)).tap()
    expectResult(app, "Result: cancel")
  }
}
