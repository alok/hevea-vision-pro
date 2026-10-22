// SPDX-License-Identifier: GPL-3.0-or-later
import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';
import { cp, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { createHash } from 'node:crypto';
import { auditPackage } from './package-smoke.mjs';

const root = dirname(fileURLToPath(import.meta.url));
let temporary;
before(async () => {
  await promisify(execFile)(process.execPath, ['build.mjs'], { cwd: root });
  temporary = await mkdtemp(resolve(tmpdir(), 'farey-package-tests-'));
});
after(async () => { if (temporary) await rm(temporary, { recursive: true, force: true }); });

test('built package resolves its complete local runtime graph', async () => {
  const result = await auditPackage(resolve(root, 'dist'));
  assert.equal(result.passed, true);
  assert.equal(result.runtimeScripts, 21);
  assert.equal(result.runtimeModules, 20);
});

const faults = [
  { name: 'unrecorded payload changes', file: 'app.js', edit: text => `${text}\n// altered`, expected: /Hash mismatch/, rehash: false },
  { name: 'missing vendor modules', file: 'vendor/three.core.js', remove: true, expected: /exact payload/ },
  { name: 'root-relative asset URLs', file: 'index.html', edit: text => text.replace('src="starscape.js', 'src="/starscape.js'), expected: /escapes package/ },
  { name: 'external stylesheets', file: 'index.html', edit: text => text.replace('href="style.css', 'href="https://example.invalid/style.css'), expected: /External asset/ },
  { name: 'unresolved module imports', file: 'app.js', edit: text => `${text}\nimport './missing.js';`, expected: /Missing local asset/ },
  { name: 'bare import inside the hover worker', file: 'aim-worker.js', edit: text => text.replace(/from '\.\/input\.js[^']*'/, "from 'three'"), expected: /Bare import inside a module worker/ },
  { name: 'new telemetry APIs', file: 'app.js', edit: text => `${text}\nnavigator.sendBeacon('/metrics', 'data');`, expected: /network API/ }
];
for (const fault of faults) test(`rejects ${fault.name}`, async () => {
  const fixture = resolve(temporary, fault.name.replaceAll(' ', '-'));
  await cp(resolve(root, 'dist'), fixture, { recursive: true });
  const file = resolve(fixture, fault.file);
  if (fault.remove) await rm(file);
  else {
    await writeFile(file, fault.edit(await readFile(file, 'utf8')));
    if (fault.rehash !== false) {
      const manifestPath = resolve(fixture, 'manifest.json');
      const manifest = JSON.parse(await readFile(manifestPath, 'utf8'));
      manifest[fault.file] = createHash('sha256').update(await readFile(file)).digest('hex');
      await writeFile(manifestPath, JSON.stringify(manifest));
    }
  }
  await assert.rejects(auditPackage(fixture), fault.expected);
});
