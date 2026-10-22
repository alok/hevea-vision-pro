// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

#if canImport(FareyCore)
  import FareyCore
#endif

struct FractionEntryView: View {
  @Environment(GalleryModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @FocusState private var editing: Bool
  @State private var draft = ""
  @State private var selection: FractionEntry?
  @State private var error: String?
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("Choose a fraction").font(.title2)
        Spacer()
        Button("Close") { dismiss() }.accessibilityIdentifier("close-fraction-entry")
      }
      Text("Selected: \(model.state.mediant) · \(model.state.wordLabel)")
        .font(.headline.monospaced()).accessibilityIdentifier("entry-selected-state")
      HStack {
        TextField("3/5", text: $draft)
          .font(.title3.monospaced()).textFieldStyle(.roundedBorder)
          .textInputAutocapitalization(.never).autocorrectionDisabled()
          .keyboardType(.numbersAndPunctuation).focused($editing)
          .onSubmit(select).accessibilityLabel("Positive fraction p/q")
          .accessibilityIdentifier("fraction-input")
        Button("Clear") { draft = ""; editing = true }
          .accessibilityIdentifier("clear-fraction")
        Button("Select", action: select).buttonStyle(.borderedProminent)
          .accessibilityIdentifier("select-fraction")
      }
      if let error {
        Text(error).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("fraction-error")
      } else if let selection, selection.state == model.state {
        Text(selection.explanation).fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("fraction-result")
      }
      Text("Positive numerator and denominator: 1…1000. Maximum path: 24 moves.")
        .font(.callout).foregroundStyle(.secondary)
      Text("Selection reconstructs its L/R path. Undo removes the final move; lattice and disk keep the same fraction.")
        .font(.caption).foregroundStyle(.secondary)
    }
    .padding(24).frame(width: 580)
    .onAppear { draft = model.state.mediant.description; selection = nil; error = nil }
    .onChange(of: draft) { error = nil; selection = nil }
  }
  private func select() {
    do {
      selection = try model.enterFraction(draft)
      error = nil
      editing = false
    } catch {
      self.error = error.localizedDescription
    }
  }
}
