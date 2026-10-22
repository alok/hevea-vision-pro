// SPDX-License-Identifier: GPL-3.0-or-later
import test from 'node:test';
import assert from 'node:assert/strict';
import { stars, vector, project, upperRoot, discriminant, kind, coefficientLattice, positiveRepresentative, projectedRepresentative } from './starscape-core.js';
test('every coefficient point lies strictly inside the 3D cone and projects along its ray', () => {
  for (const p of stars()) {
    const [x,y,z] = vector(p), image = project(p);
    assert.equal(x*x+z*z-y*y, discriminant(p));
    assert.ok(discriminant(p) < 0); assert.equal(image[1], 4);
    assert.ok(image[0]**2+image[2]**2 < 16);
    assert.ok(Math.abs(x*image[1]-y*image[0]) < 1e-10);
    const [u,v] = upperRoot(p), [a,b,c] = p;
    assert.ok(Math.abs(a*(u*u-v*v)+b*u+c) < 1e-10);
    assert.ok(Math.abs(2*a*u*v+b*v) < 1e-10);
    const k = [image[0]/4,image[2]/4];
    assert.ok(Math.abs(k[0]/(1-k[1])-u) < 1e-10);
    assert.ok(Math.abs(Math.sqrt(1-k[0]**2-k[1]**2)/(1-k[1])-v) < 1e-10);
  }
});
test('scalar multiples have distinct spatial positions and the same projection/root', () => {
  assert.notDeepEqual(vector([1,-1,2]),vector([2,-2,4]));
  assert.deepEqual(project([1,-1,2]),project([2,-2,4]));
  assert.deepEqual(upperRoot([1,-1,2]),upperRoot([2,-2,4]));
});
test('the displayed set is noncoplanar and rejects nonstars', () => {
  const origin = vector([1,0,1]);
  const vectors = [[1,1,1],[1,0,2],[2,0,2]].map(p=>vector(p).map((x,i)=>x-origin[i]));
  const [a,b,c]=vectors;
  const determinant=a[0]*(b[1]*c[2]-b[2]*c[1])-a[1]*(b[0]*c[2]-b[2]*c[0])+a[2]*(b[0]*c[1]-b[1]*c[0]);
  assert.notEqual(determinant,0);
  assert.equal(project([1,2,1]),null); assert.equal(project([0,0,1]),null);
  assert.equal(stars(100).length,0);
});
test('full coefficient ball contains both cone halves and exact sign partners', () => {
  const points=coefficientLattice(6), keys=new Set(points.map(p=>p.join(',')));
  assert.ok(points.some(p=>kind(p)==='upper'));
  assert.ok(points.some(p=>kind(p)==='lower'));
  assert.ok(points.some(p=>kind(p)==='null'));
  assert.ok(points.some(p=>kind(p)==='exterior'));
  for(const p of points) {
    assert.ok(keys.has(p.map(x=>-x).join(',')));
    assert.ok(vector(p).reduce((s,x)=>s+x*x,0)<=36);
    if(discriminant(p)<0) assert.deepEqual(projectedRepresentative(p), projectedRepresentative(p.map(x=>-x)));
  }
  assert.deepEqual(positiveRepresentative([-1,1,-2]),[1,-1,2]);
  assert.equal(projectedRepresentative([1,2,1]),null);
  assert.ok(coefficientLattice(12).length<4000);
});
