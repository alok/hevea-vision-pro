import XCTest
@testable import HeveaCore

final class HeveaMeshGeneratorTests: XCTestCase {
    func testShortTorusMatchesPinnedUpstreamFormulaAtLandmarks() throws {
        let configuration = try TestSupport.configuration()
        let origin = try HeveaMeshGenerator.position(
            at: .zero,
            stage: .shortTorus,
            configuration: configuration
        )
        XCTAssertEqual(origin.x, 0.7 / (2 * Double.pi), accuracy: 1e-14)
        XCTAssertEqual(origin.y, 0, accuracy: 1e-14)
        XCTAssertEqual(origin.z, 0, accuracy: 1e-14)

        let quarterTube = try HeveaMeshGenerator.position(
            at: ParameterPoint(u: 0.25, v: 0),
            stage: .shortTorus,
            configuration: configuration
        )
        XCTAssertEqual(quarterTube.x, 0.5 / (2 * Double.pi), accuracy: 1e-14)
        XCTAssertEqual(quarterTube.y, 0, accuracy: 1e-14)
        XCTAssertEqual(quarterTube.z, 0.2 / (2 * Double.pi), accuracy: 1e-14)
    }

    func testEveryStageIsPeriodicAcrossBothParameterSeams() throws {
        let configuration = try TestSupport.configuration(uCount: 40, vCount: 56)
        let probes = [
            ParameterPoint(u: 0.137, v: 0.291),
            ParameterPoint(u: -0.073, v: 1.443),
            ParameterPoint(u: 2.4, v: -3.7),
        ]

        for stage in HeveaStage.allCases {
            for point in probes {
                let reference = try HeveaMeshGenerator.position(
                    at: point,
                    stage: stage,
                    configuration: configuration
                )
                let shiftedU = try HeveaMeshGenerator.position(
                    at: ParameterPoint(u: point.u + 1, v: point.v),
                    stage: stage,
                    configuration: configuration
                )
                let shiftedV = try HeveaMeshGenerator.position(
                    at: ParameterPoint(u: point.u, v: point.v - 2),
                    stage: stage,
                    configuration: configuration
                )
                TestSupport.assertEqual(reference, shiftedU, accuracy: 2e-13)
                TestSupport.assertEqual(reference, shiftedV, accuracy: 2e-13)
            }
        }
    }

    func testGeneratedMeshContainsEveryTypedRenderChannel() throws {
        let configuration = try TestSupport.configuration(uCount: 24, vCount: 36)
        let mesh = try HeveaMeshGenerator.generate(
            stage: .proxyStage3,
            configuration: configuration
        )

        XCTAssertEqual(mesh.positions.count, configuration.grid.vertexCount)
        XCTAssertEqual(mesh.normals.count, configuration.grid.vertexCount)
        XCTAssertEqual(mesh.textureCoordinates.count, configuration.grid.vertexCount)
        XCTAssertEqual(mesh.uvs, mesh.textureCoordinates)
        XCTAssertEqual(mesh.triangleIndices.count, configuration.grid.triangleIndexCount)
        XCTAssertEqual(mesh.indices, mesh.triangleIndices)
        XCTAssertEqual(mesh.scalarFields.count, 2)
        XCTAssertEqual(
            mesh.scalarField(named: MetricDiagnostics.scalarFieldName)?.values.count,
            configuration.grid.vertexCount
        )
        XCTAssertEqual(
            mesh.scalarField(named: "proxyDisplacementMagnitude")?.values.count,
            configuration.grid.vertexCount
        )
    }

    func testAllGeneratedValuesAreFiniteAndNormalsAreUnitLength() throws {
        let configuration = try TestSupport.configuration(uCount: 36, vCount: 52)
        for stage in HeveaStage.allCases {
            let mesh = try HeveaMeshGenerator.generate(stage: stage, configuration: configuration)
            XCTAssertTrue(mesh.positions.allSatisfy(\.isFinite))
            XCTAssertTrue(mesh.normals.allSatisfy(\.isFinite))
            XCTAssertTrue(mesh.textureCoordinates.allSatisfy(\.isFinite))
            XCTAssertTrue(mesh.scalarFields.flatMap(\.values).allSatisfy(\.isFinite))
            for normal in mesh.normals {
                XCTAssertEqual(normal.length, 1, accuracy: 2e-12)
            }
            for uv in mesh.textureCoordinates {
                XCTAssertTrue((0..<1).contains(uv.x))
                XCTAssertTrue((0..<1).contains(uv.y))
            }
        }
    }

    func testGenerationIsExactlyDeterministic() throws {
        let configuration = try TestSupport.configuration(uCount: 28, vCount: 44)
        let first = try HeveaMeshGenerator.generate(
            stage: .proxyStage3,
            configuration: configuration
        )
        let second = try HeveaMeshGenerator.generate(
            stage: .proxyStage3,
            configuration: configuration
        )
        XCTAssertEqual(first, second)
    }

    func testSuccessiveProxyStagesAreNumericallyDifferent() throws {
        let configuration = try TestSupport.configuration(uCount: 40, vCount: 64)
        let meshes = try HeveaStage.allCases.map {
            try HeveaMeshGenerator.generate(stage: $0, configuration: configuration)
        }

        for index in 1..<meshes.count {
            let maximumDifference = zip(meshes[index - 1].positions, meshes[index].positions)
                .map(Vector3.distance)
                .max() ?? 0
            XCTAssertGreaterThan(maximumDifference, 0.001)
        }

        XCTAssertTrue(
            meshes[0].scalarField(named: "proxyDisplacementMagnitude")!.values
                .allSatisfy { $0 == 0 }
        )
        XCTAssertGreaterThan(
            meshes[3].scalarField(named: "proxyDisplacementMagnitude")!.values.max() ?? 0,
            0.01
        )
    }

    func testClaimLabelsAndManifestKeepProxyCeilingExplicit() throws {
        let configuration = try TestSupport.configuration(uCount: 16, vCount: 24)
        XCTAssertEqual(HeveaStage.shortTorus.claimClass, .upstreamBaseline)
        XCTAssertTrue(HeveaStage.shortTorus.displayName.hasPrefix("UPSTREAM BASELINE"))

        for stage in HeveaStage.allCases.dropFirst() {
            XCTAssertEqual(stage.claimClass, .realTimeProxy)
            XCTAssertTrue(stage.displayName.hasPrefix("REAL-TIME PROXY"))
            XCTAssertNotNil(stage.proxyDescriptor)

            let mesh = try HeveaMeshGenerator.generate(stage: stage, configuration: configuration)
            XCTAssertEqual(mesh.manifest.claimClass, .realTimeProxy)
            XCTAssertTrue(mesh.manifest.claimCeiling.contains("not the upstream corrugation"))
            XCTAssertEqual(
                mesh.manifest.appliedProxyCorrugations.count,
                stage.appliedCorrugationCount
            )
        }

        XCTAssertEqual(
            ProxySchedule.default.corrugations.map(\.upstreamReferenceFrequency),
            [12, 80, 500]
        )
        XCTAssertEqual(
            ProxySchedule.default.corrugations.map(\.frequency),
            [5, 8, 13]
        )
    }
}
