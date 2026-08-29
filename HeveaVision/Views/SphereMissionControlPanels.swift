import HeveaCore
import SwiftUI

struct SphereMissionControlPanels<ImmersionCard: View>: View {
  @Environment(AppModel.self) private var model
  let immersionCard: ImmersionCard

  var body: some View {
    HStack(alignment: .top, spacing: 22) {
      VStack(spacing: 18) {
        stageCard
        regimeCard
      }
      .frame(maxWidth: .infinity)

      VStack(spacing: 18) {
        addressCard
        immersionCard
      }
      .frame(width: 400)
    }
  }

  private var stageCard: some View {
    InstrumentCard(
      eyebrow: "THE REDUCTION",
      title: "Sphere construction rail",
      subtitle:
        "Exact round input, reconstructed short map, then three bounded explanatory corrugation families."
    ) {
      VStack(spacing: 14) {
        stageRail
        stageExplanation
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("sphere-stage-card")
  }

  private var stageRail: some View {
    HStack(spacing: 7) {
      ForEach(Array(SphereStage.allCases.enumerated()), id: \.element) { index, stage in
        Button {
          model.selectSphereStage(stage)
        } label: {
          VStack(spacing: 6) {
            Text("\(index)")
              .font(.caption.bold())
              .frame(width: 31, height: 31)
              .background(
                stage == model.selectedSphereStage
                  ? Color.yellow : Color.white.opacity(0.11),
                in: Circle()
              )
              .foregroundStyle(stage == model.selectedSphereStage ? .black : .white)
            Text(stage.shortDisplayName)
              .font(.caption2.weight(.semibold))
              .lineLimit(1)
              .foregroundStyle(stage == model.selectedSphereStage ? .primary : .secondary)
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select \(stage.displayName)")
        .accessibilityIdentifier("sphere-stage-\(stage.rawValue)")
      }
    }
  }

  private var stageExplanation: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(
        systemName: model.selectedSphereStage == .unitSphere
          ? "checkmark.seal.fill" : "waveform.path"
      )
      .foregroundStyle(model.selectedSphereStage == .unitSphere ? .cyan : .yellow)
      .font(.title3)
      VStack(alignment: .leading, spacing: 4) {
        Text("Requested · \(model.selectedSphereStage.displayName)")
          .font(.headline)
          .accessibilityIdentifier("sphere-window-stage-state")
        Text(model.sphereRidgeSummary)
          .font(.callout.monospacedDigit().weight(.semibold))
          .foregroundStyle(.yellow)
        Text(model.sphereRenderStatusText)
          .font(.caption.monospacedDigit().weight(.semibold))
          .foregroundStyle(model.sphereRenderIsCurrent ? .green : .yellow)
        if let renderedStage = model.renderedSphereStage, !model.sphereRenderIsCurrent {
          Text("Actually installed · \(renderedStage.displayName)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.orange)
        }
        Text(model.selectedSphereStage.claimCeiling)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer()
    }
    .padding(13)
    .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
  }

  private var regimeCard: some View {
    InstrumentCard(
      eyebrow: "CHOOSE A GAUGE",
      title: "Live in, on, above, or around it",
      subtitle: model.selectedSphereRegime.explanation
    ) {
      HStack(spacing: 8) {
        ForEach(SphereRegime.allCases) { regime in
          regimeButton(regime)
        }
      }
      Text(
        "NSA gauge: as radius becomes infinitesimal, the global shadow collapses while "
          + "positive-length standard paths retain their standard intrinsic length. "
          + "Atlas and Habitat coordinate two honest scales."
      )
      .font(.caption)
      .foregroundStyle(.secondary)
      .padding(11)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("sphere-regime-card")
  }

  private func regimeButton(_ regime: SphereRegime) -> some View {
    Button {
      model.selectSphereRegime(regime)
    } label: {
      VStack(spacing: 7) {
        Image(systemName: regime.systemImage)
          .font(.title3)
        Text(regime.rawValue)
          .font(.caption.weight(.semibold))
      }
      .foregroundStyle(regime == model.selectedSphereRegime ? .black : .white)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      .background(
        regime == model.selectedSphereRegime ? Color.yellow : Color.white.opacity(0.07),
        in: RoundedRectangle(cornerRadius: 13)
      )
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("sphere-regime-\(regime.rawValue.lowercased())")
  }

  private var addressCard: some View {
    InstrumentCard(
      eyebrow: "HV EXPERIMENT",
      title: "Intrinsic address",
      subtitle: "Navigation lives on S². RealityKit world position is only the current gauge."
    ) {
      VStack(spacing: 12) {
        addressReadouts
        walkControls
        altitudeAndRouteControls
        addressFooter
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("sphere-address-card")
  }

  private var addressReadouts: some View {
    HStack(spacing: 9) {
      DiagnosticValue(
        label: "latitude",
        value: degree(model.sphereLatitudeDegrees),
        tint: .yellow
      )
      DiagnosticValue(
        label: "longitude",
        value: degree(model.sphereLongitudeDegrees),
        tint: .cyan
      )
      DiagnosticValue(
        label: "walked",
        value: model.sphereNavigation.traversedIntrinsicDistance.formatted(
          .number.precision(.fractionLength(2))
        ),
        tint: .orange
      )
    }
  }

  private var walkControls: some View {
    HStack(spacing: 8) {
      Button {
        model.turnOnSphere(by: -.pi / 12)
      } label: {
        Image(systemName: "arrow.counterclockwise")
      }
      .accessibilityLabel("Turn left")
      .accessibilityIdentifier("sphere-turn-left")

      Button {
        model.moveOnSphere(.left)
      } label: {
        Image(systemName: "arrow.left")
      }
      .accessibilityLabel("Walk left")
      .accessibilityIdentifier("sphere-walk-left")

      VStack(spacing: 5) {
        Button {
          model.moveOnSphere(.forward)
        } label: {
          Image(systemName: "arrow.up")
        }
        .accessibilityLabel("Walk forward")
        .accessibilityIdentifier("sphere-walk-forward")
        Button {
          model.moveOnSphere(.backward)
        } label: {
          Image(systemName: "arrow.down")
        }
        .accessibilityLabel("Walk backward")
        .accessibilityIdentifier("sphere-walk-backward")
      }

      Button {
        model.moveOnSphere(.right)
      } label: {
        Image(systemName: "arrow.right")
      }
      .accessibilityLabel("Walk right")
      .accessibilityIdentifier("sphere-walk-right")

      Button {
        model.turnOnSphere(by: .pi / 12)
      } label: {
        Image(systemName: "arrow.clockwise")
      }
      .accessibilityLabel("Turn right")
      .accessibilityIdentifier("sphere-turn-right")
    }
    .buttonStyle(.bordered)
  }

  private var altitudeAndRouteControls: some View {
    HStack(spacing: 8) {
      Button {
        model.changeSphereAltitude(by: -0.04)
      } label: {
        Label("Descend", systemImage: "arrow.down.to.line.compact")
      }
      .accessibilityIdentifier("sphere-altitude-down")
      Button {
        model.changeSphereAltitude(by: 0.04)
      } label: {
        Label("Ascend", systemImage: "arrow.up.to.line.compact")
      }
      .accessibilityIdentifier("sphere-altitude-up")
      Button {
        model.walkCapToEquator()
      } label: {
        Label("Cap → equator", systemImage: "figure.walk.motion")
      }
      .accessibilityIdentifier("sphere-cap-to-equator")
    }
    .font(.caption)
    .buttonStyle(.bordered)
  }

  private var addressFooter: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(navigationStateText)
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("sphere-navigation-state")
        Spacer()
        Button {
          model.resetLab()
        } label: {
          Image(systemName: "arrow.counterclockwise.circle")
        }
        .accessibilityLabel("Reset sphere address")
        .accessibilityIdentifier("sphere-reset-address")
      }

      Text(model.spherePresentationStatusText)
        .font(.caption2.monospacedDigit())
        .foregroundStyle(model.spherePresentationIsCurrent ? .green : .yellow)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var navigationStateText: String {
    let altitude = model.sphereNavigation.address.altitude.formatted(
      .number.precision(.fractionLength(2))
    )
    return "alt \(altitude) · heading \(degree(model.sphereHeadingDegrees)) "
      + "· steps \(model.sphereNavigation.stepCount)"
  }

  private func degree(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(1))) + "°"
  }
}
