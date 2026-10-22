FAREY — INTO THE INFINITE, browser version @VERSION@

LOCAL LAUNCH
Unpack the complete folder. From a terminal in this folder, run:

    python3 serve.py --port 8080

Open http://127.0.0.1:8080/ in a modern WebGL2-capable browser.
Python 3 is required for this local server; Node/npm are not needed to view it.
The address works only on the computer running the server. It is not a
public demo link and will not reach this copy from a phone or headset.
Stop the server with Control-C. It listens only on this computer's loopback.
Use another --port if 8080 is occupied. Keep every file in the folder together.
Do not double-click index.html: browser module security requires an HTTP URL.

TRY THIS FIRST — DOUBLE CONE
The opening page shows integer coefficient triples (a,b,c), displayed at
(X,Y,Z)=(-b,a+c,c-a), and both halves of b²-4ac=0. Drag to orbit, scroll to
zoom; click a dot or enter its coefficients. Radius controls a finite ball
X²+Y²+Z²<=R², excluding zero. Dense options reach 1,852,484 distinct triples,
without duplication or sampling. At high density, overlapping dots appear
as a cloud; use Inhabit, zoom or the star-size control to inspect it.

Viridis shows upper-interior |discriminant| on a fixed logarithmic 3-240
range, using Viridis positions 0.2-1 for visibility. Values above 240
saturate. Exterior, cone and lower-interior categories have separate
swatches. Stange's palette is also available; its category hues are
approximations. Coloring the lower half is explicitly our extension.

CUTTING PLANES
Select a point with positive discriminant to use it as a Lorentz normal.
Or select (1,0,1), then Shift-click (1,1,1), or enter that second point
and press Pair entered point. The plane is 2a-2c=0, endpoints -1 and 1.
Amber rings mark exact displayed interior members. Optional fading away
from the plane is a Euclidean distance viewing aid, not a hyperbolic
invariant. Uncheck it to restore ordinary opacity. Projection is hidden
initially; Project to Klein disk shows radial images on the screen.

INHABIT AND ORIGIN
The single Inhabit/Overview button switches viewing mode and restores
the saved overview. Inhabit starts near the selected point. Origin is
an explicit location preset at the apex. The zero polynomial has no
unique associated root or projective point; radial projection there
is undefined. Look up/Level/Look down choose a direction. Drag to look;
W/A/S/D move, Q/E move down/up. Onscreen buttons give the same steps.
This is ambient Euclidean navigation, not intrinsic hyperbolic motion.
No automatic camera movement occurs. Reset restores the default scene.

DEBUG
The compact Debug button opens counts and measurements. It starts closed;
Close or Escape dismisses it and cancels an unfinished frame measurement.
Point primitives, triangles and draw calls are distinct. CPU timings,
array-size estimates and Chrome JS heap are labelled separately. Measured
frame intervals are browser scheduling observations, not GPU timings or
headset frame rates. No continuous measurement runs with Debug closed.

FAREY L/R — SEPARATE VIEW
Follow the Farey L/R link, or open /farey.html. This intrinsically planar
rational-pair lattice retains the 3/5 example, L/R, Undo, Reset and lesson.
The saved-state and detailed L/R controls below refer to this separate page.

OFFLINE BOUNDARY
The local server and all graphics assets work without an internet connection.
No CDN, analytics, external font, account or API key is used. Source links open
external websites only if you follow them. Browsers must still allow localhost
requests. A browser's fully offline mode blocks even localhost on a fresh load
or reload. This package has no service worker or installable offline cache.
An already loaded page continues to work with browser networking disabled.

FAREY PAGE — CONTROLS AND SAVED STATE
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

A small display-overlap notice appears when distinct interval directions
have identical single-precision display coordinates. The exact fractions
remain different. It is a conservative test: close directions may still
look overlapped without triggering it. Geometry and selection do not move.

XR AND GRAPHICS
Desktop/touch 3D does not require a headset. Unsupported WebXR leaves these
controls available. WebXR needs a compatible browser/device and runtime
consent; remote hosting generally requires HTTPS. Actual immersive sessions,
stereo frames and headset input have not been verified for this package.
No browser security changes are needed or recommended for local desktop use.
WebGL creation failure shows an explanation. The coefficient page pauses
on context loss and repaints after restoration; the Farey page also has
its separately tested exact-state reload recovery.
Missing application modules show a reload/local-launch explanation. With
JavaScript disabled, the page explains the requirement.

SOURCE, LICENSES AND REBUILD
SOURCE.txt contains attribution and provenance. COPYING.txt is the app's
GPL-3.0-or-later license. vendor/THREE-LICENSE.txt covers Three.js (MIT). VIRIDIS-LICENSE.txt covers
the CC0 palette data by Smith, van der Walt and Firing.
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
