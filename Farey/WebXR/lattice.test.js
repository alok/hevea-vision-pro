// SPDX-License-Identifier: GPL-3.0-or-later
import test from 'node:test';
import assert from 'node:assert/strict';
import { ballCount, enumerateLattice, inBall, indexOf, isUpper, tripleAt } from './lattice.js';
import { coefficientLattice, discriminant, kind, vector } from './starscape-core.js';

const keys = (lattice) => Array.from({ length: lattice.count }, (_, i) => tripleAt(lattice, i).join());

test('typed enumeration is exactly the existing coefficient ball, without duplicates', () => {
  for (let r = 4; r <= 12; r++) {
    const typed = enumerateLattice(r), reference = coefficientLattice(r);
    const set = new Set(keys(typed));
    assert.equal(typed.count, reference.length);
    assert.equal(set.size, typed.count);
    for (const p of reference) assert.ok(set.has(p.join()), p.join());
    assert.equal(ballCount(r), typed.count);
    const upper = enumerateLattice(r, true);
    assert.equal(upper.count, reference.filter(p => kind(p) === 'upper').length);
  }
  assert.equal(enumerateLattice(12).count, 3608);
});
test('display coordinates satisfy X=−b, Y=a+c, Z=c−a and Δ = X²+Z²−Y²', () => {
  const lattice = enumerateLattice(24);
  for (let i = 0; i < lattice.count; i += 7) {
    const p = tripleAt(lattice, i), [x, y, z] = [lattice.xyz[3 * i], lattice.xyz[3 * i + 1], lattice.xyz[3 * i + 2]];
    assert.deepEqual([x, y, z], vector(p).map(v => v + 0));
    assert.ok(!Object.is(x, -0));
    assert.equal(x * x + z * z - y * y, discriminant(p));
    assert.ok(inBall(p, 24));
  }
  assert.equal(lattice.maxInterior, 24 * 24);
});
test('displayed lattice has Y ≡ Z (mod 2) and covolume 2: count ≈ (4/3)πR³/2', () => {
  for (const r of [24, 48]) {
    const lattice = enumerateLattice(r);
    for (let i = 0; i < lattice.count; i++) assert.equal(Math.abs(lattice.xyz[3 * i + 1] - lattice.xyz[3 * i + 2]) % 2, 0);
    const expected = 2 * Math.PI * r ** 3 / 3;
    assert.ok(Math.abs(lattice.count / expected - 1) < 0.02, `${lattice.count} vs ${expected}`);
  }
});
test('membership and lookup agree with enumeration', () => {
  const lattice = enumerateLattice(8);
  assert.ok(inBall([1, -1, 2], 8)); assert.ok(!inBall([0, 0, 0], 8)); assert.ok(!inBall([6, 0, 0], 8));
  assert.equal(tripleAt(lattice, indexOf(lattice, [1, -1, 2])).join(), '1,-1,2');
  assert.equal(indexOf(lattice, [9, 9, 9]), -1);
  assert.ok(isUpper([1, -1, 2]) && !isUpper([-1, 1, -2]) && !isUpper([1, 3, 1]));
  assert.throws(() => enumerateLattice(97), RangeError);
});
