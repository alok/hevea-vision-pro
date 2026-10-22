# Precision-notice evidence

Native **0.8.1/build 11** and browser **0.7.4**. See [the policy and its limits](../../PRECISION_NOTICE.md).

- `native-tests.json`: 17 passing simulator tests, including 16 model/renderer tests and the new notice UI walkthrough.
- `native-states.json` / `native-captures.json`: exact values, notice text and synchronized acquisition timing for the lattice/grid-14 and disk screenshots.
- `browser-source.json` / `browser-static.json`: successful notice interactions, accessibility status, reset and phone checks on source and built app.
- `browser-geometry.json`: the existing scene-coordinate audit still passes after extracting the shared endpoint calculation.
- `exact-state.json`: the independent 56,451-case browser/native oracle remains unchanged.
- `tested-source-hashes.json`: runtime source, build specification and checked-in Xcode project match the tested copy.
- `validation.json`: versions, test counts, archive/manifest hashes and screenshot hashes.

The two native screenshots are unaltered 3840×2160 simulator captures. Browser screenshots show the final static artifact on desktop and at 390px phone width. They are not physical-device, screen-reader speech or WebXR-session evidence.

The local archive is `Farey/WebXR/output/Farey-WebXR-0.7.4.zip` (501,470 bytes). It passed the static manifest/module check and archive integrity check. It has not been publicly deployed or uploaded.

The temporary notice-check simulator was removed. During this earlier check the main showcase remained on native 0.8. The subsequent [release-candidate integration](../release-candidate/README.md) updates it to 0.8.1 and restores the same 3/5 presentation. The earlier capture uncertainty and pending approvals are unchanged.
