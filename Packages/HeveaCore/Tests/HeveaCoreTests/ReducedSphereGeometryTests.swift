import XCTest
@testable import HeveaCore

final class ReducedSphereGeometryTests: XCTestCase {
    func testExactRoundAndTranslatedCapFormulasAtLandmarks() throws {
        TestSupport.assertEqual(
            try ReducedSphereExactGeometry.roundPosition(longitude: 0, latitude: 0),
            Vector3(x: 1, y: 0, z: 0),
            accuracy: 1e-14
        )
        TestSupport.assertEqual(
            try ReducedSphereExactGeometry.roundPosition(
                longitude: Double.pi / 2,
                latitude: 0
            ),
            Vector3(x: 0, y: 1, z: 0),
            accuracy: 1e-14
        )
        TestSupport.assertEqual(
            try ReducedSphereExactGeometry.translatedCapPosition(
                longitude: 0,
                latitude: -Double.pi / 2,
                cap: .south
            ),
            Vector3(x: 0, y: 0, z: -0.5),
            accuracy: 1e-14
        )
        TestSupport.assertEqual(
            try ReducedSphereExactGeometry.translatedCapPosition(
                longitude: 0,
                latitude: Double.pi / 2,
                cap: .north
            ),
            Vector3(x: 0, y: 0, z: 0.5),
            accuracy: 1e-14
        )
    }

    func testGPLProfileRetainsEndpointPositionsAndFirstDerivatives() throws {
        let yInfinity = JudddReducedSphereProfile.yInfinity
        let cosine = cos(yInfinity)
        let sine = sin(yInfinity)
        let south = try JudddReducedSphereProfile.evaluate(latitude: -yInfinity)
        let north = try JudddReducedSphereProfile.evaluate(latitude: yInfinity)

        XCTAssertEqual(south.radial, cosine, accuracy: 2e-14)
        XCTAssertEqual(north.radial, cosine, accuracy: 2e-14)
        XCTAssertEqual(south.height, JudddReducedSphereProfile.eta - sine, accuracy: 2e-14)
        XCTAssertEqual(north.height, sine - JudddReducedSphereProfile.eta, accuracy: 2e-14)
        XCTAssertEqual(south.radialDerivative, sine, accuracy: 2e-14)
        XCTAssertEqual(north.radialDerivative, -sine, accuracy: 2e-14)
        XCTAssertEqual(south.heightDerivative, cosine, accuracy: 2e-14)
        XCTAssertEqual(north.heightDerivative, cosine, accuracy: 2e-14)
        XCTAssertEqual(south.radial, north.radial, accuracy: 0)
        XCTAssertEqual(south.height, -north.height, accuracy: 0)
        XCTAssertEqual(JudddReducedSphereProfile.coefficients.count, 10)
        XCTAssertEqual(
            JudddReducedSphereProfile.sourceRevision,
            "c098ea6fabb994bdd2555719b64ebbe8d7fca483"
        )
    }

    func testTranslatedCapsRemainExactAndEveryProxyFadesBeforeThem() throws {
        let configuration = try TestSupport.sphereConfiguration()
        let latitude = 1.55
        let direction = TestSupport.unitDirection(longitude: 1.2, latitude: latitude)
        let exact = try ReducedSphereExactGeometry.translatedCapPosition(
            longitude: 1.2,
            latitude: latitude,
            cap: .north
        )
        for stage in SphereStage.allCases.dropFirst() {
            let sample = try SphereMeshGenerator.sample(
                at: direction,
                stage: stage,
                configuration: configuration
            )
            TestSupport.assertEqual(sample.position, exact, accuracy: 2e-14)
            XCTAssertEqual(sample.proxyDisplacementMagnitude, 0)
            XCTAssertEqual(sample.ribbonRank, 0)
            XCTAssertEqual(sample.familyWeights, [0, 0, 0])
        }
    }

    func testNestedProxyFamiliesActivateInCapToEquatorOrder() throws {
        let configuration = try TestSupport.sphereConfiguration()
        let yInfinity = JudddReducedSphereProfile.yInfinity
        let probes: [(fraction: Double, rank: Int)] = [
            (0.95, 0),
            (0.80, 1),
            (0.55, 2),
            (0.20, 3),
            (0.00, 3),
        ]
        for probe in probes {
            let sample = try SphereMeshGenerator.sample(
                at: TestSupport.unitDirection(
                    longitude: 0.173,
                    latitude: probe.fraction * yInfinity
                ),
                stage: .proxyFamily3,
                configuration: configuration
            )
            XCTAssertEqual(sample.ribbonRank, probe.rank, "fraction \(probe.fraction)")
        }

        for familyIndex in 0..<3 {
            let family = configuration.proxySchedule.corrugations[familyIndex]
            let supportLatitude = family.supportHalfWidthFraction * yInfinity
            let sample = try SphereMeshGenerator.sample(
                at: TestSupport.unitDirection(longitude: 0.37, latitude: supportLatitude),
                stage: .proxyFamily3,
                configuration: configuration
            )
            XCTAssertEqual(sample.familyWeights[familyIndex], 0, accuracy: 0)
        }
    }

    func testRidgeMetadataNeverConflatesPaperAndRenderedCounts() throws {
        let configuration = try TestSupport.sphereConfiguration()
        let manifest = SphereMeshManifest(stage: .proxyFamily2, configuration: configuration)
        XCTAssertEqual(manifest.ridgeMetadata.map(\.paperRidgeCount), [21, 142, 997])
        XCTAssertEqual(manifest.ridgeMetadata.map(\.renderedRidgeCount), [7, 13, 21])
        XCTAssertEqual(manifest.ridgeMetadata.map(\.isApplied), [true, true, false])
        XCTAssertEqual(manifest.appliedProxyCorrugations.count, 2)
        XCTAssertEqual(manifest.source.profileLicenseIdentifier, "GPL-3.0")
        XCTAssertTrue(manifest.claimCeiling.contains("f_{1,3}"))
    }

    func testProxyScheduleRejectsMissingLabelsWrongPaperCountsAndUnnestedSupports() {
        let valid = SphereProxySchedule.default.corrugations
        XCTAssertThrowsError(try SphereProxySchedule(corrugations: Array(valid.prefix(2))))

        var invalid = valid
        invalid[0] = SphereProxyCorrugation(
            displayName: "Family 1",
            primitiveDirection: .diagonalPlus,
            paperRidgeCount: 21,
            renderedRidgeCount: 7,
            amplitude: 0.006,
            supportHalfWidthFraction: 0.45,
            fullStrengthFraction: 0.7
        )
        XCTAssertThrowsError(try SphereProxySchedule(corrugations: invalid))

        invalid = valid
        invalid[1] = SphereProxyCorrugation(
            displayName: valid[1].displayName,
            primitiveDirection: .diagonalMinus,
            paperRidgeCount: 141,
            renderedRidgeCount: 13,
            amplitude: 0.0035,
            supportHalfWidthFraction: 0.68,
            fullStrengthFraction: 0.74
        )
        XCTAssertThrowsError(try SphereProxySchedule(corrugations: invalid))

        invalid = valid
        invalid[2] = SphereProxyCorrugation(
            displayName: valid[2].displayName,
            primitiveDirection: .latitude,
            paperRidgeCount: 997,
            renderedRidgeCount: 21,
            amplitude: 0.002,
            supportHalfWidthFraction: 0.6,
            fullStrengthFraction: 0.78
        )
        XCTAssertThrowsError(try SphereProxySchedule(corrugations: invalid))
    }

    func testLongitudeSeamAndSuccessiveStagesAreDeterministicAndDistinct() throws {
        let configuration = try TestSupport.sphereConfiguration()
        let point = TestSupport.unitDirection(longitude: 0.417, latitude: 0.31)
        let wrapped = TestSupport.unitDirection(
            longitude: 0.417 + 2 * Double.pi,
            latitude: 0.31
        )
        var prior: Vector3?
        for stage in SphereStage.allCases {
            let first = try SphereMeshGenerator.position(
                at: point,
                stage: stage,
                configuration: configuration
            )
            let second = try SphereMeshGenerator.position(
                at: wrapped,
                stage: stage,
                configuration: configuration
            )
            TestSupport.assertEqual(first, second, accuracy: 2e-14)
            if let prior { XCTAssertNotEqual(first, prior) }
            prior = first
        }
    }
}
