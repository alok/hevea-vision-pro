import XCTest

/// Pair next through the actual controls and real coordinate taps on the Roots window; the window reports what its
/// shared picker picked, and the outcome must agree. Pointer hover is not exercised (no visionOS XCUITest hover route).
extension FareyUITests {
  func testPairNextThroughTheRootsWindow() {
    app = XCUIApplication()
    app.terminate()
    Self.launched = false
    launch()
    require("enter-void").tap()
    type("1,0,1", into: "coefficient-entry", then: "coefficient-select")
    // Arm, Cancel, arm again: the state line appears only while armed.
    require("pair-next").tap()
    XCTAssertTrue(require("pair-next-state").label.contains("(1, 0, 1)"))
    require("pair-next").tap()
    XCTAssertTrue(element("pair-next-state").waitForNonExistence(timeout: 5))
    require("pair-next").tap()
    require("roots-open").tap()
    let pane = require("roots-pane")
    XCTAssertTrue(pane.wait(for: \.isHittable, toEqual: true, timeout: 10), "the Roots window never became hittable")
    capture("roots-pair-00-before")                                  // Pair next armed, nothing paired yet
    // The primary itself: the same direction, refused, with the selection kept and Pair next still armed.
    tapStar("(1, 0, 1)", in: pane)
    XCTAssertTrue(picked("(1, 0, 1)", in: pane), "a coordinate tap on (1, 0, 1) did not pick it")
    XCTAssertTrue(require("pair-error").exists)
    XCTAssertTrue(require("pair-next-state").exists)
    XCTAssertFalse(element("plane-state").exists)
    // (1,1,1): paired, plane 2a − 2c = 0, Pair next disarmed, the selection unchanged.
    tapStar("(1, 1, 1)", in: pane)
    XCTAssertTrue(picked("(1, 1, 1)", in: pane), "a coordinate tap on (1, 1, 1) did not pick it")
    XCTAssertTrue(require("plane-detail").label.contains("Paired with (1, 1, 1)"), require("plane-detail").label)
    XCTAssertTrue(require("plane-state").label.contains("2a −2c = 0"))
    XCTAssertTrue(require("coefficient-state").label.contains("(1, 0, 1)"))
    XCTAssertFalse(element("pair-next-state").exists)
    capture("roots-pair-01-paired")
    // Unarmed, a tap selects: (1,1,1) becomes the primary and the pair is dropped.
    tapStar("(1, 1, 1)", in: pane)
    let state = require("coefficient-state")
    let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "(1, 1, 1)"), object: state)
    XCTAssertEqual(XCTWaiter().wait(for: [selected], timeout: 10), .completed, state.label)
    XCTAssertFalse(element("plane-detail").exists && require("plane-detail").label.contains("Paired with"))
    // Arm, then close the Roots window: closing cancels Pair next.
    require("pair-next").tap()
    XCTAssertTrue(require("pair-next-state").exists)
    require("roots-close").tap()
    XCTAssertTrue(element("pair-next-state").waitForNonExistence(timeout: 5), "closing Roots left Pair next armed")
    require("pair-next").tap()                                       // arm, then Reset disarms
    require("coefficient-reset").tap()
    XCTAssertTrue(element("pair-next-state").waitForNonExistence(timeout: 5))
    exit()
  }
  /// Taps a star the window says it draws, through this route's measured mapping: on visionOS 27.2 a normalized
  /// offset (dx, dy) lands at (w/2 + w·dx, h/2 − h·dy), centred with y up (the separately owned Lean app's coordinate
  /// probes; reused as a measurement, not code).
  private func tapStar(_ label: String, in pane: XCUIElement) {
    let value = pane.value as? String ?? ""
    guard let range = value.range(of: "at \(label) ") else { return XCTFail("the window does not draw \(label): \(value)") }
    let parts = value[range.upperBound...].prefix { $0 != " " }.split(separator: ",").compactMap { Double($0) }
    guard parts.count == 2 else { return XCTFail("no location for \(label) in \(value)") }
    print("ROOTS-PAIR tapping \(label) at fraction \(parts)")
    pane.coordinate(withNormalizedOffset: CGVector(dx: parts[0] - 0.5, dy: 0.5 - parts[1])).tap()
  }
  private func picked(_ label: String, in pane: XCUIElement) -> Bool {
    let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "last pick \(label)"), object: pane)
    let result = XCTWaiter().wait(for: [expectation], timeout: 10) == .completed
    print("ROOTS-PAIR after tapping \(label): \(pane.value as? String ?? "nil")")
    return result
  }
}
