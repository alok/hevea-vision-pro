# Mathematical consistency audit — 22 October 2026

This audit covers browser **0.7.3** and native **0.8**. No application runtime code, camera behavior or mathematical construction changed. The existing Vision Pro showcase and the foreground were left untouched.

## Exact state and finite continued fractions

An independent BigInt oracle uses Euclidean subtraction blocks for the L/R word, multiplies 2×2 integer matrices, and evaluates continued-fraction truncations backwards. Its results matched both the browser model and the compiled native FareyCore across **56,451 input/path cases**. The comparison includes interval endpoints, selected mediant, word, retained raw point, both finite expansions, and every convergent/intermediate label.

The cases include all positive pairs up to 200, 4,096 deterministic pairs up to 1000, every word through length 12, 4,096 deterministic 24-move words, both alternating 24-move extremes, repeated L/R words through 25 moves, and explicit zero/infinity/invalid/boundary inputs. This is bounded execution evidence, not a formal proof over an infinite domain. Repeated cases from different input routes are counted as cases, not unique fractions.

- **49,176 cases accepted their complete input.** Rejected cases agree, including the 25th move and valid positive fractions requiring more than 24 moves.
- The largest observed numerator or denominator was **121,393**. A separate elementary safety bound is looser: after 24 additions each endpoint component is at most 2²⁴, so determinant products are at most 2⁴⁸, below JavaScript's exact integer limit 2⁵³ and Swift Int64's limit. The direct-entry cap of 1000 keeps search comparisons within those limits too.
- 0/1 and infinity remain non-selectable boundaries. A boundary convergent may still be spotlighted without replacing the positive target.
- Nonprimitive points such as (10,6) retain their identity while the exact target is 3/5. Alternate finite expansions change the classification of rows, not the target, point or word.
- Choosing the expansion ending in R reproduces the endpoint convention: the endpoint word is the app's interval word followed by R.

The browser/native record digest is `ee0af2667466e895ccff0417e3ede75a9e954b3acdf9d25aad002ca457b1d32a`.

## Geometry and labels

The native core audit checked **74,575 distinct encoded endpoint pairs**, including reflected finite tessellation edges. Their sampled geodesics had finite coordinates, remained in the unit disk, retained their endpoints and satisfied the orthogonal-circle equation. The largest residual in the division-free circle equation was approximately **2.22×10⁻¹⁶**. No distinct consecutive Double samples collapsed, and the Float differences used by the tube-tangent calculation remained nonzero. The reflected disk chart and positive-multiple invariance also passed.

The actual headless browser renderer was inspected separately through a temporary test-only hook. It verified:

- All 224 points in grid 14 use the expected uniformly scaled, rigidly rotated (q,p) coordinates. Maximum measured Double coordinate discrepancy was about **8.89×10⁻¹⁶** display units.
- The finite direction plane follows the selected rational ray and the perpendicular direction. Its Float32 vertex buffers differed from the formula by at most **1.16×10⁻⁷** display units in these cases.
- All four construction stages preserve the target. Projected dots use (1,p/q), hidden nonprimitive points stay hidden there, and the plane appears only in its final stage. The interpolation remains explicitly described as pedagogical motion, not a hyperbolic map.
- For 1/25, 25/1, the alternating 24-move target 121393/75025, and an inspected point outside grid 6, the appropriate out-of-chart or out-of-grid text appears. Coordinates are not clamped to visible points.
- White inspection of 6/10 remains distinct from orange 3/5. Toggling finite expansions and undoing/replaying the final deep move preserve the expected exact state.

Native lattice-renderer formulas were inspected against this same coordinate convention, but RealityKit rendering was not executed in this headless pass. Earlier native renderer/UI tests are documented in [the integration audit](INTEGRATION_08.md). This audit does not convert those earlier tests into a new simulator or hardware run.

The subsequent [native deep-path follow-up](NATIVE_PRECISION_AUDIT.md) executes the generated meshes and UI in isolated simulators; it records that separate evidence and the capture uncertainty.

## Reproduced precision limit

**23,634 checked endpoint pairs had at least one adjacent sampled center that rounded to the same Float32 coordinate.** This is a display-precision limit of deep disk curves, not a disagreement between rational models. It does not mean all those arcs collapse entirely.

One concrete example is the interval 762/487 to 1657/1059, reached before the mediant 2419/1546 with the 19-move word `LRLRRRLLRLLRLLLLLRR`. The first two Double samples are approximately:

```text
(0.9075277600135973, 0.41999210088369837)
(0.9075277266332665, 0.4199920867238846)
```

Both center coordinates become `(0.90752774477005, 0.4199920892715454)` after Float conversion. The native renderer computes its tangent from the Double difference before converting it, which remains nonzero. The mathematical endpoints and labels stay distinct; their tiny geometric separation need not be visible. This fraction exceeds the direct-entry component cap but is reachable through the listed L/R moves.

No rendering workaround was added: the audit did not reproduce a wrong rational result, nonfinite tangent, incorrect curve equation or silent state clamp. The exact fractions are the authoritative state; a finite-width, finite-precision curve picture is not proof that nearby fractions coincide.

## Reproduce and limits

From `Farey`:

```sh
node scripts/audit-consistency.mjs --native --output /tmp/farey-consistency.json
node scripts/audit-math.mjs
swift test --package-path Packages/FareyCore --scratch-path /tmp/farey-math-core --jobs 2
```

`--native` needs the installed Xcode Swift toolchain and compiles only local source into a temporary directory. It installs nothing, opens no UI and removes its temporary inputs/binary. Omit it for the browser/BigInt comparison alone.

With the packaged browser served locally, use an already installed Playwright CLI:

```sh
playwright-cli open http://127.0.0.1:8080/
playwright-cli run-code --filename WebXR/mathematics-checks.js
```

The renderer hook is injected by the test response and is not shipped in the package. Results are in [evidence/math-consistency](evidence/math-consistency/).

Katherine Stange's [talk and L/R lattice viewer](https://katestange.net/talks/math-exploration/) and Caroline Series's [underlying work](https://doi.org/10.1112/jlms/s2-31.1.69) remain credited. The [source-fidelity audit](SOURCE_FIDELITY.md) records the deliberate differences from her viewer. This work adds no copied code or assets.

Real WebXR sessions, physical-device input/comfort/performance, spoken assistive technology and the existing simulator capture uncertainty remain unverified. No consent, signing assets, uploads or deployment were changed.
