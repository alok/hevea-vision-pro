# Browser 0.11.0 pair-plane evidence

Original finite implementation, tested on 22 October 2026. See [the construction and source boundary](../../PAIR_PLANE.md).

- `browser.json`: actual browser Shift-click, form/button selection, duplicate rejection, camera preservation, radius/filter changes, clear/reset, Inhabit, phone layout, and repeated disposal. The source pair `(1,0,1)` / `(1,1,1)` produces normal `(1,0,-1)`, endpoints −1/1, and 22 displayed complex-root members at radius 6. It uses 16 draw calls; after repeated clearing, geometry resources return to 6.
- `validation.json`: 55 passing unit/package tests and the passing existing browser walkthrough. No XR session was requested.
- `overview-plane.png`, `inside-plane.png`, `phone-plane.png`: fresh browser-rendered views from the new pair walkthrough. These are not physical-headset or native-simulator screenshots.

The live 8778 page was reloaded to the tested version. Its original selected point `(1,-1,2)`, Inhabit mode, exact camera position, quaternion and target were captured and restored. Pairing remains opt-in. The prior macOS inactive-desktop capture limitation is not claimed fixed.

Reproduce with installed project dependencies:

```sh
cd Farey/WebXR
npm test
npm run build
python3 serve.py --port 8781 --directory dist
# In a separate terminal, from the same directory:
playwright-cli -s=pair open http://127.0.0.1:8781/
playwright-cli -s=pair run-code --filename=pair-checks.js
```

The package `WebXR/output/Farey-WebXR-0.11.0.zip` contains the manifest-checked local runtime and source, 542184 bytes, SHA-256 `e0c86d7b53b1cd6b1666af2acf2b9f41ece81b5858d634e24d335a2b1f56730b`. It was created locally, not uploaded or publicly deployed.
