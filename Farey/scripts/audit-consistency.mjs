// SPDX-License-Identifier: GPL-3.0-or-later
// Bounded model agreement and independent exact arithmetic; not a proof for all inputs.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { FareyState, continuedFraction } from '../WebXR/core.js';

const cases = [];
for (let p = 1; p <= 200; p++) for (let q = 1; q <= 200; q++) cases.push({ p, q });
for (let n = 0; n <= 12; n++) for (let bits = 0; bits < 2 ** n; bits++) {
  cases.push({ word: Array.from({ length: n }, (_, i) => bits >> i & 1 ? 'L' : 'R').join('') });
}
for (let n = 0; n <= 25; n++) for (const turn of ['L', 'R']) cases.push({ word: turn.repeat(n) });
let seed = 0x51a7e;
const random = () => seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
for (let n = 0; n < 4096; n++) {
  cases.push({ word: Array.from({ length: 24 }, () => random() & 0x80000000 ? 'L' : 'R').join('') });
}
cases.push({ word: 'LR'.repeat(12) }, { word: 'RL'.repeat(12) });
for (let n = 0; n < 4096; n++) cases.push({ p: random() % 1000 + 1, q: random() % 1000 + 1 });
for (const [p, q] of [[0, 1], [1, 0], [0, 0], [-1, 2], [1, -2], [1001, 1001],
  [1000, 1000], [26, 1], [1, 26], [25, 1], [1, 25], [999, 1000], [1000, 999], [750, 1000]]) cases.push({ p, q });

// Euclidean blocks produce the path independently of the app's interval search.
function pathFor(p, q) {
  let word = '';
  while (p !== q) {
    const left = p > q, count = left ? (p - 1n) / q : (q - 1n) / p;
    word += (left ? 'L' : 'R').repeat(Number(count));
    if (left) p -= count * q; else q -= count * p;
  }
  return word;
}
const pair = (p, q) => `${p},${q}`;
function oracle(input) {
  let word = '', accepted = true, selected = '-';
  if ('word' in input) { word = input.word.slice(0, 24); accepted = input.word.length <= 24; }
  else {
    const p = BigInt(input.p), q = BigInt(input.q);
    accepted = p > 0n && q > 0n && p <= 1000n && q <= 1000n;
    if (accepted) { word = pathFor(p, q); accepted = word.length <= 24; }
    if (!accepted) word = ''; else selected = pair(p, q);
  }
  let a = 1n, b = 0n, c = 0n, d = 1n;
  const visited = [pair(1n, 1n)];
  for (const turn of word) {
    if (turn === 'L') { b += a; d += c; } else { a += b; c += d; }
    visited.push(pair(a + b, c + d));
  }
  assert.equal(a * d - b * c, 1n);
  let p = a + b, q = c + d;
  const terms = [];
  while (q) { terms.push(p / q); [p, q] = [q, p % q]; }
  const alternate = [...terms.slice(0, -1), terms.at(-1) - 1n, 1n];
  const endpointTerms = terms.length % 2 ? alternate : terms;
  assert.equal(endpointTerms.map((n, i) => (i % 2 ? 'R' : 'L').repeat(Number(n))).join(''), word + 'R');
  const truncations = terms => terms.map((_, i) => {
    let p = terms[i], q = 1n;
    for (let j = i - 1; j >= 0; j--) [p, q] = [terms[j] * p + q, p];
    return pair(p, q);
  });
  const rows = terms => {
    const convergents = truncations(terms);
    assert.equal(convergents.at(-1), pair(a + b, c + d));
    return [...convergents.filter(value => value.startsWith('0,')), ...visited]
      .map(value => `${value}:${convergents.includes(value) ? 1 : 0}`).join(';');
  };
  return [accepted ? 1 : 0, pair(b, d), pair(a, c), pair(a + b, c + d), word, selected,
    terms.join(','), alternate.join(','), rows(terms), rows(alternate)].join('|');
}
function record(state, accepted) {
  const p = value => pair(value.p, value.q);
  const rows = alternate => state.cfPoints(alternate).map(row => `${p(row.rational)}:${row.isConvergent ? 1 : 0}`).join(';');
  return [accepted ? 1 : 0, p(state.left), p(state.right), p(state.mediant), state.word,
    state.selectedPoint ? p(state.selectedPoint) : '-', continuedFraction(state.mediant).terms.join(','),
    continuedFraction(state.mediant, true).terms.join(','), rows(false), rows(true)].join('|');
}
const hash = createHash('sha256');
let acceptedCount = 0, maxComponent = 0;
for (const input of cases) {
  const state = new FareyState(); let accepted = true;
  if ('word' in input) { for (const turn of input.word) if (!state.step(turn)) accepted = false; }
  else accepted = state.select(input.p, input.q);
  const actual = record(state, accepted);
  assert.equal(actual, oracle(input), JSON.stringify(input));
  hash.update(actual + '\n'); acceptedCount += Number(accepted);
  maxComponent = Math.max(maxComponent, state.mediant.p, state.mediant.q);
  assert.ok(Number.isSafeInteger(state.determinant));
}
const result = { passed: true, cases: cases.length, accepted: acceptedCount, maxComponent,
  digest: hash.digest('hex'), oracle: 'BigInt Euclidean path, matrix product, reversed continued-fraction evaluation' };
if (process.argv.includes('--native')) {
  const scratch = mkdtempSync(join(tmpdir(), 'farey-consistency-'));
  try {
    const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
    const source = join(root, 'Packages/FareyCore/Sources/FareyCore');
    const inputs = join(scratch, 'inputs.json'), binary = join(scratch, 'audit');
    writeFileSync(inputs, JSON.stringify(cases));
    const run = (command, args) => {
      const r = spawnSync(command, args, { encoding: 'utf8', maxBuffer: 4 * 1024 * 1024 });
      if (r.status !== 0) throw Error(r.stderr || `${command} failed (${r.status})`);
      return r.stdout;
    };
    run('xcrun', ['swiftc', '-O', '-parse-as-library', ...readdirSync(source).filter(name => name.endsWith('.swift')).sort().map(name => join(source, name)),
      join(root, 'scripts/AuditConsistency.swift'), '-o', binary]);
    result.native = JSON.parse(run(binary, [inputs]));
    assert.equal(result.native.digest, result.digest, 'Native/browser exact records differ');
  } finally { rmSync(scratch, { recursive: true, force: true }); }
}
const output = process.argv.indexOf('--output');
if (output >= 0) writeFileSync(process.argv[output + 1], JSON.stringify(result, null, 2) + '\n');
console.log(JSON.stringify(result, null, 2));
