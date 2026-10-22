// SPDX-License-Identifier: GPL-3.0-or-later

/// A temporary choice among visible primitive directions; it does not change the target.
public struct ProjectedSelection: Equatable, Sendable {
  public let points: [LatticePoint]
  public private(set) var index: Int
  public var point: LatticePoint { points[index] }
  public var canGoBack: Bool { index > 0 }
  public var canGoForward: Bool { index + 1 < points.count }

  public init?(near point: LatticePoint, bound: Int) {
    points = LatticePoint.grid(bound: bound)
      .filter { $0.p > 0 && $0.q > 0 && $0.isPrimitive }
      .sorted { $0.p * $1.q < $1.p * $0.q }
    guard let index = points.firstIndex(of: point) else { return nil }
    self.index = index
  }

  public mutating func move(_ delta: Int) {
    index += delta < 0 ? max(delta, -index) : min(delta, points.count - 1 - index)
  }
}
