// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest

@testable import FareyCore

final class GeodesicStabilityTests: XCTestCase {
  func testDeepHistoryDoesNotCollapseTubeSegments() {
    for turn: Turn in [.l, .r] {
      var state = FareyState()
      for index in 0..<24 { state.step(index % 2 == 0 ? turn : (turn == .l ? .r : .l)) }
      for edge in state.history {
        let samples = edge.samples
        for (a, b) in zip(samples, samples.dropFirst()) {
          XCTAssertNotEqual(a, b, "Collapsed segment at \(edge.left), \(edge.right)")
          let dx = Float(b.x - a.x), dy = Float(b.y - a.y)
          XCTAssertGreaterThan(dx * dx + dy * dy, 0)
        }
      }
    }
  }
  func testNearCoincidentAndNearAntipodalBoundariesStayFinite() {
    for epsilon in [1e-5, 1e-8, 1e-10] {
      let start = Point2(cos(epsilon), sin(epsilon))
      for end in [Point2(cos(epsilon), -sin(epsilon)), Point2(-cos(epsilon), sin(epsilon))] {
        let samples = Geometry.geodesic(start, end)
        XCTAssertEqual(samples.first, start)
        XCTAssertEqual(samples.last, end)
        for point in samples {
          XCTAssertTrue(point.x.isFinite && point.y.isFinite)
          XCTAssertLessThanOrEqual(point.lengthSquared, 1 + 1e-12)
        }
        XCTAssertTrue(zip(samples, samples.dropFirst()).allSatisfy { $0 != $1 })
      }
    }
  }
  func testCircleEquationAndDiameterArePreserved() {
    let start = Rational(0, 1).diskPoint, end = Rational(1, 1).diskPoint
    for point in Geometry.geodesic(start, end) {
      XCTAssertEqual(pow(point.x - 1, 2) + pow(point.y + 1, 2), 1, accuracy: 1e-12)
    }
    for point in Geometry.geodesic(Point2(0, -1), Point2(0, 1)) {
      XCTAssertEqual(point.x, 0)
      XCTAssertTrue(point.y >= -1 && point.y <= 1)
    }
  }
}
