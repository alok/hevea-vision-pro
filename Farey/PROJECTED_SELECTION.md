# Selecting crowded projected directions

Native 0.8 / browser 0.7.0 add an explicit preview before selecting a projected dot. This addresses a measured ambiguity in the optional q=1 construction; the ordinary integer lattice keeps direct point selection.

The construction remains an independent teaching sequence inspired by [Katherine Stange's viewer](https://katestange.net/talks/math-exploration/viewers/farey-cf-lattice.html), with [Caroline Series's L/R coding](https://doi.org/10.1112/jlms/s2-31.1.69). See the [source-fidelity audit](SOURCE_FIDELITY.md) for the mathematical correspondence and its limits. This change does not alter that mathematics or reproduce Stange's code.

## Measured problem

At grid 14, the projected centers for 3/5 and 8/13 are only `0.25 × (8/13 − 3/5) ≈ 0.00385 m` apart. Each ordinary sphere has diameter 0.072 m. Their images overlap substantially, and the selected sphere is larger still.

The committed 0.7.1 / browser 0.6.1 baseline was tested with real browser mouse input aimed at the live projected center of 3/5. Fifteen cases combined offsets −4, −2, 0, +2, +4 CSS pixels with the default view, front view, and a closer front view. Fourteen selected another fraction. The test exposed existing camera/mesh matrices read-only to obtain coordinates; it did not replace hit testing. A separate center click at 13/14 selected the enlarged 1/1 sphere.

Native rendering tests confirm the same overlapping center geometry. A direct simulator coordinate tap was attempted on an exposed RealityKit accessibility entity. Xcode returned a placeholder frame `(0,0,50,50)` and failed with `Received invalid activation point transform (nil) from Accessibility`. A subsequent [integration diagnostic](INTEGRATION_08.md) using the documented `XCUIElement.tap()` API failed with the same error. These attempts are not evidence of successful spatial input. Native controls provide a separately tested alternative.

## Interaction

- A projected-dot hit opens **Preview**, showing the exact rational and its primitive integer point. In native controls, **Pick p/q** opens the same chooser without requiring a sphere hit.
- **Previous fraction** and **Next fraction** traverse all displayed positive primitive directions in exact numeric order. At grid 14 there are 127 selectable directions. Zero and infinity remain boundaries.
- **Select** explicitly changes the target and inspected point. Choosing 3/5 selects primitive point `(5,3)`; it does not silently retain an old inspected multiple such as `(10,6)`.
- **Cancel** preserves the target, inspected point, spotlight and lesson. Preview navigation does not move the camera or rewrite the L/R word. Changing the target, grid or construction step clears a stale preview.

The browser also retains direct fraction entry. Its in-world controller panel has corresponding preview controls, but actual immersive WebXR input remains unverified. Previewing is deliberately a separate state from the current target and the approximant spotlight.

This does not improve the accuracy of the first hit or separate the overlapping spheres. It makes that hit a proposed choice that can be inspected and corrected before committing. The fifteen repeated browser cases all reached the intended 3/5 after explicit preview navigation and confirmation. Some required up to eleven Previous/Next actions; direct p/q entry remains faster for a distant choice.

## Evidence and limits

[Evidence](evidence/projected-selection/) includes baseline and final browser measurements, native results, screenshots and the static artifact manifest. All 27 Swift core tests, 26 JavaScript tests and 18 focused native model/renderer/UI tests passed. The signed native 0.8 Release build passed strict signature verification using existing signing material. Browser checks cover actual mouse clicks, emulated touch, keyboard activation, cancellation, retained inspected multiples/lesson predictions, and unchanged scene pixels before confirmation. Eighty preview moves left the renderer's geometry/texture counters unchanged; this is not a heap-leak proof or a headset frame-rate measurement.

Native tests cover exact fraction ordering, renderer geometry, model state preservation, and actual **Pick p/q**, Previous, Cancel and Select button taps with exit/re-entry. Direct sphere coordinate automation remains limited as described above. Physical hand/gaze interaction, spoken screen-reader output and real immersive WebXR sessions are not established by these tests.

Run `projected-selection-checks.js` through the existing Playwright CLI on either local browser server. The native scenario is `FareyVisionUITests/FareyUITests/testProjectedPreviewSelectionAndCancel`. The preview-order tests are in the `ProjectedSelectionTests` core suite.
