// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import CryptoKit

@main struct AuditConsistency {
  struct Input: Decodable { let word: String?; let p: Int64?; let q: Int64? }
  static func main() throws {
    let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
    let cases = try JSONDecoder().decode([Input].self, from: data)
    var digest = SHA256(), acceptedCount = 0, maxComponent: Int64 = 0
    var checkedEdges = Set<String>(), maxResidual = 0.0, collapsedFloatEdges = 0
    var examples: [[String: Any]] = []
    func pair(_ value: Rational) -> String { "\(value.p),\(value.q)" }
    func check(_ edge: FareyEdge) {
      let key = "\(pair(edge.left))|\(pair(edge.right))"
      guard checkedEdges.insert(key).inserted else { return }
      let a = edge.left.diskPoint, b = edge.right.diskPoint, points = edge.samples
      precondition(points.first == a && points.last == b)
      let delta = a.x * b.y - a.y * b.x
      var collapsed = false
      for point in points {
        precondition(point.x.isFinite && point.y.isFinite && point.lengthSquared <= 1 + 1e-12)
        let residual = abs(delta * (point.lengthSquared + 1)
          - 2 * ((b.y - a.y) * point.x + (a.x - b.x) * point.y))
        maxResidual = max(maxResidual, residual)
        precondition(residual < 2e-13, "Not on the orthogonal geodesic: \(key)")
      }
      for (index, samples) in zip(points, points.dropFirst()).enumerated() {
        let (p, q) = samples
        precondition(p != q, "Collapsed Double sample: \(key)")
        if Float(p.x) == Float(q.x) && Float(p.y) == Float(q.y) {
          if !collapsed && examples.count < 5 {
            examples.append(["edge": key, "sampleIndex": index,
              "first": [p.x, p.y], "second": [q.x, q.y],
              "roundedCenter": [Double(Float(p.x)), Double(Float(p.y))]])
          }
          collapsed = true
        }
        let dx = Float(q.x - p.x), dy = Float(q.y - p.y)
        precondition(dx * dx + dy * dy > 0, "Vanishing tube tangent: \(key)")
      }
      if collapsed { collapsedFloatEdges += 1 }
    }
    for input in cases {
      var state = FareyState(), accepted = true
      if let word = input.word {
        for c in word { if !state.step(c == "L" ? .l : .r) { accepted = false } }
      } else { accepted = state.select(Rational(input.p!, input.q!)) }
      if accepted { acceptedCount += 1 }
      maxComponent = max(maxComponent, state.mediant.p, state.mediant.q)
      precondition(state.determinant == 1)
      let cf = ContinuedFraction(state.mediant)!
      let terms = cf.canonical.map(String.init).joined(separator: ",")
      let alternate = cf.terms(alternate: true).map(String.init).joined(separator: ",")
      func rows(_ alternate: Bool) -> String {
        state.cfPoints(alternate: alternate).map {
          "\(pair($0.rational)):\($0.isConvergent ? 1 : 0)"
        }.joined(separator: ";")
      }
      let selected = state.selectedPoint.map { pair($0.rational) } ?? "-"
      let line = [accepted ? "1" : "0", pair(state.left), pair(state.right), pair(state.mediant),
        state.word.map(\.rawValue).joined(), selected, terms, alternate, rows(false), rows(true)]
        .joined(separator: "|") + "\n"
      digest.update(data: Data(line.utf8))
      let inspected = state.inspection!.point, projected = BoundaryConstruction.project(inspected)!
      precondition(abs(projected.x * Double(inspected.q) - Double(inspected.p)) <= 1e-10)
      precondition(abs(state.mediant.diskPoint.lengthSquared - 1) < 1e-12)
      for edge in state.history { check(edge) }
    }
    for edge in Geometry.tessellation(depth: 8) { check(edge) }
    for p: Int64 in 1...14 { for q: Int64 in 1...14 {
      let positive = Rational(p, q).diskPoint, negative = Rational(-p, q).diskPoint
      let multiple = Rational(7 * p, 7 * q).diskPoint
      precondition(abs(positive.x + negative.x) < 1e-14 && abs(positive.y - negative.y) < 1e-14)
      precondition(abs(positive.x - multiple.x) < 1e-14 && abs(positive.y - multiple.y) < 1e-14)
    } }
    let result: [String: Any] = ["cases": cases.count, "accepted": acceptedCount,
      "maxComponent": maxComponent, "digest": digest.finalize().map { String(format: "%02x", $0) }.joined(),
      "checkedEndpointPairs": checkedEdges.count, "maxOrthogonalResidual": maxResidual,
      "edgesWithCollapsedFloatCenters": collapsedFloatEdges, "collapsedFloatExamples": examples, "passed": true]
    print(String(data: try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]), encoding: .utf8)!)
  }
}
