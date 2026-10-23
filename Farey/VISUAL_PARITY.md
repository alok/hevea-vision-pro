# Native 0.10.0 (13) candidate versus browser 0.13.1

This candidate corrects the first-priority gaps in the 0.9.0 baseline below, which is preserved unchanged. As before, the evidence is visionOS Simulator 27.2 screenshots taken by passing XCTests, compared with an actual browser render. The physical Vision Pro still has 0.9.0 (12) installed, so nothing here is a headset appearance, comfort or input claim.

| Area | Native 0.10.0 (13), observed | Result |
| --- | --- | --- |
| Mathematical domain | Browser ball b²+2a²+2c² ≤ R², zero excluded: R4/6/8/10/12 give 128/480/1060/2100/3608 points, native cap 12 | An independent review compared every point and found them identical for all five radii |
| Spatial object | Both nappes; upper, lower, null and exterior points; projection off by default | Matches the browser default |
| Palette | log(\|Δ\|/3)/log(80) on Viridis 0.2–1; browser category swatches; optional lower-half color labelled "ours"; 0.72 factor for nonprimitive upper forms, and lower ones only with that option | Every color and factor was compared and is identical to the browser's (exact data parity) |
| Glyph size | Fixed unlit 7.5 mm spheres. At the matched pose (3,0,3) draws 8×9 px; the browser draws 8×7 px; 0.9.0-sized 13 mm spheres drew 14×13 px | Close at this pose only: the browser clamps sprite size in pixels and native does not |
| Guide opacity | Browser opacities (cone 0.018, lines 0.26, disk 0.1/0.8, selection ray 0.35) converted for linear-light blending. Measured inside the cone: (1,4,4) native, (2,4,4)–(3,8,8) browser, (6,23,28) before conversion | Close over black; the formula is exact only over black and for a single layer |
| Pixel color | Same core value for (3,0,3). The capture PNG carries an sRGB tag and reads [92,178,128], whose Display P3 conversion is consistent; the browser PNG has no profile and fog, and reads [44,163,112] | Data identical. The pixel difference is unexplained and has not been compensated |
| Entry and filters | Exact signed (a,b,c). Rejected entries keep the text, focus, state and revision. A valid entry dismisses the keyboard. Filtered selections keep their identity and are marked hidden | Tested in the UI and the model |
| Controls in space | A **Hide controls** toggle leaves one row (readout, Show controls, Reset, Farey L/R, Exit) and clears the apex | The expanded panel still covers the waist; window placement is unchanged |
| Attribution | Sources credits Harriss, Stange and Trettel, *Algebraic Number Starscapes* (arXiv:2008.07655), for the coefficient and root spaces; Series for Farey/LR; Viridis (CC0) | A UI test confirms the link is present |

[Native oblique](../docs/screenshots/parity-0100-native-oblique.png), [other side after a valid entry](../docs/screenshots/parity-0100-native-other-side.png), [controls hidden](../docs/screenshots/parity-0100-native-controls-hidden.png), [R12](../docs/screenshots/parity-0100-native-radius-12.png) and a [**test-only** browser render at the native pose](../docs/screenshots/parity-0100-browser-matched-pose.png) (root (0,1.4,−3.1), Rx(0.2814)Ry(−0.4806), eye (0,1.6,0), vertical FOV 58.7155°, full R6, projection off). That pose is a matching device, not XR head telemetry. The [measurements, scripts and hashes](evidence/parity-0100/measurements.json) let these numbers be rerun. The rim-line metric is crude: it is one row's brightest pixel.

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
