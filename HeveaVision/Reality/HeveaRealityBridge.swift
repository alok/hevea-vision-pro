import HeveaCore
import RealityKit
import UIKit

struct HeveaAnalysisBundle: Sendable {
  let mesh: HeveaMesh
  let metricReport: MetricResidualReport
  let microscopeReport: NormalMicroscopeReport
  let localNormalVariationRadians: [Double]

  var diagnosticSnapshot: DiagnosticSnapshot {
    let firstScale = microscopeReport.observations.first
    return DiagnosticSnapshot(
      vertexCount: mesh.grid.vertexCount,
      triangleCount: mesh.grid.triangleCount,
      maximumMetricResidual: metricReport.statistics.maximum,
      rmsMetricResidual: metricReport.statistics.rootMeanSquare,
      microscopeMedianDegrees: (firstScale?.omegaStatisticsRadians.median ?? 0) * 180 / .pi,
      microscopeP95Degrees: (firstScale?.omegaStatisticsRadians.percentile95 ?? 0) * 180 / .pi,
      fittedScaleSlope: descriptiveScaleSlope
    )
  }

  private var descriptiveScaleSlope: Double? {
    guard let first = microscopeReport.observations.first,
      let last = microscopeReport.observations.last,
      first.gridStep != last.gridStep
    else { return nil }

    let firstScale = sqrt(first.parameterRadiusU * first.parameterRadiusV)
    let lastScale = sqrt(last.parameterRadiusU * last.parameterRadiusV)
    let firstOmega = first.omegaStatisticsRadians.median
    let lastOmega = last.omegaStatisticsRadians.median
    guard firstScale > 0, lastScale > 0, firstOmega > 0, lastOmega > 0 else { return nil }

    let denominator = log(lastScale) - log(firstScale)
    guard denominator.isFinite, abs(denominator) > 1e-12 else { return nil }
    let slope = (log(lastOmega) - log(firstOmega)) / denominator
    return slope.isFinite ? slope : nil
  }
}

enum HeveaAnalysisEngine {
  static func generate(stage: HeveaStage) throws -> HeveaAnalysisBundle {
    let mesh = try HeveaMeshGenerator.generate(stage: stage)
    let metricReport = try MetricDiagnostics.analyze(mesh)
    let microscopeReport = try NormalScaleMicroscope.analyze(mesh)
    let normalVariation = oneStepNormalVariation(on: mesh)
    return HeveaAnalysisBundle(
      mesh: mesh,
      metricReport: metricReport,
      microscopeReport: microscopeReport,
      localNormalVariationRadians: normalVariation
    )
  }

  /// Rendering scalar for the first scale in `NormalScaleMicroscope`.
  /// This mirrors omega(p, 1) over every vertex; aggregate claims still come
  /// from the retained `NormalMicroscopeReport` and stay labelled HV EXPERIMENT.
  private static func oneStepNormalVariation(on mesh: HeveaMesh) -> [Double] {
    let directions = [
      GridCoordinate(u: -1, v: -1),
      GridCoordinate(u: -1, v: 0),
      GridCoordinate(u: -1, v: 1),
      GridCoordinate(u: 0, v: -1),
      GridCoordinate(u: 0, v: 1),
      GridCoordinate(u: 1, v: -1),
      GridCoordinate(u: 1, v: 0),
      GridCoordinate(u: 1, v: 1),
    ]

    var values = Array(repeating: 0.0, count: mesh.grid.vertexCount)
    for u in 0..<mesh.grid.uCount {
      for v in 0..<mesh.grid.vCount {
        let coordinate = GridCoordinate(u: u, v: v)
        let center = mesh.normal(at: coordinate)
        var maximum = 0.0
        for direction in directions {
          let neighbor = GridCoordinate(u: u + direction.u, v: v + direction.v)
          maximum = max(maximum, Vector3.angle(center, mesh.normal(at: neighbor)) ?? 0)
        }
        values[mesh.grid.index(of: coordinate)] = maximum
      }
    }
    return values
  }
}

@MainActor
enum HeveaRealityBridge {
  static let surfaceEntityName = "hevea-observable-surface"
  static let modelToMetersScale: Float = 4.0

  static func makeSurface(
    from analysis: HeveaAnalysisBundle,
    overlay: DiagnosticOverlay,
    sectionAmount: Double
  ) throws -> ModelEntity {
    let coreMesh = analysis.mesh
    let positions = coreMesh.positions.map(simd3)
    let normals = coreMesh.normals.map(simd3)
    let textureCoordinates = coreMesh.textureCoordinates.map { SIMD2(Float($0.x), Float($0.y)) }
    let palette = materialPalette(for: overlay)

    var indices: [UInt32] = []
    var faceMaterials: [UInt32] = []
    indices.reserveCapacity(coreMesh.triangleIndices.count)
    faceMaterials.reserveCapacity(coreMesh.grid.triangleCount)

    let scalarValues = values(for: overlay, analysis: analysis)
    let scalarRange = robustRange(of: scalarValues)
    let inputIndices = coreMesh.triangleIndices

    for triangleStart in stride(from: 0, to: inputIndices.count, by: 3) {
      let triangle = Array(inputIndices[triangleStart..<(triangleStart + 3)])
      guard
        !isSectionedOut(
          triangle: triangle,
          grid: coreMesh.grid,
          sectionAmount: sectionAmount
        )
      else { continue }

      indices.append(contentsOf: triangle)
      faceMaterials.append(
        materialIndex(
          overlay: overlay,
          triangle: triangle,
          grid: coreMesh.grid,
          values: scalarValues,
          range: scalarRange,
          paletteCount: palette.count,
          stage: coreMesh.stage
        )
      )
    }

    var descriptor = MeshDescriptor(name: "Hevea \(coreMesh.stage.rawValue)")
    descriptor.positions = MeshBuffers.Positions(positions)
    descriptor.normals = MeshBuffers.Normals(normals)
    descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(textureCoordinates)
    descriptor.primitives = .triangles(indices)
    descriptor.materials = .perFace(faceMaterials)

    let resource = try MeshResource.generate(from: [descriptor])
    let entity = ModelEntity(mesh: resource, materials: palette)
    entity.name = surfaceEntityName
    entity.components.set(InputTargetComponent(allowedInputTypes: .all))
    entity.components.set(
      CollisionComponent(shapes: [.generateSphere(radius: 0.13)])
    )
    entity.components.set(HoverEffectComponent(.highlight(.default)))
    entity.accessibilityLabelKey = "Interactive \(coreMesh.stage.displayName) surface"
    return entity
  }

  static func nearestSample(
    to localPosition: SIMD3<Float>,
    analysis: HeveaAnalysisBundle
  ) -> SelectedSurfaceSample? {
    guard !analysis.mesh.positions.isEmpty else { return nil }

    var bestIndex = 0
    var bestDistance = Float.greatestFiniteMagnitude
    for (index, position) in analysis.mesh.positions.enumerated() {
      let distance = simd_distance_squared(localPosition, simd3(position))
      if distance < bestDistance {
        bestDistance = distance
        bestIndex = index
      }
    }

    guard let coordinate = try? analysis.mesh.grid.coordinate(for: bestIndex) else { return nil }
    let parameter = analysis.mesh.grid.parameterPoint(u: coordinate.u, v: coordinate.v)
    let metric = analysis.metricReport.residuals[bestIndex]
    let variation = analysis.localNormalVariationRadians[bestIndex]
    return SelectedSurfaceSample(
      vertexIndex: bestIndex,
      u: parameter.u,
      v: parameter.v,
      position: simd3(analysis.mesh.positions[bestIndex]),
      normal: simd3(analysis.mesh.normals[bestIndex]),
      metricResidual: metric,
      normalVariation: variation
    )
  }

  private static func values(
    for overlay: DiagnosticOverlay,
    analysis: HeveaAnalysisBundle
  ) -> [Double] {
    switch overlay {
    case .metricResidual:
      analysis.metricReport.residuals
    case .normalVariation:
      analysis.localNormalVariationRadians
    default:
      []
    }
  }

  private static func materialIndex(
    overlay: DiagnosticOverlay,
    triangle: [UInt32],
    grid: PeriodicGrid,
    values: [Double],
    range: ClosedRange<Double>,
    paletteCount: Int,
    stage: HeveaStage
  ) -> UInt32 {
    switch overlay {
    case .surface:
      return 0
    case .parameterGrid:
      let strideU = max(1, grid.uCount / 12)
      let strideV = max(1, grid.vCount / 16)
      let isGridLine = triangle.contains { rawIndex in
        let index = Int(rawIndex)
        let u = index / grid.vCount
        let v = index % grid.vCount
        return u % strideU == 0 || v % strideV == 0
      }
      return isGridLine ? 1 : 0
    case .corrugationDirection:
      guard let descriptor = stage.proxyDescriptor else { return 0 }
      let index = Int(triangle[0])
      let u = Double(index / grid.vCount) / Double(grid.uCount)
      let v = Double(index % grid.vCount) / Double(grid.vCount)
      let phase =
        (Double(descriptor.direction.u) * u + Double(descriptor.direction.v) * v)
        * Double(descriptor.defaultFrequency) * 2
      return Int(floor(phase)).isMultiple(of: 2) ? 0 : 1
    case .metricResidual, .normalVariation:
      guard !values.isEmpty else { return 0 }
      let average = triangle.reduce(0.0) { $0 + values[Int($1)] } / 3
      let width = max(range.upperBound - range.lowerBound, 1e-15)
      let normalized = min(max((average - range.lowerBound) / width, 0), 1)
      let bin = min(Int(normalized * Double(paletteCount)), paletteCount - 1)
      return UInt32(bin)
    }
  }

  private static func isSectionedOut(
    triangle: [UInt32],
    grid: PeriodicGrid,
    sectionAmount: Double
  ) -> Bool {
    guard sectionAmount > 0 else { return false }
    let averageV =
      triangle.reduce(0.0) {
        $0 + Double(Int($1) % grid.vCount) / Double(grid.vCount)
      } / 3
    let wrappedDistanceToCut = min(averageV, 1 - averageV)
    return wrappedDistanceToCut < min(max(sectionAmount, 0), 0.8) * 0.22
  }

  private static func robustRange(of values: [Double]) -> ClosedRange<Double> {
    guard !values.isEmpty else { return 0...1 }
    let sorted = values.sorted()
    let lowIndex = min(Int(Double(sorted.count - 1) * 0.02), sorted.count - 1)
    let highIndex = min(Int(Double(sorted.count - 1) * 0.98), sorted.count - 1)
    let lower = sorted[lowIndex]
    let upper = max(sorted[highIndex], lower + 1e-15)
    return lower...upper
  }

  private static func materialPalette(for overlay: DiagnosticOverlay) -> [SimpleMaterial] {
    switch overlay {
    case .surface:
      [material(red: 0.10, green: 0.82, blue: 0.88, roughness: 0.27, metallic: true)]
    case .parameterGrid:
      [
        material(red: 0.08, green: 0.13, blue: 0.24, roughness: 0.34, metallic: true),
        material(red: 0.22, green: 0.96, blue: 0.91, roughness: 0.18, metallic: false),
      ]
    case .metricResidual:
      heatPalette([
        (0.02, 0.05, 0.16),
        (0.08, 0.22, 0.42),
        (0.09, 0.45, 0.57),
        (0.30, 0.67, 0.51),
        (0.70, 0.79, 0.34),
        (0.98, 0.72, 0.20),
        (0.96, 0.38, 0.23),
      ])
    case .normalVariation:
      heatPalette([
        (0.07, 0.03, 0.20),
        (0.20, 0.06, 0.43),
        (0.41, 0.10, 0.56),
        (0.65, 0.20, 0.48),
        (0.87, 0.37, 0.31),
        (0.98, 0.62, 0.22),
        (1.00, 0.88, 0.45),
      ])
    case .corrugationDirection:
      [
        material(red: 0.13, green: 0.88, blue: 0.92, roughness: 0.22, metallic: true),
        material(red: 0.68, green: 0.24, blue: 0.92, roughness: 0.25, metallic: true),
      ]
    }
  }

  private static func heatPalette(_ colors: [(Double, Double, Double)]) -> [SimpleMaterial] {
    colors.map { material(red: $0.0, green: $0.1, blue: $0.2, roughness: 0.36, metallic: false) }
  }

  private static func material(
    red: Double,
    green: Double,
    blue: Double,
    roughness: MaterialScalarParameter,
    metallic: Bool
  ) -> SimpleMaterial {
    SimpleMaterial(
      color: UIColor(red: red, green: green, blue: blue, alpha: 1),
      roughness: roughness,
      isMetallic: metallic
    )
  }

  private static func simd3(_ value: Vector3) -> SIMD3<Float> {
    SIMD3(Float(value.x), Float(value.y), Float(value.z))
  }
}
