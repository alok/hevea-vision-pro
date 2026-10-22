# Source-fidelity audit — 22 October 2026

This historical audit covers native 0.7.1 / browser 0.6.1. See [the integration check](INTEGRATION_08.md) for the current build and [projected-selection follow-up](PROJECTED_SELECTION.md) for the completed crowding audit. This is an independent, finite teaching demo inspired by **Katherine Stange**. It is not her software, her complete visualization collection, or a mathematical proof.

## What was inspected

- [Stange's talk](https://katestange.net/talks/math-exploration/) and its actual [L/R and lattice viewer](https://katestange.net/talks/math-exploration/viewers/farey-cf-lattice.html), including its readable browser source. A fresh browser run selected 3/5 and traversed Tessellation → Dots → Lattice → Labels. It displayed R L R² and `[0; 1, 1, 2]`. Reference screenshots stay outside the repository; no source code or media was copied into the application.
- [Series's 1985 paper](https://doi.org/10.1112/jlms/s2-31.1.69): publisher metadata verified the title, author and pages 69–80. The full 1985 paper was not accessed. The supporting mathematics was checked against her freely available [2015 lecture notes](https://warwick.ac.uk/fac/sci/maths/people/staff/caroline_series/hypgeomandcntdfractions.pdf), especially §1 and §2, Exercise 2.1(b), Proposition 2.2 and the convergent definition on printed page 10.
- Native and browser rendering, selection and explanation code, followed by actual local browser and visionOS simulator execution. An independent reviewer examined the mathematics and source correspondence without editing files. Download hashes and observed source state are in [provenance.json](evidence/fidelity/provenance.json).

## Correspondence and deliberate differences

| Topic | Reference and interpretation | Current demo and claim boundary |
|---|---|---|
| Coordinates | Stange's viewer places the pair `(q,p)` at world position `(q,0,p)`. | The same pair is embedded by uniform scale 0.25 and a rigid rotation. The scene tilt is presentation. Distances in metres are not integer-coordinate distances. |
| Lattice extent | The viewer uses a signed lattice in a circular patch of radius 70. | The demo shows a bounded nonnegative square, with positive selections, and axes as boundaries. This is a smaller domain, not the full source scene. |
| Rational direction | A primitive pair determines a ray; its positive multiples lie on it. | Inspected `(10,6)` and primitive `(5,3)` remain distinct points sharing 3/5. Reducing a fraction does not move the inspected point to the primitive point. |
| Direction plane | The source draws a finite upright wall along the selected ray. | A finite plane patch spans that ray and a direction perpendicular to the lattice. Its height is arbitrary. It is not an extrusion of a disk arc, a hyperboloid or another rational coordinate. |
| Boundary chart | The source's initial view is a ground-level perspective with a number-line/tessellation overlay. | Our q=1 chart is an explicit projective cross-section: `(q,p)` becomes `(1,p/q)`. It identifies multiples and is not an injective map of lattice points. It is distinct from the Poincaré disk. |
| Stage transition | The source holds the lattice positions fixed, changes sphere appearance, then lifts and turns the camera. | Our optional interpolation moves dots along rays while the camera stays fixed. Intermediate positions need not be integral. This is a teaching choice, not the source's camera path or a hyperbolic isometry. |
| L/R matrices | The source multiplies on the right by `L=[1 1;0 1]`, `R=[1 0;1 1]` and ends its rational word in R. | The app stores an interval word with selected mediant `M(1)`. Appending R gives the source endpoint convention `M(∞)`. For 3/5 the app stores RLR; the endpoint word is RLRR. |
| Finite expansions | Series's notes permit two finite expressions and a terminal triangle-label choice at a rational endpoint. | The app explicitly chooses the ending-in-R endpoint convention. Toggling the finite expansion changes the convergent list, not the stored interval or selected rational. |
| Convergents | Truncations of the chosen continued fraction, not every mediant visited. | For canonical 3/5, 2/3 is an intermediate mediant. It becomes a convergent in `[0;1,1,1,1]`. Gold/gray rings annotate this distinction; ring sizes have no mathematical meaning. |
| Disk | Farey edges are hyperbolic geodesics; a change of model changes their appearance. | The native disk uses a rotated Cayley boundary chart and sampled orthogonal arcs. It shares the rational state with the lattice but does not claim their Euclidean distances agree. The browser currently offers the spatial lattice, not a linked disk. |
| Infinity and bounds | q=0 is the infinity direction and has no finite intersection with q=1. | Projection omits it. Selections beyond the finite grid/chart remain exact and are reported, not clamped. |

The coordinate projection and interpolation formula in [CONSTRUCTION.md](CONSTRUCTION.md) are derived directly from scaling a ray. They are implementation explanations, not formulas copied from Stange's source. The original 1985 attribution remains prominent alongside her talk and viewer links.

## Verified problems corrected

1. Projected dots and moving markers were incorrectly counted/described as integer lattice points. Receipts now distinguish **92 projected direction dots** from the **168-point source grid** at the default bound. Natural animation completion, explicit Stop and graphics recovery restore the integer-position description. Native accessibility labels and browser canvas descriptions/hover text follow the same distinction.
2. Three.js raycasting still hits a mesh whose `visible` flag is false. Hidden construction markers could intercept pointing. Desktop hover, desktop selection and controller selection now filter invisible targets. A regression uses actual Three.js meshes to reproduce the old failure and verify the correction; actual XR controller execution remains untested.
3. Documentation said every projected value was labelled; only the selected value is labelled. That statement is corrected. The app's explanation now also states the rational terminal-label convention.
4. The native Sources panel truncated its longer provenance paragraphs. Its text is now scrollable, with the return button kept outside the scrolling content.

## Evidence and reproducibility

[Evidence directory](evidence/fidelity/) contains app-only screenshots, test summaries and the static artifact manifest. The bounded arithmetic sweep checks all positive numerator/denominator pairs up to 200: 34,196 accepted cases pass determinant, target, finite-expansion, convergent and endpoint-word checks; 5,804 exceed the supported 24-move cap. This is execution evidence, not a proof beyond those cases.

```sh
node scripts/audit-math.mjs
swift test --package-path Packages/FareyCore --scratch-path /tmp/farey-core-audit --jobs 2
# In WebXR, with the source server on 8080 or static server on 8081:
playwright-cli open http://127.0.0.1:8080/
playwright-cli run-code --filename construction-checks.js
```

Twenty-five Swift core tests, 25 JavaScript tests and the 22-test native simulator suite passed. After the Sources-only scrolling fix, its final UI scenario passed again. The final signed Release build passed strict signature verification.

The native `LatticeRendererTests` inspect actual RealityKit entities, projected positions, visibility and accessible labels. The simulator construction scenario checks entry, natural animation completion, Stop, exit/re-entry, linked disk state and out-of-grid handling. Build/test results are recorded separately from hardware claims.

## Prioritized continuation

1. **Authorized independent coding:** the largest remaining teaching gap is that the q=1 chart and linked native disk cannot yet be inspected side by side. First evaluate whether a compact selected-value comparison would clarify this without implying a metric equivalence. Prototype and test only if it addresses observed confusion; do not add another decorative transformation.
2. **Authorized independent validation:** exercise direct spatial hit selection at crowded projected directions and extremes, and repeat native lifecycle/resource checks after any interaction change. Keep the stationary default and finite geometry cap.
3. **Unverified XR runtime:** desktop rendering and native simulator tests do not establish an immersive WebXR session. Validate actual session entry, frames and input on an authorized XR target, with its operator handling required consent.
4. **Hardware-dependent:** physical Vision Pro/Quest input, comfort and frame performance remain untested. Headset availability needs a fresh check before installation; a signed build is not device execution. No new signing assets or access are authorized.
5. **Distribution:** no public web deployment is validated by this audit. Review the intended host and publication scope separately. Earlier demonstration recordings predate these revisions and do not verify their behavior.
