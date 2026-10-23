// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

#if canImport(FareyCore)
  import FareyCore
#endif

struct StarscapeControls: View {
  @Environment(GalleryModel.self) private var model
  @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
  @State private var showSources = false
  @State private var entry = "1,-1,2"
  @State private var collapsed = false
  @FocusState private var entryFocused: Bool
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("COEFFICIENT SPACE · ℤ³").font(.headline).foregroundStyle(.cyan)
        Spacer()
        // Collapsing keeps this row and the readout, so Reset and Exit stay reachable with less of the scene covered.
        Button(collapsed ? "Show controls" : "Hide controls") {
          entryFocused = false
          collapsed.toggle()
        }.accessibilityIdentifier("controls-toggle")
        Button("Reset") {
          model.resetStarscape()
          entry = model.coefficient.entryText
        }.accessibilityIdentifier("coefficient-reset")
        Button("Farey L/R") {
          model.starscapeMode = false
          model.revision += 1
        }
        .accessibilityIdentifier("show-farey")
        Button("Exit") {
          guard !model.transitioning else { return }
          model.transitioning = true
          Task {
            await dismissImmersiveSpace()
            model.transitioning = false
          }
        }.disabled(model.transitioning).accessibilityIdentifier("exit-void")
      }
      Text("(a, b, c) = \(model.coefficient.label)   Δ = \(model.coefficient.discriminant)")
        .font(.title3.monospaced()).accessibilityIdentifier("coefficient-state")
      if !collapsed { details }
    }.padding(20).frame(width: 760).glassBackgroundEffect()
      .sheet(isPresented: $showSources) { SourcesView() }
  }
  private var details: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(rootLabel).font(.caption.monospaced()).accessibilityIdentifier("coefficient-root")
      HStack {
        TextField("a,b,c", text: $entry).textFieldStyle(.roundedBorder).frame(width: 150)
          .focused($entryFocused).onSubmit(select).accessibilityIdentifier("coefficient-entry")
        Button("Select", action: select).accessibilityIdentifier("coefficient-select")
        if let error = model.coefficientEntryError {
          Text(error).font(.caption).foregroundStyle(.orange).accessibilityIdentifier("coefficient-error")
        }
      }
      HStack {
        Picker("Radius", selection: binding(\.coefficientRadius)) {
          ForEach(CoefficientBall.radii, id: \.self) { Text("R\($0)").tag($0) }
        }.pickerStyle(.segmented).frame(width: 300).accessibilityIdentifier("coefficient-radius")
        Toggle("Upper only", isOn: binding(\.coefficientUpperOnly)).accessibilityIdentifier("upper-only")
        Toggle("Color lower (ours)", isOn: binding(\.coefficientColorLower)).accessibilityIdentifier("color-lower")
      }.toggleStyle(.button)
      HStack {
        Button("Next point") { model.nextCoefficient() }.accessibilityIdentifier("coefficient-next")
        Button(model.showProjection ? "Hide projection" : "Show projection") {
          model.showProjection.toggle()
          model.revision += 1
        }.accessibilityIdentifier("projection-toggle")
        Button(["Oblique", "Other side", "Side view"][model.coefficientView]) {
          model.coefficientView = (model.coefficientView + 1) % 3
          model.revision += 1
        }.accessibilityIdentifier("coefficient-view")
        Button("Sources") { showSources = true }.accessibilityIdentifier("sources")
      }.buttonStyle(.bordered)
      legend
      Text("Inspired by Katherine Stange’s Starscape / Lattice · \(model.renderReceipt)")
        .font(.caption).foregroundStyle(.cyan).accessibilityIdentifier("render-receipt")
    }
  }
  /// A valid entry dismisses the keyboard; a rejected one keeps the text and focus so it can be corrected.
  private func select() {
    guard model.enterCoefficient(entry) else { return }
    entry = model.coefficient.entryText
    entryFocused = false
  }
  private func binding<Value>(_ path: ReferenceWritableKeyPath<GalleryModel, Value>) -> Binding<Value> {
    Binding(
      get: { model[keyPath: path] },
      set: {
        model[keyPath: path] = $0
        model.coefficientEntryError = nil
        model.revision += 1
      })
  }
  /// Upper-interior |Δ| on the browser's fixed log range, plus its category swatches.
  private var legend: some View {
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 2) {
        LinearGradient(
          stops: (0...16).map { i in
            let rgb = CoefficientPalette.sample(Double(i) / 16)
            return .init(color: Color(red: rgb.x, green: rgb.y, blue: rgb.z), location: Double(i) / 16)
          }, startPoint: .leading, endPoint: .trailing
        ).frame(width: 220, height: 8).clipShape(Capsule())
        Text("|Δ| 3 … 240, log · Viridis 0.2–1").font(.caption2).foregroundStyle(.secondary)
      }
      ForEach(
        [("exterior Δ>0", CoefficientPalette.exterior), ("cone Δ=0", CoefficientPalette.boundary),
         ("lower interior", CoefficientPalette.lower)], id: \.0
      ) { name, rgb in
        HStack(spacing: 4) {
          Circle().fill(Color(red: rgb.x, green: rgb.y, blue: rgb.z)).frame(width: 9, height: 9)
          Text(name).font(.caption2)
        }
      }
    }.accessibilityElement(children: .combine).accessibilityIdentifier("coefficient-legend")
  }
  private var rootLabel: String {
    let point = model.coefficient
    let hidden = model.coefficientShown ? "" : "  ·  hidden by this radius or filter"
    switch point.kind {
    case .upper?, .lower?:
      guard let root = point.representativeRoot else { return "" }
      let flipped = point.kind == .lower ? " (sign-flipped representative)" : ""
      return String(format: "upper root %.3f + %.3fi", root.x, root.y) + flipped + hidden
    case .null?: return "boundary: one repeated real root" + hidden
    case .exterior?: return "exterior: two real roots" + hidden
    case nil: return hidden
    }
  }
}

extension CoefficientPoint {
  var entryText: String { "\(a),\(b),\(c)" }
}

struct StarscapePreview: View {
  var body: some View {
    Canvas { context, size in
      func screen(_ p: SIMD3<Double>) -> CGPoint {
        CGPoint(
          x: size.width / 2 + (p.x * 0.85 + p.z * 0.53) * 16,
          y: size.height / 2 - (p.y * 0.86 - p.z * 0.35 + p.x * 0.2) * 17)
      }
      for i in 0..<12 {
        let angle = Double(i) * .pi / 6
        for h in [6.0, -6.0] {
          var line = Path()
          line.move(to: screen(.zero))
          line.addLine(to: screen(SIMD3(6 * cos(angle), h, 6 * sin(angle))))
          context.stroke(line, with: .color(.cyan.opacity(0.18)), lineWidth: 1)
        }
      }
      // The same R6 ball and palette as the immersive scene.
      for p in CoefficientBall.points(radius: 6).sorted(by: { $0.vector.z < $1.vector.z }) {
        guard let rgb = CoefficientPalette.color(for: p) else { continue }
        let point = screen(p.vector)
        context.fill(
          Path(ellipseIn: CGRect(x: point.x - 1.5, y: point.y - 1.5, width: 3, height: 3)),
          with: .color(Color(red: rgb.x, green: rgb.y, blue: rgb.z)))
      }
    }
  }
}
