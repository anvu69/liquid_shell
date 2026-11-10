import XCTest

extension XCTestCase {
  /// Taps [element] once it is hittable and its frame has stopped moving
  /// (two equal frames 200 ms apart). Fails at [timeout] with the last
  /// state; never taps twice.
  func tapWhenSettled(
    _ element: XCUIElement,
    timeout: TimeInterval = 10,
    _ what: String,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let deadline = Date().addingTimeInterval(timeout)
    var last = CGRect.null
    while Date() < deadline {
      if element.exists, element.isHittable {
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
    XCTFail(
      "\(what): not settled after \(timeout) s (exists \(element.exists), "
        + "hittable \(element.exists && element.isHittable), frame \(last))",
      file: file, line: line)
  }
}
