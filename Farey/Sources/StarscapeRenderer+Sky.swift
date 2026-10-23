// SPDX-License-Identifier: GPL-3.0-or-later
import RealityKit

#if canImport(FareyCore)
  import FareyCore
#endif

// The eye-at-origin drag: a hit target around the coefficient origin and the map from a scene point to a display
// direction. The drag acts only at Origin; in Overview a drag changes nothing.
extension StarscapeRenderer {
  /// The prepared shell's vertex radius, beyond the ball at the identity; fitSky() enlarges it when g carries stars
  /// further.
  static let skyRadius: Float = 2.4
  static let skyClearance: Float = 0.1
  /// The shell's flat facets lie inside the sphere through its vertices: this is the least distance from the origin
  /// to any facet's plane (degenerate pole facets skipped), about 0.983 of skyRadius for 12 × 24 bands. Every point
  /// of the shell is at least this far out.
  static let skyInradius: Float = {
    let (positions, faces) = skyMesh()
    return stride(from: 0, to: faces.count, by: 3).compactMap { i -> Float? in
      let a = positions[Int(faces[i])], b = positions[Int(faces[i + 1])], c = positions[Int(faces[i + 2])]
      let normal = simd_cross(b - a, c - a)
      return simd_length(normal) < 1e-6 ? nil : abs(simd_dot(simd_normalize(normal), a))
    }.min() ?? 0
  }()
  /// The shell: a latitude-longitude triangle mesh of radius skyRadius.
  static func skyMesh(bands: Int = 12, sectors: Int = 24) -> ([SIMD3<Float>], [UInt16]) {
    var positions: [SIMD3<Float>] = [], faces: [UInt16] = []
    for band in 0...bands {
      let polar = Float.pi * Float(band) / Float(bands)
      for sector in 0...sectors {
        let azimuth = 2 * Float.pi * Float(sector) / Float(sectors)
        positions.append(skyRadius * [sin(polar) * cos(azimuth), cos(polar), sin(polar) * sin(azimuth)])
      }
    }
    for band in 0..<bands {
      for sector in 0..<sectors {
        let a = UInt16(band * (sectors + 1) + sector), b = a + UInt16(sectors + 1)
        faces += [a, b, a + 1, a + 1, b, b + 1]
      }
    }
    return (positions, faces)
  }
  /// Keeps every facet of the shell beyond every star's collision sphere under the current g and glyph sizes, so a
  /// star is always hit before the sky. A uniform scale of the one prepared shape: the cloud and g are untouched, and
  /// the drag direction is read in `root`'s frame, which this scale does not change.
  func fitSky() {
    sky.scale = .one * max(1, (collisionReach + Self.skyClearance) / Self.skyInradius)
  }
  /// Gives the sky its collision shape: a static triangle mesh, which a ray from inside can hit (a convex sphere
  /// would be solid there). Interactive only while enabled, that is, at Origin.
  func prepareSky() async throws {
    guard sky.components[CollisionComponent.self] == nil else { return }
    let (positions, faces) = Self.skyMesh()
    let shape = try await ShapeResource.generateStaticMesh(positions: positions, faceIndices: faces)
    sky.components.set(CollisionComponent(shapes: [shape]))
    sky.components.set(InputTargetComponent())
  }
  /// The sky target's state for the opt-in input diagnostics.
  var skyState: String {
    let collision = sky.components[CollisionComponent.self] != nil, target = sky.components[InputTargetComponent.self] != nil
    return "collision \(collision ? "yes" : "no") · input target \(target ? "yes" : "no") · enabled \(sky.isEnabledInHierarchy)"
      + String(format: " · scale %.3f", sky.scale.x)
  }
  /// The display direction from the coefficient origin to a point given in scene coordinates (the object's
  /// placement and Origin turn are undone; length is irrelevant to the Klein point).
  func displayDirection(ofScenePoint point: SIMD3<Float>) -> SIMD3<Double> {
    let local = root.convert(position: point, from: nil)
    return SIMD3(Double(local.x), Double(local.y), Double(local.z))
  }
}
