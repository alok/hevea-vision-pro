import XCTest

extension FareyUITests {
  func testSingleTransitionFrames() {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["--showcase"]
    app.launch()
    XCTAssertTrue(require("render-receipt").wait(for: \.label, toEqual: "168 lattice points", timeout: 20))
    capture("popover-baseline", holdFor: 0)
    require("show-cf").tap()
    require("close-cf").tap()
    capture("popover-cf-closed", holdFor: 0)
    require("construction-start").tap()
    require("projected-open").tap()
    require("projected-cancel").tap()
    capture("popover-picker-cancelled", holdFor: 0)
    XCUIDevice.shared.press(.home)
    app.activate()
    if element("enter-void").isHittable { enter() }
    XCTAssertEqual(require("word-state").label, "RLR")
    capture("popover-home-without-picker", holdFor: 0)
    require("projected-open").tap()
    XCUIDevice.shared.press(.home)
    app.activate()
    if element("enter-void").isHittable { enter() }
    XCTAssertEqual(require("word-state").label, "RLR")
    capture("popover-home-with-picker", holdFor: 0)
    if element("projected-cancel").isHittable { require("projected-cancel").tap() }
    capture("popover-final", holdFor: 0)
    exit()
  }
}
