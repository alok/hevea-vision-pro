// SPDX-License-Identifier: GPL-3.0-or-later

/// Presentation focus, independent of the target rational and inspected lattice point.
public struct ApproximantSpotlight: Equatable, Sendable {
  public private(set) var rational: Rational?
  private var target: Rational?
  public init() {}
  @discardableResult public mutating func focus(
    _ rational: Rational, in state: FareyState, alternate: Bool
  ) -> Bool {
    guard state.cfPoints(alternate: alternate).contains(where: { $0.rational == rational }) else {
      return false
    }
    self.rational = rational
    target = state.mediant
    return true
  }
  public mutating func reconcile(with state: FareyState, alternate: Bool) {
    guard let rational else { return }
    if target != state.mediant
      || !state.cfPoints(alternate: alternate).contains(where: { $0.rational == rational }) {
      clear()
    }
  }
  public mutating func clear() { rational = nil; target = nil }
}
