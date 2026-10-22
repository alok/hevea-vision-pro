import test from 'node:test';
import assert from 'node:assert/strict';
import { boundaryProjection } from './construction.js';
import { grid } from './core.js';
test('q=1 projection preserves the ray and identifies positive multiples', () => {
  for (const point of grid(14).filter(p => p.q > 0)) {
    const projected = boundaryProjection(point);
    assert.equal(projected.q, 1);
    assert.ok(Math.abs(projected.p * point.q - point.p) < 1e-12);
    assert.deepEqual(boundaryProjection({p:point.p*3,q:point.q*3}), projected);
  }
});
test('infinity is not silently moved to a finite boundary point', () => {
  assert.equal(boundaryProjection({p:1,q:0}), null);
  assert.equal(boundaryProjection({p:-1,q:2}), null);
  assert.deepEqual(boundaryProjection({p:0,q:1}), {p:0,q:1});
});
