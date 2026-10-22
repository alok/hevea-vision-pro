import XCTest

@testable import FareyCore

final class PointInspectionTests: XCTestCase {
  func testMultiplesKeepTheirIdentityAndShareTheExactDirection() throws {
    var state = FareyState()
    for (p, q, divisor) in [(3, 5, 1), (6, 10, 2), (9, 15, 3)] {
      XCTAssertTrue(state.select(Rational(Int64(p), Int64(q))))
      let inspection = try XCTUnwrap(state.inspection)
      XCTAssertEqual(inspection.point, LatticePoint(p: Int64(p), q: Int64(q)))
      XCTAssertEqual(inspection.divisor, Int64(divisor))
      XCTAssertEqual(inspection.primitive, Rational(3, 5))
      XCTAssertEqual(state.wordLabel, "RLR")
      XCTAssertEqual(state.determinant, 1)
      XCTAssertTrue(inspection.point.isOnRay(state.mediant))
      XCTAssertEqual(inspection.point.rational.diskPoint, state.mediant.diskPoint)
    }
    XCTAssertEqual(state.inspection?.equation, "(15, 9) = 3 × (5, 3)")
  }
  func testGridAndInputBoundariesPreserveTheUnreducedPoint() {
    for (p, q, divisor) in [(14, 14, 14), (1000, 1000, 1000), (1, 25, 1), (25, 1, 1)] {
      var state = FareyState()
      XCTAssertTrue(state.select(Rational(Int64(p), Int64(q))))
      XCTAssertEqual(state.inspection?.divisor, Int64(divisor))
      XCTAssertEqual(state.selectedPoint, LatticePoint(p: Int64(p), q: Int64(q)))
    }
  }
  func testAxesOriginAndRejectedSelectionsDoNotReplaceInspection() {
    var state = FareyState()
    state.select(Rational(6, 10))
    let before = state
    for rational in [Rational(0, 0), Rational(0, 5), Rational(5, 0), Rational(-1, 2),
      Rational(1001, 1001), Rational(1, 1000)] {
      XCTAssertFalse(state.select(rational))
      XCTAssertEqual(state, before)
    }
    for point in [LatticePoint(p: 0, q: 0), LatticePoint(p: 0, q: 5),
      LatticePoint(p: 5, q: 0), LatticePoint(p: -1, q: 2)] {
      XCTAssertNil(PointInspection(point))
    }
  }
  func testNavigationClearsPointIdentityAndRejectedMovePreservesIt() {
    var state = FareyState()
    state.select(Rational(6, 10))
    state.step(.l)
    XCTAssertNil(state.selectedPoint)
    XCTAssertEqual(state.inspection?.primitive, Rational(5, 8))
    state.select(Rational(6, 10))
    state.undo()
    XCTAssertNil(state.selectedPoint)
    XCTAssertEqual(state.inspection?.primitive, Rational(2, 3))
    state.select(Rational(25, 1))
    let before = state
    XCTAssertFalse(state.step(.l))
    XCTAssertEqual(state, before)
    state.reset()
    XCTAssertNil(state.selectedPoint)
    XCTAssertEqual(state.inspection?.primitive, Rational(1, 1))
  }
}
