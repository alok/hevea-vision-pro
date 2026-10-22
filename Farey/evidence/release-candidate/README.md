# Release-candidate integration evidence

Native **0.8.1/build 11**, browser **0.7.4**, 22 October 2026. This pass adds no application features. See [current demo readiness](../../READER_READINESS.md) for launch instructions and limits.

`native-summary.json` records **33/33** passing tests in one disposable visionOS 27.2 simulator: 16 model/renderer tests and 17 UI scenarios. The new showcase test launches the Debug presentation path, verifies RLR / 3/5 / grid 12 / Left / lattice, exercises L → 5/8 → Undo → 3/5 → Reset, and exits. Other scenarios cover the lesson, input bounds, restoration, repeated lifecycle transitions, projected selection, inspected multiples and precision notice. This full run requested no still images.

After that pass, the same build was installed on the main simulator. `main-installed.json` records the upgrade from 0.8/build 10 to 0.8.1/build 11. `main-binary-match.json` confirms that the installed executable and Debug dylibs match the tested build. A separate main-simulator readback test passed **1/1**; `main-ui-state.json` and `main-readback-tests.json` record its actual controls and state.

The app was then relaunched with `--showcase`, and `main-081-showcase.png` was manually checked for RLR, 3/5, lattice, grid 12 and Left view. The first post-launch image was still an entrance transition and is not used as presentation evidence. The main app remains running in the final captured state. `images.json` records the unaltered screenshot hashes.

Browser checks used the exact extracted ZIP identified by `browser-artifact.json`. Clean profiles verified saved point/grid restoration, corrupt-state handling, offline interaction, portrait/landscape layout, attribution, unsupported graphics/XR and loader failures. `browser-first-use.json`, `browser-keyboard.json` and `browser-precision.json` record the demonstration sequence and accessible keyboard interactions. Both root and subdirectory routes passed; no unexpected external requests were made.

The first browser smoke invocation timed out waiting for readiness. Its page state was not collected at that moment. Diagnostic root/subdirectory checks and the unchanged original command subsequently passed. `browser-initial-timeout.json` preserves this limit; no runtime workaround was added.

The disposable simulator and browser processes were closed. The main simulator alone remains booted. Blog source/preview windows, consent and upload boundaries were not changed. Capture completeness, physical headset behavior, actual WebXR sessions and spoken screen-reader output remain unverified; no public deployment or Library upload occurred.
