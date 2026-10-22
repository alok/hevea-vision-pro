// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// A conservative warning test for exact Float32 coordinate collisions.
/// It does not detect every overlap caused by finite marker width or screen resolution.
public enum DisplayPrecision {
  public static func diskOverlaps(_ state: FareyState) -> Bool {
    overlaps(state) { rational in
      let point = rational.diskPoint
      return SIMD3(Float(point.x), Float(point.y), 0.012)
    }
  }

  public static func latticeEndpoint(_ rational: Rational, bound: Int) -> SIMD3<Float> {
    let largest = max(Float(rational.p), Float(rational.q), 1)
    let scale = Float(bound) / largest
    let p = Float(rational.p) * scale, q = Float(rational.q) * scale
    let diagonal: Float = 0.25 / sqrt(2)
    return [(p - q) * diagonal, 0, -(p + q) * diagonal]
  }

  public static func latticeOverlaps(_ state: FareyState, bound: Int) -> Bool {
    overlaps(state) { latticeEndpoint($0, bound: bound) }
  }

  private static func overlaps(_ state: FareyState, project: (Rational) -> SIMD3<Float>) -> Bool {
    let fractions = [state.left, state.mediant, state.right]
    let positions = fractions.map(project)
    for i in 0..<2 {
      for j in (i + 1)..<3 where positions[i] == positions[j] {
        if fractions[i].p * fractions[j].q != fractions[j].p * fractions[i].q { return true }
      }
    }
    return false
  }
}
