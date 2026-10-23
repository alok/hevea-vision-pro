// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// Coefficients of ax² + bx + c; this is a different lattice from Farey pairs (q,p).
public struct CoefficientPoint: Hashable, Sendable {
  public let a: Int
  public let b: Int
  public let c: Int
  public init(_ a: Int, _ b: Int, _ c: Int) {
    self.a = a
    self.b = b
    self.c = c
  }
  public var discriminant: Int { b * b - 4 * a * c }
  public var height: Int { a + c }
  public var isStar: Bool { a > 0 && discriminant < 0 }
  /// A rigidly rotated version of the source viewer's (b,a+c,a-c) coordinates.
  public var vector: SIMD3<Double> { SIMD3(-Double(b), Double(height), Double(c - a)) }
  public func projected(height h: Double) -> SIMD3<Double>? {
    guard isStar, h > 0 else { return nil }
    return vector * (h / Double(height))
  }
  public var upperRoot: SIMD2<Double>? {
    guard isStar else { return nil }
    return SIMD2(-Double(b) / Double(2 * a), sqrt(Double(-discriminant)) / Double(2 * a))
  }
  public var label: String { "(\(a), \(b), \(c))" }
  /// The exact signed polynomial in her viewer's typography (x² + x + 1, 2x² − 2x + 4, −x² + x − 2): spaced
  /// operators, a leading minus without a space, implicit unit coefficients, zero terms dropped. A multiple is never
  /// reduced to its primitive form.
  public var polynomial: String {
    let terms = [(a, "x²"), (b, "x"), (c, "")].filter { $0.0 != 0 }
    guard !terms.isEmpty else { return "0" }
    return terms.enumerated().map { index, term in
      let (k, power) = term, magnitude = k.magnitude
      let body = (!power.isEmpty && magnitude == 1 ? "" : "\(magnitude)") + power
      return index == 0 ? (k < 0 ? "−" : "") + body : (k < 0 ? " − " : " + ") + body
    }.joined()
  }
}

public enum Starscape {
  public static let bound = 8
  public static let screenHeight = 4.0
  public static let examples = [
    CoefficientPoint(1, -1, 2), CoefficientPoint(2, -2, 4),
    CoefficientPoint(2, 1, 1), CoefficientPoint(1, 0, 1), CoefficientPoint(3, 2, 2),
  ]
  public static func points(bound: Int = bound) -> [CoefficientPoint] {
    guard (2...12).contains(bound) else { return [] }
    var result: [CoefficientPoint] = []
    for a in 1..<bound {
      for c in 1...(bound - a) {
        for b in -bound...bound {
          let point = CoefficientPoint(a, b, c)
          if point.isStar { result.append(point) }
        }
      }
    }
    return result
  }
}
