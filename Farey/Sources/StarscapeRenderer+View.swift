// SPDX-License-Identifier: GPL-3.0-or-later
import RealityKit
import SwiftUI

#if canImport(FareyCore)
  import FareyCore
#endif

// Placement, the Möbius view's helpers and receipts; none of these touch the renderer's private state.
extension StarscapeRenderer {
  /// Where the coefficient object sits relative to the viewer. Overview is the stationary default. Origin and
  /// Inhabit place it once, relative to the head center at the moment they are chosen (a `.once` head anchor: the
  /// system uses the head pose that once; the app reads no tracking transform and needs no additional sensing
  /// authorization; the object stays world-stationary afterwards, so real head motion gives parallax). Origin puts the coefficient origin, the zero polynomial, at that head center; it is not a
  /// point of the projective picture, and the two eyes sit a few centimetres either side of it. Origin also turns
  /// the object so the upper nappe's axis (+Y) points where the viewer was looking (Rx(−π/2)), or the lower
  /// nappe's (Rx(π/2)): a presentation rotation of the object, not a walk in hyperbolic space. Inhabit puts a
  /// chosen point `inhabitEye` from the head center, upright in the anchor's frame.
  enum Placement: Equatable {
    case overview
    case origin(facingLower: Bool)
    case inhabit(CoefficientPoint)
    var anchored: Bool { self != .overview }
    var isOrigin: Bool { if case .origin = self { true } else { false } }
    /// Same anchor: an Origin nappe flip keeps the anchor; any other change re-anchors at the current head.
    func sharesAnchor(with other: Placement) -> Bool {
      switch (self, other) {
      case (.origin, .origin): return true
      case (.inhabit(let a), .inhabit(let b)): return a == b
      default: return false
      }
    }
  }
  var placementReceipt: String {
    switch placement {
    case .overview: return ""
    case .origin(let lower): return " · origin at head center, \(lower ? "lower" : "upper") nappe ahead"
    case .inhabit(let point): return " · inhabiting \(point.label)"
    }
  }

  var groupReceipt: String {
    guard !group.isIdentity else { return "" }
    return " · g = [" + group.entries.map { String(format: "%.2f", $0) }.joined(separator: ", ") + "]"
  }
  /// A base point's drawn display coordinates under g.
  func viewVector(_ point: CoefficientPoint) -> SIMD3<Double> {
    group.isIdentity ? point.vector : group.displayVector(of: point)
  }
  /// Radial projection to the screen Y = h of the moved positive representative (projection after g); nil off the
  /// interior.
  func projectedView(_ point: CoefficientPoint) -> SIMD3<Double>? {
    guard let representative = point.positiveRepresentative else { return nil }
    let v = viewVector(representative)
    guard v.y > 0 else { return nil }
    return v * (Starscape.screenHeight / v.y)
  }
  func ringMaterial(_ rgb: SIMD3<Double>) -> UnlitMaterial {
    var ring = UnlitMaterial(applyPostProcessToneMap: false)
    ring.color = .init(tint: UIColor(red: rgb.x, green: rgb.y, blue: rgb.z, alpha: 1))
    ring.faceCulling = .front
    return ring
  }
}
