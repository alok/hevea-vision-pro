import Foundation

/// Reference-typed failure from the finite-mesh certificate gates. Keeping the
/// diagnostic payload in a dedicated error also lets callers distinguish a
/// rejected mesh from malformed input (`HeveaCoreError`).
public final class SphereMeshValidationError: Error, @unchecked Sendable, CustomStringConvertible {
    public enum Kind: String, Codable, Equatable, Sendable {
        case topology
        case seam
        case containingRadius
    }

    public let kind: Kind
    public let reason: String

    public init(kind: Kind, reason: String) {
        self.kind = kind
        self.reason = reason
    }

    public var description: String {
        "Reduced-sphere \(kind.rawValue) validation failed: \(reason)"
    }
}

public struct SphereSeamReport: Codable, Equatable, Sendable {
    public let claimClass: ClaimClass
    public let longitudeSampleCount: Int
    public let maximumPositionResidual: Double
    public let maximumFirstDerivativeResidual: Double
    public let maximumNormalAngleRadians: Double
    public let proxyFamiliesAreZeroAtSeam: Bool

    public var allValuesAreFinite: Bool {
        maximumPositionResidual.isFinite
            && maximumFirstDerivativeResidual.isFinite
            && maximumNormalAngleRadians.isFinite
    }
}

public struct SphereTopologyReport: Codable, Equatable, Sendable {
    public let claimClass: ClaimClass
    public let vertexCount: Int
    public let edgeCount: Int
    public let triangleCount: Int
    public let eulerCharacteristic: Int
    public let boundaryEdgeCount: Int
    public let nonManifoldEdgeCount: Int
    public let inconsistentOrientationEdgeCount: Int
    public let degenerateTriangleCount: Int
    public let invertedTriangleCount: Int
    public let minimumDoubledTriangleArea: Double

    public var isClosedOrientedGenusZero: Bool {
        eulerCharacteristic == 2
            && boundaryEdgeCount == 0
            && nonManifoldEdgeCount == 0
            && inconsistentOrientationEdgeCount == 0
            && degenerateTriangleCount == 0
            && invertedTriangleCount == 0
    }
}

public struct SphereContainingRadiusReport: Codable, Equatable, Sendable {
    public let claimClass: ClaimClass
    public let measuredMaximumRadius: Double
    public let declaredMaximumRadius: Double
    public let margin: Double
    public let passes: Bool

    public var allValuesAreFinite: Bool {
        measuredMaximumRadius.isFinite
            && declaredMaximumRadius.isFinite
            && margin.isFinite
    }
}

public struct SphereMeshDiagnosticReport: Codable, Equatable, Sendable {
    public let claimClass: ClaimClass
    public let topology: SphereTopologyReport
    public let seam: SphereSeamReport
    public let containingRadius: SphereContainingRadiusReport
    public let deterministicFingerprint: String
    public let claimCeiling: String

    public var passes: Bool {
        topology.isClosedOrientedGenusZero
            && seam.allValuesAreFinite
            && containingRadius.passes
            && containingRadius.allValuesAreFinite
    }
}

public enum SphereMeshDiagnostics {
    public static let minimumDoubledTriangleArea = 1e-14
    public static let maximumSeamPositionResidual = 1e-10
    public static let maximumSeamNormalAngleRadians = 1e-7
    public static let containingRadiusTolerance = 1e-10

    public static func validate(
        _ mesh: SphereMesh,
        configuration: SphereConfiguration = .default
    ) throws -> SphereMeshDiagnosticReport {
        try configuration.validate()
        guard mesh.grid == configuration.grid else {
            throw HeveaCoreError.invalidSphereConfiguration(
                reason: "diagnostic configuration grid differs from mesh grid"
            )
        }
        let topology = try topologyReport(mesh)
        try requireValidTopology(topology)

        let seam = seamReport(stage: mesh.stage, configuration: configuration)
        try requireValidSeam(seam)

        let measured = mesh.positions.map(\.length).max() ?? .infinity
        let declared = mesh.manifest.declaredContainingRadius
        let containing = SphereContainingRadiusReport(
            claimClass: .heveaVisionExperiment,
            measuredMaximumRadius: measured,
            declaredMaximumRadius: declared,
            margin: declared - measured,
            passes: measured.isFinite && measured <= declared + containingRadiusTolerance
        )
        try requireValidContainingRadius(containing)

        return SphereMeshDiagnosticReport(
            claimClass: .heveaVisionExperiment,
            topology: topology,
            seam: seam,
            containingRadius: containing,
            deterministicFingerprint: mesh.deterministicFingerprint,
            claimCeiling: "Finite-mesh topology, seam, and radius measurements only; not an isometry or limiting-map proof."
        )
    }

    // Keep failure gates as small no-return functions. Besides making the
    // fail-closed order explicit, this avoids coupling error paths to the
    // comparatively large diagnostic-report return value under optimization.
    @inline(never)
    private static func requireValidTopology(_ topology: SphereTopologyReport) throws {
        guard topology.isClosedOrientedGenusZero else {
            throw SphereMeshValidationError(
                kind: .topology,
                reason: "Euler=\(topology.eulerCharacteristic), boundary=\(topology.boundaryEdgeCount), nonmanifold=\(topology.nonManifoldEdgeCount), orientation=\(topology.inconsistentOrientationEdgeCount), degenerate=\(topology.degenerateTriangleCount), inverted=\(topology.invertedTriangleCount)"
            )
        }
    }

    @inline(never)
    private static func requireValidSeam(_ seam: SphereSeamReport) throws {
        guard seam.maximumPositionResidual <= maximumSeamPositionResidual,
              seam.maximumNormalAngleRadians <= maximumSeamNormalAngleRadians,
              seam.proxyFamiliesAreZeroAtSeam
        else {
            throw SphereMeshValidationError(
                kind: .seam,
                reason: "position=\(seam.maximumPositionResidual), normal=\(seam.maximumNormalAngleRadians) rad, zeroProxyAtSeam=\(seam.proxyFamiliesAreZeroAtSeam)"
            )
        }
    }

    @inline(never)
    private static func requireValidContainingRadius(
        _ containing: SphereContainingRadiusReport
    ) throws {
        guard containing.passes else {
            throw SphereMeshValidationError(
                kind: .containingRadius,
                reason: "measured=\(containing.measuredMaximumRadius), declared=\(containing.declaredMaximumRadius)"
            )
        }
    }

    public static func topologyReport(_ mesh: SphereMesh) throws -> SphereTopologyReport {
        struct Edge: Hashable {
            let low: UInt32
            let high: UInt32
        }
        struct EdgeStats {
            var incidenceCount = 0
            var orientationBalance = 0
        }

        guard mesh.triangleIndices.count.isMultiple(of: 3) else {
            throw HeveaCoreError.sphereTopologyViolation(
                reason: "triangle-index count is not divisible by three"
            )
        }
        var edges: [Edge: EdgeStats] = [:]
        edges.reserveCapacity(mesh.grid.vertexCount + mesh.grid.triangleCount)
        var degenerateCount = 0
        var invertedCount = 0
        var minimumArea = Double.infinity

        func retainEdge(_ start: UInt32, _ end: UInt32) {
            let edge = Edge(low: min(start, end), high: max(start, end))
            var stats = edges[edge] ?? EdgeStats()
            stats.incidenceCount += 1
            stats.orientationBalance += start < end ? 1 : -1
            edges[edge] = stats
        }

        for triangle in 0..<mesh.grid.triangleCount {
            let offset = triangle * 3
            let aIndex = mesh.triangleIndices[offset]
            let bIndex = mesh.triangleIndices[offset + 1]
            let cIndex = mesh.triangleIndices[offset + 2]
            retainEdge(aIndex, bIndex)
            retainEdge(bIndex, cIndex)
            retainEdge(cIndex, aIndex)

            let a = mesh.positions[Int(aIndex)]
            let b = mesh.positions[Int(bIndex)]
            let c = mesh.positions[Int(cIndex)]
            let cross = Vector3.cross(b - a, c - a)
            let doubledArea = cross.length
            guard doubledArea.isFinite else {
                throw HeveaCoreError.nonFiniteValue(
                    context: "sphere triangle \(triangle) area"
                )
            }
            minimumArea = min(minimumArea, doubledArea)
            if doubledArea <= minimumDoubledTriangleArea {
                degenerateCount += 1
                continue
            }
            let expected = mesh.normals[Int(aIndex)]
                + mesh.normals[Int(bIndex)]
                + mesh.normals[Int(cIndex)]
            let orientationDot = Vector3.dot(cross, expected)
            if !orientationDot.isFinite || orientationDot <= 0 {
                invertedCount += 1
            }
        }

        let boundary = edges.values.filter { $0.incidenceCount == 1 }.count
        let nonManifold = edges.values.filter { $0.incidenceCount != 2 }.count
        let inconsistentOrientation = edges.values.filter {
            $0.incidenceCount == 2 && $0.orientationBalance != 0
        }.count
        let euler = mesh.grid.vertexCount - edges.count + mesh.grid.triangleCount
        return SphereTopologyReport(
            claimClass: .heveaVisionExperiment,
            vertexCount: mesh.grid.vertexCount,
            edgeCount: edges.count,
            triangleCount: mesh.grid.triangleCount,
            eulerCharacteristic: euler,
            boundaryEdgeCount: boundary,
            nonManifoldEdgeCount: nonManifold,
            inconsistentOrientationEdgeCount: inconsistentOrientation,
            degenerateTriangleCount: degenerateCount,
            invertedTriangleCount: invertedCount,
            minimumDoubledTriangleArea: minimumArea
        )
    }

    public static func seamReport(
        stage: SphereStage,
        configuration: SphereConfiguration = .default
    ) -> SphereSeamReport {
        guard stage != .unitSphere else {
            return SphereSeamReport(
                claimClass: .heveaVisionExperiment,
                longitudeSampleCount: configuration.grid.longitudeCount,
                maximumPositionResidual: 0,
                maximumFirstDerivativeResidual: 0,
                maximumNormalAngleRadians: 0,
                proxyFamiliesAreZeroAtSeam: true
            )
        }

        let yInfinity = JudddReducedSphereProfile.yInfinity
        var maximumPositionResidual = 0.0
        var maximumDerivativeResidual = 0.0
        var maximumNormalAngle = 0.0
        var familiesAreZero = true

        for longitudeIndex in 0..<configuration.grid.longitudeCount {
            let longitude = configuration.grid.longitude(at: longitudeIndex)
            for cap in SphereCap.allCases {
                let latitude = cap == .south ? -yInfinity : yInfinity
                let profile = JudddReducedSphereProfile.uncheckedEvaluate(latitude: latitude)
                let ribbonPosition = Vector3(
                    x: profile.radial * cos(longitude),
                    y: profile.radial * sin(longitude),
                    z: profile.height
                )
                var capPosition = ReducedSphereExactGeometry.uncheckedRoundPosition(
                    longitude: longitude,
                    latitude: latitude
                )
                capPosition.z += cap == .south
                    ? JudddReducedSphereProfile.eta
                    : -JudddReducedSphereProfile.eta
                maximumPositionResidual = max(
                    maximumPositionResidual,
                    Vector3.distance(ribbonPosition, capPosition)
                )

                let ribbonLongitudeDerivative = Vector3(
                    x: -profile.radial * sin(longitude),
                    y: profile.radial * cos(longitude),
                    z: 0
                )
                let capLongitudeDerivative = Vector3(
                    x: -cos(latitude) * sin(longitude),
                    y: cos(latitude) * cos(longitude),
                    z: 0
                )
                let ribbonLatitudeDerivative = Vector3(
                    x: profile.radialDerivative * cos(longitude),
                    y: profile.radialDerivative * sin(longitude),
                    z: profile.heightDerivative
                )
                let capLatitudeDerivative = Vector3(
                    x: -sin(latitude) * cos(longitude),
                    y: -sin(latitude) * sin(longitude),
                    z: cos(latitude)
                )
                maximumDerivativeResidual = max(
                    maximumDerivativeResidual,
                    Vector3.distance(ribbonLongitudeDerivative, capLongitudeDerivative),
                    Vector3.distance(ribbonLatitudeDerivative, capLatitudeDerivative)
                )
                let ribbonNormal = Vector3.cross(
                    ribbonLongitudeDerivative,
                    ribbonLatitudeDerivative
                )
                let capNormal = Vector3.cross(
                    capLongitudeDerivative,
                    capLatitudeDerivative
                )
                maximumNormalAngle = max(
                    maximumNormalAngle,
                    Vector3.angle(ribbonNormal, capNormal) ?? .infinity
                )

                for family in configuration.proxySchedule.corrugations.prefix(
                    stage.appliedCorrugationCount
                ) {
                    let support = yInfinity * family.supportHalfWidthFraction
                    if abs(latitude) < support { familiesAreZero = false }
                }
            }
        }

        return SphereSeamReport(
            claimClass: .heveaVisionExperiment,
            longitudeSampleCount: configuration.grid.longitudeCount,
            maximumPositionResidual: maximumPositionResidual,
            maximumFirstDerivativeResidual: maximumDerivativeResidual,
            maximumNormalAngleRadians: maximumNormalAngle,
            proxyFamiliesAreZeroAtSeam: familiesAreZero
        )
    }
}
