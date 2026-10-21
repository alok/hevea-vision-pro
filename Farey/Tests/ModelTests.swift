import XCTest

@testable import FareyVision

@MainActor final class ModelTests: XCTestCase {
  func testResetRestoresPresentationAndBounds() {
    let model = GalleryModel()
    model.step(.l)
    model.changeView()
    model.changeDepth(100)
    XCTAssertEqual(model.depth, 7)
    model.reset()
    XCTAssertEqual(model.state.wordLabel, "Start")
    XCTAssertEqual(model.depth, 6)
    XCTAssertEqual(model.viewpoint, 0)
    model.changeDepth(-100)
    XCTAssertEqual(model.depth, 3)
  }
}
