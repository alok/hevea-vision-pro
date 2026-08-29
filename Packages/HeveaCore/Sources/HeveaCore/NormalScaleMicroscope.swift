import Foundation

public struct NormalMicroscopeConfiguration: Codable, Equatable, Sendable {
    public let scales: [Int]
    public let sampleCount: Int
    public let deterministicSeed: UInt64

    public init(
        scales: [Int] = [1, 2, 4, 8, 16],
        sampleCount: Int = 128,
        deterministicSeed: UInt64 = 0x4845_5645_415F_5631
    ) throws {
        try Self.validate(scales: scales, sampleCount: sampleCount)
        self.scales = scales
        self.sampleCount = sampleCount
        self.deterministicSeed = deterministicSeed
    }

    private init(knownValidScales: [Int], sampleCount: Int, deterministicSeed: UInt64) {
        scales = knownValidScales
        self.sampleCount = sampleCount
        self.deterministicSeed = deterministicSeed
    }

    public static let `default` = NormalMicroscopeConfiguration(
        knownValidScales: [1, 2, 4, 8, 16],
        sampleCount: 128,
        deterministicSeed: 0x4845_5645_415F_5631
    )

    private enum CodingKeys: String, CodingKey {
        case scales
        case sampleCount
        case deterministicSeed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let scales = try container.decode([Int].self, forKey: .scales)
        let sampleCount = try container.decode(Int.self, forKey: .sampleCount)
        let deterministicSeed = try container.decode(UInt64.self, forKey: .deterministicSeed)
        do {
            try self.init(
                scales: scales,
                sampleCount: sampleCount,
                deterministicSeed: deterministicSeed
            )
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .scales,
                in: container,
                debugDescription: String(describing: error)
            )
        }
    }

    private static func validate(scales: [Int], sampleCount: Int) throws {
        guard !scales.isEmpty else {
            throw HeveaCoreError.invalidDiagnosticConfiguration(
                reason: "normal microscope requires at least one scale"
            )
        }
        guard sampleCount > 0 else {
            throw HeveaCoreError.invalidDiagnosticConfiguration(
                reason: "normal microscope sample count must be positive"
            )
        }
        guard scales.allSatisfy({ $0 > 0 }) else {
            throw HeveaCoreError.invalidDiagnosticConfiguration(
                reason: "normal microscope scales must be positive grid steps"
            )
        }
        guard zip(scales, scales.dropFirst()).allSatisfy({ $0 < $1 }) else {
            throw HeveaCoreError.invalidDiagnosticConfiguration(
                reason: "normal microscope scales must be strictly increasing"
            )
        }
    }
}

public struct ExcludedNormalScale: Codable, Equatable, Sendable {
    public let gridStep: Int
    public let reason: String

    public init(gridStep: Int, reason: String) {
        self.gridStep = gridStep
        self.reason = reason
    }
}

public struct LocalNormalScaleObservation: Codable, Equatable, Sendable {
    public let gridStep: Int
    public let parameterRadiusU: Double
    public let parameterRadiusV: Double
    public let maximumNormalAngleRadians: Double
    public let neighborCount: Int

    public var isFinite: Bool {
        parameterRadiusU.isFinite
            && parameterRadiusV.isFinite
            && maximumNormalAngleRadians.isFinite
    }

    public init(
        gridStep: Int,
        parameterRadiusU: Double,
        parameterRadiusV: Double,
        maximumNormalAngleRadians: Double,
        neighborCount: Int
    ) {
        self.gridStep = gridStep
        self.parameterRadiusU = parameterRadiusU
        self.parameterRadiusV = parameterRadiusV
        self.maximumNormalAngleRadians = maximumNormalAngleRadians
        self.neighborCount = neighborCount
    }
}

public struct LocalNormalMicroscopeReport: Codable, Equatable, Sendable {
    public let stage: HeveaStage
    public let claimClass: ClaimClass
    public let coordinate: GridCoordinate
    public let observations: [LocalNormalScaleObservation]

    public var allValuesAreFinite: Bool { observations.allSatisfy(\.isFinite) }

    public init(
        stage: HeveaStage,
        coordinate: GridCoordinate,
        observations: [LocalNormalScaleObservation]
    ) {
        self.stage = stage
        claimClass = .heveaVisionExperiment
        self.coordinate = coordinate
        self.observations = observations
    }
}

public struct NormalScaleObservation: Codable, Equatable, Sendable {
    public let gridStep: Int
    public let parameterRadiusU: Double
    public let parameterRadiusV: Double
    public let validSampleCount: Int
    public let excludedSampleCount: Int
    public let omegaStatisticsRadians: ScalarStatistics

    public var allValuesAreFinite: Bool {
        parameterRadiusU.isFinite
            && parameterRadiusV.isFinite
            && omegaStatisticsRadians.allValuesAreFinite
    }

    public init(
        gridStep: Int,
        parameterRadiusU: Double,
        parameterRadiusV: Double,
        validSampleCount: Int,
        excludedSampleCount: Int,
        omegaStatisticsRadians: ScalarStatistics
    ) {
        self.gridStep = gridStep
        self.parameterRadiusU = parameterRadiusU
        self.parameterRadiusV = parameterRadiusV
        self.validSampleCount = validSampleCount
        self.excludedSampleCount = excludedSampleCount
        self.omegaStatisticsRadians = omegaStatisticsRadians
    }
}

public struct NormalMicroscopeReport: Codable, Equatable, Sendable {
    public let stage: HeveaStage
    public let claimClass: ClaimClass
    public let grid: PeriodicGrid
    public let requestedSampleCount: Int
    public let actualSampleCount: Int
    public let deterministicSeed: UInt64
    public let sampleCoordinates: [GridCoordinate]
    public let observations: [NormalScaleObservation]
    public let excludedScales: [ExcludedNormalScale]
    public let claimCeiling: String

    public var allValuesAreFinite: Bool { observations.allSatisfy(\.allValuesAreFinite) }

    public init(
        stage: HeveaStage,
        grid: PeriodicGrid,
        requestedSampleCount: Int,
        deterministicSeed: UInt64,
        sampleCoordinates: [GridCoordinate],
        observations: [NormalScaleObservation],
        excludedScales: [ExcludedNormalScale]
    ) {
        self.stage = stage
        claimClass = .heveaVisionExperiment
        self.grid = grid
        self.requestedSampleCount = requestedSampleCount
        actualSampleCount = sampleCoordinates.count
        self.deterministicSeed = deterministicSeed
        self.sampleCoordinates = sampleCoordinates
        self.observations = observations
        self.excludedScales = excludedScales
        claimCeiling = "Finite-mesh normal variation only; no fractal-dimension or limiting-regularity theorem is claimed."
    }
}

public enum NormalScaleMicroscope {
    private static let neighborDirections = [
        GridCoordinate(u: -1, v: -1),
        GridCoordinate(u: -1, v: 0),
        GridCoordinate(u: -1, v: 1),
        GridCoordinate(u: 0, v: -1),
        GridCoordinate(u: 0, v: 1),
        GridCoordinate(u: 1, v: -1),
        GridCoordinate(u: 1, v: 0),
        GridCoordinate(u: 1, v: 1),
    ]

    /// Aggregates `omega(p,h)` over a reproducible subset of mesh vertices.
    /// The result is an `HV EXPERIMENT`; it is not a regularity proof.
    public static func analyze(
        _ mesh: HeveaMesh,
        configuration: NormalMicroscopeConfiguration = .default
    ) throws -> NormalMicroscopeReport {
        let sampleIndices = deterministicIndices(
            totalCount: mesh.grid.vertexCount,
            requestedCount: configuration.sampleCount,
            seed: configuration.deterministicSeed
        )
        let sampleCoordinates = try sampleIndices.map { try mesh.grid.coordinate(for: $0) }
        let minimumDimension = min(mesh.grid.uCount, mesh.grid.vCount)

        var observations: [NormalScaleObservation] = []
        var excludedScales: [ExcludedNormalScale] = []
        observations.reserveCapacity(configuration.scales.count)

        for scale in configuration.scales {
            guard 2 * scale < minimumDimension else {
                excludedScales.append(
                    ExcludedNormalScale(
                        gridStep: scale,
                        reason: "scale reaches or exceeds the finite grid's periodic Nyquist radius"
                    )
                )
                continue
            }

            var omegaValues: [Double] = []
            omegaValues.reserveCapacity(sampleCoordinates.count)
            var excludedSampleCount = 0
            for coordinate in sampleCoordinates {
                if let omega = omega(mesh: mesh, coordinate: coordinate, gridStep: scale) {
                    omegaValues.append(omega)
                } else {
                    excludedSampleCount += 1
                }
            }
            guard !omegaValues.isEmpty else {
                excludedScales.append(
                    ExcludedNormalScale(
                        gridStep: scale,
                        reason: "no sampled neighborhood produced a finite normal angle"
                    )
                )
                continue
            }

            observations.append(
                NormalScaleObservation(
                    gridStep: scale,
                    parameterRadiusU: Double(scale) / Double(mesh.grid.uCount),
                    parameterRadiusV: Double(scale) / Double(mesh.grid.vCount),
                    validSampleCount: omegaValues.count,
                    excludedSampleCount: excludedSampleCount,
                    omegaStatisticsRadians: try ScalarStatistics(summarizing: omegaValues)
                )
            )
        }

        let report = NormalMicroscopeReport(
            stage: mesh.stage,
            grid: mesh.grid,
            requestedSampleCount: configuration.sampleCount,
            deterministicSeed: configuration.deterministicSeed,
            sampleCoordinates: sampleCoordinates,
            observations: observations,
            excludedScales: excludedScales
        )
        guard report.allValuesAreFinite else {
            throw HeveaCoreError.nonFiniteValue(context: "normal microscope report")
        }
        return report
    }

    public static func inspect(
        _ mesh: HeveaMesh,
        at coordinate: GridCoordinate,
        scales: [Int]
    ) throws -> LocalNormalMicroscopeReport {
        guard !scales.isEmpty,
              scales.allSatisfy({ $0 > 0 }),
              zip(scales, scales.dropFirst()).allSatisfy({ $0 < $1 })
        else {
            throw HeveaCoreError.invalidDiagnosticConfiguration(
                reason: "local microscope scales must be positive and strictly increasing"
            )
        }
        let minimumDimension = min(mesh.grid.uCount, mesh.grid.vCount)
        guard scales.allSatisfy({ 2 * $0 < minimumDimension }) else {
            throw HeveaCoreError.invalidDiagnosticConfiguration(
                reason: "local microscope scale reaches the finite grid's periodic Nyquist radius"
            )
        }

        let wrapped = mesh.grid.wrapped(coordinate)
        var observations: [LocalNormalScaleObservation] = []
        observations.reserveCapacity(scales.count)
        for scale in scales {
            guard let omega = omega(mesh: mesh, coordinate: wrapped, gridStep: scale) else {
                throw HeveaCoreError.nonFiniteValue(
                    context: "local normal microscope at (\(wrapped.u), \(wrapped.v)), scale \(scale)"
                )
            }
            observations.append(
                LocalNormalScaleObservation(
                    gridStep: scale,
                    parameterRadiusU: Double(scale) / Double(mesh.grid.uCount),
                    parameterRadiusV: Double(scale) / Double(mesh.grid.vCount),
                    maximumNormalAngleRadians: omega,
                    neighborCount: neighborDirections.count
                )
            )
        }

        let report = LocalNormalMicroscopeReport(
            stage: mesh.stage,
            coordinate: wrapped,
            observations: observations
        )
        guard report.allValuesAreFinite else {
            throw HeveaCoreError.nonFiniteValue(context: "local normal microscope report")
        }
        return report
    }

    private static func omega(
        mesh: HeveaMesh,
        coordinate: GridCoordinate,
        gridStep: Int
    ) -> Double? {
        let center = mesh.normal(at: coordinate)
        guard center.isFinite else { return nil }
        var maximumAngle = 0.0
        for direction in neighborDirections {
            let neighbor = GridCoordinate(
                u: coordinate.u + direction.u * gridStep,
                v: coordinate.v + direction.v * gridStep
            )
            guard let angle = Vector3.angle(center, mesh.normal(at: neighbor)), angle.isFinite else {
                return nil
            }
            maximumAngle = max(maximumAngle, angle)
        }
        return maximumAngle.isFinite ? maximumAngle : nil
    }

    private static func deterministicIndices(
        totalCount: Int,
        requestedCount: Int,
        seed: UInt64
    ) -> [Int] {
        let count = min(totalCount, requestedCount)
        guard count < totalCount else { return Array(0..<totalCount) }

        var generator = SplitMix64(state: seed)
        var selected = Array(repeating: false, count: totalCount)
        var result: [Int] = []
        result.reserveCapacity(count)
        while result.count < count {
            let index = Int(generator.next() % UInt64(totalCount))
            if !selected[index] {
                selected[index] = true
                result.append(index)
            }
        }
        return result
    }
}

private struct SplitMix64 {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
