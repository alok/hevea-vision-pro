// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

@main
struct GeodesicAudit {
  static func main() throws {
    var states: [FareyState] = []
    for word in [String(repeating: "LR", count: 12), String(repeating: "RL", count: 12),
      String(repeating: "L", count: 24), String(repeating: "R", count: 24)] {
      var state = FareyState()
      for letter in word { state.step(letter == "L" ? .l : .r) }
      states.append(state)
    }
    var seed: UInt64 = 42
    for _ in 0..<1000 {
      var state = FareyState()
      for _ in 0..<24 {
        seed = seed &* 6_364_136_223_846_793_005 &+ 1
        state.step(seed >> 63 == 0 ? .l : .r)
      }
      states.append(state)
    }
    var duplicates = 0, nonfinite = 0, outside = 0
    var worst = 0.0
    for state in states {
      for edge in state.history {
        let points = edge.samples
        duplicates += zip(points, points.dropFirst()).filter { $0 == $1 }.count
        nonfinite += points.filter { !$0.x.isFinite || !$0.y.isFinite }.count
        let overshoot = points.map { $0.lengthSquared - 1 }.max() ?? 0
        worst = max(worst, overshoot)
        if overshoot > 1e-6 { outside += 1 }
      }
    }
    let result: [String: Any] = ["states": states.count, "duplicateSegments": duplicates,
      "nonfinitePoints": nonfinite, "arcsOutsideDiskByMoreThan1eMinus6": outside,
      "maxSquaredRadiusOvershoot": worst]
    let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
    FileHandle.standardOutput.write(data)
  }
}
