# Simulator evidence

[Watch the 32-second simulator tour](demo.mp4). [Launch instructions](../README.md#run-on-this-mac).

Environment: Xcode 27.2 beta 2 (27B5028f), visionOS simulator 27.2 (24N5093f), Apple Vision Pro `D2ECE520-ED92-4A38-A990-AE65431DF562`. The room visible before entry is the simulator's synthetic environment. The captures contain no desktop or private recording.

## Verified results

- **Exact core: 5 passed.** All 8,191 L/R words through length 12 preserve determinant 1 and reduced mediants. Tests cover the 24-move cap, undo/reset, tessellation counts and disk bounds through depth 8, and a known orthogonal circular geodesic.
- **Native simulator: 4 passed, 0 failures** in `Simulator-20261021T232015Z.xcresult`, completed 2026-10-21 23:22:27 UTC. [Exported Xcode result summary](simulator-summary.json). This is one model test and three UI tests, with seven immersive sessions in the same running app, including four consecutive enter/L/reset/exit cycles.
- The UI tests assert attribution, exact `LR → 3/2`, Undo, the example word, all three object views, minimum/maximum detail, disabled controls at 24 moves, recovery after Undo, repeated Reset, and repeated exit/re-entry.
- **Release build: succeeded.** The optimized app was installed and launched on the simulator. Strict SwiftLint passed with zero violations; staged whitespace checks passed.
- **Optimized simulator suite: 4 passed, 0 failures**, completed 2026-10-21 23:30:28 UTC. [Release result summary](release-summary.json). Run with `-configuration Release ENABLE_TESTABILITY=YES ONLY_ACTIVE_ARCH=YES` for the model test's internal-module access.
- [Measured rendering updates](performance-samples.json): two 509-edge rebuilds took 12.62–13.01 ms; 36 updates at the 253-edge default had a median of 1.76 ms and a maximum of 19.39 ms. These are synchronous CPU-side update timings from this simulator run, not frame-rate or headset measurements.

| Capture | Verified state |
|---|---|
| [Entry](00-entry.png) | Prominent Katherine Stange credit, original links, Series link |
| [Sources](00-sources.png) | Full attribution and precise original/finite implementation description |
| [Initial void](01-initial-void.png) | Stationary, full black immersion, 253-edge default |
| [L then R](02-LR-selection.png) | Selected itinerary and exact mediant 3/2 |
| [Oblique](03-oblique.png), [side](04-side.png) | Static object rotations without forced camera motion |
| [Maximum detail](05-maximum-detail.png) | 509-edge rendering cap |
| [Reset](06-reset.png), [re-entry](07-reentered.png) | Initial state restored and geometry recreated |
| [24-move limit](08-move-limit.png) | Full fraction remains legible, determinant 1, L/R disabled |
| [Viewer left](10-viewer-left.png), [viewer right](11-viewer-right.png), [closer](12-viewer-near.png) | Independent camera translation, intact world-space geometry and readable controls |

[Frame manifest](frame-manifest.json) records timestamps in the raw simulator recording. The final passing suite occurred within a continuous simulator-only recording that was finalized after a simulator restart. The curated clip and PNGs are from that suite, not reconstructed mockups. Raw movies, logs and `.xcresult` bundles remain local and are excluded from Git. Reproduce using `scripts/test-simulator.sh` or `scripts/capture-tests.py`.

## Fixes found through simulation

An initial SwiftUI container identifier overrode its child button identifiers; it was removed. Directly dismissing/reopening the last regular window caused a second-exit failure. The app now follows Apple's [associated-window pattern](https://developer.apple.com/documentation/visionos/associating-a-window-with-an-immersive-space): a pushed controls window retains the entry window in the background, and the active scenes close together. Each immersive session has fresh scene identity, and rendering waits for the open operation to complete.

XCTest's `XCUIScreen.screenshot()` reports “Manual screenshots are not supported” on this runtime. Evidence uses `simctl io recordVideo` and `simctl io screenshot`. The recording helper now checks that recording actually starts and that a finalized file exists; it does not report a busy recorder as a saved video.

## Scope of validation

The simulator exercised front, oblique and side **object views**, plus independent left/right/forward camera translation using Device Hub's documented A/D/W controls. Reset Camera restored the default. A temporary local XCTest harness held the immersive scene open during this inspection, then reset and exited; it is not part of the shipped test suite. Device Hub's coordinate-input bridge intermittently returned `noWindowsAvailable`; keyboard navigation and native XCTest interactions supplied working alternatives.

No physical-headset execution, hand/eye gesture, comfort, frame-rate or battery claim is made. Available signing identities and the paired physical headset were inspected; no hardware deployment was attempted. Geometry is capped at 509 background edges in the app, sampled with 32 segments and six-sided tubes, and grouped into at most 13 model entities. No per-frame geometry generation runs.
