# Demo readiness — 22 October 2026

Native **0.8.1/build 11** and the exact browser **0.7.4** ZIP were checked as one release candidate. This is simulator and desktop-browser evidence; it is not hardware or actual WebXR-session validation.

| Route | Verified result | Remaining boundary |
| --- | --- | --- |
| Main Vision Pro simulator | Installed 0.8.1/build 11; read back RLR, 3/5, lattice, grid 12, Left view; final stationary showcase captured | Debug simulator build. Physical Vision Pro input, comfort and performance remain untested. |
| Native regression | 33/33 tests passed in a disposable visionOS 27.2 simulator; first-time sequence, lesson, repeated entry/exit, background/foreground, exact state, direct entry, projected selection, spotlight and precision notice | XCTest accessibility and simulator behavior, not hand/gaze or spoken VoiceOver testing. |
| Browser 0.7.4 package | Exact ZIP/manifest verified; clean profiles, first-time sequence, keyboard lesson, portrait/landscape, saved state, corrupt storage and offline interaction passed | A fully offline fresh load/reload still blocks localhost; there is no installed offline cache. |
| Failure/fallback paths | Unavailable WebGL, missing modules and JavaScript-disabled cases gave useful explanations; unsupported XR preserved desktop exploration | Controlled fault injection. No immersive WebXR session or stereo frame was tested. |
| Attribution | Stange is prominent beside original links; Series remains cited | Original implementation; no Stange code/media license is presumed. |

The native run used Xcode 27.2 beta 2 and visionOS 27.2. Browser checks used isolated headless Chromium 155.0.8059.86. The checked-in Xcode project matches the build specification and current sources. The main showcase is the tested Debug presentation path; previous device signing success is separate evidence and does not establish a hardware run of this version.

## Short launch and demonstration

On this Mac, from `Farey`, run `./scripts/run-simulator.sh --showcase`. It builds, installs and opens Device Hub, then presents stationary **3/5** in the lattice with the **Left** view. The displayed app name is **Farey — Into the Infinite**. This command changes the running simulator app. Another configured simulator can be chosen with `SIMULATOR_UDID=YOUR_ID`.

For the ordinary entry window, launch the app, choose **Enter the void**, then **3/5 example**. Press **L** to obtain **5/8**, **Undo** to return to **3/5**, and **Reset** to return to **1/1**. **Exit** returns to the launch window; entering again preserves the current mathematical selection. **Learn** is a separate guided path beginning at **1/2**.

For the browser ZIP, unpack the whole `Farey-WebXR-0.7.4` directory, run `python3 serve.py --port 8080` there, then open `http://127.0.0.1:8080/` on that same computer. Use the same **3/5 example → L → Undo → Reset** sequence. Node/npm are not required to view the package. Do not double-click `index.html`, and do not send a localhost URL expecting it to reach another computer.

The local ZIP is `WebXR/output/Farey-WebXR-0.7.4.zip`, **501,470 bytes**, SHA-256 `c8f21411829e6ba16c03f9f19979448ab144f008268a7bf5b8e7cdee6521ff89`. Payload-manifest SHA-256: `017a82bfd7c3254a77722554c3b5d0f714522ca1e652c75e3d851db435079d9e`.

## Remaining blockers and known limits

- **Actual immersive WebXR:** tracking consent remains pending; no actual session has been verified. Desktop 3D and the native simulator do not establish WebXR readiness.
- **Physical headsets:** installation, hand/controller input, comfort and performance remain unverified. No new signing assets were created.
- **Capture reliability:** the earlier partial-scene/title captures remain unresolved. A complete final showcase capture is evidence of that frame, not a fix for simulator compositing/readback.
- **One browser smoke timeout:** the first clean-profile run timed out at readiness without recording its page state. Diagnostic root and subdirectory runs and the unchanged original-command retry passed. The initial cause remains unknown; no delay or runtime workaround was added.
- **Distribution:** the artifact and recordings remain local. No public deployment or Library upload occurred; those approval boundaries are unchanged.
- **Finite precision:** the [conditional notice](PRECISION_NOTICE.md) identifies confirmed coordinate collisions. Its absence does not guarantee that nearby fractions are visually separated.

See [release-candidate evidence](evidence/release-candidate/README.md), [precision policy](PRECISION_NOTICE.md), [native rendering audit](NATIVE_PRECISION_AUDIT.md) and [source fidelity](SOURCE_FIDELITY.md). Earlier first-use evidence for 0.7.3 remains in [readiness-073](evidence/readiness-073/).
