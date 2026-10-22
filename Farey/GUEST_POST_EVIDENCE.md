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

Twenty-three Swift core tests, seventeen native model/UI tests, and twenty-two JavaScript tests passed. The revised native lesson popover also passed its focused UI test. Native UI tests exercised entry, exit, repeated re-entry, L/R, Undo, Reset, bounds and linked representation selection. Browser checks exercised orbit, sphere hit-testing, fraction entry, bounds and recovery. The latest native device-target Release build passed strict signature verification using existing signing material.

## Claims to leave open

There has been no physical-headset installation or execution in this task. The local desktop browser reports immersive VR unsupported, so the implemented WebXR session and controller path has not been verified on Quest, Meta Browser or physical Vision Pro. Do not claim headset performance, comfort, hand/eye interaction quality, Meta affiliation, or a public deployment. The finite lattice is exact within its stated bounds; it is not the infinite Farey fractal or Stange's separate hyperboloid construction.

The UI word denotes M(1). Stange's endpoint convention sends M(∞) to the same fraction after appending R; for 3/5 the two displayed words are RLR and RLRR respectively. State this distinction if showing both applications together.

A separate visionOS 27.2 Safari probe reported immersive VR available and an actual click reached its device position/head-movement permission prompt. The permission was left ungranted; no session or XR frames were observed. A [static deployment plan](WebXR/DEPLOYMENT_PLAN.md) and local artifact are prepared; publication remains unperformed.

Both native and browser versions offer a worked “predict, apply, explain” path: 1/2 → L → 2/3 → R → 3/5. It uses the ordinary L/R state and shows its exact vector additions. This is a demonstrable interaction; no learner study or educational efficacy is claimed.

Version 0.2 adds [native lesson evidence](evidence/spatial/lesson-R.png), [actual desktop Safari evidence](evidence/webxr/desktop-safari-lesson.png), and a [portrait browser view](evidence/webxr/portrait.png). The [native 0.2 test summary](evidence/spatial/native-02-summary.json), [popover recheck](evidence/spatial/lesson-popover-summary.json), and [precise WebXR consent boundary](evidence/webxr/safari-probe.json) distinguish passing application behavior from remaining runtime validation.

Browser 0.2.1 was also exercised in **actual Mobile Safari on an iPhone simulator**: [L](evidence/webxr/mobile-safari-L.png), [R](evidence/webxr/mobile-safari-R.png), Undo and Reset all agreed with the same exact state. Phone controls no longer cover the lattice during the lesson, and keyboard focus remains usable. The [browser regression record](evidence/webxr/browser-021-validation.json) includes the static artifact and asset hash checks. This adds mobile-browser evidence; it does not establish physical-phone or immersive-headset behavior.

Browser 0.2.2 separates single-tap selection from gestures and keeps the lattice visible in landscape. [Actual simulator Safari before and after a drag](evidence/webxr/safari-landscape-validation.json) preserves the same rational while changing the view. Pinch and two-finger pan were tested with Chromium protocol-generated events. Accessibility-tree descriptions and keyboard controls passed; screen-reader speech, physical-device gestures and immersive WebXR remain unverified.

Browser 0.2.3 recovers from controlled WebGL context loss without requiring another mathematical move. The visible fallback preserves access to exact controls, and reload restores the saved L/R word and finite grid. The evidence distinguishes browser-generated loss/restoration events from the separately mocked initial-WebGL failure. This does not establish physical GPU failure recovery or XR-session recovery.

Native 0.3 adds direct positive-fraction entry. Entering `6/10` selects the reduced fraction `3/5` and its exact L/R path. Invalid, zero-denominator, overflow and out-of-domain entries preserve the previous mathematical state. A selected vector outside the visible grid keeps its direction plane and an explicit bounds explanation. Native and browser selection agreed on 907 bounded test inputs; this is test evidence, not a formal proof.

Native 0.4 and browser 0.3 distinguish the inspected integer point from its reduced direction. The worked example is `(10,6) = 2 × (5,3)`: the two lattice points have different locations but represent the same rational `3/5`. The inspector shows the gcd, primitive vector and exact L/R word. The native disk links that reduced rational to the same boundary point and green geodesic from infinity; it does not identify lattice distances with hyperbolic distances. The finite upright plane now reaches the grid boundary so the displayed multiples visibly lie in it. [Native and browser comparison](evidence/point-inspection/parity.json) agreed on 966 bounded coordinate pairs, including zero and invalid inputs.

The point-inspection increment includes [native inspection](evidence/point-inspection/native-multiple.png), its [linked disk](evidence/point-inspection/native-disk.png), and the [browser view](evidence/point-inspection/browser-multiple.png). The browser check clicked the actual 6/10 sphere and verified point identity survived reload. Native tests selected its spatial label, switched representations, exited/re-entered, and tested a point outside the reduced grid. This does not establish physical hand/eye interaction or an immersive WebXR session.

Native 0.5 and browser 0.4 distinguish convergents from intermediate mediants. The [canonical view](evidence/convergents/native-canonical.png) marks `2/3` as intermediate for `3/5 = [0;1,1,2]`; the [alternate finite form](evidence/convergents/native-alternate.png) makes it a convergent of `[0;1,1,1,1]`. The rational and exact L/R path stay fixed. Gold and gray rings agree with the labels in the native lattice, [native disk](evidence/convergents/native-disk.png), and [browser](evidence/convergents/browser-canonical.png). Convergent labels are relative to the chosen expansion; not every visited mediant is a convergent.

Native 0.6 and browser 0.5 add a separate approximant spotlight. Double white rings locate the chosen row without changing the target, inspected point or lesson prediction. A fresh-launch walkthrough follows the lesson, enters `6/10`, spotlights an intermediate and a convergent, changes expansion, switches views, checks a point beyond the grid, then clears and resets. That review led to two visibility fixes: the native row picker closes so it cannot cover its marker, and browser target/spotlight context stays visible while the rows scroll. The [walkthrough evidence](evidence/spotlight/validation.json) separates this tested behavior from unverified headset and WebXR operation.

The native 0.6.1 / browser 0.5.1 [release audit](DEMO_READINESS.md) corrects numerical collapse in deep disk arcs and recovery after zero-size browser resizing. It records deterministic geometry checks, repeated native background/foreground transitions, malformed-state rejection and desktop CPU timings. These add reliability evidence; they do not close the real WebXR or physical-headset validation gap.

Native 0.7 and browser 0.6 add an optional [boundary-to-lattice construction](CONSTRUCTION.md). Its q=1 projection preserves rational directions; the opt-in interpolation passes through real positions that need not be integer points. It is an explanation, not a hyperbolic map or a claim of educational efficacy. The earlier recorded demonstration remains explicitly labelled native 0.6.1 / browser 0.5.1.
