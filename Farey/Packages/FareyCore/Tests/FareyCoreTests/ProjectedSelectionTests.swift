import XCTest
@testable import FareyCore

final class ProjectedSelectionTests: XCTestCase {
  func testDenseNeighborsFollowExactFractionOrder() throws {
    var choice = try XCTUnwrap(ProjectedSelection(near: LatticePoint(p: 3, q: 5), bound: 14))
    XCTAssertEqual(choice.points.count, 127)
    choice.move(-1)
    XCTAssertEqual(choice.point, LatticePoint(p: 7, q: 12))
    choice.move(2)
    XCTAssertEqual(choice.point, LatticePoint(p: 8, q: 13))
    for pair in zip(choice.points, choice.points.dropFirst()) {
      XCTAssertLessThan(pair.0.p * pair.1.q, pair.1.p * pair.0.q)
    }
  }
  func testOnlyDisplayedPrimitiveDirectionsAndSaturatingNavigation() throws {
    XCTAssertNil(ProjectedSelection(near: LatticePoint(p: 6, q: 10), bound: 14))
    XCTAssertNil(ProjectedSelection(near: LatticePoint(p: 0, q: 1), bound: 14))
    XCTAssertNil(ProjectedSelection(near: LatticePoint(p: 1, q: 0), bound: 14))
    var choice = try XCTUnwrap(ProjectedSelection(near: LatticePoint(p: 1, q: 1), bound: 14))
    choice.move(-1)
    XCTAssertEqual(choice.point, LatticePoint(p: 13, q: 14))
    choice.move(Int.min)
    XCTAssertEqual(choice.point, LatticePoint(p: 1, q: 14))
    XCTAssertFalse(choice.canGoBack)
    choice.move(Int.max)
    XCTAssertEqual(choice.point, LatticePoint(p: 14, q: 1))
    XCTAssertFalse(choice.canGoForward)
  }
}
