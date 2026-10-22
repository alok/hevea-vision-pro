import XCTest

extension FareyUITests {
  func testSingleTransitionFrames() {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["--showcase"]
    app.launch()
    XCTAssertTrue(require("render-receipt").wait(for: \.label, toEqual: "168 lattice points", timeout: 20))
    require("construction-start").tap()
    capture("commit-baseline", holdFor: 0)
    for index in 0..<2 {
      let previous = require("word-state").label
      require("projected-open").tap()
      require("projected-previous").tap()
      require("projected-confirm").tap()
      XCTAssertNotEqual(require("word-state").label, previous)
      capture("commit-selected-\(index)", holdFor: 0)
    }
    exit()
  }
}
