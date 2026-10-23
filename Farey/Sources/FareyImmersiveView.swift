// SPDX-License-Identifier: GPL-3.0-or-later
import RealityKit
import SwiftUI

#if canImport(FareyCore)
  import FareyCore
#endif

@MainActor struct FareyImmersiveView: View {
  @Environment(GalleryModel.self) private var model
  @State private var renderer = FareyRenderer()
  @State private var lattice = LatticeRenderer()
  @State private var starscape = StarscapeRenderer()
  @State private var activation: EventSubscription?
  /// True while a drag gesture is live; its reset on end or cancellation tells the model the drag is over.
  @GestureState private var dragging = false
  var body: some View {
    RealityView { content, attachments in
      content.add(renderer.root)
      content.add(lattice.root)
      content.add(starscape.stage)
      content.add(starscape.anchorHost)
      do { try await starscape.prepareSky() } catch { model.record("Origin sky unavailable: \(error.localizedDescription)") }
      activation = content.subscribe(to: AccessibilityEvents.Activate.self) { [model] event in
        InputDiagnostics.shared.recordActivate(entity: event.entity.name)
        Self.activate(event.entity, model: model)
      }
      for rational in LatticeRenderer.landmarks {
        if let label = attachments.entity(for: "lattice-\(rational.p)-\(rational.q)") {
          lattice.addLandmark(label, at: rational)
        }
      }
      if let title = attachments.entity(for: "title") {
        title.position = [0, 3.15, -3.3]
        title.scale = [3, 3, 3]
        content.add(title)
      }
      for (name, position) in [
        ("0", SIMD3<Float>(0, 0.51, -3.3)), ("∞", SIMD3<Float>(0, 3.08, -3.3)),
        ("1", SIMD3<Float>(1.35, 1.8, -3.3)), ("−1", SIMD3<Float>(-1.35, 1.8, -3.3)),
      ] {
        if let label = attachments.entity(for: name) {
          label.position = position
          label.scale = [3, 3, 3]
          renderer.labels.addChild(label)
        }
      }
      content.add(renderer.labels)
    } attachments: {
      ForEach(LatticeRenderer.landmarks, id: \.self) { rational in
        Attachment(id: "lattice-\(rational.p)-\(rational.q)") {
          Button(rational.description) { model.select(LatticePoint(p: rational.p, q: rational.q)) }
            .font(.caption.weight(.semibold)).buttonStyle(.borderedProminent)
            .tint(landmarkColor(rational))
            .foregroundStyle(
              rational == model.state.selectedPoint?.rational && rational != model.state.mediant
                ? Color.black : Color.white
            )
            .accessibilityIdentifier("lattice-\(rational.p)-\(rational.q)")
        }
      }
      Attachment(id: "title") {
        VStack(spacing: 4) {
          Text(
            model.starscapeMode
              ? "THE COEFFICIENT CONE"
              : model.constructionStage != nil
                ? "BOUNDARY TO LATTICE"
                : model.latticeMode ? "THE FAREY LATTICE" : "THE FAREY UNIVERSE"
          )
          .font(.headline).tracking(4).foregroundStyle(.cyan)
          Text(
            model.starscapeMode
              ? "Integer triples in 3D → radial projection to a Klein disk"
              : model.constructionStage != nil
                ? "q = 1 · a projective chart of the same rational direction"
                : model.latticeMode
                  ? "p/q is the direction (q, p) · mediants add integer vectors"
                  : "Exact rational edges · finite hyperbolic tessellation"
          ).font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      ForEach(["0", "∞", "1", "−1"], id: \.self) { label in
        Attachment(id: label) {
          Text(label).font(.system(size: 24, weight: .light, design: .serif)).foregroundStyle(.cyan)
        }
      }
    }
    .task(id: [model.revision, model.immersionSession, model.immersionOpen ? 1 : 0]) {
      guard model.immersionOpen else { return }
      do {
        let showingLattice =
          !model.starscapeMode && (model.latticeMode || model.constructionStage != nil)
        starscape.root.isEnabled = model.starscapeMode
        renderer.root.isEnabled = !showingLattice && !model.starscapeMode
        renderer.labels.isEnabled = !model.starscapeMode && !showingLattice && model.viewpoint == 0
        lattice.root.isEnabled = showingLattice
        if model.starscapeMode {
          model.renderReceipt = try starscape.render(
            selected: model.coefficient, showProjection: model.showProjection,
            viewpoint: model.coefficientView, crop: model.coefficientCrop,
            cuttingPlane: model.cuttingPlane, second: model.coefficientSecond, placement: model.coefficientPlacement,
            placementEpoch: model.coefficientPlacementEpoch, group: model.coefficientGroup,
            devicePose: model.currentDevicePose)
          InputDiagnostics.shared.recordSky(starscape.skyState)
        } else if showingLattice {
          model.renderReceipt = try lattice.render(
            state: model.state, bound: model.depth * 2,
            viewpoint: model.viewpoint, alternateCF: model.alternateCF,
            spotlight: model.spotlight.rational,
            construction: model.constructionStage, animateReveal: model.constructionMoving)
        } else {
          model.renderReceipt = try renderer.render(
            state: model.state, depth: model.depth, viewpoint: model.viewpoint,
            alternateCF: model.alternateCF, spotlight: model.spotlight.rational)
        }
        model.record("Rendered session \(model.immersionSession): \(model.renderReceipt)")
        if model.constructionMoving {
          let revision = model.revision
          try? await Task.sleep(for: .seconds(1.4))
          if !Task.isCancelled && revision == model.revision { model.stopConstruction() }
        }
      } catch { model.renderReceipt = "Geometry error: \(error.localizedDescription)" }
    }
    // One device-pose query per anchored placement; changing placement or closing the space cancels it, and the
    // query stops its session on every path.
    .task(id: model.coefficientPlacement.anchored ? model.coefficientPlacementEpoch : -1) {
      guard model.starscapeMode, model.coefficientPlacement.anchored else { return }
      let epoch = model.coefficientPlacementEpoch
      model.coefficientInput.devicePoseStatus = "querying world tracking"
      let result = await DevicePoseQuery.once()
      guard !Task.isCancelled, epoch == model.coefficientPlacementEpoch, model.coefficientPlacement.anchored else { return }
      switch result {
      case .success(let matrix):
        model.coefficientInput.devicePose = DevicePose(epoch: epoch, originFromDevice: matrix)
        model.coefficientInput.devicePoseStatus = "device pose for placement \(epoch)"
      case .failure(let failure): model.coefficientInput.devicePoseStatus = "no device pose: \(failure)"
      }
      model.revision += 1
    }
    .gesture(
      SpatialTapGesture().targetedToAnyEntity().onEnded { value in
        InputDiagnostics.shared.recordTap(entity: value.entity.name)
        Self.activate(value.entity, model: model)
      }
    )
    .simultaneousGesture(
      // At Origin, her eye-at-origin drag: the sky turns by the roots-pane step, never a camera move. Elsewhere a
      // drag changes nothing.
      // The direction is taken in the object's frame (`root`), which g never moves, so stars moving under the
      // pointer do not feed back into it.
      DragGesture().targetedToAnyEntity()
        .updating($dragging) { _, state, _ in state = true }
        .onChanged { value in
          // The gesture's location in the object's frame. In a real Device Hub drag (87d4f0f) this direct conversion
          // and the earlier path through the scene agreed exactly, and every step was off the interior: neither puts
          // the eye at the coefficient origin. The cause is still being measured (see the opt-in ray diagnostics).
          let direction = Self.double(value.convert(value.location3D, from: .local, to: starscape.root))
          let outcome = model.originDragStep(to: direction)
          guard InputDiagnostics.shared.enabled else { return }
          let twoHop = starscape.displayDirection(ofScenePoint: value.convert(value.location3D, from: .local, to: .scene))
          InputDiagnostics.shared.recordDrag(
            entity: value.entity.name,
            sample: .init(
              direction: direction, twoHop: twoHop,
              start: Self.double(value.convert(value.startLocation3D, from: .local, to: starscape.root)),
              translation: Self.double(value.convert(value.translation3D, from: .local, to: starscape.root))),
            outcome: outcome)
        }
        .onEnded { _ in
          InputDiagnostics.shared.recordDragEnd()
          model.endOriginDrag(completed: true)
        }
    )
    // Opt-in only: the system's selection ray for an indirect pinch, the one input that carries where the eye was,
    // recorded in the object's frame beside the location; it changes nothing.
    .simultaneousGesture(
      SpatialEventGesture().targetedToAnyEntity()
        .onChanged { value in recordPinches(value) }
        .onEnded { value in recordPinches(value) },
      including: InputDiagnostics.shared.enabled ? .all : .none)
    // A cancelled gesture never calls onEnded; the gesture state's reset still does.
    .onChange(of: dragging) { _, live in
      guard !live else { return }
      InputDiagnostics.shared.recordDragReset()
      model.endOriginDrag(completed: false)
    }
    .onAppear {
      model.record("Immersive view appeared session \(model.immersionSession)")
      model.error = nil
    }
    .onDisappear {
      model.projectedSelection = nil
      model.stopConstruction()
      activation?.cancel()
      activation = nil
      model.endOriginDrag(completed: false)
      model.armPairNext(false)
      model.record("Immersive view disappeared session \(model.immersionSession)")
      model.immersionOpen = false
      model.transitioning = false
      // A head placement belongs to one immersive session; re-entry starts at the stationary overview.
      model.coefficientPlacement = .overview
    }

  }
  private static func double(_ v: SIMD3<Float>) -> SIMD3<Double> { SIMD3(Double(v.x), Double(v.y), Double(v.z)) }
  /// Every indirect-pinch event of a SpatialEventGesture update, into the opt-in diagnostics.
  private func recordPinches(_ value: EntityTargetValue<SpatialEventCollection>) {
    for event in value.gestureValue where event.kind == .indirectPinch {
      let ray = event.selectionRay.map { ray in
        (origin: Self.double(value.convert(ray.origin, from: .local, to: starscape.root)),
         direction: Self.double(value.convert(ray.direction, from: .local, to: starscape.root)))
      }
      InputDiagnostics.shared.recordPinch(
        entity: event.targetedEntity?.name ?? "none", phase: "\(event.phase)",
        location: Self.double(value.convert(event.location3D, from: .local, to: starscape.root)), ray: ray)
    }
  }
  private static func activate(_ entity: Entity, model: GalleryModel) {
    if model.starscapeMode {
      let parts = entity.name.split(separator: ":")
      if parts.count == 4, parts[0] == "coefficient", let a = Int(parts[1]),
        let b = Int(parts[2]), let c = Int(parts[3]) {
        model.activateCoefficient(CoefficientPoint(a, b, c))
      }
    } else if let point = latticePoint(for: entity) {
      model.activatePoint(point)
    }
  }
  private static func latticePoint(for entity: Entity) -> LatticePoint? {
    let parts = entity.name.split(separator: ":")
    guard parts.count == 3, parts[0] == "rational",
      let p = Int64(parts[1]), let q = Int64(parts[2])
    else { return nil }
    return LatticePoint(p: p, q: q)
  }
  private func landmarkColor(_ rational: Rational) -> Color {
    if rational == model.state.mediant { return .orange }
    if rational == model.state.selectedPoint?.rational { return .white }
    if rational == model.state.left { return .cyan }
    if rational == model.state.right { return .purple }
    return .blue
  }
}

@MainActor final class FareyRenderer {
  let root = Entity()
  let labels = Entity()
  private var previousDepth: Int?
  private let base = Entity()
  private let selection = Entity()
  init() {
    root.position = [0, 1.8, -3.3]
    root.scale = [1.2, 1.2, 1.2]
    root.addChild(base)
    root.addChild(selection)
  }
  func render(
    state: FareyState, depth: Int, viewpoint: Int, alternateCF: Bool = false,
    spotlight: Rational? = nil
  ) throws -> String {
    let start = ContinuousClock.now
    var vertices = 0
    if previousDepth != depth {
      base.children.removeAll()
      let edges = Geometry.tessellation(depth: depth)
      for level in 0...depth {
        let lines = edges.filter { $0.depth == level }.map(\.samples)
        let radius = Float(0.0032 / (1 + Double(level) * 0.28))
        let shade = CGFloat(max(0.28, 0.95 - Double(level) * 0.095))
        let mesh = try tubeMesh(lines: lines, radius: radius)
        vertices += mesh.1
        let entity = ModelEntity(
          mesh: mesh.0,
          materials: [UnlitMaterial(color: UIColor(red: 0.12, green: shade, blue: 1, alpha: 1))])
        base.addChild(entity)
      }
      let ring = (0...160).map { i in
        Point2(cos(Double(i) * 2 * .pi / 160), sin(Double(i) * 2 * .pi / 160))
      }
      let boundary = try tubeMesh(lines: [ring], radius: 0.0035)
      base.addChild(
        ModelEntity(
          mesh: boundary.0,
          materials: [UnlitMaterial(color: UIColor(red: 0.2, green: 0.65, blue: 1, alpha: 1))]))
      previousDepth = depth
    }
    selection.children.removeAll()
    let direction = try tubeMesh(
      lines: [Geometry.geodesic(Rational(1, 0).diskPoint, state.mediant.diskPoint)], radius: 0.004)
    selection.addChild(
      ModelEntity(
        mesh: direction.0,
        materials: [UnlitMaterial(color: UIColor.systemGreen)]))
    try addHistory(state)
    try addCFRings(state, alternate: alternateCF)
    if let spotlight { try addSpotlight(spotlight) }
    for rational in [state.left, state.right, state.mediant] {
      let point = rational.diskPoint
      let dot = ModelEntity(
        mesh: .generateSphere(radius: 0.014), materials: [UnlitMaterial(color: UIColor.orange)])
      dot.position = [Float(point.x), Float(point.y), 0.012]
      selection.addChild(dot)
    }
    let angle: Float = [0, -0.5, 0.8][viewpoint]
    root.orientation = simd_quatf(angle: angle, axis: [0, 1, 0])
    labels.isEnabled = viewpoint == 0
    let elapsed = start.duration(to: .now)
    let edgeCount = Geometry.tessellation(depth: depth).count
    return
      "\(edgeCount) Farey edges · \(base.children.count + selection.children.count) draw groups · \(elapsed) update · stationary"
  }

  private func addCFRings(_ state: FareyState, alternate: Bool) throws {
    for convergent in [true, false] {
      let circles = state.cfPoints(alternate: alternate).filter { $0.isConvergent == convergent }
        .map { point in
          let center = point.rational.diskPoint
          let radius = convergent ? 0.028 : 0.022
          return (0...24).map { index in
            let angle = Double(index) * 2 * .pi / 24
            return Point2(center.x + cos(angle) * radius, center.y + sin(angle) * radius)
          }
        }
      if !circles.isEmpty {
        let rings = try tubeMesh(lines: circles, radius: 0.0025)
        selection.addChild(
          ModelEntity(
            mesh: rings.0,
            materials: [
              UnlitMaterial(color: convergent ? UIColor.systemYellow : UIColor.lightGray)
            ]))
      }
    }
  }

  private func addSpotlight(_ rational: Rational) throws {
    let center = rational.diskPoint
    let circles = [0.04, 0.055].map { radius in
      (0...32).map { index in
        let angle = Double(index) * 2 * .pi / 32
        return Point2(center.x + cos(angle) * radius, center.y + sin(angle) * radius)
      }
    }
    let mesh = try tubeMesh(lines: circles, radius: 0.003)
    selection.addChild(ModelEntity(mesh: mesh.0, materials: [UnlitMaterial(color: .white)]))
  }

  private func addHistory(_ state: FareyState) throws {
    if !state.word.isEmpty {
      let path = try tubeMesh(lines: state.history.map(\.samples), radius: 0.005)
      selection.addChild(
        ModelEntity(
          mesh: path.0,
          materials: [UnlitMaterial(color: UIColor(red: 1, green: 0.62, blue: 0.2, alpha: 1))]))
    }
  }

  private func tubeMesh(lines: [[Point2]], radius: Float) throws -> (MeshResource, Int) {
    let sides = 6
    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var indices: [UInt32] = []
    for line in lines where line.count > 1 {
      let offset = positions.count
      for i in line.indices {
        let before = line[max(0, i - 1)]
        let after = line[min(line.count - 1, i + 1)]
        let tangent = simd_normalize(
          SIMD3<Float>(Float(after.x - before.x), Float(after.y - before.y), 0))
        let normal = SIMD3<Float>(-tangent.y, tangent.x, 0)
        let center = SIMD3<Float>(Float(line[i].x), Float(line[i].y), 0)
        for side in 0..<sides {
          let angle = Float(side) * 2 * .pi / Float(sides)
          let direction = normal * cos(angle) + SIMD3<Float>(0, 0, 1) * sin(angle)
          positions.append(center + radius * direction)
          normals.append(direction)
        }
        if i > 0 {
          for side in 0..<sides {
            let a = UInt32(offset + (i - 1) * sides + side)
            let b = UInt32(offset + (i - 1) * sides + (side + 1) % sides)
            let c = UInt32(offset + i * sides + side)
            let d = UInt32(offset + i * sides + (side + 1) % sides)
            indices.append(contentsOf: [a, b, c, b, d, c])
          }
        }
      }
    }
    var descriptor = MeshDescriptor(name: "Farey exact geodesic tubes")
    descriptor.positions = MeshBuffers.Positions(positions)
    descriptor.normals = MeshBuffers.Normals(normals)
    descriptor.primitives = .triangles(indices)
    return (try MeshResource.generate(from: [descriptor]), positions.count)
  }
}
