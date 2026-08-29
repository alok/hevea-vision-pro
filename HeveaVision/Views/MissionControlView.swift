import HeveaCore
import SwiftUI

struct MissionControlView: View {
  @Environment(AppModel.self) private var model
  @Environment(\.openImmersiveSpace) private var openImmersiveSpace
  @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
  @Environment(\.dismissWindow) private var dismissWindow

  var body: some View {
    @Bindable var model = model

    ZStack {
      observatoryBackground

      VStack(spacing: 0) {
        header
          .padding(.horizontal, 34)
          .padding(.top, 28)
          .padding(.bottom, 18)

        Divider().opacity(0.22)

        HStack(alignment: .top, spacing: 22) {
          VStack(spacing: 18) {
            stageCard
            overlayCard
          }
          .frame(maxWidth: .infinity)

          VStack(spacing: 18) {
            researchInstrument
            immersionCard
          }
          .frame(width: 370)
        }
        .padding(26)
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("mission-control")
    .task {
      await openAutomationScenarioIfNeeded()
    }
  }

  private var observatoryBackground: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.025, green: 0.045, blue: 0.09),
          Color(red: 0.055, green: 0.025, blue: 0.10),
          Color(red: 0.015, green: 0.085, blue: 0.12),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      Circle()
        .fill(.cyan.opacity(0.10))
        .frame(width: 520, height: 520)
        .blur(radius: 90)
        .offset(x: -360, y: 250)

      Circle()
        .fill(.purple.opacity(0.13))
        .frame(width: 440, height: 440)
        .blur(radius: 110)
        .offset(x: 420, y: -280)
    }
    .ignoresSafeArea()
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 18) {
      ZStack {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .fill(.white.opacity(0.08))
        Image(systemName: "tornado")
          .font(.system(size: 32, weight: .medium))
          .foregroundStyle(.cyan)
      }
      .frame(width: 62, height: 62)
      .overlay {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .strokeBorder(.white.opacity(0.12))
      }

      VStack(alignment: .leading, spacing: 4) {
        Text("HEVEA VISION")
          .font(.system(.title, design: .rounded, weight: .bold))
          .tracking(1.7)
        Text("A spatial observatory for convex integration")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Spacer()

      ClaimBadge(claim: model.currentClaim)
    }
  }

  private var stageCard: some View {
    InstrumentCard(
      eyebrow: "CONSTRUCTION",
      title: "Stage rail",
      subtitle:
        "Move from the exact short torus input through three deliberately compressed explanatory corrugations."
    ) {
      VStack(spacing: 16) {
        HStack(spacing: 10) {
          ForEach(Array(HeveaStage.allCases.enumerated()), id: \.element) { index, stage in
            Button {
              model.selectStage(stage)
            } label: {
              VStack(spacing: 8) {
                ZStack {
                  Circle()
                    .fill(stage == model.selectedStage ? Color.cyan : Color.white.opacity(0.10))
                    .frame(width: 34, height: 34)
                  Text("\(index)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(stage == model.selectedStage ? Color.black : Color.white)
                }

                Text(stage.shortDisplayName.replacingOccurrences(of: "Proxy ", with: ""))
                  .font(.caption2.weight(.semibold))
                  .lineLimit(1)
                  .foregroundStyle(stage == model.selectedStage ? .primary : .secondary)
              }
              .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select \(stage.displayName)")
            .accessibilityIdentifier("stage-\(stage.rawValue)")

            if index < HeveaStage.allCases.count - 1 {
              Capsule()
                .fill(
                  index < model.stageIndex ? Color.cyan.opacity(0.8) : Color.white.opacity(0.14)
                )
                .frame(width: 34, height: 3)
                .offset(y: -11)
            }
          }
        }

        HStack(alignment: .top, spacing: 12) {
          Image(
            systemName: model.selectedStage == .shortTorus ? "checkmark.seal.fill" : "waveform.path"
          )
          .foregroundStyle(model.selectedStage == .shortTorus ? .cyan : .orange)
          .font(.title3)
          VStack(alignment: .leading, spacing: 4) {
            Text(model.selectedStage.displayName)
              .font(.headline)
            Text(model.selectedStage.explanation)
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer()
        }
        .padding(14)
        .background(
          .black.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("stage-card")
  }

  private var overlayCard: some View {
    InstrumentCard(
      eyebrow: "VISIBLE EVIDENCE",
      title: "Diagnostic overlay",
      subtitle: model.selectedOverlay.explanation
    ) {
      HStack(spacing: 9) {
        ForEach(DiagnosticOverlay.allCases) { overlay in
          Button {
            model.selectOverlay(overlay)
          } label: {
            VStack(spacing: 8) {
              Image(systemName: overlay.systemImage)
                .font(.title3)
              Text(overlay.shortLabel)
                .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(overlay == model.selectedOverlay ? Color.black : Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
              overlay == model.selectedOverlay ? Color.cyan : Color.white.opacity(0.07),
              in: RoundedRectangle(cornerRadius: 13, style: .continuous)
            )
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Show \(overlay.rawValue)")
          .accessibilityIdentifier("overlay-\(overlay.shortLabel.lowercased())")
        }
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("overlay-card")
  }

  private var researchInstrument: some View {
    InstrumentCard(
      eyebrow: "HV EXPERIMENT",
      title: "C1 scale microscope",
      subtitle: "How much do nearby unit normals turn as the sampling scale changes?"
    ) {
      VStack(spacing: 15) {
        HStack(spacing: 12) {
          DiagnosticValue(
            label: "Median turn",
            value: model.diagnostics.vertexCount == 0
              ? "pending" : angle(model.diagnostics.microscopeMedianDegrees),
            tint: .cyan
          )
          DiagnosticValue(
            label: "95th percentile",
            value: model.diagnostics.vertexCount == 0
              ? "pending" : angle(model.diagnostics.microscopeP95Degrees),
            tint: .purple
          )
        }

        HStack {
          Label(
            model.diagnostics.vertexCount == 0
              ? "Geometry will be measured in the immersive lab"
              : "\(model.diagnostics.vertexCount.formatted()) vertices · \(model.diagnostics.triangleCount.formatted()) triangles",
            systemImage: "scope"
          )
          .font(.caption)
          .foregroundStyle(.secondary)
          Spacer()
        }

        Text(
          "A fitted scale slope is descriptive finite-mesh evidence. It is not a regularity or fractal-dimension theorem."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.purple.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("research-instrument")
  }

  private var immersionCard: some View {
    InstrumentCard(
      eyebrow: "FULL IMMERSION",
      title: model.immersiveSpaceState == .open ? "The lab is open" : "Enter the observatory",
      subtitle: model.currentClaimExplanation
    ) {
      VStack(spacing: 12) {
        Button {
          Task { await toggleImmersion() }
        } label: {
          HStack(spacing: 12) {
            Image(systemName: immersiveButtonIcon)
              .font(.title3)
            Text(immersiveButtonLabel)
              .font(.headline)
            Spacer()
            Image(systemName: "arrow.up.forward")
          }
          .padding(.horizontal, 18)
          .frame(height: 56)
          .background(.cyan, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
          .foregroundStyle(.black)
        }
        .buttonStyle(.plain)
        .disabled(model.immersiveSpaceState == .inTransition)
        .accessibilityHint("Opens or closes the fully immersive Hevea laboratory")
        .accessibilityIdentifier("toggle-immersive-lab")

        HStack {
          Label("visionOS simulator", systemImage: "visionpro")
          Spacer()
          Text("DEVICE TEST PENDING")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.orange)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("immersion-card")
  }

  private var immersiveButtonLabel: String {
    switch model.immersiveSpaceState {
    case .closed: "Enter Immersive Lab"
    case .inTransition: "Changing space…"
    case .open: "Exit Immersive Lab"
    }
  }

  private var immersiveButtonIcon: String {
    switch model.immersiveSpaceState {
    case .closed: "view.3d"
    case .inTransition: "hourglass"
    case .open: "rectangle.portrait.and.arrow.right"
    }
  }

  private func angle(_ degrees: Double) -> String {
    degrees.formatted(.number.precision(.fractionLength(1))) + "°"
  }

  private func toggleImmersion() async {
    guard model.immersiveSpaceState != .inTransition else { return }

    switch model.immersiveSpaceState {
    case .closed:
      model.immersiveSpaceState = .inTransition
      let result = await openImmersiveSpace(id: AppModel.immersiveSpaceID)
      switch result {
      case .opened:
        // `ImmersiveLabView.onAppear` is the lifecycle authority.
        dismissWindow(id: AppModel.mainWindowID)
      case .userCancelled, .error:
        model.immersiveSpaceState = .closed
      @unknown default:
        model.immersiveSpaceState = .closed
      }
    case .open:
      model.immersiveSpaceState = .inTransition
      await dismissImmersiveSpace()
    // `ImmersiveLabView.onDisappear` is the lifecycle authority.
    case .inTransition:
      break
    }
  }

  private func openAutomationScenarioIfNeeded() async {
    guard model.automationScenario != nil,
      model.automationScenario != "mission-control",
      !model.automationDidRequestImmersion,
      model.immersiveSpaceState == .closed
    else { return }

    model.automationDidRequestImmersion = true
    model.immersiveSpaceState = .inTransition
    let result = await openImmersiveSpace(id: AppModel.immersiveSpaceID)
    if case .opened = result {
      dismissWindow(id: AppModel.mainWindowID)
    } else {
      model.immersiveSpaceState = .closed
    }
  }
}

private struct InstrumentCard<Content: View>: View {
  let eyebrow: String
  let title: String
  let subtitle: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 15) {
      VStack(alignment: .leading, spacing: 5) {
        Text(eyebrow)
          .font(.caption2.weight(.heavy))
          .tracking(1.2)
          .foregroundStyle(.cyan)
        Text(title)
          .font(.title3.weight(.semibold))
        Text(subtitle)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      content
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
    }
  }
}

private struct DiagnosticValue: View {
  let label: String
  let value: String
  let tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.title3.monospacedDigit().weight(.semibold))
        .foregroundStyle(tint)
    }
    .padding(13)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
  }
}
