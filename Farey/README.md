# Farey — Into the Infinite

**Inspired by [Katherine Stange’s mathematical visualizations](https://www.katestange.net/code/) and her [Illustrating Mathematics for Math 2.0 talk](https://katestange.net/talks/math-exploration/).** Underlying L/R geodesic coding: [Caroline Series (1985)](https://doi.org/10.1112/jlms/s2-31.1.69).

A native visionOS experience of the integer lattice behind the Farey tessellation. Shaded spheres occupy actual integer coordinates in space; a translucent plane follows the selected rational direction, and a parallelogram shows how the mediant adds two integer vectors. The linked Poincaré disk uses the same exact state. The surrounding immersive space is fully black. The viewer is stationary by default.

## Run on this Mac

```sh
cd /Users/alokbeniwal/Documents/Codex/2026-10-21/task-7/FareyVision/Farey
./scripts/run-simulator.sh
```

This generates the checked-in XcodeGen project, builds Release with three jobs, boots the existing simulator if needed, installs the app, and opens Device Hub. Select **Apple Vision Pro — Simulator**, then **Enter the void**. The app's displayed name is **Farey — Into the Infinite**.

The scripts first copy the source and build specification into a fresh `/tmp/farey-build-*` directory. This avoids stalled reads and Finder metadata in the synced Documents checkout. To open the 3/5 lattice scene directly for inspection, run `./scripts/run-simulator.sh --showcase`. This uses a Debug-only launch option; ordinary launches still start at the entry window.

The [browser/WebXR companion](WebXR/README.md) uses the same exact lattice and L/R convention. It has desktop orbit, sphere selection, finite grid controls and an immersive-VR entry path. Desktop behavior is verified; actual headset WebXR sessions remain untested.

Xcode 27.2 beta 2 and visionOS 27.2 are installed; the simulator is `D2ECE520-ED92-4A38-A990-AE65431DF562`. Xcode 27 uses Device Hub. In its normal interaction mode, click a control or sphere. For simulator camera navigation, release captured input with Escape, then use A/D for sideways motion and W/S for forward/backward; Reset Camera restores the view. See [Apple's Device Hub controls](https://developer.apple.com/documentation/xcode/interacting-with-your-visionos-app-in-device-hub).

## Explore

- Tap a lattice sphere or a floating rational label to select its positive rational p/q, including reducible pairs such as 6/10.
- **L** and **R** update the exact interval. **Undo** reverses one step. **3/5 example** reproduces the selected fraction used in our reference inspection.
- The **green plane** contains the ray through (q,p). Every green lattice sphere is an exact integer multiple of that direction. The orange point is the primitive mediant; orange edges form its vector-addition parallelogram.
- **Space: Lattice / Disk** switches the spatial representation while preserving the same rational and matrix.
- **Front / Left / Right** provide camera-equivalent translations of the lattice relative to a stationary viewer, making depth and parallax inspectable without forced camera motion.
- Grid controls bound the visible integer patch. If the primitive vector lies beyond that patch, the direction plane remains visible and the controls say so.
- **Reset** restores the initial interval, grid, lattice view and front placement. **Exit** returns to the entry window, ready for another session.

## Mathematics and source boundary

Before this revision, we ran the [exact L/R viewer embedded in Stange's slides](https://katestange.net/talks/math-exploration/viewers/farey-cf-lattice.html) in a browser. Selecting 3/5 showed R L R² acting on (1,0)^T. The Tessellation, Dots, Lattice and Labels stages link a rational to the integer point (q,p) and its vertical direction plane; dragging changes the spatial view. We also inspected the separate [Farey Hyperboloid](https://www.katestange.net/farey-hyperboloid/) companion, which links a ruled q=1 surface to geodesics. This version implements the talk's lattice construction; the hyperboloid is reference material for a separate representation.

All new Swift mathematics and rendering code is original. No Stange source code or media is bundled. Reference screenshots are retained outside the repository, separately from app evidence; no redistribution license for the original demo is presumed. This is an independent implementation, not an official port or endorsement. New code follows the parent repository's GPL-3.0-or-later license.

M starts at the identity, with columns right=(a,c) and left=(b,d). The interval is b/d < (a+b)/(c+d) < a/c, with infinity allowed:

```
L = [1 1; 0 1]    R = [1 0; 1 1]
M ← M L          M ← M R
```

L replaces the left column by the mediant, and R replaces the right column. Every step preserves ad−bc=1. This app displays the current mediant M(1). The original reference's endpoint word appends R to place that same fraction in M(∞): our interval word RLR selects 3/5, while RLRR sends (1,0)^T to (3,5)^T. These conventions are stated explicitly rather than conflated.

The lattice is a rigidly placed copy of Z²: (q,p) is mapped to a physical plane by uniform scale and rotation. Its direction plane is perpendicular to the lattice and passes through the origin. The parallelogram is ordinary vector addition (q₁,p₁)+(q₂,p₂), and its integer area is one for neighboring Farey endpoints. Sphere radii, colors, physical placement and the finite plane height are presentation choices.

The disk places p/q at (2pq/(p²+q²), (p²−q²)/(p²+q²)), joining Farey neighbors by sampled circular arcs orthogonal to the boundary. It is a finite tessellation, not the infinite object or a reconstructed Stange fractal.

## Bounds and verification

Navigation is capped at 24 moves. The lattice grid spans 0…2×detail on each axis, with detail 3…7: at most 224 nonzero points and 196 selectable positive pairs. Sphere meshes are shared. Static lattice geometry rebuilds only when its bounds change; selection changes recolor points and rebuild a small plane and vector overlay. The disk retains its 509-edge cap. There is no per-frame geometry generation.

```sh
swift test --package-path Packages/FareyCore --scratch-path .build-core --jobs 3
./scripts/test-simulator.sh
python3 scripts/capture-tests.py
```

For optimized simulator tests, add `-configuration Release ENABLE_TESTABILITY=YES ONLY_ACTIVE_ARCH=YES` to the xcodebuild test command. Testability is needed by the model test's internal-module import; the ordinary Release build does not require it.

See [simulator evidence](evidence/README.md). The controls use a pushed native window that preserves the entry scene. Every immersive session gets a fresh scene identity, and geometry waits for entry to complete. The original Hévéa target and unrelated work remain unchanged.

## Existing hardware signing

The device target uses development team `5795ZPYZ2T` and the already-installed wildcard profile **Lean Calculator Vision Pro 20261008** (expires 2027-10-08). Its certificate matches the installed development identity, its wildcard covers `com.alok.FareyVision`, and it includes the paired Vision Pro. No new certificate, app identifier or provisioning profile was created. These device-only settings do not change the unsigned simulator workflow.

A signed Release build of the spatial revision and strict signature verification succeeded on 2026-10-22. Use a local temporary build directory to avoid Finder metadata being attached to generated app bundles in the synced Documents workspace:

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
