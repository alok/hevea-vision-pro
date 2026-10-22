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
  func testRealDepthAndProjectionStayDistinctAcrossViews() throws {
    let renderer = StarscapeRenderer()
    let point = CoefficientPoint(1, -1, 2)
    _ = try renderer.render(selected: point, showProjection: true, viewpoint: 0)
    let names = [
      "coefficient:1:0:1", "coefficient:1:1:1", "coefficient:1:0:2", "coefficient:2:0:2",
    ]
    let positions = try names.map {
      try XCTUnwrap(renderer.root.findEntity(named: $0)).position(relativeTo: nil)
    }
    let a = positions[1] - positions[0]
    let b = positions[2] - positions[0]
    let c = positions[3] - positions[0]
    XCTAssertGreaterThan(abs(simd_dot(a, simd_cross(b, c))), 0.001)
    for view in 0..<3 {
      let receipt = try renderer.render(selected: point, showProjection: true, viewpoint: view)
      XCTAssertTrue(receipt.contains("280 coefficient points"))
      let source = try XCTUnwrap(renderer.root.findEntity(named: "coefficient:1:-1:2"))
      let image = try XCTUnwrap(renderer.root.findEntity(named: "image:1:-1:2"))
      XCTAssertNotEqual(source.position, image.position)
      XCTAssertEqual(image.position.y, 4 * StarscapeRenderer.scale, accuracy: 1e-6)
      XCTAssertEqual(
        source.position.x * image.position.y, source.position.y * image.position.x, accuracy: 1e-6)
    }
  }
}
