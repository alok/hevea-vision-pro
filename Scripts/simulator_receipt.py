#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# ///
"""Render a compact, reviewable receipt from simulator matrix event rows."""

from __future__ import annotations

import argparse
import csv
import json
from collections import Counter, defaultdict
from pathlib import Path
from typing import TypedDict


class Event(TypedDict):
    runtime: str
    os_version: str
    udid: str
    initial_state: str
    scenario: str
    repetition: str
    build: str
    boot: str
    install: str
    launch: str
    pid: str
    screenshot: str
    screenshot_path: str
    screenshot_sha256: str
    baseline_path: str
    baseline_sha256: str
    visual_delta: str
    logs: str
    log_path: str
    log_sha256: str
    note: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create receipt.json and receipt.md for one simulator run."
    )
    parser.add_argument("--events", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--started-at", required=True)
    parser.add_argument("--finished-at", required=True)
    parser.add_argument("--status", required=True, choices=("passed", "partial", "failed"))
    parser.add_argument("--repository-revision", required=True)
    parser.add_argument("--developer-dir", required=True)
    parser.add_argument("--project", required=True)
    parser.add_argument("--scheme", required=True)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--derived-data", required=True)
    parser.add_argument("--derived-data-bytes", required=True, type=int)
    parser.add_argument("--repetitions", required=True, type=int)
    parser.add_argument("--scenarios", required=True)
    parser.add_argument("--runtimes", required=True)
    parser.add_argument("--disk-before-bytes", required=True, type=int)
    parser.add_argument("--disk-after-bytes", required=True, type=int)
    parser.add_argument("--xcode-version-file", required=True, type=Path)
    return parser.parse_args()


def read_events(path: Path) -> list[Event]:
    if not path.exists() or path.stat().st_size == 0:
        return []
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle, delimiter="\t"))  # type: ignore[return-value]


def artifact_totals(output_dir: Path) -> tuple[int, int]:
    count = 0
    size = 0
    for path in output_dir.rglob("*"):
        if path.is_file() and path.name not in {"receipt.json", "receipt.md"}:
            count += 1
            size += path.stat().st_size
    return count, size


def gibibytes(byte_count: int) -> float:
    return round(byte_count / (1024**3), 2)


def mibibytes(byte_count: int) -> float:
    return round(byte_count / (1024**2), 2)


def markdown_cell(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", " ")


def main() -> None:
    args = parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    events = read_events(args.events)
    xcode_version = (
        args.xcode_version_file.read_text(encoding="utf-8").strip()
        if args.xcode_version_file.exists()
        else "unavailable"
    )

    runtime_rows: dict[str, list[Event]] = defaultdict(list)
    for event in events:
        runtime_rows[event["runtime"]].append(event)

    runtime_summaries: list[dict[str, object]] = []
    for runtime in args.runtimes.split(","):
        rows = runtime_rows.get(runtime, [])
        runtime_summaries.append(
            {
                "runtime": runtime,
                "udid": rows[0]["udid"] if rows else None,
                "initialState": rows[0]["initial_state"] if rows else None,
                "launchesPassed": sum(row["launch"] == "passed" for row in rows),
                "launchesFailed": sum(row["launch"] == "failed" for row in rows),
                "screenshotsPassed": sum(row["screenshot"] == "passed" for row in rows),
                "visualDeltasPassed": sum(
                    row["visual_delta"] == "passed" for row in rows
                ),
                "visualDeltasFailed": sum(
                    row["visual_delta"] == "failed" for row in rows
                ),
                "logsPassed": sum(row["logs"] == "passed" for row in rows),
            }
        )

    artifact_count, artifact_bytes = artifact_totals(args.output_dir)
    step_counts = {
        step: dict(Counter(event[step] for event in events))
        for step in (
            "build",
            "boot",
            "install",
            "launch",
            "screenshot",
            "visual_delta",
            "logs",
        )
    }
    receipt: dict[str, object] = {
        "schemaVersion": 2,
        "runId": args.run_id,
        "status": args.status,
        "startedAt": args.started_at,
        "finishedAt": args.finished_at,
        "repository": {
            "revision": args.repository_revision,
            "project": args.project,
            "scheme": args.scheme,
            "bundleIdentifier": args.bundle_id,
        },
        "toolchain": {
            "developerDir": args.developer_dir,
            "xcodeVersion": xcode_version,
        },
        "matrix": {
            "runtimes": args.runtimes.split(","),
            "scenarios": args.scenarios.split(","),
            "repetitions": args.repetitions,
            "runtimeSummaries": runtime_summaries,
            "stepCounts": step_counts,
        },
        "storage": {
            "freeBeforeBytes": args.disk_before_bytes,
            "freeAfterBytes": args.disk_after_bytes,
            "derivedDataPath": args.derived_data,
            "derivedDataBytes": args.derived_data_bytes,
            "runArtifactCount": artifact_count,
            "runArtifactBytes": artifact_bytes,
        },
        "events": events,
        "claimBoundary": (
            "This receipt records visionOS Simulator behavior only. It is not evidence "
            "of physical-headset performance, comfort, tracking, or interaction quality."
        ),
    }

    json_path = args.output_dir / "receipt.json"
    json_path.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")

    lines = [
        f"# Simulator evidence receipt - `{args.run_id}`",
        "",
        "> **Claim boundary:** visionOS Simulator evidence only; this is not physical-headset proof.",
        "",
        "| Field | Value |",
        "|---|---|",
        f"| Result | **{args.status}** |",
        f"| Revision | `{args.repository_revision}` |",
        f"| Started | `{args.started_at}` |",
        f"| Finished | `{args.finished_at}` |",
        f"| Runtimes | {markdown_cell(args.runtimes)} |",
        f"| Scenarios | {markdown_cell(args.scenarios)} |",
        f"| Repetitions | {args.repetitions} |",
        f"| Free disk | {gibibytes(args.disk_before_bytes)} GiB before / {gibibytes(args.disk_after_bytes)} GiB after |",
        f"| Shared DerivedData | `{args.derived_data}` ({gibibytes(args.derived_data_bytes)} GiB) |",
        f"| Run artifacts | {artifact_count} files / {mibibytes(artifact_bytes)} MiB |",
        "",
        "## Runtime summary",
        "",
        "| Runtime | Device | Initial state | Launches | Screenshots | Visible delta | Logs |",
        "|---|---|---:|---:|---:|---:|---:|",
    ]
    for summary in runtime_summaries:
        lines.append(
            "| {runtime} | `{udid}` | {initialState} | {launchesPassed} passed / "
            "{launchesFailed} failed | {screenshotsPassed} | {visualDeltasPassed} passed / "
            "{visualDeltasFailed} failed | {logsPassed} |".format(**summary)
        )

    lines.extend(
        [
            "",
            "## Captures",
            "",
            "| Runtime | Scenario | Rep | Launch | Screenshot | Visible delta | Baseline | Unified log | Note |",
            "|---|---|---:|---|---|---|---|---|---|",
        ]
    )
    for event in events:
        screenshot = (
            f"[{event['screenshot']}]({event['screenshot_path']})"
            if event["screenshot_path"]
            else event["screenshot"]
        )
        log = (
            f"[{event['logs']}]({event['log_path']})"
            if event["log_path"]
            else event["logs"]
        )
        baseline = (
            f"[baseline]({event['baseline_path']})"
            if event["baseline_path"]
            else "unavailable"
        )
        lines.append(
            "| {runtime} | {scenario} | {repetition} | {launch} | {screenshot} | "
            "{visual_delta} | {baseline} | {log} | {note} |".format(
                runtime=markdown_cell(event["runtime"]),
                scenario=markdown_cell(event["scenario"]),
                repetition=event["repetition"],
                launch=event["launch"],
                screenshot=screenshot,
                visual_delta=event["visual_delta"],
                baseline=baseline,
                log=log,
                note=markdown_cell(event["note"]),
            )
        )

    lines.extend(
        [
            "",
            "## Toolchain",
            "",
            "```text",
            xcode_version,
            "```",
            "",
            "The JSON receipt contains SHA-256 hashes for every captured screenshot and log.",
            "",
        ]
    )
    markdown_path = args.output_dir / "receipt.md"
    markdown_path.write_text("\n".join(lines), encoding="utf-8")
    print(json_path)
    print(markdown_path)


if __name__ == "__main__":
    main()
