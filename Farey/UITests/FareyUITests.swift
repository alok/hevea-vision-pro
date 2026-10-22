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
  func capture(_ name: String, holdFor seconds: TimeInterval = 1) {
    NSLog("FAREY_CAPTURE:%@", name)
    Thread.sleep(forTimeInterval: seconds)
  }
  func enter() {
    let button = require("enter-void")
    XCTAssertTrue(button.wait(for: \.isEnabled, toEqual: true, timeout: 20))
    button.tap()
    require("word-state")
    let rendered = NSPredicate(
      format: "label CONTAINS %@ OR label CONTAINS %@", "lattice points", "Farey edges")
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
    capture("01-lattice-default")
    require("step-L").tap()
    require("step-R").tap()
    XCTAssertEqual(require("word-state").label, "LR")
    XCTAssertTrue(require("fraction-state").label.contains("3/2"))
    capture("02-LR-selection")
    require("undo").tap()
    XCTAssertEqual(require("word-state").label, "L")
    require("example").tap()
    XCTAssertEqual(require("word-state").label, "RLR")
    require("viewpoint").tap()
    capture("03-left-translation")
    require("viewpoint").tap()
    capture("04-right-translation")
    require("detail-more").tap()
    capture("05-maximum-grid")
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

  func testSpatialPointSelectionAndLinkedDisk() {
    launch()
    enter()
    require("lattice-3-5").tap()
    XCTAssertTrue(require("fraction-state").label.contains("3/5"))
    XCTAssertEqual(require("word-state").label, "RLR")
    capture("10-selected-lattice")
    require("space-toggle").tap()
    XCTAssertTrue(
      require("render-receipt").wait(for: \.label, toEqual: "253 Farey edges", timeout: 20))
    XCTAssertTrue(require("fraction-state").label.contains("3/5"))
    capture("11-linked-disk")
    require("reset").tap()
    XCTAssertTrue(require("space-toggle").label.contains("Lattice"))
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

  func testWorkedPathAndLinkedView() {
    launch()
    enter()
    require("learn").tap()
    XCTAssertTrue(require("lesson-fraction").label.contains("1/2"))
    XCTAssertFalse(require("lesson-apply").isEnabled)
    require("lesson-choice-1-3").tap()
    require("lesson-apply").tap()
    XCTAssertTrue(require("lesson-fraction").label.contains("2/3"))
    XCTAssertTrue(require("lesson-explanation").label.contains("(2, 1) + (1, 1) = (3, 2)"))
    capture("12-native-lesson-L", holdFor: 3)
    require("lesson-next").tap()
    require("lesson-choice-3-5").tap()
    require("lesson-apply").tap()
    XCTAssertTrue(require("lesson-fraction").label.contains("3/5"))
    capture("13-native-lesson-R", holdFor: 3)
    require("lesson-space").tap()
    require("close-lesson").tap()
    XCTAssertTrue(require("space-toggle").label.contains("Disk"))
    XCTAssertTrue(require("fraction-state").label.contains("3/5"))
    XCTAssertEqual(require("word-state").label, "RLR")
    require("undo").tap()
    XCTAssertEqual(require("word-state").label, "RL")
    require("reset").tap()
    exit()
  }
  func testDirectFractionEntryAndReentry() {
    launch()
    enter()
    require("reset").tap()
    require("choose-fraction").tap()
    enterFraction("6/10")
    XCTAssertTrue(require("fraction-result").label.contains("6/10 reduces to 3/5"))
    XCTAssertTrue(require("entry-selected-state").label.contains("RLR"))
    capture("14-direct-entry-reduced", holdFor: 4)
    require("close-fraction-entry").tap()
    require("space-toggle").tap()
    require("choose-fraction").tap()
    for (text, message) in [
      ("1/0", "denominator cannot be zero"),
      ("999999999999999999999/1", "too large"),
      ("1/1000", "more than 24"),
      ("1001/1001", "before reduction"),
    ] {
      enterFraction(text)
      XCTAssertTrue(require("fraction-error").label.contains(message))
      XCTAssertTrue(require("entry-selected-state").label.contains("3/5 · RLR"))
    }
    enterFraction("13/17")
    XCTAssertTrue(require("entry-selected-state").label.contains("RLLLRRR"))
    require("close-fraction-entry").tap()
    XCTAssertTrue(require("space-toggle").label.contains("Disk"))
    require("space-toggle").tap()
    XCTAssertTrue(require("geometry-explanation").label.contains("beyond this finite grid"))
    capture("15-direct-entry-beyond-grid", holdFor: 4)
    exit()
    enter()
    XCTAssertEqual(require("word-state").label, "RLLLRRR")
    require("choose-fraction").tap()
    XCTAssertEqual(require("fraction-input").value as? String, "13/17")
    require("close-fraction-entry").tap()
    require("undo").tap()
    XCTAssertEqual(require("word-state").label, "RLLLRR")
    XCTAssertTrue(require("fraction-state").label.contains("10/13"))
    require("reset").tap()
    XCTAssertEqual(require("word-state").label, "Start")
    exit()
  }
  private func enterFraction(_ text: String) {
    require("clear-fraction").tap()
    require("fraction-input").typeText(text)
    require("select-fraction").tap()
  }
  func testInspectedMultipleAndLinkedDisk() {
    launch()
    enter()
    require("reset").tap()
    require("lattice-6-10").tap()
    XCTAssertEqual(require("word-state").label, "RLR")
    XCTAssertTrue(require("inspect-point").label.contains("(10, 6) = 2 × (5, 3)"))
    require("inspect-point").tap()
    XCTAssertEqual(require("point-equation").label, "(10, 6) = 2 × (5, 3)")
    XCTAssertTrue(require("point-gcd").label.contains("gcd(10, 6) = 2"))
    XCTAssertTrue(require("point-reduction").label.contains("6/10 = 3/5"))
    capture("16-inspected-multiple", holdFor: 3)
    require("close-point-inspection").tap()
    require("space-toggle").tap()
    XCTAssertTrue(require("inspect-point").label.contains("(10, 6) = 2 × (5, 3)"))
    capture("17-multiple-linked-disk", holdFor: 3)
    exit()
    enter()
    XCTAssertTrue(require("inspect-point").label.contains("(10, 6) = 2 × (5, 3)"))
    require("space-toggle").tap()
    for _ in 0..<3 { require("detail-less").tap() }
    require("inspect-point").tap()
    XCTAssertTrue(require("point-outside-grid").label.contains("beyond this finite grid"))
    require("close-point-inspection").tap()
    require("undo").tap()
    XCTAssertEqual(require("word-state").label, "RL")
    XCTAssertTrue(require("inspect-point").label.contains("(3, 2) = 1 × (3, 2)"))
    require("reset").tap()
    XCTAssertTrue(require("inspect-point").label.contains("(1, 1) = 1 × (1, 1)"))
    exit()
  }
}
