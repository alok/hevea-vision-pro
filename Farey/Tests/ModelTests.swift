import XCTest

@testable import FareyVision

@MainActor final class ModelTests: XCTestCase {
  func testPrecisionNoticeTracksTheViewWithoutChangingExactState() {
    let model = GalleryModel()
    model.starscapeMode = false
    model.preset()
    XCTAssertNil(model.precisionNotice)
    model.reset()
    for _ in 0..<12 { model.step(.l); model.step(.r) }
    let exact = model.state
    XCTAssertNil(model.precisionNotice)
    model.changeDepth(1)
    XCTAssertNotNil(model.precisionNotice)
    model.toggleSpace()
    XCTAssertNotNil(model.precisionNotice)
    model.startConstruction()
    XCTAssertNil(model.precisionNotice)
    model.endConstruction()
    XCTAssertNotNil(model.precisionNotice)
    XCTAssertEqual(model.state, exact)
    model.reset()
    XCTAssertNil(model.precisionNotice)
  }
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
  func testChangingFiniteExpansionPreservesTheMathematicsAndLesson() {
    let model = GalleryModel()
    model.startLesson()
    let state = model.state
    let lesson = model.lesson
    model.setAlternateCF(true)
    XCTAssertTrue(model.alternateCF)
    XCTAssertEqual(model.state, state)
    XCTAssertEqual(model.lesson, lesson)
    model.toggleSpace()
    XCTAssertTrue(model.alternateCF)
    model.reset()
    XCTAssertFalse(model.alternateCF)
  }
  func testSpotlightPreservesLessonAndReportsAnOutsideGridPoint() throws {
    let model = GalleryModel()
    model.startLesson()
    model.predictLesson(Rational(2, 3))
    let state = model.state
    let lesson = model.lesson
    model.spotlightPoint(Rational(1, 1))
    XCTAssertEqual(model.state, state)
    XCTAssertEqual(model.lesson, lesson)
    model.applyLessonStep()
    XCTAssertNil(model.spotlight.rational)
    try model.enterFraction("13/17")
    model.spotlightPoint(Rational(13, 17))
    model.changeDepth(-100)
    XCTAssertTrue(model.spotlightStatus.contains("Outside grid 6"))
    XCTAssertEqual(model.spotlight.rational, Rational(13, 17))
    XCTAssertThrowsError(try model.enterFraction("1/0"))
    XCTAssertEqual(model.spotlight.rational, Rational(13, 17))
    model.toggleSpace()
    XCTAssertFalse(model.spotlightStatus.contains("Outside grid"))
    model.undo()
    XCTAssertNil(model.spotlight.rational)
    model.reset()
    model.spotlightPoint(Rational(1, 1))
    model.reset()
    XCTAssertNil(model.spotlight.rational)
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
  func testConstructionPreservesMathematicsLessonAndPresentation() {
    let model = GalleryModel()
    model.startLesson()
    model.predictLesson(Rational(2, 3))
    model.spotlightPoint(Rational(1, 1))
    model.toggleSpace()
    model.changeView()
    let viewpoint = model.viewpoint
    let state = model.state, lesson = model.lesson
    model.startConstruction()
    for _ in 0..<4 { model.moveConstruction(1, reduceMotion: true) }
    XCTAssertEqual(model.constructionStage, .plane)
    XCTAssertEqual(model.state, state)
    XCTAssertEqual(model.lesson, lesson)
    XCTAssertEqual(model.spotlight.rational, Rational(1, 1))
    model.endConstruction()
    XCTAssertFalse(model.latticeMode)
    XCTAssertEqual(model.viewpoint, viewpoint)
    XCTAssertEqual(model.state, state)
  }
  func testConstructionMotionIsOptInAndReducedMotionWins() {
    let model = GalleryModel()
    model.startConstruction()
    model.moveConstruction(1, reduceMotion: false)
    model.animateConstruction = true
    model.moveConstruction(1, reduceMotion: true)
    XCTAssertFalse(model.constructionMoving)
    model.moveConstruction(-1, reduceMotion: false)
    model.moveConstruction(1, reduceMotion: false)
    XCTAssertTrue(model.constructionMoving)
    model.changeDepth(-1)
    XCTAssertFalse(model.constructionMoving)
    model.moveConstruction(-1, reduceMotion: false)
    model.moveConstruction(1, reduceMotion: false)
    model.stopConstruction()
    XCTAssertFalse(model.constructionMoving)
    model.reset()
    XCTAssertNil(model.constructionStage)
    model.select(LatticePoint(p: 13, q: 17))
    model.startConstruction()
    model.moveConstruction(1, reduceMotion: true)
    model.moveConstruction(1, reduceMotion: true)
    XCTAssertTrue(model.constructionExplanation.contains("outside grid 12"))
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
