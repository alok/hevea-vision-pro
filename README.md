# Hevea Vision Pro

An unofficial, open-source revival of the [Hévéa project](https://hevea-project.fr/): a native Apple Vision Pro observatory for the flat torus, convex integration, metric defect, and C1-fractal scale structure.

This repository is at its first public specification checkpoint. The app implementation and simulator screenshots are landing as separately verified commits.

## Why revive it?

The Hévéa team turned the Nash-Kuiper existence phenomenon into an explicit computation and produced the first visualizations of a C1 isometric square flat torus in three-dimensional space. Their work showed that visualization can uncover mathematics: the finite corrugations led to a Gauss-map description with fractal behavior even though the limiting surface remains continuously differentiable.

Vision Pro offers a different way to encounter that result. The goal here is not to place an old mesh in a headset. It is to let a person move through the stages, compare intrinsic and ambient measurements, inspect normals across scales, and see exactly where an explanatory model ends and a numerical result begins.

## Current scope

- Native visionOS window and fully immersive lab
- Stage-by-stage flat-torus construction
- Parameter grid, metric-residual heatmap, and intrinsic-versus-ambient rulers
- C1 scale microscope synchronized with a Gauss sphere
- Deterministic simulator stress scenarios and retained screenshots
- Reproducible, provenance-aware research manifests

Read [SPEC.md](SPEC.md), [upstream source map](docs/UPSTREAM.md), and [simulator matrix](docs/SIMULATOR_MATRIX.md) for the exact contract.

## Honesty labels

The app distinguishes an upstream regenerated finite stage, a lower-frequency real-time explanatory proxy, and a new Hevea Vision numerical experiment. A finite mesh is never called the limiting C1 isometric embedding, and simulator results are never called headset validation.

## Attribution

The original flat-torus code was written by Vincent Borrelli, Saïd Jabrane, Francis Lazarus, and Boris Thibert. See [NOTICE.md](NOTICE.md) and the primary paper, [“Flat tori in three-dimensional space and convex integration”](https://doi.org/10.1073/pnas.1118478109).

Licensed under GNU GPL version 3.0. This is an unofficial tribute and is not endorsed by the original researchers or their institutions.
