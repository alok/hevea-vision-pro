// SPDX-License-Identifier: GPL-3.0-or-later
// Ported from this project's browser WebXR/pair-plane.js (same author, same license).
import Foundation

/// A coefficient plane through the origin, Lorentz-orthogonal to an exterior normal n = (A, B, C):
/// −2C·a + B·b − 2A·c = 0, equivalently B·X + (A+C)·Y + (A−C)·Z = 0 in display coordinates. Its geodesic endpoints
/// are the real roots of A t² + B t + C, kept exact: a rational, a quadratic surd, or ∞ when A = 0.
/// As in Stange's viewer, an exterior selection is its own normal and two interior points determine a plane.
/// Membership is exact integer arithmetic; drawing distances and opacity are viewing aids, not hyperbolic metrics.
public struct CuttingPlane: Equatable, Sendable {
  public enum Endpoint: Equatable, Sendable {
    case infinity
    /// p/q in lowest terms with q > 0.
    case rational(p: Int, q: Int)
    /// (p + sign·s·√r)/q in lowest terms, r squarefree and greater than 1, q > 0.
    case surd(p: Int, sign: Int, s: Int, r: Int, q: Int)

    /// The browser's labels: "-1", "1/2", "∞", "1 − √2", "(−1 + √3)/2".
    public var label: String {
      switch self {
      case .infinity: return "∞"
      case .rational(let p, let q): return q == 1 ? "\(p)" : "\(p)/\(q)"
      case .surd(let p, let sign, let s, let r, let q):
        let radical = "\(s == 1 ? "" : "\(s)")√\(r)"
        let head = p == 0 ? (sign < 0 ? "−" : "") : "\(p)".replacingOccurrences(of: "-", with: "−") + (sign < 0 ? " − " : " + ")
        return q == 1 ? head + radical : "(\(head + radical))/\(q)"
      }
    }
    public var value: Double {
      switch self {
      case .infinity: return .infinity
      case .rational(let p, let q): return Double(p) / Double(q)
      case .surd(let p, let sign, let s, let r, let q):
        return (Double(p) + Double(sign * s) * Double(r).squareRoot()) / Double(q)
      }
    }
  }

  /// Primitive, with its first nonzero coefficient positive.
  public let normal: CoefficientPoint
  public let endpoints: [Endpoint]

  /// Selecting an exterior triple uses it as the normal; a null, interior or zero triple has no real geodesic.
  public static func fromNormal(_ raw: CoefficientPoint) -> Result<CuttingPlane, CuttingPlaneError> {
    guard !raw.isZero else { return .failure(.zero) }
    guard let n = primitive(raw) else { return .failure(.tooLarge) }
    guard let delta = discriminant(n) else { return .failure(.tooLarge) }
    guard delta > 0 else { return .failure(.notExterior) }
    let (a, b, c) = (n.a, n.b, n.c)
    let endpoints: [Endpoint]
    if a == 0 {
      endpoints = [rational(-c, b), .infinity]
    } else {
      let root = isqrt(delta)
      endpoints = [-1, 1].map { sign in
        root * root == delta ? rational(-b + sign * root, 2 * a) : surd(-b, sign, delta, 2 * a)
      }
    }
    return .success(CuttingPlane(normal: n, endpoints: endpoints))
  }

  /// Two complex-root (interior) points determine the plane containing both directions; the normal is the cross
  /// product of their Lorentz duals (−2c, b, −2a). Points of one projective direction, including sign partners
  /// and multiples, determine no unique plane.
  public static func pair(_ first: CoefficientPoint, _ second: CoefficientPoint) -> Result<CuttingPlane, CuttingPlaneError> {
    for point in [first, second] {
      // Products in the dual cross product below must stay exact.
      guard [point.a, point.b, point.c].allSatisfy({ abs($0) <= 1 << 20 }), let delta = discriminant(point) else {
        return .failure(.tooLarge)
      }
      guard delta < 0 else { return .failure(.notInterior) }
    }
    func dual(_ p: CoefficientPoint) -> CoefficientPoint { CoefficientPoint(-2 * p.c, p.b, -2 * p.a) }
    let (p, q) = (dual(first), dual(second))
    let normal = CoefficientPoint(p.b * q.c - p.c * q.b, p.c * q.a - p.a * q.c, p.a * q.b - p.b * q.a)
    guard !normal.isZero else { return .failure(.sameDirection) }
    return fromNormal(normal)
  }

  public func contains(_ point: CoefficientPoint) -> Bool {
    -2 * normal.c * point.a + normal.b * point.b - 2 * normal.a * point.c == 0
  }

  /// "2a −2c = 0", in the browser's form.
  public var equation: String {
    var terms: [String] = []
    for (coefficient, variable) in [(-2 * normal.c, "a"), (normal.b, "b"), (-2 * normal.a, "c")] where coefficient != 0 {
      let magnitude = abs(coefficient)
      terms.append((coefficient < 0 ? "−" : terms.isEmpty ? "" : "+") + (magnitude == 1 ? "" : "\(magnitude)") + variable)
    }
    return terms.joined(separator: " ") + " = 0"
  }

  /// Unit-height null directions (X, Y, Z) of the two endpoints: t ↦ (sin 2θ, 1, −cos 2θ) with t = tan θ, ∞ ↦ (0, 1, 1).
  public var coneDirections: [SIMD3<Double>] {
    endpoints.map { endpoint in
      let t = endpoint.value
      guard t.isFinite else { return SIMD3(0, 1, 1) }
      let angle = 2 * atan(t)
      return SIMD3(sin(angle), 1, -cos(angle))
    }
  }

  /// The plane's patch inside the drawn double cone's bounding cylinder |Y| ≤ radius, X² + Z² ≤ radius², as a closed
  /// loop of display-coordinate points around the origin.
  public func section(radius: Double, segments: Int = 64) -> [SIMD3<Double>] {
    let (na, nb, nc) = (Double(normal.a), Double(normal.b), Double(normal.c))
    let (x, y, z) = (-nb, -na - nc, nc - na)
    let horizontal = (x * x + z * z).squareRoot(), length = (x * x + y * y + z * z).squareRoot()
    let u = SIMD3(-z / horizontal, 0, x / horizontal)
    let v = SIMD3(-x * y / (horizontal * length), horizontal / length, -z * y / (horizontal * length))
    return (0...segments).map { i in
      let angle = Double(i) / Double(segments) * 2 * .pi
      let d = u * cos(angle) + v * sin(angle)
      return d * (radius / max(abs(d.y), (d.x * d.x + d.z * d.z).squareRoot()))
    }
  }

  static func discriminant(_ p: CoefficientPoint) -> Int? {
    let (bb, o1) = p.b.multipliedReportingOverflow(by: p.b)
    let (ac, o2) = p.a.multipliedReportingOverflow(by: p.c)
    let (ac4, o3) = ac.multipliedReportingOverflow(by: 4)
    let (delta, o4) = bb.subtractingReportingOverflow(ac4)
    return o1 || o2 || o3 || o4 ? nil : delta
  }
  static func primitive(_ p: CoefficientPoint) -> CoefficientPoint? {
    let divisor = gcd(gcd(p.a, p.b), p.c)
    let sign = (p.a != 0 ? p.a : p.b != 0 ? p.b : p.c) < 0 ? -1 : 1
    let result = CoefficientPoint(p.a / divisor * sign, p.b / divisor * sign, p.c / divisor * sign)
    // Keep coefficients small enough that every product above stays exact.
    return [result.a, result.b, result.c].allSatisfy { abs($0) <= 1 << 20 } ? result : nil
  }
  static func gcd(_ x: Int, _ y: Int) -> Int {
    var (a, b) = (x.magnitude, y.magnitude)
    while b != 0 { (a, b) = (b, a % b) }
    return Int(a)
  }
  static func isqrt(_ n: Int) -> Int {
    var x = Int(Double(n).squareRoot())
    while x * x > n { x -= 1 }
    while (x + 1) * (x + 1) <= n { x += 1 }
    return x
  }
  static func rational(_ p: Int, _ q: Int) -> Endpoint {
    let d = gcd(p, q), sign = q < 0 ? -1 : 1
    return .rational(p: p / d * sign, q: q / d * sign)
  }
  /// (p ± √d)/q with d = s²·r, r squarefree, reduced by gcd(p, s, q).
  static func surd(_ p: Int, _ sign: Int, _ d: Int, _ q: Int) -> Endpoint {
    var (s, r) = (1, d)
    var f = 2
    while f * f <= r {
      while r % (f * f) == 0 { r /= f * f; s *= f }
      f += 1
    }
    let g = gcd(gcd(p, s), q), qs = q < 0 ? -1 : 1
    return .surd(p: p / g * qs, sign: sign, s: s / g, r: r, q: q / g * qs)
  }
}

public enum CuttingPlaneError: Error, Equatable, Sendable {
  case zero, notExterior, notInterior, sameDirection, tooLarge
  public var message: String {
    switch self {
    case .zero: return "The zero triple has no plane."
    case .notExterior: return "Only an exterior triple (Δ > 0) is a plane normal; this one defines no real geodesic."
    case .notInterior: return "Pair two complex-root points inside the cone (Δ < 0)."
    case .sameDirection: return "These triples have the same primitive direction and root. Choose a different root."
    case .tooLarge: return "This pair is too large for exact arithmetic here."
    }
  }
}
