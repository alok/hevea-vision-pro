# visionOS Simulator evidence

This directory is the landing zone for bounded, reproducible simulator runs. It is deliberately separate from physical-headset evidence: a passing row here says that a build launched and rendered in a named visionOS Simulator runtime. It does **not** establish headset performance, comfort, tracking fidelity, or interaction quality.

Generated `runs/` are ignored by Git. Review screenshots and logs for private or machine-specific information before deliberately curating any artifact.

## Safe preflight

The preflight reads the Xcode installation, installed simulator list, project, and free-disk count. It does not boot a device, build, install, launch, or capture.

```bash
Scripts/run-simulator-matrix.sh --preflight-only
```

## Canonical matrix

This produces 16 launches and screenshots: four scenarios, two repetitions, and two runtimes. It leaves each simulator booted and the final app instance running, and it never erases devices, removes app data, shuts down simulators, or deletes `.derivedData`.

```bash
Scripts/run-simulator-matrix.sh \
  --runtime all \
  --scenarios mission-control,stage-sweep,metric-heatmap,scale-microscope \
  --repetitions 2 \
  --settle-seconds 6 \
  --show-simulator
```

For a quick smoke pass:

```bash
Scripts/run-simulator-matrix.sh \
  --runtime 27.0 \
  --scenarios mission-control,scale-microscope \
  --repetitions 1
```

The repetition bound is 10 and the scenario bound is 12, preventing an accidental unbounded launch loop. The default free-disk floor is 16 GiB and is checked before each build and launch. Override it only deliberately with `--min-free-gib`; the accepted range is 5-100 GiB.

## App automation contract

Each launch receives both environment variables and arguments so the app can deterministically select a view without simulator UI automation:

```text
HEVEA_AUTOMATION=1
HEVEA_SCENARIO=<scenario>
HEVEA_REPETITION=<1-based run>

--hevea-automation
--hevea-scenario <scenario>
--hevea-repetition <1-based run>
```

An app version that does not yet consume this contract will still launch and capture, but different scenario rows may show the same initial view. That limitation should remain visible in the receipt rather than being interpreted as scenario coverage.

## Artifacts and receipt

Each run is written under `docs/simulator-evidence/runs/<UTC timestamp>-<pid>/` and contains:

- one quiet Xcode build log per runtime;
- boot and install logs;
- one launch result, PNG screenshot, and filtered unified log per matrix row;
- `receipt.json`, containing the exact toolchain, revision, simulator IDs, step statuses, disk accounting, and SHA-256 artifact hashes;
- `receipt.md`, a compact human-readable matrix with links to every capture.

All builds reuse the repository-local `.derivedData` directory. `--skip-build` may reuse its existing `Debug-xrsimulator/HeveaVision.app`; it fails closed if that product is absent. The harness performs no automatic cleanup, so disk reclamation remains an explicit human decision.

## Fixed simulator identities

| Label | Device UDID |
|---|---|
| visionOS 26.5 | `820CCDAA-EA00-41FC-8A4A-675701BD9E33` |
| visionOS 27.0 | `4077DC3A-1866-489B-98AC-206E86DCEB74` |

The harness uses `/Applications/Xcode-27.0.0-Beta.5.app/Contents/Developer` unless `--developer-dir` explicitly selects another installation. `xcrun` and `xcodebuild` are invoked by absolute path with `DEVELOPER_DIR` set for every call.
