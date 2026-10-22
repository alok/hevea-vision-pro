import test from 'node:test';
import assert from 'node:assert/strict';
import { ApproximantSpotlight, FareyState, boundedDirectionEndpoint, latticeDirectionsOverlap, continuedFraction, grid, inspectPoint, onRay, position, primitive } from './core.js';

test('Float32 direction collision is detected for the known deep path at every grid bound', () => {
  const state = new FareyState();
  for (const turn of 'LR'.repeat(12)) state.step(turn);
  const exact = JSON.stringify(state);
  for (let bound = 6; bound <= 14; bound++) assert.equal(latticeDirectionsOverlap(state, bound), true);
  assert.deepEqual(state.mediant, { p: 121393, q: 75025 });
  assert.equal(JSON.stringify(state), exact);
});

test('Ordinary and close-but-distinct directions do not trigger the precision notice', () => {
  for (const word of ['', 'RLR', 'LRLRRRLLRLLRLLLLLRR', 'L'.repeat(24), 'R'.repeat(24)]) {
    const state = new FareyState();
    for (const turn of word) state.step(turn);
    for (let bound = 6; bound <= 14; bound++) assert.equal(latticeDirectionsOverlap(state, bound), false, word);
  }
});

test('Unreduced inspection is not a collision and the plane endpoint keeps its original formula', () => {
  const state = new FareyState(); state.select(6, 10);
  assert.equal(latticeDirectionsOverlap(state, 12), false);
  for (const rational of [state.left, state.mediant, state.right, { p: 121393, q: 75025 }]) {
    const scale = 12 / Math.max(rational.p, rational.q);
    assert.deepEqual(boundedDirectionEndpoint(rational, 12), position({ p: rational.p * scale, q: rational.q * scale }));
  }
});

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
test('canonical convergents differ from intermediate mediants and the alternate finite form', () => {
  const state = new FareyState(); state.select(6, 10);
  assert.deepEqual(continuedFraction(state.mediant).terms, [0, 1, 1, 2]);
  assert.deepEqual(continuedFraction({ p: 6, q: 10 }), continuedFraction({ p: 3, q: 5 }));
  assert.deepEqual(continuedFraction(state.mediant, true).terms, [0, 1, 1, 1, 1]);
  assert.equal(state.cfPoints().find(p => p.rational.p === 2 && p.rational.q === 3).isConvergent, false);
  assert.equal(state.cfPoints(true).find(p => p.rational.p === 2 && p.rational.q === 3).isConvergent, true);
  assert.deepEqual(state.selectedPoint, { p: 6, q: 10 });
});
test('both finite expansions end at the rational and agree with the endpoint L/R convention', () => {
  for (let p = 1; p <= 30; p++) for (let q = 1; q <= 30; q++) {
    const state = new FareyState(); if (!state.select(p, q)) continue;
    const cf = continuedFraction(state.mediant);
    assert.ok(cf.terms.length === 1 || cf.terms.at(-1) >= 2);
    const endpoint = continuedFraction(state.mediant, cf.terms.length % 2 === 1);
    assert.equal(endpoint.terms.map((n, i) => (i % 2 ? 'R' : 'L').repeat(n)).join(''), state.word + 'R');
    for (const alternate of [false, true]) {
      const convergents = continuedFraction(state.mediant, alternate).convergents;
      assert.deepEqual(convergents.at(-1), state.mediant);
      for (let i = 1; i < convergents.length; i++) {
        const a = convergents[i - 1], b = convergents[i]; assert.equal(Math.abs(a.p * b.q - a.q * b.p), 1);
      }
      assert.ok(state.cfPoints(alternate).length <= 26);
      for (const c of convergents) assert.ok(state.cfPoints(alternate).some(p => p.rational.p === c.p && p.rational.q === c.q));
    }
  }
  for (const [p, q] of [[0, 1], [1, 0], [-1, 2]]) assert.equal(continuedFraction({ p, q }), null);
});
test('spotlight is separate from target and inspection, and reconciles row identity', () => {
  const state = new FareyState(), spotlight = new ApproximantSpotlight();
  state.select(6, 10); const before = JSON.stringify(state);
  assert.ok(spotlight.focus({ p: 2, q: 3 }, state));
  spotlight.reconcile(state, true);
  assert.deepEqual(spotlight.rational, { p: 2, q: 3 }); assert.equal(JSON.stringify(state), before);
  assert.equal(spotlight.focus({ p: 7, q: 11 }, state), false);
  assert.deepEqual(spotlight.rational, { p: 2, q: 3 });
  assert.ok(spotlight.focus({ p: 1, q: 2 }, state));
  state.step('L'); spotlight.reconcile(state); assert.equal(spotlight.rational, null);
  state.reset(); assert.ok(spotlight.focus({ p: 0, q: 1 }, state, true));
  spotlight.reconcile(state); assert.equal(spotlight.rational, null);
  state.select(13, 17); assert.ok(spotlight.focus({ p: 13, q: 17 }, state));
  spotlight.reconcile(state, true); assert.deepEqual(spotlight.rational, { p: 13, q: 17 });
  spotlight.clear(); assert.equal(spotlight.rational, null);
});

test('projected preview navigates exact adjacent primitive directions without changing the target', async () => {
  const { ProjectedSelection } = await import('./core.js');
  const state = new FareyState(); state.select(6, 10); const before = JSON.stringify(state);
  const pick = ProjectedSelection.near({p:3,q:5},14);
  assert.equal(pick.points.length,127);
  pick.move(-1); assert.deepEqual(pick.point,{p:7,q:12});
  pick.move(2); assert.deepEqual(pick.point,{p:8,q:13});
  assert.equal(JSON.stringify(state),before);
  pick.move(-1000); assert.deepEqual(pick.point,{p:1,q:14}); assert.equal(pick.canGoBack,false);
  pick.move(1000); assert.deepEqual(pick.point,{p:14,q:1}); assert.equal(pick.canGoForward,false);
  for(const point of [{p:0,q:1},{p:1,q:0},{p:6,q:10},{p:15,q:1}]) assert.equal(ProjectedSelection.near(point,14),null);
  for(let i=1;i<pick.points.length;i++) {
    const a=pick.points[i-1],b=pick.points[i]; assert.ok(a.p*b.q<b.p*a.q);
  }
});
