# Browser package audit — 22 October 2026

Browser **0.7.1** now carries its own local launch guide, Python server, exact authored source/build inputs and license notices. The mathematical construction is unchanged. One verified UI defect was fixed: WebGL initialization failure left the disabled VR button saying “Checking WebXR…” indefinitely; it now explains that VR is unavailable without WebGL.

The native 0.8 showcase was not modified or relaunched during this audit. Its unresolved simulator capture/compositing finding remains documented in [LIFECYCLE_CAPTURE_AUDIT.md](LIFECYCLE_CAPTURE_AUDIT.md). No capture-root-cause claim follows from these browser results.

## Verified package

- Clean installation used the existing npm cache with `--offline --ignore-scripts`; Three.js remains pinned to 0.180.0 and its lockfile integrity hash.
- **33/33 tests passed:** 26 existing mathematical/input/recovery tests, plus the valid package and six deliberately broken packages. The checker rejected payload tampering, a missing vendor module, root-relative URLs, external stylesheets, an unresolved import and an added telemetry call.
- All **39 payload files** are covered by the SHA-256 manifest. The checker resolved all **9 runtime JavaScript modules** locally. A copy of the bundled `source/` rebuilt to a byte-identical manifest in a separate directory after an offline npm install.
- Source notices prominently credit **Katherine Stange**, her talk and viewer, **Caroline Series** and the 1985 paper. GPL text and Three.js's MIT notice are bundled. No Stange source, media or meshes are included; attribution is not a redistribution license for her work.
- A local ZIP was extracted and checked again. It contains only the payload and manifest, including rebuildable source; no recordings, browser profiles, screenshots or private context.

Manifest SHA-256: `3be28d8aa09ae5c7f460562b1ca0900d641a1d4bf456c0165be2ae7a83d30ef0`.

## Actual browser execution

Headless Chromium **155.0.8059.86** loaded the final artifact both at `/` and `/dist/`. Each run used fresh isolated contexts and blocked nonlocal requests. All 67 observed requests per run were local, with no missing assets, incorrect JavaScript/CSS MIME types or unexpected page errors. This is evidence for the exercised flows, not a security proof about all future code paths.

Both runs verified:

- Fresh state: 1/1, empty word and grid 12. A separately created browser context did not inherit the first one's selection.
- Selecting 6/10, then reloading, preserved `(10,6) = 2 × (5,3)`, reduced target 3/5, word RLR and grid 14. Temporary lesson/spotlight state stayed closed. Invalid JSON storage returned safely to the fresh state.
- With browser networking disabled **after loading**, L, Undo, Reset and mobile example selection still worked. Reset replaced the saved state.
- Portrait 390×844 and landscape 844×390 retained a visible scene and no horizontal overflow. Screenshots were inspected. These are emulated Chromium viewports, not physical phones or a new Safari test.
- A deliberately mocked failure of WebGL context creation showed the error explanation, disabled unusable controls, retained the Stange link and stopped the indefinite XR-checking message. The expected `WebGL unavailable` exception was recorded separately.
- Actual unsupported WebXR in this headless environment left a useful explanation and desktop controls. No immersive session was requested or observed.

The offline boundary is explicit: a local Python HTTP server works without external internet, but the browser must still permit localhost requests. A completely offline browser reload failed with `ERR_INTERNET_DISCONNECTED`, as expected. There is no service worker, installed offline cache or supported `file://` launch. The package does not change network/security settings.

Evidence: [subdirectory run](evidence/offline-package/subdirectory.json), [root run](evidence/offline-package/root.json), [source rebuild](evidence/offline-package/rebuild.json), [archive verification](evidence/offline-package/archive.json), [desktop](evidence/offline-package/offline-desktop.png), [portrait](evidence/offline-package/offline-mobile-390.png), [landscape](evidence/offline-package/offline-mobile-844.png), [graphics fallback](evidence/offline-package/offline-no-webgl.png).

## Reproduce

From `Farey/WebXR`:

```sh
npm ci --ignore-scripts
npm test
npm run build
npm run smoke:package
python3 dist/serve.py --port 8080
```

Open `http://127.0.0.1:8080/`. A recipient of the complete built folder needs Python 3 and a WebGL2-capable browser to view it; Node/npm are needed only to rebuild. All instructions are also inside `dist/README.txt`.

With Playwright CLI and its browser already installed:

```sh
npm run smoke:offline
python3 smoke-offline.py --artifact dist --at-root --output output/playwright/offline-root
```

For a CLI outside PATH, pass `--cli 'node /absolute/path/to/playwright-cli.js'`. This Mac used the existing cached `@playwright/cli` 0.1.22. The script never downloads dependencies or browsers, opens a headed/persistent profile, requests XR consent, or publishes anything. It binds an automatically chosen loopback port and closes its own browser/server. JSON, screenshots and detailed logs go under `output/playwright/`, which is ignored by Git. CLI failures are checked even if the CLI itself returns exit status zero.

The local archive is `Farey/WebXR/output/Farey-WebXR-0.7.1.zip` (493,665 bytes). Its SHA-256 is `95b026db8f2e80c5d00e2ba1059dc408add7cbbc1657559f48040e958dbfc4eb`. It was not uploaded or published, and the binary is not committed. Source, reproduction scripts and compact evidence are committed.

## Next work, separated by access requirements

1. **Independent validation:** repeat the packaged offline/state path in the existing iOS simulator Safari. Chromium mobile emulation does not establish WebKit behavior. Keep the native showcase untouched while doing so.
2. **Independent usability/fidelity investigation:** evaluate a compact, exact comparison of the selected q=1 chart value and native disk boundary point. The browser still lacks the linked disk; any comparison must state that the charts do not preserve the same metric. The current phone screenshots also warrant measuring point/label legibility at larger grids before adding controls or more geometry.
3. **Independent native follow-up:** retain the capture issue as unresolved; use a bounded comparison of capture methods when there is new evidence, rather than repeatedly changing the renderer. Direct spatial sphere-tap automation is still not verified.
4. **Pending consent / hardware:** genuine WebXR entry, stereo frames, exit/re-entry and controller/transient-pointer input still need authorized tracking consent and a supported XR target. Physical headset comfort/performance remains untested; existing signing is not hardware execution. No tracking permission or signing assets were changed here.
5. **Pending distribution authorization:** Library upload remains unperformed after the earlier denial, and no public deployment has been authorized. Local packaging does not change those boundaries.
