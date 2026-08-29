import Foundation

public enum SphereGridVertex: Codable, Equatable, Hashable, Sendable {
    case southPole
    case ring(latitudeRing: Int, longitude: Int)
    case northPole
}

/// A closed genus-zero sampling with one canonical vertex at each pole and no
/// duplicated longitude seam. `nonPolarLatitudeRingCount` excludes both poles.
public struct SphereGrid: Codable, Equatable, Hashable, Sendable {
    public static let minimumLongitudeCount = 4
    public static let minimumNonPolarLatitudeRingCount = 3
    public static let maximumVertexCount = 65_536

    public let longitudeCount: Int
    public let nonPolarLatitudeRingCount: Int

    public init(longitudeCount: Int, nonPolarLatitudeRingCount: Int) throws {
        guard longitudeCount >= Self.minimumLongitudeCount else {
            throw HeveaCoreError.invalidSphereGrid(
                reason: "longitude count must be at least \(Self.minimumLongitudeCount)"
            )
        }
        guard nonPolarLatitudeRingCount >= Self.minimumNonPolarLatitudeRingCount else {
            throw HeveaCoreError.invalidSphereGrid(
                reason: "non-polar latitude-ring count must be at least \(Self.minimumNonPolarLatitudeRingCount)"
            )
        }
        let (ringVertices, multiplicationOverflow) = longitudeCount.multipliedReportingOverflow(
            by: nonPolarLatitudeRingCount
        )
        let (vertexCount, additionOverflow) = ringVertices.addingReportingOverflow(2)
        guard !multiplicationOverflow, !additionOverflow else {
            throw HeveaCoreError.arithmeticOverflow(context: "sphere-grid vertex count")
        }
        guard vertexCount <= Self.maximumVertexCount else {
            throw HeveaCoreError.vertexBudgetExceeded(
                vertexCount: vertexCount,
                maximum: Self.maximumVertexCount
            )
        }
        self.longitudeCount = longitudeCount
        self.nonPolarLatitudeRingCount = nonPolarLatitudeRingCount
    }

    private init(knownValidLongitudeCount: Int, knownValidRingCount: Int) {
        longitudeCount = knownValidLongitudeCount
        nonPolarLatitudeRingCount = knownValidRingCount
    }

    /// The implementation-spec default: 32,514 vertices and 65,024 triangles.
    public static let interactive = SphereGrid(
        knownValidLongitudeCount: 256,
        knownValidRingCount: 127
    )

    private enum CodingKeys: String, CodingKey {
        case longitudeCount
        case nonPolarLatitudeRingCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(
                longitudeCount: container.decode(Int.self, forKey: .longitudeCount),
                nonPolarLatitudeRingCount: container.decode(
                    Int.self,
                    forKey: .nonPolarLatitudeRingCount
                )
            )
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .longitudeCount,
                in: container,
                debugDescription: String(describing: error)
            )
        }
    }

    public var vertexCount: Int {
        2 + longitudeCount * nonPolarLatitudeRingCount
    }

    public var triangleCount: Int {
        2 * longitudeCount * (nonPolarLatitudeRingCount - 1) + 2 * longitudeCount
    }

    public var triangleIndexCount: Int { 3 * triangleCount }
    public var southPoleIndex: Int { 0 }
    public var northPoleIndex: Int { vertexCount - 1 }

    public func wrappedLongitude(_ longitude: Int) -> Int {
        let remainder = longitude % longitudeCount
        return remainder < 0 ? remainder + longitudeCount : remainder
    }

    public func index(latitudeRing: Int, longitude: Int) throws -> Int {
        guard (0..<nonPolarLatitudeRingCount).contains(latitudeRing) else {
            throw HeveaCoreError.invalidSphereGrid(
                reason: "latitude ring \(latitudeRing) is outside 0..<\(nonPolarLatitudeRingCount)"
            )
        }
        return 1 + latitudeRing * longitudeCount + wrappedLongitude(longitude)
    }

    public func index(of vertex: SphereGridVertex) throws -> Int {
        switch vertex {
        case .southPole:
            return southPoleIndex
        case let .ring(latitudeRing, longitude):
            return try index(latitudeRing: latitudeRing, longitude: longitude)
        case .northPole:
            return northPoleIndex
        }
    }

    public func vertex(for index: Int) throws -> SphereGridVertex {
        guard (0..<vertexCount).contains(index) else {
            throw HeveaCoreError.invalidSphereGrid(
                reason: "vertex index \(index) is outside 0..<\(vertexCount)"
            )
        }
        if index == southPoleIndex { return .southPole }
        if index == northPoleIndex { return .northPole }
        let ringOffset = index - 1
        return .ring(
            latitudeRing: ringOffset / longitudeCount,
            longitude: ringOffset % longitudeCount
        )
    }

    public func longitude(at longitudeIndex: Int) -> Double {
        2 * Double.pi * Double(wrappedLongitude(longitudeIndex)) / Double(longitudeCount)
    }

    public func latitude(at latitudeRing: Int) throws -> Double {
        guard (0..<nonPolarLatitudeRingCount).contains(latitudeRing) else {
            throw HeveaCoreError.invalidSphereGrid(
                reason: "latitude ring \(latitudeRing) is outside 0..<\(nonPolarLatitudeRingCount)"
            )
        }
        return -Double.pi / 2
            + Double.pi * Double(latitudeRing + 1) / Double(nonPolarLatitudeRingCount + 1)
    }

    public func unitDirection(for vertex: SphereGridVertex) throws -> Vector3 {
        switch vertex {
        case .southPole:
            return Vector3(x: 0, y: 0, z: -1)
        case let .ring(latitudeRing, longitudeIndex):
            let latitude = try latitude(at: latitudeRing)
            let longitude = longitude(at: longitudeIndex)
            let radial = cos(latitude)
            return Vector3(
                x: radial * cos(longitude),
                y: radial * sin(longitude),
                z: sin(latitude)
            )
        case .northPole:
            return Vector3(x: 0, y: 0, z: 1)
        }
    }

    public func textureCoordinate(for vertex: SphereGridVertex) throws -> Vector2 {
        switch vertex {
        case .southPole:
            return Vector2(x: 0.5, y: 0)
        case let .ring(latitudeRing, longitude):
            return Vector2(
                x: Double(wrappedLongitude(longitude)) / Double(longitudeCount),
                y: Double(latitudeRing + 1) / Double(nonPolarLatitudeRingCount + 1)
            )
        case .northPole:
            return Vector2(x: 0.5, y: 1)
        }
    }

    public func triangleIndices() throws -> [UInt32] {
        var result: [UInt32] = []
        result.reserveCapacity(triangleIndexCount)

        for longitude in 0..<longitudeCount {
            let current = UInt32(try index(latitudeRing: 0, longitude: longitude))
            let next = UInt32(try index(latitudeRing: 0, longitude: longitude + 1))
            // Reversed around the south fan so the face normal points outward.
            result.append(contentsOf: [UInt32(southPoleIndex), next, current])
        }

        if nonPolarLatitudeRingCount > 1 {
            for latitudeRing in 0..<(nonPolarLatitudeRingCount - 1) {
                for longitude in 0..<longitudeCount {
                    let lowerCurrent = UInt32(
                        try index(latitudeRing: latitudeRing, longitude: longitude)
                    )
                    let lowerNext = UInt32(
                        try index(latitudeRing: latitudeRing, longitude: longitude + 1)
                    )
                    let upperNext = UInt32(
                        try index(latitudeRing: latitudeRing + 1, longitude: longitude + 1)
                    )
                    let upperCurrent = UInt32(
                        try index(latitudeRing: latitudeRing + 1, longitude: longitude)
                    )
                    result.append(contentsOf: [lowerCurrent, lowerNext, upperNext])
                    result.append(contentsOf: [lowerCurrent, upperNext, upperCurrent])
                }
            }
        }

        let lastRing = nonPolarLatitudeRingCount - 1
        for longitude in 0..<longitudeCount {
            let current = UInt32(try index(latitudeRing: lastRing, longitude: longitude))
            let next = UInt32(try index(latitudeRing: lastRing, longitude: longitude + 1))
            result.append(contentsOf: [current, next, UInt32(northPoleIndex)])
        }
        return result
    }
}
