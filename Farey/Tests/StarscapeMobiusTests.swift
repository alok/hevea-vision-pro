import RealityKit
import XCTest

@testable import FareyVision

/// The native Möbius view against the exact single-step fixture g = [[3, 1], [1, 2]]/√5 (the transvection i → 1 + i).
@MainActor final class StarscapeMobiusTests: XCTestCase {
  private let g = Mobius(3, 1, 1, 2)!
  /// A measured device pose for the model's current placement (the view's world-tracking query, stood in for).
  private func grantDevicePose(_ model: GalleryModel, _ pose: simd_float4x4 = matrix_identity_float4x4) {
    model.coefficientInput.devicePose = DevicePose(epoch: model.coefficientPlacementEpoch, originFromDevice: pose)
  }
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
  /// At Origin a drag from the direction of (1,0,1), (0,2,0), to (2,3,1) is the roots-pane step i → 1 + i: it gives
  /// the fixture g, keeps the exact selection and pair, and the dragged star is then drawn along (2,3,1).
  func testOriginDragIsTheRootsPaneStep() throws {
    let model = GalleryModel()
    model.select(CoefficientPoint(1, 0, 1))
    XCTAssertTrue(model.pairCoefficient("1,1,1"))
    let pair = model.coefficientSecond
    model.dragOrigin(from: [0, 2, 0], to: [2, 3, 1])
    for (x, y) in zip(model.coefficientGroup.entries, g.entries) { XCTAssertEqual(x, y, accuracy: 1e-12) }
    XCTAssertEqual(model.coefficient, CoefficientPoint(1, 0, 1))
    XCTAssertEqual(model.coefficientSecond, pair)
    // Off the interior (exterior, null, horizontal) there is no anchor: g is unchanged and nothing is clamped.
    let revision = model.revision
    for d: SIMD3<Double> in [[2, 1, 0], [1, 1, 0], [1, 0, 0]] {
      model.dragOrigin(from: [2, 3, 1], to: d)
      model.dragOrigin(from: d, to: [0, 2, 0])
    }
    XCTAssertEqual(model.revision, revision)
    for (x, y) in zip(model.coefficientGroup.entries, g.entries) { XCTAssertEqual(x, y, accuracy: 1e-12) }
    // The renderer under this g at Origin: the scene position of (1,0,1) maps back to display direction (2,3,1).
    let renderer = StarscapeRenderer()
    _ = try renderer.render(
      selected: CoefficientPoint(1, 0, 1), showProjection: false, viewpoint: 0, placement: .origin(facingLower: false),
      placementEpoch: 1, group: model.coefficientGroup)
    let dot = try XCTUnwrap(renderer.root.findEntity(named: "coefficient:1:0:1"))
    let z = try XCTUnwrap(upperPoint(displayDirection: renderer.displayDirection(ofScenePoint: dot.position(relativeTo: nil))))
    XCTAssertEqual(simd_distance(z, [1, 1]), 0, accuracy: 1e-5)
  }
  func testSkyIsAHitTargetOnlyAtOrigin() async throws {
    let renderer = StarscapeRenderer()
    try await renderer.prepareSky()
    XCTAssertNotNil(renderer.sky.components[CollisionComponent.self])
    XCTAssertNotNil(renderer.sky.components[InputTargetComponent.self])
    _ = try renderer.render(selected: CoefficientPoint(1, 0, 1), showProjection: false, viewpoint: 0)
    XCTAssertFalse(renderer.sky.isEnabled)
    _ = try renderer.render(
      selected: CoefficientPoint(1, 0, 1), showProjection: false, viewpoint: 0, placement: .origin(facingLower: true), placementEpoch: 1)
    XCTAssertTrue(renderer.sky.isEnabled)
    _ = try renderer.render(selected: CoefficientPoint(1, 0, 1), showProjection: false, viewpoint: 0)
    XCTAssertFalse(renderer.sky.isEnabled)
  }
  /// A drag's previous direction belongs to the placement it began under: a nappe flip, a new Origin or Reset makes
  /// the next step a fresh start, a cancelled gesture never snaps, and Overview ignores drags.
  func testOriginDragLifecycleNeverJumpsOrSnapsStaleState() throws {
    let model = GalleryModel()
    model.coefficientSnap = true
    model.originDragStep(to: [0, 2, 0])                               // Overview: ignored
    model.originDragStep(to: [2, 3, 1])
    XCTAssertTrue(model.coefficientGroup.isIdentity)
    XCTAssertNil(model.originDragAnchor)
    model.coefficientPlacement = .origin(facingLower: false)
    model.coefficientPlacementEpoch += 1
    grantDevicePose(model)
    model.originDragStep(to: [0, 2, 0])                               // first step only records
    XCTAssertTrue(model.coefficientGroup.isIdentity)
    model.originDragStep(to: [2, 3, 1])
    for (x, y) in zip(model.coefficientGroup.entries, g.entries) { XCTAssertEqual(x, y, accuracy: 1e-12) }
    model.endOriginDrag(completed: false)                             // cancelled: no Snap despite Snap on
    for (x, y) in zip(model.coefficientGroup.entries, g.entries) { XCTAssertEqual(x, y, accuracy: 1e-12) }
    // After the flip the old direction is stale: no jump from (2,3,1).
    model.originDragStep(to: [2, 3, 1])
    model.coefficientPlacement = .origin(facingLower: true)
    model.originDragStep(to: [0, 2, 0])
    for (x, y) in zip(model.coefficientGroup.entries, g.entries) { XCTAssertEqual(x, y, accuracy: 1e-12) }
    model.endOriginDrag(completed: true)                              // never moved under this placement: no Snap
    XCTAssertFalse(model.coefficientGroup.isIdentity)
    // Reset mid-drag: the completed end finds a different placement, so nothing is snapped or applied.
    model.originDragStep(to: [0, 2, 0])
    model.originDragStep(to: [1, 3, 0])
    model.resetStarscape()
    model.endOriginDrag(completed: true)
    XCTAssertTrue(model.coefficientGroup.isIdentity)
    XCTAssertEqual(model.coefficient, CoefficientPoint(1, -1, 2))
    // A completed drag under its own placement snaps, as a roots-pane drag does.
    model.coefficientSnap = true
    model.coefficientPlacement = .origin(facingLower: false)
    grantDevicePose(model)                                           // Reset cleared the earlier pose
    model.originDragStep(to: [0, 2, 0])
    model.originDragStep(to: [0.05, 2, 0])
    model.endOriginDrag(completed: true)
    XCTAssertTrue(model.coefficientGroup.isIdentity)                  // a short drag snaps back to g = 1
  }
  /// The pointer's direction is read in the object's frame, which g does not move: the same scene point gives the
  /// same direction whatever g is drawn, so a moving star cannot feed back into the drag.
  func testDragDirectionIsIndependentOfG() throws {
    let renderer = StarscapeRenderer()
    let point: SIMD3<Float> = [0.1, 0.3, -0.4]
    _ = try renderer.render(
      selected: CoefficientPoint(1, 0, 1), showProjection: false, viewpoint: 0, placement: .origin(facingLower: false),
      placementEpoch: 1)
    let before = renderer.displayDirection(ofScenePoint: point)
    _ = try renderer.render(
      selected: CoefficientPoint(1, 0, 1), showProjection: false, viewpoint: 0, placement: .origin(facingLower: false),
      placementEpoch: 1, group: g)
    XCTAssertEqual(simd_distance(renderer.displayDirection(ofScenePoint: point), before), 0, accuracy: 1e-6)
  }
  /// Under any g every facet of the sky's shell stays beyond every star's collision sphere: at the identity, the
  /// fixture g (which carries (1,−4,3) to display (10,11,5), 2.51 m out) and diag(2, ½) (108 R6 centers beyond the
  /// unscaled shell, up to 3.63 m).
  func testSkyStaysBeyondEveryStar() async throws {
    for group in [Mobius.identity, g, try XCTUnwrap(Mobius(2, 0, 0, 0.5))] {
      let renderer = StarscapeRenderer()
      try await renderer.prepareSky()
      _ = try renderer.render(
        selected: CoefficientPoint(1, 0, 1), showProjection: false, viewpoint: 0, placement: .origin(facingLower: false),
        placementEpoch: 1, group: group)
      var reach: Float = 0
      for point in CoefficientBall.points(radius: 6) {
        let dot = try XCTUnwrap(renderer.root.findEntity(named: "coefficient:\(point.a):\(point.b):\(point.c)"))
        reach = max(reach, simd_length(dot.position) + StarscapeRenderer.dotCollisionRadius * dot.scale.x)
      }
      // The nearest facet plane of the scaled shell, recomputed from its mesh, not the nominal radius.
      let (positions, faces) = StarscapeRenderer.skyMesh()
      let nearest = stride(from: 0, to: faces.count, by: 3).compactMap { i -> Float? in
        let a = positions[Int(faces[i])] * renderer.sky.scale.x, b = positions[Int(faces[i + 1])] * renderer.sky.scale.x
        let c = positions[Int(faces[i + 2])] * renderer.sky.scale.x, n = simd_cross(b - a, c - a)
        return simd_length(n) < 1e-6 ? nil : abs(simd_dot(simd_normalize(n), a))
      }.min() ?? 0
      XCTAssertLessThan(reach, nearest, "\(group.entries)")
    }
    XCTAssertEqual(StarscapeRenderer.skyInradius / StarscapeRenderer.skyRadius, 0.98310560, accuracy: 1e-5)
  }
  /// Rays from the coefficient origin, cast in a real RealityKit scene under the fixture g: one through the clearest
  /// gap between the stars' collision spheres meets the sky's static mesh from inside; one at the far star (1,−4,3),
  /// beyond the unscaled shell, meets that star. If this runtime gives the entities no scene, the gap is reported.
  func testRaysFromTheOriginHitTheSkyOrAStar() async throws {
    let renderer = StarscapeRenderer()
    try await renderer.prepareSky()
    _ = try renderer.render(
      selected: CoefficientPoint(1, 0, 1), showProjection: false, viewpoint: 0, placement: .origin(facingLower: false),
      placementEpoch: 1, group: g)
    let host = try RealityRenderer()
    host.entities.append(renderer.anchorHost)
    host.entities.append(renderer.stage)
    guard let scene = renderer.root.scene else {
      throw XCTSkip("No RealityKit scene for these entities in this runtime; the sky raycast remains unverified")
    }
    // The clearest of 2,000 evenly spread directions, by distance past every star's collision sphere ahead.
    let stars = try CoefficientBall.points(radius: 6).map { point in
      let dot = try XCTUnwrap(renderer.root.findEntity(named: "coefficient:\(point.a):\(point.b):\(point.c)"))
      return (dot.position, StarscapeRenderer.dotCollisionRadius * dot.scale.x)
    }
    func clearance(_ d: SIMD3<Float>) -> Float {
      stars.map { s, r in simd_dot(s, d) < 0 ? .infinity : simd_length(s - simd_dot(s, d) * d) - r }.min() ?? .infinity
    }
    let directions = (0..<2000).map { i -> SIMD3<Float> in
      let y = 1 - 2 * (Float(i) + 0.5) / 2000, r = (1 - y * y).squareRoot(), t = Float(i) * 2.399963
      return [r * cos(t), y, r * sin(t)]
    }
    let clear = try XCTUnwrap(directions.max { clearance($0) < clearance($1) })
    XCTAssertGreaterThan(clearance(clear), 0.02)
    let origin = renderer.root.position(relativeTo: nil)
    let skyHits = scene.raycast(origin: origin, direction: renderer.root.convert(direction: clear, to: nil), length: 20, query: .nearest)
    XCTAssertEqual(skyHits.first?.entity.name, "origin-sky", "\(skyHits.map(\.entity.name))")
    let far = try XCTUnwrap(renderer.root.findEntity(named: "coefficient:1:-4:3"))
    XCTAssertGreaterThan(simd_length(far.position), StarscapeRenderer.skyRadius)
    let toFar = simd_normalize(far.position(relativeTo: nil) - origin)
    let farHits = scene.raycast(origin: origin, direction: toFar, length: 20, query: .nearest)
    XCTAssertEqual(farHits.first?.entity.name, "coefficient:1:-4:3", "\(farHits.map(\.entity.name))")
  }
}
