import HeveaCore
import Testing

@testable import HeveaVision

@MainActor
struct SphereReceiptTests {
  @Test
  func renderReceiptNamesOnlyTheMeshThatWasActuallyInstalled() {
    let model = makeSceneModel()
    let family3 = sphereSnapshot(fingerprint: "family3-mesh")

    #expect(model.renderedSphereStage == nil)
    #expect(model.sphereRenderStatusText == "Rendering Family 3…")
    #expect(
      !model.acknowledgeSphereRender(
        stage: .proxyFamily3,
        sectionStep: 0,
        geometryRevision: 0,
        sceneSessionRevision: model.sphereSceneSessionRevision,
        snapshot: .pending
      )
    )
    #expect(
      model.acknowledgeSphereRender(
        stage: .proxyFamily3,
        sectionStep: 0,
        geometryRevision: 0,
        sceneSessionRevision: model.sphereSceneSessionRevision,
        snapshot: family3
      )
    )
    #expect(model.sphereRenderIsCurrent)
    #expect(model.renderedSphereStage == .proxyFamily3)
    #expect(model.sphereDiagnostics == family3)
    #expect(
      model.sphereRenderStatusText
        == "Rendered Family 3 · session 1 · install 1 · family3-mesh"
    )

    model.selectSphereStage(.proxyFamily2)

    #expect(!model.sphereRenderIsCurrent)
    #expect(model.renderedSphereStage == .proxyFamily3)
    #expect(
      model.sphereRenderStatusText
        == "Loading Family 2 · retaining Family 3 · session 1 · install 1 · family3-mesh"
    )
    #expect(
      !model.acknowledgeSphereRender(
        stage: .proxyFamily3,
        sectionStep: 0,
        geometryRevision: 0,
        sceneSessionRevision: model.sphereSceneSessionRevision,
        snapshot: sphereSnapshot(fingerprint: "obsolete")
      )
    )
    #expect(model.sphereRenderReceipt?.fingerprint == "family3-mesh")
  }

  @Test
  func sectionedRenderReceiptMustMatchTheDiscreteRequestedSection() {
    let model = makeSceneModel()
    #expect(
      model.acknowledgeSphereRender(
        stage: .proxyFamily3,
        sectionStep: 0,
        geometryRevision: 0,
        sceneSessionRevision: model.sphereSceneSessionRevision,
        snapshot: sphereSnapshot(fingerprint: "closed")
      )
    )

    model.sectionAmount = 0.5

    #expect(model.sphereSectionStep == 6)
    #expect(!model.sphereRenderIsCurrent)
    #expect(
      !model.acknowledgeSphereRender(
        stage: .proxyFamily3,
        sectionStep: 5,
        geometryRevision: 0,
        sceneSessionRevision: model.sphereSceneSessionRevision,
        snapshot: sphereSnapshot(fingerprint: "wrong-section")
      )
    )
    #expect(
      model.acknowledgeSphereRender(
        stage: .proxyFamily3,
        sectionStep: 6,
        geometryRevision: 0,
        sceneSessionRevision: model.sphereSceneSessionRevision,
        snapshot: sphereSnapshot(fingerprint: "section-six")
      )
    )
    #expect(model.sphereRenderIsCurrent)
  }

  @Test
  func reinstallingIdenticalGeometryIssuesANewSceneInstallationRevision() {
    let model = makeSceneModel()
    let snapshot = sphereSnapshot(fingerprint: "same-mesh")
    #expect(
      model.acknowledgeSphereRender(
        stage: .proxyFamily3,
        sectionStep: 0,
        geometryRevision: 0,
        sceneSessionRevision: model.sphereSceneSessionRevision,
        snapshot: snapshot
      )
    )
    let firstRevision = model.sphereRenderReceipt?.installationRevision
    acknowledgeCurrentPresentation(model, renderFingerprint: snapshot.fingerprint)

    #expect(
      model.acknowledgeSphereRender(
        stage: .proxyFamily3,
        sectionStep: 0,
        geometryRevision: 0,
        sceneSessionRevision: model.sphereSceneSessionRevision,
        snapshot: snapshot
      )
    )
    #expect(model.sphereRenderReceipt?.installationRevision == firstRevision.map { $0 + 1 })
    #expect(model.spherePresentationReceipt == nil)
    #expect(!model.spherePresentationIsCurrent)
  }

  @Test
  func presentationReceiptRequiresTheCurrentRenderGaugeAndFullAddress() {
    let model = makeSceneModel()
    let render = sphereSnapshot(fingerprint: "render-fingerprint-123")
    #expect(
      model.acknowledgeSphereRender(
        stage: .proxyFamily3,
        sectionStep: 0,
        geometryRevision: 0,
        sceneSessionRevision: model.sphereSceneSessionRevision,
        snapshot: render
      )
    )
    let addressToken = model.sphereAddressToken

    #expect(
      !model.acknowledgeSpherePresentation(
        stage: .proxyFamily3,
        regime: .habitat,
        navigationRevision: model.sphereNavigationRevision,
        navigationStepCount: model.sphereNavigation.stepCount,
        addressFingerprint: "wrong-address",
        poseFingerprint: model.spherePoseToken,
        renderFingerprint: render.fingerprint,
        renderInstallationRevision: model.sphereRenderReceipt?.installationRevision ?? 0
      )
    )
    #expect(
      model.acknowledgeSpherePresentation(
        stage: .proxyFamily3,
        regime: .habitat,
        navigationRevision: model.sphereNavigationRevision,
        navigationStepCount: model.sphereNavigation.stepCount,
        addressFingerprint: addressToken,
        poseFingerprint: model.spherePoseToken,
        renderFingerprint: render.fingerprint,
        renderInstallationRevision: model.sphereRenderReceipt?.installationRevision ?? 0
      )
    )
    #expect(model.spherePresentationIsCurrent)
    #expect(
      model.spherePresentationStatusText
        == "Presented Habitat · address step #0 · session 1 · install 1 · "
        + "pose \(model.spherePoseToken) · \(addressToken)"
    )
  }

  @Test
  func everyAuthoritativeSphereStateChangeInvalidatesPresentation() {
    let model = makeSceneModel()
    let render = sphereSnapshot(fingerprint: "installed")
    #expect(
      model.acknowledgeSphereRender(
        stage: .proxyFamily3,
        sectionStep: 0,
        geometryRevision: 0,
        sceneSessionRevision: model.sphereSceneSessionRevision,
        snapshot: render
      )
    )

    acknowledgeCurrentPresentation(model, renderFingerprint: render.fingerprint)
    model.selectSphereRegime(.atlas)
    #expect(model.spherePresentationReceipt == nil)

    acknowledgeCurrentPresentation(model, renderFingerprint: render.fingerprint)
    let tokenBeforeWalk = model.sphereAddressToken
    model.moveOnSphere(.forward)
    #expect(model.spherePresentationReceipt == nil)
    #expect(model.sphereAddressToken != tokenBeforeWalk)

    acknowledgeCurrentPresentation(model, renderFingerprint: render.fingerprint)
    model.resetLab()
    #expect(model.spherePresentationReceipt == nil)

    acknowledgeCurrentPresentation(model, renderFingerprint: render.fingerprint)
    model.selectSphereStage(.proxyFamily2)
    #expect(model.spherePresentationReceipt == nil)

    #expect(
      model.acknowledgeSphereRender(
        stage: .proxyFamily2,
        sectionStep: 0,
        geometryRevision: 1,
        sceneSessionRevision: model.sphereSceneSessionRevision,
        snapshot: sphereSnapshot(fingerprint: "family-two")
      )
    )
    acknowledgeCurrentPresentation(model, renderFingerprint: "family-two")
    model.selectExhibit(.flatTorus)
    #expect(model.spherePresentationReceipt == nil)
    #expect(!model.spherePresentationIsCurrent)
  }

  @Test
  func fullAddressTokenIsStableAcrossGaugeChanges() {
    let model = makeSceneModel()
    let token = model.sphereAddressToken

    for regime in SphereRegime.allCases {
      model.selectSphereRegime(regime)
      #expect(model.sphereAddressToken == token)
    }
  }

  @Test
  func sceneSessionsInvalidateReceiptsFromDestroyedRealityKitScenes() {
    let model = makeSceneModel()
    let firstSession = model.sphereSceneSessionRevision
    #expect(
      model.acknowledgeSphereRender(
        stage: .proxyFamily3,
        sectionStep: 0,
        geometryRevision: 0,
        sceneSessionRevision: firstSession,
        snapshot: sphereSnapshot(fingerprint: "first-scene")
      )
    )
    acknowledgeCurrentPresentation(model, renderFingerprint: "first-scene")

    model.endSphereSceneSession()
    #expect(!model.sphereSceneIsActive)
    #expect(model.sphereRenderReceipt == nil)
    #expect(model.spherePresentationReceipt == nil)
    #expect(
      model.sphereRenderStatusText
        == "Immersive renderer inactive · requested Family 3"
    )

    model.beginSphereSceneSession()
    #expect(model.sphereSceneSessionRevision == firstSession + 1)
    #expect(
      !model.acknowledgeSphereRender(
        stage: .proxyFamily3,
        sectionStep: 0,
        geometryRevision: 0,
        sceneSessionRevision: firstSession,
        snapshot: sphereSnapshot(fingerprint: "stale-scene")
      )
    )
  }

  @Test
  func scaleAndRotationChangesInvalidateTheAcknowledgedPose() {
    let model = makeSceneModel()
    #expect(
      model.acknowledgeSphereRender(
        stage: .proxyFamily3,
        sectionStep: 0,
        geometryRevision: 0,
        sceneSessionRevision: model.sphereSceneSessionRevision,
        snapshot: sphereSnapshot(fingerprint: "pose-mesh")
      )
    )
    acknowledgeCurrentPresentation(model, renderFingerprint: "pose-mesh")

    model.applyMagnification(1.4)
    #expect(model.spherePresentationReceipt == nil)

    acknowledgeCurrentPresentation(model, renderFingerprint: "pose-mesh")
    model.applyRotation(delta: SIMD2<Float>(0.2, -0.1))
    #expect(model.spherePresentationReceipt == nil)
  }

  @Test
  func sphereSectionCutRemovesPeriodicSeamBridgesAndPolePlaceholders() throws {
    let mesh = try SphereMeshGenerator.generate(stage: .proxyFamily3)
    let sectionAmount = 0.5
    let cut = sectionAmount * 0.28
    let visible = SphereRealityBridge.sectionedTriangleIndices(
      from: mesh,
      sectionAmount: sectionAmount
    )

    #expect(visible.count < mesh.triangleIndices.count)
    #expect(visible.count.isMultiple(of: 3))

    for offset in stride(from: 0, to: visible.count, by: 3) {
      let indices = visible[offset..<(offset + 3)].map(Int.init)
      let longitudes = indices.compactMap { index -> Double? in
        let position = mesh.positions[index]
        let radialSquared = position.x * position.x + position.y * position.y
        return radialSquared > 1e-16 ? mesh.textureCoordinates[index].x : nil
      }
      #expect(!longitudes.isEmpty)
      let minimum = try #require(longitudes.min())
      let maximum = try #require(longitudes.max())
      #expect(maximum - minimum <= 0.5)
      #expect(minimum >= cut)
    }
  }

  private func acknowledgeCurrentPresentation(
    _ model: AppModel,
    renderFingerprint: String
  ) {
    #expect(
      model.acknowledgeSpherePresentation(
        stage: model.selectedSphereStage,
        regime: model.selectedSphereRegime,
        navigationRevision: model.sphereNavigationRevision,
        navigationStepCount: model.sphereNavigation.stepCount,
        addressFingerprint: model.sphereAddressToken,
        poseFingerprint: model.spherePoseToken,
        renderFingerprint: renderFingerprint,
        renderInstallationRevision: model.sphereRenderReceipt?.installationRevision ?? 0
      )
    )
    #expect(model.spherePresentationIsCurrent)
  }

  private func sphereSnapshot(fingerprint: String) -> SphereDiagnosticSnapshot {
    SphereDiagnosticSnapshot(
      vertexCount: 32_514,
      triangleCount: 65_024,
      measuredContainingRadius: 0.39,
      declaredContainingRadius: 0.40,
      eulerCharacteristic: 2,
      seamResidual: 0,
      fingerprint: fingerprint
    )
  }

  private func makeSceneModel() -> AppModel {
    let model = AppModel(arguments: ["HeveaVision"], environment: [:])
    model.beginSphereSceneSession()
    return model
  }
}
