# Simulator evidence matrix

Status date: 2026-08-29

Every generated run records the git revision, Xcode build, runtime, device UUID, scenario, repetition, launch PID, screenshot and log hashes, storage accounting, and known claim ceiling. Receipt schema 2 also compares every screenshot with an app-terminated runtime baseline. A PID and a syntactically valid PNG are insufficient: if the screenshot is byte-identical to the baseline, the visible-delta step fails and the overall run cannot be `passed`.

## Reduced-sphere release matrix

The current public evidence is the retained
[schema-2 JSON receipt](simulator-evidence/reduced-sphere-release-matrix-20260829.json).
The raw 469.68 MiB run remains local because it contains duplicate build logs
and 28 full-resolution captures; seven human-inspected release captures are
promoted below.

| Field | Value |
|---|---|
| Run ID | `20260829T233057Z-47702` |
| Repository revision | `136a06209d593301fddaa8135ec5bae40c0ee048` |
| App-source revision | `bdb56b834af1eadcc9136ad27d8e7ebf057a9427` |
| Toolchain | Xcode 27 beta 5, build `27A5237l` |
| Matrix | 7 scenarios × 2 repetitions × 2 runtimes = 28 rows |
| Scenarios | `mission-control`, `sphere-atlas`, `sphere-habitat`, `sphere-hover`, `sphere-interior`, `sphere-stage-sweep`, `sphere-navigation-stress-1000` |
| Artifacts | 94 local files, 492,494,406 bytes (469.68 MiB) |
| Free disk | 17,420,242,944 bytes before; 16,292,524,032 bytes after |
| Result | **partial** |

`136a0620…` differs from its app-source parent `bdb56b83…` only in the
sphere-specific 200-change UI test. The matrix therefore binds the installed
app to the production app source while retaining the exact test/evidence head.

| Runtime | Build/install | Launch PIDs | PNG captures | Visible delta from baseline | Filtered logs | Interpretation |
|---|---:|---:|---:|---:|---:|---|
| visionOS 26.5, build `23O470` | 14/14 | 14/14 | 14/14 | **14/14 passed** | 14/14 | All captures changed from the empty-room baseline; the named release images below were also inspected by a human. |
| visionOS 27.0 beta, build `24M5348a` | 14/14 | 14/14 | 14/14 | **0/14 passed** | 14/14 | Every capture has SHA-256 `919534fb…` and is byte-identical to the app-terminated baseline. This is launch-only beta evidence, not rendered-app evidence. |

A baseline-different screenshot proves only that visible pixels changed after
launch. It does not prove that the intended sphere, gauge, stage, or receipt
is present. Named screenshots were promoted only after manual visual
inspection. Unified logs are cumulative two-minute queries; collection
success does not bind every line in a log to that row's launch PID.

### Curated visionOS 26.5 release captures

Both repetitions of each gauge were byte-identical. Repetition 1 was promoted
without cropping or compositing. Each source image is 3840 × 2160 pixels.

| Destination | Scenario / rep | SHA-256 | Human inspection outcome |
|---|---|---|---|
| [Mission Control](screenshots/sphere-mission-control-visionos-26-5.png) | `mission-control` / 1 | `49545a4604785a50d2d72934c72a2251af10263bdbbcd32812a5390b83b3a946` | Complete reduced-sphere control surface, construction rail, gauge selector, address, and immersion entry are visible. |
| [Atlas](screenshots/sphere-atlas-visionos-26-5.png) | `sphere-atlas` / 1 | `46cd853171746aad98efbb15bc68797ee716b4b911573296600a0a4e4d751253` | Complete corrugated proxy, Atlas receipt, gauge card, address card, and instrumentation are visible. |
| [Habitat](screenshots/sphere-habitat-visionos-26-5.png) | `sphere-habitat` / 1 | `54f497d23f4e5d1f2ecc89b8cb8de44be85b11b81db512280b5f019381aa0505` | Habitat receipt, foot-scale gauge, address, and walk pad are visible. The underfoot shell is outside the simulator's forward capture frustum. |
| [Hover](screenshots/sphere-hover-visionos-26-5.png) | `sphere-hover` / 1 | `2845aa6e4c5835b76eab889b04079a56c667d1137384ea5ef8e40199ea3ef4ec` | Hover receipt, signed-altitude gauge, and address are visible. The near-field shell is outside the simulator's forward capture frustum. |
| [Interior](screenshots/sphere-interior-visionos-26-5.png) | `sphere-interior` / 1 | `135b57037c42bd85e49b5b36a21d24d173e9096efae8b9841e2d86af8c99ee82` | Inward-facing corrugated shell, Interior receipt/gauge, address, Return Habitat, and Exit Lab are visible. |
| [Short map](screenshots/sphere-short-map-visionos-26-5.png) | `sphere-stage-sweep` / 1 | `c50fd3177f4ed6ae128353bdf37a09b0b005f5774bfc5716722db109eb501bd0` | Complete striped short-map proxy and stage-specific receipt are visible. |
| [Family 1](screenshots/sphere-family-1-visionos-26-5.png) | `sphere-stage-sweep` / 2 | `2fb512f5e8f6c0715b84c7e2d892b1baf470149aa0025caafc760ce9c90697d8` | First nested corrugation belt and Family 1 receipt are visibly distinct from Short map. |

The `sphere-stage-sweep` matrix rows are two deterministic samples only:
repetition 1 renders Short map and repetition 2 renders Family 1. Coverage of
all five construction stages comes from the immersive lifecycle UI workflow,
not from these two screenshot rows.

### Selected sphere UI workflows on visionOS 26.5

These are selected, individually retained workflows—not a claim that the
entire UI-test target passed in one monolithic run. Xcode-exported UI
attachments were one-pixel placeholders, so only the independent
`simctl` captures above are presented as screenshots.

| Workflow | Exact evidence | Result |
|---|---|---:|
| Mission Control and construction rail | Named controls plus exact stage requests; separate immersive lifecycle run awaits rendered receipts for all five sphere stages, dismisses, reopens, and dismisses again | passed |
| Four coordinated gauges | `testSphereRegimeCyclePreservesIntrinsicAddressAndExposesInteriorEscapeControls()`; stable intrinsic-address token, current presentation receipt in each regime, Interior controls present and hittable; 49.028 s | passed with activation boundary |
| Deterministic launch-hook navigation | `testSphereNavigationStressHookReportsExactlyOneThousandIntrinsicSteps()`; current `Presented Habitat` receipt and `Address step #1000`; 21.501 s | passed |
| Acknowledged walk-pad updates | `testImmersiveSphereWalkPadSurvivesFiveHundredRealityViewReanchors()`; every tap awaits its matching RealityKit presentation receipt | passed |
| Stage/regime convergence | `testSphereStageAndRegimeSpamConvergesAfterTwoHundredChanges()`; 100 stage and 100 gauge requests; final Family 3 + Atlas receipt; address preserved | passed |

The Interior attachment's Return Habitat and Exit Lab controls were visible
and reported hittable on visionOS Simulator 26.5. Two synthesized attempts to
activate Return Habitat did not produce a Habitat presentation receipt, so
that activation path remains unverified on both simulator and physical Vision
Pro. Ordinary gauge controls and app-model state transitions are separately
tested; they do not prove activation of the Interior escape attachment.

### Revision-bound 500-update walk

The compact public receipt is
[`sphere-walk-500-visionos-26-5.json`](simulator-evidence/sphere-walk-500-visionos-26-5.json).

| Field | Final run value |
|---|---|
| Test | `testImmersiveSphereWalkPadSurvivesFiveHundredRealityViewReanchors()` |
| App-source revision | `bdb56b834af1eadcc9136ad27d8e7ebf057a9427` |
| Simulator | Apple Vision Pro, visionOS 26.5, build `23O470` |
| Device UUID | `820CCDAA-EA00-41FC-8A4A-675701BD9E33` |
| Synthesized accessibility taps | 500, repeating `forward, right, left` |
| Receipt contract | after every tap, await `Presented Habitat · address step #n · …` emitted after matching presentation-transform application |
| Final state witness | `Address step #500`; foreground liveness checks; clean dismissal and Mission Control return |
| Acknowledgement loop | `905.2148829698563` seconds |
| Complete test case | `934.0711989402771` seconds |
| Result | passed, 1/1 |
| Canonical summary SHA-256 | `9d42955b9c9bd9bec12702c4fb00b0c4c7e1eb610860702dbce7652288406924` |
| Canonical tests SHA-256 | `4504fc27a56b552d1125daedfc07eb75009def48d4982a18376bd3b3fda80cc7` |
| Canonical test-details SHA-256 | `e7ccdb394a64ff745331810719412f757f3b41c7de3c9431032b78377d80d215` |
| Text receipt SHA-256 | `f071673e44592915b893de116d4ab8ffc3465a34b7389eb931ca0b0a47bad3a2` |

This establishes 500 acknowledged simulator-side intrinsic-state and
RealityKit presentation-transform updates on one installed mesh. It is not
500 mesh regenerations or 500 new anchors, and it is not evidence of physical
footsteps, headset comfort, collision behavior, or eye/hand interaction.

### Revision-bound 200-change sphere convergence

The compact public receipt is
[`sphere-stage-regime-200-visionos-26-5.json`](simulator-evidence/sphere-stage-regime-200-visionos-26-5.json).

| Field | Final run value |
|---|---|
| Test | `testSphereStageAndRegimeSpamConvergesAfterTwoHundredChanges()` |
| Repository revision | `136a06209d593301fddaa8135ec5bae40c0ee048` |
| Simulator | Apple Vision Pro, visionOS 26.5, build `23O470` |
| Requests | 100 construction-stage requests + 100 gauge requests |
| Final state witness | Family 3 + Atlas presentation receipt; intrinsic address preserved |
| Change loop | `122.4232269525528` seconds |
| Complete test case | `163.39902102947235` seconds |
| Result | passed, 1/1 |
| Canonical summary SHA-256 | `e106571a8e291cdfef5e8783a489f40359b85746f0a3adf647965a8ed6bbef65` |
| Canonical tests SHA-256 | `4e9977cf5b790e3f8398a002c83bfce5257febe23ec75080ea53377abdacd316` |
| Canonical test-details SHA-256 | `f54f4f9721428c6dbd7d1ba1fbc08689684ac7e6394efe674a8b129a51725c42` |
| Text receipt SHA-256 | `ee826fd5320f27ede07047c84f12086ad87671284954b78152adbad111cc4d3c` |

The supported claim is request churn, foreground survival, address
preservation, and convergence to the last requested stage/gauge—not 200
separately completed mesh generations.

### Reproduce the sphere matrix

```bash
Scripts/run-simulator-matrix.sh --preflight-only

Scripts/run-simulator-matrix.sh \
  --runtime all \
  --scenarios mission-control,sphere-atlas,sphere-habitat,sphere-hover,sphere-interior,sphere-stage-sweep,sphere-navigation-stress-1000 \
  --repetitions 2 \
  --settle-seconds 6 \
  --min-free-gib 12
```

## Archived flat-torus two-runtime run

| Field | Value |
|---|---|
| Run ID | `20260829T201738Z-57215` |
| Revision | `e56f7fa0c81bf0090e7ed585a15aa705fc14b11a` |
| Toolchain | Xcode 27 beta 5, build `27A5237l` |
| Matrix | 4 scenarios × 2 repetitions × 2 runtimes = 16 rows |
| Scenarios | `mission-control`, `stage-sweep`, `metric-heatmap`, `scale-microscope` |
| Artifacts | 58 local files, 122.36 MiB; raw runs are ignored rather than published automatically |
| Result | `partial` |

| Runtime | Build | Launch PIDs | PNG captures | Visible delta from baseline | Filtered logs | Interpretation |
|---|---:|---:|---:|---:|---:|---|
| visionOS 26.5 | passed | 8/8 | 8/8 | **8/8 passed** | 8/8 | Current public screenshots and visual scenario evidence come from this runtime. |
| visionOS 27.0 beta | passed | 8/8 | 8/8 | **0/8 passed** | 8/8 | Every capture has SHA-256 `919534fb…` and is byte-identical to the empty-room baseline. No rendered-app claim is allowed. |

The 27 beta behavior was reproduced after terminating, uninstalling, reinstalling, and relaunching the app. A targeted Xcode 27 UI run initially exposed the Mission Control accessibility hierarchy, then failed while trying to reactivate the app because it was `Running Background`; Xcode's test finalizer also hung and had to be interrupted. This is retained as a beta-runtime/tooling blocker, not generalized into an app or shipping visionOS 27 claim.

### Archived torus UI workflows on visionOS 26.5

Each workflow passed individually against simulator `820CCDAA-EA00-41FC-8A4A-675701BD9E33`:

| Workflow | What it establishes | Result |
|---|---|---:|
| Mission Control accessibility and stage rail | Root cards and every control are exposed; `0 → 1 → 2 → 3 → 2 → 1 → 0` reaches the expected named stages | passed |
| Diagnostic overlays | Surface, Grid, Metric, Normals, and Direction each expose the expected explanation after selection | passed |
| Immersive lifecycle | Open full immersion, await generated geometry, cycle all stages, dismiss, reopen, and dismiss again | passed |
| Deterministic metric scenario | Repetition 2 relaunches with the same selected-sample label | passed |
| Inside-view contract | Outside changes to Inside; close-range Return Outside and Exit Lab controls are present and hittable | passed with boundary |
| Rapid immersive stage churn | 200 consecutive spatial stage-control updates, foreground checks every 25 updates, final geometry/sample convergence, and clean dismissal | passed |

The inside-view boundary matters: visionOS automation could assert the close-range escape controls' presence and hittability but did not reliably activate them after the model surrounded the simulated observer. The state transition and reset logic are app-model tested; physical-device interaction remains pending.

### Archived torus 200-update churn

The dedicated high-count workflow ran twice on visionOS 26.5. The final run was executed from clean public revision `4e17464aaa0acdfbe1f0a25d5370d0c8323924a4` and retained a local `.xcresult` plus text attachment.

| Field | Final run value |
|---|---|
| Test | `testImmersiveStageRailSurvivesTwoHundredRenderedUpdates()` |
| Simulator | Apple Vision Pro, visionOS 26.5, build `23O470` |
| Device UUID | `820CCDAA-EA00-41FC-8A4A-675701BD9E33` |
| Spatial control updates | 200 |
| Foreground liveness checks | every 25 updates |
| Final state witness | `Proxy Stage 3` plus `Selected sample #…` |
| Transition-loop time | `121.64274489879608` seconds |
| Complete test-case time | `151.53133296966553` seconds |
| Result | passed; zero failures, clean immersive dismissal |
| Canonical summary SHA-256 | `700559dfb3bcd4b029212961dbe66e57970c2fc237e3f7204a28ed3b3e9f1d34` |
| Canonical tests SHA-256 | `6bac09493cbb9f8b567d9619245ce987f71f8ce54117d300278ae7cc0f3a7ff7` |
| Text receipt SHA-256 | `dbb1cd50284029e9f6ee7c7d7ba6c278ca1c0d84344f97a6713eb2cdfb17ef3f` |

The test changes the visible stage and requests asynchronous regeneration on every tap. Intermediate generation tasks may be cancelled or coalesced when a newer request arrives, so the supported claim is UI/renderer-task churn, foreground survival, and convergence to the latest requested geometry—not 200 separately witnessed completed meshes. The public [curated JSON receipt](simulator-evidence/stress-200-visionos-26-5.json) records the exact boundary. The 9.9 MiB raw result bundle remains local and ignored.

### Archived torus acceptance backlog

| ID | Scenario | Current evidence | Status |
|---|---|---|---:|
| S01 | Clean build, install, and first launch | 26.5 build/install/visible capture; 27 beta build/launch without visible delta | partial |
| S02 | Open, dismiss, and reopen immersion | Dedicated 26.5 UI workflow | passed on 26.5 |
| S03 | Cycle every construction stage both ways | Dedicated 26.5 UI workflow | passed on 26.5 |
| S04 | Toggle every overlay | Dedicated 26.5 UI workflow plus named visual scenarios | passed on 26.5 |
| S05 | Manipulation bounds and exact reset | Bounded model-scale and reset unit tests; no automated spatial gesture sweep | partial |
| S06 | Deterministic sample selection | Immersive workflows await finite selected-sample diagnostics | passed on 26.5 |
| S07 | Inside/outside and recovery | State change plus escape-control accessibility; physical activation pending | partial |
| S08 | High-count rapid stage/overlay churn | Revision-bound 200-update immersive stage-control workflow with final geometry/sample convergence | passed on 26.5 |
| S09 | Relaunch policy | Deterministic metric relaunch and immersive dismiss/reopen workflows | passed on 26.5 |
| S10 | Curated screenshot scenarios | Four inspected 26.5 captures; 27 beta correctly rejected | partial |

### Reproduce the archived torus matrix

```bash
Scripts/run-simulator-matrix.sh --preflight-only

Scripts/run-simulator-matrix.sh \
  --runtime all \
  --scenarios mission-control,stage-sweep,metric-heatmap,scale-microscope \
  --repetitions 2 \
  --settle-seconds 6 \
  --show-simulator
```

The fixed UDIDs in the harness identify this development machine's installed simulators and must be adapted elsewhere. Generated runs remain local until a human reviews and curates them. The script does not erase devices, remove simulator app data, shut down simulators, or delete DerivedData.

Simulator evidence does not validate physical-headset comfort, device frame rate, eye/hand tracking quality, accessibility in use, or real-room compositing.
