import XCTest
@testable import HeveaCore

final class HeveaCoreSmokeTests: XCTestCase {
    func testPackageResolvesWithDedicatedTestTarget() throws {
        let grid = try PeriodicGrid(uCount: 8, vCount: 8)
        XCTAssertEqual(grid.vertexCount, 64)
    }
}
