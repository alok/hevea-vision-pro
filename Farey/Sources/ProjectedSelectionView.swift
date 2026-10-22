// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

extension GalleryModel {
  func chooseProjectedDirection() {
    guard let stage = constructionStage, stage.rawValue < 2 else { return }
    let target = LatticePoint(p: state.mediant.p, q: state.mediant.q)
    projectedSelection = ProjectedSelection(near: target, bound: depth * 2)
      ?? ProjectedSelection(near: LatticePoint(p: 1, q: 1), bound: depth * 2)
  }
  func activatePoint(_ point: LatticePoint) {
    if let stage = constructionStage, stage.rawValue < 2 {
      projectedSelection = ProjectedSelection(near: point, bound: depth * 2)
    } else { select(point) }
  }
  func confirmProjectedSelection() {
    guard let point = projectedSelection?.point else { return }
    select(point)
  }
}

struct ProjectedSelectionView: View {
  @Environment(GalleryModel.self) private var model
  var body: some View {
    if let choice = model.projectedSelection {
      VStack(alignment: .leading, spacing: 16) {
        Text("Choose a projected direction").font(.title2)
        Text("Dots overlap here. Preview a fraction, then select it. Previous and Next follow exact fraction order.")
          .fixedSize(horizontal: false, vertical: true)
        Text("Preview: \(choice.point.rational)").font(.title.monospaced())
          .accessibilityIdentifier("projected-preview")
        Text("Primitive point (q, p) = (\(choice.point.q), \(choice.point.p)) · \(choice.index + 1) of \(choice.points.count)")
          .font(.callout.monospaced()).accessibilityIdentifier("projected-point")
        Text("Current target: \(model.state.mediant). The inspected point and lesson stay unchanged until Select.")
          .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        HStack {
          Button("Previous fraction") { model.projectedSelection?.move(-1) }
            .disabled(!choice.canGoBack).accessibilityIdentifier("projected-previous")
          Button("Next fraction") { model.projectedSelection?.move(1) }
            .disabled(!choice.canGoForward).accessibilityIdentifier("projected-next")
        }
        HStack {
          Button("Select \(choice.point.rational)") { model.confirmProjectedSelection() }
            .buttonStyle(.borderedProminent).accessibilityIdentifier("projected-confirm")
          Button("Cancel") { model.projectedSelection = nil }.accessibilityIdentifier("projected-cancel")
        }
      }.padding(24).frame(width: 540)
    }
  }
}
