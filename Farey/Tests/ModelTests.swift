import XCTest

@testable import FareyVision

@MainActor final class ModelTests: XCTestCase {
  func testResetRestoresPresentationAndBounds() {
    let model = GalleryModel()
    model.step(.l)
    model.toggleSpace()
    model.changeView()
    model.changeDepth(100)
    XCTAssertEqual(model.depth, 7)
    model.reset()
    XCTAssertEqual(model.state.wordLabel, "Start")
    XCTAssertEqual(model.depth, 6)
    XCTAssertEqual(model.viewpoint, 0)
    XCTAssertTrue(model.latticeMode)
    model.changeDepth(-100)
    XCTAssertEqual(model.depth, 3)
  }
  func testPointSelectionKeepsTheLinkedViewState() {
    let model = GalleryModel()
    model.select(LatticePoint(p: 3, q: 5))
    XCTAssertEqual(model.state.mediant, Rational(3, 5))
    XCTAssertEqual(model.state.wordLabel, "RLR")
    model.toggleSpace()
    XCTAssertFalse(model.latticeMode)
    XCTAssertEqual(model.state.mediant, Rational(3, 5))
    model.preset()
    XCTAssertEqual(model.state.mediant, Rational(3, 5))
  }
}
