// SPDX-License-Identifier: GPL-3.0-or-later
import RealityKit
import XCTest

@testable import FareyVision

@MainActor final class DeepPathRendererTests: XCTestCase {
  private struct MeshCounts {
    var vertices = 0
    var triangles = 0
    var zeroArea = 0
  }
  func testDeepPathsProduceFiniteMeshesAndRetainExactEndpoints() throws {
    let cases = ["RLR", String(repeating: "L", count: 24), String(repeating: "R", count: 24),
      "LRLRRRLLRLLRLLLLLRR", String(repeating: "LR", count: 12)]
    var records: [[String: Any]] = []
    for word in cases {
      var state = FareyState()
      for character in word { XCTAssertTrue(state.step(character == "L" ? .l : .r)) }
      let exact = state
      let renderer = FareyRenderer()
      for viewpoint in 0...2 {
        let receipt = try renderer.render(state: state, depth: 6, viewpoint: viewpoint)
        XCTAssertTrue(receipt.hasPrefix("253 Farey edges"))
        XCTAssertEqual(state, exact)
        let groups = Array(renderer.root.children)
        XCTAssertEqual(groups.count, 2)
        let selection = groups[1]
        let dots = Array(selection.children.suffix(3))
        for (dot, rational) in zip(dots, [state.left, state.right, state.mediant]) {
          XCTAssertEqual(dot.position, SIMD3(Float(rational.diskPoint.x), Float(rational.diskPoint.y), 0.012))
        }
        let counts = inspect(renderer.root)
        // For these nonempty paths, the selected direction is followed by the history mesh.
        let history = try XCTUnwrap(selection.children.dropFirst().first)
        let historyCounts = inspect(history)
        XCTAssertGreaterThan(counts.vertices, 0)
        let markersCoincide = dots[0].position == dots[1].position && dots[1].position == dots[2].position
        if word == String(repeating: "LR", count: 12) { XCTAssertTrue(markersCoincide) }
        records.append([
          "word": word, "viewpoint": viewpoint, "left": state.left.description,
          "target": state.mediant.description, "right": state.right.description,
          "vertices": counts.vertices, "triangles": counts.triangles, "zeroAreaTriangles": counts.zeroArea,
          "historyVertices": historyCounts.vertices, "historyTriangles": historyCounts.triangles,
          "historyZeroAreaTriangles": historyCounts.zeroArea,
          "leftRightMarkersCoincide": dots[0].position == dots[1].position,
          "allMarkersCoincide": markersCoincide,
          "receipt": receipt,
        ])
      }
    }
    let data = try JSONSerialization.data(withJSONObject: records, options: [.prettyPrinted, .sortedKeys])
    let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
    attachment.name = "deep-renderer-mesh-audit"
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func inspect(_ entity: Entity) -> MeshCounts {
    var counts = MeshCounts()
    if let mesh = entity.components[ModelComponent.self]?.mesh {
      for model in mesh.contents.models {
        for part in model.parts {
          let positions = part[MeshBuffers.positions]?.elements ?? []
          XCTAssertFalse(positions.isEmpty)
          counts.vertices += positions.count
          for p in positions { XCTAssertTrue(p.x.isFinite && p.y.isFinite && p.z.isFinite) }
          for n in part[MeshBuffers.normals]?.elements ?? [] {
            XCTAssertTrue(n.x.isFinite && n.y.isFinite && n.z.isFinite)
          }
          let indices = part.triangleIndices?.elements ?? []
          XCTAssertEqual(indices.count % 3, 0)
          for i in stride(from: 0, to: indices.count, by: 3) {
            let a = positions[Int(indices[i])], b = positions[Int(indices[i + 1])]
            let c = positions[Int(indices[i + 2])]
            counts.triangles += 1
            if simd_length_squared(simd_cross(b - a, c - a)) == 0 { counts.zeroArea += 1 }
          }
        }
      }
    }
    for child in entity.children {
      let childCounts = inspect(child)
      counts.vertices += childCounts.vertices
      counts.triangles += childCounts.triangles
      counts.zeroArea += childCounts.zeroArea
    }
    return counts
  }
}
