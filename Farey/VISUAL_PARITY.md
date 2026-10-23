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
