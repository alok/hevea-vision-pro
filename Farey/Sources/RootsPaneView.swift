// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

#if canImport(FareyCore)
  import FareyCore
#endif

/// The roots of the upper interior forms in the upper half-plane, as the right-hand diagram of Stange's viewer shows
/// them (the browser's WebXR/roots-pane.js, in SwiftUI). Each base form (a, b, c), a > 0, Δ < 0, is drawn at the root of
/// its image under g, with radius 0.03·scale/a′. Dragging applies her transvection drag, so the root under the pointer
/// follows it; a tap selects (or pairs, with Pair next armed); a pointer hover labels the star a tap would pick. Base
/// identities never change here.
struct RootsPaneView: View {
  @Environment(GalleryModel.self) private var model
  @Environment(\.dismissWindow) private var dismissWindow
  @State private var anchor: SIMD2<Double>?
  /// The pointer location while it hovers (a pointer hover, not eye gaze); the hovered star is picked from it afresh
  /// on every draw, so a change of g or Reset never leaves a stale label.
  @State private var hover: CGPoint?
  @State private var lastPick: CoefficientPoint?

  var body: some View {
    GeometryReader { geometry in
      let layout = RootsLayout(size: geometry.size, group: model.coefficientGroup, crop: model.coefficientCrop)
      Canvas { context, _ in draw(layout, in: &context) }
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 4)
            .onChanged { value in
              let start = anchor ?? layout.root(at: value.startLocation)
              let current = layout.root(at: value.location)
              if let start, let current { model.dragRoots(from: start, to: current) }
              anchor = current ?? start
            }
            .onEnded { _ in
              anchor = nil
              model.endRootsDrag()
            }
        )
        .simultaneousGesture(
          SpatialTapGesture().onEnded { value in
            lastPick = layout.pick(at: value.location)?.point
            if let point = lastPick { model.activateCoefficient(point) }
          })
        .onContinuousHover { phase in
          if case .active(let location) = phase { hover = location } else { hover = nil }
        }
        .accessibilityElement()
        .accessibilityLabel("Roots of the upper interior forms in the upper half-plane")
        .accessibilityValue(
          (model.coefficientGroup.isIdentity ? "g = identity" : "g moved") + " · last pick " + (lastPick?.label ?? "none")
            + layout.locations(of: [CoefficientPoint(1, 0, 1), CoefficientPoint(1, 1, 1)]))
        .accessibilityIdentifier("roots-pane")
    }
    .overlay(alignment: .topLeading) {
      Text("roots · upper half-plane").font(.caption).foregroundStyle(.secondary).padding(10)
    }
    .overlay(alignment: .topTrailing) {
      // Closes only this window; g, the selection and the immersive scene are unchanged, and Roots… reopens it.
      Button("Close") { dismissWindow(id: "roots") }.buttonStyle(.bordered).padding(8).accessibilityIdentifier("roots-close")
    }
    .background(.black)
  }

  private func draw(_ layout: RootsLayout, in context: inout GraphicsContext) {
    for star in layout.stars where star.radius > 0.08 {
      let r = max(star.radius, 0.6)
      context.opacity = star.radius < 0.6 ? (star.radius / 0.6) * (star.radius / 0.6) : 1
      let disc = CGRect(x: star.center.x - r, y: star.center.y - r, width: 2 * r, height: 2 * r)
      context.fill(Path(ellipseIn: disc), with: .color(Color(red: star.rgb.x, green: star.rgb.y, blue: star.rgb.z)))
    }
    context.opacity = 1
    let axis = layout.screen([0, 0]).y
    context.stroke(Path { $0.move(to: CGPoint(x: 0, y: axis)); $0.addLine(to: CGPoint(x: layout.size.width, y: axis)) },
      with: .color(Color(red: 0.47, green: 0.59, blue: 0.66)), lineWidth: 1)
    for (t, label) in [(-1.0, "−1"), (-0.5, "−½"), (0, "0"), (0.5, "½"), (1, "1")] {
      let x = layout.screen([t, 0]).x
      context.draw(Text(label).font(.caption2).foregroundStyle(.secondary), at: CGPoint(x: x, y: axis + 14))
    }
    // The hovered star (the same picker as a tap), then the selection and the pair, each with its exact base polynomial.
    let hovered = hover.flatMap { layout.pick(at: $0) }
    let marks: [(CoefficientPoint?, Color)] = [
      (hovered?.point, Color(white: 0.8)), (model.coefficient, .white), (model.coefficientSecond, .orange),
    ]
    for (index, (point, color)) in marks.enumerated() {
      guard let point, let star = layout.stars.first(where: { $0.point == point }) else { continue }
      if index == 0 && (point == model.coefficient || point == model.coefficientSecond) { continue }
      let r = max(star.radius, 0.6) + 3
      let ring = CGRect(x: star.center.x - r, y: star.center.y - r, width: 2 * r, height: 2 * r)
      context.stroke(Path(ellipseIn: ring), with: .color(color), lineWidth: 1.2)
      // Her label manner: one 12-point monospace line below right of the star, flipped left near the right edge.
      let offset = max(8, star.radius + 7), y = star.center.y + max(8, star.radius + 6)
      let flip = star.center.x + offset + 120 > layout.size.width
      context.draw(
        Text(point.polynomial).font(.system(size: 12, design: .monospaced)).foregroundStyle(color),
        at: CGPoint(x: star.center.x + (flip ? -offset : offset), y: y), anchor: flip ? .trailing : .leading)
    }
  }
}
