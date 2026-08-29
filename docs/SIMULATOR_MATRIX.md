# Simulator evidence matrix

Every run records the git revision, Xcode build, runtime, device UUID, scenario, exit status, screenshot path when applicable, and known claim ceiling.

| ID | Scenario | Automated assertion | Visual inspection | Runtimes |
|---|---|---|---|---|
| S01 | Clean build and install | Build, install, and launch succeed | Mission Control is framed and legible | 26.5, 27.0 |
| S02 | Immersion lifecycle | Open, dismiss, and reopen state transitions converge | No duplicate lab or orphaned controls | 26.5, 27.0 |
| S03 | Stage rail | 0→1→2→3→2→1→0 yields expected model state | Geometry changes without jumps or clipping | 26.5, 27.0 |
| S04 | Overlay churn | Every overlay toggles 20 times without crash | Legends and materials match state | 27.0 |
| S05 | Manipulation bounds | Rotation remains finite; scale clamps to bounds; reset is exact | Model stays comfortably framed | 27.0 |
| S06 | Sample selection | Deterministic points return finite diagnostics | Torus and Gauss-sphere highlights agree | 27.0 |
| S07 | Inside/outside | Presentation state toggles and resets | No near-plane clipping or inverted labels | 27.0 |
| S08 | Rapid stage stress | 200 deterministic stage updates complete | Final rendered stage matches final state | 27.0 |
| S09 | Background/relaunch | State restoration follows declared policy | No stale immersive attachment | 26.5, 27.0 |
| S10 | Screenshot scenarios | Named scenarios launch deterministically | README images are accurate and uncluttered | 27.0 |

Simulator evidence does not validate physical-headset comfort, device frame rate, eye/hand tracking quality, or real-room compositing.
