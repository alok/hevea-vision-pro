// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

#if canImport(FareyCore)
  import FareyCore
#endif

/// Transient input of the coefficient scene: an Origin drag in progress, and whether the next picked point pairs with
/// the selection. Reset and leaving the space clear it.
struct CoefficientInput {
  var originDrag: OriginDragAnchor?
  var pairNext = false
}

/// An Origin drag in progress: its previous display direction and the placement it began under. A step under any
/// other placement (a nappe flip, a new Origin, Reset, leaving the space) starts afresh rather than jumping.
struct OriginDragAnchor {
  var direction: SIMD3<Double>
  var placement: StarscapeRenderer.Placement
  var epoch: Int
  var moved = false
}

/// The Möbius view: roots-pane drags, her Symmetry generators, Snap and Identity (see GalleryModel.coefficientGroup).
extension GalleryModel {
  /// One roots-pane drag step: the root under the pointer at z0 follows it to z1. A step that would leave the
  /// supported domain is refused and g is kept.
  func dragRoots(from z0: SIMD2<Double>, to z1: SIMD2<Double>) {
    guard let next = coefficientGroup.dragged(from: z0, to: z1) else {
      coefficientGroupError = "That drag leaves the supported range; g is unchanged."
      return
    }
    coefficientGroup = next
    coefficientGroupError = nil
    revision += 1
  }
  /// Her drag with the eye at the origin: the forms along display direction `d0` follow to `d1`, the same step as a
  /// roots-pane drag between their roots. A direction off the cone's interior has no anchor, so nothing moves.
  func dragOrigin(from d0: SIMD3<Double>, to d1: SIMD3<Double>) {
    guard let z0 = upperPoint(displayDirection: d0), let z1 = upperPoint(displayDirection: d1) else { return }
    dragRoots(from: z0, to: z1)
  }
  /// One step of an Origin drag gesture, given the pointer's display direction. Only at Origin in the coefficient
  /// scene; a first step, or the first under a changed placement, only records the direction.
  func originDragStep(to direction: SIMD3<Double>) {
    guard starscapeMode, coefficientPlacement.isOrigin else {
      originDragAnchor = nil
      return
    }
    var moved = false
    if let anchor = originDragAnchor, anchor.placement == coefficientPlacement, anchor.epoch == coefficientPlacementEpoch {
      let before = revision
      dragOrigin(from: anchor.direction, to: direction)
      moved = anchor.moved || revision != before
    }
    originDragAnchor = OriginDragAnchor(
      direction: direction, placement: coefficientPlacement, epoch: coefficientPlacementEpoch, moved: moved)
  }
  /// Ends an Origin drag. Only a completed gesture that moved g under the placement it is still in may Snap; a
  /// cancelled one (`completed: false`) just forgets its direction.
  func endOriginDrag(completed: Bool) {
    if completed, let anchor = originDragAnchor, anchor.moved, anchor.placement == coefficientPlacement,
      anchor.epoch == coefficientPlacementEpoch {
      endRootsDrag()
    }
    originDragAnchor = nil
  }
  func endRootsDrag() { if coefficientSnap { snapGroup() } }
  /// Her Snap: settle on the nearest integer γ and absorb it.
  func snapGroup() {
    guard let gamma = coefficientGroup.nearestIntegral else {
      coefficientGroupError = "Snap needs a g within the supported range; nothing changed."
      return
    }
    absorb(gamma)
  }
  /// T, T⁻¹, S compose on the left; an integer result is absorbed, as Snap is.
  func applyGenerator(_ generator: Mobius) {
    guard let next = generator * coefficientGroup else {
      coefficientGroupError = "That step leaves the supported range; g is unchanged."
      return
    }
    if let gamma = next.integral { absorb(gamma) } else {
      coefficientGroup = next
      coefficientGroupError = nil
      revision += 1
    }
  }
  /// The lattice is invariant under γ ∈ SL₂(ℤ), so g = γ draws the same picture as g = 1 with every point relabelled
  /// by γ: the selection and pair become their exact images and g returns to 1. Identity afterwards does not undo
  /// this; Reset does. An image beyond the exact range is refused with every state unchanged.
  func absorb(_ gamma: IntegralMobius) {
    do {
      let selected = try gamma.image(of: coefficient)
      let second = try coefficientSecond.map { try gamma.image(of: $0) }
      coefficient = selected
      coefficientSecond = second
      coefficientGroup = .identity
      coefficientGroupError = nil
    } catch {
      coefficientGroupError = (error as? MobiusError)?.message ?? "\(error)"
      return
    }
    revision += 1
  }
  func identityGroup() {
    coefficientGroup = .identity
    coefficientGroupError = nil
    revision += 1
  }
}
