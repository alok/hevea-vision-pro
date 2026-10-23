import RealityKit
import XCTest

@testable import FareyVision

/// Origin input: what each drag step did, the opt-in diagnostics, and the explicit device-pose placement that lets the
/// app read the object's frame (a head anchor's transform reads as the identity to the app).
@MainActor final class OriginInputTests: XCTestCase {
  /// A measured device pose for the model's current placement (the view's world-tracking query, stood in for).
  private func grantDevicePose(_ model: GalleryModel, _ pose: simd_float4x4 = matrix_identity_float4x4) {
    model.coefficientInput.devicePose = DevicePose(epoch: model.coefficientPlacementEpoch, originFromDevice: pose)
  }
  /// Each Origin drag step reports what it did, for the opt-in input diagnostics; the effect is unchanged.
  func testOriginDragStepReportsItsOutcome() {
    let model = GalleryModel()
    XCTAssertEqual(model.originDragStep(to: [0, 2, 0]), .notOrigin)
    model.coefficientPlacement = .origin(facingLower: false)
    model.coefficientPlacementEpoch += 1
    XCTAssertEqual(model.originDragStep(to: [0, 2, 0]), .noDevicePose)  // no measured pose yet: nothing moves
    grantDevicePose(model)
    XCTAssertEqual(model.originDragStep(to: [0, 2, 0]), .firstAnchor)
    XCTAssertEqual(model.originDragStep(to: [2, 3, 1]), .moved)
    XCTAssertEqual(model.originDragStep(to: [2, 1, 0]), .offInterior)       // exterior: no anchor, nothing moves
    XCTAssertEqual(model.originDragStep(to: [0, 2, 0]), .offInterior)       // from the exterior direction
    let diagnostics = InputDiagnostics(enabled: true), silent = InputDiagnostics(enabled: false)
    for recorder in [diagnostics, silent] {
      recorder.recordDrag(
        entity: "origin-sky", sample: .init(direction: [0, 2.4, 0], twoHop: [0, 2, 0], start: [0, 2.4, 0], translation: [0, 0, 0]),
        outcome: .firstAnchor)
      recorder.recordDragEnd()
      recorder.recordTap(entity: "")
      recorder.recordActivate(entity: "coefficient:3:0:3")
      recorder.recordSky("collision yes · input target yes · enabled true · scale 1.000")
    }
    XCTAssertTrue(diagnostics.summary.contains("activations 1 · last activate entity coefficient:3:0:3"), diagnostics.summary)
    XCTAssertTrue(diagnostics.summary.contains("sky collision yes · input target yes · enabled true · scale 1.000"))
    XCTAssertEqual(silent.activations, 0)
    XCTAssertTrue(diagnostics.summary.contains("direction first (0.000, 2.400, 0.000) last (0.000, 2.400, 0.000)"), diagnostics.summary)
    XCTAssertTrue(diagnostics.summary.contains("two-hop first (0.000, 2.000, 0.000)"))
    XCTAssertTrue(diagnostics.summary.contains("start (0.000, 2.400, 0.000) · translation last (0.000, 0.000, 0.000)"))
    XCTAssertTrue(diagnostics.summary.contains("outcomes [first direction recorded 1]"), diagnostics.summary)
    // The first event (a click) has no ray; a later one does: both are kept, and every ray is counted.
    diagnostics.recordPinch(entity: "origin-sky", phase: "active", location: [0, 2.4, 0], ray: nil)
    diagnostics.recordPinch(entity: "origin-sky", phase: "active", location: [0.1, 2.4, 0], ray: ([0, 0, 1.5], [0, 1, 0]))
    diagnostics.recordPinch(entity: "origin-sky", phase: "ended", location: [0.2, 2.4, 0], ray: ([0, 0, 1.5], [0, 1, 0]))
    XCTAssertTrue(diagnostics.summary.hasSuffix(
      "pinch events 3 [active 2, ended 1] first entity origin-sky location (0.000, 2.400, 0.000) · rays 2 [active 1, ended 1]"
        + " first ray at active location (0.100, 2.400, 0.000) origin (0.000, 0.000, 1.500) direction (0.000, 1.000, 0.000)"),
      diagnostics.summary)
    XCTAssertEqual(diagnostics.dragChanges, 1)
    XCTAssertTrue(diagnostics.summary.contains("last drag entity origin-sky"), diagnostics.summary)
    XCTAssertTrue(diagnostics.summary.contains("outcome first direction recorded · taps 1 · last tap entity unnamed"))
    XCTAssertEqual(silent.dragChanges, 0)
    XCTAssertEqual(silent.taps, 0)
  }
  /// Origin needs the measured pose of its own placement: none, or one left from an earlier placement, moves nothing.
  func testOriginDragNeedsTheCurrentPlacementsDevicePose() {
    let model = GalleryModel()
    model.place(.origin(facingLower: false))                         // epoch 1
    XCTAssertEqual(model.originDragStep(to: [0, 2, 0]), .noDevicePose)
    XCTAssertEqual(model.originDragStep(to: [2, 3, 1]), .noDevicePose)
    XCTAssertTrue(model.coefficientGroup.isIdentity)
    grantDevicePose(model)
    XCTAssertNotNil(model.currentDevicePose)
    model.place(.origin(facingLower: true), recenter: false)         // the nappe flip keeps the placement's pose
    XCTAssertNotNil(model.currentDevicePose)
    model.place(.origin(facingLower: false))                         // a new Origin (epoch 2) needs a new pose
    XCTAssertNil(model.currentDevicePose)
    XCTAssertEqual(model.originDragStep(to: [0, 2, 0]), .noDevicePose)
    model.place(.overview)
    XCTAssertNil(model.currentDevicePose)
  }
  /// With a measured device pose (here 1.5 m up, turned 30°), the object sits explicitly under the world-stationary
  /// host, so a point straight ahead of the device reads as straight up the nappe; the flip keeps the pose; Overview
  /// returns to the stage; without a pose, a new Origin uses the head anchor and says so.
  func testExplicitDevicePosePlacement() throws {
    let renderer = StarscapeRenderer()
    let pose = simd_float4x4(simd_quatf(angle: .pi / 6, axis: [0, 1, 0])) * matrix_identity_float4x4
    var posed = pose
    posed.columns.3 = [0.2, 1.5, -0.3, 1]
    let receipt = try renderer.render(
      selected: CoefficientPoint(1, 0, 1), showProjection: false, viewpoint: 0, placement: .origin(facingLower: false),
      placementEpoch: 1, devicePose: posed)
    XCTAssertTrue(renderer.root.parent === renderer.anchorHost)
    XCTAssertNil(renderer.headAnchor)
    XCTAssertTrue(receipt.contains(" · origin, upper nappe ahead · placed from the device pose"), receipt)
    let expected = posed * simd_float4x4(simd_quatf(angle: -.pi / 2, axis: [1, 0, 0]))
    let actual = renderer.root.transformMatrix(relativeTo: nil)
    for column in 0..<4 { XCTAssertEqual(simd_distance(actual[column], expected[column]), 0, accuracy: 1e-5) }
    let ahead = posed * SIMD4<Float>(0, 0, -2.4, 1)                   // 2.4 m along the device's forward (−z)
    let direction = renderer.displayDirection(ofScenePoint: [ahead.x, ahead.y, ahead.z])
    XCTAssertEqual(direction.x, 0, accuracy: 1e-4)
    XCTAssertEqual(direction.y, 2.4, accuracy: 1e-4)
    XCTAssertEqual(direction.z, 0, accuracy: 1e-4)
    XCTAssertEqual(simd_distance(try XCTUnwrap(upperPoint(displayDirection: direction)), [0, 1]), 0, accuracy: 1e-4)
    _ = try renderer.render(
      selected: CoefficientPoint(1, 0, 1), showProjection: false, viewpoint: 0, placement: .origin(facingLower: true),
      placementEpoch: 1, devicePose: posed)
    XCTAssertTrue(renderer.root.parent === renderer.anchorHost)
    let flipped = renderer.root.transformMatrix(relativeTo: nil)
    let flippedExpected = posed * simd_float4x4(simd_quatf(angle: .pi / 2, axis: [1, 0, 0]))
    for column in 0..<4 { XCTAssertEqual(simd_distance(flipped[column], flippedExpected[column]), 0, accuracy: 1e-5) }
    _ = try renderer.render(selected: CoefficientPoint(1, 0, 1), showProjection: false, viewpoint: 0)
    XCTAssertTrue(renderer.root.parent === renderer.stage)
    let fallback = try renderer.render(
      selected: CoefficientPoint(1, 0, 1), showProjection: false, viewpoint: 0, placement: .origin(facingLower: false),
      placementEpoch: 2)
    XCTAssertNotNil(renderer.headAnchor)
    XCTAssertTrue(fallback.contains(" · origin, upper nappe ahead · placed by the head anchor (no device pose)"), fallback)
  }
  /// Only a finite rigid transform is used as a device pose; anything else is an explicit failure, never the identity.
  func testOnlyRigidDevicePosesAreUsed() {
    var pose = simd_float4x4(simd_quatf(angle: 0.4, axis: simd_normalize([0.3, 1, 0.2])))
    pose.columns.3 = [0.1, 1.6, -0.2, 1]
    XCTAssertTrue(DevicePoseQuery.isRigid(pose))
    var scaled = pose
    scaled.columns.0 *= 1.1
    XCTAssertFalse(DevicePoseQuery.isRigid(scaled))
    var mirrored = pose
    mirrored.columns.2 = -mirrored.columns.2
    XCTAssertFalse(DevicePoseQuery.isRigid(mirrored))
    var broken = pose
    broken.columns.3.y = .nan
    XCTAssertFalse(DevicePoseQuery.isRigid(broken))
    var projective = pose
    projective.columns.0.w = 0.5
    XCTAssertFalse(DevicePoseQuery.isRigid(projective))
  }
}
