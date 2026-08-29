import XCTest
@testable import HeveaCore

final class PeriodicGridTests: XCTestCase {
    func testTopologyCountsAndIndexBounds() throws {
        let grid = try PeriodicGrid(uCount: 9, vCount: 13)
        let indices = grid.triangleIndices()

        XCTAssertEqual(grid.vertexCount, 117)
        XCTAssertEqual(grid.triangleCount, 234)
        XCTAssertEqual(grid.triangleIndexCount, 702)
        XCTAssertEqual(indices.count, grid.triangleIndexCount)
        XCTAssertTrue(indices.allSatisfy { Int($0) < grid.vertexCount })
    }

    func testBothSeamsWrapWithoutDuplicatedVertices() throws {
        let grid = try PeriodicGrid(uCount: 7, vCount: 11)

        XCTAssertEqual(grid.index(u: 0, v: 0), grid.index(u: 7, v: 11))
        XCTAssertEqual(grid.index(u: -1, v: -1), grid.index(u: 6, v: 10))
        XCTAssertEqual(grid.index(u: 2, v: -12), grid.index(u: 2, v: 10))

        let lastCellOffset = ((grid.uCount - 1) * grid.vCount + (grid.vCount - 1)) * 6
        let lastCell = Array(grid.triangleIndices()[lastCellOffset..<(lastCellOffset + 6)])
        let a = UInt32(grid.index(u: 6, v: 10))
        let b = UInt32(grid.index(u: 0, v: 10))
        let c = UInt32(grid.index(u: 0, v: 0))
        let d = UInt32(grid.index(u: 6, v: 0))
        XCTAssertEqual(lastCell, [a, c, b, a, d, c])
    }

    func testParameterSamplesAndUVsStayInHalfOpenUnitSquare() throws {
        let grid = try PeriodicGrid(uCount: 8, vCount: 10)
        for u in -2..<(grid.uCount + 2) {
            for v in -2..<(grid.vCount + 2) {
                let point = grid.parameterPoint(u: u, v: v)
                let uv = grid.textureCoordinate(u: u, v: v)
                XCTAssertTrue((0..<1).contains(point.u))
                XCTAssertTrue((0..<1).contains(point.v))
                XCTAssertEqual(uv, Vector2(x: point.u, y: point.v))
            }
        }
    }

    func testVisibleVertexBudgetIsEnforcedAtBoundary() throws {
        let maximum = try PeriodicGrid(uCount: 256, vCount: 256)
        XCTAssertEqual(maximum.vertexCount, PeriodicGrid.maximumVertexCount)

        XCTAssertThrowsError(try PeriodicGrid(uCount: 257, vCount: 256)) { error in
            guard case let HeveaCoreError.vertexBudgetExceeded(vertexCount, maximum) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(vertexCount, 65_792)
            XCTAssertEqual(maximum, 65_536)
        }
    }

    func testCoordinateRoundTrip() throws {
        let grid = try PeriodicGrid(uCount: 6, vCount: 9)
        for index in 0..<grid.vertexCount {
            let coordinate = try grid.coordinate(for: index)
            XCTAssertEqual(grid.index(of: coordinate), index)
        }
        XCTAssertThrowsError(try grid.coordinate(for: -1))
        XCTAssertThrowsError(try grid.coordinate(for: grid.vertexCount))
    }
}
