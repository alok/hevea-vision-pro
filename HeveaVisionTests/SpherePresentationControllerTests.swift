import HeveaCore
import Testing
import simd

@testable import HeveaVision

@MainActor
struct SpherePresentationControllerTests {
  @Test
  // Keep all signed-altitude gauge equations together so the regression is readable as one proof.
  // swiftlint:disable:next function_body_length
  func habitatAndHoverPreserveGravityGaugeAtSignedAltitudeWhileYawing() throws {
    let model = AppModel(arguments: ["HeveaVision"], environment: [:])
    for altitude in [0.18, -0.11] {
      let address = try SphereAddress(
        unitDirection: model.sphereNavigation.address.unitDirection,
        altitude: altitude,
        headingRadians: 0.37
      )
      let navigation = try SphereNavigationState(address: address)
      let sample = try SphereMeshGenerator.sample(
        at: navigation.address.unitDirection,
        stage: .proxyFamily3
      )
      let selectedPosition = SphereRealityBridge.displayVector(sample.position)
      let selectedNormal = simd_normalize(SphereRealityBridge.displayVector(sample.normal))
      let tangentSeed: SIMD3<Float> = abs(selectedNormal.y) < 0.9 ? [0, 1, 0] : [1, 0, 0]
      let selectedTangent = simd_normalize(simd_cross(selectedNormal, tangentSeed))
      let plumbPlan = SpherePlumbLinePlan(
        surfacePoint: selectedPosition,
        unitNormal: selectedNormal,
        altitude: Float(altitude)
      )
      let expectedExtension: Float = altitude < 0 ? -0.055 : 0.055
      #expect(
        simd_distance(
          plumbPlan.addressPoint,
          selectedPosition + selectedNormal * Float(altitude)
        ) < 1e-6
      )
      #expect(abs(simd_dot(plumbPlan.endpoint - plumbPlan.addressPoint, selectedNormal)
          - expectedExtension) < 1e-6)
      #expect(simd_length(simd_cross(plumbPlan.endpoint - selectedPosition, selectedNormal)) < 1e-6)

      for regime in [SphereRegime.habitat, .hover] {
        let scene = HeveaSceneController()
        #expect(
          scene.applySpherePresentation(
            regime: regime,
            navigation: navigation,
            stage: .proxyFamily3,
            scale: 1,
            rotation: .zero,
            showUnitSphereGhost: true
          )
        )
        let unrotatedTangent = scene.sphereAnchor.orientation.act(selectedTangent)

        // Pitch is deliberately nonzero here: a local gauge must ignore it while applying yaw.
        #expect(
          scene.applySpherePresentation(
            regime: regime,
            navigation: navigation,
            stage: .proxyFamily3,
            scale: 1,
            rotation: SIMD2(0.35, -0.2),
            showUnitSphereGhost: true
          )
        )

        let orientation = scene.sphereAnchor.orientation
        let localScale = scene.sphereAnchor.scale.x
        let translation = scene.sphereAnchor.position
        let worldSurface = orientation.act(selectedPosition * localScale) + translation
        let worldNormal = simd_normalize(orientation.act(selectedNormal))
        let worldLifted =
          orientation.act((selectedPosition + selectedNormal * Float(altitude)) * localScale)
          + translation
        let expectedHeight: Float = regime == .habitat ? 0.22 : 0.58
        let expectedSurface = SIMD3<Float>(
          0,
          expectedHeight - Float(altitude) * localScale,
          -0.88
        )
        let expectedLifted = SIMD3<Float>(0, expectedHeight, -0.88)
        let plumb = worldLifted - worldSurface
        let rotatedTangent = orientation.act(selectedTangent)

        #expect(simd_distance(worldSurface, expectedSurface) < 1e-5)
        #expect(simd_distance(worldNormal, [0, 1, 0]) < 1e-5)
        #expect(simd_distance(worldLifted, expectedLifted) < 1e-5)
        #expect(abs(plumb.x) < 1e-5)
        #expect(abs(plumb.z) < 1e-5)
        #expect(abs(plumb.y - Float(altitude) * localScale) < 1e-5)
        #expect(simd_distance(unrotatedTangent, rotatedTangent) > 0.05)
      }
    }
  }

  @Test
  func nonFinitePoseIsRejectedBeforeAnySceneMutation() {
    let model = AppModel(arguments: ["HeveaVision"], environment: [:])
    let scene = HeveaSceneController()
    #expect(
      scene.applySpherePresentation(
        regime: .atlas,
        navigation: model.sphereNavigation,
        stage: .proxyFamily3,
        scale: 1,
        rotation: SIMD2(0.2, -0.1),
        showUnitSphereGhost: true
      )
    )
    let position = scene.sphereAnchor.position
    let orientation = scene.sphereAnchor.orientation.vector
    let scale = scene.sphereAnchor.scale
    let markerCount = scene.sphereAddressContent.children.count

    #expect(
      !scene.applySpherePresentation(
        regime: .habitat,
        navigation: model.sphereNavigation,
        stage: .proxyFamily3,
        scale: .nan,
        rotation: .zero,
        showUnitSphereGhost: true
      )
    )
    #expect(
      !scene.applySpherePresentation(
        regime: .habitat,
        navigation: model.sphereNavigation,
        stage: .proxyFamily3,
        scale: 1,
        rotation: SIMD2(.infinity, 0),
        showUnitSphereGhost: true
      )
    )
    #expect(scene.sphereAnchor.position == position)
    #expect(scene.sphereAnchor.orientation.vector == orientation)
    #expect(scene.sphereAnchor.scale == scale)
    #expect(scene.sphereAddressContent.children.count == markerCount)
  }

  @Test
  func modelRejectsNonFinitePoseMutationsAndReceipts() {
    let model = AppModel(arguments: ["HeveaVision"], environment: [:])
    model.beginSphereSceneSession()
    let snapshot = SphereDiagnosticSnapshot(
      vertexCount: 32_514,
      triangleCount: 65_024,
      measuredContainingRadius: 0.39,
      declaredContainingRadius: 0.40,
      eulerCharacteristic: 2,
      seamResidual: 0,
      fingerprint: "finite-pose-mesh"
    )
    #expect(
      model.acknowledgeSphereRender(
        stage: .proxyFamily3,
        sectionStep: 0,
        geometryRevision: 0,
        sceneSessionRevision: model.sphereSceneSessionRevision,
        snapshot: snapshot
      )
    )

    model.applyMagnification(.nan)
    #expect(model.modelScale == 1)
    #expect(model.generationError == "Rejected a non-finite presentation scale.")
    model.generationError = nil

    model.applyRotation(delta: SIMD2(.infinity, 0))
    #expect(model.modelRotation == .zero)
    #expect(model.generationError == "Rejected a non-finite presentation rotation.")

    model.modelScale = .nan
    #expect(!model.spherePoseIsValid)
    #expect(
      !model.acknowledgeSpherePresentation(
        stage: .proxyFamily3,
        regime: .hover,
        navigationRevision: model.sphereNavigationRevision,
        navigationStepCount: model.sphereNavigation.stepCount,
        addressFingerprint: model.sphereAddressToken,
        poseFingerprint: model.spherePoseToken,
        renderFingerprint: snapshot.fingerprint,
        renderInstallationRevision: model.sphereRenderReceipt?.installationRevision ?? 0
      )
    )
  }

  @Test
  func modelRotationMatchesEachRegimesAppliedDegreesOfFreedom() {
    let model = AppModel(arguments: ["HeveaVision"], environment: [:])

    model.applyRotation(delta: SIMD2(100, .pi))
    #expect(model.spherePoseIsValid)
    #expect((-Float.pi...Float.pi).contains(model.modelRotation.x))
    #expect(model.modelRotation.y == 0)
    #expect(model.spherePresentationRotation.y == 0)

    model.selectSphereRegime(.atlas)
    model.setRotation(SIMD2(0.4, .pi))
    #expect(model.modelRotation.y == .pi / 2)
    #expect(model.spherePresentationRotation.y == .pi / 2)

    model.selectSphereRegime(.hover)
    #expect(model.modelRotation.y == 0)
    #expect(model.spherePresentationRotation.y == 0)

    // Even a direct state mutation cannot make a local-gauge receipt claim ignored pitch.
    model.modelRotation.y = 0.3
    #expect(model.spherePresentationRotation.y == 0)
    #expect(model.spherePoseToken.hasSuffix(",+0]"))
  }

  @Test
  func torusInspectionPitchDoesNotDependOnTheRememberedSphereGauge() {
    let model = AppModel(
      arguments: [
        "HeveaVision", "--hevea-automation", "--hevea-scenario", "torus-mission-control",
      ],
      environment: [:]
    )
    #expect(model.selectedExhibit == .flatTorus)
    #expect(model.selectedSphereRegime == .habitat)

    model.setRotation(SIMD2(0.35, -0.42))
    #expect(model.modelRotation.y == -0.42)

    model.selectExhibit(.reducedSphere)
    #expect(model.spherePresentationRotation.y == 0)
    #expect(model.spherePoseToken.hasSuffix(",+0]"))
  }
}
