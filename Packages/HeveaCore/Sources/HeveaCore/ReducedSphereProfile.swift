/*
 HeveaCore is GPL-3.0-or-later.

 This file adapts the deterministic reduced-sphere profile from
 https://github.com/Juddd/hevea-reduced-sphere at revision
 c098ea6fabb994bdd2555719b64ebbe8d7fca483 (GPL-3.0).

 Retained upstream notice:
 "The reduced-sphere profile, characteristic-flow implementation, numerical
 certificates, CMake integration and Wolfram Language wrapper in this
 repository are a separate reimplementation. They are not an official release
 of the paper's authors or of the Hévéa project."

 That repository states that its generic corrugation and numerical-integration
 ideas adapt the GPL Hévéa project and that its sphere construction follows
 Bartzos, Borrelli, Denis, Lazarus, Rohmer, and Thibert, DOI
 10.1007/s10208-017-9360-1.

 Modification notice: Alok Singh with OpenAI Codex, 2026-08-29. The profile
 evaluation was translated from C++ to bounded, platform-neutral Swift. The
 convex-integration flow was NOT copied. HeveaCore adds visibly lower-frequency
 explanatory displacements that remain REAL-TIME PROXY geometry, not the
 paper's f_{1,3}, the authors' unpublished profile, or the limiting C1 map.
*/

import Foundation

public struct ReducedSphereProfilePoint: Codable, Equatable, Sendable {
    public let radial: Double
    public let height: Double
    public let radialDerivative: Double
    public let heightDerivative: Double

    public var isFinite: Bool {
        radial.isFinite
            && height.isFinite
            && radialDerivative.isFinite
            && heightDerivative.isFinite
    }
}

/// A GPL-attributed constrained reconstruction of the paper's unpublished
/// initial ribbon. It is deliberately identified as a real-time proxy.
public enum JudddReducedSphereProfile {
    public static let sourceRepositoryURL = "https://github.com/Juddd/hevea-reduced-sphere"
    public static let sourceRevision = "c098ea6fabb994bdd2555719b64ebbe8d7fca483"
    public static let sourcePath = "src/reduced_sphere_profile.hpp"
    public static let licenseIdentifier = "GPL-3.0"
    public static let stableIdentifier = "profile-20260725-author-envelope-paper-flow-certified-v5"
    public static let yInfinity = 1.5358895
    public static let certifiedContainingRadius = 0.52
    public static let eta = 0.5

    /// Ten coefficients of the symmetric degree-thirteen constrained profile.
    /// They are not the paper authors' unpublished degree-nine coefficients.
    public static let coefficients: [Double] = [
        -0.52164358694220492,
        -0.024827807054374828,
        1.0452244736858278,
        -1.3656657598369506,
        0.54300716429149642,
        -0.38685452062281694,
        0.31457715720002261,
        -0.61976108254554241,
        1.1664678885754221,
        -0.73680735226233729,
    ]

    public static func evaluate(latitude: Double) throws -> ReducedSphereProfilePoint {
        guard latitude.isFinite, abs(latitude) <= yInfinity + 1e-12 else {
            throw HeveaCoreError.invalidSphereConfiguration(
                reason: "profile latitude must lie in [-yInfinity, yInfinity]"
            )
        }
        let result = uncheckedEvaluate(latitude: min(yInfinity, max(-yInfinity, latitude)))
        guard result.isFinite, result.radial > 0 else {
            throw HeveaCoreError.nonFiniteValue(context: "Juddd reduced-sphere profile")
        }
        return result
    }

    static func uncheckedEvaluate(latitude: Double) -> ReducedSphereProfilePoint {
        let u = latitude / yInfinity
        let t = 1 - u * u
        let t2 = t * t
        let t3 = t2 * t
        let t4 = t3 * t
        let t5 = t4 * t
        let t6 = t5 * t
        let cosine = cos(yInfinity)
        let sine = sin(yInfinity)
        let a = yInfinity * sine / 2
        let q0 = sine - eta
        let q1 = (q0 - yInfinity * cosine) / 2
        let values = coefficients

        let radial = cosine + a * t
            + values[0] * t2
            + values[1] * t3
            + values[2] * t4
            + values[3] * t5
            + values[4] * t6
        let q = q0 + q1 * t
            + values[5] * t2
            + values[6] * t3
            + values[7] * t4
            + values[8] * t5
            + values[9] * t6
        let radialDerivative = (-2 * u / yInfinity) * (
            a
                + 2 * values[0] * t
                + 3 * values[1] * t2
                + 4 * values[2] * t3
                + 5 * values[3] * t4
                + 6 * values[4] * t5
        )
        let heightDerivative = (q - 2 * u * u * (
            q1
                + 2 * values[5] * t
                + 3 * values[6] * t2
                + 4 * values[7] * t3
                + 5 * values[8] * t4
                + 6 * values[9] * t5
        )) / yInfinity

        return ReducedSphereProfilePoint(
            radial: radial,
            height: u * q,
            radialDerivative: radialDerivative,
            heightDerivative: heightDerivative
        )
    }
}

public enum SphereCap: String, Codable, CaseIterable, Equatable, Sendable {
    case south
    case north
}

/// Exact formulas printed in the reduced-sphere paper, kept separate from the
/// reconstructed central-ribbon proxy.
public enum ReducedSphereExactGeometry {
    public static func roundPosition(longitude: Double, latitude: Double) throws -> Vector3 {
        try validateAngles(longitude: longitude, latitude: latitude)
        return uncheckedRoundPosition(longitude: longitude, latitude: latitude)
    }

    public static func roundLongitudeDerivative(
        longitude: Double,
        latitude: Double
    ) throws -> Vector3 {
        try validateAngles(longitude: longitude, latitude: latitude)
        let radial = cos(latitude)
        return Vector3(
            x: -radial * sin(longitude),
            y: radial * cos(longitude),
            z: 0
        )
    }

    public static func roundLatitudeDerivative(
        longitude: Double,
        latitude: Double
    ) throws -> Vector3 {
        try validateAngles(longitude: longitude, latitude: latitude)
        return Vector3(
            x: -sin(latitude) * cos(longitude),
            y: -sin(latitude) * sin(longitude),
            z: cos(latitude)
        )
    }

    /// The south cap is translated by `+eta` and the north cap by `-eta` in z.
    public static func translatedCapPosition(
        longitude: Double,
        latitude: Double,
        cap: SphereCap,
        eta: Double = JudddReducedSphereProfile.eta
    ) throws -> Vector3 {
        try validateAngles(longitude: longitude, latitude: latitude)
        guard eta.isFinite, eta > 0 else {
            throw HeveaCoreError.invalidSphereConfiguration(
                reason: "translated-cap eta must be finite and positive"
            )
        }
        guard (cap == .south && latitude <= 0) || (cap == .north && latitude >= 0) else {
            throw HeveaCoreError.invalidSphereConfiguration(
                reason: "translated-cap latitude lies in the wrong hemisphere"
            )
        }
        var result = uncheckedRoundPosition(longitude: longitude, latitude: latitude)
        result.z += cap == .south ? eta : -eta
        return result
    }

    static func uncheckedRoundPosition(longitude: Double, latitude: Double) -> Vector3 {
        let radial = cos(latitude)
        return Vector3(
            x: radial * cos(longitude),
            y: radial * sin(longitude),
            z: sin(latitude)
        )
    }

    private static func validateAngles(longitude: Double, latitude: Double) throws {
        guard longitude.isFinite,
              latitude.isFinite,
              (-Double.pi / 2 - 1e-12...Double.pi / 2 + 1e-12).contains(latitude)
        else {
            throw HeveaCoreError.nonFiniteValue(context: "sphere longitude/latitude")
        }
    }
}
