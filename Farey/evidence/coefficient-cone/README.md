# Coefficient-cone evidence

Native 0.9.0 (12), browser 0.8.0. These are captures of our original implementation, not screenshots of Stange’s viewer.

- `main-devicehub.png`: actual Device Hub window after installing native 0.9.0; geometry is visibly present. `main-simctl-incomplete.png` from the same launch omitted the geometry and is retained as evidence of the unresolved capture limitation.
- `native-oblique.png`, `native-other-side.png`, `native-side.png`: synchronized captures from the focused simulator walkthrough, using the same coefficient-space construction from different placements.
- `browser-oblique.png`, `browser-other-side.png`: actual browser views of the noncoplanar cloud and its projection disk.
- `browser-cloud.png`: projection hidden; the source cloud remains in three dimensions.
- `browser-phone.png`, `browser-landscape.png`: Chromium at 390×844 and 844×390. These do not establish physical-phone or Safari behavior for the new scene.
- `browser-validation.json`: source/image positions, distinct view positions, actual sphere-click result, state checks, context recovery and mocked unsupported-graphics fallback.
- `coefficient-subpath.json`: the new scene loaded from `/dist/`, selected a scalar multiple and made no external requests.
- `legacy-browser-validation.json`, `legacy-package-offline.json`: preserved Farey L/R page and packaged offline checks.
- `focused-native-tests.json`: the 2-test tilted-scene simulator walkthrough. The complete suite is recorded separately when finished.
- `provenance.json`: public-source hashes; original reference media was not redistributed.
- `package-validation.json`, `package-zip.json`: exact local package identity. No public deployment or upload occurred.

The native simulator capture limitation documented in `../../LIFECYCLE_CAPTURE_AUDIT.md` remains: a successful still does not prove every compositor frame is complete. No physical headset or immersive WebXR session was tested. No GPU frame-rate result is claimed.
