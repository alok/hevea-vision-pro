// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

public struct Rational: Hashable, Sendable, CustomStringConvertible {
  public let p: Int64
  public let q: Int64
  public init(_ p: Int64, _ q: Int64) {
    self.p = p
    self.q = q
  }
  public var description: String { q == 0 ? "∞" : "\(p)/\(q)" }
  public func mediant(_ other: Self) -> Self { Self(p + other.p, q + other.q) }
  public var diskPoint: Point2 {
    let a = Double(p)
    let b = Double(q)
    let norm = a * a + b * b
    return Point2(2 * a * b / norm, (a * a - b * b) / norm)
  }
}

public struct Point2: Sendable, Equatable {
  public let x: Double
  public let y: Double
  public init(_ x: Double, _ y: Double) {
    self.x = x
    self.y = y
  }
  public var lengthSquared: Double { x * x + y * y }
}

public enum Turn: String, Sendable {
  case l = "L"
  case r = "R"
}

/// M is multiplied on the right. Its columns are the endpoints M(∞), M(0).
/// L = [1 1; 0 1], R = [1 0; 1 1], agreeing with Stange's talk convention.
public struct FareyState: Equatable, Sendable {
  public static let maxSteps = 24
  public private(set) var word: [Turn] = []
  public private(set) var right = Rational(1, 0)
  public private(set) var left = Rational(0, 1)
  public private(set) var selectedPoint: LatticePoint?
  public init() {}
  public var mediant: Rational { left.mediant(right) }
  public var determinant: Int64 { right.p * left.q - left.p * right.q }
  public var wordLabel: String { word.isEmpty ? "Start" : word.map(\.rawValue).joined() }
  public var matrixLabel: String { "[\(right.p)  \(left.p); \(right.q)  \(left.q)]" }
  public var canStep: Bool { word.count < Self.maxSteps }
  public var inspection: PointInspection? {
    PointInspection(selectedPoint ?? LatticePoint(p: mediant.p, q: mediant.q))
  }
  @discardableResult public mutating func step(_ turn: Turn) -> Bool {
    guard canStep else { return false }
    selectedPoint = nil
    switch turn {
    case .l: left = mediant
    case .r: right = mediant
    }
    word.append(turn)
    return true
  }
  public mutating func undo() {
    let prefix = word.dropLast()
    self = Self()
    for turn in prefix { step(turn) }
  }
  public mutating func reset() { self = Self() }
  /// Select a positive rational by its finite Stern–Brocot interval path.
  /// The visible fraction is M(1); appending R would put it in M(∞).
  @discardableResult public mutating func select(_ target: Rational) -> Bool {
    guard target.p > 0, target.q > 0, target.p <= 1000, target.q <= 1000 else { return false }
    var candidate = Self()
    while candidate.mediant.p * target.q != target.p * candidate.mediant.q {
      guard candidate.canStep else { return false }
      candidate.step(candidate.mediant.p * target.q < target.p * candidate.mediant.q ? .l : .r)
    }
    candidate.selectedPoint = LatticePoint(p: target.p, q: target.q)
    self = candidate
    return true
  }
  public var history: [FareyEdge] {
    var state = Self()
    var result = [FareyEdge(left: state.left, right: state.right, depth: 0)]
    for turn in word {
      state.step(turn)
      result.append(FareyEdge(left: state.left, right: state.right, depth: result.count))
    }
    return result
  }
}

/// Integer lattice coordinates are (q,p), so a rational is a direction p/q.
public struct LatticePoint: Hashable, Sendable {
  public let p: Int64
  public let q: Int64
  public init(p: Int64, q: Int64) {
    self.p = p
    self.q = q
  }
  public var rational: Rational { Rational(p, q) }
  public func isOnRay(_ direction: Rational) -> Bool {
    p * direction.q == q * direction.p
  }
  public var isPrimitive: Bool {
    var a = p
    var b = q
    while b != 0 { (a, b) = (b, a % b) }
    return a == 1
  }
  public static func grid(bound: Int) -> [Self] {
    let n = Int64(min(14, max(6, bound)))
    return (0...n).flatMap { q in
      (0...n).compactMap { p in p == 0 && q == 0 ? nil : Self(p: p, q: q) }
    }
  }
}

public struct FareyEdge: Sendable {
  public let left: Rational
  public let right: Rational
  public let depth: Int
  public init(left: Rational, right: Rational, depth: Int) {
    self.left = left
    self.right = right
    self.depth = depth
  }
  public var determinant: Int64 { right.p * left.q - left.p * right.q }
  public var samples: [Point2] { Geometry.geodesic(left.diskPoint, right.diskPoint) }
}

public enum Geometry {
  /// Two reflected Stern–Brocot trees cover both halves of the Farey disk.
  /// Finite truncation: depth 3...8, at most 1,021 distinct geodesics.
  public static func tessellation(depth: Int) -> [FareyEdge] {
    let limit = min(8, max(3, depth))
    var edges = [FareyEdge(left: Rational(0, 1), right: Rational(1, 0), depth: 0)]
    func visit(_ left: Rational, _ right: Rational, _ level: Int) {
      guard level < limit else { return }
      let middle = left.mediant(right)
      edges.append(FareyEdge(left: left, right: middle, depth: level + 1))
      edges.append(FareyEdge(left: middle, right: right, depth: level + 1))
      visit(left, middle, level + 1)
      visit(middle, right, level + 1)
    }
    visit(Rational(0, 1), Rational(1, 0), 0)
    visit(Rational(-1, 0), Rational(0, 1), 0)
    return edges
  }

  /// A stable rational-quadratic parametrization of the geodesic between unit-boundary points.
  /// The origin is the tangent intersection; its weight is half the endpoint chord length.
  public static func geodesic(_ start: Point2, _ end: Point2, segments: Int = 32) -> [Point2] {
    let count = max(2, segments)
    let weight = min(1, hypot(end.x - start.x, end.y - start.y) / 2)
    return (0...count).map { index in
      let t = Double(index) / Double(count)
      let a = (1 - t) * (1 - t)
      let b = t * t
      let denominator = a + b + 2 * weight * t * (1 - t)
      return Point2((a * start.x + b * end.x) / denominator,
        (a * start.y + b * end.y) / denominator)
    }
  }
}
