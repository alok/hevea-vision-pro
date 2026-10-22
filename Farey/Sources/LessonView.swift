// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

#if canImport(FareyCore)
  import FareyCore
#endif

struct LessonProgress: Equatable {
  var index = 0
  var prediction: Rational?
  var explanation: String?
  var turn: Turn { index == 0 ? .l : .r }
  var choices: [Rational] {
    index == 0
      ? [Rational(1, 3), Rational(2, 3), Rational(3, 2)]
      : [Rational(3, 4), Rational(3, 5), Rational(2, 5)]
  }
}

struct LessonView: View {
  @Environment(GalleryModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("One Farey move").font(.title2)
        Spacer()
        Button("Close") {
          model.endLesson()
          dismiss()
        }.accessibilityIdentifier("close-lesson")
      }
      HStack {
        Text("Selected: \(model.state.mediant.description) · \(model.state.wordLabel)")
          .font(.headline.monospaced()).accessibilityIdentifier("lesson-fraction")
        Spacer()
        Button(model.latticeMode ? "Show disk" : "Show lattice") { model.toggleSpace() }
          .accessibilityIdentifier("lesson-space")
      }
      if let progress = model.lesson {
        if let explanation = progress.explanation {
          Text(explanation).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("lesson-explanation")
          HStack {
            if progress.index == 0 {
              Button("Predict R next") { model.nextLessonStep() }
                .accessibilityIdentifier("lesson-next")
            }
            Button("Restart lesson") { model.startLesson() }
              .accessibilityIdentifier("lesson-restart")
          }.buttonStyle(.borderedProminent)
        } else {
          Text("After \(progress.turn.rawValue), which rational will be selected?")
          HStack {
            ForEach(progress.choices, id: \.self) { choice in
              Button(choice.description) { model.predictLesson(choice) }
                .tint(progress.prediction == choice ? .cyan : .gray)
                .accessibilityIdentifier("lesson-choice-\(choice.p)-\(choice.q)")
            }
            Spacer()
            Button("Apply \(progress.turn.rawValue)") { model.applyLessonStep() }
              .disabled(progress.prediction == nil)
              .accessibilityIdentifier("lesson-apply")
          }.buttonStyle(.borderedProminent)
          Text(
            "\(progress.turn.rawValue) replaces the \(progress.turn == .l ? "lower" : "upper") endpoint with the current mediant."
          )
          .font(.callout).foregroundStyle(.secondary)
        }
      } else {
        Text("The selection changed. Restart to predict the next move from 1/2.")
        Button("Restart lesson") { model.startLesson() }
          .accessibilityIdentifier("lesson-restart")
      }
      HStack {
        Link("Katherine Stange’s L/R demonstration ↗", destination: SourcesView.latticeURL)
        Spacer()
        Link("Caroline Series ↗", destination: SourcesView.seriesURL)
      }.font(.caption)
    }
    .padding(24).frame(width: 660)
    .onDisappear { model.endLesson() }
  }
}
