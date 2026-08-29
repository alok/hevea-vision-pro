# Hévéa Vision finite-mesh scale microscope

> **HV EXPERIMENT — finite meshes only.** Finite deterministic meshes and descriptive numerical diagnostics only. This report does not certify isometry, reproduce the upstream corrugation algorithm, identify a limiting C1 embedding, estimate a theorem-level fractal dimension, or establish limiting regularity.

This report is a reproducible numerical extension of the Hévéa flat-torus exhibit. It asks what the app's bounded meshes reveal about metric residuals, two fundamental winding curves, and normal-field variation across a finite scale ladder. It does not replace the original construction or papers.

## Reproducibility receipt

| Field | Value |
|---|---|
| Experiment label | `HV EXPERIMENT` |
| Report schema | `1` |
| Report baseline | `2026-08-29` |
| Build configuration | `release` |
| HeveaCore revision | `68202cae55a59a71b1573c869a05ac82b87c7ee2` |
| Upstream project | [Hévéa](https://hevea-project.fr/) |
| Upstream source | [repository](https://github.com/HeveaProject/Hevea) at `e792074e4dd6319351bc957afeb16b4725d304f0` |
| Adapted upstream path | `torus/v0r1m2/include/TOR_implementation.h` |
| License | `GPL-3.0-or-later` |

The `UPSTREAM BASELINE` label below applies only to the regenerated short-torus starting surface. Every diagnostic and every fitted slope in this report remains an `HV EXPERIMENT`.

## Exact run configuration

- Periodic grid: `96 × 128` = `12288` vertices and `24576` triangles per stage.
- Short-torus radii: minor `0.2`, major `0.5`; the implementation scales the formula by `1/(2π)`.
- Stages: `shortTorus`, `proxyStage1`, `proxyStage2`, `proxyStage3`.
- Normal scales requested: `1, 2, 4, 8, 16, 32, 64` grid steps; samples: `256`; deterministic seed: `0x48455645415F5631`.
- Winding basepoint: `(u, v) = (0.1375, 0.28125)`; `2048` interpolated segments per curve.

### Real-time proxy schedule

| Added stage | Lattice direction | Proxy frequency | Proxy amplitude | Upstream reference frequency |
|---|---:|---:|---:|---:|
| REAL-TIME PROXY 1 — u Corrugation | `u` | 5 | 0.012 | 12 |
| REAL-TIME PROXY 2 — u + 2v Corrugation | `1u + 2v` | 8 | 0.006 | 80 |
| REAL-TIME PROXY 3 — u - 2v Corrugation | `1u - 2v` | 13 | 0.0035 | 500 |

The proxy frequencies and amplitudes are deliberately compressed for interaction. They do not reproduce the upstream oscillatory corrugations.

## Methods

1. **Finite metric residual.** At each periodic grid vertex, use wrapped central finite differences to form E=<du f,du f>, F=<du f,dv f>, G=<dv f,dv f>; report sqrt((E-1)^2+2F^2+(G-1)^2) against du^2+dv^2.
2. **Fundamental winding curves.** Sample one full u winding and one full v winding from a fixed off-grid basepoint with periodic bilinear mesh interpolation; compare ambient polyline length and endpoint chord with unit intrinsic target length.
3. **Normal scale microscope.** For deterministic sampled vertices and each valid grid step h, record omega(p,h), the maximum unit-normal angle over the eight neighbors at offsets {-h,0,h}^2 excluding the center; aggregate median and 95th percentile in radians.
4. **Descriptive log-log fit.** Fit ordinary least squares to log(omega) versus log(sqrt((h/uCount)*(h/vCount))) over valid positive scale observations. Median and 95th-percentile fits are descriptive summaries, not dimensions or regularity exponents.
5. **Proxy displacement.** Summarize Euclidean vertex displacement from the short-torus baseline and from the immediately previous finite stage on the same periodic grid.
6. **Finite-grid exclusion.** Exclude a normal scale whenever 2*h is greater than or equal to the smaller grid dimension, because that scale reaches the finite periodic Nyquist radius.

## Bounded findings

- **HV EXPERIMENT · metric-rms-range.** Across the four sampled meshes, finite-difference metric RMS ranges from 1.0334177 on Proxy Stage 3 to 1.2145344 on Short Torus. Ordering these proxy residuals does not establish convergence toward an isometry; the proxies are explanatory normal ripples, not upstream convex-integration stages.
- **HV EXPERIMENT · final-proxy-displacement.** Proxy Stage 3 has maximum corresponding-vertex displacement 0.021432748 model units from the short-torus baseline. This is displacement from the baseline, not error against the upstream third corrugation or a limiting embedding.
- **HV EXPERIMENT · winding-polyline-residual.** The largest absolute u/v winding polyline-length residual in this run is 0.80003903 on Short Torus. Only two fixed winding paths are sampled per stage; this is not a global distortion bound.
- **HV EXPERIMENT · normal-median-slope-range.** Descriptive median-normal log-log slopes range from 0.13624694 on Proxy Stage 3 to 0.98081618 on Short Torus over retained grid steps. These least-squares slopes summarize a short finite scale ladder and are not Hölder exponents, graph dimensions, or limiting-regularity estimates.

## Cross-stage summary

| Geometry stage | Geometry class | Metric RMS | Metric maximum | u winding residual | v winding residual | Median normal slope | P95 normal slope | Max displacement from short torus |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| Short Torus | `UPSTREAM BASELINE` | 1.21453437 | 1.3228534 | -0.800039026 | -0.370217446 | 0.980816182 | 0.981066557 | 0 |
| Proxy Stage 1 | `REAL-TIME PROXY` | 1.16028231 | 1.32142078 | -0.67562724 | -0.414983671 | 0.553091698 | 0.389165778 | 0.012 |
| Proxy Stage 2 | `REAL-TIME PROXY` | 1.06864371 | 1.31208935 | -0.634481522 | -0.292444628 | 0.194318708 | 0.103762398 | 0.018 |
| Proxy Stage 3 | `REAL-TIME PROXY` | 1.03341765 | 1.32808807 | -0.59569215 | -0.226495229 | 0.13624694 | 0.0973356196 | 0.0214327485 |

Residuals in the winding columns are `(ambient polyline length - intrinsic target length) / intrinsic target length`. A value near zero for one path is not a surface-wide isometry result.

## Metric residual tables

All rows are `HV EXPERIMENT`. The target tensor is `(E,F,G)=(1,0,1)` and the reported scalar is its finite-difference Frobenius residual.

| Stage | Δu | Δv | Minimum | Median | Mean | RMS | P95 | Maximum | Samples |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Short Torus | 0.0104166667 | 0.0078125 | 1.0872953 | 1.218405 | 1.21160069 | 1.21453437 | 1.3221459 | 1.3228534 | 12288 |
| Proxy Stage 1 | 0.0104166667 | 0.0078125 | 0.955314501 | 1.17326328 | 1.15598275 | 1.16028231 | 1.29770408 | 1.32142078 | 12288 |
| Proxy Stage 2 | 0.0104166667 | 0.0078125 | 0.745373719 | 1.06696635 | 1.06158428 | 1.06864371 | 1.25227196 | 1.31208935 | 12288 |
| Proxy Stage 3 | 0.0104166667 | 0.0078125 | 0.507475475 | 1.00955664 | 1.02471216 | 1.03341765 | 1.25496597 | 1.32808807 | 12288 |

Claim ceiling: A residual summary of this sampled mesh only; not an isometry certificate and not a bound on a limiting map.

## Winding-curve diagnostics

| Stage | Curve | Segments | Intrinsic target | Ambient chord | Ambient polyline | Chord / intrinsic | Polyline residual |
|---|---|---:|---:|---:|---:|---:|---:|
| Short Torus | u winding at v = 0.28125 | 2048 | 1 | 0 | 0.199960974 | 0 | -0.800039026 |
| Short Torus | v winding at u = 0.1375 | 2048 | 1 | 0 | 0.629782554 | 0 | -0.370217446 |
| Proxy Stage 1 | u winding at v = 0.28125 | 2048 | 1 | 0 | 0.32437276 | 0 | -0.67562724 |
| Proxy Stage 1 | v winding at u = 0.1375 | 2048 | 1 | 0 | 0.585016329 | 0 | -0.414983671 |
| Proxy Stage 2 | u winding at v = 0.28125 | 2048 | 1 | 0 | 0.365518478 | 0 | -0.634481522 |
| Proxy Stage 2 | v winding at u = 0.1375 | 2048 | 1 | 0 | 0.707555372 | 0 | -0.292444628 |
| Proxy Stage 3 | u winding at v = 0.28125 | 2048 | 1 | 0 | 0.40430785 | 0 | -0.59569215 |
| Proxy Stage 3 | v winding at u = 0.1375 | 2048 | 1 | 0 | 0.773504771 | 0 | -0.226495229 |

The endpoint chord of a complete periodic winding should be zero up to interpolation and floating-point effects; its nonzero intrinsic target length is precisely why ambient chord and intrinsic distance must not be conflated.

## Normal-field scale microscope

For each stage, `ω` is an angle in radians. Degrees are included only for human readability. The scale radius used by the fit is the geometric mean of the anisotropic parameter radii.

### Short Torus

Samples: `256` of `256` requested, deterministic seed `0x48455645415F5631`.

| Grid step h | Radius u | Radius v | Valid samples | Excluded samples | Median ω (rad) | Median ω (deg) | P95 ω (rad) | P95 ω (deg) | Maximum ω (rad) |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 0.0104166667 | 0.0078125 | 256 | 0 | 0.075642851 | 4.33401611 | 0.0817912691 | 4.68629452 | 0.0817912691 |
| 2 | 0.0208333333 | 0.015625 | 256 | 0 | 0.152234567 | 8.72239816 | 0.16345601 | 9.36533953 | 0.163582538 |
| 4 | 0.0416666667 | 0.03125 | 256 | 0 | 0.307909373 | 17.6419076 | 0.326655969 | 18.7160084 | 0.326912021 |
| 8 | 0.0833333333 | 0.0625 | 256 | 0 | 0.626823798 | 35.9143581 | 0.651245121 | 37.3135969 | 0.651782086 |
| 16 | 0.166666667 | 0.125 | 256 | 0 | 1.25497973 | 71.9050417 | 1.28665836 | 73.7200938 | 1.28665836 |
| 32 | 0.333333333 | 0.25 | 256 | 0 | 2.15841501 | 123.668071 | 2.41241482 | 138.221188 | 2.41885841 |

Excluded scales:

- `h = 64`: scale reaches or exceeds the finite grid's periodic Nyquist radius

- Fit for **median omega in radians** over `h = [1, 2, 4, 8, 16, 32]`: slope `0.980816182`, intercept `2.06614141`, R² `0.998409914`.
  Claim ceiling: Descriptive least-squares slope across this finite scale ladder only; not a Hölder exponent, fractal dimension, convergence rate, or theorem.
- Fit for **95th-percentile omega in radians** over `h = [1, 2, 4, 8, 16, 32]`: slope `0.981066557`, intercept `2.13068214`, R² `0.999741989`.
  Claim ceiling: Descriptive least-squares slope across this finite scale ladder only; not a Hölder exponent, fractal dimension, convergence rate, or theorem.

### Proxy Stage 1

Samples: `256` of `256` requested, deterministic seed `0x48455645415F5631`.

| Grid step h | Radius u | Radius v | Valid samples | Excluded samples | Median ω (rad) | Median ω (deg) | P95 ω (rad) | P95 ω (deg) | Maximum ω (rad) |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 0.0104166667 | 0.0078125 | 256 | 0 | 0.237702356 | 13.6193418 | 0.783030394 | 44.8643368 | 0.835026102 |
| 2 | 0.0208333333 | 0.015625 | 256 | 0 | 0.716989442 | 41.080469 | 1.35934699 | 77.8848455 | 1.37742136 |
| 4 | 0.0416666667 | 0.03125 | 256 | 0 | 1.50960769 | 86.4941494 | 1.78028975 | 102.003089 | 1.78077084 |
| 8 | 0.0833333333 | 0.0625 | 256 | 0 | 2.24982933 | 128.905725 | 2.57743197 | 147.675974 | 2.57940639 |
| 16 | 0.166666667 | 0.125 | 256 | 0 | 1.30997835 | 75.0562307 | 2.93480575 | 168.151983 | 2.9451709 |
| 32 | 0.333333333 | 0.25 | 256 | 0 | 2.2377209 | 128.211963 | 3.02791657 | 173.48684 | 3.03556096 |

Excluded scales:

- `h = 64`: scale reaches or exceeds the finite grid's periodic Nyquist radius

- Fit for **median omega in radians** over `h = [1, 2, 4, 8, 16, 32]`: slope `0.553091698`, intercept `1.73374925`, R² `0.699488958`.
  Claim ceiling: Descriptive least-squares slope across this finite scale ladder only; not a Hölder exponent, fractal dimension, convergence rate, or theorem.
- Fit for **95th-percentile omega in radians** over `h = [1, 2, 4, 8, 16, 32]`: slope `0.389165778`, intercept `1.78631095`, R² `0.909394238`.
  Claim ceiling: Descriptive least-squares slope across this finite scale ladder only; not a Hölder exponent, fractal dimension, convergence rate, or theorem.

### Proxy Stage 2

Samples: `256` of `256` requested, deterministic seed `0x48455645415F5631`.

| Grid step h | Radius u | Radius v | Valid samples | Excluded samples | Median ω (rad) | Median ω (deg) | P95 ω (rad) | P95 ω (deg) | Maximum ω (rad) |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 0.0104166667 | 0.0078125 | 256 | 0 | 1.10133997 | 63.1021324 | 2.07922597 | 119.130873 | 2.34804837 |
| 2 | 0.0208333333 | 0.015625 | 256 | 0 | 1.72182256 | 98.6531655 | 2.3995735 | 137.485434 | 2.51871921 |
| 4 | 0.0416666667 | 0.03125 | 256 | 0 | 2.05023559 | 117.469846 | 2.41802493 | 138.542623 | 2.5566924 |
| 8 | 0.0833333333 | 0.0625 | 256 | 0 | 2.32877603 | 133.429038 | 2.97611886 | 170.51905 | 3.11227626 |
| 16 | 0.166666667 | 0.125 | 256 | 0 | 2.12181978 | 121.571319 | 2.93769904 | 168.317756 | 3.0882096 |
| 32 | 0.333333333 | 0.25 | 256 | 0 | 2.43161531 | 139.321295 | 2.92273206 | 167.460212 | 3.07461081 |

Excluded scales:

- `h = 64`: scale reaches or exceeds the finite grid's periodic Nyquist radius

- Fit for **median omega in radians** over `h = [1, 2, 4, 8, 16, 32]`: slope `0.194318708`, intercept `1.21883365`, R² `0.742955103`.
  Claim ceiling: Descriptive least-squares slope across this finite scale ladder only; not a Hölder exponent, fractal dimension, convergence rate, or theorem.
- Fit for **95th-percentile omega in radians** over `h = [1, 2, 4, 8, 16, 32]`: slope `0.103762398`, intercept `1.26389368`, R² `0.834208939`.
  Claim ceiling: Descriptive least-squares slope across this finite scale ladder only; not a Hölder exponent, fractal dimension, convergence rate, or theorem.

### Proxy Stage 3

Samples: `256` of `256` requested, deterministic seed `0x48455645415F5631`.

| Grid step h | Radius u | Radius v | Valid samples | Excluded samples | Median ω (rad) | Median ω (deg) | P95 ω (rad) | P95 ω (deg) | Maximum ω (rad) |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 0.0104166667 | 0.0078125 | 256 | 0 | 1.4315846 | 82.0237558 | 2.15853268 | 123.674813 | 2.52753551 |
| 2 | 0.0208333333 | 0.015625 | 256 | 0 | 1.97743901 | 113.298909 | 2.45052509 | 140.404745 | 2.55976112 |
| 4 | 0.0416666667 | 0.03125 | 256 | 0 | 2.26412859 | 129.725012 | 2.59394128 | 148.621888 | 2.71907531 |
| 8 | 0.0833333333 | 0.0625 | 256 | 0 | 2.55270058 | 146.258969 | 3.05172034 | 174.850696 | 3.11060159 |
| 16 | 0.166666667 | 0.125 | 256 | 0 | 2.31271861 | 132.509015 | 2.94009088 | 168.454799 | 3.12221719 |
| 32 | 0.333333333 | 0.25 | 256 | 0 | 2.46425901 | 141.191641 | 3.00391291 | 172.111532 | 3.09058371 |

Excluded scales:

- `h = 64`: scale reaches or exceeds the finite grid's periodic Nyquist radius

- Fit for **median omega in radians** over `h = [1, 2, 4, 8, 16, 32]`: slope `0.13624694`, intercept `1.16125195`, R² `0.684777798`.
  Claim ceiling: Descriptive least-squares slope across this finite scale ladder only; not a Hölder exponent, fractal dimension, convergence rate, or theorem.
- Fit for **95th-percentile omega in radians** over `h = [1, 2, 4, 8, 16, 32]`: slope `0.0973356196`, intercept `1.27509993`, R² `0.844108367`.
  Claim ceiling: Descriptive least-squares slope across this finite scale ladder only; not a Hölder exponent, fractal dimension, convergence rate, or theorem.

Claim ceiling: Finite-mesh normal variation only; no fractal-dimension or limiting-regularity theorem is claimed.

## Proxy displacement

| Stage | Previous stage | From short torus mean | From short torus RMS | From short torus P95 | From short torus max | Increment mean | Increment RMS | Increment max |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| Short Torus | — | 0 | 0 | 0 | 0 | — | — | — |
| Proxy Stage 1 | Short Torus | 0.00763671 | 0.00848528137 | 0.0119743071 | 0.012 | 0.00763671 | 0.00848528137 | 0.012 |
| Proxy Stage 2 | Proxy Stage 1 | 0.00811958298 | 0.00948683298 | 0.016559314 | 0.018 | 0.00379787706 | 0.00424264069 | 0.006 |
| Proxy Stage 3 | Proxy Stage 2 | 0.00830201161 | 0.00980433578 | 0.0177034226 | 0.0214327485 | 0.00222797035 | 0.00247487373 | 0.0035 |

Claim ceiling: Finite-stage proxy displacement only; not a geometric error bound against an upstream corrugation or limiting embedding.

## Interpretation boundaries

This experiment deliberately preserves several distinctions:

- The short torus is a regenerated upstream starting formula; the three rippled surfaces are newly written low-frequency explanatory proxies.
- A finite-difference residual is a sensor reading, not a proof. Grid resolution, interpolation, derivative stencil, and chosen paths all influence the number.
- A short log-log line through six retained scales can be useful for visual comparison, but it does not reveal an asymptotic exponent by itself.
- The sampled normal field belongs to each triangulated/procedural finite surface, not to the limiting C1 isometric embedding in the Hévéa papers.
- The report has no error-controlled comparison with the historical 10,000 × 10,000 computation and no physical Vision Pro performance evidence.
- Results may motivate higher-resolution, cross-resolution, or upstream-matched experiments; they do not settle a mathematical open question.

## Reproduce

Run from the repository root. The first command fails if the current `Packages/HeveaCore` tree or working copy differs from the pinned core checkpoint; the experiment package itself may live in a later commit:

```sh
git diff --exit-code 68202cae55a59a71b1573c869a05ac82b87c7ee2 -- Packages/HeveaCore
swift run -c release --package-path Research/ScaleMicroscope hevea-scale-microscope --output-directory docs/research
```

The executable writes `docs/research/scale-microscope-report.json` and this Markdown file. To audit determinism, run twice into separate temporary directories and compare SHA-256 hashes of corresponding files.

## Source trail

- Hévéa project: <https://hevea-project.fr/>
- Pinned GPL source: <https://github.com/HeveaProject/Hevea> at `e792074e4dd6319351bc957afeb16b4725d304f0`
- Source path adapted for the short-torus baseline: `torus/v0r1m2/include/TOR_implementation.h`
- Machine-readable companion: [`scale-microscope-report.json`](scale-microscope-report.json)

Generated deterministically by `Research/ScaleMicroscope` from HeveaCore `68202cae55a59a71b1573c869a05ac82b87c7ee2`.
