import OSLog
// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

#if canImport(FareyCore)
  import FareyCore
#endif

@MainActor @Observable final class GalleryModel {
  var state = FareyState() {
    didSet {
      constructionMoving = false
      projectedSelection = nil
    }
  }
  var depth = 6 { didSet { projectedSelection = nil } }
  var viewpoint = 0
  var latticeMode = true
  var starscapeMode = true
  var coefficient = Starscape.examples[0]
  var coefficientView = 0
  var showProjection = false
  var coefficientRadius = CoefficientBall.defaultRadius
  var coefficientUpperOnly = false
  var coefficientColorLower = false
  var coefficientEntryError: String?
  /// A second interior point pairs with the selection to define a cutting plane. Both keep their exact signed
  /// identities; the plane's canonical normal is derived, never substituted for either.
  var coefficientSecond: CoefficientPoint?
  var coefficientPairError: String?
  /// Where the viewer stands. This is separate from the selection: selecting another point while inhabiting does
  /// not move the viewer; only the placement controls, Reset and leaving the immersive space do.
  var coefficientPlacement = StarscapeRenderer.Placement.overview
  /// Counts explicit Origin and Inhabit requests: each one re-anchors at the current head center, even when the
  /// placement is unchanged. Renders, selection changes and the Origin nappe flip keep the existing anchor.
  var coefficientPlacementEpoch = 0
  /// The view's Möbius transformation g (her viewer's group element). Points keep their exact identities; g moves
  /// where they are drawn. Only an integer g is absorbed, relabelling the selection and pair exactly.
  var coefficientGroup = Mobius.identity
  var coefficientSnap = false
  var coefficientGroupError: String?
  /// The pair's plane, else the selection's own plane when it is exterior (as in Stange's viewer), else none.
  var cuttingPlane: CuttingPlane? {
    if let second = coefficientSecond { return try? CuttingPlane.pair(coefficient, second).get() }
    return try? CuttingPlane.fromNormal(coefficient).get()
  }
  var coefficientCrop: StarscapeRenderer.Crop {
    .init(radius: coefficientRadius, upperOnly: coefficientUpperOnly, colorLower: coefficientColorLower)
  }
  /// The inspected triple keeps its identity when a filter or radius hides it.
  var coefficientShown: Bool {
    CoefficientBall.shown(coefficient, radius: coefficientRadius, upperOnly: coefficientUpperOnly)
  }
  func nextCoefficient() {
    let sequence = CoefficientBall.nextSequence
    let index = sequence.firstIndex(of: coefficient) ?? -1
    select(sequence[(index + 1) % sequence.count])
  }
  /// A new primary selection drops any pair, as in the browser; it never changes the placement.
  func select(_ point: CoefficientPoint) {
    coefficient = point
    coefficientSecond = nil
    coefficientEntryError = nil
    coefficientPairError = nil
    revision += 1
  }
  /// Pairs an exactly entered second point with the selection. A rejected entry or pair (outside the ball, not
  /// interior, or the same projective direction, sign partners included) leaves every state unchanged.
  @discardableResult func pairCoefficient(_ text: String) -> Bool {
    let point: CoefficientPoint
    switch CoefficientEntry.parse(text, radius: coefficientRadius) {
    case .success(let entered): point = entered
    case .failure(let error):
      coefficientPairError = error.message
      return false
    }
    if case .failure(let error) = CuttingPlane.pair(coefficient, point) {
      coefficientPairError = error.message
      return false
    }
    coefficientSecond = point
    coefficientPairError = nil
    revision += 1
    return true
  }
  func clearPair() {
    coefficientSecond = nil
    coefficientPairError = nil
    revision += 1
  }
  func place(_ placement: StarscapeRenderer.Placement, recenter: Bool = true) {
    if recenter && placement.anchored { coefficientPlacementEpoch += 1 }
    coefficientPlacement = placement
    revision += 1
  }
  /// Exact signed entry; a rejected entry leaves every part of the coefficient state unchanged.
  @discardableResult func enterCoefficient(_ text: String) -> Bool {
    switch CoefficientEntry.parse(text, radius: coefficientRadius) {
    case .success(let point):
      select(point)
      return true
    case .failure(let error):
      coefficientEntryError = error.message
      return false
    }
  }
  func resetStarscape() {
    coefficient = Starscape.examples[0]
    coefficientView = 0
    showProjection = false
    coefficientRadius = CoefficientBall.defaultRadius
    coefficientUpperOnly = false
    coefficientColorLower = false
    coefficientEntryError = nil
    coefficientSecond = nil
    coefficientPairError = nil
    coefficientPlacement = .overview
    coefficientGroup = .identity
    coefficientSnap = false
    coefficientGroupError = nil
    revision += 1
  }
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
  var spotlight = ApproximantSpotlight()
  var constructionStage: ConstructionStage? { didSet { projectedSelection = nil } }
  var projectedSelection: ProjectedSelection?
  var animateConstruction = false
  var constructionMoving = false
  var precisionNotice: String? {
    guard !starscapeMode, constructionStage == nil else { return nil }
    let overlaps =
      latticeMode
      ? DisplayPrecision.latticeOverlaps(state, bound: depth * 2)
      : DisplayPrecision.diskOverlaps(state)
    guard overlaps else { return nil }
    return
      "Display overlap: distinct fractions can look identical here. Read the exact values above."
  }
  func spotlightPoint(_ point: Rational) {
    constructionMoving = false
    if spotlight.focus(point, in: state, alternate: alternateCF) { revision += 1 }
  }
  func clearSpotlight() {
    constructionMoving = false
    spotlight.clear()
    revision += 1
  }
  func setAlternateCF(_ value: Bool) {
    guard value != alternateCF else { return }
    constructionMoving = false
    alternateCF = value
    spotlight.reconcile(with: state, alternate: value)
    revision += 1
  }
  func step(_ turn: Turn) {
    if state.step(turn) {
      spotlight.reconcile(with: state, alternate: alternateCF)
      lesson = nil
      revision += 1
    }
  }
  func undo() {
    lesson = nil
    state.undo()
    spotlight.reconcile(with: state, alternate: alternateCF)
    revision += 1
  }
  func reset() {
    endConstruction()
    alternateCF = false
    spotlight.clear()
    lesson = nil
    state.reset()
    depth = 6
    viewpoint = 0
    latticeMode = true
    revision += 1
  }
  func select(_ point: LatticePoint) {
    if state.select(point.rational) {
      spotlight.reconcile(with: state, alternate: alternateCF)
      lesson = nil
      revision += 1
    }
  }
  @discardableResult func enterFraction(_ text: String) throws -> FractionEntry {
    let entry = try FractionEntry(text)
    state = entry.state
    spotlight.reconcile(with: state, alternate: alternateCF)
    lesson = nil
    revision += 1
    return entry
  }
  func toggleSpace() {
    endConstruction()
    latticeMode.toggle()
    revision += 1
  }
  func preset() {
    lesson = nil
    state.select(Rational(3, 5))
    spotlight.reconcile(with: state, alternate: alternateCF)
    revision += 1
  }
  func changeDepth(_ delta: Int) {
    constructionMoving = false
    depth = min(7, max(3, depth + delta))
    revision += 1
  }
  func changeView() {
    projectedSelection = nil
    constructionMoving = false
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
    spotlight.reconcile(with: state, alternate: alternateCF)
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
    .defaultSize(width: 760, height: 360)
    .defaultWindowPlacement { _, _ in WindowPlacement(.utilityPanel) }
    .windowStyle(.plain)
    .persistentSystemOverlays(.hidden)
    .defaultLaunchBehavior(.suppressed)
    .restorationBehavior(.disabled)
    // Her right-hand diagram, beside the controls panel and never over it (overlapping, it hid Reset and Exit).
    Window("Roots", id: "roots") { RootsPaneView().environment(model) }
      .defaultSize(width: 560, height: 560)
      .defaultWindowPlacement { _, context in
        WindowPlacement(context.windows.first { $0.id == "controls" }.map { .trailing($0) } ?? .utilityPanel)
      }
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
          Text("See the mathematics in space").font(
            .system(size: 40, weight: .light, design: .serif))
          Text("A 3D lattice. A cone. Its 2D image.").font(.title3).foregroundStyle(.secondary)
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
      StarscapePreview().frame(height: 280)
      Text(
        "Explore quadratic coefficients (a,b,c) at genuinely different depths.\n"
          + "See their projection onto a disk, or switch to the separate Farey L/R lattice."
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
