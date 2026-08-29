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
        if model.presentation == .inside {
          InsideEscapeHUD()
            .environment(model)
        }
      }
    }
    .gesture(surfaceTapGesture)
    .gesture(surfaceDragGesture)
    .gesture(surfaceMagnifyGesture)
    .task(id: generationRequest) {
      await regenerateSurface()
    }
    .onAppear {
      model.immersiveSpaceState = .open
    }
    .onDisappear {
      model.immersiveSpaceState = .closed
      openWindow(id: AppModel.mainWindowID)
    }
    .accessibilityLabel("Fully immersive Hevea geometry laboratory")
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("immersive-lab")
  }

  private var generationRequest: GenerationRequest {
    GenerationRequest(
      stage: model.selectedStage,
      overlay: model.selectedOverlay,
      sectionStep: Int((model.sectionAmount * 12).rounded()),
      revision: model.geometryRevision
    )
  }

  private var surfaceTapGesture: some Gesture {
    SpatialTapGesture()
      .targetedToAnyEntity()
      .onEnded { value in
        guard value.entity.name == HeveaRealityBridge.surfaceEntityName else { return }
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
        guard value.entity.name == HeveaRealityBridge.surfaceEntityName else { return }
        let start = dragStartRotation ?? model.modelRotation
        if dragStartRotation == nil {
          dragStartRotation = start
        }
        model.modelRotation =
          start
          + SIMD2(
            Float(value.translation3D.x) * 0.006,
            Float(value.translation3D.y) * 0.006
          )
        model.modelRotation.y = min(max(model.modelRotation.y, -.pi / 2), .pi / 2)
      }
      .onEnded { _ in
        dragStartRotation = nil
      }
  }

  private var surfaceMagnifyGesture: some Gesture {
    MagnifyGesture()
      .targetedToAnyEntity()
      .onChanged { value in
        guard value.entity.name == HeveaRealityBridge.surfaceEntityName else { return }
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

  private func regenerateSurface() async {
    model.generationError = nil
    do {
      let snapshot = try await scene.regenerate(
        stage: model.selectedStage,
        overlay: model.selectedOverlay,
        sectionAmount: Double(generationRequest.sectionStep) / 12
      )
      try Task.checkCancellation()
      model.diagnostics = snapshot

      if model.automationScenario != nil {
        model.selectedSample = scene.selectDeterministicSample(
          index: model.automationRepetition
        )
      }
    } catch is CancellationError {
      return
    } catch {
      model.generationError = String(describing: error)
    }
  }

  private func applyPresentation() {
    scene.applyPresentation(
      presentation: model.presentation,
      scale: model.modelScale,
      rotation: model.modelRotation,
      showDomainFloor: model.showDomainFloor,
      showGaussSphere: model.showGaussSphere
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
  let stage: HeveaStage
  let overlay: DiagnosticOverlay
  let sectionStep: Int
  let revision: Int
}

private struct StageHUD: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("CONSTRUCTION STAGE")
            .font(.caption2.weight(.heavy))
            .tracking(1.2)
            .foregroundStyle(.cyan)
          Text(model.selectedStage.shortDisplayName)
            .font(.headline)
        }
        Spacer()
        ClaimBadge(claim: model.selectedStage.claimClass)
        Button {
          model.resetLab()
        } label: {
          Image(systemName: "arrow.counterclockwise")
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Reset lab")
        .accessibilityIdentifier("reset-lab")
        Button(role: .cancel) {
          model.immersiveSpaceState = .inTransition
          Task { await dismissImmersiveSpace() }
        } label: {
          Image(systemName: "rectangle.portrait.and.arrow.right")
        }
        .buttonStyle(.borderedProminent)
        .tint(.cyan)
        .foregroundStyle(.black)
        .accessibilityLabel("Exit immersive lab")
        .accessibilityIdentifier("exit-immersive-lab")
      }

      HStack(spacing: 7) {
        ForEach(Array(HeveaStage.allCases.enumerated()), id: \.element) { index, stage in
          Button {
            model.selectStage(stage)
          } label: {
            Text("\(index)")
              .font(.caption.bold())
              .frame(width: 31, height: 31)
              .background(
                stage == model.selectedStage ? Color.cyan : Color.white.opacity(0.12),
                in: Circle()
              )
              .foregroundStyle(stage == model.selectedStage ? .black : .white)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(stage.displayName)
          .accessibilityIdentifier("immersive-stage-\(stage.rawValue)")
        }
      }

      VStack(alignment: .leading, spacing: 4) {
        Text("View · \(model.presentation.rawValue)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("presentation-state")
        HStack(spacing: 4) {
          ForEach(LabPresentation.allCases) { presentation in
            Button {
              model.presentation = presentation
            } label: {
              Text(presentation.rawValue)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                  presentation == model.presentation ? Color.cyan : Color.white.opacity(0.08),
                  in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .foregroundStyle(presentation == model.presentation ? .black : .white)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("presentation-\(presentation.rawValue.lowercased())")
            .accessibilityAddTraits(presentation == model.presentation ? .isSelected : [])
          }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("presentation-picker")
      }

      Text(model.selectedStage.explanation)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .frame(width: 330, alignment: .leading)
    .padding(17)
    .glassBackgroundEffect(in: .rect(cornerRadius: 22))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("immersive-stage-hud")
  }
}

private struct LegendHUD: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    VStack(alignment: .leading, spacing: 11) {
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

private struct SampleHUD: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Image(systemName: "scope")
          .foregroundStyle(.purple)
        Text("C1 SCALE MICROSCOPE")
          .font(.caption2.weight(.heavy))
          .tracking(1.05)
          .foregroundStyle(.purple)
      }

      if let sample = model.selectedSample {
        Text("Selected sample #\(sample.vertexIndex)")
          .font(.headline.monospacedDigit())

        HStack(spacing: 14) {
          Readout(label: "u", value: decimal(sample.u, places: 3))
          Readout(label: "v", value: decimal(sample.v, places: 3))
          Readout(
            label: "ω(p,1)",
            value: decimal(sample.normalVariation * 180 / .pi, places: 1) + "°"
          )
        }

        Readout(
          label: "metric residual",
          value: sample.metricResidual.formatted(.number.precision(.significantDigits(3)))
        )
      } else if let error = model.generationError {
        Label(error, systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(.orange)
      } else {
        Text("Tap the torus to synchronize one surface normal with its point on the Gauss sphere.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Text("Finite mesh only · no limiting-regularity theorem")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
    }
    .frame(width: 330, alignment: .leading)
    .padding(17)
    .glassBackgroundEffect(in: .rect(cornerRadius: 22))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("immersive-sample-hud")
  }

  private func decimal(_ value: Double, places: Int) -> String {
    value.formatted(.number.precision(.fractionLength(places)))
  }
}

private struct Readout: View {
  let label: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(label)
        .font(.caption2)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.caption.monospacedDigit().weight(.semibold))
    }
  }
}

private struct LabControlsHUD: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var model = model

    HStack(spacing: 15) {
      Menu {
        ForEach(DiagnosticOverlay.allCases) { overlay in
          Button {
            model.selectOverlay(overlay)
          } label: {
            Label(overlay.rawValue, systemImage: overlay.systemImage)
          }
        }
      } label: {
        Label(model.selectedOverlay.shortLabel, systemImage: model.selectedOverlay.systemImage)
      }
      .accessibilityIdentifier("immersive-overlay-menu")

      Divider().frame(height: 34)

      VStack(alignment: .leading, spacing: 2) {
        Text("Section \(Int(model.sectionAmount * 100))%")
          .font(.caption2.monospacedDigit())
          .foregroundStyle(.secondary)
        Slider(value: $model.sectionAmount, in: 0...0.8, step: 1 / 12)
          .frame(width: 125)
          .accessibilityIdentifier("section-slider")
      }

      Button {
        model.showDomainFloor.toggle()
      } label: {
        Image(systemName: model.showDomainFloor ? "grid.circle.fill" : "grid.circle")
      }
      .accessibilityLabel("Toggle parameter domain")

      Button {
        model.showGaussSphere.toggle()
      } label: {
        Image(systemName: model.showGaussSphere ? "circle.hexagongrid.fill" : "circle.hexagongrid")
      }
      .accessibilityLabel("Toggle Gauss sphere")

    }
    .padding(.horizontal, 20)
    .padding(.vertical, 13)
    .glassBackgroundEffect(in: .capsule)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("immersive-controls-hud")
  }
}

private struct InsideEscapeHUD: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

  var body: some View {
    HStack(spacing: 10) {
      Button {
        model.presentation = .outside
      } label: {
        Label("Return Outside", systemImage: "arrow.backward.circle.fill")
      }
      .buttonStyle(.borderedProminent)
      .tint(.cyan)
      .foregroundStyle(.black)
      .accessibilityIdentifier("return-outside")

      Button(role: .cancel) {
        model.immersiveSpaceState = .inTransition
        Task { await dismissImmersiveSpace() }
      } label: {
        Label("Exit Lab", systemImage: "rectangle.portrait.and.arrow.right")
      }
      .buttonStyle(.bordered)
      .accessibilityIdentifier("exit-inside-lab")
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 11)
    .glassBackgroundEffect(in: .capsule)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("inside-escape-hud")
  }
}
