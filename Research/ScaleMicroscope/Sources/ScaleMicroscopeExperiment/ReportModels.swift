/*
 HeveaScaleMicroscope is GPL-3.0-or-later.

 This file contains new finite-mesh diagnostics written for Hevea Vision Pro.
 It makes no claim about the limiting C1 embedding or its regularity.
*/

import Foundation
import HeveaCore

public enum ExperimentConstants {
    public static let schemaVersion = 1
    public static let reportTitle = "Hévéa Vision finite-mesh scale microscope"
    public static let experimentLabel = ClaimClass.heveaVisionExperiment.rawValue
    public static let reportBaselineDate = "2026-08-29"
    public static let coreRevision = "68202cae55a59a71b1573c869a05ac82b87c7ee2"
    public static let reproductionCommand = "git diff --exit-code 68202cae55a59a71b1573c869a05ac82b87c7ee2 -- Packages/HeveaCore && swift run -c release --package-path Research/ScaleMicroscope hevea-scale-microscope --output-directory docs/research"
    public static let overallClaimCeiling = "Finite deterministic meshes and descriptive numerical diagnostics only. This report does not certify isometry, reproduce the upstream corrugation algorithm, identify a limiting C1 embedding, estimate a theorem-level fractal dimension, or establish limiting regularity."
}

public struct RunReceipt: Codable, Equatable, Sendable {
    public let buildConfiguration: String
    public let coreRevision: String
    public let reportBaselineDate: String
    public let reproductionCommand: String

    public init(
        buildConfiguration: String,
        coreRevision: String = ExperimentConstants.coreRevision,
        reportBaselineDate: String = ExperimentConstants.reportBaselineDate,
        reproductionCommand: String = ExperimentConstants.reproductionCommand
    ) {
        self.buildConfiguration = buildConfiguration
        self.coreRevision = coreRevision
        self.reportBaselineDate = reportBaselineDate
        self.reproductionCommand = reproductionCommand
    }
}

public struct CurveExperimentConfiguration: Codable, Equatable, Sendable {
    public let basepoint: ParameterPoint
    public let segmentCount: Int
    public let directions: [LatticeDirection]

    public init(
        basepoint: ParameterPoint,
        segmentCount: Int,
        directions: [LatticeDirection]
    ) {
        self.basepoint = basepoint
        self.segmentCount = segmentCount
        self.directions = directions
    }
}

public struct ExperimentConfigurationReceipt: Codable, Equatable, Sendable {
    public let torus: TorusConfiguration
    public let normalMicroscope: NormalMicroscopeConfiguration
    public let windingCurves: CurveExperimentConfiguration
    public let stages: [HeveaStage]

    public init(
        torus: TorusConfiguration,
        normalMicroscope: NormalMicroscopeConfiguration,
        windingCurves: CurveExperimentConfiguration,
        stages: [HeveaStage]
    ) {
        self.torus = torus
        self.normalMicroscope = normalMicroscope
        self.windingCurves = windingCurves
        self.stages = stages
    }
}

public struct MethodReceipt: Codable, Equatable, Sendable {
    public let metricResidual: String
    public let windingCurve: String
    public let normalScaleStatistic: String
    public let descriptiveSlope: String
    public let proxyDisplacement: String
    public let samplingBoundary: String

    public init(
        metricResidual: String,
        windingCurve: String,
        normalScaleStatistic: String,
        descriptiveSlope: String,
        proxyDisplacement: String,
        samplingBoundary: String
    ) {
        self.metricResidual = metricResidual
        self.windingCurve = windingCurve
        self.normalScaleStatistic = normalScaleStatistic
        self.descriptiveSlope = descriptiveSlope
        self.proxyDisplacement = proxyDisplacement
        self.samplingBoundary = samplingBoundary
    }

    public static let finiteMeshV1 = MethodReceipt(
        metricResidual: "At each periodic grid vertex, use wrapped central finite differences to form E=<du f,du f>, F=<du f,dv f>, G=<dv f,dv f>; report sqrt((E-1)^2+2F^2+(G-1)^2) against du^2+dv^2.",
        windingCurve: "Sample one full u winding and one full v winding from a fixed off-grid basepoint with periodic bilinear mesh interpolation; compare ambient polyline length and endpoint chord with unit intrinsic target length.",
        normalScaleStatistic: "For deterministic sampled vertices and each valid grid step h, record omega(p,h), the maximum unit-normal angle over the eight neighbors at offsets {-h,0,h}^2 excluding the center; aggregate median and 95th percentile in radians.",
        descriptiveSlope: "Fit ordinary least squares to log(omega) versus log(sqrt((h/uCount)*(h/vCount))) over valid positive scale observations. Median and 95th-percentile fits are descriptive summaries, not dimensions or regularity exponents.",
        proxyDisplacement: "Summarize Euclidean vertex displacement from the short-torus baseline and from the immediately previous finite stage on the same periodic grid.",
        samplingBoundary: "Exclude a normal scale whenever 2*h is greater than or equal to the smaller grid dimension, because that scale reaches the finite periodic Nyquist radius."
    )
}

public struct MetricSummary: Codable, Equatable, Sendable {
    public let claimClass: ClaimClass
    public let residualDefinition: String
    public let targetMetric: MetricTensor
    public let finiteDifferenceStepU: Double
    public let finiteDifferenceStepV: Double
    public let statistics: ScalarStatistics
    public let claimCeiling: String

    public init(report: MetricResidualReport) {
        claimClass = report.claimClass
        residualDefinition = report.residualDefinition
        targetMetric = report.targetMetric
        finiteDifferenceStepU = report.finiteDifferenceStepU
        finiteDifferenceStepV = report.finiteDifferenceStepV
        statistics = report.statistics
        claimCeiling = "A residual summary of this sampled mesh only; not an isometry certificate and not a bound on a limiting map."
    }
}

public struct WindingCurveSummary: Codable, Equatable, Sendable {
    public let label: String
    public let direction: LatticeDirection
    public let diagnostic: CurveDiagnostic
    public let claimCeiling: String

    public init(
        label: String,
        direction: LatticeDirection,
        diagnostic: CurveDiagnostic
    ) {
        self.label = label
        self.direction = direction
        self.diagnostic = diagnostic
        claimCeiling = "Polyline and chord measurements of one interpolated finite-mesh path only."
    }
}

public struct DescriptiveLogLogFit: Codable, Equatable, Sendable {
    public let statistic: String
    public let radiusDefinition: String
    public let includedGridSteps: [Int]
    public let includedPointCount: Int
    public let slope: Double?
    public let intercept: Double?
    public let coefficientOfDetermination: Double?
    public let exclusionReason: String?
    public let claimCeiling: String

    public init(
        statistic: String,
        radiusDefinition: String,
        includedGridSteps: [Int],
        includedPointCount: Int,
        slope: Double?,
        intercept: Double?,
        coefficientOfDetermination: Double?,
        exclusionReason: String?
    ) {
        self.statistic = statistic
        self.radiusDefinition = radiusDefinition
        self.includedGridSteps = includedGridSteps
        self.includedPointCount = includedPointCount
        self.slope = slope
        self.intercept = intercept
        self.coefficientOfDetermination = coefficientOfDetermination
        self.exclusionReason = exclusionReason
        claimCeiling = "Descriptive least-squares slope across this finite scale ladder only; not a Hölder exponent, fractal dimension, convergence rate, or theorem."
    }

    public static func fit(
        statistic: String,
        observations: [NormalScaleObservation],
        value: (NormalScaleObservation) -> Double
    ) -> DescriptiveLogLogFit {
        let usable = observations.compactMap { observation -> (Int, Double, Double)? in
            let radius = sqrt(observation.parameterRadiusU * observation.parameterRadiusV)
            let observedValue = value(observation)
            guard radius.isFinite,
                  observedValue.isFinite,
                  radius > 0,
                  observedValue > 0
            else {
                return nil
            }
            return (observation.gridStep, log(radius), log(observedValue))
        }

        let radiusDefinition = "sqrt((h/uCount)*(h/vCount))"
        guard usable.count >= 2 else {
            return DescriptiveLogLogFit(
                statistic: statistic,
                radiusDefinition: radiusDefinition,
                includedGridSteps: usable.map(\.0),
                includedPointCount: usable.count,
                slope: nil,
                intercept: nil,
                coefficientOfDetermination: nil,
                exclusionReason: "At least two positive finite observations are required for a log-log fit."
            )
        }

        let count = Double(usable.count)
        let meanX = usable.reduce(0) { $0 + $1.1 } / count
        let meanY = usable.reduce(0) { $0 + $1.2 } / count
        let centered = usable.map { point in
            (x: point.1 - meanX, y: point.2 - meanY)
        }
        let denominator = centered.reduce(0) { $0 + $1.x * $1.x }
        guard denominator.isFinite, denominator > 0 else {
            return DescriptiveLogLogFit(
                statistic: statistic,
                radiusDefinition: radiusDefinition,
                includedGridSteps: usable.map(\.0),
                includedPointCount: usable.count,
                slope: nil,
                intercept: nil,
                coefficientOfDetermination: nil,
                exclusionReason: "The retained log radii have zero or non-finite variance."
            )
        }

        let slope = centered.reduce(0) { $0 + $1.x * $1.y } / denominator
        let intercept = meanY - slope * meanX
        let residualSumOfSquares = usable.reduce(0) { partial, point in
            let residual = point.2 - (intercept + slope * point.1)
            return partial + residual * residual
        }
        let totalSumOfSquares = centered.reduce(0) { $0 + $1.y * $1.y }
        let rSquared = totalSumOfSquares > 0
            ? 1 - residualSumOfSquares / totalSumOfSquares
            : nil

        guard slope.isFinite,
              intercept.isFinite,
              residualSumOfSquares.isFinite,
              totalSumOfSquares.isFinite,
              rSquared?.isFinite ?? true
        else {
            return DescriptiveLogLogFit(
                statistic: statistic,
                radiusDefinition: radiusDefinition,
                includedGridSteps: usable.map(\.0),
                includedPointCount: usable.count,
                slope: nil,
                intercept: nil,
                coefficientOfDetermination: nil,
                exclusionReason: "The least-squares computation produced a non-finite value."
            )
        }

        return DescriptiveLogLogFit(
            statistic: statistic,
            radiusDefinition: radiusDefinition,
            includedGridSteps: usable.map(\.0),
            includedPointCount: usable.count,
            slope: slope,
            intercept: intercept,
            coefficientOfDetermination: rSquared,
            exclusionReason: nil
        )
    }
}

public struct NormalMicroscopeSummary: Codable, Equatable, Sendable {
    public let claimClass: ClaimClass
    public let requestedSampleCount: Int
    public let actualSampleCount: Int
    public let deterministicSeed: UInt64
    public let sampleCoordinates: [GridCoordinate]
    public let observations: [NormalScaleObservation]
    public let excludedScales: [ExcludedNormalScale]
    public let medianLogLogFit: DescriptiveLogLogFit
    public let percentile95LogLogFit: DescriptiveLogLogFit
    public let claimCeiling: String

    public init(report: NormalMicroscopeReport) {
        claimClass = report.claimClass
        requestedSampleCount = report.requestedSampleCount
        actualSampleCount = report.actualSampleCount
        deterministicSeed = report.deterministicSeed
        sampleCoordinates = report.sampleCoordinates
        observations = report.observations
        excludedScales = report.excludedScales
        medianLogLogFit = DescriptiveLogLogFit.fit(
            statistic: "median omega in radians",
            observations: report.observations,
            value: { $0.omegaStatisticsRadians.median }
        )
        percentile95LogLogFit = DescriptiveLogLogFit.fit(
            statistic: "95th-percentile omega in radians",
            observations: report.observations,
            value: { $0.omegaStatisticsRadians.percentile95 }
        )
        claimCeiling = report.claimCeiling
    }
}

public struct ProxyDisplacementSummary: Codable, Equatable, Sendable {
    public let claimClass: ClaimClass
    public let reference: String
    public let fromShortTorus: ScalarStatistics
    public let fromPreviousStage: ScalarStatistics?
    public let previousStage: HeveaStage?
    public let claimCeiling: String

    public init(
        fromShortTorus: ScalarStatistics,
        fromPreviousStage: ScalarStatistics?,
        previousStage: HeveaStage?
    ) {
        claimClass = .heveaVisionExperiment
        reference = "Euclidean distance between corresponding vertices on the shared periodic grid, in model units"
        self.fromShortTorus = fromShortTorus
        self.fromPreviousStage = fromPreviousStage
        self.previousStage = previousStage
        claimCeiling = "Finite-stage proxy displacement only; not a geometric error bound against an upstream corrugation or limiting embedding."
    }
}

public struct MeshReceipt: Codable, Equatable, Sendable {
    public let vertexCount: Int
    public let triangleCount: Int
    public let grid: PeriodicGrid
    public let generatorIdentifier: String
    public let generatorVersion: String

    public init(mesh: HeveaMesh) {
        vertexCount = mesh.positions.count
        triangleCount = mesh.triangleIndices.count / 3
        grid = mesh.grid
        generatorIdentifier = mesh.manifest.generatorIdentifier
        generatorVersion = mesh.manifest.generatorVersion
    }
}

public struct StageExperimentReport: Codable, Equatable, Sendable {
    public let stage: HeveaStage
    public let displayName: String
    public let geometryClaimClass: ClaimClass
    public let appliedProxyCorrugations: [ProxyCorrugation]
    public let mesh: MeshReceipt
    public let metric: MetricSummary
    public let windingCurves: [WindingCurveSummary]
    public let normalMicroscope: NormalMicroscopeSummary
    public let displacement: ProxyDisplacementSummary
    public let geometryClaimCeiling: String

    public init(
        stage: HeveaStage,
        mesh: HeveaMesh,
        metric: MetricSummary,
        windingCurves: [WindingCurveSummary],
        normalMicroscope: NormalMicroscopeSummary,
        displacement: ProxyDisplacementSummary
    ) {
        self.stage = stage
        displayName = stage.displayName
        geometryClaimClass = stage.claimClass
        appliedProxyCorrugations = mesh.manifest.appliedProxyCorrugations
        self.mesh = MeshReceipt(mesh: mesh)
        self.metric = metric
        self.windingCurves = windingCurves
        self.normalMicroscope = normalMicroscope
        self.displacement = displacement
        geometryClaimCeiling = mesh.manifest.claimCeiling
    }
}

public struct RankedStageValue: Codable, Equatable, Sendable {
    public let stage: HeveaStage
    public let value: Double

    public init(stage: HeveaStage, value: Double) {
        self.stage = stage
        self.value = value
    }
}

public struct CrossStageComparison: Codable, Equatable, Sendable {
    public let lowestMetricRootMeanSquare: RankedStageValue
    public let highestMetricRootMeanSquare: RankedStageValue
    public let lowestMedianNormalSlope: RankedStageValue?
    public let highestMedianNormalSlope: RankedStageValue?
    public let finalProxyMaximumDisplacementFromShortTorus: Double
    public let maximumAbsoluteWindingPolylineResidual: RankedStageValue

    public init(
        lowestMetricRootMeanSquare: RankedStageValue,
        highestMetricRootMeanSquare: RankedStageValue,
        lowestMedianNormalSlope: RankedStageValue?,
        highestMedianNormalSlope: RankedStageValue?,
        finalProxyMaximumDisplacementFromShortTorus: Double,
        maximumAbsoluteWindingPolylineResidual: RankedStageValue
    ) {
        self.lowestMetricRootMeanSquare = lowestMetricRootMeanSquare
        self.highestMetricRootMeanSquare = highestMetricRootMeanSquare
        self.lowestMedianNormalSlope = lowestMedianNormalSlope
        self.highestMedianNormalSlope = highestMedianNormalSlope
        self.finalProxyMaximumDisplacementFromShortTorus = finalProxyMaximumDisplacementFromShortTorus
        self.maximumAbsoluteWindingPolylineResidual = maximumAbsoluteWindingPolylineResidual
    }
}

public struct BoundedFinding: Codable, Equatable, Sendable {
    public let identifier: String
    public let claimClass: ClaimClass
    public let statement: String
    public let limitation: String

    public init(identifier: String, statement: String, limitation: String) {
        self.identifier = identifier
        claimClass = .heveaVisionExperiment
        self.statement = statement
        self.limitation = limitation
    }
}

public struct ExperimentReport: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let title: String
    public let claimClass: ClaimClass
    public let claimCeiling: String
    public let run: RunReceipt
    public let upstreamSource: UpstreamSourceManifest
    public let configuration: ExperimentConfigurationReceipt
    public let methods: MethodReceipt
    public let stages: [StageExperimentReport]
    public let crossStageComparison: CrossStageComparison
    public let boundedFindings: [BoundedFinding]

    public init(
        run: RunReceipt,
        upstreamSource: UpstreamSourceManifest,
        configuration: ExperimentConfigurationReceipt,
        methods: MethodReceipt,
        stages: [StageExperimentReport],
        crossStageComparison: CrossStageComparison,
        boundedFindings: [BoundedFinding]
    ) {
        schemaVersion = ExperimentConstants.schemaVersion
        title = ExperimentConstants.reportTitle
        claimClass = .heveaVisionExperiment
        claimCeiling = ExperimentConstants.overallClaimCeiling
        self.run = run
        self.upstreamSource = upstreamSource
        self.configuration = configuration
        self.methods = methods
        self.stages = stages
        self.crossStageComparison = crossStageComparison
        self.boundedFindings = boundedFindings
    }
}

public enum ScaleMicroscopeExperimentError: Error, Equatable, Sendable, CustomStringConvertible {
    case missingScalarField(name: String, stage: HeveaStage)
    case missingCurve(direction: String, stage: HeveaStage)
    case missingStage(HeveaStage)
    case inconsistentVertexCount(stage: HeveaStage, expected: Int, actual: Int)
    case emptyExperiment

    public var description: String {
        switch self {
        case let .missingScalarField(name, stage):
            "Missing scalar field \(name) for stage \(stage.rawValue)."
        case let .missingCurve(direction, stage):
            "Missing \(direction) winding curve for stage \(stage.rawValue)."
        case let .missingStage(stage):
            "Missing required stage \(stage.rawValue)."
        case let .inconsistentVertexCount(stage, expected, actual):
            "Stage \(stage.rawValue) has \(actual) vertices; expected \(expected)."
        case .emptyExperiment:
            "The experiment produced no stage reports."
        }
    }
}
