import XCTest

/// Cutting planes, second selection and Origin/Inhabit placement through the actual controls. These use window
/// buttons and text entry; spatial gaze/pinch activation of points remains unverified in the simulator.
extension FareyUITests {
  private func waitForReceipt(containing text: String, _ message: String = "") {
    let predicate = NSPredicate(format: "label CONTAINS %@", text)
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: require("render-receipt"))
    XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 20), .completed, "\(message) receipt: \(require("render-receipt").label)")
  }
  private func type(_ text: String, into field: String, then button: String) {
    let entry = require(field)
    entry.tap()
    entry.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30) + text)
    require(button).tap()
  }
  func testCoefficientPlanesAndPlacement() {
    app = XCUIApplication()
    app.terminate()
    Self.launched = false
    launch()
    require("enter-void").tap()
    // Pair (1,0,1) with (1,1,1): the browser's audited plane and endpoints.
    type("1,0,1", into: "coefficient-entry", then: "coefficient-select")
    type("1,1,1", into: "pair-entry", then: "pair-select")
    XCTAssertTrue(require("plane-state").label.contains("2a −2c = 0 · geodesic endpoints -1 and 1"))
    XCTAssertTrue(require("plane-detail").label.contains("Paired with (1, 1, 1) · normal (1, 0, -1)"))
    waitForReceipt(containing: " · plane 2a −2c = 0 · ")
    XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 10), "keyboard stayed open after a valid pair")
    capture("plane-01-pair")
    // A sign partner of the selection is one projective direction: rejected, nothing changes, and the text and
    // keyboard stay for correction.
    type("-2,0,-2", into: "pair-entry", then: "pair-select")
    XCTAssertTrue(require("pair-error").label.contains("same primitive direction"))
    XCTAssertTrue(require("plane-detail").label.contains("Paired with (1, 1, 1)"))
    XCTAssertEqual(require("pair-entry").value as? String, "-2,0,-2")
    checkCompactOverview()
    // An exterior selection is its own normal; a new selection drops the pair.
    type("1,3,1", into: "coefficient-entry", then: "coefficient-select")
    XCTAssertFalse(element("pair-clear").exists)
    XCTAssertTrue(require("plane-detail").label.contains("Lorentz normal (1, 3, 1)"))
    capture("plane-02-exterior")
    type("0,1,0", into: "coefficient-entry", then: "coefficient-select")
    XCTAssertTrue(require("plane-state").label.contains("b = 0 · geodesic endpoints 0 and ∞"))
    checkPlacement()
    // Leaving the immersive space ends the head placement; re-entry starts at the overview.
    require("placement-origin").tap()
    waitForReceipt(containing: "origin at head center")
    exit()
    require("enter-void").tap()
    XCTAssertEqual(require("placement-inhabit").label, "Inhabit")
    XCTAssertFalse(require("render-receipt").label.contains("origin at head center"))
    exit()
  }
  /// From an open keyboard: Inhabit closes it; collapsed controls still offer Overview; the exact primary and second
  /// points and their plane survive the round trip.
  private func checkCompactOverview() {
    require("placement-inhabit").tap()
    XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 10), "keyboard stayed open after Inhabit")
    waitForReceipt(containing: " · inhabiting (1, 0, 1)")
    require("controls-toggle").tap()
    XCTAssertFalse(element("placement-origin").exists)
    XCTAssertEqual(require("placement-inhabit").label, "Overview")
    capture("placement-00-inhabit-compact")
    require("placement-inhabit").tap()
    XCTAssertEqual(require("placement-inhabit").label, "Inhabit")
    require("controls-toggle").tap()
    XCTAssertTrue(require("coefficient-state").label.contains("(1, 0, 1)"))
    XCTAssertTrue(require("plane-detail").label.contains("Paired with (1, 1, 1) · normal (1, 0, -1)"))
    waitForReceipt(containing: " · plane 2a −2c = 0 · ")
    XCTAssertFalse(require("render-receipt").label.contains("inhabiting"))
  }
  private func checkPlacement() {
    type("1,-1,2", into: "coefficient-entry", then: "coefficient-select")
    require("placement-origin").tap()
    waitForReceipt(containing: " · origin at head center, upper nappe ahead")
    XCTAssertTrue(require("placement-state").label.contains("zero polynomial"))
    XCTAssertFalse(require("coefficient-view").isEnabled)
    capture("placement-01-origin-upper")
    require("origin-nappe").tap()
    waitForReceipt(containing: " · origin at head center, lower nappe ahead")
    capture("placement-02-origin-lower")
    // Origin again re-centers (a new one-time anchor; identity is unit-tested) and faces the upper nappe.
    require("placement-origin").tap()
    waitForReceipt(containing: " · origin at head center, upper nappe ahead")
    require("placement-inhabit").tap()  // labelled Overview while anchored
    XCTAssertEqual(require("placement-inhabit").label, "Inhabit")
    require("placement-inhabit").tap()
    waitForReceipt(containing: " · inhabiting (1, -1, 2)")
    capture("placement-03-inhabit")
    // Selecting another point changes the inspected state but does not move the inhabited viewer.
    type("2,1,1", into: "coefficient-entry", then: "coefficient-select")
    XCTAssertTrue(require("coefficient-state").label.contains("(2, 1, 1)"))
    waitForReceipt(containing: " · inhabiting (1, -1, 2)")
    capture("placement-04-inhabit-other-selection")
    // An invalid pair keeps its keyboard; Reset is an explicit action and closes it.
    type("9,9,9", into: "pair-entry", then: "pair-select")
    XCTAssertTrue(require("pair-error").exists)
    require("coefficient-reset").tap()
    XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 10), "keyboard stayed open after Reset")
    XCTAssertEqual(require("placement-inhabit").label, "Inhabit")
    XCTAssertFalse(require("render-receipt").label.contains("inhabiting"))
    XCTAssertFalse(element("plane-state").exists)
  }
}
