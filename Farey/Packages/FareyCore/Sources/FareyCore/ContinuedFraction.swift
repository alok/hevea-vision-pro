// SPDX-License-Identifier: GPL-3.0-or-later

/// Finite simple continued fractions of a positive rational.
/// Canonical terms end in at least 2, except for a single integer term.
public struct ContinuedFraction: Equatable, Sendable {
  public let canonical: [Int64]
  public init?(_ rational: Rational) {
    guard rational.p > 0, rational.q > 0 else { return nil }
    var p = rational.p
    var q = rational.q
    var terms: [Int64] = []
    while q != 0 {
      terms.append(p / q)
      (p, q) = (q, p % q)
    }
    canonical = terms
  }
  public func terms(alternate: Bool) -> [Int64] {
    guard alternate, let last = canonical.last else { return canonical }
    return canonical.dropLast() + [last - 1, 1]
  }
  public func label(alternate: Bool) -> String {
    let terms = terms(alternate: alternate)
    guard let first = terms.first else { return "[]" }
    return terms.count == 1 ? "[\(first)]"
      : "[\(first); \(terms.dropFirst().map(String.init).joined(separator: ", "))]"
  }
  public func convergents(alternate: Bool) -> [Rational] {
    var previous = Rational(1, 0)
    var before = Rational(0, 1)
    return terms(alternate: alternate).map { term in
      let next = Rational(term * previous.p + before.p, term * previous.q + before.q)
      before = previous
      previous = next
      return next
    }
  }
}

public struct CFPoint: Equatable, Sendable {
  public let rational: Rational
  public let isConvergent: Bool
  public var label: String { isConvergent ? "Convergent" : "Intermediate mediant" }
}

extension FareyState {
  /// Classifies visited mediants for the chosen finite expansion; includes 0/1 when it is a convergent.
  public func cfPoints(alternate: Bool) -> [CFPoint] {
    guard let fraction = ContinuedFraction(mediant) else { return [] }
    let convergents = fraction.convergents(alternate: alternate)
    let visited = history.map { $0.left.mediant($0.right) }
    let boundary = convergents.filter { $0.p == 0 }
    return (boundary + visited).map { CFPoint(rational: $0, isConvergent: convergents.contains($0)) }
  }
}
