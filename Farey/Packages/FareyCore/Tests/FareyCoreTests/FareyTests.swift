import XCTest

@testable import FareyCore

final class FareyTests: XCTestCase {
  func testExactConventionAndUndo() {
    var s = FareyState()
    XCTAssertEqual(s.mediant, Rational(1, 1))
    s.step(.l)
    XCTAssertEqual(s.left, Rational(1, 1))
    XCTAssertEqual(s.mediant, Rational(2, 1))
    s.step(.r)
    XCTAssertEqual(s.right, Rational(2, 1))
    XCTAssertEqual(s.mediant, Rational(3, 2))
    s.undo()
    XCTAssertEqual(s.wordLabel, "L")
    XCTAssertEqual(s.mediant, Rational(2, 1))
    s.reset()
    XCTAssertEqual(s, FareyState())
  }
  func testEveryWordThroughDepth12IsUnimodularAndReduced() {
    func visit(_ s: FareyState, _ depth: Int) {
      XCTAssertEqual(s.determinant, 1)
      XCTAssertEqual(gcd(s.mediant.p, s.mediant.q), 1)
      XCTAssertGreaterThan(s.mediant.q, 0)
      if depth < 12 {
        for turn: Turn in [.l, .r] {
          var next = s
          next.step(turn)
          visit(next, depth + 1)
        }
      }
    }
    visit(FareyState(), 0)
  }
  func testBoundsAndRepeatedReset() {
    var s = FareyState()
    for i in 0..<100 { s.step(i % 2 == 0 ? .l : .r) }
    XCTAssertEqual(s.word.count, 24)
    XCTAssertFalse(s.canStep)
    XCTAssertEqual(s.determinant, 1)
    for _ in 0..<30 { s.undo() }
    XCTAssertEqual(s, FareyState())
    for _ in 0..<10 {
      s.step(.r)
      s.reset()
      XCTAssertEqual(s, FareyState())
    }
  }
  func testTessellationBudgetAndHyperbolicArcs() {
    for depth in 3...8 {
      let edges = Geometry.tessellation(depth: depth)
      XCTAssertEqual(edges.count, (1 << (depth + 2)) - 3)
      for edge in edges {
        XCTAssertEqual(abs(edge.determinant), 1)
        for p in edge.samples {
          XCTAssertTrue(p.x.isFinite && p.y.isFinite)
          XCTAssertLessThanOrEqual(p.lengthSquared, 1.000001)
        }
        XCTAssertEqual(edge.samples.first, edge.left.diskPoint)
        XCTAssertEqual(edge.samples.last, edge.right.diskPoint)
      }
    }
    XCTAssertEqual(Geometry.tessellation(depth: 99).count, 1021)
  }
  func testKnownCircularGeodesic() {
    let zero = Rational(0, 1).diskPoint
    let one = Rational(1, 1).diskPoint
    for point in Geometry.geodesic(zero, one) {
      let radiusSquared = (point.x - 1) * (point.x - 1) + (point.y + 1) * (point.y + 1)
      XCTAssertEqual(radiusSquared, 1, accuracy: 1e-12)
    }
    let midpoint = Geometry.geodesic(zero, one)[16]
    XCTAssertEqual(midpoint.x, 1 - 1 / sqrt(2), accuracy: 1e-12)
    XCTAssertEqual(midpoint.y, -1 + 1 / sqrt(2), accuracy: 1e-12)
  }

  private func gcd(_ a: Int64, _ b: Int64) -> Int64 {
    var x = abs(a)
    var y = abs(b)
    while y != 0 { (x, y) = (y, x % y) }
    return x
  }
}
