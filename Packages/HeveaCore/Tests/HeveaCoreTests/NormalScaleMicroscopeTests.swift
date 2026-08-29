import XCTest
@testable import HeveaCore

final class NormalScaleMicroscopeTests: XCTestCase {
    func testAggregateMicroscopeIsFiniteBoundedAndDeterministic() throws {
        let configuration = try TestSupport.configuration(uCount: 48, vCount: 64)
        let mesh = try HeveaMeshGenerator.generate(
            stage: .proxyStage3,
            configuration: configuration
        )
        let microscopeConfiguration = try NormalMicroscopeConfiguration(
            scales: [1, 2, 4, 8],
            sampleCount: 40,
            deterministicSeed: 42
        )
        let first = try NormalScaleMicroscope.analyze(
            mesh,
            configuration: microscopeConfiguration
        )
        let second = try NormalScaleMicroscope.analyze(
            mesh,
            configuration: microscopeConfiguration
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.claimClass, .heveaVisionExperiment)
        XCTAssertEqual(first.actualSampleCount, 40)
        XCTAssertEqual(Set(first.sampleCoordinates).count, 40)
        XCTAssertEqual(first.observations.map(\.gridStep), [1, 2, 4, 8])
        XCTAssertTrue(first.excludedScales.isEmpty)
        XCTAssertTrue(first.allValuesAreFinite)
        XCTAssertTrue(first.claimCeiling.contains("no fractal-dimension"))

        for observation in first.observations {
            XCTAssertEqual(observation.validSampleCount, 40)
            XCTAssertEqual(observation.excludedSampleCount, 0)
            XCTAssertGreaterThanOrEqual(observation.omegaStatisticsRadians.minimum, 0)
            XCTAssertLessThanOrEqual(observation.omegaStatisticsRadians.maximum, Double.pi)
            XCTAssertTrue(observation.allValuesAreFinite)
        }
    }

    func testDifferentSeedsProduceDifferentRetainedSamples() throws {
        let mesh = try HeveaMeshGenerator.generate(
            stage: .proxyStage2,
            configuration: TestSupport.configuration(uCount: 32, vCount: 48)
        )
        let first = try NormalScaleMicroscope.analyze(
            mesh,
            configuration: NormalMicroscopeConfiguration(
                scales: [1, 2, 4],
                sampleCount: 24,
                deterministicSeed: 1
            )
        )
        let second = try NormalScaleMicroscope.analyze(
            mesh,
            configuration: NormalMicroscopeConfiguration(
                scales: [1, 2, 4],
                sampleCount: 24,
                deterministicSeed: 2
            )
        )
        XCTAssertNotEqual(first.sampleCoordinates, second.sampleCoordinates)
    }

    func testExcludedScaleRemainsVisible() throws {
        let mesh = try HeveaMeshGenerator.generate(
            stage: .shortTorus,
            configuration: TestSupport.configuration(uCount: 24, vCount: 32)
        )
        let report = try NormalScaleMicroscope.analyze(
            mesh,
            configuration: NormalMicroscopeConfiguration(
                scales: [1, 4, 12],
                sampleCount: 16,
                deterministicSeed: 7
            )
        )
        XCTAssertEqual(report.observations.map(\.gridStep), [1, 4])
        XCTAssertEqual(report.excludedScales.map(\.gridStep), [12])
        XCTAssertTrue(report.excludedScales[0].reason.contains("Nyquist"))
    }

    func testLocalMicroscopeWrapsSelectionAndReturnsEightNeighborOmega() throws {
        let mesh = try HeveaMeshGenerator.generate(
            stage: .proxyStage1,
            configuration: TestSupport.configuration(uCount: 32, vCount: 40)
        )
        let report = try NormalScaleMicroscope.inspect(
            mesh,
            at: GridCoordinate(u: -1, v: 41),
            scales: [1, 2, 4]
        )

        XCTAssertEqual(report.coordinate, GridCoordinate(u: 31, v: 1))
        XCTAssertEqual(report.observations.map(\.gridStep), [1, 2, 4])
        XCTAssertTrue(report.observations.allSatisfy { $0.neighborCount == 8 })
        XCTAssertTrue(report.observations.allSatisfy(\.isFinite))
        XCTAssertTrue(report.observations.allSatisfy {
            (0...Double.pi).contains($0.maximumNormalAngleRadians)
        })
    }

    func testRequestedSampleCountIsBoundedByMeshVertexCount() throws {
        let mesh = try HeveaMeshGenerator.generate(
            stage: .shortTorus,
            configuration: TestSupport.configuration(uCount: 8, vCount: 8)
        )
        let report = try NormalScaleMicroscope.analyze(
            mesh,
            configuration: NormalMicroscopeConfiguration(
                scales: [1],
                sampleCount: 1_000,
                deterministicSeed: 3
            )
        )
        XCTAssertEqual(report.requestedSampleCount, 1_000)
        XCTAssertEqual(report.actualSampleCount, 64)
        XCTAssertEqual(report.sampleCoordinates.count, 64)
    }

    func testProxyMicroscopeOutputDiffersFromShortTorus() throws {
        let configuration = try TestSupport.configuration(uCount: 48, vCount: 64)
        let microscopeConfiguration = try NormalMicroscopeConfiguration(
            scales: [1, 2, 4],
            sampleCount: 64,
            deterministicSeed: 99
        )
        let base = try NormalScaleMicroscope.analyze(
            HeveaMeshGenerator.generate(stage: .shortTorus, configuration: configuration),
            configuration: microscopeConfiguration
        )
        let proxy = try NormalScaleMicroscope.analyze(
            HeveaMeshGenerator.generate(stage: .proxyStage3, configuration: configuration),
            configuration: microscopeConfiguration
        )
        XCTAssertNotEqual(base.observations, proxy.observations)
    }
}
