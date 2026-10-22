import test from 'node:test';
import assert from 'node:assert/strict';
import { FareyState, grid, inspectPoint, onRay, position, primitive } from './core.js';

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
test('inspected multiples keep their point identity and canonical path', () => {
  const state = new FareyState();
  for (const [p, q, divisor] of [[3, 5, 1], [6, 10, 2], [9, 15, 3], [14, 14, 14], [1000, 1000, 1000]]) {
    assert.ok(state.select(p, q));
    assert.deepEqual(state.inspection.point, { p, q });
    assert.equal(state.inspection.divisor, divisor);
    assert.deepEqual(state.inspection.primitive, state.mediant);
    assert.ok(onRay(state.inspection.point, state.mediant));
    const point = position({ p, q }), direction = position(state.mediant);
    point.forEach((coordinate, axis) => assert.ok(Math.abs(coordinate - divisor * direction[axis]) < 1e-12));
  }
  state.select(6, 10);
  assert.equal(state.word, 'RLR');
  assert.equal(state.inspection.equation, '(10, 6) = 2 × (5, 3)');
  assert.equal(state.inspection.reduction, '6/10 = 3/5');
});
test('axes and invalid selections preserve inspection; navigation selects a new direction', () => {
  const state = new FareyState(); state.select(6, 10);
  const before = JSON.stringify(state);
  for (const [p, q] of [[0, 0], [0, 5], [5, 0], [-1, 2], [1001, 1001], [1, 1000]]) {
    assert.equal(state.select(p, q), false); assert.equal(JSON.stringify(state), before);
  }
  for (const [p, q] of [[0, 0], [0, 5], [5, 0], [-1, 2]]) assert.equal(inspectPoint({ p, q }), null);
  state.step('L'); assert.equal(state.selectedPoint, null); assert.deepEqual(state.inspection.primitive, { p: 5, q: 8 });
  state.select(6, 10); state.undo(); assert.equal(state.selectedPoint, null); assert.deepEqual(state.inspection.primitive, { p: 2, q: 3 });
  state.select(25, 1); const limit = JSON.stringify(state);
  assert.equal(state.step('L'), false); assert.equal(JSON.stringify(state), limit);
  state.reset(); assert.equal(state.selectedPoint, null); assert.deepEqual(state.inspection.primitive, { p: 1, q: 1 });
});
