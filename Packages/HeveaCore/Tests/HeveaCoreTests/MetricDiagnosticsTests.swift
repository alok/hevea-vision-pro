import XCTest
@testable import HeveaCore

final class MetricDiagnosticsTests: XCTestCase {
    func testMetricResidualSummaryMatchesFiniteVertexField() throws {
        let configuration = try TestSupport.configuration(uCount: 32, vCount: 48)
        let mesh = try HeveaMeshGenerator.generate(
            stage: .proxyStage2,
            configuration: configuration
        )
        let report = try MetricDiagnostics.analyze(mesh)

        XCTAssertEqual(report.claimClass, .heveaVisionExperiment)
        XCTAssertEqual(report.residuals.count, mesh.grid.vertexCount)
        XCTAssertEqual(report.statistics.count, mesh.grid.vertexCount)
        XCTAssertTrue(report.allValuesAreFinite)
        XCTAssertGreaterThanOrEqual(report.statistics.minimum, 0)
        XCTAssertLessThanOrEqual(report.statistics.minimum, report.statistics.median)
        XCTAssertLessThanOrEqual(report.statistics.median, report.statistics.percentile95)
        XCTAssertLessThanOrEqual(report.statistics.percentile95, report.statistics.maximum)
        XCTAssertEqual(
            mesh.scalarField(named: MetricDiagnostics.scalarFieldName)?.values,
            report.residuals
        )
    }

    func testMetricReportsAreDeterministicAndStagesDiffer() throws {
        let configuration = try TestSupport.configuration(uCount: 36, vCount: 56)
        let shortMesh = try HeveaMeshGenerator.generate(
            stage: .shortTorus,
            configuration: configuration
        )
        let proxyMesh = try HeveaMeshGenerator.generate(
            stage: .proxyStage3,
            configuration: configuration
        )
        let first = try MetricDiagnostics.analyze(proxyMesh)
        let second = try MetricDiagnostics.analyze(proxyMesh)
        let shortReport = try MetricDiagnostics.analyze(shortMesh)

        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first.residuals, shortReport.residuals)
        XCTAssertNotEqual(first.statistics.mean, shortReport.statistics.mean)
    }

    func testCurveDiagnosticSeparatesIntrinsicPolylineAndAmbientChord() throws {
        let configuration = try TestSupport.configuration(uCount: 48, vCount: 64)
        let mesh = try HeveaMeshGenerator.generate(
            stage: .shortTorus,
            configuration: configuration
        )
        let winding = try MetricDiagnostics.intrinsicCurve(
            on: mesh,
            from: ParameterPoint(u: 0.125, v: 0.25),
            to: ParameterPoint(u: 1.125, v: 0.25),
            segments: 256
        )

        XCTAssertEqual(winding.claimClass, .heveaVisionExperiment)
        XCTAssertEqual(winding.intrinsicTargetLength, 1, accuracy: 1e-14)
        XCTAssertEqual(winding.ambientChordLength, 0, accuracy: 1e-12)
        XCTAssertGreaterThan(winding.ambientPolylineLength, 0)
        XCTAssertTrue(winding.allValuesAreFinite)

        let openCurve = try MetricDiagnostics.intrinsicCurve(
            on: mesh,
            from: ParameterPoint(u: 0.1, v: 0.2),
            to: ParameterPoint(u: 0.43, v: 0.51),
            segments: 80
        )
        XCTAssertGreaterThan(openCurve.intrinsicTargetLength, 0)
        XCTAssertLessThanOrEqual(openCurve.ambientChordLength, openCurve.ambientPolylineLength + 1e-14)
        XCTAssertTrue(openCurve.allValuesAreFinite)
    }

    func testCurveDiagnosticsDetectStageDifference() throws {
        let configuration = try TestSupport.configuration(uCount: 48, vCount: 72)
        let start = ParameterPoint(u: 0.07, v: 0.13)
        let end = ParameterPoint(u: 0.78, v: 0.57)
        let base = try MetricDiagnostics.intrinsicCurve(
            on: HeveaMeshGenerator.generate(stage: .shortTorus, configuration: configuration),
            from: start,
            to: end,
            segments: 180
        )
        let proxy = try MetricDiagnostics.intrinsicCurve(
            on: HeveaMeshGenerator.generate(stage: .proxyStage3, configuration: configuration),
            from: start,
            to: end,
            segments: 180
        )
        XCTAssertNotEqual(base.ambientPolylineLength, proxy.ambientPolylineLength)
        XCTAssertNotEqual(base.ambientChordLength, proxy.ambientChordLength)
    }
}
