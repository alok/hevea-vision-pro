import HeveaCore
import RealityKit
import UIKit

@MainActor
final class HeveaSceneController {
  let root = Entity()

  private let surfaceAnchor = Entity()
  private let surfaceContent = Entity()
  private let selectionContent = Entity()
  private let gaussAnchor = Entity()
  private let gaussSamples = Entity()
  private let gaussSelection = Entity()
  private let domainFloor = Entity()
  private var analysis: HeveaAnalysisBundle?

  init() {
    root.name = "hevea-immersive-observatory"
    surfaceAnchor.name = "hevea-surface-anchor"
    gaussAnchor.name = "hevea-gauss-sphere"
    domainFloor.name = "hevea-parameter-domain"

    surfaceAnchor.addChild(surfaceContent)
    surfaceAnchor.addChild(selectionContent)
    gaussAnchor.addChild(gaussSamples)
    gaussAnchor.addChild(gaussSelection)

    root.addChild(surfaceAnchor)
    root.addChild(gaussAnchor)
    root.addChild(domainFloor)

    installParameterDomain()
    installGaussSphere()
    installStarField()
    installLighting()
  }

  func regenerate(
    stage: HeveaStage,
    overlay: DiagnosticOverlay,
    sectionAmount: Double
  ) async throws -> DiagnosticSnapshot {
    let generated = try await Task.detached(priority: .userInitiated) {
      try HeveaAnalysisEngine.generate(stage: stage)
    }.value
    try Task.checkCancellation()

    let surface = try HeveaRealityBridge.makeSurface(
      from: generated,
      overlay: overlay,
      sectionAmount: sectionAmount
    )
    surfaceContent.children.removeAll()
    surfaceContent.addChild(surface)
    selectionContent.children.removeAll()
    gaussSelection.children.removeAll()
    analysis = generated
    installGaussSamples(from: generated)
    return generated.diagnosticSnapshot
  }

  func applyPresentation(
    presentation: LabPresentation,
    scale: Float,
    rotation: SIMD2<Float>,
    showDomainFloor: Bool,
    showGaussSphere: Bool
  ) {
    domainFloor.isEnabled = showDomainFloor && presentation == .outside
    gaussAnchor.isEnabled = showGaussSphere && presentation == .outside

    let xRotation = simd_quatf(angle: rotation.y, axis: [1, 0, 0])
    let yRotation = simd_quatf(angle: rotation.x, axis: [0, 1, 0])
    surfaceAnchor.orientation = yRotation * xRotation

    switch presentation {
    case .outside:
      surfaceAnchor.position = [0, 1.40, -1.55]
      surfaceAnchor.scale = SIMD3(repeating: HeveaRealityBridge.modelToMetersScale * scale)
    case .inside:
      surfaceAnchor.position = [0, 1.48, 0]
      surfaceAnchor.scale = SIMD3(repeating: 19 * scale)
    }
  }

  func selectSurface(at localPosition: SIMD3<Float>) -> SelectedSurfaceSample? {
    guard let analysis,
      let selection = HeveaRealityBridge.nearestSample(
        to: localPosition,
        analysis: analysis
      )
    else { return nil }

    updateSelectionMarkers(selection)
    return selection
  }

  func selectDeterministicSample(index: Int) -> SelectedSurfaceSample? {
    guard let analysis else { return nil }
    let coordinates = analysis.microscopeReport.sampleCoordinates
    guard !coordinates.isEmpty else { return nil }
    let coordinate = coordinates[index % coordinates.count]
    let vertexIndex = analysis.mesh.grid.index(of: coordinate)
    let position = analysis.mesh.positions[vertexIndex]
    guard
      let selection = HeveaRealityBridge.nearestSample(
        to: SIMD3(Float(position.x), Float(position.y), Float(position.z)),
        analysis: analysis
      )
    else { return nil }
    updateSelectionMarkers(selection)
    return selection
  }

  private func updateSelectionMarkers(_ selection: SelectedSurfaceSample) {
    selectionContent.children.removeAll()
    gaussSelection.children.removeAll()

    let surfaceMarker = ModelEntity(
      mesh: .generateSphere(radius: 0.0035),
      materials: [Self.unlit(.systemCyan)]
    )
    surfaceMarker.position = selection.position
    selectionContent.addChild(surfaceMarker)

    let normalEnd = selection.position + selection.normal * 0.045
    selectionContent.addChild(
      Self.segment(
        from: selection.position,
        to: normalEnd,
        radius: 0.0014,
        color: .systemYellow
      )
    )

    let selectedNormal = ModelEntity(
      mesh: .generateSphere(radius: 0.014),
      materials: [Self.unlit(.systemYellow)]
    )
    selectedNormal.position = selection.normal * 0.18
    gaussSelection.addChild(selectedNormal)
  }

  private func installParameterDomain() {
    domainFloor.position = [-0.72, 0.58, -1.32]

    var panelMaterial = UnlitMaterial()
    panelMaterial.color = .init(tint: UIColor(red: 0.025, green: 0.06, blue: 0.12, alpha: 0.82))
    panelMaterial.blending = .transparent(opacity: 0.72)
    let panel = ModelEntity(
      mesh: .generatePlane(width: 0.58, depth: 0.58),
      materials: [panelMaterial]
    )
    domainFloor.addChild(panel)

    for index in 0...10 {
      let offset = -0.29 + Float(index) * 0.058
      let alpha: CGFloat = index == 0 || index == 10 ? 0.72 : 0.22
      let lineColor = UIColor(red: 0.20, green: 0.92, blue: 1, alpha: alpha)

      let horizontal = ModelEntity(
        mesh: .generateBox(size: [0.58, 0.0015, 0.0015]),
        materials: [Self.unlit(lineColor)]
      )
      horizontal.position = [0, 0.002, offset]
      domainFloor.addChild(horizontal)

      let vertical = ModelEntity(
        mesh: .generateBox(size: [0.0015, 0.0015, 0.58]),
        materials: [Self.unlit(lineColor)]
      )
      vertical.position = [offset, 0.002, 0]
      domainFloor.addChild(vertical)
    }

    // Matching colors make the two pairs of identified edges visible.
    addDomainEdge(center: [0, 0.004, -0.292], size: [0.59, 0.004, 0.006], color: .systemCyan)
    addDomainEdge(center: [0, 0.004, 0.292], size: [0.59, 0.004, 0.006], color: .systemCyan)
    addDomainEdge(center: [-0.292, 0.004, 0], size: [0.006, 0.004, 0.59], color: .systemPurple)
    addDomainEdge(center: [0.292, 0.004, 0], size: [0.006, 0.004, 0.59], color: .systemPurple)
  }

  private func addDomainEdge(center: SIMD3<Float>, size: SIMD3<Float>, color: UIColor) {
    let edge = ModelEntity(mesh: .generateBox(size: size), materials: [Self.unlit(color)])
    edge.position = center
    domainFloor.addChild(edge)
  }

  private func installGaussSphere() {
    gaussAnchor.position = [0.78, 1.24, -1.38]

    var sphereMaterial = UnlitMaterial()
    sphereMaterial.color = .init(tint: UIColor(red: 0.30, green: 0.65, blue: 1, alpha: 0.15))
    sphereMaterial.blending = .transparent(opacity: 0.14)
    let sphere = ModelEntity(
      mesh: .generateSphere(radius: 0.17),
      materials: [sphereMaterial]
    )
    gaussAnchor.addChild(sphere)

    let axes: [(SIMD3<Float>, UIColor)] = [
      ([0.20, 0.0015, 0.0015], .systemRed),
      ([0.0015, 0.20, 0.0015], .systemGreen),
      ([0.0015, 0.0015, 0.20], .systemBlue),
    ]
    for (size, color) in axes {
      gaussAnchor.addChild(
        ModelEntity(
          mesh: .generateBox(size: size), materials: [Self.unlit(color.withAlphaComponent(0.55))])
      )
    }
  }

  private func installGaussSamples(from analysis: HeveaAnalysisBundle) {
    gaussSamples.children.removeAll()
    let samples = analysis.microscopeReport.sampleCoordinates
    let strideLength = max(1, samples.count / 40)

    for coordinate in samples.enumerated() where coordinate.offset.isMultiple(of: strideLength) {
      let normal = analysis.mesh.normal(at: coordinate.element)
      let position = SIMD3(Float(normal.x), Float(normal.y), Float(normal.z)) * 0.18
      let point = ModelEntity(
        mesh: .generateSphere(radius: 0.006),
        materials: [Self.unlit(.systemPink)]
      )
      point.position = position
      gaussSamples.addChild(point)
    }
  }

  private func installStarField() {
    let starRoot = Entity()
    starRoot.name = "deterministic-star-field"
    var generator = DeterministicGenerator(state: 0x4845_5645_415F_5354)
    for _ in 0..<90 {
      let angle = generator.unitFloat * 2 * .pi
      let radius = 2.4 + generator.unitFloat * 4.2
      let height = 0.25 + generator.unitFloat * 3.4
      let star = ModelEntity(
        mesh: .generateSphere(radius: 0.003 + generator.unitFloat * 0.004),
        materials: [
          Self.unlit(UIColor(white: 0.75 + CGFloat(generator.unitFloat) * 0.25, alpha: 0.72))
        ]
      )
      star.position = [cos(angle) * radius, height, sin(angle) * radius - 1.5]
      starRoot.addChild(star)
    }
    root.addChild(starRoot)
  }

  private func installLighting() {
    let key = PointLight()
    key.light.color = .init(red: 0.70, green: 0.92, blue: 1, alpha: 1)
    key.light.intensity = 2_600
    key.light.attenuationRadius = 4
    key.position = [-1.2, 2.4, -0.4]
    root.addChild(key)

    let fill = PointLight()
    fill.light.color = .init(red: 0.82, green: 0.48, blue: 1, alpha: 1)
    fill.light.intensity = 1_500
    fill.light.attenuationRadius = 3
    fill.position = [1.25, 1.7, -0.7]
    root.addChild(fill)
  }

  private static func segment(
    from start: SIMD3<Float>,
    to end: SIMD3<Float>,
    radius: Float,
    color: UIColor
  ) -> ModelEntity {
    let vector = end - start
    let length = max(simd_length(vector), 0.0001)
    let entity = ModelEntity(
      mesh: .generateCylinder(height: length, radius: radius),
      materials: [unlit(color)]
    )
    entity.position = (start + end) / 2
    entity.orientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: vector / length)
    return entity
  }

  private static func unlit(_ color: UIColor) -> UnlitMaterial {
    var material = UnlitMaterial()
    material.color = .init(tint: color)
    return material
  }
}

private struct DeterministicGenerator {
  var state: UInt64

  var unitFloat: Float {
    mutating get {
      state &+= 0x9E37_79B9_7F4A_7C15
      var value = state
      value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
      value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
      value ^= value >> 31
      return Float(value & 0x00FF_FFFF) / Float(0x0100_0000)
    }
  }
}
