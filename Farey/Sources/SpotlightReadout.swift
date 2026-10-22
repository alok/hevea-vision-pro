// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

extension GalleryModel {
  var spotlightStatus: String {
    guard let point = spotlight.rational else {
      return "Choose a row to spotlight an approximant without changing the target."
    }
    let kind = state.cfPoints(alternate: alternateCF).first { $0.rational == point }?.label ?? "Approximant"
    var message = "Spotlight \(point): \(kind.lowercased()). Target \(state.mediant) unchanged."
    if latticeMode && (point.p > depth * 2 || point.q > depth * 2) {
      message += " Outside grid \(depth * 2); use Disk to see its boundary point."
    }
    return message
  }
}

struct SpotlightReadout: View {
  @Environment(GalleryModel.self) private var model
  var body: some View {
    HStack {
      Text(model.spotlightStatus).font(.caption).foregroundStyle(.white)
        .accessibilityIdentifier("spotlight-status")
      if model.spotlight.rational != nil {
        Button("Clear") { model.clearSpotlight() }.font(.caption)
          .accessibilityIdentifier("clear-spotlight")
      }
    }
  }
}
