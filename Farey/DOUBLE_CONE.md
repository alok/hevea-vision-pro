# Browser-first double cone and Inhabit

Browser 0.9.0 extends the earlier upper-cone scene. Native 0.9.0 still has the upper-cone projection view documented in [COEFFICIENT_CONE.md](COEFFICIENT_CONE.md); it does not yet have this signed-lattice or Inhabit mode.

## What is visible

The browser starts in a stationary oblique overview of the **signed integer coefficient lattice** and both halves of `b²−4ac=0`. The display coordinates remain `(-b,a+c,c−a)`, so the round cone is `x²+z²=y²`. Points satisfy `x²+y²+z²≤R²`, with the zero triple omitted. They are transformed integer triples, not arbitrary integer points in display coordinates.

At default radius 6 there are 480 points: 55 in each cone interior, 24 on the null cone and 346 outside. Radius 12 caps the set at 3,608 points. Instanced meshes render the source cloud; the measured default/max overview used 10 draw calls. This is a geometry count, not a GPU frame-rate or headset-performance measurement.

The color categories follow Stange’s reference: positive interior colored by the actual discriminant, negative interior gray, exterior blue and null forms gold. **Color lower half too** is explicitly our extension. Since browser 0.10.0 the upper palette uses the source’s six dark-theme anchors with OKLab interpolation over her fixed logarithmic |Δ| range 3–240. The default **Contrast** categories are our choice: the null color is ivory instead of gold, because the gold anchor is also an interior color, and exterior blue is slightly deepened; **Stange reference** restores gold, blue and gray. Her viewer derives its category colors from OKLCH lightness and chroma, and those exact values are not verified here. Points are flat unlit discs whose radius stays between 1.25 and 3 CSS pixels; their centers are exact, and a click selects the nearest center within about 10 pixels. Our symmetric cone height and origin-centered finite crop also differ from the reference’s asymmetric framing. These presentation choices are not attributed to her as exact behavior.

**Whole coefficient lattice** switches between the signed ball and its positive interior. **Show double cone** controls the surface. **Project to Klein disk** is off initially, avoiding an extra plane in the overview. Negative interior forms are sign-flipped before projection to the positive screen: a polynomial and its negative have the same roots. Exterior forms have real roots and do not enter this Klein disk. Null forms lie on the discriminant boundary; when `a=0`, the repeated root is at infinity in homogeneous coordinates.

## Inhabit

**Inhabit** moves the eye near the selected visible coefficient point. Drag to look, W/A/S/D to move, Q/E to move down/up; onscreen buttons perform the same discrete translations. The readout shows Euclidean display coordinates and the camera orientation as ordered rotation angles in the oriented display planes ZX (e_z∧e_x), YZ (e_y∧e_z) and XY (e_x∧e_y), with C = R_ZX R_YZ R_XY (Three.js Euler YXZ). **Return to overview** restores the previous camera and target. **Reset** restores the default crop, colors, selection and overview.

This is ambient Euclidean navigation in three-dimensional coefficient space. It is not intrinsic hyperbolic navigation, a Flatland simulation, or a claim that Euclidean distances equal hyperbolic distances. Entering is an explicit action; there is no automatic motion. Changing the crop while inside does not move the eye.

## Comparison and provenance

The live reference is [Stange’s whole-lattice scene](https://katestange.net/starscape-lattice/#lm=1&c=1&sc=0&p=0&cp=1). Its [talk](https://katestange.net/talks/math-exploration/#/starscape-cone) and [Starscape / Lattice viewer](https://www.katestange.net/starscape-lattice/) explain the coefficient-to-root map. Research background is [Harriss, Stange and Trettel, *Algebraic Number Starscapes*](https://arxiv.org/abs/2008.07655). The separate Farey L/R page retains the Caroline Series citation. No reference code or media is bundled.

Our browser supports orbit, selection, crop, cone/whole-lattice visibility, optional projection and Inhabit. It does not yet implement Stange’s full SL₂ action, discriminant shells, general geodesic planes, or continuous Klein–Poincaré–half-plane morph. Those are distinct future work, not claims of this release.

## Verification

`WebXR/starscape-checks.js` exercises actual point clicking, all color categories, the maximum crop, upper-only filtering, negative-form projection, entering the cloud, button/keyboard translations, fixed-eye mouse look, parallax and exact overview return. It also exercises real `WEBGL_lose_context` loss/recovery and portrait/landscape layouts. The core tests check the signed coefficient set, sign pairing and shared projections. See [evidence](evidence/double-cone/).

These are desktop-browser checks. Immersive WebXR sessions, physical headset input, GPU frame rate, touch behavior while inhabiting and screen-reader speech remain unverified. Tracking consent, uploads and public deployment remain outside this completed work.

## Bounded design review

Three consequential mismatches drove this change: the missing signed half of the coefficient scene; an overview-only camera with no way to inhabit it; and navigation that needed explicit keyboard focus and stable camera state while changing parameters. The implemented journey is open → inspect categories → Inhabit → move/look → change radius → return → reset. Checks cover immediate keyboard focus, fixed-eye look, no camera jump on an inside radius change, and exact restoration of the overview.

The source and this demo share the coefficient equations and sign categories. Their finite crops, cone extent, framing and color interpolation differ as described above; screenshots at similar viewport sizes are not presented as pixel-identical reconstructions. No extra UI installation or OS permission change was needed.

The browser 0.9.0 checkpoint is commit `cbaeeed` on `codex/farey-void-demo`; its local package is `WebXR/output/Farey-WebXR-0.9.0.zip`. Native 0.9.0 passed its complete 36-test simulator suite independently of the newer browser-only features.
