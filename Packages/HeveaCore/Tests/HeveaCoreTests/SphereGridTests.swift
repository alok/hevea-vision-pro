import XCTest
@testable import HeveaCore

final class SphereGridTests: XCTestCase {
    func testInteractiveGridHasSpecifiedSinglePoleTopologyCounts() throws {
        let grid = SphereGrid.interactive
        XCTAssertEqual(grid.longitudeCount, 256)
        XCTAssertEqual(grid.nonPolarLatitudeRingCount, 127)
        XCTAssertEqual(grid.vertexCount, 32_514)
        XCTAssertEqual(grid.triangleCount, 65_024)
        XCTAssertEqual(grid.triangleIndexCount, 195_072)
        XCTAssertEqual(grid.southPoleIndex, 0)
        XCTAssertEqual(grid.northPoleIndex, grid.vertexCount - 1)

        let indices = try grid.triangleIndices()
        XCTAssertEqual(indices.count, grid.triangleIndexCount)
        XCTAssertTrue(indices.allSatisfy { Int($0) < grid.vertexCount })
        XCTAssertEqual(indices.filter { Int($0) == grid.southPoleIndex }.count, 256)
        XCTAssertEqual(indices.filter { Int($0) == grid.northPoleIndex }.count, 256)
    }

    func testLongitudeWrapDoesNotDuplicateVertices() throws {
        let grid = try SphereGrid(longitudeCount: 12, nonPolarLatitudeRingCount: 7)
        for ring in 0..<grid.nonPolarLatitudeRingCount {
            XCTAssertEqual(
                try grid.index(latitudeRing: ring, longitude: 0),
                try grid.index(latitudeRing: ring, longitude: 12)
            )
            XCTAssertEqual(
                try grid.index(latitudeRing: ring, longitude: -1),
                try grid.index(latitudeRing: ring, longitude: 11)
            )
        }
        XCTAssertEqual(try grid.index(of: .southPole), grid.southPoleIndex)
        XCTAssertEqual(try grid.index(of: .northPole), grid.northPoleIndex)
    }

    func testVertexCoordinateRoundTripAndPoleUVs() throws {
        let grid = try SphereGrid(longitudeCount: 9, nonPolarLatitudeRingCount: 5)
        for index in 0..<grid.vertexCount {
            let vertex = try grid.vertex(for: index)
            XCTAssertEqual(try grid.index(of: vertex), index)
            XCTAssertTrue(try grid.unitDirection(for: vertex).isFinite)
            XCTAssertTrue(try grid.textureCoordinate(for: vertex).isFinite)
        }
        XCTAssertEqual(try grid.textureCoordinate(for: .southPole), Vector2(x: 0.5, y: 0))
        XCTAssertEqual(try grid.textureCoordinate(for: .northPole), Vector2(x: 0.5, y: 1))
    }

    func testSphereGridBudgetAndMinimumsFailClosed() throws {
        XCTAssertThrowsError(
            try SphereGrid(longitudeCount: 3, nonPolarLatitudeRingCount: 8)
        )
        XCTAssertThrowsError(
            try SphereGrid(longitudeCount: 8, nonPolarLatitudeRingCount: 2)
        )
        let maximumNearBoundary = try SphereGrid(
            longitudeCount: 256,
            nonPolarLatitudeRingCount: 255
        )
        XCTAssertEqual(maximumNearBoundary.vertexCount, 65_282)
        XCTAssertThrowsError(
            try SphereGrid(longitudeCount: 256, nonPolarLatitudeRingCount: 256)
        ) { error in
            guard case let HeveaCoreError.vertexBudgetExceeded(vertexCount, maximum) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(vertexCount, 65_538)
            XCTAssertEqual(maximum, 65_536)
        }
    }
}
