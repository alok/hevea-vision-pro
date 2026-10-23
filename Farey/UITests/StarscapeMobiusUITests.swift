import XCTest

/// The native Möbius view through actual window controls and the supported swipe route on the Roots window. Not
/// covered here: coordinate press-drags (they left g unchanged, the window's accessibility frame being reported at the
/// origin), the app-coordinate route (nil scene ID), tapping a root in this window, and spatial gaze/pinch on entities.
extension FareyUITests {
  private func waitFor(_ id: String, containing text: String, _ message: String = "") {
    let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", text), object: require(id))
    XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 10), .completed, "\(message) \(require(id).label)")
  }
  func testMobiusRootsDragAndSymmetry() {
    app = XCUIApplication()
    app.terminate()
    Self.launched = false
    launch()
    require("enter-void").tap()
    // The shared pair: (1,0,1) with (1,1,1), plane 2a − 2c = 0, at R6 with projection off.
    type("1,0,1", into: "coefficient-entry", then: "coefficient-select")
    type("1,1,1", into: "pair-entry", then: "pair-select")
    waitFor("plane-state", containing: "2a −2c = 0")
    XCTAssertTrue(require("group-state").label.contains("g = identity"))
    capture("mobius-01-pair-identity")
    // A swipe on the Roots window, handled by its own DragGesture, applies a non-integer g.
    require("roots-open").tap()
    let pane = require("roots-pane")
    XCTAssertTrue(pane.wait(for: \.isHittable, toEqual: true, timeout: 10), "the Roots window never became hittable")
    pane.swipeRight()
    waitFor("group-state", containing: "off SL₂(ℤ)")
    capture("mobius-02-roots-after-swipe")
    let g = require("group-state").label, gExact = require("group-state").value as? String ?? ""
    print("MOBIUS-G \(gExact)")
    // Exact base identities are unchanged; the receipt reports g.
    XCTAssertTrue(require("coefficient-state").label.contains("(1, 0, 1)"))
    XCTAssertTrue(require("plane-state").label.contains("2a −2c = 0"))
    XCTAssertTrue(require("plane-detail").label.contains("Paired with (1, 1, 1)"))
    XCTAssertTrue(require("render-receipt").label.contains(" · g = ["), require("render-receipt").label)
    // Close only Roots; then the transformed scene from several views, unobstructed.
    require("roots-close").tap()
    XCTAssertTrue(pane.waitForNonExistence(timeout: 10), "Roots did not close")
    XCTAssertEqual(require("group-state").label, g)
    captureTransformedViews()
    // Reopening Roots, and leaving and re-entering the space, keep g and the pair; re-entry is in Overview.
    require("roots-open").tap()
    XCTAssertTrue(require("roots-pane").wait(for: \.isHittable, toEqual: true, timeout: 10))
    XCTAssertEqual(require("group-state").label, g)
    require("roots-close").tap()
    exit()
    require("enter-void").tap()
    XCTAssertEqual(require("group-state").label, g)
    XCTAssertEqual(require("group-state").value as? String, gExact)
    XCTAssertTrue(require("plane-detail").label.contains("Paired with (1, 1, 1)"))
    XCTAssertEqual(require("placement-inhabit").label, "Inhabit")
    capture("mobius-08-reentered")
    checkIdentityAbsorptionAndReset()
    exit()
  }
  /// The transformed scene, unobstructed: overview, the other side, projection on, and Origin facing each nappe.
  private func captureTransformedViews() {
    capture("mobius-03-transformed-overview")
    require("coefficient-view").tap()
    capture("mobius-04-transformed-other-side")
    require("coefficient-view").tap()
    require("coefficient-view").tap()
    require("projection-toggle").tap()
    capture("mobius-05-transformed-projection")
    require("projection-toggle").tap()
    require("placement-origin").tap()
    capture("mobius-06-transformed-origin-upper")
    require("origin-nappe").tap()
    capture("mobius-07-transformed-origin-lower")
    require("placement-inhabit").tap()  // Overview
  }
  private func checkIdentityAbsorptionAndReset() {
    // Identity restores the base geometry and keeps the pair; T is integral and absorbed into both exact triples.
    require("group-identity").tap()
    waitFor("group-state", containing: "g = identity")
    XCTAssertTrue(require("plane-detail").label.contains("Paired with (1, 1, 1)"))
    require("group-t").tap()
    waitFor("coefficient-state", containing: "(1, -2, 2)")
    XCTAssertTrue(require("plane-detail").label.contains("Paired with (1, -1, 1)"), require("plane-detail").label)
    XCTAssertTrue(require("group-state").label.contains("g = identity"))
    capture("mobius-09-after-t")
    // Reset clears the pair and g.
    require("coefficient-reset").tap()
    waitFor("coefficient-state", containing: "(1, -1, 2)")
    XCTAssertFalse(element("plane-state").exists)
    XCTAssertTrue(require("group-state").label.contains("g = identity"))
  }
}
