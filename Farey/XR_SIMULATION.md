# Browser 0.12.1 XR simulation verification

October 22, 2026. The live localhost double-cone app was exercised in **actual `immersive-vr` sessions provided by official Immersive Web Emulator 2.0.0**, simulating Quest 3 in the user's main Chrome. This is browser simulation, not physical headset validation. The native Meta OpenXR Simulator is a separate runtime and was not used as proof of Chrome WebXR execution.

Two reproduced camera defects are fixed: Three.js XR changes the desktop camera's field of view and zoom; those are now saved and restored. Disabled OrbitControls still enforces its orbit constraints if `update()` is called; restoration now skips that call for a disabled first-person controller. Before the second fix, a real Origin reproduction moved the camera one metre and nearly π radians. Afterward the same browser test using real OrbitControls has zero position and orientation drift.

| Check | Observed result |
| --- | --- |
| Promoted browser 0.12.1 | Main Chrome localhost tab reloaded; live and source XR helper SHA-256 `29aeb1cc36611aa23fb55e63774535a7293a9e7ce106b93eed00067e05685838` |
| Stereo session | Real XRFrame contains `left` and `right` XRViews, eye separation 0.063 m; stereo mirror visibly renders both views |
| Head translation, 0.12.0 before camera fixes | Emulator's normal headset-X control moved measured head from x=0 to 0.25 m; eye and controller-ray poses moved correspondingly |
| Controller selection, 0.12.0 before camera fixes | Normal emulator right trigger selected exterior `(1,0,-1)`, giving plane `2a−2c=0`, endpoints −1 and +1; controller-driven in-world Exit ended the session |
| Apex, 0.12.1 | Programmed emulator head at world `(0,1.4,−3.1)` produced real frames at that position; ±90° X orientations looked into upper and lower nappes |
| Lifecycle, 0.12.1 | Three entries and three end events; Origin remained selected after exit, with eye label `(0,0,0)` and upward orientation; Return to overview restored a usable oblique scene |
| Mathematical state | Restored user's `(1,0,−1)` selection and exact cutting plane after testing; reference viewer left intact beside the app |
| Regression | 68 unit/package tests; actual-browser coefficient, pair-plane, Debug and context-loss walkthroughs passed; real OrbitControls reproduction passed |

[Structured frame and regression evidence](evidence/browser-0.12.1/checks.json) retains exact measured positions and projection matrices. Raw screenshots remain local, showing the stereo overview, upper/lower apex views and restored desktop Origin. No private recordings or browser context are included in this package.

A temporary DevTools observer requested frames from the actual returned session; it did not fabricate XRViews or replace rendering. Apex poses used the installed runtime's programmatic pose mode, then restored manual mode. No remote-agent connection, OS tracking grant or security setting was added. Initial direct pose assignments in manual mode were overwritten by the emulator rig; those attempts are excluded from apex evidence. Early console probes also produced test errors, so this document does not claim the extension-filled main Chrome console was clean. Isolated application regressions separately check page errors.

At the apex, only the cyclopean head position is at the origin: stereo eyes remain separated. This is ambient Euclidean navigation around coefficient space, not intrinsic hyperbolic motion. The zero polynomial has no unique root/projective point. Lower-category coloring remains a display choice; opposite nonzero forms share roots.

Remaining: physical Quest/Vision Pro tracking, controller/hand usability, GPU frame rate and comfort; current coefficient-page Safari/touch and assistive speech; dense-cloud ray ambiguity and opacity-ordering audit; native parity with browser Origin/dense signed cloud/plane controls. The physical Vision Pro was unavailable on the latest supported device query; installation has not occurred. Public hosting and private uploads remain separate pending actions.

## Local package

`WebXR/output/Farey-WebXR-0.12.1.zip` is 588,518 bytes; SHA-256 `0ab1c4112b7f7618618ac22f5943aa3c56f6aeb618928727f9c9ae2e8126a80f`. Its 73-file manifest SHA-256 is `dcbe1a656859efbc8b6e8a155375ea0fa0f788e63aafb8f19931a54460a689fe`. The ZIP was unpacked outside the checkout and checked using its own local server. Both pages passed clean-profile offline/mobile/state/failure checks with no external runtime requests or page errors. That isolated package smoke does not request XR; actual IWE evidence above comes from the promoted identical runtime code in main Chrome.

To reproduce, unpack the ZIP, run `python3 serve.py --port 8778` in its folder and open `http://127.0.0.1:8778/`. On a browser with an already-authorized IWE installation, enable emulation for this origin and reload. Click Origin, then Enter VR. Use normal emulator headset/controller controls and the in-world Exit; repeat entry and check the restored desktop eye label and view. The emulator stereo-rendering option requires reload. Do not grant physical tracking or change browser security to reproduce the local desktop checks.
