import XCTest

extension XCTestCase {
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
