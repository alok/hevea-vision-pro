// SPDX-License-Identifier: GPL-3.0-or-later
import test from 'node:test';
import assert from 'node:assert/strict';
import { anchors, categoryPalettes, coefficientColor, decode, glyphPixels, glyphRadius, glyphScale, oklab, outlinePixels, palettePosition, paletteRange, paletteSample } from './appearance.js';
const distance = (p,q) => Math.hypot(...oklab(p).map((v,i)=>v-oklab(q)[i]));
const pixels = (depth,h=900,fov=45) => glyphRadius*h/(2*depth*Math.tan(fov*Math.PI/360));

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
test('drawn radius stays within the CSS-pixel bounds at every depth',()=>{
  for(const depth of [0.01,0.05,0.1,0.5,1,2,5,10,20,60]) {
    const drawn=glyphScale(depth,900,45)*pixels(depth);
    assert.ok(drawn>=glyphPixels.min-1e-9&&drawn<=glyphPixels.max+1e-9,`${depth}: ${drawn}`);
    assert.ok(Math.abs(glyphScale(depth,900,45,1,outlinePixels)*pixels(depth)-drawn-outlinePixels)<1e-9);
  }
  const free=6;assert.ok(pixels(free)>glyphPixels.min&&pixels(free)<glyphPixels.max);
  assert.equal(glyphScale(free,900,45),1);
});
