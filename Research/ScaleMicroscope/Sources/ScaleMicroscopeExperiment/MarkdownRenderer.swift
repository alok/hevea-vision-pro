/*
 HeveaScaleMicroscope is GPL-3.0-or-later.

 The rendered prose keeps finite evidence separate from mathematical claims.
*/

import Foundation
import HeveaCore

public enum MarkdownRenderer {
    public static func render(_ report: ExperimentReport) -> String {
        var lines: [String] = []

        append("# \(report.title)", to: &lines)
        append("", to: &lines)
        append("> **HV EXPERIMENT — finite meshes only.** \(report.claimCeiling)", to: &lines)
        append("", to: &lines)
        append("This report is a reproducible numerical extension of the Hévéa flat-torus exhibit. It asks what the app's bounded meshes reveal about metric residuals, two fundamental winding curves, and normal-field variation across a finite scale ladder. It does not replace the original construction or papers.", to: &lines)
        append("", to: &lines)

        append("## Reproducibility receipt", to: &lines)
        append("", to: &lines)
        append("| Field | Value |", to: &lines)
        append("|---|---|", to: &lines)
        append("| Experiment label | `\(report.claimClass.rawValue)` |", to: &lines)
        append("| Report schema | `\(report.schemaVersion)` |", to: &lines)
        append("| Report baseline | `\(report.run.reportBaselineDate)` |", to: &lines)
        append("| Build configuration | `\(report.run.buildConfiguration)` |", to: &lines)
        append("| HeveaCore revision | `\(report.run.coreRevision)` |", to: &lines)
        append("| Upstream project | [\(report.upstreamSource.projectName)](\(report.upstreamSource.projectURL)) |", to: &lines)
        append("| Upstream source | [repository](\(report.upstreamSource.sourceRepositoryURL)) at `\(report.upstreamSource.revision)` |", to: &lines)
        append("| Adapted upstream path | `\(report.upstreamSource.sourcePath)` |", to: &lines)
        append("| License | `\(report.upstreamSource.licenseIdentifier)` |", to: &lines)
        append("", to: &lines)
        append("The `UPSTREAM BASELINE` label below applies only to the regenerated short-torus starting surface. Every diagnostic and every fitted slope in this report remains an `HV EXPERIMENT`.", to: &lines)
        append("", to: &lines)

        append("## Exact run configuration", to: &lines)
        append("", to: &lines)
        let torus = report.configuration.torus
        let microscope = report.configuration.normalMicroscope
        let curves = report.configuration.windingCurves
        append("- Periodic grid: `\(torus.grid.uCount) × \(torus.grid.vCount)` = `\(torus.grid.vertexCount)` vertices and `\(torus.grid.triangleCount)` triangles per stage.", to: &lines)
        append("- Short-torus radii: minor `\(number(torus.minorRadius))`, major `\(number(torus.majorRadius))`; the implementation scales the formula by `1/(2π)`.", to: &lines)
        append("- Stages: \(report.configuration.stages.map { "`\($0.rawValue)`" }.joined(separator: ", ")).", to: &lines)
        append("- Normal scales requested: `\(microscope.scales.map(String.init).joined(separator: ", "))` grid steps; samples: `\(microscope.sampleCount)`; deterministic seed: `\(hex(microscope.deterministicSeed))`.", to: &lines)
        append("- Winding basepoint: `(u, v) = (\(number(curves.basepoint.u)), \(number(curves.basepoint.v)))`; `\(curves.segmentCount)` interpolated segments per curve.", to: &lines)
        append("", to: &lines)

        append("### Real-time proxy schedule", to: &lines)
        append("", to: &lines)
        append("| Added stage | Lattice direction | Proxy frequency | Proxy amplitude | Upstream reference frequency |", to: &lines)
        append("|---|---:|---:|---:|---:|", to: &lines)
        for corrugation in torus.proxySchedule.corrugations {
            append("| \(corrugation.displayName) | `\(corrugation.direction.label)` | \(corrugation.frequency) | \(number(corrugation.amplitude)) | \(corrugation.upstreamReferenceFrequency) |", to: &lines)
        }
        append("", to: &lines)
        append("The proxy frequencies and amplitudes are deliberately compressed for interaction. They do not reproduce the upstream oscillatory corrugations.", to: &lines)
        append("", to: &lines)

        append("## Methods", to: &lines)
        append("", to: &lines)
        append("1. **Finite metric residual.** \(report.methods.metricResidual)", to: &lines)
        append("2. **Fundamental winding curves.** \(report.methods.windingCurve)", to: &lines)
        append("3. **Normal scale microscope.** \(report.methods.normalScaleStatistic)", to: &lines)
        append("4. **Descriptive log-log fit.** \(report.methods.descriptiveSlope)", to: &lines)
        append("5. **Proxy displacement.** \(report.methods.proxyDisplacement)", to: &lines)
        append("6. **Finite-grid exclusion.** \(report.methods.samplingBoundary)", to: &lines)
        append("", to: &lines)

        append("## Bounded findings", to: &lines)
        append("", to: &lines)
        for finding in report.boundedFindings {
            append("- **\(finding.claimClass.rawValue) · \(finding.identifier).** \(finding.statement) \(finding.limitation)", to: &lines)
        }
        append("", to: &lines)

        append("## Cross-stage summary", to: &lines)
        append("", to: &lines)
        append("| Geometry stage | Geometry class | Metric RMS | Metric maximum | u winding residual | v winding residual | Median normal slope | P95 normal slope | Max displacement from short torus |", to: &lines)
        append("|---|---|---:|---:|---:|---:|---:|---:|---:|", to: &lines)
        for stage in report.stages {
            let uCurve = curve(stage, direction: LatticeDirection(u: 1, v: 0))
            let vCurve = curve(stage, direction: LatticeDirection(u: 0, v: 1))
            append(
                "| \(stage.stage.shortDisplayName) | `\(stage.geometryClaimClass.rawValue)` | \(number(stage.metric.statistics.rootMeanSquare)) | \(number(stage.metric.statistics.maximum)) | \(optionalNumber(uCurve?.diagnostic.polylineRelativeLengthResidual)) | \(optionalNumber(vCurve?.diagnostic.polylineRelativeLengthResidual)) | \(optionalNumber(stage.normalMicroscope.medianLogLogFit.slope)) | \(optionalNumber(stage.normalMicroscope.percentile95LogLogFit.slope)) | \(number(stage.displacement.fromShortTorus.maximum)) |",
                to: &lines
            )
        }
        append("", to: &lines)
        append("Residuals in the winding columns are `(ambient polyline length - intrinsic target length) / intrinsic target length`. A value near zero for one path is not a surface-wide isometry result.", to: &lines)
        append("", to: &lines)

        append("## Metric residual tables", to: &lines)
        append("", to: &lines)
        append("All rows are `HV EXPERIMENT`. The target tensor is `(E,F,G)=(1,0,1)` and the reported scalar is its finite-difference Frobenius residual.", to: &lines)
        append("", to: &lines)
        append("| Stage | Δu | Δv | Minimum | Median | Mean | RMS | P95 | Maximum | Samples |", to: &lines)
        append("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|", to: &lines)
        for stage in report.stages {
            let metric = stage.metric
            let stats = metric.statistics
            append("| \(stage.stage.shortDisplayName) | \(number(metric.finiteDifferenceStepU)) | \(number(metric.finiteDifferenceStepV)) | \(number(stats.minimum)) | \(number(stats.median)) | \(number(stats.mean)) | \(number(stats.rootMeanSquare)) | \(number(stats.percentile95)) | \(number(stats.maximum)) | \(stats.count) |", to: &lines)
        }
        append("", to: &lines)
        append("Claim ceiling: \(report.stages[0].metric.claimCeiling)", to: &lines)
        append("", to: &lines)

        append("## Winding-curve diagnostics", to: &lines)
        append("", to: &lines)
        append("| Stage | Curve | Segments | Intrinsic target | Ambient chord | Ambient polyline | Chord / intrinsic | Polyline residual |", to: &lines)
        append("|---|---|---:|---:|---:|---:|---:|---:|", to: &lines)
        for stage in report.stages {
            for winding in stage.windingCurves {
                let diagnostic = winding.diagnostic
                append("| \(stage.stage.shortDisplayName) | \(winding.label) | \(diagnostic.segmentCount) | \(number(diagnostic.intrinsicTargetLength)) | \(number(diagnostic.ambientChordLength)) | \(number(diagnostic.ambientPolylineLength)) | \(number(diagnostic.chordToIntrinsicRatio)) | \(number(diagnostic.polylineRelativeLengthResidual)) |", to: &lines)
            }
        }
        append("", to: &lines)
        append("The endpoint chord of a complete periodic winding should be zero up to interpolation and floating-point effects; its nonzero intrinsic target length is precisely why ambient chord and intrinsic distance must not be conflated.", to: &lines)
        append("", to: &lines)

        append("## Normal-field scale microscope", to: &lines)
        append("", to: &lines)
        append("For each stage, `ω` is an angle in radians. Degrees are included only for human readability. The scale radius used by the fit is the geometric mean of the anisotropic parameter radii.", to: &lines)
        append("", to: &lines)
        for stage in report.stages {
            let microscope = stage.normalMicroscope
            append("### \(stage.stage.shortDisplayName)", to: &lines)
            append("", to: &lines)
            append("Samples: `\(microscope.actualSampleCount)` of `\(microscope.requestedSampleCount)` requested, deterministic seed `\(hex(microscope.deterministicSeed))`.", to: &lines)
            append("", to: &lines)
            append("| Grid step h | Radius u | Radius v | Valid samples | Excluded samples | Median ω (rad) | Median ω (deg) | P95 ω (rad) | P95 ω (deg) | Maximum ω (rad) |", to: &lines)
            append("|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|", to: &lines)
            for observation in microscope.observations {
                let stats = observation.omegaStatisticsRadians
                append("| \(observation.gridStep) | \(number(observation.parameterRadiusU)) | \(number(observation.parameterRadiusV)) | \(observation.validSampleCount) | \(observation.excludedSampleCount) | \(number(stats.median)) | \(number(radiansToDegrees(stats.median))) | \(number(stats.percentile95)) | \(number(radiansToDegrees(stats.percentile95))) | \(number(stats.maximum)) |", to: &lines)
            }
            append("", to: &lines)
            if microscope.excludedScales.isEmpty {
                append("Excluded scales: none.", to: &lines)
            } else {
                append("Excluded scales:", to: &lines)
                append("", to: &lines)
                for excluded in microscope.excludedScales {
                    append("- `h = \(excluded.gridStep)`: \(excluded.reason)", to: &lines)
                }
            }
            append("", to: &lines)
            appendFit(microscope.medianLogLogFit, to: &lines)
            appendFit(microscope.percentile95LogLogFit, to: &lines)
            append("", to: &lines)
        }
        append("Claim ceiling: \(report.stages[0].normalMicroscope.claimCeiling)", to: &lines)
        append("", to: &lines)

        append("## Proxy displacement", to: &lines)
        append("", to: &lines)
        append("| Stage | Previous stage | From short torus mean | From short torus RMS | From short torus P95 | From short torus max | Increment mean | Increment RMS | Increment max |", to: &lines)
        append("|---|---|---:|---:|---:|---:|---:|---:|---:|", to: &lines)
        for stage in report.stages {
            let baseline = stage.displacement.fromShortTorus
            let incremental = stage.displacement.fromPreviousStage
            append("| \(stage.stage.shortDisplayName) | \(stage.displacement.previousStage?.shortDisplayName ?? "—") | \(number(baseline.mean)) | \(number(baseline.rootMeanSquare)) | \(number(baseline.percentile95)) | \(number(baseline.maximum)) | \(optionalNumber(incremental?.mean)) | \(optionalNumber(incremental?.rootMeanSquare)) | \(optionalNumber(incremental?.maximum)) |", to: &lines)
        }
        append("", to: &lines)
        append("Claim ceiling: \(report.stages[0].displacement.claimCeiling)", to: &lines)
        append("", to: &lines)

        append("## Interpretation boundaries", to: &lines)
        append("", to: &lines)
        append("This experiment deliberately preserves several distinctions:", to: &lines)
        append("", to: &lines)
        append("- The short torus is a regenerated upstream starting formula; the three rippled surfaces are newly written low-frequency explanatory proxies.", to: &lines)
        append("- A finite-difference residual is a sensor reading, not a proof. Grid resolution, interpolation, derivative stencil, and chosen paths all influence the number.", to: &lines)
        append("- A short log-log line through six retained scales can be useful for visual comparison, but it does not reveal an asymptotic exponent by itself.", to: &lines)
        append("- The sampled normal field belongs to each triangulated/procedural finite surface, not to the limiting C1 isometric embedding in the Hévéa papers.", to: &lines)
        append("- The report has no error-controlled comparison with the historical 10,000 × 10,000 computation and no physical Vision Pro performance evidence.", to: &lines)
        append("- Results may motivate higher-resolution, cross-resolution, or upstream-matched experiments; they do not settle a mathematical open question.", to: &lines)
        append("", to: &lines)

        append("## Reproduce", to: &lines)
        append("", to: &lines)
        append("Run from the repository root. The first command fails if the current `Packages/HeveaCore` tree or working copy differs from the pinned core checkpoint; the experiment package itself may live in a later commit:", to: &lines)
        append("", to: &lines)
        append("```sh", to: &lines)
        append("git diff --exit-code \(report.run.coreRevision) -- Packages/HeveaCore", to: &lines)
        append("swift run -c release --package-path Research/ScaleMicroscope hevea-scale-microscope --output-directory docs/research", to: &lines)
        append("```", to: &lines)
        append("", to: &lines)
        append("The executable writes `docs/research/scale-microscope-report.json` and this Markdown file. To audit determinism, run twice into separate temporary directories and compare SHA-256 hashes of corresponding files.", to: &lines)
        append("", to: &lines)

        append("## Source trail", to: &lines)
        append("", to: &lines)
        append("- Hévéa project: <\(report.upstreamSource.projectURL)>", to: &lines)
        append("- Pinned GPL source: <\(report.upstreamSource.sourceRepositoryURL)> at `\(report.upstreamSource.revision)`", to: &lines)
        append("- Source path adapted for the short-torus baseline: `\(report.upstreamSource.sourcePath)`", to: &lines)
        append("- Machine-readable companion: [`scale-microscope-report.json`](scale-microscope-report.json)", to: &lines)
        append("", to: &lines)
        append("Generated deterministically by `Research/ScaleMicroscope` from HeveaCore `\(report.run.coreRevision)`.", to: &lines)

        return lines.joined(separator: "\n") + "\n"
    }

    private static func appendFit(
        _ fit: DescriptiveLogLogFit,
        to lines: inout [String]
    ) {
        if let slope = fit.slope, let intercept = fit.intercept {
            append("- Fit for **\(fit.statistic)** over `h = [\(fit.includedGridSteps.map(String.init).joined(separator: ", "))]`: slope `\(number(slope))`, intercept `\(number(intercept))`, R² `\(optionalNumber(fit.coefficientOfDetermination))`.", to: &lines)
        } else {
            append("- Fit for **\(fit.statistic)**: unavailable — \(fit.exclusionReason ?? "no retained finite fit").", to: &lines)
        }
        append("  Claim ceiling: \(fit.claimCeiling)", to: &lines)
    }

    private static func curve(
        _ stage: StageExperimentReport,
        direction: LatticeDirection
    ) -> WindingCurveSummary? {
        stage.windingCurves.first { $0.direction == direction }
    }

    private static func radiansToDegrees(_ radians: Double) -> Double {
        radians * 180 / Double.pi
    }

    private static func append(_ line: String, to lines: inout [String]) {
        lines.append(line)
    }

    private static func optionalNumber(_ value: Double?) -> String {
        value.map(number) ?? "—"
    }

    private static func number(_ value: Double) -> String {
        let normalized = abs(value) < 5e-16 ? 0 : value
        return String(
            format: "%.9g",
            locale: Locale(identifier: "en_US_POSIX"),
            normalized
        )
    }

    private static func hex(_ value: UInt64) -> String {
        String(
            format: "0x%016llX",
            locale: Locale(identifier: "en_US_POSIX"),
            value
        )
    }
}
