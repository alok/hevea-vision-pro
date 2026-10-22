# Safari and compact framing — browser 0.7.2

This increment improves the existing spatial lattice on small screens. It adds no mathematical construction or camera animation. Native visionOS 0.8 was not changed or relaunched.

## Changes grounded in inspection

- A short Safari window (848×562) placed the control panel over much of the lattice. Short, wide windows now use the same separate scene/panel arrangement as phone landscape.
- The compact starting view was distant and aimed below the finite lattice's center. Launch, Reset and Front view now frame the center of the default finite grid more closely. L/R, fraction entry, lessons and spotlights do not move the camera. Resizing retains the orbit direction and adjusts distance for the available aspect ratio.
- The existing q/p letters became too small with perspective. Their world size now follows depth and viewport height to keep each label sprite 28 CSS pixels tall (about a 12px glyph). The points, axes and direction plane retain their mathematical positions. Immersive mode retains the previous world-sized labels.
- Touch fraction/grid inputs use 16px text. Pinch zoom remains available; the viewport is not locked to a maximum scale.

The maximum grid remains 14: 224 nonzero points. The app still distinguishes inspected integer points, primitive directions, L/R mediants, convergents and projected noninteger positions. Stange/Series attribution and the source/licensing boundaries are unchanged.

## Verification

**36/36 Node tests passed.** The new projection test covers both compact starting views, aspect ratios 0.6–3, and the corners of the maximum grid plus its direction-plane height. The label test projects actual Three.js points at different depths, zooms and viewport heights. Existing gesture cancellation and two-finger selection guards still pass.

Five real-browser walkthroughs passed: keyboard/lesson flow, actual pointer selection of 6/10, three browser-generated WebGL loss/restoration cycles, malformed state and resize/background recovery, and 15 crowded projected-direction cases. A focused renderer-inspection check confirmed that selection did not move the camera, the grid stayed within the view, and label sprites stayed 28 CSS pixels tall at 390×699, 390×844, 844×390 and 848×562. Inspection hooks were injected only by the test; none are shipped.

**Actual Mobile Safari:** two acceptance tests passed on a separate iPhone 17e simulator, iOS 27.2 (24B5089g), using Xcode 27.2 beta 2. The tests opened fresh local documents from the packaged build. They verified:

1. Initial 1/1; typed 6/10; reduced target 3/5 with the inspected (10,6) point; grid 14; exact point, word RLR and grid after reload.
2. A new document; the 3/5 example; portrait and landscape; L to 5/8; Undo to 3/5; Reset to 1/1 and grid 12. The landscape scene was separate from the controls.

The [test fixture](WebXR/SafariAudit/README.md) is reproducible and separate from the native app. The final tests use no DOM injection. A separate temporary diagnostic confirmed page scale 1 and identical camera coordinates before/after L and Undo. That diagnostic made only local reports and was stopped; it is not part of the artifact.

Earlier test failures are not counted as passing: Command-A did not reliably replace the mobile field, producing `6/101/1`, which the app correctly rejected. The corrected test checks that ordinary Delete keystrokes clear the field before entering 6/10. A focused document could also become magnified during automated interaction, so the state and layout tests now open separate fresh documents. Some XCTest attachments and post-test `simctl` captures contained partial composites despite passing UI assertions. A complete landscape capture is included; the best observed Safari portrait remains diagnostic because the front of the scene appears cropped relative to the measured bounds. Clean Chromium portraits are included separately. An extra animation-frame repaint did not resolve the capture discrepancy and was reverted. No general simulator capture fix is claimed.

The Safari desktop MCP viewport override did not persist reliably, and its native picker interaction stalled. Its test-owned automation process was closed. Final mobile claims come from Mobile Safari itself, not that override or Chromium emulation. The earlier desktop Safari 0.7.1 check verified startup and restored selection; final compact-layout measurements are from Chromium and Mobile Safari.

## Evidence and package

[Evidence directory](evidence/safari-072/) contains the acceptance summary, browser checks, framing measurements, local diagnostic measurements and inspected screenshots. The package manifest and local archive hash identify the exact build. The new ZIP is `WebXR/output/Farey-WebXR-0.7.2.zip`; binaries remain local and are not committed or uploaded. Launch it using its included `README.txt` and `python3 serve.py --port 8080`.

- [Mobile Safari acceptance](evidence/safari-072/safari-acceptance.json): 2/2 tests passed. [Complete Safari landscape](evidence/safari-072/safari-landscape.png); [portrait diagnostic](evidence/safari-072/safari-portrait-best-observed.png), with the capture limitation above.
- [Chromium portrait](evidence/safari-072/chromium-portrait.png), [landscape](evidence/safari-072/chromium-landscape.png), [root smoke](evidence/safari-072/offline-root.json) and [subdirectory smoke](evidence/safari-072/offline-subdirectory.json).
- [Rebuild](evidence/safari-072/rebuild.json) and [archive verification](evidence/safari-072/archive.json). The 497,137-byte archive SHA-256 is `af002239448bac939aab081f7e5b0306b75497ea49fd9ce130f3aec581196510`; its 42-file payload manifest SHA-256 is `2b2692f8c19d4fb6ba61f2a4fc82904eb6d6e176d1f27ddc09e44c3ffe7ce28e`.

## Remaining limits

- These Safari tests use an iPhone simulator. No physical phone or headset touch/comfort/performance claim follows.
- WebXR tracking consent remains pending. No immersive WebXR session, stereo frame or headset input was observed.
- Native sphere-tap automation and the previously documented native capture uncertainty remain separate open issues. The native showcase was preserved.
- VoiceOver speech and cross-device reading comfort remain untested. Existing keyboard/accessibility semantics were checked; no accessibility settings were changed.
- No public deployment, Library upload, new signing asset or permission grant occurred. The earlier upload denial was not retried.

The next independent fidelity question remains a compact comparison between the q=1 chart and the native disk's selected boundary value, without suggesting that their metrics agree. Further visual controls should follow an observed need rather than expand this demo's scope.
