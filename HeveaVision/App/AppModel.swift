import Foundation
import HeveaCore
import Observation
import simd

// The observable state machine and its transactional render receipts intentionally stay in one
// file so Observation cannot publish a partially split provenance state.
// swiftlint:disable file_length

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

enum HeveaExhibit: String, CaseIterable, Identifiable, Sendable {
  case reducedSphere = "Reduced sphere"
  case flatTorus = "Flat torus archive"

  var id: Self { self }

  var shortLabel: String {
    switch self {
    case .reducedSphere: "Reduced sphere"
    case .flatTorus: "Torus archive"
    }
  }

  var systemImage: String {
    switch self {
    case .reducedSphere: "globe.americas.fill"
    case .flatTorus: "tornado"
    }
  }
}

enum SphereRegime: String, CaseIterable, Identifiable, Sendable {
  case atlas = "Atlas"
  case habitat = "Habitat"
  case hover = "Hover"
  case interior = "Interior"

  var id: Self { self }

  /// Local gauges keep the addressed proxy normal parallel to gravity. Pitching the
  /// surface would break that invariant, so only the two inspection gauges permit it.
  var permitsInspectionPitch: Bool {
    switch self {
    case .atlas, .interior: true
    case .habitat, .hover: false
    }
  }

  var systemImage: String {
    switch self {
    case .atlas: "globe"
    case .habitat: "figure.walk"
    case .hover: "arrow.up.to.line.compact"
    case .interior: "circle.inset.filled"
    }
  }

  var gaugeTitle: String {
    switch self {
    case .atlas: "Ambient atlas gauge"
    case .habitat: "Intrinsic foot-scale gauge"
    case .hover: "Intrinsic gauge + signed altitude"
    case .interior: "Collapsed-ball interior gauge"
    }
  }

  var explanation: String {
    switch self {
    case .atlas:
      "The whole finite proxy fits in view. Compare intrinsic diameter π with its bounded ambient chord scale."
    case .habitat:
      "The addressed point stays underfoot while the source-sphere exponential map advances the world around you."
    case .hover:
      "The same intrinsic address remains authoritative; a plumb line makes signed altitude explicit."
    case .interior:
      "Read the finite shell from inside. The addressed point and outward normal remain visible through a double-sided surface."
    }
  }
}

enum SphereMove: Sendable {
  case forward
  case backward
  case left
  case right
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

struct SphereDiagnosticSnapshot: Equatable, Sendable {
  var vertexCount: Int
  var triangleCount: Int
  var measuredContainingRadius: Double
  var declaredContainingRadius: Double
  var eulerCharacteristic: Int
  var seamResidual: Double
  var fingerprint: String

  static let pending = SphereDiagnosticSnapshot(
    vertexCount: 0,
    triangleCount: 0,
    measuredContainingRadius: 0,
    declaredContainingRadius: SphereConfiguration.default.declaredProxyContainingRadius,
    eulerCharacteristic: 0,
    seamResidual: 0,
    fingerprint: "pending"
  )
}

/// A receipt issued only after a caller has installed one generated sphere mesh in RealityKit.
///
/// Keeping the requested stage separate from this receipt prevents asynchronous generation from
/// relabeling an older, still-visible mesh as the newly requested construction stage.
struct SphereRenderReceipt: Equatable, Sendable {
  let stage: SphereStage
  let sectionStep: Int
  let geometryRevision: Int
  let sceneSessionRevision: UInt64
  let installationRevision: UInt64
  let fingerprint: String
}

/// A receipt issued only after the installed sphere has received the requested intrinsic pose.
struct SpherePresentationReceipt: Equatable, Sendable {
  let stage: SphereStage
  let regime: SphereRegime
  let navigationRevision: Int
  let navigationStepCount: UInt64
  let addressFingerprint: String
  let poseFingerprint: String
  let renderFingerprint: String
  let sceneSessionRevision: UInt64
  let renderInstallationRevision: UInt64
}

@MainActor
@Observable
// swiftlint:disable:next type_body_length
final class AppModel {
  static let mainWindowID = "HeveaMissionControl"
  static let immersiveSpaceID = "HeveaImmersiveLab"

  var selectedExhibit: HeveaExhibit = .reducedSphere {
    didSet {
      if selectedExhibit != oldValue {
        invalidateSpherePresentation()
      }
    }
  }
  var selectedSphereStage: SphereStage = .proxyFamily3 {
    didSet {
      if selectedSphereStage != oldValue {
        invalidateSpherePresentation()
      }
    }
  }
  var selectedSphereRegime: SphereRegime = .habitat {
    didSet {
      if selectedSphereRegime != oldValue {
        invalidateSpherePresentation()
      }
    }
  }
  var sphereNavigation: SphereNavigationState = AppModel.makeInitialSphereNavigation() {
    didSet {
      if sphereNavigation != oldValue {
        invalidateSpherePresentation()
      }
    }
  }
  var selectedStage: HeveaStage = .proxyStage3
  var selectedOverlay: DiagnosticOverlay = .normalVariation
  var presentation: LabPresentation = .outside
  var immersiveSpaceState: ImmersiveSpaceState = .closed
  var selectedSample: SelectedSurfaceSample?
  var diagnostics: DiagnosticSnapshot = .pending
  var sphereDiagnostics: SphereDiagnosticSnapshot = .pending
  var modelScale: Float = 1 {
    didSet {
      if modelScale != oldValue {
        invalidateSpherePresentation()
      }
    }
  }
  var modelRotation = SIMD2<Float>(0, 0) {
    didSet {
      if modelRotation != oldValue {
        invalidateSpherePresentation()
      }
    }
  }
  var sectionAmount: Double = 0 {
    didSet {
      if sectionAmount != oldValue {
        invalidateSpherePresentation()
      }
    }
  }
  var frequencyCompression: Double = 1
  var motionEnabled = true
  var showDomainFloor = true
  var showGaussSphere = true
  var generationError: String?
  var geometryRevision = 0
  var sphereNavigationRevision = 0
  var resetRevision = 0
  private(set) var sphereRenderReceipt: SphereRenderReceipt?
  private(set) var spherePresentationReceipt: SpherePresentationReceipt?
  private(set) var sphereSceneSessionRevision: UInt64 = 0
  private(set) var sphereSceneIsActive = false
  private(set) var sphereRenderInstallationRevision: UInt64 = 0
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
    switch selectedExhibit {
    case .reducedSphere:
      selectedSphereStage.claimClass
    case .flatTorus:
      selectedOverlay == .surface ? selectedStage.claimClass : .heveaVisionExperiment
    }
  }

  var currentClaimExplanation: String {
    if selectedExhibit == .reducedSphere {
      return selectedSphereStage.claimCeiling
    }
    return switch currentClaim {
    case .upstreamBaseline:
      "The short torus formula is a pinned, documented input to Hévéa. No limiting-embedding claim is made."
    case .realTimeProxy:
      "This compressed interactive stage illustrates direction and scale; it is not the upstream embedding."
    case .heveaVisionExperiment:
      "This readout is a finite-resolution numerical observation on the displayed mesh, not a theorem."
    }
  }

  var sphereStageIndex: Int {
    SphereStage.allCases.firstIndex(of: selectedSphereStage) ?? 0
  }

  /// The discrete sectioning value used by sphere generation requests.
  var sphereSectionStep: Int {
    Int((sectionAmount * 12).rounded())
  }

  /// The construction stage that is actually installed, not merely the requested selection.
  var renderedSphereStage: SphereStage? {
    sphereRenderReceipt?.stage
  }

  var sphereRenderIsCurrent: Bool {
    guard selectedExhibit == .reducedSphere,
      sphereSceneIsActive,
      let receipt = sphereRenderReceipt
    else {
      return false
    }
    return receipt.stage == selectedSphereStage
      && receipt.sectionStep == sphereSectionStep
      && receipt.geometryRevision == geometryRevision
      && receipt.sceneSessionRevision == sphereSceneSessionRevision
  }

  var spherePresentationIsCurrent: Bool {
    guard sphereRenderIsCurrent,
      let renderReceipt = sphereRenderReceipt,
      let presentationReceipt = spherePresentationReceipt
    else {
      return false
    }
    return presentationReceipt.stage == selectedSphereStage
      && presentationReceipt.regime == selectedSphereRegime
      && presentationReceipt.navigationRevision == sphereNavigationRevision
      && presentationReceipt.navigationStepCount == sphereNavigation.stepCount
      && presentationReceipt.addressFingerprint == sphereAddressToken
      && presentationReceipt.poseFingerprint == spherePoseToken
      && presentationReceipt.renderFingerprint == renderReceipt.fingerprint
      && presentationReceipt.sceneSessionRevision == sphereSceneSessionRevision
      && presentationReceipt.renderInstallationRevision == renderReceipt.installationRevision
  }

  /// A locale-independent token containing every authoritative field of the sphere address.
  var sphereAddressToken: String {
    let address = sphereNavigation.address
    return String(
      format: "u[%+.17g,%+.17g,%+.17g]|alt[%+.17g]|head[%+.17g]",
      locale: Locale(identifier: "en_US_POSIX"),
      address.unitDirection.x,
      address.unitDirection.y,
      address.unitDirection.z,
      address.altitude,
      address.headingRadians
    )
  }

  var spherePoseToken: String {
    let rotation = spherePresentationRotation
    return String(
      format: "scale[%+.9g]|rotation[%+.9g,%+.9g]",
      locale: Locale(identifier: "en_US_POSIX"),
      modelScale,
      rotation.x,
      rotation.y
    )
  }

  /// The pose actually presented by RealityKit. Habitat and Hover intentionally
  /// expose gravity-preserving yaw only; Atlas and Interior remain full inspection gauges.
  var spherePresentationRotation: SIMD2<Float> {
    selectedSphereRegime.permitsInspectionPitch ? modelRotation : [modelRotation.x, 0]
  }

  var spherePoseIsValid: Bool {
    modelScale.isFinite && (0.55...2.25).contains(modelScale)
      && modelRotation.x.isFinite && (-Float.pi...Float.pi).contains(modelRotation.x)
      && modelRotation.y.isFinite
      && (-Float.pi / 2...Float.pi / 2).contains(modelRotation.y)
  }

  var sphereRenderStatusText: String {
    guard selectedExhibit == .reducedSphere else {
      return "Sphere render inactive"
    }
    guard sphereSceneIsActive else {
      return "Immersive renderer inactive · requested \(selectedSphereStage.shortDisplayName)"
    }
    guard let receipt = sphereRenderReceipt else {
      return "Rendering \(selectedSphereStage.shortDisplayName)…"
    }
    if sphereRenderIsCurrent {
      return "Rendered \(receipt.stage.shortDisplayName) · session "
        + "\(receipt.sceneSessionRevision) · install \(receipt.installationRevision) · "
        + shortFingerprint(receipt.fingerprint)
    }
    return "Loading \(selectedSphereStage.shortDisplayName) · retaining "
      + "\(receipt.stage.shortDisplayName) · session \(receipt.sceneSessionRevision) · "
      + "install \(receipt.installationRevision) · \(shortFingerprint(receipt.fingerprint))"
  }

  var spherePresentationStatusText: String {
    if spherePresentationIsCurrent, let receipt = spherePresentationReceipt {
      return
        "Presented \(receipt.regime.rawValue) · address step #\(receipt.navigationStepCount) · "
        + "session \(receipt.sceneSessionRevision) · "
        + "install \(receipt.renderInstallationRevision) · "
        + "pose \(receipt.poseFingerprint) · \(receipt.addressFingerprint)"
    }
    if let receipt = spherePresentationReceipt {
      return "Presentation pending · address step #\(sphereNavigation.stepCount) · "
        + "last acknowledged #\(receipt.navigationStepCount)"
    }
    return "Presentation pending · address step #\(sphereNavigation.stepCount) · "
      + sphereAddressToken
  }

  var sphereLatitudeDegrees: Double {
    sphereNavigation.address.latitude * 180 / .pi
  }

  var sphereLongitudeDegrees: Double {
    sphereNavigation.address.longitude * 180 / .pi
  }

  var sphereHeadingDegrees: Double {
    sphereNavigation.address.headingRadians * 180 / .pi
  }

  var sphereReductionRatio: Double {
    Double.pi / (2 * sphereDiagnostics.declaredContainingRadius)
  }

  var sphereRidgeSummary: String {
    sphereRidgeSummary(for: selectedSphereStage)
  }

  func sphereRidgeSummary(for stage: SphereStage) -> String {
    let schedule = SphereConfiguration.default.proxySchedule.corrugations
    let rendered = schedule.map(\.renderedRidgeCount).map(String.init).joined(separator: " / ")
    let paper = schedule.map(\.paperRidgeCount).map(String.init).joined(separator: " / ")
    return "Rendered \(rendered) · paper \(paper) · active \(stage.appliedCorrugationCount)"
  }

  var stageIndex: Int {
    HeveaStage.allCases.firstIndex(of: selectedStage) ?? 0
  }

  func selectExhibit(_ exhibit: HeveaExhibit) {
    guard selectedExhibit != exhibit else { return }
    selectedExhibit = exhibit
    selectedSample = nil
    geometryRevision &+= 1
  }

  func selectSphereStage(_ stage: SphereStage) {
    guard selectedSphereStage != stage else { return }
    selectedSphereStage = stage
    selectedSample = nil
    geometryRevision &+= 1
  }

  func stepSphereStage(by offset: Int) {
    let stages = SphereStage.allCases
    let destination = min(
      max(sphereStageIndex + offset, stages.startIndex),
      stages.index(before: stages.endIndex)
    )
    selectSphereStage(stages[destination])
  }

  func selectSphereRegime(_ regime: SphereRegime) {
    guard selectedSphereRegime != regime else { return }
    selectedSphereRegime = regime
    if !regime.permitsInspectionPitch, modelRotation.y != 0 {
      modelRotation.y = 0
    }
    sphereNavigationRevision &+= 1
  }

  func beginSphereSceneSession() {
    let (nextRevision, overflow) = sphereSceneSessionRevision.addingReportingOverflow(1)
    precondition(!overflow, "Sphere scene-session revision exhausted")
    sphereSceneSessionRevision = nextRevision
    sphereSceneIsActive = true
    sphereRenderReceipt = nil
    spherePresentationReceipt = nil
    sphereDiagnostics = .pending
  }

  func endSphereSceneSession() {
    sphereSceneIsActive = false
    sphereRenderReceipt = nil
    spherePresentationReceipt = nil
    sphereDiagnostics = .pending
  }

  /// Records a mesh only after the caller has installed it into the live RealityKit scene.
  /// Returns `false` for an obsolete request so stale asynchronous work cannot acquire provenance.
  @discardableResult
  func acknowledgeSphereRender(
    stage: SphereStage,
    sectionStep: Int,
    geometryRevision: Int,
    sceneSessionRevision: UInt64,
    snapshot: SphereDiagnosticSnapshot
  ) -> Bool {
    guard selectedExhibit == .reducedSphere,
      sphereSceneIsActive,
      stage == selectedSphereStage,
      sectionStep == sphereSectionStep,
      geometryRevision == self.geometryRevision,
      sceneSessionRevision == sphereSceneSessionRevision,
      snapshot.vertexCount > 0,
      snapshot.triangleCount > 0,
      !snapshot.fingerprint.isEmpty,
      snapshot.fingerprint != SphereDiagnosticSnapshot.pending.fingerprint
    else {
      return false
    }

    let (nextInstallationRevision, overflow) =
      sphereRenderInstallationRevision.addingReportingOverflow(1)
    guard !overflow else { return false }
    sphereRenderInstallationRevision = nextInstallationRevision
    sphereDiagnostics = snapshot
    sphereRenderReceipt = SphereRenderReceipt(
      stage: stage,
      sectionStep: sectionStep,
      geometryRevision: geometryRevision,
      sceneSessionRevision: sceneSessionRevision,
      installationRevision: nextInstallationRevision,
      fingerprint: snapshot.fingerprint
    )
    spherePresentationReceipt = nil
    return true
  }

  /// Records a RealityKit pose application only when it exactly matches the current render and
  /// authoritative intrinsic navigation state.
  @discardableResult
  func acknowledgeSpherePresentation(
    stage: SphereStage,
    regime: SphereRegime,
    navigationRevision: Int,
    navigationStepCount: UInt64,
    addressFingerprint: String,
    poseFingerprint: String,
    renderFingerprint: String,
    renderInstallationRevision: UInt64
  ) -> Bool {
    guard sphereRenderIsCurrent,
      let renderReceipt = sphereRenderReceipt,
      spherePoseIsValid,
      stage == selectedSphereStage,
      regime == selectedSphereRegime,
      navigationRevision == sphereNavigationRevision,
      navigationStepCount == sphereNavigation.stepCount,
      addressFingerprint == sphereAddressToken,
      poseFingerprint == spherePoseToken,
      renderFingerprint == renderReceipt.fingerprint,
      renderInstallationRevision == renderReceipt.installationRevision
    else {
      return false
    }

    spherePresentationReceipt = SpherePresentationReceipt(
      stage: stage,
      regime: regime,
      navigationRevision: navigationRevision,
      navigationStepCount: navigationStepCount,
      addressFingerprint: addressFingerprint,
      poseFingerprint: poseFingerprint,
      renderFingerprint: renderFingerprint,
      sceneSessionRevision: renderReceipt.sceneSessionRevision,
      renderInstallationRevision: renderInstallationRevision
    )
    return true
  }

  func moveOnSphere(_ move: SphereMove, step: Double = 0.035) {
    let forward: Double
    let right: Double
    switch move {
    case .forward: (forward, right) = (step, 0)
    case .backward: (forward, right) = (-step, 0)
    case .left: (forward, right) = (0, -step)
    case .right: (forward, right) = (0, step)
    }

    do {
      let tangentStep = try SphereNavigator.headingTangentStep(
        at: sphereNavigation.address,
        forward: forward,
        right: right
      )
      sphereNavigation = try SphereNavigator.advance(
        sphereNavigation,
        tangentStep: tangentStep
      )
      generationError = nil
      sphereNavigationRevision &+= 1
    } catch {
      generationError = String(describing: error)
    }
  }

  func turnOnSphere(by radians: Double) {
    do {
      let address = try sphereNavigation.address.turned(by: radians)
      sphereNavigation = try SphereNavigationState(
        address: address,
        traversedIntrinsicDistance: sphereNavigation.traversedIntrinsicDistance,
        stepCount: sphereNavigation.stepCount
      )
      generationError = nil
      sphereNavigationRevision &+= 1
    } catch {
      generationError = String(describing: error)
    }
  }

  func changeSphereAltitude(by delta: Double) {
    let boundedAltitude = min(max(sphereNavigation.address.altitude + delta, -0.30), 1.0)
    do {
      let address = try sphereNavigation.address.withAltitude(boundedAltitude)
      sphereNavigation = try SphereNavigationState(
        address: address,
        traversedIntrinsicDistance: sphereNavigation.traversedIntrinsicDistance,
        stepCount: sphereNavigation.stepCount
      )
      generationError = nil
      sphereNavigationRevision &+= 1
    } catch {
      generationError = String(describing: error)
    }
  }

  func runSphereNavigationStress(stepCount: Int) {
    guard stepCount > 0 else { return }
    for index in 0..<stepCount {
      if index.isMultiple(of: 19) {
        turnOnSphere(by: .pi / 180)
      } else if index.isMultiple(of: 23) {
        turnOnSphere(by: -.pi / 240)
      }
      switch index % 4 {
      case 0, 1: moveOnSphere(.forward, step: 0.004)
      case 2: moveOnSphere(.right, step: 0.003)
      default: moveOnSphere(.left, step: 0.002)
      }
    }
  }

  func walkCapToEquator() {
    sphereNavigation = Self.makeInitialSphereNavigation()
    for _ in 0..<32 {
      moveOnSphere(.forward, step: 0.04)
    }
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
    invalidateSpherePresentation()
    presentation = .outside
    selectedSphereRegime = .habitat
    sphereNavigation = Self.makeInitialSphereNavigation()
    modelScale = 1
    modelRotation = .zero
    sectionAmount = 0
    selectedSample = nil
    generationError = nil
    resetRevision &+= 1
    sphereNavigationRevision &+= 1
  }

  func applyMagnification(_ magnification: Float) {
    guard magnification.isFinite else {
      generationError = "Rejected a non-finite presentation scale."
      return
    }
    modelScale = min(max(magnification, 0.55), 2.25)
  }

  func applyRotation(delta: SIMD2<Float>) {
    setRotation(modelRotation + delta)
  }

  func setRotation(_ rotation: SIMD2<Float>) {
    guard rotation.x.isFinite, rotation.y.isFinite else {
      generationError = "Rejected a non-finite presentation rotation."
      return
    }
    let yaw = Double(rotation.x)
    modelRotation.x = Float(atan2(sin(yaw), cos(yaw)))
    let permitsPitch = selectedExhibit == .flatTorus || selectedSphereRegime.permitsInspectionPitch
    modelRotation.y = permitsPitch
      ? min(max(rotation.y, -.pi / 2), .pi / 2)
      : 0
  }

  private func applyLaunchScenario(arguments: [String], environment: [String: String]) {
    let selectedScenario =
      environment["HEVEA_SCENARIO"]
      ?? launchArgument(named: "--hevea-scenario", in: arguments)
    let repetition =
      environment["HEVEA_REPETITION"].flatMap(Int.init)
      ?? launchArgument(named: "--hevea-repetition", in: arguments).flatMap(Int.init)
      ?? 0
    let automationRequested =
      environment["HEVEA_AUTOMATION"] == "1"
      || arguments.contains("--hevea-automation")

    automationScenario = automationRequested ? selectedScenario : nil
    automationRepetition = max(0, repetition)

    guard !applySphereLaunchScenario(selectedScenario) else { return }
    applyTorusLaunchScenario(selectedScenario)
  }

  private func launchArgument(named name: String, in arguments: [String]) -> String? {
    guard let marker = arguments.firstIndex(of: name) else { return nil }
    let valueIndex = arguments.index(after: marker)
    return arguments.indices.contains(valueIndex) ? arguments[valueIndex] : nil
  }

  private func applySphereLaunchScenario(_ scenario: String?) -> Bool {
    switch scenario {
    case "sphere-atlas":
      selectedExhibit = .reducedSphere
      selectedSphereStage = .proxyFamily3
      selectedSphereRegime = .atlas
    case "sphere-habitat", "hero-window", "mission-control":
      selectedExhibit = .reducedSphere
      selectedSphereStage = .proxyFamily3
      selectedSphereRegime = .habitat
    case "sphere-hover":
      selectedExhibit = .reducedSphere
      selectedSphereStage = .proxyFamily3
      selectedSphereRegime = .hover
      changeSphereAltitude(by: 0.18)
    case "sphere-interior":
      selectedExhibit = .reducedSphere
      selectedSphereStage = .proxyFamily3
      selectedSphereRegime = .interior
    case "sphere-stage-sweep":
      selectedExhibit = .reducedSphere
      let stages = SphereStage.allCases
      selectedSphereStage = stages[automationRepetition % stages.count]
      selectedSphereRegime = .atlas
    case "sphere-navigation-stress-1000":
      selectedExhibit = .reducedSphere
      selectedSphereStage = .proxyFamily3
      selectedSphereRegime = .habitat
      runSphereNavigationStress(stepCount: 1_000)
    default:
      return false
    }
    return true
  }

  private func applyTorusLaunchScenario(_ scenario: String?) {
    switch scenario {
    case "torus-mission-control":
      selectedExhibit = .flatTorus
      selectedStage = .proxyStage3
      selectedOverlay = .normalVariation
    case "baseline-window":
      selectedExhibit = .flatTorus
      selectedStage = .shortTorus
      selectedOverlay = .surface
    case "metric-window", "metric-heatmap":
      selectedExhibit = .flatTorus
      selectedStage = .proxyStage2
      selectedOverlay = .metricResidual
    case "microscope-window", "scale-microscope":
      selectedExhibit = .flatTorus
      selectedStage = .proxyStage3
      selectedOverlay = .normalVariation
    case "grid-window":
      selectedExhibit = .flatTorus
      selectedStage = .proxyStage1
      selectedOverlay = .parameterGrid
    case "stage-sweep":
      selectedExhibit = .flatTorus
      let stages = HeveaStage.allCases
      selectedStage = stages[automationRepetition % stages.count]
      selectedOverlay = .parameterGrid
    default:
      break
    }
  }

  private static func makeInitialSphereNavigation() -> SphereNavigationState {
    let latitude = -1.28
    let direction = Vector3(x: cos(latitude), y: 0, z: sin(latitude))
    do {
      let address = try SphereAddress(
        unitDirection: direction,
        altitude: 0,
        headingRadians: 0
      )
      return try SphereNavigationState(address: address)
    } catch {
      preconditionFailure("The checked-in finite initial sphere address must be valid: \(error)")
    }
  }

  private func invalidateSpherePresentation() {
    spherePresentationReceipt = nil
  }

  private func shortFingerprint(_ fingerprint: String) -> String {
    String(fingerprint.prefix(12))
  }
}
