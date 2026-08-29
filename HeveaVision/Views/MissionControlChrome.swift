import SwiftUI

struct MissionControlBackground: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.025, green: 0.045, blue: 0.09),
          model.selectedExhibit == .reducedSphere
            ? Color(red: 0.105, green: 0.057, blue: 0.018)
            : Color(red: 0.055, green: 0.025, blue: 0.10),
          model.selectedExhibit == .reducedSphere
            ? Color(red: 0.045, green: 0.080, blue: 0.085)
            : Color(red: 0.015, green: 0.085, blue: 0.12),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      Circle()
        .fill(.cyan.opacity(0.10))
        .frame(width: 520, height: 520)
        .blur(radius: 90)
        .offset(x: -360, y: 250)

      Circle()
        .fill(
          model.selectedExhibit == .reducedSphere
            ? Color.orange.opacity(0.14)
            : Color.purple.opacity(0.13)
        )
        .frame(width: 440, height: 440)
        .blur(radius: 110)
        .offset(x: 420, y: -280)
    }
    .ignoresSafeArea()
  }
}

struct MissionControlHeader: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    HStack(alignment: .center, spacing: 18) {
      exhibitIcon

      VStack(alignment: .leading, spacing: 4) {
        Text("HEVEA VISION")
          .font(.system(.title, design: .rounded, weight: .bold))
          .tracking(1.7)
        Text("A spatial observatory for convex integration")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Spacer()
      exhibitSwitcher
      ClaimBadge(claim: model.currentClaim)
    }
  }

  private var exhibitIcon: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(.white.opacity(0.08))
      Image(systemName: model.selectedExhibit.systemImage)
        .font(.system(size: 32, weight: .medium))
        .foregroundStyle(model.selectedExhibit == .reducedSphere ? .yellow : .cyan)
    }
    .frame(width: 62, height: 62)
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(.white.opacity(0.12))
    }
  }

  private var exhibitSwitcher: some View {
    HStack(spacing: 5) {
      ForEach(HeveaExhibit.allCases) { exhibit in
        Button {
          model.selectExhibit(exhibit)
        } label: {
          Label(exhibit.shortLabel, systemImage: exhibit.systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 11)
            .frame(height: 36)
            .background(
              exhibit == model.selectedExhibit ? Color.white.opacity(0.18) : Color.clear,
              in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(
          "exhibit-\(exhibit == .reducedSphere ? "sphere" : "torus")"
        )
      }
    }
    .padding(4)
    .background(.black.opacity(0.18), in: Capsule())
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("exhibit-switcher")
  }
}
