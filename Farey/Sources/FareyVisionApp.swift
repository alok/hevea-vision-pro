import OSLog
// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

#if canImport(FareyCore)
  import FareyCore
#endif

@MainActor @Observable final class GalleryModel {
  var state = FareyState()
  var depth = 6
  var viewpoint = 0
  var latticeMode = true
  var immersionOpen = false
  var transitioning = false
  var immersionSession = 0
  func record(_ event: String) {
    Logger(subsystem: "com.alok.FareyVision", category: "Lifecycle").info(
      "\(event, privacy: .public)")
  }
  var error: String?
  var renderReceipt = "Preparing geometry"
  var revision = 0
  var lesson: LessonProgress?
  var alternateCF = false
  func setAlternateCF(_ value: Bool) {
    guard value != alternateCF else { return }
    alternateCF = value
    revision += 1
  }
  func step(_ turn: Turn) {
    if state.step(turn) {
      lesson = nil
      revision += 1
    }
  }
  func undo() {
    lesson = nil
    state.undo()
    revision += 1
  }
  func reset() {
    alternateCF = false
    lesson = nil
    state.reset()
    depth = 6
    viewpoint = 0
    latticeMode = true
    revision += 1
  }
  func select(_ point: LatticePoint) {
    if state.select(point.rational) {
      lesson = nil
      revision += 1
    }
  }
  @discardableResult func enterFraction(_ text: String) throws -> FractionEntry {
    let entry = try FractionEntry(text)
    state = entry.state
    lesson = nil
    revision += 1
    return entry
  }
  func toggleSpace() {
    latticeMode.toggle()
    revision += 1
  }
  func preset() {
    lesson = nil
    state.select(Rational(3, 5))
    revision += 1
  }
  func changeDepth(_ delta: Int) {
    depth = min(7, max(3, depth + delta))
    revision += 1
  }
  func changeView() {
    viewpoint = (viewpoint + 1) % 3
    revision += 1
  }
  func startLesson() {
    reset()
    state.select(Rational(1, 2))
    lesson = LessonProgress()
    revision += 1
  }
  func endLesson() { lesson = nil }
  func predictLesson(_ choice: Rational) {
    guard let progress = lesson, progress.explanation == nil, progress.choices.contains(choice)
    else { return }
    lesson?.prediction = choice
  }
  func applyLessonStep() {
    guard var progress = lesson, progress.explanation == nil, let prediction = progress.prediction
    else { return }
    let turn = progress.turn
    let old = turn == .l ? state.left : state.right
    let middle = state.mediant
    guard state.step(turn) else { return }
    let left = state.left
    let right = state.right
    let result = state.mediant
    let feedback =
      prediction == result
      ? "Your prediction matched." : "You predicted \(prediction); the result is \(result)."
    progress.explanation =
      "\(feedback) \(turn.rawValue) replaced \(old) with \(middle). "
      + "The new neighbors are \(left) and \(right). Their lattice vectors add: "
      + "(\(left.q), \(left.p)) + (\(right.q), \(right.p)) = (\(result.q), \(result.p)). "
      + "The mediant is \(result)."
    lesson = progress
    revision += 1
  }
  func nextLessonStep() {
    guard let progress = lesson, progress.index == 0, progress.explanation != nil else { return }
    lesson = LessonProgress(index: 1)
  }
}

@main struct FareyVisionApp: App {
  @State private var model = GalleryModel()
  var body: some Scene {
    Window("Farey universe", id: "launch") {
      LaunchView().environment(model)
    }
    .defaultSize(width: 920, height: 780)
    Window("Farey controls", id: "controls") {
      ControlsWindowView().environment(model)
    }
    .defaultSize(width: 760, height: 310)
    .defaultWindowPlacement { _, _ in WindowPlacement(.utilityPanel) }
    .windowStyle(.plain)
    .persistentSystemOverlays(.hidden)
    .defaultLaunchBehavior(.suppressed)
    .restorationBehavior(.disabled)
    ImmersiveSpace(id: "farey-void") {
      FareyImmersiveView().id(model.immersionSession).environment(model)
    }
    .immersionStyle(selection: .constant(.full), in: .full)
  }
}

struct LaunchView: View {
  @Environment(GalleryModel.self) private var model
  @Environment(\.openImmersiveSpace) private var openImmersiveSpace
  @Environment(\.pushWindow) private var pushWindow
  var body: some View {
    VStack(spacing: 20) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 7) {
          Text("INTO THE INFINITE").font(.caption.weight(.semibold)).tracking(4).foregroundStyle(
            .cyan)
          Text("The Farey universe").font(.system(size: 40, weight: .light, design: .serif))
          Text("Two moves. Every positive rational.").font(.title3).foregroundStyle(.secondary)
          Text("Inspired by Katherine Stange").font(.title3.weight(.semibold))
            .foregroundStyle(.cyan)
            .accessibilityIdentifier("entry-credit")
          HStack(spacing: 20) {
            Link("Original talk ↗", destination: SourcesView.talkURL)
            Link("Stange’s visualizations ↗", destination: SourcesView.catalogURL)
          }.font(.subheadline)
        }
        Spacer()
        Text("L  R").font(.system(size: 42, weight: .ultraLight, design: .monospaced))
          .foregroundStyle(.cyan)
      }
      DiskPreview().frame(height: 280)
      Text(
        "Step into the integer lattice behind the Farey tessellation.\n"
          + "Choose a rational, follow its direction plane, and build its mediants in a full-immersion void."
      )
      .multilineTextAlignment(.center).foregroundStyle(.secondary)
      Button(action: enter) {
        Label("Enter the void", systemImage: "viewfinder").font(.title3).padding(.horizontal, 35)
          .padding(.vertical, 8)
      }
      .buttonStyle(.borderedProminent).tint(.cyan)
      .disabled(model.transitioning || model.immersionOpen)
      .accessibilityIdentifier("enter-void")
      if let error = model.error {
        Text(error).foregroundStyle(.orange).accessibilityIdentifier("entry-error")
      }
      Link("Underlying L/R coding: Caroline Series (1985) ↗", destination: SourcesView.seriesURL)
        .font(.subheadline)
    }
    .padding(35)
    .background(Color(red: 0.015, green: 0.025, blue: 0.045))
    .task {
      #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--showcase"), model.immersionSession == 0 {
          model.preset()
          model.viewpoint = 1
          enter()
        }
      #endif
    }

  }
  private func enter() {
    guard !model.transitioning, !model.immersionOpen else { return }
    model.transitioning = true
    model.renderReceipt = "Preparing geometry"
    model.immersionSession += 1
    model.record("Open requested session \(model.immersionSession)")
    Task {
      switch await openImmersiveSpace(id: "farey-void") {
      case .opened:
        model.record("Open completed session \(model.immersionSession)")
        model.immersionOpen = true
        pushWindow(id: "controls")
      case .userCancelled: model.error = "Entry cancelled. Try again whenever you’re ready."
      case .error: model.error = "The immersive space could not open. Please try again."
      @unknown default: model.error = "The system could not enter the space."
      }
      model.transitioning = false
    }
  }
}

struct DiskPreview: View {
  let edges = Geometry.tessellation(depth: 5)
  var body: some View {
    Canvas { context, size in
      let scale = min(size.width, size.height) * 0.47
      func point(_ p: Point2) -> CGPoint {
        CGPoint(x: size.width / 2 + p.x * scale, y: size.height / 2 - p.y * scale)
      }
      let rect = CGRect(
        x: size.width / 2 - scale, y: size.height / 2 - scale, width: 2 * scale, height: 2 * scale)
      context.stroke(Path(ellipseIn: rect), with: .color(.cyan.opacity(0.8)), lineWidth: 1.2)
      for edge in edges {
        let points = edge.samples
        var path = Path()
        path.move(to: point(points[0]))
        for p in points.dropFirst() { path.addLine(to: point(p)) }
        context.stroke(
          path, with: .color(.cyan.opacity(0.85 - Double(edge.depth) * 0.11)),
          lineWidth: edge.depth < 2 ? 1.4 : 0.8)
      }
    }
    .accessibilityLabel("Preview of the finite Farey tessellation in the Poincaré disk")
  }
}

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
        Button(model.latticeMode ? "Space: Lattice" : "Space: Disk") { model.toggleSpace() }
          .accessibilityIdentifier("space-toggle")
        Text(model.latticeMode ? "Grid \(model.depth * 2)" : "Detail \(model.depth)").font(.caption)
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
        model.latticeMode
          ? (model.state.mediant.p > model.depth * 2 || model.state.mediant.q > model.depth * 2
            ? "Direction plane shown. The primitive point lies beyond this finite grid."
            : "Tap a point for p/q. Green plane: multiples of (q, p). Orange: the mediant.")
          : "Green: ∞ to p/q. Orange: the L/R path. Both views share the same exact interval."
      )
      .font(.caption).foregroundStyle(.secondary)
      .accessibilityIdentifier("geometry-explanation")
      if let inspection = model.state.inspection {
        HStack {
          Button("Point (q, p): \(inspection.equation) · Inspect") { showPointInspection = true }
            .font(.caption.monospaced()).foregroundStyle(.cyan).buttonStyle(.plain)
            .lineLimit(1).minimumScaleFactor(0.7).accessibilityIdentifier("inspect-point")
            .popover(isPresented: $showPointInspection, arrowEdge: .bottom) { PointInspectionView() }
          Spacer()
          Button("Convergents / mediants") { showContinuedFraction = true }
            .font(.caption).foregroundStyle(.yellow).buttonStyle(.plain)
            .accessibilityIdentifier("show-cf")
            .popover(isPresented: $showContinuedFraction, arrowEdge: .bottom) { ContinuedFractionView() }
        }
      }
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

  }
}
