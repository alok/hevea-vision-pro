import XCTest

/// Opt-in, operator-assisted diagnostic (scripts/capture-tests.py --spatial-probe --only-testing this test): XCUITest
/// only prepares state through the real controls; the pick itself must be an external public Device Hub Select click
/// on the (3,0,3) sphere of this disposable simulator. Each phase prints a READY line with the simulator and waits up
/// to 90 s; nothing here injects input or calls the model. Skipped in the ordinary suite.
extension FareyUITests {
  private func waitForPick(_ id: String, containing text: String) -> Bool {
    let predicate = NSPredicate(format: "exists == true AND label CONTAINS %@", text)
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element(id))
    return XCTWaiter().wait(for: [expectation], timeout: 90) == .completed
  }
  private func announce(_ phase: String) {
    let simulator = ProcessInfo.processInfo.environment["SIMULATOR_UDID"] ?? "unknown"
    capture("devicehub-pair-ready-\(phase)")
    print("DEVICEHUB-PAIR READY phase \(phase) simulator \(simulator) at \(Date().timeIntervalSince1970): click the (3,0,3) sphere now")
  }
  func testDeviceHubSpherePairing() throws {
    try XCTSkipUnless(
      ProcessInfo.processInfo.environment["FAREY_SPATIAL_PROBE"] == "1", "Opt-in diagnostic: run capture-tests.py --spatial-probe")
    app = XCUIApplication()
    app.terminate()
    Self.launched = false
    launch()
    require("enter-void").tap()
    // Phase 1: the default (1,−1,2), Pair next armed; a click on (3,0,3) should pair them.
    XCTAssertTrue(require("coefficient-state").label.contains("(1, -1, 2)"))
    require("pair-next").tap()
    XCTAssertTrue(require("pair-next-state").label.contains("(1, -1, 2)"))
    announce("1")
    XCTAssertTrue(waitForPick("plane-detail", containing: "Paired with (3, 0, 3)"), "no paired (3, 0, 3) within 90 s")
    print("DEVICEHUB-PAIR phase 1 plane \(element("plane-state").label) · receipt \(element("render-receipt").label)")
    XCTAssertTrue(require("plane-state").label.contains("2a −2b −2c = 0"), require("plane-state").label)
    XCTAssertTrue(require("render-receipt").label.contains("18 displayed interior triples"), require("render-receipt").label)
    XCTAssertTrue(require("coefficient-state").label.contains("(1, -1, 2)"))
    XCTAssertFalse(element("pair-next-state").exists)
    capture("devicehub-pair-1-paired")
    // Phase 2: (3,0,3) selected and Pair next armed; a click on the same sphere is the same direction, refused.
    type("3,0,3", into: "coefficient-entry", then: "coefficient-select")
    XCTAssertTrue(require("coefficient-state").label.contains("(3, 0, 3)"))
    require("pair-next").tap()
    announce("2")
    XCTAssertTrue(waitForPick("pair-error", containing: "same primitive direction"), "no same-direction refusal within 90 s")
    XCTAssertTrue(require("coefficient-state").label.contains("(3, 0, 3)"))
    XCTAssertTrue(require("pair-next-state").exists)
    XCTAssertFalse(element("plane-detail").exists && require("plane-detail").label.contains("Paired with"))
    capture("devicehub-pair-2-refused")
    require("coefficient-reset").tap()
    exit()
  }
}
