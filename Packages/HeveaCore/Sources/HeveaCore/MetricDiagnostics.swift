import Foundation

public struct ScalarStatistics: Codable, Equatable, Sendable {
    public let count: Int
    public let minimum: Double
    public let maximum: Double
    public let mean: Double
    public let rootMeanSquare: Double
    public let median: Double
    public let percentile95: Double

    public var allValuesAreFinite: Bool {
        minimum.isFinite
            && maximum.isFinite
            && mean.isFinite
            && rootMeanSquare.isFinite
            && median.isFinite
            && percentile95.isFinite
    }

    public init(summarizing values: [Double]) throws {
        guard !values.isEmpty else {
            throw HeveaCoreError.invalidDiagnosticConfiguration(
                reason: "cannot summarize an empty numerical sample"
            )
        }
        guard values.allSatisfy(\.isFinite) else {
            throw HeveaCoreError.nonFiniteValue(context: "statistical sample")
        }

        let sorted = values.sorted()
        let sum = values.reduce(0, +)
        let sumOfSquares = values.reduce(0) { $0 + $1 * $1 }
        let countAsDouble = Double(values.count)
        let mean = sum / countAsDouble
        let rootMeanSquare = sqrt(sumOfSquares / countAsDouble)
        let median = Self.quantile(0.5, sortedValues: sorted)
        let percentile95 = Self.quantile(0.95, sortedValues: sorted)

        guard sum.isFinite,
              sumOfSquares.isFinite,
              mean.isFinite,
              rootMeanSquare.isFinite,
              median.isFinite,
              percentile95.isFinite
        else {
            throw HeveaCoreError.nonFiniteValue(context: "statistical summary")
        }

        count = values.count
        minimum = sorted[0]
        maximum = sorted[sorted.count - 1]
        self.mean = mean
        self.rootMeanSquare = rootMeanSquare
        self.median = median
        self.percentile95 = percentile95
    }

    private static func quantile(_ probability: Double, sortedValues: [Double]) -> Double {
        guard sortedValues.count > 1 else { return sortedValues[0] }
        let position = probability * Double(sortedValues.count - 1)
        let lowerIndex = Int(floor(position))
        let upperIndex = Int(ceil(position))
        let fraction = position - Double(lowerIndex)
        return sortedValues[lowerIndex] * (1 - fraction) + sortedValues[upperIndex] * fraction
    }
}

public struct MetricTensor: Codable, Equatable, Sendable {
    /// `E = <∂u f, ∂u f>`
    public let e: Double
    /// `F = <∂u f, ∂v f>`
    public let f: Double
    /// `G = <∂v f, ∂v f>`
    public let g: Double

    public init(e: Double, f: Double, g: Double) {
        self.e = e
        self.f = f
        self.g = g
    }

    public static let unitFlat = MetricTensor(e: 1, f: 0, g: 1)
    public var isFinite: Bool { e.isFinite && f.isFinite && g.isFinite }

    public func frobeniusDistance(to target: MetricTensor) -> Double {
        let deltaE = e - target.e
        let deltaF = f - target.f
        let deltaG = g - target.g
        return sqrt(deltaE * deltaE + 2 * deltaF * deltaF + deltaG * deltaG)
    }
}

public struct MetricResidualReport: Codable, Equatable, Sendable {
    public let stage: HeveaStage
    public let claimClass: ClaimClass
    public let grid: PeriodicGrid
    public let targetMetric: MetricTensor
    public let finiteDifferenceStepU: Double
    public let finiteDifferenceStepV: Double
    public let residualDefinition: String
    public let residuals: [Double]
    public let statistics: ScalarStatistics

    public var allValuesAreFinite: Bool {
        finiteDifferenceStepU.isFinite
            && finiteDifferenceStepV.isFinite
            && residuals.allSatisfy(\.isFinite)
            && statistics.allValuesAreFinite
    }

    public init(
        stage: HeveaStage,
        grid: PeriodicGrid,
        targetMetric: MetricTensor,
        finiteDifferenceStepU: Double,
        finiteDifferenceStepV: Double,
        residuals: [Double],
        statistics: ScalarStatistics
    ) {
        self.stage = stage
        claimClass = .heveaVisionExperiment
        self.grid = grid
        self.targetMetric = targetMetric
        self.finiteDifferenceStepU = finiteDifferenceStepU
        self.finiteDifferenceStepV = finiteDifferenceStepV
        residualDefinition = "sqrt((E-1)^2 + 2F^2 + (G-1)^2) from wrapped central finite differences"
        self.residuals = residuals
        self.statistics = statistics
    }
}

public struct CurveDiagnostic: Codable, Equatable, Sendable {
    public let stage: HeveaStage
    public let claimClass: ClaimClass
    public let start: ParameterPoint
    public let end: ParameterPoint
    public let segmentCount: Int
    public let intrinsicTargetLength: Double
    public let ambientChordLength: Double
    public let ambientPolylineLength: Double
    public let chordToIntrinsicRatio: Double
    public let polylineRelativeLengthResidual: Double

    public var allValuesAreFinite: Bool {
        intrinsicTargetLength.isFinite
            && ambientChordLength.isFinite
            && ambientPolylineLength.isFinite
            && chordToIntrinsicRatio.isFinite
            && polylineRelativeLengthResidual.isFinite
    }

    public init(
        stage: HeveaStage,
        start: ParameterPoint,
        end: ParameterPoint,
        segmentCount: Int,
        intrinsicTargetLength: Double,
        ambientChordLength: Double,
        ambientPolylineLength: Double
    ) {
        self.stage = stage
        claimClass = .heveaVisionExperiment
        self.start = start
        self.end = end
        self.segmentCount = segmentCount
        self.intrinsicTargetLength = intrinsicTargetLength
        self.ambientChordLength = ambientChordLength
        self.ambientPolylineLength = ambientPolylineLength
        chordToIntrinsicRatio = ambientChordLength / intrinsicTargetLength
        polylineRelativeLengthResidual = (ambientPolylineLength - intrinsicTargetLength)
            / intrinsicTargetLength
    }
}

public enum MetricDiagnostics {
    public static let scalarFieldName = "metricResidualFrobenius"

    /// Measures the first fundamental form of the finite mesh against the unit
    /// flat metric. This is an `HV EXPERIMENT`, not an isometry certificate.
    public static func analyze(
        _ mesh: HeveaMesh,
        targetMetric: MetricTensor = .unitFlat
    ) throws -> MetricResidualReport {
        guard targetMetric.isFinite else {
            throw HeveaCoreError.nonFiniteValue(context: "target metric")
        }

        let grid = mesh.grid
        let uStep = 1 / Double(grid.uCount)
        let vStep = 1 / Double(grid.vCount)
        var residuals: [Double] = []
        residuals.reserveCapacity(grid.vertexCount)

        for u in 0..<grid.uCount {
            for v in 0..<grid.vCount {
                let beforeU = mesh.position(at: GridCoordinate(u: u - 1, v: v))
                let afterU = mesh.position(at: GridCoordinate(u: u + 1, v: v))
                let beforeV = mesh.position(at: GridCoordinate(u: u, v: v - 1))
                let afterV = mesh.position(at: GridCoordinate(u: u, v: v + 1))
                let derivativeU = (afterU - beforeU) / (2 * uStep)
                let derivativeV = (afterV - beforeV) / (2 * vStep)
                let tensor = MetricTensor(
                    e: Vector3.dot(derivativeU, derivativeU),
                    f: Vector3.dot(derivativeU, derivativeV),
                    g: Vector3.dot(derivativeV, derivativeV)
                )
                let residual = tensor.frobeniusDistance(to: targetMetric)
                guard tensor.isFinite, residual.isFinite else {
                    throw HeveaCoreError.nonFiniteValue(
                        context: "metric residual at (\(u), \(v))"
                    )
                }
                residuals.append(residual)
            }
        }

        let statistics = try ScalarStatistics(summarizing: residuals)
        return MetricResidualReport(
            stage: mesh.stage,
            grid: grid,
            targetMetric: targetMetric,
            finiteDifferenceStepU: uStep,
            finiteDifferenceStepV: vStep,
            residuals: residuals,
            statistics: statistics
        )
    }

    /// Compares a prescribed straight path in the unwrapped unit-flat
    /// parameter plane with its finite mesh image. A full winding has a zero
    /// ambient endpoint chord even though its intrinsic target length is nonzero.
    public static func intrinsicCurve(
        on mesh: HeveaMesh,
        from start: ParameterPoint,
        to end: ParameterPoint,
        segments: Int = 256
    ) throws -> CurveDiagnostic {
        guard start.isFinite, end.isFinite else {
            throw HeveaCoreError.nonFiniteValue(context: "curve endpoints")
        }
        guard segments > 0 else {
            throw HeveaCoreError.invalidCurve(reason: "segment count must be positive")
        }
        let delta = Vector2(x: end.u - start.u, y: end.v - start.v)
        let intrinsicLength = delta.length
        guard intrinsicLength.isFinite, intrinsicLength > 0 else {
            throw HeveaCoreError.invalidCurve(reason: "curve must have positive intrinsic target length")
        }

        var firstPosition: Vector3?
        var previousPosition: Vector3?
        var finalPosition: Vector3?
        var polylineLength = 0.0

        for index in 0...segments {
            let fraction = Double(index) / Double(segments)
            let point = ParameterPoint(
                u: start.u + delta.x * fraction,
                v: start.v + delta.y * fraction
            )
            let position = try mesh.interpolatedPosition(at: point)
            if let previousPosition {
                polylineLength += Vector3.distance(previousPosition, position)
            } else {
                firstPosition = position
            }
            previousPosition = position
            finalPosition = position
        }

        guard let firstPosition, let finalPosition, polylineLength.isFinite else {
            throw HeveaCoreError.nonFiniteValue(context: "curve image")
        }
        let chordLength = Vector3.distance(firstPosition, finalPosition)
        let report = CurveDiagnostic(
            stage: mesh.stage,
            start: start,
            end: end,
            segmentCount: segments,
            intrinsicTargetLength: intrinsicLength,
            ambientChordLength: chordLength,
            ambientPolylineLength: polylineLength
        )
        guard report.allValuesAreFinite else {
            throw HeveaCoreError.nonFiniteValue(context: "curve diagnostic")
        }
        return report
    }
}
