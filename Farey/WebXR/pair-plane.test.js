// SPDX-License-Identifier: GPL-3.0-or-later
import test from 'node:test';
import assert from 'node:assert/strict';
import { pairPlane, inPairPlane, coneDirections, planeSection, necklaceMembers } from './pair-plane.js';
import { coefficientLattice, discriminant } from './starscape-core.js';

test('audited pair and its translated pair have the exact plane and endpoints',()=>{
  const p=pairPlane([1,0,1],[1,1,1]);
  assert.deepEqual(p.normal,[1,0,-1]);assert.equal(p.equation,'2a −2c = 0');
  assert.deepEqual(p.endpoints.map(x=>x.label),['-1','1']);
  const moved=pairPlane([1,-2,2],[1,-1,1]);
  assert.deepEqual(moved.normal,[1,-2,0]);assert.deepEqual(moved.endpoints.map(x=>x.label),['0','2']);
});

test('multiples, signs and order preserve a pair; equal primitive directions are rejected',()=>{
  const p=pairPlane([1,0,1],[1,1,1]);
  for(const q of [pairPlane([2,0,2],[-3,-3,-3]),pairPlane([1,1,1],[1,0,1])]) {
    assert.deepEqual(q.normal,p.normal);assert.deepEqual(q.endpoints,p.endpoints);
  }
  assert.match(pairPlane([1,0,1],[-2,0,-2]).error,/same primitive/);
  assert.match(pairPlane([1,0,1],[1,2,1]).error,/inside the cone/);
  assert.match(pairPlane([1,0,1],[NaN,0,1]).error,/integer/);
});

test('vertical geodesic includes infinity and irrational endpoints stay explicitly exact',()=>{
  const p=pairPlane([1,0,1],[1,0,4]);
  assert.deepEqual(p.endpoints.map(x=>x.label),['0','∞']);
  const q=pairPlane([1,0,1],[2,1,1]);
  assert.deepEqual(q.normal,[1,-2,-1]);assert.deepEqual(q.endpoints.map(x=>x.label),['1 − √2','1 + √2']);
});

test('sampled distinct complex-root directions determine real planes containing both points',()=>{
  const points=coefficientLattice(8).filter(p=>discriminant(p)<0);
  for(let i=0;i<points.length;i+=7)for(let j=i+1;j<points.length;j+=19) {
    const pair=pairPlane(points[i],points[j]);if(pair.error)continue;
    assert.ok(discriminant(pair.normal)>0);assert.ok(inPairPlane(pair.normal,points[i]));assert.ok(inPairPlane(pair.normal,points[j]));
    const [A,B,C]=pair.normal;
    for(const [x,y,z] of [...coneDirections(pair),...planeSection(pair.normal,8)]) {
      assert.ok(Math.abs(-B*x-(A+C)*y+(C-A)*z)<1e-10);
      assert.ok(Math.abs(y)<=8+1e-10);assert.ok(Math.hypot(x,z)<=8+1e-10);
    }
    for(const [x,y,z] of coneDirections(pair))assert.ok(Math.abs(x*x+z*z-y*y)<1e-12);
  }
});

test('necklace membership is exact and excludes off-cone points in the same plane',()=>{
  const pair=pairPlane([1,0,1],[1,1,1]);
  assert.deepEqual(necklaceMembers(pair,[[1,0,1],[2,2,2],[-1,0,-1],[1,3,1],[1,2,1],[1,0,2]]),[[1,0,1],[2,2,2],[-1,0,-1]]);
});

test('an exterior triple is its own Lorentz normal, as in Stange\'s viewer', async () => {
  const { planeFromNormal } = await import('./pair-plane.js');
  const plane = planeFromNormal([1, 8, -1]);
  assert.deepEqual(plane.normal, [1, 8, -1]);
  assert.equal(plane.equation, '2a +8b −2c = 0');
  assert.deepEqual(plane.endpoints.map(e => e.label), ['−4 − √17', '−4 + √17']);
  assert.ok(Math.abs(plane.endpoints[1].value - (-4 + Math.sqrt(17))) < 1e-12);
  assert.deepEqual(planeFromNormal([-2, -16, 2]).normal, [1, 8, -1]);
  assert.ok(planeFromNormal([1, 2, 1]).error && planeFromNormal([1, 0, 1]).error && planeFromNormal([0, 0, 0]).error);
  assert.deepEqual(planeFromNormal([2, 0, -6]).endpoints.map(e => e.label), ['−√3', '√3']);
  assert.deepEqual(planeFromNormal([2, 2, -1]).endpoints.map(e => e.label), ['(−1 − √3)/2', '(−1 + √3)/2']);
});
