import HeveaCore
import RealityKit
import UIKit

struct SphereAnalysisBundle: Sendable {
  let mesh: SphereMesh
  let diagnosticReport: SphereMeshDiagnosticReport

  var diagnosticSnapshot: SphereDiagnosticSnapshot {
    SphereDiagnosticSnapshot(
      vertexCount: mesh.grid.vertexCount,
      triangleCount: mesh.grid.triangleCount,
      measuredContainingRadius: diagnosticReport.containingRadius.measuredMaximumRadius,
      declaredContainingRadius: diagnosticReport.containingRadius.declaredMaximumRadius,
      eulerCharacteristic: diagnosticReport.topology.eulerCharacteristic,
      seamResidual: diagnosticReport.seam.maximumPositionResidual,
      fingerprint: diagnosticReport.deterministicFingerprint
    )
  }
}

enum SphereAnalysisEngine {
  static func generate(stage: SphereStage) throws -> SphereAnalysisBundle {
    let mesh = try SphereMeshGenerator.generate(stage: stage)
    let report = try SphereMeshDiagnostics.validate(mesh)
    return SphereAnalysisBundle(mesh: mesh, diagnosticReport: report)
  }
}

@MainActor
enum SphereRealityBridge {
  static let surfaceEntityName = "hevea-reduced-sphere-surface"
  static let innerSurfaceEntityName = "hevea-reduced-sphere-inner-surface"

  /// Converts the core's z-up coordinates into RealityKit's y-up frame while
  /// preserving handedness.
  static func displayVector(_ value: Vector3) -> SIMD3<Float> {
    SIMD3(Float(value.x), Float(value.z), -Float(value.y))
  }

  static func makeSurface(
    from analysis: SphereAnalysisBundle,
    sectionAmount: Double
  ) throws -> Entity {
    let assembly = Entity()
    assembly.name = "hevea-reduced-sphere-double-sided-shell"

    let visibleTriangles = sectionedTriangleIndices(
      from: analysis.mesh,
      sectionAmount: sectionAmount
    )
    let faceMaterials = materialIndices(
      for: visibleTriangles,
      mesh: analysis.mesh
    )
    let materials = surfacePalette()

    let outer = try makeModel(
      name: surfaceEntityName,
      mesh: analysis.mesh,
      indices: visibleTriangles,
      faceMaterials: faceMaterials,
      materials: materials,
      inward: false
    )
    assembly.addChild(outer)

    // RealityKit's default rasterization culls back faces. A second descriptor
    // with reversed winding and normals makes the collapsed shell legible from
    // Interior without changing the mathematical mesh or its diagnostics.
    let inwardTriangles = reversedWinding(visibleTriangles)
    let inner = try makeModel(
      name: innerSurfaceEntityName,
      mesh: analysis.mesh,
      indices: inwardTriangles,
      faceMaterials: faceMaterials,
      materials: materials,
      inward: true
    )
    assembly.addChild(inner)
    return assembly
  }

  static func makeUnitSphereGhost() -> ModelEntity {
    var material = UnlitMaterial()
    material.color = .init(
      tint: UIColor(red: 0.55, green: 0.78, blue: 1, alpha: 0.11)
    )
    material.blending = .transparent(opacity: 0.10)
    let entity = ModelEntity(
      mesh: .generateSphere(radius: 1),
      materials: [material]
    )
    entity.name = "unit-sphere-comparison-ghost"
    return entity
  }

  static func isSurfaceEntity(_ entity: Entity) -> Bool {
    entity.name == surfaceEntityName || entity.name == innerSurfaceEntityName
  }

  private static func makeModel(
    name: String,
    mesh: SphereMesh,
    indices: [UInt32],
    faceMaterials: [UInt32],
    materials: [SimpleMaterial],
    inward: Bool
  ) throws -> ModelEntity {
    let positions = mesh.positions.map(displayVector)
    let normals = mesh.normals.map { value in
      let converted = displayVector(value)
      return inward ? -converted : converted
    }
    let textureCoordinates = mesh.textureCoordinates.map {
      SIMD2(Float($0.x), Float($0.y))
    }

    var descriptor = MeshDescriptor(
      name: "Reduced sphere \(mesh.stage.rawValue) \(inward ? "inside" : "outside")"
    )
    descriptor.positions = MeshBuffers.Positions(positions)
    descriptor.normals = MeshBuffers.Normals(normals)
    descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(textureCoordinates)
    descriptor.primitives = .triangles(indices)
    descriptor.materials = .perFace(faceMaterials)

    let resource = try MeshResource.generate(from: [descriptor])
    let model = ModelEntity(mesh: resource, materials: materials)
    model.name = name
    model.components.set(InputTargetComponent(allowedInputTypes: .all))
    let collisionRadius = Float(
      max(mesh.manifest.declaredContainingRadius, 0.05)
    )
    model.components.set(
      CollisionComponent(shapes: [.generateSphere(radius: collisionRadius)])
    )
    model.components.set(HoverEffectComponent(.highlight(.default)))
    model.accessibilityLabelKey =
      inward
      ? "Interior-readable reduced sphere shell"
      : "Interactive reduced sphere \(mesh.stage.shortDisplayName)"
    return model
  }

  /// Returns the triangles outside the longitude section cut. This remains
  /// internal so focused tests can validate seam and pole behavior without
  /// constructing RealityKit resources.
  static func sectionedTriangleIndices(
    from mesh: SphereMesh,
    sectionAmount: Double
  ) -> [UInt32] {
    guard sectionAmount > 0 else { return mesh.triangleIndices }
    let cut = min(max(sectionAmount, 0), 0.8) * 0.28
    var output: [UInt32] = []
    output.reserveCapacity(mesh.triangleIndices.count)

    for offset in stride(from: 0, to: mesh.triangleIndices.count, by: 3) {
      let triangle = Array(mesh.triangleIndices[offset..<(offset + 3)])
      let footprint = longitudeFootprint(
        for: triangle,
        mesh: mesh
      )
      // A topological cut must discard an entire face that bridges either the
      // periodic seam or the removed interval; classifying by its mean can
      // otherwise stitch the two exposed edges back together.
      guard
        !footprint.unwrapped.isEmpty,
        !footprint.crossesPeriodicSeam,
        footprint.unwrapped.allSatisfy({ $0 >= cut })
      else { continue }
      output.append(contentsOf: triangle)
    }
    return output
  }

  private struct LongitudeFootprint {
    let unwrapped: [Double]
    let crossesPeriodicSeam: Bool
  }

  /// Builds a local unwrapped chart for the face. Pole UVs use 0.5 only as a
  /// placeholder, so vertices on the axis are excluded using mesh geometry.
  private static func longitudeFootprint(
    for triangle: [UInt32],
    mesh: SphereMesh
  ) -> LongitudeFootprint {
    let longitudes = triangle.compactMap { index -> Double? in
      let vertexIndex = Int(index)
      let position = mesh.positions[vertexIndex]
      let radialSquared = position.x * position.x + position.y * position.y
      guard radialSquared > 1e-16 else { return nil }
      return wrapUnitInterval(mesh.textureCoordinates[vertexIndex].x)
    }

    guard let reference = longitudes.first else {
      return LongitudeFootprint(
        unwrapped: [],
        crossesPeriodicSeam: false
      )
    }
    let minimum = longitudes.min() ?? reference
    let maximum = longitudes.max() ?? reference
    let unwrapped = longitudes.map { longitude in
      var unwrapped = longitude
      if unwrapped - reference > 0.5 {
        unwrapped -= 1
      } else if unwrapped - reference < -0.5 {
        unwrapped += 1
      }
      return unwrapped
    }
    return LongitudeFootprint(
      unwrapped: unwrapped,
      crossesPeriodicSeam: maximum - minimum > 0.5
    )
  }

  private static func wrapUnitInterval(_ value: Double) -> Double {
    let remainder = value.truncatingRemainder(dividingBy: 1)
    return remainder < 0 ? remainder + 1 : remainder
  }

  private static func reversedWinding(_ indices: [UInt32]) -> [UInt32] {
    var output: [UInt32] = []
    output.reserveCapacity(indices.count)
    for offset in stride(from: 0, to: indices.count, by: 3) {
      output.append(indices[offset])
      output.append(indices[offset + 2])
      output.append(indices[offset + 1])
    }
    return output
  }

  private static func materialIndices(
    for triangles: [UInt32],
    mesh: SphereMesh
  ) -> [UInt32] {
    let displacement =
      mesh.scalarField(
        named: "sphereProxyDisplacementMagnitude"
      )?.values ?? Array(repeating: 0, count: mesh.grid.vertexCount)
    let ribbonRank =
      mesh.scalarField(
        named: "sphereRibbonRank"
      )?.values ?? Array(repeating: 0, count: mesh.grid.vertexCount)
    var output: [UInt32] = []
    output.reserveCapacity(triangles.count / 3)

    for offset in stride(from: 0, to: triangles.count, by: 3) {
      let indices = [
        Int(triangles[offset]),
        Int(triangles[offset + 1]),
        Int(triangles[offset + 2]),
      ]
      let rank = Int(
        (indices.reduce(0.0) { $0 + ribbonRank[$1] } / 3).rounded()
      )
      let averageDisplacement = indices.reduce(0.0) { $0 + displacement[$1] } / 3
      let averageU =
        indices.reduce(0.0) {
          $0 + mesh.textureCoordinates[$1].x
        } / 3
      let fineRib = Int(floor(averageU * 96)).isMultiple(of: 2)
      let highlight = averageDisplacement > 0.0012 || fineRib
      let base = min(max(rank, 0), 3) * 2
      output.append(UInt32(base + (highlight ? 1 : 0)))
    }
    return output
  }

  private static func surfacePalette() -> [SimpleMaterial] {
    [
      material(0.91, 0.81, 0.55, roughness: 0.38, metallic: true),
      material(1.00, 0.95, 0.78, roughness: 0.23, metallic: false),
      material(0.73, 0.51, 0.20, roughness: 0.31, metallic: true),
      material(0.98, 0.84, 0.49, roughness: 0.20, metallic: true),
      material(0.61, 0.38, 0.13, roughness: 0.34, metallic: true),
      material(0.93, 0.72, 0.31, roughness: 0.19, metallic: true),
      material(0.48, 0.25, 0.08, roughness: 0.37, metallic: true),
      material(0.86, 0.58, 0.20, roughness: 0.18, metallic: true),
    ]
  }

  private static func material(
    _ red: Double,
    _ green: Double,
    _ blue: Double,
    roughness: MaterialScalarParameter,
    metallic: Bool
  ) -> SimpleMaterial {
    SimpleMaterial(
      color: UIColor(red: red, green: green, blue: blue, alpha: 1),
      roughness: roughness,
      isMetallic: metallic
    )
  }
}
