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

  func requireImmersiveAccessibilityContract() {
    for identifier in [
      "immersive-lab",
      "immersive-stage-hud",
      "immersive-legend-hud",
      "immersive-sample-hud",
      "immersive-controls-hud",
      "immersive-overlay-menu",
      "presentation-picker",
      "section-slider",
      "reset-lab",
      "exit-immersive-lab",
    ] {
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
