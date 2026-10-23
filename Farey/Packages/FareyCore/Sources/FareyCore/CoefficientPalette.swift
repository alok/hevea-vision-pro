// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// The browser's default discriminant palette (WebXR/appearance.js): upper-interior |Δ| on Stange's fixed range,
/// t = clamp(log(|Δ|/3) / log(240/3)), mapped onto canonical Viridis over [0.2, 1]; exterior, boundary and lower
/// categories use our CVD-checked swatches. Colors are sRGB components in 0...1.
public enum CoefficientPalette {
  public static let range = (low: 3.0, high: 240.0)
  public static let viridisStart = 0.2
  public static let exterior = rgb(0x7a5230)
  public static let boundary = rgb(0xf4f2ff)
  public static let lower = rgb(0x4d3a46)

  /// The browser's guide colors: cone and projection-disk cyan, the cone's rim and ray lines, and the selection ray.
  public static let guideCyan = rgb(0x54e9f5)
  public static let guideLine = rgb(0x7896a8)
  public static let selectionRay = rgb(0xbacbd6)

  /// WebGL blends sRGB-encoded values, so alpha a over black shows a·c; RealityKit blends in linear light, where
  /// the same a shows toLinear⁻¹(a·toLinear(c)), much brighter for faint guides. This returns the linear-light
  /// alpha that reproduces the browser's value over black for color's brightest channel.
  public static func linearLightOpacity(_ alpha: Double, color: SIMD3<Double>) -> Double {
    let c = max(color.x, color.y, color.z)
    guard c > 0 else { return alpha }
    return linear(alpha * c) / linear(c)
  }
  static func linear(_ s: Double) -> Double { s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4) }

  static func rgb(_ hex: Int) -> SIMD3<Double> {
    SIMD3(Double((hex >> 16) & 0xff), Double((hex >> 8) & 0xff), Double(hex & 0xff)) / 255
  }
  public static func position(_ magnitude: Double) -> Double {
    min(1, max(0, log(magnitude / range.low) / log(range.high / range.low)))
  }
  public static func sample(_ t: Double) -> SIMD3<Double> {
    let table = Viridis.table
    let x = (viridisStart + (1 - viridisStart) * min(1, max(0, t))) * Double(table.count - 1)
    let i = min(table.count - 2, Int(x.rounded(.down))), f = x - Double(i)
    return table[i] * (1 - f) + table[i + 1] * f
  }
  /// colorLower is our optional extension: lower-interior forms use the ramp too.
  public static func color(for point: CoefficientPoint, colorLower: Bool = false) -> SIMD3<Double>? {
    switch point.kind {
    case nil: return nil
    case .null: return boundary
    case .exterior: return exterior
    case .lower where !colorLower: return lower
    case .upper, .lower: return sample(position(Double(-point.discriminant)))
    }
  }
  /// Stange's whole-lattice star radius factor away from the origin eye: 0.72 for a nonprimitive interior form
  /// that is colored by the ramp; every other point uses the standard radius.
  public static func radiusFactor(for point: CoefficientPoint, colorLower: Bool = false) -> Double {
    guard point.discriminant < 0, point.a > 0 || colorLower else { return 1 }
    return point.isPrimitive ? 1 : 0.72
  }
}
