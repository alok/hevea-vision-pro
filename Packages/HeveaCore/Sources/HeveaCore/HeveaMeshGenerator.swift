/*
 HeveaCore is GPL-3.0-or-later.

 The short-torus formula in this file is an independent Swift adaptation of
 the GPL Hévéa implementation by Vincent Borrelli, Saïd Jabrane, Francis
 Lazarus, and Boris Thibert (Copyright 2012), pinned in `UpstreamSourceManifest`.

 Modification notice: Alok Singh with OpenAI Codex, 2026-08-29. The formula was
 adapted to a bounded platform-neutral Swift mesh and paired with newly written,
 low-frequency explanatory proxies. Those proxies are NOT the upstream
 corrugations and are never evidence of the limiting C1 isometric embedding.
*/

import Foundation

public enum HeveaMeshGenerator {
    public static func generate(
        stage: HeveaStage,
        configuration: TorusConfiguration = .default
    ) throws -> HeveaMesh {
        try configuration.validate()

        let grid = configuration.grid
        var positions: [Vector3] = []
        var normals: [Vector3] = []
        var textureCoordinates: [Vector2] = []
        var corrugationMagnitudes: [Double] = []
        positions.reserveCapacity(grid.vertexCount)
        normals.reserveCapacity(grid.vertexCount)
        textureCoordinates.reserveCapacity(grid.vertexCount)
        corrugationMagnitudes.reserveCapacity(grid.vertexCount)

        let derivativeSteps = finiteDifferenceSteps(stage: stage, configuration: configuration)

        for uIndex in 0..<grid.uCount {
            for vIndex in 0..<grid.vCount {
                let point = grid.parameterPoint(u: uIndex, v: vIndex)
                let base = shortTorusPosition(at: point, configuration: configuration)
                let position = uncheckedPosition(
                    at: point,
                    stage: stage,
                    configuration: configuration
                )
                let normal = try finiteDifferenceNormal(
                    at: point,
                    stage: stage,
                    configuration: configuration,
                    uStep: derivativeSteps.u,
                    vStep: derivativeSteps.v,
                    coordinate: GridCoordinate(u: uIndex, v: vIndex)
                )

                guard position.isFinite, base.isFinite else {
                    throw HeveaCoreError.nonFiniteValue(
                        context: "\(stage.rawValue) position at (\(uIndex), \(vIndex))"
                    )
                }
                positions.append(position)
                normals.append(normal)
                textureCoordinates.append(grid.textureCoordinate(u: uIndex, v: vIndex))
                corrugationMagnitudes.append(Vector3.distance(position, base))
            }
        }

        let manifest = HeveaMeshManifest(
            stage: stage,
            grid: grid,
            minorRadius: configuration.minorRadius,
            majorRadius: configuration.majorRadius,
            appliedProxyCorrugations: Array(
                configuration.proxySchedule.corrugations.prefix(stage.appliedCorrugationCount)
            )
        )

        let preliminary = try HeveaMesh(
            stage: stage,
            grid: grid,
            positions: positions,
            normals: normals,
            textureCoordinates: textureCoordinates,
            triangleIndices: grid.triangleIndices(),
            scalarFields: [],
            manifest: manifest
        )
        let metricReport = try MetricDiagnostics.analyze(preliminary)
        let fields = [
            try MeshScalarField(
                name: MetricDiagnostics.scalarFieldName,
                displayName: "HV EXPERIMENT — finite-difference metric residual",
                claimClass: .heveaVisionExperiment,
                units: "dimensionless Frobenius norm",
                values: metricReport.residuals
            ),
            try MeshScalarField(
                name: "proxyDisplacementMagnitude",
                displayName: "REAL-TIME PROXY — displacement from short torus",
                claimClass: .realTimeProxy,
                units: "model units",
                values: corrugationMagnitudes
            ),
        ]

        return try HeveaMesh(
            stage: stage,
            grid: grid,
            positions: positions,
            normals: normals,
            textureCoordinates: textureCoordinates,
            triangleIndices: preliminary.triangleIndices,
            scalarFields: fields,
            manifest: manifest
        )
    }

    /// Evaluates the deterministic finite stage at any parameter point. Proxy
    /// stages remain explanatory surfaces even when sampled more densely.
    public static func position(
        at point: ParameterPoint,
        stage: HeveaStage,
        configuration: TorusConfiguration = .default
    ) throws -> Vector3 {
        try configuration.validate()
        guard point.isFinite else {
            throw HeveaCoreError.nonFiniteValue(context: "surface parameter")
        }
        let result = uncheckedPosition(at: point.wrapped, stage: stage, configuration: configuration)
        guard result.isFinite else {
            throw HeveaCoreError.nonFiniteValue(context: "surface position")
        }
        return result
    }

    private static func uncheckedPosition(
        at point: ParameterPoint,
        stage: HeveaStage,
        configuration: TorusConfiguration
    ) -> Vector3 {
        let wrapped = point.wrapped
        var result = shortTorusPosition(at: wrapped, configuration: configuration)
        guard stage.appliedCorrugationCount > 0 else { return result }

        let baseNormal = shortTorusNormal(at: wrapped)
        for corrugation in configuration.proxySchedule.corrugations
            .prefix(stage.appliedCorrugationCount)
        {
            let latticePhase = Double(corrugation.direction.u) * wrapped.u
                + Double(corrugation.direction.v) * wrapped.v
            let phase = 2 * Double.pi * Double(corrugation.frequency) * latticePhase
            result = result + baseNormal * (corrugation.amplitude * sin(phase))
        }
        return result
    }

    private static func shortTorusPosition(
        at point: ParameterPoint,
        configuration: TorusConfiguration
    ) -> Vector3 {
        let uAngle = 2 * Double.pi * point.u
        let vAngle = 2 * Double.pi * point.v
        let scale = 1 / (2 * Double.pi)
        let radial = (configuration.majorRadius + configuration.minorRadius * cos(uAngle)) * scale
        return Vector3(
            x: radial * cos(vAngle),
            y: radial * sin(vAngle),
            z: configuration.minorRadius * sin(uAngle) * scale
        )
    }

    private static func shortTorusNormal(at point: ParameterPoint) -> Vector3 {
        let uAngle = 2 * Double.pi * point.u
        let vAngle = 2 * Double.pi * point.v
        return Vector3(
            x: cos(uAngle) * cos(vAngle),
            y: cos(uAngle) * sin(vAngle),
            z: sin(uAngle)
        )
    }

    private static func finiteDifferenceSteps(
        stage: HeveaStage,
        configuration: TorusConfiguration
    ) -> (u: Double, v: Double) {
        let applied = configuration.proxySchedule.corrugations.prefix(stage.appliedCorrugationCount)
        let maximumUFrequency = applied.map {
            abs($0.direction.u) * $0.frequency
        }.max() ?? 1
        let maximumVFrequency = applied.map {
            abs($0.direction.v) * $0.frequency
        }.max() ?? 1
        let uResolution = max(configuration.grid.uCount * 4, maximumUFrequency * 16)
        let vResolution = max(configuration.grid.vCount * 4, maximumVFrequency * 16)
        return (u: 1 / Double(uResolution), v: 1 / Double(vResolution))
    }

    private static func finiteDifferenceNormal(
        at point: ParameterPoint,
        stage: HeveaStage,
        configuration: TorusConfiguration,
        uStep: Double,
        vStep: Double,
        coordinate: GridCoordinate
    ) throws -> Vector3 {
        let beforeU = uncheckedPosition(
            at: ParameterPoint(u: point.u - uStep, v: point.v),
            stage: stage,
            configuration: configuration
        )
        let afterU = uncheckedPosition(
            at: ParameterPoint(u: point.u + uStep, v: point.v),
            stage: stage,
            configuration: configuration
        )
        let beforeV = uncheckedPosition(
            at: ParameterPoint(u: point.u, v: point.v - vStep),
            stage: stage,
            configuration: configuration
        )
        let afterV = uncheckedPosition(
            at: ParameterPoint(u: point.u, v: point.v + vStep),
            stage: stage,
            configuration: configuration
        )
        let derivativeU = (afterU - beforeU) / (2 * uStep)
        let derivativeV = (afterV - beforeV) / (2 * vStep)

        // Parameter order is (tube, revolution), so dv × du faces outward.
        guard let normal = Vector3.cross(derivativeV, derivativeU).normalized() else {
            throw HeveaCoreError.degenerateNormal(u: coordinate.u, v: coordinate.v)
        }
        return normal
    }
}
