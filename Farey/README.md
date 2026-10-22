# Farey — Into the Infinite

[Current browser 0.12.1 XR verification](XR_SIMULATION.md) · [Browser 0.12.0 packaging audit](BROWSER_012_READINESS.md) · [Double cone, Origin and cutting planes](DOUBLE_CONE.md). Native remains 0.9.0; [its coefficient-cone guide](COEFFICIENT_CONE.md) records the separate simulator evidence. [Previous release-candidate readiness](READER_READINESS.md) — native 0.8.1 / browser 0.7.4. [Precision notice](PRECISION_NOTICE.md). [Safari and compact-view audit](MOBILE_SAFARI.md). [Lifecycle capture audit](LIFECYCLE_CAPTURE_AUDIT.md) · [Native integration check](INTEGRATION_08.md). [Crowded projected selection](PROJECTED_SELECTION.md). [Source-fidelity audit](SOURCE_FIDELITY.md). [Optional boundary-to-lattice construction](CONSTRUCTION.md). [Previous release audit](DEMO_READINESS.md). [Recorded demonstration outline](DEMONSTRATION_OUTLINE.md).

[Independent mathematical consistency audit](MATHEMATICAL_AUDIT.md): exact rational state agrees across implementations; very close deep disk curves can merge at display precision. Read exact fractions when interpreting overlapping arcs.

[Native deep-path rendering follow-up](NATIVE_PRECISION_AUDIT.md): isolated simulator screenshots, generated-mesh checks and the unresolved capture limitation.

**Inspired by [Katherine Stange’s mathematical visualizations](https://www.katestange.net/code/) and her [Illustrating Mathematics for Math 2.0 talk](https://katestange.net/talks/math-exploration/).** Underlying L/R geodesic coding: [Caroline Series (1985)](https://doi.org/10.1112/jlms/s2-31.1.69).

The native default scene is the noncoplanar **coefficient lattice** from Stange’s Starscape / Lattice construction: 280 integer triples `(a,b,c)` inside the discriminant cone, alongside their radial projection onto a Klein disk. Selecting `(1,−1,2)` then its multiple `(2,−2,4)` changes the spatial point while keeping the projected point and quadratic root fixed. A stationary oblique view exposes depth immediately. The immersive surroundings are black.

The browser now leads with a signed coefficient lattice, a double cone and an **Inhabit** mode; see [the browser-first update](DOUBLE_CONE.md).

The separate **Farey L/R** view retains the rational-pair lattice, mediants and linked Poincaré disk. That lattice is intrinsically planar; the new coefficient scene does not relabel it as a three-dimensional lattice. See [exact formulas and evidence](COEFFICIENT_CONE.md).

## Run on this Mac

The native route requires macOS, Xcode with a visionOS simulator runtime, and XcodeGen at `/opt/homebrew/bin/xcodegen`. This Mac was checked with Xcode 27.2 beta 2, visionOS 27.2 and XcodeGen 2.46.0. For a reader on another computer, the [browser package](WebXR/README.md) is the simpler starting point and does not need Xcode.

```sh
cd /Users/alokbeniwal/Documents/Codex/2026-10-21/task-7/FareyVision/Farey
./scripts/run-simulator.sh
```

This generates the checked-in XcodeGen project, builds Release with three jobs, boots the existing simulator if needed, installs the app, and opens Device Hub. Select **Apple Vision Pro — Simulator**, then **Enter the void**. The app's displayed name is **Farey — Into the Infinite**.

The scripts first copy the source and build specification into a fresh `/tmp/farey-build-*` directory. This avoids stalled reads and Finder metadata in the synced Documents checkout. To open the default coefficient-cone scene directly for inspection, run `./scripts/run-simulator.sh --showcase`. This uses a Debug-only launch option; ordinary launches still start at the entry window.

On another configured Mac, select a visionOS simulator with `xcrun simctl list devices available`, then pass its identifier as `SIMULATOR_UDID=YOUR_ID ./scripts/run-simulator.sh`. The default identifier above is specific to this Mac. The script builds, installs and opens the app; it is not a read-only check.

The [browser/WebXR companion](WebXR/README.md) uses the same exact lattice and L/R convention. It has desktop orbit, sphere selection, finite grid controls and an immersive-VR entry path. Desktop behavior is verified; actual headset WebXR sessions remain untested.

For a first visit, enter the void and inspect the 3D coefficient cloud. **Next point** selects a scalar multiple at a different depth; **Hide projection** reveals the cloud alone. **Other side** changes the view without animation. **Farey L/R** switches to the previous rational-pair scene. There, choose **3/5 example**, then press **L**. The selected fraction becomes **5/8**, between **3/5** and **2/3**. **Undo** returns to **3/5**; **Reset** returns to **1/1**. **Learn** guides a different path, starting at **1/2**. **Exit** returns to the launch window. The launch preview is a perspective sketch; the entered space uses actual 3D RealityKit entities.

Xcode 27.2 beta 2 and visionOS 27.2 are installed; the simulator is `D2ECE520-ED92-4A38-A990-AE65431DF562`. Xcode 27 uses Device Hub. In its normal interaction mode, click a control or sphere. For simulator camera navigation, release captured input with Escape, then use A/D for sideways motion and W/S for forward/backward; Reset Camera restores the view. See [Apple's Device Hub controls](https://developer.apple.com/documentation/xcode/interacting-with-your-visionos-app-in-device-hub).

## Explore the Farey L/R view

- Tap a lattice sphere or a floating rational label to select its positive rational p/q, including reducible pairs such as 6/10.
- **Inspect** below the geometry hint explains the actual selected point: `(10,6) = 2 × (5,3)`, `gcd(10,6) = 2`, and `6/10 = 3/5`. The point remains distinct from its reduced direction across lattice/disk switches and immersive re-entry. White marks a non-primitive inspected point; orange marks the primitive mediant. L/R, Undo and Reset choose a new direction and clear the previous point identity.
- **Convergents / mediants** explains the selected rational's finite continued fraction. Gold rings mark convergents of the chosen expansion; gray rings mark other visited L/R mediants. The toggle compares canonical form with the equivalent form ending in 1 without changing the rational, inspected point, L/R path or lesson. The same markings appear in the lattice and disk. Reset restores canonical form.
- Tap an approximant row to **spotlight** it with double white rings. The native panel closes so it cannot cover the marker; reopen it to choose another row or expansion. Spotlighting does not change the target rational, inspected point or lesson prediction. A target change clears the spotlight; an expansion change keeps it only while that row remains. Grid changes retain its coordinates and explicitly report an out-of-grid point. **Clear** removes only the spotlight; **Reset** clears it and restores the demo.
- **p/q** opens direct entry. Positive numerator and denominator values must each be at most 1000 before reduction, and the exact path must fit within 24 moves. `6/10` selects `3/5`; invalid, zero, negative, overflow and over-limit entries leave the current selection and lesson intact. Selection rebuilds the L/R path, so Undo removes its last move.
- **Learn** opens a worked path: predict and apply L at 1/2 to reach 2/3, then R to reach 3/5. Its vector explanation and linked disk use the same selected state.
- **L** and **R** update the exact interval. **Undo** reverses one step. **3/5 example** reproduces the selected fraction used in our reference inspection.
- The **green plane** contains the ray through (q,p). Every green lattice sphere is an exact integer multiple of the primitive direction. Cyan/purple edges form the neighbor-vector parallelogram; its orange diagonal reaches the primitive mediant.
- **Space: Lattice / Disk** switches the spatial representation while preserving the same rational and matrix.
- **Front / Left / Right** provide camera-equivalent translations of the lattice relative to a stationary viewer, making depth and parallax inspectable without forced camera motion.
- Grid controls bound the visible integer patch. If the primitive vector lies beyond that patch, the direction plane remains visible and the controls say so.
- **Reset** restores the initial interval, grid, lattice view and front placement. **Exit** returns to the entry window, ready for another session.

## Mathematics and source boundary

The coefficient-cone formulas and their provenance are in [the new scene guide](COEFFICIENT_CONE.md). The remainder of this section describes the separate Farey L/R view.

Before this revision, we ran the [exact L/R viewer embedded in Stange's slides](https://katestange.net/talks/math-exploration/viewers/farey-cf-lattice.html) in a browser. Selecting 3/5 showed R L R² acting on (1,0)^T. The Tessellation, Dots, Lattice and Labels stages link a rational to the integer point (q,p) and its vertical direction plane; dragging changes the spatial view. We also inspected the separate [Farey Hyperboloid](https://www.katestange.net/farey-hyperboloid/) companion, which links a ruled q=1 surface to geodesics. This version implements the talk's lattice construction; the hyperboloid is reference material for a separate representation.

All new Swift mathematics and rendering code is original. No Stange source code or media is bundled. Reference screenshots are retained outside the repository, separately from app evidence; no redistribution license for the original demo is presumed. This is an independent implementation, not an official port or endorsement. New code follows the parent repository's GPL-3.0-or-later license.

M starts at the identity, with columns right=(a,c) and left=(b,d). The interval is b/d < (a+b)/(c+d) < a/c, with infinity allowed:

```
L = [1 1; 0 1]    R = [1 0; 1 1]
M ← M L          M ← M R
```

L replaces the left column by the mediant, and R replaces the right column. Every step preserves ad−bc=1. This app displays the current mediant M(1). The original reference's endpoint word appends R to place that same fraction in M(∞): our interval word RLR selects 3/5, while RLRR sends (1,0)^T to (3,5)^T. These conventions are stated explicitly rather than conflated.

The lattice is a rigidly placed copy of Z²: (q,p) is mapped to a physical plane by uniform scale and rotation. Its direction plane is perpendicular to the lattice and passes through the origin; the drawn patch extends to the grid boundary along the selected ray. Positive scalar multiples share this ray, plane and disk boundary point, while their lattice locations differ. The parallelogram is ordinary vector addition (q₁,p₁)+(q₂,p₂), and its integer area is one for neighboring Farey endpoints. Sphere radii, colors, physical placement and the finite plane height are presentation choices. Axis points represent 0 and ∞ and remain non-selectable boundaries in this positive-rational interface.

The disk places p/q at (2pq/(p²+q²), (p²−q²)/(p²+q²)), joining Farey neighbors by sampled circular arcs orthogonal to the boundary. It is a finite tessellation, not the infinite object or a reconstructed Stange fractal.

A convergent is a truncation of the selected continued fraction ([definition and recurrence](https://dlmf.nist.gov/1.12.ii)). Canonical finite simple expansions end in a term at least 2, except for integers; replacing a final term `a` by `a−1, 1` gives the same rational but can change the convergent list. For `3/5`, canonical `[0;1,1,2]` has convergents `0/1, 1/1, 1/2, 3/5`; the visited `2/3` is an intermediate mediant. It becomes a convergent in `[0;1,1,1,1]`. The boundary `0/1` may be a convergent even though this interface only selects positive rationals. Rings identify primitive points, not every scalar multiple. Ring size and color are annotations, not geometric claims.

Stange's endpoint word uses the even-length expansion so its final block is R. Our interval word still displays M(1); appending R sends M(∞) to that same rational. Choosing the other expansion for labeling does not rewrite the stored interval word.

## Bounds and verification

Navigation is capped at 24 moves. The lattice grid spans 0…2×detail on each axis, with detail 3…7: at most 224 nonzero points and 196 selectable positive pairs. Sphere meshes are shared. Static lattice geometry rebuilds only when its bounds change; selection changes recolor points and rebuild a small plane and vector overlay. The disk retains its 509-edge cap. There is no per-frame geometry generation.

```sh
swift test --package-path Packages/FareyCore --scratch-path .build-core --jobs 3
./scripts/test-simulator.sh
python3 scripts/capture-tests.py
```

The capture helper creates an isolated simulator and records synchronized still images. Use `python3 scripts/record-demo.py --output /tmp/farey-video-new` for a separate video-only tour. See the [capture audit](LIFECYCLE_CAPTURE_AUDIT.md) for precise limitations.

For optimized simulator tests, add `-configuration Release ENABLE_TESTABILITY=YES ONLY_ACTIVE_ARCH=YES` to the xcodebuild test command. Testability is needed by the model test's internal-module import; the ordinary Release build does not require it.

See [simulator evidence](evidence/README.md). The controls use a pushed native window that preserves the entry scene. Every immersive session gets a fresh scene identity, and geometry waits for entry to complete. The original Hévéa target and unrelated work remain unchanged.

## Existing hardware signing

The device target uses development team `5795ZPYZ2T` and the already-installed wildcard profile **Lean Calculator Vision Pro 20261008** (expires 2027-10-08). Its certificate matches the installed development identity, its wildcard covers `com.alok.FareyVision`, and it includes the paired Vision Pro. No new certificate, app identifier or provisioning profile was created. These device-only settings do not change the unsigned simulator workflow.

A signed Release build of native 0.8 and strict signature verification succeeded on 2026-10-22. Use a local temporary build directory to avoid Finder metadata being attached to generated app bundles in the synced Documents workspace:

```sh
build_root="$(python3 scripts/prepare-local-build.py)"
xcodebuild -project "$build_root/FareyVision.xcodeproj" -scheme FareyVision \
  -configuration Release -destination 'generic/platform=visionOS' \
  -derivedDataPath /tmp/FareyVision-device -jobs 3 build
codesign --verify --deep --strict /tmp/FareyVision-device/Build/Products/Release-xros/FareyVision.app
```

The paired headset reports visionOS 27.2 and Developer Mode enabled. On 2026-10-22, both a read-only device-details query and an installed-app query succeeded; the earlier locked-device blocker did not recur. No installation or hardware execution has been performed. After unlocking, obtain its identifier with `xcrun devicectl list devices`, then run:

```sh
xcrun devicectl device install app --device YOUR_VISION_PRO_IDENTIFIER \
  /tmp/FareyVision-device/Build/Products/Release-xros/FareyVision.app
```
