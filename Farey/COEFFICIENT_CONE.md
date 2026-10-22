# Coefficient space before projection

This guide describes native 0.9.0 and the earlier browser 0.8.0. [Browser 0.9.0](DOUBLE_CONE.md) extends the scene to the full signed lattice, both cone halves and an ambient first-person mode. The original versions open a noncoplanar mathematical object. The previous Farey L/R lattice remains available as a separate view.

The distinction matters: Stange’s L/R slide starts with a **two-dimensional rational-pair lattice**. Its spheres and upright direction plane do not make it a three-dimensional lattice. The talk’s **Starscape / Lattice** sequence starts with integer polynomial coefficients `(a,b,c)` filling three-dimensional space, restricts them to a discriminant cone, then projects their rays to a disk. This update implements that coefficient construction in original code. It does not extrude the old Farey diagram.

## Exact object and map

Each point represents `a t²+b t+c`. We display all 280 integer triples satisfying

```
a > 0,  b²−4ac < 0,  a+c ≤ 8.
```

The display coordinates before a uniform scale and rigid placement are

```
(x,y,z) = (−b, a+c, c−a)
x²+z²−y² = b²−4ac.
```

Thus the cone surface is `x²+z²=y²`; the points occupy its interior at different heights and depths. These are transformed integer coefficient triples, not arbitrary integer points in the displayed coordinate basis.

The cyan screen is the plane `y=4`. Projection from the origin is exactly

```
P(x,y,z) = (4x/y, 4, 4z/y).
```

It is radial projection, not orthographic flattening. The source point stays visible; the white marker shows its image. The screen’s intersection with the cone is a disk. Normalize its two coordinates to

```
u = −b/(a+c),  v = (c−a)/(a+c).
```

These are Klein-disk coordinates. The corresponding upper-half-plane point is

```
u/(1−v) + i sqrt(1−u²−v²)/(1−v)
  = (−b + i sqrt(4ac−b²))/(2a).
```

The interface reports that quadratic root. `(1,−1,2)` and `(2,−2,4)` have different 3D locations but the same projected position and root. **Next point** demonstrates this directly. The projection loses scale; it does not preserve three-dimensional Euclidean distances.

## Source boundary

Inspected on 22 October 2026:

- [Stange’s exact talk, coefficient-cone slide](https://katestange.net/talks/math-exploration/#/starscape-cone).
- [Live Starscape / Lattice talk viewer](https://www.katestange.net/starscape-lattice/?talk), stages 0, 1 and 2: coefficient lattice, cone interior, then radial projection. The public viewer’s own explanatory text and live implementation agree on the formulas above. Its source display uses `(b,a+c,a−c)`; ours differs by a rigid half-turn around the vertical axis.
- Research background: [*Algebraic Number Starscapes*](https://arxiv.org/abs/2008.07655), Edmund Harriss, Katherine E. Stange and Steve Trettel. The author/title metadata was verified; the full paper was not independently audited in this increment.
- The separate [L/R viewer](https://katestange.net/talks/math-exploration/viewers/farey-cf-lattice.html) remains the reference for the original Farey view and [Caroline Series’s coding](https://doi.org/10.1112/jlms/s2-31.1.69).

This is an independent finite explanatory implementation. No Stange JavaScript, meshes, media or screenshots are bundled. Public reference downloads and screenshots stay outside the repository. Source checksums are recorded in the evidence manifest. The point count, finite cone height, sphere sizes, colors, screen height, stationary oblique views and presentation tilt are our choices.

The separate `?talk=geo` sequence cuts the cone with a Lorentz plane to produce Farey geodesics. That bridge is **not implemented** in this increment; the two views are not claimed to share a selection. The interface switches between distinct coefficient and rational-pair states without converting one into the other.

## Try it

Native: `./scripts/run-simulator.sh --showcase` builds and opens the coefficient cone. **Next point** selects the deeper multiple. **Hide projection** shows only the spatial cloud; **Other side** and **Side view** give distinct oblique placements. **Reset** restores the first example. **Farey L/R** returns to the preserved rational-pair scene; **3D starscape** returns to coefficient space. **Exit** supports another entry. There is no automatic movement.

Browser: serve `WebXR/dist` using its `serve.py`, then open `/`. Use the same controls, click a source sphere, or enter an integer triple. Invalid, boundary-cone or out-of-bound input preserves the selection. `farey.html` is the separate legacy scene. The coefficient page starts fresh on reload; the Farey page retains its existing validated session state.

## Evidence and limits

See [coefficient-cone evidence](evidence/coefficient-cone/) for current results and representative views. Core tests check all 280 points, the quadratic roots, radial incidence, scalar multiples and an explicitly nonzero tetrahedron volume. Native renderer tests inspect actual RealityKit world positions; browser checks record actual Three.js positions and exercise a real pointer click. The browser walkthrough also checks portrait/landscape layout, invalid input, offline interaction, actual `WEBGL_lose_context` recovery and a deliberately mocked WebGL-unavailable fallback. Screenshots from different viewpoints show the same noncoplanar source object and its projection.

Simulator controls and desktop browser interaction do not establish physical headset comfort, GPU frame rate, WebXR session entry or controller operation. Tracking consent remains pending. Native sphere-tap automation and screen-reader speech remain unverified; native button-based selection and browser pointer selection are covered. The prior simulator screenshot/attachment capture inconsistency is not declared fixed by these successful captures.

The earlier performance audit was paused at the user’s priority correction, and its temporary simulator was removed. Its partial timing data is not a completed benchmark of this new scene.

## Next source-faithful increment

A useful next step is the Lorentz-plane bridge from the current Farey interval into coefficient space. For neighboring endpoints p/q and r/s, the form `(q t−p)(s t−r)` has coefficients `(qs,−(ps+qr),pr)` and discriminant `(ps−qr)²=1. Its Lorentz-orthogonal plane cuts the cone in the corresponding rational geodesic. This is a planned, separately testable link; the current software does not yet draw it.

Physical-headset interaction, immersive WebXR consent and GPU performance need their own authorized runtime checks. No upload or public deployment is included in this increment.

The final native regression run completed with **36/36 tests passing**, no failures or skips. Its disposable simulator was removed. The main simulator retained native 0.9.0 and the verified source-matching app binary.
