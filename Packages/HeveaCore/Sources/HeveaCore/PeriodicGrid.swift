import Foundation

public struct GridCoordinate: Codable, Equatable, Hashable, Sendable {
    public var u: Int
    public var v: Int

    public init(u: Int, v: Int) {
        self.u = u
        self.v = v
    }
}

/// A rectangular sampling of `R²/Z²` with no duplicated seam vertices.
public struct PeriodicGrid: Codable, Equatable, Hashable, Sendable {
    public static let minimumDimension = 4
    public static let maximumVertexCount = 65_536

    public let uCount: Int
    public let vCount: Int

    public init(uCount: Int, vCount: Int) throws {
        guard uCount >= Self.minimumDimension, vCount >= Self.minimumDimension else {
            throw HeveaCoreError.gridDimensionTooSmall(
                uCount: uCount,
                vCount: vCount,
                minimum: Self.minimumDimension
            )
        }
        let (count, overflow) = uCount.multipliedReportingOverflow(by: vCount)
        guard !overflow else {
            throw HeveaCoreError.arithmeticOverflow(context: "periodic-grid vertex count")
        }
        guard count <= Self.maximumVertexCount else {
            throw HeveaCoreError.vertexBudgetExceeded(
                vertexCount: count,
                maximum: Self.maximumVertexCount
            )
        }
        self.uCount = uCount
        self.vCount = vCount
    }

    private init(knownValidUCount: Int, knownValidVCount: Int) {
        uCount = knownValidUCount
        vCount = knownValidVCount
    }

    /// A bounded default suitable for interactive generation and diagnostics.
    public static let interactive = PeriodicGrid(knownValidUCount: 96, knownValidVCount: 128)

    private enum CodingKeys: String, CodingKey {
        case uCount
        case vCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let uCount = try container.decode(Int.self, forKey: .uCount)
        let vCount = try container.decode(Int.self, forKey: .vCount)
        do {
            try self.init(uCount: uCount, vCount: vCount)
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .uCount,
                in: container,
                debugDescription: String(describing: error)
            )
        }
    }

    public var vertexCount: Int { uCount * vCount }
    public var triangleCount: Int { 2 * vertexCount }
    public var triangleIndexCount: Int { 3 * triangleCount }

    public func wrapped(_ coordinate: GridCoordinate) -> GridCoordinate {
        GridCoordinate(u: wrap(coordinate.u, modulus: uCount), v: wrap(coordinate.v, modulus: vCount))
    }

    public func index(u: Int, v: Int) -> Int {
        let wrappedU = wrap(u, modulus: uCount)
        let wrappedV = wrap(v, modulus: vCount)
        return wrappedU * vCount + wrappedV
    }

    public func index(of coordinate: GridCoordinate) -> Int {
        index(u: coordinate.u, v: coordinate.v)
    }

    public func coordinate(for index: Int) throws -> GridCoordinate {
        guard (0..<vertexCount).contains(index) else {
            throw HeveaCoreError.invalidDiagnosticConfiguration(
                reason: "vertex index \(index) is outside 0..<\(vertexCount)"
            )
        }
        return GridCoordinate(u: index / vCount, v: index % vCount)
    }

    public func parameterPoint(u: Int, v: Int) -> ParameterPoint {
        let coordinate = wrapped(GridCoordinate(u: u, v: v))
        return ParameterPoint(
            u: Double(coordinate.u) / Double(uCount),
            v: Double(coordinate.v) / Double(vCount)
        )
    }

    public func textureCoordinate(u: Int, v: Int) -> Vector2 {
        let point = parameterPoint(u: u, v: v)
        return Vector2(x: point.u, y: point.v)
    }

    public func triangleIndices() -> [UInt32] {
        var result: [UInt32] = []
        result.reserveCapacity(triangleIndexCount)

        for u in 0..<uCount {
            for v in 0..<vCount {
                let a = UInt32(index(u: u, v: v))
                let b = UInt32(index(u: u + 1, v: v))
                let c = UInt32(index(u: u + 1, v: v + 1))
                let d = UInt32(index(u: u, v: v + 1))

                // The surface uses (u = tube, v = revolution). This order gives
                // outward-facing winding for the upstream short-torus formula.
                result.append(contentsOf: [a, c, b, a, d, c])
            }
        }
        return result
    }

    private func wrap(_ value: Int, modulus: Int) -> Int {
        let remainder = value % modulus
        return remainder < 0 ? remainder + modulus : remainder
    }
}
