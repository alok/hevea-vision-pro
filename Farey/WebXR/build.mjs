// SPDX-License-Identifier: GPL-3.0-or-later
import { copyFile, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));
const destination = resolve(root, 'dist');
const vendor = resolve(root, 'node_modules/three');
const dependency = JSON.parse(await readFile(resolve(vendor, 'package.json'), 'utf8'));
if (dependency.version !== '0.180.0') throw Error('Run npm ci: Three.js 0.180.0 is required.');
await rm(destination, { recursive: true, force: true });
await mkdir(resolve(destination, 'vendor/addons/controls'), { recursive: true });
const files = ['app.js', 'core.js', 'xr-support.js', 'style.css'];
for (const name of files) await copyFile(resolve(root, name), resolve(destination, name));
const html = (await readFile(resolve(root, 'index.html'), 'utf8'))
  .replace('./node_modules/three/build/three.module.js', './vendor/three.module.js')
  .replace('./node_modules/three/examples/jsm/', './vendor/addons/');
await writeFile(resolve(destination, 'index.html'), html);
for (const name of ['three.module.js', 'three.core.js']) {
  await copyFile(resolve(vendor, 'build', name), resolve(destination, 'vendor', name));
}
await copyFile(resolve(vendor, 'examples/jsm/controls/OrbitControls.js'), resolve(destination, 'vendor/addons/controls/OrbitControls.js'));
await copyFile(resolve(vendor, 'LICENSE'), resolve(destination, 'vendor/THREE-LICENSE.txt'));
await copyFile(resolve(root, '../../LICENSE'), resolve(destination, 'COPYING.txt'));
await writeFile(resolve(destination, 'SOURCE.txt'), 'Original Farey companion source and attribution: https://github.com/alok/hevea-vision-pro/tree/codex/farey-void-demo/Farey/WebXR\n');
files.push('index.html', 'COPYING.txt', 'SOURCE.txt', 'vendor/three.module.js', 'vendor/three.core.js', 'vendor/addons/controls/OrbitControls.js', 'vendor/THREE-LICENSE.txt');
const manifest = {};
for (const name of files.sort()) manifest[name] = createHash('sha256').update(await readFile(resolve(destination, name))).digest('hex');
await writeFile(resolve(destination, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(`Built ${files.length} static files in ${destination}`);
