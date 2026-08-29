# Upstream source map

## Hévéa project

- Project website: <https://hevea-project.fr/>
- English flat-torus overview: <https://hevea-project.fr/ENPageToreDossierDePresse.html>
- Source page: <https://hevea-project.fr/ENPageToreCodeSource.html>
- Public source repository: <https://github.com/HeveaProject/Hevea>
- Pinned revision initially audited: `e792074e4dd6319351bc957afeb16b4725d304f0`
- Upstream license: GNU GPL v3; individual source headers say version 3 or later.

The audited C++ program starts from a short torus of revolution and applies three corrugations. Its documented default oscillation counts are 12, 80, and 500 on a 10,000 by 10,000 grid. The PNAS paper reports a fourth visually rendered corrugation and explains that later changes become difficult to see while frequencies grow dramatically.

## Primary flat-torus paper

- Article: <https://pmc.ncbi.nlm.nih.gov/articles/PMC3358891/>
- DOI: <https://doi.org/10.1073/pnas.1118478109>

The paper defines the isometric default, the repeated three-direction decomposition, corrugation matrices, and the Gauss-map infinite-product description. It reports at most 10.2% length deviation for its displayed finite approximation over a tested collection of meridians, parallels, and diagonals, versus up to 80% for the initial standard torus. That paper-specific finite experiment must not be generalized to arbitrary meshes generated here.

## Reduced sphere

- Project overview: <https://hevea-project.fr/ENPageSphereDossierDePresse.html>
- Paper PDF: <https://hevea-project.fr/pdfSphere/focm-revised-2.pdf>
- DOI: <https://doi.org/10.1007/s10208-017-9360-1>
- Current independent reproduction: <https://github.com/Juddd/hevea-reduced-sphere>
- Current technical exchange: <https://github.com/HeveaProject/Hevea/issues/1>

As of 2026-08-29, [Roland Denis's author comment](https://github.com/HeveaProject/Hevea/issues/1#issuecomment-5396587822) shares the composite-Hermite initial-profile recipe and the article configuration `theta = 88 degrees`, `eta = 0.5`, and `beta = 0.6`; the transition function and possible official sphere-source publication remain pending. The same comment writes the cap and belt boundaries using `pi / 2 - theta`. Taken literally with `theta = 88 degrees`, those intervals conflict with condition (3.4) of the paper, the public mesh envelope, and the independent reproduction's `yInfinity` near 88 degrees. Until the angle convention is clarified, treat the comment as live collaboration context rather than an executable upstream baseline.

## Licensing boundary

The website identifies its flat-torus generator as GPL software. Gallery content carries separate attribution terms, while the downloadable precomputed mesh page does not make the mesh redistribution license explicit enough for this repository. This project therefore links to those meshes but does not commit or redistribute them without clarification.
