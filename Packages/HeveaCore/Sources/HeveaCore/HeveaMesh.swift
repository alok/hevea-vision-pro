import Foundation

public struct UpstreamSourceManifest: Codable, Equatable, Sendable {
    public let projectName: String
    public let projectURL: String
    public let sourceRepositoryURL: String
    public let revision: String
    public let sourcePath: String
    public let licenseIdentifier: String

    public init(
        projectName: String,
        projectURL: String,
        sourceRepositoryURL: String,
        revision: String,
        sourcePath: String,
        licenseIdentifier: String
    ) {
        self.projectName = projectName
        self.projectURL = projectURL
        self.sourceRepositoryURL = sourceRepositoryURL
        self.revision = revision
        self.sourcePath = sourcePath
        self.licenseIdentifier = licenseIdentifier
    }

    public static let pinnedFlatTorus = UpstreamSourceManifest(
        projectName: "Hévéa",
        projectURL: "https://hevea-project.fr/",
        sourceRepositoryURL: "https://github.com/HeveaProject/Hevea",
        revision: "e792074e4dd6319351bc957afeb16b4725d304f0",
        sourcePath: "torus/v0r1m2/include/TOR_implementation.h",
        licenseIdentifier: "GPL-3.0-or-later"
    )
}

public struct HeveaMeshManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let generatorIdentifier: String
    public let generatorVersion: String
    public let stage: HeveaStage
    public let stageLabel: String
    public let claimClass: ClaimClass
    public let grid: PeriodicGrid
    public let minorRadius: Double
    public let majorRadius: Double
    public let appliedProxyCorrugations: [ProxyCorrugation]
    public let upstreamSource: UpstreamSourceManifest
    public let targetMetricDescription: String
    public let claimCeiling: String

    public init(
        schemaVersion: Int = 1,
        generatorIdentifier: String = "org.aloksingh.HeveaCore.HeveaMeshGenerator",
        generatorVersion: String = "0.1.0",
        stage: HeveaStage,
        grid: PeriodicGrid,
        minorRadius: Double,
        majorRadius: Double,
        appliedProxyCorrugations: [ProxyCorrugation],
        upstreamSource: UpstreamSourceManifest = .pinnedFlatTorus,
        targetMetricDescription: String = "unit flat metric du² + dv² on R²/Z²"
    ) {
        self.schemaVersion = schemaVersion
        self.generatorIdentifier = generatorIdentifier
        self.generatorVersion = generatorVersion
        self.stage = stage
        stageLabel = stage.displayName
        claimClass = stage.claimClass
        self.grid = grid
        self.minorRadius = minorRadius
        self.majorRadius = majorRadius
        self.appliedProxyCorrugations = appliedProxyCorrugations
        self.upstreamSource = upstreamSource
        self.targetMetricDescription = targetMetricDescription
        claimCeiling = stage == .shortTorus
            ? "Regenerated finite starting surface from the pinned GPL formula and parameters."
            : "Interactive explanatory proxy only; not the upstream corrugation, an isometry certificate, or the limiting C1 embedding."
    }
}

public struct MeshScalarField: Codable, Equatable, Sendable {
    public let name: String
    public let displayName: String
    public let claimClass: ClaimClass
    public let units: String
    public let values: [Double]

    public init(
        name: String,
        displayName: String,
        claimClass: ClaimClass,
        units: String,
        values: [Double]
    ) throws {
        guard !name.isEmpty, !displayName.isEmpty else {
            throw HeveaCoreError.invalidDiagnosticConfiguration(
                reason: "scalar field names cannot be empty"
            )
        }
        guard values.allSatisfy(\.isFinite) else {
            throw HeveaCoreError.nonFiniteValue(context: "scalar field \(name)")
        }
        self.name = name
        self.displayName = displayName
        self.claimClass = claimClass
        self.units = units
        self.values = values
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case displayName
        case claimClass
        case units
        case values
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(
                name: container.decode(String.self, forKey: .name),
                displayName: container.decode(String.self, forKey: .displayName),
                claimClass: container.decode(ClaimClass.self, forKey: .claimClass),
                units: container.decode(String.self, forKey: .units),
                values: container.decode([Double].self, forKey: .values)
            )
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .values,
                in: container,
                debugDescription: String(describing: error)
            )
        }
    }
}

/// A validated, periodic, indexed surface. The seams are represented by wrapped
/// indices rather than duplicated vertices, so every vertex has one canonical sample.
public struct HeveaMesh: Codable, Equatable, Sendable {
    public let stage: HeveaStage
    public let grid: PeriodicGrid
    public let positions: [Vector3]
    public let normals: [Vector3]
    public let textureCoordinates: [Vector2]
    public let triangleIndices: [UInt32]
    public let scalarFields: [MeshScalarField]
    public let manifest: HeveaMeshManifest

    /// Alias used by render bridges that conventionally call texture coordinates UVs.
    public var uvs: [Vector2] { textureCoordinates }

    /// Alias used by render bridges that conventionally call triangle indices indices.
    public var indices: [UInt32] { triangleIndices }

    public init(
        stage: HeveaStage,
        grid: PeriodicGrid,
        positions: [Vector3],
        normals: [Vector3],
        textureCoordinates: [Vector2],
        triangleIndices: [UInt32],
        scalarFields: [MeshScalarField],
        manifest: HeveaMeshManifest
    ) throws {
        let vertexCount = grid.vertexCount
        try Self.requireCount(positions.count, expected: vertexCount, field: "positions")
        try Self.requireCount(normals.count, expected: vertexCount, field: "normals")
        try Self.requireCount(textureCoordinates.count, expected: vertexCount, field: "textureCoordinates")
        try Self.requireCount(
            triangleIndices.count,
            expected: grid.triangleIndexCount,
            field: "triangleIndices"
        )
        guard positions.allSatisfy(\.isFinite) else {
            throw HeveaCoreError.nonFiniteValue(context: "mesh positions")
        }
        guard normals.allSatisfy({ $0.isFinite && $0.squaredLength > 0 }) else {
            throw HeveaCoreError.nonFiniteValue(context: "mesh normals")
        }
        guard textureCoordinates.allSatisfy(\.isFinite) else {
            throw HeveaCoreError.nonFiniteValue(context: "mesh texture coordinates")
        }
        for index in triangleIndices where Int(index) >= vertexCount {
            throw HeveaCoreError.invalidMeshIndex(index: index, vertexCount: vertexCount)
        }
        for field in scalarFields {
            try Self.requireCount(field.values.count, expected: vertexCount, field: field.name)
            guard field.values.allSatisfy(\.isFinite) else {
                throw HeveaCoreError.nonFiniteValue(context: "mesh scalar field \(field.name)")
            }
        }
        guard Set(scalarFields.map(\.name)).count == scalarFields.count else {
            throw HeveaCoreError.invalidDiagnosticConfiguration(
                reason: "mesh scalar field names must be unique"
            )
        }
        guard manifest.stage == stage,
              manifest.grid == grid,
              manifest.stageLabel == stage.displayName,
              manifest.claimClass == stage.claimClass,
              manifest.appliedProxyCorrugations.count == stage.appliedCorrugationCount,
              manifest.minorRadius.isFinite,
              manifest.majorRadius.isFinite,
              manifest.minorRadius > 0,
              manifest.majorRadius > 0,
              manifest.minorRadius + manifest.majorRadius < 1
        else {
            throw HeveaCoreError.invalidDiagnosticConfiguration(
                reason: "mesh manifest does not match the validated payload and stage claim"
            )
        }

        self.stage = stage
        self.grid = grid
        self.positions = positions
        self.normals = normals
        self.textureCoordinates = textureCoordinates
        self.triangleIndices = triangleIndices
        self.scalarFields = scalarFields
        self.manifest = manifest
    }

    private enum CodingKeys: String, CodingKey {
        case stage
        case grid
        case positions
        case normals
        case textureCoordinates
        case triangleIndices
        case scalarFields
        case manifest
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        do {
            try self.init(
                stage: container.decode(HeveaStage.self, forKey: .stage),
                grid: container.decode(PeriodicGrid.self, forKey: .grid),
                positions: container.decode([Vector3].self, forKey: .positions),
                normals: container.decode([Vector3].self, forKey: .normals),
                textureCoordinates: container.decode([Vector2].self, forKey: .textureCoordinates),
                triangleIndices: container.decode([UInt32].self, forKey: .triangleIndices),
                scalarFields: container.decode([MeshScalarField].self, forKey: .scalarFields),
                manifest: container.decode(HeveaMeshManifest.self, forKey: .manifest)
            )
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .positions,
                in: container,
                debugDescription: String(describing: error)
            )
        }
    }

    public func position(at coordinate: GridCoordinate) -> Vector3 {
        positions[grid.index(of: coordinate)]
    }

    public func normal(at coordinate: GridCoordinate) -> Vector3 {
        normals[grid.index(of: coordinate)]
    }

    public func scalarField(named name: String) -> MeshScalarField? {
        scalarFields.first { $0.name == name }
    }

    /// Periodic bilinear interpolation over the finite mesh. This is a mesh
    /// measurement, not evaluation of an exact or limiting surface.
    public func interpolatedPosition(at point: ParameterPoint) throws -> Vector3 {
        guard point.isFinite else {
            throw HeveaCoreError.nonFiniteValue(context: "mesh interpolation parameter")
        }
        let wrapped = point.wrapped
        let scaledU = wrapped.u * Double(grid.uCount)
        let scaledV = wrapped.v * Double(grid.vCount)
        let u0 = Int(floor(scaledU))
        let v0 = Int(floor(scaledV))
        let uFraction = scaledU - Double(u0)
        let vFraction = scaledV - Double(v0)

        let p00 = position(at: GridCoordinate(u: u0, v: v0))
        let p10 = position(at: GridCoordinate(u: u0 + 1, v: v0))
        let p01 = position(at: GridCoordinate(u: u0, v: v0 + 1))
        let p11 = position(at: GridCoordinate(u: u0 + 1, v: v0 + 1))

        let lower = p00 * (1 - uFraction) + p10 * uFraction
        let upper = p01 * (1 - uFraction) + p11 * uFraction
        let result = lower * (1 - vFraction) + upper * vFraction
        guard result.isFinite else {
            throw HeveaCoreError.nonFiniteValue(context: "mesh interpolation result")
        }
        return result
    }

    private static func requireCount(_ actual: Int, expected: Int, field: String) throws {
        guard actual == expected else {
            throw HeveaCoreError.inconsistentMeshData(
                field: field,
                expected: expected,
                actual: actual
            )
        }
    }
}
