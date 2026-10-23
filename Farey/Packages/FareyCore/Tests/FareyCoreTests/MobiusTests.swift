// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import simd
import XCTest

@testable import FareyCore

private struct FixtureImage: Decodable { let id: String; let image: [Int] }
private struct FixtureGenerator: Decodable {
  let name: String
  let g: [Int]
  let pushforwardRows: [Double]
  let images: [FixtureImage]
}
private struct FixtureDragStep: Decodable {
  let z0, z1: [String: Double]
  let gApprox: [Double]
}
private struct FixtureNamedPoint: Decodable { let id: String; let abc: [Int] }
private struct FixtureMobius: Decodable { let generators: [FixtureGenerator]; let dragStep: FixtureDragStep }
private struct MobiusFixtures: Decodable {
  let mobius: FixtureMobius
  let points: [FixtureNamedPoint]
}

final class MobiusTests: XCTestCase {
  private func fixtures() throws -> MobiusFixtures {
    var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    for _ in 0..<6 {
      let candidate = directory.appendingPathComponent("parity/fixtures.json")
      if FileManager.default.fileExists(atPath: candidate.path) {
        return try JSONDecoder().decode(MobiusFixtures.self, from: Data(contentsOf: candidate))
      }
      directory.deleteLastPathComponent()
    }
    throw XCTSkip("parity/fixtures.json is not above this test file")
  }
  private func point(_ abc: [Int]) -> CoefficientPoint { CoefficientPoint(abc[0], abc[1], abc[2]) }
  private let samples: [SIMD2<Double>] = [[0, 1], [1, 2], [-0.3, 0.05], [4, 7], [-2.5, 0.4]]

  func testSharedFixturesGeneratorsAndDragStep() throws {
    let fixtures = try fixtures()
    let abcOf = Dictionary(uniqueKeysWithValues: fixtures.points.map { ($0.id, $0.abc) })
    for generator in fixtures.mobius.generators {
      let g = try XCTUnwrap(Mobius(Double(generator.g[0]), Double(generator.g[1]), Double(generator.g[2]), Double(generator.g[3])))
      XCTAssertEqual(g.pushforward.map { $0 + 0 }, generator.pushforwardRows, generator.name)
      let integral = try XCTUnwrap(g.integral, generator.name)
      for image in generator.images {
        let base = point(try XCTUnwrap(abcOf[image.id]))
        XCTAssertEqual(try integral.image(of: base), point(image.image), "\(generator.name) \(image.id)")
      }
    }
    let step = fixtures.mobius.dragStep
    let g = try XCTUnwrap(Mobius.transvection(from: [step.z0["x"]!, step.z0["y"]!], to: [step.z1["x"]!, step.z1["y"]!]))
    for (x, y) in zip(g.entries, step.gApprox) { XCTAssertEqual(x, y, accuracy: 1e-12) }
  }
  func testTransvectionCarriesZ0ToZ1AndDragStepsFollowThePointer() throws {
    for z0 in samples {
      for z1 in samples {
        let g = try XCTUnwrap(Mobius.transvection(from: z0, to: z1))
        XCTAssertEqual(g.p * g.s - g.q * g.r, 1, accuracy: 1e-12)
        XCTAssertEqual(simd_distance(g.act(z0), z1), 0, accuracy: 1e-9 * max(1, simd_length(z1)))
      }
    }
    var g = Mobius.identity
    let w = SIMD2<Double>(0.3, 1.7)
    var z = g.act(w)
    for target in [SIMD2<Double>(0.5, 1.5), [2, 0.8], [-1, 3]] {
      g = try XCTUnwrap(g.dragged(from: z, to: target))
      z = target
      XCTAssertEqual(simd_distance(g.act(w), target), 0, accuracy: 1e-9)
    }
    XCTAssertNil(Mobius.transvection(from: [0, 1], to: [0, 0]))
    XCTAssertNil(Mobius.transvection(from: [0, 1], to: [.nan, 1]))
  }
  func testPushforwardKeepsDeltaAndMovesRootsByG() throws {
    let g = try XCTUnwrap(Mobius.transvection(from: [0, 1], to: [1.3, 0.6]))
    for base in [CoefficientPoint(1, -1, 2), CoefficientPoint(1, 0, 1), CoefficientPoint(13, 20, 34), CoefficientPoint(2, 1, 1)] {
      let v = g.image(of: base), delta = v.y * v.y - 4 * v.x * v.z
      XCTAssertEqual(delta, Double(base.discriminant), accuracy: 1e-8 * Double(abs(base.discriminant)))
      let root = try XCTUnwrap(base.upperRoot), moved = g.act([root.x, root.y])
      let d = g.displayVector(of: base), viewRoot = try XCTUnwrap(kleinToUpper(d.x / d.y, d.z / d.y))
      XCTAssertEqual(simd_distance(viewRoot, moved), 0, accuracy: 1e-9)
    }
    // The user's seed (13,20,34): exact math only; native's R12 crop excludes it.
    XCTAssertEqual(CoefficientPoint(13, 20, 34).discriminant, -1368)
    XCTAssertFalse(CoefficientBall.contains(CoefficientPoint(13, 20, 34), radius: CoefficientBall.maximumRadius))
  }
  func testSnapFindsTheNearestIntegerMatrix() throws {
    XCTAssertEqual(Mobius.identity.nearestIntegral, .identity)
    let small = try XCTUnwrap(Mobius.transvection(from: [0, 1], to: [0.1, 1.05]))
    XCTAssertEqual(small.nearestIntegral, .identity)
    let nearT = try XCTUnwrap(try XCTUnwrap(Mobius.transvection(from: [0, 1], to: [0.05, 1.1])) * .t)
    let snapped = nearT.nearestIntegral
    XCTAssertEqual(snapped.asMobius.act(SIMD2(0, 1)), Mobius.t.act(SIMD2(0, 1)))
    XCTAssertNil(try XCTUnwrap(Mobius.transvection(from: [0, 1], to: [1, 1])).integral)
    XCTAssertEqual(Mobius.t.integral, IntegralMobius(p: 1, q: 1, r: 0, s: 1))
  }
  /// Her viewer's polar criterion, not entrywise distance: one drag from −0.4 + 0.1i to −0.4 + i snaps to T⁴, so
  /// (13,20,34) is absorbed as (13,−84,162).
  func testSnapUsesThePolarRotationCriterion() throws {
    let g = try XCTUnwrap(Mobius.transvection(from: [-0.4, 0.1], to: [-0.4, 1]))
    XCTAssertEqual(g.p, 10.0.squareRoot(), accuracy: 1e-12)
    XCTAssertEqual(g.nearestIntegral, IntegralMobius(p: 1, q: 4, r: 0, s: 1))
    // The g recorded from her viewer for that drag (reading 'nearest γ [1,4;0,1]').
    let recorded = try XCTUnwrap(Mobius(3.162278103784889, 1.1384199665329495, 4.0371747379733554e-16, 0.31622772165519336))
    XCTAssertEqual(recorded.nearestIntegral, IntegralMobius(p: 1, q: 4, r: 0, s: 1))
    XCTAssertEqual(try g.nearestIntegral.image(of: CoefficientPoint(13, 20, 34)), CoefficientPoint(13, -84, 162))
    XCTAssertEqual(Mobius.identity.polarAngle, 0)
    XCTAssertEqual(abs(Mobius.sGenerator.polarAngle), .pi / 2, accuracy: 1e-12)
  }
  func testInvalidAndOutOfDomainInputsAreRefused() throws {
    XCTAssertNil(Mobius(1, 0, 0, -1))
    XCTAssertNil(Mobius(.nan, 0, 0, 1))
    XCTAssertNil(Mobius(.infinity, 0, 0, 1))
    XCTAssertEqual(try XCTUnwrap(Mobius(2, 0, 0, 2)), .identity)
    let big = IntegralMobius(p: 1, q: 1 << 19, r: 0, s: 1)
    XCTAssertThrowsError(try big.image(of: CoefficientPoint(4, 0, 4))) { XCTAssertEqual($0 as? MobiusError, .outOfExactDomain) }
    XCTAssertThrowsError(try IntegralMobius.identity.image(of: CoefficientPoint(Int.min, 0, 1)))
    XCTAssertEqual(try IntegralMobius(p: 1, q: 1, r: 0, s: 1).image(of: CoefficientPoint(1, 0, 1)), CoefficientPoint(1, -2, 2))
  }
}
