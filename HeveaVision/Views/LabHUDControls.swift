import SwiftUI

struct Readout: View {
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

struct LabControlsHUD: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var model = model

    HStack(spacing: 15) {
      if model.selectedExhibit == .reducedSphere {
        sphereControls
      } else {
        torusControls(model: $model)
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 13)
    .glassBackgroundEffect(in: .capsule)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("immersive-controls-hud")
  }

  private var sphereControls: some View {
    Group {
      Button {
        model.turnOnSphere(by: -.pi / 18)
      } label: {
        Image(systemName: "arrow.counterclockwise")
      }
      .accessibilityLabel("Turn left")
      .accessibilityIdentifier("immersive-sphere-turn-left")

      Button {
        model.moveOnSphere(.left)
      } label: {
        Image(systemName: "arrow.left")
      }
      .accessibilityLabel("Walk left")
      .accessibilityIdentifier("immersive-sphere-walk-left")

      Button {
        model.moveOnSphere(.forward)
      } label: {
        Label("Walk", systemImage: "arrow.up")
      }
      .accessibilityIdentifier("immersive-sphere-walk-forward")

      Button {
        model.moveOnSphere(.backward)
      } label: {
        Image(systemName: "arrow.down")
      }
      .accessibilityLabel("Walk backward")
      .accessibilityIdentifier("immersive-sphere-walk-backward")

      Button {
        model.moveOnSphere(.right)
      } label: {
        Image(systemName: "arrow.right")
      }
      .accessibilityLabel("Walk right")
      .accessibilityIdentifier("immersive-sphere-walk-right")

      Button {
        model.turnOnSphere(by: .pi / 18)
      } label: {
        Image(systemName: "arrow.clockwise")
      }
      .accessibilityLabel("Turn right")
      .accessibilityIdentifier("immersive-sphere-turn-right")

      Divider().frame(height: 34)
      sphereGaugeControls
    }
  }

  private var sphereGaugeControls: some View {
    Group {
      Button {
        model.changeSphereAltitude(by: -0.04)
      } label: {
        Image(systemName: "arrow.down.to.line.compact")
      }
      .accessibilityLabel("Descend")
      .accessibilityIdentifier("immersive-sphere-altitude-down")

      Button {
        model.changeSphereAltitude(by: 0.04)
      } label: {
        Image(systemName: "arrow.up.to.line.compact")
      }
      .accessibilityLabel("Ascend")
      .accessibilityIdentifier("immersive-sphere-altitude-up")

      Button {
        model.sectionAmount = model.sectionAmount == 0 ? 0.42 : 0
      } label: {
        Image(systemName: model.sectionAmount == 0 ? "circle" : "circle.lefthalf.filled")
      }
      .accessibilityLabel("Toggle sphere section")
      .accessibilityIdentifier("immersive-sphere-section-toggle")
    }
  }

  @ViewBuilder
  private func torusControls(model: Bindable<AppModel>) -> some View {
    Menu {
      ForEach(DiagnosticOverlay.allCases) { overlay in
        Button {
          model.wrappedValue.selectOverlay(overlay)
        } label: {
          Label(overlay.rawValue, systemImage: overlay.systemImage)
        }
      }
    } label: {
      Label(
        model.wrappedValue.selectedOverlay.shortLabel,
        systemImage: model.wrappedValue.selectedOverlay.systemImage
      )
    }
    .accessibilityIdentifier("immersive-overlay-menu")

    Divider().frame(height: 34)

    VStack(alignment: .leading, spacing: 2) {
      Text("Section \(Int(model.wrappedValue.sectionAmount * 100))%")
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.secondary)
      Slider(value: model.sectionAmount, in: 0...0.8, step: 1 / 12)
        .frame(width: 125)
        .accessibilityIdentifier("section-slider")
    }

    Button {
      model.wrappedValue.showDomainFloor.toggle()
    } label: {
      Image(
        systemName: model.wrappedValue.showDomainFloor ? "grid.circle.fill" : "grid.circle"
      )
    }
    .accessibilityLabel("Toggle parameter domain")

    Button {
      model.wrappedValue.showGaussSphere.toggle()
    } label: {
      Image(
        systemName: model.wrappedValue.showGaussSphere
          ? "circle.hexagongrid.fill" : "circle.hexagongrid"
      )
    }
    .accessibilityLabel("Toggle Gauss sphere")
  }
}

struct InsideEscapeHUD: View {
  @Environment(AppModel.self) private var model
  @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

  var body: some View {
    HStack(spacing: 10) {
      Button {
        // This control removes its own RealityView attachment. Defer by one main-actor turn so
        // visionOS can finish dispatching the spatial tap before SwiftUI tears down its source.
        Task { @MainActor in
          await Task.yield()
          if model.selectedExhibit == .reducedSphere {
            model.selectSphereRegime(.habitat)
          } else {
            model.presentation = .outside
          }
        }
      } label: {
        Label(returnLabel, systemImage: "arrow.backward.circle.fill")
      }
      .buttonStyle(.borderedProminent)
      .tint(.cyan)
      .foregroundStyle(.black)
      .accessibilityIdentifier(returnIdentifier)

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

  private var returnLabel: String {
    model.selectedExhibit == .reducedSphere ? "Return to Habitat" : "Return Outside"
  }

  private var returnIdentifier: String {
    model.selectedExhibit == .reducedSphere ? "return-habitat" : "return-outside"
  }
}
