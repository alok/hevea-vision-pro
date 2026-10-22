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
  func testInspectedMultipleSurvivesPresentationChangesAndInvalidSelection() throws {
    let model = GalleryModel()
    model.select(LatticePoint(p: 6, q: 10))
    XCTAssertEqual(model.state.inspection?.equation, "(10, 6) = 2 × (5, 3)")
    model.toggleSpace()
    model.changeView()
    model.changeDepth(-3)
    model.select(LatticePoint(p: 0, q: 5))
    XCTAssertEqual(model.state.selectedPoint, LatticePoint(p: 6, q: 10))
    XCTAssertThrowsError(try model.enterFraction("1/0"))
    XCTAssertEqual(model.state.selectedPoint, LatticePoint(p: 6, q: 10))
    model.undo()
    XCTAssertNil(model.state.selectedPoint)
    XCTAssertEqual(model.state.mediant, Rational(2, 3))
    _ = try model.enterFraction("14/14")
    XCTAssertEqual(model.state.inspection?.divisor, 14)
    model.startLesson()
    XCTAssertEqual(model.state.inspection?.primitive, Rational(1, 2))
    XCTAssertEqual(model.state.inspection?.divisor, 1)
  }
  func testWorkedPathUsesExactStateAndRejectsMissingPrediction() {
    let model = GalleryModel()
    model.startLesson()
    XCTAssertEqual(model.state.mediant, Rational(1, 2))
    model.applyLessonStep()
    XCTAssertEqual(model.state.wordLabel, "R")
    model.predictLesson(Rational(1, 3))
    model.applyLessonStep()
    XCTAssertEqual(model.state.mediant, Rational(2, 3))
    XCTAssertTrue(model.lesson?.explanation?.contains("(2, 1) + (1, 1) = (3, 2)") == true)
    model.nextLessonStep()
    model.predictLesson(Rational(3, 5))
    model.applyLessonStep()
    XCTAssertEqual(model.state.mediant, Rational(3, 5))
    XCTAssertEqual(model.state.wordLabel, "RLR")
    model.toggleSpace()
    XCTAssertNotNil(model.lesson)
    model.undo()
    XCTAssertNil(model.lesson)
    XCTAssertEqual(model.state.mediant, Rational(2, 3))
    model.reset()
    XCTAssertEqual(model.state.wordLabel, "Start")
  }
  func testDirectEntryPreservesStateOnErrorAndReplacesTheLessonOnSuccess() throws {
    let model = GalleryModel()
    model.startLesson()
    model.predictLesson(Rational(2, 3))
    model.toggleSpace()
    model.changeView()
    let state = model.state
    let lesson = model.lesson
    let revision = model.revision
    for text in ["1/0", "1001/1001", "1/1000", "999999999999999999999/1"] {
      XCTAssertThrowsError(try model.enterFraction(text))
      XCTAssertEqual(model.state, state)
      XCTAssertEqual(model.lesson, lesson)
      XCTAssertEqual(model.revision, revision)
    }
    let result = try model.enterFraction("6/10")
    XCTAssertEqual(result.fraction, Rational(3, 5))
    XCTAssertNil(model.lesson)
    XCTAssertFalse(model.latticeMode)
    XCTAssertEqual(model.viewpoint, 1)
    XCTAssertEqual(model.state.wordLabel, "RLR")
    model.undo()
    XCTAssertEqual(model.state.mediant, Rational(2, 3))
    model.reset()
    XCTAssertEqual(model.state.mediant, Rational(1, 1))
  }
}
