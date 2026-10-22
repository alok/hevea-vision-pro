import XCTest
@testable import FareyCore

final class BoundaryConstructionTests: XCTestCase {
  func testProjectionPreservesDirectionAndIdentifiesMultiples() {
    for point in LatticePoint.grid(bound: 14) where point.q > 0 {
      let projection = BoundaryConstruction.project(point)!
      XCTAssertEqual(projection.y, 1)
      XCTAssertEqual(projection.x * Double(point.q), Double(point.p), accuracy: 1e-12)
      let multiple = LatticePoint(p: point.p * 3, q: point.q * 3)
      XCTAssertEqual(BoundaryConstruction.project(multiple), projection)
    }
  }
  func testInfinityHasNoFiniteChartPoint() {
    XCTAssertNil(BoundaryConstruction.project(LatticePoint(p: 1, q: 0)))
    XCTAssertNil(BoundaryConstruction.project(LatticePoint(p: -1, q: 2)))
    XCTAssertEqual(BoundaryConstruction.project(LatticePoint(p: 0, q: 1)), Point2(0, 1))
  }
}
