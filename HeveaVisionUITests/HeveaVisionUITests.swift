import XCTest

/// End-to-end checks for the stable accessibility contract shared by Mission
/// Control and the fully immersive lab.
///
/// Every launch opts into Hevea's deterministic automation mode. Screenshots
/// are captured only after a semantic state witness appears; the suite never
/// waits an arbitrary number of seconds for rendering to "probably" finish.
@MainActor
final class HeveaVisionUITests: XCTestCase {
  var app: XCUIApplication!

  override func setUp() {
    super.setUp()
    continueAfterFailure = false
  }

  func testMissionControlAccessibilityContractAndStageRail() {
    launch(scenario: "mission-control")

    for identifier in [
      "mission-control",
      "stage-card",
      "overlay-card",
      "research-instrument",
      "immersion-card",
    ] {
      requireElement(identifier)
    }

    for identifier in [
      "toggle-immersive-lab",
      "stage-shortTorus",
      "stage-proxyStage1",
      "stage-proxyStage2",
      "stage-proxyStage3",
      "overlay-surface",
      "overlay-grid",
      "overlay-metric",
      "overlay-normals",
      "overlay-direction",
    ] {
      requireHittable(identifier)
    }

    attachScreenshot(named: "mission-control-initial")

    let stageCycle: [StageCheckpoint] = [
      .shortTorus,
      .proxyStage1,
      .proxyStage2,
      .proxyStage3,
      .proxyStage2,
      .proxyStage1,
      .shortTorus,
    ]

    for checkpoint in stageCycle {
      let button = requireHittable(checkpoint.windowIdentifier)
      button.tap()
      requireStaticText(checkpoint.visibleTitle)
    }

    attachScreenshot(named: "mission-control-stage-cycle-complete")
  }

  func testMissionControlCyclesEveryDiagnosticOverlay() {
    launch(scenario: "mission-control")
    requireElement("mission-control")

    for checkpoint in OverlayCheckpoint.allCases {
      let button = requireHittable(checkpoint.windowIdentifier)
      button.tap()
      requireStaticText(checkpoint.explanation)
      attachScreenshot(named: "mission-control-overlay-\(checkpoint.screenshotName)")
    }
  }

  func testImmersiveLabCanDismissReopenAndCycleStages() {
    launch(scenario: "mission-control")
    openImmersiveLab()
    requireImmersiveAccessibilityContract()

    // HEVEA_AUTOMATION requests a deterministic surface sample. Waiting for
    // this readout also proves that asynchronous geometry generation ended.
    requireStaticText(beginningWith: "Selected sample #", timeout: Timeout.geometry)
    attachScreenshot(named: "immersive-lab-open")
    cycleImmersiveStages()

    dismissImmersiveLab()
    attachScreenshot(named: "mission-control-after-dismiss")

    openImmersiveLab()
    requireElement("immersive-controls-hud", timeout: Timeout.immersive)
    attachScreenshot(named: "immersive-lab-reopened")

    dismissImmersiveLab()
  }

  func testMetricHeatmapScenarioProducesDeterministicScreenshotEvidence() {
    launch(scenario: "metric-heatmap", repetition: 2)

    requireElement("immersive-legend-hud", timeout: Timeout.immersive)
    requireStaticText("Metric residual", timeout: Timeout.immersive)
    let sample = requireStaticText(beginningWith: "Selected sample #", timeout: Timeout.geometry)
    let firstSampleLabel = sample.label
    XCTAssertFalse(firstSampleLabel.isEmpty)

    attachScreenshot(named: "metric-heatmap-repetition-2")

    // A relaunch with the same scenario/repetition must expose the same
    // deterministic sample label. This checks state, not pixel identity.
    app.terminate()
    launch(scenario: "metric-heatmap", repetition: 2)
    requireElement("immersive-legend-hud", timeout: Timeout.immersive)
    let repeatedSample = requireStaticText(
      beginningWith: "Selected sample #", timeout: Timeout.geometry)
    XCTAssertEqual(repeatedSample.label, firstSampleLabel)

    attachScreenshot(named: "metric-heatmap-repetition-2-relaunch")
    dismissImmersiveLab()
  }

  func testImmersiveStageRailSurvivesTwoHundredRenderedUpdates() {
    let updateCount = 200
    launch(scenario: "mission-control")
    openImmersiveLab()
    requireStaticText(beginningWith: "Selected sample #", timeout: Timeout.geometry)

    let stageButtons = StageCheckpoint.allCases.map { checkpoint in
      requireHittable(checkpoint.immersiveIdentifier, timeout: Timeout.immersive)
    }
    let startedAt = Date()

    for index in 0..<updateCount {
      stageButtons[index % stageButtons.count].tap()
      if index.isMultiple(of: 25) {
        XCTAssertEqual(app.state, .runningForeground)
      }
    }

    let finalStage = StageCheckpoint.allCases[(updateCount - 1) % stageButtons.count]
    requireStaticText(finalStage.shortTitle, timeout: Timeout.geometry)
    requireStaticText(beginningWith: "Selected sample #", timeout: Timeout.geometry)
    XCTAssertEqual(app.state, .runningForeground)

    let elapsedSeconds = Date().timeIntervalSince(startedAt)
    let receipt =
      "iterations=\(updateCount) finalStage=\(finalStage.shortTitle) "
      + "elapsedSeconds=\(elapsedSeconds)"
    let attachment = XCTAttachment(string: receipt)
    attachment.name = "Hevea Vision — 200-update stress receipt"
    attachment.lifetime = .keepAlways
    add(attachment)
    attachScreenshot(named: "immersive-stage-stress-200-complete")

    dismissImmersiveLab()
  }

  func testImmersivePresentationControlReportsDeterministicState() {
    launch(scenario: "metric-heatmap")

    let presentationState = requireElement("presentation-state", timeout: Timeout.immersive)
    XCTAssertEqual(presentationState.label, "View · Outside")

    let inside = requireHittable("presentation-inside", timeout: Timeout.immersive)
    XCTAssertTrue(
      tapWithSpatialRetry(inside, until: presentationState, hasLabel: "View · Inside"),
      "The presentation state remained '\(presentationState.label)' after selecting Inside"
    )
    requireElement("inside-escape-hud", timeout: Timeout.immersive)
    requireHittable("return-outside", timeout: Timeout.immersive)
    requireHittable("exit-inside-lab", timeout: Timeout.immersive)
    attachScreenshot(named: "immersive-inside-escape-contract")
  }
}
