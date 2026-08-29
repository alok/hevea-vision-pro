/*
 HeveaScaleMicroscope is GPL-3.0-or-later.

 The experiment is deliberately deterministic and finite. Its measurements
 are descriptive observations, never theorem-level claims.
*/

import Foundation
import HeveaCore

public enum ExperimentBuild {
    #if DEBUG
    public static let configuration = "debug"
    #else
    public static let configuration = "release"
    #endif
}

public enum ExperimentRunner {
    public static func run(
        buildConfiguration: String = ExperimentBuild.configuration
    ) throws -> ExperimentReport {
        let torusConfiguration = TorusConfiguration.default
        let normalConfiguration = try NormalMicroscopeConfiguration(
            scales: [1, 2, 4, 8, 16, 32, 64],
            sampleCount: 256,
            deterministicSeed: 0x4845_5645_415F_5631
        )
        let curveConfiguration = CurveExperimentConfiguration(
            basepoint: ParameterPoint(u: 0.1375, v: 0.28125),
            segmentCount: 2_048,
            directions: [
                LatticeDirection(u: 1, v: 0),
                LatticeDirection(u: 0, v: 1),
            ]
        )
        let configurationReceipt = ExperimentConfigurationReceipt(
            torus: torusConfiguration,
            normalMicroscope: normalConfiguration,
            windingCurves: curveConfiguration,
            stages: HeveaStage.allCases
        )

        let meshes = try HeveaStage.allCases.map {
            try HeveaMeshGenerator.generate(stage: $0, configuration: torusConfiguration)
        }
        guard let shortTorusMesh = meshes.first(where: { $0.stage == .shortTorus }) else {
            throw ScaleMicroscopeExperimentError.missingStage(.shortTorus)
        }

        var stageReports: [StageExperimentReport] = []
        stageReports.reserveCapacity(meshes.count)

        for (index, mesh) in meshes.enumerated() {
            guard mesh.positions.count == shortTorusMesh.positions.count else {
                throw ScaleMicroscopeExperimentError.inconsistentVertexCount(
                    stage: mesh.stage,
                    expected: shortTorusMesh.positions.count,
                    actual: mesh.positions.count
                )
            }

            let metric = try MetricDiagnostics.analyze(mesh)
            let microscope = try NormalScaleMicroscope.analyze(
                mesh,
                configuration: normalConfiguration
            )
            let windingCurves = try curveConfiguration.directions.map { direction in
                try makeWindingCurve(
                    direction: direction,
                    mesh: mesh,
                    configuration: curveConfiguration
                )
            }

            guard let displacementField = mesh.scalarField(named: "proxyDisplacementMagnitude") else {
                throw ScaleMicroscopeExperimentError.missingScalarField(
                    name: "proxyDisplacementMagnitude",
                    stage: mesh.stage
                )
            }
            let fromShortTorus = try ScalarStatistics(summarizing: displacementField.values)

            let previousMesh = index > 0 ? meshes[index - 1] : nil
            let fromPreviousStage: ScalarStatistics?
            if let previousMesh {
                guard previousMesh.positions.count == mesh.positions.count else {
                    throw ScaleMicroscopeExperimentError.inconsistentVertexCount(
                        stage: previousMesh.stage,
                        expected: mesh.positions.count,
                        actual: previousMesh.positions.count
                    )
                }
                let distances = zip(mesh.positions, previousMesh.positions).map(Vector3.distance)
                fromPreviousStage = try ScalarStatistics(summarizing: distances)
            } else {
                fromPreviousStage = nil
            }

            stageReports.append(
                StageExperimentReport(
                    stage: mesh.stage,
                    mesh: mesh,
                    metric: MetricSummary(report: metric),
                    windingCurves: windingCurves,
                    normalMicroscope: NormalMicroscopeSummary(report: microscope),
                    displacement: ProxyDisplacementSummary(
                        fromShortTorus: fromShortTorus,
                        fromPreviousStage: fromPreviousStage,
                        previousStage: previousMesh?.stage
                    )
                )
            )
        }

        let comparison = try makeCrossStageComparison(stageReports)
        let findings = makeBoundedFindings(comparison: comparison)
        return ExperimentReport(
            run: RunReceipt(buildConfiguration: buildConfiguration),
            upstreamSource: .pinnedFlatTorus,
            configuration: configurationReceipt,
            methods: .finiteMeshV1,
            stages: stageReports,
            crossStageComparison: comparison,
            boundedFindings: findings
        )
    }

    private static func makeWindingCurve(
        direction: LatticeDirection,
        mesh: HeveaMesh,
        configuration: CurveExperimentConfiguration
    ) throws -> WindingCurveSummary {
        let start = configuration.basepoint
        let end = ParameterPoint(
            u: start.u + Double(direction.u),
            v: start.v + Double(direction.v)
        )
        let diagnostic = try MetricDiagnostics.intrinsicCurve(
            on: mesh,
            from: start,
            to: end,
            segments: configuration.segmentCount
        )
        let label: String
        switch (direction.u, direction.v) {
        case (1, 0):
            label = "u winding at v = 0.28125"
        case (0, 1):
            label = "v winding at u = 0.1375"
        default:
            label = "\(direction.label) winding"
        }
        return WindingCurveSummary(
            label: label,
            direction: direction,
            diagnostic: diagnostic
        )
    }

    private static func makeCrossStageComparison(
        _ stages: [StageExperimentReport]
    ) throws -> CrossStageComparison {
        guard !stages.isEmpty else {
            throw ScaleMicroscopeExperimentError.emptyExperiment
        }

        let metricValues = stages.map {
            RankedStageValue(stage: $0.stage, value: $0.metric.statistics.rootMeanSquare)
        }
        guard let lowestMetric = metricValues.min(by: rankedAscending),
              let highestMetric = metricValues.max(by: rankedAscending)
        else {
            throw ScaleMicroscopeExperimentError.emptyExperiment
        }

        let slopeValues = stages.compactMap { stage -> RankedStageValue? in
            guard let slope = stage.normalMicroscope.medianLogLogFit.slope else { return nil }
            return RankedStageValue(stage: stage.stage, value: slope)
        }
        let lowestSlope = slopeValues.min(by: rankedAscending)
        let highestSlope = slopeValues.max(by: rankedAscending)

        guard let finalProxy = stages.first(where: { $0.stage == .proxyStage3 }) else {
            throw ScaleMicroscopeExperimentError.missingStage(.proxyStage3)
        }

        let windingValues = try stages.map { stage -> RankedStageValue in
            guard !stage.windingCurves.isEmpty else {
                throw ScaleMicroscopeExperimentError.missingCurve(
                    direction: "u/v",
                    stage: stage.stage
                )
            }
            let maximumResidual = stage.windingCurves
                .map { abs($0.diagnostic.polylineRelativeLengthResidual) }
                .max() ?? 0
            return RankedStageValue(stage: stage.stage, value: maximumResidual)
        }
        guard let maximumWindingResidual = windingValues.max(by: rankedAscending) else {
            throw ScaleMicroscopeExperimentError.emptyExperiment
        }

        return CrossStageComparison(
            lowestMetricRootMeanSquare: lowestMetric,
            highestMetricRootMeanSquare: highestMetric,
            lowestMedianNormalSlope: lowestSlope,
            highestMedianNormalSlope: highestSlope,
            finalProxyMaximumDisplacementFromShortTorus: finalProxy.displacement.fromShortTorus.maximum,
            maximumAbsoluteWindingPolylineResidual: maximumWindingResidual
        )
    }

    private static func rankedAscending(_ lhs: RankedStageValue, _ rhs: RankedStageValue) -> Bool {
        if lhs.value == rhs.value {
            return stageIndex(lhs.stage) < stageIndex(rhs.stage)
        }
        return lhs.value < rhs.value
    }

    private static func stageIndex(_ stage: HeveaStage) -> Int {
        HeveaStage.allCases.firstIndex(of: stage) ?? Int.max
    }

    private static func makeBoundedFindings(
        comparison: CrossStageComparison
    ) -> [BoundedFinding] {
        var findings = [
            BoundedFinding(
                identifier: "metric-rms-range",
                statement: "Across the four sampled meshes, finite-difference metric RMS ranges from \(format(comparison.lowestMetricRootMeanSquare.value)) on \(comparison.lowestMetricRootMeanSquare.stage.shortDisplayName) to \(format(comparison.highestMetricRootMeanSquare.value)) on \(comparison.highestMetricRootMeanSquare.stage.shortDisplayName).",
                limitation: "Ordering these proxy residuals does not establish convergence toward an isometry; the proxies are explanatory normal ripples, not upstream convex-integration stages."
            ),
            BoundedFinding(
                identifier: "final-proxy-displacement",
                statement: "Proxy Stage 3 has maximum corresponding-vertex displacement \(format(comparison.finalProxyMaximumDisplacementFromShortTorus)) model units from the short-torus baseline.",
                limitation: "This is displacement from the baseline, not error against the upstream third corrugation or a limiting embedding."
            ),
            BoundedFinding(
                identifier: "winding-polyline-residual",
                statement: "The largest absolute u/v winding polyline-length residual in this run is \(format(comparison.maximumAbsoluteWindingPolylineResidual.value)) on \(comparison.maximumAbsoluteWindingPolylineResidual.stage.shortDisplayName).",
                limitation: "Only two fixed winding paths are sampled per stage; this is not a global distortion bound."
            ),
        ]

        if let lowest = comparison.lowestMedianNormalSlope,
           let highest = comparison.highestMedianNormalSlope
        {
            findings.append(
                BoundedFinding(
                    identifier: "normal-median-slope-range",
                    statement: "Descriptive median-normal log-log slopes range from \(format(lowest.value)) on \(lowest.stage.shortDisplayName) to \(format(highest.value)) on \(highest.stage.shortDisplayName) over retained grid steps.",
                    limitation: "These least-squares slopes summarize a short finite scale ladder and are not Hölder exponents, graph dimensions, or limiting-regularity estimates."
                )
            )
        }

        return findings
    }

    private static func format(_ value: Double) -> String {
        String(
            format: "%.8g",
            locale: Locale(identifier: "en_US_POSIX"),
            value
        )
    }
}
