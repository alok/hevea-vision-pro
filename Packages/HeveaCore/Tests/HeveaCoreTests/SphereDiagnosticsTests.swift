import XCTest
@testable import HeveaCore

final class SphereDiagnosticsTests: XCTestCase {
    func testContainingRadiusErrorRetainsTypedPayload() {
        do {
            throw HeveaCoreError.sphereContainingRadiusExceeded(measured: 0.51, declared: 0.49)
        } catch let error as HeveaCoreError {
            guard case let .sphereContainingRadiusExceeded(measured, declared) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(measured, 0.51)
            XCTAssertEqual(declared, 0.49)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testTopologyErrorRetainsTypedPayload() {
        do {
            throw HeveaCoreError.sphereTopologyViolation(reason: "inverted")
        } catch let error as HeveaCoreError {
            guard case let .sphereTopologyViolation(reason) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(reason, "inverted")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }


    func testEverySphereStageIsClosedOrientedFiniteAndInsideDeclaredRadius() throws {
        let configuration = try TestSupport.sphereConfiguration(
            longitudeCount: 64,
            nonPolarLatitudeRingCount: 47
        )
        for stage in SphereStage.allCases {
            let mesh = try SphereMeshGenerator.generate(
                stage: stage,
                configuration: configuration
            )
            let report = try SphereMeshDiagnostics.validate(mesh, configuration: configuration)
            XCTAssertTrue(report.passes)
            XCTAssertEqual(report.topology.eulerCharacteristic, 2)
            XCTAssertEqual(report.topology.boundaryEdgeCount, 0)
            XCTAssertEqual(report.topology.nonManifoldEdgeCount, 0)
            XCTAssertEqual(report.topology.inconsistentOrientationEdgeCount, 0)
            XCTAssertEqual(report.topology.degenerateTriangleCount, 0)
            XCTAssertEqual(report.topology.invertedTriangleCount, 0)
            XCTAssertGreaterThan(report.topology.minimumDoubledTriangleArea, 0)
            XCTAssertGreaterThanOrEqual(report.containingRadius.margin, -1e-10)
            XCTAssertEqual(report.deterministicFingerprint, mesh.deterministicFingerprint)
        }
    }

    func testInteractiveDefaultStage3MeetsThePublishedRuntimeBudget() throws {
        let mesh = try SphereMeshGenerator.generate(stage: .proxyFamily3)
        let report = try SphereMeshDiagnostics.validate(mesh)
        XCTAssertEqual(mesh.positions.count, 32_514)
        XCTAssertEqual(mesh.triangleIndices.count / 3, 65_024)
        XCTAssertTrue(report.passes)
        XCTAssertLessThanOrEqual(report.containingRadius.measuredMaximumRadius, 0.52)
    }

    func testCapSeamPositionDerivativeAndNormalResidualsPassTightBounds() throws {
        let configuration = try TestSupport.sphereConfiguration()
        for stage in SphereStage.allCases {
            let report = SphereMeshDiagnostics.seamReport(
                stage: stage,
                configuration: configuration
            )
            XCTAssertTrue(report.allValuesAreFinite)
            XCTAssertLessThanOrEqual(report.maximumPositionResidual, 1e-12)
            XCTAssertLessThanOrEqual(report.maximumFirstDerivativeResidual, 1e-12)
            XCTAssertLessThanOrEqual(report.maximumNormalAngleRadians, 1e-7)
            XCTAssertTrue(report.proxyFamiliesAreZeroAtSeam)
        }
    }

    func testMeshGenerationAndFingerprintAreExactlyDeterministic() throws {
        let configuration = try TestSupport.sphereConfiguration()
        let first = try SphereMeshGenerator.generate(
            stage: .proxyFamily3,
            configuration: configuration
        )
        let second = try SphereMeshGenerator.generate(
            stage: .proxyFamily3,
            configuration: configuration
        )
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.deterministicFingerprint, second.deterministicFingerprint)
        XCTAssertEqual(first.deterministicFingerprint.count, 16)
    }

    func testDiagnosticsRejectAnInvertedTriangle() throws {
        let configuration = try TestSupport.sphereConfiguration(
            longitudeCount: 24,
            nonPolarLatitudeRingCount: 15
        )
        let original = try SphereMeshGenerator.generate(
            stage: .shortMap,
            configuration: configuration
        )
        var invertedIndices = original.triangleIndices
        invertedIndices.swapAt(1, 2)
        let inverted = try SphereMesh.validated(
            stage: original.stage,
            grid: original.grid,
            positions: original.positions,
            normals: original.normals,
            textureCoordinates: original.textureCoordinates,
            triangleIndices: invertedIndices,
            scalarFields: original.scalarFields,
            manifest: original.manifest
        )
        let report = try SphereMeshDiagnostics.topologyReport(inverted)
        XCTAssertEqual(report.invertedTriangleCount, 1)
        XCTAssertGreaterThan(report.inconsistentOrientationEdgeCount, 0)
        do {
            _ = try SphereMeshDiagnostics.validate(inverted, configuration: configuration)
            XCTFail("Expected topology validation to reject an inverted triangle")
        } catch let error as SphereMeshValidationError {
            XCTAssertEqual(error.kind, .topology)
            XCTAssertTrue(error.reason.contains("inverted=1"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testContainingRadiusFailsClosedWhenDeclarationIsTooSmall() throws {
        let configuration = try TestSupport.sphereConfiguration(declaredRadius: 0.49)
        do {
            _ = try SphereMeshGenerator.generate(stage: .shortMap, configuration: configuration)
            XCTFail("Expected containing-radius validation to reject the mesh")
        } catch let error as HeveaCoreError {
            guard case HeveaCoreError.sphereContainingRadiusExceeded = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testSphereMeshAndDiagnosticsRoundTripThroughJSON() throws {
        let configuration = try TestSupport.sphereConfiguration(
            longitudeCount: 24,
            nonPolarLatitudeRingCount: 15
        )
        let mesh = try SphereMeshGenerator.generate(
            stage: .proxyFamily2,
            configuration: configuration
        )
        let report = try SphereMeshDiagnostics.validate(mesh, configuration: configuration)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let decoder = JSONDecoder()
        XCTAssertEqual(
            try decoder.decode(SphereConfiguration.self, from: encoder.encode(configuration)),
            configuration
        )
        XCTAssertEqual(
            try decoder.decode(SphereMesh.self, from: encoder.encode(mesh)),
            mesh
        )
        XCTAssertEqual(
            try decoder.decode(SphereMeshDiagnosticReport.self, from: encoder.encode(report)),
            report
        )
    }
}
