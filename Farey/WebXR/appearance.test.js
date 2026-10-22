// SPDX-License-Identifier: GPL-3.0-or-later
import test from 'node:test';
import assert from 'node:assert/strict';
import { anchors, categoryPalettes, coefficientColor, decode, drawnPixels, glyphRadius, glyphScale, oklab, outlinePixels, palettePosition, paletteRange, paletteSample, pixelsPerWorld, sizePixels, sourceRadiusFactor } from './appearance.js';
import { vector } from './starscape-core.js';
const distance = (p,q) => Math.hypot(...oklab(p).map((v,i)=>v-oklab(q)[i]));

test('interior color uses Stange\'s fixed logarithmic |Δ| range and reproduces her anchors',()=>{
  assert.deepEqual(paletteRange,[3,240]);
  assert.equal(palettePosition(3),0);assert.equal(palettePosition(240),1);assert.equal(palettePosition(1000),1);
  anchors.forEach((hex,i)=>assert.ok(distance(paletteSample(i/5),decode(hex))<1e-3,hex));
  assert.ok(palettePosition(28)>palettePosition(7));
});
const nearestRamp=hex=>Math.min(...Array.from({length:241},(_,i)=>distance(paletteSample(i/240),decode(hex))));
test('our contrast categories stay visibly apart from every interior color; the reference gold does not',()=>{
  assert.ok(nearestRamp(categoryPalettes.reference.null)<1e-3);
  for(const [name,hex] of Object.entries(categoryPalettes.contrast)) {
    const nearest=nearestRamp(hex);
    assert.ok(nearest>=0.1,`${name} is ${nearest.toFixed(3)} from the ramp`);
  }
});
test('coloring uses the actual discriminant, not the primitive one',()=>{
  assert.notDeepEqual(coefficientColor([1,-1,2]),coefficientColor([2,-2,4]));
  assert.deepEqual(coefficientColor([1,-1,2]),coefficientColor([-1,1,-2],true));
  for(const mode of ['contrast','reference']) {
    const colors=categoryPalettes[mode];
    assert.deepEqual(coefficientColor([-1,1,-2],false,mode),decode(colors.lower));
    assert.deepEqual(coefficientColor([1,2,1],false,mode),decode(colors.null));
    assert.deepEqual(coefficientColor([1,3,1],false,mode),decode(colors.exterior));
    assert.deepEqual(coefficientColor([1,-1,2],false,mode),coefficientColor([1,-1,2]));
  }
});
test('source radius factors match the constants in Stange\'s viewer',()=>{
  assert.equal(sourceRadiusFactor([1,-1,2]),1);
  assert.equal(sourceRadiusFactor([2,-2,4]),0.72);
  assert.equal(sourceRadiusFactor([1,-1,2],{onPlane:true}),1.35);
  for(const offCone of [[1,2,1],[1,3,1],[-1,1,-2],[2,6,2]])assert.equal(sourceRadiusFactor(offCone),1);
  assert.equal(sourceRadiusFactor([-2,2,-4],{symmetric:true}),0.72);
  assert.equal(sourceRadiusFactor([1,3,1],{origin:true}),1);
  assert.equal(sourceRadiusFactor([-1,1,-2],{origin:true}),sourceRadiusFactor([1,-1,2],{origin:true}));
});
test('from the origin, apparent radius along a ray follows 1/sqrt|Δ| of the primitive form',()=>{
  const apparent=p=>sourceRadiusFactor(p,{origin:true})/Math.hypot(...vector(p));
  // multiples share a ray: k·p looks k times smaller, i.e. 1/sqrt of its |Δ| = k²|Δ₀|
  for(const k of [2,3])assert.ok(Math.abs(apparent([k,-k,2*k])*k-apparent([1,-1,2]))<1e-12);
  // x²+1: 0.4·|Δ|^¼/√(a+c) with |Δ|=4, a+c=2
  assert.ok(Math.abs(sourceRadiusFactor([1,0,1],{origin:true})-0.4*4**0.25/Math.sqrt(2))<1e-12);
});
test('drawn radius: faithful below the knee, cube-root and capped above, dimmed below the minimum',()=>{
  assert.deepEqual(drawnPixels(2),{px:2,dim:1});
  assert.equal(drawnPixels(0.5).px,sizePixels.min);assert.equal(drawnPixels(0.5).dim,0.25);
  assert.ok(Math.abs(drawnPixels(20).px-sizePixels.knee*2)<1e-12);
  assert.equal(drawnPixels(1e6).px,sizePixels.cap);
  let previous=0;for(let px=0.1;px<400;px*=1.1){const d=drawnPixels(px).px;assert.ok(d>=previous);previous=d;}
  const ratio=drawnPixels(40).px/drawnPixels(20).px;assert.ok(ratio>1.25&&ratio<1.27);
});
test('glyph scale reproduces drawnPixels and adds outline pixels',()=>{
  for(const depth of [0.1,0.5,2,6,20]) for(const factor of [0.5,1,1.35]) {
    const base=glyphRadius*pixelsPerWorld(depth,900,45);
    assert.ok(Math.abs(glyphScale(depth,900,45,1,0,factor)*base-drawnPixels(base*factor).px)<1e-9);
    assert.ok(Math.abs(glyphScale(depth,900,45,1,outlinePixels,factor)*base-drawnPixels(base*factor).px-outlinePixels)<1e-9);
  }
});
