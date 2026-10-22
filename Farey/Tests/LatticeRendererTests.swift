import RealityKit
import XCTest

@testable import FareyVision

@MainActor final class LatticeRendererTests: XCTestCase {
  func testProjectedMarkersDescribeTheirChartPositionAndRetainIntegerIdentity() throws {
    let renderer = LatticeRenderer()
    var state = FareyState()
    XCTAssertTrue(state.select(Rational(3, 5)))
    let receipt = try renderer.render(state: state, bound: 12, viewpoint: 0, construction: .boundary)
    XCTAssertEqual(receipt, "92 projected direction dots · q = 1 · source grid: 168 points")
    let target = try XCTUnwrap(renderer.root.findEntity(named: "rational:3:5"))
    let multiple = try XCTUnwrap(renderer.root.findEntity(named: "rational:6:10"))
    XCTAssertTrue(target.isEnabled)
    XCTAssertFalse(multiple.isEnabled)
    let resource = try XCTUnwrap(target.components[AccessibilityComponent.self]?.label)
    XCTAssertEqual(String(localized: resource), "Projected direction 3/5 at (1, 3/5), from integer point (5, 3)")
    let projected = target.position
    _ = try renderer.render(state: state, bound: 12, viewpoint: 0, construction: .lattice)
    XCTAssertEqual(target.position.x, projected.x * 5, accuracy: 1e-6)
    XCTAssertEqual(target.position.z, projected.z * 5, accuracy: 1e-6)
    XCTAssertTrue(multiple.isEnabled)
    XCTAssertEqual(label(of: target),
      "Lattice point (5, 3), fraction 3/5")
  }

  func testMovingMarkersAreNotReportedAsIntegerPositionsUntilSettled() throws {
    let renderer = LatticeRenderer()
    let state = FareyState()
    _ = try renderer.render(state: state, bound: 12, viewpoint: 0, construction: .direction)
    let receipt = try renderer.render(
      state: state, bound: 12, viewpoint: 0, construction: .lattice, animateReveal: true)
    XCTAssertEqual(receipt, "168 markers · illustrative motion toward integer positions")
    let point = try XCTUnwrap(renderer.root.findEntity(named: "rational:3:5"))
    XCTAssertEqual(label(of: point),
      "Illustrative motion toward integer point (5, 3), fraction 3/5")
    let settled = try renderer.render(state: state, bound: 12, viewpoint: 0, construction: .lattice)
    XCTAssertTrue(settled.hasPrefix("168 lattice points"))
    XCTAssertEqual(label(of: point),
      "Lattice point (5, 3), fraction 3/5")
  }
  private func label(of entity: Entity) -> String? {
    guard let label = entity.components[AccessibilityComponent.self]?.label else { return nil }
    return String(localized: label)
  }

}
