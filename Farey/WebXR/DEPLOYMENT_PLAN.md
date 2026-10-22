# Static deployment plan — prepared, not deployed

The repository has a pinned npm dependency and local development server. It has no existing Pages workflow, Vercel/Netlify configuration, custom domain, or chosen public hosting target. No hosting service, credential, grant or public deployment was created during this work.

## Reviewable artifact

From `Farey/WebXR`, run:

```sh
npm ci --ignore-scripts
npm test
npm run build
python3 serve.py --port 8081 --directory dist
```

The build copies only application files, the required Three.js modules, GPL text, MIT dependency license and source link into `dist/`. It rewrites the import map to use those local modules and adds content hashes to app, stylesheet and application-module URLs. `manifest.json` gives SHA-256 hashes for the twelve payload files. Tests, node_modules, reference images, private context and native recordings are excluded. No bundler, remote CDN, API key, runtime API or server function is needed.

## Publication settings once a destination is authorized

1. Choose an existing authorized static-host project and identify its exact account, project, hostname and rollback mechanism before publishing. Build from a clean, recorded Git commit; archive the artifact hash manifest with that commit.
2. Publish `Farey/WebXR/dist` as the site root. Use HTTPS and serve JavaScript, CSS and JSON with their correct content types. Runtime assets are same-origin and work under a subdirectory as well as a domain root.
3. Allow `xr-spatial-tracking` for the same origin. Launch as a top-level page; an iframe needs an explicit `allow="xr-spatial-tracking"` delegation. Do not add a Content Security Policy that blocks the inline import map; configure its hash or nonce if CSP is required.
4. Keep `index.html` and the import map revalidated on updates. Do not mark unversioned JavaScript URLs immutable. Retain the previous complete artifact for rollback.
5. Verify HTTPS, all asset requests, visible Stange/Series attribution, desktop fallback, and clean browser console at the published URL before sharing it.

## Headset acceptance before describing it as headset-tested

On the intended Quest/Meta Browser and/or physical Vision Pro, test the published HTTPS URL with the user's explicit runtime consent. Record browser/OS versions and device type. Confirm an actual `immersive-vr` session, valid stereo views and rendered frames, then select fractions, use L/R, Undo and Reset, exit and re-enter three times. Check transient-pointer input on visionOS and controller rays on Quest. Check readability, stationary placement, comfort and performance on hardware separately.

Do not describe desktop orbit or a positive capability query as an immersive-session test. The isolated visionOS simulator reported WebXR available and an actual mouse click reached Safari’s runtime consent prompt for device position and head-movement tracking. That permission was not granted. No XR session or frame was observed. The next XR acceptance step requires explicit runtime consent; the earlier XCTest accessibility blocker has been bypassed using existing macOS UI authorization without changing security settings. The native app's passing simulator tests do not close this WebXR gap.

## Rollback and stop conditions

Restore the prior complete artifact if module loading, session exit, input, or attribution fails. Do not provision new credentials, enable browser feature flags, grant automation access or change security settings to bypass a failure. Record the blocked action and request the needed authorization separately.
