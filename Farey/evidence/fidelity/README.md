# Source-fidelity evidence

Native 0.7.1 (build 9), browser 0.6.1; 22 October 2026. See the [interpretation audit and next-work plan](../../SOURCE_FIDELITY.md).

App-generated screenshots:

- [Native q=1 projection](31-boundary-chart.png) and [settled integer lattice](32-construction-lattice.png).
- [Native convergent/mediant explanation](18-canonical-convergents.png), [Sources](00-sources.png) and its [scrolled provenance text](00-sources-boundary.png).
- [Browser q=1 projection](browser-boundary.png), [integer lattice](browser-integer-lattice.png) and [finite-expansion conventions](browser-conventions.png).

The reference viewer's screenshots and source downloads are not redistributed. [Provenance](provenance.json) records the public source URLs and hashes, the live 3/5 observation, and the limitation that the 1985 paper's full text was not accessed.

[Arithmetic sweep](math-sweep.json) covers 40,000 positive input pairs with numerator and denominator at most 200. The 34,196 accepted inputs passed all checks; 5,804 exceeded the 24-move cap. The independently reviewed sweep and regression tests are bounded execution evidence, not formal proofs.

The browser JSON files record actual source/static Playwright checks of labels, animation completion, state preservation, real WebGL context loss/restoration, keyboard controls, portrait/landscape layout and malformed saved state. These were desktop Chromium sessions. No immersive WebXR session was requested. The [static manifest](static-manifest.json) contains hashes for all 14 generated files.

[Full native results](native-full-summary.json) record 22 passing simulator tests. [Focused native results](native-focused-summary.json) record eleven model/renderer tests plus the construction UI scenario. The final Sources-only scrolling correction then passed a [separate UI recheck](native-layout-summary.json), including scrolling to the full provenance text and returning to the scene. The renderer tests inspect RealityKit entity positions, visibility and accessibility labels; they do not test spoken VoiceOver output. [Device build](device-build.json) records a signed Release build and strict signature verification using existing signing material. It does not record physical-headset execution.

To launch the simulator demo from the repository root:

```sh
cd Farey
build_root="$(python3 scripts/prepare-local-build.py)"
simulator_id=D2ECE520-ED92-4A38-A990-AE65431DF562
xcodebuild -project "$build_root/FareyVision.xcodeproj" -scheme FareyVision \
  -configuration Debug -destination "platform=visionOS Simulator,id=$simulator_id" \
  -derivedDataPath "$build_root/DerivedData" -jobs 2 CODE_SIGNING_ALLOWED=NO build
xcrun simctl bootstatus "$simulator_id" -b
xcrun simctl install "$simulator_id" "$build_root/DerivedData/Build/Products/Debug-xrsimulator/FareyVision.app"
xcrun simctl launch "$simulator_id" com.alok.FareyVision --showcase
open "$(xcode-select -p)/../Applications/DeviceHub.app"
```

This opens **Farey — Into the Infinite** with the stationary 3/5 showcase. Choose **Construct** to inspect the staged explanation. Next/Back do not move the camera. Animate reveal is opt-in; Stop settles at integer positions. Done restores the ordinary scene, Reset restores the initial state, and Exit returns to the entry window.

Immersive WebXR, physical-headset performance and spoken VoiceOver behavior remain unverified. Reference images and recordings are not included in this evidence.
