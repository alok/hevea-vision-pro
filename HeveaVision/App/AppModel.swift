import Foundation
import HeveaCore
import Observation
import simd

enum ImmersiveSpaceState: Equatable, Sendable {
  case closed
  case inTransition
  case open

  var accessibilityDescription: String {
    switch self {
    case .closed: "closed"
    case .inTransition: "changing"
    case .open: "open"
    }
  }
}

enum DiagnosticOverlay: String, CaseIterable, Identifiable, Sendable {
  case surface = "Surface"
  case parameterGrid = "Parameter grid"
  case metricResidual = "Metric residual"
  case normalVariation = "Normal variation"
  case corrugationDirection = "Corrugation direction"

  var id: Self { self }

  var shortLabel: String {
    switch self {
    case .surface: "Surface"
    case .parameterGrid: "Grid"
    case .metricResidual: "Metric"
    case .normalVariation: "Normals"
    case .corrugationDirection: "Direction"
    }
  }

  var systemImage: String {
    switch self {
    case .surface: "circle.hexagongrid"
    case .parameterGrid: "grid"
    case .metricResidual: "waveform.path.ecg"
    case .normalVariation: "arrow.up.and.down.and.arrow.left.and.right"
    case .corrugationDirection: "point.topleft.down.to.point.bottomright.curvepath"
    }
  }

  var explanation: String {
    switch self {
    case .surface:
      "A neutral material for reading the finite proxy geometry."
    case .parameterGrid:
      "Coordinate lines show the square parameter domain with opposite edges identified."
    case .metricResidual:
      "Color bins show a finite-difference first-fundamental-form residual on this mesh."
    case .normalVariation:
      "Color bins show how quickly neighboring unit normals change at the selected sampling scale."
    case .corrugationDirection:
      "A directional overlay identifies the active low-frequency explanatory ripple."
    }
  }
}

enum LabPresentation: String, CaseIterable, Identifiable, Sendable {
  case outside = "Outside"
  case inside = "Inside"

  var id: Self { self }
}

struct SelectedSurfaceSample: Equatable, Sendable {
  var vertexIndex: Int
  var u: Double
  var v: Double
  var position: SIMD3<Float>
  var normal: SIMD3<Float>
  var metricResidual: Double
  var normalVariation: Double
}

struct DiagnosticSnapshot: Equatable, Sendable {
  var vertexCount: Int
  var triangleCount: Int
  var maximumMetricResidual: Double
  var rmsMetricResidual: Double
  var microscopeMedianDegrees: Double
  var microscopeP95Degrees: Double
  var fittedScaleSlope: Double?

  static let pending = DiagnosticSnapshot(
    vertexCount: 0,
    triangleCount: 0,
    maximumMetricResidual: 0,
    rmsMetricResidual: 0,
    microscopeMedianDegrees: 0,
    microscopeP95Degrees: 0,
    fittedScaleSlope: nil
  )
}

@MainActor
@Observable
final class AppModel {
  static let mainWindowID = "HeveaMissionControl"
  static let immersiveSpaceID = "HeveaImmersiveLab"

  var selectedStage: HeveaStage = .proxyStage3
  var selectedOverlay: DiagnosticOverlay = .normalVariation
  var presentation: LabPresentation = .outside
  var immersiveSpaceState: ImmersiveSpaceState = .closed
  var selectedSample: SelectedSurfaceSample?
  var diagnostics: DiagnosticSnapshot = .pending
  var modelScale: Float = 1
  var modelRotation = SIMD2<Float>(0, 0)
  var sectionAmount: Double = 0
  var frequencyCompression: Double = 1
  var motionEnabled = true
  var showDomainFloor = true
  var showGaussSphere = true
  var generationError: String?
  var geometryRevision = 0
  var resetRevision = 0
  private(set) var automationScenario: String?
  private(set) var automationRepetition = 0
  var automationDidRequestImmersion = false

  init(
    arguments: [String] = ProcessInfo.processInfo.arguments,
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) {
    applyLaunchScenario(arguments: arguments, environment: environment)
  }

  var currentClaim: ClaimClass {
    selectedOverlay == .surface ? selectedStage.claimClass : .heveaVisionExperiment
  }

  var currentClaimExplanation: String {
    switch currentClaim {
    case .upstreamBaseline:
      "The short torus formula is a pinned, documented input to Hévéa. No limiting-embedding claim is made."
    case .realTimeProxy:
      "This compressed interactive stage illustrates direction and scale; it is not the upstream embedding."
    case .heveaVisionExperiment:
      "This readout is a finite-resolution numerical observation on the displayed mesh, not a theorem."
    }
  }

  var stageIndex: Int {
    HeveaStage.allCases.firstIndex(of: selectedStage) ?? 0
  }

  func selectStage(_ stage: HeveaStage) {
    guard selectedStage != stage else { return }
    selectedStage = stage
    selectedSample = nil
    geometryRevision &+= 1
  }

  func stepStage(by offset: Int) {
    let stages = HeveaStage.allCases
    let destination = min(
      max(stageIndex + offset, stages.startIndex), stages.index(before: stages.endIndex))
    selectStage(stages[destination])
  }

  func selectOverlay(_ overlay: DiagnosticOverlay) {
    guard selectedOverlay != overlay else { return }
    selectedOverlay = overlay
    geometryRevision &+= 1
  }

  func resetLab() {
    presentation = .outside
    modelScale = 1
    modelRotation = .zero
    sectionAmount = 0
    selectedSample = nil
    generationError = nil
    resetRevision &+= 1
  }

  func applyMagnification(_ magnification: Float) {
    modelScale = min(max(magnification, 0.55), 2.25)
  }

  func applyRotation(delta: SIMD2<Float>) {
    modelRotation.x += delta.x
    modelRotation.y = min(max(modelRotation.y + delta.y, -.pi / 2), .pi / 2)
  }

  private func applyLaunchScenario(arguments: [String], environment: [String: String]) {
    let environmentScenario = environment["HEVEA_SCENARIO"]
    let argumentScenario: String? = {
      guard let marker = arguments.firstIndex(of: "--hevea-scenario") else { return nil }
      let valueIndex = arguments.index(after: marker)
      return arguments.indices.contains(valueIndex) ? arguments[valueIndex] : nil
    }()

    let selectedScenario = environmentScenario ?? argumentScenario
    let repetition =
      environment["HEVEA_REPETITION"].flatMap(Int.init)
      ?? {
        guard let marker = arguments.firstIndex(of: "--hevea-repetition") else { return 0 }
        let valueIndex = arguments.index(after: marker)
        guard arguments.indices.contains(valueIndex) else { return 0 }
        return Int(arguments[valueIndex]) ?? 0
      }()
    let automationRequested =
      environment["HEVEA_AUTOMATION"] == "1"
      || arguments.contains("--hevea-automation")

    automationScenario = automationRequested ? selectedScenario : nil
    automationRepetition = max(0, repetition)

    switch selectedScenario {
    case "baseline-window":
      selectedStage = .shortTorus
      selectedOverlay = .surface
    case "metric-window", "metric-heatmap":
      selectedStage = .proxyStage2
      selectedOverlay = .metricResidual
    case "microscope-window", "hero-window", "scale-microscope", "mission-control":
      selectedStage = .proxyStage3
      selectedOverlay = .normalVariation
    case "grid-window":
      selectedStage = .proxyStage1
      selectedOverlay = .parameterGrid
    case "stage-sweep":
      let stages = HeveaStage.allCases
      selectedStage = stages[automationRepetition % stages.count]
      selectedOverlay = .parameterGrid
    default:
      break
    }
  }
}
