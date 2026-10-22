// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

struct PointInspectionView: View {
  @Environment(GalleryModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("One direction, different points").font(.title2)
        Spacer()
        Button("Close") { dismiss() }.accessibilityIdentifier("close-point-inspection")
      }
      if let inspection = model.state.inspection {
        Text(inspection.equation).font(.title2.monospaced()).foregroundStyle(.cyan)
          .accessibilityIdentifier("point-equation")
        Text("\(inspection.gcdDescription). Divide both coordinates by this number.")
          .accessibilityIdentifier("point-gcd")
        Text("Primitive vector (q, p) = (\(inspection.primitive.q), \(inspection.primitive.p)). "
          + "Reduced fraction: \(inspection.reduction). L/R path: \(model.state.wordLabel).")
          .accessibilityIdentifier("point-reduction")
        Text("These positive multiples share a ray from the origin. "
          + "The green upright plane contains that ray; only a finite patch is drawn.")
        Text("In the disk, they determine the same boundary point p/q and the same green geodesic from ∞. "
          + "L/R follows the reduced fraction, not the distance of the lattice point from the origin.")
        if inspection.point.p > model.depth * 2 || inspection.point.q > model.depth * 2 {
          Text("The inspected point lies beyond this finite grid. Its coordinates are preserved; it has not been moved to the edge.")
            .foregroundStyle(.orange).accessibilityIdentifier("point-outside-grid")
        }
      }
      Text("White marks the inspected point when it differs from the orange primitive point. "
        + "Axis points 0 and ∞ are boundaries; they do not replace the positive L/R selection.")
        .font(.caption).foregroundStyle(.secondary)
      Link("Katherine Stange’s lattice demonstration ↗", destination: SourcesView.latticeURL)
        .font(.caption)
    }
    .fixedSize(horizontal: false, vertical: true).padding(24).frame(width: 620)
  }
}
