# Browser 0.13.1 dense-hover verification

**Current status (2026-10-23):** this page is historical 0.13.1 evidence. Browser 0.14.0 adds exact polynomial hover and clears it across XR entry and exit, tested with a mocked session only; its foreground XR rendering is pending. Native 0.10.0 (13) is installed and rendered in the main simulator; the physical headset still has 0.9.0 (12), installed but not functionally tested.

October 22, 2026. Dense crops (at least 50,000 points) now query hover in a local module worker. It runs the unchanged `nearestToRayPacked` over the same Float32 coordinates and thresholds. The trigger still recomputes synchronously on its current ray. Small crops and worker failure retain the synchronous path. No points are sampled, duplicated or moved.

The protocol permits one physically outstanding query per hand. Rebuild, context loss and session end invalidate results; obsolete replies drain without creating an unbounded queue. One copied lattice generation is transferred to the worker, leaving the renderer's array intact. At radius 96 that copy occupies 22,229,808 bytes, retained for reuse while the worker is idle. Main-realm Chrome heap excludes this worker data, GPU and process memory. Debug distinguishes these measurements.

## Matched desktop measurement

The committed 0.13.0 runtime and final worker candidate used the same 120-frame pose sequence, one mock controller, the same camera and exact point counts in isolated headless Chrome on this M4 Max. `WebXR/hover-performance-checks.js` specifies the pose and records timing. These are CPU/browser scheduling measurements with mocked XR input, **no XRSession**, and no headset or GPU frame-rate claim.

| R96, 1,852,484 points | Previous runtime | Worker runtime |
| --- | ---: | ---: |
| Moving 2 mrad/frame: `updateAims` p95 | 27.9 ms | 0.1 ms |
| Moving: total main-thread aim work / 120 frames | 271.4 ms | 13.2 ms |
| Moving: frames with aim work above 4 ms | 9 | 1 |
| Moving: frame interval p95 | 28.2 ms | 16.8 ms |
| Moving: fresh-preview frames | 9 | 0 |
| Held: `updateAims` p95 | 32.1 ms | 0.1 ms |
| Held: fresh-preview frames | 120 | 117 |

The worker still spent 25–28 ms per dense scan. One-time transfer setup cost 5.3–7.0 ms in these samples; the moving run's maximum main-thread aim work was 7.6 ms. At R6 (480 points), both paths remained at 0.3 ms p95 while moving, with the worker unused. [Before](evidence/browser-0.13.1/before.json) and [after](evidence/browser-0.13.1/after.json) retain all measured values.

To repeat against either local runtime, open its coefficient page with a separate Playwright CLI session, then run `playwright-cli run-code --filename hover-performance-checks.js` from `WebXR/` (or the extracted package's `source/`). The harness drives identical held and rotating rays at R6 and R96, reports actual counts, and never requests XR. Close that test session afterward. Timing varies with browser scheduling, garbage collection and other Mac work; heap samples do not establish a memory improvement.

**Tradeoff:** a ray moving faster than the 1 mrad staleness threshold can keep the ring hidden until it settles. This measured run showed no fresh moving previews in the worker case. The worker removes repeated dense scans from the UI thread; it does not solve continuous-motion preview latency, dense directional ambiguity, or the trigger's remaining synchronous scan cost.

## Correctness and integration evidence

All 79 unit/package tests passed in an isolated copy. An independent actual-browser run loaded the real module worker: 40/40 R48 rays and 40/40 R96 rays matched the original synchronous point index. Both hands, current-ray trigger selection, reset/session-end with queries in flight, transferred byte count and a real worker-load failure fallback passed. [Worker results](evidence/browser-0.13.1/hover-worker-checks.json) and [aim regression](evidence/browser-0.13.1/xr-aim-checks.json) explicitly label their XR inputs as mocked.

Review reproduced and fixed a close-range starvation bug: at 0.2 m, a 0.5 mm translation hid the preview but never refreshed it because refresh and display used different distance thresholds. Both now use the same predicate. The regression fails on the pre-fix runtime and recovers on the fixed runtime, matching the synchronous oracle. Below-threshold and distant controls retain their previews without unnecessary queries. A below-threshold preview can still differ from a fresh pick in this dense cloud; the trigger recomputes rather than selecting a cached preview.

The local 0.13.1 package was promoted and only the known background mathematics tab was refreshed. Its `(1,0,−1)`, R6 and Origin state were restored; the user's active tab index remained 1. This is a background DOM/version readback, not a screenshot of the user's foreground. [Promotion receipt](evidence/browser-0.13.1/promotion.json).

A bounded test before the close-range correction on the already-installed IWE entered and ended one real session, but received **no XRFrame within three seconds while the tab was hidden**. It restored R6, the selected normal, Origin and manual emulator mode, with no active session. [Exact result](evidence/browser-0.13.1/background-emulator.json). Foreground 0.13.1 stereo, controller-worker integration and repeated entry remain unverified. The actual 0.13.0 emulator evidence below remains historical evidence for that version.

## Final local package

`WebXR/output/Farey-WebXR-0.13.1.zip` is 612763 bytes, SHA-256 `59f0807bde48ccb504bba09c0594e04e82a4077e6e8d945f8fcce7202889dcd8`. Its 81-file manifest SHA-256 is `50f5c05687f3340eb86aab01cb0746cda24fd085d0e3cefc6135176714c3c73c`. The exact ZIP was extracted outside the checkout and both pages passed local/offline/mobile/state/failure checks with no external runtime requests or page errors. No private-path or credential markers were found. [Package receipt](evidence/browser-0.13.1/package.json). Launch with `python3 serve.py --port 8778` in the extracted folder, then open `http://127.0.0.1:8778/`. This is a local package; it has not been deployed or uploaded.

Next: when the comparison tab is foreground and available for testing, repeat the actual IWE two-hand/exit/re-entry sequence at R48, then investigate continuous-motion latency with the same selection oracle. Physical headset input, GPU performance and comfort remain separate. The freshly signed native 0.9.0 (12) candidate is ready; the paired physical Vision Pro's tunnel was still unavailable at this checkpoint, so no installation or hardware test has occurred.

---

# Browser 0.13.0 spatial interaction verification

October 22, 2026. The current double-cone browser adds app-owned controller aim rays, depth-tested cyan hover rings and a compact in-world readout: Left aim, Right aim, Selected, and the current plane. Hover does not change the mathematical selection. Each trigger recomputes on that controller's current ray; a ray movement can change the result from the last preview. The viewer-facing ring is an approximate angular-scale cue, not a mathematical locus.

Verified in the user's main Chrome using official IWE 2.0.0 and actual emulated XRSession/XRFrame objects:

- Two stereo views, 0.063 m apart, with distinct left/right controller poses.
- Left aim `(1,0,1)`, Δ=−4, and Right aim `(1,0,−1)`, Δ=4, appeared simultaneously. Real emulator trigger press/release events selected the corresponding point for each hand; the exterior selection restored plane `2a−2c=0`.
- Right aim changed to Exit, the controller event ended the actual session.
- Re-entry from desktop Origin rendered upper/lower apex views from programmed emulator poses. Exit restored the desktop Origin position/orientation, and the emulator returned to manual control with no active session. Final Overview handback was not verified in this run; desktop Origin restoration was verified.

[Structured 0.13 evidence](evidence/browser-0.13/checks.json) separates these real emulator observations from the portable `WebXR/xr-aim-checks.js` regression, which explicitly mocks XR inputs and creates no XRSession. The initial 0.13 request observer missed entry; it then attached to IWE's actual active session. Early test-console errors are not presented as app errors or as a clean main-Chrome console. A hidden DOM plane label can retain old text; current in-world Plane text is recorded separately.

The mocked regression also checks stale-button clearing, R=96→6 cache invalidation, two-hand labels/selection, and unchanged selection during hover. All 68 unit/package tests pass. No minimap, palm interface, automatic camera motion, mathematical color change or native feature change was added.

**Measured limit:** R=96 contains 1,852,484 distinct points. Claude measured roughly 25–26 ms CPU per linear hover scan in its isolated browser test; hover backs off about 180–200 ms, and moving rays hide stale previews. Those scans can still hitch rendering. This is not GPU timing or measured headset frame rate. Dense directional ambiguity, motion below the staleness threshold, real tracking jitter and physical haptics remain unresolved. The next supported improvement is to move/accelerate exact hover queries without changing selection semantics or silently sampling.

Guidance consulted by Claude: [Apple HIG Eyes](https://developer.apple.com/design/human-interface-guidelines/eyes) and [Meta ray-casting best practices](https://developers.meta.com/vr/design/raycasting_bp/). The implementation review checked feedback against actual selection identity, lifecycle and cache ownership. Physical headset comfort and input remain untested.

Native 0.9.0 (12), `com.alok.FareyVision`, was separately rebuilt from current native source, passed `codesign --verify --deep --strict`, and passed 33 core tests using existing signing only. The paired physical Vision Pro remains unavailable, so installation, launch and physical functionality have not occurred. Native does not yet have the browser's signed dense cloud/Origin/aiming parity. No new automation was created.

---

# Browser 0.12.1 camera-restoration verification

October 22, 2026. The live localhost double-cone app was exercised in **actual `immersive-vr` sessions provided by official Immersive Web Emulator 2.0.0**, simulating Quest 3 in the user's main Chrome. This is browser simulation, not physical headset validation. The native Meta OpenXR Simulator is a separate runtime and was not used as proof of Chrome WebXR execution.

Two reproduced camera defects are fixed: Three.js XR changes the desktop camera's field of view and zoom; those are now saved and restored. Disabled OrbitControls still enforces its orbit constraints if `update()` is called; restoration now skips that call for a disabled first-person controller. Before the second fix, a real Origin reproduction moved the camera one metre and nearly π radians. Afterward the same browser test using real OrbitControls has zero position and orientation drift.

| Check | Observed result |
| --- | --- |
| Promoted browser 0.12.1 | Main Chrome localhost tab reloaded; live and source XR helper SHA-256 `29aeb1cc36611aa23fb55e63774535a7293a9e7ce106b93eed00067e05685838` |
| Stereo session | Real XRFrame contains `left` and `right` XRViews, eye separation 0.063 m; stereo mirror visibly renders both views |
| Head translation, 0.12.0 before camera fixes | Emulator's normal headset-X control moved measured head from x=0 to 0.25 m; eye and controller-ray poses moved correspondingly |
| Controller selection, 0.12.0 before camera fixes | Normal emulator right trigger selected exterior `(1,0,-1)`, giving plane `2a−2c=0`, endpoints −1 and +1; controller-driven in-world Exit ended the session |
| Apex, 0.12.1 | Programmed emulator head at world `(0,1.4,−3.1)` produced real frames at that position; ±90° X orientations looked into upper and lower nappes |
| Lifecycle, 0.12.1 | Three entries and three end events; Origin remained selected after exit, with eye label `(0,0,0)` and upward orientation; Return to overview restored a usable oblique scene |
| Mathematical state | Restored user's `(1,0,−1)` selection and exact cutting plane after testing; reference viewer left intact beside the app |
| Regression | 68 unit/package tests; actual-browser coefficient, pair-plane, Debug and context-loss walkthroughs passed; real OrbitControls reproduction passed |

[Structured frame and regression evidence](evidence/browser-0.12.1/checks.json) retains exact measured positions and projection matrices. Raw screenshots remain local, showing the stereo overview, upper/lower apex views and restored desktop Origin. No private recordings or browser context are included in this package.

A temporary DevTools observer requested frames from the actual returned session; it did not fabricate XRViews or replace rendering. Apex poses used the installed runtime's programmatic pose mode, then restored manual mode. No remote-agent connection, OS tracking grant or security setting was added. Initial direct pose assignments in manual mode were overwritten by the emulator rig; those attempts are excluded from apex evidence. Early console probes also produced test errors, so this document does not claim the extension-filled main Chrome console was clean. Isolated application regressions separately check page errors.

At the apex, only the cyclopean head position is at the origin: stereo eyes remain separated. This is ambient Euclidean navigation around coefficient space, not intrinsic hyperbolic motion. The zero polynomial has no unique root/projective point. Lower-category coloring remains a display choice; opposite nonzero forms share roots.

Remaining: physical Quest/Vision Pro tracking, controller/hand usability, GPU frame rate and comfort; current coefficient-page Safari/touch and assistive speech; dense-cloud ray ambiguity and opacity-ordering audit; native parity with browser Origin/dense signed cloud/plane controls. The physical Vision Pro was unavailable on the latest supported device query; installation has not occurred. Public hosting and private uploads remain separate pending actions.

## Local package

`WebXR/output/Farey-WebXR-0.12.1.zip` is 588,518 bytes; SHA-256 `0ab1c4112b7f7618618ac22f5943aa3c56f6aeb618928727f9c9ae2e8126a80f`. Its 73-file manifest SHA-256 is `dcbe1a656859efbc8b6e8a155375ea0fa0f788e63aafb8f19931a54460a689fe`. The ZIP was unpacked outside the checkout and checked using its own local server. Both pages passed clean-profile offline/mobile/state/failure checks with no external runtime requests or page errors. That isolated package smoke does not request XR; actual IWE evidence above comes from the promoted identical runtime code in main Chrome.

To reproduce, unpack the ZIP, run `python3 serve.py --port 8778` in its folder and open `http://127.0.0.1:8778/`. On a browser with an already-authorized IWE installation, enable emulation for this origin and reload. Click Origin, then Enter VR. Use normal emulator headset/controller controls and the in-world Exit; repeat entry and check the restored desktop eye label and view. The emulator stereo-rendering option requires reload. Do not grant physical tracking or change browser security to reproduce the local desktop checks.

## Current 0.13.0 package

`WebXR/output/Farey-WebXR-0.13.0.zip` is 595,314 bytes; SHA-256 `9669e53a13ae7de0b85ecd1cb58e4eaaa10452fecc567c930f654e7699a923f3`. Its 74-file manifest SHA-256 is `4316ab7e1d2711018f8ee54876fd8008646a3005f315a7311bdb2876f07e07a8`. Independent extracted-package smoke passed both pages with no external runtime requests or page errors, including portrait/landscape and loaded-page offline behavior. The package still uses the documented `python3 serve.py --port 8778` local launch. This is a local artifact, not a public deployment.
