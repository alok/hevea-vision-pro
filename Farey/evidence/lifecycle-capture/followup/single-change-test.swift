import XCTest

extension FareyUITests {
  func testSingleTransitionFrames() {
    app = XCUIApplication()
    app.launchArguments = ["--showcase"]
    app.launch()
    XCTAssertTrue(require("render-receipt").wait(for: \.label, toEqual: "168 lattice points", timeout: 20))
    XCTAssertEqual(require("word-state").label, "RLR")
    capture("transition-baseline", holdFor: 0)
    require("viewpoint").tap()
    XCTAssertEqual(require("word-state").label, "RLR")
    capture("transition-viewpoint", holdFor: 0)
    require("step-L").tap()
    XCTAssertEqual(require("word-state").label, "RLRL")
    capture("transition-mediant", holdFor: 0)
    require("space-toggle").tap()
    XCTAssertTrue(require("render-receipt").wait(for: \.label, toEqual: "253 Farey edges", timeout: 20))
    capture("transition-disk", holdFor: 0)
    require("construction-start").tap()
    XCTAssertTrue(require("render-receipt").label.contains("projected direction dots"))
    capture("transition-chart", holdFor: 0)
    exit()
  }
}
