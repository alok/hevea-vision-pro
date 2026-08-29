/*
 HeveaScaleMicroscope is GPL-3.0-or-later.
*/

import Foundation
import ScaleMicroscopeExperiment

@main
struct HeveaScaleMicroscopeCLI {
    static func main() throws {
        let options = try Options(arguments: Array(CommandLine.arguments.dropFirst()))
        if options.showHelp {
            print(Options.help)
            return
        }

        let first = try ExperimentRunner.run()
        let second = try ExperimentRunner.run()
        guard first == second else {
            throw ReportWriterError.determinismMismatch
        }

        let artifacts = try ReportWriter.write(
            first,
            outputDirectory: options.outputDirectory
        )
        let rematerialized = try ReportWriter.materialize(
            second,
            outputDirectory: options.outputDirectory
        )
        guard artifacts.jsonData == rematerialized.jsonData,
              artifacts.markdownData == rematerialized.markdownData
        else {
            throw ReportWriterError.determinismMismatch
        }

        print("HV EXPERIMENT complete (\(first.run.buildConfiguration)).")
        print("HeveaCore: \(first.run.coreRevision)")
        print("Upstream:  \(first.upstreamSource.revision)")
        print("JSON:      \(artifacts.jsonURL.path)")
        print("Markdown:  \(artifacts.markdownURL.path)")
        for finding in first.boundedFindings {
            print("- \(finding.statement)")
        }
        print("Claim ceiling: \(first.claimCeiling)")
    }
}

private struct Options {
    let outputDirectory: URL
    let showHelp: Bool

    init(arguments: [String]) throws {
        var outputPath = "docs/research"
        var showHelp = false
        var index = 0

        while index < arguments.count {
            switch arguments[index] {
            case "--output-directory":
                let valueIndex = index + 1
                guard valueIndex < arguments.count else {
                    throw OptionsError.missingOutputDirectory
                }
                outputPath = arguments[valueIndex]
                index += 2
            case "--help", "-h":
                showHelp = true
                index += 1
            default:
                throw OptionsError.unknownArgument(arguments[index])
            }
        }

        let currentDirectory = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        outputDirectory = URL(
            fileURLWithPath: outputPath,
            relativeTo: currentDirectory
        ).standardizedFileURL
        self.showHelp = showHelp
    }

    static let help = """
    hevea-scale-microscope

    Deterministically generate the finite-mesh Hévéa Vision research report.

    Usage:
      hevea-scale-microscope [--output-directory PATH]

    Default output directory:
      docs/research

    Required claim ceiling:
      HV EXPERIMENT; finite meshes only. No isometry certificate, limiting
      regularity theorem, fractal-dimension claim, or upstream-stage claim.
    """
}

private enum OptionsError: Error, CustomStringConvertible {
    case missingOutputDirectory
    case unknownArgument(String)

    var description: String {
        switch self {
        case .missingOutputDirectory:
            "--output-directory requires a path."
        case let .unknownArgument(argument):
            "Unknown argument: \(argument)"
        }
    }
}
