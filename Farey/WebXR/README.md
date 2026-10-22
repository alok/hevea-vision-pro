# Farey lattice — browser and WebXR companion

An original Three.js implementation of the same integer lattice and L/R state as the native visionOS app. Inspired by **[Katherine Stange](https://katestange.net/talks/math-exploration/)** and her [visualization catalog](https://www.katestange.net/code/), with underlying [Caroline Series L/R geodesic coding (1985)](https://doi.org/10.1112/jlms/s2-31.1.69).

## Run locally

```sh
cd Farey/WebXR
npm ci --ignore-scripts
npm test
npm start
```

Open **http://127.0.0.1:8080**. The server binds only to this Mac and disables development caching so edits cannot mix stale styles with new code. Node.js, npm and Python 3 are required. Three.js is pinned to 0.180.0 with an integrity hash in the lockfile. No network dependency is used at runtime after installation.

Drag to orbit, scroll to zoom, right-drag to pan. Hover a sphere to read its integer pair and click to select its rational direction. L/R, Undo, Reset, the 3/5 example and fraction entry share one exact state. Grid size is capped at 14 (224 nonzero points). On narrow screens the lattice occupies a separate visible area above the controls, and the lesson keeps only its relevant actions visible. Rendering is event-driven on desktop; XR uses the headset animation loop. Reset restores the initial geometry and view.

## Immersive VR

The **Enter VR** button becomes available only when `isSessionSupported('immersive-vr')` succeeds. It requests an immersive VR session with a local-floor reference space. The lattice is stationary in a black environment. Controller/select rays can choose points and use the in-world L, R, Undo, Reset, 3/5 and Exit controls. Session end restores the desktop controls. The in-world panel credits Stange and Series; full source links remain in the desktop panel.

WebXR needs a compatible headset browser and a secure context. A headset cannot access the Mac's loopback address directly. Use an already-trusted HTTPS development host or an independently authorized deployment for headset testing. This work does not provision a certificate, change network permissions, or publish a site.

**Verified here:** Safari 27.0.1 completed the worked 1/2 → L → 2/3 → R → 3/5 path with a clean page console. Portrait Chromium at 390 × 844 shows a fitted lattice and legible controls. Chromium desktop rendering and real mouse orbit, L/R/Undo/Reset, rational selection (including 6/10 → 3/5), maximum grid, 24-step limit and recovery. Eight automated tests cover mathematics, unsupported/error paths, transient input pose updates, and desktop camera restoration. This Mac's Chromium reports `immersive-vr` unsupported. A separate visionOS 27.2 simulator Safari reported support and received an actual click requesting immersive VR. Safari displayed a runtime prompt to allow tracking the device’s position and head movements. That permission was left ungranted and the isolated Safari process was closed. No XR session or frame was observed. A mocked pending-request/denial test verified duplicate-entry prevention, continued desktop interaction, and recovery; it is not XR runtime evidence. **Not verified:** Quest/Meta Browser, a physical Vision Pro browser, controller/hand interaction in an actual XR session, device frame rate or comfort. The native simulator is separate evidence, not a WebXR headset test.

## Mathematical correspondence and provenance

Each point is (q,p), uniformly scaled and rigidly rotated into the scene. The green plane is perpendicular to the lattice and passes through its origin and the selected direction. Cyan and purple vectors are Farey neighbors; their orange sum is the mediant. Sphere sizes, colors, finite plane height and placement are presentation choices. The app word represents M(1); appending R puts the same rational in M(∞), matching the endpoint convention seen in Stange's talk viewer.

No Stange JavaScript, media or meshes are bundled. This is an independent implementation of the lattice construction, not her separate hyperboloid visualization or a reproduction of an infinite fractal. Application code is GPL-3.0-or-later under the parent repository license. Three.js is a separate MIT-licensed dependency; its license is installed at `node_modules/three/LICENSE`.

`npm run build` prepares a self-contained static artifact. See the [deployment plan](DEPLOYMENT_PLAN.md); no public deployment has been made.

## Worked path

Choose **Learn a move** to begin at 1/2. Predict the result of L, apply the actual operation, and compare the selected 2/3 point with the vector equation. Continue with R to reach 3/5. The explanation is computed from the same exact state as the lattice. Undo or another manual selection closes a stale lesson; Reset restores the ordinary starting state. This is a teaching interaction, not a claim of measured educational efficacy.

## Browser regression walkthrough

With the local server running, the optional Playwright CLI walkthrough checks keyboard-only lesson completion, focus retention, phone layout, exact reset/undo state, invalid input, reducible fractions and the 24-move limit:

```sh
playwright-cli open http://127.0.0.1:8080/
playwright-cli run-code "$(cat browser-checks.js)"
```

This uses a separately installed Playwright CLI; it is not a runtime dependency. The same walkthrough passed against the built artifact. Actual iPhone 17e **simulator** Safari also completed the lesson, Undo and Reset. See [mobile evidence](../evidence/webxr/mobile-safari-validation.json). Physical iPhone, headset input and immersive WebXR remain separate validation steps.
