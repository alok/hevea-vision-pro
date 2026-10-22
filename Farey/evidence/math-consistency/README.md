# Mathematical audit evidence

Recorded on 22 October 2026 against runtime source commit `f33787c51cef7a9f13b99601f1bca0f36af9d880`: browser 0.7.3 and native 0.8. This audit changes no application runtime code.

- `exact-state-and-geodesics.json`: 56,451 cases compared with an independent BigInt oracle and the compiled native core. Includes the shared exact-state digest, 74,575 sampled endpoint pairs, and concrete Float32 precision counterexamples.
- `browser-renderer.json`: actual Three.js scene-object inspection in an isolated headless Chromium 155 page at 1440 × 1000. Five selected states, 20 settled construction stages, a 24-move path, undo/replay, and off-grid inspection. The test injects a temporary local response hook; that hook is absent from the packaged application. This checks geometry buffers and scene state, not visual perception or XR frames.

The same pass ran all **36 browser unit tests** and **27 native core tests** successfully. SwiftPM used two jobs, temporary build/module caches, and its per-build sandbox was disabled inside the existing execution sandbox because nested `sandbox-exec` was unavailable. No operating-system permission or security setting changed.

The packaged runtime manifest still hashes to `b6dd1268ee904e38feffa23d145e5faa554c958cf027af5baff84a9137c96822`. Its ZIP is unchanged. See [the audit](../../MATHEMATICAL_AUDIT.md) for the formulas, reproduction commands and limits.

No fresh native UI, physical headset, immersive WebXR or screen-reader speech test was performed. The main simulator showcase and foreground applications were left untouched. No recordings were uploaded and no deployment occurred.
