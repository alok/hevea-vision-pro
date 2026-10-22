# Browser 0.9.0 evidence

- `overview.png`: both cone halves with all four coefficient categories; projection hidden.
- `inside.png`: an ambient first-person view near the selected coefficient point.
- `phone.png`, `landscape.png`: responsive Chromium views, not physical-phone tests.
- `browser-validation.json`: actual instanced-sphere click, radius/category counts, upper-only filter, optional lower coloring, negative-form root, eye translation/parallax, fixed-eye look, keyboard focus, crop change inside, return to overview and real context loss/recovery.
- `tests.log`: 43 browser/core/package unit tests passed.
- `package-validation.json`, `package-zip.json`: the exact local browser package; no deployment or upload.
- `legacy-parity.json`: the preserved Farey runtime is byte-identical to the previously tested browser 0.8.0 package.

The native app remains at its earlier upper-cone 0.9.0 scene. Its separate full simulator regression is recorded under `../coefficient-cone/`. No immersive WebXR session, physical headset performance, or intrinsic hyperbolic navigation is established here. The comparison screenshots containing Stange's original are kept outside this repository.
