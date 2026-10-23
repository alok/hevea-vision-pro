import XCTest

/// Opt-in diagnostic (scripts/capture-tests.py --spatial-probe) for the Roots window's input in the simulator. Each
/// route is recorded. Observed on 2026-10-23: the window's accessibility frame is reported at the origin (0, 0, 560,
/// 560), so a coordinate tap at the root of i did not select and a coordinate press-drag left g unchanged; swipeRight
/// changed g to [1.21, 0.36; 0.34, 0.93]; an app-coordinate press-drag then failed with "Received invalid scene ID
/// (nil) from Accessibility". The ordinary suite drives the pane with swipes only.
extension FareyUITests {
  func testRootsPaneInputRoutes() throws {
    try XCTSkipUnless(
      ProcessInfo.processInfo.environment["FAREY_SPATIAL_PROBE"] == "1", "Opt-in diagnostic: run capture-tests.py --spatial-probe")
    continueAfterFailure = true
    app = XCUIApplication()
    app.terminate()
    Self.launched = false
    launch()
    require("enter-void").tap()
    require("roots-open").tap()
    let pane = require("roots-pane")
    XCTAssertTrue(pane.wait(for: \.isHittable, toEqual: true, timeout: 10))
    print("ROOTS-PROBE pane frame \(pane.frame) app frame \(app.frame)")
    let scale = pane.frame.width / 2.4, cy = (pane.frame.height / 2 - 28) / scale
    let iY = (pane.frame.height / 2 - (1 - cy) * scale) / pane.frame.height
    pane.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: iY)).tap()
    sleep(1)
    print("ROOTS-PROBE tap at i: state \(require("coefficient-state").label)")
    let routes: [(String, () -> Void)] = [
      ("swipe", { pane.swipeRight() }),
      ("press-drag", {
        pane.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.55))
          .press(forDuration: 0.5, thenDragTo: pane.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.4)),
            withVelocity: 200, thenHoldForDuration: 0.2)
      }),
      ("app-coordinate press-drag", {
        let start = self.app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: pane.frame.midX, dy: pane.frame.midY))
        start.press(forDuration: 0.5, thenDragTo: start.withOffset(CGVector(dx: 80, dy: -40)))
      }),
    ]
    for (name, route) in routes {
      require("group-identity").tap()
      route()
      sleep(1)
      print("ROOTS-PROBE \(name): \(require("group-state").label)")
    }
  }
}
