import Foundation

public enum SpherePrimitiveDirection: String, Codable, CaseIterable, Equatable, Sendable {
    case diagonalPlus
    case diagonalMinus
    case latitude

    /// Primitive one-forms from Equation (2.2) of the paper.
    public var paperFormula: String {
        switch self {
        case .diagonalPlus: "(dx + dy) / sqrt(2)"
        case .diagonalMinus: "(-dx + dy) / sqrt(2)"
        case .latitude: "dy"
        }
    }
}

public enum SphereStage: String, Codable, CaseIterable, Equatable, Sendable {
    case unitSphere
    case shortMap
    case proxyFamily1
    case proxyFamily2
    case proxyFamily3

    public var displayName: String {
        switch self {
        case .unitSphere: "UPSTREAM BASELINE — Unit sphere"
        case .shortMap: "REAL-TIME PROXY — Short map"
        case .proxyFamily1: "REAL-TIME PROXY 1 — First primitive family"
        case .proxyFamily2: "REAL-TIME PROXY 2 — Second primitive family"
        case .proxyFamily3: "REAL-TIME PROXY 3 — Third primitive family"
        }
    }

    public var shortDisplayName: String {
        switch self {
        case .unitSphere: "Unit sphere"
        case .shortMap: "Short map"
        case .proxyFamily1: "Family 1"
        case .proxyFamily2: "Family 2"
        case .proxyFamily3: "Family 3"
        }
    }

    public var claimClass: ClaimClass {
        self == .unitSphere ? .upstreamBaseline : .realTimeProxy
    }

    public var appliedCorrugationCount: Int {
        switch self {
        case .unitSphere, .shortMap: 0
        case .proxyFamily1: 1
        case .proxyFamily2: 2
        case .proxyFamily3: 3
        }
    }

    public var claimCeiling: String {
        switch self {
        case .unitSphere:
            "Exact round unit-sphere formula printed in the paper."
        case .shortMap:
            "GPL-attributed constrained profile reconstruction with exact translated caps; not the authors' unpublished profile."
        case .proxyFamily1, .proxyFamily2, .proxyFamily3:
            "Paper-calibrated explanatory geometry only; not f_{1,3}, an isometry certificate, or the limiting C1 map."
        }
    }
}

public struct SphereProxyCorrugation: Codable, Equatable, Sendable {
    public let displayName: String
    public let primitiveDirection: SpherePrimitiveDirection
    public let paperRidgeCount: Int
    public let renderedRidgeCount: Int
    public let amplitude: Double
    public let supportHalfWidthFraction: Double
    public let fullStrengthFraction: Double

    public init(
        displayName: String,
        primitiveDirection: SpherePrimitiveDirection,
        paperRidgeCount: Int,
        renderedRidgeCount: Int,
        amplitude: Double,
        supportHalfWidthFraction: Double,
        fullStrengthFraction: Double
    ) {
        self.displayName = displayName
        self.primitiveDirection = primitiveDirection
        self.paperRidgeCount = paperRidgeCount
        self.renderedRidgeCount = renderedRidgeCount
        self.amplitude = amplitude
        self.supportHalfWidthFraction = supportHalfWidthFraction
        self.fullStrengthFraction = fullStrengthFraction
    }
}

public struct SphereProxySchedule: Codable, Equatable, Sendable {
    public let corrugations: [SphereProxyCorrugation]

    public init(corrugations: [SphereProxyCorrugation]) throws {
        try Self.validate(corrugations)
        self.corrugations = corrugations
    }

    private init(knownValidCorrugations: [SphereProxyCorrugation]) {
        corrugations = knownValidCorrugations
    }

    /// Rendered counts are intentionally compressed from the paper's
    /// 21 / 142 / 997 visible ridges and remain separately identified.
    public static let `default` = SphereProxySchedule(knownValidCorrugations: [
        SphereProxyCorrugation(
            displayName: "REAL-TIME PROXY 1 — rendered 7 / paper 21 ridges",
            primitiveDirection: .diagonalPlus,
            paperRidgeCount: 21,
            renderedRidgeCount: 7,
            amplitude: 0.006,
            supportHalfWidthFraction: 0.45,
            fullStrengthFraction: 0.70
        ),
        SphereProxyCorrugation(
            displayName: "REAL-TIME PROXY 2 — rendered 13 / paper 142 ridges",
            primitiveDirection: .diagonalMinus,
            paperRidgeCount: 142,
            renderedRidgeCount: 13,
            amplitude: 0.0035,
            supportHalfWidthFraction: 0.68,
            fullStrengthFraction: 0.74
        ),
        SphereProxyCorrugation(
            displayName: "REAL-TIME PROXY 3 — rendered 21 / paper 997 ridges",
            primitiveDirection: .latitude,
            paperRidgeCount: 997,
            renderedRidgeCount: 21,
            amplitude: 0.002,
            supportHalfWidthFraction: 0.90,
            fullStrengthFraction: 0.78
        ),
    ])

    private enum CodingKeys: String, CodingKey {
        case corrugations
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(
                corrugations: container.decode(
                    [SphereProxyCorrugation].self,
                    forKey: .corrugations
                )
            )
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .corrugations,
                in: container,
                debugDescription: String(describing: error)
            )
        }
    }

    static func validate(_ corrugations: [SphereProxyCorrugation]) throws {
        guard corrugations.count == 3 else {
            throw HeveaCoreError.invalidSphereConfiguration(
                reason: "exactly three sphere proxy families are required"
            )
        }
        let expectedPaperCounts = [21, 142, 997]
        var previousSupport = 0.0
        for (index, corrugation) in corrugations.enumerated() {
            guard corrugation.displayName.hasPrefix("REAL-TIME PROXY \(index + 1)") else {
                throw HeveaCoreError.invalidSphereConfiguration(
                    reason: "sphere family \(index + 1) lacks its REAL-TIME PROXY label"
                )
            }
            guard corrugation.paperRidgeCount == expectedPaperCounts[index] else {
                throw HeveaCoreError.invalidSphereConfiguration(
                    reason: "paper ridge metadata must remain 21 / 142 / 997"
                )
            }
            guard corrugation.renderedRidgeCount > 0,
                  corrugation.renderedRidgeCount < corrugation.paperRidgeCount
            else {
                throw HeveaCoreError.invalidSphereConfiguration(
                    reason: "rendered ridge count must be positive and explicitly compressed"
                )
            }
            guard corrugation.amplitude.isFinite, corrugation.amplitude >= 0 else {
                throw HeveaCoreError.invalidSphereConfiguration(
                    reason: "sphere proxy amplitude must be finite and nonnegative"
                )
            }
            guard corrugation.supportHalfWidthFraction.isFinite,
                  corrugation.supportHalfWidthFraction > previousSupport,
                  corrugation.supportHalfWidthFraction < 1
            else {
                throw HeveaCoreError.invalidSphereConfiguration(
                    reason: "sphere proxy supports must be strictly nested inside the ribbon"
                )
            }
            guard corrugation.fullStrengthFraction.isFinite,
                  corrugation.fullStrengthFraction > 0,
                  corrugation.fullStrengthFraction < 1
            else {
                throw HeveaCoreError.invalidSphereConfiguration(
                    reason: "sphere proxy fade fraction must lie strictly between zero and one"
                )
            }
            previousSupport = corrugation.supportHalfWidthFraction
        }
    }
}

public struct SphereConfiguration: Codable, Equatable, Sendable {
    public let grid: SphereGrid
    public let proxySchedule: SphereProxySchedule
    public let declaredProxyContainingRadius: Double
    public let maximumNavigationStep: Double

    public init(
        grid: SphereGrid = .interactive,
        proxySchedule: SphereProxySchedule = .default,
        declaredProxyContainingRadius: Double = JudddReducedSphereProfile.certifiedContainingRadius,
        maximumNavigationStep: Double = Double.pi
    ) throws {
        guard declaredProxyContainingRadius.isFinite,
              declaredProxyContainingRadius > 0,
              declaredProxyContainingRadius < 1
        else {
            throw HeveaCoreError.invalidSphereConfiguration(
                reason: "declared proxy radius must be finite and lie in (0, 1)"
            )
        }
        guard maximumNavigationStep.isFinite,
              maximumNavigationStep > 0,
              maximumNavigationStep <= 2 * Double.pi
        else {
            throw HeveaCoreError.invalidSphereConfiguration(
                reason: "maximum navigation step must lie in (0, 2pi]"
            )
        }
        try SphereProxySchedule.validate(proxySchedule.corrugations)
        self.grid = grid
        self.proxySchedule = proxySchedule
        self.declaredProxyContainingRadius = declaredProxyContainingRadius
        self.maximumNavigationStep = maximumNavigationStep
    }

    private init(
        knownValidGrid: SphereGrid,
        proxySchedule: SphereProxySchedule,
        declaredProxyContainingRadius: Double,
        maximumNavigationStep: Double
    ) {
        grid = knownValidGrid
        self.proxySchedule = proxySchedule
        self.declaredProxyContainingRadius = declaredProxyContainingRadius
        self.maximumNavigationStep = maximumNavigationStep
    }

    public static let `default` = SphereConfiguration(
        knownValidGrid: .interactive,
        proxySchedule: .default,
        declaredProxyContainingRadius: JudddReducedSphereProfile.certifiedContainingRadius,
        maximumNavigationStep: Double.pi
    )

    private enum CodingKeys: String, CodingKey {
        case grid
        case proxySchedule
        case declaredProxyContainingRadius
        case maximumNavigationStep
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(
                grid: container.decode(SphereGrid.self, forKey: .grid),
                proxySchedule: container.decode(SphereProxySchedule.self, forKey: .proxySchedule),
                declaredProxyContainingRadius: container.decode(
                    Double.self,
                    forKey: .declaredProxyContainingRadius
                ),
                maximumNavigationStep: container.decode(
                    Double.self,
                    forKey: .maximumNavigationStep
                )
            )
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .declaredProxyContainingRadius,
                in: container,
                debugDescription: String(describing: error)
            )
        }
    }

    func validate() throws {
        _ = try SphereConfiguration(
            grid: grid,
            proxySchedule: proxySchedule,
            declaredProxyContainingRadius: declaredProxyContainingRadius,
            maximumNavigationStep: maximumNavigationStep
        )
    }
}
