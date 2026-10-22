# Browser-first coefficient space

Browser **0.12.0** is the current desktop demo. Native **0.9.0** retains the upper-cone projection view in [COEFFICIENT_CONE.md](COEFFICIENT_CONE.md); the dense signed lattice, Origin and newer cutting-plane controls are browser features.

## Open and explore

Unpack `WebXR/output/Farey-WebXR-0.12.0.zip`, open a terminal in the unpacked folder and run `python3 serve.py --port 8080`. Open `http://127.0.0.1:8080/`. All runtime assets are local. This loopback address only serves the computer running the command; it is not a published link or a headset-accessible deployment.

The initial view is a stationary, oblique overview of a genuinely noncoplanar integer coefficient lattice and both halves of the discriminant cone. Drag to orbit, scroll to zoom and click to inspect. **Inhabit** enters near the selected point; **Overview** restores the saved camera. **Origin** places the eye exactly at the apex. Look up/Level/Look down, drag to look, and W/A/S/D plus Q/E or the onscreen buttons move explicitly. **Reset** restores the initial scene. There is no automatic motion.

This is ambient Euclidean coefficient-space navigation. It does not implement the source's SL₂ action or intrinsic hyperbolic navigation. The camera origin is a valid viewing location. The zero polynomial is omitted from the lattice: it has no unique associated root/projective point, and radial projection there is undefined.

## Exact mathematical object

Each point is an integer triple `(a,b,c)` for `at²+bt+c`. Our display basis is

```
(X,Y,Z) = (−b, a+c, c−a)
Δ = b²−4ac = X²+Z²−Y²
```

The finite crop is `X²+Y²+Z² ≤ R²`, excluding zero. Transformed lattice points obey `Y ≡ Z (mod 2)`; they are not all of Z³. The upper and lower interiors have Δ<0; the null cone has Δ=0; the exterior has Δ>0. Opposite nonzero triples represent the same roots/projective class, while retaining different ambient locations.

**Project to Klein disk** explicitly adds the slice and radial correspondence. Interior forms map to `u=−b/(a+c), v=(c−a)/(a+c)`. Negative forms are sign-flipped to the positive representative before radial projection onto the positive screen. The upper-half-plane root is `(-b+i√(4ac−b²))/(2a)` for a>0. Exterior forms are not complex-root stars in this disk. The separate Farey L/R page has a different, intrinsically planar rational-pair lattice.

## Cutting planes

Select an exterior point to use its coefficients `(A,B,C)` as a Lorentz normal. Or select two distinct interior projective directions with Shift-click or **Pair entered point**. The plane is

```
−2Ca + Bb − 2Ac = 0
```

It cuts the cone in null directions corresponding to roots of `At²+Bt+C`. An amber sheet, exact-member rings and optional disk chord make this correspondence visible. The pair `(1,0,1)` and `(1,1,1)` gives `2a−2c=0` and endpoints −1,+1. An independently clicked source example `(1,8,−1)` gives `2a+8b−2c=0` and endpoints `−4±√17`.

Optional fading away from the selected plane uses normalized **Euclidean display-space distance**, with a nonzero opacity floor. It is a viewing aid, not a projective invariant or intrinsic hyperbolic distance. Turn it off to recover ordinary opacity. Transparency uses an approximate depth treatment without per-point sorting; a rigorous overlapping-point occlusion audit remains open.

## Color and glyphs

The default **Viridis** maps the actual triple's `|Δ|` by `clamp(log(|Δ|/3)/log(240/3),0,1)` into Viridis positions 0.2–1. Skipping its darkest fifth keeps tiny dots visible on black. Values above 240 saturate. The null, exterior and lower-interior categories use separate swatches. **Stange anchors** uses her six verified anchors and OKLab interpolation; category hues are approximations, not a pixel-identical reproduction. **Color lower half too** is our explicit extension.

Primitive/nonprimitive factors, perspective, overview fog and the source eye-at-origin radius `∝ |Δ|¼/√(a+c)` inform dot size. Apparent size along a fixed ray decreases as `1/√|Δ|` after the position factor is fixed. Our display limits are intentional: below 1 CSS pixel a dot stays one pixel and dims; radius above 2.5 px grows as a cube root and is capped at 9 px. Exact centers are unchanged. Click picking selects the closest center within an angular threshold; overlapping points can remain ambiguous.

Viridis data is CC0, credited to Nathaniel J. Smith, Stefan van der Walt and Eric Firing. Normal, protan and deutan simulations test category/ramp separation in OKLab; this is a numerical check, not assistive-technology or human accessibility validation. Tritanopia and very dense clouds need further assessment.

## Density and measured limits

One GPU point batch renders exact unique triples without sampling or duplication:

| Radius | Points | Crop change wall time | Pick time | Chrome JS heap |
| --- | ---: | ---: | ---: | ---: |
| 12 | 3,608 | 17 ms | 0.8 ms | 19.9 MB |
| 24 | 28,832 | 13 ms | 2.1 ms | 17.4 MB |
| 48 | 231,348 | 36 ms | 12.2 ms | 30.1 MB |
| 96 | 1,852,484 | 186 ms | 41.5 ms | 130.4 MB |

These one-run desktop Chrome observations used ANGLE Metal on Apple M4 Max. The overview submitted 10 draw calls and 592 triangles plus the point primitives. Median requestAnimationFrame intervals were 16.7 ms, which reflects browser/vsync scheduling and does **not** establish GPU headroom, headset FPS or comfort. Heap excludes GPU/driver/process memory. At high density overlapping glyphs form a cloud and large discriminants saturate at yellow. Use a smaller crop, Inhabit or star size for inspection.

**Debug** starts closed. It distinguishes submitted point primitives, triangles, draw calls, CPU timing, array estimates and JS heap. Its optional 60-interval measurement cancels on close; Escape closes Debug without changing view mode. There is no continuous stats collection while closed.

## Provenance and evidence boundaries

Compare [Stange's whole-lattice scene](https://katestange.net/starscape-lattice/#lm=1&c=1&sc=0&p=0&cp=1), [talk](https://katestange.net/talks/math-exploration/#/starscape-cone), and [Harriss, Stange and Trettel, *Algebraic Number Starscapes*](https://arxiv.org/abs/2008.07655). Our basis differs from her `(b,a+c,a−c)` by a rigid half-turn around the vertical axis. Our symmetric cone extent, origin-centered crop, bounded glyph sizes, palette and Euclidean navigation are independent presentation choices. No Stange code, meshes or media are bundled. Attribution is not a software license or endorsement. Caroline Series' [1985 paper](https://doi.org/10.1112/jlms/s2-31.1.69) remains credited for the separate L/R geodesic coding.

`npm test` exercises exact counts, parity, cone/ray maps, sign pairs, plane endpoints, finite continued fractions, input, recovery and package integrity. `starscape-checks.js`, `pair-checks.js` and `debug-checks.js` exercise the actual local artifact in isolated desktop Chromium. The original native 0.9.0 passed 36 simulator UI tests independently of these browser additions.

Browser WebXR code requests `immersive-vr` with local-floor support and renders using Three.js XR camera/controller paths. **Actual IWE-emulated immersive sessions, stereo frames, programmed head poses, controller-ray selection and repeated exit/re-entry are verified.** See [the exact evidence and limits](XR_SIMULATION.md). Physical tracking, headset controls, GPU performance and comfort remain unverified. No OS permission or security setting was changed for this increment. Physical-device signing/install, public hosting and private video uploads remain separate steps.

Browser 0.13 adds app-owned XR rays, per-hand hover labels and a selected-point/plane readout. Hover and selection remain distinct; the trigger uses a fresh ray. The depth-tested cyan ring is an approximate angular-scale annotation. Linear hover scans at the largest crop can still hitch; [current evidence and limits](XR_SIMULATION.md) distinguish actual emulator observations from mocked regressions and physical hardware.
