// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

#if canImport(FareyCore)
  import FareyCore
#endif

struct StarscapeControls: View {
  @Environment(GalleryModel.self) private var model
  @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
  @State private var showSources = false
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("COEFFICIENT SPACE · ℤ³").font(.headline).foregroundStyle(.cyan)
        Spacer()
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
        .font(.title3.monospaced()).foregroundStyle(.orange)
        .accessibilityIdentifier("coefficient-state")
      Text(
        "Orange: selected integer point. White: its image on the cyan disk a+c=4. Points at different depths can share one image."
      )
      .font(.caption).fixedSize(horizontal: false, vertical: true)
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
        Button("Reset") { model.resetStarscape() }.accessibilityIdentifier("coefficient-reset")
        Button("Sources") { showSources = true }.accessibilityIdentifier("sources")
      }.buttonStyle(.bordered)
      Text(
        "\(model.coefficient.a)x² + (\(model.coefficient.b))x + \(model.coefficient.c) = 0    ·    z = \(rootLabel)"
      )
      .font(.caption.monospaced()).accessibilityIdentifier("coefficient-root")
      Text(
        "(x,y,z) = (−b,a+c,c−a). The cone is x²+z²=y². Projection scales the whole vector by 4/(a+c), preserving its ray."
      )
      .font(.caption).foregroundStyle(.secondary)
      Text("Inspired by Katherine Stange’s Starscape / Lattice · \(model.renderReceipt)")
        .font(.caption).foregroundStyle(.cyan).accessibilityIdentifier("render-receipt")
    }.padding(20).frame(width: 760).glassBackgroundEffect()
      .sheet(isPresented: $showSources) { SourcesView() }
  }
  private var rootLabel: String {
    guard let root = model.coefficient.upperRoot else { return "undefined" }
    return String(format: "%.3f + %.3fi", root.x, root.y)
  }
}

struct StarscapePreview: View {
  var body: some View {
    Canvas { context, size in
      func screen(_ p: SIMD3<Double>) -> CGPoint {
        CGPoint(
          x: size.width / 2 + (p.x * 0.85 + p.z * 0.53) * 15,
          y: size.height - 25 - (p.y * 0.82 - p.z * 0.45 + p.x * 0.28) * 22)
      }
      for i in 0..<12 {
        let angle = Double(i) * .pi / 6
        var line = Path()
        line.move(to: screen(.zero))
        line.addLine(to: screen(SIMD3(8 * cos(angle), 8, 8 * sin(angle))))
        context.stroke(line, with: .color(.cyan.opacity(0.2)), lineWidth: 1)
      }
      for p in Starscape.points().sorted(by: { $0.vector.z < $1.vector.z }) {
        let point = screen(p.vector)
        context.fill(
          Path(ellipseIn: CGRect(x: point.x - 2, y: point.y - 2, width: 4, height: 4)),
          with: .color(.cyan.opacity(0.75)))
      }
    }
  }
}
