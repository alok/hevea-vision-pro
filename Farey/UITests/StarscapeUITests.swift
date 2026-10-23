import XCTest

extension FareyUITests {
  private func waitForReceipt(_ text: String) {
    XCTAssertTrue(
      require("render-receipt").wait(for: \.label, toEqual: "Inspired by Katherine Stange’s Starscape / Lattice · " + text, timeout: 20),
      "receipt: \(require("render-receipt").label)")
  }
  private func enterCoefficient(_ text: String) {
    let field = require("coefficient-entry")
    field.tap()
    field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 30) + text)
    require("coefficient-select").tap()
  }
  func testCoefficientSpaceProjectionAndLifecycle() {
    app = XCUIApplication()
    app.terminate()
    Self.launched = false
    launch()
    require("enter-void").tap()
    XCTAssertTrue(require("coefficient-state").label.contains("(1, -1, 2)"))
    waitForReceipt("480 coefficient points · radius 6 (native cap 12)")
    XCTAssertEqual(require("projection-toggle").label, "Show projection")
    capture("cone-01-oblique")
    // (2,-2,4) is in the browser's Next sequence but outside R6: its identity stays, marked hidden, until R8.
    require("coefficient-next").tap()
    XCTAssertTrue(require("coefficient-state").label.contains("(2, -2, 4)"))
    XCTAssertTrue(require("coefficient-root").label.contains("0.500 + 1.323i"))
    XCTAssertTrue(require("coefficient-root").label.contains("hidden"))
    waitForReceipt("480 coefficient points · radius 6 (native cap 12) · selected point hidden by this filter")
    app.buttons["R8"].tap()
    waitForReceipt("1060 coefficient points · radius 8 (native cap 12)")
    XCTAssertTrue(require("coefficient-state").label.contains("(2, -2, 4)"))
    app.buttons["R6"].tap()
    waitForReceipt("480 coefficient points · radius 6 (native cap 12) · selected point hidden by this filter")
    checkCoefficientEntry()
    checkCoefficientViewsAndFilters()
    exit()
    require("enter-void").tap()
    XCTAssertTrue(require("coefficient-state").label.contains("(-1, 1, -2)"))
    waitForReceipt("3608 coefficient points · radius 12 (native cap 12)")
    require("show-farey").tap()
    require("step-L").tap()
    require("show-starscape").tap()
    XCTAssertTrue(require("coefficient-state").label.contains("(-1, 1, -2)"))
    require("coefficient-reset").tap()
    XCTAssertTrue(require("coefficient-state").label.contains("(1, -1, 2)"))
    XCTAssertEqual(require("coefficient-view").label, "Oblique")
    XCTAssertEqual(require("projection-toggle").label, "Show projection")
    waitForReceipt("480 coefficient points · radius 6 (native cap 12)")
    capture("cone-06-reset")
    require("sources").tap()
    XCTAssertTrue(require("starscapes-paper").exists)
    require("close-sources").tap()
    // Collapsed controls keep the readout, Reset and Exit while covering less of the scene.
    require("controls-toggle").tap()
    XCTAssertEqual(require("controls-toggle").label, "Show controls")
    XCTAssertFalse(element("coefficient-next").exists)
    XCTAssertTrue(require("coefficient-state").label.contains("(1, -1, 2)"))
    capture("cone-07-controls-hidden")
    require("coefficient-reset").tap()
    XCTAssertTrue(require("coefficient-state").label.contains("(1, -1, 2)"))
    exit()
  }
  private func checkCoefficientEntry() {
    // Rejected entries change nothing; an accepted lower form keeps its sign and uses its representative's root.
    for bad in ["0,0,0", "5,0,0", "1,2", "99999999999999999999,0,1"] {
      enterCoefficient(bad)
      XCTAssertTrue(require("coefficient-error").exists, bad)
      XCTAssertTrue(require("coefficient-state").label.contains("(2, -2, 4)"), bad)
      XCTAssertEqual(require("coefficient-entry").value as? String, bad, "rejected text is kept for correction")
    }
    enterCoefficient("-1,1,-2")
    XCTAssertTrue(require("coefficient-state").label.contains("(-1, 1, -2)"))
    XCTAssertTrue(require("coefficient-root").label.contains("0.500 + 1.323i (sign-flipped representative)"))
    XCTAssertFalse(element("coefficient-error").exists)
    XCTAssertTrue(app.keyboards.element.waitForNonExistence(timeout: 10), "keyboard stayed open after a valid entry")
    waitForReceipt("480 coefficient points · radius 6 (native cap 12)")
  }
  private func checkCoefficientViewsAndFilters() {
    require("projection-toggle").tap()
    XCTAssertEqual(require("projection-toggle").label, "Hide projection")
    capture("cone-02-projection")
    require("projection-toggle").tap()
    require("coefficient-view").tap()
    capture("cone-03-other-side")
    require("coefficient-view").tap()
    capture("cone-04-side")
    require("coefficient-view").tap()
    require("upper-only").tap()
    waitForReceipt("55 coefficient points · radius 6 (native cap 12) · upper only · selected point hidden by this filter")
    XCTAssertTrue(require("coefficient-state").label.contains("(-1, 1, -2)"))
    require("upper-only").tap()
    app.buttons["R12"].tap()
    waitForReceipt("3608 coefficient points · radius 12 (native cap 12)")
    capture("cone-05-radius-12")
  }
}
