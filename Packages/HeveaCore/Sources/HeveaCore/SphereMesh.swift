import Foundation

public struct ReducedSphereSourceManifest: Codable, Equatable, Sendable {
    public let paperTitle: String
    public let paperDOI: String
    public let projectURL: String
    public let profileRepositoryURL: String
    public let profileRevision: String
    public let profileSourcePath: String
    public let profileLicenseIdentifier: String
    public let profileIdentifier: String
    public let provenanceCeiling: String

    public init(
        paperTitle: String,
        paperDOI: String,
        projectURL: String,
        profileRepositoryURL: String,
        profileRevision: String,
        profileSourcePath: String,
        profileLicenseIdentifier: String,
        profileIdentifier: String,
        provenanceCeiling: String
    ) {
        self.paperTitle = paperTitle
        self.paperDOI = paperDOI
        self.projectURL = projectURL
        self.profileRepositoryURL = profileRepositoryURL
        self.profileRevision = profileRevision
        self.profileSourcePath = profileSourcePath
        self.profileLicenseIdentifier = profileLicenseIdentifier
        self.profileIdentifier = profileIdentifier
        self.provenanceCeiling = provenanceCeiling
    }

    public static let paperAndJudddProfile = ReducedSphereSourceManifest(
        paperTitle: "An Explicit Isometric Reduction of the Unit Sphere into an Arbitrarily Small Ball",
        paperDOI: "10.1007/s10208-017-9360-1",
        projectURL: "https://hevea-project.fr/",
        profileRepositoryURL: JudddReducedSphereProfile.sourceRepositoryURL,
        profileRevision: JudddReducedSphereProfile.sourceRevision,
        profileSourcePath: JudddReducedSphereProfile.sourcePath,
        profileLicenseIdentifier: JudddReducedSphereProfile.licenseIdentifier,
        profileIdentifier: JudddReducedSphereProfile.stableIdentifier,
        provenanceCeiling: "The central profile is a GPL constrained reconstruction, not the paper authors' unpublished coefficient vector."
    )
}

public struct SphereRidgeMetadata: Codable, Equatable, Sendable {
    public let family: Int
    public let primitiveDirection: SpherePrimitiveDirection
    public let paperRidgeCount: Int
    public let renderedRidgeCount: Int
    public let isApplied: Bool

    public init(
        family: Int,
        primitiveDirection: SpherePrimitiveDirection,
        paperRidgeCount: Int,
        renderedRidgeCount: Int,
        isApplied: Bool
    ) {
        self.family = family
        self.primitiveDirection = primitiveDirection
        self.paperRidgeCount = paperRidgeCount
        self.renderedRidgeCount = renderedRidgeCount
        self.isApplied = isApplied
    }
}

public struct SphereMeshManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let generatorIdentifier: String
    public let generatorVersion: String
    public let stage: SphereStage
    public let stageLabel: String
    public let claimClass: ClaimClass
    public let grid: SphereGrid
    public let yInfinity: Double
    public let eta: Double
    public let declaredContainingRadius: Double
    public let ridgeMetadata: [SphereRidgeMetadata]
    public let appliedProxyCorrugations: [SphereProxyCorrugation]
    public let source: ReducedSphereSourceManifest
    public let targetMetricDescription: String
    public let claimCeiling: String

    public init(stage: SphereStage, configuration: SphereConfiguration) {
        schemaVersion = 1
        generatorIdentifier = "org.aloksingh.HeveaCore.SphereMeshGenerator"
        generatorVersion = "0.1.0"
        self.stage = stage
        stageLabel = stage.displayName
        claimClass = stage.claimClass
        grid = configuration.grid
        yInfinity = JudddReducedSphereProfile.yInfinity
        eta = JudddReducedSphereProfile.eta
        declaredContainingRadius = stage == .unitSphere
            ? 1
            : configuration.declaredProxyContainingRadius
        ridgeMetadata = configuration.proxySchedule.corrugations.enumerated().map { index, item in
            SphereRidgeMetadata(
                family: index + 1,
                primitiveDirection: item.primitiveDirection,
                paperRidgeCount: item.paperRidgeCount,
                renderedRidgeCount: item.renderedRidgeCount,
                isApplied: index < stage.appliedCorrugationCount
            )
        }
        appliedProxyCorrugations = Array(
            configuration.proxySchedule.corrugations.prefix(stage.appliedCorrugationCount)
        )
        source = .paperAndJudddProfile
        targetMetricDescription = "round unit-sphere metric cos²(y) dx² + dy²"
        claimCeiling = stage.claimCeiling
    }
}

public struct SphereMesh: Codable, Equatable, Sendable {
    public let stage: SphereStage
    public let grid: SphereGrid
    public let positions: [Vector3]
    public let normals: [Vector3]
    public let textureCoordinates: [Vector2]
    public let triangleIndices: [UInt32]
    public let scalarFields: [MeshScalarField]
    public let manifest: SphereMeshManifest

    public var uvs: [Vector2] { textureCoordinates }
    public var indices: [UInt32] { triangleIndices }

    /// Validated construction is a factory rather than a failable value
    /// initializer. This keeps the error return separate from the large mesh
    /// value on every supported Swift optimizer.
    public static func validated(
        stage: SphereStage,
        grid: SphereGrid,
        positions: [Vector3],
        normals: [Vector3],
        textureCoordinates: [Vector2],
        triangleIndices: [UInt32],
        scalarFields: [MeshScalarField],
        manifest: SphereMeshManifest
    ) throws -> SphereMesh {
        try Self.requireCount(positions.count, expected: grid.vertexCount, field: "positions")
        try Self.requireCount(normals.count, expected: grid.vertexCount, field: "normals")
        try Self.requireCount(
            textureCoordinates.count,
            expected: grid.vertexCount,
            field: "textureCoordinates"
        )
        try Self.requireCount(
            triangleIndices.count,
            expected: grid.triangleIndexCount,
            field: "triangleIndices"
        )
        guard positions.allSatisfy(\.isFinite) else {
            throw HeveaCoreError.nonFiniteValue(context: "sphere mesh positions")
        }
        guard normals.allSatisfy({ $0.isFinite && $0.squaredLength > 0 }) else {
            throw HeveaCoreError.nonFiniteValue(context: "sphere mesh normals")
        }
        guard textureCoordinates.allSatisfy(\.isFinite) else {
            throw HeveaCoreError.nonFiniteValue(context: "sphere mesh texture coordinates")
        }
        for index in triangleIndices where Int(index) >= grid.vertexCount {
            throw HeveaCoreError.invalidMeshIndex(index: index, vertexCount: grid.vertexCount)
        }
        for field in scalarFields {
            try Self.requireCount(field.values.count, expected: grid.vertexCount, field: field.name)
        }
        guard Set(scalarFields.map(\.name)).count == scalarFields.count else {
            throw HeveaCoreError.invalidDiagnosticConfiguration(
                reason: "sphere scalar-field names must be unique"
            )
        }
        guard manifest.stage == stage,
              manifest.grid == grid,
              manifest.stageLabel == stage.displayName,
              manifest.claimClass == stage.claimClass,
              manifest.appliedProxyCorrugations.count == stage.appliedCorrugationCount,
              manifest.ridgeMetadata.count == 3,
              manifest.declaredContainingRadius.isFinite,
              manifest.declaredContainingRadius > 0
        else {
            throw HeveaCoreError.invalidSphereConfiguration(
                reason: "sphere manifest does not match the validated payload"
            )
        }

        return SphereMesh(
            knownValidStage: stage,
            grid: grid,
            positions: positions,
            normals: normals,
            textureCoordinates: textureCoordinates,
            triangleIndices: triangleIndices,
            scalarFields: scalarFields,
            manifest: manifest
        )
    }

    init(
        knownValidStage stage: SphereStage,
        grid: SphereGrid,
        positions: [Vector3],
        normals: [Vector3],
        textureCoordinates: [Vector2],
        triangleIndices: [UInt32],
        scalarFields: [MeshScalarField],
        manifest: SphereMeshManifest
    ) {
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
            self = try Self.validated(
                stage: container.decode(SphereStage.self, forKey: .stage),
                grid: container.decode(SphereGrid.self, forKey: .grid),
                positions: container.decode([Vector3].self, forKey: .positions),
                normals: container.decode([Vector3].self, forKey: .normals),
                textureCoordinates: container.decode([Vector2].self, forKey: .textureCoordinates),
                triangleIndices: container.decode([UInt32].self, forKey: .triangleIndices),
                scalarFields: container.decode([MeshScalarField].self, forKey: .scalarFields),
                manifest: container.decode(SphereMeshManifest.self, forKey: .manifest)
            )
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .positions,
                in: container,
                debugDescription: String(describing: error)
            )
        }
    }

    public func position(at vertex: SphereGridVertex) throws -> Vector3 {
        positions[try grid.index(of: vertex)]
    }

    public func normal(at vertex: SphereGridVertex) throws -> Vector3 {
        normals[try grid.index(of: vertex)]
    }

    public func scalarField(named name: String) -> MeshScalarField? {
        scalarFields.first { $0.name == name }
    }

    /// Stable FNV-1a fingerprint over the mathematical render payload. Swift's
    /// randomized `Hasher` is intentionally not used.
    public var deterministicFingerprint: String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        let prime: UInt64 = 1_099_511_628_211

        func update(byte: UInt8) {
            hash ^= UInt64(byte)
            hash &*= prime
        }
        func update(word: UInt64) {
            var littleEndian = word.littleEndian
            withUnsafeBytes(of: &littleEndian) { bytes in
                for byte in bytes { update(byte: byte) }
            }
        }

        for byte in stage.rawValue.utf8 { update(byte: byte) }
        update(word: UInt64(grid.longitudeCount))
        update(word: UInt64(grid.nonPolarLatitudeRingCount))
        for position in positions {
            update(word: position.x.bitPattern)
            update(word: position.y.bitPattern)
            update(word: position.z.bitPattern)
        }
        for normal in normals {
            update(word: normal.x.bitPattern)
            update(word: normal.y.bitPattern)
            update(word: normal.z.bitPattern)
        }
        for index in triangleIndices { update(word: UInt64(index)) }
        return String(format: "%016llx", hash)
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
