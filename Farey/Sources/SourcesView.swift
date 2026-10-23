// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

struct SourcesView: View {
  static let cfURL = URL(string: "https://dlmf.nist.gov/1.12.ii")!
  static let talkURL = URL(string: "https://katestange.net/talks/math-exploration/")!
  static let catalogURL = URL(string: "https://www.katestange.net/code/")!
  static let seriesURL = URL(string: "https://doi.org/10.1112/jlms/s2-31.1.69")!
  static let starscapesURL = URL(string: "https://arxiv.org/abs/2008.07655")!
  static let latticeURL = URL(
    string: "https://katestange.net/talks/math-exploration/viewers/farey-cf-lattice.html")!
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
      Link(
        "Original 3D Starscape / Lattice ↗",
        destination: URL(string: "https://www.katestange.net/starscape-lattice/")!)
      Text(
        "The coefficient view shows every nonzero integer triple (a,b,c) in the ball b²+2a²+2c² ≤ R², "
          + "the same signed lattice and double cone as our browser version, drawn at (−b, a+c, c−a). "
          + "Radial projection onto a+c=4 gives the Klein disk; a lower form uses its sign flip, which has the same roots. "
          + "Boundary and exterior forms have real roots, and the zero polynomial has no projective point. "
          + "This is distinct from the planar Farey L/R lattice."
      )
      Text("Edmund Harriss, Katherine E. Stange and Steve Trettel").font(.title3.weight(.medium))
      Link("Algebraic Number Starscapes ↗", destination: Self.starscapesURL)
        .accessibilityIdentifier("starscapes-paper")
      Text(
        "Their paper is the research source for this coefficient-space and root-space construction. "
          + "This app illustrates it; it does not verify the paper's results."
      )
      .font(.callout)
      Text(
        "Upper-interior color is |Δ| on Stange's fixed logarithmic range 3–240, mapped onto Viridis from 0.2 to 1. "
          + "Exterior, boundary and lower swatches, and coloring the lower half, are our choices. "
          + "Viridis by Nathaniel J. Smith, Stefan van der Walt and Eric Firing (CC0)."
      )
      .font(.callout)
      Text(
        "Native draws one entity per point, so its radius is capped at 12 (3,608 points); the browser's dense crops "
          + "are not reproduced here. Points are small unlit spheres of fixed physical size (0.72 for nonprimitive "
          + "upper-interior forms, and for nonprimitive lower-interior forms only when Color lower is on) rather than "
          + "the browser's screen-pixel point sprites, so sizes follow ordinary perspective. "
          + "The ball keeps a 0.96 m radius at every crop, centered 3.1 m ahead. Its oblique and side views are "
          + "stationary orientations, not tracked or hyperbolic navigation."
      )
      .font(.callout)
      Divider()
      Text("Caroline Series").font(.title2.weight(.medium))
      Link("The modular surface and continued fractions (1985) ↗", destination: Self.seriesURL)
      Text(
        "Exact integer L/R matrices and mediants link the lattice and the finite Farey tessellation. "
          + "In the ordinary lattice, (q, p) represents p/q. Its direction plane contains its integer multiples. "
          + "Orange edges show vector addition. Sphere radii, colors, plane height and the scene's tilt are presentation choices."
      )
      Text(
        "Construction projects directions onto q = 1. Its optional dot motion is an illustration, "
          + "not a hyperbolic map; Stange's original stages move the camera around fixed lattice points."
      )
      .font(.callout)
      Text(
        "Independent native implementation by Alok Singh. "
          + "No source code or media from Stange’s demo is bundled. This is not an official port or endorsement."
      )
      .font(.callout).foregroundStyle(.secondary).accessibilityIdentifier("source-boundary")
    }
  }
}
