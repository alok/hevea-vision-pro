import HeveaCore
import Testing

@testable import HeveaVision

@MainActor
struct AppModelTests {
  @Test
  func defaultScenarioUsesMicroscopeHero() {
    let model = AppModel(arguments: ["HeveaVision"], environment: [:])

    #expect(model.selectedStage == .proxyStage3)
    #expect(model.selectedOverlay == .normalVariation)
    #expect(model.currentClaim == .heveaVisionExperiment)
  }

  @Test
  func launchScenarioIsDeterministic() {
    let model = AppModel(
      arguments: ["HeveaVision", "--hevea-scenario", "baseline-window"],
      environment: [:]
    )

    #expect(model.selectedStage == .shortTorus)
    #expect(model.selectedOverlay == .surface)
    #expect(model.currentClaim == .upstreamBaseline)
  }

  @Test
  func simulatorMatrixScenarioSelectsDistinctEvidenceState() {
    let metric = AppModel(
      arguments: [
        "HeveaVision", "--hevea-automation", "--hevea-scenario", "metric-heatmap",
        "--hevea-repetition", "2",
      ],
      environment: [:]
    )
    let stageSweep = AppModel(
      arguments: [
        "HeveaVision", "--hevea-automation", "--hevea-scenario", "stage-sweep",
        "--hevea-repetition", "2",
      ],
      environment: [:]
    )

    #expect(metric.automationScenario == "metric-heatmap")
    #expect(metric.automationRepetition == 2)
    #expect(metric.selectedStage == .proxyStage2)
    #expect(metric.selectedOverlay == .metricResidual)
    #expect(stageSweep.selectedStage == .proxyStage2)
    #expect(stageSweep.selectedOverlay == .parameterGrid)
  }

  @Test
  func stageSteppingClampsAtBothEnds() {
    let model = AppModel(arguments: ["HeveaVision"], environment: [:])

    model.selectStage(.shortTorus)
    model.stepStage(by: -1)
    #expect(model.selectedStage == .shortTorus)

    model.selectStage(.proxyStage3)
    model.stepStage(by: 1)
    #expect(model.selectedStage == .proxyStage3)
  }

  @Test
  func resetRestoresReproduciblePose() {
    let model = AppModel(arguments: ["HeveaVision"], environment: [:])
    model.presentation = .inside
    model.modelScale = 2.2
    model.modelRotation = [0.5, -0.4]
    model.sectionAmount = 0.7

    model.resetLab()

    #expect(model.presentation == .outside)
    #expect(model.modelScale == 1)
    #expect(model.modelRotation == .zero)
    #expect(model.sectionAmount == 0)
    #expect(model.resetRevision == 1)
  }
}
