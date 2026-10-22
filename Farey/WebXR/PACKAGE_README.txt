FAREY — INTO THE INFINITE, browser version @VERSION@

LOCAL LAUNCH
Unpack the complete folder. From a terminal in this folder, run:

    python3 serve.py --port 8080

Open http://127.0.0.1:8080/ in a modern WebGL2-capable browser.
Python 3 is required for this local server; Node/npm are not needed to view it.
Stop the server with Control-C. It listens only on this computer's loopback.
Use another --port if 8080 is occupied. Keep every file in the folder together.
Do not double-click index.html: browser module security requires an HTTP URL.

OFFLINE BOUNDARY
The local server and all graphics assets work without an internet connection.
No CDN, analytics, external font, account or API key is used. Source links open
external websites only if you follow them. Browsers must still allow localhost
requests. A browser's fully offline mode blocks even localhost on a fresh load
or reload. This package has no service worker or installable offline cache.
An already loaded page continues to work with browser networking disabled.

CONTROLS AND STATE
Drag to orbit, scroll to zoom, right-drag to pan. On touch screens, use one
finger to rotate and two to pan/pinch. Focus the scene for arrow-key pan,
Shift+arrows rotation, +/- zoom and Home/front view. The camera starts still.
Compact screens center the grid more closely; short, wide windows place it
beside the controls. Axis letters stay readable while you change the view.
Use L/R, Undo, Reset, the 3/5 example, or a positive fraction such as 6/10.
Point inspection keeps (10,6) separate from its primitive direction (5,3).
Reload restores the validated selection and grid in this browser tab, but
closes lessons and temporary spotlights. Reset clears the selection and view.
A new browser profile starts at 1/1. Storage isolation policies may differ
when duplicating an existing tab. Closing a tab normally ends its session.

XR AND GRAPHICS
Desktop/touch 3D does not require a headset. Unsupported WebXR leaves these
controls available. WebXR needs a compatible browser/device and runtime
consent; remote hosting generally requires HTTPS. Actual immersive sessions,
stereo frames and headset input have not been verified for this package.
No browser security changes are needed or recommended for local desktop use.
WebGL creation failure shows an explanation; context loss shows recovery UI.

SOURCE, LICENSES AND REBUILD
SOURCE.txt contains attribution and provenance. COPYING.txt is the app's
GPL-3.0-or-later license. vendor/THREE-LICENSE.txt covers Three.js (MIT).
source/ contains the exact authored sources, pinned package lock, build
instructions and smoke checks. manifest.json hashes every payload file.
To rebuild, from source/ with Node.js, npm and Python 3 installed:

    npm ci --ignore-scripts
    npm test
    npm run build
    npm run smoke:package

The rebuilt folder is source/dist/. npm ci needs internet or an existing
package cache. Building and viewing afterwards use local files only.
Optional browser smoke: install Playwright CLI and its browser separately,
then run npm run smoke:offline. The script never installs tools, requests an
XR session, uploads files or changes OS/browser permissions.
