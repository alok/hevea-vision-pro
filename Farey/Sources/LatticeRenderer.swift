// SPDX-License-Identifier: GPL-3.0-or-later
import RealityKit
import SwiftUI

#if canImport(FareyCore)
  import FareyCore
#endif

/// A rigidly placed copy of Z², with the rational p/q at the point (q,p).
/// The upright direction plane is perpendicular to the lattice, not an extrusion of a Farey arc.
@MainActor final class LatticeRenderer {
  static let landmarks = [
    Rational(1, 1), Rational(1, 2), Rational(2, 3), Rational(3, 5), Rational(3, 2),
    Rational(6, 10),
  ]
  let root = Entity()
  private let base = Entity()
  private let selection = Entity()
  private var points: [LatticePoint: ModelEntity] = [:]
  private var landmarkLabels: [Rational: Entity] = [:]
  private var previousBound = 0
  private let spacing: Float = 0.25
  private let sphere = MeshResource.generateSphere(radius: 0.036)
  private let blue = SimpleMaterial(
    color: UIColor(red: 0.12, green: 0.48, blue: 0.86, alpha: 1),
    roughness: 0.28, isMetallic: false)
  private let muted = SimpleMaterial(
    color: UIColor(red: 0.12, green: 0.25, blue: 0.36, alpha: 1),
    roughness: 0.55, isMetallic: false)
  private let green = SimpleMaterial(color: UIColor.systemGreen, roughness: 0.3, isMetallic: false)
  private let orange = SimpleMaterial(
    color: UIColor.systemOrange, roughness: 0.3, isMetallic: false)
  private let leftMaterial = SimpleMaterial(color: UIColor.cyan, roughness: 0.3, isMetallic: false)
  private let rightMaterial = SimpleMaterial(
    color: UIColor.systemPurple, roughness: 0.3, isMetallic: false)
  private let inspectedMaterial = SimpleMaterial(color: UIColor.white, roughness: 0.3, isMetallic: false)
  private let arrow = MeshResource.generateCone(height: 0.06, radius: 0.022)

  init() {
    root.position = [0, 1.8, -2.1]
    root.addChild(base)
    root.addChild(selection)
    let key = PointLight()
    key.light.color = .white
    key.light.intensity = 5000
    key.light.attenuationRadius = 12
    key.position = [-1.5, 3, 0.5]
    root.addChild(key)
    let fill = PointLight()
    fill.light.color = UIColor(red: 0.4, green: 0.7, blue: 1, alpha: 1)
    fill.light.intensity = 2200
    fill.light.attenuationRadius = 12
    fill.position = [1, -1.5, 1.5]
    root.addChild(fill)
  }

  private func position(p: Float, q: Float) -> SIMD3<Float> {
    let diagonal = spacing / sqrt(2)
    return [(p - q) * diagonal, 0, -(p + q) * diagonal]
  }

  private func position(_ rational: Rational) -> SIMD3<Float> {
    position(p: Float(rational.p), q: Float(rational.q))
  }
  func addLandmark(_ entity: Entity, at rational: Rational) {
    entity.position = position(rational) + [0, 0.18, 0]
    entity.orientation = simd_quatf(angle: -.pi / 7, axis: [1, 0, 0])
    entity.scale = [3, 3, 3]
    landmarkLabels[rational] = entity
    root.addChild(entity)
  }

  private func planeEndpoint(_ rational: Rational, bound: Int) -> SIMD3<Float> {
    let largest = max(Float(rational.p), Float(rational.q), 1)
    let scale = Float(bound) / largest
    return position(p: Float(rational.p) * scale, q: Float(rational.q) * scale)
  }

  func render(
    state: FareyState, bound: Int, viewpoint: Int, alternateCF: Bool = false, spotlight: Rational? = nil
  ) throws -> String {
    let start = ContinuousClock.now
    if bound != previousBound { try rebuildBase(bound: bound) }
    for (rational, label) in landmarkLabels {
      label.isEnabled = rational.p <= bound && rational.q <= bound
    }

    selection.children.removeAll()
    updatePointColors(for: state)
    try addCFRings(state.cfPoints(alternate: alternateCF), bound: bound)
    if let spotlight, spotlight.p <= bound, spotlight.q <= bound { try addSpotlight(spotlight) }
    let end = planeEndpoint(state.mediant, bound: bound)
    let height: SIMD3<Float> = [0, 0.65, 0]
    var descriptor = MeshDescriptor(name: "Exact rational direction plane")
    descriptor.positions = MeshBuffers.Positions([.zero, end, height, end + height])
    descriptor.normals = MeshBuffers.Normals(
      Array(
        repeating:
          simd_normalize(simd_cross(end, height)), count: 4))
    descriptor.primitives = .triangles([0, 1, 2, 2, 1, 3])
    var planeMaterial = UnlitMaterial(color: UIColor.systemGreen)
    planeMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.16))
    planeMaterial.faceCulling = .none
    selection.addChild(
      ModelEntity(mesh: try .generate(from: [descriptor]), materials: [planeMaterial]))
    selection.addChild(
      try lines(
        [[.zero, end], [height, end + height]],
        radius: 0.006, color: .systemGreen))

    let within = state.mediant.p <= bound && state.mediant.q <= bound
    if within { try addMediantBasis(state) }
    if let point = state.selectedPoint, point.rational != state.mediant,
      point.p <= bound, point.q <= bound, !Self.landmarks.contains(point.rational) {
      label(point.rational.description, at: position(point.rational) + [-0.05, 0.14, 0],
        color: .white, parent: selection)
    }
    // Preview translations are equivalent to moving the viewer oppositely.
    // They reveal parallax while leaving the actual camera stationary.
    root.position = [[0, 1.8, -2.1], [0.45, 1.8, -2.1], [-0.45, 1.8, -2.1]][viewpoint]
    root.orientation = simd_quatf(angle: .pi / 7, axis: [1, 0, 0])
    let elapsed = start.duration(to: .now)
    let count = points.keys.filter { $0.isOnRay(state.mediant) }.count
    return "\(points.count) lattice points · \(count) on the rational ray · \(elapsed) update"
      + (within ? "" : " · primitive vector beyond this finite grid")
  }

  private func addMediantBasis(_ state: FareyState) throws {
    let left = position(state.left)
    let right = position(state.right)
    let sum = position(state.mediant)
    selection.addChild(try lines([[.zero, left], [right, sum]], radius: 0.009, color: .cyan))
    selection.addChild(
      try lines([[.zero, right], [left, sum]], radius: 0.009, color: .systemPurple))
    selection.addChild(try lines([[.zero, sum]], radius: 0.009, color: .systemOrange))
    addArrow(to: left, color: .cyan)
    addArrow(to: right, color: .systemPurple)
    addArrow(to: sum, color: .systemOrange)
    if !Self.landmarks.contains(state.mediant) {
      label(
        state.mediant.description, at: sum + [-0.05, 0.14, 0], color: .orange, parent: selection)
    }
    if !Self.landmarks.contains(state.left) {
      label(state.left.description, at: left + [-0.05, 0.11, 0], color: .cyan, parent: selection)
    }
    if !Self.landmarks.contains(state.right) {
      label(
        state.right.description, at: right + [-0.05, 0.11, 0], color: .systemPurple,
        parent: selection)
    }
  }

  private func addArrow(to end: SIMD3<Float>, color: UIColor) {
    let direction = simd_normalize(end)
    let entity = ModelEntity(mesh: arrow, materials: [UnlitMaterial(color: color)])
    entity.position = end - direction * 0.07 + [0, 0.012, 0]
    entity.orientation = simd_quatf(from: [0, 1, 0], to: direction)
    selection.addChild(entity)
  }

  private func updatePointColors(for state: FareyState) {
    for (point, entity) in points {
      let selected = point.rational == state.mediant
      let inspected = point == state.selectedPoint && !selected
      if inspected {
        entity.model?.materials = [inspectedMaterial]
      } else if selected {
        entity.model?.materials = [orange]
      } else if point.rational == state.left {
        entity.model?.materials = [leftMaterial]
      } else if point.rational == state.right {
        entity.model?.materials = [rightMaterial]
      } else if point.isOnRay(state.mediant) {
        entity.model?.materials = [green]
      } else {
        entity.model?.materials = [point.isPrimitive ? blue : muted]
      }
      entity.scale = selected || inspected ? [1.65, 1.65, 1.65] : [1, 1, 1]
    }
  }

  private func rebuildBase(bound: Int) throws {
    base.children.removeAll()
    points.removeAll()
    var gridLines: [[SIMD3<Float>]] = []
    for n in 0...bound {
      gridLines.append([position(p: Float(n), q: 0), position(p: Float(n), q: Float(bound))])
      gridLines.append([position(p: 0, q: Float(n)), position(p: Float(bound), q: Float(n))])
    }
    base.addChild(try lines(gridLines, radius: 0.002, color: UIColor(white: 0.2, alpha: 1)))
    for point in LatticePoint.grid(bound: bound) {
      let entity = ModelEntity(mesh: sphere, materials: [point.isPrimitive ? blue : muted])
      entity.position = position(point.rational)
      entity.name = "rational:\(point.p):\(point.q)"
      if point.p > 0 && point.q > 0 {
        entity.components.set(InputTargetComponent())
        entity.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.065)]))
        entity.components.set(HoverEffectComponent())
        var accessibility = AccessibilityComponent()
        accessibility.isAccessibilityElement = true
        accessibility.traits = .button
        accessibility.systemActions = .activate
        accessibility.label = "Lattice point (\(point.q), \(point.p)), fraction \(point.p)/\(point.q)"
        entity.components.set(accessibility)
      }
      points[point] = entity
      base.addChild(entity)
    }
    let origin = ModelEntity(
      mesh: sphere,
      materials: [
        SimpleMaterial(
          color: .white,
          roughness: 0.3, isMetallic: false)
      ])
    origin.scale = [1.5, 1.5, 1.5]
    base.addChild(origin)
    label("q", at: position(p: 0, q: Float(bound)) + [0, 0.12, 0], color: .cyan, parent: base)
    label("p", at: position(p: Float(bound), q: 0) + [0, 0.12, 0], color: .cyan, parent: base)
    previousBound = bound
  }

  private func label(_ text: String, at position: SIMD3<Float>, color: UIColor, parent: Entity) {
    let mesh = MeshResource.generateText(
      text, extrusionDepth: 0.001,
      font: .systemFont(ofSize: 0.075, weight: .medium))
    let entity = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: color)])
    entity.position = position
    entity.orientation = simd_quatf(angle: -.pi / 7, axis: [1, 0, 0])
    parent.addChild(entity)
  }

  private func lines(
    _ paths: [[SIMD3<Float>]], radius: Float, color: UIColor
  ) throws -> ModelEntity {
    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var indices: [UInt32] = []
    let sides = 8
    for path in paths where path.count >= 2 {
      let direction = path[1] - path[0]
      guard simd_length(direction) > 0.00001 else { continue }
      let tangent = simd_normalize(direction)
      let axis: SIMD3<Float> = abs(tangent.y) > 0.9 ? [1, 0, 0] : [0, 1, 0]
      let a = simd_normalize(simd_cross(tangent, axis))
      let b = simd_cross(tangent, a)
      let offset = positions.count
      for center in path {
        for side in 0..<sides {
          let angle = Float(side) * 2 * .pi / Float(sides)
          let normal = a * cos(angle) + b * sin(angle)
          positions.append(center + radius * normal)
          normals.append(normal)
        }
      }
      for side in 0..<sides {
        let a = UInt32(offset + side)
        let b = UInt32(offset + (side + 1) % sides)
        let c = a + UInt32(sides)
        let d = b + UInt32(sides)
        indices += [a, b, c, b, d, c]
      }
    }
    var mesh = MeshDescriptor(name: "Lattice lines")
    mesh.positions = MeshBuffers.Positions(positions)
    mesh.normals = MeshBuffers.Normals(normals)
    mesh.primitives = .triangles(indices)
    return ModelEntity(mesh: try .generate(from: [mesh]), materials: [UnlitMaterial(color: color)])
  }
}

extension LatticeRenderer {
  private func addSpotlight(_ point: Rational) throws {
    let center = position(point) + [0, 0.025, 0]
    var paths: [[SIMD3<Float>]] = []
    for radius in [Float(0.10), 0.135] {
      let ring = (0...24).map { index in
        let angle = Float(index) * 2 * .pi / 24
        return center + SIMD3<Float>(cos(angle) * radius, 0, sin(angle) * radius)
      }
      paths += zip(ring, ring.dropFirst()).map { [$0, $1] }
    }
    selection.addChild(try lines(paths, radius: 0.0035, color: .white))
  }

  private func addCFRings(_ points: [CFPoint], bound: Int) throws {
    for convergent in [true, false] {
      var paths: [[SIMD3<Float>]] = []
      for point in points where point.isConvergent == convergent
        && point.rational.p <= bound && point.rational.q <= bound {
        let center = position(point.rational) + [0, 0.015, 0]
        let radius: Float = convergent ? 0.075 : 0.055
        let ring = (0...20).map { index in
          let angle = Float(index) * 2 * .pi / 20
          return center + SIMD3<Float>(cos(angle) * radius, 0, sin(angle) * radius)
        }
        paths += zip(ring, ring.dropFirst()).map { [$0, $1] }
      }
      if !paths.isEmpty {
        selection.addChild(try lines(paths, radius: 0.003,
          color: convergent ? UIColor.systemYellow : UIColor.lightGray))
      }
    }
  }

}
