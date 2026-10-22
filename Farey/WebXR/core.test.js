import test from 'node:test';
import assert from 'node:assert/strict';
import { FareyState, grid, onRay, position, primitive } from './core.js';

test('L/R convention, mediant and unimodular basis', () => {
  const s = new FareyState();
  s.step('L'); s.step('R');
  assert.deepEqual(s.mediant, { p: 3, q: 2 });
  assert.equal(s.determinant, 1);
  for (let i = 0; i < 22; i++) { s.step(i % 2 ? 'L' : 'R'); assert.equal(s.determinant, 1); }
  assert.equal(s.step('L'), false);
  s.undo(); assert.equal(s.word.length, 23);
});
test('every visible positive lattice pair selects its exact reduced direction', () => {
  for (const point of grid(14).filter(p => p.p > 0 && p.q > 0)) {
    const s = new FareyState();
    assert.ok(s.select(point.p, point.q));
    assert.ok(onRay(point, s.mediant));
    assert.ok(primitive(s.mediant));
    assert.equal(s.determinant, 1);
  }
  const s = new FareyState(); s.select(6, 10);
  assert.equal(s.word, 'RLR'); assert.deepEqual(s.mediant, { p: 3, q: 5 });
});
test('bounds reject invalid or unreachable selection without changing state', () => {
  const s = new FareyState(); s.select(3, 5); const before = JSON.stringify(s);
  for (const pair of [[0, 1], [1, 0], [1.5, 2], [1001, 2], [1, 1000]]) {
    assert.equal(s.select(...pair), false); assert.equal(JSON.stringify(s), before);
  }
  assert.equal(grid(99).length, 224); assert.equal(grid(0).length, 48);
});
test('spatial embedding preserves vector addition and ray incidence', () => {
  const s = new FareyState(); s.select(3, 5);
  const a = position(s.left), b = position(s.right), sum = position(s.mediant);
  for (let i = 0; i < 3; i++) assert.ok(Math.abs(a[i] + b[i] - sum[i]) < 1e-12);
  assert.ok(onRay({ p: 6, q: 10 }, s.mediant));
  assert.ok(!onRay({ p: 6, q: 9 }, s.mediant));
});
