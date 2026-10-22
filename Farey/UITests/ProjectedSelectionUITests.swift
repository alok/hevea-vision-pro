import XCTest

extension FareyUITests {
  func testProjectedPreviewSelectionAndCancel() {
    launch()
    enter()
    require("reset").tap()
    require("detail-more").tap()
    require("construction-start").tap()
    require("projected-open").tap()
    XCTAssertEqual(require("projected-preview").label, "Preview: 1/1")
    require("projected-previous").tap()
    XCTAssertEqual(require("projected-preview").label, "Preview: 13/14")
    capture("42-native-projected-preview", holdFor: 3)
    require("projected-cancel").tap()
    XCTAssertEqual(require("word-state").label, "Start")
    require("projected-open").tap()
    require("projected-previous").tap()
    require("projected-confirm").tap()
    XCTAssertTrue(require("fraction-state").label.contains("13/14"))
    XCTAssertTrue(require("geometry-explanation").label.contains("Boundary chart"))
    capture("43-native-projected-selected", holdFor: 3)
    require("construction-close").tap()
    require("inspect-point").tap()
    XCTAssertEqual(require("point-equation").label, "(14, 13) = 1 × (14, 13)")
    require("close-point-inspection").tap()
    exit()
    enter()
    XCTAssertTrue(require("fraction-state").label.contains("13/14"))
    require("reset").tap()
    exit()
  }
}
