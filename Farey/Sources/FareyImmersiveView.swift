// SPDX-License-Identifier: GPL-3.0-or-later
import RealityKit
import SwiftUI

#if canImport(FareyCore)
  import FareyCore
#endif

@MainActor struct FareyImmersiveView: View {
  @Environment(GalleryModel.self) private var model
  @State private var renderer = FareyRenderer()
  @State private var lattice = LatticeRenderer()
  @State private var activation: EventSubscription?
  var body: some View {
    RealityView { content, attachments in
      content.add(renderer.root)
      content.add(lattice.root)
      activation = content.subscribe(to: AccessibilityEvents.Activate.self) { [model] event in
        if let point = Self.latticePoint(for: event.entity) { model.select(point) }
      }
      for rational in LatticeRenderer.landmarks {
        if let label = attachments.entity(for: "lattice-\(rational.p)-\(rational.q)") {
          lattice.addLandmark(label, at: rational)
        }
      }
      if let title = attachments.entity(for: "title") {
        title.position = [0, 3.15, -3.3]
        title.scale = [3, 3, 3]
        content.add(title)
      }
      for (name, position) in [
        ("0", SIMD3<Float>(0, 0.51, -3.3)), ("∞", SIMD3<Float>(0, 3.08, -3.3)),
        ("1", SIMD3<Float>(1.35, 1.8, -3.3)), ("−1", SIMD3<Float>(-1.35, 1.8, -3.3)),
      ] {
        if let label = attachments.entity(for: name) {
          label.position = position
          label.scale = [3, 3, 3]
          renderer.labels.addChild(label)
        }
      }
      content.add(renderer.labels)
    } attachments: {
      ForEach(LatticeRenderer.landmarks, id: \.self) { rational in
        Attachment(id: "lattice-\(rational.p)-\(rational.q)") {
          Button(rational.description) { model.select(LatticePoint(p: rational.p, q: rational.q)) }
            .font(.caption.weight(.semibold)).buttonStyle(.borderedProminent)
            .tint(landmarkColor(rational))
            .foregroundStyle(
              rational == model.state.selectedPoint?.rational && rational != model.state.mediant
                ? Color.black : Color.white)
            .accessibilityIdentifier("lattice-\(rational.p)-\(rational.q)")
        }
      }
      Attachment(id: "title") {
        VStack(spacing: 4) {
          Text(model.latticeMode ? "THE FAREY LATTICE" : "THE FAREY UNIVERSE")
            .font(.headline).tracking(4).foregroundStyle(.cyan)
          Text(
            model.latticeMode
              ? "p/q is the direction (q, p) · mediants add integer vectors"
              : "Exact rational edges · finite hyperbolic tessellation"
          ).font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      ForEach(["0", "∞", "1", "−1"], id: \.self) { label in
        Attachment(id: label) {
          Text(label).font(.system(size: 24, weight: .light, design: .serif)).foregroundStyle(.cyan)
        }
      }
    }
    .task(id: [model.revision, model.immersionSession, model.immersionOpen ? 1 : 0]) {
      guard model.immersionOpen else { return }
      do {
        renderer.root.isEnabled = !model.latticeMode
        renderer.labels.isEnabled = !model.latticeMode && model.viewpoint == 0
        lattice.root.isEnabled = model.latticeMode
        if model.latticeMode {
          model.renderReceipt = try lattice.render(
            state: model.state, bound: model.depth * 2,
            viewpoint: model.viewpoint)
        } else {
          model.renderReceipt = try renderer.render(
            state: model.state, depth: model.depth, viewpoint: model.viewpoint)
        }
        model.record("Rendered session \(model.immersionSession): \(model.renderReceipt)")
      } catch { model.renderReceipt = "Geometry error: \(error.localizedDescription)" }
    }
    .gesture(
      SpatialTapGesture().targetedToAnyEntity().onEnded { value in
        if let point = Self.latticePoint(for: value.entity) { model.select(point) }
      }
    )
    .onAppear {
      model.record("Immersive view appeared session \(model.immersionSession)")
      model.error = nil
    }
    .onDisappear {
      activation?.cancel()
      activation = nil
      model.record("Immersive view disappeared session \(model.immersionSession)")
      model.immersionOpen = false
      model.transitioning = false
    }

  }
  private static func latticePoint(for entity: Entity) -> LatticePoint? {
    let parts = entity.name.split(separator: ":")
    guard parts.count == 3, parts[0] == "rational",
      let p = Int64(parts[1]), let q = Int64(parts[2])
    else { return nil }
    return LatticePoint(p: p, q: q)
  }
  private func landmarkColor(_ rational: Rational) -> Color {
    if rational == model.state.mediant { return .orange }
    if rational == model.state.selectedPoint?.rational { return .white }
    if rational == model.state.left { return .cyan }
    if rational == model.state.right { return .purple }
    return .blue
  }
}

@MainActor final class FareyRenderer {
  let root = Entity()
  let labels = Entity()
  private var previousDepth: Int?
  private let base = Entity()
  private let selection = Entity()
  init() {
    root.position = [0, 1.8, -3.3]
    root.scale = [1.2, 1.2, 1.2]
    root.addChild(base)
    root.addChild(selection)
  }
  func render(state: FareyState, depth: Int, viewpoint: Int) throws -> String {
    let start = ContinuousClock.now
    var vertices = 0
    if previousDepth != depth {
      base.children.removeAll()
      let edges = Geometry.tessellation(depth: depth)
      for level in 0...depth {
        let lines = edges.filter { $0.depth == level }.map(\.samples)
        let radius = Float(0.0032 / (1 + Double(level) * 0.28))
        let shade = CGFloat(max(0.28, 0.95 - Double(level) * 0.095))
        let mesh = try tubeMesh(lines: lines, radius: radius)
        vertices += mesh.1
        let entity = ModelEntity(
          mesh: mesh.0,
          materials: [UnlitMaterial(color: UIColor(red: 0.12, green: shade, blue: 1, alpha: 1))])
        base.addChild(entity)
      }
      let ring = (0...160).map { i in
        Point2(cos(Double(i) * 2 * .pi / 160), sin(Double(i) * 2 * .pi / 160))
      }
      let boundary = try tubeMesh(lines: [ring], radius: 0.0035)
      base.addChild(
        ModelEntity(
          mesh: boundary.0,
          materials: [UnlitMaterial(color: UIColor(red: 0.2, green: 0.65, blue: 1, alpha: 1))]))
      previousDepth = depth
    }
    selection.children.removeAll()
    let direction = try tubeMesh(
      lines: [Geometry.geodesic(Rational(1, 0).diskPoint, state.mediant.diskPoint)], radius: 0.004)
    selection.addChild(
      ModelEntity(
        mesh: direction.0,
        materials: [UnlitMaterial(color: UIColor.systemGreen)]))
    try addHistory(state)
    for rational in [state.left, state.right, state.mediant] {
      let point = rational.diskPoint
      let dot = ModelEntity(
        mesh: .generateSphere(radius: 0.014), materials: [UnlitMaterial(color: UIColor.orange)])
      dot.position = [Float(point.x), Float(point.y), 0.012]
      selection.addChild(dot)
    }
    let angle: Float = [0, -0.5, 0.8][viewpoint]
    root.orientation = simd_quatf(angle: angle, axis: [0, 1, 0])
    labels.isEnabled = viewpoint == 0
    let elapsed = start.duration(to: .now)
    let edgeCount = Geometry.tessellation(depth: depth).count
    return
      "\(edgeCount) Farey edges · \(base.children.count + selection.children.count) draw groups · \(elapsed) update · stationary"
  }

  private func addHistory(_ state: FareyState) throws {
    if !state.word.isEmpty {
      let path = try tubeMesh(lines: state.history.map(\.samples), radius: 0.005)
      selection.addChild(
        ModelEntity(
          mesh: path.0,
          materials: [UnlitMaterial(color: UIColor(red: 1, green: 0.62, blue: 0.2, alpha: 1))]))
    }
  }

  private func tubeMesh(lines: [[Point2]], radius: Float) throws -> (MeshResource, Int) {
    let sides = 6
    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var indices: [UInt32] = []
    for line in lines where line.count > 1 {
      let offset = positions.count
      for i in line.indices {
        let before = line[max(0, i - 1)]
        let after = line[min(line.count - 1, i + 1)]
        let tangent = simd_normalize(
          SIMD3<Float>(Float(after.x - before.x), Float(after.y - before.y), 0))
        let normal = SIMD3<Float>(-tangent.y, tangent.x, 0)
        let center = SIMD3<Float>(Float(line[i].x), Float(line[i].y), 0)
        for side in 0..<sides {
          let angle = Float(side) * 2 * .pi / Float(sides)
          let direction = normal * cos(angle) + SIMD3<Float>(0, 0, 1) * sin(angle)
          positions.append(center + radius * direction)
          normals.append(direction)
        }
        if i > 0 {
          for side in 0..<sides {
            let a = UInt32(offset + (i - 1) * sides + side)
            let b = UInt32(offset + (i - 1) * sides + (side + 1) % sides)
            let c = UInt32(offset + i * sides + side)
            let d = UInt32(offset + i * sides + (side + 1) % sides)
            indices.append(contentsOf: [a, b, c, b, d, c])
          }
        }
      }
    }
    var descriptor = MeshDescriptor(name: "Farey exact geodesic tubes")
    descriptor.positions = MeshBuffers.Positions(positions)
    descriptor.normals = MeshBuffers.Normals(normals)
    descriptor.primitives = .triangles(indices)
    return (try MeshResource.generate(from: [descriptor]), positions.count)
  }
}
