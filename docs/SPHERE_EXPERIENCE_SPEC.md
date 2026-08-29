# The inhabitable reduced sphere

Status: implementation specification for ALOK-846, 2026-08-29

## 1. Purpose

Turn the Hévéa reduced-sphere construction into a spatial place rather than a
model on a pedestal. A visitor must be able to:

- stand on the smooth south cap and walk into the corrugated equatorial belt;
- remain at a persistent intrinsic address while the local world re-anchors
  around them;
- rise above the surface without losing that address;
- enter the collapsed ball and read the surface from inside; and
- pull out to an atlas view that shows the whole reduced sphere beside the
  original unit sphere.

The mathematical experience is the transition of scale. At foot scale the
unit-sphere metric is the ruler. At atlas scale the containing ball is the
ruler. Those rulers cannot both remain literal when the reduction radius is
made infinitesimal, so every transition must identify the active gauge.

## 2. Source and claim boundary

The primary construction is:

> E. Bartzos, V. Borrelli, R. Denis, F. Lazarus, D. Rohmer, and B. Thibert,
> “An Explicit Isometric Reduction of the Unit Sphere into an Arbitrarily
> Small Ball,” *Foundations of Computational Mathematics* 18 (2018),
> 1015–1042. DOI: `10.1007/s10208-017-9360-1`.

The paper proves convergence of boundary-aware convex integration stages to a
`C1` isometric map. Its published renderings are a finite discretization of
`f_{1,3}`, not the limit `f_infinity`. The paper reports a `4000 x 20000` grid,
visible ridge counts `21`, `142`, and `997`, and a factor-two numerical
reduction. It does not print the degree-nine initial profile coefficients or a
complete infinite schedule of domains, target metrics, and corrugation
numbers.

The app therefore uses these claim classes:

| Object | Badge | Exact meaning |
|---|---|---|
| Round unit sphere and translated cap formula | `UPSTREAM BASELINE` | Exact standard formula printed in the paper |
| Independently adapted initial profile and compressed finite corrugations | `REAL-TIME PROXY` | Reproducible, paper-calibrated explanatory geometry; not the authors' hidden parameters and not `f_{1,3}` |
| Metric, normal, seam, navigation, and scale readouts | `HV EXPERIMENT` | Finite measurements on the displayed proxy |

The public Hévéa gallery images are CC BY-SA 2.0 France and have explicit
author credits. They may be linked or redistributed with that attribution and
share-alike notice. The downloadable WRL sphere meshes have no license stated
next to them; they are reference-only and must not be bundled. The community
`Juddd/hevea-reduced-sphere` implementation is GPL-3.0 and may be adapted with
its attribution and modification notice, but its fitted profile is itself a
constrained reconstruction, not an official coefficient release.

## 3. Geometry that the visitor inhabits

### 3.1 Exact decomposition

Use the paper's cylinder coordinates

```text
D = S1 x (-yInfinity, yInfinity)
h(x, y) = (cos(y) cos(x), cos(y) sin(x), sin(y)).
```

The north and south caps are translated copies of the round unit sphere. The
central ribbon is a surface of revolution

```text
f0(x, y) = (X(y) cos(x), X(y) sin(x), Z(y)).
```

The finite interactive proxy adds three corrugation families only on nested
central ribbons. Each family fades to exactly zero before its boundary. The
caps remain smooth. The proxy directions follow the three primitive forms
printed in the paper; their displayed frequencies are bounded compressions of
the reported `21 / 142 / 997` ridge counts.

### 3.2 Runtime mesh

- one vertex at each pole;
- `256` longitude samples and `127` non-polar latitude rings by default;
- no degenerate pole triangles;
- at most `32,514` vertices and `65,024` triangles;
- outward and inward readable material;
- deterministic topology, normals, UVs, proxy displacement, ribbon rank, and
  seam-residual fields;
- fail closed on non-finite values, inverted/degenerate faces above tolerance,
  broken cap seams, or a containing radius above the declared proxy bound.

No runtime level of detail may silently change the mathematical address. A
lower mesh density changes only the rendering/sample certificate.

### 3.3 Construction rail

The sphere rail is separate from the torus rail:

1. `Unit sphere` — source metric and an uncollapsed comparison shell.
2. `Short map` — translated caps plus the strictly short central ribbon.
3. `Family 1` — first finite proxy corrugation on the smallest ribbon.
4. `Family 2` — add the second direction on a larger ribbon.
5. `Family 3` — add the finest visible proxy on the largest ribbon.

The UI simultaneously shows the paper's ridge count and the rendered proxy
count. It must never imply that a compressed count regenerated the paper mesh.

## 4. Intrinsic address and locomotion

The authoritative location is not a RealityKit world-space vector. It is

```text
SphereAddress = (unit direction q in S2, signed altitude a, heading psi).
```

Walking updates `q` by the exponential map of the round unit sphere. If `v` is
a tangent step with length `s`,

```text
qNext = cos(s) q + sin(s) v/s.
```

This avoids longitude blow-up at the poles. Longitude/latitude are derived
readouts, not the state. The address wraps indefinitely and remains stable
when the visible world is re-anchored.

The proxy evaluator maps `q` to the displayed reduced-sphere position and
frame. In local modes the surface root is rotated so the proxy normal at `q`
is vertical and translated so that point remains under the visitor. This is a
mathematical treadmill: traversed intrinsic distance accumulates while
world-space coordinates stay bounded. Habitat and Hover therefore permit only
world-up yaw; arbitrary inspection pitch is reserved for Atlas and Interior,
where no gravity-up local-gauge invariant is claimed.

Simulator and accessibility controls provide discrete north/south/east/west
steps, heading changes, and a cap-to-equator guided walk. Physical-device
gesture and comfort claims remain pending until headset testing.

## 5. Four spatial regimes

### Habitat — on the surface

- fix intrinsic scale at a human-readable meters-per-unit value;
- place the current proxy point at the floor and align its normal with gravity;
- show a bounded local neighborhood with distant geometry fogged or clipped;
- make the accumulated intrinsic path length primary;
- surface corrugation is geometry, not a normal-map illusion.

### Hover — above the surface

- retain the same intrinsic address and heading;
- express altitude both in intrinsic units and local rendered wavelengths;
- allow bounded ascent/descent;
- keep a plumb line to the addressed point so “above” is never confused with
  changing latitude.

### Interior — in the collapsed ball

- place the observer inside a double-sided shell;
- retain the address as a highlighted point and normal on the shell;
- show the declared containing radius and the original unit-sphere ghost;
- motion is user-triggered and bounded.

### Atlas — around the whole sphere

- fit the complete reduced sphere in front of the visitor;
- optionally show the original unit sphere concentrically;
- expose reduction radius `r`, intrinsic diameter `pi`, ambient diameter
  `2r`, and the ratio `pi/(2r)`;
- enable rotation, sectioning, stage changes, and direct intrinsic address
  selection through walk, turn, altitude, reset, and named-route controls.

For v1, a tap on the rendered sphere does not select an address. That feature
is deferred until a RealityKit hit can be inverted to a typed source-sheet
identity. Ambient nearest-point selection is explicitly forbidden: folds that
are close in the containing ball can be far apart on the source sphere.

Regime changes are gauge changes, not claims that the camera traversed the
rendered distance at one fixed physical scale.

## 6. The infinite-distance issue

For every standard `r > 0`, the paper's limit preserves the finite intrinsic
distances of the unit sphere while its image fits inside `B_r`. The largest
intrinsic distance remains `pi`; what becomes unbounded as `r -> 0` is the
ratio between intrinsic distance and ambient chord scale.

In nonstandard analysis, transfer permits a positive infinitesimal radius
`epsilon` and an internal isometric sphere inside `*B_epsilon`. Its positions
all have the same standard part, even though every positive-length standard
path retains its standard intrinsic length internally. Consequently a single
standard-part picture cannot be
both a global collapsed view and a locally walkable world. The app responds
with two coordinated representations:

- a persistent intrinsic address plus local blow-up chart for living/walking;
- a finite atlas gauge for the global collapsed image.

The app must label this as a nonstandard-analysis interpretation, not as a
theorem stated by the Hévéa authors.

## 7. Public interface

Mission Control gains an exhibit switcher (`Flat torus` / `Reduced sphere`).
The sphere card contains:

- construction rail and visible proxy/paper frequency pair;
- regime picker (`Habitat`, `Hover`, `Interior`, `Atlas`);
- address, altitude, traversed intrinsic distance, and reduction-ratio readout;
- walk pad and `Walk cap to equator` route;
- source/claim badge and a one-sentence claim ceiling;
- link to the original paper, gallery, and the public NSA companion.

The immersive HUD keeps exit/reset controls visible in every regime. A gauge
legend states which length scale is fixed. No red/green-only encoding is
allowed.

## 8. Verification gates

### Core

- exact cap endpoint positions and first derivatives;
- closed oriented genus-zero topology with Euler characteristic `2`;
- deterministic hashes for a fixed configuration;
- cap/ribbon positional and normal seam bounds;
- nested ribbon activation and zero displacement on caps;
- navigation exponential-map norm preservation, pole crossing, wrapping, and
  long-run bounded state;
- finite containing radius and no non-finite values;
- explicit paper/rendered ridge-count metadata.

### App and simulator

- switch torus/sphere repeatedly without stale geometry;
- visit all five sphere construction stages;
- visit all four regimes and return to the identical intrinsic address;
- run at least `1,000` navigation steps and `200` geometry/regime changes;
- expose a rendered-stage/revision/fingerprint receipt only after the matching
  entity is installed; screenshots must wait for that receipt and reject a
  generation-error witness;
- serialize and cancel superseded geometry work so stage spam converges to the
  latest request without accumulating detached generators;
- expose a presentation receipt only after the matching RealityKit transform
  is applied, and acknowledge each step in the `500`-step live walk-pad run;
- cap-to-equator route visibly changes ribbon rank in the correct order;
- atlas, habitat, hover, and interior named screenshots;
- clean launch, immersion dismissal/reopen, background/foreground, and reset;
- test every installed stable and beta visionOS simulator while keeping visual
  deltas and physical-device claims separate.

## 9. Research companion

The canonical writeup is a newly worded, equation-indexed reconstruction of
the paper, optimized for Alok as the sole intended reader but safe to publish.
It must contain:

1. a one-page dependency spine;
2. a faithful theorem/proof map for Sections 2–10;
3. a nonstandard dictionary and hyperfinite reformulation;
4. a proof-obligation ledger separating transfer-equivalent results from new
   claims;
5. the infinitesimal-radius collapse theorem and its app consequence;
6. formalization hooks stated as types/lemmas rather than vague suggestions;
7. source URLs, page/equation anchors, hashes, and licensing notes.

The writeup may restate mathematical formulas and facts. It must not reproduce
the copyrighted article's prose or figures except under a separately valid
license.

## 10. Release boundary

This release can claim a native, inhabitable, paper-calibrated reduced-sphere
proxy with deterministic simulator evidence and a rigorous NSA research
companion. It cannot claim:

- regeneration of the authors' unpublished coefficients;
- display of the exact `f_{1,3}` mesh or the limiting `f_infinity`;
- proof that a finite mesh is isometric;
- physical Vision Pro comfort, collision, or gesture validation; or
- that standard part preserves the infinitesimal-radius internal embedding.
