import RealityKit
import XCTest

@testable import FareyVision

/// The native Möbius view against the exact single-step fixture g = [[3, 1], [1, 2]]/√5 (the transvection i → 1 + i).
@MainActor final class StarscapeMobiusTests: XCTestCase {
  private let g = Mobius(3, 1, 1, 2)!
  private func expect(_ a: SIMD3<Float>, _ b: SIMD3<Double>, scale: Float, accuracy: Float = 1e-5) {
    let target = SIMD3<Float>(Float(b.x), Float(b.y), Float(b.z)) * scale
    XCTAssertEqual(simd_distance(a, target), 0, accuracy: accuracy, "\(a) vs \(target)")
  }
  func testCentersImagesAndInverseFollowG() throws {
    let renderer = StarscapeRenderer()
    let pair = try CuttingPlane.pair(CoefficientPoint(1, 0, 1), CoefficientPoint(1, 1, 1)).get()
    let receipt = try renderer.render(
      selected: CoefficientPoint(1, 0, 1), showProjection: true, viewpoint: 0, cuttingPlane: pair,
      second: CoefficientPoint(1, 1, 1), group: g)
    let scale = renderer.scale
    let dot = try XCTUnwrap(renderer.root.findEntity(named: "coefficient:1:0:1"))
    expect(dot.position, [2, 3, 1], scale: scale)                        // (1,0,1) → (1,−2,2), display (2, 3, 1)
    expect(try XCTUnwrap(renderer.root.findEntity(named: "image:1:0:1")).position, [8.0 / 3, 4, 4.0 / 3], scale: scale)
    expect(try XCTUnwrap(renderer.root.findEntity(named: "image:1:1:1")).position, [6.0 / 5, 4, 8.0 / 5], scale: scale)
    expect(try XCTUnwrap(renderer.root.findEntity(named: "selection-outline")).position, [2, 3, 1], scale: scale)
    XCTAssertTrue(receipt.contains(" · plane 2a −2c = 0 · 22 displayed interior triples"), receipt)  // exact, unchanged
    XCTAssertTrue(receipt.hasSuffix(" · g = [1.34, 0.45, 0.45, 0.89]"), receipt)
    // The moved plane: its patch lies on 2X − 5Y + 11Z = 0, its endpoint rays point at −2 and 4/3.
    let sheet = try XCTUnwrap(renderer.root.findEntity(named: "plane-sheet") as? ModelEntity)
    let vertices = try XCTUnwrap(sheet.model?.mesh.contents.models.first?.parts.first?.positions.elements)
    for v in vertices.dropFirst() {
      let d = v / scale
      XCTAssertEqual(2 * d.x - 5 * d.y + 11 * d.z, 0, accuracy: 2e-3 * simd_length(d))
    }
    XCTAssertEqual(g.act(real: -1), -2, accuracy: 1e-12)
    XCTAssertEqual(g.act(real: 1), 4.0 / 3, accuracy: 1e-12)
    // Back to the identity: every center returns to its base position.
    _ = try renderer.render(selected: CoefficientPoint(1, 0, 1), showProjection: true, viewpoint: 0)
    for point in CoefficientBall.points(radius: 6) {
      let entity = try XCTUnwrap(renderer.root.findEntity(named: "coefficient:\(point.a):\(point.b):\(point.c)"))
      XCTAssertEqual(entity.position, renderer.position(point.vector))
    }
  }
  func testOriginSizesUseTheMovedHeightAndInhabitIsNotMovedByG() throws {
    let renderer = StarscapeRenderer()
    _ = try renderer.render(
      selected: CoefficientPoint(1, 0, 1), showProjection: false, viewpoint: 0, placement: .origin(facingLower: false), group: g)
    // (1,0,1) has Δ = −4 and moved height a′ + c′ = 3.
    XCTAssertEqual(renderer.originFactor(CoefficientPoint(1, 0, 1)), 0.4 * pow(4.0, 0.25) / 3.0.squareRoot(), accuracy: 1e-12)
    let point = CoefficientPoint(1, -1, 2)
    _ = try renderer.render(selected: point, showProjection: false, viewpoint: 0, placement: .inhabit(point), placementEpoch: 1, group: g)
    let address = renderer.root.position
    _ = try renderer.render(selected: point, showProjection: false, viewpoint: 0, placement: .inhabit(point), placementEpoch: 1)
    XCTAssertEqual(renderer.root.position, address)  // changing g did not move the inhabited viewer
  }
  func testModelDragsGeneratorsSnapIdentityAndRefusal() throws {
    let model = GalleryModel()
    model.dragRoots(from: [0, 1], to: [1, 1])
    for (x, y) in zip(model.coefficientGroup.entries, g.entries) { XCTAssertEqual(x, y, accuracy: 1e-12) }
    XCTAssertEqual(model.coefficient, CoefficientPoint(1, -1, 2))     // identities never change under a real g
    model.identityGroup()
    XCTAssertTrue(model.coefficientGroup.isIdentity)
    model.applyGenerator(.t)                                         // integral: absorbed into the selection
    XCTAssertEqual(model.coefficient, CoefficientPoint(1, -3, 4))
    XCTAssertTrue(model.coefficientGroup.isIdentity)
    model.identityGroup()
    XCTAssertEqual(model.coefficient, CoefficientPoint(1, -3, 4))     // Identity does not undo an absorption
    model.coefficientSnap = true
    model.dragRoots(from: [-0.4, 0.1], to: [-0.4, 1])
    model.endRootsDrag()                                             // her recorded case: γ = T⁴
    XCTAssertEqual(model.coefficient, try IntegralMobius(p: 1, q: 4, r: 0, s: 1).image(of: CoefficientPoint(1, -3, 4)))
    let before = model.coefficient, revision = model.revision
    model.absorb(IntegralMobius(p: 1, q: 1 << 19, r: 0, s: 1))       // leaves the exact range: refused
    XCTAssertEqual(model.coefficient, before)
    XCTAssertEqual(model.revision, revision)
    XCTAssertNotNil(model.coefficientGroupError)
    model.resetStarscape()
    XCTAssertEqual(model.coefficient, CoefficientPoint(1, -1, 2))
    XCTAssertTrue(model.coefficientGroup.isIdentity)
    XCTAssertFalse(model.coefficientSnap)
  }
}
