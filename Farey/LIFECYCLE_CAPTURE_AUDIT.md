# Foreground rendering and capture audit — 22 October 2026

Native 0.8/build 10. Application runtime code remains from `665e54f`; this work changes tests and capture tools. The main simulator's 3/5 Left showcase was left untouched.

## Findings

Two cycles exercised lattice → boundary chart → preview → Home → activation/re-entry → selection → viewpoint → lattice → exit/re-entry → idle, with continuous video and timestamped screenshots.

The external screenshots were not synchronized with the tests. Acquisition finished as late as 10.24 seconds after a marker; queued later captures lagged by up to 13.95 seconds. A file labeled “confirmed” showed the later lattice/exit state. This is a verified capture-harness defect, not evidence of an unexpected mathematical state change.

Video also showed two multi-second geometry gaps while controls remained visible. Timing mislabeling alone does not explain every bad image. XCTest's native screenshot API returned 1×1 black images on this runtime and was rejected as visual evidence.

A temporary read-only probe logged entity identities, scene membership, active/enabled state, session, revision, selected word and title attachment at half-second intervals. The entities attached to the scene matched those updated by rendering tasks. Lattice and title entities remained active after re-entry. Some captures also lost parts of the separate SwiftUI control window. All temporary runtime instrumentation was removed.

A control run used unmodified runtime code, the same two-cycle path, and continuous video with **no still-image requests**. At four sampled frames per second, it showed no multi-second gaps; empty samples lasted 0.25–0.75 seconds around entry, Home or exit. This is not a frame-perfect or hardware guarantee. The observations support a simulator render/capture interaction rather than demonstrated loss of scene entities. The simulator's internal cause remains uncertain.

## Verified regression

All 28 tests in the complete native suite passed: 14 model/renderer tests and 14 UI scenarios, including two repeated foreground/selection/re-entry cycles. All 62 screenshot commands completed successfully. The 21 exported lifecycle PNG attachments are 3840×2160, rather than the native screenshot API’s 1×1 placeholders. Three capture-configuration regression tests and strict SwiftLint passed. The separate video-only tour also passed; an 86-second, 1080p H.264 export decoded without errors. These results verify state behavior and the capture protocol, not pixel-perfect simulator compositing.

## Correction and reproduction

The capture tool now waits for a request/acknowledgment handshake: XCTest holds the exact state until `simctl` finishes, then receives the image and timing record as test attachments. It follows Xcode's newly installed runner container and preserves relative `.xctestrun` product paths. Tests cover both configuration formats and reject relocation. The demonstration recorder captures video without requesting still images; synchronized stills use a separate run. No artificial rendering delay was added to the app, and the handshake does not assert pixel correctness.

From `Farey`, run `python3 scripts/capture-tests.py --output /tmp/farey-captured-tests`. It creates and removes an isolated simulator. Use `--simulator UDID` only for an already isolated device. Add `--only-testing FareyVisionUITests/FareyUITests/testForegroundGeometryCaptureSequence` for the new scenario alone.

For a video-only tour, run `python3 scripts/record-demo.py --output /tmp/farey-video-only`. Use a fresh output directory.

See [evidence and results](evidence/lifecycle-capture/README.md). Apple's [`SceneEvents.Update`](https://developer.apple.com/documentation/realitykit/sceneevents/update) and [`Entity.isActive`](https://developer.apple.com/documentation/realitykit/entity/isactive) provide scene-state observations, not proof that a screenshot contains an entity's pixels.

Actual immersive WebXR, hardware rendering and hand/gaze input remain unverified. No permission, signing, deployment or upload changes were made.
