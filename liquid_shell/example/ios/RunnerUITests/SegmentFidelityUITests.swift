import XCTest

/// Drives UIKit's segmented control on the example's native reference
/// screen through the acceptance sequence of spec VK-550 §14.5, with the
/// spike's timings, while tool/segment_frames.sh records the screen, and
/// checks the selected segment after each step. Launched with
/// LIQUID_SHELL_EXAMPLE_DEMO=segments-native (DEBUG builds:
/// `SegmentReferenceViewController`). integration_test/
/// segment_fidelity_test.dart drives the Flutter case the same way.
final class SegmentFidelityUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  private func idle() { Thread.sleep(forTimeInterval: 1.0) }

  /// A screen point.
  private func point(_ app: XCUIApplication, _ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
    app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
  }

  /// Waits until segment [index] of [segments] is the selected one.
  private func expectSelected(
    _ index: Int, of segments: [XCUIElement], after step: String,
    file: StaticString = #filePath, line: UInt = #line
  ) {
    let selected = expectation(
      for: NSPredicate(format: "selected == YES"), evaluatedWith: segments[index])
    XCTAssertEqual(
      XCTWaiter().wait(for: [selected], timeout: 5), .completed,
      "\(step): segment \(index) is selected", file: file, line: line)
    for (i, segment) in segments.enumerated() where i != index {
      XCTAssertFalse(segment.isSelected, "\(step): segment \(i) is not selected", file: file, line: line)
    }
  }

  func testSequences() throws {
    // The reference screen's frames are the iPhone's (an iPad runs the
    // same Runner in make ios-ui).
    try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "iPhone only")
    let app = XCUIApplication()
    app.launchEnvironment["LIQUID_SHELL_EXAMPLE_DEMO"] = "segments-native"
    app.launch()
    // The full-width three-segment control: the one the Flutter run drives.
    let control = app.segmentedControls["full3"]
    XCTAssertTrue(control.waitForExistence(timeout: 60), "the reference screen")
    let segments = ["All", "Songs", "Places"].map { control.buttons[$0] }
    for segment in segments {
      XCTAssertTrue(segment.waitForExistence(timeout: 10), segment.description)
    }
    expectSelected(0, of: segments, after: "launch")
    let y = control.frame.midY
    func centre(_ i: Int) -> XCUICoordinate {
      point(app, segments[i].frame.midX, y)
    }

    // tool/segment_frames.sh cuts the recording here.
    print("SEGFID start")
    idle(); idle()
    // tap_1_2, tap_2_3, tap_3_1: the spike's idb taps, held 70 ms.
    for i in [1, 2, 0] {
      centre(i).press(forDuration: 0.07)
      idle()
      expectSelected(i, of: segments, after: "tap \(i)")
    }
    // press: held 2 s on the selected segment, then released in place.
    centre(0).press(forDuration: 2.0)
    idle()
    expectSelected(0, of: segments, after: "press")
    // slow_drag: 77 → 324 at 82 pt/s. No hold before the lift, as in the
    // Flutter run: a held finger makes the release a motion onset of its
    // own, and tool/tab_strips.dart would pair every later strip wrongly.
    point(app, 77, y).press(
      forDuration: 0.05, thenDragTo: point(app, 324, y),
      withVelocity: XCUIGestureVelocity(82), thenHoldForDuration: 0)
    idle()
    expectSelected(2, of: segments, after: "slow_drag")
    // flick: 324 → 77 over 0.25 s.
    point(app, 324, y).press(
      forDuration: 0.05, thenDragTo: point(app, 77, y),
      withVelocity: XCUIGestureVelocity((324 - 77) / 0.25), thenHoldForDuration: 0)
    idle()
    expectSelected(0, of: segments, after: "flick")
    // programmatic: "Next segment, from code" writes selectedSegmentIndex.
    app.buttons["segments-next"].tap()
    idle()
    expectSelected(1, of: segments, after: "programmatic")
    // tool/segment_frames.sh ends the frames here, before the app goes.
    print("SEGFID end")
    idle(); idle()
  }
}
