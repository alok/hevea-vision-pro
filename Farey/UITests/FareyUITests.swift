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

extension FareyUITests {
  func testConstructionAndReturnToLinkedDisk() {
    launch()
    enter()
    require("lattice-6-10").tap()
    require("space-toggle").tap()
    require("construction-start").tap()
    XCTAssertTrue(require("geometry-explanation").label.contains("q = 1"))
    capture("31-boundary-chart", holdFor: 3)
    require("construction-next").tap()
    require("construction-motion").tap()
    capture("33-reveal-ready", holdFor: 1)
    require("construction-next").tap()
    if require("construction-stop").isEnabled { require("construction-stop").tap() }
    capture("34-reveal-finished", holdFor: 1)
    XCTAssertTrue(require("geometry-explanation").label.contains("Integer lattice"))
    capture("32-construction-lattice", holdFor: 3)
    exit()
    enter()
    XCTAssertTrue(require("geometry-explanation").label.contains("Integer lattice"))
    XCTAssertFalse(require("construction-stop").isEnabled)
    require("construction-next").tap()
    require("construction-close").tap()
    XCTAssertTrue(require("space-toggle").label.contains("Disk"))
    XCTAssertEqual(require("word-state").label, "RLR")
    XCTAssertTrue(require("inspect-point").label.contains("(10, 6)"))
    require("choose-fraction").tap()
    enterFraction("25/1")
    require("close-fraction-entry").tap()
    require("construction-start").tap()
    require("construction-next").tap()
    require("construction-next").tap()
    XCTAssertTrue(require("geometry-explanation").label.contains("outside grid 12"))
    capture("35-construction-outside", holdFor: 3)
    require("reset").tap()
    exit()
  }
  func testMaximumPathDiskAndBackgroundRecovery() {
    launch()
    enter()
    require("reset").tap()
    for index in 0..<24 { require(index % 2 == 0 ? "step-L" : "step-R").tap() }
    let word = require("word-state").label
    let fraction = require("fraction-state").label
    require("space-toggle").tap()
    XCTAssertTrue(require("render-receipt").wait(for: \.label, toEqual: "253 Farey edges", timeout: 20))
    capture("30-max-path-disk", holdFor: 3)
    for _ in 0..<3 {
      XCUIDevice.shared.press(.home)
      app.activate()
      if element("enter-void").isHittable { enter() }
      XCTAssertEqual(require("word-state").label, word)
      XCTAssertEqual(require("fraction-state").label, fraction)
      XCTAssertTrue(require("render-receipt").label.contains("Farey edges"))
    }
    require("reset").tap()
    exit()
  }
  func testFreshLaunchSpotlightWalkthrough() {
    app = XCUIApplication()
    app.terminate()
    Self.launched = false
    launch()
    XCTAssertTrue(require("entry-credit").label.contains("Katherine Stange"))
    capture("24-fresh-entry", holdFor: 3)
    enter()
    require("learn").tap()
    require("lesson-choice-2-3").tap()
    require("lesson-apply").tap()
    require("lesson-next").tap()
    require("lesson-choice-3-5").tap()
    require("lesson-apply").tap()
    require("close-lesson").tap()
    require("viewpoint").tap()
    require("choose-fraction").tap()
    enterFraction("6/10")
    require("close-fraction-entry").tap()
    checkSpotlightRows()
    require("space-toggle").tap()
    capture("22-spotlight-disk", holdFor: 8)
    exit()
    enter()
    XCTAssertTrue(require("spotlight-status").label.contains("Spotlight 1/2"))
    require("space-toggle").tap()
    require("undo").tap()
    XCTAssertFalse(element("spotlight-status").exists)
    checkOutsideSpotlight()
    require("clear-spotlight").tap()
    XCTAssertFalse(element("spotlight-status").exists)
    require("reset").tap()
    exit()
    enter()
    XCTAssertEqual(require("word-state").label, "Start")
    XCTAssertFalse(element("spotlight-status").exists)
    exit()
  }
  private func checkSpotlightRows() {
    require("show-cf").tap()
    require("cf-kind-0-1").tap()
    XCTAssertTrue(require("spotlight-status").label.contains("Spotlight 0/1"))
    require("show-cf").tap()
    require("cf-kind-2-3").tap()
    XCTAssertTrue(require("spotlight-status").label.contains("intermediate mediant"))
    capture("21-intermediate-spotlight", holdFor: 8)
    require("show-cf").tap()
    require("cf-alternate").tap()
    XCTAssertTrue(require("spotlight-status").label.contains("Spotlight 2/3: convergent"))
    require("cf-kind-1-2").tap()
    XCTAssertTrue(require("spotlight-status").label.contains("Spotlight 1/2"))
    XCTAssertEqual(require("word-state").label, "RLR")
    XCTAssertTrue(require("inspect-point").label.contains("(10, 6)"))
  }
  private func checkOutsideSpotlight() {
    require("choose-fraction").tap()
    enterFraction("13/17")
    require("close-fraction-entry").tap()
    require("show-cf").tap()
    for _ in 0..<3 where !require("cf-kind-13-17").isHittable { require("cf-list").swipeUp() }
    require("cf-kind-13-17").tap()
    XCTAssertTrue(require("spotlight-status").label.contains("Outside grid 12"))
    capture("23-outside-spotlight", holdFor: 8)
    require("space-toggle").tap()
    XCTAssertFalse(require("spotlight-status").label.contains("Outside grid"))
  }
  func testContinuedFractionConventionsAndLinkedDisk() {
    launch()
    enter()
    require("reset").tap()
    require("example").tap()
    require("show-cf").tap()
    XCTAssertEqual(require("cf-expansion").label, "3/5 = [0; 1, 1, 2]")
    XCTAssertTrue(require("cf-kind-2-3").label.contains("Intermediate mediant"))
    XCTAssertTrue(require("cf-kind-1-2").label.contains("Convergent"))
    capture("18-canonical-convergents", holdFor: 4)
    require("cf-alternate").tap()
    XCTAssertEqual(require("cf-expansion").label, "3/5 = [0; 1, 1, 1, 1]")
    XCTAssertTrue(require("cf-kind-2-3").label.contains("Convergent"))
    capture("19-alternate-convergents", holdFor: 4)
    require("close-cf").tap()
    XCTAssertEqual(require("word-state").label, "RLR")
    require("space-toggle").tap()
    capture("20-convergent-disk", holdFor: 4)
    require("show-cf").tap()
    XCTAssertTrue(require("cf-kind-2-3").label.contains("Convergent"))
    require("close-cf").tap()
    require("reset").tap()
    require("show-cf").tap()
    XCTAssertEqual(require("cf-expansion").label, "1/1 = [1]")
    require("close-cf").tap()
    exit()
  }
}
