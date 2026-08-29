/*
 HeveaScaleMicroscope is GPL-3.0-or-later.
*/

import Foundation

public struct ReportArtifacts: Equatable, Sendable {
    public let jsonURL: URL
    public let markdownURL: URL
    public let jsonData: Data
    public let markdownData: Data

    public init(
        jsonURL: URL,
        markdownURL: URL,
        jsonData: Data,
        markdownData: Data
    ) {
        self.jsonURL = jsonURL
        self.markdownURL = markdownURL
        self.jsonData = jsonData
        self.markdownData = markdownData
    }
}

public enum ReportWriter {
    public static let jsonFilename = "scale-microscope-report.json"
    public static let markdownFilename = "scale-microscope-report.md"

    public static func materialize(
        _ report: ExperimentReport,
        outputDirectory: URL
    ) throws -> ReportArtifacts {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        var jsonData = try encoder.encode(report)
        jsonData.append(0x0A)

        let decoder = JSONDecoder()
        let roundTripped = try decoder.decode(ExperimentReport.self, from: jsonData)
        guard roundTripped == report else {
            throw ReportWriterError.jsonRoundTripMismatch
        }

        let markdown = MarkdownRenderer.render(report)
        guard let markdownData = markdown.data(using: .utf8) else {
            throw ReportWriterError.markdownEncodingFailed
        }

        return ReportArtifacts(
            jsonURL: outputDirectory.appendingPathComponent(jsonFilename),
            markdownURL: outputDirectory.appendingPathComponent(markdownFilename),
            jsonData: jsonData,
            markdownData: markdownData
        )
    }

    public static func write(
        _ report: ExperimentReport,
        outputDirectory: URL
    ) throws -> ReportArtifacts {
        let artifacts = try materialize(report, outputDirectory: outputDirectory)
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        try artifacts.jsonData.write(to: artifacts.jsonURL, options: .atomic)
        try artifacts.markdownData.write(to: artifacts.markdownURL, options: .atomic)
        return artifacts
    }
}

public enum ReportWriterError: Error, Equatable, Sendable, CustomStringConvertible {
    case jsonRoundTripMismatch
    case markdownEncodingFailed
    case determinismMismatch

    public var description: String {
        switch self {
        case .jsonRoundTripMismatch:
            "The encoded JSON did not decode to the original report."
        case .markdownEncodingFailed:
            "The Markdown report could not be encoded as UTF-8."
        case .determinismMismatch:
            "Two consecutive in-process experiment runs produced different reports."
        }
    }
}
