# Conditional precision notice

Native 0.8.1/build 11 and browser 0.7.4 add one conditional sentence:

> Display overlap: distinct fractions can look identical here. Read the exact values above.

The notice does not change geometry, exact fractions, point inspection, L/R history, camera placement or continued-fraction conventions. It is absent at ordinary 3/5 and after Reset. It is exposed as normal accessible text in native controls and a polite status in the browser; the browser canvas description includes the same explanation. The implemented in-world browser panel has a shorter equivalent message. Actual WebXR and screen-reader speech remain untested.

## Conservative trigger

The check compares the current left endpoint, mediant and right endpoint. It first requires the rational values to differ, then tests equality of their rendered Float32 coordinates. There is no arbitrary path-depth or pixel-distance threshold.

- **Native disk:** use the actual disk marker coordinates, including their common z position.
- **Native lattice:** use the same bounded direction-plane endpoint function as the renderer, preserving its existing Float arithmetic.
- **Browser lattice:** use the renderer's existing Double calculation of the bounded endpoint, then round it to the Float32 buffer format.

This is a warning about the display representation, not a claim that integer lattice points or rational numbers coincide. The lattice compares the finite direction representation; it does not move out-of-grid integer points onto the boundary. The notice is hidden during the optional construction sequence, whose projected/moving coordinates need a different test.

The two renderers have different existing arithmetic paths. For `(LR)^12`, selecting 121393/75025:

| Representation | Notice |
| --- | --- |
| Native disk | Yes |
| Native lattice, grid 12 or 6 | No: its rounded endpoints remain slightly distinct |
| Native lattice, grid 14 | Yes |
| Browser lattice, grids 6 through 14 | Yes |
| Ordinary 3/5, inspected 6/10, repeated L or R, in these tested representations | No |

The 19-move example from the [native precision audit](NATIVE_PRECISION_AUDIT.md) also stays quiet: adjacent curve samples can merge while the three endpoint positions still differ. Thus **absence of the notice does not guarantee visually separated geometry**. Finite marker width, occlusion, viewing distance and pixel resolution are outside this narrow test.

## Verification

The exact-state oracle still matches 56,451 browser/native cases with digest `ee0af2667466e895ccff0417e3ede75a9e954b3acdf9d25aad002ca457b1d32a`. All 39 browser tests and 30 Swift core tests pass. Source and static browser interaction checks verify appearance, reset, scalar multiples, grid changes, construction dismissal, expansion changes, accessible status and phone layout. The existing static renderer geometry audit also passes.

The native final run passes 16 model/renderer tests and one UI walkthrough. It confirms no notice at ordinary 3/5 or the deep default-grid lattice, a notice at grid 14 and in the disk, unchanged exact values, correct construction hiding/restoration, and clearing on Reset. Both simulator screenshots retain the notice and exact values. Strict SwiftLint passes. The checked-in Xcode project was regenerated from the existing specification and matches the tested project, including source files that were previously absent from its stale file list.

Evidence and simulator results are recorded in [evidence/precision-notice](evidence/precision-notice/). The [existing simulator capture uncertainty](LIFECYCLE_CAPTURE_AUDIT.md) still applies. The main showcase, blog windows, signing assets, pending tracking consent and upload approvals are preserved.
