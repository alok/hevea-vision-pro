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
      "exhibit-switcher",
      "sphere-stage-card",
      "sphere-regime-card",
      "sphere-address-card",
      "immersion-card",
    ] {
      requireElement(identifier)
    }

    for identifier in [
      "toggle-immersive-lab",
      "exhibit-sphere",
      "exhibit-torus",
      "sphere-stage-unitSphere",
      "sphere-stage-shortMap",
      "sphere-stage-proxyFamily1",
      "sphere-stage-proxyFamily2",
      "sphere-stage-proxyFamily3",
      "sphere-regime-atlas",
      "sphere-regime-habitat",
      "sphere-regime-hover",
      "sphere-regime-interior",
      "sphere-walk-forward",
      "sphere-cap-to-equator",
    ] {
      requireHittable(identifier)
    }

    attachScreenshot(named: "mission-control-initial")

    let stageCycle: [SphereStageCheckpoint] = [
      .unitSphere,
      .shortMap,
      .proxyFamily1,
      .proxyFamily2,
      .proxyFamily3,
      .proxyFamily2,
      .proxyFamily1,
      .shortMap,
    ]

    for checkpoint in stageCycle {
      let button = requireHittable(checkpoint.windowIdentifier)
      button.tap()
      let stageState = requireElement("sphere-window-stage-state")
      requireLabel(stageState, beginningWith: "Requested · \(checkpoint.visibleTitle)")
    }

    attachScreenshot(named: "mission-control-stage-cycle-complete")
  }

  func testMissionControlCyclesEveryDiagnosticOverlay() {
    launch(scenario: "torus-mission-control")
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
    requireImmersiveAccessibilityContract(exhibit: .sphere)

    requireSphereRender(.proxyFamily3)
    requireSpherePresentation(step: 0, regime: .habitat)
    attachScreenshot(named: "immersive-lab-open")
    cycleImmersiveSphereStages()
    let destroyedSceneReceipt = requireElement("sphere-render-state").label

    dismissImmersiveLab()
    attachScreenshot(named: "mission-control-after-dismiss")

    openImmersiveLab()
    requireElement("immersive-controls-hud", timeout: Timeout.immersive)
    let reopenedSceneReceipt = requireSphereRender(.proxyFamily3).label
    XCTAssertNotEqual(reopenedSceneReceipt, destroyedSceneReceipt)
    requireSpherePresentation(step: 0, regime: .habitat)
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

  func testImmersiveStageRailSurvivesTwoHundredSelectionUpdates() {
    let updateCount = 200
    launch(scenario: "torus-mission-control")
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
    attachment.name = "Hevea Vision — 200 stage-selection stress receipt"
    attachment.lifetime = .keepAlways
    add(attachment)
    attachScreenshot(named: "immersive-stage-stress-200-complete")

    dismissImmersiveLab()
  }

  func testSphereStageAndRegimeSpamConvergesAfterTwoHundredChanges() {
    let updateCount = 200
    launch(scenario: "sphere-habitat")
    requireSphereRender(.proxyFamily3)
    requireSpherePresentation(step: 0, regime: .habitat)
    let addressToken = requireElement("sphere-address-token-state", timeout: Timeout.geometry)
    let initialAddressToken = addressToken.label

    let stageButtons = SphereStageCheckpoint.allCases.map { checkpoint in
      requireHittable(checkpoint.immersiveIdentifier, timeout: Timeout.immersive)
    }
    let regimeCheckpoints: [SphereRegimeCheckpoint] = [.atlas, .habitat, .hover]
    let regimeButtons = regimeCheckpoints.map { checkpoint in
      requireHittable(checkpoint.immersiveIdentifier, timeout: Timeout.immersive)
    }
    let startedAt = Date()

    for index in 0..<updateCount {
      if index.isMultiple(of: 2) {
        stageButtons[(index / 2) % stageButtons.count].tap()
      } else {
        regimeButtons[(index / 2) % regimeButtons.count].tap()
      }
      if index.isMultiple(of: 25) {
        XCTAssertEqual(app.state, .runningForeground)
      }
    }

    requireSphereRender(.proxyFamily3)
    requireSpherePresentation(step: 0, regime: .atlas)
    XCTAssertEqual(addressToken.label, initialAddressToken)
    XCTAssertEqual(app.state, .runningForeground)

    let elapsedSeconds = Date().timeIntervalSince(startedAt)
    let receipt =
      "changes=200 stageRequests=100 regimeRequests=100 finalStage=Family 3 "
      + "finalRegime=Atlas addressPreserved=true elapsedSeconds=\(elapsedSeconds)"
    let attachment = XCTAttachment(string: receipt)
    attachment.name = "Hevea Vision — 200 sphere stage and regime convergence receipt"
    attachment.lifetime = .keepAlways
    add(attachment)
    attachScreenshot(named: "sphere-stage-regime-stress-200-complete")

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

  func testSphereRegimeCyclePreservesIntrinsicAddressAndExposesInteriorEscapeControls() {
    launch(scenario: "sphere-atlas")

    requireSphereRender(.proxyFamily3)
    requireSpherePresentation(step: 0, regime: .atlas)
    let state = requireElement("sphere-regime-state", timeout: Timeout.immersive)
    XCTAssertEqual(state.label, "Gauge · Atlas")
    let addressToken = requireElement("sphere-address-token-state", timeout: Timeout.geometry)
    let initialAddressToken = addressToken.label
    XCTAssertFalse(initialAddressToken.isEmpty)

    for checkpoint in SphereRegimeCheckpoint.allCases {
      let button = requireHittable(checkpoint.immersiveIdentifier, timeout: Timeout.immersive)
      XCTAssertTrue(
        tapWithSpatialRetry(button, until: state, hasLabel: checkpoint.visibleState),
        "Sphere regime remained '\(state.label)' after selecting \(checkpoint.visibleState)"
      )
      requireSpherePresentation(step: 0, regime: checkpoint)
      XCTAssertEqual(addressToken.label, initialAddressToken)
      attachScreenshot(named: "sphere-regime-\(checkpoint.screenshotName)")
    }

    requireElement("inside-escape-hud", timeout: Timeout.immersive)
    requireHittable("return-habitat", timeout: Timeout.immersive)
    requireHittable("exit-inside-lab", timeout: Timeout.immersive)
    // XRSimulator 26.5 reports both controls visible and hittable, but two attempts to activate
    // return-habitat produced no Presented-Habitat receipt. This test therefore claims
    // accessibility exposure only. Dedicated return activation remains unverified on simulator
    // and headset; XCTest terminates the app during teardown.
    XCTAssertEqual(addressToken.label, initialAddressToken)
  }

  func testSphereNavigationStressHookReportsExactlyOneThousandIntrinsicSteps() {
    launch(scenario: "sphere-navigation-stress-1000")

    requireElement("immersive-controls-hud", timeout: Timeout.immersive)
    requireSphereRender(.proxyFamily3)
    let addressStep = requireElement("sphere-address-step-state", timeout: Timeout.geometry)
    requireLabel(addressStep, beginningWith: "Address step #1000", timeout: Timeout.geometry)
    requireSpherePresentation(step: 1_000, regime: .habitat)
    XCTAssertEqual(app.state, .runningForeground)
    attachScreenshot(named: "sphere-navigation-stress-1000-complete")
    dismissImmersiveLab()
  }

  func testImmersiveSphereWalkPadSurvivesFiveHundredRealityViewReanchors() {
    let tapCount = 500
    launch(scenario: "sphere-habitat")
    requireSphereRender(.proxyFamily3)
    let addressStep = requireElement("sphere-address-step-state", timeout: Timeout.geometry)
    requireLabel(addressStep, beginningWith: "Address step #0", timeout: Timeout.geometry)
    let presentationState = requireSpherePresentation(step: 0, regime: .habitat)

    let walkButtons = [
      requireHittable("immersive-sphere-walk-forward", timeout: Timeout.immersive),
      requireHittable("immersive-sphere-walk-right", timeout: Timeout.immersive),
      requireHittable("immersive-sphere-walk-left", timeout: Timeout.immersive),
    ]
    let startedAt = Date()

    for index in 0..<tapCount {
      walkButtons[index % walkButtons.count].tap()
      requireLabel(
        presentationState,
        beginningWith: "Presented Habitat · address step #\(index + 1) ·",
        timeout: Timeout.immersive
      )
      if index.isMultiple(of: 50) {
        XCTAssertEqual(app.state, .runningForeground)
      }
    }

    requireLabel(addressStep, beginningWith: "Address step #500", timeout: Timeout.geometry)
    XCTAssertEqual(app.state, .runningForeground)
    let elapsedSeconds = Date().timeIntervalSince(startedAt)
    let receipt =
      "accessibilityTaps=\(tapCount) pattern=forward,right,left "
      + "acknowledgedRealityKitTransforms=\(tapCount) "
      + "finalAddressStep=500 elapsedSeconds=\(elapsedSeconds)"
    let attachment = XCTAttachment(string: receipt)
    attachment.name = "Hevea Vision — 500 acknowledged RealityKit transform receipt"
    attachment.lifetime = .keepAlways
    add(attachment)
    attachScreenshot(named: "sphere-walk-pad-reanchor-stress-500-complete")

    dismissImmersiveLab()
  }

  func testSphereWindowMovementAndResetAreObservable() {
    launch(scenario: "mission-control")
    let state = requireElement("sphere-navigation-state")
    XCTAssertTrue(state.label.contains("steps 0"))

    requireHittable("sphere-walk-forward").tap()
    let stepped = NSPredicate(format: "label CONTAINS %@", "steps 1")
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [XCTNSPredicateExpectation(predicate: stepped, object: state)],
        timeout: Timeout.window
      ),
      .completed
    )

    requireHittable("sphere-reset-address").tap()
    let reset = NSPredicate(format: "label CONTAINS %@", "steps 0")
    XCTAssertEqual(
      XCTWaiter.wait(
        for: [XCTNSPredicateExpectation(predicate: reset, object: state)],
        timeout: Timeout.window
      ),
      .completed
    )
    attachScreenshot(named: "sphere-window-reset-deterministic")
  }
}
