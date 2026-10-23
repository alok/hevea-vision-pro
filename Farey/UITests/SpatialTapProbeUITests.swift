import XCTest

/// Opt-in diagnostic (scripts/capture-tests.py --spatial-probe): can a public XCUITest route select a coefficient
/// dot? It reports the dot's accessibility frame, tries an app-anchored coordinate tap at the frame's center, the
/// element's tap, and checks the actual inspected state after each. No model call,
/// no direct activation, no private input injection. Skipped in the ordinary suite.
extension FareyUITests {
  func testSpatialTapProbe() throws {
    try XCTSkipUnless(
      ProcessInfo.processInfo.environment["FAREY_SPATIAL_PROBE"] == "1", "Opt-in diagnostic: run capture-tests.py --spatial-probe")
    app = XCUIApplication()
    app.terminate()
    Self.launched = false
    launch()
    require("enter-void").tap()
    XCTAssertTrue(require("coefficient-state").label.contains("(1, -1, 2)"))
    require("controls-toggle").tap()
    // (3,0,3) sits alone near the upper rim at R6, clear of the collapsed panel.
    let dot = app.descendants(matching: .any)
      .matching(NSPredicate(format: "label == %@", "Coefficient point (3, 0, 3), discriminant -36")).firstMatch
    XCTAssertTrue(dot.waitForExistence(timeout: 20), "the dot is not in the accessibility tree")
    let frame = dot.frame, appFrame = app.frame
    print("SPATIAL-PROBE element type \(dot.elementType.rawValue) frame \(frame) app frame \(appFrame) hittable \(dot.isHittable)")
    let selected = NSPredicate(format: "label CONTAINS %@", "(3, 0, 3)")
    func changed(_ route: String) -> Bool {
      let expectation = XCTNSPredicateExpectation(predicate: selected, object: require("coefficient-state"))
      let result = XCTWaiter().wait(for: [expectation], timeout: 5) == .completed
      print("SPATIAL-PROBE \(route): selection changed \(result); state \(require("coefficient-state").label)")
      return result
    }
    // 0.11.0 (15) reported a placeholder frame (0, 0, 50, 50) for this entity, and a tap there failed with "Received
    // invalid scene ID (nil) from Accessibility": treat a frame pinned at the origin as unmapped and do not tap it.
    let usable = [frame.minX, frame.minY, frame.width, frame.height].allSatisfy(\.isFinite) && !frame.isEmpty
      && frame.origin != .zero && appFrame.contains(CGPoint(x: frame.midX, y: frame.midY))
    var success = false
    if usable {
      let offset = CGVector(dx: frame.midX - appFrame.minX, dy: frame.midY - appFrame.minY)
      print("SPATIAL-PROBE app-anchored tap at offset \(offset)")
      app.coordinate(withNormalizedOffset: .zero).withOffset(offset).tap()
      success = changed("app-anchored coordinate tap")
    } else {
      print("SPATIAL-PROBE app-anchored tap not attempted: unusable frame \(frame)")
    }
    if !success {
      // XCUITest's element tap synthesizes a tap at the element's center. In 0.11 this route was not reached (an
      // app-anchored tap failed first, with "Received invalid scene ID (nil)"); with the activate action declared it
      // failed with "Received invalid activation point transform (nil) from Accessibility". A UI automation failure
      // ends the test, so this route runs last and unwrapped: its actual failure is the diagnostic's result.
      dot.tap()
      success = changed("element tap")
    }
    XCTAssertTrue(success, "no supported XCUITest route changed the selection")
  }
}
