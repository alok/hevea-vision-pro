import XCTest

@testable import FareyCore

final class StarscapeTests: XCTestCase {
  func testConeProjectionAndQuadraticRoot() {
    XCTAssertEqual(Starscape.points().count, 280)
    for p in Starscape.points() {
      let v = p.vector
      XCTAssertEqual(v.x * v.x + v.z * v.z - v.y * v.y, Double(p.discriminant))
      let image = p.projected(height: 4)!
      XCTAssertEqual(image.y, 4)
      XCTAssertLessThan(image.x * image.x + image.z * image.z, 16)
      XCTAssertEqual(image.x * v.y, image.y * v.x, accuracy: 1e-10)
      let root = p.upperRoot!
      XCTAssertEqual(
        Double(p.a) * (root.x * root.x - root.y * root.y) + Double(p.b) * root.x + Double(p.c), 0,
        accuracy: 1e-10)
      XCTAssertEqual(2 * Double(p.a) * root.x * root.y + Double(p.b) * root.y, 0, accuracy: 1e-10)
      let u = image.x / 4
      let w = image.z / 4
      XCTAssertEqual(u / (1 - w), root.x, accuracy: 1e-10)
      XCTAssertEqual(sqrt(1 - u * u - w * w) / (1 - w), root.y, accuracy: 1e-10)
    }
  }
  func testDistinctDepthsShareAnImageAndNullPointsAreExcluded() {
    let a = CoefficientPoint(1, -1, 2)
    let b = CoefficientPoint(2, -2, 4)
    XCTAssertNotEqual(a.vector, b.vector)
    XCTAssertEqual(a.projected(height: 4), b.projected(height: 4))
    XCTAssertEqual(a.upperRoot, b.upperRoot)
    XCTAssertNil(CoefficientPoint(1, 2, 1).projected(height: 4))
    XCTAssertNil(CoefficientPoint(0, 0, 1).upperRoot)
    XCTAssertTrue(Starscape.points(bound: 100).isEmpty)
  }
  func testActualCoefficientPointsAreNoncoplanar() {
    let o = CoefficientPoint(1, 0, 1).vector
    let a = CoefficientPoint(1, 1, 1).vector - o
    let b = CoefficientPoint(1, 0, 2).vector - o
    let c = CoefficientPoint(2, 0, 2).vector - o
    let determinant =
      a.x * (b.y * c.z - b.z * c.y) - a.y * (b.x * c.z - b.z * c.x) + a.z * (b.x * c.y - b.y * c.x)
    XCTAssertNotEqual(determinant, 0)
  }
}
