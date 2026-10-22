// SPDX-License-Identifier: GPL-3.0-or-later
// A bounded reproducible audit, not a proof for all rational inputs.
import assert from 'node:assert/strict';
import { FareyState, continuedFraction, position } from '../WebXR/core.js';

let accepted = 0, capped = 0;
for (let p = 1; p <= 200; p++) for (let q = 1; q <= 200; q++) {
  const state = new FareyState();
  if (!state.select(p, q)) { capped++; continue; }
  accepted++;
  assert.equal(state.determinant, 1);
  assert.equal(state.mediant.p * q, p * state.mediant.q);
  const canonical = continuedFraction(state.mediant);
  const endpoint = continuedFraction(state.mediant, canonical.terms.length % 2 === 1);
  const word = endpoint.terms.map((n, i) => (i % 2 ? 'R' : 'L').repeat(n)).join('');
  assert.equal(word, state.word + 'R');
  for (const alternate of [false, true]) {
    const cf = continuedFraction(state.mediant, alternate);
    assert.deepEqual(cf.convergents.at(-1), state.mediant);
    for (const c of cf.convergents) {
      assert.ok(state.cfPoints(alternate).some(row => row.rational.p === c.p && row.rational.q === c.q));
    }
  }
}
const qBasis = position({ p: 0, q: 1 }), pBasis = position({ p: 1, q: 0 });
assert.ok(Math.abs(Math.hypot(...qBasis) - 0.25) < 1e-14);
assert.ok(Math.abs(Math.hypot(...pBasis) - 0.25) < 1e-14);
assert.ok(Math.abs(qBasis.reduce((dot, v, i) => dot + v * pBasis[i], 0)) < 1e-14);
console.log(JSON.stringify({ domain: '1 <= p,q <= 200', accepted, capped,
  checks: ['determinant one', 'reduced target', 'both finite expansions', 'convergent inclusion',
    'endpoint word = interval word + R', 'orthogonal equal-length display basis'],
  displayBasisLength: 0.25, claim: 'bounded execution evidence, not a mathematical proof' }, null, 2));
