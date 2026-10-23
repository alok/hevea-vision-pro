# Native 0.15.0 (19): the Origin drag by real input

*This topmost section is the current status. The sections below are a dated chronology kept as evidence: their status lines, failures and gaps describe their own versions, not the current app.*

**Status (2026-10-23):** the eye-at-origin Möbius drag now works under real public input in the visionOS Simulator. The app version is 0.15.0 (19); its full suite is the release gate, and the main simulator keeps 0.14.0 (18) until that passes and it is promoted.

**Cause of the earlier failures (measured; consistent with Apple's documentation):** at Origin the object hung under a one-time head anchor. Apple's guide [Placing entities using head and device transform](https://developer.apple.com/documentation/visionos/placing-entities-using-head-and-device-transform) says an app cannot read a head anchor's transform: it returns the identity. The measured directions fit that: the app read gesture points as if the object sat at the world origin rather than at the rendered head (the offset was not measured directly), every direction left the cone's interior, and g never moved. Converting the gesture location directly to the object (`value.convert(…, to: root)`) gave exactly the same numbers, and no indirect-pinch event carried a selection ray (63 events, 0 rays), so neither offered an eye position.

**Fix:** world tracking's device anchor, which the same guide documents needs no authorization in an immersive space. When Origin or Inhabit is chosen, a short `ARKitSession` with a `WorldTrackingProvider` runs only if it is supported and requires no authorization, waits up to 3 s for a tracked device anchor, accepts only a finite rigid transform, and is stopped on every path. The object is placed explicitly at that pose under a world-stationary entity, so its frame is known to the app; the nappe flip keeps the pose. Without a pose, the head anchor still renders the placement, Origin drags report "no device pose" and move nothing, and the panel says so. The pose is the device's, not the head center; the text says device.

**Real-input acceptance** (`testDeviceHubOriginDrag`, opt-in; disposable simulator C447C820; source `65d5012`): passed 1/1. The app measured a device pose before READY ("placed from the device pose"). A public Device Hub Select-mode drag on empty sky at Origin facing the upper nappe moved g to [1.00197, 0.04440; 0.02468, 0.99913] (det 1); after the nappe flip a second drag moved it to [1.00282, 0.00320; 0.00167, 0.99719]; the selection (1,0,1), the pair (1,1,1) and the base plane 2a −2c = 0 were kept throughout; Reset, Exit and re-entry returned to the defaults in Overview. A silent recording of both drags is complete. Evidence: `/Users/alokbeniwal/Documents/Codex/2026-10-21/task-7/native-origin-devicepose-0140/` (captures, recording, input log, operator receipt), `/Users/alokbeniwal/Documents/Codex/2026-10-21/task-7/native-devicehub-origin-devicepose-snapshot.json` (all 59 inputs match `65d5012`), focused tests `/Users/alokbeniwal/Documents/Codex/2026-10-21/task-7/native-devicepose-focus-0140/` (47 passed, 1 opt-in skip).

**Failed runs kept as failed:** `testDeviceHubOriginDrag` on 11d58f1, b5d4b44, 87d4f0f, 1b616fb and 4acea09 all failed (g unchanged) and are preserved with their diagnostics; their recordings are labelled failed/partial.

**Still not verified:** physical gaze, pinch and drag on a headset (simulator host input only); how far the device pose sits from the head center on real hardware; Inhabit under real input; Roots-window pointer hover; 3D spatial hover.

# Native 0.14.0 (18): Pair next and Roots-window picking

**Status (2026-10-23):** installed in the main simulator (D2ECE520), replacing 0.13.0 (17); the installed bundle is file-for-file the focused final run's build of `b3bd1fc`, and the screen was captured after launch and inspected (`task-7/main-simulator-0140b18/`). Full suite on `60dbbdd` plus the version: 61 passed, 2 skipped (opt-in probes), 0 failed. The final source differs from that snapshot only in the Roots close (cancels Pair next) and its test; the focused run on it passed 41/41 (all unit tests, the Pair next Roots test, the coefficient-space lifecycle).

**Implemented and tested:**

- **Pair next / Cancel:** one control arms a direct pick, from the Roots window or the immersive scene, to pair with the selection; a one-line state shows only while armed. Refusals (same direction including multiples and sign partners, exterior, outside the ball, filtered out) change nothing and stay armed; success disarms; Cancel, closing Roots, Reset and leaving the space disarm.
- **Roots window:** one deterministic picker (the largest of coincident multiples) serves tap and pointer hover; the hover ring and its exact base-polynomial label follow the pointer and cannot go stale.
- **3D pairing by a public Device Hub Select click** (`testDeviceHubSpherePairing`, opt-in; disposable simulator; XCUITest only armed Pair next and waited): from (1,−1,2) a click on the (3,0,3) sphere paired it, plane 2a −2b −2c = 0, endpoints 1 ± √2, 18 members, primary kept, disarmed; with (3,0,3) selected the same click was refused as the same direction, still armed. Evidence `/Users/alokbeniwal/Documents/Codex/2026-10-21/task-7/native-devicehub-pair-0140/`. Simulator host clicks, not physical gaze/pinch.
- **Real input (XCUITest, Roots window):** coordinate taps through the measured visionOS 27.2 window mapping (normalized offsets centred, y up; from the separately owned Lean app's probes) picked (1,0,1), refused as the same direction, then (1,1,1), paired: plane 2a −2c = 0, disarmed. A silent 15.9 s recording of that sequence is local at `/Users/alokbeniwal/Documents/Codex/2026-10-21/task-7/native-pairing-0140-video/recording.mp4`.

**Not verified:**

- Roots-window pointer hover (no visionOS XCUITest hover route; a Device Hub pointer check is pending). Predicted, not observed: with a multiple such as (2,0,2) selected, hovering its root may draw the hover and selection labels at the same place.
- **The Origin drag did not move g under a public Device Hub drag (FAILED, cause unresolved).** `testDeviceHubOriginDrag` (opt-in) set (1,0,1) paired with (1,1,1), Snap off, Origin facing the upper nappe, and waited 90 s; the coordinator's Select-mode drag ran inside that window on the same disposable simulator (02D5C89D), from clear sky inside the upper nappe (64 drag events over 1.28 s after a 0.35 s hold), yet g stayed the identity and the scene did not change (`/tmp/farey-native-devicehub-origin-20261023T104240Z`; operator record and ready screenshot at `/Users/alokbeniwal/Documents/Codex/2026-10-21/task-7/native-devicehub-origin-0140/`). Phase 2 was not reached. It is not known whether any gesture callback reached the app; the opt-in `--input-diagnostics` readout (callback counts, last entity, direction and outcome) now exists so a rerun can tell. The earlier offscreen raycast showed the sky shell is hittable from inside a RealityKit scene, not that the system's gesture targeting reaches it.
- 3D spatial hover (a grouped hover-effect label prototype is next), physical gaze, pinch and drag.

# Native 0.13.0 (17): the eye-at-origin drag

**Status (2026-10-23):** installed in the main simulator (D2ECE520), replacing 0.12.0 (16); the installed bundle is file-for-file the tested build of `bd01480`, and the screen was captured after launch and inspected (`task-7/main-simulator-0130b17/`). Full suite on exactly that source: 58 passed, 2 skipped (the opt-in probes), 0 failed (simulator 64C1E8CA). The opt-in spatial tap probe itself **failed** (below); its skip in the suite is not a pass.

**Implemented and tested (model, renderer and real-scene raycast; not spatial input):**

- At Origin, a drag's display direction from the coefficient origin names a root through its Klein point; successive directions apply the Roots window's transvection, so the fixture (0,2,0) → (2,3,1) gives g = [[3,1],[1,2]]/√5 and the dragged star is then drawn along (2,3,1). Off the cone's interior nothing moves and nothing is clamped. In Overview a drag changes nothing. The direction is read in the object's frame, which g does not move.
- The drag's state is tagged with its placement: a nappe flip, a new Origin, Reset or leaving the space starts afresh instead of jumping; a cancelled gesture never Snaps; a completed one Snaps as a Roots-window drag does.
- A sky shell (one static mesh, enabled only at Origin) is scaled so every facet plane (inradius 0.983 of its vertex radius) lies beyond every star's collision sphere, checked at the identity, the fixture g and diag(2, ½). In a real RealityKit scene a ray from the origin through the clearest gap hits the sky from inside, and a ray at (1,−4,3), 2.51 m out under the fixture g, hits that star.
- Stars declare the accessibility activate action that the immersive view's handler selects with.

**Not verified:**

- **No spatial route reached an entity.** XCUITest's element tap on a star (`--spatial-probe`) failed three times with "Received invalid activation point transform (nil) from Accessibility"; its app-anchored route is skipped because the element reports a placeholder frame (0, 0, 50, 50). An earlier probe run that reported "passed" was an expected failure that ended before that route and proves nothing.
- No route drives a RealityKit drag gesture in the simulator, so the Origin drag has not been performed by input; physical gaze, pinch and drag are untested. The headset still has 0.9.0 (12), installed but not functionally tested.
- Still missing natively: polynomial hover (a shader hover-effect prototype is the next candidate, see the feasibility notes), spatial pairing and free view rotation.

**Test history of this increment, as run:** a review run failed 35/37 (a too-strict ray-clearance fixture, and a UI run whose typed entries never landed, cause not established); the typing helper now accepts an entry only when the field holds the text. Its first version gated on `isHittable`, which reads false for these fields, and failed three UI tests; that gate was removed and they passed 3/3.

**Browser alongside (0.15.8, actual IWE):** real XRFrames, both controllers matched a ray oracle, plane, re-entry and Origin; the desktop mirror's 3.42× stretch is fixed (1.0000037, projections unchanged). Evidence: `/Users/alokbeniwal/Documents/Codex/2026-10-21/task-7/browser-xr-current-0157-final/`, `/Users/alokbeniwal/Documents/Codex/2026-10-21/task-7/browser-xr-mirror-diagnosis/`.

# Native 0.12.0 (16): the Möbius view

**Status (2026-10-23):** installed in the main simulator (D2ECE520), replacing 0.11.0 (15). The installed bundle is file-for-file the tested build of `5833c7c`; the screen was captured after launch and inspected (`task-7/main-simulator-0120b16/`). A silent 64-second recording of the passing Möbius sequence (pair, Roots swipe, views, projection, both Origin directions, re-entry, Identity, T) is at `task-7/native-demo-0120b16-corrected/native-mobius-walkthrough.mp4`; an earlier partial recording (`native-demo-0120b16-final`) is from the failed `-0.000` run and is not evidence. Nothing here is a physical-headset claim; the headset still has 0.9.0 (12), installed but not functionally tested.

- **Full suite:** 51 passed, 2 skipped (the opt-in probes), 0 failed, on `2ec43e8` (version 0.12.0 (16)), simulator 386D2449. This predates the label correction below.
- **Final source `5833c7c`:** a focused run passed 34/34: every app unit test, the Möbius UI sequence, and the coefficient, plane and Origin UI tests (simulator 1A465576). FareyCore passes 60/60. Every one of the 49 tracked build inputs matches `5833c7c`; the app reports 0.12.0 (16), and its debug dylib's SHA-256 is `54956c00…`.
- **A run that failed before that:** the first focused run on the label correction printed the root of x² + 1 as `-0.000` (negative zero, −0/2). Labels now print values that round to zero as `0.000`, with regressions.

**Implemented and tested**

- **One g ∈ SL₂(ℝ)**, from a Roots window beside the controls (placed there because, overlapping, it hid Reset and Exit) with its own Close. Stars sit at g·root, and a drag applies the browser's transvection step.
- **The scene follows g:** dot centers at J·ρ(g)·(a,b,c), projection images, selection and pair markers, and the plane's patch (normal ρ(g)n) and endpoint directions (endpoints g·t). Membership stays exact on the base triples. Origin glyphs use the base Δ and the moved height, and a change of g never moves the viewer.
- **Symmetry controls:** T⁻¹, S, T, Identity and Snap (her polar criterion). An integral result is absorbed exactly into the selection and pair, or refused with all state kept. Identity does not undo absorption, and Reset clears g, Snap and the pair.
- **Readouts:** under a non-identity g, the panel says "Base plane …" and "base upper root …" and adds where they are shown, for example `shown under g ≈ -1.361 and 1.249`, with ∞ for a point at infinity. The g readout's accessibility value carries g to full precision.
- **The UI sequence, on a fixed path:** select (1,0,1), pair (1,1,1) at R6, then swipe the Roots window. That gives g = [1.201700999401844, 0.37604373874125496; 0.32849938248608124, 0.9349498223963413], and the selection, pair and exact plane stay unchanged. Captures: Overview, the other side, projection, Origin facing each nappe. Closing and reopening Roots, and leaving and re-entering the space, keep g and the pair, and re-entry is in Overview. Identity keeps the pair. T absorbs: (1,0,1) → (1,−2,2) and (1,1,1) → (1,−1,1). Reset restores (1,−1,2).
- **Renderer tests** use the exact g = [[3,1],[1,2]]/√5. (1,0,1) moves to display (2,3,1). The plane normal (1,0,−1) goes to (3/5, 2/5, −8/5), its endpoints −1 and 1 to −2 and 4/3, and the root i to 1 + i. The inverse restores every position.

**Matched browser state.** Browser captures with the same g and pair are at `/Users/alokbeniwal/Documents/Codex/2026-10-21/task-7/browser-native-mobius-parity-0154/`. They set that g through a test-only setter, so they are matched state, not the same physical gesture or the same camera. They show the root at 0.760 + 1.018i and endpoints ≈ −1.361 and 1.249, the native values for this g.

**Input routes, kept separate**

- **Works:** XCUITest `swipeRight` on the Roots window (handled by its own DragGesture) changes g.
- **Did not change g:** coordinate press-drags; the window's accessibility frame is reported at (0, 0, 560, 560).
- **Failed:** an app-coordinate drag, with "Received invalid scene ID (nil) from Accessibility". This diagnostic is opt-in (`--spatial-probe`), not part of the default suite.
- **Unverified:** tapping a root in the Roots window, spatial point selection, and gaze/pinch on entities.

**Not implemented natively:** the browser's origin-eye 3D sky drag, polynomial hover, spatial pairing, and free view rotation.

# Native 0.11.0 (15) candidate: cutting planes and Origin/Inhabit

**Status (2026-10-23):** 0.11.0 (15) is installed in the main simulator, launched and visually checked; every installed file matches the tested build from `7ec3428`. The launch's log receipt was not observed. Test boundaries:

- **Full suite:** 46/46 on the build-14 code (`ca809d2`).
- **Build 15:** the focused unit, plane/placement and lifecycle tests, plus the matched plane/Origin evidence test (separately, after a harness fix).
- **Not passing:** the opt-in spatial tap diagnostic did not pass (see below).

A silent 54-second simulator recording of the matched sequence was captured with the test that passed alongside it (`capture-tests.py --record-video`); it stays local.

This stage adds the browser's cutting planes and an ambient Origin/Inhabit placement. The evidence is visionOS Simulator 27.2 screenshots taken by passing XCTests in a disposable simulator, plus an independent cross-check against the browser's code. The main simulator keeps the promoted 0.10.0 (13) showcase until this candidate passes its full regression. Nothing here is a physical-headset claim.

**Implemented and tested**

- **Exact planes, the same as the browser's:** an exterior selection is its own Lorentz normal, and an exactly entered second interior point pairs with the selection.
  - An independent cross-check compared 6,585 cases (every interior pair at R6 plus every normal) against the browser code. Success or error, normal, equation and endpoint labels were identical, as were the R6 members of all 774 distinct planes.
  - Endpoints stay exact (rationals, surds like `1 ± √2`, and `∞`).
  - Collinear pairs, sign partners included, are rejected without changing anything.
  - Extreme inputs to the helpers are refused, not trapped.
- **Rendering:** amber rings mark the displayed interior triples that lie exactly in the plane; at R6, (1,0,−1) has 22 (11 upper and 11 lower, counting multiples and sign partners). A faint sheet, its boundary and the endpoint directions are drawn as viewing aids, not as a hyperbolic metric. Upper members are drawn 1.35× larger outside Origin. [Pair (1,0,1)/(1,1,1)](../docs/screenshots/parity-0110-native-plane-pair.png).
- **Placement:**
  - Overview is the stationary default. Origin and Inhabit place the object once from the head center through a `.once` head anchor (Apple's documented pattern). The app reads no tracking transform and needs no added authorization, and the object stays world-stationary afterwards.
  - Origin turns the object so the upper nappe's axis faces where the viewer looked, with a toggle for the lower nappe ([upper](../docs/screenshots/parity-0110-native-origin-upper.png), [lower](../docs/screenshots/parity-0110-native-origin-lower.png)). This is a presentation rotation, not hyperbolic navigation. The zero polynomial at the head center is not a point of the picture, and the two eyes sit either side of it.
  - The pair and plane are kept through Origin ([plane in Overview](../docs/screenshots/parity-0110-native-plane-origin-01-overview.png), [from Origin facing upper](../docs/screenshots/parity-0110-native-plane-origin-02-origin-upper.png), [and lower](../docs/screenshots/parity-0110-native-plane-origin-03-origin-lower.png), [Overview again](../docs/screenshots/parity-0110-native-plane-origin-04-overview-again.png)). Seen from the origin, the plane through the eye appears edge-on as one chord, the geodesic from −1 to 1, with its exact members ringed.
  - At Origin, dots follow the browser's rule 0.4·|Δ|^¼/√|a+c|; the cross-check matched it exactly for all 3,608 points up to R12.
  - Each explicit Origin or Inhabit press re-anchors. Renders, selection changes and the nappe flip keep the anchor, so selecting a point never moves an inhabited viewer ([after selecting (2,1,1) while inhabiting (1,−1,2)](../docs/screenshots/parity-0110-native-inhabit-other-selection.png)).
- **Controls:**
  - The header is pinned (Hide controls, Inhabit/Overview, Reset, Farey L/R, Exit) and the details scroll inside the 360 pt window. Before this fix, the taller panel pushed Reset and Exit out of the window.
  - Overview stays reachable with the controls collapsed ([capture](../docs/screenshots/parity-0110-native-inhabit-compact.png)).
  - Reset and the placement and view actions close open keyboards; rejected entries keep their text and focus.
- **Root labels (corrected in build 15):** boundary and exterior forms now give exact roots and separate finite roots from the projective point ∞. Examples: "double root x = 1"; the constant 1 has no finite root and a double root at ∞; x has the finite root 0 and a second root at ∞. Build 14 had said "one repeated real root" and "two real roots" for these.

**Still different or unverified**

- Glyphs are physical spheres, with no browser pixel knee or cap, so near points look large, especially boundary and exterior points at Origin.
- Native has no Stange-palette option and no plane-distance opacity focus.
- **Spatial point selection is coded but unverified.** Tapping a coefficient entity calls the same selection as text entry. An opt-in probe (`capture-tests.py --spatial-probe`, public XCUITest routes only, run once on 0.11.0 (15)) found the following:
  - The (3,0,3) entity reports a placeholder accessibility frame, (0, 0, 50, 50) in a 1280×1280 app frame, while claiming to be hittable.
  - An app-anchored coordinate tap there failed with "Failed to synthesize event: Received invalid scene ID (nil) from Accessibility"; no event was delivered and the selection did not change.
  - The element-coordinate route was not reached.
  - The probe now refuses such unmapped frames.
- **Spatial pairing is missing.** There is no native spatial second-point mode; pairing works only through exact text entry.
- **Native polynomial hover is missing code**, not just a headset test gap. It has no hover effect or spatial label; the browser's 3D hover label is itself our extension of Stange's highlight-only 3D hover.
- **Next supported manual route:** Device Hub's Select mode (pointer movement simulates eye hover, a click simulates tap, WASD/QE moves the viewpoint). It has not been run for this candidate.
- The test checks re-anchoring as anchor identity in unit tests; actual head translation and return, and parallax, still need a simulator or physical check.
- The source necklace count (71) comes from a different crop and is not comparable with native counts.
- Physical headset: 0.9.0 (12) is installed but not functionally tested.

# Native 0.10.0 (13) candidate versus browser 0.13.1

This candidate corrects the first-priority gaps in the 0.9.0 baseline below, which is preserved unchanged. As before, the evidence is visionOS Simulator 27.2 screenshots taken by passing XCTests, compared with an actual browser render. The physical Vision Pro still has 0.9.0 (12) installed, so nothing here is a headset appearance, comfort or input claim.

| Area | Native 0.10.0 (13), observed | Result |
| --- | --- | --- |
| Mathematical domain | Browser ball b²+2a²+2c² ≤ R², zero excluded: R4/6/8/10/12 give 128/480/1060/2100/3608 points, native cap 12 | An independent review compared every point and found them identical for all five radii |
| Spatial object | Both nappes; upper, lower, null and exterior points; projection off by default | Matches the browser default |
| Palette | log(\|Δ\|/3)/log(80) on Viridis 0.2–1; browser category swatches; optional lower-half color labelled "ours"; 0.72 factor for nonprimitive upper forms, and lower ones only with that option | Every point, color, factor and root was compared and is identical to the browser's ([pure-data comparison](evidence/parity-0100/data-comparison.json); projections agree within 4.44e−16) |
| Glyph size | Fixed unlit spheres of 7.5 mm radius. At the matched pose (3,0,3) draws 8×9 px; the browser draws 8×7 px; the previous 0.10 candidate's 13 mm radius drew 14×13 px | Close at this pose only: the browser clamps sprite size in pixels and native does not |
| Guide opacity | Browser opacities (cone 0.018, lines 0.26, disk 0.1/0.8, selection ray 0.35) converted for linear-light blending. Measured inside the cone: (1,4,4) native, (2,4,4)–(3,8,8) browser, (6,23,28) before conversion | A measured approximation: the conversion is calibrated on the brightest channel for one layer over black, so the other channels and overlapping layers only approximate the browser. It is not a general compositing equivalence |
| Pixel color | Same core value for (3,0,3). The native capture PNG carries an sRGB chunk and reads [92,178,128]. Converting the identical core sRGB value to Display P3 predicts exactly [92,178,128], a diagnostic clue rather than proof of the capture pipeline. The browser PNG has no profile, includes fog, and reads [44,163,112] | Data identical. The pixel difference is unexplained and has not been compensated |
| Entry and filters | Exact signed (a,b,c). Rejected entries keep the text, focus, state and revision. A valid entry dismisses the keyboard. Filtered selections keep their identity and are marked hidden | Tested in the UI and the model |
| Controls in space | A **Hide controls** toggle compacts the panel to two rows (header with Show controls, Reset, Farey L/R and Exit; then the coefficient readout) | Less obstruction, and the selected marker shows, but the compact panel still overlaps the apex. The full default panel covers the waist. Placement is not fixed |
| Attribution | Sources credits Harriss, Stange and Trettel, *Algebraic Number Starscapes* (arXiv:2008.07655), for the coefficient and root spaces; Series for Farey/LR; Viridis (CC0) | A UI test confirms the link is present |

[Native oblique](../docs/screenshots/parity-0100-native-oblique.png), [other side after a valid entry](../docs/screenshots/parity-0100-native-other-side.png), [controls hidden](../docs/screenshots/parity-0100-native-controls-hidden.png), [R12](../docs/screenshots/parity-0100-native-radius-12.png) and a [**test-only** browser render at the native pose](../docs/screenshots/parity-0100-browser-matched-pose.png) (root (0,1.4,−3.1), Rx(0.2814)Ry(−0.4806), eye (0,1.6,0), vertical FOV 58.7155°, full R6, projection off). That pose is a matching device, not XR head telemetry. The [measurements, scripts and hashes](evidence/parity-0100/measurements.json) let these numbers be rerun. The scripts rerun on the committed after-fix screenshots only; the before-fix captures stay local. The rim-line metric is crude: it is one row's brightest pixel.

Tests: a full native suite of 39/39 (21 unit/renderer, 18 UI) passed on source from before the focus/collapse, glyph and blend changes. After those changes, the renderer tests (5) and the coefficient-space UI test passed, with FareyCore at 39/39 and SwiftLint strict clean. A full suite was not repeated for these local control and material changes.

**Remaining gaps:** cutting planes, second selection and plane focus; Origin/Inhabit presets; polynomial-on-hover (next, browser first); densities above R12; pixel-clamped glyph size; the uncompensated pixel-color difference; the expanded panel's placement; spatial tap activation (the earlier AX "invalid activation point transform" failure is unresolved and untested here); everything on the physical headset.

# Native 0.9.0 versus browser 0.13.1

**The baselines do not have visual or UI parity.** This October 23 audit inspected actual simulator and browser screenshots and exercised their controls. It did not infer parity from successful builds. Native 0.9.0 (12) is installed on the physical Vision Pro, but this comparison used visionOS Simulator 27.2; physical launch, appearance and input remain untested.

| Area | Native 0.9.0 (12), observed | Browser 0.13.1, observed | Result |
| --- | --- | --- | --- |
| Mathematical domain | 280 points with a>0, Δ<0, a+c≤8 | Default R6 ball: 480 signed triples, excluding zero | Major mismatch |
| Spatial object | Noncoplanar upper-interior cloud and upper cone | Both nappes, null boundary and exterior points | Lower/exterior geometry missing natively |
| Common-point coordinates | Same (−b,a+c,c−a) basis and radial y=4 projection | Same map; diagnostic uses all 280 native triples | Shared construction agrees on this subset |
| Appearance | Large lit blue/purple spheres; selected orange | Tiny unlit dots; fixed log-discriminant Viridis and category swatches; selected white outline | Size, palette, lighting and emphasis differ |
| Opacity | Cone 0.045, projection 0.12; no focus control | Cone 0.018, projection 0.10; optional plane-distance viewing aid | Values and available control differ |
| Default projection | On | Off | Native screen dominates more of the initial view |
| View controls | Three fixed object orientations; real head motion is the native spatial input | Free orbit plus Inhabit/Overview and Origin with explicit movement/look | Native navigation presets missing |
| Selection | Next point cycles five forms; preserves a scalar multiple across re-entry | Direct coefficient entry and a real pointer click selected (2,1,1); same exact root for multiples | Native arbitrary entry missing; spatial tap activation blocked in XCTest |
| Cutting planes | No exterior-normal or paired-root controls | Pair (1,0,1)/(1,1,1) produced 2a−2c=0, endpoints −1,+1 | Missing natively |
| Density and appearance controls | Fixed population and sphere size/color | Radius through 96, size, palette, whole lattice and lower-color controls | Missing natively; dense limits must remain explicit |
| Controls in space | SwiftUI glass window with Exit and Sources; it obscures the first selected point in the capture | HTML panel on desktop; separate XR ray/readout path | Platform adaptation is appropriate; native placement needs work |
| Reset and lifecycle | Actual test passed Next, projection toggle, other/side views, exit/re-entry, separate Farey state and Reset | Actual desktop walkthrough passed matching Next/projection, Origin/Overview, pair and Reset | Common subset works; complete XR lifecycle parity unverified |
| Headset/controller input | Simulator button interaction tested; physical hand input untested | Actual desktop pointer tested here; previous 0.13 emulator evidence remains version-specific | No physical input parity claim |

## Captures and matching procedure

[Native initial scene](../docs/screenshots/parity-090-native-oblique.png) and [native alternate side](../docs/screenshots/parity-090-native-other-side.png) came from the existing coefficient/lifecycle XCTest with a state-held screenshot acknowledgment. All five captures completed and the test passed. The disposable simulator was removed; the main simulator and user Chrome tabs were preserved. This successful run does not resolve the earlier simulator capture uncertainty for every sequence.

[Browser initial scene](../docs/screenshots/parity-090-browser-default.png) shows its ordinary 480-point default. [Browser Origin](../docs/screenshots/parity-090-browser-origin.png) shows the absent native preset. The browser's actual pointer event selected `(2,1,1)`, matching its current-ray oracle. These captures use desktop rendering, not an immersive XR session.

The ordinary UIs cannot request identical populations or camera settings. To isolate rendering differences, a **test-only browser diagnostic** substituted exactly the native 280 triples, native root translation `(0.9,0.8,−3.5)`, rotation `R_y(−0.55) R_x(0.28)`, scale 0.18, upper cone of height 8, projection on and selected `(1,−1,2)`. [Its actual rendered screenshot](../docs/screenshots/parity-090-browser-matched-subset.png) retains the browser's palette/glyph/opacity rules. It is not an available product mode or proof of normal-UI parity.

The diagnostic uses a calibrated monoscopic camera at `(0,1.6,0)`, identity orientation, 90° horizontal FOV (58.7155° vertical at 3840×2160). Against the native screenshot, predicted origin and selected-image anchors differed from thresholded white-pixel centroids by 0.81 and 1.21 pixels. This checks the comparison's framing; it is not direct native head-pose telemetry, physical stereo calibration or a pixel-identical image claim. The very different marker footprints and materials remain visible with this crop and framing held fixed.

[Structured state, camera analysis and checks](evidence/parity-090-browser-0131/checks.json) retain versions, screenshot hashes, actual browser entity positions and explicit test boundaries. Raw simulator result bundles remain local. The browser hook changed only its isolated test page; it did not change the served app or the user's current view.

A separate frozen-source spatial-tap probe found the coefficient entity in accessibility, but `target.tap()` failed with **“Failed to received invalid activation point transform (nil) from Accessibility.”** No model method was substituted. That probe failed (one test), so actual native gaze/pinch or spatial tap remains unverified. This does not establish whether the failure belongs to the app or this simulator accessibility route.

## Correction priority

First align the native mathematical domain, both cone halves, default projection, discriminant palette, point-like appearance and exact selection controls. Preserve the old baseline and the independent Farey view. Use explicit geometry caps rather than implying native million-point support. Then close cutting-plane and embodied navigation gaps with tested spatial controls; an ordinary Euclidean camera mode must not be called intrinsic hyperbolic navigation. Native glass controls and gaze/pinch can remain platform adaptations, but should expose the same mathematical operations and leave the focal geometry visible.

Repeat this audit after each tested native increment. Keep current-version foreground browser XR, physical hand/controller input, comfort, GPU performance and headset capture as separate checks. No permissions or security settings were changed for the baseline audit.
