// SPDX-License-Identifier: GPL-3.0-or-later

/// A positive lattice point and the primitive direction it represents.
/// Coordinates are (q,p); the zero axes are boundaries, not selectable directions.
public struct PointInspection: Equatable, Sendable {
  public let point: LatticePoint
  public let divisor: Int64
  public let primitive: Rational
  public init?(_ point: LatticePoint) {
    guard point.p > 0, point.q > 0 else { return nil }
    var a = point.p
    var b = point.q
    while b != 0 { (a, b) = (b, a % b) }
    self.point = point
    divisor = a
    primitive = Rational(point.p / a, point.q / a)
  }
  public var equation: String {
    "(\(point.q), \(point.p)) = \(divisor) × (\(primitive.q), \(primitive.p))"
  }
  public var reduction: String { "\(point.rational) = \(primitive)" }
  public var gcdDescription: String { "gcd(\(point.q), \(point.p)) = \(divisor)" }
}
