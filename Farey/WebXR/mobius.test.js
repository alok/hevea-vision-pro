// SPDX-License-Identifier: GPL-3.0-or-later
import test from 'node:test';
import assert from 'node:assert/strict';
import { identity, multiply, determinant, inverse, normalize, act, transvection, dragStep, pushforward, applyRows,
  pushforwardExact, kleinToUpper, upperToKlein, toI, fromI, actReal, nearestIntegral, isIntegral, polarAngle } from './mobius.js';
import { vector, discriminant, upperRoot } from './starscape-core.js';

const close = (x, y, tol = 1e-10) => assert.ok(Math.abs(x - y) <= tol * Math.max(1, Math.abs(y)), `${x} vs ${y}`);
const closeZ = (z, w, tol) => { close(z.x, w.x, tol); close(z.y, w.y, tol); };
const T = [1, 1, 0, 1], S = [0, -1, 1, 0];
const points = [{ x: 0, y: 1 }, { x: 1, y: 2 }, { x: -0.3, y: 0.05 }, { x: 4, y: 7 }, { x: -2.5, y: 0.4 }];
// The upper root of an upper-interior form, through our Klein chart.
const rootOf = abc => { const [X, Y, Z] = vector(abc); return kleinToUpper(X / Y, Z / Y); };

test('the transvection carries z0 to z1, has determinant 1, and is the pure translation from i', () => {
  for (const z0 of points) for (const z1 of points) {
    const g = transvection(z0, z1);
    close(determinant(g), 1); closeZ(act(g, z0), z1, 1e-9);
  }
  const w = { x: 1, y: 1 }, p = fromI(w);
  assert.deepEqual(transvection({ x: 0, y: 1 }, w).map(x => +x.toFixed(12)), p.map(x => +x.toFixed(12)));
  close(p[1], p[2]); assert.ok(p[0] > 0 && p[3] > 0);  // symmetric positive definite: no rotation about the target
  closeZ(act(toI({ x: 3, y: 0.5 }), { x: 3, y: 0.5 }), { x: 0, y: 1 });
});

test('a drag step moves the point under the pointer with the pointer, composing on the left', () => {
  let g = [...identity];
  const w = { x: 0.3, y: 1.7 };  // a root in base coordinates
  let z = act(g, w);
  for (const target of [{ x: 0.5, y: 1.5 }, { x: 2, y: 0.8 }, { x: -1, y: 3 }]) {
    g = dragStep(g, z, target); z = target;
    closeZ(act(g, w), target, 1e-9); close(determinant(g), 1);
  }
  assert.deepEqual(normalize([2, 0, 0, 2]), [1, 0, 0, 1]);
  assert.deepEqual(normalize([1, 0, 0, -1]), [...identity]);  // not in SL₂(ℝ)
});

test('the pushforward is a homomorphism that keeps Δ and moves each root by g', () => {
  const g = transvection({ x: 0, y: 1 }, { x: 1.3, y: 0.6 }), h = multiply(T, transvection({ x: 2, y: 1 }, { x: -1, y: 2 }));
  const gh = pushforward(multiply(g, h)), composed = [0, 1, 2].flatMap(i => [0, 1, 2].map(j =>
    [0, 1, 2].reduce((sum, k) => sum + pushforward(g)[3 * i + k] * pushforward(h)[3 * k + j], 0)));
  gh.forEach((x, i) => close(x, composed[i], 1e-9));
  assert.deepEqual(pushforward(identity).map(x => x + 0), [1, 0, 0, 0, 1, 0, 0, 0, 1]);
  for (const abc of [[1, -1, 2], [1, 0, 1], [3, 2, 2], [13, 20, 34], [2, 1, 1]]) {
    const moved = applyRows(pushforward(g), abc);
    close(discriminant(moved), discriminant(abc), 1e-8);
    closeZ(rootOf(moved), act(g, rootOf(abc)), 1e-8);
  }
});

test('integer matrices act exactly; others keep base identities and have no exact image', () => {
  assert.deepEqual(pushforwardExact(T, [1, 0, 1]), [1n, -2n, 2n]);   // root i → i + 1
  assert.deepEqual(pushforwardExact(S, [1, -1, 2]), [2n, 1n, 1n]);   // root z → −1/z
  assert.deepEqual(pushforwardExact(inverse(T), [1, -2, 2]), [1n, 0n, 1n]);
  assert.equal(pushforwardExact(transvection({ x: 0, y: 1 }, { x: 1, y: 1 }), [1, 0, 1]), null);
  assert.equal(pushforwardExact([2, 0, 0, 1], [1, 0, 1]), null);  // determinant 2
  for (const abc of [[1, 0, 1], [13, 20, 34], [-1, 1, -2]]) {
    assert.deepEqual(pushforwardExact(T, abc).map(Number), applyRows(pushforward(T), abc));
    assert.deepEqual(pushforwardExact(S, abc).map(Number), applyRows(pushforward(S), abc).map(x => x + 0));
  }
});

test('our Klein chart gives the quadratic formula root and inverts exactly', () => {
  for (const abc of [[1, -1, 2], [1, 0, 1], [1, 1, 1], [13, 20, 34], [2, -2, 4]]) {
    const [x, y] = upperRoot(abc); closeZ(rootOf(abc), { x, y });
  }
  for (const z of points) { const [u, v] = upperToKlein(z); closeZ(kleinToUpper(u, v), z, 1e-9); }
  assert.equal(kleinToUpper(1, 0), null); assert.equal(kleinToUpper(0.6, 0.9), null);
  // The user's seed (13,20,34): Δ = −1368, root (−10 + i√342)/13.
  assert.equal(discriminant([13, 20, 34]), -1368);
  closeZ(rootOf([13, 20, 34]), { x: -10 / 13, y: Math.sqrt(342) / 13 });
});

test('real-line action handles infinity, and Snap returns the nearest SL₂(ℤ) element', () => {
  assert.equal(actReal(T, Infinity), Infinity); assert.equal(actReal(S, 0), Infinity); assert.equal(actReal(S, Infinity), 0);
  assert.equal(actReal(T, -1), 0); close(actReal([2, 1, 1, 1], 1), 1.5);
  assert.deepEqual(nearestIntegral(identity), [1, 0, 0, 1]);
  for (const integral of [T, S, inverse(T), multiply(T, S), multiply(multiply(T, T), S)]) {
    const g = nearestIntegral(integral);
    assert.ok(isIntegral(g)); assert.ok(g.every((x, i) => x === integral[i]) || g.every((x, i) => x === -integral[i]));
  }
  // A small drag off the identity snaps back to it; one past a cell boundary lands on the integer neighbour.
  assert.deepEqual(nearestIntegral(transvection({ x: 0, y: 1 }, { x: 0.1, y: 1.05 })), [1, 0, 0, 1]);
  const near = nearestIntegral(multiply(transvection({ x: 0, y: 1 }, { x: 0.05, y: 1.1 }), T));
  assert.ok(isIntegral(near)); closeZ(act(near, { x: 0, y: 1 }), act(T, { x: 0, y: 1 }));
  assert.ok(!isIntegral(transvection({ x: 0, y: 1 }, { x: 1, y: 1 })));
});

test('Snap picks the candidate with the smaller polar rotation, as her viewer does', () => {
  // One drag from −0.4 + 0.1i to −0.4 + i: g = [√10, 1.138…, 0, 1/√10]. Entrywise distance picks T⁴S; the polar
  // criterion picks T⁴, so (13,20,34) is absorbed as (13,−84,162).
  const g = transvection({ x: -0.4, y: 0.1 }, { x: -0.4, y: 1 });
  close(g[0], Math.sqrt(10)); close(g[3], 1 / Math.sqrt(10)); close(g[2], 0);
  assert.deepEqual(nearestIntegral(g), [1, 4, 0, 1]);
  // The g recorded from her viewer for that drag (reading 'nearest γ [1,4;0,1]').
  assert.deepEqual(nearestIntegral([3.162278103784889, 1.1384199665329495, 4.0371747379733554e-16, 0.31622772165519336]), [1, 4, 0, 1]);
  assert.deepEqual(pushforwardExact(nearestIntegral(g), [13, 20, 34]), [13n, -84n, 162n]);
  close(polarAngle(identity), 0); close(Math.abs(polarAngle(S)), Math.PI / 2);
  close(polarAngle([Math.cos(0.3), -Math.sin(0.3), Math.sin(0.3), Math.cos(0.3)]), 0.3);
  close(polarAngle([-1, 0, 0, -1]), 0);  // −I acts as the identity
});

test('Snap rounds halves toward +∞ and refuses a nonfinite image of i', () => {
  assert.deepEqual(nearestIntegral([1, -0.5, 0, 1]), [1, 0, 0, 1]);
  assert.deepEqual(nearestIntegral([1, 0.5, 0, 1]), [1, 1, 0, 1]);
  assert.deepEqual(nearestIntegral([1, -1.5, 0, 1]), [1, -1, 0, 1]);
  assert.equal(nearestIntegral([1e200, 0, 0, 1e-200]), null);
  assert.equal(nearestIntegral([1, 1e300, 0, 1]), null);
});
