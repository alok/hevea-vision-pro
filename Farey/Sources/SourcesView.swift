// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

struct SourcesView: View {
  static let cfURL = URL(string: "https://dlmf.nist.gov/1.12.ii")!
  static let talkURL = URL(string: "https://katestange.net/talks/math-exploration/")!
  static let catalogURL = URL(string: "https://www.katestange.net/code/")!
  static let seriesURL = URL(string: "https://doi.org/10.1112/jlms/s2-31.1.69")!
  static let latticeURL = URL(string: "https://katestange.net/talks/math-exploration/viewers/farey-cf-lattice.html")!
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      ScrollView { sourceNotes.fixedSize(horizontal: false, vertical: true) }
        .frame(height: 540).accessibilityIdentifier("sources-content")
      Button("Return to the geometry") { dismiss() }
        .buttonStyle(.borderedProminent).accessibilityIdentifier("close-sources")
    }
    .padding(32).frame(width: 640)
  }

  private var sourceNotes: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Katherine Stange").font(.largeTitle.weight(.semibold)).foregroundStyle(.cyan)
        .accessibilityIdentifier("stange-credit")
      Text("Inspired by her Farey visualizations and Illustrating Mathematics for Math 2.0 talk.")
        .font(.title3)
        .fixedSize(horizontal: false, vertical: true)
      HStack(spacing: 24) {
        Link("Original talk ↗", destination: Self.talkURL)
        Link("Visualization catalog ↗", destination: Self.catalogURL)
      }.font(.headline)
      Link("Original L/R and lattice demonstration ↗", destination: Self.latticeURL)
      Divider()
      Text("Caroline Series").font(.title2.weight(.medium))
      Link("The modular surface and continued fractions (1985) ↗", destination: Self.seriesURL)
      Text(
        "Exact integer L/R matrices and mediants link the lattice and the finite Farey tessellation. "
          + "In the ordinary lattice, (q, p) represents p/q. Its direction plane contains its integer multiples. "
          + "Orange edges show vector addition. Sphere radii, colors, plane height and the scene's tilt are presentation choices."
      )
      Text("Construction projects directions onto q = 1. Its optional dot motion is an illustration, "
        + "not a hyperbolic map; Stange's original stages move the camera around fixed lattice points.")
        .font(.callout)
      Text(
        "Independent native implementation by Alok Singh. "
          + "No source code or media from Stange’s demo is bundled. This is not an official port or endorsement."
      )
      .font(.callout).foregroundStyle(.secondary).accessibilityIdentifier("source-boundary")
    }
  }
}
