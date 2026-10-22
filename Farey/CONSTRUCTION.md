# Optional boundary-to-lattice construction

Native 0.7 and browser 0.6 add a manually advanced explanation inspired by [Katherine Stange's staged L/R and lattice viewer](https://katestange.net/talks/math-exploration/viewers/farey-cf-lattice.html). The ordinary stationary lattice remains the default. Stange's code and media are not bundled; this is an independent implementation. The underlying L/R coding remains credited to [Caroline Series (1985)](https://doi.org/10.1112/jlms/s2-31.1.69).

Choose **Construct** in native controls or **Construct this direction** in the browser. Next and Back traverse four stages:

1. **Boundary chart:** distinct primitive directions appear on the line q=1, positioned by p/q; the selected value is labelled. Positive multiples project to the same point. Infinity has no finite point in this chart.
2. **Direction:** the selected ray connects the origin to its boundary value.
3. **Integer lattice:** the finite integer points return to their original positions. The camera remains fixed.
4. **Direction plane:** the upright plane and ordinary annotations reappear.

The target fraction, inspected integer point, L/R path, continued-fraction choice, spotlight and lesson prediction remain unchanged. Done restores the previous representation and camera placement; native can start from the disk and return to it. The full app Reset closes the construction. Restart resets only the construction to its first stage and turns off animation.

**Animate reveal** is off by default and affects only the transition from Direction to Integer lattice. Reduce Motion disables it. **Stop** ends the animation and settles immediately at the integer-lattice endpoint; it does not leave fractional coordinates frozen as apparent lattice points. Changing the mathematical state also ends the current animation. Browser backgrounding or graphics loss settles the transition before repainting.

## Mathematics versus illustration

Coordinates here are written `(q,p)`. The ray through a point `(q,p)`, with q>0, meets q=1 at `(1,p/q)`: multiply both coordinates by 1/q. This is an exact projective relation between rational directions, not a one-to-one map between boundary points and all integer points. All positive integer multiples share the same boundary value.

The optional animation interpolates from `(1,p/q)` to `(q,p)` along that ray. Its intermediate positions need not be integer points. For 0≤t≤1, the interpolated point is `((1−t)/q + t) × (q,p)`, so it remains on the same ray. The interpolation, timing, sphere sizes and display placement are pedagogical choices; no hyperbolic map or isometry is claimed. This q=1 chart is separate from the native Poincaré disk representation. The software still uses floating-point geometry to render exact rational labels and integer state.

Stange's original viewer leaves the lattice points fixed while its camera rises from a ground-level view to an overhead view. This optional stationary-camera projection is a different teaching sequence, not a reproduction of that camera transition. See the [source-fidelity audit](SOURCE_FIDELITY.md) for the exact correspondence and limits.

The displayed q=1 segment and lattice have finite bounds. A boundary value beyond the segment, or an inspected integer point beyond the grid, is explicitly reported and is not clamped to the edge. Axis points remain boundaries; the selectable rational domain is unchanged.

## Verification and limits

The [construction evidence](evidence/construction/) records browser source/static checks, native results and screenshots. Core tests verify ray incidence, scalar-multiple agreement and the absence of a finite q=1 intersection for infinity. Interaction checks cover stages, Stop, Restart, Done, unchanged state, returning to the linked disk, mobile layout, Reduce Motion emulation and graphics-loss recovery. Native Reduce Motion logic is exercised at the model boundary; this work does not change the user's system settings.

Twenty-five core tests, 24 JavaScript tests and the 20-test native regression suite passed. The final construction revision additionally passed all nine native model tests and its UI scenario, followed by a focused caption-layout recheck. Browser source and static artifacts passed the stage, recovery and mobile checks. The existing simulator and browser regression suites also cover the ordinary experience. Signed device builds use existing signing material only. Physical-headset execution, immersive WebXR sessions, screen-reader speech and hardware comfort/performance remain unverified. This increment does not validate immersive WebXR or physical-headset execution.

Run the browser construction check with the existing Playwright CLI:

```sh
playwright-cli open http://127.0.0.1:8080/
playwright-cli run-code --filename construction-checks.js
```

The native scenario is `FareyVisionUITests/FareyUITests/testConstructionAndReturnToLinkedDisk`; the ordinary [simulator test script](scripts/test-simulator.sh) includes it.
