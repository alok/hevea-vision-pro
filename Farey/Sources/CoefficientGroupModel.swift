// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

#if canImport(FareyCore)
  import FareyCore
#endif

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
