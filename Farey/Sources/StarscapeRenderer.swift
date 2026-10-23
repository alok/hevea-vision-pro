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
  /// Where the coefficient object sits relative to the viewer. Overview is the stationary default. Origin and
  /// Inhabit place it once, relative to the head center at the moment they are chosen (a `.once` head anchor: the
  /// system uses the head pose that once; the app reads no tracking transform and needs no additional sensing
  /// authorization; the object stays world-stationary afterwards, so real head motion gives parallax). Origin puts the coefficient origin, the zero polynomial, at that head center; it is not a
  /// point of the projective picture, and the two eyes sit a few centimetres either side of it. Origin also turns
  /// the object so the upper nappe's axis (+Y) points where the viewer was looking (Rx(−π/2)), or the lower
  /// nappe's (Rx(π/2)): a presentation rotation of the object, not a walk in hyperbolic space. Inhabit puts a
  /// chosen point `inhabitEye` from the head center, upright in the anchor's frame.
  enum Placement: Equatable {
    case overview
    case origin(facingLower: Bool)
    case inhabit(CoefficientPoint)
    var anchored: Bool { self != .overview }
    var isOrigin: Bool { if case .origin = self { true } else { false } }
    /// Same anchor: an Origin nappe flip keeps the anchor; any other change re-anchors at the current head.
    func sharesAnchor(with other: Placement) -> Bool {
      switch (self, other) {
      case (.origin, .origin): return true
      case (.inhabit(let a), .inhabit(let b)): return a == b
      default: return false
      }
    }
  }
  /// The inhabited point sits slightly below and 35 cm ahead of the head center when Inhabit is chosen.
  static let inhabitEye: SIMD3<Float> = [0, -0.08, -0.35]
  /// Parent of `root` in Overview; add it and `anchorHost` to the scene.
  let stage = Entity()
  /// Holds the current one-time head anchor, as in Apple's head-and-device-transform sample.
  let anchorHost = Entity()
  private(set) var headAnchor: AnchorEntity?
  private(set) var placement = Placement.overview
  /// The placement epoch the current anchor was made for; see GalleryModel.coefficientPlacementEpoch.
  private(set) var anchorEpoch = 0
  let root = Entity()
  private let cloud = Entity()
  private let cone = Entity()
  private let projection = Entity()
  private let selection = Entity()
  private let plane = Entity()
  private var emphasized: Set<CoefficientPoint> = []
  /// Whether dots are sized by the Origin rule (CoefficientPalette.originRadiusFactor) rather than the overview's.
  private(set) var originSized = false
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
    stage.addChild(root)
    for child in [cone, cloud, projection, plane, selection] { root.addChild(child) }
  }
  var pointCount: Int { dots.count }

  func render(
    selected: CoefficientPoint, showProjection: Bool, viewpoint: Int, crop next: Crop = Crop(),
    cuttingPlane: CuttingPlane? = nil, second: CoefficientPoint? = nil, placement nextPlacement: Placement = .overview,
    placementEpoch: Int = 0
  ) throws -> String {
    if crop != next { try build(next) }
    place(nextPlacement, epoch: placementEpoch, viewpoint: viewpoint)
    sizeForOrigin(nextPlacement.isOrigin, colorLower: next.colorLower)
    projection.isEnabled = showProjection
    let planeReceipt = try renderPlane(cuttingPlane, second: second, showProjection: showProjection, crop: next)
    selection.children.removeAll()
    let shown = dots[selected] != nil
    if shown {
      let end = position(selected.vector)
      line(from: .zero, to: end, rgb: CoefficientPalette.selectionRay, opacity: 0.35, parent: selection)
      let factor = effectiveFactor(selected, colorLower: next.colorLower)
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
      + planeReceipt + placementReceipt
  }

  private func build(_ next: Crop) throws {
    for group in [cloud, cone, projection] { group.children.removeAll() }
    dots.removeAll()
    // New dots start at scale 1; Origin sizing and plane emphasis are reapplied to them.
    originSized = false
    emphasized = []
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

// Viewer placement and cutting planes; kept beside the class so they share its private state.
extension StarscapeRenderer {
  /// A dot's drawn radius as a multiple of glyphRadius: its mesh's overview factor times its current scale.
  func effectiveFactor(_ point: CoefficientPoint, colorLower: Bool) -> Float {
    Float(CoefficientPalette.radiusFactor(for: point, colorLower: colorLower)) * (dots[point]?.scale.x ?? 1)
  }
  /// The scale a dot returns to when it is not emphasized: 1 in Overview and Inhabit; at Origin, the ratio of the
  /// Origin rule to the overview factor already built into its mesh.
  private func baseScale(_ point: CoefficientPoint, colorLower: Bool) -> Float {
    guard originSized else { return 1 }
    return Float(
      CoefficientPalette.originRadiusFactor(for: point) / CoefficientPalette.radiusFactor(for: point, colorLower: colorLower))
  }
  private func sizeForOrigin(_ origin: Bool, colorLower: Bool) {
    guard origin != originSized else { return }
    originSized = origin
    for (point, dot) in dots { dot.scale = .one * baseScale(point, colorLower: colorLower) }
    emphasized = []
  }
  private var placementReceipt: String {
    switch placement {
    case .overview: return ""
    case .origin(let lower): return " · origin at head center, \(lower ? "lower" : "upper") nappe ahead"
    case .inhabit(let point): return " · inhabiting \(point.label)"
    }
  }

  /// Moves the object between the stationary overview and a one-time head anchor; see `Placement`. A new anchor,
  /// set from the head center now, is made for a new explicit request (epoch) or a change of anchored mode; the
  /// Origin nappe flip and ordinary renders keep the current one.
  func place(_ next: Placement, epoch: Int, viewpoint: Int) {
    let reanchor =
      next.anchored && (headAnchor == nil || epoch != anchorEpoch || !next.sharesAnchor(with: placement))
    if reanchor || (!next.anchored && headAnchor != nil) {
      headAnchor?.removeFromParent()
      headAnchor = nil
      if next.anchored {
        let anchor = AnchorEntity(.head)
        anchor.anchoring.trackingMode = .once
        anchor.name = "head-anchor-once"
        anchorHost.addChild(anchor)
        anchor.addChild(root)
        headAnchor = anchor
        anchorEpoch = epoch
      } else {
        stage.addChild(root)
      }
    }
    placement = next
    switch next {
    case .overview:
      root.position = Self.center
      root.orientation =
        simd_quatf(angle: Self.viewPitch[viewpoint], axis: [1, 0, 0])
        * simd_quatf(angle: -Self.viewYaw[viewpoint], axis: [0, 1, 0])
    case .origin(let lower):
      root.position = .zero
      root.orientation = simd_quatf(angle: lower ? .pi / 2 : -.pi / 2, axis: [1, 0, 0])
    case .inhabit(let point):
      root.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
      root.position = Self.inhabitEye - position(point.vector)
    }
  }

  /// The browser's plane rendering: amber rings on displayed interior points lying exactly in the plane (upper
  /// members also drawn 1.35 times larger), a faint sheet inside the cone's bounding cylinder, its boundary, the two
  /// endpoint directions on the cone, and the second point of a pair.
  private func renderPlane(
    _ cutting: CuttingPlane?, second: CoefficientPoint?, showProjection: Bool, crop: Crop
  ) throws -> String {
    plane.children.removeAll()
    for point in emphasized { dots[point]?.scale = .one * baseScale(point, colorLower: crop.colorLower) }
    emphasized = []
    guard let cutting else { return "" }
    let amber = CoefficientPalette.planeAmber
    let members = dots.keys.filter { $0.discriminant < 0 && cutting.contains($0) }
    for point in members {
      guard let dot = dots[point] else { continue }
      // The Origin rule replaces the plane emphasis, as in the browser.
      if point.kind == .upper && !originSized {
        dot.scale = [1.35, 1.35, 1.35]
        emphasized.insert(point)
      }
      let factor = effectiveFactor(point, colorLower: crop.colorLower)
      let ring = ModelEntity(
        mesh: .generateSphere(radius: Self.glyphRadius * factor * 1.55), materials: [ringMaterial(amber)])
      ring.position = dot.position
      ring.name = "plane-member:\(point.a):\(point.b):\(point.c)"
      plane.addChild(ring)
    }
    let boundary = cutting.section(radius: Double(crop.radius)).map { position($0) }
    let sheet = try fan([.zero] + boundary, rgb: amber, opacity: 0.045)
    sheet.name = "plane-sheet"
    plane.addChild(sheet)
    for i in 1..<boundary.count {
      line(from: boundary[i - 1], to: boundary[i], rgb: amber, opacity: 0.35, parent: plane)
    }
    let reach = Double(crop.radius)
    for direction in cutting.coneDirections {
      line(from: position(-reach * direction), to: position(reach * direction), rgb: amber, opacity: 0.7, parent: plane)
    }
    if showProjection {
      let ends = cutting.coneDirections.map { position(Starscape.screenHeight * $0) }
      line(from: ends[0], to: ends[1], rgb: amber, opacity: 0.9, parent: plane)
    }
    var secondReceipt = ""
    if let second {
      if let dot = dots[second] {
        let size = Self.glyphRadius * effectiveFactor(second, colorLower: crop.colorLower) * 1.9
        let marker = ModelEntity(mesh: .generateSphere(radius: size), materials: [ringMaterial(amber)])
        marker.position = dot.position
        marker.name = "pair-second"
        plane.addChild(marker)
      } else {
        secondReceipt = " · second point hidden by this filter"
      }
    }
    // Counts displayed coefficient triples, multiples and sign partners included, not distinct roots.
    return " · plane \(cutting.equation) · \(members.count) displayed interior triples" + secondReceipt
  }
  private func ringMaterial(_ rgb: SIMD3<Double>) -> UnlitMaterial {
    var ring = UnlitMaterial(applyPostProcessToneMap: false)
    ring.color = .init(tint: UIColor(red: rgb.x, green: rgb.y, blue: rgb.z, alpha: 1))
    ring.faceCulling = .front
    return ring
  }
}
