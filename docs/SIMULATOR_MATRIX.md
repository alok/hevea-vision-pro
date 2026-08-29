# Simulator evidence matrix

Status date: 2026-08-29

Every generated run records the git revision, Xcode build, runtime, device UUID, scenario, repetition, launch PID, screenshot and log hashes, storage accounting, and known claim ceiling. Receipt schema 2 also compares every screenshot with an app-terminated runtime baseline. A PID and a syntactically valid PNG are insufficient: if the screenshot is byte-identical to the baseline, the visible-delta step fails and the overall run cannot be `passed`.

## Final two-runtime run

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

## UI workflows on visionOS 26.5

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

## Revision-bound 200-update churn

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

## Acceptance backlog

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

## Reproduce

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
