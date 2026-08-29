import XCTest
@testable import HeveaCore

final class SphereNavigationTests: XCTestCase {
    func testExponentialMapPreservesNormAndGreatCircleDistance() throws {
        let origin = Vector3(x: 1, y: 0, z: 0)
        let step = Vector3(x: 0, y: 0.37, z: 0)
        let result = try SphereNavigator.exponentialMap(from: origin, tangentStep: step)
        XCTAssertEqual(result.length, 1, accuracy: 2e-14)
        XCTAssertEqual(Vector3.angle(origin, result)!, 0.37, accuracy: 2e-14)
        XCTAssertEqual(result.x, cos(0.37), accuracy: 2e-14)
        XCTAssertEqual(result.y, sin(0.37), accuracy: 2e-14)
    }

    func testPoleCrossingDoesNotUseOrBlowUpLongitudeState() throws {
        let latitude = 89 * Double.pi / 180
        let origin = TestSupport.unitDirection(longitude: 0, latitude: latitude)
        let northTangent = Vector3(x: -sin(latitude), y: 0, z: cos(latitude))
        let result = try SphereNavigator.exponentialMap(
            from: origin,
            tangentStep: northTangent * (2 * Double.pi / 180)
        )
        XCTAssertEqual(result.length, 1, accuracy: 2e-14)
        XCTAssertEqual(result.x, cos(91 * Double.pi / 180), accuracy: 2e-14)
        XCTAssertEqual(result.y, 0, accuracy: 2e-14)
        XCTAssertEqual(result.z, sin(91 * Double.pi / 180), accuracy: 2e-14)
        let address = try SphereAddress(unitDirection: result)
        XCTAssertTrue(address.longitude.isFinite)
        XCTAssertTrue(address.latitude.isFinite)
    }

    func testLongRunNavigationKeepsBoundedStateAndExactDistanceAccounting() throws {
        let configuration = try TestSupport.sphereConfiguration(maximumNavigationStep: 0.1)
        var state = try SphereNavigationState(address: .equator)
        let stepLength = 0.0001
        for _ in 0..<100_000 {
            let east = Vector3(
                x: -state.address.unitDirection.y,
                y: state.address.unitDirection.x,
                z: 0
            ).normalized()!
            state = try SphereNavigator.advance(
                state,
                tangentStep: east * stepLength,
                configuration: configuration
            )
        }
        XCTAssertEqual(state.address.unitDirection.length, 1, accuracy: 3e-14)
        XCTAssertTrue(state.address.unitDirection.isFinite)
        XCTAssertTrue(state.address.longitude.isFinite)
        XCTAssertEqual(state.traversedIntrinsicDistance, 10, accuracy: 2e-11)
        XCTAssertEqual(state.stepCount, 100_000)
    }

    func testHeadingMovementIsTangentAtEquatorAndPoles() throws {
        for address in [SphereAddress.equator, SphereAddress.southPole] {
            let step = try SphereNavigator.headingTangentStep(
                at: address,
                forward: 0.2,
                right: -0.1
            )
            XCTAssertEqual(Vector3.dot(step, address.unitDirection), 0, accuracy: 2e-14)
            XCTAssertEqual(step.length, sqrt(0.05), accuracy: 2e-14)
        }
    }

    func testAddressNormalizesDirectionWrapsHeadingAndRoundTripsJSON() throws {
        let address = try SphereAddress(
            unitDirection: Vector3(x: 2, y: 0, z: 0),
            altitude: 0.3,
            headingRadians: 5 * Double.pi
        )
        XCTAssertEqual(address.unitDirection, Vector3(x: 1, y: 0, z: 0))
        XCTAssertEqual(address.headingRadians, -Double.pi, accuracy: 1e-14)
        let encoded = try JSONEncoder().encode(address)
        XCTAssertEqual(try JSONDecoder().decode(SphereAddress.self, from: encoded), address)
    }

    func testNavigationRejectsRadialNonFiniteAndOverBudgetSteps() throws {
        XCTAssertThrowsError(
            try SphereNavigator.exponentialMap(
                from: Vector3(x: 1, y: 0, z: 0),
                tangentStep: Vector3(x: 0.01, y: 0.1, z: 0)
            )
        )
        XCTAssertThrowsError(
            try SphereNavigator.exponentialMap(
                from: Vector3(x: 1, y: 0, z: 0),
                tangentStep: Vector3(x: 0, y: 0.2, z: 0),
                maximumStepLength: 0.1
            )
        )
        XCTAssertThrowsError(
            try SphereAddress(
                unitDirection: Vector3(x: .nan, y: 0, z: 0)
            )
        )
    }
}
