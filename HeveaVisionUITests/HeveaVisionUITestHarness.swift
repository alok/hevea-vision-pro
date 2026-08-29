import XCTest

@MainActor
extension HeveaVisionUITests {
  enum Timeout {
    static let window: TimeInterval = 10
    static let immersive: TimeInterval = 20
    static let geometry: TimeInterval = 30
  }

  func launch(scenario: String, repetition: Int = 0) {
    let launchedApp = XCUIApplication()
    launchedApp.launchEnvironment = [
      "HEVEA_AUTOMATION": "1",
      "HEVEA_SCENARIO": scenario,
      "HEVEA_REPETITION": String(repetition),
    ]
    launchedApp.launchArguments = [
      "--hevea-automation",
      "--hevea-scenario", scenario,
      "--hevea-repetition", String(repetition),
    ]
    launchedApp.launch()
    app = launchedApp
    addTeardownBlock { @MainActor [weak launchedApp] in
      guard let launchedApp, launchedApp.state != .notRunning else { return }
      launchedApp.terminate()
    }
  }

  func openImmersiveLab() {
    requireElement("mission-control")
    requireHittable("toggle-immersive-lab").tap()
    requireElement("immersive-controls-hud", timeout: Timeout.immersive)
  }

  func dismissImmersiveLab() {
    let controls = requireElement("immersive-controls-hud", timeout: Timeout.immersive)
    requireHittable("exit-immersive-lab", timeout: Timeout.immersive).tap()
    XCTAssertTrue(
      controls.waitForNonExistence(timeout: Timeout.immersive),
      "Immersive controls remained after requesting dismissal"
    )
    requireHittable("toggle-immersive-lab", timeout: Timeout.immersive)
  }

  enum ImmersiveExhibit {
    case sphere
    case torus
  }

  func requireImmersiveAccessibilityContract(exhibit: ImmersiveExhibit) {
    var identifiers = [
      "immersive-lab",
      "immersive-stage-hud",
      "immersive-legend-hud",
      "immersive-sample-hud",
      "immersive-controls-hud",
      "reset-lab",
      "exit-immersive-lab",
    ]
    switch exhibit {
    case .sphere:
      identifiers.append(contentsOf: [
        "sphere-regime-picker",
        "immersive-sphere-walk-forward",
        "immersive-sphere-altitude-up",
        "immersive-sphere-section-toggle",
      ])
    case .torus:
      identifiers.append(contentsOf: [
        "immersive-overlay-menu",
        "presentation-picker",
        "section-slider",
      ])
    }
    for identifier in identifiers {
      requireElement(identifier, timeout: Timeout.immersive)
    }
  }

  func cycleImmersiveStages() {
    for checkpoint in StageCheckpoint.allCases {
      let button = requireHittable(checkpoint.immersiveIdentifier, timeout: Timeout.immersive)
      button.tap()
      requireStaticText(checkpoint.shortTitle, timeout: Timeout.geometry)
    }
  }

  func cycleImmersiveSphereStages() {
    let renderState = requireElement("sphere-render-state", timeout: Timeout.geometry)
    for checkpoint in SphereStageCheckpoint.allCases {
      let button = requireHittable(checkpoint.immersiveIdentifier, timeout: Timeout.immersive)
      button.tap()
      requireLabel(
        renderState,
        beginningWith: "Rendered \(checkpoint.shortTitle) ·",
        timeout: Timeout.geometry
      )
      assertNoGenerationError()
    }
  }

  @discardableResult
  func requireSphereRender(
    _ checkpoint: SphereStageCheckpoint = .proxyFamily3,
    timeout: TimeInterval = Timeout.geometry,
    file: StaticString = #filePath,
    line: UInt = #line
  ) -> XCUIElement {
    let state = requireElement("sphere-render-state", timeout: timeout, file: file, line: line)
    requireLabel(
      state,
      beginningWith: "Rendered \(checkpoint.shortTitle) ·",
      timeout: timeout,
      file: file,
      line: line
    )
    assertNoGenerationError(file: file, line: line)
    return state
  }

  @discardableResult
  func requireSpherePresentation(
    step: Int,
    regime: SphereRegimeCheckpoint,
    timeout: TimeInterval = Timeout.geometry,
    file: StaticString = #filePath,
    line: UInt = #line
  ) -> XCUIElement {
    let state = requireElement(
      "sphere-presentation-state",
      timeout: timeout,
      file: file,
      line: line
    )
    requireLabel(
      state,
      beginningWith: "Presented \(regime.displayName) · address step #\(step) ·",
      timeout: timeout,
      file: file,
      line: line
    )
    assertNoGenerationError(file: file, line: line)
    return state
  }

  @discardableResult
  func requireElement(
    _ identifier: String,
    timeout: TimeInterval = Timeout.window,
    file: StaticString = #filePath,
    line: UInt = #line
  ) -> XCUIElement {
    let element = app.descendants(matching: .any)
      .matching(identifier: identifier)
      .firstMatch
    if !element.waitForExistence(timeout: timeout) {
      attachScreenshot(named: "failure-missing-\(identifier)")
      XCTFail(
        "Missing accessibility identifier '\(identifier)' after \(timeout) seconds.\n\(app.debugDescription)",
        file: file,
        line: line
      )
    }
    return element
  }

  @discardableResult
  func requireHittable(
    _ identifier: String,
    timeout: TimeInterval = Timeout.window,
    file: StaticString = #filePath,
    line: UInt = #line
  ) -> XCUIElement {
    let element = requireElement(identifier, timeout: timeout, file: file, line: line)
    let predicate = NSPredicate(format: "exists == true AND hittable == true")
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
    if XCTWaiter.wait(for: [expectation], timeout: timeout) != .completed {
      attachScreenshot(named: "failure-not-hittable-\(identifier)")
      XCTFail(
        "Element '\(identifier)' exists but is not hittable.\n\(element.debugDescription)",
        file: file,
        line: line
      )
    }
    return element
  }

  @discardableResult
  func requireButton(
    label: String,
    timeout: TimeInterval = Timeout.window,
    file: StaticString = #filePath,
    line: UInt = #line
  ) -> XCUIElement {
    let predicate = NSPredicate(format: "label == %@", label)
    let button = app.buttons.matching(predicate).firstMatch
    if !button.waitForExistence(timeout: timeout) {
      attachScreenshot(named: "failure-missing-button-\(label.lowercased())")
      XCTFail("Missing button labeled '\(label)'", file: file, line: line)
    }
    return button
  }

  @discardableResult
  func requireStaticText(
    _ label: String,
    timeout: TimeInterval = Timeout.window,
    file: StaticString = #filePath,
    line: UInt = #line
  ) -> XCUIElement {
    let predicate = NSPredicate(format: "label == %@", label)
    let text = app.staticTexts.matching(predicate).firstMatch
    if !text.waitForExistence(timeout: timeout) {
      attachScreenshot(named: "failure-missing-state-text")
      XCTFail("Missing state witness '\(label)'", file: file, line: line)
    }
    return text
  }

  func requireLabel(
    _ element: XCUIElement,
    beginningWith prefix: String,
    timeout: TimeInterval = Timeout.window,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let predicate = NSPredicate(format: "label BEGINSWITH %@", prefix)
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
    if XCTWaiter.wait(for: [expectation], timeout: timeout) != .completed {
      attachScreenshot(named: "failure-state-label")
      XCTFail(
        "State witness '\(element.identifier)' never began with '\(prefix)'; "
          + "last label was '\(element.label)'",
        file: file,
        line: line
      )
    }
  }

  func assertNoGenerationError(
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let error = app.descendants(matching: .any)
      .matching(identifier: "generation-error")
      .firstMatch
    if error.exists {
      attachScreenshot(named: "failure-generation-error")
      XCTFail("Geometry generation reported: \(error.label)", file: file, line: line)
    }
  }

  @discardableResult
  func requireStaticText(
    beginningWith prefix: String,
    timeout: TimeInterval = Timeout.window,
    file: StaticString = #filePath,
    line: UInt = #line
  ) -> XCUIElement {
    let predicate = NSPredicate(format: "label BEGINSWITH %@", prefix)
    let text = app.staticTexts.matching(predicate).firstMatch
    if !text.waitForExistence(timeout: timeout) {
      attachScreenshot(named: "failure-missing-prefixed-state-text")
      XCTFail("Missing state witness beginning with '\(prefix)'", file: file, line: line)
    }
    return text
  }

  func attachScreenshot(named name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = "Hevea Vision — \(name)"
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  func tapWithSpatialRetry(
    _ control: XCUIElement,
    until state: XCUIElement,
    hasLabel label: String
  ) -> Bool {
    for _ in 0..<2 {
      control.tap()
      let predicate = NSPredicate(format: "label == %@", label)
      let expectation = XCTNSPredicateExpectation(predicate: predicate, object: state)
      if XCTWaiter.wait(for: [expectation], timeout: 3) == .completed {
        return true
      }
    }
    return false
  }

}

enum StageCheckpoint: CaseIterable {
  case shortTorus
  case proxyStage1
  case proxyStage2
  case proxyStage3

  var windowIdentifier: String {
    switch self {
    case .shortTorus: "stage-shortTorus"
    case .proxyStage1: "stage-proxyStage1"
    case .proxyStage2: "stage-proxyStage2"
    case .proxyStage3: "stage-proxyStage3"
    }
  }

  var immersiveIdentifier: String {
    switch self {
    case .shortTorus: "immersive-stage-shortTorus"
    case .proxyStage1: "immersive-stage-proxyStage1"
    case .proxyStage2: "immersive-stage-proxyStage2"
    case .proxyStage3: "immersive-stage-proxyStage3"
    }
  }

  var visibleTitle: String {
    switch self {
    case .shortTorus: "UPSTREAM BASELINE — Short Torus"
    case .proxyStage1: "REAL-TIME PROXY 1 — u Corrugation"
    case .proxyStage2: "REAL-TIME PROXY 2 — u + 2v Corrugation"
    case .proxyStage3: "REAL-TIME PROXY 3 — u - 2v Corrugation"
    }
  }

  var shortTitle: String {
    switch self {
    case .shortTorus: "Short Torus"
    case .proxyStage1: "Proxy Stage 1"
    case .proxyStage2: "Proxy Stage 2"
    case .proxyStage3: "Proxy Stage 3"
    }
  }
}

enum SphereStageCheckpoint: CaseIterable {
  case unitSphere
  case shortMap
  case proxyFamily1
  case proxyFamily2
  case proxyFamily3

  var windowIdentifier: String {
    "sphere-stage-\(rawName)"
  }

  var immersiveIdentifier: String {
    "immersive-sphere-stage-\(rawName)"
  }

  var visibleTitle: String {
    switch self {
    case .unitSphere: "UPSTREAM BASELINE — Unit sphere"
    case .shortMap: "REAL-TIME PROXY — Short map"
    case .proxyFamily1: "REAL-TIME PROXY 1 — First primitive family"
    case .proxyFamily2: "REAL-TIME PROXY 2 — Second primitive family"
    case .proxyFamily3: "REAL-TIME PROXY 3 — Third primitive family"
    }
  }

  var shortTitle: String {
    switch self {
    case .unitSphere: "Unit sphere"
    case .shortMap: "Short map"
    case .proxyFamily1: "Family 1"
    case .proxyFamily2: "Family 2"
    case .proxyFamily3: "Family 3"
    }
  }

  private var rawName: String {
    switch self {
    case .unitSphere: "unitSphere"
    case .shortMap: "shortMap"
    case .proxyFamily1: "proxyFamily1"
    case .proxyFamily2: "proxyFamily2"
    case .proxyFamily3: "proxyFamily3"
    }
  }
}

enum SphereRegimeCheckpoint: CaseIterable {
  case atlas
  case habitat
  case hover
  case interior

  var immersiveIdentifier: String {
    "immersive-sphere-regime-\(screenshotName)"
  }

  var visibleState: String {
    "Gauge · \(displayName)"
  }

  var displayName: String {
    switch self {
    case .atlas: "Atlas"
    case .habitat: "Habitat"
    case .hover: "Hover"
    case .interior: "Interior"
    }
  }

  var screenshotName: String {
    switch self {
    case .atlas: "atlas"
    case .habitat: "habitat"
    case .hover: "hover"
    case .interior: "interior"
    }
  }

}

enum OverlayCheckpoint: CaseIterable {
  case surface
  case grid
  case metric
  case normals
  case direction

  var windowIdentifier: String {
    switch self {
    case .surface: "overlay-surface"
    case .grid: "overlay-grid"
    case .metric: "overlay-metric"
    case .normals: "overlay-normals"
    case .direction: "overlay-direction"
    }
  }

  var explanation: String {
    switch self {
    case .surface:
      "A neutral material for reading the finite proxy geometry."
    case .grid:
      "Coordinate lines show the square parameter domain with opposite edges identified."
    case .metric:
      "Color bins show a finite-difference first-fundamental-form residual on this mesh."
    case .normals:
      "Color bins show how quickly neighboring unit normals change at the selected sampling scale."
    case .direction:
      "A directional overlay identifies the active low-frequency explanatory ripple."
    }
  }

  var screenshotName: String {
    switch self {
    case .surface: "surface"
    case .grid: "parameter-grid"
    case .metric: "metric-residual"
    case .normals: "normal-variation"
    case .direction: "corrugation-direction"
    }
  }
}
