# Farey lattice — browser and WebXR companion

An original Three.js implementation of the same integer lattice and L/R state as the native visionOS app. Inspired by **[Katherine Stange](https://katestange.net/talks/math-exploration/)** and her [visualization catalog](https://www.katestange.net/code/), with underlying [Caroline Series L/R geodesic coding (1985)](https://doi.org/10.1112/jlms/s2-31.1.69).

## Run locally

```sh
cd Farey/WebXR
npm ci --ignore-scripts
npm test
npm start
```

Open **http://127.0.0.1:8080**. The server binds only to this Mac. Node.js, npm and Python 3 are required. Three.js is pinned to 0.180.0 with an integrity hash in the lockfile. No network dependency is used at runtime after installation.

Drag to orbit, scroll to zoom, right-drag to pan. Hover a sphere to read its integer pair and click to select its rational direction. L/R, Undo, Reset, the 3/5 example and fraction entry share one exact state. Grid size is capped at 14 (224 nonzero points). Rendering is event-driven on desktop; XR uses the headset animation loop. Reset restores the initial geometry and view.

## Immersive VR

The **Enter VR** button becomes available only when `isSessionSupported('immersive-vr')` succeeds. It requests an immersive VR session with a local-floor reference space. The lattice is stationary in a black environment. Controller/select rays can choose points and use the in-world L, R, Undo, Reset, 3/5 and Exit controls. Session end restores the desktop controls. The in-world panel credits Stange and Series; full source links remain in the desktop panel.

WebXR needs a compatible headset browser and a secure context. A headset cannot access the Mac's loopback address directly. Use an already-trusted HTTPS development host or an independently authorized deployment for headset testing. This work does not provision a certificate, change network permissions, or publish a site.

**Verified here:** Chromium desktop rendering and real mouse orbit, L/R/Undo/Reset, rational selection (including 6/10 → 3/5), maximum grid, 24-step limit and recovery. This Mac's Chromium reports `immersive-vr` unsupported. **Not verified:** Quest/Meta Browser, a physical Vision Pro browser, controller/hand interaction in an actual XR session, device frame rate or comfort. The native simulator is separate evidence, not a WebXR headset test.

## Mathematical correspondence and provenance

Each point is (q,p), uniformly scaled and rigidly rotated into the scene. The green plane is perpendicular to the lattice and passes through its origin and the selected direction. Cyan and purple vectors are Farey neighbors; their orange sum is the mediant. Sphere sizes, colors, finite plane height and placement are presentation choices. The app word represents M(1); appending R puts the same rational in M(∞), matching the endpoint convention seen in Stange's talk viewer.

No Stange JavaScript, media or meshes are bundled. This is an independent implementation of the lattice construction, not her separate hyperboloid visualization or a reproduction of an infinite fractal. Application code is GPL-3.0-or-later under the parent repository license. Three.js is a separate MIT-licensed dependency; its license is installed at `node_modules/three/LICENSE`.
