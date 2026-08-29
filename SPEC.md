# Hevea Vision Pro revival specification

Status: implementation baseline, 2026-08-29

## 1. Purpose

Revive the Hévéa project as a native Apple Vision Pro experience in which a person can inhabit, manipulate, and interrogate the geometry behind convex integration. The app should make the original work newly understandable while remaining useful to researchers: every stage has provenance, every numerical overlay states what it measures, and finite-resolution evidence is never promoted into a theorem or an exact limiting object.

The first release centers on the square flat torus because the original GPL source is public and auditable. The reduced sphere and hyperbolic-plane lines are preserved as follow-on exhibits, with their current open technical seams documented rather than silently approximated as official results.

## 2. Product promise

On launch, the user enters a quiet mathematical observatory containing a large suspended torus and three linked instruments:

- a **stage rail** that moves from the short torus of revolution through three finite corrugation stages;
- a **metric instrument** that contrasts intrinsic target lengths with ambient chord lengths and colors finite-mesh metric residual;
- a **C1 microscope** that reveals normal-vector variation across sampling scales and synchronizes selected normals with points on a Gauss sphere.

The torus is not a decorative model. It must be selectable, rotatable, scaled, sectioned, colored by diagnostics, and inspected from outside or within. The interface must explain what changed, why the corrugation was introduced, and which claims survive at the current resolution.

## 3. Provenance and claim contract

The application exposes a visible badge on every exhibit:

| Badge | Meaning | Allowed language |
|---|---|---|
| `UPSTREAM BASELINE` | Regenerated from pinned Hévéa GPL source with retained parameters and hashes | “Regenerated finite stage from upstream code” |
| `REAL-TIME PROXY` | Interactive lower-frequency construction created for explanation | “Illustrates corrugation direction/scale” |
| `HV EXPERIMENT` | New finite-resolution numerical analysis | “Observed on this mesh/configuration” |

Forbidden claims include:

- that any finite mesh is the limiting C1 isometric embedding;
- that a proxy preserves the flat metric unless a residual certificate demonstrates the stated tolerance;
- that simulator smoothness proves Vision Pro device performance, gesture quality, comfort, or accessibility;
- that a fitted scale exponent proves a Hausdorff or graph dimension theorem.

## 4. Core experience

### 4.1 Mission Control window

The primary SwiftUI window contains:

- a concise explanation of Hévéa and the current exhibit;
- a large “Enter Immersive Lab” control with explicit open/close state;
- stage, overlay, frequency-compression, and presentation controls mirrored into the immersive space;
- provenance and current claim ceiling;
- a compact research readout exportable as JSON in a later release.

### 4.2 Fully immersive lab

The app declares a full `ImmersiveSpace` and manages its lifecycle explicitly. It contains:

- a central torus at comfortable scale and distance;
- a parameter-domain floor grid showing the square with identified opposite edges;
- a Gauss sphere positioned to the user’s right;
- floating SwiftUI attachments for stage, legend, and selected-sample details;
- spatial audio only if it adds information; v0.1 has no required audio;
- an always-visible exit affordance and recovery when the immersive space is dismissed externally.

### 4.3 Interaction

- Spatial tap selects a surface sample and its parameter coordinates.
- Drag rotates the exhibit around its local origin.
- Magnify rescales within bounded limits.
- Stage controls change geometry deterministically.
- Overlay controls select material, parameter grid, metric residual, normal variation, or corrugation direction.
- “Inside view” moves the model around the observer rather than moving the simulated observer through collision geometry.
- A reset action restores a known camera/model state for reproducible screenshots.

## 5. Geometry architecture

`HeveaCore` is a platform-neutral Swift package. It owns:

- parameter-domain types and periodic indexing;
- mesh vertices, normals, UVs, triangle indices, and per-vertex scalar fields;
- the exact short torus of revolution;
- deterministic real-time proxy stages with explicit frequencies and amplitudes;
- finite-difference first fundamental form estimates;
- metric-residual, normal-variation, and curve-length diagnostics;
- JSON manifests for reproducibility.

`HeveaReality` bridges `HeveaCore` meshes into RealityKit `MeshResource` values and materials. The app target owns view state, immersion lifecycle, attachments, gestures, and simulator-only debug scenarios.

The runtime mesh budget for v0.1 is 65,536 vertices and 131,072 triangles per visible surface. Higher-resolution research inputs remain offline artifacts and are downsampled with a recorded policy.

## 6. Research extension: the scale microscope

### Question

Can a local, error-bounded level-of-detail instrument expose the normal-field scale structure of finite Hévéa stages without loading the full historical grid?

### v0.1 experiment

For a periodic mesh and selected parameter point `p`, sample unit normals at geodesic parameter offsets `h` over a geometric scale ladder. Record:

```text
omega(p, h) = max angle(n(p), n(q)) for q in the sampled h-neighborhood
```

Aggregate median and 95th-percentile `omega(h)` over a deterministic sample set. Fit a descriptive log-log slope over scales that pass sampling and boundary checks. Render the same samples on the torus and the Gauss sphere.

This is a numerical diagnostic. It does not establish fractal dimension or limiting regularity. The report must retain mesh stage, resolution, proxy/baseline class, frequencies, amplitude schedule, sample count, excluded scales, residual statistics, and code revision.

### Local-patch seam certificate

A generated high-detail patch records:

- boundary position mismatch against the parent LOD;
- boundary normal-angle mismatch;
- maximum and RMS first-fundamental-form residual;
- generation duration and vertex count.

The immersive app may show the patch only when its manifest parses and all numbers are finite. Failed thresholds remain visible as failed; the UI must not silently relabel the patch as certified.

## 7. Simulator acceptance matrix

The app is not considered demonstrated until automated build/tests and repeated UI scenarios cover:

1. clean install and first launch;
2. open full immersion, dismiss it, and reopen it;
3. cycle every stage in both directions;
4. toggle every overlay repeatedly;
5. rotate, scale to both bounds, reset, and select representative samples;
6. switch outside/inside presentation and recover;
7. background/foreground and relaunch;
8. run deterministic rapid-stage and rapid-overlay stress scenarios;
9. capture screenshots from stable named scenarios;
10. repeat on visionOS 26.5 and 27.0 when both runtimes are installed.

Build success alone satisfies none of the interaction or visual criteria.

## 8. Accessibility and comfort

- Controls use plain-language labels before specialist terms.
- Color overlays include numeric legends and do not rely on red/green alone.
- Motion is user-triggered, bounded, and can be disabled.
- Text attachments remain readable without requiring the user to approach the surface.
- The app avoids flashing and high angular-velocity automatic motion.
- Physical-device comfort and accessibility remain unverified until tested on Apple Vision Pro hardware.

## 9. Attribution and licensing

The repository is GPL-3.0-or-later and includes an attribution notice. Original website meshes are not committed while their redistribution license remains unclear. Baseline regeneration scripts pin the upstream revision and retain source headers, modification notices, parameters, and hashes.

## 10. Release gates

### v0.1 - Flat Torus Observatory

- native window and full immersive space;
- exact short torus plus three deterministic proxy stages;
- stage rail, grid, heatmap, normals, scale microscope, inside view, and reset;
- core unit tests and app state tests;
- repeatable simulator scenarios with README screenshots;
- public GitHub repository, research report, and upstream attribution.

### v0.2 - Authenticated baseline bridge

- bounded upstream regeneration pipeline;
- converted baseline manifests and local on-demand assets;
- comparison view between proxy and regenerated finite stage;
- no redistribution of ambiguous website meshes.

### v0.3 - Reduced sphere collaboration seam

- incorporate the authors’ published construction parameters and any later transition-function/source release;
- compare official and independent implementations only after provenance and numeric configurations match;
- keep the finite-stage/limit distinction explicit.

### Later research

- hyperbolic-plane Gauss-pattern experiments at rational and irrational radii;
- local history compression for visible-patch convex integration;
- controlled 2D-versus-spatial comprehension study;
- physical Vision Pro performance, gesture, and comfort validation.
