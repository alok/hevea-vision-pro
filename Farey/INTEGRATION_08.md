# Current integration check — native 0.8 / browser 0.7.0

The subsequent [lifecycle capture audit](LIFECYCLE_CAPTURE_AUDIT.md) investigates the visual uncertainty below and corrects screenshot synchronization. This page retains the earlier measurements.

The application implementation is commit `665e54fb6839563ba9ead173e21a720cea10648d`. This integration pass adds regression coverage and corrects stale evidence labels; it does not add mathematical features. Native display name: **Farey — Into the Infinite**, bundle `com.alok.FareyVision`, build **10**.

## Main simulator

The main simulator was inspected before installation: target 3/5, inspected primitive point `(5,3)`, word RLR, grid 12, left viewpoint, ordinary lattice, no active construction or spotlight. Native 0.8 was installed and run there. A fresh-launch test entered full immersion, opened the projected chooser, left it idle, backgrounded and reactivated the app, then confirmed 11/12. The 3/5 left-view showcase was restored afterward.

The idle images retained the same preview and target. Their 3840×2160 pixel comparison found 404 changed color channels out of 24,883,200, each changing by one 8-bit step, confined to preview text. This is evidence of stable simulator rendering in that check, not a physical-headset frame-rate or comfort measurement.

[Main test result](evidence/integration-08/main-test-summary.json) · [Restored 0.8 showcase](evidence/integration-08/main-08-restored.png) · [Idle comparison](evidence/integration-08/idle-pixel-check.json).

## Complete native regression

All 27 tests in the complete native suite passed in a separate visionOS 27.2 simulator: 14 model/renderer tests and 13 UI scenarios. The additional main-simulator execution of the new fresh-launch/foreground scenario also passed. The platform-neutral Swift package's 27 tests and browser's 26 unit tests passed during this pass. No application runtime code changed.

[Full native summary](evidence/integration-08/native-full-summary.json) · [Validation scope](evidence/integration-08/validation.json).

## Visual follow-up

The first immediate foreground capture showed the controls with no geometry above them, despite passing state assertions. An instrumented repeat on the isolated simulator waited five seconds after re-entry and after selection: geometry was visible, 11/12 remained selected, the viewpoint changed, and exit/re-entry completed. Its one test passed. This does not establish immediate frame readiness or a maximum recovery time. Some attachment text also differs between the captures. The cause of the first blank capture remains unresolved; no speculative runtime fix was applied.

[Initial blank capture](evidence/integration-08/51-chooser-foreground.png) · [Settled foreground](evidence/integration-08/53-foreground-before-selection.png) · [Selected 11/12](evidence/integration-08/54-foreground-after-selection.png) · [Returned lattice](evidence/integration-08/56-foreground-lattice.png) · [Diagnostic result](evidence/integration-08/foreground-diagnostic-summary.json).

## Browser source and static artifact

All 14 files in the static artifact match their manifest hashes. The seven implementation/style files and HTML match the source after normalizing only cache-version query strings and the static vendor paths. Package version is 0.7.0. The headless source and static pages produced pixel-identical projected-chooser captures and both confirmed 13/14 correctly.

[Artifact comparison](evidence/integration-08/browser-artifact-check.json) · [Live source/static comparison](evidence/integration-08/browser-live-comparison.json).

Historical evidence remains linked with its actual version. The older native 0.6.1 / browser 0.5.1 videos have not been rerecorded and do not demonstrate the construction or projected chooser. The playback page and evidence index now state this explicitly.

## Remaining scope

Desktop 3D and native simulator tests are distinct from immersive WebXR and physical headset execution. The previous direct RealityKit coordinate-tap attempt failed with an invalid activation transform. A separate diagnostic using the documented `XCUIElement.tap()` API also failed: the sphere was exposed as an accessibility element with placeholder frame `(0,0,50,50)`, but Xcode reported `Received invalid activation point transform (nil) from Accessibility`. Neither attempt verifies direct sphere input. Ordinary native chooser controls and the model route passed. No accessibility, security or tracking settings were changed. The diagnostic was temporary and is excluded from the passing 27-test regression suite.

[Direct-tap diagnostic](evidence/integration-08/direct-tap-result.json) · [Existing signed Release artifact](evidence/integration-08/signed-artifact.json). The unchanged 0.8 hardware-target artifact passed strict signature verification again; it has not been installed or executed on a headset.

Independent work remains useful: isolate the foreground frame/attachment timing issue, record new local walkthroughs for the current versions, and make release packaging repeatable. There is no verified need for another mathematical feature in this checkpoint. Actual WebXR entry/frames, physical hand/gaze validation and spoken assistive-technology review require suitable runtime/device access and user participation. No public deployment is part of this integration pass.

To run the current native showcase from `Farey`, use `./scripts/run-simulator.sh --showcase`. For a normal fresh entry, omit `--showcase`. Browser instructions remain in [WebXR/README.md](WebXR/README.md).
