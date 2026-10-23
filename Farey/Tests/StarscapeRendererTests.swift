import RealityKit
import XCTest

@testable import FareyVision

@MainActor final class StarscapeRendererTests: XCTestCase {
  func testCoefficientViewPreservesTheSeparateFareyState() {
    let model = GalleryModel()
    model.preset()
    let state = model.state
    model.nextCoefficient()
    XCTAssertEqual(model.coefficient, CoefficientPoint(2, -2, 4))
    model.starscapeMode = false
    XCTAssertEqual(model.state, state)
    model.starscapeMode = true
    model.resetStarscape()
    XCTAssertEqual(model.state, state)
    XCTAssertNil(model.precisionNotice)
  }
  private func dots(_ renderer: StarscapeRenderer) -> [String: ModelEntity] {
    var result: [String: ModelEntity] = [:]
    func walk(_ entity: Entity) {
      if entity.name.hasPrefix("coefficient:"), let model = entity as? ModelEntity { result[entity.name] = model }
      entity.children.forEach(walk)
    }
    walk(renderer.root)
    return result
  }
  func testEntitiesAreExactlyTheBrowserBallWithExactCenters() throws {
    let renderer = StarscapeRenderer()
    for crop in [
      StarscapeRenderer.Crop(), StarscapeRenderer.Crop(radius: 12), StarscapeRenderer.Crop(upperOnly: true),
    ] {
      let receipt = try renderer.render(
        selected: CoefficientPoint(1, -1, 2), showProjection: false, viewpoint: 0, crop: crop)
      let expected = CoefficientBall.points(radius: crop.radius, upperOnly: crop.upperOnly)
      let found = dots(renderer)
      XCTAssertEqual(found.count, expected.count)
      XCTAssertTrue(receipt.hasPrefix("\(expected.count) coefficient points · radius \(crop.radius) (native cap 12)"))
      XCTAssertEqual(renderer.scale, StarscapeRenderer.ballRadius / Float(crop.radius))
      for point in expected {
        let dot = try XCTUnwrap(found["coefficient:\(point.a):\(point.b):\(point.c)"])
        XCTAssertEqual(dot.position, renderer.position(point.vector))
        XCTAssertLessThanOrEqual(simd_length(dot.position), StarscapeRenderer.ballRadius + 1e-5)
      }
    }
    XCTAssertEqual(dots(renderer).count, 55)
  }
  func testDotColorsAreThePaletteAndSelectionIsAnOutline() throws {
    let renderer = StarscapeRenderer()
    _ = try renderer.render(selected: CoefficientPoint(2, 1, 1), showProjection: false, viewpoint: 0)
    let found = dots(renderer)
    for point in [CoefficientPoint(1, -1, 2), CoefficientPoint(-1, 1, -2), CoefficientPoint(1, 2, 1), CoefficientPoint(1, 3, 1)] {
      let material = try XCTUnwrap(found["coefficient:\(point.a):\(point.b):\(point.c)"]?.model?.materials.first as? UnlitMaterial)
      let want = try XCTUnwrap(CoefficientPalette.color(for: point))
      var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
      XCTAssertTrue(material.color.tint.getRed(&r, green: &g, blue: &b, alpha: &a))
      XCTAssertEqual(Double(r), want.x, accuracy: 1 / 255.0)
      XCTAssertEqual(Double(g), want.y, accuracy: 1 / 255.0)
      XCTAssertEqual(Double(b), want.z, accuracy: 1 / 255.0)
    }
    let outline = try XCTUnwrap(renderer.root.findEntity(named: "selection-outline"))
    XCTAssertEqual(outline.position, renderer.position(CoefficientPoint(2, 1, 1).vector))
    let hidden = try renderer.render(selected: CoefficientPoint(2, -2, 4), showProjection: false, viewpoint: 0)
    XCTAssertTrue(hidden.contains("selected point hidden by this filter"))
    XCTAssertNil(renderer.root.findEntity(named: "selection-outline"))
  }
  func testProjectionUsesPositiveRepresentativesAndOnlyInteriorForms() throws {
    let renderer = StarscapeRenderer()
    for view in 0..<3 {
      _ = try renderer.render(selected: CoefficientPoint(-1, 1, -2), showProjection: true, viewpoint: view)
      let upper = try XCTUnwrap(renderer.root.findEntity(named: "image:1:-1:2"))
      let lower = try XCTUnwrap(renderer.root.findEntity(named: "image:-1:1:-2"))
      XCTAssertEqual(upper.position, lower.position)
      XCTAssertEqual(upper.position.y, 4 * renderer.scale, accuracy: 1e-6)
      let source = try XCTUnwrap(renderer.root.findEntity(named: "coefficient:1:-1:2"))
      XCTAssertEqual(source.position.x * upper.position.y, source.position.y * upper.position.x, accuracy: 1e-6)
      let marker = try XCTUnwrap(renderer.root.findEntity(named: "selection-image"))
      XCTAssertEqual(marker.position, upper.position)
      XCTAssertNil(renderer.root.findEntity(named: "image:1:2:1"))
      XCTAssertNil(renderer.root.findEntity(named: "image:1:3:1"))
    }
  }
  func testEntryFiltersAndResetKeepTheInspectedState() {
    let model = GalleryModel()
    XCTAssertFalse(model.showProjection)
    XCTAssertTrue(model.enterCoefficient("-1, 1, -2"))
    XCTAssertEqual(model.coefficient, CoefficientPoint(-1, 1, -2))
    let revision = model.revision
    for text in ["0,0,0", "1,2", "5,0,0", "99999999999999999999,0,1", "x,1,1"] {
      XCTAssertFalse(model.enterCoefficient(text))
      XCTAssertEqual(model.coefficient, CoefficientPoint(-1, 1, -2), text)
      XCTAssertEqual(model.revision, revision, text)
      XCTAssertNotNil(model.coefficientEntryError)
    }
    model.coefficientUpperOnly = true
    XCTAssertFalse(model.coefficientShown)
    XCTAssertEqual(model.coefficient, CoefficientPoint(-1, 1, -2))
    model.coefficientRadius = 12
    model.showProjection = true
    model.coefficientColorLower = true
    model.coefficientView = 2
    model.resetStarscape()
    XCTAssertEqual(model.coefficient, CoefficientPoint(1, -1, 2))
    XCTAssertEqual(model.coefficientCrop, StarscapeRenderer.Crop())
    XCTAssertFalse(model.showProjection)
    XCTAssertEqual(model.coefficientView, 0)
    XCTAssertNil(model.coefficientEntryError)
    var seen: [CoefficientPoint] = [model.coefficient]
    for _ in 0..<8 { model.nextCoefficient(); seen.append(model.coefficient) }
    XCTAssertEqual(Array(seen.prefix(8)), CoefficientBall.nextSequence)
    XCTAssertEqual(seen.last, CoefficientBall.nextSequence[0])
  }
}
