import XCTest

@testable import FareyVision

/// Direct picking: the Roots window's hover and tap share one picker, and Pair next pairs a pick with the selection.
@MainActor final class RootsPairTests: XCTestCase {
  private let size = CGSize(width: 560, height: 560)
  func testHoverAndTapShareThePickerAndLabelTheBasePolynomial() throws {
    let crop = StarscapeRenderer.Crop()
    let identity = RootsLayout(size: size, group: .identity, crop: crop)
    // (1,0,1), (2,0,2) and (3,0,3) share the root i; the largest, visible star, (1,0,1), is the one picked.
    let atI = try XCTUnwrap(identity.pick(at: identity.screen([0, 1])))
    XCTAssertEqual(atI.point, CoefficientPoint(1, 0, 1))
    XCTAssertNil(identity.pick(at: identity.screen([0, -0.5])))     // below the axis: nothing
    // Under the fixture g, (1,0,1) is drawn at 1 + i; its label stays the base polynomial.
    let moved = RootsLayout(size: size, group: try XCTUnwrap(Mobius(3, 1, 1, 2)), crop: crop)
    let at1i = try XCTUnwrap(moved.pick(at: moved.screen([1, 1])))
    XCTAssertEqual(at1i.point, CoefficientPoint(1, 0, 1))
    XCTAssertEqual(at1i.point.polynomial, "x² + 1")
  }
  func testPairNextPairsAPickAndRejectsBadPicksUnchanged() throws {
    let model = GalleryModel()
    model.select(CoefficientPoint(1, 0, 1))
    model.dragRoots(from: [0, 1], to: [1, 1])                       // a non-integer g, kept throughout
    let g = model.coefficientGroup, placement = model.coefficientPlacement
    model.armPairNext(true)
    // Same direction (a multiple, a sign partner), exterior, outside the ball: refused, still armed, nothing changed.
    for point in [CoefficientPoint(2, 0, 2), CoefficientPoint(-1, 0, -1), CoefficientPoint(1, 3, 1), CoefficientPoint(4, 0, 4)] {
      XCTAssertFalse(model.pairPicked(point), "\(point)")
      XCTAssertNil(model.coefficientSecond)
      XCTAssertEqual(model.coefficient, CoefficientPoint(1, 0, 1))
      XCTAssertTrue(model.pairNext)
      XCTAssertNotNil(model.coefficientPairError)
    }
    model.coefficientUpperOnly = true                               // a lower point is now filtered out
    model.activateCoefficient(CoefficientPoint(-1, -1, -1))
    XCTAssertNil(model.coefficientSecond)
    model.coefficientUpperOnly = false
    model.activateCoefficient(CoefficientPoint(1, 1, 1))            // a valid pick pairs and disarms
    XCTAssertEqual(model.coefficientSecond, CoefficientPoint(1, 1, 1))
    XCTAssertEqual(model.coefficient, CoefficientPoint(1, 0, 1))
    XCTAssertFalse(model.pairNext)
    XCTAssertNil(model.coefficientPairError)
    XCTAssertEqual(model.coefficientGroup.entries, g.entries)
    XCTAssertEqual(model.coefficientPlacement, placement)
    model.activateCoefficient(CoefficientPoint(1, -1, 2))           // unarmed: a pick selects (and drops the pair)
    XCTAssertEqual(model.coefficient, CoefficientPoint(1, -1, 2))
    XCTAssertNil(model.coefficientSecond)
    model.armPairNext(true)
    model.armPairNext(false)                                        // Cancel
    XCTAssertFalse(model.pairNext)
    model.armPairNext(true)
    model.resetStarscape()                                          // Reset disarms
    XCTAssertFalse(model.pairNext)
  }
}
