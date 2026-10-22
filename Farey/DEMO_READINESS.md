# Historical release audit — native 0.6.1 / browser 0.5.1

This records an earlier release. For the current native 0.8 / browser 0.7.0 state, see [the integration check](INTEGRATION_08.md). Its captures and test counts are not presented as current.

Audited on 2026-10-22. This is an original, finite spatial illustration inspired by **[Katherine Stange](https://katestange.net/talks/math-exploration/)** and her [visualization catalog](https://www.katestange.net/code/), with [Caroline Series's L/R coding](https://doi.org/10.1112/jlms/s2-31.1.69). No Stange code or media is bundled. Application code remains GPL-3.0-or-later; Three.js is MIT-licensed.

The usable demonstrations are the native visionOS simulator and desktop/mobile browser 3D. An actual immersive WebXR session and physical-headset execution are still unverified.

| Check | Evidence and limit |
|---|---|
| Exact state and bounds | 23 Swift core tests and 22 JavaScript tests pass. Existing cross-platform comparisons cover selected fractions, inspected multiples and both finite CF expansions. These are bounded tests, not a formal proof. |
| Native immersion | 17 native tests pass: 7 model and 10 simulator UI tests. Full-black immersive space, linked lattice/disk, exact L/R, reset/undo, point inspection, lesson and spotlight are exercised by native UI tests. The new test reaches 24 moves and repeats Home → activate → enter three times without changing the exact selection. |
| Browser recovery | Source and static builds recover from a zero-sized viewport with matching visible 3D pixels. Eight malformed saved states are rejected; a valid reduced direction and inspected multiple survive reload. Tab background/foreground preserves pixels and state. |
| WebGL recovery | Both builds pass three real `WEBGL_lose_context` / restoration cycles. Exact controls remain usable during loss and the scene returns. This is a browser-generated failure, not a physical GPU or XR-session failure. |
| Responsiveness | At grid 14, 120 paced DOM moves take 4.5 ms median / 5.9 ms p95 in source, and 4.4 ms / 5.0 ms in the static build. Time to the next animation-frame callback has p95 17.4 / 17.3 ms. These measure desktop main-thread work, not GPU completion, physical input latency or headset frame rate. |
| Geometry resources | Caps remain 224 nonzero lattice points and 509 disk edges. Geometry is updated on state changes, not regenerated per frame. The prior 200-spotlight allocation check returned to its baseline; this patch does not change allocation ownership. |
| Attribution and claims | Stange and Series credits remain visible in entry/source controls and browser header/source controls. The lattice's integer geometry, disk projection and finite sampling are distinguished from an infinite fractal, Stange's separate hyperboloid and a proved theorem. |
| Accessibility | Keyboard and semantic-structure checks are recorded. Screen-reader speech and physical-device gestures have not been tested. |
| Real WebXR | Simulator Safari reported support and a real click reached position/head-movement consent. Consent remains ungranted; no session or XR frame has been observed. Desktop orbit and native simulation do not establish WebXR operation. |
| Hardware / publication | Native 0.6.1 Release builds and passes strict signature verification using existing signing material. No headset installation/execution, new signing assets, new grants or public deployment. |

## Defects found and corrected

**Deep disk arcs:** the old circle-center/radius subtraction lost precision for nearby Farey endpoints. A deterministic probe of 1,004 depth-24 histories found 108,870 repeated adjacent sample segments. The new rational-quadratic parameterization produces zero repeated segments, zero nonfinite points and a maximum squared-radius overshoot of 2.22 × 10⁻¹⁶ on the same inputs. The curve still represents the orthogonal circle, with the diameter as its limiting case; the renderer draws a finite sampled mesh. Unit tests independently check the circle equation, diameter and nearly coincident/antipodal cases.

**Blank browser after resize:** a temporarily zero-width scene assigned an invalid aspect/camera fit, leaving a black canvas after returning to normal size. The resize handler now waits for positive dimensions before changing the camera. The regression goes through 10×1, 1×1, portrait, landscape and desktop layouts and compares an unobscured scene region before and after. [Before](evidence/release-audit/browser-resize-before.png) · [After](evidence/release-audit/browser-resize-after.png).

## Reproduce

Native launch: from `Farey`, run `./scripts/run-simulator.sh --showcase`. It opens **Farey — Into the Infinite** at 3/5; Left/Right reveal spatial depth, Front restores the placement, Reset restores the initial state, and Exit returns to entry. The plain script launches the entry screen. See [native instructions](README.md#run-on-this-mac).

Browser: from `Farey/WebXR`, run `npm start`, then open `http://127.0.0.1:8080`. Drag to orbit, right-drag to pan, scroll to zoom, or focus the scene and use the documented keyboard controls. See [browser instructions](WebXR/README.md).

From `Farey`, repeat the numerical probe without external dependencies:

```sh
xcrun swiftc -module-cache-path /tmp/farey-audit-modulecache \
  Packages/FareyCore/Sources/FareyCore/*.swift scripts/audit-geodesics.swift \
  -o /tmp/farey-geodesic-audit
/tmp/farey-geodesic-audit
```

Run `swift test --package-path Packages/FareyCore --scratch-path /tmp/farey-core-check --jobs 2` and `./scripts/test-simulator.sh` for native checks. From `WebXR`, run `npm test`, `npm run build`, and the optional existing Playwright CLI against both port 8080 and a local server serving `dist`:

```sh
playwright-cli run-code --filename release-audit-checks.js
playwright-cli run-code --filename responsiveness-checks.js
playwright-cli run-code --filename spotlight-checks.js
playwright-cli run-code --filename recovery-checks.js
```

The [full native result](evidence/release-audit/native-full-summary.json), [0.6.1 showcase](evidence/release-audit/native-showcase.png), and checked-in [audit evidence](evidence/release-audit/) record the environment and precise scope. Performance values depend on the machine and concurrent load.

## Next bounded acceptance work

1. With explicit runtime consent, test a real immersive WebXR session: stereo frames, selection, controls, exit/re-entry and loss handling. Current permission is pending; do not bypass it.
2. Install the signed app on an unlocked paired headset, then check hand/eye targeting, legibility, stationary placement, performance and comfort. Simulator success is not a substitute.
3. Run screen-reader speech and physical mobile touch checks using existing authorized access.
4. Once a specific public destination is approved, follow the [deployment plan](WebXR/DEPLOYMENT_PLAN.md), test that exact HTTPS origin on the intended headset, and only then describe or share it as a live XR demo.
