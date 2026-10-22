// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest

@MainActor final class SafariAuditTests: XCTestCase {
  private func openFresh() -> XCUIApplication {
    continueAfterFailure = false
    let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
    if safari.state != .notRunning { safari.terminate() }
    XCUIDevice.shared.orientation = .portrait
    XCUIDevice.shared.system.open(URL(string: "http://127.0.0.1:8765/?audit=\(UUID().uuidString)")!)
    safari.activate()
    for title in ["Continue", "Start Browsing"] {
      if safari.buttons[title].exists { safari.buttons[title].tap() }
    }
    XCTAssertTrue(safari.webViews.buttons["3/5 example"].waitForExistence(timeout: 30), safari.debugDescription)
    return safari
  }
  private func capture(_ safari: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: safari.screenshot())
    attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
  }
  func testAExactSelectionAndReload() {
    let safari = openFresh(), web = safari.webViews.firstMatch
    XCTAssertTrue(web.staticTexts["Start"].exists)
    let field = web.textFields["Positive rational p/q"]
    field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
    field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12))
    XCTAssertEqual(field.value as? String, "")
    field.typeText("6/10")
    XCTAssertEqual(field.value as? String, "6/10")
    web.buttons["Select"].tap()
    if safari.buttons["Done"].firstMatch.exists { safari.buttons["Done"].firstMatch.tap() }
    let multiple = web.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "gcd(10, 6) = 2")).firstMatch
    XCTAssertTrue(multiple.waitForExistence(timeout: 5))
    web.buttons["Grid"].tap()
    if safari.pickerWheels.firstMatch.waitForExistence(timeout: 2) { safari.pickerWheels.firstMatch.adjust(toPickerWheelValue: "14") }
    else { safari.buttons["14"].firstMatch.tap() }
    if safari.buttons["Done"].firstMatch.exists { safari.buttons["Done"].firstMatch.tap() }
    XCTAssertEqual(web.buttons["Grid"].value as? String, "14")
    safari.buttons["ReloadButton"].tap()
    XCTAssertTrue(web.staticTexts["RLR"].waitForExistence(timeout: 10))
    XCTAssertTrue(multiple.waitForExistence(timeout: 5))
    XCTAssertEqual(web.buttons["Grid"].value as? String, "14")
    print("FAREY_SAFARI_RESTORED: RLR; 3/5; inspected (10,6); grid 14")
  }
  func testBPortraitAndLandscape() {
    let safari = openFresh(), web = safari.webViews.firstMatch
    XCTAssertTrue(web.staticTexts["Start"].exists)
    web.buttons["3/5 example"].tap()
    XCTAssertTrue(web.staticTexts["RLR"].waitForExistence(timeout: 5))
    let canvas = web.images["Interactive three-dimensional integer lattice"]
    XCTAssertTrue(canvas.exists)
    XCTAssertGreaterThan(canvas.frame.height, 160)
    capture(safari, "01-safari-072-portrait")
    XCUIDevice.shared.orientation = .landscapeLeft
    XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _,_ in safari.frame.width > safari.frame.height }, object: nil)], timeout: 10), .completed)
    web.buttons["L"].tap()
    XCTAssertTrue(web.staticTexts["RLRL"].waitForExistence(timeout: 5))
    web.buttons["Undo"].tap()
    XCTAssertTrue(web.staticTexts["RLR"].waitForExistence(timeout: 5))
    XCTAssertGreaterThan(canvas.frame.minX, web.buttons["Reset"].frame.maxX)
    capture(safari, "02-safari-072-landscape")
    print("FAREY_SAFARI_LAYOUT: portrait and landscape; L and Undo preserve target")
    web.buttons["Reset"].tap()
    XCTAssertTrue(web.staticTexts["Start"].waitForExistence(timeout: 5))
    XCTAssertEqual(web.buttons["Grid"].value as? String, "12")
  }
  func testCPortraitEvidence() {
    let safari = openFresh(), web = safari.webViews.firstMatch
    web.buttons["3/5 example"].tap()
    XCTAssertTrue(web.staticTexts["RLR"].waitForExistence(timeout: 5))
    XCTAssertTrue(web.images["Interactive three-dimensional integer lattice"].exists)
  }
}
