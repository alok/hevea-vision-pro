import SwiftUI

struct SampleHUD: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if model.selectedExhibit == .reducedSphere {
        sphereAddress
      } else {
        torusSample
      }
    }
    .frame(width: 330, alignment: .leading)
    .padding(17)
    .glassBackgroundEffect(in: .rect(cornerRadius: 22))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("immersive-sample-hud")
  }

  private var sphereAddress: some View {
    Group {
      HStack {
        Image(systemName: "location.north.fill")
          .foregroundStyle(.yellow)
        Text("INTRINSIC SPHERE ADDRESS")
          .font(.caption2.weight(.heavy))
          .tracking(1.05)
          .foregroundStyle(.yellow)
      }

      Text("Address step #\(model.sphereNavigation.stepCount)")
        .font(.headline.monospacedDigit())
        .accessibilityLabel(
          Text(verbatim: "Address step #\(model.sphereNavigation.stepCount)")
        )
        .accessibilityIdentifier("sphere-address-step-state")

      HStack(spacing: 14) {
        Readout(label: "latitude", value: decimal(model.sphereLatitudeDegrees, places: 1) + "°")
        Readout(label: "longitude", value: decimal(model.sphereLongitudeDegrees, places: 1) + "°")
        Readout(
          label: "altitude",
          value: decimal(model.sphereNavigation.address.altitude, places: 2)
        )
      }

      HStack(spacing: 14) {
        Readout(
          label: "intrinsic path",
          value: decimal(model.sphereNavigation.traversedIntrinsicDistance, places: 3)
        )
        Readout(
          label: "mesh",
          value: model.sphereDiagnostics.vertexCount == 0
            ? "pending"
            : "\(model.sphereDiagnostics.vertexCount) v"
        )
        Readout(label: "χ", value: "\(model.sphereDiagnostics.eulerCharacteristic)")
      }

      if let error = model.generationError {
        generationError(error)
      } else {
        Text("Yellow is the addressed point and outward normal; cyan is intrinsic heading.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Text("HV EXPERIMENT · finite proxy · source-sheet identity retained")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
    }
  }

  private var torusSample: some View {
    Group {
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
        generationError(error)
      } else {
        Text(
          "Tap the torus to synchronize one surface normal with its point on the Gauss sphere."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }

      Text("Finite mesh only · no limiting-regularity theorem")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
    }
  }

  private func generationError(_ error: String) -> some View {
    Label(error, systemImage: "exclamationmark.triangle.fill")
      .font(.caption)
      .foregroundStyle(.orange)
      .accessibilityIdentifier("generation-error")
  }

  private func decimal(_ value: Double, places: Int) -> String {
    value.formatted(.number.precision(.fractionLength(places)))
  }
}
