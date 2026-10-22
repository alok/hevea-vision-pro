# Native deep-path evidence

Native 0.8/build 10, Debug, visionOS 27.2 simulator. Runtime source matches the pre-audit app; only tests, recording tools and documentation changed. See [the interpretation and reproduction commands](../../NATIVE_PRECISION_AUDIT.md).

The screenshot run used disposable simulator `D019A0B3-ACCD-495C-AE89-60268B803615`; the video-only control used `C29A0119-7070-40E7-9E1B-7F2D17430E8F`. Both were removed afterward. The main showcase was not targeted.

| Image | What it records |
| --- | --- |
| `002-deep-counterexample-front.png` | **Partial capture**: 2419/1546 labels are correct, but parts of the disk, title and controls are absent. |
| `003-deep-counterexample-left.png` | Oblique 2419/1546 disk; geometry and controls present, title partly absent. |
| `004-deep-counterexample-lattice.png` | Same exact target outside grid 12; finite lattice and explicit explanation. |
| `005-deep-limit-front.png` | Complete 121393/75025 disk capture with overlapping markers and distinct exact labels. |
| `007-deep-repeated-L.png` | **Partial capture** of 24/1 < 25/1 < ∞; do not treat missing regions as intended geometry. |
| `008-video-counterexample-front.png` | Complete 2419/1546 frame extracted from the video-only control. |

Images are unaltered 3840×2160 captures or decoded frames. `images.json` records hashes. The video frame time is approximate relative to the recording command; its displayed fraction and word were visually checked.

`mesh-audit.json` records 15 actual generated-mesh inspections (five states × three viewpoints). `screenshot-states.json` and `video-states.json` contain the UI's exact values at seven checkpoints. Test summaries distinguish the first two-test run from the final 16-test run. `runtime-source-hashes.json` identifies all runtime Swift sources, including FareyCore. `screenshot-timing.json` contains request/completion times, which are not GPU presentation guarantees.

The local export is `Farey/evidence/demo-package/deep-path-control.mp4`: 82 seconds, 1920×1080, H.264, 30 fps, no audio; full decode succeeded. It is excluded from Git and has not been uploaded. The 121-second raw control remains at `/tmp/farey-deep-video-20261022/native-raw.mp4`. `video-validation.json` records hashes and the limited visual screening.

No app geometry workaround, hardware test, actual WebXR session, tracking-consent grant or external upload occurred.
