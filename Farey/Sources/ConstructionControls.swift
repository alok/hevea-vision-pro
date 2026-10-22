// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

extension GalleryModel {
  func startConstruction() {
    constructionStage = .boundary
    animateConstruction = false
    constructionMoving = false
    revision += 1
  }
  func endConstruction() {
    constructionStage = nil
    constructionMoving = false
    animateConstruction = false
    revision += 1
  }
  func moveConstruction(_ delta: Int, reduceMotion: Bool) {
    guard let current = constructionStage else { return }
    let next = min(3, max(0, current.rawValue + delta))
    constructionStage = ConstructionStage(rawValue: next)
    constructionMoving = delta > 0 && next == 2 && current == .direction
      && animateConstruction && !reduceMotion
    revision += 1
  }
  func stopConstruction() {
    projectedSelection = nil
    constructionMoving = false
    revision += 1
  }
  var constructionExplanation: String {
    guard let stage = constructionStage else { return "" }
    let target = state.mediant
    let descriptions = [
      "q = 1: the ray meets (1, \(target)). Multiples share this boundary value; ∞ has no finite intersection.",
      "The ray from (0,0) through (1, \(target)) has slope \(target). Its positive integer points share this direction.",
      "Integer points at (q,p). Moving positions may be noninteger; this is not a hyperbolic map.",
      "The upright plane contains this ray. Height is a display choice, not another rational coordinate.",
    ]
    var outside = Double(target.p) / Double(target.q) > Double(depth * 2)
      ? " Boundary value outside the visible q=1 segment." : ""
    if stage.rawValue >= 2, let point = state.inspection?.point,
      point.p > depth * 2 || point.q > depth * 2 {
      outside += " Inspected point outside grid \(depth * 2); coordinates unchanged."
    }
    return "\(stage.rawValue + 1)/4 · \(stage.title). \(descriptions[stage.rawValue])\(outside)"
  }
}

struct ConstructionControls: View {
  @Environment(GalleryModel.self) private var model
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    HStack(spacing: 10) {
      if (model.constructionStage?.rawValue ?? 3) < 2 {
        Button("Pick p/q") { model.chooseProjectedDirection() }
          .accessibilityIdentifier("projected-open")
      }
      Button("Back") { model.moveConstruction(-1, reduceMotion: reduceMotion) }
        .disabled(model.constructionStage == .boundary).accessibilityIdentifier("construction-back")
      Button("Next") { model.moveConstruction(1, reduceMotion: reduceMotion) }
        .disabled(model.constructionStage == .plane).accessibilityIdentifier("construction-next")
      Toggle(reduceMotion ? "Reduce Motion" : "Animate reveal", isOn: Binding(
        get: { model.animateConstruction }, set: { model.animateConstruction = $0 }))
        .toggleStyle(.button).disabled(reduceMotion).accessibilityIdentifier("construction-motion")
      Button("Stop") { model.stopConstruction() }.disabled(!model.constructionMoving)
        .accessibilityHint("Stop motion and settle at the current step")
        .accessibilityIdentifier("construction-stop")
      Button("Restart") { model.startConstruction() }.accessibilityIdentifier("construction-reset")
      Button("Done") { model.endConstruction() }.accessibilityIdentifier("construction-close")
    }.font(.caption).buttonStyle(.bordered)
      .onChange(of: reduceMotion) { if reduceMotion { model.stopConstruction() } }
  }
}
