import XCTest

extension FareyUITests {
  func testFreshLaunchChooserAndForegroundRendering() {
    app = XCUIApplication()
    app.terminate()
    Self.launched = false
    launch()
    XCTAssertTrue(require("entry-credit").label.contains("Katherine Stange"))
    capture("48-fresh-entry")
    enter()
    XCTAssertEqual(require("word-state").label, "Start")
    require("construction-start").tap()
    require("projected-open").tap()
    require("projected-previous").tap()
    XCTAssertEqual(require("projected-preview").label, "Preview: 11/12")
    capture("49-chooser-idle-start", holdFor: 3)
    XCTAssertEqual(require("projected-preview").label, "Preview: 11/12")
    capture("50-chooser-idle-end")
    XCUIDevice.shared.press(.home)
    app.activate()
    if element("enter-void").isHittable { enter() }
    if element("projected-cancel").isHittable { require("projected-cancel").tap() }
    Thread.sleep(forTimeInterval: 5)
    capture("53-foreground-before-selection")
    NSLog("VISUAL_TITLE:%@", String(app.staticTexts["BOUNDARY TO LATTICE"].exists))
    XCTAssertEqual(require("word-state").label, "Start")
    XCTAssertTrue(require("render-receipt").label.contains("projected direction dots"))
    require("projected-open").tap()
    require("projected-previous").tap()
    require("projected-confirm").tap()
    XCTAssertTrue(require("fraction-state").label.contains("11/12"))
    Thread.sleep(forTimeInterval: 5)
    capture("54-foreground-after-selection")
    require("viewpoint").tap()
    Thread.sleep(forTimeInterval: 2)
    capture("55-foreground-viewpoint")
    require("construction-close").tap()
    capture("56-foreground-lattice", holdFor: 2)
    exit()
    enter()
    capture("57-reentered-lattice", holdFor: 3)
    require("reset").tap()
    exit()
  }

}
