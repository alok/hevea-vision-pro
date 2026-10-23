// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

#if canImport(FareyCore)
  import FareyCore
#endif

/// Where the Roots window draws each upper interior form, and which star a location picks; hover and tap share it.
struct RootsLayout {
  struct Star { let point: CoefficientPoint; let center: CGPoint; let radius: Double; let rgb: SIMD3<Double> }
  let size: CGSize
  let stars: [Star]
  var scale: Double { size.width / 2.4 }
  var cy: Double { (size.height / 2 - 28) / scale }

  /// Each base form (a, b, c), a > 0, Δ < 0, at the root of its image under g, with radius 0.03·scale/a′; smaller
  /// stars first, so larger ones draw on top.
  init(size: CGSize, group g: Mobius, crop: StarscapeRenderer.Crop) {
    let scale = size.width / 2.4, cy = (size.height / 2 - 28) / scale
    var result: [Star] = []
    for point in CoefficientBall.points(radius: crop.radius, upperOnly: crop.upperOnly)
    where point.a > 0 && point.discriminant < 0 {
      let image = g.isIdentity ? SIMD3(Double(point.a), Double(point.b), Double(point.c)) : g.image(of: point)
      let a1 = image.x, root = SIMD2(-image.y / (2 * a1), Double(-point.discriminant).squareRoot() / (2 * a1))
      guard let rgb = CoefficientPalette.color(for: point, colorLower: crop.colorLower) else { continue }
      let center = CGPoint(x: size.width / 2 + root.x * scale, y: size.height / 2 - (root.y - cy) * scale)
      result.append(Star(point: point, center: center, radius: 0.03 * scale / a1, rgb: rgb))
    }
    self.size = size
    self.stars = result.sorted { $0.radius < $1.radius }
  }
  func screen(_ z: SIMD2<Double>) -> CGPoint {
    CGPoint(x: size.width / 2 + z.x * scale, y: size.height / 2 - (z.y - cy) * scale)
  }
  /// The upper half-plane point under a location, or nil on or below the real axis (no anchor there).
  func root(at p: CGPoint) -> SIMD2<Double>? {
    let z = SIMD2((p.x - size.width / 2) / scale, cy - (p.y - size.height / 2) / scale)
    return z.y > 1e-6 ? z : nil
  }
  /// Where named stars are drawn, as fractions of the window (x right, y down), for tests that tap them: e.g.
  /// " · at (1, 0, 1) 0.5000,0.4000".
  func locations(of points: [CoefficientPoint]) -> String {
    points.compactMap { point in
      stars.first { $0.point == point }.map {
        String(format: " · at %@ %.4f,%.4f", point.label, $0.center.x / size.width, $0.center.y / size.height)
      }
    }.joined()
  }
  /// The star nearest a location within max(7 pt, its radius); multiples share a root, so stars within half a point
  /// of the nearest tie and the largest (visible) one wins.
  func pick(at location: CGPoint) -> Star? {
    let near = stars.map { star in (star, hypot(star.center.x - location.x, star.center.y - location.y)) }
      .filter { $0.1 <= max(7, $0.0.radius) }
    guard let nearest = near.map(\.1).min() else { return nil }
    return near.filter { $0.1 <= nearest + 0.5 }.max { $0.0.radius < $1.0.radius }?.0
  }
}
