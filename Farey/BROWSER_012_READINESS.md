# Browser 0.12.0 verification

Historical 0.12.0 artifact audit. Browser 0.12.1 adds tested XR camera restoration; see [current emulator evidence](XR_SIMULATION.md).

October 22, 2026. This is a local demonstration package, not a public deployment or physical-headset release. [Mathematics and controls](DOUBLE_CONE.md) distinguish source-supported constructions from our presentation choices.

## Ready locally

- Signed, noncoplanar coefficient cloud, double discriminant cone and optional radial Klein projection.
- One Inhabit/Overview toggle, exact coefficient-origin preset, up/level/down and explicit Euclidean motion with saved overview return.
- Direct exterior-point cutting planes; Shift-click or coefficient entry for a two-root plane; exact membership and endpoints.
- Small GPU point sprites with source-informed relative sizing; Viridis on a fixed logarithmic discriminant range; category swatches and source-anchor alternative.
- Finite exact crops up to 1,852,484 unique triples, without sampling. High density can overlap and saturate the fixed color range.
- Closed-by-default Debug with honest primitive counts, CPU/memory labels and optional browser scheduling intervals.
- Self-contained static assets, GPL/MIT/CC0 notices, exact source inputs and SHA-256 manifest. No reference code/media, credentials, private paths, recordings, analytics or CDN assets are bundled.

## Verified on this package

`WebXR/output/Farey-WebXR-0.12.0.zip` is 589,517 bytes. Its SHA-256 is `36b057c2213150d0a087f1b72c8d30cfbbabd8dd8fa3b15b2e258a27ead75696`; manifest SHA-256 is `ed7e52d229e2538742335f8484145ac790245373b3af3431c6f95d2c22c68c1d`.

The ZIP was unpacked outside the development checkout and started with its own documented `python3 serve.py --port PORT`. Its bundled `starscape-checks.js`, `pair-checks.js` and `debug-checks.js` passed in isolated headless Chromium. The temporary server and browser were shut down afterward. The 66 unit/package tests passed without failures or skips.

The package smoke check separately exercised both entry pages in clean profiles with external requests blocked. It found no external runtime requests or unexpected page errors. Loaded-page offline Origin/look/return, pairing/fading/reset and Farey L/R/undo worked. Portrait 390×844 and landscape 844×390 retained the scene without horizontal overflow. Coefficient reload intentionally starts fresh; the separate Farey page restores validated per-tab rational state and rejects malformed storage.

Before/after regressions:

| Reproduced failure | Result after fix |
| --- | --- |
| Debug left edge −42 px on a 390 px viewport | Bounds x=12, width=366 px |
| Closing Debug still allowed a measurement to update its DOM | Zero closed-panel updates; measurement cancels and can restart |
| Escape could leave navigation while inspecting Debug | Escape closes Debug and preserves Inhabit |
| Blocked coefficient module left zero canvases and 17 active-looking buttons, with no error | Visible local-launch/reload explanation and disabled unusable controls |

WebGL creation failure was **mocked** separately; JavaScript-disabled and blocked-module paths were exercised. The full coefficient walkthrough uses the actual `WEBGL_lose_context` extension for loss/restoration. These are browser-level failure tests, not a physical GPU failure or XR recovery test.

Numerical checks include transformed-lattice parity, covolume, exact counts, sign pairing, cone/ray equations, exterior Lorentz normals, two-root planes, infinite/irrational endpoints, source size factors and palette/category separation simulations. Human color accessibility and screen-reader speech remain untested.

Current screenshots and sanitized results: [dense overview](evidence/browser-0.12/dense-overview.png), [cutting plane and slice](evidence/browser-0.12/cutting-plane.png), [phone Debug](evidence/browser-0.12/debug-phone.png), [checks](evidence/browser-0.12/checks.json). These show desktop Chromium rendering; they are not XR stereo frames.

## Remaining checks

1. IWE simulated entry, stereo, head/controller poses, selection and exit were subsequently exercised; [0.12.1 evidence](XR_SIMULATION.md) records the camera fixes. Physical headset input, frame rate and comfort remain separate work.
2. Audit exact foreground/context overlap under optional plane-opacity fading; current transparency is approximate and avoids per-point sorting. At high density, ray-based selection can be ambiguous among coincident directions.
3. Revalidate the latest coefficient page on Safari/touch and assistive technology. Historical Farey Safari tests do not establish these new paths.
4. Native parity for signed lower nappe, Origin, dense renderer and new plane controls. Native 0.9.0's prior 36-test simulator run covers its older upper-cone scene; no new hardware result is implied.
5. Public hosting, physical-device access and private artifact delivery require their separate authorized steps. The loopback package is ready for local desktop review only.

## Reproduce

From `Farey/WebXR`, use `npm ci --ignore-scripts`, `npm test`, `npm run build`, then `npm run smoke:package`. With Playwright CLI and its browser already installed, `python3 smoke-offline.py --artifact /path/to/unpacked/Farey-WebXR-0.12.0 --cli /path/to/playwright-cli` validates both pages without an XR request, upload, tool installation or permission change. For the additional interactive checks, open the local primary page in a separate test session and run the three bundled `source/*-checks.js` files with `run-code --filename`.
