// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

#if canImport(FareyCore)
  import FareyCore
#endif

/// Picking points directly: a pick in the Roots window or the immersive scene selects it, or, with Pair next armed,
/// pairs it with the selection. A rejected pick changes neither the selection nor the pair.
extension GalleryModel {
  var originDragAnchor: OriginDragAnchor? {
    get { coefficientInput.originDrag }
    set { coefficientInput.originDrag = newValue }
  }
  var pairNext: Bool { coefficientInput.pairNext }
  func armPairNext(_ armed: Bool) {
    coefficientInput.pairNext = armed
    coefficientPairError = nil
  }
  func activateCoefficient(_ point: CoefficientPoint) {
    if coefficientInput.pairNext { pairPicked(point) } else { select(point) }
  }
  /// Pairs a picked point with the selection; it must be displayed now and interior, in another direction (sign
  /// partners included). Success disarms Pair next; a rejection keeps it armed so another point can be picked.
  @discardableResult func pairPicked(_ point: CoefficientPoint) -> Bool {
    guard CoefficientBall.shown(point, radius: coefficientRadius, upperOnly: coefficientUpperOnly) else {
      coefficientPairError = "That point is not displayed at this radius or filter; the pair is unchanged."
      return false
    }
    if case .failure(let error) = CuttingPlane.pair(coefficient, point) {
      coefficientPairError = error.message
      return false
    }
    coefficientSecond = point
    coefficientPairError = nil
    coefficientInput.pairNext = false
    revision += 1
    return true
  }
}
