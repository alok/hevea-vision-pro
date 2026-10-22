import XCTest

extension FareyUITests {
  func testCoefficientSpaceProjectionAndLifecycle() {
    app = XCUIApplication()
    app.terminate()
    Self.launched = false
    launch()
    require("enter-void").tap()
    require("coefficient-state")
    XCTAssertTrue(require("render-receipt").label.contains("280 coefficient points"))
    capture("cone-01-oblique")
    require("coefficient-next").tap()
    XCTAssertTrue(require("coefficient-state").label.contains("(2, -2, 4)"))
    XCTAssertTrue(require("coefficient-root").label.contains("0.500 + 1.323i"))
    require("projection-toggle").tap()
    XCTAssertEqual(require("projection-toggle").label, "Show projection")
    capture("cone-02-spatial-cloud")
    require("projection-toggle").tap()
    require("coefficient-view").tap()
    capture("cone-03-other-side")
    require("coefficient-view").tap()
    capture("cone-04-side")
    exit()
    require("enter-void").tap()
    XCTAssertTrue(require("coefficient-state").label.contains("(2, -2, 4)"))
    require("show-farey").tap()
    require("step-L").tap()
    require("show-starscape").tap()
    XCTAssertTrue(require("coefficient-state").label.contains("(2, -2, 4)"))
    require("coefficient-reset").tap()
    XCTAssertTrue(require("coefficient-state").label.contains("(1, -1, 2)"))
    XCTAssertEqual(require("coefficient-view").label, "Oblique")
    capture("cone-05-reset")
    exit()
  }
}
