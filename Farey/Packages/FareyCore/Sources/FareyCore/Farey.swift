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
  public init() {}
  public var mediant: Rational { left.mediant(right) }
  public var determinant: Int64 { right.p * left.q - left.p * right.q }
  public var wordLabel: String { word.isEmpty ? "Start" : word.map(\.rawValue).joined() }
  public var matrixLabel: String { "[\(right.p)  \(left.p); \(right.q)  \(left.q)]" }
  public var canStep: Bool { word.count < Self.maxSteps }
  @discardableResult public mutating func step(_ turn: Turn) -> Bool {
    guard canStep else { return false }
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

  /// Circular arcs orthogonal to the unit circle; diameters are a separate case.
  public static func geodesic(_ start: Point2, _ end: Point2, segments: Int = 32) -> [Point2] {
    let count = max(2, segments)
    let determinant = start.x * end.y - start.y * end.x
    if abs(determinant) < 1e-10 {
      return (0...count).map { i in
        let t = Double(i) / Double(count)
        return Point2(start.x * (1 - t) + end.x * t, start.y * (1 - t) + end.y * t)
      }
    }
    let cx = (end.y - start.y) / determinant
    let cy = (start.x - end.x) / determinant
    let radius = sqrt(max(0, cx * cx + cy * cy - 1))
    let angle = atan2(start.y - cy, start.x - cx)
    var delta = atan2(end.y - cy, end.x - cx) - angle
    if delta > .pi { delta -= 2 * .pi }
    if delta < -.pi { delta += 2 * .pi }
    var result = (0...count).map { i in
      let theta = angle + delta * Double(i) / Double(count)
      return Point2(cx + radius * cos(theta), cy + radius * sin(theta))
    }
    result[0] = start
    result[count] = end
    return result
  }
}
