/*
 The reconstructed profile used here is GPL-attributed in
 `ReducedSphereProfile.swift`. The corrugation families below are newly written,
 low-frequency explanatory displacements. They do not implement the paper's
 Bessel corrugation flow and must remain labelled REAL-TIME PROXY.
*/

import Foundation

public struct SphereSurfaceSample: Codable, Equatable, Sendable {
    public let unitDirection: Vector3
    public let longitude: Double
    public let latitude: Double
    public let position: Vector3
    public let normal: Vector3
    public let basePosition: Vector3
    public let proxyDisplacementMagnitude: Double
    public let ribbonRank: Int
    public let familyWeights: [Double]

    public var isFinite: Bool {
        unitDirection.isFinite
            && longitude.isFinite
            && latitude.isFinite
            && position.isFinite
            && normal.isFinite
            && basePosition.isFinite
            && proxyDisplacementMagnitude.isFinite
            && familyWeights.allSatisfy(\.isFinite)
    }
}

public enum SphereMeshGenerator {
    public static func generate(
        stage: SphereStage,
        configuration: SphereConfiguration = .default
    ) throws -> SphereMesh {
        try configuration.validate()
        if stage != .unitSphere,
           configuration.declaredProxyContainingRadius
            + SphereMeshDiagnostics.containingRadiusTolerance < 0.5
        {
            // The exact translated poles lie at radius 1 - eta = 0.5, so a
            // smaller declaration is impossible before any mesh is allocated.
            throw HeveaCoreError.sphereContainingRadiusExceeded(
                measured: 0.5,
                declared: configuration.declaredProxyContainingRadius
            )
        }
        let grid = configuration.grid
        let indices = try grid.triangleIndices()
        var positions: [Vector3] = []
        var normals: [Vector3] = []
        var textureCoordinates: [Vector2] = []
        var displacements: [Double] = []
        var ribbonRanks: [Double] = []
        positions.reserveCapacity(grid.vertexCount)
        normals.reserveCapacity(grid.vertexCount)
        textureCoordinates.reserveCapacity(grid.vertexCount)
        displacements.reserveCapacity(grid.vertexCount)
        ribbonRanks.reserveCapacity(grid.vertexCount)

        for index in 0..<grid.vertexCount {
            let vertex = try grid.vertex(for: index)
            let direction = try grid.unitDirection(for: vertex)
            let sample = try sample(
                at: direction,
                stage: stage,
                configuration: configuration
            )
            guard sample.isFinite else {
                throw HeveaCoreError.nonFiniteValue(
                    context: "sphere sample at vertex \(index)"
                )
            }
            positions.append(sample.position)
            normals.append(sample.normal)
            textureCoordinates.append(try grid.textureCoordinate(for: vertex))
            displacements.append(sample.proxyDisplacementMagnitude)
            ribbonRanks.append(Double(sample.ribbonRank))
        }

        let manifest = SphereMeshManifest(stage: stage, configuration: configuration)
        let seam = SphereMeshDiagnostics.seamReport(
            stage: stage,
            configuration: configuration
        )
        let seamValues = Array(
            repeating: seam.maximumPositionResidual,
            count: grid.vertexCount
        )
        let fields = [
            try MeshScalarField(
                name: "sphereProxyDisplacementMagnitude",
                displayName: "REAL-TIME PROXY — displacement from reconstructed short map",
                claimClass: .realTimeProxy,
                units: "model units",
                values: displacements
            ),
            try MeshScalarField(
                name: "sphereRibbonRank",
                displayName: "HV EXPERIMENT — active nested proxy-family count",
                claimClass: .heveaVisionExperiment,
                units: "families",
                values: ribbonRanks
            ),
            try MeshScalarField(
                name: "sphereCapSeamResidual",
                displayName: "HV EXPERIMENT — analytic cap/ribbon seam residual",
                claimClass: .heveaVisionExperiment,
                units: "model units",
                values: seamValues
            ),
        ]
        let mesh = try SphereMesh.validated(
            stage: stage,
            grid: grid,
            positions: positions,
            normals: normals,
            textureCoordinates: textureCoordinates,
            triangleIndices: indices,
            scalarFields: fields,
            manifest: manifest
        )
        _ = try SphereMeshDiagnostics.validate(mesh, configuration: configuration)
        return mesh
    }

    public static func position(
        at unitDirection: Vector3,
        stage: SphereStage,
        configuration: SphereConfiguration = .default
    ) throws -> Vector3 {
        try sample(at: unitDirection, stage: stage, configuration: configuration).position
    }

    public static func sample(
        at unitDirection: Vector3,
        stage: SphereStage,
        configuration: SphereConfiguration = .default
    ) throws -> SphereSurfaceSample {
        try configuration.validate()
        let direction = try normalizedDirection(unitDirection)
        let latitude = asin(min(1, max(-1, direction.z)))
        var longitude = atan2(direction.y, direction.x)
        if longitude < 0 { longitude += 2 * Double.pi }
        if abs(abs(latitude) - Double.pi / 2) < 1e-12 { longitude = 0 }

        let data = uncheckedSurfaceData(
            longitude: longitude,
            latitude: latitude,
            stage: stage,
            configuration: configuration
        )
        let normal = try surfaceNormal(
            longitude: longitude,
            latitude: latitude,
            stage: stage,
            configuration: configuration,
            unitDirection: direction
        )
        let sample = SphereSurfaceSample(
            unitDirection: direction,
            longitude: longitude,
            latitude: latitude,
            position: data.position,
            normal: normal,
            basePosition: data.basePosition,
            proxyDisplacementMagnitude: abs(data.displacement),
            ribbonRank: data.ribbonRank,
            familyWeights: data.familyWeights
        )
        guard sample.isFinite else {
            throw HeveaCoreError.nonFiniteValue(context: "sphere surface evaluator")
        }
        return sample
    }

    static func baseNormal(
        at unitDirection: Vector3,
        stage: SphereStage
    ) throws -> Vector3 {
        let direction = try normalizedDirection(unitDirection)
        if stage == .unitSphere { return direction }
        let latitude = asin(min(1, max(-1, direction.z)))
        if abs(latitude) >= JudddReducedSphereProfile.yInfinity { return direction }
        let longitude = atan2(direction.y, direction.x)
        let profile = JudddReducedSphereProfile.uncheckedEvaluate(latitude: latitude)
        let candidate = Vector3(
            x: profile.radial * profile.heightDerivative * cos(longitude),
            y: profile.radial * profile.heightDerivative * sin(longitude),
            z: -profile.radial * profile.radialDerivative
        )
        guard let normal = candidate.normalized() else {
            throw HeveaCoreError.degenerateNormal(u: 0, v: 0)
        }
        return normal
    }

    private struct SurfaceData {
        let position: Vector3
        let basePosition: Vector3
        let displacement: Double
        let ribbonRank: Int
        let familyWeights: [Double]
    }

    private static func uncheckedSurfaceData(
        longitude: Double,
        latitude: Double,
        stage: SphereStage,
        configuration: SphereConfiguration
    ) -> SurfaceData {
        if stage == .unitSphere {
            let position = ReducedSphereExactGeometry.uncheckedRoundPosition(
                longitude: longitude,
                latitude: latitude
            )
            return SurfaceData(
                position: position,
                basePosition: position,
                displacement: 0,
                ribbonRank: 0,
                familyWeights: [0, 0, 0]
            )
        }

        let yInfinity = JudddReducedSphereProfile.yInfinity
        let basePosition: Vector3
        let normal: Vector3
        if latitude <= -yInfinity {
            basePosition = Vector3(
                x: cos(latitude) * cos(longitude),
                y: cos(latitude) * sin(longitude),
                z: sin(latitude) + JudddReducedSphereProfile.eta
            )
            normal = ReducedSphereExactGeometry.uncheckedRoundPosition(
                longitude: longitude,
                latitude: latitude
            )
        } else if latitude >= yInfinity {
            basePosition = Vector3(
                x: cos(latitude) * cos(longitude),
                y: cos(latitude) * sin(longitude),
                z: sin(latitude) - JudddReducedSphereProfile.eta
            )
            normal = ReducedSphereExactGeometry.uncheckedRoundPosition(
                longitude: longitude,
                latitude: latitude
            )
        } else {
            let profile = JudddReducedSphereProfile.uncheckedEvaluate(latitude: latitude)
            basePosition = Vector3(
                x: profile.radial * cos(longitude),
                y: profile.radial * sin(longitude),
                z: profile.height
            )
            let candidate = Vector3(
                x: profile.radial * profile.heightDerivative * cos(longitude),
                y: profile.radial * profile.heightDerivative * sin(longitude),
                z: -profile.radial * profile.radialDerivative
            )
            normal = candidate.normalized() ?? Vector3.zero
        }

        var weights = [0.0, 0.0, 0.0]
        var displacement = 0.0
        var ribbonRank = 0
        let longitudeUnit = longitude / (2 * Double.pi)
        let applied = configuration.proxySchedule.corrugations.prefix(
            stage.appliedCorrugationCount
        )
        for (index, family) in applied.enumerated() {
            let support = yInfinity * family.supportHalfWidthFraction
            let weight = fadeWeight(
                latitude: latitude,
                support: support,
                fullStrengthFraction: family.fullStrengthFraction
            )
            weights[index] = weight
            guard weight > 0 else { continue }
            ribbonRank += 1
            let localLatitude = (latitude / support + 1) / 2
            let phaseCoordinate: Double
            switch family.primitiveDirection {
            case .diagonalPlus:
                phaseCoordinate = longitudeUnit + localLatitude
            case .diagonalMinus:
                phaseCoordinate = -longitudeUnit + localLatitude
            case .latitude:
                phaseCoordinate = localLatitude
            }
            let phase = 2 * Double.pi * Double(family.renderedRidgeCount) * phaseCoordinate
            displacement += family.amplitude * weight * sin(phase)
        }

        return SurfaceData(
            position: basePosition + normal * displacement,
            basePosition: basePosition,
            displacement: displacement,
            ribbonRank: ribbonRank,
            familyWeights: weights
        )
    }

    private static func fadeWeight(
        latitude: Double,
        support: Double,
        fullStrengthFraction: Double
    ) -> Double {
        let absoluteLatitude = abs(latitude)
        guard absoluteLatitude < support else { return 0 }
        let inner = support * fullStrengthFraction
        guard absoluteLatitude > inner else { return 1 }
        let parameter = (support - absoluteLatitude) / (support - inner)
        // Quintic smootherstep: value and first two derivatives vanish at both ends.
        return parameter * parameter * parameter
            * (parameter * (parameter * 6 - 15) + 10)
    }

    private static func surfaceNormal(
        longitude: Double,
        latitude: Double,
        stage: SphereStage,
        configuration: SphereConfiguration,
        unitDirection: Vector3
    ) throws -> Vector3 {
        if stage == .unitSphere || abs(latitude) >= JudddReducedSphereProfile.yInfinity {
            return unitDirection
        }
        let step = 1e-6
        let longitudePlus = uncheckedSurfaceData(
            longitude: longitude + step,
            latitude: latitude,
            stage: stage,
            configuration: configuration
        ).position
        let longitudeMinus = uncheckedSurfaceData(
            longitude: longitude - step,
            latitude: latitude,
            stage: stage,
            configuration: configuration
        ).position
        let latitudePlus = uncheckedSurfaceData(
            longitude: longitude,
            latitude: latitude + step,
            stage: stage,
            configuration: configuration
        ).position
        let latitudeMinus = uncheckedSurfaceData(
            longitude: longitude,
            latitude: latitude - step,
            stage: stage,
            configuration: configuration
        ).position
        let longitudeDerivative = (longitudePlus - longitudeMinus) / (2 * step)
        let latitudeDerivative = (latitudePlus - latitudeMinus) / (2 * step)
        let candidate = Vector3.cross(longitudeDerivative, latitudeDerivative)
        guard let normal = candidate.normalized(),
              Vector3.dot(normal, try baseNormal(at: unitDirection, stage: stage)) > 0
        else {
            throw HeveaCoreError.degenerateNormal(u: 0, v: 0)
        }
        return normal
    }

    private static func normalizedDirection(_ direction: Vector3) throws -> Vector3 {
        guard direction.isFinite, let normalized = direction.normalized() else {
            throw HeveaCoreError.invalidSphereAddress(
                reason: "unit direction must be finite and nonzero"
            )
        }
        return normalized
    }
}
