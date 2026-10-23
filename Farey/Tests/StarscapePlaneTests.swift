import RealityKit
import XCTest

@testable import FareyVision

@MainActor final class StarscapePlaneTests: XCTestCase {
  private func named(_ prefix: String, in entity: Entity) -> [Entity] {
    (entity.name.hasPrefix(prefix) ? [entity] : []) + entity.children.flatMap { named(prefix, in: $0) }
  }
  func testPairPlaneRingsExactlyTheDisplayedInteriorMembers() throws {
    let renderer = StarscapeRenderer()
    let plane = try CuttingPlane.pair(CoefficientPoint(1, 0, 1), CoefficientPoint(1, 1, 1)).get()
    let receipt = try renderer.render(
      selected: CoefficientPoint(1, 0, 1), showProjection: false, viewpoint: 0, cuttingPlane: plane,
      second: CoefficientPoint(1, 1, 1))
    let expected = Set(CoefficientBall.points(radius: 6).filter { $0.discriminant < 0 && plane.contains($0) })
    let rings = Set(named("plane-member:", in: renderer.root).map(\.name))
    XCTAssertEqual(rings, Set(expected.map { "plane-member:\($0.a):\($0.b):\($0.c)" }))
    XCTAssertTrue(expected.contains(CoefficientPoint(2, 2, 2)) && expected.contains(CoefficientPoint(-1, 0, -1)))
    XCTAssertTrue(receipt.hasSuffix(" · plane 2a −2c = 0 · \(expected.count) displayed interior triples"), receipt)
    XCTAssertEqual(expected.count, 22)  // 11 upper + 11 lower at R6, multiples and sign partners included
    XCTAssertNotNil(renderer.root.findEntity(named: "plane-sheet"))
    XCTAssertNotNil(renderer.root.findEntity(named: "pair-second"))
    let upper = try XCTUnwrap(renderer.root.findEntity(named: "coefficient:1:0:1"))
    XCTAssertEqual(upper.scale.x, 1.35)
    // Without a plane every ring, the sheet and the emphasis go away.
    let cleared = try renderer.render(selected: CoefficientPoint(1, -1, 2), showProjection: false, viewpoint: 0)
    XCTAssertFalse(cleared.contains("plane"))
    XCTAssertTrue(named("plane-member:", in: renderer.root).isEmpty)
    XCTAssertEqual(upper.scale.x, 1)
  }
  func testModelPlanesPairsAndRejectionsKeepState() {
    let model = GalleryModel()
    XCTAssertNil(model.cuttingPlane)
    XCTAssertTrue(model.enterCoefficient("1,3,1"))
    XCTAssertEqual(model.cuttingPlane?.normal, CoefficientPoint(1, 3, 1))  // exterior: its own normal
    XCTAssertTrue(model.enterCoefficient("0,1,0"))
    XCTAssertEqual(model.cuttingPlane?.endpoints.map(\.label), ["0", "∞"])
    XCTAssertTrue(model.enterCoefficient("1,0,1"))
    let revision = model.revision
    for text in ["2,0,2", "-1,0,-1", "1,0,1", "1,2,1", "1,3,1", "0,0,0", "x", "9,0,9"] {
      XCTAssertFalse(model.pairCoefficient(text), text)
      XCTAssertNil(model.coefficientSecond, text)
      XCTAssertEqual(model.coefficient, CoefficientPoint(1, 0, 1), text)
      XCTAssertEqual(model.revision, revision, text)
      XCTAssertNotNil(model.coefficientPairError, text)
    }
    XCTAssertTrue(model.pairCoefficient("1,1,1"))
    XCTAssertEqual(model.cuttingPlane?.equation, "2a −2c = 0")
    XCTAssertEqual(model.coefficient, CoefficientPoint(1, 0, 1))
    model.nextCoefficient()
    XCTAssertNil(model.coefficientSecond)
  }
  func testPlacementAnchorsOnceAndSelectionNeverMovesAnInhabitedViewer() throws {
    let renderer = StarscapeRenderer()
    _ = try renderer.render(selected: CoefficientPoint(1, -1, 2), showProjection: false, viewpoint: 0)
    XCTAssertTrue(renderer.root.parent === renderer.stage)
    XCTAssertEqual(renderer.root.position, StarscapeRenderer.center)
    _ = try renderer.render(
      selected: CoefficientPoint(1, -1, 2), showProjection: false, viewpoint: 0, placement: .origin(facingLower: false))
    let origin = try XCTUnwrap(renderer.headAnchor)
    XCTAssertTrue(renderer.root.parent === origin && origin.parent === renderer.anchorHost)
    XCTAssertEqual(origin.anchoring.trackingMode, .once)
    XCTAssertEqual(renderer.root.position, .zero)
    XCTAssertEqual(simd_distance(renderer.root.orientation.act([0, 1, 0]), [0, 0, -1]), 0, accuracy: 1e-6)
    // Flipping the nappe keeps the same one-time anchor and turns +Y behind (−Y ahead).
    _ = try renderer.render(
      selected: CoefficientPoint(1, -1, 2), showProjection: false, viewpoint: 0, placement: .origin(facingLower: true))
    XCTAssertTrue(renderer.headAnchor === origin)
    XCTAssertEqual(simd_distance(renderer.root.orientation.act([0, 1, 0]), [0, 0, 1]), 0, accuracy: 1e-6)
    let point = CoefficientPoint(1, -1, 2)
    _ = try renderer.render(selected: point, showProjection: false, viewpoint: 0, placement: .inhabit(point))
    let inhabit = try XCTUnwrap(renderer.headAnchor)
    XCTAssertFalse(inhabit === origin)
    XCTAssertNil(origin.parent)
    let address = StarscapeRenderer.inhabitEye - renderer.position(point.vector)
    XCTAssertEqual(renderer.root.position, address)
    for other in [CoefficientPoint(2, 1, 1), CoefficientPoint(1, 3, 1)] {
      let receipt = try renderer.render(selected: other, showProjection: false, viewpoint: 2, placement: .inhabit(point))
      XCTAssertTrue(renderer.headAnchor === inhabit)
      XCTAssertEqual(renderer.root.position, address)
      XCTAssertTrue(receipt.hasSuffix(" · inhabiting (1, -1, 2)"), receipt)
    }
    _ = try renderer.render(selected: point, showProjection: false, viewpoint: 0)
    XCTAssertNil(renderer.headAnchor)
    XCTAssertTrue(renderer.root.parent === renderer.stage && renderer.anchorHost.children.isEmpty)
    XCTAssertEqual(renderer.root.position, StarscapeRenderer.center)
  }
  /// An explicit Origin or Inhabit request re-anchors at the current head center even when the placement is
  /// unchanged; renders, selection changes and the nappe flip keep the anchor.
  func testExplicitRequestsReanchorButRendersAndNappeFlipsDoNot() throws {
    let model = GalleryModel()
    let renderer = StarscapeRenderer()
    func render() throws {
      _ = try renderer.render(
        selected: model.coefficient, showProjection: false, viewpoint: 0, placement: model.coefficientPlacement,
        placementEpoch: model.coefficientPlacementEpoch)
    }
    model.place(.origin(facingLower: false))
    try render()
    let first = try XCTUnwrap(renderer.headAnchor)
    model.select(CoefficientPoint(2, 1, 1))
    try render()
    try render()
    XCTAssertTrue(renderer.headAnchor === first)
    model.place(.origin(facingLower: true), recenter: false)
    try render()
    XCTAssertTrue(renderer.headAnchor === first)
    model.place(.origin(facingLower: false))  // Origin pressed again
    try render()
    let second = try XCTUnwrap(renderer.headAnchor)
    XCTAssertFalse(second === first)
    XCTAssertNil(first.parent)
    XCTAssertEqual(renderer.anchorHost.children.count, 1)
    model.place(.inhabit(model.coefficient))
    try render()
    let inhabit = try XCTUnwrap(renderer.headAnchor)
    model.place(.inhabit(CoefficientPoint(2, 1, 1)))  // Inhabit pressed again at the same point
    try render()
    XCTAssertFalse(renderer.headAnchor === inhabit)
    let address = renderer.root.position
    model.select(CoefficientPoint(1, 3, 1))
    try render()
    XCTAssertEqual(renderer.root.position, address)
    XCTAssertEqual(model.coefficientPlacement, .inhabit(CoefficientPoint(2, 1, 1)))
    model.place(.overview)
    try render()
    XCTAssertNil(renderer.headAnchor)
    XCTAssertTrue(renderer.anchorHost.children.isEmpty)
  }
  /// At Origin, dots and their rings follow the browser's origin rule; leaving Origin restores overview sizes.
  func testOriginUsesTheSourceSizeRuleAndOverviewIsRestored() throws {
    let renderer = StarscapeRenderer()
    let plane = try CuttingPlane.pair(CoefficientPoint(1, 0, 1), CoefficientPoint(1, 1, 1)).get()
    func render(_ placement: StarscapeRenderer.Placement) throws {
      _ = try renderer.render(
        selected: CoefficientPoint(1, 0, 1), showProjection: false, viewpoint: 0, cuttingPlane: plane,
        second: CoefficientPoint(1, 1, 1), placement: placement)
    }
    try render(.origin(facingLower: false))
    for point in [CoefficientPoint(1, 0, 1), CoefficientPoint(2, 0, 2), CoefficientPoint(-1, 0, -1), CoefficientPoint(1, -1, 2),
                  CoefficientPoint(1, 2, 1), CoefficientPoint(1, 3, 1)] {
      XCTAssertEqual(
        Double(renderer.effectiveFactor(point, colorLower: false)), CoefficientPalette.originRadiusFactor(for: point),
        accuracy: 1e-6, point.label)
    }
    // Plane membership is still ringed, with rings sized from the Origin radius and no 1.35 emphasis.
    let ring = try XCTUnwrap(renderer.root.findEntity(named: "plane-member:2:0:2") as? ModelEntity)
    let bounds = ring.visualBounds(relativeTo: ring)
    XCTAssertEqual(bounds.extents.x / 2, StarscapeRenderer.glyphRadius * 0.4 * 1.55, accuracy: 1e-4)
    try render(.overview)
    XCTAssertEqual(renderer.effectiveFactor(CoefficientPoint(2, 0, 2), colorLower: false), 0.72 * 1.35, accuracy: 1e-6)
    XCTAssertEqual(renderer.effectiveFactor(CoefficientPoint(1, 2, 1), colorLower: false), 1)
    try render(.origin(facingLower: true))
    XCTAssertEqual(Double(renderer.effectiveFactor(CoefficientPoint(1, 0, 1), colorLower: false)), 0.4, accuracy: 1e-6)
  }
  func testResetReturnsToOverviewAndDropsThePair() {
    let model = GalleryModel()
    XCTAssertTrue(model.enterCoefficient("1,0,1"))
    XCTAssertTrue(model.pairCoefficient("1,1,1"))
    model.place(.inhabit(model.coefficient))
    XCTAssertTrue(model.enterCoefficient("2,1,1"))
    XCTAssertEqual(model.coefficientPlacement, .inhabit(CoefficientPoint(1, 0, 1)))
    model.resetStarscape()
    XCTAssertEqual(model.coefficientPlacement, .overview)
    XCTAssertNil(model.coefficientSecond)
    XCTAssertNil(model.cuttingPlane)
  }
}
