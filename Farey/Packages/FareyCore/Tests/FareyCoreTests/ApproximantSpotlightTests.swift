import XCTest

@testable import FareyCore

final class ApproximantSpotlightTests: XCTestCase {
  func testSpotlightIsIndependentAndSurvivesAReclassification() {
    var state = FareyState()
    state.select(Rational(6, 10))
    let before = state
    var spotlight = ApproximantSpotlight()
    XCTAssertTrue(spotlight.focus(Rational(2, 3), in: state, alternate: false))
    spotlight.reconcile(with: state, alternate: true)
    XCTAssertEqual(spotlight.rational, Rational(2, 3))
    XCTAssertEqual(state, before)
    XCTAssertFalse(spotlight.focus(Rational(7, 11), in: state, alternate: true))
    XCTAssertEqual(spotlight.rational, Rational(2, 3))
    XCTAssertTrue(spotlight.focus(Rational(1, 2), in: state, alternate: false))
    XCTAssertEqual(spotlight.rational, Rational(1, 2))
  }
  func testRemovedBoundaryAndChangedTargetClearTheSpotlight() {
    var state = FareyState()
    var spotlight = ApproximantSpotlight()
    XCTAssertTrue(spotlight.focus(Rational(0, 1), in: state, alternate: true))
    spotlight.reconcile(with: state, alternate: false)
    XCTAssertNil(spotlight.rational)
    state.select(Rational(3, 5))
    XCTAssertTrue(spotlight.focus(Rational(2, 3), in: state, alternate: false))
    state.step(.l)
    spotlight.reconcile(with: state, alternate: false)
    XCTAssertNil(spotlight.rational)
  }
  func testOutsideGridCoordinatesAreRetainedWithoutClamping() {
    var state = FareyState()
    state.select(Rational(13, 17))
    var spotlight = ApproximantSpotlight()
    XCTAssertTrue(spotlight.focus(Rational(13, 17), in: state, alternate: false))
    spotlight.reconcile(with: state, alternate: true)
    XCTAssertEqual(spotlight.rational, Rational(13, 17))
    spotlight.clear()
    XCTAssertNil(spotlight.rational)
  }
}
