# Projected selection evidence

Native 0.8 (build 10) / browser 0.7.0. See [the explanation and limitations](../../PROJECTED_SELECTION.md).

- [Native preview](42-native-projected-preview.png) and [confirmed 13/14 selection](43-native-projected-selected.png).
- Browser preview on [desktop](browser-preview.png), [phone](browser-preview-phone.png) and [landscape](browser-preview-landscape.png).
- [Baseline browser clicks](browser-before.json) and [source preview/confirmation results](browser-source.json). The corresponding static tests are recorded separately.
- [Native regression summary](native-regression-summary.json): 18 passing model, renderer and simulator UI checks. [Unit tests](unit-tests.json): 27 Swift and 26 JavaScript tests passed.
- [Native coordinate-tap automation limit](native-spatial-input-limit.json). This failed automation attempt is not a successful sphere tap or a hardware test.
- [Signed Release build](device-build.json), using existing signing only. No headset installation or execution is asserted.

Mouse clicks and emulated touch were delivered through Chromium input APIs. Read-only test instrumentation exposed the actual camera and mesh transforms to locate the projected centers. It did not replace the hit-test or selection handlers. Native preview controls were operated through simulator UI tests; direct RealityKit sphere coordinate activation was unavailable through the tested XCTest path.

The initial hit is still ambiguous. The explicit preview prevents that hit from silently changing the mathematics, and Previous/Next lets a visitor select the intended primitive direction. Ordinary integer-point selection and direct p/q entry remain available.
