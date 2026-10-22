# First-use readiness — 22 October 2026

This bounded audit started from the exact browser **0.7.2** ZIP and native **0.8, build 10**. It used headless browser checks, source inspection and an isolated native build. No foreground application was opened or rearranged, and the running native showcase was not replaced.

## Repaired first-use failure

In the original ZIP, disabling JavaScript or blocking `app.js` left a blank scene, enabled-looking controls and “Checking WebXR…” indefinitely. Browser **0.7.3** adds:

- A visible JavaScript requirement with inactive controls hidden when scripts are disabled. Stange and Series links remain available.
- A module-load failure explanation covering both the main module and a missing dependency, with unusable controls disabled and guidance to reload or use the packaged local server.
- A short documented route through 3/5 → L → 5/8 → Undo → 3/5 → Reset → 1/1. The optional lesson is clearly a separate path beginning at 1/2.
- Explicit prerequisites and the distinction between a localhost address and a public demo link. The native launch script's simulator identifier is machine-specific; its existing override is now documented.

The source attribution and licenses were inspected again. Katherine Stange is prominent at entry and beside her original links; Caroline Series is cited for the underlying coding. No Stange code or media was added. The finite lattice, projective q=1 chart and optional pedagogical motion retain their existing qualifications.

## What is ready, and on what evidence

| Path | Verified state | Boundary |
|---|---|---|
| Browser ZIP on a local computer | Exact payload hashes; 36/36 tests; clean source rebuild; headless first-use, lesson, saved state, mobile layout and error handling | Requires Python 3, a modern WebGL2 browser and localhost access. It is not an installed offline cache. |
| Browser 0.7.3 startup failures | Missing main module, missing `view.js`, JavaScript disabled and unavailable WebGL all have useful explanations | Error injection is a controlled test; normal loading also passed. |
| Mobile Safari | Prior 0.7.2 acceptance passed 2/2 actual iPhone-simulator tests for entry, grid, reload and portrait/landscape controls | The 0.7.3 loader was checked in Chromium, not rerun in foreground Safari during this audit. Geometry and input code did not change. |
| Native 0.8 | Installed version read as 0.8/build 10; fresh Release **xrsimulator27.2** build passed; 27/27 platform-neutral Swift tests passed | This audit did not launch the native app or repeat its UI suite. Earlier simulator results are linked below. The new build is unsigned simulator output, not a hardware build. |
| Immersive WebXR | Entry implementation exists | Tracking consent remains pending; no actual immersive session/stereo frames are verified. |
| Physical Vision Pro/Quest | No new hardware check | Physical input, comfort and performance remain unverified. Earlier signing success does not establish execution. |
| Reader-facing public URL | Not published | Localhost is reachable only on the serving computer. Sharing/hosting requires the separately authorized distribution step. |

Current headless checks used Chromium 155.0.8059.86. The native build used Xcode 27.2 beta 2 (27B5028f), with two build jobs, and did not install or launch its output. `simctl bootstatus -b` was checked: it boots a selected simulator when needed, so the existing launch script's boot step is valid.

Evidence: [original failure](evidence/readiness-073/startup-before.json), [current headless checks](evidence/readiness-073/browser.json), [first-use walkthrough](evidence/readiness-073/first-use.json), [native build/core scope](evidence/readiness-073/native-audit.json), [clean rebuild](evidence/readiness-073/rebuild.json), [archive verification](evidence/readiness-073/archive.json). [Earlier Safari evidence](MOBILE_SAFARI.md), [native integration](INTEGRATION_08.md) and [capture investigation](LIFECYCLE_CAPTURE_AUDIT.md) remain versioned separately.

The local handoff archive is `WebXR/output/Farey-WebXR-0.7.3.zip`, 499,818 bytes, SHA-256 `57d7952ecc0254c9b16665fc7bd347f198f9fa47263f2b4cc684379a45751a3e`. Its 44-file payload manifest is `b6dd1268ee904e38feffa23d145e5faa554c958cf027af5baff84a9137c96822`. It was extracted and verified, and its bundled sources rebuilt identically using the existing npm cache. The archive remains local; it is not a public download or a deployed site.

## Minimal reader instructions

For the browser ZIP, unpack the whole folder, run `python3 serve.py --port 8080` in it, then open `http://127.0.0.1:8080/` on the same computer. Choose **3/5 example**, then **L**, **Undo** and **Reset**. **Learn a move** supplies a guided explanation. Do not double-click `index.html`; do not send a localhost URL to another person expecting it to reach this machine.

On this Mac, the native route is `./scripts/run-simulator.sh` from `Farey`, then **Enter the void**. It requires Xcode, a visionOS simulator runtime and XcodeGen; it builds, installs and opens Device Hub. It changes the running app, so it was deliberately not invoked in this headless audit. Use `SIMULATOR_UDID=YOUR_ID` for another configured simulator.

## Remaining blockers and next work

The public delivery step, runtime tracking consent and physical-device validation remain outside this audit. No upload, deployment, new signing material, permission grant or external message occurred. The prior Library-upload denial was not retried.

Simulator screenshots can still be partial or inconsistent; the unsuccessful repaint experiment remains reverted. Use the complete, correctly labelled evidence already recorded, not a partial portrait capture as a polished product image. Further capture work should be bounded and based on new evidence.

The next useful independent task is to review the reader-facing evidence/launch guide with the actual intended distribution format. A new mathematical view is not needed to resolve these delivery and verification gaps.
