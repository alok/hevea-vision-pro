// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import Observation

/// Opt-in observability for spatial input (launch argument --input-diagnostics), so an operator-assisted test can tell
/// "no gesture callback reached the app" from "callbacks arrived and were refused". It counts the immersive scene's
/// drag and tap callbacks and keeps only the last entity, direction and outcome; nothing is stored or sent elsewhere,
/// and without the argument nothing is shown.
@MainActor @Observable final class InputDiagnostics {
  static let shared = InputDiagnostics(enabled: ProcessInfo.processInfo.arguments.contains("--input-diagnostics"))
  let enabled: Bool
  // One property per declaration: @Observable does not track multiple bindings in one `var`.
  private(set) var dragChanges = 0
  private(set) var dragEnds = 0
  private(set) var dragResets = 0
  private(set) var taps = 0
  /// Accessibility activations arrive by a separate route from SpatialTapGesture (a Device Hub click may use either).
  private(set) var activations = 0
  private(set) var lastActivateEntity = "none"
  /// The Origin sky target as the renderer last left it: collision present, enabled, scale.
  private(set) var sky = "unknown"
  private(set) var lastDragEntity = "none"
  private(set) var lastTapEntity = "none"
  private(set) var lastOutcome = "none"
  /// The direction used (the gesture value's own conversion into the object's frame) at the first and last step; the
  /// earlier two-hop path through the scene at the same steps; the gesture's start location (same direct conversion)
  /// and its last translation as a vector in the object's frame. Recorded, never used.
  private(set) var firstDirection: SIMD3<Double>?
  private(set) var lastDirection: SIMD3<Double>?
  private(set) var firstTwoHop: SIMD3<Double>?
  private(set) var lastTwoHop: SIMD3<Double>?
  private(set) var start: SIMD3<Double>?
  private(set) var lastTranslation: SIMD3<Double>?
  private(set) var outcomes: [String: Int] = [:]
  /// Indirect-pinch events: every one counted, with how many carried the system's selection ray, per event phase; the
  /// first event's sample (as in a plain click), and the first sample that carried a ray, all in the object's frame.
  private(set) var pinches = 0
  private(set) var rays = 0
  private(set) var pinchPhases: [String: Int] = [:]
  private(set) var rayPhases: [String: Int] = [:]
  private(set) var pinchEntity = "none"
  private(set) var pinchLocation: SIMD3<Double>?
  struct RaySample { var phase: String, location: SIMD3<Double>, origin: SIMD3<Double>, direction: SIMD3<Double> }
  private(set) var firstRay: RaySample?
  init(enabled: Bool) { self.enabled = enabled }
  struct DragSample {
    var direction: SIMD3<Double>, twoHop: SIMD3<Double>, start: SIMD3<Double>, translation: SIMD3<Double>
  }
  func recordDrag(entity: String, sample: DragSample, outcome: OriginDragOutcome) {
    guard enabled else { return }
    dragChanges += 1
    lastDragEntity = entity.isEmpty ? "unnamed" : entity
    if firstDirection == nil { (firstDirection, firstTwoHop, start) = (sample.direction, sample.twoHop, sample.start) }
    (lastDirection, lastTwoHop, lastTranslation) = (sample.direction, sample.twoHop, sample.translation)
    lastOutcome = outcome.rawValue
    outcomes[outcome.rawValue, default: 0] += 1
  }
  func recordPinch(
    entity: String, phase: String, location: SIMD3<Double>, ray: (origin: SIMD3<Double>, direction: SIMD3<Double>)?
  ) {
    guard enabled else { return }
    pinches += 1
    pinchPhases[phase, default: 0] += 1
    if pinchLocation == nil { (pinchEntity, pinchLocation) = (entity.isEmpty ? "unnamed" : entity, location) }
    guard let ray else { return }
    rays += 1
    rayPhases[phase, default: 0] += 1
    if firstRay == nil { firstRay = RaySample(phase: phase, location: location, origin: ray.origin, direction: ray.direction) }
  }
  func recordDragEnd() { if enabled { dragEnds += 1 } }
  func recordDragReset() { if enabled { dragResets += 1 } }
  func recordActivate(entity: String) {
    guard enabled else { return }
    activations += 1
    lastActivateEntity = entity.isEmpty ? "unnamed" : entity
  }
  func recordSky(_ state: String) { if enabled && sky != state { sky = state } }
  func recordTap(entity: String) {
    guard enabled else { return }
    taps += 1
    lastTapEntity = entity.isEmpty ? "unnamed" : entity
  }
  var summary: String {
    func f(_ v: SIMD3<Double>?) -> String { v.map { String(format: "(%.3f, %.3f, %.3f)", $0.x, $0.y, $0.z) } ?? "none" }
    let tally = Self.tally(outcomes)
    return "input: drag changes \(dragChanges) · ends \(dragEnds) · resets \(dragResets) · last drag entity \(lastDragEntity)"
      + " · outcome \(lastOutcome) · taps \(taps) · last tap entity \(lastTapEntity)"
      + " · activations \(activations) · last activate entity \(lastActivateEntity) · sky \(sky)"
      + " · direction first \(f(firstDirection)) last \(f(lastDirection)) · two-hop first \(f(firstTwoHop)) last \(f(lastTwoHop))"
      + " · start \(f(start)) · translation last \(f(lastTranslation)) · outcomes [\(tally)]"
      + " · pinch events \(pinches) [\(Self.tally(pinchPhases))] first entity \(pinchEntity) location \(f(pinchLocation))"
      + " · rays \(rays) [\(Self.tally(rayPhases))] first ray " + (firstRay.map {
        "at \($0.phase) location \(f($0.location)) origin \(f($0.origin)) direction \(f($0.direction))"
      } ?? "none")
  }
  private static func tally(_ counts: [String: Int]) -> String {
    counts.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
  }
}
