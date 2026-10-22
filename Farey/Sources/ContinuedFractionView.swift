// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

struct ContinuedFractionView: View {
  @Environment(GalleryModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text("Convergents & mediants").font(.title2)
        Spacer()
        Button("Close") { dismiss() }.accessibilityIdentifier("close-cf")
      }
      if let fraction = ContinuedFraction(model.state.mediant) {
        Text("\(model.state.mediant) = \(fraction.label(alternate: model.alternateCF))")
          .font(.title3.monospaced()).accessibilityIdentifier("cf-expansion")
        Toggle("Use equivalent finite form ending in 1", isOn: Binding(
          get: { model.alternateCF }, set: { model.setAlternateCF($0) }))
          .accessibilityIdentifier("cf-alternate")
        Text("Convergents are the truncations of the chosen expansion. "
          + "Canonical form ends in at least 2, except for an integer. The other finite form replaces the last term a with a−1, 1.")
          .font(.callout)
        let points = model.state.cfPoints(alternate: model.alternateCF)
        ScrollView {
          VStack(spacing: 7) {
            ForEach(points, id: \.rational) { point in
              Button {
                model.spotlightPoint(point.rational)
                dismiss()
              } label: {
                HStack {
                  Text(point.rational.description).monospaced()
                  if point.rational.p == 0 { Text("boundary").foregroundStyle(.secondary) }
                  Spacer()
                  Text(point.label).foregroundStyle(point.isConvergent ? Color.yellow : Color.secondary)
                  if point.rational == model.spotlight.rational { Image(systemName: "scope") }
                }.contentShape(Rectangle())
              }.buttonStyle(.plain)
                .accessibilityLabel("\(point.rational): \(point.label)")
                .accessibilityHint("Spotlight this approximant without changing the target")
                .accessibilityIdentifier("cf-kind-\(point.rational.p)-\(point.rational.q)")
            }
          }
        }.frame(height: min(CGFloat(points.count) * 30, 210)).accessibilityIdentifier("cf-list")
        SpotlightReadout()
        Text("Tap a row to spotlight it and return to the scene. Reopen this panel to compare another row.")
          .font(.caption).foregroundStyle(.secondary)
        if let point = model.state.inspection?.point {
          Text("Inspected lattice point stays (\(point.q), \(point.p)). Double white rings mark the spotlight.")
            .font(.caption).foregroundStyle(.secondary)
        }
        Text("Gold rings: convergents. Gray rings: other mediants visited by this L/R path. "
          + "Rings mark primitive lattice points and the matching disk boundary points.")
          .font(.caption).foregroundStyle(.secondary)
        Text("The choice changes which intermediate is a convergent, not the rational or its L/R path. "
          + "Here M(1) = \(model.state.mediant); appending R gives the endpoint word for M(∞). "
          + "At a rational endpoint the final triangle label is a convention; we use Stange's ending-in-R form.")
          .font(.caption).accessibilityIdentifier("cf-convention")
      }
      HStack {
        Link("Convergent definition ↗", destination: SourcesView.cfURL)
        Link("Katherine Stange’s demonstration ↗", destination: SourcesView.latticeURL)
      }.font(.caption)
    }
    .padding(24).frame(width: 620)
  }
}
