// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

public enum ConstructionStage: Int, CaseIterable, Sendable {
  case boundary, direction, lattice, plane
  public var title: String { ["Boundary chart", "Direction", "Integer lattice", "Direction plane"][rawValue] }
}

public enum BoundaryConstruction {
  /// Intersection of a positive-q ray with q=1, in (p,q) storage order.
  /// The display uses floating coordinates; the label p/q remains rational.
  public static func project(_ point: LatticePoint) -> Point2? {
    guard point.q > 0, point.p >= 0 else { return nil }
    return Point2(Double(point.p) / Double(point.q), 1)
  }
}
