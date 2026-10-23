import XCTest

/// Opt-in, operator-assisted diagnostic (scripts/capture-tests.py --spatial-probe --only-testing this test): XCUITest
/// only prepares state through the real controls; each drag must be an external public Device Hub Select-mode drag on
/// empty sky in this disposable simulator while it is at Origin. It reads g from the panel's readout (the
/// accessibility value carries g to full precision) and checks the exact base state is untouched. Each phase prints a
/// READY line and waits up to 90 s; a drag that never arrives fails the test, after printing the app's opt-in input
/// diagnostics (gesture callback counts and the last outcome) and capturing the state. Overview's no-effect is not checked here:
/// without an observable drag event the test could not tell "ignored" from "never sent". Skipped in the ordinary suite.
extension FareyUITests {
  private func groupEntries() -> [Double] {
    (require("group-state").value as? String ?? "").split(separator: ",").compactMap { Double($0) }
  }
  private func waitForGroup(where condition: @escaping ([Double]) -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(90)
    while Date() < deadline {
      if condition(groupEntries()) { return true }
      _ = XCTWaiter().wait(for: [XCTestExpectation(description: "poll g")], timeout: 0.5)
    }
    return false
  }
  private func waitForDiagnostics(containing text: String, seconds: TimeInterval) -> Bool {
    let predicate = NSPredicate(format: "label CONTAINS %@", text)
    return XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element("input-diagnostics"))], timeout: seconds)
      == .completed
  }
  /// READY only once the app itself measured a device pose for this placement (world tracking); never injected. A
  /// missing pose fails here with the app's own status.
  private func waitForDevicePose() {
    let posed = XCTWaiter().wait(
      for: [XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "placed from the device pose"),
        object: require("render-receipt"))], timeout: 15) == .completed
    print("DEVICEHUB-ORIGIN pose \(posed ? "measured" : "NOT measured") · receipt \(require("render-receipt").label)"
      + " · placement \(element("placement-state").exists ? element("placement-state").label : "none")")
    XCTAssertTrue(posed, "no device pose within 15 s: \(element("placement-state").exists ? element("placement-state").label : "none")")
  }
  private func checkBaseState(nappe: String) {
    XCTAssertTrue(require("coefficient-state").label.contains("(1, 0, 1)"), require("coefficient-state").label)
    XCTAssertTrue(require("plane-detail").label.contains("Paired with (1, 1, 1)"), require("plane-detail").label)
    // The exact base plane in either label form: "Plane …" at g = identity, "Base plane …" otherwise.
    let plane = require("plane-state").label
    XCTAssertTrue(plane.hasPrefix("Plane 2a −2c = 0") || plane.hasPrefix("Base plane 2a −2c = 0"), plane)
    XCTAssertEqual(plane.hasPrefix("Plane"), require("group-state").label.contains("g = identity"), plane)
    XCTAssertTrue(require("render-receipt").label.contains("origin, \(nappe) nappe ahead"), require("render-receipt").label)
    let g = groupEntries()
    XCTAssertEqual(g.count, 4, "g readout \(g)")
    XCTAssertTrue(g.allSatisfy(\.isFinite), "g readout \(g)")
    XCTAssertEqual(g[0] * g[3] - g[1] * g[2], 1, accuracy: 1e-9, "det g")
  }
  private func announce(_ phase: String) {
    let simulator = ProcessInfo.processInfo.environment["SIMULATOR_UDID"] ?? "unknown"
    capture("devicehub-origin-ready-\(phase)")
    let at = Date().timeIntervalSince1970
    let ask = phase == "0" ? "click empty sky once" : "drag on empty sky now"
    print("DEVICEHUB-ORIGIN READY phase \(phase) simulator \(simulator) at \(at) g \(groupEntries()): \(ask)")
    print("DEVICEHUB-ORIGIN phase \(phase) diagnostics at READY: \(diagnostics())")
    print("DEVICEHUB-ORIGIN phase \(phase) receipt at READY: \(require("render-receipt").label)")
  }
  /// The app's opt-in input diagnostics line (callback counts, last entity, direction and outcome).
  private func diagnostics() -> String {
    element("input-diagnostics").exists ? element("input-diagnostics").label : "input diagnostics not shown"
  }
  func testDeviceHubOriginDrag() throws {
    try XCTSkipUnless(
      ProcessInfo.processInfo.environment["FAREY_SPATIAL_PROBE"] == "1", "Opt-in diagnostic: run capture-tests.py --spatial-probe")
    app = XCUIApplication()
    app.terminate()
    // Launched with the opt-in input diagnostics, so a failure can say whether any gesture callback arrived.
    continueAfterFailure = false
    app.launchArguments += ["--input-diagnostics"]
    app.launch()
    Self.launched = false                                            // later tests relaunch without the argument
    require("enter-void").tap()
    type("1,0,1", into: "coefficient-entry", then: "coefficient-select")
    type("1,1,1", into: "pair-entry", then: "pair-select")
    XCTAssertTrue(require("plane-state").label.contains("2a −2c = 0"))
    XCTAssertTrue(require("group-state").label.contains("g = identity"))
    print("DEVICEHUB-ORIGIN snap value \(require("group-snap").value ?? "nil")")  // Snap starts off; a drag would otherwise settle
    require("placement-origin").tap()
    XCTAssertTrue(require("render-receipt").label.contains("upper nappe ahead"), require("render-receipt").label)
    waitForDevicePose()
    // Phase 0, a targeting check that is reported, not asserted: one plain click on empty sky. A tap callback naming
    // origin-sky shows system targeting reaches the sky; none in 60 s points at targeting rather than at the drag.
    print("DEVICEHUB-ORIGIN phase 0 diagnostics before: \(diagnostics())")
    announce("0")
    let tapped = waitForDiagnostics(containing: "last tap entity origin-sky", seconds: 60)
    print("DEVICEHUB-ORIGIN phase 0 sky click \(tapped ? "reached origin-sky" : "not observed in 60 s"): \(diagnostics())")
    capture("devicehub-origin-0-after-click")
    // Phase 1, upper nappe ahead: one empty-sky drag should give a non-integer g and leave every base identity alone.
    announce("1")
    let moved = waitForGroup { $0.count == 4 && $0 != [1, 0, 0, 1] } && require("group-state").label.contains("off SL₂(ℤ)")
    print("DEVICEHUB-ORIGIN phase 1 diagnostics after wait: \(diagnostics())")
    if !moved { capture("devicehub-origin-1-failed") }
    XCTAssertTrue(moved, "no non-integer g within 90 s: \(require("group-state").label) · \(diagnostics())")
    // The drag must have ended before the capture and the nappe flip: wait on the observed end, not a delay.
    XCTAssertTrue(waitForDiagnostics(containing: " · ends 1 · ", seconds: 30), "phase 1 drag never ended: \(diagnostics())")
    let first = groupEntries()
    print("DEVICEHUB-ORIGIN phase 1 g \(first) · receipt \(require("render-receipt").label)")
    checkBaseState(nappe: "upper")
    capture("devicehub-origin-1-dragged")
    // Phase 2, lower nappe ahead (same anchor): another drag should move g again.
    require("origin-nappe").tap()
    XCTAssertTrue(require("render-receipt").label.contains("lower nappe ahead"), require("render-receipt").label)
    announce("2")
    let movedAgain = waitForGroup { $0.count == 4 && $0 != first }
    print("DEVICEHUB-ORIGIN phase 2 diagnostics after wait: \(diagnostics())")
    if movedAgain {
      XCTAssertTrue(waitForDiagnostics(containing: " · ends 2 · ", seconds: 30), "phase 2 drag never ended: \(diagnostics())")
    }
    if !movedAgain { capture("devicehub-origin-2-failed") }
    XCTAssertTrue(movedAgain, "g did not change within 90 s after the nappe flip · \(diagnostics())")
    print("DEVICEHUB-ORIGIN phase 2 g \(groupEntries()) · receipt \(require("render-receipt").label)")
    checkBaseState(nappe: "lower")
    capture("devicehub-origin-2-dragged")
    checkResetAndReentry()
  }
  /// The actual Reset: g identity, the default point, the pair cleared, Overview; then Exit and re-entry keep that.
  private func checkResetAndReentry() {
    require("coefficient-reset").tap()
    func checkDefaults(_ when: String) {
      XCTAssertTrue(require("group-state").label.contains("g = identity"), "\(when): \(require("group-state").label)")
      XCTAssertTrue(require("coefficient-state").label.contains("(1, -1, 2)"), "\(when): \(require("coefficient-state").label)")
      XCTAssertFalse(element("plane-state").exists, "\(when): a plane remains")
      XCTAssertFalse(require("render-receipt").label.contains(" · origin, "), "\(when): \(require("render-receipt").label)")
      XCTAssertEqual(require("placement-inhabit").label, "Inhabit", "\(when): not in Overview")
    }
    checkDefaults("after Reset")
    print("DEVICEHUB-ORIGIN reset · \(require("render-receipt").label)")
    exit()
    require("enter-void").tap()
    checkDefaults("after re-entry")
    exit()
  }
}
