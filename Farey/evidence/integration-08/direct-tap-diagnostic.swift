import XCTest

extension FareyUITests {
  func testSystemComputedSphereTap() {
    launch()
    enter()
    require("reset").tap()
    require("construction-start").tap()
    let dot = app.descendants(matching: .any).matching(NSPredicate(
      format: "label BEGINSWITH %@", "Projected direction 3/5 at")).firstMatch
    XCTAssertTrue(dot.waitForExistence(timeout: 5))
    NSLog("DIRECT_SYSTEM_FRAME:%@", String(describing: dot.frame))
    dot.tap()
    XCTAssertTrue(element("projected-preview").waitForExistence(timeout: 8))
    NSLog("DIRECT_SYSTEM_PREVIEW:%@", require("projected-preview").label)
    XCTAssertEqual(require("word-state").label, "Start")
    capture("52-system-tap-preview")
    require("projected-cancel").tap()
    exit()
  }
}
