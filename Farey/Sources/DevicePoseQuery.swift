// SPDX-License-Identifier: GPL-3.0-or-later
import ARKit
import QuartzCore

/// One tracked device pose, for placing the object explicitly when Origin or Inhabit is chosen. A head anchor's
/// transform is not visible to the app (Apple: it reads as the identity), so gesture locations could not be measured
/// from the head; world tracking's device anchor is, and Apple documents that it needs no authorization. The pose is
/// the device's, not the head center. The session runs only for the query and is stopped on every path; nothing is
/// requested or stored beyond the returned transform.
enum DevicePoseQuery {
  enum Failure: Error, CustomStringConvertible {
    case unsupported, authorizationRequired, sessionFailed(String), notTracked, unusablePose, cancelled
    var description: String {
      switch self {
      case .unsupported: return "world tracking is not supported here"
      case .authorizationRequired: return "world tracking would need an authorization here, so it is not started"
      case .sessionFailed(let reason): return "world tracking did not start (\(reason))"
      case .notTracked: return "no tracked device pose within 3 s"
      case .unusablePose: return "the device pose was not a finite rigid transform"
      case .cancelled: return "cancelled"
      }
    }
  }
  @MainActor static func once(timeout: Duration = .seconds(3)) async -> Result<simd_float4x4, Failure> {
    guard !Task.isCancelled else { return .failure(.cancelled) }
    guard WorldTrackingProvider.isSupported else { return .failure(.unsupported) }
    guard WorldTrackingProvider.requiredAuthorizations.isEmpty else { return .failure(.authorizationRequired) }
    let session = ARKitSession(), provider = WorldTrackingProvider()
    defer { session.stop() }                                        // also after a throw or a partial start
    do { try await session.run([provider]) } catch { return .failure(.sessionFailed(error.localizedDescription)) }
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
      if Task.isCancelled { return .failure(.cancelled) }
      if provider.state == .running, let anchor = provider.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()),
        anchor.isTracked {
        let pose = anchor.originFromAnchorTransform
        return isRigid(pose) ? .success(pose) : .failure(.unusablePose)
      }
      try? await Task.sleep(for: .milliseconds(50))
    }
    return .failure(.notTracked)
  }
  /// Finite, with a (0, 0, 0, 1) bottom row and a rotation part that is orthonormal with determinant 1.
  static func isRigid(_ m: simd_float4x4, tolerance: Float = 1e-3) -> Bool {
    let columns = [m.columns.0, m.columns.1, m.columns.2, m.columns.3]
    guard columns.allSatisfy({ $0.x.isFinite && $0.y.isFinite && $0.z.isFinite && $0.w.isFinite }),
      abs(m.columns.0.w) < tolerance, abs(m.columns.1.w) < tolerance, abs(m.columns.2.w) < tolerance,
      abs(m.columns.3.w - 1) < tolerance
    else { return false }
    let r = simd_float3x3(
      SIMD3(m.columns.0.x, m.columns.0.y, m.columns.0.z), SIMD3(m.columns.1.x, m.columns.1.y, m.columns.1.z),
      SIMD3(m.columns.2.x, m.columns.2.y, m.columns.2.z))
    let gram = r.transpose * r
    let identity = matrix_identity_float3x3
    let deviation = [gram.columns.0 - identity.columns.0, gram.columns.1 - identity.columns.1, gram.columns.2 - identity.columns.2]
    return deviation.allSatisfy { simd_length($0) < tolerance } && abs(r.determinant - 1) < tolerance
  }
}
