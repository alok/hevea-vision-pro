import HeveaCore
import RealityKit
import SwiftUI

@MainActor
struct ImmersiveLabView: View {
  private static let stageAttachmentID = "hevea-stage-hud"
  private static let legendAttachmentID = "hevea-legend-hud"
  private static let sampleAttachmentID = "hevea-sample-hud"
  private static let controlsAttachmentID = "hevea-controls-hud"
  private static let insideEscapeAttachmentID = "hevea-inside-escape-hud"

  @Environment(AppModel.self) private var model
  @Environment(\.openWindow) private var openWindow
  @State private var scene = HeveaSceneController()
  @State private var dragStartRotation: SIMD2<Float>?
  @State private var magnifyStartScale: Float?

  var body: some View {
    RealityView { content, attachments in
      if scene.root.parent == nil {
        content.add(scene.root)
      }
      attachHUD(to: &content, attachments: attachments)
      applyPresentation()
    } update: { content, attachments in
      attachHUD(to: &content, attachments: attachments)
      applyPresentation()
    } attachments: {
      Attachment(id: Self.stageAttachmentID) {
        StageHUD()
          .environment(model)
      }
      Attachment(id: Self.legendAttachmentID) {
        LegendHUD()
          .environment(model)
      }
      Attachment(id: Self.sampleAttachmentID) {
        SampleHUD()
          .environment(model)
      }
      Attachment(id: Self.controlsAttachmentID) {
        LabControlsHUD()
          .environment(model)
      }
      Attachment(id: Self.insideEscapeAttachmentID) {
        if shouldShowEscapeHUD {
          InsideEscapeHUD()
            .environment(model)
        }
      }
    }
    .gesture(surfaceTapGesture)
    .gesture(surfaceDragGesture)
    .gesture(surfaceMagnifyGesture)
    .task(id: generationRequest) {
      let request = generationRequest
      await regenerateSurface(for: request)
    }
    .task(id: spherePresentationRequest) {
      guard let request = spherePresentationRequest else { return }
      applySpherePresentationAndAcknowledge(request)
    }
    .onAppear {
      model.beginSphereSceneSession()
      model.immersiveSpaceState = .open
    }
    .onDisappear {
      model.endSphereSceneSession()
      model.immersiveSpaceState = .closed
      openWindow(id: AppModel.mainWindowID)
    }
    .accessibilityLabel("Fully immersive Hevea geometry laboratory")
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("immersive-lab")
  }

  private var generationRequest: GenerationRequest {
    GenerationRequest(
      exhibit: model.selectedExhibit,
      torusStage: model.selectedStage,
      sphereStage: model.selectedSphereStage,
      overlay: model.selectedOverlay,
      sectionStep: Int((model.sectionAmount * 12).rounded()),
      revision: model.geometryRevision,
      sphereSceneSessionRevision: model.sphereSceneSessionRevision
    )
  }

  private var shouldShowEscapeHUD: Bool {
    (model.selectedExhibit == .flatTorus && model.presentation == .inside)
      || (model.selectedExhibit == .reducedSphere && model.selectedSphereRegime == .interior)
  }

  private var spherePresentationRequest: SpherePresentationRequest? {
    guard model.selectedExhibit == .reducedSphere,
      let renderReceipt = model.sphereRenderReceipt
    else {
      return nil
    }
    return SpherePresentationRequest(
      requestedStage: model.selectedSphereStage,
      renderReceipt: renderReceipt,
      regime: model.selectedSphereRegime,
      navigation: model.sphereNavigation,
      navigationRevision: model.sphereNavigationRevision,
      addressFingerprint: model.sphereAddressToken,
      poseFingerprint: model.spherePoseToken,
      scale: model.modelScale,
      rotation: model.spherePresentationRotation
    )
  }

  private var surfaceTapGesture: some Gesture {
    SpatialTapGesture()
      .targetedToAnyEntity()
      .onEnded { value in
        guard model.selectedExhibit == .flatTorus,
          value.entity.name == HeveaRealityBridge.surfaceEntityName
        else { return }
        let location = value.convert(value.location3D, from: .local, to: value.entity)
        model.selectedSample = scene.selectSurface(
          at: SIMD3(
            Float(location.x),
            Float(location.y),
            Float(location.z)
          ))
      }
  }

  private var surfaceDragGesture: some Gesture {
    DragGesture()
      .targetedToAnyEntity()
      .onChanged { value in
        guard
          value.entity.name == HeveaRealityBridge.surfaceEntityName
            || SphereRealityBridge.isSurfaceEntity(value.entity)
        else { return }
        let start = dragStartRotation ?? model.modelRotation
        if dragStartRotation == nil {
          dragStartRotation = start
        }
        model.setRotation(
          start
            + SIMD2(
              Float(value.translation3D.x) * 0.006,
              Float(value.translation3D.y) * 0.006
            )
        )
      }
      .onEnded { _ in
        dragStartRotation = nil
      }
  }

  private var surfaceMagnifyGesture: some Gesture {
    MagnifyGesture()
      .targetedToAnyEntity()
      .onChanged { value in
        guard
          value.entity.name == HeveaRealityBridge.surfaceEntityName
            || SphereRealityBridge.isSurfaceEntity(value.entity)
        else { return }
        let start = magnifyStartScale ?? model.modelScale
        if magnifyStartScale == nil {
          magnifyStartScale = start
        }
        model.applyMagnification(start * Float(value.magnification))
      }
      .onEnded { _ in
        magnifyStartScale = nil
      }
  }

  private func regenerateSurface(for request: GenerationRequest) async {
    guard generationRequest == request else { return }
    model.generationError = nil
    do {
      switch request.exhibit {
      case .reducedSphere:
        let snapshot = try await scene.regenerateSphere(
          stage: request.sphereStage,
          sectionAmount: Double(request.sectionStep) / 12
        )
        try Task.checkCancellation()
        _ = model.acknowledgeSphereRender(
          stage: request.sphereStage,
          sectionStep: request.sectionStep,
          geometryRevision: request.revision,
          sceneSessionRevision: request.sphereSceneSessionRevision,
          snapshot: snapshot
        )
      case .flatTorus:
        let snapshot = try await scene.regenerate(
          stage: request.torusStage,
          overlay: request.overlay,
          sectionAmount: Double(request.sectionStep) / 12
        )
        try Task.checkCancellation()
        guard generationRequest == request else { return }
        model.diagnostics = snapshot
      }
      try Task.checkCancellation()

      let shouldSelectAutomationSample =
        model.automationScenario != nil
        && request.exhibit == .flatTorus
        && generationRequest == request
      if shouldSelectAutomationSample {
        model.selectedSample = scene.selectDeterministicSample(
          index: model.automationRepetition
        )
      }
    } catch is CancellationError {
      return
    } catch {
      guard generationRequest == request else { return }
      model.generationError = String(describing: error)
    }
  }

  private func applyPresentation() {
    switch model.selectedExhibit {
    case .reducedSphere:
      guard let renderReceipt = model.sphereRenderReceipt else { return }
      _ = scene.applySpherePresentation(
        regime: model.selectedSphereRegime,
        navigation: model.sphereNavigation,
        stage: renderReceipt.stage,
        scale: model.modelScale,
        rotation: model.spherePresentationRotation,
        showUnitSphereGhost: true
      )
    case .flatTorus:
      scene.applyPresentation(
        presentation: model.presentation,
        scale: model.modelScale,
        rotation: model.modelRotation,
        showDomainFloor: model.showDomainFloor,
        showGaussSphere: model.showGaussSphere
      )
    }
  }

  /// Applies the captured intrinsic pose and issues an acknowledgment in one
  /// main-actor transaction. UI automation waits for this receipt after every
  /// walk-pad step instead of inferring a RealityKit update from SwiftUI text.
  private func applySpherePresentationAndAcknowledge(_ request: SpherePresentationRequest) {
    guard !Task.isCancelled,
      model.sphereRenderIsCurrent,
      model.sphereRenderReceipt == request.renderReceipt,
      request.requestedStage == request.renderReceipt.stage
    else {
      return
    }

    guard
      scene.applySpherePresentation(
        regime: request.regime,
        navigation: request.navigation,
        stage: request.renderReceipt.stage,
        scale: request.scale,
        rotation: request.rotation,
        showUnitSphereGhost: true
      )
    else {
      model.generationError = "Could not evaluate the requested intrinsic sphere address."
      return
    }
    guard !Task.isCancelled else { return }
    _ = model.acknowledgeSpherePresentation(
      stage: request.requestedStage,
      regime: request.regime,
      navigationRevision: request.navigationRevision,
      navigationStepCount: request.navigation.stepCount,
      addressFingerprint: request.addressFingerprint,
      poseFingerprint: request.poseFingerprint,
      renderFingerprint: request.renderReceipt.fingerprint,
      renderInstallationRevision: request.renderReceipt.installationRevision
    )
  }

  private func attachHUD(
    to content: inout RealityViewContent,
    attachments: RealityViewAttachments
  ) {
    attach(
      Self.stageAttachmentID,
      position: [-0.68, 1.73, -1.25],
      to: &content,
      attachments: attachments
    )
    attach(
      Self.legendAttachmentID,
      position: [0.68, 1.70, -1.25],
      to: &content,
      attachments: attachments
    )
    attach(
      Self.sampleAttachmentID,
      position: [0.68, 1.12, -1.20],
      to: &content,
      attachments: attachments
    )
    attach(
      Self.controlsAttachmentID,
      position: [0, 1.02, -1.18],
      to: &content,
      attachments: attachments
    )
    attach(
      Self.insideEscapeAttachmentID,
      position: [0, 1.28, -0.65],
      to: &content,
      attachments: attachments
    )
  }

  private func attach(
    _ identifier: String,
    position: SIMD3<Float>,
    to content: inout RealityViewContent,
    attachments: RealityViewAttachments
  ) {
    guard let entity = attachments.entity(for: identifier) else { return }
    entity.name = identifier
    entity.position = position
    if entity.parent == nil {
      content.add(entity)
    }
  }
}

private struct GenerationRequest: Hashable {
  let exhibit: HeveaExhibit
  let torusStage: HeveaStage
  let sphereStage: SphereStage
  let overlay: DiagnosticOverlay
  let sectionStep: Int
  let revision: Int
  let sphereSceneSessionRevision: UInt64
}

private struct SpherePresentationRequest: Equatable {
  let requestedStage: SphereStage
  let renderReceipt: SphereRenderReceipt
  let regime: SphereRegime
  let navigation: SphereNavigationState
  let navigationRevision: Int
  let addressFingerprint: String
  let poseFingerprint: String
  let scale: Float
  let rotation: SIMD2<Float>
}

private struct LegendHUD: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    VStack(alignment: .leading, spacing: 11) {
      if model.selectedExhibit == .reducedSphere {
        HStack {
          Image(systemName: model.selectedSphereRegime.systemImage)
            .foregroundStyle(.yellow)
          VStack(alignment: .leading, spacing: 1) {
            Text("ACTIVE NSA GAUGE")
              .font(.caption2.weight(.heavy))
              .tracking(1.1)
              .foregroundStyle(.yellow)
            Text(model.selectedSphereRegime.gaugeTitle)
              .font(.headline)
          }
        }

        HStack(spacing: 14) {
          Readout(label: "intrinsic diameter", value: "π")
          Readout(
            label: "ambient bound",
            value: (2 * model.sphereDiagnostics.declaredContainingRadius).formatted(
              .number.precision(.fractionLength(2))
            )
          )
          Readout(
            label: "ratio",
            value: model.sphereReductionRatio.formatted(
              .number.precision(.fractionLength(2))
            ) + "×"
          )
        }

        Text(model.selectedSphereRegime.explanation)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        Text(
          "Global shadow and local walkability are coordinated views, not one fixed physical scale."
        )
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.yellow)

        ClaimBadge(claim: .heveaVisionExperiment)
      } else {
        HStack {
          Image(systemName: model.selectedOverlay.systemImage)
            .foregroundStyle(.cyan)
          VStack(alignment: .leading, spacing: 1) {
            Text("VISIBLE EVIDENCE")
              .font(.caption2.weight(.heavy))
              .tracking(1.1)
              .foregroundStyle(.cyan)
            Text(model.selectedOverlay.rawValue)
              .font(.headline)
          }
        }

        if model.selectedOverlay == .metricResidual || model.selectedOverlay == .normalVariation {
          HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
              Rectangle()
                .fill(legendColor(index: index, normal: model.selectedOverlay == .normalVariation))
                .frame(height: 9)
            }
          }
          .clipShape(Capsule())

          HStack {
            Text("lower")
            Spacer()
            Text("98th percentile+")
          }
          .font(.caption2)
          .foregroundStyle(.secondary)
        }

        Text(model.selectedOverlay.explanation)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        ClaimBadge(claim: model.currentClaim)
      }
    }
    .frame(width: 330, alignment: .leading)
    .padding(17)
    .glassBackgroundEffect(in: .rect(cornerRadius: 22))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("immersive-legend-hud")
  }

  private func legendColor(index: Int, normal: Bool) -> Color {
    let metric: [Color] = [
      Color(red: 0.02, green: 0.05, blue: 0.16),
      Color(red: 0.08, green: 0.22, blue: 0.42),
      Color(red: 0.09, green: 0.45, blue: 0.57),
      Color(red: 0.30, green: 0.67, blue: 0.51),
      Color(red: 0.70, green: 0.79, blue: 0.34),
      Color(red: 0.98, green: 0.72, blue: 0.20),
      Color(red: 0.96, green: 0.38, blue: 0.23),
    ]
    let normalPalette: [Color] = [.indigo, .purple, .purple, .pink, .orange, .yellow, .white]
    return (normal ? normalPalette : metric)[index]
  }
}
