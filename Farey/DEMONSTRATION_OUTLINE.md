# Factual demonstration outline

This is supporting evidence for a blog discussion, not drafted testimony or claims about audience reactions.

## Current recordings

Open the [local playback page](evidence/demo-package/playback.html), or open either MP4 directly. The video files are local delivery artifacts and are intentionally excluded from Git; the screenshots, capture helpers and verification records are committed.

| Recording | Actual environment | Length / size |
|---|---|---|
| [Native walkthrough](evidence/demo-package/native-demo.mp4) | Farey 0.6.1, build 7; visionOS 27.2 simulator | 81.46 s / 1,139,303 bytes; 1920×1080 |
| [Browser walkthrough](evidence/demo-package/browser-demo.mp4) | Browser companion 0.5.1; Chromium 155 on macOS | 39.00 s / 803,823 bytes; 1440×1000 |

Both are silent H.264 MP4 files with progressive playback metadata. Neither contains desktop windows, private recordings or Stange's media. Both were fully decoded without errors, played with advancing time in Chromium, and sought near the end to confirm playback completes. These checks establish local desktop playback; iOS delivery playback has not been tested. [File hashes and versions](evidence/demo-package/manifest.json) · [Playback verification](evidence/demo-package/playback-validation.json).

The application source in both recordings is commit `490a7d1ed5e7ae2f47384cfa5bd30e7b559ef93d`. The native tour ran on a disposable simulator; the user's existing 3/5 showcase remained available. The browser clip trims idle time after its final demonstration state. The native clip preserves the continuous recorded timeline. Still-frame capture markers are approximate timing guides.

## Demonstrable sequence

| Topic | What the recording establishes | Representative frame |
|---|---|---|
| Spatial construction | Integer lattice points and a perpendicular plane containing the chosen rational ray; a deliberate change of viewpoint exposes depth. | [Browser orbit](evidence/demo-package/browser-orbit.png) |
| Predict, apply, explain | Starting at 1/2, L selects 2/3 and R then selects 3/5. The explanation and scene use the same exact state. | Native approximately 14–29 s; browser approximately 8–14 s |
| Point versus direction | Selecting 6/10 retains the point (10,6), reduces the rational to 3/5, and explains `(10,6) = 2 × (5,3)`. | [Native inspector](evidence/demo-package/native-point-reduction.png) · [Browser inspector](evidence/demo-package/browser-point-reduction.png) |
| Convergent distinction | For canonical `[0;1,1,2]`, 2/3 is an intermediate mediant. In equivalent `[0;1,1,1,1]`, it is a convergent. The target 3/5 and inspected point remain fixed. | [Native alternate form](evidence/demo-package/native-convergents.png) · [Browser alternate form](evidence/demo-package/browser-convergent.png) |
| Separate spotlight | Choosing an approximant adds double white rings without selecting a different target rational. Gold identifies convergents of the chosen expansion. | Native approximately 47–65 s; browser approximately 18–30 s |
| Linked representation | Native switches to the Poincaré disk with the same selected state, then exits and re-enters immersion. The browser recording shows the lattice only. | [Native linked disk](evidence/demo-package/native-linked-disk.png) |

The native recording test passed its assertions; the browser walkthrough passed with no page errors. This supplements the [release audit](DEMO_READINESS.md): 23 core tests, 17 native model/UI tests and 22 JavaScript tests. It does not establish mathematical proof, educational efficacy or hardware interaction quality.

## Attribution and boundaries

Credit **Katherine Stange** prominently beside her [talk](https://katestange.net/talks/math-exploration/) and [visualization catalog](https://www.katestange.net/code/). Credit **Caroline Series**, [The Modular Surface and Continued Fractions (1985)](https://doi.org/10.1112/jlms/s2-31.1.69), for the underlying L/R geodesic coding. Continued-fraction terminology follows [DLMF §1.12(ii)](https://dlmf.nist.gov/1.12.ii).

This is an independent implementation, not an official port, endorsement or reproduction of an infinite fractal. No Stange source or media is bundled; attribution does not imply a software license. New application code follows the repository's GPL-3.0-or-later license; Three.js is MIT-licensed. Lattice coordinates and rational operations are exact within stated bounds; meshes, line samples, physical placement, colors and finite plane height are display choices.

Native full immersion is demonstrated in a simulator. No physical-headset installation or execution occurred. The browser video demonstrates desktop 3D, not an immersive WebXR session. VisionOS Safari's position/head-movement consent remains ungranted; no actual XR frames, hand/controller performance or headset comfort claim is supported. No public deployment, Meta affiliation or third-party video upload is claimed.

## Source comparison and next bounded increment

On 2026-10-22, the [live source viewer](https://katestange.net/talks/math-exploration/viewers/farey-cf-lattice.html) accepted a click on 3/5 and showed its Tessellation, Dots, Lattice and Labels stages. Its rational number-line view becomes a view of lattice spheres, then an elevated view of the same direction plane, and finally a labelled overhead lattice. The final view includes signed rational labels. Reference screenshots remain in `/tmp`, outside the repository.

The substantive gap is the missing construction between representations. Native currently switches between a Poincaré disk and lattice; the browser starts directly in the lattice. A useful next increment is an optional, manually advanced **boundary-to-lattice explanation** preserving one selected rational and point across stages. It should explain the projective correspondence and keep camera movement opt-in. This is a source-fidelity/teaching improvement, not a defect in the current bounded rational arithmetic. Extending the selectable signed domain is separate work.

## Reproduce capture

From `Farey`, with the existing Xcode/visionOS runtime:

```sh
PATH=/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin \
  python3 scripts/record-demo.py --output /tmp/farey-demo-new
ffmpeg -i /tmp/farey-demo-new/native-raw.mp4 \
  -vf scale=1920:-2,fps=24 -c:v libx264 -crf 24 -preset veryfast \
  -threads 2 -filter_threads 1 -pix_fmt yuv420p -an -movflags +faststart \
  /tmp/farey-demo-new/native-demo.mp4
```

The helper appends `scripts/demo-tour.swift` only to a temporary build's existing UI-test source. It creates a disposable simulator, starts recording after the entry window appears, asserts the demonstrated states, then removes that simulator. It refuses to overwrite an existing raw video and does not modify ordinary app/test sources.

For the browser, start `npm start` in `WebXR`, then use the existing Playwright CLI from the same working directory:

```sh
playwright-cli -s=farey-demo open http://127.0.0.1:8080/ --headed
playwright-cli -s=farey-demo video-start /tmp/browser-demo-raw.webm --size=1440x1000 --fps=24
playwright-cli -s=farey-demo run-code --filename demo-walkthrough.js
playwright-cli -s=farey-demo video-stop
ffmpeg -i /tmp/browser-demo-raw.webm -vf fps=24 -c:v libx264 -crf 23 \
  -preset veryfast -threads 2 -filter_threads 1 -pix_fmt yuv420p -an \
  -movflags +faststart /tmp/browser-demo.mp4
playwright-cli -s=farey-demo close
```

The capture script writes app-only screenshots to `output/playwright/`. The CLI's raw recording uses VP8/WebM; encoding it as H.264 MP4 is required for the delivery format above. A new run's duration may differ with UI timing.
