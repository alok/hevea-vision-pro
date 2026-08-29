import XCTest
@testable import HeveaCore

enum TestSupport {
    static func configuration(
        uCount: Int = 32,
        vCount: Int = 48,
        schedule: ProxySchedule = .default
    ) throws -> TorusConfiguration {
        try TorusConfiguration(
            grid: PeriodicGrid(uCount: uCount, vCount: vCount),
            minorRadius: 0.2,
            majorRadius: 0.5,
            proxySchedule: schedule
        )
    }

    static func sphereConfiguration(
        longitudeCount: Int = 48,
        nonPolarLatitudeRingCount: Int = 31,
        schedule: SphereProxySchedule = .default,
        declaredRadius: Double = JudddReducedSphereProfile.certifiedContainingRadius,
        maximumNavigationStep: Double = Double.pi
    ) throws -> SphereConfiguration {
        try SphereConfiguration(
            grid: SphereGrid(
                longitudeCount: longitudeCount,
                nonPolarLatitudeRingCount: nonPolarLatitudeRingCount
            ),
            proxySchedule: schedule,
            declaredProxyContainingRadius: declaredRadius,
            maximumNavigationStep: maximumNavigationStep
        )
    }

    static func unitDirection(longitude: Double, latitude: Double) -> Vector3 {
        let radial = cos(latitude)
        return Vector3(
            x: radial * cos(longitude),
            y: radial * sin(longitude),
            z: sin(latitude)
        )
    }

    static func assertEqual(
        _ lhs: Vector3,
        _ rhs: Vector3,
        accuracy: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(lhs.x, rhs.x, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.y, rhs.y, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(lhs.z, rhs.z, accuracy: accuracy, file: file, line: line)
    }
}
