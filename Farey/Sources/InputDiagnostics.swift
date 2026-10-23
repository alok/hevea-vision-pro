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
  private(set) var lastDragEntity = "none"
  private(set) var lastTapEntity = "none"
  private(set) var lastOutcome = "none"
  private(set) var lastDirection: SIMD3<Double>?
  init(enabled: Bool) { self.enabled = enabled }
  func recordDrag(entity: String, direction: SIMD3<Double>, outcome: OriginDragOutcome) {
    guard enabled else { return }
    dragChanges += 1
    lastDragEntity = entity.isEmpty ? "unnamed" : entity
    lastDirection = direction
    lastOutcome = outcome.rawValue
  }
  func recordDragEnd() { if enabled { dragEnds += 1 } }
  func recordDragReset() { if enabled { dragResets += 1 } }
  func recordTap(entity: String) {
    guard enabled else { return }
    taps += 1
    lastTapEntity = entity.isEmpty ? "unnamed" : entity
  }
  var summary: String {
    let d = lastDirection.map { String(format: "(%.3f, %.3f, %.3f)", $0.x, $0.y, $0.z) } ?? "none"
    return "input: drag changes \(dragChanges) · ends \(dragEnds) · resets \(dragResets) · last drag entity \(lastDragEntity)"
      + " · direction \(d) · outcome \(lastOutcome) · taps \(taps) · last tap entity \(lastTapEntity)"
  }
}
