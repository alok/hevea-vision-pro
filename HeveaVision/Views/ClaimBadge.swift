import HeveaCore
import SwiftUI

struct ClaimBadge: View {
  let claim: ClaimClass

  private var tint: Color {
    switch claim {
    case .upstreamBaseline: .cyan
    case .realTimeProxy: .orange
    case .heveaVisionExperiment: .purple
    }
  }

  var body: some View {
    Text(claim.rawValue)
      .font(.caption.weight(.heavy))
      .tracking(1.15)
      .foregroundStyle(tint)
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(tint.opacity(0.15), in: Capsule())
      .overlay {
        Capsule()
          .strokeBorder(tint.opacity(0.38), lineWidth: 1)
      }
      .accessibilityLabel("Claim class: \(claim.rawValue)")
  }
}
