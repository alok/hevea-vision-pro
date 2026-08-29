import Foundation

public struct SphereAddress: Codable, Equatable, Sendable {
    public let unitDirection: Vector3
    public let altitude: Double
    public let headingRadians: Double

    public init(
        unitDirection: Vector3,
        altitude: Double = 0,
        headingRadians: Double = 0
    ) throws {
        guard unitDirection.isFinite, let normalized = unitDirection.normalized() else {
            throw HeveaCoreError.invalidSphereAddress(
                reason: "unit direction must be finite and nonzero"
            )
        }
        guard altitude.isFinite, headingRadians.isFinite else {
            throw HeveaCoreError.invalidSphereAddress(
                reason: "altitude and heading must be finite"
            )
        }
        self.unitDirection = normalized
        self.altitude = altitude
        self.headingRadians = Self.wrappedAngle(headingRadians)
    }

    private init(knownValidDirection: Vector3, altitude: Double, headingRadians: Double) {
        unitDirection = knownValidDirection
        self.altitude = altitude
        self.headingRadians = headingRadians
    }

    public static let southPole = SphereAddress(
        knownValidDirection: Vector3(x: 0, y: 0, z: -1),
        altitude: 0,
        headingRadians: 0
    )
    public static let equator = SphereAddress(
        knownValidDirection: Vector3(x: 1, y: 0, z: 0),
        altitude: 0,
        headingRadians: 0
    )

    public var latitude: Double {
        asin(min(1, max(-1, unitDirection.z)))
    }

    public var longitude: Double {
        guard abs(unitDirection.x) + abs(unitDirection.y) > 1e-14 else { return 0 }
        let angle = atan2(unitDirection.y, unitDirection.x)
        return angle < 0 ? angle + 2 * Double.pi : angle
    }

    public func withAltitude(_ altitude: Double) throws -> SphereAddress {
        try SphereAddress(
            unitDirection: unitDirection,
            altitude: altitude,
            headingRadians: headingRadians
        )
    }

    public func turned(by radians: Double) throws -> SphereAddress {
        guard radians.isFinite else {
            throw HeveaCoreError.invalidSphereAddress(reason: "heading change must be finite")
        }
        return try SphereAddress(
            unitDirection: unitDirection,
            altitude: altitude,
            headingRadians: headingRadians + radians
        )
    }

    private enum CodingKeys: String, CodingKey {
        case unitDirection
        case altitude
        case headingRadians
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(
                unitDirection: container.decode(Vector3.self, forKey: .unitDirection),
                altitude: container.decode(Double.self, forKey: .altitude),
                headingRadians: container.decode(Double.self, forKey: .headingRadians)
            )
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .unitDirection,
                in: container,
                debugDescription: String(describing: error)
            )
        }
    }

    static func wrappedAngle(_ angle: Double) -> Double {
        let fullTurn = 2 * Double.pi
        var result = (angle + Double.pi).truncatingRemainder(dividingBy: fullTurn)
        if result < 0 { result += fullTurn }
        return result - Double.pi
    }
}

public struct SphereNavigationState: Codable, Equatable, Sendable {
    public let address: SphereAddress
    public let traversedIntrinsicDistance: Double
    public let stepCount: UInt64

    public init(
        address: SphereAddress,
        traversedIntrinsicDistance: Double = 0,
        stepCount: UInt64 = 0
    ) throws {
        guard traversedIntrinsicDistance.isFinite, traversedIntrinsicDistance >= 0 else {
            throw HeveaCoreError.invalidSphereAddress(
                reason: "traversed distance must be finite and nonnegative"
            )
        }
        self.address = address
        self.traversedIntrinsicDistance = traversedIntrinsicDistance
        self.stepCount = stepCount
    }

    private enum CodingKeys: String, CodingKey {
        case address
        case traversedIntrinsicDistance
        case stepCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(
                address: container.decode(SphereAddress.self, forKey: .address),
                traversedIntrinsicDistance: container.decode(
                    Double.self,
                    forKey: .traversedIntrinsicDistance
                ),
                stepCount: container.decode(UInt64.self, forKey: .stepCount)
            )
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .traversedIntrinsicDistance,
                in: container,
                debugDescription: String(describing: error)
            )
        }
    }
}

public enum SphereNavigator {
    /// The S² exponential map `cos(s)q + sin(s)v/s`, where `v` must be tangent
    /// at `q`. No longitude is used as navigation state.
    public static func exponentialMap(
        from unitDirection: Vector3,
        tangentStep: Vector3,
        maximumStepLength: Double = Double.pi
    ) throws -> Vector3 {
        guard unitDirection.isFinite, let direction = unitDirection.normalized() else {
            throw HeveaCoreError.invalidSphereAddress(
                reason: "exponential-map origin must be finite and nonzero"
            )
        }
        guard tangentStep.isFinite,
              maximumStepLength.isFinite,
              maximumStepLength > 0
        else {
            throw HeveaCoreError.invalidSphereAddress(
                reason: "tangent step and maximum step must be finite"
            )
        }
        let length = tangentStep.length
        guard length.isFinite, length <= maximumStepLength else {
            throw HeveaCoreError.invalidSphereAddress(
                reason: "step length \(length) exceeds the \(maximumStepLength) budget"
            )
        }
        guard length > 1e-15 else { return direction }
        let radialComponent = Vector3.dot(direction, tangentStep)
        let tangencyTolerance = 1e-10 * max(1, length)
        guard abs(radialComponent) <= tangencyTolerance else {
            throw HeveaCoreError.invalidSphereAddress(
                reason: "step has non-tangent radial component \(radialComponent)"
            )
        }
        let result = cos(length) * direction + sin(length) * (tangentStep / length)
        guard let normalized = result.normalized(), normalized.isFinite else {
            throw HeveaCoreError.nonFiniteValue(context: "sphere exponential map")
        }
        return normalized
    }

    public static func advance(
        _ state: SphereNavigationState,
        tangentStep: Vector3,
        configuration: SphereConfiguration = .default
    ) throws -> SphereNavigationState {
        try configuration.validate()
        let stepLength = tangentStep.length
        let nextDirection = try exponentialMap(
            from: state.address.unitDirection,
            tangentStep: tangentStep,
            maximumStepLength: configuration.maximumNavigationStep
        )
        let (nextStepCount, overflow) = state.stepCount.addingReportingOverflow(1)
        guard !overflow else {
            throw HeveaCoreError.arithmeticOverflow(context: "sphere navigation step count")
        }
        let distance = state.traversedIntrinsicDistance + stepLength
        guard distance.isFinite else {
            throw HeveaCoreError.nonFiniteValue(context: "sphere traversed distance")
        }
        return try SphereNavigationState(
            address: SphereAddress(
                unitDirection: nextDirection,
                altitude: state.address.altitude,
                headingRadians: state.address.headingRadians
            ),
            traversedIntrinsicDistance: distance,
            stepCount: nextStepCount
        )
    }

    /// Deterministic tangent frame used by simulator/accessibility walk pads.
    /// The fallback at a pole changes only the derived control frame, never the
    /// authoritative address.
    public static func tangentFrame(at address: SphereAddress) -> (east: Vector3, north: Vector3) {
        let q = address.unitDirection
        let zAxis = Vector3(x: 0, y: 0, z: 1)
        let fallback = Vector3(x: 0, y: 1, z: 0)
        let east = Vector3.cross(zAxis, q).normalized()
            ?? Vector3.cross(fallback, q).normalized()
            ?? Vector3(x: 1, y: 0, z: 0)
        let north = Vector3.cross(q, east).normalized() ?? Vector3(x: 0, y: 1, z: 0)
        return (east: east, north: north)
    }

    public static func headingTangentStep(
        at address: SphereAddress,
        forward: Double,
        right: Double
    ) throws -> Vector3 {
        guard forward.isFinite, right.isFinite else {
            throw HeveaCoreError.invalidSphereAddress(
                reason: "heading-relative movement must be finite"
            )
        }
        let frame = tangentFrame(at: address)
        let forwardDirection = cos(address.headingRadians) * frame.north
            + sin(address.headingRadians) * frame.east
        let rightDirection = -sin(address.headingRadians) * frame.north
            + cos(address.headingRadians) * frame.east
        return forward * forwardDirection + right * rightDirection
    }
}
