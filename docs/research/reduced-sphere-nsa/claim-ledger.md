# Reduced-sphere NSA claim ledger

Status: verified research ledger, 2026-08-29

This ledger is the compact audit surface for
[`report-source.md`](report-source.md). “Verified” means the cited source or
derivation was checked; it does not turn a finite rendered proxy into the
paper's limiting map.

## Source keys

| key | source | pinned or stable locator |
|---|---|---|
| `SPHERE` | Bartzos–Borrelli–Denis–Lazarus–Rohmer–Thibert, *An Explicit Isometric Reduction of the Unit Sphere into an Arbitrarily Small Ball* | [project PDF](https://hevea-project.fr/pdfSphere/focm-revised-2.pdf), [DOI](https://doi.org/10.1007/s10208-017-9360-1), local PDF SHA-256 `5f8588a257a173ef86b8ed45bdabba05f09428c6229e6f4055a50ccec2e2a141` |
| `GALLERY` | official reduced-sphere gallery | [gallery](https://hevea-project.fr/Sphere_Gallery.html), HTML SHA-256 `8ca228e881225d294115386c3438ef92edc01c0ef333911888f2e4f583ea7d4f` |
| `NELSON` | Edward Nelson, *Internal Set Theory* | [author PDF](https://web.math.princeton.edu/~nelson/papers/ist.pdf), [DOI](https://doi.org/10.1090/S0002-9904-1977-14398-X) |
| `KEISLER` | H. Jerome Keisler, *Foundations of Infinitesimal Calculus* | [author PDF, 2022 edition](https://people.math.wisc.edu/~hkeisler/foundations.pdf) |
| `NOWIK-KATZ` | Tahl Nowik and Mikhail Katz, *Differential Geometry via Infinitesimal Displacements* | [primary manuscript](https://arxiv.org/pdf/1405.0984) |
| `JUDDD` | independent GPL reduced-sphere reproduction | [repository](https://github.com/Juddd/hevea-reduced-sphere), inspected revision `c098ea6fabb994bdd2555719b64ebbe8d7fca483` |
| `DENIS-2026` | live author clarification | [issue comment](https://github.com/HeveaProject/Hevea/issues/1#issuecomment-5396587822), 2026-08-24 |

## Mathematical claims

| ID | class | claim | support | verification / caveat |
|---|---|---|---|---|
| `P-01` | `PAPER` | For every standard `0 < r < 1`, the unit sphere admits a `C1` isometric map into `B_r`. | `SPHERE`, Corollary 10 and surrounding construction | Verified in the official project manuscript. Say “isometric map” at the formal boundary; the paper's broader “embedding” language is not backed by a separately named injectivity lemma in the inspected proof. |
| `P-02` | `PAPER` | The initial map keeps two translated round caps and inserts a rotationally symmetric short ribbon. | `SPHERE`, Sections 2–3 | Verified from formulas and Proposition 1. |
| `P-03` | `PAPER` | The defect is decomposed into three primitive one-forms and one primitive coordinate is corrected per step. | `SPHERE`, Equations (2.1)–(2.2), Sections 4–5 | Verified. A single correction is not an isometry. |
| `P-04` | `PAPER` | Exact quotient descent imposes an integral phase condition. | `SPHERE`, Lemmas 2 and 7 | Verified. “Approximately integral” is not sufficient. |
| `P-05` | `PAPER` | Nested ribbons and altered target metrics preserve boundary attachment while the active region expands. | `SPHERE`, Section 6 | Verified. This is essential because the primitive margin can vanish toward the cap seams. |
| `P-06` | `PAPER` | Summable stagewise derivative changes yield a `C1` limit with the round metric. | `SPHERE`, Theorem 9 and Corollary 10 | Verified. The uniform-in-stage constants are essential at an unlimited index. |
| `P-07` | `PAPER` | The Gauss map admits an ordered infinite frame product called a `C1`-fractal expansion. | `SPHERE`, Theorem 13 | Verified. This is not a Hausdorff-dimension result. |
| `P-08` | `PAPER` | The displayed first stage uses visible ridge counts `21 / 142 / 997`. | `SPHERE`, Figure 9 / numerical table | Verified. These are the three primitive corrections within stage one, not three completed convergence stages. |
| `P-09` | `PAPER` | The displayed round-metric average errors are `.83 / .73 / .66`; the altered-target averages are `.14 / .07 / .03`. | `SPHERE`, numerical table | Verified. The `.03` value is not global round-metric error. |
| `P-10` | `PAPER` | The displayed mesh was computed on a `4000 x 20000` grid in about `2h46m` on 16 cores with 64 GB RAM. | `SPHERE`, numerical implementation discussion | Verified; retained only as historical computation metadata. |
| `N-01` | `NSA-EQUIV` | For a fixed standard radius, every unlimited transferred construction stage is micro-isometric. | `SPHERE` + transfer in `NELSON`/`KEISLER` | Derived by transferring the uniform stage estimate and target-metric convergence. |
| `N-02` | `NSA-EQUIV` | Unlimited stages are mutually infinitesimally close in `C1`. | `SPHERE`, Theorem 9 + hyperreal Cauchy criterion in `KEISLER` | Derived from the transferred summable tail. |
| `N-03` | `NSA-EQUIV` | The common `C1` shadow of unlimited stages is the paper's exact standard isometry. | `SPHERE` + completeness + standard-part machinery | Derived. Limitedness alone in the infinite-dimensional `C1` space would not suffice; the transferred Cauchy estimates supply nearstandardness. |
| `N-04` | `NSA-EQUIV` | The infinite Gauss-frame product can be represented by an ordered hyperfinite product whose shadow is cutoff-independent. | `SPHERE`, Theorem 13 + transfer | Derived from classical convergence, not from boundedness of `SO(3)` factors alone. |
| `N-05` | `NSA-EQUIV` | Hyperfinite polygonal sums represent length when the partition mesh resolves the actual modulus of continuity of the internal path derivative. | hyperfinite integration in `NELSON`/`KEISLER` + transferred uniform continuity | The invariant criterion is `omega_(g')(1/M) ≈ 0`. `M/N_max` unlimited is only a cutoff-stage heuristic after phase, transition, composition, and amplitude bounds are proved. |
| `C-01` | `NEW-COROLLARY` | Transfer of the finished radius theorem to positive infinitesimal `epsilon` yields an internal exact isometry into `*B_epsilon`. | `P-01` + transfer | New reformulation/corollary; the quantified theorem must first be encoded as an internal superstructure statement. |
| `C-02` | `NEW-COROLLARY` | The pointwise shadow of that infinitesimal-radius map is constant zero. | `C-01` | Immediate from ball containment. |
| `C-03` | `NEW-COROLLARY` | Internal curve length is preserved while the ordinary length of the pointwise shadow is zero. | `C-01`, transferred length identity | Proved in the report. Taking pointwise shadow before forming length changes the answer for every positive-length standard path; constant paths are the trivial equality case. |
| `C-04` | `NEW-COROLLARY` | In any standard local chart and smooth tangent-frame trivialization, the derivative field cannot be S-continuous at a standard point. | `C-02`, exact internal metric, local standard-part differentiation theorem | Proved by contradiction. The internal map may still be `*C1`; S-`C1` is the stronger property that fails. Smooth changes of frame preserve the conclusion. |
| `C-05` | `NEW-COROLLARY` | No single similarity scale makes both global diameter and unit tangent speed appreciable and limited. | `C-01` | Proved by the two alternatives `lambda` limited / unlimited. This is the no-single-scale camera theorem. |
| `C-06` | `NEW-COROLLARY` | The sphere's minimal intrinsic diameter remains `pi`; the unlimited quantity is an intrinsic-to-extrinsic scale ratio, a repeated path length, or a required sampling frequency. | round-sphere metric + `C-01` | Proved/clarified. Do not call geodesic distance itself infinite. |

## Product and implementation claims

| ID | class | claim | support | release consequence |
|---|---|---|---|---|
| `A-01` | `APP-MODEL` | The persistent visitor identity is a source-sphere address, not an ambient mesh point. | `C-02`–`C-06` | Locomotion stores a unit direction, tangent heading, altitude, and accumulated intrinsic length. |
| `A-02` | `APP-MODEL` | Atlas, Habitat, Hover, and Interior are gauge changes synchronized by address. | `C-05` | The app must not pretend they are one fixed-scale Euclidean camera journey. |
| `A-03` | `APP-MODEL` | Collision and adjacency must be source-sheet aware. | `C-02`, `C-06` | Ambient nearest-neighbor selection cannot decide the next intrinsic address. |
| `A-04` | `APP-MODEL` | A finite rendered proxy can illustrate cap attachment, nested support, ridge directions, and navigation without receiving an isometry claim. | paper structure + finite runtime implementation | Every sphere stage other than the exact unit sphere formula is visibly `REAL-TIME PROXY`; numerical overlays are `HV EXPERIMENT`. |
| `A-05` | `APP-MODEL` | Simulator stress establishes bounded state/render liveness only. | retained simulator receipts | It does not establish physical Vision Pro performance, comfort, or interaction quality. |

## Provenance and asset claims

| ID | class | claim | support | consequence |
|---|---|---|---|---|
| `S-01` | source fact | The official GPL repository at pinned revision `e792074...` contains the flat-torus generator, not the reduced-sphere generator. | audited `HeveaProject/Hevea` tree | Do not attribute sphere runtime geometry to that code. |
| `S-02` | source fact | `JUDDD` is an independent constrained reconstruction and explicitly does not recover the hidden author coefficient vector. | `JUDDD` README/source notice | Reused profile code retains GPL attribution and remains `REAL-TIME PROXY`. |
| `S-03` | source fact | The website sphere meshes have no explicit adjacent redistribution license. | official mesh page | Inspect for research; do not bundle. |
| `S-04` | source fact | Gallery pictures/videos are CC BY-SA 2.0 France with six named authors. | `GALLERY` footer | Link by default; if copied, carry title/source, all author credits, license link, and modification notice. |
| `S-05` | source fact | The supplied image matches the official first “On the sphere” frame. | `GALLERY` inventory and perceptual comparison | Use it as design/provenance evidence, not as an uncredited app asset. |
| `S-06` | source fact | `DENIS-2026` shares a composite-Hermite recipe but its printed interval convention conflicts with its stated `theta = 88 degrees` and the paper/mesh geometry. | `DENIS-2026`, `SPHERE`, `JUDDD` | Preserve it as live author correspondence; do not badge a literal implementation `UPSTREAM BASELINE` until clarified. |

## Open claims deliberately not made

- The runtime sphere is not the authors' finite `f_(1,3)` mesh.
- No finite mesh in this repository is certified isometric.
- No global injectivity theorem has been added to the inspected paper proof.
- No curvature blow-up exponent, Hausdorff dimension, or Loeb normal
  distribution has been proved.
- No simulator result is evidence of physical-headset comfort.
