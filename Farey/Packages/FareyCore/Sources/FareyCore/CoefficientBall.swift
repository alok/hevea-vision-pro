// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// Sign category of a nonzero coefficient triple, matching the browser's double cone.
public enum CoefficientKind: Sendable { case upper, lower, null, exterior }

extension CoefficientPoint {
  public var isZero: Bool { a == 0 && b == 0 && c == 0 }
  /// Nil for the zero polynomial, which has no unique root or projective point.
  public var kind: CoefficientKind? {
    guard !isZero else { return nil }
    let delta = discriminant
    if delta == 0 { return .null }
    if delta > 0 { return .exterior }
    return a > 0 ? .upper : .lower
  }
  /// Interior forms only: ±(a,b,c) have the same roots, so a lower form uses its sign flip.
  public var positiveRepresentative: CoefficientPoint? {
    guard discriminant < 0 else { return nil }
    return a > 0 ? self : CoefficientPoint(-a, -b, -c)
  }
  public var isPrimitive: Bool {
    func gcd(_ x: Int, _ y: Int) -> Int { y == 0 ? abs(x) : gcd(y, x % y) }
    return gcd(gcd(a, b), c) == 1
  }
  /// Radial image on a+c = h of the positive representative; nil for boundary, exterior and zero.
  public func radialImage(height h: Double) -> SIMD3<Double>? {
    positiveRepresentative?.projected(height: h)
  }
  /// Upper-half-plane root shared by ±(a,b,c); nil unless the roots are complex.
  public var representativeRoot: SIMD2<Double>? { positiveRepresentative?.upperRoot }
}

/// The browser's exact signed coefficient ball: nonzero integer (a,b,c) with X²+Y²+Z² = b²+2a²+2c² ≤ R²
/// in display coordinates (X,Y,Z) = (−b, a+c, c−a). Native renders one entity per point, so its radius is
/// capped at 12 (3,608 points); the browser's dense point-primitive crops are not reproduced here.
public enum CoefficientBall {
  public static let maximumRadius = 12
  public static let radii = [4, 6, 8, 10, 12]
  public static let defaultRadius = 6
  /// The browser's Next sequence: its five examples, then a lower, a boundary and an exterior form.
  public static let nextSequence =
    Starscape.examples + [CoefficientPoint(-1, 1, -2), CoefficientPoint(1, 2, 1), CoefficientPoint(1, 3, 1)]

  /// False for unsupported radii (checked before any arithmetic) and for coefficients beyond the radius.
  public static func contains(_ point: CoefficientPoint, radius: Int) -> Bool {
    guard (1...maximumRadius).contains(radius) else { return false }
    let bound = UInt(radius)
    guard !point.isZero, point.a.magnitude <= bound, point.b.magnitude <= bound, point.c.magnitude <= bound
    else { return false }
    return point.b * point.b + 2 * point.a * point.a + 2 * point.c * point.c <= radius * radius
  }
  public static func shown(_ point: CoefficientPoint, radius: Int, upperOnly: Bool) -> Bool {
    contains(point, radius: radius) && (!upperOnly || point.kind == .upper)
  }
  /// Each (a,c) column contributes |b| ≤ ⌊√(R² − 2a² − 2c²)⌋. Empty outside 1...maximumRadius.
  public static func points(radius: Int, upperOnly: Bool = false) -> [CoefficientPoint] {
    guard (1...maximumRadius).contains(radius) else { return [] }
    var result: [CoefficientPoint] = []
    let square = radius * radius
    for a in -radius...radius {
      for c in -radius...radius {
        let rest = square - 2 * a * a - 2 * c * c
        guard rest >= 0 else { continue }
        var m = Int(Double(rest).squareRoot())
        while m * m > rest { m -= 1 }
        while (m + 1) * (m + 1) <= rest { m += 1 }
        for b in -m...m {
          let point = CoefficientPoint(a, b, c)
          if !point.isZero, !upperOnly || point.kind == .upper { result.append(point) }
        }
      }
    }
    return result
  }
}

public enum CoefficientEntryError: Error, Equatable, Sendable {
  case format, notInteger, zero, outsideBall(radius: Int)
  public var message: String {
    switch self {
    case .format: return "Enter three integers separated by commas, such as 1,-1,2."
    case .notInteger: return "Each coefficient must be an integer that fits exactly."
    case .zero: return "The zero polynomial is not a point of this lattice."
    case .outsideBall(let radius): return "That triple lies outside the radius-\(radius) ball."
    }
  }
}

/// Exact signed "a,b,c" entry. Rejects rather than clamps; the caller keeps its state on failure.
public enum CoefficientEntry {
  public static func parse(_ text: String, radius: Int) -> Result<CoefficientPoint, CoefficientEntryError> {
    let parts = text.split(separator: ",", omittingEmptySubsequences: false)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    guard parts.count == 3 else { return .failure(.format) }
    var values: [Int] = []
    for part in parts {
      let digits = part.first == "+" || part.first == "-" ? part.dropFirst() : Substring(part)
      guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return .failure(.format) }
      guard let value = Int(part) else { return .failure(.notInteger) }
      values.append(value)
    }
    let point = CoefficientPoint(values[0], values[1], values[2])
    if point.isZero { return .failure(.zero) }
    guard CoefficientBall.contains(point, radius: radius) else { return .failure(.outsideBall(radius: radius)) }
    return .success(point)
  }
}
