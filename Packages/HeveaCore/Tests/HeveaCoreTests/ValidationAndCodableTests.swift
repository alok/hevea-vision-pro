import XCTest
@testable import HeveaCore

final class ValidationAndCodableTests: XCTestCase {
    func testInvalidGridParametersThrowTypedErrors() {
        XCTAssertThrowsError(try PeriodicGrid(uCount: 3, vCount: 8)) { error in
            guard case HeveaCoreError.gridDimensionTooSmall = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertThrowsError(try PeriodicGrid(uCount: Int.max, vCount: Int.max)) { error in
            guard case HeveaCoreError.arithmeticOverflow = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testInvalidShortTorusRadiiThrow() throws {
        let grid = try PeriodicGrid(uCount: 8, vCount: 8)
        for radii in [(0.0, 0.5), (-0.2, 0.5), (0.2, 0.8), (.nan, 0.5)] {
            XCTAssertThrowsError(
                try TorusConfiguration(
                    grid: grid,
                    minorRadius: radii.0,
                    majorRadius: radii.1
                )
            ) { error in
                guard case HeveaCoreError.invalidRadius = error else {
                    return XCTFail("Unexpected error: \(error)")
                }
            }
        }
    }

    func testProxyScheduleRejectsMissingMislabelledAndNonFiniteStages() {
        let valid = ProxySchedule.default.corrugations
        XCTAssertThrowsError(try ProxySchedule(corrugations: Array(valid.prefix(2))))

        var invalid = valid
        invalid[0] = ProxyCorrugation(
            displayName: "Stage one",
            direction: LatticeDirection(u: 1, v: 0),
            frequency: 5,
            amplitude: 0.01,
            upstreamReferenceFrequency: 12
        )
        XCTAssertThrowsError(try ProxySchedule(corrugations: invalid))

        invalid = valid
        invalid[1] = ProxyCorrugation(
            displayName: valid[1].displayName,
            direction: LatticeDirection(u: 1, v: 2),
            frequency: 0,
            amplitude: 0.01,
            upstreamReferenceFrequency: 80
        )
        XCTAssertThrowsError(try ProxySchedule(corrugations: invalid))

        invalid = valid
        invalid[2] = ProxyCorrugation(
            displayName: valid[2].displayName,
            direction: LatticeDirection(u: 1, v: -2),
            frequency: 13,
            amplitude: .infinity,
            upstreamReferenceFrequency: 500
        )
        XCTAssertThrowsError(try ProxySchedule(corrugations: invalid))
    }

    func testInvalidMicroscopeConfigurationsThrow() {
        XCTAssertThrowsError(try NormalMicroscopeConfiguration(scales: [], sampleCount: 1))
        XCTAssertThrowsError(try NormalMicroscopeConfiguration(scales: [0, 1], sampleCount: 1))
        XCTAssertThrowsError(try NormalMicroscopeConfiguration(scales: [1, 1], sampleCount: 1))
        XCTAssertThrowsError(try NormalMicroscopeConfiguration(scales: [2, 1], sampleCount: 1))
        XCTAssertThrowsError(try NormalMicroscopeConfiguration(scales: [1], sampleCount: 0))
    }

    func testInvalidCurveAndParameterInputsThrow() throws {
        let mesh = try HeveaMeshGenerator.generate(
            stage: .shortTorus,
            configuration: TestSupport.configuration(uCount: 12, vCount: 16)
        )
        XCTAssertThrowsError(
            try MetricDiagnostics.intrinsicCurve(
                on: mesh,
                from: .zero,
                to: .zero,
                segments: 10
            )
        )
        XCTAssertThrowsError(
            try MetricDiagnostics.intrinsicCurve(
                on: mesh,
                from: .zero,
                to: ParameterPoint(u: 1, v: 0),
                segments: 0
            )
        )
        XCTAssertThrowsError(
            try HeveaMeshGenerator.position(
                at: ParameterPoint(u: .nan, v: 0),
                stage: .shortTorus
            )
        )
        XCTAssertThrowsError(
            try NormalScaleMicroscope.inspect(
                mesh,
                at: GridCoordinate(u: 0, v: 0),
                scales: [1, 8]
            )
        )
    }

    func testMeshValidationRejectsMismatchedAndNonFinitePayloads() throws {
        let mesh = try HeveaMeshGenerator.generate(
            stage: .shortTorus,
            configuration: TestSupport.configuration(uCount: 8, vCount: 10)
        )
        XCTAssertThrowsError(
            try HeveaMesh(
                stage: mesh.stage,
                grid: mesh.grid,
                positions: Array(mesh.positions.dropLast()),
                normals: mesh.normals,
                textureCoordinates: mesh.textureCoordinates,
                triangleIndices: mesh.triangleIndices,
                scalarFields: mesh.scalarFields,
                manifest: mesh.manifest
            )
        )

        var invalidPositions = mesh.positions
        invalidPositions[0].x = .nan
        XCTAssertThrowsError(
            try HeveaMesh(
                stage: mesh.stage,
                grid: mesh.grid,
                positions: invalidPositions,
                normals: mesh.normals,
                textureCoordinates: mesh.textureCoordinates,
                triangleIndices: mesh.triangleIndices,
                scalarFields: mesh.scalarFields,
                manifest: mesh.manifest
            )
        )

        var invalidIndices = mesh.triangleIndices
        invalidIndices[0] = UInt32(mesh.grid.vertexCount)
        XCTAssertThrowsError(
            try HeveaMesh(
                stage: mesh.stage,
                grid: mesh.grid,
                positions: mesh.positions,
                normals: mesh.normals,
                textureCoordinates: mesh.textureCoordinates,
                triangleIndices: invalidIndices,
                scalarFields: mesh.scalarFields,
                manifest: mesh.manifest
            )
        )
    }

    func testConfigurationManifestMeshAndReportsRoundTripThroughJSON() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let decoder = JSONDecoder()
        let configuration = try TestSupport.configuration(uCount: 12, vCount: 16)
        let mesh = try HeveaMeshGenerator.generate(
            stage: .proxyStage2,
            configuration: configuration
        )
        let metric = try MetricDiagnostics.analyze(mesh)
        let microscope = try NormalScaleMicroscope.analyze(
            mesh,
            configuration: NormalMicroscopeConfiguration(
                scales: [1, 2],
                sampleCount: 12,
                deterministicSeed: 123
            )
        )

        XCTAssertEqual(
            try decoder.decode(TorusConfiguration.self, from: encoder.encode(configuration)),
            configuration
        )
        XCTAssertEqual(
            try decoder.decode(HeveaMeshManifest.self, from: encoder.encode(mesh.manifest)),
            mesh.manifest
        )
        XCTAssertEqual(
            try decoder.decode(HeveaMesh.self, from: encoder.encode(mesh)),
            mesh
        )
        XCTAssertEqual(
            try decoder.decode(MetricResidualReport.self, from: encoder.encode(metric)),
            metric
        )
        XCTAssertEqual(
            try decoder.decode(NormalMicroscopeReport.self, from: encoder.encode(microscope)),
            microscope
        )
    }

    func testDecodingRevalidatesGridAndSchedule() throws {
        let decoder = JSONDecoder()
        XCTAssertThrowsError(
            try decoder.decode(
                PeriodicGrid.self,
                from: Data(#"{"uCount":2,"vCount":8}"#.utf8)
            )
        )

        let badSchedule = #"{"corrugations":[{"displayName":"bad","direction":{"u":1,"v":0},"frequency":1,"amplitude":0.1,"upstreamReferenceFrequency":12}]}"#
        XCTAssertThrowsError(
            try decoder.decode(ProxySchedule.self, from: Data(badSchedule.utf8))
        )
    }
}
