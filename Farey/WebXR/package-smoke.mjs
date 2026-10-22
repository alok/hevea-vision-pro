// SPDX-License-Identifier: GPL-3.0-or-later
// Static release checks; runtime/network checks live in offline-checks.js.
import { readFile, readdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { resolve, relative, isAbsolute, sep } from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';

export async function auditPackage(directory) {
  const root = resolve(directory);
  const ensure = (condition, message) => { if (!condition) throw Error(message); };
  const walk = async (dir, prefix = '') => {
    const files = [];
    for (const entry of await readdir(dir, { withFileTypes: true })) {
      ensure(!entry.isSymbolicLink(), `Unexpected symlink: ${prefix}${entry.name}`);
      if (entry.isDirectory()) files.push(...await walk(resolve(dir, entry.name), `${prefix}${entry.name}/`));
      else files.push(`${prefix}${entry.name}`);
    }
    return files.sort();
  };
  const files = await walk(root);
  const manifest = JSON.parse(await readFile(resolve(root, 'manifest.json'), 'utf8'));
  ensure(JSON.stringify(files.filter(name => name !== 'manifest.json')) === JSON.stringify(Object.keys(manifest).sort()), 'Manifest does not cover the exact payload');
  for (const name of Object.keys(manifest)) {
    const actual = createHash('sha256').update(await readFile(resolve(root, name))).digest('hex');
    ensure(actual === manifest[name], `Hash mismatch: ${name}`);
  }
  for (const name of ['README.txt', 'serve.py', 'SOURCE.txt', 'COPYING.txt', 'vendor/THREE-LICENSE.txt', 'source/build.mjs', 'source/package-lock.json']) {
    ensure(name in manifest, `Missing distributable input: ${name}`);
  }
  const html = await readFile(resolve(root, 'index.html'), 'utf8');
  const importMap = JSON.parse(html.match(/<script type="importmap">([\s\S]*?)<\/script>/)[1]).imports;
  const localFile = (specifier, from) => {
    const target = new URL(specifier, pathToFileURL(from));
    ensure(target.protocol === 'file:', `External asset: ${specifier}`);
    const file = fileURLToPath(target);
    const path = relative(root, file);
    ensure(path !== '..' && !path.startsWith(`..${sep}`) && !isAbsolute(path), `Asset escapes package: ${specifier}`);
    const name = path.split(sep).join('/');
    ensure(name in manifest, `Missing local asset: ${specifier} from ${relative(root, from)}`);
    return file;
  };
  const visited = new Set();
  const visit = async file => {
    if (visited.has(file)) return;
    visited.add(file);
    const code = await readFile(file, 'utf8');
    for (const match of code.matchAll(/\b(?:import|export)\s+(?:[^;'"]*?\s+from\s*)?['"]([^'"]+)['"]/g)) {
      let specifier = match[1], from = file;
      if (!specifier.startsWith('.')) {
        const key = Object.keys(importMap).find(key => specifier === key || key.endsWith('/') && specifier.startsWith(key));
        ensure(key, `Unresolved bare import: ${specifier}`);
        specifier = importMap[key] + specifier.slice(key.length);
        from = resolve(root, 'index.html');
      }
      await visit(localFile(specifier, from));
    }
  };
  for (const match of html.matchAll(/<(script|link)\b[^>]*(?:src|href)="([^"]+)"[^>]*>/g)) {
    if (match[2].startsWith('data:')) continue;
    const file = localFile(match[2], resolve(root, 'index.html'));
    if (match[1] === 'script') await visit(file);
    else {
      const css = await readFile(file, 'utf8');
      for (const asset of css.matchAll(/url\(\s*['"]?([^'"\)]+)['"]?\s*\)/g)) {
        if (!asset[1].startsWith('data:')) localFile(asset[1], file);
      }
    }
  }
  for (const name of ['app.js', 'core.js', 'xr-support.js', 'input.js', 'recovery.js', 'construction.js', 'view.js']) {
    const code = await readFile(resolve(root, name), 'utf8');
    ensure(!/\b(?:fetch|XMLHttpRequest|WebSocket|EventSource|sendBeacon)\s*\(/.test(code), `Review new network API in ${name}`);
  }
  const attribution = await readFile(resolve(root, 'SOURCE.txt'), 'utf8');
  ensure(attribution.includes('Katherine Stange') && attribution.includes('Caroline Series') && attribution.includes('No Stange code'), 'Missing source attribution/boundary');
  ensure(html.includes('Inspired by <strong>Katherine Stange</strong>') && html.includes('https://doi.org/10.1112/jlms/s2-31.1.69'), 'Missing in-app credit');
  ensure((await readFile(resolve(root, 'COPYING.txt'), 'utf8')).includes('GNU GENERAL PUBLIC LICENSE'), 'Missing GPL text');
  ensure((await readFile(resolve(root, 'vendor/THREE-LICENSE.txt'), 'utf8')).includes('Permission is hereby granted'), 'Missing MIT text');
  return { passed: true, payloadFiles: Object.keys(manifest).length, runtimeModules: visited.size,
    manifestSHA256: createHash('sha256').update(await readFile(resolve(root, 'manifest.json'))).digest('hex') };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  console.log(JSON.stringify(await auditPackage(process.argv[2] ?? 'dist'), null, 2));
}
