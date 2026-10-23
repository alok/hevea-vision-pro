// SPDX-License-Identifier: GPL-3.0-or-later
// Ported from this project's browser WebXR/mobius.js (same author, same license), after Harriss, Stange and Trettel,
// Algebraic Number Starscapes §4.2.2.
import Foundation

/// A real Möbius transformation g = [[p, q], [r, s]] with determinant 1. It moves every root z to (pz + q)/(rz + s)
/// and pushes coefficients forward as Q ↦ Q∘g⁻¹:
///   a′ = s²a − rs·b + r²c,  b′ = −2qs·a + (ps + qr)·b − 2pr·c,  c′ = q²a − pq·b + p²c,
/// which keeps Δ. Under any g the base integer triples keep their exact identities; only an integer g (SL₂(ℤ))
/// maps the lattice to itself.
public struct Mobius: Equatable, Sendable {
  public let p, q, r, s: Double
  public static let identity = Mobius(unchecked: 1, 0, 0, 1)
  public static let t = Mobius(unchecked: 1, 1, 0, 1)
  public static let tInverse = Mobius(unchecked: 1, -1, 0, 1)
  public static let sGenerator = Mobius(unchecked: 0, -1, 1, 0)

  init(unchecked p: Double, _ q: Double, _ r: Double, _ s: Double) {
    (self.p, self.q, self.r, self.s) = (p, q, r, s)
  }
  /// Supported entry size: far beyond any drag, small enough that every action and Snap stays finite.
  public static let maximumEntry = 1e6
  /// Rescaled to determinant 1; nil for a nonfinite matrix, a nonpositive determinant (not in SL₂(ℝ)) or an entry
  /// beyond `maximumEntry` after rescaling, so a caller keeps its previous g rather than silently substituting the
  /// identity.
  public init?(_ p: Double, _ q: Double, _ r: Double, _ s: Double) {
    let det = p * s - q * r
    guard [p, q, r, s, det].allSatisfy(\.isFinite), det > 0 else { return nil }
    let k = 1 / det.squareRoot()
    guard [p, q, r, s].allSatisfy({ abs($0 * k) <= Mobius.maximumEntry }) else { return nil }
    if det == 1 {
      self.init(unchecked: p, q, r, s)
    } else {
      let k = 1 / det.squareRoot()
      self.init(unchecked: p * k, q * k, r * k, s * k)
    }
  }
  public var entries: [Double] { [p, q, r, s] }
  public var isIdentity: Bool { self == .identity }
  public static func * (g: Mobius, h: Mobius) -> Mobius? {
    Mobius(g.p * h.p + g.q * h.r, g.p * h.q + g.q * h.s, g.r * h.p + g.s * h.r, g.r * h.q + g.s * h.s)
  }
  public var inverse: Mobius { Mobius(unchecked: s, -q, -r, p) }

  /// g·z on the upper half-plane.
  public func act(_ z: SIMD2<Double>) -> SIMD2<Double> {
    let nx = p * z.x + q, ny = p * z.y, dx = r * z.x + s, dy = r * z.y, d = dx * dx + dy * dy
    return SIMD2((nx * dx + ny * dy) / d, (ny * dx - nx * dy) / d)
  }
  /// g·t on the real projective line, with ∞ as .infinity.
  public func act(real t: Double) -> Double {
    guard t.isFinite else { return r == 0 ? .infinity : p / r }
    let d = r * t + s
    return d == 0 ? .infinity : (p * t + q) / d
  }

  /// The matrix sending z to i.
  static func toI(_ z: SIMD2<Double>) -> Mobius {
    let t = z.y.squareRoot()
    return Mobius(unchecked: 1 / t, -z.x / t, 0, t)
  }
  /// The symmetric positive-definite element sending i to w: the pure translation along their geodesic.
  static func fromI(_ w: SIMD2<Double>) -> Mobius {
    let m = (w.x * w.x + w.y * w.y) / w.y, n = w.x / w.y, k = 1 / w.y, t = (m + k + 2).squareRoot()
    return Mobius(unchecked: (m + 1) / t, n / t, n / t, (k + 1) / t)
  }
  /// The hyperbolic transvection carrying z0 to z1 along their geodesic, with no extra rotation; nil off the
  /// upper half-plane.
  public static func transvection(from z0: SIMD2<Double>, to z1: SIMD2<Double>) -> Mobius? {
    guard z0.y > 0, z1.y > 0, [z0.x, z0.y, z1.x, z1.y].allSatisfy(\.isFinite) else { return nil }
    let h = toI(z0)
    guard let lifted = fromI(h.act(z1)) * h else { return nil }
    return h.inverse * lifted
  }
  /// One drag step: the point under the pointer at z0 follows it to z1 (composed on the left).
  public func dragged(from z0: SIMD2<Double>, to z1: SIMD2<Double>) -> Mobius? {
    guard let step = Mobius.transvection(from: z0, to: z1) else { return nil }
    return step * self
  }

  /// The 3×3 coefficient pushforward, row-major, acting on (a, b, c).
  public var pushforward: [Double] {
    [s * s, -r * s, r * r, -2 * q * s, p * s + q * r, -2 * p * r, q * q, -p * q, p * p]
  }
  /// The drawn (real) coefficients of a base point under g.
  public func image(of point: CoefficientPoint) -> SIMD3<Double> {
    let m = pushforward, (a, b, c) = (Double(point.a), Double(point.b), Double(point.c))
    return SIMD3(m[0] * a + m[1] * b + m[2] * c, m[3] * a + m[4] * b + m[5] * c, m[6] * a + m[7] * b + m[8] * c)
  }
  /// Display position J·ρ(g)·(a, b, c) = (−b′, a′ + c′, c′ − a′).
  public func displayVector(of point: CoefficientPoint) -> SIMD3<Double> {
    let v = image(of: point)
    return SIMD3(-v.y, v.x + v.z, v.z - v.x)
  }

  /// The integer matrix, when g is one exactly.
  public var integral: IntegralMobius? {
    guard entries.allSatisfy({ $0 == $0.rounded() && abs($0) <= Double(1 << 20) }) else { return nil }
    let m = IntegralMobius(p: Int(p), q: Int(q), r: Int(r), s: Int(s))
    return m.p * m.s - m.q * m.r == 1 ? m : nil
  }
  /// Rotation angle about i in the polar decomposition g = P·R(θ), folded into (−π/2, π/2] since ±g act alike.
  public var polarAngle: Double {
    var theta = atan2(r - q, p + s)
    while theta > .pi / 2 { theta -= .pi }
    while theta <= -.pi / 2 { theta += .pi }
    return theta
  }
  /// Snap, by her viewer's criterion: reduce g·i into the standard fundamental domain by integer translations and
  /// inversions m (rounding halves toward +∞, as her viewer's Math.round does); γ = m⁻¹ sends i to the orbit point in
  /// that cell. Of γ and γS (S fixes i), keep γ unless γS's residual turns less about i by more than 1e−12, her
  /// tie tolerance; signed with positive trace. Nil if g·i or the reduction leaves the finite exact range, so the
  /// caller keeps its state.
  public var nearestIntegral: IntegralMobius? {
    var w = act(SIMD2(0, 1)), m = IntegralMobius.identity
    let bound = Double(1 << 20)
    var reduced = false
    for _ in 0..<200 {
      guard w.x.isFinite, w.y.isFinite, w.y > 0, abs(w.x) <= bound else { return nil }
      let n = Int((w.x + 0.5).rounded(.down))
      if n != 0 { w.x -= Double(n); m = IntegralMobius(p: 1, q: -n, r: 0, s: 1) * m }
      if w.x * w.x + w.y * w.y < 1 - 1e-12 {
        w = Mobius.sGenerator.act(w); m = IntegralMobius.sGenerator * m
      } else { reduced = true; break }
      guard [m.p, m.q, m.r, m.s].allSatisfy({ $0.magnitude <= UInt(1 << 20) }) else { return nil }
    }
    guard reduced else { return nil }
    let gamma = m.inverse, candidates = [gamma, gamma * IntegralMobius.sGenerator]
    func turn(_ c: IntegralMobius) -> Double {
      let residual = c.inverse.asMobius
      let product = Mobius(
        unchecked: residual.p * p + residual.q * r, residual.p * q + residual.q * s,
        residual.r * p + residual.s * r, residual.r * q + residual.s * s)
      return abs(product.polarAngle)
    }
    let best = turn(candidates[1]) < turn(candidates[0]) - 1e-12 ? candidates[1] : candidates[0]
    let trace = best.p + best.s
    return trace > 0 || (trace == 0 && (best.p != 0 ? best.p : best.r) > 0) ? best : best.negated
  }
}

/// An exact element of SL₂(ℤ) (determinant 1), the only transformations that map the integer lattice to itself.
public struct IntegralMobius: Equatable, Sendable {
  public let p, q, r, s: Int
  public static let identity = IntegralMobius(p: 1, q: 0, r: 0, s: 1)
  public static let sGenerator = IntegralMobius(p: 0, q: -1, r: 1, s: 0)
  public static func * (g: IntegralMobius, h: IntegralMobius) -> IntegralMobius {
    IntegralMobius(p: g.p * h.p + g.q * h.r, q: g.p * h.q + g.q * h.s, r: g.r * h.p + g.s * h.r, s: g.r * h.q + g.s * h.s)
  }
  public var inverse: IntegralMobius { IntegralMobius(p: s, q: -q, r: -r, s: p) }
  public var negated: IntegralMobius { IntegralMobius(p: -p, q: -q, r: -r, s: -s) }
  public var asMobius: Mobius { Mobius(unchecked: Double(p), Double(q), Double(r), Double(s)) }

  /// The exact image γ·(a, b, c), refusing anything whose arithmetic would overflow or leave the supported exact domain
  /// (|coefficients| ≤ 2²⁰), so a caller can keep its previous state rather than crash or round.
  public func image(of point: CoefficientPoint) throws -> CoefficientPoint {
    let bound = 1 << 20
    func checked(_ terms: [(Int, Int)]) throws -> Int {
      var sum = 0
      for (k, x) in terms {
        let (product, o1) = k.multipliedReportingOverflow(by: x)
        let (next, o2) = sum.addingReportingOverflow(product)
        guard !o1, !o2 else { throw MobiusError.outOfExactDomain }
        sum = next
      }
      guard sum.magnitude <= UInt(bound) else { throw MobiusError.outOfExactDomain }
      return sum
    }
    guard [p, q, r, s, point.a, point.b, point.c].allSatisfy({ $0.magnitude <= UInt(bound) }) else {
      throw MobiusError.outOfExactDomain
    }
    let (a, b, c) = (point.a, point.b, point.c)
    return CoefficientPoint(
      try checked([(s * s, a), (-r * s, b), (r * r, c)]),
      try checked([(-2 * q * s, a), (p * s + q * r, b), (-2 * p * r, c)]),
      try checked([(q * q, a), (-p * q, b), (p * p, c)]))
  }
}

public enum MobiusError: Error, Equatable, Sendable {
  case outOfExactDomain
  public var message: String { "This integer image leaves the supported exact range (|coefficients| ≤ 2²⁰); nothing changed." }
}

/// Our Klein coordinates (u, v) = (X/Y, Z/Y) of display (X, Y, Z) to the upper root, or nil outside the disk.
/// The upper half-plane point seen along a display direction from the coefficient origin, as in her eye-at-origin
/// drag: the Klein point (X/Y, Z/Y) taken to H². Both signs of the line give the same point, since (a,b,c) and
/// (−a,−b,−c) share their roots; nil off the cone's interior, on Y = 0, or for non-finite input.
public func upperPoint(displayDirection d: SIMD3<Double>) -> SIMD2<Double>? {
  guard d.y != 0, d.x.isFinite, d.y.isFinite, d.z.isFinite else { return nil }
  return kleinToUpper(d.x / d.y, d.z / d.y)
}

public func kleinToUpper(_ u: Double, _ v: Double) -> SIMD2<Double>? {
  let h = 1 - u * u - v * v
  guard h > 0, 1 - v > 0 else { return nil }
  return SIMD2(u / (1 - v), h.squareRoot() / (1 - v))
}

extension Mobius {
  /// A real projective point under g, as shown (g moves the base roots; the base values stay the exact identity).
  public func shown(real values: [Double]) -> [Double] { values.map { act(real: $0) } }
  /// A compact approximate label for a real projective point: three decimals, or ∞. Values that round to zero print as
  /// 0.000, never −0.000 (the root of x² + 1 is −0/2, which is negative zero).
  public static func approximateLabel(_ t: Double) -> String {
    t.isFinite ? String(format: "%.3f", abs(t) < 5e-4 ? 0 : t) : "∞"
  }
  /// A compact approximate label for a point of the upper half-plane, x + yi.
  public static func approximateLabel(_ z: SIMD2<Double>) -> String {
    "\(approximateLabel(z.x)) + \(approximateLabel(z.y))i"
  }
}

extension CoefficientPoint {
  /// The real roots of a boundary or exterior form as projective values (∞ for a root at infinity); nil otherwise.
  public var realRootValues: [Double]? {
    switch kind {
    case .null?: return a == 0 ? [.infinity, .infinity] : Array(repeating: -Double(b) / Double(2 * a), count: 2)
    case .exterior?: return (try? CuttingPlane.fromNormal(self).get())?.endpoints.map(\.value)
    default: return nil
    }
  }
}
