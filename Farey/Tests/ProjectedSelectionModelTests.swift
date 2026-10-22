import XCTest
@testable import FareyVision

@MainActor final class ProjectedSelectionModelTests: XCTestCase {
  func testPreviewPreservesPointLessonAndCameraUntilConfirmed() {
    let model = GalleryModel()
    model.startLesson()
    model.predictLesson(Rational(2, 3))
    model.spotlightPoint(Rational(1, 1))
    model.startConstruction()
    let state = model.state, lesson = model.lesson, revision = model.revision
    model.activatePoint(LatticePoint(p: 3, q: 5))
    model.projectedSelection?.move(1)
    XCTAssertEqual(model.state, state)
    XCTAssertEqual(model.lesson, lesson)
    XCTAssertEqual(model.spotlight.rational, Rational(1, 1))
    XCTAssertEqual(model.viewpoint, 0)
    XCTAssertEqual(model.revision, revision)
    model.confirmProjectedSelection()
    XCTAssertEqual(model.state.mediant, Rational(5, 8))
    XCTAssertEqual(model.state.selectedPoint, LatticePoint(p: 5, q: 8))
    XCTAssertNil(model.projectedSelection)
    XCTAssertNil(model.lesson)
  }
  func testCancelAndPresentationChangesDoNotCommitAPreview() {
    let model = GalleryModel()
    model.select(LatticePoint(p: 6, q: 10))
    model.startConstruction()
    let state = model.state
    model.activatePoint(LatticePoint(p: 1, q: 1))
    model.projectedSelection = nil
    XCTAssertEqual(model.state, state)
    model.chooseProjectedDirection()
    model.changeDepth(1)
    XCTAssertNil(model.projectedSelection)
    model.chooseProjectedDirection()
    model.moveConstruction(1, reduceMotion: true)
    XCTAssertNil(model.projectedSelection)
    XCTAssertEqual(model.state, state)
    model.endConstruction()
    model.activatePoint(LatticePoint(p: 6, q: 10))
    XCTAssertNil(model.projectedSelection)
    XCTAssertEqual(model.state.selectedPoint, LatticePoint(p: 6, q: 10))
  }
}
