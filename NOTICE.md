# Attribution, modification, and media notice

Hévéa Vision is an **unofficial tribute and independent spatial-computing
research prototype** by Alok Singh, developed with OpenAI Codex beginning on
2026-08-29. It is not an official release of, or endorsed by, the Hévéa team,
the authors named below, CNRS, Université Claude Bernard Lyon 1, Université
Grenoble Alpes, Apple, or their institutions.

## Reduced-sphere research source

The reduced-sphere exhibit follows:

> Evangelis Bartzos, Vincent Borrelli, Roland Denis, Francis Lazarus, Damien
> Rohmer, and Boris Thibert. “An Explicit Isometric Reduction of the Unit
> Sphere into an Arbitrarily Small Ball.” *Foundations of Computational
> Mathematics* 18, 1015–1042 (2018).
> <https://doi.org/10.1007/s10208-017-9360-1>

The paper and its author-hosted manuscript are research references. Their
prose and figures are not relicensed by this repository's GPL license. The
application independently implements formulas and paper-calibrated concepts
with explicit finite-mesh claim ceilings.

## Community GPL reduced-sphere profile

Hévéa Vision adapts the deterministic constrained profile from the independent
community project:

- repository: <https://github.com/Juddd/hevea-reduced-sphere>
- pinned revision: `c098ea6fabb994bdd2555719b64ebbe8d7fca483`
- adapted source path: `src/reduced_sphere_profile.hpp`
- upstream license: `GPL-3.0`
- retained local research snapshot:
  `Research/Upstream/Sphere/hevea-reduced-sphere/`
- Swift adaptation:
  `Packages/HeveaCore/Sources/HeveaCore/ReducedSphereProfile.swift`

The community project's retained notice states that its reduced-sphere
profile, characteristic-flow implementation, numerical certificates, CMake
integration, and Wolfram Language wrapper are a separate reimplementation—not
an official release by the paper authors or Hévéa project. It also states that
its generic corrugation, numerical-integration, and mesh-output ideas adapt the
GPL Hévéa project.

Modification notice: Alok Singh with OpenAI Codex translated the pinned
degree-thirteen constrained profile evaluation from C++ into bounded,
platform-neutral Swift on 2026-08-29. The community project's
convex-integration flow was **not** copied into the runtime app. Hévéa Vision
adds lower-frequency, nested explanatory displacements rendered as
`REAL-TIME PROXY` geometry. Those surfaces are not the authors' unpublished
degree-nine profile, the paper's finite `f₁,₃`, an isometry certificate, or the
limiting `C1` map.

The community profile remains under `GPL-3.0`. Original Hévéa Vision files
marked `GPL-3.0-or-later` retain that option; the combined distribution is
available under GNU GPL version 3. See [LICENSE](LICENSE) and the community
snapshot's own `LICENSE` and `NOTICE` files.

## Original Hévéa flat-torus source

The archived flat-torus exhibit adapts the original implementation by Vincent
Borrelli, Saïd Jabrane, Francis Lazarus, and Boris Thibert for the Hévéa
project:

- repository: <https://github.com/HeveaProject/Hevea>
- pinned revision: `e792074e4dd6319351bc957afeb16b4725d304f0`
- adapted source path: `torus/v0r1m2/include/TOR_implementation.h`
- upstream license: GNU GPL version 3; individual source headers permit
  version 3 or later

The runtime preserves the exact short-torus starting formula and labels its
new low-frequency corrugations as explanatory proxies rather than upstream
construction stages.

Primary flat-torus reference:

> Vincent Borrelli, Saïd Jabrane, Francis Lazarus, and Boris Thibert. “Flat
> tori in three-dimensional space and convex integration.” *PNAS* 109(19),
> 7218–7223 (2012). DOI `10.1073/pnas.1118478109`;
> <https://pmc.ncbi.nlm.nih.gov/articles/PMC3358891/>.

## Official gallery and mesh boundary

The official reduced-sphere gallery is:

- <https://hevea-project.fr/Sphere_Gallery.html>

Its footer licenses its pictures and videos under
[Creative Commons Attribution-ShareAlike 2.0
France](https://creativecommons.org/licenses/by-sa/2.0/fr/) and credits
E. Bartzos, V. Borrelli, R. Denis, F. Lazarus, D. Rohmer, and B. Thibert.

**No official gallery image or video is bundled in this repository.** The app
screenshots under `docs/screenshots/` are generated from Hévéa Vision's own
Swift/RealityKit implementation and do not imply endorsement. The CC BY-SA
gallery license therefore is recorded as a source boundary, not asserted as
the license of those app screenshots.

The official downloadable reduced-sphere WRL meshes are also not bundled.
Although they are publicly downloadable, no explicit adjacent redistribution
license for those mesh files was found on the inspected download page. This
repository links to and studies them as references without redistributing
them. If official gallery media or meshes are added later, that change must
carry a separate asset manifest, exact source URL, author credits, applicable
license, and modification notice.

## Repository research artifacts

The reduced-sphere nonstandard-analysis reader, claim ledger, generated PDF,
finite-mesh diagnostics, UI, and app-generated screenshots are new Hévéa
Vision materials unless a file says otherwise. Mathematical facts and formulas
are cited to their sources; third-party paper prose and figures are not
incorporated as GPL application assets.
