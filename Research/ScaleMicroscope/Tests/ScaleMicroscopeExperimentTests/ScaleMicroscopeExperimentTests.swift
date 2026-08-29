import Foundation
import HeveaCore
@testable import ScaleMicroscopeExperiment
import XCTest

final class ScaleMicroscopeExperimentTests: XCTestCase {
    func testDescriptiveFitRecoversKnownPowerLaw() throws {
        let observations = try [
            observation(step: 1, radius: 0.01, value: 0.0001),
            observation(step: 2, radius: 0.02, value: 0.0004),
            observation(step: 4, radius: 0.04, value: 0.0016),
            observation(step: 8, radius: 0.08, value: 0.0064),
        ]

        let fit = DescriptiveLogLogFit.fit(
            statistic: "synthetic",
            observations: observations,
            value: { $0.omegaStatisticsRadians.median }
        )

        XCTAssertEqual(fit.includedGridSteps, [1, 2, 4, 8])
        XCTAssertEqual(try XCTUnwrap(fit.slope), 2, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(fit.coefficientOfDetermination), 1, accuracy: 1e-12)
        XCTAssertNil(fit.exclusionReason)
    }

    func testExperimentCoversEveryStageAndRequiredDiagnostic() throws {
        let report = try ExperimentRunner.run(buildConfiguration: "test")

        XCTAssertEqual(report.run.coreRevision, ExperimentConstants.coreRevision)
        XCTAssertEqual(report.upstreamSource.revision, UpstreamSourceManifest.pinnedFlatTorus.revision)
        XCTAssertEqual(report.stages.map(\.stage), HeveaStage.allCases)
        XCTAssertEqual(report.claimClass, .heveaVisionExperiment)
        XCTAssertEqual(report.boundedFindings.count, 4)

        for stage in report.stages {
            XCTAssertEqual(stage.mesh.vertexCount, 96 * 128)
            XCTAssertEqual(stage.mesh.triangleCount, 2 * 96 * 128)
            XCTAssertEqual(stage.metric.claimClass, .heveaVisionExperiment)
            XCTAssertTrue(stage.metric.statistics.allValuesAreFinite)
            XCTAssertEqual(stage.windingCurves.map(\.direction), [
                LatticeDirection(u: 1, v: 0),
                LatticeDirection(u: 0, v: 1),
            ])
            XCTAssertTrue(stage.windingCurves.allSatisfy(\.diagnostic.allValuesAreFinite))
            XCTAssertEqual(stage.normalMicroscope.actualSampleCount, 256)
            XCTAssertEqual(stage.normalMicroscope.observations.map(\.gridStep), [1, 2, 4, 8, 16, 32])
            XCTAssertEqual(stage.normalMicroscope.excludedScales.map(\.gridStep), [64])
            XCTAssertNotNil(stage.normalMicroscope.medianLogLogFit.slope)
            XCTAssertTrue(stage.displacement.fromShortTorus.allValuesAreFinite)
        }
    }

    func testMaterializedReportsAreByteDeterministicAndDecodable() throws {
        let first = try ExperimentRunner.run(buildConfiguration: "test")
        let second = try ExperimentRunner.run(buildConfiguration: "test")
        XCTAssertEqual(first, second)

        let directory = URL(fileURLWithPath: "/deterministic-output", isDirectory: true)
        let firstArtifacts = try ReportWriter.materialize(first, outputDirectory: directory)
        let secondArtifacts = try ReportWriter.materialize(second, outputDirectory: directory)
        XCTAssertEqual(firstArtifacts.jsonData, secondArtifacts.jsonData)
        XCTAssertEqual(firstArtifacts.markdownData, secondArtifacts.markdownData)

        let decoded = try JSONDecoder().decode(
            ExperimentReport.self,
            from: firstArtifacts.jsonData
        )
        XCTAssertEqual(decoded, first)
        XCTAssertTrue(
            String(decoding: firstArtifacts.markdownData, as: UTF8.self)
                .contains("HV EXPERIMENT — finite meshes only")
        )
    }

    private func observation(
        step: Int,
        radius: Double,
        value: Double
    ) throws -> NormalScaleObservation {
        NormalScaleObservation(
            gridStep: step,
            parameterRadiusU: radius,
            parameterRadiusV: radius,
            validSampleCount: 1,
            excludedSampleCount: 0,
            omegaStatisticsRadians: try ScalarStatistics(summarizing: [value])
        )
    }
}
