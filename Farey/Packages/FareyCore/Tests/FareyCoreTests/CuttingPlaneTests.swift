// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest

@testable import FareyCore

/// Fixtures shared with the browser's pair-plane.test.js, plus the native reference's edge cases.
final class CuttingPlaneTests: XCTestCase {
  private func plane(_ first: CoefficientPoint, _ second: CoefficientPoint) throws -> CuttingPlane {
    try CuttingPlane.pair(first, second).get()
  }
  func testAuditedPairAndItsTranslateHaveExactPlanesAndEndpoints() throws {
    let p = try plane(CoefficientPoint(1, 0, 1), CoefficientPoint(1, 1, 1))
    XCTAssertEqual(p.normal, CoefficientPoint(1, 0, -1))
    XCTAssertEqual(p.equation, "2a −2c = 0")
    XCTAssertEqual(p.endpoints.map(\.label), ["-1", "1"])
    let moved = try plane(CoefficientPoint(1, -2, 2), CoefficientPoint(1, -1, 1))
    XCTAssertEqual(moved.normal, CoefficientPoint(1, -2, 0))
    XCTAssertEqual(moved.endpoints.map(\.label), ["0", "2"])
  }
  func testMultiplesSignsAndOrderPreserveAPairAndOneDirectionIsRejected() throws {
    let p = try plane(CoefficientPoint(1, 0, 1), CoefficientPoint(1, 1, 1))
    for q in [
      try plane(CoefficientPoint(2, 0, 2), CoefficientPoint(-3, -3, -3)),
      try plane(CoefficientPoint(1, 1, 1), CoefficientPoint(1, 0, 1)),
    ] { XCTAssertEqual(q, p) }
    // Collinear: the same point, a multiple, and a sign partner.
    for q in [CoefficientPoint(1, 0, 1), CoefficientPoint(3, 0, 3), CoefficientPoint(-2, 0, -2)] {
      XCTAssertEqual(CuttingPlane.pair(CoefficientPoint(1, 0, 1), q), .failure(.sameDirection))
    }
    XCTAssertEqual(CuttingPlane.pair(CoefficientPoint(1, 0, 1), CoefficientPoint(1, 2, 1)), .failure(.notInterior))
    XCTAssertEqual(CuttingPlane.pair(CoefficientPoint(1, 0, -1), CoefficientPoint(1, 0, 1)), .failure(.notInterior))
    XCTAssertEqual(CuttingPlane.pair(CoefficientPoint(1, 0, 1), CoefficientPoint(Int.max, 0, 1)), .failure(.tooLarge))
  }
  func testInfinityAndNonsquareEndpointsStayExact() throws {
    let vertical = try plane(CoefficientPoint(1, 0, 1), CoefficientPoint(1, 0, 4))
    XCTAssertEqual(vertical.endpoints, [.rational(p: 0, q: 1), .infinity])
    XCTAssertEqual(vertical.endpoints.map(\.label), ["0", "∞"])
    let q = try plane(CoefficientPoint(1, 0, 1), CoefficientPoint(2, 1, 1))
    XCTAssertEqual(q.normal, CoefficientPoint(1, -2, -1))
    XCTAssertEqual(q.endpoints.map(\.label), ["1 − √2", "1 + √2"])
    XCTAssertEqual(q.endpoints[1].value, 1 + 2.0.squareRoot(), accuracy: 1e-12)
  }
  func testAnExteriorTripleIsItsOwnLorentzNormal() throws {
    let plane = try CuttingPlane.fromNormal(CoefficientPoint(1, 8, -1)).get()
    XCTAssertEqual(plane.normal, CoefficientPoint(1, 8, -1))
    XCTAssertEqual(plane.equation, "2a +8b −2c = 0")
    XCTAssertEqual(plane.endpoints.map(\.label), ["−4 − √17", "−4 + √17"])
    XCTAssertEqual(plane.endpoints[1].value, -4 + 17.0.squareRoot(), accuracy: 1e-12)
    XCTAssertEqual(try CuttingPlane.fromNormal(CoefficientPoint(-2, -16, 2)).get().normal, CoefficientPoint(1, 8, -1))
    XCTAssertEqual(CuttingPlane.fromNormal(CoefficientPoint(1, 2, 1)), .failure(.notExterior))  // null: tangent
    XCTAssertEqual(CuttingPlane.fromNormal(CoefficientPoint(1, 0, 1)), .failure(.notExterior))  // interior
    XCTAssertEqual(CuttingPlane.fromNormal(CoefficientPoint(0, 0, 0)), .failure(.zero))
    XCTAssertEqual(try CuttingPlane.fromNormal(CoefficientPoint(2, 0, -6)).get().endpoints.map(\.label), ["−√3", "√3"])
    XCTAssertEqual(
      try CuttingPlane.fromNormal(CoefficientPoint(2, 2, -1)).get().endpoints.map(\.label),
      ["(−1 − √3)/2", "(−1 + √3)/2"])
    // The reference's cases: (1,0,−2) has endpoints ±√2, (0,1,0) is b = 0 with endpoints 0 and ∞.
    XCTAssertEqual(try CuttingPlane.fromNormal(CoefficientPoint(1, 0, -2)).get().endpoints.map(\.label), ["−√2", "√2"])
    let b0 = try CuttingPlane.fromNormal(CoefficientPoint(0, 1, 0)).get()
    XCTAssertEqual(b0.equation, "b = 0")
    XCTAssertEqual(b0.endpoints.map(\.label), ["0", "∞"])
    XCTAssertEqual(CuttingPlane.fromNormal(CoefficientPoint(0, 0, 1)), .failure(.notExterior))  // Δ = 0: tangent at ∞
  }
  func testSampledPairsContainBothPointsAndTheirDrawnPatchLiesInThePlane() throws {
    let interior = CoefficientBall.points(radius: 8).filter { $0.kind == .upper || $0.kind == .lower }
    var checked = 0
    for i in stride(from: 0, to: interior.count, by: 7) {
      for j in stride(from: i + 1, to: interior.count, by: 19) {
        guard case .success(let plane) = CuttingPlane.pair(interior[i], interior[j]) else { continue }
        checked += 1
        XCTAssertGreaterThan(plane.normal.discriminant, 0)
        XCTAssertTrue(plane.contains(interior[i]) && plane.contains(interior[j]))
        let (na, nb, nc) = (Double(plane.normal.a), Double(plane.normal.b), Double(plane.normal.c))
        for d in plane.coneDirections + plane.section(radius: 8) {
          XCTAssertEqual(-nb * d.x - (na + nc) * d.y + (nc - na) * d.z, 0, accuracy: 1e-9)
          XCTAssertLessThanOrEqual(abs(d.y), 8 + 1e-9)
          XCTAssertLessThanOrEqual((d.x * d.x + d.z * d.z).squareRoot(), 8 + 1e-9)
        }
        for d in plane.coneDirections { XCTAssertEqual(d.x * d.x + d.z * d.z - d.y * d.y, 0, accuracy: 1e-12) }
      }
    }
    XCTAssertGreaterThan(checked, 200)  // 292 with the browser's strides at R8
  }
  func testMembershipIsExact() throws {
    let plane = try plane(CoefficientPoint(1, 0, 1), CoefficientPoint(1, 1, 1))
    let candidates = [(1, 0, 1), (2, 2, 2), (-1, 0, -1), (1, 3, 1), (1, 2, 1), (1, 0, 2)].map { CoefficientPoint($0.0, $0.1, $0.2) }
    XCTAssertEqual(candidates.filter(plane.contains), candidates.prefix(5).map { $0 })
    // Interior members only, as the necklace highlights: (1,3,1) is exterior and (1,2,1) null.
    XCTAssertEqual(
      candidates.filter { plane.contains($0) && $0.discriminant < 0 },
      [CoefficientPoint(1, 0, 1), CoefficientPoint(2, 2, 2), CoefficientPoint(-1, 0, -1)])
  }
  /// Defensive boundaries of the public helpers (the drawn UI only reaches R ≤ 12): refused or false, never trapped.
  func testExtremeInputsAreRefusedNotTrapped() throws {
    XCTAssertEqual(CuttingPlane.fromNormal(CoefficientPoint(Int.min, 0, 0)), .failure(.notExterior))  // reduces to (1,0,0)
    XCTAssertEqual(CuttingPlane.fromNormal(CoefficientPoint(Int.min, 1, 0)), .failure(.tooLarge))
    XCTAssertEqual(CuttingPlane.fromNormal(CoefficientPoint(Int.max, 0, 0)), .failure(.notExterior))
    // A legitimately scaled normal still reduces exactly.
    XCTAssertEqual(try CuttingPlane.fromNormal(CoefficientPoint(1 << 40, 0, -(1 << 40))).get().normal, CoefficientPoint(1, 0, -1))
    XCTAssertEqual(CuttingPlane.pair(CoefficientPoint(Int.min, 0, 1), CoefficientPoint(1, 0, 1)), .failure(.tooLarge))
    XCTAssertEqual(CuttingPlane.pair(CoefficientPoint(1, 0, 1), CoefficientPoint(Int.min, 0, Int.min)), .failure(.tooLarge))
    let plane = try CuttingPlane.fromNormal(CoefficientPoint(1, 0, -1)).get()
    XCTAssertFalse(plane.contains(CoefficientPoint(Int.max, 0, Int.max)))
    XCTAssertFalse(plane.contains(CoefficientPoint(Int.min, 0, Int.min)))
    XCTAssertTrue(plane.contains(CoefficientPoint(1 << 40, 7, 1 << 40)))
    let invalid: [(Double, Int)] = [
      (6, -1), (6, 0), (6, CuttingPlane.maximumSegments + 1), (.nan, 64), (.infinity, 64), (0, 64), (-1, 64),
    ]
    for (radius, segments) in invalid {
      XCTAssertEqual(plane.section(radius: radius, segments: segments), [], "\(radius) \(segments)")
    }
    XCTAssertEqual(plane.section(radius: 6, segments: 1).count, 2)
  }
}
