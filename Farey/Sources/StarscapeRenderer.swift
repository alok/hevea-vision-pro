// SPDX-License-Identifier: GPL-3.0-or-later
import RealityKit
import SwiftUI

#if canImport(FareyCore)
  import FareyCore
#endif

/// The browser's signed coefficient ball and double cone as RealityKit entities (one per point, so the radius is
/// capped at CoefficientBall.maximumRadius). Centers are exact: (−b, a+c, c−a) times `scale`. Glyphs are small unlit
/// spheres with a fixed physical radius; the browser's screen-pixel minimum, knee and cap have no physical-sphere
/// equivalent, so apparent sizes follow ordinary perspective here.
@MainActor final class StarscapeRenderer {
  struct Crop: Equatable {
    var radius = CoefficientBall.defaultRadius
    var upperOnly = false
    var colorLower = false
  }
  let root = Entity()
  private let cloud = Entity()
  private let cone = Entity()
  private let projection = Entity()
  private let selection = Entity()
  /// Physical ball radius in metres for every crop; at R6 this is the browser's 0.16 m per lattice unit.
  static let ballRadius: Float = 0.96
  /// Base glyph radius in metres; nonprimitive ramp-colored forms use 0.72 of it. The browser's base is 0.013 but it
  /// compresses radii above a 2.5-pixel knee; at the matched oblique pose a 0.013 m sphere drew about 1.75 times
  /// the browser's diameter (14 versus 8 pixels for (3,0,3)), so native uses a smaller point-like default.
  static let glyphRadius: Float = 0.0075
  static let center: SIMD3<Float> = [0, 1.4, -3.1]
  /// Stationary orientations. Oblique maps the browser's default camera direction (2.4, 1.5, 4.6) from the center
  /// onto the viewer's line of sight; Other side adds the browser's 60° turn; Side view is level.
  static let viewYaw: [Float] = [0.4806, 0.4806 + .pi / 3, 0]
  static let viewPitch: [Float] = [0.2814, 0.2814, 0]
  private(set) var scale: Float = ballRadius / Float(CoefficientBall.defaultRadius)
  private(set) var crop: Crop?
  private var dots: [CoefficientPoint: ModelEntity] = [:]
  private var materials: [UInt32: UnlitMaterial] = [:]
  private let meshes = [
    MeshResource.generateSphere(radius: glyphRadius), MeshResource.generateSphere(radius: glyphRadius * 0.72),
  ]

  init() {
    root.position = Self.center
    for child in [cone, cloud, projection, selection] { root.addChild(child) }
  }
  var pointCount: Int { dots.count }

  func render(
    selected: CoefficientPoint, showProjection: Bool, viewpoint: Int, crop next: Crop = Crop()
  ) throws -> String {
    if crop != next { try build(next) }
    root.orientation =
      simd_quatf(angle: Self.viewPitch[viewpoint], axis: [1, 0, 0])
      * simd_quatf(angle: -Self.viewYaw[viewpoint], axis: [0, 1, 0])
    projection.isEnabled = showProjection
    selection.children.removeAll()
    let shown = dots[selected] != nil
    if shown {
      let end = position(selected.vector)
      line(from: .zero, to: end, rgb: CoefficientPalette.selectionRay, opacity: 0.35, parent: selection)
      let factor = Float(CoefficientPalette.radiusFactor(for: selected, colorLower: next.colorLower))
      let outline = ModelEntity(
        mesh: .generateSphere(radius: Self.glyphRadius * factor * 1.55), materials: [outlineMaterial])
      outline.position = end
      outline.name = "selection-outline"
      selection.addChild(outline)
      if showProjection, let image = selected.radialImage(height: Starscape.screenHeight) {
        let projected = position(image)
        line(from: .zero, to: projected, rgb: [1, 1, 1], opacity: 1, parent: selection)
        let marker = ModelEntity(mesh: meshes[0], materials: [UnlitMaterial(color: .white)])
        marker.position = projected
        marker.name = "selection-image"
        selection.addChild(marker)
      }
    }
    return "\(dots.count) coefficient points · radius \(next.radius) (native cap \(CoefficientBall.maximumRadius))"
      + (next.upperOnly ? " · upper only" : "") + (shown ? "" : " · selected point hidden by this filter")
  }

  private func build(_ next: Crop) throws {
    for group in [cloud, cone, projection] { group.children.removeAll() }
    dots.removeAll()
    scale = Self.ballRadius / Float(next.radius)
    for point in CoefficientBall.points(radius: next.radius, upperOnly: next.upperOnly) {
      guard let rgb = CoefficientPalette.color(for: point, colorLower: next.colorLower) else { continue }
      let factor = CoefficientPalette.radiusFactor(for: point, colorLower: next.colorLower)
      let dot = ModelEntity(mesh: meshes[factor < 1 ? 1 : 0], materials: [material(rgb)])
      dot.position = position(point.vector)
      dot.name = "coefficient:\(point.a):\(point.b):\(point.c)"
      dot.components.set(InputTargetComponent())
      dot.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.03)]))
      var accessibility = AccessibilityComponent()
      accessibility.label = "Coefficient point \(point.label), discriminant \(point.discriminant)"
      accessibility.isAccessibilityElement = true
      accessibility.traits = [.button]
      dot.components.set(accessibility)
      dots[point] = dot
      cloud.addChild(dot)
      if let image = point.radialImage(height: Starscape.screenHeight) {
        let projected = ModelEntity(
          mesh: meshes[1], materials: [UnlitMaterial(color: UIColor(red: 0.33, green: 0.91, blue: 0.96, alpha: 1))])
        projected.scale = [0.5, 0.5, 0.5]
        projected.position = position(image)
        projected.name = "image:\(point.a):\(point.b):\(point.c)"
        projection.addChild(projected)
      }
    }
    try buildCone(radius: next.radius)
    crop = next
  }
  private func buildCone(radius: Int) throws {
    let screen = Float(Starscape.screenHeight) * scale
    var diskPositions = [SIMD3<Float>(0, screen, 0)]
    for i in 0...64 {
      let angle = Float(i) * 2 * .pi / 64
      diskPositions.append([screen * cos(angle), screen, screen * sin(angle)])
    }
    for sign: Float in [1, -1] {
      let h = Self.ballRadius * sign, r = Self.ballRadius
      var positions = [SIMD3<Float>.zero]
      for i in 0...64 {
        let angle = Float(i) * 2 * .pi / 64
        positions.append([r * cos(angle), h, r * sin(angle)])
      }
      cone.addChild(try fan(positions, rgb: CoefficientPalette.guideCyan, opacity: 0.018))
      for i in 1...64 {
        line(from: positions[i], to: positions[i + 1], rgb: CoefficientPalette.guideLine, opacity: 0.26, parent: cone)
        if i % 8 == 1 {
          line(from: .zero, to: positions[i], rgb: CoefficientPalette.guideLine, opacity: 0.26, parent: cone)
        }
      }
    }
    projection.addChild(try fan(diskPositions, rgb: CoefficientPalette.guideCyan, opacity: 0.1))
    for i in 1...64 {
      line(
        from: diskPositions[i], to: diskPositions[i + 1], rgb: CoefficientPalette.guideCyan, opacity: 0.8,
        parent: projection, width: 0.003)
    }
    let origin = ModelEntity(mesh: meshes[0], materials: [UnlitMaterial(color: .white)])
    origin.name = "origin"
    cone.addChild(origin)
  }
  private var outlineMaterial: UnlitMaterial {
    var outline = UnlitMaterial(applyPostProcessToneMap: false)
    outline.color = .init(tint: .white)
    outline.faceCulling = .front
    return outline
  }
  private func material(_ rgb: SIMD3<Double>) -> UnlitMaterial {
    let bytes = (rgb * 255).rounded(.toNearestOrAwayFromZero)
    let key = UInt32(bytes.x) << 16 | UInt32(bytes.y) << 8 | UInt32(bytes.z)
    if let cached = materials[key] { return cached }
    // Exact sRGB palette values: no post-process tone mapping.
    var made = UnlitMaterial(applyPostProcessToneMap: false)
    made.color = .init(tint: UIColor(red: rgb.x, green: rgb.y, blue: rgb.z, alpha: 1))
    materials[key] = made
    return made
  }
  func position(_ vector: SIMD3<Double>) -> SIMD3<Float> {
    SIMD3(Float(vector.x), Float(vector.y), Float(vector.z)) * scale
  }
  /// An unlit material drawing rgb at the browser's sRGB-blended opacity (see linearLightOpacity).
  private func guideMaterial(_ rgb: SIMD3<Double>, opacity: Double) -> UnlitMaterial {
    var material = UnlitMaterial(applyPostProcessToneMap: false)
    material.color = .init(tint: UIColor(red: rgb.x, green: rgb.y, blue: rgb.z, alpha: 1))
    if opacity < 1 {
      let linear = CoefficientPalette.linearLightOpacity(opacity, color: rgb)
      material.blending = .transparent(opacity: .init(floatLiteral: Float(linear)))
    }
    return material
  }
  private func fan(_ positions: [SIMD3<Float>], rgb: SIMD3<Double>, opacity: Double) throws -> ModelEntity {
    var descriptor = MeshDescriptor(name: "Coefficient cone or projective screen")
    descriptor.positions = MeshBuffers.Positions(positions)
    descriptor.primitives = .triangles(
      (1..<(positions.count - 1)).flatMap { [UInt32(0), UInt32($0), UInt32($0 + 1)] })
    var material = guideMaterial(rgb, opacity: opacity)
    material.faceCulling = .none
    return ModelEntity(mesh: try .generate(from: [descriptor]), materials: [material])
  }
  private func line(
    from a: SIMD3<Float>, to b: SIMD3<Float>, rgb: SIMD3<Double>, opacity: Double, parent: Entity,
    width: Float = 0.002
  ) {
    let delta = b - a
    let length = simd_length(delta)
    guard length > 0.00001 else { return }
    let entity = ModelEntity(
      mesh: .generateBox(size: [width, length, width]), materials: [guideMaterial(rgb, opacity: opacity)])
    entity.position = (a + b) / 2
    entity.orientation = simd_quatf(from: [0, 1, 0], to: delta / length)
    parent.addChild(entity)
  }
}
