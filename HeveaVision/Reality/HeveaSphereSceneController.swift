import HeveaCore
import RealityKit
import UIKit

private actor SphereAnalysisPipeline {
  private var analysisByStage: [String: SphereAnalysisBundle] = [:]

  /// Serializes the expensive immutable core analysis. A request canceled
  /// while waiting for the actor exits before doing work; a request canceled
  /// during synchronous generation may still populate the reusable cache, but
  /// its caller will never receive a value that it can install in the scene.
  func analysis(for stage: SphereStage) throws -> SphereAnalysisBundle {
    try Task.checkCancellation()
    if let cached = analysisByStage[stage.rawValue] {
      return cached
    }

    let generated = try SphereAnalysisEngine.generate(stage: stage)
    analysisByStage[stage.rawValue] = generated
    try Task.checkCancellation()
    return generated
  }
}

private let sphereAnalysisPipeline = SphereAnalysisPipeline()

private struct SphereSceneTransform {
  let position: SIMD3<Float>
  let orientation: simd_quatf
  let scale: SIMD3<Float>

  var isFiniteAndPositive: Bool {
    position.x.isFinite && position.y.isFinite && position.z.isFinite
      && orientation.vector.x.isFinite && orientation.vector.y.isFinite
      && orientation.vector.z.isFinite && orientation.vector.w.isFinite
      && scale.x.isFinite && scale.y.isFinite && scale.z.isFinite
      && scale.x > 0 && scale.y > 0 && scale.z > 0
  }
}

private struct SpherePresentationPlan {
  let sample: SphereSurfaceSample
  let transform: SphereSceneTransform
}

/// A pure witness plan shared by rendering and tests. The visible line always runs from the
/// addressed surface point through the signed-altitude marker and extends in the same direction.
struct SpherePlumbLinePlan {
  let surfacePoint: SIMD3<Float>
  let addressPoint: SIMD3<Float>
  let endpoint: SIMD3<Float>

  init(surfacePoint: SIMD3<Float>, unitNormal: SIMD3<Float>, altitude: Float) {
    self.surfacePoint = surfacePoint
    addressPoint = surfacePoint + unitNormal * altitude
    let extensionSign: Float = altitude < 0 ? -1 : 1
    endpoint = addressPoint + unitNormal * (extensionSign * 0.055)
  }
}

@MainActor
extension HeveaSceneController {
  func regenerateSphere(
    stage: SphereStage,
    sectionAmount: Double
  ) async throws -> SphereDiagnosticSnapshot {
    let generated = try await sphereAnalysisPipeline.analysis(for: stage)
    try Task.checkCancellation()

    let surface = try SphereRealityBridge.makeSurface(
      from: generated,
      sectionAmount: sectionAmount
    )
    try Task.checkCancellation()
    sphereSurfaceContent.children.removeAll()
    sphereSurfaceContent.addChild(surface)
    sphereGhostContent.children.removeAll()
    if stage != .unitSphere {
      sphereGhostContent.addChild(SphereRealityBridge.makeUnitSphereGhost())
    }
    return generated.diagnosticSnapshot
  }

  func applySpherePresentation(
    regime: SphereRegime,
    navigation: SphereNavigationState,
    stage: SphereStage,
    scale: Float,
    rotation: SIMD2<Float>,
    showUnitSphereGhost: Bool
  ) -> Bool {
    guard
      let plan = makeSpherePresentationPlan(
        regime: regime,
        navigation: navigation,
        stage: stage,
        scale: scale,
        rotation: rotation
      )
    else { return false }

    surfaceAnchor.isEnabled = false
    sphereAnchor.isEnabled = true
    domainFloor.isEnabled = false
    gaussAnchor.isEnabled = false
    sphereGhostContent.isEnabled = showUnitSphereGhost && regime == .atlas && stage != .unitSphere
    updateSphereAddressMarker(
      sample: plan.sample,
      navigation: navigation,
      stage: stage
    )
    sphereAnchor.position = plan.transform.position
    sphereAnchor.orientation = plan.transform.orientation
    sphereAnchor.scale = plan.transform.scale
    return true
  }

  private func makeSpherePresentationPlan(
    regime: SphereRegime,
    navigation: SphereNavigationState,
    stage: SphereStage,
    scale: Float,
    rotation: SIMD2<Float>
  ) -> SpherePresentationPlan? {
    guard scale.isFinite, (0.55...2.25).contains(scale),
      rotation.x.isFinite, (-Float.pi...Float.pi).contains(rotation.x),
      rotation.y.isFinite, (-Float.pi / 2...Float.pi / 2).contains(rotation.y),
      let sample = try? SphereMeshGenerator.sample(
        at: navigation.address.unitDirection,
        stage: stage
      )
    else { return nil }

    let position = SphereRealityBridge.displayVector(sample.position)
    let rawNormal = SphereRealityBridge.displayVector(sample.normal)
    let normalLength = simd_length(rawNormal)
    guard position.x.isFinite, position.y.isFinite, position.z.isFinite,
      normalLength.isFinite, normalLength > 0.000_001
    else { return nil }

    let yawOrientation = simd_quatf(angle: rotation.x, axis: [0, 1, 0])
    let userOrientation = regime.permitsInspectionPitch
      ? yawOrientation * simd_quatf(angle: rotation.y, axis: [1, 0, 0])
      : yawOrientation
    let transform = makeSphereTransform(
      regime: regime,
      navigation: navigation,
      stage: stage,
      scale: scale,
      userOrientation: userOrientation,
      selectedPosition: position,
      selectedNormal: rawNormal / normalLength
    )
    guard transform.isFiniteAndPositive else { return nil }
    return SpherePresentationPlan(sample: sample, transform: transform)
  }

  private func makeSphereTransform(
    regime: SphereRegime,
    navigation: SphereNavigationState,
    stage: SphereStage,
    scale: Float,
    userOrientation: simd_quatf,
    selectedPosition: SIMD3<Float>,
    selectedNormal: SIMD3<Float>
  ) -> SphereSceneTransform {
    switch regime {
    case .atlas:
      let baseScale: Float = stage == .unitSphere ? 0.58 : 1.22
      return SphereSceneTransform(
        position: [0, 1.42, -1.55],
        orientation: userOrientation,
        scale: SIMD3(repeating: baseScale * scale)
      )
    case .habitat, .hover:
      return makeSphereLocalGaugeTransform(
        regime: regime,
        navigation: navigation,
        stage: stage,
        scale: scale,
        userOrientation: userOrientation,
        selectedPosition: selectedPosition,
        selectedNormal: selectedNormal
      )
    case .interior:
      let interiorScale: Float = stage == .unitSphere ? 2.0 : 4.2
      return SphereSceneTransform(
        position: [0, 1.42, 0],
        orientation: userOrientation,
        scale: SIMD3(repeating: interiorScale * scale)
      )
    }
  }

  private func makeSphereLocalGaugeTransform(
    regime: SphereRegime,
    navigation: SphereNavigationState,
    stage: SphereStage,
    scale: Float,
    userOrientation: simd_quatf,
    selectedPosition: SIMD3<Float>,
    selectedNormal: SIMD3<Float>
  ) -> SphereSceneTransform {
    let alignNormal = simd_quatf(from: selectedNormal, to: [0, 1, 0])
    let alignHeading = simd_quatf(
      angle: Float(-navigation.address.headingRadians),
      axis: [0, 1, 0]
    )
    let orientation = userOrientation * alignHeading * alignNormal
    let localScale: Float = (stage == .unitSphere ? 2.7 : 6.0) * scale

    let altitude = Float(navigation.address.altitude)
    let addressedFloorHeight: Float =
      regime == .habitat
      ? 0.22 - altitude * localScale
      : 0.58 - altitude * localScale
    let target = SIMD3<Float>(0, addressedFloorHeight, -0.88)
    return SphereSceneTransform(
      position: target - orientation.act(selectedPosition * localScale),
      orientation: orientation,
      scale: SIMD3(repeating: localScale)
    )
  }

  private func updateSphereAddressMarker(
    sample: SphereSurfaceSample,
    navigation: SphereNavigationState,
    stage: SphereStage
  ) {
    sphereAddressContent.children.removeAll()
    let surfacePoint = SphereRealityBridge.displayVector(sample.position)
    let displayNormal = normalizedOrUp(SphereRealityBridge.displayVector(sample.normal))
    let altitude = Float(navigation.address.altitude)
    let plumb = SpherePlumbLinePlan(
      surfacePoint: surfacePoint,
      unitNormal: displayNormal,
      altitude: altitude
    )

    let marker = ModelEntity(
      mesh: .generateSphere(radius: 0.012),
      materials: [Self.unlit(.systemYellow)]
    )
    marker.position = plumb.addressPoint
    marker.name = "sphere-intrinsic-address-marker"
    sphereAddressContent.addChild(marker)

    sphereAddressContent.addChild(
      Self.segment(
        from: plumb.surfacePoint,
        to: plumb.endpoint,
        radius: 0.0022,
        color: .systemYellow
      )
    )

    addHeadingMarker(
      from: plumb.addressPoint,
      surfacePoint: surfacePoint,
      navigation: navigation,
      stage: stage
    )
  }

  private func addHeadingMarker(
    from addressPoint: SIMD3<Float>,
    surfacePoint: SIMD3<Float>,
    navigation: SphereNavigationState,
    stage: SphereStage
  ) {
    guard
      let headingStep = try? SphereNavigator.headingTangentStep(
        at: navigation.address,
        forward: 0.008,
        right: 0
      ),
      let nextDirection = try? SphereNavigator.exponentialMap(
        from: navigation.address.unitDirection,
        tangentStep: headingStep
      ),
      let nextSample = try? SphereMeshGenerator.sample(
        at: nextDirection,
        stage: stage
      )
    else { return }

    let delta = SphereRealityBridge.displayVector(nextSample.position) - surfacePoint
    let heading = normalizedOrForward(delta)
    sphereAddressContent.addChild(
      Self.segment(
        from: addressPoint,
        to: addressPoint + heading * 0.075,
        radius: 0.0024,
        color: .systemCyan
      )
    )
  }

  private func normalizedOrUp(_ vector: SIMD3<Float>) -> SIMD3<Float> {
    let length = simd_length(vector)
    guard length.isFinite, length > 0.000_001 else { return [0, 1, 0] }
    return vector / length
  }

  private func normalizedOrForward(_ vector: SIMD3<Float>) -> SIMD3<Float> {
    let length = simd_length(vector)
    guard length.isFinite, length > 0.000_001 else { return [0, 0, -1] }
    return vector / length
  }
}
