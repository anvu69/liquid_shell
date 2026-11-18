import XCTest

extension XCTestCase {
  /// Launches the example on [demo], runs [ready] (the caller's launch
  /// waits: the evidence that Dart ran), then waits up to [displayTimeout]
  /// for the example's probe (`FlutterUIProbe`) to read "displayed".
  ///
  /// VK-1081: about one CI launch in 26 shows the native chrome over a white
  /// screen that never gets Flutter's first frame; its rows exist and are
  /// never hittable. Such a launch, positively reported "not displayed" by
  /// the probe, is relaunched once, recorded (activity, print, screenshot,
  /// the element tree). Still not displayed: the test fails. A missing
  /// probe fails at once: the probe broke, which a relaunch does not mend.
  func launchShowingFlutter(
    _ demo: String,
    displayTimeout: TimeInterval = 20,
    file: StaticString = #filePath,
    line: UInt = #line,
    ready: (XCUIApplication) -> Void
  ) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["LIQUID_SHELL_EXAMPLE_DEMO"] = demo
    for attempt in 1...2 {
      app.launch()
      ready(app)
      let probe = app.staticTexts["flutterUIProbe"]
      let displayed = XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "label == %@", "flutterUI: displayed"), object: probe)
      if XCTWaiter.wait(for: [displayed], timeout: displayTimeout) == .completed { return app }
      guard probe.exists else {
        XCTFail("the Flutter UI probe is missing (\(demo))", file: file, line: line)
        return app
      }
      let reads = probe.label
      guard attempt == 1 else {
        XCTFail(
          "Flutter UI never displayed (twice): \(demo), the probe reads \"\(reads)\"",
          file: file, line: line)
        return app
      }
      XCTContext.runActivity(named: "VK-1081: relaunch, Flutter UI never displayed") { activity in
        print("UITestWaits: \(demo) launched with no Flutter UI (\"\(reads)\"); relaunching once")
        let screen = XCTAttachment(screenshot: app.screenshot())
        screen.name = "white launch"
        screen.lifetime = .keepAlways
        activity.add(screen)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "element tree"
        tree.lifetime = .keepAlways
        activity.add(tree)
        app.terminate()
      }
    }
    return app
  }

  /// VK-1064: once settled, [row] sits below [bar], not under it. Waits up
  /// to 10 s for two equal reads of both frames with the row below.
  func waitRowBelowBar(
    _ row: XCUIElement, _ bar: XCUIElement,
    file: StaticString = #filePath, line: UInt = #line
  ) {
    let deadline = Date().addingTimeInterval(10)
    var last: (row: CGRect, bar: CGRect) = (.null, .null)
    while Date() < deadline {
      let now = (row: row.frame, bar: bar.frame)
      if now == last, now.row.minY >= now.bar.maxY - 0.5 { break }
      last = now
      Thread.sleep(forTimeInterval: 0.2)
    }
    XCTAssertGreaterThanOrEqual(
      row.frame.minY, bar.frame.maxY - 0.5,
      "launch: row.minY \(row.frame.minY) < bar.maxY \(bar.frame.maxY)", file: file, line: line)
  }

  /// Taps [element] once it is hittable and its frame has stopped moving
  /// (two equal frames 200 ms apart). Fails at [timeout] with the
  /// element's real frame and the last sample's hittability (VK-1081: not
  /// the settle loop's `CGRect.null` sentinel); never taps twice.
  func tapWhenSettled(
    _ element: XCUIElement,
    timeout: TimeInterval = 10,
    _ what: String,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let deadline = Date().addingTimeInterval(timeout)
    var last = CGRect.null
    var lastHittable = false
    while Date() < deadline {
      lastHittable = element.exists && element.isHittable
      if lastHittable {
        let frame = element.frame
        if frame == last {
          element.tap()
          return
        }
        last = frame
      } else {
        last = .null
      }
      Thread.sleep(forTimeInterval: 0.2)
    }
    // VK-1043: on a loaded runner one query can take seconds, so the
    // deadline can pass after a single sample. One last sample: equal to the
    // one before it, the element has settled; otherwise fail.
    if !last.isNull, element.exists, element.isHittable, element.frame == last {
      element.tap()
      return
    }
    // `frame` on a missing element records a failure of its own.
    let exists = element.exists
    let frame = exists ? String(describing: element.frame) : "none"
    XCTFail(
      "\(what): not settled after \(timeout) s (exists \(exists), "
        + "hittable \(exists && element.isHittable), frame \(frame), "
        + "last sample hittable \(lastHittable))",
      file: file, line: line)
  }
}
