// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import XCTest

@testable import FareyCore

private struct ExactUpperRoot: Decodable { let realNumerator, imaginaryRadicand, denominator: Int }
/// A projective root: infinity, a rational p/q in lowest terms, or (numerator + sign·√radicand)/denominator.
private struct ExactRoot: Decodable {
  let kind: String
  let p, q, numerator, sign, radicand, denominator: Int?
}
private struct FixtureCensus: Decodable { let radius, count, upper, lower, null, exterior: Int }
private struct FixturePoint: Decodable {
  let id: String
  let abc: [Int]
  let kind: String
  let discriminant: Int
  let vector: [Int]
  let primitive: Bool
  let upperRootApprox: [Double]?
  let upperRootExact: ExactUpperRoot?
  let realRoots: [String]?
  let inBall: [String: Bool]
}
private struct FixturePlane: Decodable {
  let id: String
  let first, second, normalInput: [Int]?
  let normal: [Int]
  let equation: String
  let endpoints: [String]
  let endpointsExact: [ExactRoot]
  let interiorTriplesR6, upperR6, lowerR6: Int
}
private struct FixtureRejection: Decodable { let first, second, normalInput: [Int]?; let error: String }
private struct Fixtures: Decodable {
  let census: [FixtureCensus]
  let points: [FixturePoint]
  let planes: [FixturePlane]
  let rejections: [FixtureRejection]
}

/// Native FareyCore against parity/fixtures.json, which parity/generate-fixtures.mjs computes with the browser's own
/// modules: the shared exact contract for browser, native and other implementations.
final class ParityContractTests: XCTestCase {
  private func fixtures() throws -> Fixtures {
    var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    for _ in 0..<6 {
      let candidate = directory.appendingPathComponent("parity/fixtures.json")
      if FileManager.default.fileExists(atPath: candidate.path) {
        return try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: candidate))
      }
      directory.deleteLastPathComponent()
    }
    throw XCTSkip("parity/fixtures.json is not above this test file")
  }
  private func point(_ abc: [Int]) -> CoefficientPoint { CoefficientPoint(abc[0], abc[1], abc[2]) }
  private func kindName(_ kind: CoefficientKind?) -> String {
    switch kind {
    case .upper?: return "upper"
    case .lower?: return "lower"
    case .null?: return "null"
    case .exterior?: return "exterior"
    case nil: return "zero"
    }
  }
  func testCensusMatches() throws {
    for census in try fixtures().census {
      let points = CoefficientBall.points(radius: census.radius)
      XCTAssertEqual(points.count, census.count)
      for (name, count) in [("upper", census.upper), ("lower", census.lower), ("null", census.null), ("exterior", census.exterior)] {
        XCTAssertEqual(points.filter { kindName($0.kind) == name }.count, count, "R\(census.radius) \(name)")
      }
    }
  }
  func testPointsMatch() throws {
    for fixture in try fixtures().points {
      let p = point(fixture.abc)
      XCTAssertEqual(kindName(p.kind), fixture.kind, fixture.id)
      XCTAssertEqual(p.discriminant, fixture.discriminant, fixture.id)
      XCTAssertEqual([p.vector.x, p.vector.y, p.vector.z].map { Int($0) }, fixture.vector, fixture.id)
      XCTAssertEqual(p.isPrimitive, fixture.primitive, fixture.id)
      // Browser-only radii (96) are beyond native's cap, which contains() refuses by design.
      for (radius, inside) in fixture.inBall where (Int(radius) ?? 0) <= CoefficientBall.maximumRadius {
        XCTAssertEqual(CoefficientBall.contains(p, radius: Int(radius) ?? 0), inside, "\(fixture.id) R\(radius)")
      }
      if let exact = fixture.upperRootExact {
        let representative = try XCTUnwrap(p.positiveRepresentative, fixture.id)
        XCTAssertEqual(exact.realNumerator, -representative.b, fixture.id)
        XCTAssertEqual(exact.imaginaryRadicand, -representative.discriminant, fixture.id)
        XCTAssertEqual(exact.denominator, 2 * representative.a, fixture.id)
      }
      if let expected = fixture.upperRootApprox {
        let root = try XCTUnwrap(p.representativeRoot, fixture.id)
        XCTAssertEqual(root.x, expected[0], accuracy: 1e-12, fixture.id)
        XCTAssertEqual(root.y, expected[1], accuracy: 1e-12, fixture.id)
      } else {
        XCTAssertNil(p.representativeRoot, fixture.id)
      }
      if let roots = fixture.realRoots {
        let description = try XCTUnwrap(p.realRootDescription, fixture.id)
        if roots == ["∞", "∞"] {
          XCTAssertTrue(description.contains("no finite root") && description.contains("double root is at ∞"), fixture.id)
        } else if roots[0] == roots[1] {
          XCTAssertTrue(description.hasSuffix("double root x = \(roots[0])"), fixture.id)
        } else if roots[1] == "∞" {
          XCTAssertTrue(description.contains("one finite root x = \(roots[0])") && description.contains("at ∞"), fixture.id)
        } else {
          XCTAssertTrue(description.hasSuffix("two real roots x = \(roots[0]) and \(roots[1])"), fixture.id)
        }
      } else {
        XCTAssertNil(p.realRootDescription, fixture.id)
      }
    }
  }
  func testPlanesAndRejectionsMatch() throws {
    let fixtures = try fixtures()
    let r6 = CoefficientBall.points(radius: 6)
    for fixture in fixtures.planes {
      let result = fixture.normalInput.map { CuttingPlane.fromNormal(point($0)) }
        ?? CuttingPlane.pair(point(fixture.first ?? []), point(fixture.second ?? []))
      let plane = try result.get()
      XCTAssertEqual([plane.normal.a, plane.normal.b, plane.normal.c], fixture.normal, fixture.id)
      XCTAssertEqual(plane.equation, fixture.equation, fixture.id)
      XCTAssertEqual(plane.endpoints.map(\.label), fixture.endpoints, fixture.id)
      for (endpoint, exact) in zip(plane.endpoints, fixture.endpointsExact) {
        switch (endpoint, exact.kind) {
        case (.infinity, "infinity"): break
        case (.rational(let p, let q), "rational"): XCTAssertEqual([p, q], [exact.p, exact.q].compactMap { $0 }, fixture.id)
        case (.surd, "quadratic"):
          let value = (Double(exact.numerator ?? 0) + Double(exact.sign ?? 0) * Double(exact.radicand ?? 0).squareRoot())
            / Double(exact.denominator ?? 1)
          XCTAssertEqual(endpoint.value, value, accuracy: 1e-12, fixture.id)
        default: XCTFail("\(fixture.id): native \(endpoint) versus \(exact.kind)")
        }
      }
      let members = r6.filter { $0.discriminant < 0 && plane.contains($0) }
      XCTAssertEqual(members.count, fixture.interiorTriplesR6, fixture.id)
      XCTAssertEqual(members.filter { $0.a > 0 }.count, fixture.upperR6, fixture.id)
      XCTAssertEqual(members.filter { $0.a < 0 }.count, fixture.lowerR6, fixture.id)
    }
    for rejection in fixtures.rejections {
      let result = rejection.normalInput.map { CuttingPlane.fromNormal(point($0)) }
        ?? CuttingPlane.pair(point(rejection.first ?? []), point(rejection.second ?? []))
      guard case .failure(let error) = result else { return XCTFail("accepted \(rejection)") }
      XCTAssertEqual("\(error)", rejection.error)
    }
  }
}
