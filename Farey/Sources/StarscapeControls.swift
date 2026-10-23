// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

#if canImport(FareyCore)
  import FareyCore
#endif

struct StarscapeControls: View {
  @Environment(GalleryModel.self) private var model
  @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
  @Environment(\.openWindow) private var openWindow
  @State private var showSources = false
  @State private var entry = "1,-1,2"
  @State private var collapsed = false
  @State private var pairEntry = ""
  @FocusState private var entryFocused: Bool
  @FocusState private var pairFocused: Bool
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("COEFFICIENT SPACE · ℤ³").font(.headline).foregroundStyle(.cyan)
        Spacer()
        // Collapsing keeps this row and the readout, so Reset and Exit stay reachable with less of the scene covered.
        Button(collapsed ? "Show controls" : "Hide controls") {
          entryFocused = false
          pairFocused = false
          collapsed.toggle()
        }.accessibilityIdentifier("controls-toggle")
        // The one Inhabit/Overview toggle stays here, so Overview is reachable with the controls collapsed.
        Button(model.coefficientPlacement.anchored ? "Overview" : "Inhabit") {
          dismissKeyboard()
          model.place(model.coefficientPlacement.anchored ? .overview : .inhabit(model.coefficient))
        }
        .disabled(!model.coefficientPlacement.anchored && !model.coefficientShown)
        .accessibilityIdentifier("placement-inhabit")
        Button("Reset") {
          dismissKeyboard()
          model.resetStarscape()
          entry = model.coefficient.entryText
          pairEntry = ""
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
      // The header and readout stay pinned; the details scroll within whatever height the window allows, so a
      // taller panel can no longer push Reset, Inhabit/Overview or Exit out of the window.
      if !collapsed { ScrollView { details.padding(.trailing, 8) } }
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
          dismissKeyboard()
          model.showProjection.toggle()
          model.revision += 1
        }.accessibilityIdentifier("projection-toggle")
        Button(["Oblique", "Other side", "Side view"][model.coefficientView]) {
          dismissKeyboard()
          model.coefficientView = (model.coefficientView + 1) % 3
          model.revision += 1
        }.disabled(model.coefficientPlacement.anchored).accessibilityIdentifier("coefficient-view")
        Button("Sources") { showSources = true }.accessibilityIdentifier("sources")
      }.buttonStyle(.bordered)
      symmetryRow
      pairRow
      if let plane = model.cuttingPlane { planeReadout(plane) }
      placementRow
      if InputDiagnostics.shared.enabled {
        Text(InputDiagnostics.shared.summary).font(.caption2.monospaced()).foregroundStyle(.secondary)
          .accessibilityIdentifier("input-diagnostics")
      }
      legend
      Text("Inspired by Katherine Stange’s Starscape / Lattice · \(model.renderReceipt)")
        .font(.caption).foregroundStyle(.cyan).accessibilityIdentifier("render-receipt")
    }
  }
  /// Her Symmetry controls: generators compose on the left and are absorbed when integral; Identity returns to g = 1
  /// without undoing an absorption; Snap settles a drag on SL₂(ℤ). The Roots window is where g is dragged.
  private var symmetryRow: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Button("Roots…") { openWindow(id: "roots") }.accessibilityIdentifier("roots-open")
        Button("T⁻¹") { dismissKeyboard(); model.applyGenerator(.tInverse) }.accessibilityIdentifier("group-tinv")
        Button("S") { dismissKeyboard(); model.applyGenerator(.sGenerator) }.accessibilityIdentifier("group-s")
        Button("T") { dismissKeyboard(); model.applyGenerator(.t) }.accessibilityIdentifier("group-t")
        Button("Identity") { dismissKeyboard(); model.identityGroup() }.accessibilityIdentifier("group-identity")
        Toggle("Snap", isOn: Binding(get: { model.coefficientSnap }, set: { model.coefficientSnap = $0; if $0 { model.snapGroup() } }))
          .toggleStyle(.button).accessibilityIdentifier("group-snap")
      }.buttonStyle(.bordered)
      // The visible readout is rounded; its accessibility value carries g to full precision, so a capture's g can be
      // reproduced exactly (for example in the browser, as a matched-state capture).
      Text(groupText).font(.caption.monospaced()).accessibilityIdentifier("group-state")
        .accessibilityValue(model.coefficientGroup.entries.map { "\($0)" }.joined(separator: ","))
      if let error = model.coefficientGroupError {
        Text(error).font(.caption).foregroundStyle(.orange).accessibilityIdentifier("group-error")
      }
    }
  }
  private var groupText: String {
    let g = model.coefficientGroup
    if g.isIdentity { return "g = identity" }
    let entries = g.entries.map { String(format: "%.2f", $0) }
    let nearest = g.nearestIntegral.map { " (nearest γ = [\($0.p), \($0.q); \($0.r), \($0.s)])" } ?? ""
    return "g = [\(entries[0]), \(entries[1]); \(entries[2]), \(entries[3])] · off SL₂(ℤ)\(nearest); points keep their identities"
  }
  private var pairRow: some View {
    HStack {
      TextField("pair a,b,c", text: $pairEntry).textFieldStyle(.roundedBorder).frame(width: 150)
        .focused($pairFocused).onSubmit(pair).accessibilityIdentifier("pair-entry")
      Button("Pair", action: pair).accessibilityIdentifier("pair-select")
      if model.coefficientSecond != nil {
        Button("Clear pair") { model.clearPair() }.accessibilityIdentifier("pair-clear")
      }
      // Arms one direct pick (in the Roots window or the immersive scene) to pair with the selection.
      Button(model.pairNext ? "Cancel" : "Pair next") { model.armPairNext(!model.pairNext) }
        .accessibilityIdentifier("pair-next")
      if model.pairNext {
        Text("next pick pairs with \(model.coefficient.label)").font(.caption).accessibilityIdentifier("pair-next-state")
      }
      if let error = model.coefficientPairError {
        Text(error).font(.caption).foregroundStyle(.orange).accessibilityIdentifier("pair-error")
      }
    }
  }
  private func planeReadout(_ plane: CuttingPlane) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(planeText(plane)).font(.caption.monospaced()).accessibilityIdentifier("plane-state")
      Text(
        model.coefficientSecond.map { "Paired with \($0.label) · normal \(plane.normal.label)" }
          ?? "The selected exterior triple is this plane's Lorentz normal \(plane.normal.label)."
      ).font(.caption2).foregroundStyle(.secondary).accessibilityIdentifier("plane-detail")
    }
  }
  /// The exact plane is the base one; under a non-identity g the drawn plane has moved, so the readout says which is
  /// which and adds the shown endpoints (approximate, ∞ handled).
  private func planeText(_ plane: CuttingPlane) -> String {
    let base = "\(plane.equation) · geodesic endpoints \(plane.endpoints.map(\.label).joined(separator: " and "))"
    let g = model.coefficientGroup
    guard !g.isIdentity else { return "Plane " + base }
    let shown = g.shown(real: plane.endpoints.map(\.value)).map(Mobius.approximateLabel).joined(separator: " and ")
    return "Base plane " + base + " · shown under g ≈ " + shown
  }
  private var placementRow: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        // Pressing Origin again re-centers it at the current head center.
        Button("Origin") {
          dismissKeyboard()
          model.place(.origin(facingLower: false))
        }.accessibilityIdentifier("placement-origin")
        if case .origin(let lower) = model.coefficientPlacement {
          Button(lower ? "Face upper nappe" : "Face lower nappe") {
            dismissKeyboard()
            model.place(.origin(facingLower: !lower), recenter: false)
          }.accessibilityIdentifier("origin-nappe")
        }
      }.buttonStyle(.bordered)
      if let description = placementDescription {
        Text(description).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("placement-state")
      }
    }
  }
  /// Explicit navigation and Reset close any open keyboard so it does not cover the scene.
  private func dismissKeyboard() {
    entryFocused = false
    pairFocused = false
  }
  /// A valid pair dismisses the keyboard; a rejected one keeps the text, focus and current state.
  private func pair() {
    guard model.pairCoefficient(pairEntry) else { return }
    pairFocused = false
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
  /// The selected form's exact root(s); under a non-identity g these are labelled base and followed by where they are
  /// shown (approximate, ∞ handled).
  private var rootLabel: String {
    let point = model.coefficient, g = model.coefficientGroup
    let hidden = model.coefficientShown ? "" : "  ·  hidden by this radius or filter"
    let prefix = g.isIdentity ? "" : "base "
    switch point.kind {
    case .upper?, .lower?:
      guard let root = point.representativeRoot else { return "" }
      let flipped = point.kind == .lower ? " (sign-flipped representative)" : ""
      let shown = g.isIdentity ? "" : " · shown under g " + Mobius.approximateLabel(g.act([root.x, root.y]))
      return prefix + "upper root " + Mobius.approximateLabel([root.x, root.y]) + flipped + shown + hidden
    case .null?, .exterior?:
      let shown = g.isIdentity ? "" : point.realRootValues.map {
        " · shown under g ≈ " + g.shown(real: $0).map(Mobius.approximateLabel).joined(separator: " and ")
      } ?? ""
      return prefix + (point.realRootDescription ?? "") + shown + hidden
    case nil: return hidden
    }
  }
}

// Placement explanations, shown under the placement controls.
extension StarscapeControls {
  /// Shown only when no device pose was measured: the placement falls back to the head anchor and Origin drags are off.
  private var poseNote: String {
    model.currentDevicePose != nil ? "" : " (\(model.coefficientInput.devicePoseStatus); placed at the head center, drags off)"
  }
  /// Exact placement semantics: set once from the device pose when chosen, world-stationary afterwards.
  private var placementDescription: String? {
    switch model.coefficientPlacement {
    case .overview: return nil
    case .origin(let lower):
      return "Origin: the coefficient origin (the zero polynomial, not a point of the picture) was placed at the "
        + "device's position when you chose it; the \(lower ? "lower" : "upper") nappe's axis is turned toward where "
        + "it faced. This turns the object; it is not hyperbolic navigation." + poseNote
    case .inhabit(let point):
      return "Inhabiting \(point.label): placed 35 cm ahead of the device when chosen. Selecting other points does "
        + "not move you; Overview or Reset returns." + poseNote
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
