# Browser companion — coefficient cone and Farey L/R

Version 0.11.0 opens the **signed 3D coefficient lattice and double cone** at `index.html`. The previous rational-pair lattice remains at `farey.html`; the two pages link to one another. See [the coefficient-cone guide](../COEFFICIENT_CONE.md) for exact coordinates, projection, source provenance and current evidence. No real WebXR session or headset execution has been verified.

For the new scene: orbit the double cone, select a coefficient point, vary the radius or toggle the whole lattice. **Inhabit** enters the cloud; drag to look, W/A/S/D and Q/E move in ordinary Euclidean coefficient space. **Return to overview** restores the previous camera. Projection is off by default. The optional lower-half coloring is explicitly our extension. Invalid coefficient entries preserve the current state. Reload starts the coefficient scene at its default example. The Farey page retains its per-tab saved rational state.

Pair two interior points with **Shift-click** or **Pair entered point** to reveal their coefficient plane, its boundary endpoints and highlighted lattice members. Try `1,0,1` then `1,1,1`: the plane is `2a − 2c = 0`, endpoints `−1` and `1`. See [the exact construction and source limits](../PAIR_PLANE.md).

The following earlier walkthroughs apply to **farey.html**. Their historical simulator/Safari evidence does not establish testing of the new coefficient scene.

## Farey lattice — browser and WebXR companion

[Release-candidate readiness](../READER_READINESS.md) — browser 0.7.4. [Precision notice](../PRECISION_NOTICE.md). [Safari and compact-view audit](../MOBILE_SAFARI.md). [Offline package audit](../OFFLINE_PACKAGE.md). [Native integration check](../INTEGRATION_08.md). [Crowded projected selection](../PROJECTED_SELECTION.md). [Source-fidelity audit](../SOURCE_FIDELITY.md). [Optional boundary-to-lattice construction](../CONSTRUCTION.md). [Previous release audit](../DEMO_READINESS.md).

An original Three.js implementation of the same integer lattice and L/R state as the native visionOS app. Inspired by **[Katherine Stange](https://katestange.net/talks/math-exploration/)** and her [visualization catalog](https://www.katestange.net/code/), with underlying [Caroline Series L/R geodesic coding (1985)](https://doi.org/10.1112/jlms/s2-31.1.69).

## Run locally

```sh
cd Farey/WebXR
npm ci --ignore-scripts
npm test
npm start
```

Open **http://127.0.0.1:8080**. The server binds only to this Mac and disables development caching so edits cannot mix stale styles with new code. Node.js, npm and Python 3 are required. Three.js is pinned to 0.180.0 with an integrity hash in the lockfile. No network dependency is used at runtime after installation.

Try **3/5 example**, then **L**: the selected fraction becomes **5/8**, between **3/5** and **2/3**. **Undo** returns to **3/5**, and **Reset** returns to **1/1**. **Learn a move** provides a guided path starting at **1/2**. The packaged ZIP needs only Python 3 and a WebGL2 browser to view; Node/npm are for rebuilding. A localhost address works only on the computer serving it, not as a public link for other readers.

Drag to orbit, scroll to zoom, right-drag to pan. Hover a sphere to read its coordinates and click to select its rational direction. L/R, Undo, Reset, the 3/5 example and fraction entry share one exact state. Grid size is capped at 14 (224 nonzero points). On narrow screens the lattice occupies a separate visible area above the controls, and the lesson keeps only its relevant actions visible. Rendering is event-driven on desktop; XR uses the headset animation loop. Reset restores the initial geometry and view.

Phones and short windows start with the finite lattice centered more closely. Axis letters retain a readable screen size; their positions still mark the same axes. Short, wide windows place the scene beside the controls. Fraction/grid inputs use 16px text on touch devices. Selection never moves the camera; only launch, Reset, Front view and explicit camera gestures change the framing. Resizing preserves the user's orbit while fitting the available aspect ratio.

The **Point (q,p)** disclosure preserves and explains the selected integer point. Clicking `6/10` shows `(10,6) = 2 × (5,3)` and the reduced rational `3/5`, with the exact word `RLR`. The white inspected sphere differs from the orange primitive sphere, while both lie in the same upright green plane. That finite plane now extends to the grid boundary. Point identity survives grid changes and reload, including when the point is outside the visible grid; L/R, Undo, Reset and a new lesson clear it. Axis points 0 and ∞ remain non-selectable boundaries. The native app also shows how the same reduced rational determines its disk boundary point and green geodesic; the browser companion currently renders the lattice.

The **Continued fraction** disclosure distinguishes convergents from other visited mediants. Gold rings mark truncations of the chosen expansion; gray rings mark intermediate L/R mediants. For `3/5`, `2/3` is intermediate in canonical `[0;1,1,2]` and a convergent in the equivalent `[0;1,1,1,1]`. The toggle only changes this classification. It preserves the rational, point inspection and L/R word. Canonical form is restored by Reset or reload; reload still preserves the mathematical selection. `0/1` can appear as a boundary convergent without becoming selectable. Definitions follow [DLMF §1.12(ii)](https://dlmf.nist.gov/1.12.ii); the native app shows the same classifications in its lattice and disk.

Click an approximant row to **spotlight** it with double white rings. The target rational, inspected lattice point and lesson prediction stay fixed. A persistent readout names all three roles, including when the controls scroll on a phone. A target change clears the spotlight; a convention change keeps it only while that row remains. An out-of-grid point retains its exact coordinates and receives an explicit message. Clear removes only the spotlight. Reset and reload clear this temporary focus; reload still restores the target and inspected point. Row activation retains keyboard focus, and the camera never moves automatically.

## Immersive VR implementation

The **Enter VR** button becomes available only when `isSessionSupported('immersive-vr')` succeeds. It requests an immersive VR session with a local-floor reference space. The lattice is stationary in a black environment. The implemented controller/select rays target points and use the in-world L, R, Undo, Reset, 3/5 and Exit controls. The session-end handler restores the desktop controls; this lifecycle still needs an actual XR session test. The in-world panel credits Stange and Series; full source links remain in the desktop panel.

WebXR needs a compatible headset browser and a secure context. A headset cannot access the Mac's loopback address directly. Use an already-trusted HTTPS development host or an independently authorized deployment for headset testing. This work does not provision a certificate, change network permissions, or publish a site.

**Earlier environment checks:** Safari 27.0.1 completed the worked 1/2 → L → 2/3 → R → 3/5 path with a clean page console. Portrait Chromium at 390 × 844 shows a fitted lattice and legible controls. Chromium desktop rendering and real mouse orbit, L/R/Undo/Reset, rational selection (including 6/10 → 3/5), maximum grid, 24-step limit and recovery. The then-current 22 automated tests covered mathematics, unsupported/error paths, transient input pose updates, desktop camera restoration, and separation of taps from multi-pointer gestures. This Mac's Chromium reports `immersive-vr` unsupported. A separate visionOS 27.2 simulator Safari reported support and received an actual click requesting immersive VR. Safari displayed a runtime prompt to allow tracking the device’s position and head movements. That permission was left ungranted and the isolated Safari process was closed. No XR session or frame was observed. A mocked pending-request/denial test verified duplicate-entry prevention, continued desktop interaction, and recovery; it is not XR runtime evidence. **Not verified:** Quest/Meta Browser, a physical Vision Pro browser, controller/hand interaction in an actual XR session, device frame rate or comfort. The native simulator is separate evidence, not a WebXR headset test.

Browser 0.7.4 has 39 passing unit tests. Its conditional [precision notice](../PRECISION_NOTICE.md) explains confirmed display collisions without changing the exact state or geometry. The [release-candidate audit](../READER_READINESS.md) records the current package, first-time sequence and recovery checks. The [mathematical consistency audit](../MATHEMATICAL_AUDIT.md) compares exact state with the native core and an independent integer oracle. Earlier Safari observations above are not claims of a fresh Safari or immersive XR run.

## Mathematical correspondence and provenance

Each point is (q,p), uniformly scaled and rigidly rotated into the scene. The green plane is perpendicular to the lattice and passes through its origin and the selected direction. Cyan and purple vectors are Farey neighbors; their orange sum is the mediant. Sphere sizes, colors, finite plane height and placement are presentation choices. The app word represents M(1); appending R puts the same rational in M(∞), matching the endpoint convention seen in Stange's talk viewer.

No Stange JavaScript, media or meshes are bundled. This is an independent implementation of the lattice construction, not her separate hyperboloid visualization or a reproduction of an infinite fractal. Application code is GPL-3.0-or-later under the parent repository license. Three.js is a separate MIT-licensed dependency; its license is installed at `node_modules/three/LICENSE`.

`npm run build` prepares a static artifact with a local Python server, launch instructions, exact authored sources, build inputs and license notices. It runs without internet once installed, with localhost requests still available. A fully offline browser setting also blocks localhost reloads; there is no service worker/cache installation. Do not open `index.html` as a file URL. See the [package audit](../OFFLINE_PACKAGE.md) and [deployment plan](DEPLOYMENT_PLAN.md); no public deployment has been made.

`npm run smoke:package` verifies the complete hash manifest and resolves the local runtime module graph. With Playwright CLI and its browser already installed, `npm run smoke:offline` builds the artifact, serves it on an automatically chosen loopback port, opens isolated headless profiles and checks offline interaction, state recovery, mobile layout and unsupported graphics/XR. It closes only its own browser/server. It never installs tools, requests an XR session or changes permissions. Results and screenshots go to `output/playwright/offline-package/`. Use `python3 smoke-offline.py --help` for an existing artifact, root URL or explicit CLI path.

## Worked path

Choose **Learn a move** to begin at 1/2. Predict the result of L, apply the actual operation, and compare the selected 2/3 point with the vector equation. Continue with R to reach 3/5. The explanation is computed from the same exact state as the lattice. Undo or another manual selection closes a stale lesson; Reset restores the ordinary starting state. This is a teaching interaction, not a claim of measured educational efficacy.

## Browser regression walkthrough

With the local server running, the optional Playwright CLI walkthrough checks keyboard-only lesson completion, focus retention, phone layout, exact reset/undo state, invalid input, reducible fractions and the 24-move limit:

```sh
playwright-cli open http://127.0.0.1:8080/farey.html
playwright-cli run-code "$(cat browser-checks.js)"
```

This uses a separately installed Playwright CLI; it is not a runtime dependency. The same walkthrough passed against the built artifact. Actual iPhone 17e **simulator** Safari also completed the lesson, Undo and Reset. See [mobile evidence](../evidence/webxr/mobile-safari-validation.json). Physical iPhone, headset input and immersive WebXR remain separate validation steps.

## Gesture and accessibility validation

One-finger drags rotate. Two-finger gestures pan and pinch to zoom; only a single primary tap selects a sphere. Once the scene has keyboard focus, arrow keys pan, Shift + arrows rotate, plus/minus zoom, and Home restores the front view. The fraction field remains an alternative to pointing at a small sphere.

The canvas exposes a named image with the selected rational, its vector, and its neighbors as an accessible description. L/R buttons describe which endpoint changes. Automated checks inspect this semantic structure and keyboard focus; no VoiceOver or other screen-reader speech session has been run. Chromium protocol-generated touch tests are labeled synthetic and are separate from the recorded iOS simulator Safari checks.

## Graphics and reload recovery

If WebGL is lost, a visible notice replaces the invalid canvas while the exact mathematics controls remain usable. When the browser restores the context, the scene repaints automatically. The Reload page fallback preserves the L/R word, inspected point and grid through validated per-tab session storage. Reload starts with the default camera and a closed lesson panel; Reset replaces the saved selection with the initial state. If storage is unavailable, the notice says the current selection may not survive reload.

The repeatable recovery check uses the browser’s actual `WEBGL_lose_context` extension, not hand-dispatched context events:

```sh
playwright-cli open http://127.0.0.1:8080/farey.html
playwright-cli run-code --filename recovery-checks.js
```

Source and static artifacts passed three loss/restoration cycles, with matching restored 3D-region pixels, usable L/R during loss, and exact selection/grid recovery through the reload button. This is a controlled browser-level loss, not a physical GPU crash or an XR-session recovery test. Initial context-creation failure was tested separately by explicitly mocking unavailable WebGL; reference links remain available and unusable controls are disabled.
