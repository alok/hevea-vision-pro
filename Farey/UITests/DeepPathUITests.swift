// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest

extension FareyUITests {
  func testDeepDiskPathsAndExactLabels() throws {
    app = XCUIApplication()
    app.terminate()
    Self.launched = false
    launch()
    enter()
    require("example").tap()
    require("space-toggle").tap()
    try captureDeepState("baseline", word: "RLR", target: "3/5")

    require("reset").tap()
    for character in "LRLRRRLLRLLRLLLLLRR" {
      require(character == "L" ? "step-L" : "step-R").tap()
    }
    require("space-toggle").tap()
    try captureDeepState("counterexample-front", word: "LRLRRRLLRLLRLLLLLRR", target: "2419/1546")
    require("viewpoint").tap()
    try captureDeepState("counterexample-left", word: "LRLRRRLLRLLRLLLLLRR", target: "2419/1546")
    require("space-toggle").tap()
    XCTAssertTrue(require("geometry-explanation").label.contains("beyond this finite grid"))
    try captureDeepState("counterexample-lattice", word: "LRLRRRLLRLLRLLLLLRR", target: "2419/1546")

    require("reset").tap()
    for character in String(repeating: "LR", count: 12) {
      require(character == "L" ? "step-L" : "step-R").tap()
    }
    XCTAssertFalse(require("step-L").isEnabled)
    XCTAssertFalse(require("step-R").isEnabled)
    require("space-toggle").tap()
    let deepWord = String(repeating: "LR", count: 12)
    try captureDeepState("limit-front", word: deepWord, target: "121393/75025")
    exit()
    enter()
    try captureDeepState("limit-reentered", word: deepWord, target: "121393/75025")
    require("undo").tap()
    XCTAssertTrue(require("step-R").isEnabled)
    require("reset").tap()
    XCTAssertEqual(require("word-state").label, "Start")
    require("choose-fraction").tap()
    require("clear-fraction").tap()
    require("fraction-input").typeText("25/1")
    require("select-fraction").tap()
    require("close-fraction-entry").tap()
    require("space-toggle").tap()
    try captureDeepState("repeated-L", word: String(repeating: "L", count: 24), target: "25/1")
    require("reset").tap()
    exit()
  }

  private func captureDeepState(_ name: String, word: String, target: String) throws {
    XCTAssertEqual(require("word-state").label, word)
    XCTAssertTrue(require("fraction-state").label.contains(target))
    XCTAssertTrue(require("matrix-state").label.contains("det M = 1"))
    let record: [String: Any] = [
      "name": name, "word": require("word-state").label,
      "fraction": require("fraction-state").label, "matrix": require("matrix-state").label,
      "space": require("space-toggle").label, "viewpoint": require("viewpoint").label,
      "explanation": require("geometry-explanation").label, "receipt": require("render-receipt").label,
      "recordedAt": Date().timeIntervalSince1970,
    ]
    let attachment = XCTAttachment(
      data: try JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]),
      uniformTypeIdentifier: "public.json")
    attachment.name = "deep-state-" + name
    attachment.lifetime = .keepAlways
    add(attachment)
    capture("deep-" + name, holdFor: 1)
  }
}
