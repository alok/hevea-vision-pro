import HeveaCore
import SwiftUI

struct StageHUD: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      header
      if model.selectedExhibit == .reducedSphere {
        sphereControls
      } else {
        torusControls
      }
    }
    .frame(width: 330, alignment: .leading)
    .padding(17)
    .glassBackgroundEffect(in: .rect(cornerRadius: 22))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("immersive-stage-hud")
  }

  private var header: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(model.selectedExhibit == .reducedSphere ? "REDUCED SPHERE" : "TORUS ARCHIVE")
          .font(.caption2.weight(.heavy))
          .tracking(1.2)
          .foregroundStyle(model.selectedExhibit == .reducedSphere ? .yellow : .cyan)
        Text(stageShortName)
          .font(.headline)
      }
      Spacer()
      ClaimBadge(claim: stageClaim)
      resetButton
      exitButton
    }
  }

  private var stageShortName: String {
    guard model.selectedExhibit == .reducedSphere else {
      return model.selectedStage.shortDisplayName
    }
    return model.renderedSphereStage?.shortDisplayName ?? "No sphere mesh installed"
  }

  private var stageClaim: ClaimClass {
    guard model.selectedExhibit == .reducedSphere else {
      return model.selectedStage.claimClass
    }
    return model.renderedSphereStage?.claimClass ?? .heveaVisionExperiment
  }

  private var resetButton: some View {
    Button {
      model.resetLab()
    } label: {
      Image(systemName: "arrow.counterclockwise")
    }
    .buttonStyle(.bordered)
    .accessibilityLabel("Reset lab")
    .accessibilityIdentifier("reset-lab")
  }

  private var exitButton: some View {
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

  private var sphereControls: some View {
    Group {
      HStack(spacing: 7) {
        ForEach(Array(SphereStage.allCases.enumerated()), id: \.element) { index, stage in
          sphereStageButton(stage, index: index)
        }
      }

      Text(model.sphereRenderStatusText)
        .font(.caption.monospacedDigit().weight(.semibold))
        .foregroundStyle(model.sphereRenderIsCurrent ? .green : .yellow)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("sphere-render-state")

      Text(renderedSphereRidgeSummary)
        .font(.caption.monospacedDigit().weight(.semibold))
        .foregroundStyle(.yellow)

      VStack(alignment: .leading, spacing: 4) {
        Text("Gauge · \(model.selectedSphereRegime.rawValue)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("sphere-regime-state")
        HStack(spacing: 4) {
          ForEach(SphereRegime.allCases) { regime in
            sphereRegimeButton(regime)
          }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sphere-regime-picker")
      }

      Text(renderedSphereClaimCeiling)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      Text(model.spherePresentationStatusText)
        .font(.caption2.monospacedDigit().weight(.semibold))
        .foregroundStyle(model.spherePresentationIsCurrent ? .green : .yellow)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("sphere-presentation-state")

      Text(model.sphereAddressToken)
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.secondary)
        .lineLimit(3)
        .minimumScaleFactor(0.7)
        .accessibilityIdentifier("sphere-address-token-state")
    }
  }

  private var renderedSphereRidgeSummary: String {
    guard let renderedStage = model.renderedSphereStage else {
      return "Requested schedule · \(model.sphereRidgeSummary)"
    }
    return model.sphereRidgeSummary(for: renderedStage)
  }

  private var renderedSphereClaimCeiling: String {
    guard let renderedStage = model.renderedSphereStage else {
      return "No claim is attached until the requested mesh is installed."
    }
    return renderedStage.claimCeiling
  }

  private func sphereStageButton(_ stage: SphereStage, index: Int) -> some View {
    Button {
      model.selectSphereStage(stage)
    } label: {
      Text("\(index)")
        .font(.caption.bold())
        .frame(width: 31, height: 31)
        .background(
          stage == model.selectedSphereStage ? Color.yellow : Color.white.opacity(0.12),
          in: Circle()
        )
        .foregroundStyle(stage == model.selectedSphereStage ? .black : .white)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(stage.displayName)
    .accessibilityIdentifier("immersive-sphere-stage-\(stage.rawValue)")
  }

  private func sphereRegimeButton(_ regime: SphereRegime) -> some View {
    Button {
      model.selectSphereRegime(regime)
    } label: {
      Image(systemName: regime.systemImage)
        .font(.caption.weight(.semibold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 7)
        .background(
          regime == model.selectedSphereRegime ? Color.yellow : Color.white.opacity(0.08),
          in: RoundedRectangle(cornerRadius: 8)
        )
        .foregroundStyle(regime == model.selectedSphereRegime ? .black : .white)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(regime.rawValue)
    .accessibilityIdentifier("immersive-sphere-regime-\(regime.rawValue.lowercased())")
  }

  private var torusControls: some View {
    Group {
      HStack(spacing: 7) {
        ForEach(Array(HeveaStage.allCases.enumerated()), id: \.element) { index, stage in
          torusStageButton(stage, index: index)
        }
      }

      VStack(alignment: .leading, spacing: 4) {
        Text("View · \(model.presentation.rawValue)")
          .font(.caption2)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("presentation-state")
        HStack(spacing: 4) {
          ForEach(LabPresentation.allCases) { presentation in
            presentationButton(presentation)
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
  }

  private func torusStageButton(_ stage: HeveaStage, index: Int) -> some View {
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

  private func presentationButton(_ presentation: LabPresentation) -> some View {
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
