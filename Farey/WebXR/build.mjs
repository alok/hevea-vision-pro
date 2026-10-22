// SPDX-License-Identifier: GPL-3.0-or-later
import { copyFile, mkdir, readFile, rm, writeFile, access } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));
const destination = resolve(root, 'dist');
const vendor = resolve(root, 'node_modules/three');
const metadata = JSON.parse(await readFile(resolve(root, 'package.json'), 'utf8'));
const dependency = JSON.parse(await readFile(resolve(vendor, 'package.json'), 'utf8'));
if (dependency.version !== '0.180.0') throw Error('Run npm ci: Three.js 0.180.0 is required.');
let license = resolve(root, 'LICENSE');
try { await access(license); } catch { license = resolve(root, '../../LICENSE'); }
await rm(destination, { recursive: true, force: true });
await mkdir(resolve(destination, 'vendor/addons/controls'), { recursive: true });
const files = ['app.js', 'core.js', 'xr-support.js', 'input.js', 'recovery.js', 'construction.js', 'view.js', 'style.css'];
for (const name of files) await copyFile(resolve(root, name), resolve(destination, name));
const hash = content => createHash('sha256').update(content).digest('hex');
const assetHash = async name => hash(await readFile(resolve(destination, name)));
const recovery = (await readFile(resolve(destination, 'recovery.js'), 'utf8'))
  .replace("'./core.js'", `'./core.js?v=${await assetHash('core.js')}'`);
await writeFile(resolve(destination, 'recovery.js'), recovery);
let app = await readFile(resolve(destination, 'app.js'), 'utf8');
for (const name of ['core.js', 'xr-support.js', 'input.js', 'recovery.js', 'construction.js', 'view.js']) {
  app = app.replace(`'./${name}'`, `'./${name}?v=${await assetHash(name)}'`);
}
await writeFile(resolve(destination, 'app.js'), app);
const html = (await readFile(resolve(root, 'index.html'), 'utf8'))
  .replace('./node_modules/three/build/three.module.js', './vendor/three.module.js')
  .replace('./node_modules/three/examples/jsm/', './vendor/addons/')
  .replace('href="style.css"', `href="style.css?v=${await assetHash('style.css')}"`)
  .replace('src="app.js"', `src="app.js?v=${await assetHash('app.js')}"`);
await writeFile(resolve(destination, 'index.html'), html);
for (const name of ['three.module.js', 'three.core.js']) {
  await copyFile(resolve(vendor, 'build', name), resolve(destination, 'vendor', name));
}
await copyFile(resolve(vendor, 'examples/jsm/controls/OrbitControls.js'), resolve(destination, 'vendor/addons/controls/OrbitControls.js'));
await copyFile(resolve(vendor, 'LICENSE'), resolve(destination, 'vendor/THREE-LICENSE.txt'));
await copyFile(license, resolve(destination, 'COPYING.txt'));
await copyFile(resolve(root, 'serve.py'), resolve(destination, 'serve.py'));
await writeFile(resolve(destination, 'README.txt'), (await readFile(resolve(root, 'PACKAGE_README.txt'), 'utf8')).replace('@VERSION@', metadata.version));
await writeFile(resolve(destination, 'SOURCE.txt'), `Farey — Into the Infinite, browser ${metadata.version}

Original implementation by Alok Singh, GPL-3.0-or-later (COPYING.txt).
Exact authored source and build inputs are included in source/; manifest.json
records their SHA-256 hashes. Rebuild instructions are in README.txt.
Project repository: https://github.com/alok/hevea-vision-pro
The bundled source, rather than a moving branch, identifies this artifact.

Inspired by Katherine Stange's L/R lattice visualization and talk:
https://katestange.net/talks/math-exploration/
https://www.katestange.net/code/
https://katestange.net/talks/math-exploration/viewers/farey-cf-lattice.html
Underlying geodesic coding: Caroline Series, The Modular Surface and
Continued Fractions (1985), https://doi.org/10.1112/jlms/s2-31.1.69
Convergent definitions: https://dlmf.nist.gov/1.12.ii

No Stange code, media or meshes are bundled. Attribution does not imply
permission to redistribute her code or an endorsement. This is a finite
independent lattice illustration, not her separate hyperboloid visualization.
Three.js ${dependency.version} is included under MIT; see vendor/THREE-LICENSE.txt.
`);
files.push('index.html', 'COPYING.txt', 'SOURCE.txt', 'README.txt', 'serve.py', 'vendor/three.module.js', 'vendor/three.core.js', 'vendor/addons/controls/OrbitControls.js', 'vendor/THREE-LICENSE.txt');
await mkdir(resolve(destination, 'source'), { recursive: true });
const sources = ['app.js', 'core.js', 'xr-support.js', 'input.js', 'recovery.js', 'construction.js', 'view.js', 'style.css', 'index.html',
  'build.mjs', 'package.json', 'package-lock.json', 'serve.py', 'PACKAGE_README.txt', 'package-smoke.mjs', 'smoke-offline.py', 'offline-checks.js',
  'core.test.js', 'xr-support.test.js', 'input.test.js', 'recovery.test.js', 'construction.test.js', 'view.test.js', 'package-smoke.test.js'];
for (const name of sources) {
  await copyFile(resolve(root, name), resolve(destination, 'source', name));
  files.push(`source/${name}`);
}
await copyFile(license, resolve(destination, 'source/LICENSE'));
files.push('source/LICENSE');
const manifest = {};
for (const name of files.sort()) manifest[name] = createHash('sha256').update(await readFile(resolve(destination, name))).digest('hex');
await writeFile(resolve(destination, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(`Built ${files.length} static files in ${destination}`);
