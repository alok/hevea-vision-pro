# Deep-path native rendering audit

Native 0.8, build 10, visionOS 27.2 simulator. The app's runtime source is unchanged from `ad705fd`; this work adds renderer/UI tests and recording support for selected test cases. The main 3/5 showcase and foreground source/preview were not used by these tests.

## What the images establish

The 24-move alternating path selects the exact interval

```text
46368/28657 < 121393/75025 < 75025/46368.
```

The native controls display these three distinct fractions. Their disk markers have identical Float32 positions. The complete [front screenshot](evidence/deep-native/005-deep-limit-front.png) shows overlapping markers near the upper-right boundary, while the exact values remain distinct in the controls. Exit and re-entry preserve that state. This is expected finite display resolution, not rational equality. The screenshot alone cannot isolate Float32 rounding from ordinary pixel resolution and finite marker width; the generated-mesh checks establish the coincident positions.

For the 19-move word `LRLRRRLLRLLRLLLLLRR`, the interval is

```text
762/487 < 2419/1546 < 1657/1059.
```

Its endpoint separation is about 0.000001125 in local disk coordinates: roughly 25,000 times smaller than the drawn marker diameter of 0.028. The [oblique disk view](evidence/deep-native/003-deep-counterexample-left.png) shows the resulting overlap. The [lattice view](evidence/deep-native/004-deep-counterexample-lattice.png) retains the same fraction and explicitly states that the primitive point lies beyond the finite grid; it does not move that point into the visible patch.

Exact state attachments confirm the repeated-L boundary case `24/1 < 25/1 < ∞`. Its [screenshot](evidence/deep-native/007-deep-repeated-L.png) also has partial capture loss, so geometric conclusions do not rely on that image. The ordinary 3/5 case provides a separated-marker control.

## Capture limitation reproduced

The first [front capture of 2419/1546](evidence/deep-native/002-deep-counterexample-front.png) lost part of the left disk, title and several controls. A later oblique capture retained the full disk. Missing parts of separate controls cannot be explained by the selected arc's Float32 rounding. This reproduces the broader [capture uncertainty](LIFECYCLE_CAPTURE_AUDIT.md); it does not establish its internal cause or distinguish an on-screen transient from simulator compositing/readback. The partial image is retained as diagnostic evidence, not presented as the intended geometry.

Screenshots use the request/acknowledgment capture handshake. Each image has a matching exact-state attachment and capture timing. The handshake holds the requested application state during acquisition; it does not guarantee complete simulator compositing.

The separate video-only run requested no still images. Its [sampled front frame](evidence/deep-native/008-video-counterexample-front.png) shows the full 2419/1546 scene, with the same exact values as the partial still. All seven sampled video frames retained the disk/lattice geometry and controls, but three lost part of the title. Thus removing still-image requests did not eliminate every capture defect. This is a seven-frame review, not a claim that every video frame is complete.

## Verified results

- The first isolated run passed its renderer test and deep-path UI test, producing seven synchronized screenshots.
- The final isolated run passed all 15 model/renderer tests plus the deep-path UI test. Five exact states, including repeated L and repeated R boundary paths, were rendered at all three viewpoints. All 15 generated-mesh inspections found finite positions/normals and no zero-area triangles, including in the history meshes. The largest scene inspected had 72,777 vertices and 140,736 triangles.
- The actual left, right and target marker positions coincided for the 24-step alternating case at all three viewpoints. The stored rational state stayed distinct and unchanged.
- The UI checked exact labels, the move bound, the out-of-grid explanation, exit/re-entry, Undo, Reset and direct entry of 25/1. No sphere-tap, hardware or actual WebXR test is implied.
- Strict SwiftLint and the three capture-coordinator regressions passed. The 82-second 1920×1080 H.264 export decoded without errors and has no audio. Video remains local; it was not committed or uploaded.

No incorrect mathematical label, nonfinite mesh or silent point clamp was reproduced. The smallest supported change is the added regression/evidence coverage. No application geometry or timing workaround was added; the cause and duration of capture incompleteness remain unresolved.

## Reproduce

```sh
python3 scripts/capture-tests.py --output /tmp/farey-deep-check \
  --only-testing FareyVisionTests/DeepPathRendererTests \
  --only-testing FareyVisionUITests/FareyUITests/testDeepDiskPathsAndExactLabels

python3 scripts/record-demo.py --output /tmp/farey-deep-video \
  --only-testing FareyVisionTests \
  --only-testing FareyVisionUITests/FareyUITests/testDeepDiskPathsAndExactLabels
```

Use new output directories. Each command creates and removes its own simulator. The second records video without requesting still images. Neither command installs to the main showcase or uses a physical headset.

See [evidence/deep-native](evidence/deep-native/) for results, exact labels, source hashes and capture timing. This remains a finite, original implementation inspired by [Katherine Stange's talk](https://katestange.net/talks/math-exploration/) and [Caroline Series's work](https://doi.org/10.1112/jlms/s2-31.1.69), not a proof, a reconstruction of an infinite fractal, or a hardware/WebXR validation.
