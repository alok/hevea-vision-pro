import Foundation

/// The visible claim badge required by the Hevea Vision provenance contract.
public enum ClaimClass: String, Codable, CaseIterable, Equatable, Sendable {
    case upstreamBaseline = "UPSTREAM BASELINE"
    case realTimeProxy = "REAL-TIME PROXY"
    case heveaVisionExperiment = "HV EXPERIMENT"
}

public struct LatticeDirection: Codable, Equatable, Hashable, Sendable {
    public let u: Int
    public let v: Int

    public init(u: Int, v: Int) {
        self.u = u
        self.v = v
    }

    public var label: String {
        switch (u, v) {
        case (1, 0): "u"
        case (0, 1): "v"
        default: "\(u)u \(v < 0 ? "-" : "+") \(abs(v))v"
        }
    }
}

public enum HeveaStage: String, Codable, CaseIterable, Equatable, Sendable {
    case shortTorus
    case proxyStage1
    case proxyStage2
    case proxyStage3

    public var displayName: String {
        switch self {
        case .shortTorus: "UPSTREAM BASELINE — Short Torus"
        case .proxyStage1: "REAL-TIME PROXY 1 — u Corrugation"
        case .proxyStage2: "REAL-TIME PROXY 2 — u + 2v Corrugation"
        case .proxyStage3: "REAL-TIME PROXY 3 — u - 2v Corrugation"
        }
    }

    public var shortDisplayName: String {
        switch self {
        case .shortTorus: "Short Torus"
        case .proxyStage1: "Proxy Stage 1"
        case .proxyStage2: "Proxy Stage 2"
        case .proxyStage3: "Proxy Stage 3"
        }
    }

    public var claimClass: ClaimClass {
        self == .shortTorus ? .upstreamBaseline : .realTimeProxy
    }

    public var appliedCorrugationCount: Int {
        switch self {
        case .shortTorus: 0
        case .proxyStage1: 1
        case .proxyStage2: 2
        case .proxyStage3: 3
        }
    }

    public var explanation: String {
        switch self {
        case .shortTorus:
            "The exact finite short torus of revolution used to initialize the pinned GPL Hévéa implementation."
        case .proxyStage1:
            "A low-frequency explanatory normal ripple along the first primitive metric direction. It is not the upstream corrugation."
        case .proxyStage2:
            "Adds a compressed explanatory ripple along the second lattice direction. It is not claimed to preserve the flat metric."
        case .proxyStage3:
            "Adds the third compressed explanatory ripple. This finite mesh is not the limiting C1 isometric embedding."
        }
    }

    public var proxyDescriptor: ProxyStageDescriptor? {
        guard appliedCorrugationCount > 0 else { return nil }
        return ProxyStageDescriptor.defaults[appliedCorrugationCount - 1]
    }
}

public struct ProxyStageDescriptor: Codable, Equatable, Sendable {
    public let stage: HeveaStage
    public let displayName: String
    public let direction: LatticeDirection
    public let defaultFrequency: Int
    public let upstreamReferenceFrequency: Int
    public let claimClass: ClaimClass

    public init(
        stage: HeveaStage,
        displayName: String,
        direction: LatticeDirection,
        defaultFrequency: Int,
        upstreamReferenceFrequency: Int,
        claimClass: ClaimClass = .realTimeProxy
    ) {
        self.stage = stage
        self.displayName = displayName
        self.direction = direction
        self.defaultFrequency = defaultFrequency
        self.upstreamReferenceFrequency = upstreamReferenceFrequency
        self.claimClass = claimClass
    }

    public static let defaults: [ProxyStageDescriptor] = [
        ProxyStageDescriptor(
            stage: .proxyStage1,
            displayName: "REAL-TIME PROXY 1 — u Corrugation",
            direction: LatticeDirection(u: 1, v: 0),
            defaultFrequency: 5,
            upstreamReferenceFrequency: 12
        ),
        ProxyStageDescriptor(
            stage: .proxyStage2,
            displayName: "REAL-TIME PROXY 2 — u + 2v Corrugation",
            direction: LatticeDirection(u: 1, v: 2),
            defaultFrequency: 8,
            upstreamReferenceFrequency: 80
        ),
        ProxyStageDescriptor(
            stage: .proxyStage3,
            displayName: "REAL-TIME PROXY 3 — u - 2v Corrugation",
            direction: LatticeDirection(u: 1, v: -2),
            defaultFrequency: 13,
            upstreamReferenceFrequency: 500
        ),
    ]
}

public struct ProxyCorrugation: Codable, Equatable, Sendable {
    public let displayName: String
    public let direction: LatticeDirection
    public let frequency: Int
    public let amplitude: Double
    public let upstreamReferenceFrequency: Int

    public init(
        displayName: String,
        direction: LatticeDirection,
        frequency: Int,
        amplitude: Double,
        upstreamReferenceFrequency: Int
    ) {
        self.displayName = displayName
        self.direction = direction
        self.frequency = frequency
        self.amplitude = amplitude
        self.upstreamReferenceFrequency = upstreamReferenceFrequency
    }
}

public struct ProxySchedule: Codable, Equatable, Sendable {
    public let corrugations: [ProxyCorrugation]

    public init(corrugations: [ProxyCorrugation]) throws {
        try Self.validate(corrugations)
        self.corrugations = corrugations
    }

    private init(knownValidCorrugations: [ProxyCorrugation]) {
        corrugations = knownValidCorrugations
    }

    public static let `default` = ProxySchedule(knownValidCorrugations: [
        ProxyCorrugation(
            displayName: "REAL-TIME PROXY 1 — u Corrugation",
            direction: LatticeDirection(u: 1, v: 0),
            frequency: 5,
            amplitude: 0.012,
            upstreamReferenceFrequency: 12
        ),
        ProxyCorrugation(
            displayName: "REAL-TIME PROXY 2 — u + 2v Corrugation",
            direction: LatticeDirection(u: 1, v: 2),
            frequency: 8,
            amplitude: 0.006,
            upstreamReferenceFrequency: 80
        ),
        ProxyCorrugation(
            displayName: "REAL-TIME PROXY 3 — u - 2v Corrugation",
            direction: LatticeDirection(u: 1, v: -2),
            frequency: 13,
            amplitude: 0.0035,
            upstreamReferenceFrequency: 500
        ),
    ])

    private enum CodingKeys: String, CodingKey {
        case corrugations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let corrugations = try container.decode([ProxyCorrugation].self, forKey: .corrugations)
        do {
            try self.init(corrugations: corrugations)
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .corrugations,
                in: container,
                debugDescription: String(describing: error)
            )
        }
    }

    static func validate(_ corrugations: [ProxyCorrugation]) throws {
        guard corrugations.count == 3 else {
            throw HeveaCoreError.invalidProxySchedule(
                reason: "exactly three clearly labelled proxy corrugations are required"
            )
        }
        for (index, corrugation) in corrugations.enumerated() {
            guard corrugation.displayName.hasPrefix("REAL-TIME PROXY \(index + 1)") else {
                throw HeveaCoreError.invalidProxySchedule(
                    reason: "corrugation \(index + 1) must be visibly labelled REAL-TIME PROXY \(index + 1)"
                )
            }
            guard corrugation.frequency > 0 else {
                throw HeveaCoreError.invalidProxySchedule(
                    reason: "corrugation \(index + 1) frequency must be positive"
                )
            }
            guard corrugation.upstreamReferenceFrequency > 0 else {
                throw HeveaCoreError.invalidProxySchedule(
                    reason: "corrugation \(index + 1) upstream reference frequency must be positive"
                )
            }
            guard corrugation.amplitude.isFinite, corrugation.amplitude >= 0 else {
                throw HeveaCoreError.invalidProxySchedule(
                    reason: "corrugation \(index + 1) amplitude must be finite and nonnegative"
                )
            }
            guard corrugation.direction.u != 0 || corrugation.direction.v != 0 else {
                throw HeveaCoreError.invalidProxySchedule(
                    reason: "corrugation \(index + 1) direction cannot be zero"
                )
            }
        }
    }
}

public struct TorusConfiguration: Codable, Equatable, Sendable {
    public let grid: PeriodicGrid
    public let minorRadius: Double
    public let majorRadius: Double
    public let proxySchedule: ProxySchedule

    public init(
        grid: PeriodicGrid = .interactive,
        minorRadius: Double = 0.2,
        majorRadius: Double = 0.5,
        proxySchedule: ProxySchedule = .default
    ) throws {
        try Self.validateRadii(minor: minorRadius, major: majorRadius)
        try ProxySchedule.validate(proxySchedule.corrugations)
        self.grid = grid
        self.minorRadius = minorRadius
        self.majorRadius = majorRadius
        self.proxySchedule = proxySchedule
    }

    private init(
        knownValidGrid: PeriodicGrid,
        minorRadius: Double,
        majorRadius: Double,
        proxySchedule: ProxySchedule
    ) {
        grid = knownValidGrid
        self.minorRadius = minorRadius
        self.majorRadius = majorRadius
        self.proxySchedule = proxySchedule
    }

    public static let `default` = TorusConfiguration(
        knownValidGrid: .interactive,
        minorRadius: 0.2,
        majorRadius: 0.5,
        proxySchedule: .default
    )

    private enum CodingKeys: String, CodingKey {
        case grid
        case minorRadius
        case majorRadius
        case proxySchedule
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let grid = try container.decode(PeriodicGrid.self, forKey: .grid)
        let minorRadius = try container.decode(Double.self, forKey: .minorRadius)
        let majorRadius = try container.decode(Double.self, forKey: .majorRadius)
        let proxySchedule = try container.decode(ProxySchedule.self, forKey: .proxySchedule)
        do {
            try self.init(
                grid: grid,
                minorRadius: minorRadius,
                majorRadius: majorRadius,
                proxySchedule: proxySchedule
            )
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .minorRadius,
                in: container,
                debugDescription: String(describing: error)
            )
        }
    }

    func validate() throws {
        try Self.validateRadii(minor: minorRadius, major: majorRadius)
        try ProxySchedule.validate(proxySchedule.corrugations)
    }

    private static func validateRadii(minor: Double, major: Double) throws {
        guard minor.isFinite,
              major.isFinite,
              minor > 0,
              major > 0,
              minor + major < 1
        else {
            throw HeveaCoreError.invalidRadius(minor: minor, major: major)
        }
    }
}
