// SPDX-License-Identifier: GPL-3.0-or-later
import XCTest

@testable import FareyCore

final class CoefficientBallTests: XCTestCase {
  // Counts from the browser's WebXR/lattice.js and starscape-core.js kind(), computed 2026-10-23.
  func testBallMatchesTheBrowserCountsAndCategories() {
    // radius: [count, upper, lower, null, exterior]
    let expected: [Int: [Int]] = [
      1: [2, 0, 0, 0, 2], 4: [128, 14, 14, 12, 88], 6: [480, 55, 55, 24, 346],
      8: [1060, 134, 134, 36, 756], 10: [2100, 275, 275, 48, 1502], 12: [3608, 484, 484, 56, 2584],
    ]
    for (radius, counts) in expected {
      let want = (count: counts[0], upper: counts[1], lower: counts[2], null: counts[3], exterior: counts[4])
      let points = CoefficientBall.points(radius: radius)
      XCTAssertEqual(points.count, want.count, "R\(radius)")
      XCTAssertEqual(Set(points).count, points.count, "duplicates at R\(radius)")
      let kinds = points.compactMap(\.kind)
      XCTAssertEqual(kinds.count, points.count, "zero included at R\(radius)")
      XCTAssertEqual(kinds.filter { $0 == .upper }.count, want.upper)
      XCTAssertEqual(kinds.filter { $0 == .lower }.count, want.lower)
      XCTAssertEqual(kinds.filter { $0 == .null }.count, want.null)
      XCTAssertEqual(kinds.filter { $0 == .exterior }.count, want.exterior)
      XCTAssertEqual(CoefficientBall.points(radius: radius, upperOnly: true).count, want.upper)
    }
    XCTAssertTrue(CoefficientBall.points(radius: 13).isEmpty)
    XCTAssertTrue(CoefficientBall.points(radius: 0).isEmpty)
  }
  func testMembershipIsExactlyTheDisplayBall() {
    for radius in [4, 6, 12] {
      var brute = Set<CoefficientPoint>()
      for a in -radius...radius { for b in -radius...radius { for c in -radius...radius {
        let point = CoefficientPoint(a, b, c), v = point.vector
        if !point.isZero, v.x * v.x + v.y * v.y + v.z * v.z <= Double(radius * radius) { brute.insert(point) }
        XCTAssertEqual(CoefficientBall.contains(point, radius: radius), brute.contains(point))
      } } }
      XCTAssertEqual(Set(CoefficientBall.points(radius: radius)), brute)
    }
    XCTAssertFalse(CoefficientBall.contains(CoefficientPoint(Int.max, 0, 0), radius: 12))
    XCTAssertFalse(CoefficientBall.contains(CoefficientPoint(Int.min, Int.min, Int.min), radius: 12))
    for radius in [Int.max, Int.min, 0, -6, 13] {
      XCTAssertFalse(CoefficientBall.contains(CoefficientPoint(1, 0, 1), radius: radius))
      XCTAssertEqual(CoefficientEntry.parse("1,0,1", radius: radius), .failure(.outsideBall(radius: radius)))
    }
    // (2,-2,4) is in the browser's Next sequence but outside R6 (X²+Y²+Z² = 44); it appears at R8.
    XCTAssertFalse(CoefficientBall.contains(CoefficientPoint(2, -2, 4), radius: 6))
    XCTAssertTrue(CoefficientBall.contains(CoefficientPoint(2, -2, 4), radius: 8))
  }
  func testSignedFormsShareRootsAndOnlyInteriorFormsProject() throws {
    let upper = CoefficientPoint(1, -1, 2), lower = CoefficientPoint(-1, 1, -2)
    XCTAssertEqual(lower.kind, .lower)
    XCTAssertEqual(lower.positiveRepresentative, upper)
    XCTAssertEqual(lower.radialImage(height: 4), upper.projected(height: 4))
    XCTAssertEqual(lower.representativeRoot, upper.upperRoot)
    XCTAssertNil(lower.upperRoot)
    let image = try XCTUnwrap(lower.radialImage(height: 4))
    XCTAssertEqual(image.y, 4)
    for point in [CoefficientPoint(1, 2, 1), CoefficientPoint(0, 0, 1), CoefficientPoint(1, 3, 1), CoefficientPoint(0, 0, 0)] {
      XCTAssertNil(point.radialImage(height: 4)); XCTAssertNil(point.representativeRoot)
    }
    XCTAssertNil(CoefficientPoint(0, 0, 0).kind)
    XCTAssertEqual(CoefficientPoint(0, 0, 1).kind, .null)
    XCTAssertEqual(CoefficientPoint(1, 0, -1).kind, .exterior)
  }
  struct Fixture {
    let point: CoefficientPoint
    let colorLower: Bool
    let factor: Double
    let rgb: SIMD3<Double>
  }
  // From the browser's WebXR/appearance.js coefficientColor(point, colorLower, 'viridis') and orbitFactor.
  static let browserFixtures: [Fixture] = [
    Fixture(
      point: CoefficientPoint(1, -1, 2), colorLower: false, factor: 1,
      rgb: [0.18153208787898883, 0.42787075528626517, 0.55719207975636376]),
    Fixture(
      point: CoefficientPoint(1, -1, 2), colorLower: true, factor: 1,
      rgb: [0.18153208787898883, 0.42787075528626517, 0.55719207975636376]),
    Fixture(
      point: CoefficientPoint(2, -2, 4), colorLower: false, factor: 0.72,
      rgb: [0.14015892453995282, 0.66579483100508874, 0.51346514203634319]),
    Fixture(
      point: CoefficientPoint(2, -2, 4), colorLower: true, factor: 0.72,
      rgb: [0.14015892453995282, 0.66579483100508874, 0.51346514203634319]),
    Fixture(
      point: CoefficientPoint(1, 1, 1), colorLower: false, factor: 1,
      rgb: [0.25393500000000002, 0.26525399999999999, 0.52998299999999998]),
    Fixture(
      point: CoefficientPoint(1, 1, 1), colorLower: true, factor: 1,
      rgb: [0.25393500000000002, 0.26525399999999999, 0.52998299999999998]),
    Fixture(
      point: CoefficientPoint(1, 0, 1), colorLower: false, factor: 1,
      rgb: [0.22897835129670854, 0.32402327463140568, 0.54603036542535821]),
    Fixture(
      point: CoefficientPoint(1, 0, 1), colorLower: true, factor: 1,
      rgb: [0.22897835129670854, 0.32402327463140568, 0.54603036542535821]),
    Fixture(
      point: CoefficientPoint(3, 2, 2), colorLower: false, factor: 1,
      rgb: [0.11948368482686972, 0.60863383024269646, 0.53982476905630328]),
    Fixture(
      point: CoefficientPoint(3, 2, 2), colorLower: true, factor: 1,
      rgb: [0.11948368482686972, 0.60863383024269646, 0.53982476905630328]),
    Fixture(
      point: CoefficientPoint(12, 0, 12), colorLower: false, factor: 0.72,
      rgb: [0.99324800000000002, 0.90615699999999999, 0.14393600000000001]),
    Fixture(
      point: CoefficientPoint(12, 0, 12), colorLower: true, factor: 0.72,
      rgb: [0.99324800000000002, 0.90615699999999999, 0.14393600000000001]),
    Fixture(
      point: CoefficientPoint(2, 1, 1), colorLower: false, factor: 1,
      rgb: [0.18153208787898883, 0.42787075528626517, 0.55719207975636376]),
    Fixture(
      point: CoefficientPoint(2, 1, 1), colorLower: true, factor: 1,
      rgb: [0.18153208787898883, 0.42787075528626517, 0.55719207975636376]),
    Fixture(
      point: CoefficientPoint(-1, 1, -2), colorLower: false, factor: 1,
      rgb: [0.30196078431372547, 0.22745098039215686, 0.27450980392156865]),
    Fixture(
      point: CoefficientPoint(-1, 1, -2), colorLower: true, factor: 1,
      rgb: [0.18153208787898883, 0.42787075528626517, 0.55719207975636376]),
    Fixture(
      point: CoefficientPoint(-2, 2, -4), colorLower: false, factor: 1,
      rgb: [0.30196078431372547, 0.22745098039215686, 0.27450980392156865]),
    Fixture(
      point: CoefficientPoint(-2, 2, -4), colorLower: true, factor: 0.72,
      rgb: [0.14015892453995282, 0.66579483100508874, 0.51346514203634319]),
    Fixture(
      point: CoefficientPoint(1, 2, 1), colorLower: false, factor: 1,
      rgb: [0.95686274509803926, 0.94901960784313721, 1.0000000000000000]),
    Fixture(
      point: CoefficientPoint(1, 2, 1), colorLower: true, factor: 1,
      rgb: [0.95686274509803926, 0.94901960784313721, 1.0000000000000000]),
    Fixture(
      point: CoefficientPoint(0, 0, 1), colorLower: false, factor: 1,
      rgb: [0.95686274509803926, 0.94901960784313721, 1.0000000000000000]),
    Fixture(
      point: CoefficientPoint(0, 0, 1), colorLower: true, factor: 1,
      rgb: [0.95686274509803926, 0.94901960784313721, 1.0000000000000000]),
    Fixture(
      point: CoefficientPoint(1, 3, 1), colorLower: false, factor: 1,
      rgb: [0.47843137254901963, 0.32156862745098042, 0.18823529411764706]),
    Fixture(
      point: CoefficientPoint(1, 3, 1), colorLower: true, factor: 1,
      rgb: [0.47843137254901963, 0.32156862745098042, 0.18823529411764706]),
    Fixture(
      point: CoefficientPoint(1, 0, -1), colorLower: false, factor: 1,
      rgb: [0.47843137254901963, 0.32156862745098042, 0.18823529411764706]),
    Fixture(
      point: CoefficientPoint(1, 0, -1), colorLower: true, factor: 1,
      rgb: [0.47843137254901963, 0.32156862745098042, 0.18823529411764706]),
  ]
  func testColorsAndSizeFactorsMatchTheBrowser() throws {
    for fixture in Self.browserFixtures {
      let color = try XCTUnwrap(CoefficientPalette.color(for: fixture.point, colorLower: fixture.colorLower))
      for i in 0..<3 { XCTAssertEqual(color[i], fixture.rgb[i], accuracy: 1e-12, "\(fixture.point.label)") }
      XCTAssertEqual(CoefficientPalette.radiusFactor(for: fixture.point, colorLower: fixture.colorLower), fixture.factor)
    }
    XCTAssertNil(CoefficientPalette.color(for: CoefficientPoint(0, 0, 0)))
    XCTAssertEqual(Viridis.table.count, 256)
  }
  func testOriginSizesFollowTheBrowserRule() {
    XCTAssertEqual(CoefficientPalette.originRadiusFactor(for: CoefficientPoint(1, 0, 1)), 0.4, accuracy: 1e-12)  // x²+1
    let d7 = 0.4 * pow(7.0, 0.25) / 3.0.squareRoot()
    XCTAssertEqual(CoefficientPalette.originRadiusFactor(for: CoefficientPoint(1, -1, 2)), d7, accuracy: 1e-12)
    // A multiple and a sign partner: |Δ| scales by k², |a+c| by k, so the factor is unchanged (the point is k
    // times farther, hence 1/k = 1/√(|Δ| ratio) the apparent size); the sign partner is the same size.
    XCTAssertEqual(CoefficientPalette.originRadiusFactor(for: CoefficientPoint(2, -2, 4)), d7, accuracy: 1e-12)
    XCTAssertEqual(CoefficientPalette.originRadiusFactor(for: CoefficientPoint(-1, 1, -2)), d7, accuracy: 1e-12)
    for point in [CoefficientPoint(1, 2, 1), CoefficientPoint(1, 3, 1), CoefficientPoint(0, 1, 0)] {
      XCTAssertEqual(CoefficientPalette.originRadiusFactor(for: point), 1)
    }
  }
  func testGuideOpacityReproducesTheBrowserBlendOverBlack() {
    for (alpha, color) in [
      (0.018, CoefficientPalette.guideCyan), (0.26, CoefficientPalette.guideLine), (0.1, CoefficientPalette.guideCyan),
    ] {
      let native = CoefficientPalette.linearLightOpacity(alpha, color: color)
      XCTAssertLessThan(native, alpha)
      // Linear-light blend over black, re-encoded, equals the browser's sRGB product on the brightest channel.
      let c = max(color.x, color.y, color.z)
      let linear = native * CoefficientPalette.linear(c)
      let encoded = linear <= 0.0031308 ? linear * 12.92 : 1.055 * pow(linear, 1 / 2.4) - 0.055
      XCTAssertEqual(encoded, alpha * c, accuracy: 1e-12)
    }
    XCTAssertEqual(CoefficientPalette.linearLightOpacity(1, color: CoefficientPalette.guideLine), 1, accuracy: 1e-12)
  }
  func testEntryAcceptsExactSignedTriplesAndRejectsEverythingElse() {
    XCTAssertEqual(try CoefficientEntry.parse(" -1, 1 ,-2", radius: 6).get(), CoefficientPoint(-1, 1, -2))
    XCTAssertEqual(try CoefficientEntry.parse("+1,0,1", radius: 6).get(), CoefficientPoint(1, 0, 1))
    XCTAssertEqual(try CoefficientEntry.parse("1, -1, 2\n", radius: 6).get(), CoefficientPoint(1, -1, 2))
    XCTAssertEqual(try CoefficientEntry.parse("\t1,0,1\r\n", radius: 6).get(), CoefficientPoint(1, 0, 1))
    let cases: [(String, CoefficientEntryError)] = [
      ("", .format), ("1,2", .format), ("1,2,3,4", .format), ("1.5,0,1", .format), ("a,b,c", .format),
      ("1,,1", .format), ("--1,0,1", .format), ("１,0,1", .format), ("0,0,0", .zero), ("-0,+0,0", .zero),
      ("5,0,0", .outsideBall(radius: 6)), ("4,1,2", .outsideBall(radius: 6)),
      ("99999999999999999999,0,1", .notInteger), ("1,0,-9223372036854775809", .notInteger),
      ("9223372036854775807,0,0", .outsideBall(radius: 6)),
    ]
    for (text, error) in cases {
      XCTAssertEqual(CoefficientEntry.parse(text, radius: 6), .failure(error), text)
    }
    XCTAssertEqual(try CoefficientEntry.parse("4,1,2", radius: 12).get(), CoefficientPoint(4, 1, 2))
  }
}
