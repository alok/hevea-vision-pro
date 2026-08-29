import HeveaCore
import Testing

@testable import HeveaVision

@MainActor
struct AppModelTests {
  @Test
  func defaultScenarioOpensTheInhabitableReducedSphere() {
    let model = AppModel(arguments: ["HeveaVision"], environment: [:])

    #expect(model.selectedExhibit == .reducedSphere)
    #expect(model.selectedSphereStage == .proxyFamily3)
    #expect(model.selectedSphereRegime == .habitat)
    #expect(model.currentClaim == .realTimeProxy)
    #expect(model.sphereNavigation.stepCount == 0)
  }

  @Test
  func legacyTorusLaunchScenarioRemainsDeterministic() {
    let model = AppModel(
      arguments: ["HeveaVision", "--hevea-scenario", "baseline-window"],
      environment: [:]
    )

    #expect(model.selectedExhibit == .flatTorus)
    #expect(model.selectedStage == .shortTorus)
    #expect(model.selectedOverlay == .surface)
    #expect(model.currentClaim == .upstreamBaseline)
  }

  @Test
  func simulatorMatrixScenariosSelectDistinctExhibitsAndEvidenceStates() {
    let metric = AppModel(
      arguments: [
        "HeveaVision", "--hevea-automation", "--hevea-scenario", "metric-heatmap",
        "--hevea-repetition", "2",
      ],
      environment: [:]
    )
    let sphereStageSweep = AppModel(
      arguments: [
        "HeveaVision", "--hevea-automation", "--hevea-scenario", "sphere-stage-sweep",
        "--hevea-repetition", "2",
      ],
      environment: [:]
    )

    #expect(metric.automationScenario == "metric-heatmap")
    #expect(metric.selectedExhibit == .flatTorus)
    #expect(metric.selectedStage == .proxyStage2)
    #expect(metric.selectedOverlay == .metricResidual)
    #expect(sphereStageSweep.selectedExhibit == .reducedSphere)
    #expect(sphereStageSweep.selectedSphereStage == .proxyFamily1)
    #expect(sphereStageSweep.selectedSphereRegime == .atlas)
  }

  @Test
  func bothConstructionRailsClampAtTheirEnds() {
    let model = AppModel(arguments: ["HeveaVision"], environment: [:])

    model.selectSphereStage(.unitSphere)
    model.stepSphereStage(by: -1)
    #expect(model.selectedSphereStage == .unitSphere)

    model.selectSphereStage(.proxyFamily3)
    model.stepSphereStage(by: 1)
    #expect(model.selectedSphereStage == .proxyFamily3)

    model.selectStage(.shortTorus)
    model.stepStage(by: -1)
    #expect(model.selectedStage == .shortTorus)

    model.selectStage(.proxyStage3)
    model.stepStage(by: 1)
    #expect(model.selectedStage == .proxyStage3)
  }

  @Test
  func regimeCycleDoesNotChangeTheAuthoritativeIntrinsicAddress() {
    let model = AppModel(arguments: ["HeveaVision"], environment: [:])
    model.moveOnSphere(.forward)
    model.turnOnSphere(by: .pi / 7)
    model.changeSphereAltitude(by: 0.12)
    let addressBefore = model.sphereNavigation

    for regime in SphereRegime.allCases {
      model.selectSphereRegime(regime)
    }

    #expect(model.sphereNavigation == addressBefore)
  }

  @Test
  func oneThousandIntrinsicStepsAreDeterministicAndRemainOnTheUnitSphere() {
    let first = AppModel(arguments: ["HeveaVision"], environment: [:])
    let second = AppModel(arguments: ["HeveaVision"], environment: [:])

    first.runSphereNavigationStress(stepCount: 1_000)
    second.runSphereNavigationStress(stepCount: 1_000)

    #expect(first.sphereNavigation == second.sphereNavigation)
    #expect(first.sphereNavigation.stepCount == 1_000)
    #expect(first.sphereNavigation.traversedIntrinsicDistance > 2.9)
    #expect(abs(first.sphereNavigation.address.unitDirection.length - 1) < 1e-12)
    #expect(first.sphereNavigation.address.latitude.isFinite)
    #expect(first.sphereNavigation.address.longitude.isFinite)
  }

  @Test
  func capToEquatorRouteUsesIntrinsicStepsAndReachesTheEquator() {
    let model = AppModel(arguments: ["HeveaVision"], environment: [:])

    model.walkCapToEquator()

    #expect(model.sphereNavigation.stepCount == 32)
    #expect(abs(model.sphereNavigation.address.latitude) < 1e-10)
    #expect(abs(model.sphereNavigation.traversedIntrinsicDistance - 1.28) < 1e-12)
  }

  @Test
  func resetRestoresAReproducibleSphereAddressAndPose() {
    let model = AppModel(arguments: ["HeveaVision"], environment: [:])
    let initial = model.sphereNavigation
    model.selectSphereRegime(.interior)
    model.moveOnSphere(.right)
    model.changeSphereAltitude(by: 0.20)
    model.modelScale = 2.2
    model.modelRotation = [0.5, -0.4]
    model.sectionAmount = 0.7

    model.resetLab()

    #expect(model.selectedSphereRegime == .habitat)
    #expect(model.sphereNavigation == initial)
    #expect(model.presentation == .outside)
    #expect(model.modelScale == 1)
    #expect(model.modelRotation == .zero)
    #expect(model.sectionAmount == 0)
    #expect(model.resetRevision == 1)
  }

  @Test
  func automationStressHookPerformsExactlyOneThousandIntrinsicSteps() {
    let model = AppModel(
      arguments: [
        "HeveaVision", "--hevea-automation", "--hevea-scenario",
        "sphere-navigation-stress-1000",
      ],
      environment: [:]
    )

    #expect(model.selectedExhibit == .reducedSphere)
    #expect(model.sphereNavigation.stepCount == 1_000)
    #expect(model.automationScenario == "sphere-navigation-stress-1000")
  }
}
