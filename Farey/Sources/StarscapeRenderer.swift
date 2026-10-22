// SPDX-License-Identifier: GPL-3.0-or-later
import RealityKit
import SwiftUI

#if canImport(FareyCore)
  import FareyCore
#endif

@MainActor final class StarscapeRenderer {
  let root = Entity()
  private let cloud = Entity()
  private let projection = Entity()
  private let selection = Entity()
  private let sphere = MeshResource.generateSphere(radius: 0.027)
  private var dots: [CoefficientPoint: ModelEntity] = [:]
  private var built = false
  static let scale: Float = 0.18

  init() {
    root.position = [0.9, 0.8, -3.5]
    root.addChild(cloud)
    root.addChild(projection)
    root.addChild(selection)
  }
  func render(selected: CoefficientPoint, showProjection: Bool, viewpoint: Int) throws -> String {
    if !built {
      try build()
      built = true
    }
    root.orientation =
      simd_quatf(angle: [-0.55, 0.15, -1.1][viewpoint], axis: [0, 1, 0])
      * simd_quatf(angle: 0.28, axis: [1, 0, 0])
    projection.isEnabled = showProjection
    for (point, dot) in dots {
      dot.scale = point == selected ? [1.8, 1.8, 1.8] : [1, 1, 1]
      dot.model?.materials = [
        SimpleMaterial(
          color: point == selected ? .orange : shade(point), roughness: 0.35, isMetallic: false)
      ]
    }
    selection.children.removeAll()
    let end = position(selected.vector)
    line(from: .zero, to: end, color: .orange, parent: selection, width: 0.008)
    if showProjection, let image = selected.projected(height: Starscape.screenHeight) {
      let projected = position(image)
      line(from: .zero, to: projected, color: .white, parent: selection, width: 0.004)
      let marker = ModelEntity(mesh: sphere, materials: [UnlitMaterial(color: .white)])
      marker.scale = [1.5, 1.5, 1.5]
      marker.position = projected
      selection.addChild(marker)
    }
    return "\(dots.count) coefficient points · noncoplanar · stationary"
  }
  private func build() throws {
    for point in Starscape.points() {
      let dot = ModelEntity(
        mesh: sphere,
        materials: [SimpleMaterial(color: shade(point), roughness: 0.35, isMetallic: false)])
      dot.position = position(point.vector)
      dot.name = "coefficient:\(point.a):\(point.b):\(point.c)"
      dot.components.set(InputTargetComponent())
      dot.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.045)]))
      var accessibility = AccessibilityComponent()
      accessibility.label = "Coefficient point \(point.label), discriminant \(point.discriminant)"
      accessibility.isAccessibilityElement = true
      accessibility.traits = [.button]
      dot.components.set(accessibility)
      dots[point] = dot
      cloud.addChild(dot)
      if let image = point.projected(height: Starscape.screenHeight) {
        let projected = ModelEntity(
          mesh: sphere,
          materials: [UnlitMaterial(color: UIColor.systemCyan.withAlphaComponent(0.75))])
        projected.scale = [0.42, 0.42, 0.42]
        projected.position = position(image)
        projected.name = "image:\(point.a):\(point.b):\(point.c)"
        projection.addChild(projected)
      }
    }
    try buildCone()
  }
  private func buildCone() throws {
    let height = Float(Starscape.bound) * Self.scale
    let screen = Float(Starscape.screenHeight) * Self.scale
    var conePositions = [SIMD3<Float>.zero]
    var diskPositions = [SIMD3<Float>(0, screen, 0)]
    for i in 0...64 {
      let angle = Float(i) * 2 * .pi / 64
      conePositions.append([height * cos(angle), height, height * sin(angle)])
      diskPositions.append([screen * cos(angle), screen, screen * sin(angle)])
    }
    root.addChild(try fan(conePositions, color: .systemCyan, opacity: 0.045))
    projection.addChild(try fan(diskPositions, color: .systemCyan, opacity: 0.12))
    for i in 1...64 {
      line(
        from: conePositions[i], to: conePositions[i + 1],
        color: UIColor.systemCyan.withAlphaComponent(0.45), parent: root, width: 0.003)
      line(
        from: diskPositions[i], to: diskPositions[i + 1], color: .systemCyan, parent: projection,
        width: 0.004)
      if i % 8 == 1 {
        line(
          from: .zero, to: conePositions[i], color: UIColor.systemCyan.withAlphaComponent(0.35),
          parent: root, width: 0.002)
      }
    }
    let origin = ModelEntity(mesh: sphere, materials: [UnlitMaterial(color: .white)])
    origin.scale = [1.5, 1.5, 1.5]
    root.addChild(origin)
  }
  private func position(_ vector: SIMD3<Double>) -> SIMD3<Float> {
    SIMD3(Float(vector.x), Float(vector.y), Float(vector.z)) * Self.scale
  }
  private func shade(_ point: CoefficientPoint) -> UIColor {
    let hue = CGFloat(0.52 + 0.25 * Double(-point.discriminant) / 64)
    return UIColor(hue: hue, saturation: 0.65, brightness: 0.95, alpha: 1)
  }
  private func fan(_ positions: [SIMD3<Float>], color: UIColor, opacity: Float) throws -> ModelEntity {
    var descriptor = MeshDescriptor(name: "Coefficient cone or projective screen")
    descriptor.positions = MeshBuffers.Positions(positions)
    descriptor.primitives = .triangles(
      (1..<(positions.count - 1)).flatMap { [UInt32(0), UInt32($0), UInt32($0 + 1)] })
    var material = UnlitMaterial(color: color)
    material.blending = .transparent(opacity: .init(floatLiteral: opacity))
    material.faceCulling = .none
    return ModelEntity(mesh: try .generate(from: [descriptor]), materials: [material])
  }
  private func line(
    from a: SIMD3<Float>, to b: SIMD3<Float>, color: UIColor, parent: Entity, width: Float
  ) {
    let delta = b - a
    let length = simd_length(delta)
    guard length > 0.00001 else { return }
    let entity = ModelEntity(
      mesh: .generateBox(size: [width, length, width]), materials: [UnlitMaterial(color: color)])
    entity.position = (a + b) / 2
    entity.orientation = simd_quatf(from: [0, 1, 0], to: delta / length)
    parent.addChild(entity)
  }
}
