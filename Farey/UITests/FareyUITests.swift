import XCTest

@MainActor final class FareyUITests: XCTestCase {
  static var launched = false
  var app: XCUIApplication!
  func launch() {
    continueAfterFailure = false
    app = XCUIApplication()
    if Self.launched {
      app.activate()
    } else {
      app.launch()
      Self.launched = true
    }
  }
  func element(_ id: String) -> XCUIElement {
    let matches = app.descendants(matching: .any).matching(identifier: id)
    return matches.allElementsBoundByIndex.first(where: { $0.isHittable }) ?? matches.firstMatch
  }
  @discardableResult func require(_ id: String) -> XCUIElement {
    let e = element(id)
    if !e.exists {
      XCTAssertTrue(e.waitForExistence(timeout: 30), "Missing \(id): \(app.debugDescription)")
    }
    return e
  }
  func capture(_ name: String) {
    NSLog("FAREY_CAPTURE:%@", name)
    Thread.sleep(forTimeInterval: 1)
  }
  func enter() {
    let button = require("enter-void")
    XCTAssertTrue(button.wait(for: \.isEnabled, toEqual: true, timeout: 20))
    button.tap()
    require("word-state")
    let rendered = NSPredicate(format: "label CONTAINS %@", "Farey edges")
    expectation(for: rendered, evaluatedWith: require("render-receipt"))
    waitForExpectations(timeout: 20)
  }
  func exit() {
    require("exit-void").tap()
    let exitButton = element("exit-void")
    XCTAssertTrue(exitButton.wait(for: \.isHittable, toEqual: false, timeout: 20))
    let button = require("enter-void")
    XCTAssertTrue(button.wait(for: \.isEnabled, toEqual: true, timeout: 20))
    XCTAssertEqual(app.buttons.matching(identifier: "enter-void").count, 1)
  }
  func testImmersionControlsAndReentry() {
    launch()
    XCTAssertTrue(require("entry-credit").label.contains("Katherine Stange"))
    enter()
    require("sources").tap()
    XCTAssertEqual(require("stange-credit").label, "Katherine Stange")
    capture("00-sources")
    require("close-sources").tap()
    capture("01-initial-void")
    require("step-L").tap()
    require("step-R").tap()
    XCTAssertEqual(require("word-state").label, "LR")
    XCTAssertTrue(require("fraction-state").label.contains("3/2"))
    capture("02-LR-selection")
    require("undo").tap()
    XCTAssertEqual(require("word-state").label, "L")
    require("example").tap()
    XCTAssertEqual(require("word-state").label, "LRLRLR")
    require("viewpoint").tap()
    capture("03-oblique")
    require("viewpoint").tap()
    capture("04-side")
    require("detail-more").tap()
    capture("05-maximum-detail")
    require("reset").tap()
    XCTAssertEqual(require("word-state").label, "Start")
    capture("06-reset")
    exit()
    enter()
    XCTAssertEqual(require("word-state").label, "Start")
    capture("07-reentered")
    exit()
  }
  func testInputBoundsAndRecovery() {
    launch()
    enter()
    for _ in 0..<4 where require("detail-more").isEnabled { require("detail-more").tap() }
    XCTAssertFalse(require("detail-more").isEnabled)
    for _ in 0..<6 where require("detail-less").isEnabled { require("detail-less").tap() }
    XCTAssertFalse(require("detail-less").isEnabled)
    require("reset").tap()
    for i in 0..<24 { require(i % 2 == 0 ? "step-L" : "step-R").tap() }
    XCTAssertFalse(require("step-L").isEnabled)
    XCTAssertFalse(require("step-R").isEnabled)
    XCTAssertTrue(require("matrix-state").label.contains("det M = 1"))
    capture("08-move-limit")
    require("undo").tap()
    XCTAssertTrue(require("step-L").isEnabled)
    for _ in 0..<3 {
      require("reset").tap()
      XCTAssertEqual(require("word-state").label, "Start")
    }
    exit()
  }

  func testRepeatedImmersionLifecycle() {
    launch()
    for index in 0..<4 {
      enter()
      require("step-L").tap()
      XCTAssertEqual(require("word-state").label, "L")
      require("reset").tap()
      XCTAssertEqual(require("word-state").label, "Start")
      exit()
      capture("09-lifecycle-\(index)")
    }
  }

}
