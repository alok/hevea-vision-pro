import XCTest

extension FareyUITests {
  func testForegroundGeometryCaptureSequence() {
    app = XCUIApplication()
    app.terminate()
    Self.launched = false
    launch()
    captureLifecycle("entry")
    enter()
    for cycle in 0..<2 {
      require("reset").tap()
      require("example").tap()
      captureLifecycle("c\(cycle)-lattice")
      require("construction-start").tap()
      captureLifecycle("c\(cycle)-boundary")
      require("projected-open").tap()
      require("projected-previous").tap()
      captureLifecycle("c\(cycle)-preview")
      XCUIDevice.shared.press(.home)
      NSLog("FAREY_TIMELINE:c%d-home:%@", cycle, Date().ISO8601Format())
      app.activate()
      if element("enter-void").isHittable { enter() }
      XCTAssertEqual(require("word-state").label, "RLR")
      captureLifecycle("c\(cycle)-foreground")
      if element("projected-cancel").isHittable { require("projected-cancel").tap() }
      require("projected-open").tap()
      require("projected-previous").tap()
      require("projected-confirm").tap()
      XCTAssertTrue(require("fraction-state").label.contains("7/12"))
      captureLifecycle("c\(cycle)-confirmed")
      require("viewpoint").tap()
      captureLifecycle("c\(cycle)-viewpoint")
      require("construction-close").tap()
      captureLifecycle("c\(cycle)-returned-lattice")
      exit()
      captureLifecycle("c\(cycle)-exited")
      enter()
      captureLifecycle("c\(cycle)-reentered")
      Thread.sleep(forTimeInterval: 3)
      captureLifecycle("c\(cycle)-idle")
    }
    require("reset").tap()
    exit()
  }
  private func captureLifecycle(_ name: String) {
    capture("lifecycle-" + name, holdFor: 0)
  }
}
