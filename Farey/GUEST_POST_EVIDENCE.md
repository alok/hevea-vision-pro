# Evidence for a proposed spatial-mathematics guest post

The demonstrable result is an independent spatial rendering of the integer lattice behind Farey fractions, with matching native visionOS and browser implementations. A rational p/q becomes the direction of the integer vector (q,p). Adjacent Farey vectors span a unit-area parallelogram; their sum gives the mediant. The green direction plane makes the multiples visible in space.

Credit **Katherine Stange** prominently, next to links to her [talk](https://katestange.net/talks/math-exploration/) and [visualization catalog](https://www.katestange.net/code/). Credit [Caroline Series (1985)](https://doi.org/10.1112/jlms/s2-31.1.69) for the underlying L/R geodesic coding. We ran and inspected the original talk's lattice viewer as reference, but wrote original implementation code. No source-code or media license for Stange's original is presumed. This is not an official port or endorsement.

## Evidence that can accompany the post

- [Native 3/5 scene](evidence/spatial/showcase.png): full black immersion, actual spatial lattice and perpendicular direction plane, native controls.
- [Opposite viewpoint](evidence/spatial/right-view.png): parallax from a controlled model translation relative to the stationary viewer.
- [Linked Poincaré disk](evidence/spatial/linked-disk.png): the same exact rational state in a second representation.
- [39-second simulator video](evidence/spatial/demo.mp4): real simulator recording, including transitions out of and back into immersion.
- [Browser scene](evidence/webxr/farey-webxr-final.png) and [mouse orbit](evidence/webxr/farey-webxr-orbit.png): original Three.js rendering with real pointer interaction.
- [Native test summary](evidence/spatial/simulator-summary.json) and [browser check record](evidence/webxr/validation.json).

## Claims supported by this work

Seven Swift math tests, six native model/UI tests, and eight JavaScript tests passed. Native UI tests exercised entry, exit, repeated re-entry, L/R, Undo, Reset, bounds and linked representation selection. Browser checks exercised orbit, sphere hit-testing, fraction entry, bounds and recovery. The latest native device-target Release build passed strict signature verification using existing signing material.

## Claims to leave open

There has been no physical-headset installation or execution in this task. The local desktop browser reports immersive VR unsupported, so the implemented WebXR session and controller path has not been verified on Quest, Meta Browser or physical Vision Pro. Do not claim headset performance, comfort, hand/eye interaction quality, Meta affiliation, or a public deployment. The finite lattice is exact within its stated bounds; it is not the infinite Farey fractal or Stange's separate hyperboloid construction.

The UI word denotes M(1). Stange's endpoint convention sends M(∞) to the same fraction after appending R; for 3/5 the two displayed words are RLR and RLRR respectively. State this distinction if showing both applications together.

A separate visionOS 27.2 Safari probe reported immersive VR available, but a welcome screen and XCTest `kAXErrorAPIDisabled` blocked entry. No XR frames were observed. A [static deployment plan](WebXR/DEPLOYMENT_PLAN.md) and local artifact are prepared; publication remains unperformed.

The browser also offers a worked “predict, apply, explain” path: 1/2 → L → 2/3 → R → 3/5. It uses the ordinary L/R state and shows its exact vector additions. This is a demonstrable interaction; no learner study or educational efficacy is claimed.
