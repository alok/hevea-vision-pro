// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

#if canImport(FareyCore)
  import FareyCore
#endif

struct ControlsWindowView: View {
  @Environment(GalleryModel.self) private var model
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

  var body: some View {
    ControlsView()
      .onChange(of: model.immersionOpen) {
        if !model.immersionOpen { dismiss() }
      }
      .onDisappear {
        if model.immersionOpen {
          Task { await dismissImmersiveSpace() }
        }
      }
  }
}

struct ControlsView: View {
  @Environment(GalleryModel.self) private var model
  @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
  @State private var showSources = false
  @State private var showLesson = false
  @State private var showFractionEntry = false
  @State private var showPointInspection = false
  @State private var showContinuedFraction = false
  var body: some View {
    if model.starscapeMode { StarscapeControls() } else { fareyControls }
  }
  private var fareyControls: some View {
    VStack(spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        Text(model.state.wordLabel).font(.system(.headline, design: .monospaced))
          .lineLimit(1).minimumScaleFactor(0.5).accessibilityIdentifier("word-state")
        Spacer()
        Text(
          "\(model.state.left.description)  <  \(model.state.mediant.description)  <  \(model.state.right.description)"
        )
        .font(.system(.title3, design: .monospaced)).foregroundStyle(.orange)
        .lineLimit(1).minimumScaleFactor(0.5).layoutPriority(1)
        .accessibilityIdentifier("fraction-state")
      }
      .fixedSize(horizontal: false, vertical: true)
      HStack(spacing: 12) {
        Button("L") { model.step(.l) }.disabled(!model.state.canStep).tint(.cyan)
          .accessibilityIdentifier("step-L")
          .accessibilityHint("Replace the lower endpoint with the mediant")
        Button("R") { model.step(.r) }.disabled(!model.state.canStep).tint(.purple)
          .accessibilityIdentifier("step-R")
          .accessibilityHint("Replace the upper endpoint with the mediant")
        Button {
          model.undo()
        } label: {
          Image(systemName: "arrow.uturn.backward")
        }
        .disabled(model.state.word.isEmpty).accessibilityLabel("Undo").accessibilityIdentifier(
          "undo")
        Button("Reset") { model.reset() }.accessibilityIdentifier("reset")
        Spacer()
        Button("Exit") {
          guard !model.transitioning else { return }
          model.transitioning = true
          Task { @MainActor in
            model.record("Close requested session \(model.immersionSession)")
            await Task.yield()
            await dismissImmersiveSpace()
            model.record("Close completed session \(model.immersionSession)")
            model.transitioning = false
          }
        }.disabled(model.transitioning).accessibilityIdentifier("exit-void")
      }
      .buttonStyle(.borderedProminent).controlSize(.large)
      HStack(spacing: 10) {
        Button("3D starscape") {
          model.starscapeMode = true
          model.revision += 1
        }
        .accessibilityIdentifier("show-starscape")
        Button(
          model.constructionStage != nil
            ? (model.latticeMode ? "Back to Lattice" : "Back to Disk")
            : (model.latticeMode ? "Space: Lattice" : "Space: Disk")
        ) {
          if model.constructionStage != nil { model.endConstruction() } else { model.toggleSpace() }
        }
        .accessibilityIdentifier("space-toggle")
        Text(
          model.latticeMode || model.constructionStage != nil
            ? "Grid \(model.depth * 2)" : "Detail \(model.depth)"
        ).font(.caption)
        Button {
          model.changeDepth(-1)
        } label: {
          Image(systemName: "minus")
        }
        .disabled(model.depth <= 3).accessibilityIdentifier("detail-less")
        Button {
          model.changeDepth(1)
        } label: {
          Image(systemName: "plus")
        }
        .disabled(model.depth >= 7).accessibilityIdentifier("detail-more")
        Button(["Front", "Left", "Right"][model.viewpoint]) { model.changeView() }
          .accessibilityIdentifier("viewpoint")
        Button("3/5 example") { model.preset() }.accessibilityIdentifier("example")
        Button("p/q") { showFractionEntry = true }
          .accessibilityLabel("Choose a fraction")
          .accessibilityIdentifier("choose-fraction")
          .popover(isPresented: $showFractionEntry, arrowEdge: .bottom) { FractionEntryView() }
        Button("Learn") {
          model.startLesson()
          showLesson = true
        }.accessibilityIdentifier("learn")
          .popover(isPresented: $showLesson, arrowEdge: .bottom) { LessonView() }
        Button("Sources") { showSources = true }.accessibilityIdentifier("sources")
      }.buttonStyle(.bordered).controlSize(.small)
      Text(
        model.constructionStage != nil
          ? model.constructionExplanation
          : model.latticeMode
            ? (model.state.mediant.p > model.depth * 2 || model.state.mediant.q > model.depth * 2
              ? "Direction plane shown. The primitive point lies beyond this finite grid."
              : "Tap a point for p/q. Green plane: multiples of (q, p). Orange: the mediant.")
            : "Green: ∞ to p/q. Orange: the L/R path. Both views share the same exact interval."
      )
      .font(.caption).foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityIdentifier("geometry-explanation")
      if let notice = model.precisionNotice {
        Text(notice).font(.caption).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
          .accessibilityIdentifier("precision-notice")
      }
      if let inspection = model.state.inspection {
        if model.constructionStage != nil {
          ConstructionControls()
        } else {
          HStack {
            Button("Point (q, p): \(inspection.equation) · Inspect") { showPointInspection = true }
              .font(.caption.monospaced()).foregroundStyle(.cyan).buttonStyle(.plain)
              .lineLimit(1).minimumScaleFactor(0.7).accessibilityIdentifier("inspect-point")
              .popover(isPresented: $showPointInspection, arrowEdge: .bottom) {
                PointInspectionView()
              }
            Spacer()
            Button("Convergents / mediants") { showContinuedFraction = true }
              .font(.caption).foregroundStyle(.yellow).buttonStyle(.plain)
              .accessibilityIdentifier("show-cf")
              .popover(isPresented: $showContinuedFraction, arrowEdge: .bottom) {
                ContinuedFractionView()
              }
            Button("Construct") { model.startConstruction() }
              .font(.caption).accessibilityIdentifier("construction-start")
          }
        }
      }
      if model.spotlight.rational != nil { SpotlightReadout() }
      Text(
        "M = \(model.state.matrixLabel)    det M = \(model.state.determinant)    •    \(model.state.word.count)/24 moves"
      )
      .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
      .accessibilityIdentifier("matrix-state")
      Text(model.renderReceipt.components(separatedBy: " · ").first ?? model.renderReceipt)
        .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("render-receipt")
      if !model.state.canStep {
        Text("24-move limit reached. Undo or reset to continue.").font(.caption).foregroundStyle(
          .orange)
      }
    }
    .padding(20).frame(width: 760)
    .glassBackgroundEffect()
    .accessibilityElement(children: .contain)
    .sheet(isPresented: $showSources) { SourcesView() }
    .popover(
      isPresented: Binding(
        get: { model.projectedSelection != nil },
        set: { if !$0 { model.projectedSelection = nil } }
      )
    ) { ProjectedSelectionView() }

  }
}
