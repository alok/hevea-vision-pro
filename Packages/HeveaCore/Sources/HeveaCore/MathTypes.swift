import Foundation

/// A platform-neutral two-dimensional vector.
public struct Vector2: Codable, Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = Vector2(x: 0, y: 0)

    public var isFinite: Bool { x.isFinite && y.isFinite }
    public var squaredLength: Double { x * x + y * y }
    public var length: Double { sqrt(squaredLength) }

    public static func + (lhs: Vector2, rhs: Vector2) -> Vector2 {
        Vector2(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    public static func - (lhs: Vector2, rhs: Vector2) -> Vector2 {
        Vector2(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    public static prefix func - (value: Vector2) -> Vector2 {
        Vector2(x: -value.x, y: -value.y)
    }

    public static func * (lhs: Vector2, rhs: Double) -> Vector2 {
        Vector2(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    public static func * (lhs: Double, rhs: Vector2) -> Vector2 { rhs * lhs }

    public static func / (lhs: Vector2, rhs: Double) -> Vector2 {
        Vector2(x: lhs.x / rhs, y: lhs.y / rhs)
    }
}

/// A platform-neutral three-dimensional vector used by `HeveaMesh`.
public struct Vector3: Codable, Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static let zero = Vector3(x: 0, y: 0, z: 0)

    public var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
    public var squaredLength: Double { x * x + y * y + z * z }
    public var length: Double { sqrt(squaredLength) }

    public func normalized(epsilon: Double = 1e-14) -> Vector3? {
        let magnitude = length
        guard magnitude.isFinite, magnitude > epsilon else { return nil }
        let result = self / magnitude
        return result.isFinite ? result : nil
    }

    public static func dot(_ lhs: Vector3, _ rhs: Vector3) -> Double {
        lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
    }

    public static func cross(_ lhs: Vector3, _ rhs: Vector3) -> Vector3 {
        Vector3(
            x: lhs.y * rhs.z - lhs.z * rhs.y,
            y: lhs.z * rhs.x - lhs.x * rhs.z,
            z: lhs.x * rhs.y - lhs.y * rhs.x
        )
    }

    public static func distance(_ lhs: Vector3, _ rhs: Vector3) -> Double {
        (lhs - rhs).length
    }

    public static func angle(_ lhs: Vector3, _ rhs: Vector3) -> Double? {
        guard let left = lhs.normalized(), let right = rhs.normalized() else { return nil }
        let cosine = min(1, max(-1, dot(left, right)))
        let result = acos(cosine)
        return result.isFinite ? result : nil
    }

    public static func + (lhs: Vector3, rhs: Vector3) -> Vector3 {
        Vector3(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    public static func - (lhs: Vector3, rhs: Vector3) -> Vector3 {
        Vector3(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    public static prefix func - (value: Vector3) -> Vector3 {
        Vector3(x: -value.x, y: -value.y, z: -value.z)
    }

    public static func * (lhs: Vector3, rhs: Double) -> Vector3 {
        Vector3(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }

    public static func * (lhs: Double, rhs: Vector3) -> Vector3 { rhs * lhs }

    public static func / (lhs: Vector3, rhs: Double) -> Vector3 {
        Vector3(x: lhs.x / rhs, y: lhs.y / rhs, z: lhs.z / rhs)
    }
}

/// Coordinates on the unwrapped parameter plane. Mesh lookup wraps them into `R²/Z²`.
public struct ParameterPoint: Codable, Equatable, Hashable, Sendable {
    public var u: Double
    public var v: Double

    public init(u: Double, v: Double) {
        self.u = u
        self.v = v
    }

    public static let zero = ParameterPoint(u: 0, v: 0)
    public var isFinite: Bool { u.isFinite && v.isFinite }

    public var wrapped: ParameterPoint {
        ParameterPoint(u: Self.wrapUnit(u), v: Self.wrapUnit(v))
    }

    private static func wrapUnit(_ value: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: 1)
        return remainder < 0 ? remainder + 1 : remainder
    }
}

public enum HeveaCoreError: Error, Equatable, Sendable, CustomStringConvertible {
    case gridDimensionTooSmall(uCount: Int, vCount: Int, minimum: Int)
    case vertexBudgetExceeded(vertexCount: Int, maximum: Int)
    case arithmeticOverflow(context: String)
    case invalidRadius(minor: Double, major: Double)
    case invalidProxySchedule(reason: String)
    case inconsistentMeshData(field: String, expected: Int, actual: Int)
    case invalidMeshIndex(index: UInt32, vertexCount: Int)
    case nonFiniteValue(context: String)
    case degenerateNormal(u: Int, v: Int)
    case invalidDiagnosticConfiguration(reason: String)
    case invalidCurve(reason: String)
    case invalidSphereGrid(reason: String)
    case invalidSphereConfiguration(reason: String)
    case invalidSphereAddress(reason: String)
    case sphereTopologyViolation(reason: String)
    case sphereSeamViolation(positionResidual: Double, normalResidualRadians: Double)
    case sphereContainingRadiusExceeded(measured: Double, declared: Double)
    case degenerateSphereTriangle(index: Int, doubledArea: Double)
    case invertedSphereTriangle(index: Int, orientationDot: Double)

    public var description: String {
        switch self {
        case let .gridDimensionTooSmall(uCount, vCount, minimum):
            "Grid dimensions (\(uCount), \(vCount)) must each be at least \(minimum)."
        case let .vertexBudgetExceeded(vertexCount, maximum):
            "Grid has \(vertexCount) vertices; the visible-surface budget is \(maximum)."
        case let .arithmeticOverflow(context):
            "Integer arithmetic overflow while computing \(context)."
        case let .invalidRadius(minor, major):
            "Short-torus radii must be finite and positive with minor + major < 1; got \(minor), \(major)."
        case let .invalidProxySchedule(reason):
            "Invalid real-time proxy schedule: \(reason)"
        case let .inconsistentMeshData(field, expected, actual):
            "Mesh field \(field) contains \(actual) values; expected \(expected)."
        case let .invalidMeshIndex(index, vertexCount):
            "Triangle index \(index) is outside the \(vertexCount)-vertex mesh."
        case let .nonFiniteValue(context):
            "A non-finite numerical value occurred in \(context)."
        case let .degenerateNormal(u, v):
            "Could not construct a finite surface normal at grid coordinate (\(u), \(v))."
        case let .invalidDiagnosticConfiguration(reason):
            "Invalid diagnostic configuration: \(reason)"
        case let .invalidCurve(reason):
            "Invalid curve diagnostic: \(reason)"
        case let .invalidSphereGrid(reason):
            "Invalid reduced-sphere grid: \(reason)"
        case let .invalidSphereConfiguration(reason):
            "Invalid reduced-sphere configuration: \(reason)"
        case let .invalidSphereAddress(reason):
            "Invalid intrinsic sphere address: \(reason)"
        case let .sphereTopologyViolation(reason):
            "Reduced-sphere topology validation failed: \(reason)"
        case let .sphereSeamViolation(positionResidual, normalResidualRadians):
            "Reduced-sphere cap seam exceeded tolerance (position \(positionResidual), normal \(normalResidualRadians) rad)."
        case let .sphereContainingRadiusExceeded(measured, declared):
            "Reduced-sphere containing radius \(measured) exceeds declared bound \(declared)."
        case let .degenerateSphereTriangle(index, doubledArea):
            "Reduced-sphere triangle \(index) is degenerate (doubled area \(doubledArea))."
        case let .invertedSphereTriangle(index, orientationDot):
            "Reduced-sphere triangle \(index) is inverted (orientation dot \(orientationDot))."
        }
    }
}
