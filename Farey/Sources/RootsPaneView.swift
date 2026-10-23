// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

#if canImport(FareyCore)
  import FareyCore
#endif

/// The roots of the upper interior forms in the upper half-plane, as the right-hand diagram of Stange's viewer shows
/// them (the browser's WebXR/roots-pane.js, in SwiftUI). Each base form (a, b, c), a > 0, Δ < 0, is drawn at the root of
/// its image under g, with radius 0.03·scale/a′. Dragging applies her transvection drag, so the root under the pointer
/// follows it; a tap selects. Base identities never change here.
struct RootsPaneView: View {
  @Environment(GalleryModel.self) private var model
  @Environment(\.dismissWindow) private var dismissWindow
  @State private var anchor: SIMD2<Double>?
  private struct Star { let point: CoefficientPoint; let center: CGPoint; let radius: Double; let color: Color }
  private struct Frame {
    let size: CGSize
    var scale: Double { size.width / 2.4 }
    var cy: Double { (size.height / 2 - 28) / scale }
    func screen(_ z: SIMD2<Double>) -> CGPoint {
      CGPoint(x: size.width / 2 + z.x * scale, y: size.height / 2 - (z.y - cy) * scale)
    }
    /// The upper half-plane point under a location, or nil on or below the real axis (no anchor there).
    func root(at p: CGPoint) -> SIMD2<Double>? {
      let z = SIMD2((p.x - size.width / 2) / scale, cy - (p.y - size.height / 2) / scale)
      return z.y > 1e-6 ? z : nil
    }
  }

  var body: some View {
    GeometryReader { geometry in
      let frame = Frame(size: geometry.size), stars = self.stars(in: frame)
      Canvas { context, _ in draw(stars, frame: frame, in: &context) }
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 4)
            .onChanged { value in
              let start = anchor ?? frame.root(at: value.startLocation)
              let current = frame.root(at: value.location)
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
            if let star = pick(stars, at: value.location) { model.select(star.point) }
          })
        .accessibilityElement()
        .accessibilityLabel("Roots of the upper interior forms in the upper half-plane")
        .accessibilityValue(model.coefficientGroup.isIdentity ? "g = identity" : "g moved")
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

  private func stars(in frame: Frame) -> [Star] {
    let g = model.coefficientGroup, crop = model.coefficientCrop
    var result: [Star] = []
    for point in CoefficientBall.points(radius: crop.radius, upperOnly: crop.upperOnly)
    where point.a > 0 && point.discriminant < 0 {
      let image = g.isIdentity ? SIMD3(Double(point.a), Double(point.b), Double(point.c)) : g.image(of: point)
      let a1 = image.x, root = SIMD2(-image.y / (2 * a1), Double(-point.discriminant).squareRoot() / (2 * a1))
      guard let rgb = CoefficientPalette.color(for: point, colorLower: crop.colorLower) else { continue }
      result.append(
        Star(
          point: point, center: frame.screen(root), radius: 0.03 * frame.scale / a1,
          color: Color(red: rgb.x, green: rgb.y, blue: rgb.z)))
    }
    return result.sorted { $0.radius < $1.radius }  // larger stars on top
  }
  private func draw(_ stars: [Star], frame: Frame, in context: inout GraphicsContext) {
    for star in stars where star.radius > 0.08 {
      let r = max(star.radius, 0.6)
      context.opacity = star.radius < 0.6 ? (star.radius / 0.6) * (star.radius / 0.6) : 1
      let disc = CGRect(x: star.center.x - r, y: star.center.y - r, width: 2 * r, height: 2 * r)
      context.fill(Path(ellipseIn: disc), with: .color(star.color))
    }
    context.opacity = 1
    let axis = frame.screen([0, 0]).y
    context.stroke(Path { $0.move(to: CGPoint(x: 0, y: axis)); $0.addLine(to: CGPoint(x: frame.size.width, y: axis)) },
      with: .color(Color(red: 0.47, green: 0.59, blue: 0.66)), lineWidth: 1)
    for (t, label) in [(-1.0, "−1"), (-0.5, "−½"), (0, "0"), (0.5, "½"), (1, "1")] {
      let x = frame.screen([t, 0]).x
      context.draw(Text(label).font(.caption2).foregroundStyle(.secondary), at: CGPoint(x: x, y: axis + 14))
    }
    for (point, color) in [(model.coefficient, Color.white), (model.coefficientSecond, Color.orange)] {
      guard let point, let star = stars.first(where: { $0.point == point }) else { continue }
      let r = max(star.radius, 0.6) + 3
      let ring = CGRect(x: star.center.x - r, y: star.center.y - r, width: 2 * r, height: 2 * r)
      context.stroke(Path(ellipseIn: ring), with: .color(color), lineWidth: 1.2)
      // Her label manner: one 12-point monospace line below right of the star.
      let offset = max(8, star.radius + 7)
      context.draw(
        Text(point.polynomial).font(.system(size: 12, design: .monospaced)).foregroundStyle(color),
        at: CGPoint(x: star.center.x + offset, y: star.center.y + max(8, star.radius + 6)), anchor: .leading)
    }
  }
  /// The star nearest a location within max(7 pt, its radius); multiples share a root, so stars within half a point of
  /// the nearest tie and the largest (visible) one wins.
  private func pick(_ stars: [Star], at location: CGPoint) -> Star? {
    let near = stars.map { star in (star, hypot(star.center.x - location.x, star.center.y - location.y)) }
      .filter { $0.1 <= max(7, $0.0.radius) }
    guard let nearest = near.map(\.1).min() else { return nil }
    return near.filter { $0.1 <= nearest + 0.5 }.max { $0.0.radius < $1.0.radius }?.0
  }
}
